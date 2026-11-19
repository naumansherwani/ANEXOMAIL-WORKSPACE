// QC1e (19 Nov 2026): the pure side of the emoji picker. No DOM, no React: bun-tested (emoji_pure.test.ts).
// Data = emojibase-data (Unicode 17), bundled locally and loaded lazily; no network, no vendor.
export type Emoji = { hexcode: string; label: string; unicode: string; group?: number; order?: number; tags?: string[]; skins?: { unicode: string; hexcode: string; label: string }[] };
export type Group = { key: string; message: string; order: number };
export const MAX_RECENT = 32, RECENT_KEY = "fw.emoji.recent", TONE_KEY = "fw.emoji.tone";
export const TONES = ["", "light", "medium-light", "medium", "medium-dark", "dark"] as const;
export type Tone = (typeof TONES)[number];

/** Lower-case, accents folded. */
export function fold(s: string): string { return s.normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase().trim(); }

/** Emoji of one group, in the Unicode order. The "component" group (skin tone swatches, hair pieces) is not a thing to type, so it is left out. */
export function inGroup(all: Emoji[], group: number, groups: Group[]): Emoji[] {
  const g = groups.find((x) => x.order === group); if (!g || g.key === "component") return [];
  return all.filter((e) => e.group === group).sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
}

/** The emoji to show for a tone: the skin variant when the emoji has one, else the plain one. */
export function withTone(e: Emoji, tone: Tone): { unicode: string; label: string } {
  if (!tone || !e.skins?.length) return { unicode: e.unicode, label: e.label };
  const k = TONES.indexOf(tone); // 1..5 -> skins[0..4] (single tone variants come first)
  const s = e.skins[k - 1]; return s ? { unicode: s.unicode, label: s.label } : { unicode: e.unicode, label: e.label };
}

/** Search: every word typed must be found at the start of a word of the label or of a tag. Empty = nothing (the caller shows a group). At most `max` rows, best first (label hit before tag hit). */
export function search(all: Emoji[], groups: Group[], q: string, max = 120): Emoji[] {
  const words = fold(q).split(/\s+/).filter(Boolean); if (!words.length) return [];
  const comp = new Set(groups.filter((g) => g.key === "component").map((g) => g.order));
  const hit = (text: string, w: string) => text.split(/[^a-z0-9]+/).some((t) => t.startsWith(w));
  const scored: { e: Emoji; s: number }[] = [];
  for (const e of all) {
    if (e.group !== undefined && comp.has(e.group)) continue;
    const l = fold(e.label), tags = (e.tags ?? []).map(fold);
    let s = 0, ok = true;
    for (const w of words) { if (hit(l, w)) s += 2; else if (tags.some((t) => hit(t, w))) s += 1; else { ok = false; break; } }
    if (ok) scored.push({ e, s });
  }
  return scored.sort((a, b) => b.s - a.s || (a.e.order ?? 0) - (b.e.order ?? 0)).slice(0, max).map((x) => x.e);
}

/** New recent list: the used one first, no duplicates, at most MAX_RECENT. */
export function pushRecent(list: string[], hexcode: string): string[] { return [hexcode, ...list.filter((h) => h !== hexcode)].slice(0, MAX_RECENT); }

/** Insert at the caret (or replace the selection). Returns the new text and the caret after the emoji. */
export function insertAt(text: string, start: number, end: number, emoji: string): { text: string; caret: number } {
  const a = Math.max(0, Math.min(start, text.length)), b = Math.max(a, Math.min(end, text.length));
  return { text: text.slice(0, a) + emoji + text.slice(b), caret: a + emoji.length };
}
export function loadList(raw: string | null): string[] { try { const v = JSON.parse(raw ?? "[]"); return Array.isArray(v) ? v.filter((x) => typeof x === "string").slice(0, MAX_RECENT) : []; } catch { return []; } }
export function loadTone(raw: string | null): Tone { const r = raw ?? ""; return (TONES as readonly string[]).includes(r) ? (r as Tone) : ""; }

// ---- QC1e-D1: NEW-EMOJI SAFETY (Anexomail only). An emoji from a Unicode release newer than the common phone shows as an empty box on older phones. Before Send the writer is told, and one tap swaps it for its name in words.
// Data: emojibase-data/versions/emoji.json maps a release number to the hexcodes introduced in it (skin-tone and ZWJ variants included).
export const BASELINE = 15.1;     // releases up to Emoji 15.1 (Sep 2023) are on nearly every phone still in use; 16.0 and 17.0 may be boxes on older ones. One number to tune.
export type Flag = { emoji: string; name: string; version: number };
export function versionMap(v: Record<string, string[]>): Map<string, number> {
  const m = new Map<string, number>();
  for (const [k, list] of Object.entries(v)) { const n = Number(k); if (!Number.isFinite(n) || !Array.isArray(list)) continue; for (const h of list) if (typeof h === "string") m.set(h, n); }
  return m;
}
export function hexOf(g: string): string { return Array.from(g, (c) => (c.codePointAt(0) ?? 0).toString(16).toUpperCase().padStart(4, "0")).join("-"); }
/** The release of one emoji: exact hexcode, else without the skin tone, else without the emoji-style selector. Unknown = undefined (never flagged: we only warn when we KNOW). */
export function versionOf(hex: string, vm: Map<string, number>): number | undefined {
  const a = vm.get(hex); if (a !== undefined) return a;
  const noSkin = hex.replace(/-1F3F[B-F]/g, ""); const b = vm.get(noSkin); if (b !== undefined) return b;
  const noVs = noSkin.replace(/-FE0F/g, ""); return vm.get(noVs) ?? vm.get(noVs + "-FE0F");
}
export function graphemes(text: string): string[] {
  const Seg = (Intl as unknown as { Segmenter?: new (l?: string, o?: { granularity: string }) => { segment(s: string): Iterable<{ segment: string }> } }).Segmenter;
  return Seg ? Array.from(new Seg(undefined, { granularity: "grapheme" }).segment(text), (s) => s.segment) : Array.from(text);
}
const PICT = /\p{Extended_Pictographic}|\p{Regional_Indicator}/u;
export const hasEmoji = (text: string) => PICT.test(text);
/** unicode string -> name, for the emoji and their skin variants. */
export function nameIndex(all: Emoji[]): Map<string, string> {
  const m = new Map<string, string>();
  for (const e of all) { m.set(e.unicode, e.label); for (const s of e.skins ?? []) m.set(s.unicode, s.label); }
  return m;
}
/** The distinct emoji in `text` that appeared AFTER the baseline release. Order of first use. */
export function newerEmoji(text: string, vm: Map<string, number>, names: Map<string, string>, base = BASELINE): Flag[] {
  const seen = new Set<string>(), out: Flag[] = [];
  for (const g of graphemes(text)) {
    if (seen.has(g) || !PICT.test(g)) continue; seen.add(g);
    const v = versionOf(hexOf(g), vm); if (v === undefined || v <= base) continue;
    out.push({ emoji: g, name: names.get(g) ?? names.get(g.replace(/️/g, "")) ?? "new emoji", version: v });
  }
  return out;
}
/** Every flagged emoji becomes its name in square brackets, so the reader still gets the meaning. */
export function inWords(text: string, flags: Flag[]): string {
  let t = text; for (const f of flags) t = t.split(f.emoji).join(`[${f.name}]`); return t;
}

// ---- QC1e-D2: ":" SHORTCODE. Typing ":smi" at the caret offers matching emoji; Enter/Tab puts one in place of the typed ":smi". Pure part only (the popup is EmojiShortcode.tsx).
/** The ":name" being typed right at the caret: the colon must be at the start of the text or after a space/newline/opening bracket (so "12:30" and "https://x" are never touched), then 2..24 name characters (letters, digits, _ - +). */
export function shortcodeAt(text: string, caret: number): { start: number; query: string } | null {
  const c = Math.max(0, Math.min(caret, text.length)), head = text.slice(0, c);
  const m = /(^|[\s([{])(:)([A-Za-z0-9_+-]{2,24})$/.exec(head); if (!m) return null;
  return { start: c - m[3].length - 1, query: m[3] };
}
/** Emoji for a typed shortcode name: "_" and "-" count as spaces ("thumbs_up" = "thumbs up"). */
export function shortcodeSearch(all: Emoji[], groups: Group[], query: string, max = 8): Emoji[] { return search(all, groups, query.replace(/[_-]+/g, " "), max); }
/** Replace the typed ":name" (start..caret) by the emoji. Returns the new text and the caret after it. */
export function acceptShortcode(text: string, start: number, caret: number, emoji: string): { text: string; caret: number } { return insertAt(text, start, caret, emoji); }
/** Recently used first (in the order they were used), then the rest in the order search gave them. */
export function rankRecent(list: Emoji[], recent: string[]): Emoji[] {
  const r = new Map(recent.map((h, i) => [h, i] as const));
  return list.map((e, i) => ({ e, i, r: r.get(e.hexcode) })).sort((a, b) => (a.r === undefined ? 1e9 : a.r) - (b.r === undefined ? 1e9 : b.r) || a.i - b.i).map((x) => x.e);
}
