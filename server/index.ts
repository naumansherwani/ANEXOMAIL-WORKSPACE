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

// ---- JSON APIs ----
app.use(express.json({ limit: "2mb" }));

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

// Phase 9 Compose Studio — mount BEFORE mailRouter so its paths win
app.use("/api/mail", mailComposeRouter);
app.use("/api/mail", mailRouter);

// ---- 404 handler: HAMESHA sab routers ke BAAD (last middleware) ----
app.use((_req, res) => res.status(404).json({ error: "not_found" }));

app.listen(PORT, "0.0.0.0", () => {
  console.log(
    `ANEXOMAIL Brain LIVE on port ${PORT} (Leo + auth + workspace + compose + contacts + calendar + crm + org + ai + founder + integrations + settings + admin)`,
  );
});
