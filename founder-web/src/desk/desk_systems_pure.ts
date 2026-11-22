// ADMIN DESK D7 Systems (22 Nov 2026, his 07:38 word: "system ka folder banao, employee ko maloom hona chahiye system kaise live hai ya masla hai"). PURE view model.
// Input = the kernel-verified stream snapshot (Rule 52). Output = plain words for EVERY employee (working / slow or partly down / down / not measured) plus what to tell a customer,
// and the technical rows only for owner / admin / engineer. The Desk's own way, not the Founder's. Honest: a value that was not measured says so; a stale stream says "Not answering".
import type { StreamState } from "./desk_stream_pure";
import { asServices, ago, type Svc } from "./desk_bridge_pure";

export type Level = "ok" | "degraded" | "outage" | "unknown" | "stale" | "connecting";
export type Area = { id: string; label: string; level: Level; words: string; tell: string | null; tech: { label: string; text: string }[] };
export type Systems = { overall: Level; headline: string; banner: string | null; areas: Area[]; showTech: boolean };

/** Which of the Desk's measured services belong to each plain-language area. */
export const AREAS: { id: string; label: string; services: string[]; tell: string }[] = [
  { id: "mail", label: "Receiving and sending company mail", services: ["mail_in", "mail_out"], tell: "We know mail may be late or missing for a short while and the team is working on it. Do not promise a time." },
  { id: "desk", label: "The Desk website and its secure connection", services: ["h3_edge", "tls"], tell: "The support desk is having trouble. Use the phone or note the customer's details and reply later." },
  { id: "records", label: "Sign-in and saving your work", services: ["db", "signer"], tell: "Some actions may not save right now. Write the customer's request down and enter it later." },
  { id: "virus", label: "Virus scanning of attachments", services: ["clamav"], tell: "Attachments may be held back for a short while. Ask the customer to wait; do not open files yourself." },
  { id: "audit", label: "Audit trail (the record of who did what)", services: ["ledger"], tell: "Nothing to tell the customer. Tell your admin." },
];
const WORDS: Record<Level, string> = { ok: "Working", degraded: "Slow or partly down", outage: "Down", unknown: "Not measured yet", stale: "Not answering", connecting: "Connecting…" };
const RANK: Record<Level, number> = { ok: 0, unknown: 1, connecting: 1, degraded: 2, stale: 3, outage: 4 };
const lv = (s: string): Level => (s === "operational" ? "ok" : s === "degraded" ? "degraded" : s === "outage" ? "outage" : "unknown");
const worst = (xs: Level[]): Level => xs.reduce((a, b) => (RANK[b] > RANK[a] ? b : a), "ok" as Level);

/** Only these roles see latency, probe age and the Service health page. Today this is a screen rule; the server-side split by role is phase G / H (fadm_need). */
export const canSeeTech = (role: string): boolean => ["owner", "admin", "engineer"].includes(role.trim().toLowerCase());

export function systemsModel(stream: StreamState, data: { services?: unknown }, role: string): Systems {
  const fresh = stream === "live", wait = stream === "connecting", svcs = fresh ? asServices(data.services) : null;
  const showTech = canSeeTech(role);
  const areas: Area[] = AREAS.map((a) => {
    const rows = a.services.map((id) => svcs?.find((s) => s.service === id) ?? null);
    const level: Level = !fresh ? (wait ? "connecting" : "stale") : !svcs ? "unknown" : worst(rows.map((r) => (r ? lv(r.state) : "unknown")));
    // "unknown" mixed with ok must stay "unknown": we never call an area Working when part of it was not measured.
    const lvl: Level = fresh && svcs && rows.some((r) => !r || lv(r.state) === "unknown") && level === "ok" ? "unknown" : level;
    const bad = lvl === "degraded" || lvl === "outage";
    const tech = showTech && fresh ? rows.filter((r): r is Svc => !!r).map((r) => ({ label: r.label, text: [r.state === "operational" ? "Operational" : r.state, r.last_latency_ms !== null ? `${r.last_latency_ms} ms` : null, ago(r.age_s)].filter(Boolean).join(" · ") })) : [];
    return { id: a.id, label: a.label, level: lvl, words: WORDS[lvl], tell: bad ? a.tell : null, tech };
  });
  const overall = worst(areas.map((a) => a.level));
  const headline = overall === "ok" ? "Everything we measure is working." : overall === "outage" ? "Something is down. See below what to tell customers." : overall === "degraded" ? "Something is slow or partly down." : overall === "stale" ? "The Desk is not getting live updates. Do not trust the colours below." : overall === "connecting" ? "Connecting…" : "Working, but some parts are not measured yet.";
  const hot = areas.filter((a) => a.tell);
  return { overall, headline, banner: hot.length ? hot.map((a) => `${a.label}: ${a.tell}`).join(" ") : null, areas, showTech };
}
