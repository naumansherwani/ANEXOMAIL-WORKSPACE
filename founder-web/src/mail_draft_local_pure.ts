// QC7b: pure helpers for the browser-sealed draft copy (no DOM, no network, no kernel; tested in mail_draft_local_pure.test.ts).
export type DraftBody = { to: string[]; cc: string[]; bcc: string[]; subject: string; text: string; html?: string; in_reply_to?: string; reply_to?: string };
export type LocalRec = { box: string; slot: string; key_id: string; wrap: string; nonce: string; sealed: string; saved_ms: number; server_id?: string; synced: boolean };
/** The AAD: the sealed copy is bound to the mailbox and the slot, so it cannot be moved to another draft. */
export const draftAad = (box: string, slot: string): string[] => ["fmail-draft-local-v1", box.toLowerCase(), slot];
/** One slot per draft: the server draft id when it has one, else "new". */
export const slotOf = (serverId?: string | null): string => (serverId && /^[0-9a-f-]{36}$/i.test(serverId) ? serverId.toLowerCase() : "new");
export const encodeDraft = (d: DraftBody): Uint8Array => new TextEncoder().encode(JSON.stringify(d));
export function decodeDraft(b: Uint8Array): DraftBody | null {
  try {
    const o = JSON.parse(new TextDecoder().decode(b)); const arr = (x: unknown) => Array.isArray(x) && x.every((y) => typeof y === "string");
    if (!o || !arr(o.to) || !arr(o.cc) || !arr(o.bcc) || typeof o.subject !== "string" || typeof o.text !== "string") return null;
    return { to: o.to, cc: o.cc, bcc: o.bcc, subject: o.subject, text: o.text, ...(typeof o.html === "string" ? { html: o.html } : {}), ...(typeof o.in_reply_to === "string" ? { in_reply_to: o.in_reply_to } : {}), ...(typeof o.reply_to === "string" ? { reply_to: o.reply_to } : {}) };
  } catch { return null; }
}
/** The newest copy the server never accepted (the offline case); null when everything reached the server. */
export const pendingOf = (recs: LocalRec[], box: string): LocalRec | null => recs.filter((r) => r.box === box.toLowerCase() && !r.synced).sort((a, b) => b.saved_ms - a.saved_ms)[0] ?? null;
/** Words for the restore bar. */
export function restoreLine(r: LocalRec, now: number): string {
  const m = Math.max(0, Math.round((now - r.saved_ms) / 60_000));
  return m < 1 ? "A draft sealed on this device a moment ago never reached the server." : m < 60 ? `A draft sealed on this device ${m} min ago never reached the server.` : `A draft sealed on this device ${Math.round(m / 60)} h ago never reached the server.`;
}
