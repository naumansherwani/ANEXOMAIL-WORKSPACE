// ANEXOMAIL — ANEXOChat PHASE 1 SLICE API (service `anexochat`, port 3300)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/chat.ts /opt/anexomail/src/routes/chat.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/chat.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// FOUNDER LOCK:
//   1. Truth Supabase #4 mein — yeh file sirf chat_* RPC bulati hai
//   2. Gate DB ka chat_access(): founder + business/business_pro/AI. Basic/Pro = 403
//   3. Idempotent send: client_msg_id — duplicate send kabhi doosra message nahi
//   4. Koi fake state nahi: sent/delivered/read sirf DB rows se
//   5. Bun path = fallback/secondary. Rust /wt/* baad mein SAME contract par.
//
// Routes (mount: src/anexochat.ts -> app.use("/api/chat", chatRouter))
//   GET  /api/chat/bootstrap                auth — workspace + access + me
//   GET  /api/chat/conversations            auth — list + truthful health
//   POST /api/chat/conversations/direct     auth — {other_user_id}
//   GET  /api/chat/messages?c=&before=      auth — page (newest first)
//   POST /api/chat/messages                 auth — {conversation_id, client_msg_id, body, device}
//   POST /api/chat/receipts                 auth — {conversation_id, state, upto_seq}
//   POST /api/chat/typing                   auth — {conversation_id, typing}
//   POST /api/chat/presence                 auth — {device}
//   GET  /api/chat/presence?c=              auth — presence + real typing only
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
  console.error("chat: SUPABASE4_* missing — /api/chat/* will 503");
}

export const chatRouter = Router();

const fail = (res: any, e: any) =>
  res.status(500).json({ error: "db_error", detail: String(e?.message || e) });

async function requireUser(req: any, res: any): Promise<{ id: string; email: string } | null> {
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
  return { id: data.user.id, email: data.user.email || "" };
}

/** Gate DB se — frontend ka koi claim nahi maana jata. */
async function requireChat(
  req: any,
  res: any,
): Promise<{ id: string; email: string; workspace_id: string } | null> {
  const user = await requireUser(req, res);
  if (!user) return null;
  const gate = await db!.rpc("chat_access", { _user_id: user.id });
  if (gate.error) {
    fail(res, gate.error);
    return null;
  }
  if (gate.data !== true) {
    res.status(403).json({ error: "chat_not_entitled", plan_required: "business" });
    return null;
  }
  const ws = await db!.rpc("chat_ensure_workspace", {
    _user: user.id,
    _name: user.email ? user.email.split("@")[1] || "Workspace" : "Workspace",
  });
  if (ws.error) {
    fail(res, ws.error);
    return null;
  }
  return { ...user, workspace_id: String(ws.data) };
}

// ── bootstrap ───────────────────────────────────────────────────
chatRouter.get("/bootstrap", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  try {
    const members = await db!
      .from("chat_members")
      .select("user_id, display_name, role")
      .eq("workspace_id", me.workspace_id);
    if (members.error) throw members.error;
    res.json({
      user_id: me.id,
      email: me.email,
      workspace_id: me.workspace_id,
      members: members.data ?? [],
      transport: "bun",
    });
  } catch (e) {
    fail(res, e);
  }
});

// ── conversations ───────────────────────────────────────────────
chatRouter.get("/conversations", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const { data, error } = await db!.rpc("chat_conversation_list", {
    _ws: me.workspace_id,
    _me: me.id,
  });
  if (error) return fail(res, error);
  res.json({ conversations: data ?? [] });
});

chatRouter.post("/conversations/direct", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const other = String(req.body?.other_user_id || "");
  if (!other) return res.status(400).json({ error: "other_user_id_required" });
  const { data, error } = await db!.rpc("chat_direct_conversation", {
    _ws: me.workspace_id,
    _me: me.id,
    _other: other,
  });
  if (error) return fail(res, error);
  res.json({ conversation_id: data });
});

// ── messages ────────────────────────────────────────────────────
chatRouter.get("/messages", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.query?.c || "");
  if (!conv) return res.status(400).json({ error: "conversation_required" });
  const before = req.query?.before ? Number(req.query.before) : null;
  const limit = req.query?.limit ? Number(req.query.limit) : 80;
  const { data, error } = await db!.rpc("chat_messages_page", {
    _conv: conv,
    _me: me.id,
    _before_seq: Number.isFinite(before as number) ? before : null,
    _limit: Number.isFinite(limit) ? limit : 80,
  });
  if (error) return fail(res, error);
  res.json({ messages: data ?? [] });
});

chatRouter.post("/messages", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.body?.conversation_id || "");
  const clientId = String(req.body?.client_msg_id || "");
  const body = String(req.body?.body || "");
  if (!conv || !clientId || !body.trim()) {
    return res.status(400).json({ error: "conversation_id_client_msg_id_body_required" });
  }
  const { data, error } = await db!.rpc("chat_send", {
    _conv: conv,
    _sender: me.id,
    _client_msg_id: clientId,
    _body: body,
    _device: req.body?.device ? String(req.body.device) : null,
  });
  if (error) return fail(res, error);
  const row = Array.isArray(data) ? data[0] : data;
  res.json({ ...row, state: "sent" });
});

// ── receipts (delivered / read) ─────────────────────────────────
chatRouter.post("/receipts", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.body?.conversation_id || "");
  const state = String(req.body?.state || "");
  const upto = Number(req.body?.upto_seq);
  if (!conv || !Number.isFinite(upto)) {
    return res.status(400).json({ error: "conversation_id_upto_seq_required" });
  }
  const { data, error } = await db!.rpc("chat_mark", {
    _conv: conv,
    _user: me.id,
    _state: state === "delivered" ? "delivered" : "read",
    _upto: upto,
  });
  if (error) return fail(res, error);
  res.json({ marked: data ?? 0 });
});

// ── presence + typing (never guessed) ───────────────────────────
chatRouter.post("/presence", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const { error } = await db!.rpc("chat_presence_ping", {
    _ws: me.workspace_id,
    _user: me.id,
    _device: req.body?.device ? String(req.body.device) : null,
  });
  if (error) return fail(res, error);
  res.json({ ok: true });
});

chatRouter.post("/typing", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.body?.conversation_id || "");
  if (!conv) return res.status(400).json({ error: "conversation_required" });
  const { error } = await db!.rpc("chat_typing_ping", {
    _conv: conv,
    _user: me.id,
    _typing: req.body?.typing === true,
  });
  if (error) return fail(res, error);
  res.json({ ok: true });
});

chatRouter.get("/presence", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.query?.c || "");
  try {
    const presence = await db!
      .from("chat_presence")
      .select("user_id, device_label, last_seen_at")
      .eq("workspace_id", me.workspace_id);
    if (presence.error) throw presence.error;

    let typing: { user_id: string }[] = [];
    if (conv) {
      const t = await db!
        .from("chat_typing")
        .select("user_id, until")
        .eq("conversation_id", conv)
        .gt("until", new Date().toISOString());
      if (t.error) throw t.error;
      typing = (t.data ?? []).filter((r: any) => r.user_id !== me.id);
    }
    res.json({ presence: presence.data ?? [], typing });
  } catch (e) {
    fail(res, e);
  }
});

export default chatRouter;