// ============================================================================
// ANEXOMAIL — PHASE 48: INBOX STORAGE & QUOTA CONTROL (Brain, port 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/storage.ts /opt/anexomail/src/routes/storage.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/storage.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//   pm2 restart anexomail-leo && pm2 logs anexomail-leo --lines 40 --nostream
//
// Routes (auth):
//   GET  /api/storage/state                  → plan + pool + per mailbox quota/used/remaining
//   POST /api/storage/preflight              → { mailbox, bytes, kind } allow/reject + reason
//   POST /api/storage/reserve                → upload shuru (in-flight bytes hold)
//   POST /api/storage/commit                 → upload/mail complete
//   POST /api/storage/release                → upload cancel/fail
// Routes (internal, x-cron-secret / delivery hook):
//   POST /api/internal/storage/accept        → Postfix hook: incoming mail allow?
//   POST /api/internal/storage/commit        → hook: delivered bytes commit
// Founder:
//   GET  /api/founder/storage/volumes        → capacity abstraction (kaunsa volume kitna bhara)
//
// RULE: quota LOGICAL hai. Koi disk reservation nahi. Truth Supabase #4 mein
// (storage_state / storage_can_accept / reserve / commit / release / purge).
// Jimmy · LEO · AI · chat · billing ko yeh file chhoti bhi nahi.
import { Router } from "express";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const CRON_SECRET = process.env.CRON_SECRET || "";

let db: SupabaseClient | null = null;
if (SUPABASE_URL && SERVICE_KEY) {
  db = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
} else {
  console.error("storage: SUPABASE4_* env missing — routes will 503");
}

const storageRouter = Router();
const internalStorageRouter = Router();
const founderStorageRouter = Router();

const fail = (res: any, e: any) =>
  res.status(500).json({ error: "db_error", detail: String(e?.message || e) });

const KINDS = new Set(["email", "attachment", "file"]);

async function requireWs(
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

function parseBody(req: any, res: any): { mailbox: string; bytes: number; kind: string } | null {
  const mailbox = String(req.body?.mailbox || "").trim().toLowerCase();
  const bytes = Math.max(0, Math.floor(Number(req.body?.bytes) || 0));
  const kind = String(req.body?.kind || "attachment");
  if (!mailbox || !KINDS.has(kind)) {
    res.status(400).json({ error: "bad_request", detail: "mailbox + kind (email|attachment|file)" });
    return null;
  }
  return { mailbox, bytes, kind };
}

// ── UI truth ────────────────────────────────────────────────────────────────
storageRouter.get("/state", async (req, res) => {
  const me = await requireWs(req, res);
  if (!me) return;
  const r = await db!.rpc("storage_state", { _workspace: me.workspace_id });
  if (r.error) return fail(res, r.error);
  res.json(r.data);
});

// ── enforcement (frontend upload gate) ──────────────────────────────────────
storageRouter.post("/preflight", async (req, res) => {
  const me = await requireWs(req, res);
  if (!me) return;
  const b = parseBody(req, res);
  if (!b) return;
  const r = await db!.rpc("storage_can_accept", {
    _workspace: me.workspace_id,
    _mailbox: b.mailbox,
    _bytes: b.bytes,
    _kind: b.kind,
  });
  if (r.error) return fail(res, r.error);
  const out: any = r.data;
  res.status(out?.allowed ? 200 : 413).json(out);
});

storageRouter.post("/reserve", async (req, res) => {
  const me = await requireWs(req, res);
  if (!me) return;
  const b = parseBody(req, res);
  if (!b) return;
  const r = await db!.rpc("storage_reserve", {
    _workspace: me.workspace_id,
    _mailbox: b.mailbox,
    _bytes: b.bytes,
    _kind: b.kind,
  });
  if (r.error) return fail(res, r.error);
  const out: any = r.data;
  res.status(out?.allowed ? 200 : 413).json(out);
});

storageRouter.post("/commit", async (req, res) => {
  const me = await requireWs(req, res);
  if (!me) return;
  const b = parseBody(req, res);
  if (!b) return;
  const r = await db!.rpc("storage_commit", {
    _workspace: me.workspace_id,
    _mailbox: b.mailbox,
    _bytes: b.bytes,
    _kind: b.kind,
    _was_reserved: req.body?.was_reserved !== false,
  });
  if (r.error) return fail(res, r.error);
  res.json(r.data);
});

storageRouter.post("/release", async (req, res) => {
  const me = await requireWs(req, res);
  if (!me) return;
  const b = parseBody(req, res);
  if (!b) return;
  const r = await db!.rpc("storage_release", {
    _workspace: me.workspace_id,
    _mailbox: b.mailbox,
    _bytes: b.bytes,
  });
  if (r.error) return fail(res, r.error);
  res.json({ ok: true });
});

// ── Postfix delivery hook: incoming mail quota gate ─────────────────────────
function cronOk(req: any, res: any): boolean {
  if (!db) {
    res.status(503).json({ error: "supabase_not_configured" });
    return false;
  }
  if (!CRON_SECRET || String(req.headers["x-cron-secret"] || "") !== CRON_SECRET) {
    res.status(401).json({ error: "unauthorized" });
    return false;
  }
  return true;
}

internalStorageRouter.post("/storage/accept", async (req, res) => {
  if (!cronOk(req, res)) return;
  const workspace = String(req.body?.workspace_id || "");
  const b = parseBody(req, res);
  if (!b || !workspace) return res.status(400).json({ error: "bad_request" });
  const r = await db!.rpc("storage_can_accept", {
    _workspace: workspace,
    _mailbox: b.mailbox,
    _bytes: b.bytes,
    _kind: b.kind,
  });
  if (r.error) return fail(res, r.error);
  const out: any = r.data;
  // 452 = SMTP "insufficient system storage" → sender ko retry milta hai,
  // mail discard NAHI hoti (frozen/full mailbox rule).
  res.status(out?.allowed ? 200 : 452).json(out);
});

internalStorageRouter.post("/storage/commit", async (req, res) => {
  if (!cronOk(req, res)) return;
  const workspace = String(req.body?.workspace_id || "");
  const b = parseBody(req, res);
  if (!b || !workspace) return res.status(400).json({ error: "bad_request" });
  const r = await db!.rpc("storage_commit", {
    _workspace: workspace,
    _mailbox: b.mailbox,
    _bytes: b.bytes,
    _kind: b.kind,
    _was_reserved: false,
  });
  if (r.error) return fail(res, r.error);
  res.json(r.data);
});

// ── founder: storage abstraction (kaunsa volume kitna bhara) ────────────────
founderStorageRouter.get("/storage/volumes", async (req, res) => {
  const me = await requireWs(req, res);
  if (!me) return;
  const v = await db!
    .from("storage_volumes")
    .select("id,name,kind,capacity_bytes,used_bytes,accepts_new")
    .order("name");
  if (v.error) return fail(res, v.error);
  const rows = v.data || [];
  res.json({
    volumes: rows,
    capacity_bytes: rows.reduce((n: number, r: any) => n + Number(r.capacity_bytes || 0), 0),
    used_bytes: rows.reduce((n: number, r: any) => n + Number(r.used_bytes || 0), 0),
  });
});

export { storageRouter, internalStorageRouter, founderStorageRouter };
export default storageRouter;
