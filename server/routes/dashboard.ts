/**
 * ANEXOMAIL — Phase 6: Dashboard Command Center
 * Real data only. Supabase 4 (service role) se read, org scope enforce.
 */
import { Router } from "express";
import { admin as supa } from "../lib/supa";

export const dashboardRouter = Router();

type Ctx = { userId: string; orgId: string; email: string };

async function ctx(req: any, res: any): Promise<Ctx | null> {
  const bearer = (req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  const token = bearer || req.cookies?.ax_session || "";
  if (!token) { res.status(401).json({ error: "unauthenticated" }); return null; }

  const { data, error } = await supa.auth.getUser(token);
  if (error || !data?.user) { res.status(401).json({ error: "unauthenticated" }); return null; }
  const userId = data.user.id;

  const requested = (req.header("x-org-id") || req.query.org_id || "") as string;
  const { data: rows } = await supa
    .from("org_members")
    .select("org_id")
    .eq("user_id", userId);

  const ids = (rows || []).map((r: any) => r.org_id);
  if (!ids.length) { res.status(409).json({ error: "no_workspace" }); return null; }
  const orgId = requested && ids.includes(requested) ? requested : ids[0];
  return { userId, orgId, email: String(data.user.email || "") };
}

const iso = (d: Date) => d.toISOString();

/* ---------- GET /api/dashboard/summary ---------- */
// Hisaab Postgres mein (E30 dashboard_summary) — Rust :3200 PRIMARY wahi function
// call karta hai. Yeh Bun route sirf FALLBACK hai; dono ka sach ek hi jagah.
dashboardRouter.get("/summary", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data, error } = await supa.rpc("dashboard_summary", {
    _org: c.orgId, _user: c.userId, _email: c.email,
  });
  if (error) return res.status(500).json({ error: error.message || "summary_failed" });
  res.json(data);
});

/* ---------- GET /api/dashboard/activity ---------- */
dashboardRouter.get("/activity", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const limit = Math.min(Number(req.query.limit) || 20, 50);
  const { data, error } = await supa
    .from("activity_log")
    .select("id, kind, actor_label, subject, detail, created_at")
    .eq("org_id", c.orgId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) return res.status(500).json({ error: error.message });
  res.json({
    items: (data || []).map((r: any) => ({
      id: r.id, kind: r.kind, actor: r.actor_label ?? null,
      subject: r.subject, detail: r.detail ?? null, created_at: r.created_at,
    })),
  });
});

/* ---------- GET /api/dashboard/ai-usage ---------- */
dashboardRouter.get("/ai-usage", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data } = await supa
    .from("ai_credits")
    .select("enabled, plan, credits_total, credits_used, period_end")
    .eq("org_id", c.orgId).maybeSingle();
  res.json({
    enabled: Boolean(data?.enabled),
    plan: data?.plan ?? null,
    credits_total: Number(data?.credits_total ?? 0),
    credits_used: Number(data?.credits_used ?? 0),
    period_end: data?.period_end ?? null,
  });
});

/* ---------- GET /api/dashboard/analytics ---------- */
// E30 dashboard_analytics: direction 'in'/'out', Delivered mail_scheduled se
// (koi row nahi -> null, jhoota 100% nahi), pehla jawab asli messages se.
dashboardRouter.get("/analytics", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const days = Math.min(Math.max(Number(req.query.days) || 14, 1), 90);
  const { data, error } = await supa.rpc("dashboard_analytics", { _org: c.orgId, _days: days });
  if (error) return res.status(500).json({ error: error.message || "analytics_failed" });
  res.json(data);
});

/* ---------- GET /api/dashboard/calendar ---------- */
dashboardRouter.get("/calendar", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data, error } = await supa
    .from("calendar_events")
    .select("id, title, starts_at, ends_at, location, all_day")
    .eq("org_id", c.orgId)
    .gte("starts_at", iso(new Date(Date.now() - 3600000)))
    .order("starts_at", { ascending: true })
    .limit(10);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ events: data || [] });
});
