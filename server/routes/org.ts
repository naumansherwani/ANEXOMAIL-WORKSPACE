import { Router } from "express";
import { admin } from "../lib/supa";

export const org = Router();

/* ---------------------------------------------------------------- session */
async function ctx(req: any) {
  const h = String(req.headers["authorization"] || "");
  const token = h.startsWith("Bearer ") ? h.slice(7) : "";
  if (!token) return { user: null as any, org_id: null as string | null };
  const { data } = await admin.auth.getUser(token);
  const user = data?.user || null;
  if (!user) return { user: null as any, org_id: null as string | null };
  let org_id: string | null = null;
  for (const t of ["org_members", "organization_members", "memberships"]) {
    try {
      const r = await admin.from(t).select("org_id, organisation_id, organization_id").eq("user_id", user.id).limit(1);
      const row: any = r.data?.[0];
      if (row) { org_id = row.org_id ?? row.organisation_id ?? row.organization_id ?? null; break; }
    } catch {}
  }
  if (!org_id) {
    try {
      const r = await admin.from("organizations").select("id").limit(1);
      org_id = (r.data?.[0] as any)?.id ?? null;
    } catch {}
  }
  return { user, org_id };
}

function guard(handler: (req: any, res: any, c: any) => Promise<any>) {
  return async (req: any, res: any) => {
    try {
      const c = await ctx(req);
      if (!c.user) return res.status(401).json({ error: "unauthorized" });
      return await handler(req, res, c);
    } catch (e: any) {
      console.error("[org]", e?.message || e);
      return res.status(500).json({ error: "org_failed" });
    }
  };
}

/** table read that never explodes when a table/column is absent */
async function safe<T>(fn: () => Promise<{ data: any; error: any }>, fallback: T): Promise<T> {
  try {
    const { data, error } = await fn();
    if (error) return fallback;
    return (data as T) ?? fallback;
  } catch { return fallback; }
}

async function writesEnabled(): Promise<boolean> {
  const rows = await safe<any[]>(
    () => admin.from("org_switches").select("value").eq("key", "org_writes_enabled").limit(1),
    [],
  );
  if (!rows.length) return true;
  const v = rows[0].value;
  return v === true || v === "true" || v?.enabled === true;
}

async function ledger(actor: string, action: string, target: string | null, ip: string | null) {
  try { await admin.rpc("org_ledger_append", { p_actor: actor, p_action: action, p_target: target, p_ip: ip }); }
  catch (e) { console.error("[ledger]", (e as any)?.message); }
}

const ipOf = (req: any) =>
  String(req.headers["x-forwarded-for"] || req.socket?.remoteAddress || "").split(",")[0].trim() || null;

/* --------------------------------------------------------------- overview */
org.get("/org/overview", guard(async (_req, res, c) => {
  const members = await safe<any[]>(() => admin.from("org_members").select("*").eq("org_id", c.org_id), []);
  const departments = await safe<any[]>(() => admin.from("org_departments").select("id").eq("org_id", c.org_id), []);
  const policies = await safe<any[]>(() => admin.from("org_policies").select("id,enabled").eq("org_id", c.org_id), []);
  const proof = await safe<any[]>(() => admin.from("org_dns_proof").select("*").eq("org_id", c.org_id), []);
  const anomalies = await safe<any[]>(() => admin.from("org_anomalies").select("id,state").eq("org_id", c.org_id), []);
  const orgRow = await safe<any[]>(() => admin.from("organizations").select("*").eq("id", c.org_id).limit(1), []);
  const o: any = orgRow[0] || {};
  const active = members.filter((m) => (m.status ?? "active") === "active");
  const mfaOn = active.filter((m) => m.mfa === true).length;
  const dnsGreen = proof.length ? proof.every((p) => p.state === "ok") : null;
  const openRisks = anomalies.filter((a) => a.state === "open").length;
  const score = active.length
    ? Math.round(
        (mfaOn / active.length) * 55 + (dnsGreen ? 30 : dnsGreen === false ? 5 : 15) + (openRisks ? 0 : 15),
      )
    : null;
  res.json({
    name: o.name ?? "ANEXOMAIL Workspace",
    primary_domain: o.primary_domain ?? o.domain ?? null,
    plan: o.plan ?? null,
    seats_used: active.length,
    seats_total: o.seats_paid ?? o.seats ?? active.length,
    members_active: active.length,
    members_suspended: members.filter((m) => m.status === "suspended").length,
    departments: departments.length,
    policies_active: policies.filter((p) => p.enabled).length,
    security_score: score,
    dns_all_green: dnsGreen,
    open_risks: openRisks,
    last_audit_at: null,
  });
}));

/* ---------------------------------------------------------------- members */
org.get("/org/members", guard(async (req, res, c) => {
  const status = String(req.query.status || "all");
  let rows = await safe<any[]>(() => admin.from("org_members").select("*").eq("org_id", c.org_id), []);
  if (status !== "all") rows = rows.filter((r) => (r.status ?? "active") === status);
  const usage = await safe<any[]>(() => admin.from("org_privilege_usage").select("*").eq("org_id", c.org_id), []);
  const sessions = await safe<any[]>(() => admin.from("org_sessions").select("user_id").eq("org_id", c.org_id), []);
  res.json({
    members: rows.map((r) => ({
      user_id: r.user_id,
      email: r.email ?? "",
      display_name: r.display_name ?? null,
      role: r.role ?? "member",
      department: r.department ?? null,
      status: r.status ?? "active",
      mfa: r.mfa === true,
      sessions: sessions.filter((s) => s.user_id === r.user_id).length,
      last_active_at: r.last_active_at ?? null,
      admin_power_last_used_at: usage.find((u) => u.user_id === r.user_id)?.last_used_at ?? null,
    })),
  });
}));

org.post("/org/members/blast-radius", guard(async (req, res, c) => {
  const user_id = String(req.body?.user_id || "");
  if (!user_id) return res.status(400).json({ error: "user_id_required" });
  const threads = await safe<any[]>(() => admin.from("mail_threads").select("id").eq("owner_id", user_id), []);
  const boxes = await safe<any[]>(() => admin.from("mailboxes").select("id").eq("owner_id", user_id), []);
  const appr = await safe<any[]>(() => admin.from("crm_approvals").select("id").eq("requested_by", user_id).eq("state", "pending"), []);
  const events = await safe<any[]>(() => admin.from("calendar_events").select("id").eq("owner_id", user_id), []);
  const owner = await safe<any[]>(() => admin.from("org_members").select("email").eq("org_id", c.org_id).eq("role", "owner").limit(1), []);
  res.json({
    user_id,
    threads_orphaned: threads.length,
    shared_addresses: boxes.length,
    pending_approvals: appr.length,
    calendar_events: events.length,
    transfer_to: (owner[0] as any)?.email ?? null,
  });
}));

org.post("/org/members/revoke", guard(async (req, res, c) => {
  if (!(await writesEnabled())) return res.status(423).json({ error: "org_writes_disabled" });
  const t0 = Date.now();
  const user_id = String(req.body?.user_id || "");
  if (!user_id) return res.status(400).json({ error: "user_id_required" });
  try { await admin.from("org_members").update({ status: "revoked" }).eq("org_id", c.org_id).eq("user_id", user_id); } catch {}
  try { await admin.from("org_sessions").delete().eq("org_id", c.org_id).eq("user_id", user_id); } catch {}
  try { await admin.auth.admin.signOut(user_id as any); } catch {}
  await ledger(c.user.email || c.user.id, "member.revoke", user_id, ipOf(req));
  res.json({ ok: true, ms: Date.now() - t0 });
}));

/* ------------------------------------------------------------------ roles */
const CAPS: { key: string; label: string; roles: string[] }[] = [
  { key: "mail.read.own", label: "Read own mail", roles: ["owner", "admin", "manager", "member", "viewer"] },
  { key: "mail.send", label: "Send mail", roles: ["owner", "admin", "manager", "member"] },
  { key: "mail.shared.assign", label: "Assign shared inbox", roles: ["owner", "admin", "manager"] },
  { key: "org.members.invite", label: "Invite members", roles: ["owner", "admin"] },
  { key: "org.members.revoke", label: "Revoke members", roles: ["owner", "admin"] },
  { key: "org.policies.write", label: "Change policies", roles: ["owner", "admin"] },
  { key: "org.audit.read", label: "Read audit ledger", roles: ["owner", "admin"] },
  { key: "org.billing", label: "Billing & seats", roles: ["owner"] },
  { key: "org.domain", label: "Domain & DNS proof", roles: ["owner"] },
  { key: "org.export", label: "Export all data", roles: ["owner"] },
];

org.get("/org/roles", guard(async (_req, res, c) => {
  const rows = await safe<any[]>(() => admin.from("org_members").select("role").eq("org_id", c.org_id), []);
  const count = (r: string) => rows.filter((x) => (x.role ?? "member") === r).length;
  res.json({
    roles: [
      { role: "owner", label: "Owner", description: "Domain, billing, kill switch.", members: count("owner") },
      { role: "admin", label: "Admin", description: "Members, policies, audit.", members: count("admin") },
      { role: "manager", label: "Manager", description: "Department + shared inbox.", members: count("manager") },
      { role: "member", label: "Member", description: "Own mail, send, collaborate.", members: count("member") },
      { role: "viewer", label: "Viewer", description: "Read-only access.", members: count("viewer") },
    ],
    capabilities: CAPS,
  });
}));

org.get("/org/privilege-radar", guard(async (_req, res, c) => {
  const rows = await safe<any[]>(() => admin.from("org_members").select("*").eq("org_id", c.org_id), []);
  const usage = await safe<any[]>(() => admin.from("org_privilege_usage").select("*").eq("org_id", c.org_id), []);
  const now = Date.now();
  const findings = rows
    .filter((r) => ["admin", "manager"].includes(r.role ?? ""))
    .map((r) => {
      const last = usage.find((u) => u.user_id === r.user_id)?.last_used_at;
      const days = last ? Math.floor((now - new Date(last).getTime()) / 86400000) : 9999;
      return { user_id: r.user_id, email: r.email ?? "", role: r.role, days_unused: days,
        recommendation: days >= 30 ? `Downgrade to member — ${r.role} powers unused ${days === 9999 ? "ever" : days + "d"}.` : "Keep — actively used." };
    })
    .filter((f) => f.days_unused >= 30);
  res.json({ findings });
}));

/* ------------------------------------------------------------ departments */
org.get("/org/departments", guard(async (_req, res, c) => {
  const rows = await safe<any[]>(() => admin.from("org_departments").select("*").eq("org_id", c.org_id).order("name"), []);
  res.json({
    departments: rows.map((d) => ({
      id: d.id, name: d.name, shared_address: d.shared_address ?? null,
      members: d.members_count ?? 0, sla_minutes: d.sla_minutes ?? null,
      escalation_chain: Array.isArray(d.escalation_chain) ? d.escalation_chain : [],
      budget_monthly: d.budget_monthly ?? null, currency: d.currency ?? "GBP",
      open_threads: d.open_threads ?? 0, breached_sla: d.breached_sla ?? 0,
    })),
  });
}));

/* --------------------------------------------------------------- policies */
org.get("/org/policies", guard(async (_req, res, c) => {
  const rows = await safe<any[]>(() => admin.from("org_policies").select("*").eq("org_id", c.org_id).order("name"), []);
  res.json({
    policies: rows.map((p) => ({
      id: p.id, name: p.name, kind: p.kind ?? "access", description: p.description ?? "",
      enabled: p.enabled === true, updated_at: p.updated_at ?? null,
    })),
  });
}));

org.post("/org/policies/simulate", guard(async (req, res, c) => {
  const policy_id = String(req.body?.policy_id || "");
  if (!policy_id) return res.status(400).json({ error: "policy_id_required" });
  const pol = (await safe<any[]>(() => admin.from("org_policies").select("*").eq("id", policy_id).limit(1), []))[0];
  if (!pol) return res.status(404).json({ error: "policy_not_found" });
  const members = await safe<any[]>(() => admin.from("org_members").select("*").eq("org_id", c.org_id), []);
  const sessions = await safe<any[]>(() => admin.from("org_sessions").select("*").eq("org_id", c.org_id), []);
  let blocked: any[] = [];
  if (pol.kind === "device") blocked = members.filter((m) => m.mfa !== true);
  else if (pol.kind === "access") blocked = sessions.filter((s) => s.country && s.country !== (pol.allowed_country ?? "PK"));
  else if (pol.kind === "sending") blocked = members.filter((m) => (m.role ?? "member") === "viewer");
  else blocked = [];
  res.json({
    policy_id,
    members_blocked: blocked.length,
    workflows_broken: pol.kind === "sending" ? blocked.length : 0,
    examples: blocked.slice(0, 5).map((b) => b.email ?? b.user_id ?? "unknown"),
  });
}));

org.post("/org/policies/toggle", guard(async (req, res, c) => {
  if (!(await writesEnabled())) return res.status(423).json({ error: "org_writes_disabled" });
  const policy_id = String(req.body?.policy_id || "");
  const enabled = req.body?.enabled === true;
  if (!policy_id) return res.status(400).json({ error: "policy_id_required" });
  try { await admin.from("org_policies").update({ enabled, updated_at: new Date().toISOString() }).eq("id", policy_id); }
  catch { return res.status(500).json({ error: "toggle_failed" }); }
  await ledger(c.user.email || c.user.id, enabled ? "policy.enable" : "policy.disable", policy_id, ipOf(req));
  res.json({ ok: true });
}));

/* ----------------------------------------------------- sessions/anomalies */
org.get("/org/sessions", guard(async (_req, res, c) => {
  const rows = await safe<any[]>(() => admin.from("org_sessions").select("*").eq("org_id", c.org_id).order("last_seen_at", { ascending: false }), []);
  res.json({
    sessions: rows.map((s) => ({
      id: s.id, email: s.email ?? "", ip: s.ip ?? null, city: s.city ?? null, country: s.country ?? null,
      device: s.device ?? null, browser: s.browser ?? null, current: s.user_id === c.user.id,
      last_seen_at: s.last_seen_at ?? s.created_at,
    })),
  });
}));

org.post("/org/sessions/kill", guard(async (req, res, c) => {
  if (!(await writesEnabled())) return res.status(423).json({ error: "org_writes_disabled" });
  const session_id = String(req.body?.session_id || "");
  if (!session_id) return res.status(400).json({ error: "session_id_required" });
  try { await admin.from("org_sessions").delete().eq("id", session_id); } catch {}
  await ledger(c.user.email || c.user.id, "session.kill", session_id, ipOf(req));
  res.json({ ok: true });
}));

org.get("/org/anomalies", guard(async (_req, res, c) => {
  const rows = await safe<any[]>(() => admin.from("org_anomalies").select("*").eq("org_id", c.org_id).order("created_at", { ascending: false }).limit(100), []);
  res.json({
    alerts: rows.map((a) => ({
      id: a.id, kind: a.kind, email: a.email ?? "", detail: a.detail ?? "",
      severity: a.severity ?? "medium", state: a.state ?? "open", created_at: a.created_at,
    })),
  });
}));

/* ------------------------------------------------------------------ proof */
org.get("/org/proof", guard(async (_req, res, c) => {
  const rows = await safe<any[]>(() => admin.from("org_dns_proof").select("*").eq("org_id", c.org_id), []);
  const o = (await safe<any[]>(() => admin.from("organizations").select("primary_domain,domain").eq("id", c.org_id).limit(1), []))[0] as any;
  res.json({
    tiles: rows.map((r) => ({ key: r.key, state: r.state ?? "warn", detail: r.detail ?? "", checked_at: r.checked_at ?? null })),
    domain: o?.primary_domain ?? o?.domain ?? null,
    pdf_url: null,
  });
}));

/* ----------------------------------------------------------------- ledger */
org.get("/org/audit", guard(async (_req, res, c) => {
  const rows = await safe<any[]>(() => admin.from("org_audit_ledger").select("*").eq("org_id", c.org_id).order("seq", { ascending: false }).limit(200), []);
  const all = rows.length ? rows : await safe<any[]>(() => admin.from("org_audit_ledger").select("*").order("seq", { ascending: false }).limit(200), []);
  res.json({
    entries: all.map((e) => ({
      id: e.id, seq: e.seq, actor: e.actor ?? "", action: e.action ?? "", target: e.target ?? null,
      ip: e.ip ?? null, hash: e.hash ?? "", prev_hash: e.prev_hash ?? null, created_at: e.created_at,
    })),
  });
}));

org.post("/org/audit/verify", guard(async (_req, res) => {
  try {
    const { data, error } = await admin.rpc("org_ledger_verify");
    if (error) throw error;
    const v: any = Array.isArray(data) ? data[0] : data;
    return res.json({
      ok: v?.ok === true, checked: v?.checked ?? 0,
      broken_at_seq: v?.broken_at_seq ?? null, verified_at: new Date().toISOString(),
    });
  } catch {
    return res.status(500).json({ error: "verify_failed" });
  }
}));

/* ------------------------------------------------------------------ graph */
org.get("/org/graph", guard(async (req, res, c) => {
  const days = Math.max(1, Math.min(180, Number(req.query.days) || 30));
  const members = await safe<any[]>(() => admin.from("org_members").select("*").eq("org_id", c.org_id), []);
  const since = new Date(Date.now() - days * 86400000).toISOString();
  const edges = await safe<any[]>(() => admin.from("org_graph_edges").select("*").eq("org_id", c.org_id).gte("created_at", since), []);
  const weight: Record<string, number> = {};
  for (const e of edges) {
    weight[e.from_user_id] = (weight[e.from_user_id] ?? 0) + (e.weight ?? 1);
    weight[e.to_user_id] = (weight[e.to_user_id] ?? 0) + (e.weight ?? 1);
  }
  const max = Math.max(1, ...Object.values(weight));
  res.json({
    nodes: members.map((m) => {
      const centrality = weight[m.user_id] ? Math.round((weight[m.user_id] / max) * 100) : null;
      return { id: m.user_id, email: m.email ?? "", label: m.display_name ?? m.email ?? "", role: m.role ?? "member",
        department: m.department ?? null, centrality, bottleneck: (centrality ?? 0) >= 80 };
    }),
    edges: edges.map((e) => ({ from: e.from_user_id, to: e.to_user_id, weight: e.weight ?? 1 })),
    window_days: days,
  });
}));

/* ------------------------------------------------------------- compliance */
org.get("/org/compliance", guard(async (_req, res, c) => {
  const row = (await safe<any[]>(() => admin.from("org_compliance").select("*").eq("org_id", c.org_id).limit(1), []))[0] as any;
  res.json({
    retention_days: row?.retention_days ?? null,
    export_enabled: row?.export_enabled ?? true,
    delete_is_real: row?.delete_is_real ?? true,
    data_region: row?.data_region ?? "EU (Helsinki)",
    dpa_url: row?.dpa_url ?? null,
    subprocessors: Array.isArray(row?.subprocessors) ? row.subprocessors : [],
    evidence_pack_ready: row?.evidence_pack_ready ?? false,
  });
}));

/* ------------------------------------------------------------ break glass */
org.get("/org/break-glass", guard(async (_req, res, c) => {
  const rows = await safe<any[]>(() => admin.from("org_break_glass").select("*").eq("org_id", c.org_id).order("granted_at", { ascending: false }).limit(50), []);
  const now = Date.now();
  res.json({
    grants: rows.map((g) => ({
      id: g.id, actor: g.actor ?? "", reason: g.reason ?? "", granted_at: g.granted_at,
      expires_at: g.expires_at,
      state: g.state === "revoked" ? "revoked" : new Date(g.expires_at).getTime() < now ? "expired" : "active",
    })),
  });
}));

org.post("/org/break-glass", guard(async (req, res, c) => {
  const reason = String(req.body?.reason || "").trim();
  const minutes = Math.max(5, Math.min(240, Number(req.body?.minutes) || 30));
  if (reason.length < 8) return res.status(400).json({ error: "reason_too_short" });
  const granted_at = new Date().toISOString();
  const expires_at = new Date(Date.now() + minutes * 60000).toISOString();
  const ins = await admin.from("org_break_glass")
    .insert({ org_id: c.org_id, actor: c.user.email || c.user.id, reason, granted_at, expires_at, state: "active" })
    .select("*").limit(1);
  if (ins.error) return res.status(500).json({ error: "grant_failed" });
  await ledger(c.user.email || c.user.id, "break_glass.grant", reason, ipOf(req));
  const g: any = ins.data?.[0];
  res.json({ id: g.id, actor: g.actor, reason: g.reason, granted_at, expires_at, state: "active" });
}));

/* ------------------------------------------------------- founder god view */
org.get("/founder/org/state", guard(async (_req, res) => {
  const orgs = await safe<any[]>(() => admin.from("organizations").select("*"), []);
  const members = await safe<any[]>(() => admin.from("org_members").select("user_id,status"), []);
  const bg = await safe<any[]>(() => admin.from("org_break_glass").select("expires_at,state"), []);
  let ledger_ok: boolean | null = null;
  try {
    const { data } = await admin.rpc("org_ledger_verify");
    const v: any = Array.isArray(data) ? data[0] : data;
    ledger_ok = v?.ok ?? null;
  } catch {}
  const seats = orgs.reduce((s, o: any) => s + (o.seats_paid ?? o.seats ?? 0), 0);
  const price: Record<string, number> = { basic: 20, pro: 40, business: 85 };
  const mrr = orgs.reduce((s, o: any) => s + (price[String(o.plan || "").toLowerCase()] ?? 0) * (o.seats_paid ?? o.seats ?? 0), 0);
  const now = Date.now();
  res.json({
    org_writes_enabled: await writesEnabled(),
    organisations: orgs.length,
    users: new Set(members.map((m) => m.user_id)).size,
    seats_paid: seats,
    mrr,
    currency: "GBP",
    break_glass_active: bg.filter((g) => g.state === "active" && new Date(g.expires_at).getTime() > now).length,
    ledger_ok,
    last_write_at: null,
  });
}));

org.get("/founder/org/list", guard(async (_req, res) => {
  const orgs = await safe<any[]>(() => admin.from("organizations").select("*").order("created_at", { ascending: false }), []);
  const members = await safe<any[]>(() => admin.from("org_members").select("org_id,status"), []);
  res.json({
    organisations: orgs.map((o: any) => ({
      id: o.id, name: o.name ?? "", primary_domain: o.primary_domain ?? o.domain ?? null, plan: o.plan ?? null,
      seats_used: members.filter((m) => m.org_id === o.id && (m.status ?? "active") === "active").length,
      seats_paid: o.seats_paid ?? o.seats ?? 0,
      writes_enabled: o.writes_enabled !== false,
      security_score: o.security_score ?? null,
      created_at: o.created_at,
    })),
  });
}));

org.post("/founder/org/kill-switch", guard(async (req, res, c) => {
  const { org_writes_enabled, organisation_id, writes_enabled } = req.body || {};
  if (typeof org_writes_enabled === "boolean") {
    const up = await admin.from("org_switches")
      .upsert({ key: "org_writes_enabled", value: org_writes_enabled, updated_at: new Date().toISOString() }, { onConflict: "key" });
    if (up.error) return res.status(500).json({ error: "switch_failed" });
    await ledger(c.user.email || c.user.id, org_writes_enabled ? "global.writes.enable" : "global.writes.disable", null, ipOf(req));
  }
  if (organisation_id && typeof writes_enabled === "boolean") {
    try { await admin.from("organizations").update({ writes_enabled }).eq("id", organisation_id); } catch {}
    await ledger(c.user.email || c.user.id, writes_enabled ? "org.writes.enable" : "org.writes.disable", organisation_id, ipOf(req));
  }
  res.json({ ok: true });
}));

org.post("/founder/org/impersonate", guard(async (req, res, c) => {
  const user_id = String(req.body?.user_id || "");
  const reason = String(req.body?.reason || "").trim();
  if (!user_id || reason.length < 8) return res.status(400).json({ error: "user_id_and_reason_required" });
  // audit FIRST, session after — ownership proof rule
  const ins = await admin.from("org_audit_ledger").select("id").limit(1);
  await ledger(c.user.email || c.user.id, "founder.impersonate", `${user_id} :: ${reason}`, ipOf(req));
  const last = await safe<any[]>(() => admin.from("org_audit_ledger").select("id").order("seq", { ascending: false }).limit(1), []);
  res.json({ ok: true, audit_id: (last[0] as any)?.id ?? (ins.data?.[0] as any)?.id ?? "unrecorded" });
}));

/* ------------------------------------------------------------ one-click export
 * Business card: "One-click data export" + "Export & no lock-in guarantee".
 * Owner only (CAPS: org.export = owner). Real rows from Supabase — jo table
 * nahi hai woh safe() se empty array, koi fake data nahi.
 */
org.get("/org/export", guard(async (_req, res, c) => {
  if (!c.org_id) return res.status(404).json({ error: "no_org" });
  const mem = await safe<any[]>(
    () => admin.from("org_members").select("role").eq("org_id", c.org_id).eq("user_id", c.user.id).limit(1),
    [],
  );
  if ((mem[0]?.role ?? "member") !== "owner") {
    return res.status(403).json({ error: "owner_only" });
  }

  const [members, threads, events, tasks, leads, deals] = await Promise.all([
    safe<any[]>(() => admin.from("org_members").select("*").eq("org_id", c.org_id), []),
    safe<any[]>(() => admin.from("mail_threads").select("*").eq("org_id", c.org_id).limit(5000), []),
    safe<any[]>(() => admin.from("calendar_events").select("*").eq("org_id", c.org_id).limit(5000), []),
    safe<any[]>(() => admin.from("work_tasks").select("*").eq("org_id", c.org_id).limit(5000), []),
    safe<any[]>(() => admin.from("crm_leads").select("*").eq("org_id", c.org_id).limit(5000), []),
    safe<any[]>(() => admin.from("crm_deals").select("*").eq("org_id", c.org_id).limit(5000), []),
  ]);

  await ledger(c.user.email || c.user.id, "org.export", c.org_id, ipOf(_req));

  const stamp = new Date().toISOString().slice(0, 10);
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.setHeader("content-disposition", `attachment; filename="anexomail-export-${stamp}.json"`);
  res.json({
    exported_at: new Date().toISOString(),
    org_id: c.org_id,
    exported_by: c.user.email || c.user.id,
    members,
    mail_threads: threads,
    calendar_events: events,
    work_tasks: tasks,
    crm_leads: leads,
    crm_deals: deals,
  });
}));

export default org;
