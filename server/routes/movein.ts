// ============================================================================
// ANEXOMAIL — Phase 37: MOVE-IN OPERATIONS & REVENUE COCKPIT (Server 2, 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/movein.ts /opt/anexomail/src/routes/movein.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/movein.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// Falsafa: yahan koi business logic HARD-CODED nahi. Har faisla Supabase #4
// ki RPC karti hai (state machine, payment gates, capacity, health, evidence).
// Yeh router sirf transport + auth hai.
//
// Routes:
//   POST /api/public/movein/request        public — lead -> real deal (movein_open_deal)
//   GET  /api/public/movein/capacity       public — is month kitne slot bache
//   GET  /api/movein/deal                  auth   — customer portal (movein_customer_view)
//   GET  /api/movein/deal/:id              auth   — same, explicit deal
//   GET  /api/founder/movein/cockpit       auth   — movein_cockpit()
//   GET  /api/founder/movein/deal/:id      auth   — movein_evidence_bundle()
//   POST /api/founder/movein/transition    auth   — movein_transition() (gates DB mein)
//   POST /api/founder/movein/schedule      auth   — movein_book_slot() + window
//   POST /api/founder/movein/mailbox       auth   — per-mailbox ledger upsert
//   POST /api/founder/movein/dns           auth   — DNS proof check record
//   POST /api/founder/movein/runbook       auth   — runbook step result
//   POST /api/founder/movein/exception     auth   — raise / resolve exception
//   POST /api/founder/movein/rollback      auth   — rollback point record
//   POST /api/founder/movein/invoice       auth   — leg invoice (Polar intent link)
//   POST /api/public/movein/sweep          cron   — payment/health/capacity sweep
//
// Env: SUPABASE4_URL, SUPABASE4_SERVICE_ROLE_KEY, CRON_SECRET
import { Router } from "express";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const CRON_SECRET = process.env.CRON_SECRET || "";

let db: SupabaseClient | null = null;
if (SUPABASE_URL && SERVICE_KEY) {
  db = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
} else {
  console.error("movein: SUPABASE4_* env missing — routes will 503");
}

const publicRouter = Router();
const authRouter = Router();
const founderRouter = Router();

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

function fail(res: any, error: any, code = 500) {
  return res.status(code).json({ error: "rpc_failed", detail: String(error?.message || error) });
}

// ---------------------------------------------------------------------------
// PUBLIC — move-in request (yehi "instant money machine" ka darwaza hai)
// ---------------------------------------------------------------------------
publicRouter.post("/movein/request", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const { company, email, mailboxes, domain, provider, contact_name, month } = req.body || {};
  if (!company || !email) return res.status(400).json({ error: "company_and_email_required" });

  const { data, error } = await db.rpc("movein_open_deal", {
    p_company: String(company).slice(0, 200),
    p_email: String(email).slice(0, 200),
    p_mailboxes: Number(mailboxes) || 1,
    p_domain: domain ? String(domain).slice(0, 200) : null,
    p_provider: provider ? String(provider).slice(0, 40) : "other",
    p_contact: contact_name ? String(contact_name).slice(0, 200) : null,
    p_user: null,
    p_month: month ? String(month) : null,
  });
  if (error) return fail(res, error);
  return res.json(data);
});

publicRouter.get("/movein/capacity", async (_req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const { data, error } = await db
    .from("movein_capacity_state")
    .select("*")
    .order("month", { ascending: true })
    .limit(4);
  if (error) return fail(res, error);
  return res.json({ months: data ?? [] });
});

// cron sweep: payments sync + health recompute (paid kabhi miss na ho)
publicRouter.post("/movein/sweep", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  if (!CRON_SECRET || String(req.headers["x-anexomail-cron"] || "") !== CRON_SECRET) {
    return res.status(401).json({ error: "unauthorized" });
  }
  const { data: deals, error } = await db
    .from("movein_deals")
    .select("id")
    .not("state", "in", '("CLOSED","CANCELLED")')
    .limit(200);
  if (error) return fail(res, error);

  let synced = 0;
  for (const d of deals ?? []) {
    await db.rpc("movein_sync_payments", { p_deal: d.id });
    await db.rpc("movein_health", { p_deal: d.id });
    synced += 1;
  }
  return res.json({ ok: true, deals: synced, at: new Date().toISOString() });
});

// ---------------------------------------------------------------------------
// CUSTOMER PORTAL — apna move-in
// ---------------------------------------------------------------------------
async function customerView(req: any, res: any, dealId?: string) {
  const userId = await requireUser(req, res);
  if (!userId || !db) return;
  let id = dealId;
  if (!id) {
    const { data } = await db
      .from("movein_deals")
      .select("id")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    id = data?.id;
  } else {
    const { data } = await db
      .from("movein_deals")
      .select("id")
      .eq("id", id)
      .or(`user_id.eq.${userId},owner_id.eq.${userId}`)
      .maybeSingle();
    if (!data) return res.status(404).json({ error: "not_found" });
  }
  if (!id) return res.json({ deal: null });
  const { data, error } = await db.rpc("movein_customer_view", { p_deal: id });
  if (error) return fail(res, error);
  return res.json({ deal: data });
}

authRouter.get("/deal", (req, res) => customerView(req, res));
authRouter.get("/deal/:id", (req, res) => customerView(req, res, req.params.id));

// ---------------------------------------------------------------------------
// FOUNDER COCKPIT
// ---------------------------------------------------------------------------
founderRouter.get("/movein/cockpit", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId || !db) return;
  const { data, error } = await db.rpc("movein_cockpit");
  if (error) return fail(res, error);
  return res.json(data);
});

founderRouter.get("/movein/deal/:id", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId || !db) return;
  const { data, error } = await db.rpc("movein_evidence_bundle", { p_deal: req.params.id });
  if (error) return fail(res, error);
  return res.json({ deal: data });
});

founderRouter.post("/movein/transition", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId || !db) return;
  const { deal_id, to, reason, evidence } = req.body || {};
  if (!deal_id || !to) return res.status(400).json({ error: "deal_id_and_to_required" });
  const { data, error } = await db.rpc("movein_transition", {
    p_deal: deal_id,
    p_to: String(to),
    p_actor: "founder",
    p_reason: reason ?? null,
    p_evidence: evidence ?? null,
    p_actor_id: userId,
  });
  if (error) return fail(res, error);
  return res.status((data as any)?.ok === false ? 409 : 200).json(data);
});

founderRouter.post("/movein/schedule", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId || !db) return;
  const { deal_id, month, window_start, window_end } = req.body || {};
  if (!deal_id || !month) return res.status(400).json({ error: "deal_id_and_month_required" });
  const { data, error } = await db.rpc("movein_book_slot", { p_deal: deal_id, p_month: month });
  if (error) return fail(res, error);
  if (window_start || window_end) {
    await db
      .from("movein_deals")
      .update({
        cutover_window_start: window_start ?? null,
        cutover_window_end: window_end ?? null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", deal_id);
  }
  return res.json(data);
});

founderRouter.post("/movein/arm", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId || !db) return;
  const { deal_id } = req.body || {};
  if (!deal_id) return res.status(400).json({ error: "deal_id_required" });
  const { data, error } = await db.rpc("movein_arm_cutover", { p_deal: deal_id, p_actor: "founder" });
  if (error) return fail(res, error);
  return res.status((data as any)?.ok === false ? 409 : 200).json(data);
});

founderRouter.post("/movein/mailbox", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId || !db) return;
  const b = req.body || {};
  if (!b.deal_id || !b.address) return res.status(400).json({ error: "deal_id_and_address_required" });
  const row = {
    deal_id: b.deal_id,
    address: String(b.address).toLowerCase(),
    destination: b.destination ?? null,
    source_provider: b.source_provider ?? null,
    size_mb: b.size_mb ?? null,
    messages_source: Number(b.messages_source) || 0,
    messages_copied: Number(b.messages_copied) || 0,
    messages_verified: Number(b.messages_verified) || 0,
    folders_found: Number(b.folders_found) || 0,
    contacts_count: Number(b.contacts_count) || 0,
    calendar_events: Number(b.calendar_events) || 0,
    aliases_count: Number(b.aliases_count) || 0,
    signatures_count: Number(b.signatures_count) || 0,
    source_credentials: b.source_credentials ?? "PENDING",
    destination_status: b.destination_status ?? "PENDING",
    result: b.result ?? "PENDING",
    exceptions: Number(b.exceptions) || 0,
    operator: b.operator ?? "founder",
    verified_at: b.result === "VERIFIED" ? new Date().toISOString() : null,
    last_checked_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
  const { data, error } = await db
    .from("movein_mailboxes")
    .upsert(row, { onConflict: "deal_id,address" })
    .select()
    .maybeSingle();
  if (error) return fail(res, error);
  await db.rpc("movein_health", { p_deal: b.deal_id });
  return res.json({ mailbox: data });
});

founderRouter.post("/movein/dns", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId || !db) return;
  const b = req.body || {};
  if (!b.deal_id || !b.record || !b.domain) {
    return res.status(400).json({ error: "deal_id_domain_record_required" });
  }
  const { data, error } = await db
    .from("movein_dns_checks")
    .insert({
      deal_id: b.deal_id,
      phase: b.phase === "POST" ? "POST" : "PRE",
      domain: String(b.domain).toLowerCase(),
      record: String(b.record).toUpperCase(),
      hostname: b.hostname ?? null,
      resolver: b.resolver ?? null,
      expected: b.expected ?? null,
      observed: b.observed ?? null,
      result: b.result ?? "PENDING",
      reason: b.reason ?? null,
    })
    .select()
    .maybeSingle();
  if (error) return fail(res, error);
  await db.rpc("movein_health", { p_deal: b.deal_id });
  return res.json({ check: data });
});

founderRouter.post("/movein/runbook", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId || !db) return;
  const b = req.body || {};
  if (!b.deal_id || !b.step_key) return res.status(400).json({ error: "deal_id_and_step_key_required" });
  const { error } = await db
    .from("movein_runbook")
    .update({
      result: b.result ?? "PENDING",
      evidence: b.evidence ?? null,
      operator: b.operator ?? "founder",
      completed_at: b.result === "VERIFIED" ? new Date().toISOString() : null,
    })
    .eq("deal_id", b.deal_id)
    .eq("step_key", b.step_key);
  if (error) return fail(res, error);
  const { data: ready } = await db.rpc("movein_cutover_ready", { p_deal: b.deal_id });
  await db.rpc("movein_health", { p_deal: b.deal_id });
  return res.json({ ok: true, cutover_ready: ready === true });
});

founderRouter.post("/movein/exception", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId || !db) return;
  const b = req.body || {};
  if (b.resolve_id) {
    const { error } = await db
      .from("movein_exceptions")
      .update({ resolved_at: new Date().toISOString(), resolved_by: "founder" })
      .eq("id", b.resolve_id);
    if (error) return fail(res, error);
    return res.json({ ok: true, resolved: b.resolve_id });
  }
  if (!b.deal_id || !b.reason) return res.status(400).json({ error: "deal_id_and_reason_required" });
  const { data, error } = await db
    .from("movein_exceptions")
    .insert({
      deal_id: b.deal_id,
      scope: b.scope ?? "general",
      ref: b.ref ?? null,
      severity: b.severity ?? "WARNING",
      reason: String(b.reason).slice(0, 500),
      required_action: b.required_action ?? null,
      blocks_cutover: !!b.blocks_cutover,
    })
    .select()
    .maybeSingle();
  if (error) return fail(res, error);
  return res.json({ exception: data });
});

founderRouter.post("/movein/rollback", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId || !db) return;
  const b = req.body || {};
  if (!b.deal_id) return res.status(400).json({ error: "deal_id_required" });
  if (b.use_id) {
    const { error } = await db
      .from("movein_rollback_points")
      .update({ available: false, used_at: new Date().toISOString() })
      .eq("id", b.use_id);
    if (error) return fail(res, error);
    await db.from("movein_audit").insert({
      deal_id: b.deal_id,
      actor: "founder",
      action: "rollback_used",
      reason: b.reason ?? "rollback executed",
    });
    return res.json({ ok: true, used: b.use_id });
  }
  const { data, error } = await db
    .from("movein_rollback_points")
    .insert({
      deal_id: b.deal_id,
      label: b.label ?? "pre-cutover",
      operator: "founder",
      source_state: b.source_state ?? {},
      destination_state: b.destination_state ?? {},
      dns_state: b.dns_state ?? {},
      verification_state: b.verification_state ?? {},
    })
    .select()
    .maybeSingle();
  if (error) return fail(res, error);
  await db.from("movein_audit").insert({
    deal_id: b.deal_id,
    actor: "founder",
    action: "rollback_point_recorded",
    reason: b.label ?? "pre-cutover",
  });
  return res.json({ rollback: data });
});

// leg invoice — Phase 36 intent se link (paisa truth wahan hai)
founderRouter.post("/movein/invoice", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId || !db) return;
  const { deal_id, leg, intent_id, due_at } = req.body || {};
  if (!deal_id || !leg) return res.status(400).json({ error: "deal_id_and_leg_required" });
  if (intent_id) {
    const { error } = await db.rpc("movein_attach_intent", {
      p_deal: deal_id,
      p_leg: String(leg),
      p_intent: intent_id,
    });
    if (error) return fail(res, error);
  }
  if (due_at) {
    await db
      .from("movein_payments")
      .update({ due_at, state: "invoiced", invoiced_at: new Date().toISOString() })
      .eq("deal_id", deal_id)
      .eq("leg", String(leg));
  }
  await db.rpc("movein_sync_payments", { p_deal: deal_id });
  const { data } = await db.from("movein_payments").select("*").eq("deal_id", deal_id);
  return res.json({ payments: data ?? [] });
});

export { publicRouter as moveinPublicRouter, authRouter as moveinRouter, founderRouter as founderMoveinRouter };
export default authRouter;
