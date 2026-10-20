/**
 * F3 A — live passkey routes (Bun :3100). 501 nahi.
 */
import type { Router } from "express";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  b64urlToBuf,
  randomChallenge,
  rpFromRequest,
  verifyAssertion,
  verifyRegistration,
  type PublicJwk,
} from "../lib/webauthn";

const APP_URL = process.env.APP_URL || "https://anexomail.com";

function anexomailIdentity(raw: string): string {
  const trimmed = String(raw || "")
    .trim()
    .toLowerCase();
  const before = trimmed.includes("@") ? trimmed.slice(0, trimmed.indexOf("@")) : trimmed;
  const local = before.replace(/[^a-z0-9._-]/g, "");
  return local ? `${local}@anexomail.com` : "";
}

function fail(res: any, status: number, error: string) {
  return res.status(status).json({ error });
}

function credentialPayload(cred: any) {
  const response = cred?.response || cred;
  return {
    id: String(cred?.id || cred?.rawId || ""),
    clientDataJSON: String(response.clientDataJSON || ""),
    attestationObject: String(response.attestationObject || ""),
    authenticatorData: String(response.authenticatorData || ""),
    signature: String(response.signature || ""),
    userHandle: response.userHandle ? String(response.userHandle) : null,
  };
}

async function sessionForEmail(admin: SupabaseClient, email: string, req: any, sessionResult: Function) {
  const { data, error } = await admin.auth.admin.generateLink({
    type: "magiclink",
    email,
  });
  if (error || !data?.properties) throw new Error("passkey_session_failed");
  const hashed = data.properties.hashed_token;
  if (hashed) {
    const { data: verified, error: verifyError } = await admin.auth.verifyOtp({
      type: "email",
      token_hash: hashed,
    });
    if (!verifyError && verified.user && verified.session?.access_token) {
      return sessionResult(verified.user, verified.session.access_token, req);
    }
  }
  const action = String(data.properties.action_link || "");
  let token = "";
  try {
    token = new URL(action).searchParams.get("token") || "";
  } catch {
    token = "";
  }
  if (!token) throw new Error("passkey_session_failed");
  const { data: verified, error: verifyError } = await admin.auth.verifyOtp({
    type: "magiclink",
    token,
    email,
  });
  if (verifyError || !verified.user || !verified.session?.access_token) {
    throw new Error("passkey_session_failed");
  }
  return sessionResult(verified.user, verified.session.access_token, req);
}

export function mountPasskeyRoutes(
  authRouter: Router,
  deps: {
    getAdmin: () => SupabaseClient;
    userFrom: (req: any, res: any) => Promise<{ user: any; token: string } | null>;
    sessionResult: (user: any, accessToken?: string, req?: any) => Promise<unknown>;
    markPasskeySet: (userId: string) => Promise<void>;
  },
) {
  const { getAdmin, userFrom, sessionResult, markPasskeySet } = deps;

  authRouter.post("/passkey/register/options", async (req, res) => {
    const identity = await userFrom(req, res);
    if (!identity) return;
    try {
      const rp = rpFromRequest(req.headers.origin, APP_URL);
      const challenge = randomChallenge();
      await getAdmin().from("webauthn_challenges").delete().lt("expires_at", new Date().toISOString());
      const { error } = await getAdmin().from("webauthn_challenges").insert({
        user_id: identity.user.id,
        email: identity.user.email,
        kind: "register",
        challenge,
        rp_id: rp.rpId,
        origin: rp.origin,
        expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
      });
      if (error) return fail(res, 500, "passkey_challenge_failed");
      // G35: pehle se registered credentials exclude (ek hi device par dobara nahi) —
      // aur `authenticatorAttachment` NAHI lagate: phone (QR/hybrid), laptop, security key sab chalen.
      const { data: existing } = await getAdmin()
        .from("webauthn_credentials")
        .select("credential_id")
        .eq("user_id", identity.user.id);
      res.json({
        publicKey: {
          challenge,
          rp: { name: "ANEXOMAIL", id: rp.rpId },
          user: {
            id: Buffer.from(String(identity.user.id), "utf8").toString("base64url"),
            name: identity.user.email,
            displayName: identity.user.user_metadata?.display_name || identity.user.email,
          },
          pubKeyCredParams: [
            { type: "public-key", alg: -7 },
            { type: "public-key", alg: -257 },
          ],
          excludeCredentials: (existing || []).map((c: any) => ({
            type: "public-key",
            id: String(c.credential_id),
          })),
          authenticatorSelection: {
            residentKey: "preferred",
            userVerification: "required",
          },
          timeout: 120000,
          attestation: "none",
        },
      });
    } catch (e: any) {
      const code = String(e?.message || "passkey_failed");
      const status = code.startsWith("passkey_") ? 400 : 400;
      return fail(res, status, code);
    }
  });

  authRouter.post("/passkey/register/verify", async (req, res) => {
    const identity = await userFrom(req, res);
    if (!identity) return;
    try {
      const rp = rpFromRequest(req.headers.origin, APP_URL);
      const cred = credentialPayload(req.body);
      const client = JSON.parse(b64urlToBuf(cred.clientDataJSON).toString("utf8")) as {
        challenge?: string;
      };
      const { data: row, error } = await getAdmin()
        .from("webauthn_challenges")
        .select("challenge,origin,rp_id,expires_at")
        .eq("user_id", identity.user.id)
        .eq("kind", "register")
        .eq("challenge", client.challenge || "")
        .maybeSingle();
      if (error || !row || new Date(row.expires_at).getTime() < Date.now()) {
        return fail(res, 400, "passkey_challenge_expired");
      }
      if (row.origin !== rp.origin || row.rp_id !== rp.rpId) return fail(res, 400, "passkey_origin_mismatch");
      const parsed = verifyRegistration({
        clientDataJSON: cred.clientDataJSON,
        attestationObject: cred.attestationObject,
        challenge: row.challenge,
        origin: rp.origin,
        rpId: rp.rpId,
      });
      const label = String(req.body?.label || "").replace(/[^\w .,'()-]/g, "").trim().slice(0, 60);
      const ua = label || String(req.headers["user-agent"] || "This device").slice(0, 80);
      const { error: insError } = await getAdmin().from("webauthn_credentials").insert({
        user_id: identity.user.id,
        credential_id: parsed.credentialId,
        public_key: parsed.publicKey,
        sign_count: parsed.signCount,
        device_name: ua,
        transports: ["internal"],
        last_used_at: new Date().toISOString(),
      });
      if (insError) return fail(res, 400, insError.message.includes("duplicate") ? "passkey_already_registered" : "passkey_save_failed");
      await getAdmin().from("webauthn_challenges").delete().eq("challenge", row.challenge);
      await markPasskeySet(identity.user.id);
      const { count } = await getAdmin()
        .from("webauthn_credentials")
        .select("id", { count: "exact", head: true })
        .eq("user_id", identity.user.id);
      // G35: pehla passkey bante hi 10 recovery codes (plain sirf yahin, ek baar; DB mein sirf hash)
      let recovery_codes: string[] | null = null;
      if ((count || 0) === 1) {
        const { data: codes } = await getAdmin().rpc("recovery_codes_regenerate", {
          _user: identity.user.id,
        });
        if (Array.isArray(codes)) recovery_codes = codes as string[];
      }
      res.json({ token: identity.token, ok: true, passkey_count: count || 0, recovery_codes });
    } catch (e: any) {
      return fail(res, 400, String(e?.message || "passkey_verify_failed"));
    }
  });

  authRouter.post("/passkey/options", async (req, res) => {
    try {
      const rp = rpFromRequest(req.headers.origin, APP_URL);
      const email = anexomailIdentity(req.body?.email);
      if (!email) return fail(res, 400, "Email is required.");
      const { data: uid } = await getAdmin().rpc("auth_user_id_by_email", { _email: email });
      const userId = uid as string | null;
      const challenge = randomChallenge();
      await getAdmin().from("webauthn_challenges").insert({
        user_id: userId || null,
        email,
        kind: "authenticate",
        challenge,
        rp_id: rp.rpId,
        origin: rp.origin,
        expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
      });
      let allowCredentials: { type: string; id: string; transports: string[] }[] = [];
      if (userId) {
        const { data: creds } = await getAdmin()
          .from("webauthn_credentials")
          .select("credential_id,transports")
          .eq("user_id", userId);
        allowCredentials = (creds || []).map((c) => ({
          type: "public-key",
          id: c.credential_id,
          transports: c.transports || ["internal"],
        }));
      }
      if (!allowCredentials.length) {
        return fail(res, 400, "No passkey on this account. Use your password.");
      }
      res.json({
        publicKey: {
          challenge,
          rpId: rp.rpId,
          timeout: 60000,
          userVerification: "required",
          allowCredentials,
        },
      });
    } catch (e: any) {
      return fail(res, 400, String(e?.message || "passkey_options_failed"));
    }
  });

  authRouter.post("/passkey/verify", async (req, res) => {
    try {
      const rp = rpFromRequest(req.headers.origin, APP_URL);
      const cred = credentialPayload(req.body);
      const client = JSON.parse(b64urlToBuf(cred.clientDataJSON).toString("utf8")) as {
        challenge?: string;
      };
      const { data: ch } = await getAdmin()
        .from("webauthn_challenges")
        .select("*")
        .eq("kind", "authenticate")
        .eq("challenge", client.challenge || "")
        .maybeSingle();
      if (!ch || new Date(ch.expires_at).getTime() < Date.now()) {
        return fail(res, 400, "passkey_challenge_expired");
      }
      const { data: stored } = await getAdmin()
        .from("webauthn_credentials")
        .select("id,user_id,credential_id,public_key,sign_count")
        .eq("credential_id", cred.id)
        .maybeSingle();
      if (!stored) return fail(res, 400, "passkey_unknown");
      const { signCount } = verifyAssertion({
        clientDataJSON: cred.clientDataJSON,
        authenticatorData: cred.authenticatorData,
        signature: cred.signature,
        challenge: ch.challenge,
        origin: rp.origin,
        rpId: rp.rpId,
        publicKey: stored.public_key as PublicJwk,
        storedSignCount: Number(stored.sign_count || 0),
      });
      await getAdmin()
        .from("webauthn_credentials")
        .update({ sign_count: signCount, last_used_at: new Date().toISOString() })
        .eq("id", stored.id);
      await getAdmin().from("webauthn_challenges").delete().eq("id", ch.id);
      const { data: userData, error: userError } = await getAdmin().auth.admin.getUserById(stored.user_id);
      if (userError || !userData.user?.email) return fail(res, 400, "passkey_user_missing");
      const session = await sessionForEmail(getAdmin(), userData.user.email, req, sessionResult);
      res.json(session);
    } catch (e: any) {
      return fail(res, 400, String(e?.message || "passkey_verify_failed"));
    }
  });

  // G35: passkey status (gate + banners ke liye) — session ko bhari nahi karta
  authRouter.get("/passkey/status", async (req, res) => {
    const identity = await userFrom(req, res);
    if (!identity) return;
    // Founder 21 Oct 2026: 27 Oct deadline sirf REAL users ke liye. Test accounts (basic.test@, pro.test@, g38b-test@ ...) par
    // na banner na gate — ghalti se lock na hon. Asli users ka email "test@" par khatam nahi hota.
    if (/(^|[._-])test@/i.test(String((identity.user as any).email || ""))) {
      return res.json({ exempt: true, required: false, hard: false, count: 0, target: 0, codes_remaining: 1 });
    }
    const { data, error } = await getAdmin().rpc("passkey_status", { _user: identity.user.id });
    if (error) {
      // E43 SQL abhi nahi chala: gate nahi lagate (honest: "unknown"), kuch toota nahi
      return res.json({ unknown: true, required: false, hard: false, count: 0, target: 2, codes_remaining: 0 });
    }
    res.json(data);
  });

  // G35: recovery codes dobara banao (purane unused mit jate hain). Kam az kam ek passkey lazmi.
  authRouter.post("/recovery-codes/generate", async (req, res) => {
    const identity = await userFrom(req, res);
    if (!identity) return;
    const { count } = await getAdmin()
      .from("webauthn_credentials")
      .select("id", { count: "exact", head: true })
      .eq("user_id", identity.user.id);
    if (!count) return fail(res, 400, "passkey_required_first");
    const { data, error } = await getAdmin().rpc("recovery_codes_regenerate", { _user: identity.user.id });
    if (error || !Array.isArray(data)) return fail(res, 500, "recovery_codes_failed");
    res.json({ codes: data });
  });

  // G35: passkey/phone kho gaya + password bhi yaad nahi => email + ek recovery code => session (phir naya passkey lazmi)
  authRouter.post("/recovery-codes/redeem", async (req, res) => {
    try {
      const email = anexomailIdentity(String(req.body?.email || ""));
      const code = String(req.body?.code || "").slice(0, 40);
      if (!email || !code) return fail(res, 400, "invalid");
      const { data, error } = await getAdmin().rpc("recovery_code_redeem", { _email: email, _code: code });
      if (error) return fail(res, 500, "recovery_codes_unavailable");
      if (!data?.ok) return fail(res, data?.error === "too_many_attempts" ? 429 : 400, data?.error || "invalid");
      const session = await sessionForEmail(getAdmin(), email, req, sessionResult);
      res.json({ ...(session as object), codes_left: data.codes_left, must_add_passkey: true });
    } catch (e: any) {
      return fail(res, 400, String(e?.message || "recovery_failed"));
    }
  });

  authRouter.get("/passkey/list", async (req, res) => {
    const identity = await userFrom(req, res);
    if (!identity) return;
    const { data, error } = await getAdmin()
      .from("webauthn_credentials")
      .select("id,device_name,created_at,last_used_at")
      .eq("user_id", identity.user.id)
      .order("created_at", { ascending: false });
    if (error) return fail(res, 500, "passkey_list_failed");
    res.json(data || []);
  });

  authRouter.delete("/passkey/:id", async (req, res) => {
    const identity = await userFrom(req, res);
    if (!identity) return;
    const { error } = await getAdmin()
      .from("webauthn_credentials")
      .delete()
      .eq("id", req.params.id)
      .eq("user_id", identity.user.id);
    if (error) return fail(res, 500, "passkey_delete_failed");
    const { count } = await getAdmin()
      .from("webauthn_credentials")
      .select("id", { count: "exact", head: true })
      .eq("user_id", identity.user.id);
    if (!count) {
      await getAdmin()
        .from("trial_accounts")
        .update({ passkey_set: false, updated_at: new Date().toISOString() })
        .eq("user_id", identity.user.id);
    }
    res.json({ ok: true });
  });
}
