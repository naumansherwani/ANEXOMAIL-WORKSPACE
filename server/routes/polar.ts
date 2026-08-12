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

const PRODUCT_KEYS = [
  "POLAR_PRODUCT_MOVEIN_1_5",
  "POLAR_PRODUCT_MOVEIN_6_15",
  "POLAR_PRODUCT_MOVEIN_16_29",
  "POLAR_PRODUCT_MOVEIN_30PLUS",
  "POLAR_PRODUCT_PRIORITY_SUPPORT",
  "POLAR_PRODUCT_PLAN_BASIC",
  "POLAR_PRODUCT_PLAN_PRO",
  "POLAR_PRODUCT_PLAN_BUSINESS",
] as const;

function productMap(): Record<string, string> {
  const map: Record<string, string> = {};
  for (const key of PRODUCT_KEYS) {
    const id = process.env[key];
    if (id) map[key] = id;
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
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  if (!POLAR_TOKEN) return res.status(503).json({ error: "polar_not_configured" });

  const userId = await requireUser(req, res);
  if (!userId) return;

  const { product_id, product_key, email, seats = 1 } = req.body || {};
  const map = productMap();
  const resolvedProductId = product_id || (product_key ? map[product_key] : undefined);
  if (!resolvedProductId) {
    return res.status(400).json({ error: "product_required", configured: map });
  }

  try {
    const successUrl = SUCCESS_URL.replace(/\{CHECKOUT_ID\}/g, "{CHECKOUT_ID}");
    const payload: any = {
      products: [resolvedProductId],
      success_url: successUrl,
      external_customer_id: userId,
      metadata: { anexomail_user_id: userId, seats: String(seats) },
    };
    if (email) payload.customer_email = email;

    const checkout = await polarFetch("/v1/checkouts/", {
      method: "POST",
      body: JSON.stringify(payload),
    });

    // persist session for verification + idempotency
    await db.from("polar_checkout_sessions").insert({
      polar_checkout_id: checkout.id,
      user_id: userId,
      product_id: resolvedProductId,
      product_key: product_key || null,
      url: checkout.url,
      status: checkout.status || "open",
      payload: checkout,
    });

    res.json({ checkout_id: checkout.id, url: checkout.url });
  } catch (e: any) {
    console.error("[polar checkout]", e);
    res.status(502).json({ error: "checkout_failed", detail: e.message });
  }
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
    const { data: row } = await db
      .from("polar_checkout_sessions")
      .select("user_id")
      .eq("polar_checkout_id", id)
      .single();
    if (row && row.user_id !== userId) {
      return res.status(403).json({ error: "forbidden" });
    }
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
    return res.status(401).json({ error: "invalid_signature" });
  }

  // replay tolerance: 5 minutes
  const tsNum = Number(timestamp);
  if (!Number.isNaN(tsNum) && Math.abs(Date.now() / 1000 - tsNum) > 300) {
    return res.status(401).json({ error: "stale_webhook" });
  }

  const event = req.body as any;
  const eventId = webhookId;

  // idempotency: already seen?
  const { data: existing } = await db
    .from("polar_webhook_events")
    .select("id")
    .eq("polar_event_id", eventId)
    .maybeSingle();
  if (existing) return res.json({ ok: true, duplicate: true });

  // log event first
  await db.from("polar_webhook_events").insert({
    polar_event_id: eventId,
    type: event?.type || "unknown",
    payload: event,
  });

  // process business events
  try {
    await processWebhookEvent(event);
  } catch (e: any) {
    console.error("[polar webhook process]", e);
    // still 200 — acknowledge receipt; processing failure is our problem
  }

  res.json({ ok: true });
});

async function processWebhookEvent(event: any) {
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
    const meta = data.metadata || {};
    const userId = meta.anexomail_user_id;
    const product = data.product || {};
    const productMeta = product.metadata || {};
    const { kind, plan, band } = kindFromMetadata(productMeta);
    const amount = (data.amount || 0) / 100; // Polar amounts are in pence/cents
    const isRecurring = data.subscription_id ? true : false;
    const customerEmail =
      data.customer_email || data.customer?.email || data.customer?.billing_address?.email || null;
    const responseHours: Record<string, number> = { basic: 72, pro: 48, business: 24 };

    // Polar sends the provider receipt/invoice. Supabase stores our immutable proof.
    await db.from("billing_event_receipts").upsert(
      {
        polar_event_id: event?.id || `order_paid_${data.id}`,
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

    if (userId) {
      const invoiceNumber = String(
        data.invoice_number || data.order_number || data.id || event?.id,
      );
      await db.from("workspace_invoices").upsert(
        {
          user_id: userId,
          number: invoiceNumber,
          state: "paid",
          subtotal: Number(data.subtotal_amount ?? data.amount ?? 0) / 100,
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
    }

    // upsert revenue account for subscriptions
    if (kind === "plan" && userId && plan) {
      const seats = Number(meta.seats || 1);
      const mrr = isRecurring ? amount : 0;
      await db.from("workspace_subscriptions").upsert(
        {
          user_id: userId,
          plan,
          state: "active",
          seats,
          seats_used: 1,
          price_per_seat: seats > 0 ? amount / seats : amount,
          currency: String(data.currency || "GBP").toUpperCase(),
          interval: "month",
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
      await db.from("revenue_accounts").upsert(
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
