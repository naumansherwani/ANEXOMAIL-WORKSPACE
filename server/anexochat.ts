// ============================================================================
// ANEXOCHAT — dedicated service (PM2 name `anexochat`, port 3300)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/anexochat.ts /opt/anexomail/src/anexochat.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/anexochat.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// START:
//   pm2 start /root/.bun/bin/bun --name anexochat --cwd /opt/anexomail -- run src/anexochat.ts
//   pm2 save
//
// FOUNDER LOCK:
//   1. ANEXOChat ka saara data isi process se guzarta hai (Brain 3100 se alag)
//   2. Gate DB ka chat_access() — founder + business/business_pro/AI. Basic/Pro 403
//   3. Bun = FALLBACK ONLY. PRIMARY Rust engine hai: /rpc/chat.* (tcp 3200) +
//      WebTransport/QUIC (udp 3443). Contract dono par bilkul same.
//   4. Truth Supabase #4 mein (RLS enabled) — yeh service sirf RPC bulati hai
// ============================================================================
import express from "express";
import chatRouter from "./routes/chat";

const PORT = Number(process.env.ANEXOCHAT_PORT) || 3300;

const app = express();
app.disable("x-powered-by");
app.use(express.json({ limit: "2mb" }));

// Probe: koi data nahi, sirf zinda hone ka sabooth (Caddy/PM2 ke liye)
app.get("/health", (_req, res) =>
  res.json({ service: "anexochat", port: PORT, transport: "bun", ok: true }),
);
app.get("/api/chat/health", (_req, res) =>
  res.json({ service: "anexochat", port: PORT, transport: "bun", ok: true }),
);

app.use("/api/chat", chatRouter);

// 404 hamesha last
app.use((_req, res) => res.status(404).json({ error: "not_found" }));

app.listen(PORT, "0.0.0.0", () => {
  console.log(`ANEXOCHAT LIVE on port ${PORT} (chat + presence + receipts, gate=chat_access)`);
});