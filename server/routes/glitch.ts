// ANEXOMAIL — Phase 47: GLITCH TRUTH -> EMAIL + LEO DIAGNOSE (Brain, port 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/glitch.ts /opt/anexomail/src/routes/glitch.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/glitch.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// Routes:
//   POST /api/public/glitch/report    frontend  — ek glitch (noise filter DB mein)
//   POST /api/public/glitch/trigger   frontend  — rage click / dead click
//   POST /api/public/glitch/sweep     cron      — pending alerts -> EMAIL (x-cron-secret)
//   GET  /api/founder/glitch/health   auth      — counters + top glitches
//
// Env: SUPABASE4_URL, SUPABASE4_SERVICE_ROLE_KEY, CRON_SECRET,
//      GLITCH_ALERT_TO         (founder inbox, e.g. hello@anexomail.com)
//      GLITCH_ALERT_FROM       (default noreply@anexomail.com)
//      GLITCH_SMTP_HOST/PORT   (default 127.0.0.1:25 — local Postfix, no auth)
//      GLITCH_MIN_SEVERITY     (default critical)
//      GLITCH_MIN_OCCURRENCES  (default 1 — 2+ = pehli chhoti hichki chup)
//      LEO_DIAGNOSE=true       (LEO se short diagnosis, email mein add)
//      LEO_URL                 (default http://127.0.0.1:3100/api/leo)
import { Router } from "express";
import net from "node:net";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const CRON_SECRET = process.env.CRON_SECRET || "";
// EMAIL channel (WhatsApp retired — founder decision 19 Aug 2026)
const MAIL_TO = process.env.GLITCH_ALERT_TO || "";
const MAIL_FROM = process.env.GLITCH_ALERT_FROM || "noreply@anexomail.com";
const SMTP_HOST = process.env.GLITCH_SMTP_HOST || "127.0.0.1";
const SMTP_PORT = Number(process.env.GLITCH_SMTP_PORT) || 25;
// Sirf yeh severity ya us se ooper email hoti hai — default 'critical'.
// Baki sab DB mein log rehta hai aur /api/founder/glitch/health par dikhta hai.
const MIN_SEVERITY = (process.env.GLITCH_MIN_SEVERITY || "critical").toLowerCase();
// Ek hi baar ki hichki par email nahi — jab tak occurrences is se kam hain, alert wait karta hai.
const MIN_OCCURRENCES = Math.max(1, Number(process.env.GLITCH_MIN_OCCURRENCES) || 1);
const LEO_DIAGNOSE = String(process.env.LEO_DIAGNOSE || "").toLowerCase() === "true";
const LEO_URL = process.env.LEO_URL || "http://127.0.0.1:3100/api/leo";
const SEV_RANK: Record<string, number> = { info: 0, warning: 1, error: 2, critical: 3 };
function alertWorthy(sev: string): boolean {
  return (SEV_RANK[String(sev).toLowerCase()] ?? 2) >= (SEV_RANK[MIN_SEVERITY] ?? 3);
}

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

// ---- LEO diagnose (AI feature nahi deta — sirf diagnosis line) ----
async function leoDiagnose(a: any): Promise<string | null> {
  if (!LEO_DIAGNOSE) return null;
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 12_000);
    const r = await fetch(LEO_URL, {
      method: "POST",
      headers: { "content-type": "application/json", "x-internal": "glitch" },
      signal: ctrl.signal,
      body: JSON.stringify({
        mode: "diagnose",
        stream: false,
        messages: [
          {
            role: "user",
            content:
              "Diagnose this production glitch in 3 short lines: likely cause, blast radius, first fix step. No marketing, no guessing beyond the data.\n\n" +
              JSON.stringify(
                {
                  severity: a.severity,
                  summary: a.summary,
                  route: a.route,
                  occurrences: a.occurrences,
                  kind: a.kind,
                  stack: String(a.stack || "").slice(0, 1500),
                },
                null,
                2,
              ),
          },
        ],
      }),
    });
    clearTimeout(t);
    if (!r.ok) return null;
    const text = await r.text();
    try {
      const j = JSON.parse(text);
      const out = j?.text || j?.reply || j?.message || j?.choices?.[0]?.message?.content;
      return out ? String(out).slice(0, 1200) : null;
    } catch {
      return text.slice(0, 1200) || null;
    }
  } catch {
    return null;
  }
}

// ---- minimal SMTP client (local Postfix, no auth, no deps) ----
function smtpSend(to: string, subject: string, body: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const sock = net.createConnection({ host: SMTP_HOST, port: SMTP_PORT });
    sock.setTimeout(15_000);
    let buf = "";
    const steps = [
      `EHLO anexomail.com`,
      `MAIL FROM:<${MAIL_FROM}>`,
      `RCPT TO:<${to}>`,
      `DATA`,
    ];
    let i = -1;
    let dataSent = false;
    const fail = (e: any) => {
      try {
        sock.destroy();
      } catch {
        /* ignore */
      }
      reject(new Error(String(e?.message || e).slice(0, 300)));
    };
    sock.on("error", fail);
    sock.on("timeout", () => fail(new Error("smtp_timeout")));
    sock.on("data", (chunk) => {
      buf += chunk.toString("utf8");
      if (!/\r?\n$/.test(buf)) return;
      const line = buf.trim().split(/\r?\n/).pop() || "";
      buf = "";
      const code = Number(line.slice(0, 3));
      if (code >= 400) return fail(new Error(`smtp_${line.slice(0, 120)}`));

      if (dataSent) {
        sock.write("QUIT\r\n");
        sock.end();
        return resolve();
      }
      i += 1;
      if (i < steps.length) return sock.write(steps[i] + "\r\n");

      // after DATA accepted (354) -> payload
      const headers = [
        `From: ANEXOMAIL Glitch Radar <${MAIL_FROM}>`,
        `To: ${to}`,
        `Subject: ${subject.replace(/[\r\n]/g, " ").slice(0, 180)}`,
        `Date: ${new Date().toUTCString()}`,
        `Auto-Submitted: auto-generated`,
        `X-ANEXOMAIL-Alert: glitch`,
        `MIME-Version: 1.0`,
        `Content-Type: text/plain; charset=utf-8`,
      ].join("\r\n");
      const safeBody = body.replace(/\r?\n\./g, "\r\n..").replace(/\n/g, "\r\n");
      dataSent = true;
      sock.write(`${headers}\r\n\r\n${safeBody}\r\n.\r\n`);
    });
  });
}

async function sendAlertEmail(a: any): Promise<{ ok: boolean; ref?: string; error?: string }> {
  if (!MAIL_TO) return { ok: false, error: "glitch_alert_to_not_configured" };
  const diag = await leoDiagnose(a);
  const subject = `[${String(a.severity).toUpperCase()}] ANEXOMAIL glitch — ${String(
    a.summary,
  ).slice(0, 90)}`;
  const body =
    alertText(a) +
    (diag ? `\n\n— LEO diagnosis —\n${diag}` : "") +
    `\n\nFounder radar: https://anexomail.com/app/founder/glitch`;
  try {
    await smtpSend(MAIL_TO, subject, body);
    return { ok: true, ref: `mail:${a.id}` };
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
  let skipped = 0;
  for (const a of (due as any[]) || []) {
    if (!alertWorthy(a.severity)) {
      skipped += 1;
      await db.rpc("glitch_alert_mark", {
        p_id: a.id,
        p_status: "muted",
        p_ref: null,
        p_error: `below_min_severity:${MIN_SEVERITY}`,
      });
      continue;
    }
    // ek-baar ki hichki par email nahi — occurrences threshold tak pending rehta hai
    if (Number(a.occurrences || 1) < MIN_OCCURRENCES) {
      skipped += 1;
      continue;
    }
    const out = await sendAlertEmail(a);
    if (out.ok) sent += 1;
    else failed += 1;
    await db.rpc("glitch_alert_mark", {
      p_id: a.id,
      p_status: out.ok ? "sent" : "failed",
      p_ref: out.ref || null,
      p_error: out.error || null,
    });
  }
  return res.json({
    due: (due as any[])?.length || 0,
    sent,
    failed,
    skipped,
    min_severity: MIN_SEVERITY,
    min_occurrences: MIN_OCCURRENCES,
    channel: MAIL_TO ? "email" : "unconfigured",
    leo_diagnose: LEO_DIAGNOSE,
  });
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
    channel: "email",
    email_configured: Boolean(MAIL_TO),
    alert_to: MAIL_TO || null,
    smtp: `${SMTP_HOST}:${SMTP_PORT}`,
    min_severity: MIN_SEVERITY,
    min_occurrences: MIN_OCCURRENCES,
    leo_diagnose: LEO_DIAGNOSE,
  });
});

export { publicRouter as glitchPublicRouter, founderRouter as founderGlitchRouter };
export default publicRouter;
