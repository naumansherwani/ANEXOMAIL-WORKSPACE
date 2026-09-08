/**
 * ANEXOMAIL — Phase 6: Dashboard Command Center
 * Real data only. Supabase 4 (service role) se read, org scope enforce.
 */
import { Router } from "express";
import { admin as supa } from "../lib/supa";

export const dashboardRouter = Router();

type Ctx = { userId: string; orgId: string };

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
  return { userId, orgId };
}

const iso = (d: Date) => d.toISOString();
const startOfToday = () => { const d = new Date(); d.setUTCHours(0, 0, 0, 0); return d; };

async function count(table: string, build: (q: any) => any) {
  const q = build(supa.from(table).select("id", { count: "exact", head: true }));
  const { count: c } = await q;
  return c ?? 0;
}

/* ---------- GET /api/dashboard/summary ---------- */
dashboardRouter.get("/summary", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  try {
    const [unread, assigned, waiting, doneToday] = await Promise.all([
      count("mail_threads", (q) => q.eq("org_id", c.orgId).eq("is_unread", true)),
      count("mail_threads", (q) => q.eq("org_id", c.orgId).eq("assignee_id", c.userId).neq("state", "done")),
      count("mail_threads", (q) => q.eq("org_id", c.orgId).eq("state", "waiting")),
      count("mail_threads", (q) => q.eq("org_id", c.orgId).eq("state", "done").gte("closed_at", iso(startOfToday()))),
    ]);

    const { data: sizes } = await supa
      .from("mail_messages").select("size_bytes").eq("org_id", c.orgId).limit(50000);
    const used = (sizes || []).reduce((s: number, r: any) => s + Number(r.size_bytes || 0), 0);

    const { data: org } = await supa
      .from("organisations")
      .select("storage_limit_bytes, domain_verified")
      .eq("id", c.orgId).maybeSingle();

    res.json({
      unread, assigned_to_me: assigned, waiting, done_today: doneToday,
      storage_used_bytes: used,
      storage_limit_bytes: Number(org?.storage_limit_bytes ?? 32212254720),
      domain_verified: Boolean(org?.domain_verified),
    });
  } catch (e: any) { res.status(500).json({ error: e?.message || "summary_failed" }); }
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
dashboardRouter.get("/analytics", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const days = Math.min(Math.max(Number(req.query.days) || 14, 1), 90);
  const from = new Date(Date.now() - (days - 1) * 86400000);
  from.setUTCHours(0, 0, 0, 0);

  const { data: msgs, error } = await supa
    .from("mail_messages")
    .select("direction, delivered, created_at")
    .eq("org_id", c.orgId)
    .gte("created_at", iso(from))
    .limit(50000);
  if (error) return res.status(500).json({ error: error.message });

  const series: Record<string, { date: string; received: number; sent: number }> = {};
  for (let i = 0; i < days; i++) {
    const d = new Date(from.getTime() + i * 86400000).toISOString().slice(0, 10);
    series[d] = { date: d, received: 0, sent: 0 };
  }
  let received = 0, sent = 0, outbound = 0, delivered = 0;
  for (const m of msgs || []) {
    const key = String(m.created_at).slice(0, 10);
    const bucket = series[key];
    if (m.direction === "inbound") { received++; if (bucket) bucket.received++; }
    else {
      sent++; outbound++;
      if (m.delivered) delivered++;
      if (bucket) bucket.sent++;
    }
  }

  const { data: replies } = await supa
    .from("mail_threads")
    .select("first_reply_seconds")
    .eq("org_id", c.orgId)
    .gte("created_at", iso(from))
    .not("first_reply_seconds", "is", null)
    .limit(20000);
  const vals = (replies || []).map((r: any) => Number(r.first_reply_seconds)).filter(Number.isFinite);

  res.json({
    range_days: days, received, sent,
    avg_first_reply_seconds: vals.length ? Math.round(vals.reduce((a, b) => a + b, 0) / vals.length) : null,
    delivery_rate: outbound ? delivered / outbound : null,
    series: Object.values(series),
  });
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
