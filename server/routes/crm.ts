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

async function writeEvidence(row: {
  org_id: string;
  actor: string;
  decision: string;
  why: string;
  source_table: string;
  source_id: string | null;
  action: string;
  result: string;
}) {
  try {
    await insertBest("crm_evidence", row);
  } catch {
    /* table optional until phase64 */
  }
}

async function writeEdge(
  org_id: string,
  from_kind: string,
  from_id: string,
  to_kind: string,
  to_id: string,
  kind: string,
) {
  try {
    await insertBest("crm_graph_edges", { org_id, from_kind, from_id, to_kind, to_id, kind });
  } catch {
    /* optional */
  }
}

async function threadForAddress(orgId: string, email: string): Promise<string | null> {
  if (!email.includes("@")) return null;
  const fromMsg = await safe<any[]>(
    () =>
      admin
        .from("mail_messages")
        .select("thread_id,sent_at")
        .eq("org_id", orgId)
        .eq("from_address", email)
        .not("thread_id", "is", null)
        .order("sent_at", { ascending: false })
        .limit(1),
    [],
  );
  if (fromMsg[0]?.thread_id) return String(fromMsg[0].thread_id);
  const threads = await safe<any[]>(
    () =>
      admin
        .from("mail_threads")
        .select("id,from_address,last_message_at")
        .eq("org_id", orgId)
        .eq("from_address", email)
        .order("last_message_at", { ascending: false })
        .limit(1),
    [],
  );
  return threads[0]?.id ? String(threads[0].id) : null;
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

function emailOf(value: unknown) {
  return String(value || "")
    .trim()
    .toLowerCase();
}

const CONTACT_SELECT =
  "id, display_name, primary_address, company_domain, health_score, last_contact_at, " +
  "stats:contact_stats(messages_in, messages_out, avg_reply_minutes, open_threads, last_contact_at, relationship, health_score), company:companies(name)";

function shapePerson(row: any) {
  const s = row?.stats || {};
  return {
    id: String(row.id),
    display_name: row.display_name ?? null,
    primary_address: emailOf(row.primary_address),
    company_name: row.company?.name || row.company_name || row.company_domain || null,
    relationship: s.relationship || row.relationship || null,
    health_score: s.health_score ?? row.health_score ?? null,
    last_contact_at: s.last_contact_at || row.last_contact_at || null,
    open_threads: Number(s.open_threads ?? row.open_threads ?? 0),
  };
}

async function loadPeople(c: CrmCtx, deals: any[], leads: any[]) {
  const joined = await safe<any[]>(
    () => admin.from("contacts").select(CONTACT_SELECT).eq("org_id", c.orgId).limit(400),
    [],
  );
  const plain =
    joined.length > 0
      ? joined
      : await safe<any[]>(
          () =>
            admin
              .from("contacts")
              .select("id,display_name,primary_address,company_domain,health_score,last_contact_at")
              .eq("org_id", c.orgId)
              .limit(400),
          [],
        );
  const map = new Map<string, ReturnType<typeof shapePerson>>();
  for (const row of plain) {
    const person = shapePerson(row);
    if (person.primary_address.includes("@")) map.set(person.primary_address, person);
  }
  for (const d of deals) {
    const address = emailOf(d.contact_email);
    if (!address.includes("@") || map.has(address)) continue;
    map.set(address, {
      id: String(d.id),
      display_name: d.company || address,
      primary_address: address,
      company_name: d.company ?? null,
      relationship: null,
      health_score: null,
      last_contact_at: d.updated_at ?? null,
      open_threads: 0,
    });
  }
  for (const l of leads) {
    const address = emailOf(l.email);
    if (!address.includes("@") || map.has(address)) continue;
    map.set(address, {
      id: String(l.id),
      display_name: l.display_name || address,
      primary_address: address,
      company_name: l.company ?? null,
      relationship: null,
      health_score: null,
      last_contact_at: l.last_touch_at ?? l.created_at ?? null,
      open_threads: 0,
    });
  }
  return [...map.values()];
}

async function loadMail(c: CrmCtx) {
  const byOrg = await safe<any[]>(
    () =>
      admin
        .from("mail_messages")
        .select("id,thread_id,subject,from_address,direction,sent_at")
        .eq("org_id", c.orgId)
        .order("sent_at", { ascending: false })
        .limit(40),
    [],
  );
  if (byOrg.length) return byOrg;
  const threads = await safe<any[]>(
    () =>
      admin
        .from("mail_threads")
        .select("id,subject,from_address,last_message_at,status,folder")
        .eq("org_id", c.orgId)
        .order("last_message_at", { ascending: false })
        .limit(40),
    [],
  );
  return threads.map((t) => ({
    id: t.id,
    thread_id: t.id,
    subject: t.subject,
    from_address: t.from_address,
    direction: "in",
    sent_at: t.last_message_at,
    open: t.status === "open" || t.folder === "inbox",
  }));
}

crm.get(
  "/crm/live",
  guard("pro", async (_req, res, c) => {
    const deals = await safe<any[]>(() => scopedDeals(c), []);
    const leads = await safe<any[]>(() => scopedLeads(c), []);
    const contacts = await loadPeople(c, deals, leads);
    const tasks = await safe<any[]>(
      () =>
        admin.from("work_tasks").select("id,title,status,due_at,owner,thread_id,source,created_at,thread_subject").eq("org_id", c.orgId).limit(300),
      [],
    );
    const promises = await safe<any[]>(
      () =>
        admin
          .from("work_promises")
          .select("id,quote,suggested_title,suggested_due_at,status,thread_id,thread_subject")
          .eq("org_id", c.orgId)
          .limit(200),
      [],
    );
    const events = await safe<any[]>(
      () =>
        admin
          .from("calendar_events")
          .select("id,title,starts_at,organiser,thread_id")
          .eq("org_id", c.orgId)
          .gte("starts_at", new Date(Date.now() - 40 * 86400000).toISOString())
          .limit(200),
      [],
    );
    const attendees = await safe<any[]>(
      () => admin.from("calendar_attendees").select("event_id,address,org_id").eq("org_id", c.orgId).limit(2000),
      [],
    );
    const attendeeRows =
      attendees.length > 0
        ? attendees
        : await safe<any[]>(() => admin.from("calendar_attendees").select("event_id,address").limit(2000), []);
    const mail = await loadMail(c);
    const activities = await safe<any[]>(
      () => admin.from("crm_activities").select("id,kind,subject,actor,deal_id,contact_email,created_at").order("created_at", { ascending: false }).limit(40),
      [],
    );

    const open = deals.filter((d) => !["won", "lost"].includes(d.stage));
    const radar: { kind: string; title: string; why: string; source: string; href: string }[] = [];
    const next_actions: { kind: string; title: string; action: string; why: string; href: string }[] = [];
    const openMailByAddress = new Map<string, number>();
    for (const m of mail) {
      const addr = emailOf(m.from_address);
      if (!addr.includes("@")) continue;
      if (m.open || m.direction === "in") {
        openMailByAddress.set(addr, (openMailByAddress.get(addr) || 0) + 1);
      }
    }
    for (const p of contacts) {
      if (!p.open_threads) p.open_threads = openMailByAddress.get(p.primary_address) || 0;
    }

    for (const d of open) {
      const quiet = days(d.updated_at) ?? 0;
      if (quiet >= 14) {
        const href = d.thread_id ? `/app/mail/inbox/${d.thread_id}` : "/app/crm/pipeline";
        radar.push({
          kind: "silent",
          title: d.title,
          why: `Deal untouched ${quiet} days`,
          source: `crm_deals:${d.id}`,
          href,
        });
        next_actions.push({
          kind: "follow_up",
          title: d.title,
          action: "Write the thread or set a next step",
          why: `${quiet} days silent`,
          href,
        });
      }
      const contact = emailOf(d.contact_email);
      if (contact) {
        const meetIds = new Set(
          attendeeRows.filter((a) => emailOf(a.address) === contact).map((a) => a.event_id),
        );
        const lastMeet = events
          .filter((e) => meetIds.has(e.id) || emailOf(e.organiser) === contact)
          .sort((a, b) => String(b.starts_at).localeCompare(String(a.starts_at)))[0];
        const gap = lastMeet ? days(lastMeet.starts_at) : 999;
        if (gap >= 12) {
          next_actions.push({
            kind: "meeting",
            title: d.title,
            action: "No decision-maker meeting in 12 days",
            why: lastMeet ? `Last meeting ${lastMeet.starts_at}` : "No meeting on record",
            href: "/app/calendar",
          });
        }
      }
    }

    for (const p of contacts) {
      const name = p.display_name || p.primary_address;
      const quiet = days(p.last_contact_at);
      if (p.health_score == null) {
        let score = 72;
        if (quiet == null || quiet >= 14) score -= 18;
        if ((p.open_threads || 0) > 0) score -= 10;
        p.health_score = Math.max(0, Math.min(100, score));
      }
      if ((p.open_threads || 0) > 0) {
        next_actions.push({
          kind: "no_pitch",
          title: name,
          action: "Don't send a sales email — an open support thread is still waiting",
          why: `${p.open_threads} open mail threads`,
          href: "/app/mail/inbox",
        });
      }
      if (p.relationship === "at_risk" || p.relationship === "dormant" || (quiet != null && quiet >= 14 && open.some((d) => emailOf(d.contact_email) === p.primary_address))) {
        radar.push({
          kind: "health",
          title: name,
          why: p.relationship
            ? `Relationship ${p.relationship}${p.health_score != null ? ` · health ${p.health_score}` : ""}`
            : `Last touch ${quiet ?? "unknown"} days ago · health ${p.health_score}`,
          source: `contacts:${p.id}`,
          href: `/app/crm/relationships?email=${encodeURIComponent(p.primary_address)}`,
        });
      }
    }

    for (const t of tasks) {
      if (t.status === "done") continue;
      if (t.due_at && new Date(t.due_at).getTime() < Date.now()) {
        radar.push({
          kind: "promise_overdue",
          title: t.title,
          why: `Due ${t.due_at}`,
          source: `work_tasks:${t.id}`,
          href: "/app/work",
        });
        next_actions.push({
          kind: "promise",
          title: t.title,
          action: "Promise overdue — complete with evidence or move the date",
          why: `work_tasks:${t.id}`,
          href: "/app/work",
        });
      }
    }
    for (const pr of promises) {
      const due = pr.suggested_due_at;
      if (!due || new Date(due).getTime() >= Date.now()) continue;
      if (String(pr.status || "") === "done" || String(pr.status || "") === "kept") continue;
      radar.push({
        kind: "promise_overdue",
        title: pr.suggested_title || pr.quote || "Promise",
        why: `Due ${due}`,
        source: `work_promises:${pr.id}`,
        href: "/app/work",
      });
      next_actions.push({
        kind: "promise",
        title: pr.suggested_title || pr.quote || "Promise",
        action: "Promise overdue — complete with evidence or move the date",
        why: `work_promises:${pr.id}`,
        href: "/app/work",
      });
    }

    const timeline = [
      ...mail.map((m) => ({
        at: m.sent_at,
        kind: m.direction === "out" ? "email_out" : "email_in",
        title: m.subject || "(no subject)",
        source: m.from_address,
        href: m.thread_id ? `/app/mail/inbox/${m.thread_id}` : "/app/mail/inbox",
      })),
      ...events.slice(0, 20).map((e) => ({
        at: e.starts_at,
        kind: "meeting",
        title: e.title,
        source: e.organiser,
        href: "/app/calendar",
      })),
      ...tasks
        .filter((t) => t.created_at || t.due_at)
        .slice(0, 20)
        .map((t) => ({
          at: t.created_at || t.due_at,
          kind: "work",
          title: t.title,
          source: t.owner,
          href: "/app/work",
        })),
      ...activities.map((a) => ({
        at: a.created_at,
        kind: a.kind || "note",
        title: a.subject || a.kind,
        source: a.actor,
        href: "/app/crm/activity",
      })),
    ]
      .filter((row) => row.at)
      .sort((a, b) => String(b.at).localeCompare(String(a.at)))
      .slice(0, 30);

    const nodes: { id: string; kind: string; label: string; email?: string | null }[] = [
      ...contacts.slice(0, 40).map((p) => ({
        id: `person:${p.id}`,
        kind: "person",
        label: p.display_name || p.primary_address,
        email: p.primary_address,
      })),
      ...open.slice(0, 40).map((d) => ({
        id: `deal:${d.id}`,
        kind: "deal",
        label: d.title,
        email: d.contact_email,
      })),
    ];
    const seen = new Set(nodes.map((n) => n.id));
    const addNode = (node: { id: string; kind: string; label: string; email?: string | null }) => {
      if (seen.has(node.id)) return;
      seen.add(node.id);
      nodes.push(node);
    };
    const edges: { from: string; to: string; kind: string }[] = [];
    for (const d of open) {
      const person = contacts.find((p) => emailOf(p.primary_address) === emailOf(d.contact_email));
      if (person) edges.push({ from: `person:${person.id}`, to: `deal:${d.id}`, kind: "owns" });
      if (d.thread_id) {
        addNode({ id: `mail:${d.thread_id}`, kind: "mail", label: d.title });
        edges.push({ from: `deal:${d.id}`, to: `mail:${d.thread_id}`, kind: "thread" });
      }
    }
    for (const m of mail) {
      if (!m.thread_id) continue;
      addNode({ id: `mail:${m.thread_id}`, kind: "mail", label: m.subject || "(no subject)" });
      const person = contacts.find((p) => emailOf(p.primary_address) === emailOf(m.from_address));
      if (person) edges.push({ from: `person:${person.id}`, to: `mail:${m.thread_id}`, kind: "wrote" });
    }
    for (const t of tasks) {
      addNode({ id: `work:${t.id}`, kind: "work", label: t.title });
      const ownerPerson = contacts.find((p) => emailOf(p.primary_address) === emailOf(t.owner));
      if (ownerPerson) edges.push({ from: `person:${ownerPerson.id}`, to: `work:${t.id}`, kind: "assigned" });
      const deal = open.find((d) => d.thread_id && d.thread_id === t.thread_id) || open.find((d) => String(t.source || "").includes(d.id));
      if (deal) edges.push({ from: `deal:${deal.id}`, to: `work:${t.id}`, kind: "workstream" });
      if (t.thread_id) {
        addNode({ id: `mail:${t.thread_id}`, kind: "mail", label: t.thread_subject || t.title });
        edges.push({ from: `work:${t.id}`, to: `mail:${t.thread_id}`, kind: "thread" });
      }
    }
    for (const e of events) {
      addNode({ id: `calendar:${e.id}`, kind: "calendar", label: e.title });
      const who = attendeeRows.filter((a) => a.event_id === e.id).map((a) => emailOf(a.address));
      if (e.organiser) who.push(emailOf(e.organiser));
      for (const addr of who) {
        const person = contacts.find((p) => p.primary_address === addr);
        if (person) edges.push({ from: `person:${person.id}`, to: `calendar:${e.id}`, kind: "attends" });
      }
      if (e.thread_id) {
        addNode({ id: `mail:${e.thread_id}`, kind: "mail", label: e.title });
        edges.push({ from: `calendar:${e.id}`, to: `mail:${e.thread_id}`, kind: "thread" });
      }
    }
    const storedEdges = await safe<any[]>(
      () =>
        admin
          .from("crm_graph_edges")
          .select("from_kind,from_id,to_kind,to_id,kind")
          .eq("org_id", c.orgId)
          .limit(80),
      [],
    );
    for (const e of storedEdges) {
      const fromId = `${e.from_kind}:${e.from_id}`;
      const toId = `${e.to_kind}:${e.to_id}`;
      addNode({ id: fromId, kind: e.from_kind, label: e.from_kind });
      addNode({ id: toId, kind: e.to_kind, label: e.to_kind });
      edges.push({ from: fromId, to: toId, kind: e.kind });
    }

    res.json({
      radar: radar.slice(0, 24),
      next_actions: next_actions.slice(0, 16),
      timeline,
      people: contacts.slice(0, 60),
      graph: { nodes, edges: edges.slice(0, 80) },
      counts: {
        contacts: contacts.length,
        open_deals: open.length,
        overdue_tasks: tasks.filter((t) => t.status !== "done" && t.due_at && new Date(t.due_at).getTime() < Date.now()).length,
        promises: promises.length,
      },
    });
  }),
);

crm.get(
  "/crm/memory",
  guard("pro", async (req, res, c) => {
    const email = emailOf(req.query.email);
    if (!email || !email.includes("@")) return res.status(400).json({ error: "email_required" });
    const allDeals = await safe<any[]>(() => scopedDeals(c), []);
    const allLeads = await safe<any[]>(() => scopedLeads(c), []);
    const people = await loadPeople(c, allDeals, allLeads);
    const person = people.find((p) => p.primary_address === email) || null;
    const deals = allDeals.filter((d) => emailOf(d.contact_email) === email);
    const tasks = await safe<any[]>(
      () => admin.from("work_tasks").select("*").eq("org_id", c.orgId).limit(200),
      [],
    );
    const relatedTasks = tasks.filter(
      (t) =>
        emailOf(t.owner) === email ||
        deals.some((d) => d.thread_id && d.thread_id === t.thread_id) ||
        String(t.source || "").includes("crm_deal"),
    );
    let mail = await safe<any[]>(
      () =>
        admin
          .from("mail_messages")
          .select("id,thread_id,subject,from_address,direction,sent_at,snippet")
          .eq("org_id", c.orgId)
          .or(`from_address.ilike.%${email}%,to_addresses.ilike.%${email}%`)
          .order("sent_at", { ascending: false })
          .limit(40),
      [],
    );
    if (!mail.length) {
      mail = (await loadMail(c)).filter((m) => emailOf(m.from_address) === email);
    }
    const events = await safe<any[]>(
      () =>
        admin
          .from("calendar_events")
          .select("id,title,starts_at,organiser,thread_id")
          .eq("org_id", c.orgId)
          .limit(80),
      [],
    );
    const attendees = await safe<any[]>(
      () => admin.from("calendar_attendees").select("event_id,address").eq("org_id", c.orgId).limit(500),
      [],
    );
    const meetIds = new Set(attendees.filter((a) => emailOf(a.address) === email).map((a) => a.event_id));
    const relatedEvents = events.filter((e) => meetIds.has(e.id) || emailOf(e.organiser) === email);
    const no_pitch = Boolean(person?.open_threads) || mail.some((m) => m.open || m.direction === "in");
    const lastMeet = relatedEvents.sort((a, b) => String(b.starts_at).localeCompare(String(a.starts_at)))[0];
    const meetGap = lastMeet ? days(lastMeet.starts_at) : 999;
    res.json({
      email,
      person,
      deals,
      tasks: relatedTasks.map((t) => ({
        id: t.id,
        title: t.title,
        status: t.status,
        due_at: t.due_at ?? null,
        thread_id: t.thread_id ?? null,
      })),
      timeline: [
        ...mail.map((m) => ({
          at: m.sent_at,
          kind: m.direction === "out" ? "email_out" : "email_in",
          title: m.subject || "(no subject)",
          detail: m.snippet || null,
          href: m.thread_id ? `/app/mail/inbox/${m.thread_id}` : "/app/mail/inbox",
        })),
        ...relatedEvents.map((e) => ({
          at: e.starts_at,
          kind: "meeting",
          title: e.title,
          detail: e.organiser || null,
          href: "/app/calendar",
        })),
        ...relatedTasks.map((t) => ({
          at: t.due_at || t.created_at,
          kind: "work",
          title: t.title,
          detail: t.status || null,
          href: "/app/work",
        })),
      ]
        .filter((row) => row.at)
        .sort((a, b) => String(b.at).localeCompare(String(a.at)))
        .slice(0, 40),
      next_actions: [
        ...(no_pitch
          ? [
              {
                action: "Don't send a sales email — an open support thread is still waiting",
                why: `${person?.open_threads || mail.length} open threads`,
                href: "/app/mail/inbox",
              },
            ]
          : []),
        ...(deals.length && meetGap >= 12
          ? [
              {
                action: "No decision-maker meeting in 12 days",
                why: lastMeet ? `Last meeting ${lastMeet.starts_at}` : "No meeting on record",
                href: "/app/calendar",
              },
            ]
          : []),
        ...deals
          .filter((d) => (days(d.updated_at) ?? 0) >= 14)
          .map((d) => ({
            action: "Write the thread or set a next step",
            why: `Deal untouched ${days(d.updated_at)} days`,
            href: d.thread_id ? `/app/mail/inbox/${d.thread_id}` : "/app/crm/pipeline",
          })),
      ],
    });
  }),
);

crm.post(
  "/crm/deals/work",
  guard("pro", async (req, res, c) => {
    const id = String(req.body?.deal_id || req.body?.id || "");
    if (!id) return res.status(400).json({ error: "deal_id_required" });
    const owned = await safe<any[]>(() => scopedDeals(c).eq("id", id).limit(1), []);
    const deal = owned[0];
    if (!deal) return res.status(404).json({ error: "deal_not_found" });
    const ins = await insertBest("work_tasks", {
      org_id: c.orgId,
      title: deal.title,
      status: "todo",
      owner: deal.owner || c.email,
      due_at: deal.next_step_due || null,
      thread_id: deal.thread_id || null,
      source: "crm_deal",
      created_by: c.user.id,
    });
    if (ins.error) return res.status(500).json({ error: ins.error.message || "work_create_failed" });
    const taskId = (ins.data?.[0] as any)?.id;
    await writeEdge(c.orgId, "deal", id, "work", String(taskId || id), "workstream");
    await writeEvidence({
      org_id: c.orgId,
      actor: c.email,
      decision: "CRM → Work",
      why: deal.title,
      source_table: "crm_deals",
      source_id: id,
      action: "deal.work",
      result: taskId ? `work_tasks:${taskId}` : "created",
    });
    await auditCrm(c.email, "deal.work", id, ipOf(req));
    res.json({ ok: true, task_id: taskId });
  }),
);

crm.post(
  "/crm/deals/thread",
  guard("pro", async (req, res, c) => {
    const id = String(req.body?.deal_id || req.body?.id || "");
    if (!id) return res.status(400).json({ error: "deal_id_required" });
    const owned = await safe<any[]>(() => scopedDeals(c).eq("id", id).limit(1), []);
    const deal = owned[0];
    if (!deal) return res.status(404).json({ error: "deal_not_found" });
    const address = emailOf(deal.contact_email);
    const tid = await threadForAddress(c.orgId, address);
    if (!tid) return res.status(404).json({ error: "no_thread_for_address" });
    const up = await admin
      .from("crm_deals")
      .update({ thread_id: tid, updated_at: new Date().toISOString() })
      .eq("id", id);
    if (up.error) return res.status(500).json({ error: "thread_attach_failed" });
    await writeEdge(c.orgId, "deal", id, "mail", tid, "thread");
    await writeEvidence({
      org_id: c.orgId,
      actor: c.email,
      decision: "Conversation → CRM",
      why: `Recorded thread for ${address}`,
      source_table: "crm_deals",
      source_id: id,
      action: "deal.thread",
      result: `mail_threads:${tid}`,
    });
    await auditCrm(c.email, "deal.thread", `${id}:${tid}`, ipOf(req));
    res.json({ ok: true, thread_id: tid });
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
    const leadId = (ins.data?.[0] as any)?.id;
    await writeEvidence({
      org_id: c.orgId,
      actor: c.email,
      decision: "Lead captured",
      why: email,
      source_table: "crm_leads",
      source_id: leadId ? String(leadId) : email,
      action: "lead.create",
      result: "new",
    });
    await auditCrm(c.email, "lead.create", email, ipOf(req));
    res.json({ ok: true, id: leadId });
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
    const tid = contact_email ? await threadForAddress(c.orgId, contact_email) : null;
    if (id && tid) {
      await admin.from("crm_deals").update({ thread_id: tid }).eq("id", id);
      await writeEdge(c.orgId, "deal", String(id), "mail", tid, "thread");
    }
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
    await writeEvidence({
      org_id: c.orgId,
      actor: c.email,
      decision: "Deal opened",
      why: title,
      source_table: "crm_deals",
      source_id: id ? String(id) : null,
      action: "deal.create",
      result: tid ? `thread:${tid}` : "no_thread_yet",
    });
    await auditCrm(c.email, "deal.create", id || title, ipOf(req));
    res.json({ ok: true, id, thread_id: tid });
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
    await writeEvidence({
      org_id: c.orgId,
      actor: c.email,
      decision: `Stage → ${stage}`,
      why: owned[0]?.title || id,
      source_table: "crm_deals",
      source_id: id,
      action: "deal.stage",
      result: stage,
    });
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
    const dealId = (ins.data?.[0] as any)?.id;
    const tid = await threadForAddress(c.orgId, emailOf(lead.email));
    if (dealId && tid) {
      await admin.from("crm_deals").update({ thread_id: tid }).eq("id", dealId);
      await writeEdge(c.orgId, "deal", String(dealId), "mail", tid, "thread");
    }
    await admin.from("crm_leads").update({ state: "converted" }).eq("id", lead_id);
    await writeEvidence({
      org_id: c.orgId,
      actor: c.email,
      decision: "Lead converted",
      why: lead.email,
      source_table: "crm_leads",
      source_id: lead_id,
      action: "lead.convert",
      result: dealId ? `crm_deals:${dealId}` : "created",
    });
    await auditCrm(c.email, "lead.convert", lead_id, ipOf(req));
    res.json({ ok: true, deal_id: dealId, thread_id: tid });
  }),
);

/* -------------------------------------------------- activities / insights */
crm.get(
  "/crm/evidence",
  guard("pro", async (_req, res, c) => {
    const rows = await safe<any[]>(
      () =>
        admin
          .from("crm_evidence")
          .select("id,actor,decision,why,source_table,source_id,action,result,created_at")
          .eq("org_id", c.orgId)
          .order("created_at", { ascending: false })
          .limit(100),
      [],
    );
    res.json({
      entries: rows.map((r) => ({
        id: r.id,
        actor: r.actor ?? null,
        decision: r.decision,
        why: r.why ?? null,
        source_table: r.source_table ?? null,
        source_id: r.source_id ?? null,
        action: r.action ?? null,
        result: r.result ?? null,
        created_at: r.created_at,
      })),
    });
  }),
);

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
