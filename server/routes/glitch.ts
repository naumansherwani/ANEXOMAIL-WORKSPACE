// ANEXOMAIL — Phase 47: GLITCH TRUTH -> WHATSAPP (Server 2 / Brain, port 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/glitch.ts /opt/anexomail/src/routes/glitch.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/glitch.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// Routes:
//   POST /api/public/glitch/report    frontend  — ek glitch (noise filter DB mein)
//   POST /api/public/glitch/trigger   frontend  — rage click / dead click
//   POST /api/public/glitch/sweep     cron      — pending alerts -> WhatsApp (x-cron-secret)
//   GET  /api/founder/glitch/health   auth      — counters + top glitches
//
// Env: SUPABASE4_URL, SUPABASE4_SERVICE_ROLE_KEY, CRON_SECRET,
//      WHATSAPP_TOKEN, WHATSAPP_PHONE_ID, WHATSAPP_TO,
//      WHATSAPP_TEMPLATE (optional; na ho to plain text message)
import { Router } from "express";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const CRON_SECRET = process.env.CRON_SECRET || "";
const WA_TOKEN = process.env.WHATSAPP_TOKEN || "";
const WA_PHONE_ID = process.env.WHATSAPP_PHONE_ID || "";
const WA_TO = process.env.WHATSAPP_TO || "";
const WA_TEMPLATE = process.env.WHATSAPP_TEMPLATE || "";
const WA_API = "https://graph.facebook.com/v21.0";

let db: SupabaseClient | null = null;
if (SUPABASE_URL && SERVICE_KEY) {
  db = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
} else {
  console.error("glitch: SUPABASE4_* env missing — routes will 503");
}

const publicRouter = Router();
const founderRouter = Router();

// chhota in-memory flood guard: ek IP se 60 report/min se zyada nahi
const hits = new Map<string, { n: number; at: number }>();
function floodOk(ip: string): boolean {
  const now = Date.now();
  const cur = hits.get(ip);
  if (!cur || now - cur.at > 60_000) {
    hits.set(ip, { n: 1, at: now });
    return true;
  }
  cur.n += 1;
  return cur.n <= 60;
}

function clientIp(req: any): string {
  return String(req.headers["x-forwarded-for"] || req.ip || "unknown").split(",")[0].trim();
}

publicRouter.post("/glitch/report", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  if (!floodOk(clientIp(req))) return res.status(429).json({ error: "rate_limited" });

  const b = req.body || {};
  if (!b.kind || !b.message) return res.status(400).json({ error: "kind_and_message_required" });

  const { data, error } = await db.rpc("glitch_log", {
    p_kind: String(b.kind).slice(0, 40),
    p_message: String(b.message).slice(0, 1000),
    p_severity: String(b.severity || "error"),
    p_route: b.route ? String(b.route).slice(0, 200) : null,
    p_fingerprint: b.fingerprint ? String(b.fingerprint).slice(0, 200) : null,
    p_stack: b.stack ? String(b.stack).slice(0, 6000) : null,
    p_session_id: b.session_id ? String(b.session_id).slice(0, 120) : null,
    p_recording_url: b.recording_url ? String(b.recording_url).slice(0, 500) : null,
    p_user_id: null,
    p_meta: typeof b.meta === "object" && b.meta ? b.meta : {},
  });
  if (error) {
    console.error("[glitch.report]", error.message);
    return res.status(500).json({ error: "log_failed" });
  }
  return res.json(data);
});

publicRouter.post("/glitch/trigger", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  if (!floodOk(clientIp(req))) return res.status(429).json({ error: "rate_limited" });

  const b = req.body || {};
  if (!b.trigger_type) return res.status(400).json({ error: "trigger_type_required" });

  const { data, error } = await db.rpc("glitch_trigger_log", {
    p_trigger_type: String(b.trigger_type).slice(0, 40),
    p_route: b.route ? String(b.route).slice(0, 200) : null,
    p_target_label: b.target_label ? String(b.target_label).slice(0, 200) : null,
    p_hit_count: Number(b.hit_count) || 1,
    p_session_id: b.session_id ? String(b.session_id).slice(0, 120) : null,
    p_recording_url: b.recording_url ? String(b.recording_url).slice(0, 500) : null,
    p_user_id: null,
    p_meta: typeof b.meta === "object" && b.meta ? b.meta : {},
  });
  if (error) {
    console.error("[glitch.trigger]", error.message);
    return res.status(500).json({ error: "trigger_failed" });
  }
  return res.json(data);
});

function alertText(a: any): string {
  const when = new Date(a.last_seen || Date.now()).toISOString().replace("T", " ").slice(0, 19);
  const lines = [
    `ANEXOMAIL glitch (${a.severity})`,
    `${a.summary}`,
    `Page: ${a.route || "unknown"}`,
    `Hits: ${a.occurrences} · Last: ${when} UTC`,
  ];
  if (a.recording_url) lines.push(`Replay: ${a.recording_url}`);
  return lines.join("\n");
}

async function sendWhatsApp(a: any): Promise<{ ok: boolean; ref?: string; error?: string }> {
  if (!WA_TOKEN || !WA_PHONE_ID || !WA_TO) return { ok: false, error: "whatsapp_not_configured" };

  const body = WA_TEMPLATE
    ? {
        messaging_product: "whatsapp",
        to: WA_TO,
        type: "template",
        template: {
          name: WA_TEMPLATE,
          language: { code: "en" },
          components: [
            {
              type: "body",
              parameters: [
                { type: "text", text: String(a.severity) },
                { type: "text", text: String(a.summary).slice(0, 200) },
                { type: "text", text: String(a.route || "unknown") },
                { type: "text", text: String(a.occurrences) },
              ],
            },
          ],
        },
      }
    : {
        messaging_product: "whatsapp",
        to: WA_TO,
        type: "text",
        text: { preview_url: false, body: alertText(a) },
      };

  try {
    const r = await fetch(`${WA_API}/${WA_PHONE_ID}/messages`, {
      method: "POST",
      headers: { authorization: `Bearer ${WA_TOKEN}`, "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    const text = await r.text();
    if (!r.ok) return { ok: false, error: `whatsapp_${r.status}: ${text.slice(0, 300)}` };
    let ref: string | undefined;
    try {
      ref = JSON.parse(text)?.messages?.[0]?.id;
    } catch {
      /* ref optional */
    }
    return { ok: true, ref };
  } catch (e: any) {
    return { ok: false, error: String(e?.message || e).slice(0, 300) };
  }
}

// cron: har minute chalao -> 2 min SLA
publicRouter.post("/glitch/sweep", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  if (!CRON_SECRET || req.headers["x-cron-secret"] !== CRON_SECRET) {
    return res.status(401).json({ error: "unauthorized" });
  }

  const { data: due, error } = await db.rpc("glitch_alert_due", { p_limit: 10 });
  if (error) {
    console.error("[glitch.sweep]", error.message);
    return res.status(500).json({ error: "due_failed" });
  }

  let sent = 0;
  let failed = 0;
  for (const a of (due as any[]) || []) {
    const out = await sendWhatsApp(a);
    if (out.ok) sent += 1;
    else failed += 1;
    await db.rpc("glitch_alert_mark", {
      p_id: a.id,
      p_status: out.ok ? "sent" : "failed",
      p_ref: out.ref || null,
      p_error: out.error || null,
    });
  }
  return res.json({ due: (due as any[])?.length || 0, sent, failed });
});

founderRouter.get("/glitch/health", async (req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const raw = String(req.headers.authorization || "");
  const token = raw.startsWith("Bearer ") ? raw.slice(7) : "";
  if (!token) return res.status(401).json({ error: "unauthorized" });
  const { data: u, error: ue } = await db.auth.getUser(token);
  if (ue || !u?.user) return res.status(401).json({ error: "unauthorized" });

  const { data, error } = await db.rpc("glitch_health");
  if (error) return res.status(500).json({ error: "health_failed" });
  return res.json({
    ...(data as object),
    whatsapp_configured: Boolean(WA_TOKEN && WA_PHONE_ID && WA_TO),
    template: WA_TEMPLATE || null,
  });
});

export { publicRouter as glitchPublicRouter, founderRouter as founderGlitchRouter };
export default publicRouter;
