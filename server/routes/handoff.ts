// ANEXOMAIL — Phase 28: Cross-Platform (device handoff) API — Server 2, port 3100
//
// NANO COMMAND (server par):
//   nano /opt/anexomail/src/routes/handoff.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// Endpoints (sab Bearer required):
//   GET    /api/mail/handoff              — is user ke saray device drafts
//   POST   /api/mail/handoff              — draft + cursor save (upsert per device+thread)
//   POST   /api/mail/handoff/:id/claim    — draft is device par le aao
//   DELETE /api/mail/handoff/:id          — draft hatao (real delete)
//   POST   /api/mail/devices/seen         — device heartbeat (label, installed)
//
// Env locked: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY.
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
  console.error("handoff: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY missing — routes will 503");
}

const router = Router();

const fail = (res: any, e: any) =>
  res.status(500).json({ error: "db_error", detail: String(e?.message || e) });

async function requireUser(req: any, res: any): Promise<string | null> {
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
  return data.user.id;
}

const str = (v: any, max = 4000): string | null => {
  if (typeof v !== "string") return null;
  const t = v.trim();
  return t ? t.slice(0, max) : null;
};

// ---------- GET /api/mail/handoff ----------
router.get("/handoff", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data, error } = await db!
      .from("device_handoff")
      .select(
        "id, device_id, device_label, thread_id, to_address, subject, body, cursor_position, updated_at",
      )
      .eq("user_id", uid)
      .order("updated_at", { ascending: false })
      .limit(20);
    if (error) throw error;
    res.json({ drafts: data ?? [] });
  } catch (e) {
    fail(res, e);
  }
});

// ---------- POST /api/mail/handoff ----------
router.post("/handoff", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;

  const deviceId = str(req.body?.device_id, 100);
  const body = typeof req.body?.body === "string" ? req.body.body.slice(0, 100_000) : null;
  if (!deviceId || body === null) {
    return res.status(400).json({ error: "device_id_and_body_required" });
  }
  const cursor = Number.isFinite(Number(req.body?.cursor_position))
    ? Math.max(0, Math.min(100_000, Math.trunc(Number(req.body.cursor_position))))
    : 0;

  const row = {
    user_id: uid,
    device_id: deviceId,
    device_label: str(req.body?.device_label, 120) ?? "Unknown device",
    thread_id: str(req.body?.thread_id, 200),
    to_address: str(req.body?.to_address, 320),
    subject: str(req.body?.subject, 500),
    body,
    cursor_position: cursor,
    updated_at: new Date().toISOString(),
  };

  try {
    // ek device + ek thread = ek slot. Warna har keystroke naya row banata.
    const q = db!
      .from("device_handoff")
      .select("id")
      .eq("user_id", uid)
      .eq("device_id", deviceId)
      .limit(1);
    const existing = row.thread_id
      ? await q.eq("thread_id", row.thread_id)
      : await q.is("thread_id", null);
    if (existing.error) throw existing.error;

    const found = existing.data?.[0]?.id as string | undefined;
    if (found) {
      const { error } = await db!.from("device_handoff").update(row).eq("id", found);
      if (error) throw error;
      return res.json({ id: found });
    }
    const { data, error } = await db!.from("device_handoff").insert(row).select("id").single();
    if (error) throw error;
    res.json({ id: data?.id });
  } catch (e) {
    fail(res, e);
  }
});

// ---------- POST /api/mail/handoff/:id/claim ----------
router.post("/handoff/:id/claim", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const deviceId = str(req.body?.device_id, 100);
  if (!deviceId) return res.status(400).json({ error: "device_id_required" });
  try {
    const { data, error } = await db!
      .from("device_handoff")
      .update({
        claimed_by: deviceId,
        device_id: deviceId,
        device_label: str(req.body?.device_label, 120) ?? "Unknown device",
        updated_at: new Date().toISOString(),
      })
      .eq("id", req.params.id)
      .eq("user_id", uid)
      .select(
        "id, device_id, device_label, thread_id, to_address, subject, body, cursor_position, updated_at",
      )
      .single();
    if (error) throw error;
    if (!data) return res.status(404).json({ error: "not_found" });
    res.json(data);
  } catch (e) {
    fail(res, e);
  }
});

// ---------- DELETE /api/mail/handoff/:id ----------
router.delete("/handoff/:id", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { error } = await db!
      .from("device_handoff")
      .delete()
      .eq("id", req.params.id)
      .eq("user_id", uid);
    if (error) throw error;
    res.json({ ok: true });
  } catch (e) {
    fail(res, e);
  }
});

// ---------- POST /api/mail/devices/seen ----------
router.post("/devices/seen", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const deviceId = str(req.body?.device_id, 100);
  if (!deviceId) return res.status(400).json({ error: "device_id_required" });
  try {
    const { error } = await db!.from("user_devices").upsert(
      {
        user_id: uid,
        device_id: deviceId,
        device_label: str(req.body?.device_label, 120) ?? "Unknown device",
        platform: str(req.body?.platform, 120),
        installed: Boolean(req.body?.installed),
        last_seen: new Date().toISOString(),
      },
      { onConflict: "user_id,device_id" },
    );
    if (error) throw error;
    res.json({ ok: true });
  } catch (e) {
    fail(res, e);
  }
});

export default router;