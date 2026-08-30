// ANEXOMAIL — Phase 31: AI CREDIT ENGINE API (Server 2 / Brain, port 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/ai-credits.ts /opt/anexomail/src/routes/ai-credits.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/ai-credits.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// FOUNDER LOCK:
//   1. Supabase #4 = source of truth
//   2. Ledger immutable — sirf RPC likhta hai (ai_credits_reserve/settle/release/topup/complimentary)
//   3. Frontend sirf display + approval — koi credit math frontend pe nahi
//   4. Provider cost customer charge se ALAG (margin backend pe)
//
// Routes (mount: app.use("/api/ai/credits", aiCreditsRouter) + app.use("/api/founder", founderAiCreditsRouter)):
//   GET  /api/ai/credits/products          public — locked plans + visible top-ups
//   GET  /api/ai/credits/wallet            auth  — 4 buckets + total + cycle
//   GET  /api/ai/credits/ledger?limit=50   auth  — immutable history
//   GET  /api/ai/credits/actions?limit=50  auth  — pre-flight -> settle receipts
//   POST /api/ai/credits/estimate          auth  — { action_type, model?, input_tokens?, output_tokens? }
//   POST /api/ai/credits/reserve           auth  — { action_id, credits, idempotency_key }
//   POST /api/ai/credits/settle            auth  — { action_id, actual_credits, model?, provider_cost?, idempotency_key? }
//   POST /api/ai/credits/release           auth  — { action_id, reason? }
//   POST /api/ai/credits/complimentary     auth  — { day: 1|2 }
//   POST /api/ai/credits/topup             auth  — { product_id, idempotency_key, payment_ref }
//                                          NOTE: paid grant sirf verified payment se (Polar webhook TODO)
//   GET  /api/founder/ai/credits/overview  auth  — founder view: wallets, spend, provider cost, margin
import { Router } from "express";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";

let db: SupabaseClient | null = null;
if (SUPABASE_URL && SERVICE_KEY) {
  db = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
} else {
  console.error("ai-credits: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY missing — routes will 503");
}

// ── credit model (backend-only math) ────────────────────────────
// 1 credit ~= 1 small unit of work. Bands per action type: [min, max].
const BANDS: Record<string, [number, number]> = {
  summary_short: [1, 2],
  quick_reply: [1, 2],
  email_normal: [2, 4],
  compose_400: [3, 5],
  email_long: [5, 10],
  thread_huge: [8, 20],
  studio_run: [5, 25],
  automation_large: [10, 50],
  knowledge_answer: [2, 6],
  translate: [1, 3],
};
const DEFAULT_BAND: [number, number] = [2, 6];

// token-aware refinement (still backend-only)
function estimate(actionType: string, inTok: number, outTok: number) {
  const [lo, hi] = BANDS[actionType] ?? DEFAULT_BAND;
  const tokenUnits = (inTok + outTok * 3) / 1000; // output costs more
  const min = Math.max(lo, Math.round((lo + tokenUnits) * 10) / 10);
  const max = Math.max(min, Math.min(hi * 4, Math.round((hi + tokenUnits * 2) * 10) / 10));
  return { min, max };
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

/** Wallet ka ghar: workspace. Membership mile to wahi, warna personal workspace = user id. */
async function ensureWallet(userId: string) {
  const d = db!;
  const own = await d
    .from("ai_credit_wallets")
    .select("*")
    .eq("owner_id", userId)
    .maybeSingle();
  if (own.data) return own.data;

  let workspaceId = userId;
  try {
    const m = await d
      .from("workspace_members")
      .select("workspace_id")
      .eq("user_id", userId)
      .limit(1)
      .maybeSingle();
    if (m.data?.workspace_id) workspaceId = m.data.workspace_id as string;
  } catch {
    /* membership table optional */
  }

  const existing = await d
    .from("ai_credit_wallets")
    .select("*")
    .eq("workspace_id", workspaceId)
    .maybeSingle();
  if (existing.data) return existing.data;

  const created = await d
    .from("ai_credit_wallets")
    .insert({ workspace_id: workspaceId, owner_id: userId })
    .select("*")
    .single();
  if (created.error) throw created.error;
  return created.data;
}

// ── PUBLIC: locked catalogue ────────────────────────────────────
router.get("/products", async (_req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  try {
    const [plans, topups] = await Promise.all([
      db.from("ai_credit_plans").select("*").eq("active", true).order("sort_order"),
      db
        .from("ai_credit_topup_products")
        .select("*")
        .eq("active", true)
        .eq("public_visible", true)
        .order("sort_order"),
    ]);
    if (plans.error) throw plans.error;
    if (topups.error) throw topups.error;
    res.json({
      plans: plans.data ?? [],
      topups: topups.data ?? [],
      bands: Object.entries(BANDS).map(([action, [min, max]]) => ({ action, min, max })),
      currency: "GBP",
    });
  } catch (e) {
    fail(res, e);
  }
});

// ── WALLET ──────────────────────────────────────────────────────
router.get("/wallet", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId) return;
  try {
    const w = await ensureWallet(userId);
    const grants = await db!
      .from("ai_credit_grants")
      .select("grant_day, credits, created_at")
      .eq("workspace_id", w.workspace_id)
      .eq("cycle_started_at", w.cycle_started_at);
    res.json({
      wallet: {
        workspace_id: w.workspace_id,
        plan_id: w.plan_id,
        subscription_credits: Number(w.subscription_credits),
        topup_credits: Number(w.topup_credits),
        complimentary_credits: Number(w.complimentary_credits),
        reserved_credits: Number(w.reserved_credits),
        total_balance: Number(w.total_balance),
        currency: w.currency,
        cycle_started_at: w.cycle_started_at,
        renews_at: w.renews_at,
      },
      complimentary_claimed: (grants.data ?? []).map((g: any) => g.grant_day),
    });
  } catch (e) {
    fail(res, e);
  }
});

router.get("/ledger", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId) return;
  try {
    const w = await ensureWallet(userId);
    const limit = Math.min(Number(req.query['limit']) || 50, 200);
    const { data, error } = await db!
      .from("ai_credit_ledger")
      .select("*")
      .eq("workspace_id", w.workspace_id)
      .order("created_at", { ascending: false })
      .limit(limit);
    if (error) throw error;
    res.json({ entries: data ?? [], immutable: true });
  } catch (e) {
    fail(res, e);
  }
});

router.get("/actions", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId) return;
  try {
    const w = await ensureWallet(userId);
    const limit = Math.min(Number(req.query['limit']) || 50, 200);
    const { data, error } = await db!
      .from("ai_actions")
      .select(
        "id, action_type, model, status, estimated_credits_min, estimated_credits_max, reserved_credits, actual_credits, latency_ms, created_at, completed_at",
      )
      .eq("workspace_id", w.workspace_id)
      .order("created_at", { ascending: false })
      .limit(limit);
    if (error) throw error;
    res.json({ actions: data ?? [] });
  } catch (e) {
    fail(res, e);
  }
});

// ── PRE-FLIGHT ESTIMATE ─────────────────────────────────────────
router.post("/estimate", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId) return;
  const b = req.body ?? {};
  const actionType = String(b.action_type || "").trim();
  if (!actionType) return res.status(400).json({ error: "action_type_required" });
  try {
    const w = await ensureWallet(userId);
    const inTok = Math.max(0, Number(b.input_tokens) || 0);
    const outTok = Math.max(0, Number(b.output_tokens) || 0);
    const { min, max } = estimate(actionType, inTok, outTok);
    const { data, error } = await db!
      .from("ai_actions")
      .insert({
        workspace_id: w.workspace_id,
        user_id: userId,
        action_type: actionType,
        model: b.model ?? null,
        input_tokens: inTok,
        output_tokens: outTok,
        estimated_credits_min: min,
        estimated_credits_max: max,
        status: "estimated",
      })
      .select("id")
      .single();
    if (error) throw error;
    res.json({
      action_id: data.id,
      estimate: { min, max },
      balance: Number(w.total_balance),
      affordable: Number(w.total_balance) >= max,
      approval_required: true,
    });
  } catch (e) {
    fail(res, e);
  }
});

// ── RESERVE / SETTLE / RELEASE (RPC only) ───────────────────────
router.post("/reserve", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId) return;
  const b = req.body ?? {};
  if (!b.action_id || !b.credits || !b.idempotency_key) {
    return res.status(400).json({ error: "action_id_credits_idempotency_key_required" });
  }
  try {
    const w = await ensureWallet(userId);
    const { data, error } = await db!.rpc("ai_credits_reserve", {
      _workspace_id: w.workspace_id,
      _action_id: b.action_id,
      _credits: Number(b.credits),
      _idem: String(b.idempotency_key),
    });
    if (error) {
      if (String(error.message).includes("insufficient_credits")) {
        return res.status(402).json({ error: "insufficient_credits" });
      }
      throw error;
    }
    res.json({ ok: true, balance: Number(data) });
  } catch (e) {
    fail(res, e);
  }
});

router.post("/settle", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId) return;
  const b = req.body ?? {};
  if (!b.action_id || b.actual_credits === undefined) {
    return res.status(400).json({ error: "action_id_actual_credits_required" });
  }
  try {
    const w = await ensureWallet(userId);
    const { data, error } = await db!.rpc("ai_credits_settle", {
      _workspace_id: w.workspace_id,
      _action_id: b.action_id,
      _actual: Number(b.actual_credits),
      _model: b.model ?? null,
      _provider_cost: Number(b.provider_cost) || 0,
      _idem: b.idempotency_key ?? null,
    });
    if (error) throw error;
    res.json({ ok: true, balance: Number(data), receipt: { action_id: b.action_id, charged: Number(b.actual_credits) } });
  } catch (e) {
    fail(res, e);
  }
});

router.post("/release", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId) return;
  const b = req.body ?? {};
  if (!b.action_id) return res.status(400).json({ error: "action_id_required" });
  try {
    const w = await ensureWallet(userId);
    const { data, error } = await db!.rpc("ai_credits_release", {
      _workspace_id: w.workspace_id,
      _action_id: b.action_id,
      _reason: b.reason ?? "provider failure",
    });
    if (error) throw error;
    res.json({ ok: true, balance: Number(data) });
  } catch (e) {
    fail(res, e);
  }
});

// ── COMPLIMENTARY (5 + 5 once per cycle) ────────────────────────
router.post("/complimentary", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId) return;
  const day = Number(req.body?.day);
  if (day !== 1 && day !== 2) return res.status(400).json({ error: "day_must_be_1_or_2" });
  try {
    const w = await ensureWallet(userId);
    const { data, error } = await db!.rpc("ai_credits_complimentary", {
      _workspace_id: w.workspace_id,
      _day: day,
    });
    if (error) throw error;
    res.json({ ok: true, balance: Number(data) });
  } catch (e) {
    fail(res, e);
  }
});

// ── TOP-UP GRANT (paid credits) ─────────────────────────────────
// Paid credits sirf verified payment se. Jab tak Polar webhook live nahi,
// yeh endpoint internal service secret (AI_CREDITS_GRANT_SECRET) maangta hai.
router.post("/topup", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId) return;
  const b = req.body ?? {};
  if (!b.product_id || !b.idempotency_key) {
    return res.status(400).json({ error: "product_id_idempotency_key_required" });
  }
  const secret = process.env.AI_CREDITS_GRANT_SECRET || "";
  const provided = String(req.headers["x-grant-secret"] || "");
  if (!secret || provided !== secret) {
    // honest TODO: Polar checkout + webhook verification pending
    return res.status(402).json({
      error: "payment_required",
      detail: "Top-up credits are granted only after verified payment (checkout wiring pending).",
    });
  }
  try {
    const w = await ensureWallet(userId);
    const { data, error } = await db!.rpc("ai_credits_topup", {
      _workspace_id: w.workspace_id,
      _product_id: String(b.product_id),
      _idem: String(b.idempotency_key),
    });
    if (error) {
      if (String(error.message).includes("unknown_topup_product")) {
        return res.status(400).json({ error: "unknown_topup_product" });
      }
      throw error;
    }
    res.json({ ok: true, balance: Number(data) });
  } catch (e) {
    fail(res, e);
  }
});

// ── FOUNDER FOUNDER VIEW ────────────────────────────────────────────
founderRouter.get("/ai/credits/overview", async (req, res) => {
  const userId = await requireUser(req, res);
  if (!userId) return;
  try {
    const [wallets, actions, ledger] = await Promise.all([
      db!.from("ai_credit_wallets").select("*").order("updated_at", { ascending: false }).limit(200),
      db!
        .from("ai_actions")
        .select("status, actual_credits, provider_cost, infrastructure_cost, model, created_at")
        .order("created_at", { ascending: false })
        .limit(1000),
      db!
        .from("ai_credit_ledger")
        .select("entry_type, amount, created_at")
        .order("created_at", { ascending: false })
        .limit(1000),
    ]);
    if (wallets.error) throw wallets.error;

    const acts = actions.data ?? [];
    const chargedCredits = acts.reduce((s: number, a: any) => s + Number(a.actual_credits || 0), 0);
    const providerCost = acts.reduce((s: number, a: any) => s + Number(a.provider_cost || 0), 0);
    const infraCost = acts.reduce((s: number, a: any) => s + Number(a.infrastructure_cost || 0), 0);
    const topupPaid = (ledger.data ?? [])
      .filter((l: any) => l.entry_type === "topup_purchase")
      .reduce((s: number, l: any) => s + Number(l.amount || 0), 0);

    const byModel: Record<string, { runs: number; credits: number; cost: number }> = {};
    for (const a of acts) {
      const k = a.model || "unknown";
      byModel[k] ??= { runs: 0, credits: 0, cost: 0 };
      byModel[k].runs += 1;
      byModel[k].credits += Number(a.actual_credits || 0);
      byModel[k].cost += Number(a.provider_cost || 0);
    }

    res.json({
      wallets: wallets.data ?? [],
      totals: {
        wallets: (wallets.data ?? []).length,
        credits_outstanding: (wallets.data ?? []).reduce(
          (s: number, w: any) => s + Number(w.total_balance || 0),
          0,
        ),
        credits_charged: Math.round(chargedCredits * 1000) / 1000,
        topup_credits_sold: topupPaid,
        provider_cost: Math.round(providerCost * 1e6) / 1e6,
        infrastructure_cost: Math.round(infraCost * 1e6) / 1e6,
        gross_margin_cost_basis:
          Math.round((chargedCredits - (providerCost + infraCost)) * 1000) / 1000,
      },
      by_model: byModel,
      recent_actions: acts.slice(0, 50),
    });
  } catch (e) {
    fail(res, e);
  }
});

export default router;
export { router as aiCreditsRouter, founderRouter as founderAiCreditsRouter };
