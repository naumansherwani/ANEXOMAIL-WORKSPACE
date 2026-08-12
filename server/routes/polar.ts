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
      product_price_id: resolvedProductId,
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
  // Polar dashboard secret is base64. Try decode; fallback raw.
  try {
    const b = Buffer.from(POLAR_WEBHOOK_SECRET, "base64");
    if (b.length > 16 && b.toString("base64") === POLAR_WEBHOOK_SECRET) return b;
  } catch {
    // ignore
  }
  return Buffer.from(POLAR_WEBHOOK_SECRET, "utf8");
}

publicRouter.post("/polar/webhook", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  if (!POLAR_WEBHOOK_SECRET) return res.status(401).json({ error: "webhook_not_configured" });

  const signatureHeader = String(req.headers["webhook-signature"] || "");
  const body = req.rawBody || JSON.stringify(req.body);
  if (!signatureHeader || !body) return res.status(400).json({ error: "missing_payload" });

  // Standard Webhooks signature: t=<ts>,v1=<base64sig>
  const parts: Record<string, string> = {};
  for (const piece of signatureHeader.split(",")) {
    const [k, v] = piece.trim().split("=");
    if (k && v) parts[k] = v;
  }
  const sigB64 = parts.v1;
  const timestamp = parts.t;
  if (!sigB64 || !timestamp) return res.status(401).json({ error: "invalid_signature_format" });

  const secret = getWebhookSecretBytes();
  const signedPayload = `${timestamp}.${body}`;
  const expected = createHmac("sha256", secret).update(signedPayload).digest("base64");

  try {
    if (!timingSafeEqual(Buffer.from(sigB64), Buffer.from(expected))) {
      return res.status(401).json({ error: "invalid_signature" });
    }
  } catch {
    return res.status(401).json({ error: "invalid_signature" });
  }

  // replay tolerance: 5 minutes
  const tsNum = Number(timestamp);
  if (!Number.isNaN(tsNum) && Math.abs(Date.now() / 1000 - tsNum) > 300) {
    return res.status(401).json({ error: "stale_webhook" });
  }

  const event = req.body as any;
  const eventId = event?.id || `${event?.type}_${Date.now()}`;

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

    // upsert revenue account for subscriptions
    if (kind === "plan" && userId && plan) {
      const seats = Number(meta.seats || 1);
      const mrr = isRecurring ? amount : 0;
      await db.from("revenue_accounts").upsert(
        {
          company: data.customer_email || "unknown",
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
        company: data.customer_email || "unknown",
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
        .eq("company", data.customer_email || "unknown");
    }
  }

  if (type === "subscription.canceled" || type === "subscription.revoked") {
    const email = data.customer_email || "unknown";
    await db.from("revenue_accounts").update({ status: "churned" }).eq("company", email);
  }

  if (type === "subscription.past_due") {
    const email = data.customer_email || "unknown";
    await db.from("revenue_accounts").update({ status: "paused" }).eq("company", email);
  }
}

export { authRouter, publicRouter };
