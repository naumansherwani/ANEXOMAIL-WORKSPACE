// QC4 pure module: inline reply, reply all, forward, quote folding, reply-to-selection, References chain. No DOM, no network, no clock (callers pass dates).
// Rules: never "Re: Re:" / "Fwd: Fwd:"; my own addresses never get my own reply; the quoted tail folds, it is never deleted; the server (not the browser) is the source of truth for References.

/** "Name <a@b.com>" or "a@b.com" -> "a@b.com" (lower case), "" when no address. */
export function addrKey(s: string): string {
  const m = /<([^<>\s]+@[^<>\s]+)>/.exec(s) ?? /([^\s<>,;"']+@[^\s<>,;"']+)/.exec(s);
  return m ? m[1].trim().toLowerCase() : "";
}
const uniq = (list: string[], skip: Set<string>): string[] => {
  const seen = new Set(skip); const out: string[] = [];
  for (const a of list) { const k = addrKey(a); if (!k || seen.has(k)) continue; seen.add(k); out.push(a.trim()); }
  return out;
};
export type ReplyAllIn = { from: string[] | string; to: string[]; cc: string[]; replyTo?: string[]; me: string[] };
/** Reply: only the sender (or Reply-To). Reply all: sender/Reply-To + To in "to", Cc in "cc"; me removed, duplicates removed (case-insensitive, name or no name). */
export function replyTargets(i: ReplyAllIn, all: boolean): { to: string[]; cc: string[] } {
  const me = new Set(i.me.map(addrKey).filter(Boolean));
  const first = (i.replyTo && i.replyTo.length ? i.replyTo : ([] as string[]).concat(i.from));
  const to = uniq(all ? [...first, ...i.to] : first, me);
  const cc = all ? uniq(i.cc, new Set([...me, ...to.map(addrKey)])) : [];
  // a mail I sent myself: replying must still reach someone, so fall back to the original To
  if (!to.length) { const alt = uniq(i.to, me); return { to: alt.length ? alt : uniq(first, new Set()), cc }; }
  return { to, cc };
}
/** "Re: " once, "Fwd: " once (also Fw:, Re[2]:, RE : are recognised). */
const PFX = /^\s*((re|fwd?)(\[\d+\])?\s*:\s*)+/i;
export const bareSubject = (s: string): string => s.replace(PFX, "").trim();
export const replySubject = (s: string): string => `Re: ${bareSubject(s)}`.trimEnd();
export const forwardSubject = (s: string): string => `Fwd: ${bareSubject(s)}`.trimEnd();

/** "On <date>, <who> wrote:" */
export const attribution = (who: string, date: string): string => `On ${date}, ${who} wrote:`;
const quoteLines = (t: string): string => t.replace(/\s+$/, "").split(/\r?\n/).map((l) => (l.startsWith(">") ? `>${l}` : `> ${l}`.trimEnd())).join("\n");
/** The text the reply starts with. A selection (when the reader selected something) replaces the whole mail: only that part is quoted. */
export function replyBody(o: { who: string; date: string; text: string; selection?: string }): string {
  const sel = (o.selection ?? "").trim();
  const src = sel.length > 0 ? sel : o.text;
  return `\n\n${attribution(o.who, o.date)}\n${quoteLines(src)}`;
}
/** Forward inline block, Gmail style. */
export function forwardBody(o: { from: string; date: string; subject: string; to: string[]; cc?: string[]; text: string }): string {
  const h = [`From: ${o.from}`, `Date: ${o.date}`, `Subject: ${o.subject}`, `To: ${o.to.join(", ")}`, ...(o.cc && o.cc.length ? [`Cc: ${o.cc.join(", ")}`] : [])];
  return `\n\n---------- Forwarded message ----------\n${h.join("\n")}\n\n${o.text.replace(/\s+$/, "")}\n`;
}

/** Split a body into the new text and the quoted tail (folded behind "..." in the UI). null tail = nothing to fold. Never loses a character: fresh + tail === text. */
export function splitQuote(text: string): { fresh: string; tail: string | null } {
  const lines = text.split("\n"); let cut = -1;
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i];
    const attrib = /^\s*On .{3,200}wrote:\s*$/i.test(l) && /^\s*>/.test(lines[i + 1] ?? "");
    const wrapped = /^\s*On .{3,120}$/i.test(l) && /wrote:\s*$/i.test(lines[i + 1] ?? "") && /^\s*>/.test(lines[i + 2] ?? "");
    const outlook = /^\s*-{2,}\s*Original Message\s*-{2,}\s*$/i.test(l);
    const fwd = /^\s*-{5,}\s*Forwarded message\s*-{5,}\s*$/i.test(l);
    if (attrib || wrapped || outlook || fwd) { cut = i; break; }
  }
  if (cut < 0) { // a trailing block of ">" lines (at least 2) with nothing after it
    let j = lines.length; while (j > 0 && lines[j - 1].trim() === "") j--;
    let k = j; while (k > 0 && /^\s*>/.test(lines[k - 1])) k--;
    if (j - k >= 2) cut = k;
  }
  if (cut < 0) return { fresh: text, tail: null };
  const fresh = lines.slice(0, cut).join("\n"); const tail = lines.slice(cut).join("\n");
  return fresh.trim() === "" && cut === 0 ? { fresh: "", tail: text } : { fresh: fresh + "\n", tail };
}

/** RFC 5322 3.6.4: References = parent's References + parent's Message-ID. Trim to 20 ids: keep the first (thread root) and the newest 19. Ids without angle brackets, no empties, no repeats. */
export function referencesFor(parentRefs: string[], parentId: string): string[] {
  const clean = (x: string) => x.trim().replace(/^<|>$/g, "");
  const out: string[] = [];
  for (const r of [...parentRefs, parentId].map(clean)) if (r && !out.includes(r)) out.push(r);
  return out.length <= 20 ? out : [out[0], ...out.slice(out.length - 19)];
}
/** Can the "Reply all" button be useful? (more than one other person) */
export const hasOthers = (i: ReplyAllIn): boolean => { const t = replyTargets(i, true); return t.to.length + t.cc.length > 1; };
