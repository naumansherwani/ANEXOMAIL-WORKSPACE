// ADMIN DESK desk_registry_pure.ts (BL-46 B13 step T4i, 25 Nov 2026): pure logic of the company REGISTRATION NUMBER picker on the "Company confirmation" screen. No network, no browser.
// Fail closed: an answer that is not exactly the expected shape is "not available"; an unknown word is a plain refusal. Rust doors: registry.rs (read only); SQL: AD34 registry_kind (GLEIF RA list) + AD35 company identifiers.
// Rules the screen keeps: the country and the register come from the GLEIF list the database holds, never typed; a number shape is only claimed when the database says it is proven (shape_known), otherwise the screen says "no proven shape for this register" and accepts what is typed;
// the company NAME comes from the Control Plane (name_state ok | missing | unavailable); nothing is guessed. A register website is shown as TEXT, never as a link (it comes from a public list, not from us).
// RULE 52 COMBO: S = every answer is kernel-verified before it reaches this file; M = N/A; L = this file logs nothing and never puts a number in a URL.
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CTRL = /[\u0000-\u001f\u007f]/;
export const NUMBER_MAX = 80;
/** Countries where ANEXOMAIL is not available (banned-countries/banned.json is the ONE list; the Desk keeps its own copy, a test fails on drift). The Rust door already drops them; this is the second layer. */
export const BANNED_ISO: readonly string[] = ["AF", "IL", "KP", "SY"];
export const countryCodeOk = (c: string) => /^[A-Z]{2}$/.test(c);
export const numberOk = (n: string) => { const t = [...n.trim()].length; return t >= 1 && t <= NUMBER_MAX && !CTRL.test(n); };

export type Country = { code: string; country: string; registers: number };
export type Register = { id: number; raCode: string; name: string; authority: string; website: string; shapeKnown: boolean };
const text = (v: unknown, max: number): v is string => typeof v === "string" && [...v].length <= max && !CTRL.test(v);

export function parseCountries(j: unknown): Country[] | null {
  const x = j as Record<string, unknown> | null;
  if (x === null || typeof x !== "object" || !Array.isArray(x.countries) || x.countries.length > 400) return null;
  const out: Country[] = [];
  for (const r of x.countries as unknown[]) {
    const o = r as Record<string, unknown> | null;
    if (o === null || typeof o !== "object" || typeof o.code !== "string" || !countryCodeOk(o.code) || !text(o.country, 120) || o.country === "" || !Number.isInteger(o.registers) || (o.registers as number) < 1) return null;
    if (BANNED_ISO.includes(o.code)) continue;   // never listed, even if the server sent it
    out.push({ code: o.code, country: o.country, registers: o.registers as number });
  }
  return out;
}
export function parseRegisters(j: unknown): Register[] | null {
  const x = j as Record<string, unknown> | null;
  if (x === null || typeof x !== "object" || !Array.isArray(x.registers) || x.registers.length > 100) return null;
  const out: Register[] = [];
  for (const r of x.registers as unknown[]) {
    const o = r as Record<string, unknown> | null;
    if (o === null || typeof o !== "object" || !Number.isInteger(o.id) || (o.id as number) < 1 || typeof o.ra_code !== "string" || !/^RA\d{6}$/.test(o.ra_code)
      || !text(o.name, 300) || !text(o.authority, 300) || !text(o.website, 300) || typeof o.shape_known !== "boolean") return null;
    out.push({ id: o.id as number, raCode: o.ra_code, name: o.name, authority: o.authority, website: o.website, shapeKnown: o.shape_known });
  }
  return out;
}
export type NumberBody = { registry_id: number; number: string };
export function buildNumber(registryId: number | null, number: string): NumberBody | null {
  const n = number.trim();
  return registryId !== null && Number.isInteger(registryId) && registryId > 0 && numberOk(n) ? { registry_id: registryId, number: n } : null;
}
export const buildHistory = (tenantId: string): { tenant_id: string } | null => UUID.test(tenantId.trim()) && !/^[0-]+$/.test(tenantId.trim()) ? { tenant_id: tenantId.trim().toLowerCase() } : null;

export const CHECKS = ["ok", "wrong_shape", "shape_unknown", "bad_number", "no_register"] as const;
export type Check = (typeof CHECKS)[number];
export function parseCheck(j: unknown): Check | null { const o = j !== null && typeof j === "object" ? (j as Record<string, unknown>).check : null; return typeof o === "string" && (CHECKS as readonly string[]).includes(o) ? (o as Check) : null; }
export function checkWords(c: Check | null): string {
  switch (c) {
    case "ok": return "The number has the shape this register uses.";
    case "wrong_shape": return "The number does not have the shape this register uses. Check it against the register.";
    case "shape_unknown": return "No number shape has been proven for this register yet, so the Desk cannot check the shape. What you typed is used as typed.";
    case "bad_number": return "That is not a usable number.";
    case "no_register": return "That register is not in the list.";
    default: return "The Desk could not check this number.";
  }
}

export type NameState = "ok" | "missing" | "unavailable";
export type Lookup =
  | { state: "none" | "no_right" | "no_register" | "bad_number" }
  | { state: "found"; tenantId: string; since: string; shapeState: "shape_ok" | "shape_unproven"; nameState: NameState; tenantName: string | null };
export function parseLookup(j: unknown): Lookup | null {
  const o = j as Record<string, unknown> | null;
  if (o === null || typeof o !== "object") return null;
  if (o.state === "none" || o.state === "no_right" || o.state === "no_register" || o.state === "bad_number") return { state: o.state };
  if (o.state !== "found" || typeof o.tenant_id !== "string" || !UUID.test(o.tenant_id) || /^[0-]+$/.test(o.tenant_id) || typeof o.since !== "string" || o.since.length > 40
    || (o.shape_state !== "shape_ok" && o.shape_state !== "shape_unproven") || (o.name_state !== "ok" && o.name_state !== "missing" && o.name_state !== "unavailable")) return null;
  if (o.name_state === "ok" ? !text(o.tenant_name, 120) : o.tenant_name !== null) return null;
  return { state: "found", tenantId: o.tenant_id.toLowerCase(), since: o.since, shapeState: o.shape_state, nameState: o.name_state, tenantName: o.name_state === "ok" ? (o.tenant_name as string) : null };
}
export function lookupWords(l: Lookup | null): string {
  if (l === null) return "The Desk could not verify the answer, so nothing is shown.";
  switch (l.state) {
    case "none": return "No company has recorded this number. Nothing is guessed: find the company another way.";
    case "no_right": return "You do not have the right to look up registration numbers.";
    case "no_register": return "That register is not in the list.";
    case "bad_number": return "That is not a usable number.";
    case "found": return l.nameState === "ok" && l.tenantName !== null ? `This number belongs to ${l.tenantName === "" ? "a company with no name on record" : l.tenantName}.` : l.nameState === "missing" ? "A company holds this number, but the Control Plane has no record of it. Do not use it." : "A company holds this number, but its name could not be confirmed right now. Try again before you use it.";
  }
}

export type Held = { id: number; register: string; country: string; raCode: string; number: string; shapeState: string; validFrom: string; validTo: string | null; endedWhy: string | null };
export function parseHistory(j: unknown): Held[] | null {
  const x = j as Record<string, unknown> | null;
  if (x === null || typeof x !== "object" || !Array.isArray(x.items) || x.items.length > 100) return null;
  const out: Held[] = [];
  for (const r of x.items as unknown[]) {
    const o = r as Record<string, unknown> | null;
    if (o === null || typeof o !== "object" || !Number.isInteger(o.id) || !text(o.register, 300) || !text(o.country, 2) || !text(o.ra_code, 12) || !text(o.number, 64) || !text(o.shape_state, 20)
      || typeof o.valid_from !== "string" || o.valid_from.length > 40 || (o.valid_to !== null && (typeof o.valid_to !== "string" || o.valid_to.length > 40)) || (o.ended_why !== null && !text(o.ended_why, 20))) return null;
    out.push({ id: o.id as number, register: o.register, country: o.country, raCode: o.ra_code, number: o.number, shapeState: o.shape_state, validFrom: o.valid_from, validTo: o.valid_to as string | null, endedWhy: o.ended_why as string | null });
  }
  return out;
}
export const registerLabel = (r: Register): string => `${r.name || r.authority || r.raCode} (${r.raCode})${r.shapeKnown ? "" : " - number shape not proven"}`;

// ---- the searchable list of the pickers (WAI-ARIA APG editable combobox with list autocomplete): pure part ----
export type ComboItem = { key: string; label: string; hint?: string; note?: string };
/** Lower case, no accents, no extra spaces: "Cote d'Ivoire" is found by "cote", "Curaçao" by "curacao". */
export const fold = (t: string): string => t.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/\s+/g, " ").trim();
/** Items that match the typed text, best first: a label that STARTS with it, then a word that starts with it, then any other place it appears (label or hint). An empty text keeps the order. At most `max` items. */
export function filterItems(items: readonly ComboItem[], q: string, max = 300): ComboItem[] {
  const f = fold(q);
  if (f === "") return items.slice(0, max);
  const ranked: { it: ComboItem; r: number; i: number }[] = [];
  items.forEach((it, i) => {
    const l = fold(it.label), h = fold(it.hint ?? "");
    const r = l.startsWith(f) ? 0 : l.split(" ").some((w) => w.startsWith(f)) ? 1 : l.includes(f) ? 2 : h.includes(f) ? 3 : -1;
    if (r >= 0) ranked.push({ it, r, i });
  });
  ranked.sort((a, b) => a.r - b.r || a.i - b.i);
  return ranked.slice(0, max).map((x) => x.it);
}
/** Splits a label into [before, match, after] for the highlight; no match = the whole label as "before". Works on the folded text, so the cut falls on the same letters of the original (folding never changes the length of a plain letter). */
export function splitMatch(label: string, q: string): [string, string, string] {
  const f = fold(q); if (f === "") return [label, "", ""];
  const chars = [...label]; let folded = ""; const at: number[] = [];
  chars.forEach((c, i) => { const g = fold(c === " " ? " " : c); for (let k = 0; k < g.length; k++) at.push(i); folded += g; });
  const pos = folded.indexOf(f); if (pos < 0 || f.length === 0) return [label, "", ""];
  const a = at[pos], b = at[pos + f.length - 1] + 1;
  return [chars.slice(0, a).join(""), chars.slice(a, b).join(""), chars.slice(b).join("")];
}
/** Next active row for the arrow keys (wraps round); -1 means "none yet". */
export const stepActive = (cur: number, dir: 1 | -1, n: number): number => (n <= 0 ? -1 : cur < 0 ? (dir === 1 ? 0 : n - 1) : (cur + dir + n) % n);

// ---- the short note under the pickers: which countries are not listed, and why (professional wording, built from the same BANNED_ISO list) ----
export const BANNED_NAMES: Readonly<Record<string, string>> = { AF: "Afghanistan", IL: "Israel", KP: "North Korea", SY: "Syria" };
/** One sentence for staff. It names the countries from BANNED_ISO, so the note and the filter can never disagree (a test fails if a banned code has no name). */
export function bannedNote(): string {
  const n = BANNED_ISO.map((c) => BANNED_NAMES[c] ?? c).sort();
  const list = n.length > 1 ? `${n.slice(0, -1).join(", ")} and ${n[n.length - 1]}` : n.join("");
  return `${list} are not listed. Anexomail does not provide its service in these countries, so no company register is offered for them.`;
}
