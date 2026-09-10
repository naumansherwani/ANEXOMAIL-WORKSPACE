import { Router } from "express";
import { admin } from "../lib/supa";

export const crm = Router();

type CrmTier = "none" | "pro" | "business" | "business_pro";

type CrmCtx = {
  user: { id: string; email: string };
  orgId: string;
  email: string;
  plan: CrmTier;
  owners: string[];
};

function normalizePlan(plan: string | null | undefined): "basic" | "pro" | "business" | "business_pro" {
  const p = String(plan || "basic")
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_");
  if (p === "business_pro" || p === "businesspro") return "business_pro";
  if (p === "business") return "business";
  if (p === "pro") return "pro";
  return "basic";
}

function platformPlan(workspace: string | null | undefined, ai: string | null | undefined) {
  const w = normalizePlan(workspace);
  const a = String(ai || "")
    .trim()
    .toLowerCase();
  let included: ReturnType<typeof normalizePlan> = "basic";
  if (a === "ai_executive") included = "business_pro";
  else if (a === "ai_business" || a === "ai_pro" || a === "ai") included = "business";
  const rank = (p: string) => (p === "business_pro" ? 4 : p === "business" ? 3 : p === "pro" ? 2 : 1);
  return rank(included) > rank(w) ? included : w;
}

function crmTier(plan: string): CrmTier {
  if (plan === "business_pro") return "business_pro";
  if (plan === "business") return "business";
  if (plan === "pro") return "pro";
  return "none";
}

async function resolvePlan(uid: string, email: string): Promise<CrmTier> {
  const emailLower = email.toLowerCase();
  const anexo = emailLower.endsWith("@anexomail.com") ? emailLower : null;
  const family = anexo
    ? await admin.from("family_accounts").select("plan,ai_plan").eq("email", anexo).maybeSingle()
    : { data: null as any };
  const trial = await admin.from("trial_accounts").select("plan,anexomail_address").eq("user_id", uid).maybeSingle();
  const addr = String(trial.data?.anexomail_address || anexo || "").toLowerCase();
  const familyByAddr =
    !family.data && addr
      ? await admin.from("family_accounts").select("plan,ai_plan").eq("email", addr).maybeSingle()
      : family;
  const row = familyByAddr.data || family.data;
  const plan = platformPlan(row?.plan || trial.data?.plan, row?.ai_plan);
  return crmTier(plan);
}

async function ctx(req: any): Promise<CrmCtx | { error: string; status: number }> {
  const h = String(req.headers["authorization"] || "");
  const token = h.startsWith("Bearer ") ? h.slice(7) : "";
  if (!token) return { error: "unauthorized", status: 401 };
  const { data } = await admin.auth.getUser(token);
  const user = data?.user;
  if (!user) return { error: "unauthorized", status: 401 };
  const email = String(user.email || "")
    .trim()
    .toLowerCase();
  const requested = String(req.header("x-org-id") || req.query.org_id || "");
  const { data: rows } = await admin.from("org_members").select("org_id,email").eq("user_id", user.id);
  const ids = (rows || []).map((r: any) => r.org_id).filter(Boolean);
  if (!ids.length) return { error: "no_workspace", status: 409 };
  const orgId = requested && ids.includes(requested) ? requested : ids[0];
  const { data: members } = await admin.from("org_members").select("email").eq("org_id", orgId);
  const owners = Array.from(
    new Set(
      (members || [])
        .map((m: any) => String(m.email || "").trim().toLowerCase())
        .filter(Boolean)
        .concat(email),
    ),
  );
  const plan = await resolvePlan(user.id, email);
  return { user: { id: user.id, email }, orgId, email, plan, owners };
}

function guard(min: CrmTier, handler: (req: any, res: any, c: CrmCtx) => Promise<any>) {
  const need = min === "business_pro" ? 3 : min === "business" ? 2 : min === "pro" ? 1 : 0;
  const rank = (p: CrmTier) => (p === "business_pro" ? 3 : p === "business" ? 2 : p === "pro" ? 1 : 0);
  return async (req: any, res: any) => {
    try {
      const c = await ctx(req);
      if ("error" in c) return res.status(c.status).json({ error: c.error });
      if (rank(c.plan) < need) {
        return res.status(403).json({
          error: "package_required",
          message:
            min === "business_pro"
              ? "CRM ledger is on Business Pro."
              : min === "business"
                ? "Shared CRM work is on Business."
                : "CRM is on Pro and above.",
        });
      }
      return await handler(req, res, c);
    } catch (e: any) {
      console.error("[crm]", e?.message || e);
      return res.status(500).json({ error: "crm_failed" });
    }
  };
}

async function safe<T>(fn: () => Promise<{ data: any; error: any }>, fallback: T): Promise<T> {
  try {
    const { data, error } = await fn();
    if (error) return fallback;
    return (data as T) ?? fallback;
  } catch {
    return fallback;
  }
}

async function insertBest(table: string, row: Record<string, unknown>) {
  const first = await admin.from(table).insert(row).select("id").limit(1);
  if (!first.error) return first;
  const slim = { ...row };
  delete slim.org_id;
  return admin.from(table).insert(slim).select("id").limit(1);
}

const STAGE_PROB: Record<string, number> = {
  new: 10,
  qualified: 30,
  proposal: 55,
  negotiation: 75,
  won: 100,
  lost: 0,
};
const days = (iso?: string | null) =>
  iso ? Math.floor((Date.now() - new Date(iso).getTime()) / 86400000) : null;

async function auditCrm(actor: string, action: string, target: string | null, ip: string | null) {
  try {
    await admin.from("crm_audit").insert({ actor, action, target, ip });
  } catch {
    /* audit table optional */
  }
}
const ipOf = (req: any) =>
  String(req.headers["x-forwarded-for"] || req.socket?.remoteAddress || "")
    .split(",")[0]
    .trim() || null;

function scopedLeads(c: CrmCtx) {
  if (c.plan === "pro") return admin.from("crm_leads").select("*").in("owner", [c.email]);
  return admin.from("crm_leads").select("*").in("owner", c.owners);
}

function scopedDeals(c: CrmCtx) {
  if (c.plan === "pro") return admin.from("crm_deals").select("*").in("owner", [c.email]);
  return admin.from("crm_deals").select("*").in("owner", c.owners);
}

/* --------------------------------------------------------------- overview */
crm.get(
  "/crm/overview",
  guard("pro", async (_req, res, c) => {
    const deals = await safe<any[]>(() => scopedDeals(c), []);
    const leads = await safe<any[]>(() => scopedLeads(c), []);
    const open = deals.filter((d) => !["won", "lost"].includes(d.stage));
    const monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1).getTime();
    const stages = ["new", "qualified", "proposal", "negotiation", "won", "lost"];
    res.json({
      currency: deals[0]?.currency ?? "GBP",
      pipeline_value: open.reduce((s, d) => s + Number(d.value ?? 0), 0),
      weighted_value: Math.round(
        open.reduce(
          (s, d) => s + Number(d.value ?? 0) * ((d.probability ?? STAGE_PROB[d.stage] ?? 0) / 100),
          0,
        ),
      ),
      won_this_month: deals
        .filter((d) => d.stage === "won" && new Date(d.updated_at ?? 0).getTime() >= monthStart)
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
  }),
);

/* ------------------------------------------------------------ leads/deals */
crm.get(
  "/crm/leads",
  guard("pro", async (req, res, c) => {
    const state = String(req.query.state || "all");
    let q = scopedLeads(c).order("created_at", { ascending: false }).limit(300);
    const rows = await safe<any[]>(() => q, []);
    const leads = rows
      .filter((l) => state === "all" || l.state === state)
      .map((l) => ({
        id: l.id,
        display_name: l.display_name ?? null,
        email: l.email,
        company: l.company ?? null,
        source: l.source ?? null,
        score: l.score ?? null,
        score_reason: l.score_reason ?? null,
        owner: l.owner ?? null,
        state: l.state ?? "new",
        last_touch_at: l.last_touch_at ?? null,
        created_at: l.created_at,
      }));
    res.json({ leads });
  }),
);

crm.post(
  "/crm/leads",
  guard("pro", async (req, res, c) => {
    const email = String(req.body?.email || "")
      .trim()
      .toLowerCase();
    if (!email || !email.includes("@")) return res.status(400).json({ error: "email_required" });
    const display_name = String(req.body?.display_name || "").trim() || null;
    const company = String(req.body?.company || "").trim() || null;
    const source = String(req.body?.source || "manual").trim() || "manual";
    const ins = await insertBest("crm_leads", {
      email,
      display_name,
      company,
      source,
      owner: c.email,
      state: "new",
      org_id: c.orgId,
    });
    if (ins.error) return res.status(500).json({ error: ins.error.message || "lead_create_failed" });
    await auditCrm(c.email, "lead.create", email, ipOf(req));
    res.json({ ok: true, id: (ins.data?.[0] as any)?.id });
  }),
);

crm.get(
  "/crm/deals",
  guard("pro", async (_req, res, c) => {
    const rows = await safe<any[]>(
      () => scopedDeals(c).order("updated_at", { ascending: false }).limit(300),
      [],
    );
    res.json({
      deals: rows.map((d) => ({
        id: d.id,
        title: d.title,
        company: d.company ?? null,
        contact_email: d.contact_email ?? null,
        stage: d.stage ?? "new",
        value: Number(d.value ?? 0),
        currency: d.currency ?? "GBP",
        probability: d.probability ?? STAGE_PROB[d.stage] ?? null,
        owner: d.owner ?? null,
        next_step: d.next_step ?? null,
        next_step_due: d.next_step_due ?? null,
        thread_id: d.thread_id ?? null,
        stale_days: !["won", "lost"].includes(d.stage) ? days(d.updated_at) : null,
        updated_at: d.updated_at,
      })),
    });
  }),
);

crm.post(
  "/crm/deals",
  guard("pro", async (req, res, c) => {
    const title = String(req.body?.title || "").trim();
    if (title.length < 2) return res.status(400).json({ error: "title_required" });
    const company = String(req.body?.company || "").trim() || null;
    const contact_email = String(req.body?.contact_email || "")
      .trim()
      .toLowerCase() || null;
    const value = Number(req.body?.value ?? 0);
    const next_step = String(req.body?.next_step || "").trim() || null;
    const ins = await insertBest("crm_deals", {
      title,
      company,
      contact_email,
      stage: "new",
      value: Number.isFinite(value) ? value : 0,
      currency: "GBP",
      probability: STAGE_PROB.new,
      owner: c.email,
      next_step,
      org_id: c.orgId,
      updated_at: new Date().toISOString(),
    });
    if (ins.error) return res.status(500).json({ error: ins.error.message || "deal_create_failed" });
    const id = (ins.data?.[0] as any)?.id;
    try {
      await admin.from("crm_activities").insert({
        kind: "note",
        actor: c.email,
        subject: title,
        body: "Deal opened.",
        deal_id: id,
        contact_email,
      });
    } catch {
      /* optional */
    }
    await auditCrm(c.email, "deal.create", id || title, ipOf(req));
    res.json({ ok: true, id });
  }),
);

crm.post(
  "/crm/deals/stage",
  guard("pro", async (req, res, c) => {
    const id = String(req.body?.deal_id || req.body?.id || "");
    const stage = String(req.body?.stage || "");
    if (!id || !(stage in STAGE_PROB)) return res.status(400).json({ error: "deal_id_and_stage_required" });
    const owned = await safe<any[]>(() => scopedDeals(c).eq("id", id).limit(1), []);
    if (!owned[0]) return res.status(404).json({ error: "deal_not_found" });
    const up = await admin
      .from("crm_deals")
      .update({ stage, probability: STAGE_PROB[stage], updated_at: new Date().toISOString() })
      .eq("id", id);
    if (up.error) return res.status(500).json({ error: "stage_failed" });
    try {
      await admin
        .from("crm_activities")
        .insert({ kind: "stage_change", actor: c.email, subject: `Stage → ${stage}`, deal_id: id });
    } catch {
      /* optional */
    }
    await auditCrm(c.email, "deal.stage", `${id}:${stage}`, ipOf(req));
    res.json({ ok: true });
  }),
);

crm.post(
  "/crm/leads/convert",
  guard("pro", async (req, res, c) => {
    const lead_id = String(req.body?.lead_id || req.body?.id || "");
    if (!lead_id) return res.status(400).json({ error: "lead_id_required" });
    const lead = (await safe<any[]>(() => scopedLeads(c).eq("id", lead_id).limit(1), []))[0] as any;
    if (!lead) return res.status(404).json({ error: "lead_not_found" });
    const ins = await insertBest("crm_deals", {
      title: lead.company ? `${lead.company} — opportunity` : `${lead.email} — opportunity`,
      company: lead.company ?? null,
      contact_email: lead.email,
      stage: "qualified",
      value: Number(req.body?.value ?? 0),
      currency: "GBP",
      probability: STAGE_PROB.qualified,
      owner: lead.owner ?? c.email,
      org_id: c.orgId,
      updated_at: new Date().toISOString(),
    });
    if (ins.error) return res.status(500).json({ error: "convert_failed" });
    await admin.from("crm_leads").update({ state: "converted" }).eq("id", lead_id);
    await auditCrm(c.email, "lead.convert", lead_id, ipOf(req));
    res.json({ ok: true, deal_id: (ins.data?.[0] as any)?.id });
  }),
);

/* -------------------------------------------------- activities / insights */
crm.get(
  "/crm/activities",
  guard("business_pro", async (_req, res, c) => {
    const rows = await safe<any[]>(
      () => admin.from("crm_activities").select("*").order("created_at", { ascending: false }).limit(200),
      [],
    );
    const allow = new Set(c.owners);
    res.json({
      activities: rows.filter(
        (a) => !a.actor || allow.has(String(a.actor).toLowerCase()) || allow.has(String(a.contact_email || "").toLowerCase()),
      ),
    });
  }),
);

crm.get("/crm/insights", guard("pro", async (_req, res) => {
  // Workspace packages have no LEO. Empty on purpose — AI host later.
  res.json({ insights: [] });
}));

/* ---------------------------------------------------- shared inbox/drafts */
crm.get(
  "/crm/shared",
  guard("business", async (req, res) => {
    const kind = String(req.query.kind || "");
    const rows = await safe<any[]>(
      () => admin.from("crm_shared_items").select("*").order("created_at", { ascending: false }).limit(200),
      [],
    );
    res.json({ items: kind ? rows.filter((r) => r.kind === kind) : rows });
  }),
);

crm.post(
  "/crm/shared/assign",
  guard("business", async (req, res, c) => {
    const id = String(req.body?.item_id || req.body?.id || "");
    const assigned_to = String(req.body?.assigned_to || "").trim().toLowerCase();
    if (!id || !assigned_to) return res.status(400).json({ error: "item_id_and_assignee_required" });
    const up = await admin.from("crm_shared_items").update({ assigned_to, state: "assigned" }).eq("id", id);
    if (up.error) return res.status(500).json({ error: "assign_failed" });
    await auditCrm(c.email, "shared.assign", `${id}->${assigned_to}`, ipOf(req));
    res.json({ ok: true });
  }),
);

/* ------------------------------------ mentions / approvals / audit / team */
crm.get(
  "/crm/mentions",
  guard("business", async (_req, res) => {
    const rows = await safe<any[]>(
      () => admin.from("crm_mentions").select("*").order("created_at", { ascending: false }).limit(200),
      [],
    );
    res.json({ mentions: rows });
  }),
);

crm.get(
  "/crm/approvals",
  guard("business", async (_req, res) => {
    const rows = await safe<any[]>(
      () => admin.from("crm_approvals").select("*").order("created_at", { ascending: false }).limit(200),
      [],
    );
    res.json({ approvals: rows });
  }),
);

crm.post(
  "/crm/approvals/decide",
  guard("business", async (req, res, c) => {
    const id = String(req.body?.approval_id || req.body?.id || "");
    const decision = String(req.body?.decision || "");
    if (!id || !["approved", "rejected"].includes(decision)) {
      return res.status(400).json({ error: "approval_id_and_decision_required" });
    }
    const up = await admin
      .from("crm_approvals")
      .update({ state: decision, decided_by: c.email, decided_at: new Date().toISOString() })
      .eq("id", id);
    if (up.error) return res.status(500).json({ error: "decide_failed" });
    await auditCrm(c.email, `approval.${decision}`, id, ipOf(req));
    res.json({ ok: true });
  }),
);

crm.get(
  "/crm/audit",
  guard("business_pro", async (_req, res) => {
    const rows = await safe<any[]>(
      () => admin.from("crm_audit").select("*").order("created_at", { ascending: false }).limit(200),
      [],
    );
    res.json({ entries: rows });
  }),
);

crm.get(
  "/crm/permissions",
  guard("business_pro", async (_req, res) => {
    const rows = await safe<any[]>(() => admin.from("crm_permissions").select("*"), []);
    res.json({
      members: rows.map((r) => ({
        user_id: r.user_id,
        email: r.email ?? "",
        role: r.role ?? "member",
        can_see_all_deals: r.can_see_all_deals === true,
      })),
    });
  }),
);

async function founderOnly(req: any, res: any) {
  const h = String(req.headers["authorization"] || "");
  const token = h.startsWith("Bearer ") ? h.slice(7) : "";
  if (!token) return null;
  const { data } = await admin.auth.getUser(token);
  const user = data?.user;
  if (!user) return null;
  const r = await admin.from("founder_accounts").select("user_id").eq("user_id", user.id).limit(1);
  if (!r.data?.length) {
    res.status(403).json({ error: "founder_only" });
    return null;
  }
  return user;
}

/* ------------------------------------------------------- founder god view */
crm.get("/founder/crm/state", async (req, res) => {
  try {
    const user = await founderOnly(req, res);
    if (user === null && !res.headersSent) return res.status(401).json({ error: "unauthorized" });
    if (!user) return;
    const deals = await safe<any[]>(() => admin.from("crm_deals").select("*"), []);
    const leads = await safe<any[]>(() => admin.from("crm_leads").select("id,state"), []);
    const sw = await safe<any[]>(
      () => admin.from("org_switches").select("value").eq("key", "crm_writes_enabled").limit(1),
      [],
    );
    const open = deals.filter((d) => !["won", "lost"].includes(d.stage));
    res.json({
      crm_writes_enabled: sw.length ? sw[0].value === true || sw[0].value === "true" : true,
      deals_total: deals.length,
      leads_total: leads.length,
      pipeline_value: open.reduce((s, d) => s + Number(d.value ?? 0), 0),
      revenue_at_risk: open
        .filter((d) => (days(d.updated_at) ?? 0) >= 14)
        .reduce((s, d) => s + Number(d.value ?? 0), 0),
      currency: deals[0]?.currency ?? "GBP",
    });
  } catch (e: any) {
    console.error("[crm]", e?.message || e);
    res.status(500).json({ error: "crm_failed" });
  }
});

crm.post("/founder/crm/toggle", async (req, res) => {
  try {
    const user = await founderOnly(req, res);
    if (user === null && !res.headersSent) return res.status(401).json({ error: "unauthorized" });
    if (!user) return;
    const enabled = req.body?.crm_writes_enabled === true;
    const up = await admin
      .from("org_switches")
      .upsert(
        { key: "crm_writes_enabled", value: enabled, updated_at: new Date().toISOString() },
        { onConflict: "key" },
      );
    if (up.error) return res.status(500).json({ error: "toggle_failed" });
    await auditCrm(user.email || user.id, enabled ? "crm.writes.enable" : "crm.writes.disable", null, ipOf(req));
    res.json({ ok: true });
  } catch (e: any) {
    console.error("[crm]", e?.message || e);
    res.status(500).json({ error: "crm_failed" });
  }
});

export default crm;
