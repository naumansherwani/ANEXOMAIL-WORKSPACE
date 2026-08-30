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
//   5. Bun path = FALLBACK ONLY. PRIMARY = Rust /rpc/chat.* + WebTransport/QUIC
//      (server/rust/main.rs). Frontend pehle Rust, phir yeh.
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
    _reply_to: req.body?.reply_to_id ? String(req.body.reply_to_id) : null,
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

// ── PHASE 3: message engine (reactions / edit / delete) ─────────
chatRouter.post("/react", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const msg = String(req.body?.message_id || "");
  const emoji = String(req.body?.emoji || "");
  if (!msg || !emoji) return res.status(400).json({ error: "message_id_emoji_required" });
  const { data, error } = await db!.rpc("chat_react", {
    _msg: msg,
    _user: me.id,
    _emoji: emoji,
  });
  if (error) return fail(res, error);
  res.json({ reactions: data ?? [] });
});

chatRouter.post("/messages/edit", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const msg = String(req.body?.message_id || "");
  const body = String(req.body?.body || "");
  if (!msg || !body.trim()) return res.status(400).json({ error: "message_id_body_required" });
  const { data, error } = await db!.rpc("chat_edit_message", {
    _msg: msg,
    _user: me.id,
    _body: body,
  });
  if (error) return fail(res, error);
  res.json(Array.isArray(data) ? data[0] : data);
});

chatRouter.post("/messages/delete", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const msg = String(req.body?.message_id || "");
  if (!msg) return res.status(400).json({ error: "message_id_required" });
  const { data, error } = await db!.rpc("chat_delete_message", { _msg: msg, _user: me.id });
  if (error) return fail(res, error);
  res.json(Array.isArray(data) ? data[0] : data);
});

// ── PHASE 3: work objects (task / promise / decision) ───────────
chatRouter.post("/work", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.body?.conversation_id || "");
  const kind = String(req.body?.kind || "");
  const title = String(req.body?.title || "");
  if (!conv || !kind || !title.trim()) {
    return res.status(400).json({ error: "conversation_id_kind_title_required" });
  }
  const { data, error } = await db!.rpc("chat_work_create", {
    _conv: conv,
    _user: me.id,
    _msg: req.body?.message_id ? String(req.body.message_id) : null,
    _kind: kind,
    _title: title,
    _due: req.body?.due_at ? String(req.body.due_at) : null,
  });
  if (error) return fail(res, error);
  res.json({ id: data });
});

chatRouter.get("/work", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.query?.c || "");
  if (!conv) return res.status(400).json({ error: "conversation_required" });
  const { data, error } = await db!.rpc("chat_work_list", { _conv: conv, _user: me.id });
  if (error) return fail(res, error);
  res.json({ items: data ?? [] });
});

chatRouter.post("/work/state", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const item = String(req.body?.item_id || "");
  const state = String(req.body?.state || "");
  if (!item || !state) return res.status(400).json({ error: "item_id_state_required" });
  const { error } = await db!.rpc("chat_work_set_state", {
    _item: item,
    _user: me.id,
    _state: state,
  });
  if (error) return fail(res, error);
  res.json({ ok: true });
});

chatRouter.post("/conversations/state", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.body?.conversation_id || "");
  const state = String(req.body?.state || "");
  if (!conv || !state) return res.status(400).json({ error: "conversation_id_state_required" });
  const { data, error } = await db!.rpc("chat_conversation_set_state", {
    _conv: conv,
    _user: me.id,
    _state: state,
    _note: req.body?.note ? String(req.body.note) : null,
  });
  if (error) return fail(res, error);
  res.json(Array.isArray(data) ? data[0] : data);
});

// ── PHASE 6: unread truth for the ANEXOMAIL sidebar badge ───────
chatRouter.get("/unread", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const { data, error } = await db!.rpc("chat_unread_total", { _user: me.id });
  if (error) return fail(res, error);
  const row = Array.isArray(data) ? data[0] : data;
  res.json(row ?? { unread: 0, conversations: 0 });
});

// ── PHASE 8-10: parity (hide / pin / prefs / search) ────────────
chatRouter.post("/messages/hide", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const msg = String(req.body?.message_id || "");
  if (!msg) return res.status(400).json({ error: "message_id_required" });
  const { error } = await db!.rpc("chat_message_hide", { _msg: msg, _user: me.id });
  if (error) return fail(res, error);
  res.json({ hidden: true });
});

chatRouter.post("/messages/pin", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const msg = String(req.body?.message_id || "");
  if (!msg) return res.status(400).json({ error: "message_id_required" });
  const { data, error } = await db!.rpc("chat_pin_message", {
    _msg: msg,
    _user: me.id,
    _pin: req.body?.pin !== false,
  });
  if (error) return fail(res, error);
  res.json(Array.isArray(data) ? data[0] : data);
});

chatRouter.post("/conversations/prefs", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.body?.conversation_id || "");
  if (!conv) return res.status(400).json({ error: "conversation_required" });
  const { data, error } = await db!.rpc("chat_conversation_prefs", {
    _conv: conv,
    _user: me.id,
    _mute_minutes:
      req.body?.mute_minutes === undefined || req.body?.mute_minutes === null
        ? null
        : Number(req.body.mute_minutes),
    _archived:
      req.body?.archived === undefined || req.body?.archived === null
        ? null
        : Boolean(req.body.archived),
  });
  if (error) return fail(res, error);
  res.json(Array.isArray(data) ? data[0] : data);
});

chatRouter.get("/search", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const q = String(req.query?.q || "");
  if (!q.trim()) return res.json({ results: [] });
  const { data, error } = await db!.rpc("chat_search_messages", {
    _user: me.id,
    _q: q,
    _limit: 40,
  });
  if (error) return fail(res, error);
  res.json({ results: data ?? [] });
});

// ── PHASE 7: ANEXOVideoChat signalling (Business Pro only) ──────
chatRouter.get("/video/gate", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const { data, error } = await db!.rpc("chat_video_allowed", { _user_id: me.id });
  if (error) return fail(res, error);
  res.json({ allowed: data === true, plan_required: "business_pro" });
});

chatRouter.post("/video/signal", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.body?.conversation_id || "");
  const to = String(req.body?.to_user || "");
  const kind = String(req.body?.kind || "");
  if (!conv || !to || !kind) {
    return res.status(400).json({ error: "conversation_id_to_user_kind_required" });
  }
  const { data, error } = await db!.rpc("chat_signal_send", {
    _conv: conv,
    _from: me.id,
    _to: to,
    _kind: kind,
    _payload: req.body?.payload ?? {},
  });
  if (error) return fail(res, error);
  res.json({ id: data });
});

chatRouter.get("/video/signals", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const { data, error } = await db!.rpc("chat_signal_poll", {
    _conv: req.query?.c ? String(req.query.c) : null,
    _user: me.id,
  });
  if (error) return fail(res, error);
  res.json({ signals: data ?? [] });
});

export default chatRouter;
// ── PHASE 10A: ANEXOVIDEOCHAT CALL ENGINE (fallback of Rust /rpc/chat.*) ─────
//
// ENV (/opt/anexomail/.env):
//   TURN_HOST=anexovideocall.anexomail.com
//   TURN_SECRET=<coturn static-auth-secret>   # frontend pe kabhi nahi
//   TURN_TTL_SECONDS=3600
//
// Ephemeral TURN creds = coturn ka standard REST scheme:
//   username = <unix-expiry>:<user-id>
//   password = base64(HMAC-SHA1(secret, username))
import { createHmac } from "node:crypto";

const TURN_HOST = process.env.TURN_HOST || "";
const TURN_SECRET = process.env.TURN_SECRET || "";
const TURN_TTL = Number(process.env.TURN_TTL_SECONDS || 3600);

const STUN_URLS = ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"];

chatRouter.get("/video/turn", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const gate = await db!.rpc("chat_video_allowed", { _user_id: me.id });
  if (gate.error) return fail(res, gate.error);
  if (gate.data !== true) {
    return res.status(403).json({ error: "video_not_entitled", plan_required: "business_pro" });
  }

  const iceServers: any[] = [{ urls: STUN_URLS }];
  if (TURN_HOST && TURN_SECRET) {
    const expiry = Math.floor(Date.now() / 1000) + TURN_TTL;
    const username = `${expiry}:${me.id}`;
    const credential = createHmac("sha1", TURN_SECRET).update(username).digest("base64");
    iceServers.push({
      urls: [
        `turn:${TURN_HOST}:3478?transport=udp`,
        `turn:${TURN_HOST}:3478?transport=tcp`,
        `turns:${TURN_HOST}:5349?transport=tcp`,
      ],
      username,
      credential,
    });
  }
  // TURN configure na ho to jhoot nahi — sirf STUN bhejte hain.
  res.json({ ice_servers: iceServers, ttl_seconds: TURN_TTL, turn: Boolean(TURN_HOST && TURN_SECRET) });
});

chatRouter.post("/video/call/start", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.body?.conversation_id || "");
  if (!conv) return res.status(400).json({ error: "conversation_required" });
  const { data, error } = await db!.rpc("chat_call_start", {
    _conv: conv,
    _user: me.id,
    _peer: req.body?.peer_user_id ? String(req.body.peer_user_id) : null,
    _role: String(req.body?.role || "caller"),
    _signaling: String(req.body?.signaling || ""),
  });
  if (error) return fail(res, error);
  res.json({ session_id: data });
});

chatRouter.post("/video/call/stat", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const session = String(req.body?.session_id || "");
  if (!session) return res.status(400).json({ error: "session_required" });
  const { error } = await db!.rpc("chat_call_stat", {
    _session: session,
    _user: me.id,
    _sample: req.body?.sample ?? {},
  });
  if (error) return fail(res, error);
  res.json({ ok: true });
});

chatRouter.post("/video/call/end", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const session = String(req.body?.session_id || "");
  if (!session) return res.status(400).json({ error: "session_required" });
  const { error } = await db!.rpc("chat_call_end", {
    _session: session,
    _user: me.id,
    _reason: String(req.body?.reason || ""),
  });
  if (error) return fail(res, error);
  res.json({ ok: true });
});

// Founder view (measured, not marketed)
chatRouter.get("/video/calls/health", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const days = Number(req.query?.days || 7);
  const health = await db!.rpc("chat_call_health", { _user: me.id, _days: days });
  if (health.error) return res.status(403).json({ error: "founder_only" });
  const recent = await db!.rpc("chat_call_recent", { _user: me.id, _limit: 40 });
  res.json({ health: health.data ?? {}, calls: recent.data ?? [] });
});

/* ==========================================================================
 * PHASE 11 — ATTACHMENTS + AVATARS
 * Bucket `chat-media` private hai. Client ko sirf signed upload URL milta hai;
 * padhne ke liye signed download URL. Row `ready` hone tak message par nahi
 * lagta — is liye adhura attachment kabhi nazar nahi aata.
 * ========================================================================== */
const MEDIA_BUCKET = "chat-media";
const MEDIA_MAX_BYTES = 200 * 1024 * 1024; // Phase 11 — NEW ADDED (25 MB -> 200 MB)
const MEDIA_TYPES = ["image/png", "image/jpeg", "image/webp", "image/avif"];

chatRouter.post("/attachments/ticket", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.body?.conversation_id || "");
  const filename = String(req.body?.filename || "image");
  const contentType = String(req.body?.content_type || "");
  const bytes = Number(req.body?.bytes || 0);
  if (!conv) return res.status(400).json({ error: "conversation_required" });
  if (!MEDIA_TYPES.includes(contentType)) {
    return res.status(400).json({ error: "unsupported_type", allowed: MEDIA_TYPES });
  }
  if (!bytes || bytes > MEDIA_MAX_BYTES) {
    return res.status(400).json({ error: "too_large", max_bytes: MEDIA_MAX_BYTES });
  }

  const created = await db!.rpc("chat_attachment_new", {
    _user: me.id,
    _conv: conv,
    _filename: filename,
    _content_type: contentType,
    _bytes: bytes,
    _width: req.body?.width ? Number(req.body.width) : null,
    _height: req.body?.height ? Number(req.body.height) : null,
  });
  if (created.error) return fail(res, created.error);
  const row = Array.isArray(created.data) ? created.data[0] : created.data;
  if (!row?.storage_path) return res.status(500).json({ error: "ticket_failed" });

  const main = await db!.storage.from(MEDIA_BUCKET).createSignedUploadUrl(row.storage_path);
  if (main.error) return res.status(500).json({ error: main.error.message });
  const thumb = row.thumb_path
    ? await db!.storage.from(MEDIA_BUCKET).createSignedUploadUrl(row.thumb_path)
    : null;

  res.json({
    attachment_id: row.attachment_id,
    upload_url: main.data.signedUrl,
    thumb_upload_url: thumb?.data?.signedUrl ?? null,
    path: row.storage_path,
  });
});

chatRouter.post("/attachments/commit", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const id = String(req.body?.attachment_id || "");
  if (!id) return res.status(400).json({ error: "attachment_required" });
  const { data, error } = await db!.rpc("chat_attachment_commit", {
    _user: me.id,
    _attachment: id,
    _width: req.body?.width ? Number(req.body.width) : null,
    _height: req.body?.height ? Number(req.body.height) : null,
  });
  if (error) return fail(res, error);
  if (data !== true) return res.status(404).json({ error: "attachment_not_found" });
  res.json({ ok: true });
});

/** Send ke baad message se jodna. */
chatRouter.post("/attachments/attach", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const message = String(req.body?.message_id || "");
  const ids: string[] = Array.isArray(req.body?.attachment_ids)
    ? req.body.attachment_ids.map((v: unknown) => String(v))
    : [];
  if (!message || ids.length === 0) {
    return res.status(400).json({ error: "message_and_attachments_required" });
  }
  const { data, error } = await db!.rpc("chat_attachment_attach", {
    _user: me.id,
    _message: message,
    _ids: ids,
  });
  if (error) return fail(res, error);
  res.json({ attached: Number(data ?? 0) });
});

/** Signed read URLs — private bucket, is liye har baar fresh. */
chatRouter.get("/attachments/:messageId", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const { data, error } = await db!
    .from("chat_attachments")
    .select("id, filename, content_type, bytes, width, height, storage_path, thumb_path, state")
    .eq("message_id", String(req.params.messageId))
    .eq("state", "ready");
  if (error) return fail(res, error);

  const rows = data ?? [];
  const out = [];
  for (const r of rows) {
    const url = await db!.storage.from(MEDIA_BUCKET).createSignedUrl(r.storage_path, 900);
    const thumb = r.thumb_path
      ? await db!.storage.from(MEDIA_BUCKET).createSignedUrl(r.thumb_path, 900)
      : null;
    out.push({
      id: r.id,
      filename: r.filename,
      content_type: r.content_type,
      bytes: r.bytes,
      width: r.width,
      height: r.height,
      url: url.data?.signedUrl ?? null,
      thumb_url: thumb?.data?.signedUrl ?? null,
    });
  }
  res.json({ attachments: out, viewer: me.id });
});

chatRouter.post("/profile/avatar/ticket", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const contentType = String(req.body?.content_type || "image/webp");
  if (!MEDIA_TYPES.includes(contentType)) {
    return res.status(400).json({ error: "unsupported_type", allowed: MEDIA_TYPES });
  }
  const path = `avatars/${me.id}/${Date.now()}.webp`;
  const signed = await db!.storage.from(MEDIA_BUCKET).createSignedUploadUrl(path);
  if (signed.error) return res.status(500).json({ error: signed.error.message });
  res.json({ upload_url: signed.data.signedUrl, path });
});

chatRouter.post("/profile/avatar/commit", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const path = String(req.body?.path || "");
  if (!path.startsWith(`avatars/${me.id}/`)) {
    return res.status(400).json({ error: "path_not_yours" });
  }
  const { error } = await db!.rpc("chat_avatar_set", { _user: me.id, _path: path });
  if (error) return fail(res, error);
  const signed = await db!.storage.from(MEDIA_BUCKET).createSignedUrl(path, 3600);
  res.json({ ok: true, path, url: signed.data?.signedUrl ?? null });
});

// ── PHASE 12: CROSS-DEVICE CONTINUITY (resume anywhere) ─────────
// Server state authoritative. Device sirf sync + reconcile karta hai.
//   POST /api/chat/device/seen   {device_id,device_label,kind,platform,installed}
//   GET  /api/chat/continuity?device=   devices + drafts + positions
//   POST /api/chat/draft         {conversation_id,body,reply_to_id,caret,attachment_ids,rev,device_id,device_label}
//   POST /api/chat/position      {conversation_id,anchor_seq,at_bottom,rev,device_id,device_label}
//   GET  /api/chat/search/deep?q=&c=&sender=&before=&limit=
chatRouter.post("/device/seen", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const deviceId = String(req.body?.device_id || "");
  if (!deviceId) return res.status(400).json({ error: "device_id_required" });
  const { error } = await db!.rpc("chat_device_seen", {
    _user: me.id,
    _device_id: deviceId.slice(0, 100),
    _label: String(req.body?.device_label || "").slice(0, 120) || null,
    _kind: String(req.body?.kind || "unknown"),
    _platform: String(req.body?.platform || "").slice(0, 120) || null,
    _installed: Boolean(req.body?.installed),
  });
  if (error) return fail(res, error);
  res.json({ ok: true });
});

chatRouter.get("/continuity", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const { data, error } = await db!.rpc("chat_continuity", {
    _user: me.id,
    _device_id: String(req.query?.device || "") || null,
  });
  if (error) return fail(res, error);
  res.json(data ?? { devices: [], drafts: [], positions: [] });
});

chatRouter.post("/draft", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.body?.conversation_id || "");
  if (!conv) return res.status(400).json({ error: "conversation_required" });
  const ids = Array.isArray(req.body?.attachment_ids)
    ? req.body.attachment_ids.map((v: unknown) => String(v)).slice(0, 20)
    : [];
  const { data, error } = await db!.rpc("chat_draft_save", {
    _user: me.id,
    _conv: conv,
    _body: String(req.body?.body ?? "").slice(0, 20_000),
    _reply_to: req.body?.reply_to_id ? String(req.body.reply_to_id) : null,
    _caret: Number.isFinite(Number(req.body?.caret)) ? Math.trunc(Number(req.body.caret)) : 0,
    _attachment_ids: ids,
    _rev: Number.isFinite(Number(req.body?.rev)) ? Math.trunc(Number(req.body.rev)) : 0,
    _device_id: String(req.body?.device_id || "").slice(0, 100) || null,
    _device_label: String(req.body?.device_label || "").slice(0, 120) || null,
  });
  if (error) return fail(res, error);
  res.json(Array.isArray(data) ? data[0] : data);
});

chatRouter.post("/position", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const conv = String(req.body?.conversation_id || "");
  if (!conv) return res.status(400).json({ error: "conversation_required" });
  const { data, error } = await db!.rpc("chat_position_save", {
    _user: me.id,
    _conv: conv,
    _anchor_seq: Number.isFinite(Number(req.body?.anchor_seq))
      ? Math.trunc(Number(req.body.anchor_seq))
      : 0,
    _at_bottom: req.body?.at_bottom !== false,
    _rev: Number.isFinite(Number(req.body?.rev)) ? Math.trunc(Number(req.body.rev)) : 0,
    _device_id: String(req.body?.device_id || "").slice(0, 100) || null,
    _device_label: String(req.body?.device_label || "").slice(0, 120) || null,
  });
  if (error) return fail(res, error);
  res.json(Array.isArray(data) ? data[0] : data);
});

chatRouter.get("/search/deep", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const q = String(req.query?.q || "");
  if (!q.trim()) return res.json({ results: [] });
  const limit = Number(req.query?.limit);
  const { data, error } = await db!.rpc("chat_search_deep", {
    _user: me.id,
    _q: q,
    _conv: String(req.query?.c || "") || null,
    _sender: String(req.query?.sender || "") || null,
    _before: String(req.query?.before || "") || null,
    _limit: Number.isFinite(limit) ? Math.trunc(limit) : 40,
  });
  if (error) return fail(res, error);
  res.json({ results: data ?? [] });
});
