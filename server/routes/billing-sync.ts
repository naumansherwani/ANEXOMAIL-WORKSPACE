// ANEXOMAIL — Phase 36: STATE SYNC ENGINE (Server 2 / Brain, port 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/billing-sync.ts /opt/anexomail/src/routes/billing-sync.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/billing-sync.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// Falsafa: Supabase #4 = SOURCE OF TRUTH. Polar sirf MESSENGER hai.
//   - checkout se PEHLE Supabase mein intent banta hai
//   - entitlement sirf billing_intent_confirm() -> billing_apply_entitlement() se
//   - PULL loop har minute Polar se sach kheenchta hai (webhook aaye ya na aaye)
//   - paid intent kabhi abandon nahi hota, sirf unpaid stale (>24h)
//
// Routes:
//   POST /api/billing/intent            auth   — intent + Polar checkout URL
//   GET  /api/billing/state             auth   — authoritative entitlement + intents
//   GET  /api/billing/intent/:id        auth   — intent + live pull-truth check
//   GET  /api/billing/state-health      auth   — founder: gaps + counters
//   POST /api/public/billing/sync       cron   — pull-truth sweep (no payment failure)
//
// Env: SUPABASE4_URL, SUPABASE4_SERVICE_ROLE_KEY, POLAR_ACCESS_TOKEN,
//      POLAR_SUCCESS_URL, CRON_SECRET, POLAR_PRODUCT_* (8 IDs)
import { Router } from "express";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { BILLING_PRODUCTS, configuredProduct, productById } from "../config/billing-products";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const POLAR_TOKEN = process.env.POLAR_ACCESS_TOKEN || "";
const POLAR_API = "https://api.polar.sh";
const SUCCESS_URL =
  process.env.POLAR_SUCCESS_URL || "https://anexomail.com/checkout/done?checkout_id={CHECKOUT_ID}";

let db: SupabaseClient | null = null;
if (SUPABASE_URL && SERVICE_KEY) {
  db = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
} else {
  console.error("billing-sync: SUPABASE4_* env missing — routes will 503");
}

const authRouter = Router();
const publicRouter = Router();

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

async function polarFetch(path: string, init?: RequestInit) {
  const res = await fetch(`${POLAR_API}${path}`, {
    ...init,
    headers: {
      authorization: `Bearer ${POLAR_TOKEN}`,
      "content-type": "application/json",
      accept: "application/json",
      ...(init?.headers || {}),
    },
  });
  const text = await res.text();
  const json = text ? JSON.parse(text) : null;
  if (!res.ok) {
    throw new Error(String(json?.detail || json?.error || `polar_${res.status}`));
  }
  return json;
}

// ---------------------------------------------------------------------------
// 1) POST /api/billing/intent — Supabase pehle, Polar baad mein
// ---------------------------------------------------------------------------
authRouter.post("/intent", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const userId = await requireUser(req, res);
  if (!userId) return;

  const { product_key, seats = 1, email } = req.body || {};
  const selected = product_key ? configuredProduct(String(product_key)) : null;
  if (!selected) {
    return res.status(400).json({ error: "product_required", known: Object.keys(BILLING_PRODUCTS) });
  }
  const safeSeats = selected.perSeat ? Math.max(1, Math.min(10000, Math.trunc(Number(seats) || 1))) : 1;
  const expectedAmount = selected.amountGbp * safeSeats;

  // STEP 1 — sach Supabase mein likho (checkout se pehle)
  const { data: intentId, error: intentError } = await db.rpc("billing_intent_open", {
    p_user: userId,
    p_kind: selected.kind,
    p_plan: selected.plan ?? null,
    p_band: selected.band ?? null,
    p_product_key: String(product_key),
    p_product_id: selected.productId,
    p_seats: safeSeats,
    p_amount: expectedAmount,
    p_currency: "GBP",
    p_billing_cycle: selected.cycle ?? null,
  });
  if (intentError) {
    return res.status(500).json({ error: "intent_open_failed", detail: intentError.message });
  }

  // STEP 2 — messenger ko bolo
  if (!POLAR_TOKEN) {
    return res.status(503).json({ error: "polar_not_configured", intent_id: intentId });
  }
  try {
    const payload: any = {
      products: [selected.productId],
      success_url: SUCCESS_URL,
      external_customer_id: userId,
      metadata: {
        anexomail_user_id: userId,
        anexomail_intent_id: String(intentId),
        seats: String(safeSeats),
        product_key: String(product_key),
        kind: selected.kind,
        plan: selected.plan ?? "",
        band: selected.band ?? "",
        billing_cycle: selected.cycle ?? "one_time",
        amount_expected_gbp: String(expectedAmount),
      },
    };
    if (email) payload.customer_email = email;

    const checkout = await polarFetch("/v1/checkouts/", {
      method: "POST",
      body: JSON.stringify(payload),
    });
    await db.rpc("billing_intent_attach_checkout", {
      p_intent: intentId,
      p_checkout_id: checkout.id,
    });
    return res.json({ intent_id: intentId, checkout_id: checkout.id, url: checkout.url });
  } catch (e: any) {
    // intent zinda rehta hai — sweep dobara koshish karega
    await db.rpc("billing_sync_fail", {
      p_intent: intentId,
      p_error: `checkout_create_failed: ${e?.message || e}`,
    });
    return res.status(502).json({ error: "checkout_failed", intent_id: intentId });
  }
});

// ---------------------------------------------------------------------------
// 2) GET /api/billing/state — sirf Supabase se, Polar ko pucha bhi nahi jata
// ---------------------------------------------------------------------------
authRouter.get("/state", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const userId = await requireUser(req, res);
  if (!userId) return;

  const [{ data: ent }, { data: intents }, { data: log }] = await Promise.all([
    db.from("entitlement_state").select("*").eq("user_id", userId).maybeSingle(),
    db
      .from("billing_intents")
      .select(
        "id,kind,plan,band,seats,state,amount_expected,amount_paid,currency,paid_at,created_at,last_error",
      )
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(20),
    db
      .from("billing_state_log")
      .select("to_state,reason,source,created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(20),
  ]);

  return res.json({
    source_of_truth: "supabase",
    entitlement: ent || {
      plan: null,
      seats: 0,
      movein_band: null,
      support_active: false,
      active_until: null,
      revision: 0,
    },
    intents: intents || [],
    log: log || [],
  });
});

// ---------------------------------------------------------------------------
// 3) GET /api/billing/intent/:id — live pull-truth (user ke wait karte waqt)
// ---------------------------------------------------------------------------
authRouter.get("/intent/:id", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const userId = await requireUser(req, res);
  if (!userId) return;

  const { data: intent, error } = await db
    .from("billing_intents")
    .select("*")
    .eq("id", req.params.id)
    .maybeSingle();
  if (error) return res.status(500).json({ error: "db_error", detail: error.message });
  if (!intent) return res.status(404).json({ error: "intent_not_found" });
  if (intent.user_id !== userId) return res.status(403).json({ error: "forbidden" });

  if (intent.state === "open" && intent.polar_checkout_id && POLAR_TOKEN) {
    const settled = await pullTruthForIntent(intent);
    if (settled) {
      const { data: fresh } = await db
        .from("billing_intents")
        .select("*")
        .eq("id", intent.id)
        .maybeSingle();
      return res.json({ intent: fresh, pulled: true });
    }
  }
  return res.json({ intent, pulled: false });
});

// ---------------------------------------------------------------------------
// 4) GET /api/billing/state-health — founder view
// ---------------------------------------------------------------------------
authRouter.get("/state-health", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const userId = await requireUser(req, res);
  if (!userId) return;

  const [{ data: health }, { data: gaps }, { data: alerts }] = await Promise.all([
    db.from("billing_state_health").select("*").maybeSingle(),
    db.from("billing_truth_gaps").select("*").limit(50),
    db
      .from("payment_alerts")
      .select("id,severity,kind,message,created_at")
      .is("resolved_at", null)
      .order("created_at", { ascending: false })
      .limit(50),
  ]);
  return res.json({ health: health || null, gaps: gaps || [], alerts: alerts || [] });
});

// ---------------------------------------------------------------------------
// 5) PULL-TRUTH: Polar se sach kheencho, Supabase mein likho
// ---------------------------------------------------------------------------
async function pullTruthForIntent(intent: any): Promise<boolean> {
  if (!db) return false;
  try {
    // (a) webhook already aaya ho to usi se confirm — network hit bachao
    const { data: hit } = await db
      .from("polar_webhook_events")
      .select("payload,type")
      .in("type", ["order.paid", "order.created", "subscription.active", "checkout.updated"])
      .order("created_at", { ascending: false })
      .limit(50);
    for (const row of (hit as any[]) || []) {
      const d = row?.payload?.data || {};
      const checkoutId = d.checkout_id || d.checkout?.id || null;
      const metaIntent = d.metadata?.anexomail_intent_id || d.checkout?.metadata?.anexomail_intent_id;
      const paid =
        row.type === "order.paid" ||
        row.type === "subscription.active" ||
        d.status === "succeeded" ||
        d.status === "confirmed" ||
        d.paid === true;
      if (!paid) continue;
      if (metaIntent === intent.id || (checkoutId && checkoutId === intent.polar_checkout_id)) {
        await db.rpc("billing_intent_confirm", {
          p_intent: intent.id,
          p_checkout_id: intent.polar_checkout_id,
          p_order_id: d.id || null,
          p_amount: d.total_amount ? Number(d.total_amount) / 100 : null,
          p_source: "webhook",
        });
        return true;
      }
    }

    // (b) messenger se seedha pucho — webhook kabhi na aaye to bhi payment milti hai
    if (!POLAR_TOKEN || !intent.polar_checkout_id) return false;
      const checkout = await polarFetch(`/v1/checkouts/${intent.polar_checkout_id}`);
      const paidProductId = String(checkout?.product_id || checkout?.product?.id || "");
      const paidProduct = paidProductId ? productById(paidProductId) : null;
      if (paidProductId && (!paidProduct || paidProduct.productId !== intent.product_id)) {
        throw new Error("checkout_product_mismatch");
      }
    const status = String(checkout?.status || "");
    if (status === "confirmed" || status === "succeeded") {
      await db.rpc("billing_intent_confirm", {
        p_intent: intent.id,
        p_checkout_id: intent.polar_checkout_id,
        p_order_id: checkout?.order_id || null,
        p_amount: checkout?.total_amount ? Number(checkout.total_amount) / 100 : null,
        p_source: "pull",
      });
      return true;
    }
    if (status === "expired" || status === "failed") {
      await db.rpc("billing_sync_touch", { p_intent: intent.id, p_delay_seconds: 3600 });
      return false;
    }
    await db.rpc("billing_sync_touch", { p_intent: intent.id, p_delay_seconds: 60 });
    return false;
  } catch (e: any) {
    await db.rpc("billing_sync_fail", { p_intent: intent.id, p_error: String(e?.message || e) });
    return false;
  }
}

// POST /api/public/billing/sync   header: x-anexomail-cron: $CRON_SECRET
publicRouter.post("/billing/sync", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const secret = process.env.CRON_SECRET || "";
  if (!secret || String(req.headers["x-anexomail-cron"] || "") !== secret) {
    return res.status(401).json({ error: "unauthorized" });
  }

  const { data: claimed, error } = await db.rpc("billing_sync_claim", { p_limit: 25 });
  if (error) return res.status(500).json({ error: "claim_failed", detail: error.message });

  let settled = 0;
  let pending = 0;
  for (const row of (claimed as any[]) || []) {
    // paid magar entitlement nahi — dobara apply karo (idempotent)
    if (row.state === "paid" || row.state === "stuck") {
      const { error: confirmError } = await db.rpc("billing_intent_confirm", {
        p_intent: row.id,
        p_checkout_id: row.polar_checkout_id,
        p_order_id: null,
        p_amount: null,
        p_source: "sweep",
      });
      if (confirmError) {
        await db.rpc("billing_sync_fail", { p_intent: row.id, p_error: confirmError.message });
        pending += 1;
      } else {
        settled += 1;
      }
      continue;
    }
    const ok = await pullTruthForIntent(row);
    if (ok) settled += 1;
    else pending += 1;
  }

  const { data: abandoned } = await db.rpc("billing_sync_abandon_stale");
  return res.json({
    claimed: (claimed as any[])?.length || 0,
    settled,
    pending,
    abandoned: abandoned ?? 0,
  });
});

export { authRouter as billingSyncAuthRouter, publicRouter as billingSyncPublicRouter };
export default authRouter;
