// FOUNDER keys (his order 23 Nov 2026 07:51: the same key families as the Desk, written for the founder, nothing imported from the Desk). Pure, unit-tested.
// Already in the founder app and kept: Ctrl+K search (Palette.tsx) and the "g then letter" jumps. NEW here: Ctrl+D home, Ctrl+/ help, Alt+Shift+letter, Alt+Shift+Up/Down.
// Keys are read by e.code, so they work on any keyboard layout. WCAG 2.1.1: every page stays one click away in the sidebar.
type Ev = { code: string; altKey: boolean; shiftKey: boolean; ctrlKey: boolean; metaKey: boolean };
/** page id -> key (one table; a key used twice fails the unit test). */
export const FOUNDER_KEYS: Record<string, string> = {
  dashboard: "d", bridge: "b", mail: "m", people: "p", ai: "i", systems: "y", control: "c", finance: "f", release: "r", move_in: "v", audit: "u", settings: "s", devices: "e", profile: "o",
};
export const founderKeyLabel = (id: string): string => (id === "dashboard" ? "Ctrl+D" : FOUNDER_KEYS[id] ? `Alt+Shift+${FOUNDER_KEYS[id].toUpperCase()}` : "");
/** Alt+Shift+letter -> page id, else null. */
export function founderComboTarget(e: Ev): string | null {
  if (!e.altKey || !e.shiftKey || e.ctrlKey || e.metaKey) return null;
  const m = /^Key([A-Z])$/.exec(e.code); if (!m) return null; const k = m[1].toLowerCase();
  return Object.keys(FOUNDER_KEYS).find((id) => FOUNDER_KEYS[id] === k) ?? null;
}
export const founderHomeKey = (e: Ev): boolean => (e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.code === "KeyD";
export const founderHelpKey = (e: Ev): boolean => (e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.code === "Slash";
export const founderStepKey = (e: Ev): -1 | 0 | 1 => (e.altKey && e.shiftKey && !e.ctrlKey && !e.metaKey ? (e.code === "ArrowUp" ? -1 : e.code === "ArrowDown" ? 1 : 0) : 0);
export function founderStep(ids: string[], cur: string, d: -1 | 1): string {
  if (!ids.length) return "dashboard"; const i = ids.indexOf(cur); if (i < 0) return ids[0];
  return ids[Math.min(ids.length - 1, Math.max(0, i + d))];
}
export function founderKeyProblems(pageIds: string[]): string[] {
  const out: string[] = [], seen = new Map<string, string>();
  for (const [id, k] of Object.entries(FOUNDER_KEYS)) { const o = seen.get(k); if (o) out.push(`key ${k} is used by ${o} and ${id}`); seen.set(k, id); }
  for (const id of pageIds) if (!FOUNDER_KEYS[id]) out.push(`${id} has no key`);
  return out;
}
