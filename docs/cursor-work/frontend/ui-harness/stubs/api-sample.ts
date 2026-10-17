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
  if (key === "calendar.availability") return { slots: [], share_url: null };
  if (key === "calendar.load") return { load: e ? [] : [{ member: "me@anexomail.com", display_name: "Nauman", meeting_minutes: 420, open_tasks: 3, overloaded: false }, { member: "ali@axonetis.com", display_name: "Ali Khan", meeting_minutes: 1180, open_tasks: 9, overloaded: true }] };
  if (key === "calendar.focus") return { windows: [] };
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
  throw new ApiError("not wired in harness: " + key, 404, "not_found");
}
const later = <T>(v: () => T) => new Promise<T>((res, rej) => setTimeout(() => { try { res(v()); } catch (x) { rej(x); } }, 60));
export const api = <T,>(path: string, _init?: unknown) => later(() => sample(path, undefined) as T);
export const rpcOrRest = <T,>(proc: string, _rest: unknown, input?: Record<string, unknown>) => later(() => sample(proc, input) as T);
export const rpc = <T,>(proc: string, input?: Record<string, unknown>) => later(() => sample(proc, input) as T);
