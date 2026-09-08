import { Router } from "express";
import { admin } from "../lib/supa";

export const crm = Router();

async function ctx(req: any) {
  const h = String(req.headers["authorization"] || "");
  const token = h.startsWith("Bearer ") ? h.slice(7) : "";
  if (!token) return { user: null as any };
  const { data } = await admin.auth.getUser(token);
  return { user: data?.user || null };
}

function guard(handler: (req: any, res: any, c: any) => Promise<any>) {
  return async (req: any, res: any) => {
    try {
      const c = await ctx(req);
      if (!c.user) return res.status(401).json({ error: "unauthorized" });
      return await handler(req, res, c);
    } catch (e: any) {
      console.error("[crm]", e?.message || e);
      return res.status(500).json({ error: "crm_failed" });
    }
  };
}

async function safe<T>(fn: () => Promise<{ data: any; error: any }>, fallback: T): Promise<T> {
  try { const { data, error } = await fn(); if (error) return fallback; return (data as T) ?? fallback; }
  catch { return fallback; }
}

const STAGE_PROB: Record<string, number> = { new: 10, qualified: 30, proposal: 55, negotiation: 75, won: 100, lost: 0 };
const days = (iso?: string | null) => (iso ? Math.floor((Date.now() - new Date(iso).getTime()) / 86400000) : null);

async function auditCrm(actor: string, action: string, target: string | null, ip: string | null) {
  try { await admin.from("crm_audit").insert({ actor, action, target, ip }); } catch {}
}
const ipOf = (req: any) =>
  String(req.headers["x-forwarded-for"] || req.socket?.remoteAddress || "").split(",")[0].trim() || null;

/* --------------------------------------------------------------- overview */
crm.get("/crm/overview", guard(async (_req, res) => {
  const deals = await safe<any[]>(() => admin.from("crm_deals").select("*"), []);
  const leads = await safe<any[]>(() => admin.from("crm_leads").select("*"), []);
  const open = deals.filter((d) => !["won", "lost"].includes(d.stage));
  const monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1).getTime();
  const stages = ["new", "qualified", "proposal", "negotiation", "won", "lost"];
  res.json({
    currency: deals[0]?.currency ?? "GBP",
    pipeline_value: open.reduce((s, d) => s + Number(d.value ?? 0), 0),
    weighted_value: Math.round(open.reduce((s, d) => s + Number(d.value ?? 0) * ((d.probability ?? STAGE_PROB[d.stage] ?? 0) / 100), 0)),
    won_this_month: deals.filter((d) => d.stage === "won" && new Date(d.updated_at ?? 0).getTime() >= monthStart)
      .reduce((s, d) => s + Number(d.value ?? 0), 0),
    open_deals: open.length,
    leads_new: leads.filter((l) => l.state === "new").length,
    leads_unworked: leads.filter((l) => l.state === "new" && !l.last_touch_at).length,
    stale_deals: open.filter((d) => (days(d.updated_at) ?? 0) >= 14).length,
    avg_first_reply_minutes: null,
    stage_counts: stages.map((s) => ({
      stage: s,
      count: deals.filter((d) => d.stage === s).length,
      value: deals.filter((d) => d.stage === s).reduce((a, d) => a + Number(d.value ?? 0), 0),
    })),
  });
}));

/* ------------------------------------------------------------ leads/deals */
crm.get("/crm/leads", guard(async (_req, res) => {
  const rows = await safe<any[]>(() => admin.from("crm_leads").select("*").order("created_at", { ascending: false }).limit(300), []);
  res.json({
    leads: rows.map((l) => ({
      id: l.id, display_name: l.display_name ?? null, email: l.email, company: l.company ?? null,
      source: l.source ?? null, score: l.score ?? null, score_reason: l.score_reason ?? null,
      owner: l.owner ?? null, state: l.state ?? "new", last_touch_at: l.last_touch_at ?? null, created_at: l.created_at,
    })),
  });
}));

crm.get("/crm/deals", guard(async (_req, res) => {
  const rows = await safe<any[]>(() => admin.from("crm_deals").select("*").order("updated_at", { ascending: false }).limit(300), []);
  res.json({
    deals: rows.map((d) => ({
      id: d.id, title: d.title, company: d.company ?? null, contact_email: d.contact_email ?? null,
      stage: d.stage ?? "new", value: Number(d.value ?? 0), currency: d.currency ?? "GBP",
      probability: d.probability ?? STAGE_PROB[d.stage] ?? null, owner: d.owner ?? null,
      next_step: d.next_step ?? null, next_step_due: d.next_step_due ?? null, thread_id: d.thread_id ?? null,
      stale_days: !["won", "lost"].includes(d.stage) ? days(d.updated_at) : null,
      updated_at: d.updated_at,
    })),
  });
}));

crm.post("/crm/deals/stage", guard(async (req, res, c) => {
  const id = String(req.body?.deal_id || req.body?.id || "");
  const stage = String(req.body?.stage || "");
  if (!id || !(stage in STAGE_PROB)) return res.status(400).json({ error: "deal_id_and_stage_required" });
  const up = await admin.from("crm_deals")
    .update({ stage, probability: STAGE_PROB[stage], updated_at: new Date().toISOString() }).eq("id", id);
  if (up.error) return res.status(500).json({ error: "stage_failed" });
  try { await admin.from("crm_activities").insert({ kind: "stage_change", actor: c.user.email, subject: `Stage -> ${stage}`, deal_id: id }); } catch {}
  await auditCrm(c.user.email || c.user.id, "deal.stage", `${id}:${stage}`, ipOf(req));
  res.json({ ok: true });
}));

crm.post("/crm/leads/convert", guard(async (req, res, c) => {
  const lead_id = String(req.body?.lead_id || "");
  if (!lead_id) return res.status(400).json({ error: "lead_id_required" });
  const lead = (await safe<any[]>(() => admin.from("crm_leads").select("*").eq("id", lead_id).limit(1), []))[0] as any;
  if (!lead) return res.status(404).json({ error: "lead_not_found" });
  const ins = await admin.from("crm_deals").insert({
    title: lead.company ? `${lead.company} — opportunity` : `${lead.email} — opportunity`,
    company: lead.company ?? null, contact_email: lead.email, stage: "qualified",
    value: Number(req.body?.value ?? 0), currency: "GBP", probability: STAGE_PROB.qualified,
    owner: lead.owner ?? c.user.email, updated_at: new Date().toISOString(),
  }).select("id").limit(1);
  if (ins.error) return res.status(500).json({ error: "convert_failed" });
  await admin.from("crm_leads").update({ state: "converted" }).eq("id", lead_id);
  await auditCrm(c.user.email || c.user.id, "lead.convert", lead_id, ipOf(req));
  res.json({ ok: true, deal_id: (ins.data?.[0] as any)?.id });
}));

/* -------------------------------------------------- activities / insights */
crm.get("/crm/activities", guard(async (_req, res) => {
  const rows = await safe<any[]>(() => admin.from("crm_activities").select("*").order("created_at", { ascending: false }).limit(200), []);
  res.json({ activities: rows });
}));

crm.get("/crm/insights", guard(async (_req, res) => {
  const rows = await safe<any[]>(() => admin.from("crm_ai_insights").select("*").order("created_at", { ascending: false }).limit(100), []);
  res.json({ insights: rows });
}));

/* ---------------------------------------------------- shared inbox/drafts */
crm.get("/crm/shared", guard(async (_req, res) => {
  const rows = await safe<any[]>(() => admin.from("crm_shared_items").select("*").order("created_at", { ascending: false }).limit(200), []);
  res.json({ items: rows });
}));

crm.post("/crm/shared/assign", guard(async (req, res, c) => {
  const id = String(req.body?.item_id || req.body?.id || "");
  const assigned_to = String(req.body?.assigned_to || "");
  if (!id || !assigned_to) return res.status(400).json({ error: "item_id_and_assignee_required" });
  const up = await admin.from("crm_shared_items").update({ assigned_to, state: "assigned" }).eq("id", id);
  if (up.error) return res.status(500).json({ error: "assign_failed" });
  await auditCrm(c.user.email || c.user.id, "shared.assign", `${id}->${assigned_to}`, ipOf(req));
  res.json({ ok: true });
}));

/* ------------------------------------ mentions / approvals / audit / team */
crm.get("/crm/mentions", guard(async (_req, res) => {
  const rows = await safe<any[]>(() => admin.from("crm_mentions").select("*").order("created_at", { ascending: false }).limit(200), []);
  res.json({ mentions: rows });
}));

crm.get("/crm/approvals", guard(async (_req, res) => {
  const rows = await safe<any[]>(() => admin.from("crm_approvals").select("*").order("created_at", { ascending: false }).limit(200), []);
  res.json({ approvals: rows });
}));

crm.post("/crm/approvals/decide", guard(async (req, res, c) => {
  const id = String(req.body?.approval_id || req.body?.id || "");
  const decision = String(req.body?.decision || "");
  if (!id || !["approved", "rejected"].includes(decision)) return res.status(400).json({ error: "approval_id_and_decision_required" });
  const up = await admin.from("crm_approvals").update({ state: decision, decided_by: c.user.email, decided_at: new Date().toISOString() }).eq("id", id);
  if (up.error) return res.status(500).json({ error: "decide_failed" });
  await auditCrm(c.user.email || c.user.id, `approval.${decision}`, id, ipOf(req));
  res.json({ ok: true });
}));

crm.get("/crm/audit", guard(async (_req, res) => {
  const rows = await safe<any[]>(() => admin.from("crm_audit").select("*").order("created_at", { ascending: false }).limit(200), []);
  res.json({ entries: rows });
}));

crm.get("/crm/permissions", guard(async (_req, res) => {
  const rows = await safe<any[]>(() => admin.from("crm_permissions").select("*"), []);
  res.json({
    members: rows.map((r) => ({
      user_id: r.user_id, email: r.email ?? "", role: r.role ?? "member",
      can_see_all_deals: r.can_see_all_deals === true,
    })),
  });
}));

/* ------------------------------------------------------- founder god view */
crm.get("/founder/crm/state", guard(async (_req, res) => {
  const deals = await safe<any[]>(() => admin.from("crm_deals").select("*"), []);
  const leads = await safe<any[]>(() => admin.from("crm_leads").select("id,state"), []);
  const sw = await safe<any[]>(() => admin.from("org_switches").select("value").eq("key", "crm_writes_enabled").limit(1), []);
  const open = deals.filter((d) => !["won", "lost"].includes(d.stage));
  res.json({
    crm_writes_enabled: sw.length ? sw[0].value === true || sw[0].value === "true" : true,
    deals_total: deals.length,
    leads_total: leads.length,
    pipeline_value: open.reduce((s, d) => s + Number(d.value ?? 0), 0),
    revenue_at_risk: open.filter((d) => (days(d.updated_at) ?? 0) >= 14).reduce((s, d) => s + Number(d.value ?? 0), 0),
    currency: deals[0]?.currency ?? "GBP",
  });
}));

crm.post("/founder/crm/toggle", guard(async (req, res, c) => {
  const enabled = req.body?.crm_writes_enabled === true;
  const up = await admin.from("org_switches")
    .upsert({ key: "crm_writes_enabled", value: enabled, updated_at: new Date().toISOString() }, { onConflict: "key" });
  if (up.error) return res.status(500).json({ error: "toggle_failed" });
  await auditCrm(c.user.email || c.user.id, enabled ? "crm.writes.enable" : "crm.writes.disable", null, ipOf(req));
  res.json({ ok: true });
}));

export default crm;
