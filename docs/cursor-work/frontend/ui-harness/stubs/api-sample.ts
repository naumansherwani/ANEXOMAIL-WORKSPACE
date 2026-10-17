// Harness data for the /app list+detail pages (Calendar, People, Work). Stands in for BOTH @/lib/api and @/lib/rpc so the REAL hooks in
// src/lib/{calendar,contacts}.ts run unchanged. Scenario via hash, e.g. #cal?empty=1 . Dates are relative to "now" so the week is never stale.
export class ApiError extends Error {
  constructor(message: string, readonly status: number, readonly code?: string) { super(message); this.name = "ApiError"; }
  get isNotImplemented() { return this.status === 404 || this.status === 501; }
}
export const sessionToken = { get: () => null as string | null, set: (_t: string) => {}, clear: () => {} };

const empty = () => /[?&]empty=1/.test(location.hash);
const at = (dayOffset: number, h: number, m = 0, mins = 60) => {
  const s = new Date(); s.setDate(s.getDate() + dayOffset); s.setHours(h, m, 0, 0);
  const e = new Date(s.getTime() + mins * 60000);
  return [s.toISOString(), e.toISOString()] as const;
};
const att = (a: string, n: string) => ({ address: a, display_name: n, timezone: "Europe/London", local_start: null, unsociable: false });
const ev = (id: string, title: string, d: number, h: number, m: number, mins: number, over: Record<string, unknown> = {}) => {
  const [s, e] = at(d, h, m, mins);
  return { id, title, starts_at: s, ends_at: e, all_day: false, location: null, agenda: null, organiser: "me@anexomail.com", attendees: [att("ali@axonetis.com", "Ali Khan")], thread_id: null, thread_subject: null, kind: "meeting", status: "confirmed", cost: null, conflict: false, shield_conflict: false, ...over };
};
const EVENTS = () => [
  ev("e1", "Daily standup", 0, 9, 30, 15, { attendees: [att("a@x.com", "A"), att("b@x.com", "B"), att("c@x.com", "C"), att("d@x.com", "D")] }),
  ev("e2", "Customer call — Axonetis renewal", 0, 14, 0, 45, { location: "Google Meet", conflict: true, cost: { currency: "GBP", total: 312, attendees: 5, minutes: 45, hourly_total: 312 } }),
  ev("e3", "Deep work: pricing page", 1, 10, 0, 120, { kind: "focus", attendees: [] }),
  ev("e4", "Board prep", 2, 16, 0, 60, { location: "Office, Room 2", cost: { currency: "GBP", total: 1180, attendees: 6, minutes: 60, hourly_total: 1180 } }),
  ev("e5", "Hold: investor intro", 3, 11, 0, 30, { kind: "hold", attendees: [] }),
  ev("e6", "Team lunch", 4, 13, 0, 60, { kind: "personal", location: "Dishoom" }),
  ev("e7", "Sprint review", -2, 15, 0, 60),
  ev("e8", "Quarterly planning with the whole leadership group", 8, 10, 0, 90, { agenda: "Roadmap, hiring, budget." }),
  ev("e9", "Dentist", 12, 9, 0, 45, { kind: "personal", attendees: [] }),
  ev("e10", "Demo for Zephyr Labs", 15, 17, 0, 30),
];
const CONTACTS = [
  { id: "c1", display_name: "Ayesha Rahman", primary_address: "ayesha@zephyrlabs.io", addresses: ["ayesha@zephyrlabs.io"], title: "Head of Ops", company_domain: "zephyrlabs.io", company_name: "Zephyr Labs", tags: ["customer", "vip"], vip: true, relationship: "growing", health_score: 82, last_contact_at: new Date(Date.now() - 3600e3 * 5).toISOString(), messages_in: 41, messages_out: 38, avg_reply_minutes: 47, open_threads: 2, notes: "Prefers short emails. Renewal in March." },
  { id: "c2", display_name: "Tom Becker", primary_address: "tom@northwind.co.uk", addresses: ["tom@northwind.co.uk", "t.becker@gmail.com"], title: "CFO", company_domain: "northwind.co.uk", company_name: "Northwind", tags: ["customer"], vip: false, relationship: "at_risk", health_score: 34, last_contact_at: new Date(Date.now() - 86400e3 * 22).toISOString(), messages_in: 12, messages_out: 19, avg_reply_minutes: 1380, open_threads: 1, notes: null },
  { id: "c3", display_name: null, primary_address: "billing@hosting-supplier.com", addresses: ["billing@hosting-supplier.com"], title: null, company_domain: "hosting-supplier.com", company_name: null, tags: ["vendor"], vip: false, relationship: "stable", health_score: 61, last_contact_at: new Date(Date.now() - 86400e3 * 3).toISOString(), messages_in: 9, messages_out: 2, avg_reply_minutes: null, open_threads: 0, notes: null },
  { id: "c4", display_name: "Maria Gonzalez-Fernandez-Williams", primary_address: "maria.gonzalez-fernandez-williams@investorgroup-international.example", addresses: ["maria.gonzalez-fernandez-williams@investorgroup-international.example"], title: "Partner", company_domain: "investorgroup-international.example", company_name: "Investor Group International", tags: ["investor"], vip: true, relationship: "new", health_score: null, last_contact_at: new Date(Date.now() - 86400e3).toISOString(), messages_in: 2, messages_out: 3, avg_reply_minutes: 190, open_threads: 1, notes: null },
];
const COMPANIES = [
  { domain: "zephyrlabs.io", name: "Zephyr Labs", people_count: 4, messages_total: 120, open_threads: 2, relationship: "growing", health_score: 80, last_contact_at: CONTACTS[0].last_contact_at },
  { domain: "northwind.co.uk", name: "Northwind", people_count: 2, messages_total: 31, open_threads: 1, relationship: "at_risk", health_score: 34, last_contact_at: CONTACTS[1].last_contact_at },
];
const TIMELINE = [
  { id: "t1", kind: "message_in", at: new Date(Date.now() - 3600e3 * 5).toISOString(), title: "Re: Renewal terms for 2027", detail: "Thanks — can we move the call to Thursday?", thread_id: "th1", actor: "Ayesha" },
  { id: "t2", kind: "meeting", at: new Date(Date.now() - 86400e3 * 4).toISOString(), title: "Customer call — Axonetis renewal", detail: null, thread_id: null, actor: null },
  { id: "t3", kind: "message_out", at: new Date(Date.now() - 86400e3 * 6).toISOString(), title: "Proposal v3", detail: "Attached the updated numbers.", thread_id: "th2", actor: "You" },
];
const TASKS = [
  { id: "k1", title: "Send revised proposal to Zephyr", status: "todo", owner: "me@anexomail.com", due_at: new Date(Date.now() + 86400e3).toISOString(), thread_id: "th1", thread_subject: "Renewal terms for 2027", event_id: null, source: "promise", created_at: new Date().toISOString(), completed_at: null, late: false },
  { id: "k2", title: "Fix SPF for northwind.co.uk", status: "doing", owner: "me@anexomail.com", due_at: null, thread_id: null, thread_subject: null, event_id: null, source: "manual", created_at: new Date().toISOString(), completed_at: null, late: false },
  { id: "k3", title: "Wait for Tom's sign-off", status: "waiting", owner: null, due_at: new Date(Date.now() - 86400e3 * 2).toISOString(), thread_id: null, thread_subject: null, event_id: null, source: "manual", created_at: new Date().toISOString(), completed_at: null, late: true },
  { id: "k4", title: "Book dentist", status: "done", owner: "me@anexomail.com", due_at: null, thread_id: null, thread_subject: null, event_id: "e9", source: "meeting_outcome", created_at: new Date().toISOString(), completed_at: new Date().toISOString(), late: false },
];
const PROMISES = [
  { id: "p1", quote: "I'll send you the revised numbers by Friday.", suggested_title: "Send revised numbers", suggested_due_at: new Date(Date.now() + 86400e3 * 2).toISOString(), thread_id: "th1", thread_subject: "Renewal terms for 2027", detected_at: new Date().toISOString(), confidence: 0.92 },
  { id: "p2", quote: "We will get back to you next week with the contract.", suggested_title: "Return the contract", suggested_due_at: null, thread_id: "th3", thread_subject: "Contract draft", detected_at: new Date().toISOString(), confidence: 0.81 },
];
const FOLLOW = [
  { scope: "team", subject: "me@anexomail.com", display_name: "Nauman", promises_made: 14, kept_on_time: 11, kept_late: 2, broken: 1, score: 86 },
  { scope: "team", subject: "ali@axonetis.com", display_name: "Ali Khan", promises_made: 9, kept_on_time: 5, kept_late: 2, broken: 2, score: 61 },
];


// ---- CRM (M6 part 2). Mutable so "Move to…" really moves a deal in the harness.
const ago = (d: number, h = 0) => new Date(Date.now() - d * 86400e3 - h * 3600e3).toISOString();
const PROB: Record<string, number> = { new: 10, qualified: 25, proposal: 50, negotiation: 75, won: 100, lost: 0 };
type D = Record<string, unknown> & { id: string; stage: string };
const DEALS: D[] = [
  { id: "d1", title: "Zephyr Labs — annual renewal", company: "Zephyr Labs", contact_email: "ayesha@zephyrlabs.io", stage: "negotiation", value: 24000, currency: "GBP", probability: 75, owner: "me@anexomail.com", next_step: "Send revised proposal", next_step_due: "Fri", thread_id: "th1", stale_days: 2, updated_at: ago(2) },
  { id: "d2", title: "Northwind — 40 seats", company: "Northwind", contact_email: "tom@northwind.co.uk", stage: "proposal", value: 18400, currency: "GBP", probability: 50, owner: "me@anexomail.com", next_step: null, next_step_due: null, thread_id: null, stale_days: 12, updated_at: ago(12) },
  { id: "d3", title: "Investor Group International — pilot programme for the whole EMEA region", company: "Investor Group International", contact_email: "maria.gonzalez-fernandez-williams@investorgroup-international.example", stage: "qualified", value: 31000, currency: "GBP", probability: 25, owner: null, next_step: "Intro call", next_step_due: "Tue 14:00", thread_id: "th4", stale_days: 1, updated_at: ago(1) },
  { id: "d4", title: "Hosting supplier — switch", company: null, contact_email: "billing@hosting-supplier.com", stage: "new", value: 0, currency: "GBP", probability: 10, owner: null, next_step: null, next_step_due: null, thread_id: null, stale_days: 3, updated_at: ago(3) },
  { id: "d5", title: "Acme Studio — onboarding", company: "Acme Studio", contact_email: null, stage: "won", value: 12000, currency: "GBP", probability: 100, owner: "me@anexomail.com", next_step: null, next_step_due: null, thread_id: "th5", stale_days: null, updated_at: ago(4) },
];
const dealsNow = () => (empty() ? [] : DEALS);
const LEADS = [
  { id: "l1", display_name: "Priya Nair", email: "priya@brightpath.io", company: "BrightPath", source: "Inbound mail", score: 82, score_reason: "Replied twice, asked for pricing", owner: null, state: "new", last_touch_at: ago(0, 3), created_at: ago(1) },
  { id: "l2", display_name: null, email: "hello@longdomainname-consulting-group.example", company: null, source: "Website", score: 41, score_reason: "One message, no reply yet", owner: "me@anexomail.com", state: "working", last_touch_at: ago(5), created_at: ago(6) },
  { id: "l3", display_name: "Jonas Weber", email: "jonas@weberwerk.de", company: "Weberwerk", source: "Referral", score: 67, score_reason: "Referred by Ayesha Rahman", owner: null, state: "new", last_touch_at: null, created_at: ago(2) },
];
const CRM_LIVE = {
  radar: [{ kind: "risk", title: "Northwind has gone quiet for 12 days", why: "Last reply was 12 days ago; proposal value £18,400.", source: "crm_deals", href: "/app/crm/pipeline" }],
  next_actions: [
    { kind: "reply", title: "Reply to Ayesha (Zephyr Labs)", action: "Open thread", why: "Waiting 5 hours; renewal is your biggest open deal.", href: "/app/mail/inbox" },
    { kind: "task", title: "Send revised proposal", action: "Open task", why: "Promised by Friday.", href: "/app/work" },
  ],
  timeline: [
    { at: ago(0, 5), kind: "email_in", title: "Re: Renewal terms for 2027", source: "ayesha@zephyrlabs.io", href: "/app/mail/inbox" },
    { at: ago(1), kind: "meeting", title: "Customer call — Axonetis renewal", source: null, href: "/app/calendar" },
    { at: ago(4), kind: "stage_change", title: "Acme Studio → Won", source: "crm", href: "/app/crm/pipeline" },
  ],
  people: CONTACTS.map((c) => ({ id: c.id, display_name: c.display_name, primary_address: c.primary_address, company_name: c.company_name, relationship: c.relationship, health_score: c.health_score, last_contact_at: c.last_contact_at, open_threads: c.open_threads })),
  graph: { nodes: [{ id: "n1", kind: "person", label: "Ayesha Rahman", email: "ayesha@zephyrlabs.io" }, { id: "n2", kind: "deal", label: "Zephyr renewal" }, { id: "n3", kind: "mail", label: "Renewal terms" }], edges: [{ from: "n1", to: "n2", kind: "owns" }, { from: "n2", to: "n3", kind: "thread" }] },
  counts: { contacts: 4, open_deals: 4, overdue_tasks: 1, promises: 2 },
};
const overview = () => {
  const ds = dealsNow();
  const stages = ["new", "qualified", "proposal", "negotiation", "won", "lost"];
  const open = ds.filter((d) => d.stage !== "won" && d.stage !== "lost");
  return {
    currency: "GBP", pipeline_value: open.reduce((a, d) => a + Number(d.value), 0), weighted_value: open.reduce((a, d) => a + Number(d.value) * Number(d.probability) / 100, 0),
    won_this_month: ds.filter((d) => d.stage === "won").reduce((a, d) => a + Number(d.value), 0), open_deals: open.length, leads_new: empty() ? 0 : 2, leads_unworked: empty() ? 0 : 1, stale_deals: open.filter((d) => Number(d.stale_days) > 7).length, avg_first_reply_minutes: empty() ? null : 47,
    stage_counts: stages.map((st) => ({ stage: st, count: ds.filter((d) => d.stage === st).length, value: ds.filter((d) => d.stage === st).reduce((a, d) => a + Number(d.value), 0) })),
  };
};

function sample(key: string, input: Record<string, unknown> | undefined): unknown {
  const e = empty();
  if (key.startsWith("calendar.events") || key.startsWith("/api/calendar/events?")) {
    const from = new Date((input?.from as string) ?? 0).getTime(), to = new Date((input?.to as string) ?? 8e15).getTime();
    return { events: e ? [] : EVENTS().filter((x) => { const t = new Date(x.starts_at).getTime(); return t >= from && t < to; }) };
  }
  if (key === "calendar.event" || key.startsWith("/api/calendar/events/")) {
    const id = (input?.id as string) ?? key.split("/").pop();
    const found = EVENTS().find((x) => x.id === id) ?? EVENTS()[1];
    return { event: found, outcome: null, tasks: [] };
  }
  if (key === "org.audit") {
    if (/[?&]err=1/.test(location.hash)) throw new ApiError("Forbidden", 403, "forbidden");
    if (/[?&]empty=1/.test(location.hash)) return { entries: [] };
    const at = (m: number) => new Date(Date.now() - m * 60e3).toISOString();
    const rows = [
      ["member.revoke", "owner@acme-studio-holdings.co.uk", "9f1c0a52-3b7e-4c1d-8a20-6d1f2e9b4c11", "203.0.113.24"],
      ["mailbox.create", "owner@acme-studio-holdings.co.uk", "northern-region@acme-studio-holdings.co.uk", "203.0.113.24"],
      ["policy.enable", "admin@acme-studio-holdings.co.uk", "p-require-mfa", null],
      ["org.export", "owner@acme-studio-holdings.co.uk", "aaaaaaaa-0000-0000-0000-000000000001", "203.0.113.24"],
    ];
    return { entries: rows.map((r, i) => ({ id: "l" + i, seq: rows.length - i, actor: r[1], action: r[0], target: r[2], ip: r[3], hash: "9f3a71c2d8e04b6a" + i + "c0ffee1234567890", prev_hash: i === rows.length - 1 ? null : "b27de19c40a85f3" + i + "deadbeef12345678", created_at: at(i * 190 + 12) })) };
  }
  if (key === "org.audit.verify") return { ok: true, checked: 4, broken_at_seq: null, verified_at: new Date().toISOString() };
  if (key.startsWith("admin.") || key === "founderAdmin.overview") {
    // #admin/<page>[?empty=1|err=1]: Admin Center (health, storage, monitoring, logs, reports, diagnostics) sample data.
    if (/[?&]err=1/.test(location.hash)) throw new ApiError("Admin service unavailable", 503, "unavailable");
    const m = (h: number, mm = 0) => new Date(Date.now() - h * 3600e3 - mm * 60e3).toISOString();
    if (key === "admin.health") return e ? { score: 100, checks: [], self_heals_24h: 0, last_run: null, recent: [] } : {
      score: 87, self_heals_24h: 3, last_run: m(0, 4),
      checks: [
        { key: "mail-tls", label: "Mail TLS certificate", category: "security", status: "ok", detail: "Valid for 76 more days", can_self_heal: false, remedy: null, heals_24h: 0, last_healed_at: null, checked_at: m(0, 4) },
        { key: "dkim", label: "DKIM signing for northern-region.acme-studio-holdings.co.uk", category: "dns", status: "warn", detail: "Selector anexo1._domainkey has no TXT record yet — mail still sends but may land in spam", can_self_heal: true, remedy: "Publish the DKIM record", heals_24h: 1, last_healed_at: m(5), checked_at: m(0, 4) },
        { key: "queue", label: "Outbound queue", category: "mail", status: "fail", detail: "14 messages deferred for more than 30 minutes", can_self_heal: true, remedy: "Flush the queue", heals_24h: 2, last_healed_at: m(2), checked_at: m(0, 4) },
        { key: "disk", label: "Mail store disk", category: "storage", status: "ok", detail: "41% used", can_self_heal: false, remedy: null, heals_24h: 0, last_healed_at: null, checked_at: m(0, 4) },
      ],
      recent: [
        { key: "queue", action: "flush", outcome: "ok — 9 delivered", created_at: m(2) },
        { key: "dkim", action: "publish-record", outcome: "ok", created_at: m(5) },
        { key: "mail-tls-renew", action: "renew-certificate-dry-run", outcome: "skipped — not due", created_at: m(11) },
      ],
    };
    const GB = 1024 ** 3;
    if (key === "admin.storage") return e ? { used_bytes: 0, quota_bytes: 0, growth_bytes_per_day: 0, days_until_full: null, reclaimable_bytes: 0, mailboxes: [], reclaim: [] } : {
      used_bytes: 41.2 * GB, quota_bytes: 750 * GB, growth_bytes_per_day: 1.4 * GB, days_until_full: 506, reclaimable_bytes: 3.1 * GB,
      mailboxes: [
        { mailbox: "naumansherwani.founder@anexomail.com", used_bytes: 12.4 * GB, quota_bytes: 50 * GB, growth_bytes_per_day: 0.4 * GB, days_until_full: 94, reclaimable_bytes: 1.2 * GB },
        { mailbox: "accounts.payable.northern-region@acme-studio-holdings.co.uk", used_bytes: 28.8 * GB, quota_bytes: 30 * GB, growth_bytes_per_day: 1 * GB, days_until_full: 1, reclaimable_bytes: 1.9 * GB },
      ],
      reclaim: [{ label: "Spam older than 30 days", bytes: 1.9 * GB, safe: true }, { label: "Attachments in archived threads over 25 MB", bytes: 1.2 * GB, safe: false }],
    };
    if (key === "admin.incidents") return { incidents: e ? [] : [{
      id: "inc1", title: "Outbound mail deferred by a remote provider", severity: "major", status: "resolved", surface: "smtp", started_at: m(30), resolved_at: m(28), minutes: 96, impact: "Customers saw 14 messages delayed", cause: "Remote greylisting", fix: "Retried with backoff", prevention: "Warm the sending IP before bulk sends",
      auto_detected: true,
      events: [{ at: m(30), actor: "watchtower", kind: "detect", message: "Deferred count crossed 10 in 15 minutes" }, { at: m(29), actor: "heal", kind: "action", message: "Flushed queue, 9 delivered" }, { at: m(28), actor: "heal", kind: "recover", message: "Queue back to zero" }],
    }] };
    if (key === "admin.monitoring") return e ? { window_hours: 24, sent: 0, queued: 0, deferred: 0, bounced: 0, rejected: 0, delivery_rate: 100, reasons: [], recent: [] } : {
      window_hours: 24, sent: 412, queued: 3, deferred: 14, bounced: 5, rejected: 2, delivery_rate: 98,
      reasons: [
        { reason_code: "4.7.1-greylisted", human_reason: "The receiving server asked us to try again later (greylisting) — it will retry automatically", count: 11, fixable: false },
        { reason_code: "5.1.1-user-unknown", human_reason: "That address does not exist at the receiving domain", count: 4, fixable: true },
      ],
      recent: [
        { id: "r1", at: m(0, 2), direction: "out", address: "finance.team@very-long-customer-domain-name-international.example", remote: "mx1.very-long-customer-domain-name-international.example", state: "deferred", human_reason: "Greylisted — will retry in 5 minutes" },
        { id: "r2", at: m(0, 9), direction: "in", address: "hello@anexomail.com", remote: "mail.google.com", state: "delivered", human_reason: null },
        { id: "r3", at: m(0, 15), direction: "out", address: "ali@axonetis.com", remote: null, state: "bounced", human_reason: "Address does not exist" },
      ],
    };
    if (key === "admin.logs") { const lv = String(input?.level ?? "all"); const all = [
      { id: "l1", at: m(0, 1), level: "error", source: "brain", trace_id: "tr_9f3a71c2d8e04b", route: "POST /api/mail/send", status: 502, duration_ms: 1840, message: "upstream timeout talking to postfix submission", plain: "Sending failed because the mail server did not answer in time." },
      { id: "l2", at: m(0, 3), level: "warn", source: "rust", trace_id: null, route: "rpc/mail.counts", status: 200, duration_ms: 980, message: "slow query", plain: null },
      { id: "l3", at: m(0, 4), level: "info", source: "web", trace_id: "tr_1b2c3d4e5f60718", route: "GET /app/mail/inbox", status: 200, duration_ms: 64, message: "ssr render ok", plain: "A page loaded normally." },
    ]; return { logs: e ? [] : all.filter((x) => lv === "all" || x.level === lv) }; }
    if (key === "admin.reports") return { reports: e ? [] : [{ id: "rp1", period: "2026-09", title: "Organisation report 2026-09", status: "ready", numbers: { threads_started: 1240, messages_handled: 5120, incidents_recorded: 0, self_heals: 3, delivery_events: 4871, avg_first_reply_minutes: 44, delivery_rate_percent: 98.4, storage_used_gb: 41.2, spend_gbp: 1164 }, highlights: ["3 problems fixed themselves — no human time spent.", "No incidents recorded in this period."] }, { id: "rp2", period: "2026-08", title: "Organisation report 2026-08", status: "failed", numbers: {}, highlights: [] }] };
    if (key === "admin.diagnostics") return { runs: e ? [] : [{
      id: "dg1", started_at: m(1), finished_at: m(1), scope: "all", passed: 6, failed: 1, proof_hash: "9f3a71c2d8e04b6a1c77e0d2f4a98b15c3d60e7f", export_ready: true,
      probes: [
        { probe: "MX", target: "acme-studio-holdings.co.uk", result: "pass", observed: "mail.anexomail.com (10)", expected: null, fix: null, ms: 41 },
        { probe: "SPF", target: "acme-studio-holdings.co.uk", result: "pass", observed: "v=spf1 include:_spf.anexomail.com ~all", expected: null, fix: null, ms: 38 },
        { probe: "DKIM", target: "anexo1._domainkey.acme-studio-holdings.co.uk", result: "fail", observed: null, expected: "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA…", fix: "Add the TXT record shown on the Domains page, then run diagnostics again", ms: 52 },
        { probe: "DMARC", target: "_dmarc.acme-studio-holdings.co.uk", result: "pass", observed: "v=DMARC1; p=quarantine", expected: null, fix: null, ms: 30 },
        { probe: "TLS", target: "mail.anexomail.com:993", result: "pass", observed: "TLS 1.3, 76 days left", expected: null, fix: null, ms: 120 },
        { probe: "SMTP", target: "mail.anexomail.com:587", result: "pass", observed: "250 STARTTLS", expected: null, fix: null, ms: 88 },
        { probe: "IMAP", target: "mail.anexomail.com:993", result: "pass", observed: "OK Dovecot ready", expected: null, fix: null, ms: 95 },
      ] }] };
    if (key === "founderAdmin.overview") return { tenants: 12, failing_checks: 2, self_heals_24h: 3, open_incidents: 0, deferred_1h: 4, errors_1h: 1, storage_used_bytes: 41.2 * GB, worst_tenants: [{ tenant: "acme-studio-holdings", failing: 2, checks: 9 }] };
  }
  if (key.startsWith("dashboard.")) {
    // #dashboard[?empty=1][&plan=basic|pro|business|business_pro]: empty=1 is a brand-new account (first 60 seconds).
    const plan = /plan=(basic|pro|business_pro|business)/.exec(location.hash)?.[1] ?? "pro";
    const GB = 1024 ** 3;
    const lim = { basic: 10, pro: 50, business: 750, business_pro: 5000 }[plan as "basic"] ?? 10;
    if (key === "dashboard.summary") return e
      ? { unread: 0, assigned_to_me: 0, waiting: 0, sent_today: 0, done_today: 0, storage_used_bytes: 0, storage_limit_bytes: lim * GB, plan, domain: null, domain_status: "none", domain_verified: false, domain_hosted: false }
      : { unread: 7, assigned_to_me: 2, waiting: 3, sent_today: 4, done_today: 4, storage_used_bytes: 1.4 * GB, storage_limit_bytes: lim * GB, plan, domain: "acme-studio.com", domain_status: "verified", domain_verified: true, domain_hosted: false };
    if (key === "dashboard.activity") return { items: e ? [] : [
      { id: "a1", kind: "message_received", actor: "ali@axonetis.com", subject: "Re: Renewal terms", detail: null, created_at: ago(0.2) },
      { id: "a2", kind: "message_sent", actor: "you", subject: "Quote for Q4 retainer", detail: null, created_at: ago(1) },
      { id: "a3", kind: "thread_done", actor: "you", subject: "Invoice #1042 query", detail: null, created_at: ago(3) },
    ] };
    if (key === "dashboard.analytics") return { range_days: 30, received: e ? 0 : 212, sent: e ? 0 : 96, avg_first_reply_seconds: e ? null : 2640, delivery_rate: e ? null : 0.99, series: e ? [] : Array.from({ length: 14 }, (_, i) => ({ date: new Date(Date.now() - (13 - i) * 864e5).toISOString().slice(0, 10), received: 8 + ((i * 7) % 11), sent: 3 + ((i * 5) % 7) })) };
    if (key === "dashboard.calendar") return { events: e ? [] : EVENTS().slice(0, 3).map((x) => ({ id: x.id, title: x.title, starts_at: x.starts_at, ends_at: x.ends_at, location: x.location, all_day: false })) };
    if (key === "dashboard.ai-usage") return { enabled: false, plan: null, credits_total: 0, credits_used: 0, period_end: null };
  }
  if (key === "calendar.create") {
    // Import test: #cal?imperr=1 makes every "Standup" fail so the partial-failure state can be shot.
    if (/[?&]imperr=1/.test(location.hash) && String(input?.title ?? "").includes("Standup")) throw new ApiError("Calendar service is busy", 503, "unavailable");
    return { event: { id: "imp-" + Math.random().toString(36).slice(2, 8) } };
  }
  if (key === "calendar.availability") return { slots: [], share_url: null };
  if (key === "calendar.load") return { load: e ? [] : [{ member: "me@anexomail.com", display_name: "Nauman", meeting_minutes: 420, open_tasks: 3, overloaded: false }, { member: "ali@axonetis.com", display_name: "Ali Khan", meeting_minutes: 1180, open_tasks: 9, overloaded: true }] };
  if (key === "calendar.focus") return { windows: [] };
  if (key === "crm.overview") return overview();
  if (key === "crm.live") return e ? { ...CRM_LIVE, radar: [], next_actions: [], timeline: [], people: [], graph: { nodes: [], edges: [] }, counts: { contacts: 0, open_deals: 0, overdue_tasks: 0, promises: 0 } } : CRM_LIVE;
  if (key === "crm.deals") return { deals: dealsNow() };
  if (key === "crm.moveDeal") { const d = DEALS.find((x) => x.id === input?.id); if (d) { d.stage = String(input?.stage); d.probability = PROB[d.stage]; d.stale_days = d.stage === "won" || d.stage === "lost" ? null : 0; } return { deal: d }; }
  if (key === "crm.leads") {
    const st = input?.state;
    // #crm/leads?imported=1: three leads that came from an imported contacts file (the "Move to People?" bar).
    const imported = /[?&]imported=1/.test(location.hash) ? [1, 2, 3].map((n) => ({ ...LEADS[0]!, id: `im${n}`, display_name: `Imported Person ${n}`, email: `person${n}@imported.example`, source: "import", score: null, score_reason: null })) : [];
    return { leads: e ? [] : [...imported, ...LEADS].filter((l) => !st || st === "all" || l.state === st) };
  }
  // Contacts import (People "Import" panel). An address containing "known" plays "already there".
  if (key === "people.import" || key === "crm.leadsImport") {
    const rows = (input?.rows as { email: string }[]) ?? [];
    const dup = rows.filter((r) => /known/.test(r.email)).length;
    return key === "people.import"
      ? { ok: true, created: rows.length - dup, already_in_people: dup, invalid: 0, duplicate: 0 }
      : { ok: true, created: rows.length - dup, already_leads: 0, already_in_people: dup, invalid: 0, duplicate: 0 };
  }
  if (key === "crm.leadsMoveToPeople") return { ok: true, moved: 4, added_to_people: 4, already_in_people: 0 };
  if (key === "crm.leads.suggest") return { suggestions: e ? [] : [{ email: "sam@fastgrow.co", message_count: 3, last_mail_at: ago(1) }, { email: "accounts@bigcorp-international-holdings.example", message_count: 1, last_mail_at: ago(6) }] };
  if (key === "crm.memory") return { email: input?.email, person: CONTACTS[0], deals: dealsNow().slice(0, 2), tasks: TASKS.slice(0, 2).map((t) => ({ id: t.id, title: t.title, status: t.status, due_at: t.due_at, thread_id: t.thread_id })), timeline: TIMELINE.map((t) => ({ at: t.at, kind: t.kind, title: t.title, detail: t.detail, href: "/app/mail/inbox" })), next_actions: [{ action: "Reply to Ayesha", why: "Waiting 5 hours.", href: "/app/mail/inbox" }] };
  if (key === "crm.activities") return { activities: e ? [] : [{ id: "a1", kind: "email_in", actor: "ayesha@zephyrlabs.io", subject: "Re: Renewal terms for 2027", body: null, deal_id: "d1", contact_email: "ayesha@zephyrlabs.io", created_at: ago(0, 5) }, { id: "a2", kind: "stage_change", actor: "me@anexomail.com", subject: "Stage → won", body: null, deal_id: "d5", contact_email: null, created_at: ago(4) }] };
  if (key === "crm.evidence") return { entries: e ? [] : [{ id: "v1", at: ago(4), actor: "me@anexomail.com", decision: "Stage → won", why: "Acme Studio — onboarding", source_table: "crm_deals", source_id: "d5", action: "deal.stage", result: "won", created_at: ago(4) }] };
  if (key === "crm.shared") return { items: e ? [] : [{ id: "s1", kind: input?.kind ?? "inbox", subject: "Quote request — 12 seats", preview: "Hi, could you send a quote for twelve seats and the annual discount?", from_address: "orders@fastgrow.co", assigned_to: null, state: "unassigned", thread_id: "th7", created_at: ago(0, 2) }] };
  if (key === "crm.mentions") return { mentions: e ? [] : [{ id: "m1", actor: "ali@axonetis.com", target: "me@anexomail.com", context: "Can you check the Northwind terms before Friday?", thread_id: "th2", deal_id: "d2", read: false, created_at: ago(0, 1) }] };
  if (key === "crm.approvals") return { approvals: e ? [] : [{ id: "ap1", requested_by: "ali@axonetis.com", subject: "10% discount for Northwind", reason: "Multi-year commitment", amount: 1840, currency: "GBP", state: "pending", created_at: ago(0, 4) }] };
  if (key === "billing.subscription") {
    const st = /[?&]state=([a-z_]+)/.exec(location.hash)?.[1] ?? "active";
    return { plan: st === "none" ? null : "pro", state: st, seats: 5, seats_used: 3, price_per_seat: 12, currency: "GBP", interval: "month", renews_at: new Date(Date.now() + 20 * 86400e3).toISOString(), cancel_at: st === "cancelled" ? new Date(Date.now() + 9 * 86400e3).toISOString() : null, storage_per_mailbox_gb: 10 };
  }
  if (key === "billing.invoices") return { invoices: e ? [] : [
    { id: "i1", number: "ANX-2026-000412", state: "paid", subtotal: 50, tax: 10, total: 60, currency: "GBP", period_start: ago(30), period_end: ago(0), issued_at: ago(1), paid_at: ago(1), pdf_url: "https://polar.sh/example.pdf" },
    { id: "i2", number: "ANX-2026-000377", state: "open", subtotal: 50, tax: 10, total: 60, currency: "GBP", period_start: ago(60), period_end: ago(30), issued_at: ago(31), paid_at: null, pdf_url: null },
    { id: "i3", number: "ANX-2026-000301", state: "void", subtotal: 0, tax: 0, total: 0, currency: "GBP", period_start: null, period_end: null, issued_at: ago(90), paid_at: null, pdf_url: null },
  ] };
  if (key === "/api/auth/sessions") return [
    { id: "s1", device: "Windows", browser: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/141.0 Safari/537.36 Edg/141.0", ip: "203.0.113.24", location: "London, GB", last_seen_at: ago(0, 0), current: true },
    { id: "s2", device: "iPhone", browser: "Safari", ip: "198.51.100.7", location: "Lahore, PK", last_seen_at: ago(2), current: false },
    { id: "s3", device: "Bun/1.4.0", browser: "Bun/1.4.0", ip: "127.0.0.1", location: null, last_seen_at: ago(0, 1), current: false },
  ];
  if (key === "/api/auth/passkey/list") return e ? [] : [{ id: "pk1", device_name: "MacBook Pro — Touch ID", created_at: ago(40), last_used_at: ago(1) }];
  if (key === "/api/auth/recovery") return { set: !e, kind: "gmail", hint: "n***@gmail.com", sms_note: "SMS recovery is not offered." };
  if (key === "account.delete.state" || key.startsWith("/api/account-deletion/state")) return /[?&]del=1/.test(location.hash) ? { scheduled: true, scheduled_for: ago(-5), days_left: 5, blockers: [] } : /[?&]blocked=1/.test(location.hash) ? { scheduled: false, blockers: [{ code: "active_subscription", message: "Cancel your active subscription first." }] } : { scheduled: false, blockers: [] };
  if (key === "work.tasks" || key.startsWith("/api/work/tasks")) return { tasks: e ? [] : TASKS };
  if (key === "work.promises" || key.startsWith("/api/work/promises")) return { promises: e ? [] : PROMISES };
  if (key === "work.followThrough" || key.startsWith("/api/work/follow-through")) return { rows: e ? [] : FOLLOW };
  if (key === "work.note" || key.startsWith("/api/work/notes")) return { note: null };
  if (key.startsWith("/api/contacts/tags")) return { tags: [{ id: "g1", name: "customer", colour: null, count: 2 }, { id: "g2", name: "vendor", colour: null, count: 1 }, { id: "g3", name: "investor", colour: null, count: 1 }] };
  if (/^\/api\/contacts\/[^/?]+\/timeline/.test(key)) return { events: TIMELINE };
  if (/^\/api\/contacts\/[^/?]+/.test(key)) { const id = key.split("/")[3].split("?")[0]; return { contact: CONTACTS.find((c) => c.id === id) ?? CONTACTS[0] }; }
  if (key.startsWith("/api/contacts")) {
    const q = new URLSearchParams(key.split("?")[1] ?? "").get("q")?.toLowerCase();
    return { contacts: e ? [] : CONTACTS.filter((c) => !q || (c.display_name ?? c.primary_address).toLowerCase().includes(q)) };
  }
  if (/^\/api\/companies\/[^/?]+\/timeline/.test(key)) return { events: TIMELINE };
  if (/^\/api\/companies\/[^/?]+/.test(key)) { const d = key.split("/")[3].split("?")[0]; return { company: COMPANIES.find((c) => c.domain === d) ?? COMPANIES[0], people: CONTACTS.slice(0, 2) }; }
  if (key.startsWith("/api/companies")) return { companies: e ? [] : COMPANIES };
  // ---- Admin → Members / Teams / Invitations (#admin-members, #admin-teams; ?empty=1, ?err=1 = endpoint 404, role=member|admin)
  if (key.startsWith("/api/workspace/")) {
    if (/[?&]err=1/.test(location.hash)) throw new ApiError("Not found", 404, "not_found");
    if (key === "/api/workspace/members") return { members: e ? [] : [
      { id: "m1", user_id: "u1", email: "pro.buyer@anexomail.com", name: "Pro Buyer", role: "owner", joined_at: ago(120) },
      { id: "m2", user_id: "u2", email: "sara@acme-studio.co.uk", name: "Sara Khan", role: "admin", joined_at: ago(40) },
      { id: "m3", user_id: "u3", email: "ali.raza@acme-studio.co.uk", name: "Ali Raza", role: "member", joined_at: ago(12) },
      { id: "m4", user_id: "u4", email: "accounts.payable.northern-region@acme-studio.co.uk", name: null, role: "member", joined_at: ago(3) },
    ] };
    if (key === "/api/workspace/invitations") return { invitations: e ? [] : [
      { id: "i1", email: "new.hire@acme-studio.co.uk", role: "member", expires_at: ago(-5) },
      { id: "i2", email: "contractor@freelance-design-partners.example", role: "admin", expires_at: ago(-1) },
    ] };
    if (key === "/api/workspace/teams") return { teams: e ? [] : [
      { id: "t1", name: "Support", slug: "support", member_count: 4 },
      { id: "t2", name: "Finance & accounts payable northern region", slug: "finance-ap-north", member_count: 1 },
    ] };
  }
  throw new ApiError("not wired in harness: " + key, 404, "not_found");
}
const later = <T>(v: () => T) => new Promise<T>((res, rej) => setTimeout(() => { try { res(v()); } catch (x) { rej(x); } }, 60));
export const api = <T,>(path: string, _init?: unknown) => later(() => sample(path, undefined) as T);
export const rpcOrRest = <T,>(proc: string, _rest: unknown, input?: Record<string, unknown>) => later(() => sample(proc, input) as T);
export const rpc = <T,>(proc: string, input?: Record<string, unknown>) => later(() => sample(proc, input) as T);
