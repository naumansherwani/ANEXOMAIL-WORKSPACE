// QC8a (21 Nov 2026): the keyboard layer, the PURE part (no DOM, no React). Plan: docs/claude/QC8A-QC8B-PLAN-21NOV.md, his 5 answers 21 Nov 03:22.
// It does not replace mail_pure.keyCmd or the MailBox handler (both stay byte for byte); it only ADDS: (1) the switch for single-letter keys (WCAG 2.1.4, level A),
// (2) arrow / Home / End / type-ahead movement in the simple mail list (his answer 4: a plain list, no grid), (3) the help rows for the "?" sheet.
export type Mods = { ctrl?: boolean; meta?: boolean; alt?: boolean; shift?: boolean };
export type KeyScene = { composeOpen: boolean; inDialog: boolean; typing: boolean };

/** The existing single-character shortcuts of the mail screen and of the page (App "g" jumps). Used ONLY to decide what the switch silences. */
export const SINGLE_KEYS: readonly string[] = ["/", "r", "a", "f", "c", "j", "k", "e", "#", "s", "u", "g", "i", "d", "q", "v", "t", "p", "b", "m"];

/** True when this key press is a bare printable-character shortcut: one character, no Ctrl / Meta / Alt. Shift+/ ("?") counts, because it is a character key too. */
export function isCharShortcut(key: string, m: Mods): boolean {
  if (m.ctrl || m.meta || m.alt) return false;
  return [...key].length === 1 && key !== " ";
}

/** WCAG 2.1.4: with the switch OFF a bare character key must not reach the shortcut handlers. Typing places, dialogs and Compose are not touched (they own their keys). */
export function silenceSingle(key: string, m: Mods, on: boolean, s: KeyScene): boolean {
  if (on || s.typing || s.inDialog || s.composeOpen) return false;
  return isCharShortcut(key, m) && key !== "?" ? SINGLE_KEYS.includes(key.toLowerCase()) : false;
}

/** Normalises the stored setting: anything but an explicit false means ON (his fast keys keep working until he switches them off). */
export const singleKeysOn = (v: unknown): boolean => v !== false && v !== "off" && v !== 0;

export type ListMove = { to: number; extend?: boolean } | null;
/** Arrow / Home / End movement over `n` rows (cur = index of the selected row, -1 none). Up/Down, Home/End; Shift extends. The existing j/k are NOT handled here. */
export function listMove(key: string, m: Mods, cur: number, n: number): ListMove {
  if (n <= 0 || m.ctrl || m.meta || m.alt) return null;
  const to = key === "ArrowDown" ? Math.min(n - 1, cur + 1) : key === "ArrowUp" ? Math.max(0, cur < 0 ? 0 : cur - 1) : key === "Home" ? 0 : key === "End" ? n - 1 : -2;
  if (to === -2) return null;
  return m.shift ? { to, extend: true } : { to };
}

/** Type-ahead (APG listbox): letters typed within `gapMs` build one prefix; the first row at or after the current one that starts with it is chosen. */
export function typeAhead(labels: readonly string[], cur: number, buf: string, key: string, now: number, last: number, gapMs = 700): { buf: string; hit: number } {
  if (!isCharShortcut(key, {}) || labels.length === 0) return { buf, hit: -1 };
  const b = (now - last > gapMs ? "" : buf) + key.toLowerCase();
  const order = [...labels.keys()].map((i) => (i + cur + (b.length === 1 ? 1 : 0)) % labels.length);
  const hit = order.find((i) => labels[i].toLowerCase().startsWith(b)) ?? -1;
  return { buf: b, hit };
}

/** Rows of the "?" help sheet. `where` = the screen the key works on; the sheet shows only the rows of the current screen. */
export type HelpRow = { keys: string; does: string; where: "list" | "mail" | "page" | "compose" };
export const HELP_ROWS: readonly HelpRow[] = [
  { keys: "j / k  or  Down / Up", does: "Next / previous mail", where: "list" },
  { keys: "Home / End", does: "First / last mail", where: "list" },
  { keys: "Shift + Down / Up", does: "Extend the selection", where: "list" },
  { keys: "Enter", does: "Open the mail", where: "list" },
  { keys: "c", does: "Write a new mail", where: "list" },
  { keys: "/", does: "Search the loaded mails", where: "list" },
  { keys: "g then i s d a q v t p", does: "Go to Inbox, Sent, Drafts, Archive, Quarantine, Vault, Trash, Spam", where: "list" },
  { keys: "r  a  f", does: "Reply, reply all, forward", where: "mail" },
  { keys: "e  #", does: "Archive, move to Trash", where: "mail" },
  { keys: "s  u", does: "Star, mark unread", where: "mail" },
  { keys: "Esc", does: "Close the mail", where: "mail" },
  { keys: "Ctrl K", does: "Search pages", where: "page" },
  { keys: "Ctrl Enter", does: "Send (inside Compose)", where: "compose" },
  { keys: "?", does: "This help", where: "page" },
];
export const helpFor = (scene: "list" | "mail" | "compose"): HelpRow[] => HELP_ROWS.filter((r) => r.where === scene || r.where === "page" || (scene === "mail" && r.where === "list"));
