// ANEXOMAIL — Phase 9 Compose Studio API
// Owns: drafts + versions, templates, snippets, signatures, send-confidence,
// schedule / undo-send hold, follow-up promise, thread insights.
// Hierarchy: User -> LEO (primary) -> Jimmy (escalation only) -> Sherlock validation.
import { Router } from "express";
import { resolvePlan } from "../lib/plan";
import { admin as supa } from "../lib/supa";
import { allowedSenderAddresses } from "../lib/identity";

import { loadStaged } from "../mail/attachments"; // G38
type Ctx = { userId: string; orgId: string; userEmail: string };

async function ctx(req: any, res: any): Promise<Ctx | null> {
  const bearer = (req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  const token = bearer || req.cookies?.ax_session || "";
  if (!token) { res.status(401).json({ error: "unauthenticated" }); return null; }
  const { data, error } = await supa.auth.getUser(token);
  if (error || !data?.user) { res.status(401).json({ error: "unauthenticated" }); return null; }
  const userId = data.user.id;
  const requested = (req.header("x-org-id") || req.query.org_id || "") as string;
  const { data: rows } = await supa.from("org_members").select("org_id").eq("user_id", userId);
  const ids = (rows || []).map((r: any) => r.org_id);
  if (!ids.length) { res.status(409).json({ error: "no_workspace" }); return null; }
  const orgId = requested && ids.includes(requested) ? requested : ids[0];
  return { userId, orgId, userEmail: String(data.user.email || "").toLowerCase() };
}

/** Pro+ gate (Basic card does not list it) — same rule as the Rust procs (resolve_plan). */
async function proOnly(c: Ctx, res: any, what: string): Promise<boolean> {
  const plan = await resolvePlan(c.userId, c.userEmail);
  if (plan !== "basic") return true;
  res.status(403).json({ error: "feature_not_available", plan, message: `${what} is a Pro+ feature.` });
  return false;
}

export const mailComposeRouter = Router();

/* ------------------------------------------------------------------ drafts */

mailComposeRouter.post("/drafts", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const b = req.body || {};
  const draftId = b.id || crypto.randomUUID();

  const { data: last } = await supa
    .from("mail_drafts_versions")
    .select("version")
    .eq("draft_id", draftId)
    .order("version", { ascending: false })
    .limit(1);
  const version = ((last?.[0]?.version as number) || 0) + 1;

  const { error } = await supa.from("mail_drafts_versions").insert({
    org_id: c.orgId,
    draft_id: draftId,
    user_id: c.userId,
    thread_id: b.thread_id || null,
    version,
    identity: b.identity || null,
    // live columns are to / cc / bcc (to_addresses made every autosave fail with a 500)
    to: b.to || "",
    cc: b.cc || null,
    bcc: b.bcc || null,
    subject: b.subject || null,
    body: b.body || null,
    send_at: b.send_at || null,
    language: b.language || null,
  });
  if (error) return res.status(500).json({ error: error.message });

  res.json({ id: draftId, version, saved_at: new Date().toISOString() });
});

mailComposeRouter.get("/drafts/:id", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data, error } = await supa
    .from("mail_drafts_versions")
    .select("id, version, saved_at, subject, body")
    .eq("org_id", c.orgId)
    .eq("user_id", c.userId) // only your own draft history
    .eq("draft_id", req.params.id)
    .order("version", { ascending: false })
    .limit(40);
  if (error) return res.status(500).json({ error: error.message });
  res.json({
    versions: (data || []).map((v: any) => ({
      id: v.id, version: v.version, saved_at: v.saved_at, subject: v.subject, body: v.body,
    })),
  });
});

/* ------------------------------------------- templates / snippets / sigs */

mailComposeRouter.get("/templates", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data, error } = await supa
    .from("mail_templates")
    .select("id, name, scope, subject, body, variables")
    .eq("org_id", c.orgId)
    .or(`scope.eq.org,user_id.eq.${c.userId}`)
    .order("name");
  if (error) return res.status(500).json({ error: error.message });
  res.json({ templates: (data || []).map((t: any) => ({ ...t, variables: t.variables || [] })) });
});

mailComposeRouter.post("/templates", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  if (!(await proOnly(c, res, "Email templates"))) return;
  const b = req.body || {};
  const name = String(b.name ?? "").trim();
  const body = String(b.body ?? "");
  const subject = b.subject == null ? null : String(b.subject).slice(0, 200);
  if (!name || name.length > 80) return res.status(400).json({ error: "bad_name" });
  if (!body.trim() || body.length > 20000) return res.status(400).json({ error: "bad_body" });
  // 50 templates per person: a buyer cannot fill the table
  const have = await supa.from("mail_templates").select("id", { count: "exact", head: true }).eq("org_id", c.orgId).eq("user_id", c.userId);
  if ((have.count ?? 0) >= 50) return res.status(409).json({ error: "too_many" });
  const vars = Array.from(new Set([...body.matchAll(/{{\s*([\w.]+)\s*}}/g)].map((m) => m[1]!))).slice(0, 30);
  const { data, error } = await supa.from("mail_templates").insert({
    org_id: c.orgId,
    user_id: c.userId,
    name,
    scope: "personal",
    subject,
    body,
    variables: vars,
  }).select("id").single();
  if (error) return res.status(500).json({ error: error.message });
  res.json({ id: data!.id });
});

// Only your own template can be removed (personal scope, your user id, your workspace).
mailComposeRouter.delete("/templates/:id", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data, error } = await supa.from("mail_templates").delete()
    .eq("id", req.params.id).eq("org_id", c.orgId).eq("user_id", c.userId).select("id");
  if (error) return res.status(500).json({ error: error.message });
  res.json({ removed: (data || []).length });
});

mailComposeRouter.get("/snippets", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data, error } = await supa
    .from("mail_snippets")
    .select("id, shortcut, body")
    .eq("org_id", c.orgId)
    .eq("user_id", c.userId)
    .order("shortcut");
  if (error) return res.status(500).json({ error: error.message });
  res.json({ snippets: data || [] });
});

mailComposeRouter.post("/snippets", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const b = req.body || {};
  const { data, error } = await supa.from("mail_snippets").insert({
    org_id: c.orgId, user_id: c.userId, shortcut: b.shortcut || "", body: b.body || "",
  }).select("id").single();
  if (error) return res.status(500).json({ error: error.message });
  res.json({ id: data!.id });
});

mailComposeRouter.get("/signatures", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data, error } = await supa
    .from("mail_signatures")
    .select("id, identity, name, body, is_default")
    .eq("org_id", c.orgId)
    .eq("user_id", c.userId)
    .order("is_default", { ascending: false });
  if (error) return res.status(500).json({ error: error.message });
  res.json({ signatures: data || [] });
});

/* -------------------------------------------------------- send confidence */

const RISKY = ["asap", "urgent", "obviously", "as i said", "clearly you", "unacceptable"];

mailComposeRouter.post("/send-confidence", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const b = req.body || {};
  const body = String(b.body || "");
  const subject = String(b.subject || "");
  const to = String(b.to || "");
  const issues: { kind: string; severity: string; message: string }[] = [];

  if (!subject.trim()) issues.push({ kind: "empty_subject", severity: "block", message: "Subject khaali hai." });
  if (!to.trim()) issues.push({ kind: "wrong_identity", severity: "block", message: "Recipient missing." });

  const unresolved = [...body.matchAll(/{{\s*([\w.]+)\s*}}/g)].map((m) => m[1]);
  for (const v of new Set(unresolved)) {
    issues.push({ kind: "missing_variable", severity: "block", message: `Variable {{${v}}} resolve nahi hui.` });
  }

  if (/attach(ed|ment|ing)?\b/i.test(body) && !Number(b.attachments || 0)) {
    issues.push({ kind: "attachment_promised", severity: "warn", message: "Attachment ka zikr hai magar file nahi lagi." });
  }

  const internal = new Set(["anexomail.com", "nexatect.com"]);
  const domains = to.split(/[,;]/).map((a) => a.split("@")[1]?.trim().toLowerCase()).filter(Boolean) as string[];
  const external = domains.filter((d) => !internal.has(d));
  if (external.length) {
    issues.push({ kind: "external_domain", severity: "note", message: `External recipient: ${external.join(", ")}` });
  }

  const risky = RISKY.filter((w) => body.toLowerCase().includes(w));
  if (risky.length) issues.push({ kind: "risky_tone", severity: "warn", message: `Tone check: "${risky.join('", "')}"` });

  for (const m of body.matchAll(/https?:\/\/\S+/g)) {
    if (/https?:\/\/(\s|$)|\.\.|https?:\/\/[^.\s]+$/.test(m[0])) {
      issues.push({ kind: "broken_link", severity: "warn", message: `Link toota lagta hai: ${m[0]}` });
    }
  }

  const penalty = issues.reduce((n, i) => n + (i.severity === "block" ? 30 : i.severity === "warn" ? 12 : 3), 0);
  res.json({ score: Math.max(0, 100 - penalty), issues });
});

/* --------------------------------------------- schedule / undo-send hold */

mailComposeRouter.post("/schedule", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const b = req.body || {};
  const hold = Math.min(Math.max(Number(b.hold_seconds ?? 10), 0), 120);
  const sendAt = b.send_at ? new Date(b.send_at) : new Date(Date.now() + hold * 1000);
  if (Number.isNaN(sendAt.getTime())) return res.status(400).json({ error: "send_at_invalid" });
  // Undo-send hold (<= 2 min) is Basic; a real later send time is Pro+ "Schedule send".
  if (sendAt.getTime() > Date.now() + 130_000 && !(await proOnly(c, res, "Schedule send"))) return;

  // #3 SECURITY: From sirf is user ke jaiz addresses mein se (client ka identity seedha maan lena spoofing tha).
  const wantedFrom = String(b.identity || "").trim().toLowerCase();
  if (wantedFrom && !(await allowedSenderAddresses(c.orgId, c.userId)).has(wantedFrom)) {
    return res.status(403).json({ error: "identity_not_allowed", identity: wantedFrom });
  }

  // G38 — attachments: ids parakh kar hi queue mein (limit/ownership/blocked sab SQL E48 dekhta hai)
  const att = await loadStaged(supa, c.orgId, c.userId, b.attachment_ids);
  if (!att.ok) return res.status(att.status).json({ error: att.error, ...(att.detail || {}) });

  const { data, error } = await supa.from("mail_scheduled").insert({
    org_id: c.orgId,
    user_id: c.userId,
    thread_id: b.thread_id || null,
    identity: wantedFrom || null,
    to: b.to || "",
    cc: b.cc || null,
    bcc: b.bcc || null,
    subject: b.subject || null,
    body: b.body || null,
    status: "holding",
    attachment_ids: att.files.length ? att.files.map((x) => x.id) : null, // G38
    send_at: sendAt.toISOString(),
  }).select("id, status").single();
  if (error) return res.status(500).json({ error: error.message });

  res.json({ id: data!.id, status: data!.status });
});

mailComposeRouter.post("/schedule/:id/cancel", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  // B3 (E54): jo row kisi worker ne utha li woh cancel nahi hoti (mail nikal rahi hai). E54 na ho to neeche purana tareeqa.
  const rc: any = await supa.rpc("mail_queue_cancel", { _id: req.params.id, _user: c.userId, _org: c.orgId });
  if (!rc.error) return rc.data === true ? res.json({ ok: true }) : res.status(409).json({ error: "already_sent" });
  const { data, error } = await supa
    .from("mail_scheduled")
    .update({ status: "cancelled" })
    .eq("id", req.params.id)
    .eq("org_id", c.orgId)
    .eq("user_id", c.userId)
    .in("status", ["holding", "queued"])
    .select("id")
    .maybeSingle();
  if (error) return res.status(500).json({ error: error.message });
  if (!data) return res.status(409).json({ error: "already_sent" });
  res.json({ ok: true });
});

/* ------------------------------------------------------- follow-up promise */

mailComposeRouter.post("/follow-up", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const b = req.body || {};
  if (!b.remind_at) return res.status(400).json({ error: "remind_at_required" });
  const remindAt = new Date(b.remind_at);
  if (Number.isNaN(remindAt.getTime())) return res.status(400).json({ error: "bad_remind_at" });
  const { data, error } = await supa.from("mail_followups").insert({
    org_id: c.orgId,
    user_id: c.userId,
    thread_id: b.thread_id || null,
    subject: b.subject || null,
    remind_at: remindAt.toISOString(),
    status: "pending",
  }).select("id, thread_id, subject, remind_at, status").single();
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

mailComposeRouter.get("/follow-up", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data, error } = await supa
    .from("mail_followups")
    .select("id, thread_id, subject, remind_at, status")
    .eq("org_id", c.orgId)
    .eq("user_id", c.userId)
    .order("remind_at");
  if (error) return res.status(500).json({ error: error.message });
  res.json({ follow_ups: data || [] });
});

/* ------------------------------------------ feature 23 — thread insights */

mailComposeRouter.get("/thread/:id/insights", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;

  const { data: msgs, error } = await supa
    .from("mail_messages")
    .select("direction, sent_at")
    .eq("org_id", c.orgId)
    .eq("thread_id", req.params.id)
    .order("sent_at");
  if (error) return res.status(500).json({ error: error.message });

  const rows = msgs || [];
  const inbound = rows.filter((m: any) => m.direction === "in").length;
  const outbound = rows.filter((m: any) => m.direction === "out").length;

  // reply latency: har outbound se pehle wale inbound ka gap
  const gaps: number[] = [];
  for (let i = 1; i < rows.length; i++) {
    const prev: any = rows[i - 1];
    const cur: any = rows[i];
    if (prev.direction === "in" && cur.direction === "out") {
      gaps.push((new Date(cur.sent_at).getTime() - new Date(prev.sent_at).getTime()) / 60000);
    }
  }
  const avg = gaps.length ? Math.round(gaps.reduce((a, b) => a + b, 0) / gaps.length) : null;

  // best send hour: jin hours mein inbound reply aayi
  const hours = rows.filter((m: any) => m.direction === "in").map((m: any) => new Date(m.sent_at).getUTCHours());
  const tally = new Map<number, number>();
  for (const h of hours) tally.set(h, (tally.get(h) || 0) + 1);
  const best = [...tally.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;

  const { data: track } = await supa
    .from("mail_thread_insights")
    .select("opened, open_count, last_opened_at, recipient_timezone")
    .eq("org_id", c.orgId)
    .eq("thread_id", req.params.id)
    .maybeSingle();

  res.json({
    opened: track?.opened ?? null,
    open_count: track?.open_count ?? 0,
    last_opened_at: track?.last_opened_at ?? null,
    response_rate: outbound ? Math.min(1, inbound / outbound) : null,
    avg_response_minutes: avg,
    best_send_hour: best,
    recipient_timezone: track?.recipient_timezone ?? null,
  });
});

/* ----------------------------- hold release worker (undo-send -> queued) */

setInterval(async () => {
  try {
    const now = new Date().toISOString();
    await supa
      .from("mail_scheduled")
      .update({ status: "queued" })
      .eq("status", "holding")
      .lte("send_at", now);
  } catch (e) {
    console.error("[compose] hold release failed", e);
  }
}, 5000);
