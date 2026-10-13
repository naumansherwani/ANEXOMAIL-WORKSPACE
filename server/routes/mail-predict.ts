// ANEXOMAIL — PHASE 12A: EMAIL WORD PREDICTION (Bun FALLBACK, port 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/mail-predict.ts /opt/anexomail/src/routes/mail-predict.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/mail-predict.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// FOUNDER LOCK:
//   1. PRIMARY = Rust /rpc/mail.predict (3200). Yeh Bun path SIRF fallback hai.
//   2. Truth Supabase #4: functions mail_predict / mail_predict_learn / mail_predict_event.
//   3. Assistive only — engine chhota phrase deta hai, email kabhi khud nahi bhejta.
//   4. Doosre user ka data kabhi nahi: SQL function user ke apne rows + global phrase book.
//   5. Engine na chale to 503 — frontend prediction chup-chaap band kar deta hai.
//
// Mount (src/index.ts):  app.use("/api/mail/predict", mailPredictRouter);
//   POST /api/mail/predict           auth — {prefix, formality?, limit?} -> {candidates}
//   POST /api/mail/predict/learn     auth — {text} -> {learned}
//   POST /api/mail/predict/event     auth — {action, prefix?} -> {ok}
import { Router } from "express";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";

let db: SupabaseClient | null = null;
if (SUPABASE_URL && SERVICE_KEY) {
  db = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
} else {
  console.error("mail-predict: SUPABASE4_* missing — /api/mail/predict will 503");
}

async function requireUser(req: any, res: any): Promise<{ id: string } | null> {
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
  return { id: data.user.id };
}

export const mailPredictRouter = Router();

mailPredictRouter.post("/", async (req, res) => {
  const me = await requireUser(req, res);
  if (!me) return;
  const prefix = String(req.body?.prefix || "").slice(0, 400);
  if (!prefix.trim()) {
    res.json({ candidates: [] });
    return;
  }
  const formality = ["any", "formal", "casual"].includes(String(req.body?.formality))
    ? String(req.body.formality)
    : "any";
  const limit = Math.min(Math.max(Number(req.body?.limit) || 3, 1), 5);
  const { data, error } = await db!.rpc("mail_predict", {
    _user: me.id,
    _prefix: prefix,
    _formality: formality,
    _limit: limit,
  });
  if (error) {
    res.status(500).json({ error: "predict_failed", detail: error.message });
    return;
  }
  res.json({ candidates: data ?? [] });
});

mailPredictRouter.post("/learn", async (req, res) => {
  const me = await requireUser(req, res);
  if (!me) return;
  const text = String(req.body?.text || "").slice(0, 4000);
  if (text.trim().length < 12) {
    res.json({ learned: 0 });
    return;
  }
  const { data, error } = await db!.rpc("mail_predict_learn", { _user: me.id, _text: text });
  if (error) {
    res.status(500).json({ error: "learn_failed", detail: error.message });
    return;
  }
  res.json({ learned: Number(data ?? 0) });
});

mailPredictRouter.post("/event", async (req, res) => {
  const me = await requireUser(req, res);
  if (!me) return;
  const action = String(req.body?.action || "");
  if (!["accept", "dismiss", "conflict"].includes(action)) {
    res.status(400).json({ error: "bad_action" });
    return;
  }
  const { error } = await db!.rpc("mail_predict_event", {
    _user: me.id,
    _action: action,
    _prefix: req.body?.prefix ? String(req.body.prefix).slice(0, 120) : null,
  });
  if (error) {
    res.status(500).json({ error: "event_failed", detail: error.message });
    return;
  }
  res.json({ ok: true });
});

export default mailPredictRouter;
