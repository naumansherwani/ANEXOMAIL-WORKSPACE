// ADMIN DESK 1m-keys (his haan 23 Nov 2026 07:44): ONE key table for every rail folder. Pure (no browser, no network), unit-tested.
// Families: Ctrl+K palette, Ctrl+D home (desk_cards.ts), Ctrl+/ help, Alt+Shift+letter, Alt+Shift+digit, Alt+Shift+Up/Down. NO "g then" chord here.
// Keys are read by e.code, so they work on any keyboard layout (Urdu included). Plan + web research: docs/claude/admin-desk/RAIL-KEYS-PLAN-23NOV.md
import { CARDS, HOME_KEY, route } from "./desk_cards";

/** Folders that have no card key. Letters, then digits 1..7 (Audit uses its card key U). */
export const RAIL_KEYS: Record<string, string> = {
  inboxes: "i", cases: "c", macros: "o", routing: "g", automations: "n", people: "h", crm: "j", knowledge: "k", viewas: "w", datarequests: "z", abuse: "f",
  incidents: "1", quality: "2", team: "3", shifts: "4", analytics: "5", bridge: "6", policy: "7",
};
type Ev = { code: string; altKey: boolean; shiftKey: boolean; ctrlKey: boolean; metaKey: boolean };
/** The key of a folder: its card key when it has one, else its rail key; "" for none. */
export const keyOf = (id: string): string => (id === "dashboard" ? HOME_KEY : CARDS.find((c) => c.id === id)?.key ?? RAIL_KEYS[id] ?? "");
export const keyLabel = (id: string): string => (id === "dashboard" ? "Ctrl+D" : keyOf(id) ? `Alt+Shift+${keyOf(id).toUpperCase()}` : "");
/** Alt+Shift+letter or digit for a rail folder (card letters are handled by comboTarget in desk_cards.ts). */
export function railComboTarget(e: Ev): string | null {
  if (!e.altKey || !e.shiftKey || e.ctrlKey || e.metaKey) return null;
  const m = /^(?:Key([A-Z])|Digit([0-9]))$/.exec(e.code); if (!m) return null; const k = (m[1] ?? m[2]).toLowerCase();
  const id = Object.keys(RAIL_KEYS).find((x) => RAIL_KEYS[x] === k); return id ? route(id) : null;
}
/** Alt+Shift+Up / Down: -1, +1, or 0 for no. */
export const stepKey = (e: Ev): -1 | 0 | 1 => (e.altKey && e.shiftKey && !e.ctrlKey && !e.metaKey ? (e.code === "ArrowUp" ? -1 : e.code === "ArrowDown" ? 1 : 0) : 0);
/** The folder before / after `cur` in `ids` (rail order). Stays put at the ends; "dashboard" when cur is unknown. */
export function railStep(ids: string[], cur: string, d: -1 | 1): string {
  if (!ids.length) return "dashboard"; const i = ids.indexOf(cur); if (i < 0) return ids[0];
  return ids[Math.min(ids.length - 1, Math.max(0, i + d))];
}
export const paletteKey = (e: Ev): boolean => (e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.code === "KeyK";
export const helpKey = (e: Ev): boolean => (e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.code === "Slash";
export type Item = { id: string; label: string };
/** Palette search: names that start with the text first, then names that contain it; empty text = all, in rail order. */
export function searchItems(items: Item[], q: string): Item[] {
  const t = q.trim().toLowerCase(); if (!t) return items;
  const a = items.filter((x) => x.label.toLowerCase().startsWith(t)), b = items.filter((x) => !x.label.toLowerCase().startsWith(t) && (x.label.toLowerCase().includes(t) || x.id.includes(t)));
  return [...a, ...b];
}
/** Problems in the table itself (the unit test requires an empty list): a key used twice, or a rail folder without a key. */
export function keyProblems(railIds: string[]): string[] {
  const out: string[] = [], seen = new Map<string, string>();
  const put = (id: string, k: string) => { if (!k) { out.push(`${id} has no key`); return; } const o = seen.get(k); if (o && o !== id) out.push(`key ${k} is used by ${o} and ${id}`); seen.set(k, id); };
  put("dashboard", HOME_KEY); for (const c of CARDS) put(c.id, c.key);
  for (const [id, k] of Object.entries(RAIL_KEYS)) put(id, k);
  for (const id of railIds) if (!keyOf(id)) out.push(`${id} has no key`);
  return out;
}
