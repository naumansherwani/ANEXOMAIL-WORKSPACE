// QC1e D4A (20 Nov 2026, AWAM ONLY): the company emoji pack, pure logic (unit-tested). Mirrors the SQL (E193) and the Rust core (emoji_core.rs):
// same shortcode rule, same reserved list, same ":code:" token rule, so the browser, the Rust door and the database can never disagree.
// Plan: docs/claude/QC1E-D4-PLAN-20NOV.md. No network, no React here.
import type { Emoji } from "./emoji_pure";

export type CompanyItem = { shortcode: string; alt: string; sha256: string; bytes: number; w: number; h: number; created_at?: string };
export type Quota = { plan: string | null; limit: number; used: number; left: number; enabled: boolean };
export const NO_QUOTA: Quota = { plan: null, limit: 0, used: 0, left: 0, enabled: false };
export const CO_PREFIX = "co:"; // hexcode prefix of a company item inside the picker / ":" list (never collides with Unicode hexcodes)
export const MAX_FILE = 512 * 1024;
export const RESERVED = ["official", "admin", "administrator", "support", "system", "security", "billing", "staff", "moderator", "mod", "anexo", "anexomail", "anexochat", "anexosuite", "founder", "owner", "root", "null", "undefined", "everyone", "here", "channel"];
const SHAPE = /^[a-z0-9][a-z0-9_-]{0,22}[a-z0-9]$/;

export function cleanCode(raw: string): { ok: true; code: string } | { ok: false; reason: string } {
  const c = raw.trim().toLowerCase().replace(/^:+|:+$/g, "");
  if (!SHAPE.test(c)) return { ok: false, reason: "2-24 letters, digits, _ or -, starting and ending with a letter or digit" };
  if (RESERVED.includes(c)) return { ok: false, reason: "this name is reserved (official, admin, support ...)" };
  return { ok: true, code: c };
}

/** The text that goes into the message: ":acme:" plus one space (the mail itself carries the text until D4B turns it into an inline image). */
export const tokenOf = (code: string): string => `:${code}: `;

/** Same rule as Rust `tokens`: ":code:" not touching a letter/digit before it, shape ok, at least one letter (12:30:45 is a time), deduped. */
export function tokens(text: string): string[] {
  const out: string[] = [];
  for (let i = 0; i < text.length; i++) {
    if (text[i] !== ":" || (i > 0 && /[A-Za-z0-9]/.test(text[i - 1]!))) continue;
    let j = i + 1;
    while (j < text.length && j - i - 1 <= 24 && /[a-z0-9_-]/.test(text[j]!)) j++;
    if (j < text.length && text[j] === ":") {
      const c = text.slice(i + 1, j);
      if (SHAPE.test(c) && /[a-z]/.test(c) && !out.includes(c)) out.push(c);
      i = j - 1;
    }
  }
  return out;
}

/** The pack item as a pseudo-Emoji so the picker grid and the ":" list can treat it like any other row (withTone / keyboard / counts). */
export function asEmoji(c: CompanyItem): Emoji {
  return { hexcode: CO_PREFIX + c.shortcode, label: c.alt ? `${c.shortcode} (${c.alt})` : `${c.shortcode} (company)`, unicode: tokenOf(c.shortcode), tags: [] };
}
export const isCompany = (e: { hexcode: string }): boolean => e.hexcode.startsWith(CO_PREFIX);
export const codeOf = (e: { hexcode: string }): string => e.hexcode.slice(CO_PREFIX.length);

const fold = (s: string): string => s.normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase();

/** Rank: exact code 5, code prefix 4, code word prefix 3 (acme-logo -> "logo"), alt word prefix 2, code/alt contains 1. Empty query = everything A-Z (the "Company" tab). */
export function matchPack(items: CompanyItem[], query: string, max = 200): CompanyItem[] {
  const q = fold(query.trim().replace(/^:+/, ""));
  if (!q) return [...items].sort((a, b) => a.shortcode.localeCompare(b.shortcode)).slice(0, max);
  const scored: { c: CompanyItem; s: number }[] = [];
  for (const c of items) {
    const code = c.shortcode, alt = fold(c.alt);
    let s = 0;
    if (code === q) s = 5;
    else if (code.startsWith(q)) s = 4;
    else if (code.split(/[-_]/).some((w) => w.startsWith(q))) s = 3;
    else if (alt.split(/\s+/).some((w) => w.startsWith(q))) s = 2;
    else if (code.includes(q) || alt.includes(q)) s = 1;
    if (s) scored.push({ c, s });
  }
  return scored.sort((a, b) => b.s - a.s || a.c.shortcode.localeCompare(b.c.shortcode)).slice(0, max).map((x) => x.c);
}

export const quotaTone = (q: Quota): "off" | "ok" | "near" | "full" => (!q.enabled ? "off" : q.left <= 0 ? "full" : q.used / Math.max(1, q.limit) >= 0.9 ? "near" : "ok");
export const quotaLabel = (q: Quota): string => (q.enabled ? `${q.used} of ${q.limit} used` : "Not in your plan");

/** Client-side pre-check (the Rust door checks again, nothing here is trusted): PNG or WebP, at most 512 KB. */
export function fileProblem(f: { name: string; size: number; type: string }): string | null {
  if (!/^image\/(png|webp)$/.test(f.type) && !/\.(png|webp)$/i.test(f.name)) return "Use a PNG or WebP picture (no SVG, no animation).";
  if (f.size > MAX_FILE) return "The picture is too big (max 512 KB).";
  if (f.size < 100) return "The picture is empty.";
  return null;
}

/** Suggest a shortcode from a file name: "Acme Logo (1).png" -> "acme-logo-1". */
export function codeFromFile(name: string): string {
  const base = name.replace(/\.[a-z0-9]+$/i, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 24).replace(/-+$/g, "");
  const r = cleanCode(base);
  return r.ok ? r.code : "";
}
