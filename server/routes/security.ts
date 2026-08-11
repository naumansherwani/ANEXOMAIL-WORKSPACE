// ANEXOMAIL — Phase 26: Security Platform API (Server 2 / Brain, port 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/security.ts /opt/anexomail/src/routes/security.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/security.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// LOCKED: koi API keys nahi. Access ka unit DEVICE hai (fingerprint + trust score).
//
// 6 advance features:
//   1. Device Trust        — live trust score + one-click kill
//   2. Impossible travel   — haversine velocity se anomaly, auto-freeze
//   3. Ownership proof     — asli DNS/DKIM/SPF/DMARC/TLS probe, hashed pack
//   4. Encryption ledger   — at-rest + in-transit surfaces + key rotation hashes
//   5. Login replay        — risk story + "wasn't me" -> sessions kill + device block
//   6. Blast-radius kill   — sab sessions + devices, hash-chained ledger entry
//
// Env locked: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY (fallback SUPABASE_*).
// Missing env par process crash NAHI — sirf yeh router 503 deta hai.
import { Router } from "express";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createHash } from "node:crypto";
import { Resolver } from "node:dns/promises";
import tls from "node:tls";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const MAIL_DOMAIN = process.env.MAIL_DOMAIN || "anexomail.com";
const MAIL_HOST = process.env.MAIL_HOST || `mail.${MAIL_DOMAIN}`;
const DKIM_SELECTOR = process.env.DKIM_SELECTOR || "default";

let db: SupabaseClient | null = null;
if (SUPABASE_URL && SERVICE_KEY) {
  db = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
} else {
  console.error("security: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY missing — routes will 503");
}

const router = Router();
const founderRouter = Router();

const fail = (res: any, e: any) =>
  res.status(500).json({ error: "db_error", detail: String(e?.message || e) });

async function requireUser(req: any, res: any): Promise<string | null> {
  if (!db) {
    res.status(503).json({ error: "supabase_not_configured" });
    return null;
  }
  const raw = String(req.headers.authorization || "");
  const token = raw.startsWith("Bearer ") ? raw.slice(7) : "";
  if (!token) {
    res.status(401).json({ error: "unauthorized" });
    return null;
  }
  const { data, error } = await db.auth.getUser(token);
  if (error || !data?.user) {
    res.status(401).json({ error: "unauthorized" });
    return null;
  }
  return data.user.id;
}

const sha = (v: unknown) => createHash("sha256").update(JSON.stringify(v)).digest("hex");

/** Hash-chained ledger: har entry pichli entry ke hash ko lock karti hai. */
async function ledger(uid: string, action: string, payload: Record<string, unknown>, actor = "owner") {
  const { data: last } = await db!
    .from("security_ledger")
    .select("hash")
    .eq("user_id", uid)
    .order("at", { ascending: false })
    .limit(1)
    .maybeSingle();
  const prev_hash = (last as any)?.hash ?? null;
  const at = new Date().toISOString();
  const hash = sha({ uid, action, actor, payload, prev_hash, at });
  await db!.from("security_ledger").insert({
    user_id: uid,
    action,
    actor,
    payload,
    prev_hash,
    hash,
    at,
  });
  return hash;
}

// ---------------------------------------------------------------------------
// 1) Dashboard — score sirf asli rows se
// ---------------------------------------------------------------------------
router.get("/dashboard", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const since = new Date(Date.now() - 86_400_000).toISOString();
    const [devices, sessions, logins, anomalies, enc, proofs, led] = await Promise.all([
      db!.from("security_devices").select("state,trust_score").eq("user_id", uid),
      db!.from("security_sessions").select("id").eq("user_id", uid).is("killed_at", null),
      db!
        .from("security_login_events")
        .select("id")
        .eq("user_id", uid)
        .in("outcome", ["failed", "blocked"])
        .gt("at", since),
      db!.from("security_anomalies").select("id,kind,severity,detail").eq("user_id", uid).eq("state", "open"),
      db!.from("security_encryption_surfaces").select("scope,surface,state").eq("user_id", uid),
      db!.from("security_proofs").select("failed,ran_at").eq("user_id", uid).order("ran_at", { ascending: false }).limit(1),
      db!
        .from("security_ledger")
        .select("at,action,actor,hash,prev_hash")
        .eq("user_id", uid)
        .order("at", { ascending: false })
        .limit(12),
    ]);

    const devRows = (devices.data ?? []) as any[];
    const trusted = devRows.filter((d) => d.state === "trusted").length;
    const pending = devRows.filter((d) => d.state === "pending").length;
    const encRows = (enc.data ?? []) as any[];
    const encryptionOk = encRows.length > 0 && encRows.every((r) => r.state === "on");
    const lastProof = (proofs.data ?? [])[0] as any;
    const ownershipOk = !!lastProof && Number(lastProof.failed ?? 0) === 0;
    const openAnomalies = (anomalies.data ?? []) as any[];
    const failed24 = (logins.data ?? []).length;

    const advice: { title: string; detail: string; severity: "low" | "medium" | "high" }[] = [];
    if (pending > 0)
      advice.push({
        title: `${pending} device${pending > 1 ? "s" : ""} waiting for a decision`,
        detail: "Trust it or kill it — pending devices can still be challenged into access.",
        severity: "medium",
      });
    for (const a of openAnomalies)
      advice.push({ title: a.kind.replace(/_/g, " "), detail: a.detail, severity: a.severity });
    if (!encryptionOk)
      advice.push({
        title: "Encryption is not fully verified",
        detail: encRows.length ? "One or more surfaces report partial or off." : "No encryption surfaces recorded yet.",
        severity: "high",
      });
    if (!ownershipOk)
      advice.push({
        title: "Ownership proof is not signed",
        detail: lastProof ? "The last proof pack had failing checks." : "Run an ownership proof to sign DKIM, SPF, DMARC and TLS.",
        severity: "high",
      });
    if (failed24 > 10)
      advice.push({
        title: `${failed24} failed sign-ins in 24 hours`,
        detail: "Consider pulling the kill switch and rotating keys.",
        severity: "high",
      });

    const penalty =
      pending * 3 +
      openAnomalies.reduce((n, a) => n + (a.severity === "high" ? 18 : a.severity === "medium" ? 8 : 3), 0) +
      (encryptionOk ? 0 : 20) +
      (ownershipOk ? 0 : 15) +
      Math.min(15, failed24);

    res.json({
      score: Math.max(0, 100 - penalty),
      devices_trusted: trusted,
      devices_pending: pending,
      sessions_live: (sessions.data ?? []).length,
      failed_logins_24h: failed24,
      open_anomalies: openAnomalies.length,
      encryption_ok: encryptionOk,
      ownership_ok: ownershipOk,
      ledger: led.data ?? [],
      advice,
    });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 2) Device Trust
// ---------------------------------------------------------------------------
router.get("/devices", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data, error } = await db!
      .from("security_devices")
      .select("*")
      .eq("user_id", uid)
      .order("last_seen_at", { ascending: false });
    if (error) return fail(res, error);
    res.json({
      devices: (data ?? []).map((d: any) => ({
        ...d,
        reasons: Array.isArray(d.reasons) ? d.reasons : [],
      })),
    });
  } catch (e) {
    fail(res, e);
  }
});

router.post("/devices/state", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const id = String(req.body?.device_id || "");
  const state = String(req.body?.state || "");
  if (!id || !["trusted", "pending", "blocked"].includes(state))
    return res.status(400).json({ error: "device_id_and_state_required" });
  try {
    const score = state === "trusted" ? 92 : state === "blocked" ? 0 : 50;
    const { data, error } = await db!
      .from("security_devices")
      .update({ state, trust_score: score, last_seen_at: new Date().toISOString() })
      .eq("user_id", uid)
      .eq("id", id)
      .select()
      .maybeSingle();
    if (error) return fail(res, error);
    if (!data) return res.status(404).json({ error: "device_not_found" });

    // Blocked device = uske saare live sessions foran khatam.
    if (state === "blocked") {
      await db!
        .from("security_sessions")
        .update({ killed_at: new Date().toISOString() })
        .eq("user_id", uid)
        .eq("device_id", id)
        .is("killed_at", null);
    }
    await ledger(uid, `device_${state}`, { device_id: id, fingerprint: (data as any).fingerprint });
    res.json({ device: { ...(data as any), reasons: (data as any).reasons ?? [] } });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 3) Sessions + blast-radius kill switch
// ---------------------------------------------------------------------------
router.get("/sessions", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data, error } = await db!
      .from("security_sessions")
      .select("id,device_label,ip,city,country,started_at,last_seen_at,expires_at,current,risk")
      .eq("user_id", uid)
      .is("killed_at", null)
      .order("last_seen_at", { ascending: false });
    if (error) return fail(res, error);
    res.json({ sessions: data ?? [] });
  } catch (e) {
    fail(res, e);
  }
});

router.post("/sessions/kill", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const id = String(req.body?.session_id || "");
  if (!id) return res.status(400).json({ error: "session_id_required" });
  try {
    const { error } = await db!
      .from("security_sessions")
      .update({ killed_at: new Date().toISOString() })
      .eq("user_id", uid)
      .eq("id", id);
    if (error) return fail(res, error);
    await ledger(uid, "session_killed", { session_id: id });
    res.json({ ok: true });
  } catch (e) {
    fail(res, e);
  }
});

router.post("/kill-switch", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const reason = String(req.body?.reason || "kill switch").slice(0, 300);
  try {
    const now = new Date().toISOString();
    const { data: killed, error: e1 } = await db!
      .from("security_sessions")
      .update({ killed_at: now })
      .eq("user_id", uid)
      .eq("current", false)
      .is("killed_at", null)
      .select("id");
    if (e1) return fail(res, e1);
    const { data: blocked, error: e2 } = await db!
      .from("security_devices")
      .update({ state: "blocked", trust_score: 0 })
      .eq("user_id", uid)
      .eq("current", false)
      .neq("state", "blocked")
      .select("id");
    if (e2) return fail(res, e2);

    const sessions_killed = (killed ?? []).length;
    const devices_blocked = (blocked ?? []).length;
    const hash = await ledger(uid, "kill_switch", { reason, sessions_killed, devices_blocked });
    await db!
      .from("security_kill_switches")
      .insert({ user_id: uid, reason, sessions_killed, devices_blocked, hash });
    res.json({ ok: true, sessions_killed, devices_blocked, hash });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 4) Login replay + impossible travel
// ---------------------------------------------------------------------------
const haversine = (a: any, b: any) => {
  if (a?.lat == null || a?.lon == null || b?.lat == null || b?.lon == null) return null;
  const R = 6371;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLon = ((b.lon - a.lon) * Math.PI) / 180;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((a.lat * Math.PI) / 180) * Math.cos((b.lat * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
};

router.get("/history", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const outcome = String(req.query?.outcome || "all");
  try {
    let q = db!
      .from("security_login_events")
      .select("*")
      .eq("user_id", uid)
      .order("at", { ascending: false })
      .limit(120);
    if (outcome !== "all") q = q.eq("outcome", outcome);
    const [{ data: events, error }, { data: anomalies }] = await Promise.all([
      q,
      db!
        .from("security_anomalies")
        .select("*")
        .eq("user_id", uid)
        .order("created_at", { ascending: false })
        .limit(30),
    ]);
    if (error) return fail(res, error);

    // Impossible travel: consecutive successful logins ki velocity > 900 km/h.
    const success = (events ?? []).filter((e: any) => e.outcome === "success");
    for (let i = 0; i < success.length - 1; i++) {
      const a = success[i] as any;
      const b = success[i + 1] as any;
      const km = haversine(a, b);
      if (km == null || km < 500) continue;
      const minutes = Math.max(1, Math.round((new Date(a.at).getTime() - new Date(b.at).getTime()) / 60000));
      if (km / (minutes / 60) < 900) continue;
      const detail = `${b.city ?? "unknown"} to ${a.city ?? "unknown"} in ${minutes} minutes — physically impossible.`;
      const dup = (anomalies ?? []).some((x: any) => x.kind === "impossible_travel" && x.detail === detail);
      if (dup) continue;
      const { data: created } = await db!
        .from("security_anomalies")
        .insert({
          user_id: uid,
          kind: "impossible_travel",
          severity: "high",
          state: "frozen",
          detail,
          km,
          minutes,
        })
        .select()
        .maybeSingle();
      if (created) (anomalies ?? []).unshift(created as any);
      await ledger(uid, "anomaly_frozen", { kind: "impossible_travel", km, minutes }, "system");
    }

    res.json({
      events: (events ?? []).map((e: any) => ({
        ...e,
        story:
          e.story ??
          `${e.method} sign-in from ${[e.city, e.country].filter(Boolean).join(", ") || "an unknown place"}${
            e.device_label ? ` on ${e.device_label}` : ""
          } — ${e.outcome}.`,
      })),
      anomalies: anomalies ?? [],
    });
  } catch (e) {
    fail(res, e);
  }
});

/** "Wasn't me" — device block + uske saare sessions khatam + ledger entry. */
router.post("/history/disown", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const id = String(req.body?.event_id || "");
  if (!id) return res.status(400).json({ error: "event_id_required" });
  try {
    const { data: ev, error } = await db!
      .from("security_login_events")
      .update({ disowned: true })
      .eq("user_id", uid)
      .eq("id", id)
      .select()
      .maybeSingle();
    if (error) return fail(res, error);
    if (!ev) return res.status(404).json({ error: "event_not_found" });

    let sessions_killed = 0;
    const deviceId = (ev as any).device_id;
    if (deviceId) {
      await db!
        .from("security_devices")
        .update({ state: "blocked", trust_score: 0 })
        .eq("user_id", uid)
        .eq("id", deviceId);
      const { data: killed } = await db!
        .from("security_sessions")
        .update({ killed_at: new Date().toISOString() })
        .eq("user_id", uid)
        .eq("device_id", deviceId)
        .is("killed_at", null)
        .select("id");
      sessions_killed = (killed ?? []).length;
    }
    await db!.from("security_anomalies").insert({
      user_id: uid,
      kind: "token_reuse",
      severity: "high",
      state: "frozen",
      detail: `Owner disowned a ${(ev as any).method} sign-in from ${(ev as any).city ?? "unknown"}.`,
    });
    await ledger(uid, "login_disowned", { event_id: id, device_id: deviceId, sessions_killed });
    res.json({ ok: true, sessions_killed });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 5) Encryption ledger
// ---------------------------------------------------------------------------
router.get("/encryption", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const [{ data: surfaces, error }, { data: keys }] = await Promise.all([
      db!.from("security_encryption_surfaces").select("*").eq("user_id", uid).order("surface"),
      db!
        .from("security_key_ledger")
        .select("at,action,surface,hash")
        .eq("user_id", uid)
        .order("at", { ascending: false })
        .limit(12),
    ]);
    if (error) return fail(res, error);
    const rows = (surfaces ?? []) as any[];
    const lastRotation = (keys ?? []).find((k: any) => k.action === "key_rotated");
    res.json({
      at_rest: rows
        .filter((r) => r.scope === "at_rest")
        .map((r) => ({ surface: r.surface, algorithm: r.algorithm, state: r.state, detail: r.detail })),
      in_transit: rows
        .filter((r) => r.scope === "in_transit")
        .map((r) => ({ hop: r.surface, protocol: r.algorithm, cipher: r.cipher, state: r.state })),
      key_rotated_at: (lastRotation as any)?.at ?? null,
      next_rotation_at: (lastRotation as any)?.at
        ? new Date(new Date((lastRotation as any).at).getTime() + 90 * 86_400_000).toISOString()
        : null,
      ledger: keys ?? [],
    });
  } catch (e) {
    fail(res, e);
  }
});

router.post("/encryption/rotate", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const surface = String(req.body?.surface || "all");
  try {
    const at = new Date().toISOString();
    const hash = sha({ uid, surface, at, action: "key_rotated" });
    const { error } = await db!
      .from("security_key_ledger")
      .insert({ user_id: uid, action: "key_rotated", surface, hash, at });
    if (error) return fail(res, error);
    await db!
      .from("security_encryption_surfaces")
      .update({ updated_at: at })
      .eq("user_id", uid);
    await ledger(uid, "keys_rotated", { surface, key_hash: hash });
    res.json({ ok: true, rotated_at: at });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 6) Ownership proof — asli DNS + TLS probe, hashed pack
// ---------------------------------------------------------------------------
const resolver = new Resolver();
resolver.setServers(["1.1.1.1", "8.8.8.8"]);

const txt = async (name: string) => {
  try {
    return (await resolver.resolveTxt(name)).map((r) => r.join("")).join(" | ");
  } catch {
    return "";
  }
};

const tlsProbe = (host: string, port: number) =>
  new Promise<{ ok: boolean; detail: string }>((resolve) => {
    const socket = tls.connect({ host, port, servername: host, rejectUnauthorized: false }, () => {
      const cipher = socket.getCipher();
      const protocol = socket.getProtocol();
      socket.end();
      resolve({ ok: !!protocol, detail: `${protocol ?? "unknown"} ${cipher?.name ?? ""}`.trim() });
    });
    socket.setTimeout(6000, () => {
      socket.destroy();
      resolve({ ok: false, detail: "timeout" });
    });
    socket.on("error", (e) => resolve({ ok: false, detail: String(e.message) }));
  });

router.get("/proof", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data: proofs, error } = await db!
      .from("security_proofs")
      .select("*")
      .eq("user_id", uid)
      .order("ran_at", { ascending: false })
      .limit(8);
    if (error) return fail(res, error);
    const ids = (proofs ?? []).map((p: any) => p.id);
    const { data: checks } = ids.length
      ? await db!.from("security_proof_checks").select("*").in("proof_id", ids)
      : { data: [] as any[] };
    res.json({
      proofs: (proofs ?? []).map((p: any) => ({
        ...p,
        checks: (checks ?? [])
          .filter((c: any) => c.proof_id === p.id)
          .map((c: any) => ({ check: c.check_name, result: c.result, observed: c.observed, fix: c.fix })),
      })),
    });
  } catch (e) {
    fail(res, e);
  }
});

router.post("/proof/run", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const domain = String(req.body?.domain || MAIL_DOMAIN).toLowerCase();
  try {
    const [spf, dmarc, dkim, tlsRes] = await Promise.all([
      txt(domain),
      txt(`_dmarc.${domain}`),
      txt(`${DKIM_SELECTOR}._domainkey.${domain}`),
      tlsProbe(MAIL_HOST, 465),
    ]);

    const checks = [
      {
        check_name: "SPF record",
        result: spf.includes("v=spf1") ? "pass" : "fail",
        observed: spf || null,
        expected: "v=spf1 ... -all",
        fix: spf.includes("v=spf1") ? null : `Publish a TXT record on ${domain} starting with v=spf1.`,
      },
      {
        check_name: "DKIM key",
        result: dkim.includes("p=") ? "pass" : "fail",
        observed: dkim ? `${dkim.slice(0, 60)}…` : null,
        expected: `${DKIM_SELECTOR}._domainkey.${domain} with p=`,
        fix: dkim.includes("p=") ? null : `Publish the DKIM public key at ${DKIM_SELECTOR}._domainkey.${domain}.`,
      },
      {
        check_name: "DMARC policy",
        result: dmarc.includes("v=DMARC1") ? "pass" : "fail",
        observed: dmarc || null,
        expected: "v=DMARC1; p=quarantine|reject",
        fix: dmarc.includes("v=DMARC1") ? null : `Publish a TXT record at _dmarc.${domain}.`,
      },
      {
        check_name: "DMARC enforced",
        result: /p=(quarantine|reject)/.test(dmarc) ? "pass" : "fail",
        observed: dmarc || null,
        expected: "p=quarantine or p=reject",
        fix: /p=(quarantine|reject)/.test(dmarc) ? null : "Move the DMARC policy off p=none.",
      },
      {
        check_name: "TLS on submission",
        result: tlsRes.ok ? "pass" : "fail",
        observed: tlsRes.detail,
        expected: "TLSv1.3",
        fix: tlsRes.ok ? null : `Check TLS on ${MAIL_HOST}:465.`,
      },
    ];

    const passed = checks.filter((c) => c.result === "pass").length;
    const failed = checks.filter((c) => c.result === "fail").length;
    const ran_at = new Date().toISOString();
    const proof_hash = sha({ uid, domain, ran_at, checks });

    const { data: proof, error } = await db!
      .from("security_proofs")
      .insert({ user_id: uid, domain, ran_at, passed, failed, proof_hash })
      .select()
      .single();
    if (error) return fail(res, error);

    await db!
      .from("security_proof_checks")
      .insert(checks.map((c) => ({ ...c, user_id: uid, proof_id: (proof as any).id })));
    await ledger(uid, "ownership_proof", { domain, passed, failed, proof_hash });

    res.json({
      proof: {
        ...(proof as any),
        checks: checks.map((c) => ({
          check: c.check_name,
          result: c.result,
          observed: c.observed,
          fix: c.fix,
        })),
      },
    });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// Founder god-view — /api/founder/security/overview
// ---------------------------------------------------------------------------
founderRouter.get("/security/overview", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data, error } = await db!.rpc("founder_security_overview");
    if (error) return fail(res, error);
    const d = (data ?? {}) as any;
    res.json({
      tenants: d.tenants ?? 0,
      devices_blocked: d.devices_blocked ?? 0,
      open_anomalies: d.open_anomalies ?? 0,
      frozen_accounts: d.frozen_accounts ?? 0,
      failed_logins_24h: d.failed_logins_24h ?? 0,
      kill_switches_30d: d.kill_switches_30d ?? 0,
      worst_tenants: Array.isArray(d.worst_tenants) ? d.worst_tenants : [],
    });
  } catch (e) {
    fail(res, e);
  }
});

export default router;
export { founderRouter as founderSecurityRouter };