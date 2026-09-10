/**
 * ANEXOMAIL workspace API — awam Personal | Business (F3 B).
 * Live FK: org_members.org_id → public.organisations (slug NOT NULL, domain UNIQUE).
 * Founder protocol yahan nahi — sirf awam operational workspace.
 */
import { randomUUID } from "node:crypto";
import { Router } from "express";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const KEY = process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const db: SupabaseClient | null =
  URL && KEY
    ? createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } })
    : null;

export const workspaceRouter = Router();

async function userId(req: any, res: any) {
  if (!db) {
    res.status(503).json({ error: "account_service_not_configured" });
    return null;
  }
  const raw = String(req.headers.authorization || "");
  const token = raw.startsWith("Bearer ") ? raw.slice(7) : "";
  const { data, error } = token
    ? await db.auth.getUser(token)
    : { data: { user: null }, error: null };
  if (error || !data.user) {
    res.status(401).json({ error: "unauthorized" });
    return null;
  }
  return data.user.id;
}

function slugify(name: string, uid: string) {
  const base =
    name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "")
      .slice(0, 40) || "workspace";
  return `${base}-${uid.slice(0, 8)}`;
}

/** Live parent = organisations. Domain kabhi shared anexomail.com nahi (UNIQUE). */
async function createOperationalOrg(opts: {
  uid: string;
  name: string;
  email: string | null;
  kind: "personal" | "business";
}) {
  if (!db) throw new Error("account_service_not_configured");
  const id = randomUUID();
  const slug =
    opts.kind === "personal"
      ? `personal-${opts.uid.replace(/-/g, "").slice(0, 12)}`
      : slugify(opts.name, opts.uid);

  const orgRow: Record<string, unknown> = { id, name: opts.name, slug };
  // owner_id optional on some schemas
  const withOwner = { ...orgRow, owner_id: opts.uid };
  let orgError = (await db.from("organisations").insert(withOwner)).error;
  if (orgError) {
    orgError = (await db.from("organisations").insert(orgRow)).error;
  }
  if (orgError) throw new Error(orgError.message || "operational_workspace_failed");

  const memberPayload: Record<string, unknown> = {
    org_id: id,
    user_id: opts.uid,
    role: "owner",
    status: "active",
  };
  if (opts.email) memberPayload.email = opts.email;
  let memberError = (
    await db.from("org_members").upsert(memberPayload, { onConflict: "org_id,user_id" })
  ).error;
  if (memberError) {
    const { status: _s, ...withoutStatus } = memberPayload as any;
    memberError = (
      await db.from("org_members").upsert(withoutStatus, { onConflict: "org_id,user_id" })
    ).error;
  }
  if (memberError) {
    await db.from("organisations").delete().eq("id", id);
    throw new Error("operational_membership_failed");
  }

  // Account layer (UI session) — domain null; unique slug
  const { error: accountOrgError } = await db.from("account_organisations").upsert(
    {
      id,
      name: opts.name,
      slug,
      domain: null,
      created_by: opts.uid,
    },
    { onConflict: "id" },
  );
  if (!accountOrgError) {
    await db
      .from("account_org_members")
      .upsert({ org_id: id, user_id: opts.uid, role: "owner" }, { onConflict: "org_id,user_id" });
  }

  // Legacy orgs table — best effort, fail mat karo (FK live organisations pe hai)
  await db.from("orgs").upsert({ id, name: opts.name }, { onConflict: "id" });

  if (opts.email) {
    const { data: existingMail } = await db
      .from("mail_accounts")
      .select("address")
      .ilike("address", opts.email)
      .maybeSingle();
    if (existingMail) {
      await db.from("mail_accounts").update({ org_id: id }).ilike("address", opts.email);
    } else {
      await db.from("mail_accounts").insert({ org_id: id, address: opts.email });
    }
  }

  return { id, name: opts.name, slug, domain: null, kind: opts.kind };
}

workspaceRouter.post("/personal", async (req, res) => {
  const uid = await userId(req, res);
  if (!uid || !db) return;
  const { data: authUser } = await db.auth.admin.getUserById(uid);
  const email = authUser.user?.email || null;

  const { data: existing } = await db
    .from("org_members")
    .select("org_id")
    .eq("user_id", uid)
    .limit(1)
    .maybeSingle();
  if (existing?.org_id) {
    await db
      .from("account_profiles")
      .update({ onboarded: true, updated_at: new Date().toISOString() })
      .eq("user_id", uid);
    return res.status(200).json({ id: existing.org_id, kind: "personal", existing: true });
  }

  try {
    const org = await createOperationalOrg({
      uid,
      name: "Personal mail",
      email,
      kind: "personal",
    });
    await db
      .from("account_profiles")
      .update({ onboarded: true, updated_at: new Date().toISOString() })
      .eq("user_id", uid);
    return res.status(201).json(org);
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || "personal_workspace_failed" });
  }
});

workspaceRouter.post("/organisations", async (req, res) => {
  const uid = await userId(req, res);
  if (!uid || !db) return;
  const name = String(req.body?.name || "").trim();
  // F3 B: domain yahan accept mat karo — Ownership Center baad
  if (name.length < 2) return res.status(400).json({ error: "Organisation name is required." });

  const { data: authUser } = await db.auth.admin.getUserById(uid);
  const email = authUser.user?.email || null;

  try {
    const org = await createOperationalOrg({ uid, name, email, kind: "business" });
    return res.status(201).json(org);
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || "operational_workspace_failed" });
  }
});

workspaceRouter.post("/invitations", async (req, res) => {
  const uid = await userId(req, res);
  if (!uid) return;
  const emails = Array.isArray(req.body?.emails)
    ? req.body.emails.filter((v: unknown) => typeof v === "string")
    : [];
  if (!emails.length) return res.status(400).json({ error: "At least one email is required." });
  let orgId: string | null = null;
  const { data: membership } = await db!
    .from("account_org_members")
    .select("org_id,role")
    .eq("user_id", uid)
    .in("role", ["owner", "admin"])
    .limit(1)
    .maybeSingle();
  if (membership?.org_id) orgId = membership.org_id;
  if (!orgId) {
    const { data: ops } = await db!
      .from("org_members")
      .select("org_id,role")
      .eq("user_id", uid)
      .limit(1)
      .maybeSingle();
    if (ops?.org_id) orgId = ops.org_id;
  }
  if (!orgId) return res.status(403).json({ error: "organisation_admin_required" });
  const invited: string[] = [];
  for (const raw of emails) {
    const email = String(raw).trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) continue;
    const { error } = await db!.auth.admin.inviteUserByEmail(email, {
      redirectTo: "https://anexomail.com/auth/callback",
      data: { organisation_id: orgId, role: "member" },
    });
    if (!error) invited.push(email);
  }
  if (!invited.length) return res.status(502).json({ error: "invitations_not_sent" });
  res.json({ invited });
});
