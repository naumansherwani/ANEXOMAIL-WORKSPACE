// ANEXOMAIL — Billing truth + founder reply clock (Server 2 / Brain, port 3100)
// GET  /api/founder/support/replies — founder's real plan-aware reply queue
// POST /api/founder/support/replies/:id/replied — close the response clock
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
  console.error("billing-support: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY missing — routes will 503");
}

const router = Router();

async function requireFounder(req: any, res: any): Promise<string | null> {
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
  const { data: auth, error: authError } = await db.auth.getUser(token);
  if (authError || !auth.user) {
    res.status(401).json({ error: "unauthorized" });
    return null;
  }
  const { data: founder } = await db
    .from("founder_accounts")
    .select("user_id")
    .eq("user_id", auth.user.id)
    .maybeSingle();
  if (!founder) {
    res.status(403).json({ error: "founder_only" });
    return null;
  }
  return auth.user.id;
}

router.get("/support/replies", async (req, res) => {
  const founderId = await requireFounder(req, res);
  if (!founderId || !db) return;
  const { data, error } = await db
    .from("founder_reply_queue")
    .select("id,user_id,thread_id,customer_email,subject,plan,response_due_hours,received_at,respond_by,state,replied_at")
    .order("respond_by", { ascending: true });
  if (error) return res.status(500).json({ error: "db_error", detail: error.message });
  const now = Date.now();
  return res.json({
    replies: (data || []).map((row: any) => ({
      ...row,
      overdue: row.state === "awaiting_reply" && new Date(row.respond_by).getTime() < now,
      remaining_minutes: Math.max(0, Math.floor((new Date(row.respond_by).getTime() - now) / 60000)),
    })),
  });
});

router.post("/support/replies/:id/replied", async (req, res) => {
  const founderId = await requireFounder(req, res);
  if (!founderId || !db) return;
  const { data, error } = await db
    .from("founder_reply_queue")
    .update({ state: "replied", replied_at: new Date().toISOString() })
    .eq("id", req.params.id)
    .select("id,state,replied_at")
    .single();
  if (error) return res.status(500).json({ error: "db_error", detail: error.message });
  return res.json(data);
});

export default router;