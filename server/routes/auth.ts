// ANEXOMAIL account lifecycle API — credentials in Supabase Auth, profile in public tables.
import { createHash } from "node:crypto";
import { Router } from "express";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const PUBLIC =
  process.env.SUPABASE4_PUBLISHABLE_KEY || process.env.SUPABASE_PUBLISHABLE_KEY || SERVICE;
const APP_URL = process.env.APP_URL || "https://anexomail.com";

const admin =
  URL && SERVICE
    ? createClient(URL, SERVICE, { auth: { persistSession: false, autoRefreshToken: false } })
    : null;
const publicAuth =
  URL && PUBLIC
    ? createClient(URL, PUBLIC, { auth: { persistSession: false, autoRefreshToken: false } })
    : null;
export const authRouter = Router();

function getAdmin(): SupabaseClient {
  if (!admin) throw new Error("account_service_not_configured");
  return admin;
}

function getPublicAuth(): SupabaseClient {
  if (!publicAuth) throw new Error("account_service_not_configured");
  return publicAuth;
}

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const passwordOk = (value: string) => value.length >= 6 && value.length <= 15;
const tokenHash = (token: string) => createHash("sha256").update(token).digest("hex");

function unavailable(res: any) {
  if (admin && publicAuth) return false;
  res.status(503).json({ error: "account_service_not_configured" });
  return true;
}

async function userFrom(req: any, res: any) {
  if (unavailable(res)) return null;
  const raw = String(req.headers.authorization || "");
  const token = raw.startsWith("Bearer ") ? raw.slice(7) : "";
  if (!token) {
    res.status(401).json({ error: "unauthorized" });
    return null;
  }
  const { data, error } = await getAdmin().auth.getUser(token);
  if (error || !data.user) {
    res.status(401).json({ error: "unauthorized" });
    return null;
  }
  return { user: data.user, token };
}

function authError(
  res: any,
  error: { message?: string; status?: number } | null,
  fallback = "authentication_failed",
) {
  const message = error?.message || fallback;
  const status = error?.status && error.status >= 400 && error.status < 500 ? error.status : 400;
  return res.status(status).json({ error: message });
}

async function saveSession(userId: string, token: string, req: any) {
  const ua = String(req.headers["user-agent"] || "Unknown device").slice(0, 300);
  await getAdmin()
    .from("account_sessions")
    .upsert(
      {
        user_id: userId,
        token_hash: tokenHash(token),
        device: ua,
        browser: ua,
        ip: String(req.ip || "").slice(0, 80) || null,
        last_seen_at: new Date().toISOString(),
        revoked_at: null,
      },
      { onConflict: "token_hash" },
    );
}

/** FOUNDER PROTOCOL: authority `public.founder_accounts`. Founder par awam ka claim/onboarding flow kabhi nahi. */
async function isFounderUser(uid: string): Promise<boolean> {
  const { data } = await getAdmin()
    .from("founder_accounts")
    .select("user_id")
    .eq("user_id", uid)
    .maybeSingle();
  return Boolean(data);
}

async function operationalOrganisation(uid: string, email: string | null | undefined) {
  const { data: membership } = await getAdmin()
    .from("org_members")
    .select("org_id,role")
    .eq("user_id", uid)
    .limit(1)
    .maybeSingle();
  if (membership?.org_id) return { id: membership.org_id, role: membership.role || "member" };

  const address = String(email || "")
    .trim()
    .toLowerCase();
  if (!address) return null;
  const { data: mailbox } = await getAdmin()
    .from("mail_accounts")
    .select("org_id")
    .eq("address", address)
    .limit(1)
    .maybeSingle();
  if (!mailbox?.org_id) return null;

  const { error } = await getAdmin()
    .from("org_members")
    .upsert(
      { org_id: mailbox.org_id, user_id: uid, email: address, role: "owner", status: "active" },
      { onConflict: "org_id,user_id" },
    );
  if (error) {
    console.error("[auth.operational-workspace]", error.message);
    return null;
  }
  return { id: mailbox.org_id, role: "owner" };
}

async function sessionResult(user: any, accessToken?: string, req?: any) {
  if (accessToken && req) await saveSession(user.id, accessToken, req);
  const uid = user.id;
  const [{ data: profile }, { data: memberships }, { data: trial }, founder, operational] =
    await Promise.all([
      getAdmin()
        .from("account_profiles")
        .select("legal_name,display_name,avatar_url,work_role,preferences,onboarded")
        .eq("user_id", uid)
        .maybeSingle(),
      getAdmin()
        .from("account_org_members")
        .select("role,account_organisations(id,name,slug,domain)")
        .eq("user_id", uid),
      getAdmin()
        .from("trial_accounts")
        .select("anexomail_address")
        .eq("user_id", uid)
        .maybeSingle(),
      isFounderUser(uid),
      operationalOrganisation(uid, user.email),
    ]);
  const organisations = (memberships || []).flatMap((row: any) =>
    row.account_organisations ? [{ ...row.account_organisations, role: row.role }] : [],
  );
  if (
    operational &&
    !organisations.some((organisation: any) => organisation.id === operational.id)
  ) {
    const { data: legacy } = await getAdmin()
      .from("orgs")
      .select("id,name")
      .eq("id", operational.id)
      .maybeSingle();
    organisations.push({
      id: operational.id,
      name: legacy?.name || (founder ? "Founder workspace" : "ANEXOMAIL Workspace"),
      slug: founder ? "founder-workspace" : `workspace-${operational.id.slice(0, 8)}`,
      domain: null,
      role: operational.role,
    });
  }
  return {
    ...(accessToken ? { token: accessToken } : {}),
    user: {
      id: uid,
      email: user.email || "",
      name: profile?.display_name || profile?.legal_name || user.user_metadata?.name || null,
      legal_name: profile?.legal_name || null,
      display_name: profile?.display_name || null,
      avatar_url: profile?.avatar_url || null,
      work_role: profile?.work_role || null,
      preferences: profile?.preferences || {},
      mfa_enabled: false,
      is_founder: founder,
      onboarded: founder || Boolean(profile?.onboarded),
      anexomail_address: trial?.anexomail_address || (founder ? user.email || null : null),
    },
    organisations,
    active_organisation_id: organisations[0]?.id || null,
  };
}

authRouter.post("/signup", async (req, res) => {
  if (unavailable(res)) return;
  const email = String(req.body?.email || "")
    .trim()
    .toLowerCase();
  const password = String(req.body?.password || "");
  const legalName = String(req.body?.legal_name || req.body?.name || "").trim();
  const displayName = String(req.body?.display_name || legalName).trim();
  const avatarUrl = req.body?.avatar_url ? String(req.body.avatar_url).trim() : null;
  const workRole = req.body?.work_role ? String(req.body.work_role).trim() : null;
  const preferences =
    req.body?.preferences && typeof req.body.preferences === "object" ? req.body.preferences : {};
  if (!emailPattern.test(email))
    return res.status(400).json({ error: "Enter a valid email address." });
  if (!legalName || !displayName)
    return res.status(400).json({ error: "Name and display name are required." });
  if (!passwordOk(password))
    return res.status(400).json({ error: "Password must be 6 to 15 characters." });

  const { data, error } = await getPublicAuth().auth.signUp({
    email,
    password,
    options: {
      data: { name: legalName, display_name: displayName, work_role: workRole },
      emailRedirectTo: `${APP_URL}/auth/callback`,
    },
  });
  if (error || !data.user) return authError(res, error);
  const { error: profileError } = await getAdmin().from("account_profiles").upsert(
    {
      user_id: data.user.id,
      email,
      legal_name: legalName,
      display_name: displayName,
      avatar_url: avatarUrl,
      work_role: workRole,
      preferences,
    },
    { onConflict: "user_id" },
  );
  if (profileError) return res.status(500).json({ error: "profile_save_failed" });
  await getAdmin()
    .from("user_roles")
    .upsert({ user_id: data.user.id, role: "user" }, { onConflict: "user_id,role" });
  await getAdmin().rpc("trial_start", {
    _user_id: data.user.id,
    _social_email: email,
    _provider: "email",
  });
  if (!data.session?.access_token) return res.status(202).json({ confirmation_required: true });
  await saveSession(data.user.id, data.session.access_token, req);
  res.status(201).json({ token: data.session.access_token, confirmation_required: false });
});

authRouter.post("/login", async (req, res) => {
  if (unavailable(res)) return;
  const email = String(req.body?.email || "")
    .trim()
    .toLowerCase();
  const password = String(req.body?.password || "");
  if (!emailPattern.test(email) || !password)
    return res.status(400).json({ error: "Email and password are required." });
  const { data, error } = await getPublicAuth().auth.signInWithPassword({ email, password });
  if (error || !data.user || !data.session) return authError(res, error, "invalid_credentials");
  res.json(await sessionResult(data.user, data.session.access_token, req));
});

authRouter.get("/session", async (req, res) => {
  const identity = await userFrom(req, res);
  if (!identity) return;
  res.json(await sessionResult(identity.user));
});

authRouter.post("/logout", async (req, res) => {
  const identity = await userFrom(req, res);
  if (!identity) return;
  await getAdmin()
    .from("account_sessions")
    .update({ revoked_at: new Date().toISOString() })
    .eq("token_hash", tokenHash(identity.token));
  await getAdmin().auth.admin.signOut(identity.token, "local");
  res.json({ ok: true });
});

authRouter.post("/forgot-password", async (req, res) => {
  if (unavailable(res)) return;
  const email = String(req.body?.email || "")
    .trim()
    .toLowerCase();
  if (!emailPattern.test(email))
    return res.status(400).json({ error: "Enter a valid email address." });
  await getPublicAuth().auth.resetPasswordForEmail(email, {
    redirectTo: `${APP_URL}/auth?mode=reset`,
  });
  res.json({ ok: true });
});

authRouter.post("/magic-link", async (req, res) => {
  if (unavailable(res)) return;
  const email = String(req.body?.email || "")
    .trim()
    .toLowerCase();
  const redirectTo = String(req.body?.redirect_to || `${APP_URL}/auth/callback`);
  if (!emailPattern.test(email))
    return res.status(400).json({ error: "Enter a valid email address." });
  const { error } = await getPublicAuth().auth.signInWithOtp({
    email,
    options: { emailRedirectTo: redirectTo, shouldCreateUser: false },
  });
  if (error && !/user not found/i.test(error.message)) return authError(res, error);
  res.json({ ok: true });
});

// Supabase PKCE email confirmation and magic-link callback. Social providers are not exposed.
authRouter.post("/oauth/callback", async (req, res) => {
  if (unavailable(res)) return;
  const code = String(req.body?.code || "");
  if (!code) return res.status(400).json({ error: "verification_code_required" });
  const { data, error } = await getPublicAuth().auth.exchangeCodeForSession(code);
  if (error || !data.user || !data.session) return authError(res, error, "verification_failed");
  res.json(await sessionResult(data.user, data.session.access_token, req));
});

authRouter.post("/reset-password", async (req, res) => {
  if (unavailable(res)) return;
  const accessToken = String(req.body?.access_token || "");
  const password = String(req.body?.password || "");
  if (!accessToken || !passwordOk(password))
    return res.status(400).json({ error: "A valid reset link and strong password are required." });
  const { data: who, error: whoError } = await getAdmin().auth.getUser(accessToken);
  if (whoError || !who.user)
    return res.status(401).json({ error: "Reset link is invalid or expired." });
  const { error } = await getAdmin().auth.admin.updateUserById(who.user.id, { password });
  if (error) return authError(res, error);
  res.json({ ok: true });
});

authRouter.post("/change-password", async (req, res) => {
  const identity = await userFrom(req, res);
  if (!identity) return;
  const currentPassword = String(req.body?.current_password || "");
  const newPassword = String(req.body?.new_password || "");
  if (!passwordOk(newPassword))
    return res.status(400).json({ error: "New password must be 6 to 15 characters." });
  const email = identity.user.email || "";
  const verified = await getPublicAuth().auth.signInWithPassword({
    email,
    password: currentPassword,
  });
  if (verified.error) return res.status(401).json({ error: "Current password is incorrect." });
  const { error } = await getAdmin().auth.admin.updateUserById(identity.user.id, {
    password: newPassword,
  });
  if (error) return authError(res, error);
  await getAdmin()
    .from("account_sessions")
    .update({ revoked_at: new Date().toISOString() })
    .eq("user_id", identity.user.id)
    .neq("token_hash", tokenHash(identity.token));
  res.json({ ok: true });
});

authRouter.get("/sessions", async (req, res) => {
  const identity = await userFrom(req, res);
  if (!identity) return;
  const current = tokenHash(identity.token);
  const { data, error } = await getAdmin()
    .from("account_sessions")
    .select("id,token_hash,device,browser,ip,location,last_seen_at")
    .eq("user_id", identity.user.id)
    .is("revoked_at", null)
    .order("last_seen_at", { ascending: false });
  if (error) return res.status(500).json({ error: "sessions_load_failed" });
  res.json(
    (data || []).map(({ token_hash, ...row }: any) => ({
      ...row,
      current: token_hash === current,
    })),
  );
});

authRouter.delete("/sessions/:id", async (req, res) => {
  const identity = await userFrom(req, res);
  if (!identity) return;
  const { error } = await getAdmin()
    .from("account_sessions")
    .update({ revoked_at: new Date().toISOString() })
    .eq("id", req.params.id)
    .eq("user_id", identity.user.id);
  if (error) return res.status(500).json({ error: "session_revoke_failed" });
  res.json({ ok: true });
});

authRouter.post("/onboarding/complete", async (req, res) => {
  const identity = await userFrom(req, res);
  if (!identity) return;
  const { error } = await getAdmin()
    .from("account_profiles")
    .update({ onboarded: true, updated_at: new Date().toISOString() })
    .eq("user_id", identity.user.id);
  if (error) return res.status(500).json({ error: "onboarding_update_failed" });
  res.json({ ok: true });
});

authRouter.get("/identity/check", async (req, res) => {
  if (unavailable(res)) return;
  const username = String(req.query.username || "")
    .trim()
    .toLowerCase();
  if (!/^[a-z0-9]([a-z0-9.-]{1,28})[a-z0-9]$/.test(username))
    return res.json({ available: false, reason: "invalid_handle" });
  const [{ data: reserved }, { data: taken }] = await Promise.all([
    getAdmin().from("reserved_handles").select("handle").eq("handle", username).maybeSingle(),
    getAdmin()
      .from("trial_accounts")
      .select("user_id")
      .eq("anexomail_handle", username)
      .neq("status", "released")
      .maybeSingle(),
  ]);
  res.json({
    available: !reserved && !taken,
    reason: reserved ? "reserved_handle" : taken ? "taken" : undefined,
  });
});

authRouter.post("/identity/claim", async (req, res) => {
  const identity = await userFrom(req, res);
  if (!identity) return;
  const username = String(req.body?.username || "")
    .trim()
    .toLowerCase();
  const { data, error } = await getAdmin().rpc("trial_claim_address", {
    _user_id: identity.user.id,
    _handle: username,
  });
  if (error || data?.ok === false)
    return res.status(409).json({ error: error?.message || data?.reason || "address_unavailable" });
  res.json({ address: data.address || `${username}@anexomail.com` });
});
