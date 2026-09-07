// ============================================================================
// ANEXOCHAT — PHASE 13/14/15 FILE ENGINE · BUN FALLBACK (service `anexochat`, 3300)
//
// LOCK: PRIMARY Rust hai (`/rpc/file.*` + `POST /file/chunk`, port 3200 + QUIC).
// Yeh file SIRF fallback hai — jab WebTransport/Rust available na ho. Contract
// bilkul same, truth Supabase #4 (file_* RPCs). Koi jhooti progress nahi.
//
// NANO COMMAND (server par — repo se pull hota hai, manual overwrite nahi):
//   deploy: cd /opt/anexomail && git pull 2>/dev/null; pm2 restart anexochat
//
// Routes (mount: server/anexochat.ts -> app.use("/api/chat/file", filesRouter))
//   GET  /api/chat/file/state              → pool + files + live transfers
//   POST /api/chat/file/begin              → resume identity + missing chunks
//   POST /api/chat/file/chunk              → raw chunk bytes (sha256 verify)
//   GET  /api/chat/file/transfer?id=       → truthful progress + missing/corrupt
//   POST /api/chat/file/mark               → pause / resume / failed
//   POST /api/chat/file/commit             → version ready (sab chunks verified)
//   GET  /api/chat/file/versions?file=     → version chain
//   PHASE 16/17/18 (truth + safety, sab local — koi external API nahi)
//   GET  /api/chat/file/truth?version=     → evidence chain (7 steps)
//   GET  /api/chat/file/safety             → engines + queue + enforcement
//   POST /api/chat/file/download/ack       → Downloaded step (blocked par 409)
// ============================================================================
import { createHash } from "crypto";

import { Router, raw } from "express";
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
  console.error("files: SUPABASE4_* missing — /api/chat/file/* will 503");
}

export const filesRouter = Router();

const fail = (res: any, e: any) =>
  res.status(500).json({ error: "db_error", detail: String(e?.message || e) });

async function requireChat(
  req: any,
  res: any,
): Promise<{ id: string; email: string; workspace_id: string } | null> {
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
  const gate = await db.rpc("chat_access", { _user_id: data.user.id });
  if (gate.error) {
    fail(res, gate.error);
    return null;
  }
  if (gate.data !== true) {
    res.status(403).json({ error: "chat_not_entitled", plan_required: "business" });
    return null;
  }
  const email = data.user.email || "";
  const ws = await db.rpc("chat_ensure_workspace", {
    _user: data.user.id,
    _name: email ? email.split("@")[1] || "Workspace" : "Workspace",
  });
  if (ws.error) {
    fail(res, ws.error);
    return null;
  }
  return { id: data.user.id, email, workspace_id: String(ws.data) };
}

filesRouter.get("/state", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const r = await db!.rpc("file_engine_state", { _user: me.id, _workspace: me.workspace_id });
  if (r.error) return fail(res, r.error);
  res.json(r.data);
});

filesRouter.post("/begin", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const b = req.body ?? {};
  const r = await db!.rpc("file_transfer_begin", {
    _user: me.id,
    _workspace: me.workspace_id,
    _conv: b.conversation_id ?? null,
    _name: String(b.name || ""),
    _content_type: String(b.content_type || "application/octet-stream"),
    _bytes: Math.max(0, Math.floor(Number(b.bytes) || 0)),
    _file_sha256: b.file_sha256 ?? null,
    _chunk_size: Math.max(1048576, Math.floor(Number(b.chunk_size) || 8388608)),
    _device: String(b.device || "bun-fallback"),
  });
  if (r.error) return fail(res, r.error);
  const out: any = r.data;
  res.status(out?.allowed ? 200 : 413).json(out);
});

// PHASE 14: chunk integrity — server apna sha256 nikaalta hai, client ke saath
// match karta hai. Mismatch = corrupt chunk (409), storage tak nahi jata.
filesRouter.post("/chunk", raw({ type: "*/*", limit: "16mb" }), async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const transfer = String(req.headers["x-transfer-id"] || "");
  const idx = Number(req.headers["x-chunk-index"]);
  const clientSha = String(req.headers["x-chunk-sha256"] || "").toLowerCase();
  const bytes: Buffer = Buffer.isBuffer(req.body) ? req.body : Buffer.alloc(0);
  if (!transfer || !Number.isFinite(idx) || idx < 0 || bytes.length === 0) {
    return res
      .status(400)
      .json({ error: "bad_request", detail: "x-transfer-id + x-chunk-index + body" });
  }

  const st = await db!.rpc("file_transfer_state", { _user: me.id, _transfer: transfer });
  if (st.error) return fail(res, st.error);
  const state: any = st.data;
  if (state?.found !== true) return res.status(404).json({ error: "transfer_not_found" });

  const serverSha = createHash("sha256").update(bytes).digest("hex");

  if (clientSha && clientSha !== serverSha) {
    const bad = await db!.rpc("file_chunk_ack", {
      _user: me.id,
      _transfer: transfer,
      _idx: idx,
      _bytes: bytes.length,
      _sha256: clientSha,
      _server_sha256: serverSha,
    });
    if (bad.error) return fail(res, bad.error);
    return res.status(409).json(bad.data);
  }

  const up = await db!.storage
    .from("chat-files")
    .upload(`${state.storage_prefix}/chunks/${idx}`, bytes, {
      contentType: "application/octet-stream",
      upsert: true,
    });
  if (up.error) return res.status(502).json({ error: "storage_error", detail: up.error.message });

  const ack = await db!.rpc("file_chunk_ack", {
    _user: me.id,
    _transfer: transfer,
    _idx: idx,
    _bytes: bytes.length,
    _sha256: serverSha,
    _server_sha256: serverSha,
  });
  if (ack.error) return fail(res, ack.error);
  res.json(ack.data);
});

filesRouter.get("/transfer", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const r = await db!.rpc("file_transfer_state", {
    _user: me.id,
    _transfer: String(req.query.id || ""),
  });
  if (r.error) return fail(res, r.error);
  res.json(r.data);
});

filesRouter.post("/mark", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const r = await db!.rpc("file_transfer_mark", {
    _user: me.id,
    _transfer: String(req.body?.transfer_id || ""),
    _state: String(req.body?.state || "paused"),
    _transport: String(req.body?.transport || "bun"),
    _error: req.body?.error ?? null,
  });
  if (r.error) return fail(res, r.error);
  res.json(r.data);
});

filesRouter.post("/commit", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const r = await db!.rpc("file_commit", {
    _user: me.id,
    _transfer: String(req.body?.transfer_id || ""),
    _file_sha256: req.body?.file_sha256 ?? null,
  });
  if (r.error) return fail(res, r.error);
  const out: any = r.data;
  res.status(out?.ok ? 200 : 409).json(out);
});

filesRouter.get("/versions", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const r = await db!.rpc("file_versions", {
    _user: me.id,
    _file: String(req.query.file || ""),
  });
  if (r.error) return fail(res, r.error);
  res.json(r.data);
});

// ── PHASE 16: FILE TRUTH — chain sirf DB rows se, koi guess nahi ────────────
filesRouter.get("/truth", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const r = await db!.rpc("file_truth", {
    _user: me.id,
    _version: String(req.query.version || ""),
  });
  if (r.error) return fail(res, r.error);
  res.json(r.data);
});

// ── PHASE 17/18: safety truth — engine list, queue depth, enforcement state ─
filesRouter.get("/safety", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const r = await db!.rpc("file_safety_state", { _user: me.id });
  if (r.error) return fail(res, r.error);
  res.json(r.data);
});

// Downloaded step: sirf available + clean file par. Blocked = 409, kabhi bytes nahi.
filesRouter.post("/download/ack", async (req, res) => {
  const me = await requireChat(req, res);
  if (!me) return;
  const r = await db!.rpc("file_download_ack", {
    _user: me.id,
    _version: String(req.body?.version_id || ""),
    _bytes: Math.max(0, Math.floor(Number(req.body?.bytes) || 0)),
    _device: String(req.body?.device || "bun-fallback"),
  });
  if (r.error) return fail(res, r.error);
  const out: any = r.data;
  res.status(out?.ok ? 200 : 409).json(out);
});

export default filesRouter;
