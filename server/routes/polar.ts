// ANEXOMAIL — Polar Checkout + Webhook (Server 2 / Brain, port 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/polar.ts /opt/anexomail/src/routes/polar.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/polar.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// Routes:
//   POST /api/billing/checkout              auth — create Polar checkout session
//   GET  /api/billing/checkout/:id          auth — verify checkout state
//   POST /api/public/polar/webhook          public — verified Polar webhook events
//
// Env required:
//   POLAR_ACCESS_TOKEN, POLAR_WEBHOOK_SECRET, POLAR_SUCCESS_URL
//   SUPABASE4_URL, SUPABASE4_SERVICE_ROLE_KEY
import { Router } from "express";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createHmac, timingSafeEqual } from "crypto";
import { BILLING_PRODUCTS, configuredProduct, productById } from "../config/billing-products";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";

const POLAR_TOKEN = process.env.POLAR_ACCESS_TOKEN || "";
const POLAR_WEBHOOK_SECRET = process.env.POLAR_WEBHOOK_SECRET || "";
const POLAR_API = "https://api.polar.sh";
const SUCCESS_URL =
  process.env.POLAR_SUCCESS_URL || "https://anexomail.com/checkout/done?checkout_id={CHECKOUT_ID}";

let db: SupabaseClient | null = null;
if (SUPABASE_URL && SERVICE_KEY) {
  db = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
} else {
  console.error("polar: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY missing — routes will 503");
}

if (!POLAR_TOKEN) console.error("polar: POLAR_ACCESS_TOKEN missing — checkout will 503");
if (!POLAR_WEBHOOK_SECRET) console.error("polar: POLAR_WEBHOOK_SECRET missing — webhook will 401");

const publicRouter = Router();
const authRouter = Router();

function productMap(): Record<string, string> {
  const map: Record<string, string> = {};
  for (const key of Object.keys(BILLING_PRODUCTS)) {
    const product = configuredProduct(key);
    if (product) map[key] = product.productId;
  }
  return map;
}

function kindFromMetadata(meta?: Record<string, string> | null) {
  const m = meta || {};
  return {
    brand: m.brand || "anexomail",
    kind: m.kind || "unknown",
    band: m.band || null,
    plan: m.plan || null,
  };
}

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

// ---------- Polar API helpers ----------
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
    const err = json?.detail || json?.message || json?.error || `polar_${res.status}`;
    throw new Error(String(err));
  }
  return json;
}

// ---------- checkout: authenticated ----------
authRouter.post("/checkout", async (req, res) => {
  return res.status(410).json({ error: "checkout_route_retired", use: "/api/billing/intent" });
});

authRouter.get("/checkout/:id", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  if (!POLAR_TOKEN) return res.status(503).json({ error: "polar_not_configured" });

  const userId = await requireUser(req, res);
  if (!userId) return;

  const { id } = req.params;
  try {
    const checkout = await polarFetch(`/v1/checkouts/${id}`);
    // ownership check
    const { data: intent } = await db
      .from("billing_intents")
      .select("user_id")
      .eq("polar_checkout_id", id)
      .maybeSingle();
    if (!intent) return res.status(404).json({ error: "checkout_not_found" });
    if (intent.user_id !== userId) return res.status(403).json({ error: "forbidden" });
    res.json({
      id: checkout.id,
      status: checkout.status,
      customer_email: checkout.customer_email,
      product_id: checkout.product_id,
      product_price_id: checkout.product_price_id,
      metadata: checkout.metadata,
      url: checkout.url,
    });
  } catch (e: any) {
    console.error("[polar checkout get]", e);
    res.status(502).json({ error: "checkout_fetch_failed", detail: e.message });
  }
});

// ---------- webhook: public, verified ----------
function getWebhookSecretBytes(): Buffer {
  // Standard Webhooks secrets commonly use whsec_<base64>.
  const raw = POLAR_WEBHOOK_SECRET.startsWith("whsec_")
    ? POLAR_WEBHOOK_SECRET.slice(6)
    : POLAR_WEBHOOK_SECRET;
  try {
    const b = Buffer.from(raw, "base64");
    if (b.length > 16) return b;
  } catch {
    // ignore
  }
  return Buffer.from(raw, "utf8");
}

publicRouter.post("/polar/webhook", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  if (!POLAR_WEBHOOK_SECRET) return res.status(401).json({ error: "webhook_not_configured" });

  const webhookId = String(req.headers["webhook-id"] || "");
  const timestamp = String(req.headers["webhook-timestamp"] || "");
  const signatureHeader = String(req.headers["webhook-signature"] || "");
  const body = req.rawBody ? Buffer.from(req.rawBody).toString("utf8") : JSON.stringify(req.body);
  if (!webhookId || !timestamp || !signatureHeader || !body) {
    await captureRaw(req, webhookId, false, "missing_webhook_headers_or_payload");
    return res.status(400).json({ error: "missing_webhook_headers_or_payload" });
  }

  const secret = getWebhookSecretBytes();
  const signedPayload = `${webhookId}.${timestamp}.${body}`;
  const expected = createHmac("sha256", secret).update(signedPayload).digest("base64");
  const signatures = signatureHeader
    .split(" ")
    .map((piece) => piece.trim())
    .filter(Boolean)
    .map((piece) => {
      const separator = piece.includes(",") ? "," : "=";
      const [version, signature] = piece.split(separator, 2);
      return version === "v1" ? signature : null;
    })
    .filter((signature): signature is string => Boolean(signature));

  let signatureValid = false;
  for (const signature of signatures) {
    try {
      const actual = Buffer.from(signature);
      const wanted = Buffer.from(expected);
      if (actual.length === wanted.length && timingSafeEqual(actual, wanted)) {
        signatureValid = true;
        break;
      }
    } catch {
      // Try the next signature when the provider rotates signing keys.
    }
  }
  if (!signatureValid) {
    await captureRaw(req, webhookId, false, "invalid_signature");
    return res.status(401).json({ error: "invalid_signature" });
  }

  // replay tolerance: 5 minutes
  const tsNum = Number(timestamp);
  if (!Number.isNaN(tsNum) && Math.abs(Date.now() / 1000 - tsNum) > 300) {
    await captureRaw(req, webhookId, false, "stale_webhook");
    return res.status(401).json({ error: "stale_webhook" });
  }

  const event = req.body as any;
  const eventId = webhookId;

  // PAYMENT SAFETY: verified hit ka raw payload pehle Supabase mein — chahe
  // aage kuch bhi fail ho, paisa/proof kabhi zaya nahi hota.
  await captureRaw(req, eventId, true, null);

  // idempotency: already seen?
  const { data: existing } = await db
    .from("polar_webhook_events")
    .select("id,processed_at")
    .eq("polar_event_id", eventId)
    .maybeSingle();
  if (existing?.processed_at) return res.json({ ok: true, duplicate: true });

  // log event first
  if (!existing) {
    const { error: logError } = await db.from("polar_webhook_events").insert({
      polar_event_id: eventId,
      type: event?.type || "unknown",
      payload: event,
    });
    if (logError) {
      console.error("[polar webhook log]", logError);
      return res.status(500).json({ error: "event_log_failed" });
    }
  }

  // process business events — event already durable, is liye Polar ko hamesha
  // 200 milta hai. Fail hone par humara apna retry queue backoff se replay
  // karta hai (3 fail ke baad founder alert).
  try {
    await processWebhookEvent(event, eventId);
    await db.rpc("webhook_mark_processed", { p_event_id: eventId });
    return res.json({ ok: true, processed: true });
  } catch (e: any) {
    console.error("[polar webhook process]", e);
    await db.rpc("webhook_mark_failed", {
      p_event_id: eventId,
      p_error: String(e?.message || e),
    });
    return res.json({ ok: true, queued_for_retry: true });
  }
});

// Har hit ka raw record — signature fail ho to bhi. Yeh kabhi throw nahi karta.
async function captureRaw(req: any, eventId: string, verified: boolean, reason: string | null) {
  if (!db) return;
  try {
    await db.rpc("webhook_capture_raw", {
      p_event_id: eventId || null,
      p_type: req.body?.type || null,
      p_body: req.body ?? null,
      p_verified: verified,
      p_reason: reason,
      p_headers: {
        "webhook-id": String(req.headers["webhook-id"] || ""),
        "webhook-timestamp": String(req.headers["webhook-timestamp"] || ""),
        "user-agent": String(req.headers["user-agent"] || ""),
      },
    });
  } catch (e) {
    console.error("[polar webhook raw-capture]", e);
  }
}

// ---------- retry sweep: cron ya founder chala sakta hai ----------
// POST /api/public/polar/replay  header: x-anexomail-cron: $CRON_SECRET
publicRouter.post("/polar/replay", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const secret = process.env.CRON_SECRET || process.env.POLAR_REPLAY_SECRET || "";
  if (!secret || String(req.headers["x-anexomail-cron"] || "") !== secret) {
    return res.status(401).json({ error: "unauthorized" });
  }
  const { data, error } = await db.rpc("webhook_claim_retries", { p_limit: 20 });
  if (error) return res.status(500).json({ error: "claim_failed", detail: error.message });

  let processed = 0;
  let failed = 0;
  for (const row of (data as any[]) || []) {
    try {
      await processWebhookEvent(row.payload, row.polar_event_id);
      await db.rpc("webhook_mark_processed", { p_event_id: row.polar_event_id });
      processed += 1;
    } catch (e: any) {
      await db.rpc("webhook_mark_failed", {
        p_event_id: row.polar_event_id,
        p_error: String(e?.message || e),
      });
      failed += 1;
    }
  }
  return res.json({ claimed: (data as any[])?.length || 0, processed, failed });
});

// ---------- billing truth for the signed-in workspace ----------
authRouter.get("/subscription", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const userId = await requireUser(req, res);
  if (!userId) return;
  const { data, error } = await db
    .from("workspace_subscriptions")
    .select(
      "plan,state,seats,seats_used,price_per_seat,currency,interval,renews_at,cancel_at,storage_per_mailbox_gb",
    )
    .eq("user_id", userId)
    .maybeSingle();
  if (error) return res.status(500).json({ error: "db_error", detail: error.message });
  return res.json(
    data || {
      plan: null,
      state: "none",
      seats: 0,
      seats_used: 0,
      price_per_seat: 0,
      currency: "GBP",
      interval: "month",
      renews_at: null,
      cancel_at: null,
      storage_per_mailbox_gb: null,
    },
  );
});

authRouter.get("/invoices", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const userId = await requireUser(req, res);
  if (!userId) return;
  const { data, error } = await db
    .from("workspace_invoices")
    .select(
      "id,number,state,subtotal,tax,total,currency,period_start,period_end,issued_at,paid_at,pdf_url",
    )
    .eq("user_id", userId)
    .order("issued_at", { ascending: false });
  if (error) return res.status(500).json({ error: "db_error", detail: error.message });
  return res.json({ invoices: data || [] });
});

// Founder-facing payment safety board (auth required).
authRouter.get("/payment-health", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const userId = await requireUser(req, res);
  if (!userId) return;
  const { data: founder } = await db
    .from("founder_accounts")
    .select("user_id")
    .eq("user_id", userId)
    .maybeSingle();
  if (!founder) return res.status(403).json({ error: "founder_only" });

  const [health, gaps, alerts] = await Promise.all([
    db.from("payment_health").select("*").maybeSingle(),
    db.from("payment_reconciliation_gaps").select("*").limit(50),
    db
      .from("payment_alerts")
      .select("id,severity,kind,polar_event_id,message,created_at")
      .is("resolved_at", null)
      .order("created_at", { ascending: false })
      .limit(50),
  ]);
  return res.json({
    health: health.data || null,
    gaps: gaps.data || [],
    alerts: alerts.data || [],
  });
});

async function processWebhookEvent(event: any, eventId: string) {
  if (!db) return;
  const type = event?.type;
  const data = event?.data || {};

  if (type === "checkout.updated" && data.status === "confirmed") {
    await db
      .from("polar_checkout_sessions")
      .update({ status: "confirmed", confirmed_at: new Date().toISOString() })
      .eq("polar_checkout_id", data.id);
  }

  if (type === "order.paid") {
    const checkoutMeta = data.checkout?.metadata || {};
    const meta = { ...checkoutMeta, ...(data.metadata || {}) };
    const userId =
      meta.anexomail_user_id || data.external_customer_id || data.customer?.external_id;
    const product = data.product || data.items?.[0]?.product || {};
    const productMeta = product.metadata || {};
    const paidProductId = String(
      product.id || data.product_id || data.items?.[0]?.product_id || "",
    );
    const registeredProduct = paidProductId ? productById(paidProductId) : null;
    const legacyMeta = kindFromMetadata(productMeta);
    const kind = registeredProduct?.kind || legacyMeta.kind;
    const plan = registeredProduct?.plan || legacyMeta.plan;
    const band = registeredProduct?.band || legacyMeta.band;
    const billingCycle = registeredProduct?.cycle || meta.billing_cycle || "monthly";
    const amount = Number(data.total_amount ?? data.amount ?? 0) / 100;
    const isRecurring = data.subscription_id ? true : false;
    const customerEmail =
      data.customer_email || data.customer?.email || data.customer?.billing_address?.email || null;
    const responseHours: Record<string, number> = { basic: 72, pro: 48, business: 24 };

    const intentId = meta.anexomail_intent_id || null;
    if (intentId) {
      const { error: confirmError } = await db.rpc("billing_intent_confirm", {
        p_intent: intentId,
        p_checkout_id: data.checkout_id || data.checkout?.id || null,
        p_order_id: data.id || null,
        p_amount: amount,
        p_source: "webhook",
        p_currency: String(data.currency || "GBP").toUpperCase(),
        p_product_id: paidProductId || null,
      });
      if (confirmError) throw confirmError;
    }

    // Polar sends the provider receipt/invoice. Supabase stores our immutable proof.
    await db.from("billing_event_receipts").upsert(
      {
        polar_event_id: eventId,
        polar_order_id: data.id || null,
        user_id: userId || null,
        customer_email: customerEmail,
        event_type: type,
        plan: plan || null,
        amount_gbp: amount,
        currency: String(data.currency || "GBP").toUpperCase(),
        provider_email_state: "provider_managed",
        payload: data,
      },
      { onConflict: "polar_event_id", ignoreDuplicates: true },
    );

    let invoiceWriteError: string | null = null;
    if (userId) {
      const invoiceNumber = String(
        data.invoice_number || data.order_number || data.id || event?.id,
      );
      const { error: invoiceError } = await db.from("workspace_invoices").upsert(
        {
          user_id: userId,
          number: invoiceNumber,
          state: "paid",
          subtotal: Number(data.subtotal_amount ?? data.total_amount ?? data.amount ?? 0) / 100,
          tax: Number(data.tax_amount ?? 0) / 100,
          total: amount,
          currency: String(data.currency || "GBP").toUpperCase(),
          period_start: data.subscription?.current_period_start || null,
          period_end: data.subscription?.current_period_end || null,
          issued_at: data.created_at || new Date().toISOString(),
          paid_at: data.modified_at || data.created_at || new Date().toISOString(),
          pdf_url: data.invoice?.url || data.invoice_url || null,
        },
        { onConflict: "user_id,number" },
      );
      invoiceWriteError = invoiceError?.message || null;
    }

    // upsert revenue account for subscriptions
    if (kind === "plan" && userId && plan) {
      const seats = Number(meta.seats || 1);
      const mrr = isRecurring ? (billingCycle === "yearly" ? amount / 12 : amount) : 0;
      const { error: subscriptionError } = await db.from("workspace_subscriptions").upsert(
        {
          user_id: userId,
          plan,
          state: "active",
          seats,
          seats_used: 1,
          price_per_seat: seats > 0 ? amount / seats : amount,
          currency: String(data.currency || "GBP").toUpperCase(),
          interval: billingCycle === "yearly" ? "year" : "month",
          renews_at: data.subscription?.current_period_end || data.current_period_end || null,
          polar_customer_id: data.customer_id || data.customer?.id || null,
          polar_subscription_id: data.subscription_id || data.subscription?.id || null,
          customer_email: customerEmail,
          response_due_hours: responseHours[plan] || 72,
          provider_payload: data,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id" },
      );
      if (subscriptionError) throw subscriptionError;
      const { error: revenueError } = await db.from("revenue_accounts").upsert(
        {
          company: customerEmail || "unknown",
          plan,
          seats,
          mrr_gbp: mrr,
          status: "active",
          started_at: new Date().toISOString(),
        },
        { onConflict: "company" },
      );
      if (revenueError) throw revenueError;
    }

    // log one-off job for move-in
    if (kind === "movein" && userId) {
      await db.from("revenue_jobs").insert({
        company: customerEmail || "unknown",
        kind: "migration",
        amount_gbp: amount,
        stage: "paid",
      });
    }

    // flag SLA addon
    if (kind === "support" && userId) {
      await db
        .from("revenue_accounts")
        .update({ sla_addon: true })
        .eq("company", customerEmail || "unknown");
    }

    if (invoiceWriteError) throw new Error(`workspace_invoice_sync_failed: ${invoiceWriteError}`);
  }

  if (type === "subscription.canceled" || type === "subscription.revoked") {
    const email = data.customer_email || data.customer?.email || "unknown";
    await db.from("revenue_accounts").update({ status: "churned" }).eq("company", email);
    if (data.id) {
      await db
        .from("workspace_subscriptions")
        .update({ state: "cancelled", updated_at: new Date().toISOString() })
        .eq("polar_subscription_id", data.id);
    }
  }

  if (type === "subscription.past_due") {
    const email = data.customer_email || data.customer?.email || "unknown";
    await db.from("revenue_accounts").update({ status: "paused" }).eq("company", email);
    if (data.id) {
      await db
        .from("workspace_subscriptions")
        .update({ state: "past_due", updated_at: new Date().toISOString() })
        .eq("polar_subscription_id", data.id);
    }
  }
}

export { authRouter, publicRouter };
