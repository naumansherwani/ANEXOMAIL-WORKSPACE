// ANEXOMAIL — Phase 32: TRIAL LIFECYCLE API (Server 2 / Brain, port 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/trial.ts /opt/anexomail/src/routes/trial.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/trial.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// FOUNDER LOCK:
//   1. Truth Supabase mein — yeh file sirf public.account_state() / trial_* RPC bulati hai
//   2. Koi frontend claim trust nahi (hours_left, state, can_social_login sab DB se)
//   3. AI trial mein HARD ZERO — yahan koi credit grant nahi
//   4. Recovery path hamesha khula — expired user bhi account/billing/recovery dekh sakta hai
//   5. Warnings + lifecycle events idempotent (DB unique index)
//
// Routes (mount: app.use("/api/trial", trialRouter); app.use("/api/public", trialCronRouter))
//   GET  /api/trial/state                  auth   — authoritative account state
//   GET  /api/trial/address?handle=x       public — availability (reserved list + ci unique)
//   POST /api/trial/start                  auth   — {provider} 48h timer + signup event
//   POST /api/trial/claim                  auth   — {handle} mandatory @anexomail.com claim
//   POST /api/trial/security               auth   — {passkey?, recovery_kind?, recovery_hint?}
//   POST /api/trial/subscribe              auth   — {plan, payment_ref} (payment verify = Polar TODO)
//   GET  /api/trial/events                 auth   — immutable audit trail
//   GET  /api/trial/mail-holds             auth   — frozen period mail (never discarded)
//   POST /api/public/trial/sweep           cron   — x-cron-secret: TRIAL_CRON_SECRET
import { Router } from "express";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const CRON_SECRET = process.env.TRIAL_CRON_SECRET || "";

let db: SupabaseClient | null = null;
if (SUPABASE_URL && SERVICE_KEY) {
  db = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
} else {
  console.error("trial: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY missing — routes will 503");
}

const router = Router();
const cronRouter = Router();

const fail = (res: any, e: any) =>
  res.status(500).json({ error: "db_error", detail: String(e?.message || e) });

async function requireUser(req: any, res: any): Promise<{ id: string; email: string } | null> {
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
  return { id: data.user.id, email: data.user.email || "" };
}

async function state(userId: string) {
  const { data, error } = await db!.rpc("account_state", { _user_id: userId });
  if (error) throw error;
  return data;
}

// ── authoritative state ─────────────────────────────────────────
router.get("/state", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  try {
    res.json(await state(user.id));
  } catch (e) {
    fail(res, e);
  }
});

// ── address availability (public: signup ke waqt chahiye) ───────
router.get("/address", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const handle = String(req.query['handle'] || "").trim().toLowerCase();
  if (!/^[a-z0-9]([a-z0-9.-]{1,28})[a-z0-9]$/.test(handle)) {
    return res.json({ handle, available: false, reason: "invalid_handle" });
  }
  try {
    const reserved = await db
      .from("reserved_handles")
      .select("handle")
      .eq("handle", handle)
      .maybeSingle();
    if (reserved.data) return res.json({ handle, available: false, reason: "reserved_handle" });

    const taken = await db
      .from("trial_accounts")
      .select("user_id,status")
      .eq("anexomail_handle", handle)
      .neq("status", "released")
      .maybeSingle();
    if (taken.data) return res.json({ handle, available: false, reason: "taken" });

    res.json({ handle, available: true, address: `${handle}@anexomail.com` });
  } catch (e) {
    fail(res, e);
  }
});

// ── 48h timer start ─────────────────────────────────────────────
router.post("/start", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  const provider = String(req.body?.provider || "email");
  try {
    const { data, error } = await db!.rpc("trial_start", {
      _user_id: user.id,
      _social_email: user.email,
      _provider: provider,
    });
    if (error) throw error;
    res.json(data);
  } catch (e) {
    fail(res, e);
  }
});

// ── mandatory claim ─────────────────────────────────────────────
router.post("/claim", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  const handle = String(req.body?.handle || "").trim().toLowerCase();
  try {
    const { data, error } = await db!.rpc("trial_claim_address", {
      _user_id: user.id,
      _handle: handle,
    });
    if (error) throw error;
    if (data && data.ok === false) return res.status(409).json(data);
    res.json(data);
  } catch (e) {
    fail(res, e);
  }
});

// ── passkey + recovery (recovery MANDATORY before 48h) ──────────
router.post("/security", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  const passkey = Boolean(req.body?.passkey);
  const kind = req.body?.recovery_kind ? String(req.body.recovery_kind) : null;
  const hint = req.body?.recovery_hint ? String(req.body.recovery_hint).slice(0, 120) : null;
  if (!passkey && !kind) return res.status(400).json({ error: "nothing_to_set" });
  try {
    const { data, error } = await db!.rpc("trial_set_security", {
      _user_id: user.id,
      _passkey: passkey,
      _recovery_kind: kind,
      _recovery_hint: hint,
    });
    if (error) throw error;
    res.json(data);
  } catch (e) {
    fail(res, e);
  }
});

// ── conversion: payment green -> active, seedha dashboard ───────
router.post("/subscribe", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  const plan = String(req.body?.plan || "");
  const paymentRef = String(req.body?.payment_ref || "");
  // Paid grant sirf verified payment se. Polar webhook wiring = TODO (product IDs pending).
  if (!paymentRef) return res.status(402).json({ error: "payment_ref_required" });
  try {
    const { data, error } = await db!.rpc("trial_subscribe", {
      _user_id: user.id,
      _plan: plan,
      _payment_ref: paymentRef,
    });
    if (error) throw error;
    if (data && data.ok === false) return res.status(400).json(data);
    res.json(data);
  } catch (e) {
    fail(res, e);
  }
});

// ── audit trail (expired/frozen user bhi dekh sakta hai) ───────
router.get("/events", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  try {
    const { data, error } = await db!
      .from("trial_events")
      .select("id,event_type,detail,created_at")
      .eq("user_id", user.id)
      .order("created_at", { ascending: false })
      .limit(100);
    if (error) throw error;
    res.json({ events: data ?? [] });
  } catch (e) {
    fail(res, e);
  }
});

// ── frozen period mail: held/rejected, kabhi silently discard nahi ──
router.get("/mail-holds", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  try {
    const { data, error } = await db!
      .from("trial_mail_holds")
      .select("id,from_address,subject,disposition,reason,received_at,released_at")
      .eq("user_id", user.id)
      .order("received_at", { ascending: false })
      .limit(200);
    if (error) throw error;
    res.json({ holds: data ?? [] });
  } catch (e) {
    fail(res, e);
  }
});

// ── hourly sweep (idempotent) ──────────────────────────────────
cronRouter.post("/trial/sweep", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  if (!CRON_SECRET || req.headers['x-cron-secret'] !== CRON_SECRET) {
    return res.status(401).json({ error: "unauthorized" });
  }
  try {
    const { data, error } = await db.rpc("trial_sweep");
    if (error) throw error;
    res.json(data);
  } catch (e) {
    fail(res, e);
  }
});

export default router;
export { router as trialRouter, cronRouter as trialCronRouter };
