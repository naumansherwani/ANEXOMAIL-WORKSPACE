// ============================================================================
// ANEXOMAIL — Server 2 (Brain, port 3100) MAIN ENTRY
//
// NANO COMMAND (server par yeh chalao, phir select-all -> paste -> Ctrl+O, Ctrl+X):
//   cp /opt/anexomail/src/index.ts /opt/anexomail/src/index.ts.bak.$(date +%s)
//   nano /opt/anexomail/src/index.ts
//
// Phir:
//   pm2 restart anexomail-leo && pm2 logs anexomail-leo --lines 40 --nostream
//
// FIX (Phase 22 + 23): integrations aur settings routers ab 404 handler se
// PEHLE mount hote hain. Pehle 404 handler upar tha, is liye sab 404 aa raha tha.
// ============================================================================
import express from "express";
import leoRouter from "./routes/leo.js";
import { support } from "./routes/support";
import { authRouter } from "./routes/auth";
import { mailRouter } from "./routes/mail";
import { mailComposeRouter } from "./routes/mail-compose";
import { mailPredictRouter } from "./routes/mail-predict";

import { contactsRouter } from "./routes/contacts";
import { dashboardRouter } from "./routes/dashboard";
import { workspaceRouter } from "./routes/workspace";
import { calendar } from "./routes/calendar";
import { crm } from "./routes/crm";
import { org } from "./routes/org";
import { ai } from "./routes/ai";
import { founder } from "./routes/founder";
import { aiStudio } from "./routes/ai-studio";
import { aiAutomation } from "./routes/ai-automation";
import integrationsRouter, { founderIntegrationsRouter } from "./routes/integrations";
import settingsRouter, { founderSettingsRouter } from "./routes/settings";
import adminRouter, { founderAdminRouter } from "./routes/admin";
import securityRouter, { founderSecurityRouter } from "./routes/security";
import perfRouter, { founderPerfRouter } from "./routes/perf";
import revenuePublicRouter, { founderRevenueRouter } from "./routes/revenue";
import handoffRouter from "./routes/handoff";
import aiCreditsRouter, { founderAiCreditsRouter } from "./routes/ai-credits";
import { trialRouter, trialCronRouter } from "./routes/trial";
import releasePublicRouter, { founderReleaseRouter, outboxRouter } from "./routes/release";
import { authRouter as polarAuthRouter, publicRouter as polarPublicRouter } from "./routes/polar";
import { moveinRouter, moveinPublicRouter, founderMoveinRouter } from "./routes/movein";
import billingSupportRouter from "./routes/billing-support";
import { glitchPublicRouter, founderGlitchRouter } from "./routes/glitch";
import {
  storageRouter,
  internalStorageRouter,
  founderStorageRouter,
} from "./routes/storage";
import {
  billingSyncAuthRouter,
  billingSyncPublicRouter,
} from "./routes/billing-sync";

const PORT = Number(process.env.PORT) || 3100;

const app = express();

app.disable("x-powered-by");

// ---- LEO bridge: native (Request -> Response) handler inside Express ----
app.use("/api/leo", async (req, res) => {
  try {
    const chunks: Buffer[] = [];
    if (req.method !== "GET" && req.method !== "HEAD") {
      for await (const c of req) chunks.push(c as Buffer);
    }
    const headers = new Headers();
    for (const [k, v] of Object.entries(req.headers)) {
      if (typeof v === "string") headers.set(k, v);
      else if (Array.isArray(v)) headers.set(k, v.join(", "));
    }
    const url = `http://127.0.0.1:${PORT}/api/leo${req.url === "/" ? "" : req.url}`;
    const request = new Request(url, {
      method: req.method,
      headers,
      body: chunks.length ? Buffer.concat(chunks) : undefined,
    });

    const out: Response = await leoRouter(request);
    res.status(out.status);
    out.headers.forEach((val, key) => {
      if (key.toLowerCase() !== "content-encoding") res.setHeader(key, val);
    });

    if (!out.body) return res.end();
    const reader = out.body.getReader();
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      res.write(Buffer.from(value));
      // @ts-ignore flush for SSE when compression middleware absent
      if (typeof (res as any).flush === "function") (res as any).flush();
    }
    res.end();
  } catch (e) {
    console.error("[leo-bridge]", e);
    if (!res.headersSent) res.status(500).json({ error: "leo_bridge_failed" });
    else res.end();
  }
});

// ---- JSON APIs (raw body captured for Polar webhook HMAC) ----
app.use(
  express.json({
    limit: "2mb",
    verify: (req: any, _res, buf) => {
      req.rawBody = buf;
    },
  }),
);

app.get(["/health", "/api/health"], (_req, res) =>
  res.json({ ok: true, service: "ANEXOMAIL Brain", ai: "Leo" }),
);

app.use("/api/auth", authRouter);
app.use("/api/workspace", workspaceRouter);
app.use("/api/dashboard", dashboardRouter);
app.use("/api", support);
// Phase 10 Contacts & Communication Intelligence
app.use("/api", contactsRouter);
// Phase 11 Calendar + Work
app.use("/api", calendar);
// Phase 13 AI CRM (/api/crm/*, /api/founder/crm/*)
app.use("/api", crm);
// Phase 15 Organization Center (/api/org/*, /api/founder/org/*)
app.use("/api", org);
// Phase 16 AI Workspace (/api/ai/*)
app.use("/api", ai);
// Wiring Page 2 — AI Studio + AI Automation
app.use("/api", aiStudio);
app.use("/api", aiAutomation);
// Wiring Page 1 — Founder Command Deck + AI Email Center (/api/founder/*)
app.use("/api", founder);

// Phase 22 Integrations Platform (/api/integrations/*, /api/founder/integrations/*)
app.use("/api/integrations", integrationsRouter);
app.use("/api/founder", founderIntegrationsRouter);

// Phase 23 Settings Center (/api/settings/*, /api/founder/settings/*)
app.use("/api/settings", settingsRouter);
app.use("/api/founder", founderSettingsRouter);

// Phase 25 Admin Center (/api/admin/*, /api/founder/admin/*)
app.use("/api/admin", adminRouter);
app.use("/api/founder", founderAdminRouter);

// Phase 26 Security Platform (/api/security/*, /api/founder/security/*)
app.use("/api/security", securityRouter);
app.use("/api/founder", founderSecurityRouter);

// Phase 27 Performance Platform (/api/perf/*, /api/founder/perf/*)
app.use("/api/perf", perfRouter);
app.use("/api/founder", founderPerfRouter);

// Phase 28 — Revenue Engine (public lead intake + founder view)
app.use("/api/public", revenuePublicRouter);
app.use("/api/founder", founderRevenueRouter);

// Phase 31 AI Credit Engine (/api/ai/credits/*, /api/founder/ai/credits/*)
// NOTE: aiCreditsRouter ko `app.use("/api", ai)` ke BAAD mount karo — yeh
// zyada specific path hai, is liye jeetta hai.
app.use("/api/ai/credits", aiCreditsRouter);
app.use("/api/founder", founderAiCreditsRouter);

// Phase 12A — inline word prediction (Bun FALLBACK; PRIMARY = Rust /rpc/mail.predict)
app.use("/api/mail/predict", mailPredictRouter);
// Phase 9 Compose Studio — mount BEFORE mailRouter so its paths win
app.use("/api/mail", mailComposeRouter);

// Phase 30 — offline outbox send (idempotency-key based)
app.use("/api/mail", outboxRouter);
// Phase 28 — Cross-Platform: device handoff (drafts + cursor across devices)
app.use("/api/mail", handoffRouter);
app.use("/api/mail", mailRouter);

// Phase 30 — Production & Founder Lock (public status + founder release gate)
app.use("/api/public", releasePublicRouter);
app.use("/api/founder", founderReleaseRouter);

// Phase 32 — Trial lifecycle (48h · mandatory claim · passkey/recovery · freeze)
// account_state() = only authority. Cron sweep: POST /api/public/trial/sweep
app.use("/api/trial", trialRouter);
app.use("/api/public", trialCronRouter);

// Phase 33 — Polar Checkout + Webhook
// /api/billing/checkout (auth) + /api/public/polar/webhook (verified)
app.use("/api/billing", polarAuthRouter);
app.use("/api/public", polarPublicRouter);
app.use("/api/founder", billingSupportRouter);

// Phase 36 — STATE SYNC ENGINE (Supabase = truth, Polar = messenger)
// /api/billing/intent · /state · /intent/:id · /state-health (auth)
// /api/public/billing/sync (cron)
app.use("/api/billing", billingSyncAuthRouter);
app.use("/api/public", billingSyncPublicRouter);

// Phase 37 — MOVE-IN OPERATIONS & REVENUE COCKPIT (money machine)
// public: /api/public/movein/request · /capacity · /sweep (cron)
// customer: /api/movein/deal · /deal/:id
// founder: /api/founder/movein/cockpit · /deal/:id · /transition · /schedule ·
//          /arm · /mailbox · /dns · /runbook · /exception · /rollback · /invoice
app.use("/api/public", moveinPublicRouter);
app.use("/api/movein", moveinRouter);
app.use("/api/founder", founderMoveinRouter);

// Phase 47 — GLITCH TRUTH -> WHATSAPP
// public: /api/public/glitch/report · /trigger · /sweep (cron)
// founder: /api/founder/glitch/health
app.use("/api/public", glitchPublicRouter);
app.use("/api/founder", founderGlitchRouter);

// Phase 48 — INBOX STORAGE & QUOTA (logical quota, storage abstraction)
// user:     /api/storage/state · /preflight · /reserve · /commit · /release
// internal: /api/internal/storage/accept · /commit   (x-cron-secret, Postfix hook)
// founder:  /api/founder/storage/volumes
app.use("/api/storage", storageRouter);
app.use("/api/internal", internalStorageRouter);
app.use("/api/founder", founderStorageRouter);

// ANEXOChat: /api/chat/* Brain se HATA diya gaya hai — apni service `anexochat`
// (src/anexochat.ts, port 3300). Caddy: /api/chat/* -> 127.0.0.1:3300.
// Yahan dobara mount kabhi nahi (NO DUPLICATE rule).

// ---- 404 handler: HAMESHA sab routers ke BAAD (last middleware) ----
app.use((_req, res) => res.status(404).json({ error: "not_found" }));

app.listen(PORT, "0.0.0.0", () => {
  console.log(
    `ANEXOMAIL Brain LIVE on port ${PORT} (Leo + auth + workspace + compose + contacts + calendar + crm + org + ai + founder + integrations + settings + admin)`,
  );
});
