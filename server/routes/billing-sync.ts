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
import {
  BILLING_PRODUCTS,
  configuredProduct,
  productById,
  type BillingProduct,
} from "../config/billing-products";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const POLAR_TOKEN = process.env.POLAR_ACCESS_TOKEN || "";
const POLAR_API = "https://api.polar.sh";
const SUCCESS_URL =
  process.env.POLAR_SUCCESS_URL || "https://anexomail.com/checkout/done?checkout_id={CHECKOUT_ID}";

function safeReturnTo(raw: unknown): string | null {
  const s = String(raw || "").trim();
  if (!s.startsWith("/") || s.startsWith("//") || s.includes("://") || s.length > 200) return null;
  return s;
}

function successUrlWithReturn(returnTo: string | null): string {
  if (!returnTo) return SUCCESS_URL;
  const join = SUCCESS_URL.includes("?") ? "&" : "?";
  return `${SUCCESS_URL}${join}return_to=${encodeURIComponent(returnTo)}`;
}

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

async function accountKindFor(userId: string): Promise<"personal" | "business" | null> {
  if (!db) return null;
  const { data } = await db
    .from("account_profiles")
    .select("preferences")
    .eq("user_id", userId)
    .maybeSingle();
  const kind = String(data?.preferences?.workspace_kind || "")
    .trim()
    .toLowerCase();
  return kind === "personal" || kind === "business" ? kind : null;
}

async function enforceAccountKind(
  userId: string,
  required: BillingProduct["accountKind"],
  res: any,
): Promise<boolean> {
  if (!required) return true;
  const actual = await accountKindFor(userId);
  if (actual !== required) {
    res.status(403).json({ error: "product_not_available_for_account_kind" });
    return false;
  }
  return true;
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
    const detail =
      typeof json?.detail === "string" ? json.detail : JSON.stringify(json?.detail ?? json ?? {});
    throw new Error(`polar_${res.status}: ${detail}`);
  }
  return json;
}

// ---------------------------------------------------------------------------
// 1) POST /api/billing/intent — Supabase pehle, Polar baad mein
//    E21 (14 Oct 2026): body handling pulled out into openCheckoutIntent()
//    so /change-plan's "no existing subscription yet" fallback can reuse
//    the exact same first-time-checkout path — no duplicate logic (Rule 6).
// ---------------------------------------------------------------------------
async function openCheckoutIntent(
  userId: string,
  body: { product_key?: unknown; seats?: unknown; email?: unknown; return_to?: unknown },
  res: any,
  // E22: set by /change-plan when this checkout REPLACES an existing active
  // subscription (founder rule: full price for the new plan, old one closed).
  replaces?: { subscriptionId: string },
): Promise<void> {
  if (!db) {
    res.status(503).json({ error: "supabase_not_configured" });
    return;
  }
  const { product_key, seats = 1, email, return_to } = body || {};
  const selected = product_key ? configuredProduct(String(product_key)) : null;
  if (!selected) {
    res.status(400).json({ error: "product_required", known: Object.keys(BILLING_PRODUCTS) });
    return;
  }
  if (!(await enforceAccountKind(userId, selected.accountKind, res))) return;
  const safeSeats = selected.perSeat
    ? Math.max(1, Math.min(10000, Math.trunc(Number(seats) || 1)))
    : 1;
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
    res.status(500).json({ error: "intent_open_failed", detail: intentError.message });
    return;
  }

  // STEP 2 — messenger ko bolo
  if (!POLAR_TOKEN) {
    res.status(503).json({ error: "polar_not_configured", intent_id: intentId });
    return;
  }
  try {
    // Polar metadata: koi bhi empty string bhejne par 422 aata hai —
    // is liye khali values yahan hi nikal dete hain.
    const rawMeta: Record<string, string> = {
      anexomail_user_id: userId,
      anexomail_intent_id: String(intentId),
      seats: String(safeSeats),
      product_key: String(product_key),
      kind: selected.kind,
      account_kind: selected.accountKind ?? "",
      plan: selected.plan ?? "",
      band: selected.band ?? "",
      billing_cycle: selected.cycle ?? "one_time",
      amount_expected_gbp: String(expectedAmount),
      replaces_subscription_id: replaces?.subscriptionId ?? "",
    };
    const metadata: Record<string, string> = {};
    for (const [key, value] of Object.entries(rawMeta)) {
      const v = String(value ?? "").trim();
      if (v) metadata[key] = v;
    }

    const payload: any = {
      // Polar CheckoutProductCreate `product_id` maangta hai; `products`
      // bhi bhejte hain taake naya aur purana schema dono chal jaye.
      product_id: selected.productId,
      products: [selected.productId],
      success_url: successUrlWithReturn(safeReturnTo(return_to)),
      external_customer_id: userId,
      metadata,
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

    // E22: record "this payment replaces subscription X" BEFORE the user gets
    // the checkout URL. If this cannot be written they would pay and keep the
    // old plan running too (double billing) — so no URL is handed out.
    // The Rust payment engine's replace loop closes the old subscription only
    // after the new product's subscription is active.
    if (replaces) {
      await db
        .from("polar_plan_replacements")
        .update({ state: "abandoned", done_at: new Date().toISOString() })
        .eq("old_subscription_id", replaces.subscriptionId)
        .eq("state", "pending");
      const { error: replError } = await db.from("polar_plan_replacements").insert({
        user_id: userId,
        old_subscription_id: replaces.subscriptionId,
        target_product_id: selected.productId,
        target_product_key: String(product_key),
        intent_id: intentId,
        checkout_id: checkout.id,
      });
      if (replError) {
        console.error("[billing intent] replacement record failed:", replError.message);
        res.status(500).json({ error: "replacement_record_failed", intent_id: intentId });
        return;
      }
    }

    res.json({ intent_id: intentId, checkout_id: checkout.id, url: checkout.url });
  } catch (e: any) {
    // intent zinda rehta hai — sweep dobara koshish karega
    console.error("[billing intent] polar checkout failed:", e?.message || e);
    await db.rpc("billing_sync_fail", {
      p_intent: intentId,
      p_error: `checkout_create_failed: ${e?.message || e}`,
    });
    res.status(502).json({
      error: "checkout_failed",
      intent_id: intentId,
      detail: String(e?.message || e),
    });
  }
}

authRouter.post("/intent", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const userId = await requireUser(req, res);
  if (!userId) return;
  await openCheckoutIntent(userId, req.body || {}, res);
});

// ---------------------------------------------------------------------------
// 1b) POST /api/billing/change-plan — E21 part 3/4 + E22 (14 Oct 2026)
//
//     FOUNDER RULE: a user who moves to another package pays the NEW package
//     in full from the start — no proration, no credit for the old one — and
//     the old subscription is closed. (Earlier E21 part 3 used Polar's
//     in-place PATCH with proration_behavior "prorate"; that credited the old
//     payment and is removed.)
//
//     So this route never changes a subscription itself. It:
//       • validates the target (personal tier for a personal account, or a
//         workspace plan for a non-personal account — a personal account has
//         to convert first),
//       • finds the user's current active *plan* subscription,
//       • opens an ordinary full-price checkout (openCheckoutIntent) and
//         records "this checkout replaces subscription X"
//         (public.polar_plan_replacements, E22 SQL).
//     The Rust payment engine (polar-rust-payment :3400, replace loop) closes
//     subscription X on Polar ONLY after the new product's subscription is
//     active. Checkout abandoned = old plan untouched.
//
//     No active plan subscription (first purchase) = plain checkout, nothing
//     to replace. Same product as today = {ok, unchanged}.
//     Works for every plan incl. Business Pro (no seat/non-seat in-place
//     limit any more, because nothing is switched in place).
// ---------------------------------------------------------------------------
authRouter.post("/change-plan", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const userId = await requireUser(req, res);
  if (!userId) return;

  const { product_key, return_to } = req.body || {};
  const target = product_key ? configuredProduct(String(product_key)) : null;
  if (!target) {
    return res.status(400).json({ error: "product_required", known: Object.keys(BILLING_PRODUCTS) });
  }
  // Two kinds of target:
  //   • personal-tier products (accountKind "personal"): only a personal account
  //   • generic workspace plans (kind "plan", no accountKind tag): only an
  //     account that is NOT explicitly personal. A personal account has to
  //     convert first (ConvertToBusiness). kind null (not stamped yet) is
  //     allowed, same as /intent already allows it for untagged products.
  const isPersonalTarget = target.accountKind === "personal";
  const isWorkspaceTarget = target.kind === "plan" && !target.accountKind;
  if (!isPersonalTarget && !isWorkspaceTarget) {
    return res.status(400).json({ error: "change_plan_plan_products_only" });
  }
  if (isPersonalTarget) {
    if (!(await enforceAccountKind(userId, target.accountKind, res))) return;
  } else if ((await accountKindFor(userId)) === "personal") {
    return res.status(403).json({ error: "convert_to_business_first" });
  }

  const { data: current, error: curError } = await db
    .from("polar_subscriptions")
    .select("polar_subscription_id, product_id, status")
    .eq("user_id", userId)
    .eq("status", "active")
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (curError) {
    return res.status(500).json({ error: "db_error", detail: curError.message });
  }

  const currentProduct = current?.product_id ? productById(String(current.product_id)) : null;
  const hasActivePlanSubscription =
    Boolean(current?.polar_subscription_id) && currentProduct?.kind === "plan";

  if (!hasActivePlanSubscription) {
    // Nothing to replace — first-time purchase.
    await openCheckoutIntent(userId, { product_key, seats: 1, return_to }, res);
    return;
  }

  // Already on exactly this product — nothing to buy.
  if (String(current!.product_id) === target.productId) {
    return res.json({ ok: true, subscription_id: current!.polar_subscription_id, unchanged: true });
  }

  await openCheckoutIntent(userId, { product_key, seats: 1, return_to }, res, {
    subscriptionId: String(current!.polar_subscription_id),
  });
});

// ---------------------------------------------------------------------------
// FALLBACK: GET /api/billing/subscription  (Rust :3200 PRIMARY)
// GET /api/billing/invoices               (Rust :3200 PRIMARY)
//
// rpcOrRest (billing-platform.ts) tries POST /rpc/billing.* on Rust :3200 first.
// These Bun routes activate ONLY when Rust returns 404/501/502/503.
//
// Both call the same Supabase RPCs (E5_billing_subscription_api.sql):
//   get_billing_subscription(p_user_id) — uses polar_billing_state() [Phase 50]
//   get_billing_invoices(p_user_id) — reads workspace_invoices [E5]
//
// Polar Rust payment :3400 NO-TOUCH. Chain: :3400 → Supabase → RPCs → here.
// ---------------------------------------------------------------------------
authRouter.get("/subscription", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const userId = await requireUser(req, res);
  if (!userId) return;
  const { data, error } = await db.rpc("get_billing_subscription", { p_user_id: userId });
  if (error) return res.status(500).json({ error: "db_error", detail: error.message });
  return res.json(
    data ?? {
      plan: null,
      state: "none",
      price_per_seat: 0,
      currency: "GBP",
      interval: "month",
      seats: 0,
      seats_used: 0,
      storage_per_mailbox_gb: null,
      renews_at: null,
      cancel_at: null,
    },
  );
});

authRouter.get("/invoices", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const userId = await requireUser(req, res);
  if (!userId) return;
  const { data, error } = await db.rpc("get_billing_invoices", { p_user_id: userId });
  if (error) return res.status(500).json({ error: "db_error", detail: error.message });
  return res.json(data ?? { invoices: [] });
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
      const metaIntent =
        d.metadata?.anexomail_intent_id || d.checkout?.metadata?.anexomail_intent_id;
      const paid =
        row.type === "order.paid" ||
        row.type === "subscription.active" ||
        d.status === "succeeded" ||
        d.status === "confirmed" ||
        d.paid === true;
      if (!paid) continue;
      if (metaIntent === intent.id || (checkoutId && checkoutId === intent.polar_checkout_id)) {
        const paidProductId = String(
          d.product_id || d.product?.id || d.items?.[0]?.product_id || "",
        );
        await db.rpc("billing_intent_confirm", {
          p_intent: intent.id,
          p_checkout_id: intent.polar_checkout_id,
          p_order_id: d.id || null,
          p_amount: d.total_amount ? Number(d.total_amount) / 100 : null,
          p_source: "webhook",
          p_currency: String(d.currency || "GBP").toUpperCase(),
          p_product_id: paidProductId || null,
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
        p_currency: String(checkout?.currency || "GBP").toUpperCase(),
        p_product_id: paidProductId || null,
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
        p_currency: row.currency || "GBP",
        p_product_id: row.product_id || null,
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

// ---------------------------------------------------------------------------
// ABSM (Phase 49) — POST /api/public/billing/guest-intent
// Sign-in ke bina checkout: Supabase mein pehle guest intent, phir Polar.
// Sign-in ke baad /api/billing/claim-guest intent ko asli user se jodta hai.
// ---------------------------------------------------------------------------
publicRouter.post("/billing/guest-intent", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const { product_key, seats = 1, email, return_to } = req.body || {};
  const selected = product_key ? configuredProduct(String(product_key)) : null;
  if (!selected) {
    return res
      .status(400)
      .json({ error: "product_required", known: Object.keys(BILLING_PRODUCTS) });
  }
  if (selected.accountKind) {
    return res.status(403).json({ error: "personal_products_require_sign_in" });
  }
  const safeSeats = selected.perSeat
    ? Math.max(1, Math.min(10000, Math.trunc(Number(seats) || 1)))
    : 1;
  const expectedAmount = selected.amountGbp * safeSeats;

  const { data: opened, error: openError } = await db.rpc("billing_guest_intent_open", {
    p_kind: selected.kind,
    p_plan: selected.plan ?? null,
    p_band: selected.band ?? null,
    p_product_key: String(product_key),
    p_product_id: selected.productId,
    p_seats: safeSeats,
    p_amount: expectedAmount,
    p_currency: "GBP",
    p_email: email ? String(email) : null,
  });
  if (openError) {
    return res.status(500).json({ error: "intent_open_failed", detail: openError.message });
  }
  const row = Array.isArray(opened) ? opened[0] : opened;
  const intentId = row?.intent_id;
  const guestToken = row?.guest_token;
  if (!intentId || !guestToken) return res.status(500).json({ error: "intent_open_failed" });

  if (!POLAR_TOKEN) {
    return res.status(503).json({ error: "polar_not_configured", intent_id: intentId });
  }
  try {
    const rawMeta: Record<string, string> = {
      anexomail_intent_id: String(intentId),
      anexomail_guest_token: String(guestToken),
      seats: String(safeSeats),
      product_key: String(product_key),
      kind: selected.kind,
      plan: selected.plan ?? "",
      band: selected.band ?? "",
      billing_cycle: selected.cycle ?? "one_time",
      amount_expected_gbp: String(expectedAmount),
    };
    const metadata: Record<string, string> = {};
    for (const [key, value] of Object.entries(rawMeta)) {
      const v = String(value ?? "").trim();
      if (v) metadata[key] = v;
    }
    const payload: any = {
      product_id: selected.productId,
      products: [selected.productId],
      success_url: successUrlWithReturn(safeReturnTo(return_to) ?? "/auth"),
      metadata,
    };
    if (email) payload.customer_email = String(email);

    const checkout = await polarFetch("/v1/checkouts/", {
      method: "POST",
      body: JSON.stringify(payload),
    });
    await db.rpc("billing_intent_attach_checkout", {
      p_intent: intentId,
      p_checkout_id: checkout.id,
    });
    return res.json({
      intent_id: intentId,
      guest_token: guestToken,
      checkout_id: checkout.id,
      url: checkout.url,
    });
  } catch (e: any) {
    console.error("[billing guest-intent] polar checkout failed:", e?.message || e);
    await db.rpc("billing_sync_fail", {
      p_intent: intentId,
      p_error: `guest_checkout_create_failed: ${e?.message || e}`,
    });
    return res.status(502).json({
      error: "checkout_failed",
      intent_id: intentId,
      detail: String(e?.message || e),
    });
  }
});

// POST /api/billing/claim-guest  { guest_token }  — sign-in ke baad linking
authRouter.post("/claim-guest", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const userId = await requireUser(req, res);
  if (!userId) return;
  const token = String(req.body?.guest_token || "");
  if (!token) return res.status(400).json({ error: "guest_token_required" });
  const { data, error } = await db.rpc("billing_guest_intent_claim", {
    p_token: token,
    p_user: userId,
  });
  if (error) return res.status(500).json({ error: "claim_failed", detail: error.message });
  return res.json({ intent_id: data ?? null, claimed: Boolean(data) });
});

export { authRouter as billingSyncAuthRouter, publicRouter as billingSyncPublicRouter };
export default authRouter;
