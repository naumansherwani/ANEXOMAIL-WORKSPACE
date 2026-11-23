// ADMIN DESK 1m-3 (card B8 Staff online and shifts), 23 Nov 2026. Pure parsing of the one read-only door /desk/v1/staff/board. Fail-closed: anything that is not exactly the agreed shape is null and the screen says "Data unavailable".
// Names and counts only (never an e-mail, IP, device or key). No money, no promises.
export type StaffCounts = { staff: number; online: number; scheduled: number; on_shift: number; covered: number; gap: number; extra: number; elevations: number; breakglass: number };
export type StaffPerson = { name: string; role: "owner" | "agent"; online: boolean; scheduled: boolean; on_shift: boolean; signed_in_minutes: number | null };
export type StaffElevation = { who: string; relation: string; unit: string; source: "elevation" | "breakglass"; minutes_left: number };
export type StaffTrend = "up" | "steady" | "down" | "unknown";
export type StaffBoard = { counts: StaffCounts; people: StaffPerson[]; elevations: StaffElevation[]; spark: (number | null)[]; trend: StaffTrend };
export const COUNT_KEYS = ["staff", "online", "scheduled", "on_shift", "covered", "gap", "extra", "elevations", "breakglass"] as const;
const nat = (x: unknown): x is number => typeof x === "number" && Number.isInteger(x) && x >= 0;
const txt = (x: unknown): x is string => typeof x === "string" && x.length > 0 && x.length <= 80;
export function parseBoard(j: unknown): StaffBoard | null {
  const o = j as Record<string, unknown> | null;
  const c = (o?.counts ?? null) as Record<string, unknown> | null;
  if (!o || !c || !COUNT_KEYS.every((k) => nat(c[k]))) return null;
  const n = c as unknown as StaffCounts;
  if (!(n.online <= n.staff && n.scheduled <= n.staff && n.on_shift <= n.scheduled && n.covered + n.gap === n.on_shift && n.covered <= n.online)) return null;
  if (!Array.isArray(o.people) || o.people.length > 50 || !Array.isArray(o.elevations) || o.elevations.length > 20) return null;
  const people: StaffPerson[] = [];
  for (const p of o.people as Record<string, unknown>[]) {
    if (!p || Object.keys(p).length !== 6 || !txt(p.name) || !["owner", "agent"].includes(p.role as string) || typeof p.online !== "boolean" || typeof p.scheduled !== "boolean" || typeof p.on_shift !== "boolean") return null;
    if (!(p.signed_in_minutes === null || nat(p.signed_in_minutes))) return null;
    people.push({ name: p.name, role: p.role as "owner" | "agent", online: p.online, scheduled: p.scheduled, on_shift: p.on_shift, signed_in_minutes: p.signed_in_minutes as number | null });
  }
  const elevations: StaffElevation[] = [];
  for (const e of o.elevations as Record<string, unknown>[]) {
    if (!e || !txt(e.who) || !txt(e.relation) || !txt(e.unit) || !["elevation", "breakglass"].includes(e.source as string) || !nat(e.minutes_left)) return null;
    elevations.push({ who: e.who, relation: e.relation, unit: e.unit, source: e.source as "elevation" | "breakglass", minutes_left: e.minutes_left });
  }
  if (!Array.isArray(o.spark) || o.spark.length !== 24 || !o.spark.every((x) => x === null || nat(x))) return null;
  if (!["up", "steady", "down", "unknown"].includes(o.trend as string)) return null;
  return { counts: n, people, elevations, spark: o.spark as (number | null)[], trend: o.trend as StaffTrend };
}
export const TREND_WORDS: Record<StaffTrend, string> = { up: "More people online than 24 hours ago", steady: "Same as 24 hours ago", down: "Fewer people online than 24 hours ago", unknown: "No 24-hour history yet" };
export const NOT_YOURS = "This is for people who manage staff.";
export const NOTE = "Online means a live sign-in right now. On shift uses each person's own shift hours in his own time zone. People with no shift hours are never counted as late or missing.";
export function headline(c: StaffCounts): string {
  if (c.staff === 0) return "No active staff account yet.";
  const base = `${c.online} of ${c.staff} online`;
  if (c.on_shift === 0) return `${base}. Nobody has a shift right now.`;
  return c.gap === 0 ? `${base}. Everyone on shift is online.` : `${base}. ${c.gap} on shift ${c.gap === 1 ? "is" : "are"} not online.`;
}
export function personWords(p: StaffPerson): string {
  if (p.online) return p.scheduled ? (p.on_shift ? "Online, on shift" : "Online, outside shift") : "Online";
  return p.scheduled ? (p.on_shift ? "On shift, not online" : "Off shift") : "Offline";
}
export function signedInWords(m: number | null): string { if (m === null) return ""; if (m < 1) return "Signed in just now"; if (m < 60) return `Signed in ${m} min ago`; const h = Math.floor(m / 60); return `Signed in ${h} h ${m % 60} min ago`; }
export function leftWords(m: number): string { if (m <= 0) return "Ending now"; if (m < 60) return `${m} min left`; return `${Math.floor(m / 60)} h ${m % 60} min left`; }
export function sourceWords(s: "elevation" | "breakglass"): string { return s === "breakglass" ? "Break-glass" : "Temporary access"; }
/** Gap first (on shift, not online), then online, then the rest; names break ties. */
export function sortedPeople(ps: StaffPerson[]): StaffPerson[] {
  const rank = (p: StaffPerson) => (p.on_shift && !p.online ? 0 : p.online ? 1 : 2);
  return ps.map((p, i) => ({ p, i })).sort((a, b) => rank(a.p) - rank(b.p) || a.p.name.localeCompare(b.p.name) || a.i - b.i).map((x) => x.p);
}
