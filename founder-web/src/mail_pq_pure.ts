// DK4 (20 Nov 2026): the PURE part of opening a post-quantum sealed mail in the browser: the byte plumbing between the server's answer and the kernel's kemopen@1 input. No network, no DOM.
// AAD fields are the SAME as the server's fmail_core::part_aad: ["fmail-msg-v1", mailbox, direction, msgid_blind_hex, part]; the key wrap is bound to its key id inside the kernel.
export const AAD_TAG = "fmail-msg-v1";
export type SealedMail = { key_id: string; key_wrap: string; msgid_blind: string; direction: string; meta: string; nonce_meta: string; body?: string | null; nonce_body?: string | null };
const hexOf = (b: Uint8Array) => [...b].map((v) => v.toString(16).padStart(2, "0")).join("");
export function b64ToHex(s: unknown): string | null {
  if (typeof s !== "string" || s.length === 0 || s.length > 40_000_000) return null;
  try { const bin = atob(s.replace(/-/g, "+").replace(/_/g, "/")); const u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); return hexOf(u); } catch { return null; }
}
export const partAad = (box: string, direction: string, msgid: string, part: "meta" | "body") => [AAD_TAG, box, direction, msgid, part];
/** The kemOpen inputs (without the private halves) for the meta part and, when present, the body part. null = the server's answer is malformed (never guess). */
export function kemInputs(box: string, m: SealedMail): { meta: Record<string, unknown>; body: Record<string, unknown> | null } | null {
  const wrap = b64ToHex(m.key_wrap), meta = b64ToHex(m.meta), nm = b64ToHex(m.nonce_meta);
  if (!wrap || !meta || !nm || !m.key_id || !/^[0-9a-f]+$/i.test(m.msgid_blind ?? "") || (m.direction !== "in" && m.direction !== "out")) return null;
  const base = { key_id: m.key_id, wrap };
  let body: Record<string, unknown> | null = null;
  if (m.body && m.nonce_body) { const b = b64ToHex(m.body), nb = b64ToHex(m.nonce_body); if (!b || !nb) return null; body = { ...base, nonce: nb, aad: partAad(box, m.direction, m.msgid_blind, "body"), sealed: b }; }
  return { meta: { ...base, nonce: nm, aad: partAad(box, m.direction, m.msgid_blind, "meta"), sealed: meta }, body };
}
/** Reply / Reply all / Forward headers from a parsed pq mail (DK1 gives References and Reply-To): Reply goes to Reply-To when it exists, else From. */
export function replyPlan(s: { from: string; to: string[]; cc: string[]; message_id: string; references: string[]; reply_to: string[]; subject: string }, me: string) {
  const re = (x: string) => (/^re:/i.test(x.trim()) ? x.trim() : `Re: ${x.trim()}`), fw = (x: string) => (/^fwd?:/i.test(x.trim()) ? x.trim() : `Fwd: ${x.trim()}`);
  const refs = [...s.references, s.message_id].filter(Boolean).slice(-40);
  const dedupe = (a: string[]) => [...new Set(a.map((x) => x.toLowerCase()))].filter((x) => x && x !== me.toLowerCase());
  return {
    reply: { to: dedupe(s.reply_to.length ? s.reply_to : [s.from]), cc: [] as string[], subject: re(s.subject), in_reply_to: s.message_id, references: refs },
    replyAll: { to: dedupe(s.reply_to.length ? s.reply_to : [s.from]), cc: dedupe([...s.to, ...s.cc]).filter((x) => !(s.reply_to.length ? s.reply_to : [s.from]).map((y) => y.toLowerCase()).includes(x)), subject: re(s.subject), in_reply_to: s.message_id, references: refs },
    forward: { to: [] as string[], cc: [] as string[], subject: fw(s.subject), in_reply_to: "", references: refs },
  };
}
