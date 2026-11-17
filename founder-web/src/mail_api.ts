// Q1c: the Mail page's only network door. GET answers are signature-checked by api.get (WASM kernel); the live stream frames are verified by the kernel too and dropped if they fail.
import { get, post } from "./api";
import { rpcAvailable, mailLedgerCheck, anchorCheck, type AnchorReport } from "./kernel";
import { prove } from "./passkey";
import type { Box, Counts, Lane, Proof, Row, Sum } from "./mail_pure";

const q = (o: Record<string, string | number | undefined | null>) => Object.entries(o).filter(([, v]) => v !== undefined && v !== null && v !== "").map(([k, v]) => `${k}=${encodeURIComponent(String(v))}`).join("&");
export type Facts = Row & { key_id?: string };
export type Opened = { opened: true; touched: boolean; facts: Facts; sum: Sum; view: { text: string; had_html: boolean; remote_content_blocked: boolean; attachments: { name: string; type: string; size: number }[] } };
export type OpenAnswer = Opened | { needs_touch: true; action: string; target: string } | { broken: true; reason: string } | { sealed_for_kernel: true; mail: any } | { error: string };

export async function boxes(): Promise<{ connected: boolean; boxes: Box[]; vault_ready?: boolean }> { return (await get("/founder/v1/mail/boxes")).data; }
export async function counts(box: string): Promise<Counts | null> { const d = (await get(`/founder/v1/mail/counts?${q({ box })}`)).data; return d?.connected ? d.counts : null; }
export async function list(box: string, view: string, after?: { ts: string; id: string }): Promise<{ rows: Row[]; more: boolean; next: { ts: string; id: string } | null } | null> {
  const d = (await get(`/founder/v1/mail/list?${q({ box, view, ts: after?.ts, id: after?.id, limit: 50 })}`)).data; return d?.connected ? d.list : null;
}
export async function lanes(): Promise<{ lanes: Lane[]; unread: number; ledger_head: number; mailboxes_without_key: number } | null> { const d = (await get("/founder/v1/mail/lanes")).data; return d?.connected ? d.feed : null; }
export async function proof(box: string, id?: string): Promise<Proof | null> { const d = (await get(`/founder/v1/mail/proof?${q({ box, id })}`)).data; return d?.connected ? d.proof : null; }
/** QUI-H3: one page of raw ledger rows (E172 door, signed answer). */
export async function ledgerRows(after: number, limit = 500): Promise<any | null> { const d = (await get(`/founder/v1/mail/ledger-rows?after=${after}&limit=${limit}`)).data; return d?.connected ? d.ledger : null; }
/** QUI-H3: the browser KERNEL re-hashes the whole mail ledger chain page by page (mailledger@1) and checks it ends at the head the server claims.
 *  Returns the kernel report, or null when the kernel/door is unavailable (the chip then says "verified by the server", never "in your browser"). */
export async function verifyLedgerInKernel(claimHeadSeq?: number | null, claimHeadHash?: string | null): Promise<{ ok: boolean; checked: number; head_seq: number | null; problem?: string } | null> {
  try {
    let after = 0, afterHash: string | undefined, checked = 0, last: number | null = null;
    for (let page = 0; page < 10000; page++) {
      const door = await ledgerRows(after, 500); if (!door) return null;
      const last_page = !door.more;
      const r = await mailLedgerCheck({ ...door, after_seq: after, after_hash: afterHash, ...(last_page && claimHeadSeq != null ? { claim_head_seq: claimHeadSeq, claim_head_hash: claimHeadHash ?? undefined } : {}) });
      if (!r) return null; if (!r.ok) return { ok: false, checked, head_seq: last, problem: (r as any).problem };
      checked += r.checked ?? 0; last = r.last_seq ?? last; afterHash = r.head_hash; after = r.last_seq ?? after;
      if (last_page) return { ok: true, checked, head_seq: last };
    }
    return null;
  } catch { return null; }
}
/** QUI-H4: fetch the anchor proof door for ONE mail and let the browser KERNEL prove it is inside the audit Merkle tree. null = not available (never a fake tick). */
export async function verifyAnchorInKernel(box: string, id: string): Promise<{ state: "proven" | "pending" | "failed"; text: string; report?: AnchorReport } | null> {
  try {
    const d = (await get(`/founder/v1/mail/anchor-proof?${q({ box, id })}`)).data; if (!d?.connected) return null;
    const door = d.anchor; if (!door || door.found === false) return null;
    if (door.anchored === false) return { state: "pending", text: door.reason ?? "not anchored yet" };
    const r = await anchorCheck(door); if (!r) return null;
    return r.ok ? { state: "proven", text: `inside the audit Merkle tree (checkpoint #${r.checkpoint_seq}, ${r.ledger_rows} ledger rows, ${r.hops} hops), checked in your browser`, report: r } : { state: "failed", text: r.problem ?? "the proof failed", report: r };
  } catch { return null; }
}
/** QPERF-3: the mail speed numbers (E174) + the meter's own loss counters. Signed answer; null when the door is not answering (the card then hides itself). */
export async function perf(window: string): Promise<{ perf: import("./mail_pure").PerfDoor; meter: import("./mail_pure").PerfMeter } | null> {
  try { const d = (await get(`/founder/v1/mail/perf?${q({ window })}`)).data; return d?.connected && d.perf?.stages ? { perf: d.perf, meter: d.meter } : null; } catch { return null; }
}
export async function dbscBound(): Promise<boolean | null> {
  try { const s = (await get("/founder/v1/dbsc/status")).data; if (!s?.available) return null; return !!(s.devices ?? []).find((x: any) => x.id === s.this_device)?.bound; } catch { return null; }
}
/** nextHopProtocol of THIS page load ("h3" = QUIC). Empty string if the browser does not say. */
export function pageProtocol(): string {
  try {
    const nav = (performance.getEntriesByType("navigation")[0] as PerformanceNavigationTiming | undefined)?.nextHopProtocol; if (nav) return nav;
    // the page entry can be blank (cached or restored page): the newest same-origin request says what this connection speaks
    const res = (performance.getEntriesByType("resource") as PerformanceResourceTiming[]).filter((r) => r.nextHopProtocol && r.name.startsWith(location.origin));
    return res.length ? res[res.length - 1].nextHopProtocol : "";
  } catch { return ""; }
}

/** The channel that REALLY carries the mail calls: the kernel's WebTransport (QUIC) session when it is up ("wt"), else what this page load speaks. */
export function mailTransport(): string { try { if (rpcAvailable()) return "wt"; } catch { /* kernel not loaded */ } return pageProtocol(); }

/** Open a message. A gated one answers needs_touch; then the key is touched (prove) and the call is repeated with the spent grant. Nothing is retried without the person touching. */
export async function open(box: string, id: string): Promise<{ r: OpenAnswer; touched: boolean }> {
  let r = await post("/founder/v1/mail/open", { box, id });
  if (r.status !== 200) return { r: { error: r.body?.error || `HTTP ${r.status}` }, touched: false };
  if (r.body?.needs_touch) {
    const p = await prove({ action: r.body.action, target: r.body.target });
    if (!p.ok) return { r: { error: p.error }, touched: false };
    r = await post("/founder/v1/mail/open", { box, id, grant: p.result?.grant, nonce: p.nonce });
    if (r.status !== 200) return { r: { error: r.body?.error || `HTTP ${r.status}` }, touched: false };
  }
  return { r: r.body as OpenAnswer, touched: !!r.body?.touched };
}
export const flag = (box: string, ids: string[], f: { read?: boolean; starred?: boolean }) => post("/founder/v1/mail/flag", { box, ids, ...f });
export async function move(box: string, ids: string[], to: string): Promise<{ ok: boolean; error?: string }> {
  let r = await post("/founder/v1/mail/move", { box, ids, to });
  if (r.status === 200 && r.body?.needs_touch) {
    const p = await prove({ action: r.body.action, target: r.body.target });
    if (!p.ok) return { ok: false, error: p.error };
    r = await post("/founder/v1/mail/move", { box, ids, to, grant: p.result?.grant, nonce: p.nonce });
  }
  return r.status === 200 && r.body?.ok ? { ok: true } : { ok: false, error: r.body?.error || `HTTP ${r.status}` };
}
export async function setVault(box: string, thread: string, vault: boolean): Promise<{ ok: boolean; error?: string }> {
  let r = await post("/founder/v1/mail/vault", { box, thread, vault });
  if (r.status === 200 && r.body?.needs_touch) {
    const p = await prove({ action: r.body.action, target: r.body.target });
    if (!p.ok) return { ok: false, error: p.error };
    r = await post("/founder/v1/mail/vault", { box, thread, vault, grant: p.result?.grant, nonce: p.nonce });
  }
  return r.status === 200 && r.body?.ok ? { ok: true } : { ok: false, error: r.body?.error || `HTTP ${r.status}` };
}

export type LiveMsg = { event: "snapshot" | "counts" | "arrival"; data: any };
/** The Mail live channel. KP3 step 4 (14 Nov 2026, his word: no SSE for the founder): there is NO Server-Sent-Events stream any more. Counts and lanes are two signed GETs over the kernel's WebTransport API session
 *  every 5 s while the tab is visible (each answer is signature-checked by the kernel inside api.get); an arrival = the inbox total grew. Phase Q3 replaces this with a pushed WebTransport stream. Returns stop(). */
export const MAIL_POLL_MS = 5000;
export function live(box: string, on: (m: LiveMsg) => void, state: (s: "live" | "reconnecting") => void): () => void {
  let stopped = false, lastInbox = -1, first = true, last = "", timer: ReturnType<typeof setTimeout> | null = null, fails = 0;
  const tick = async () => {
    if (stopped) return;
    if (!document.hidden) {
      try {
        const [c, l] = await Promise.all([counts(box), lanes()]); if (stopped) return;
        if (c && l) {
          fails = 0; state("live");
          const data = { counts: c, feed: l }, key = JSON.stringify(data), inbox = Number((c as { inbox?: { total?: number } }).inbox?.total ?? 0);
          if (key !== last) {
            on({ event: first ? "snapshot" : "counts", data });
            if (!first && lastInbox >= 0 && inbox > lastInbox) on({ event: "arrival", data: { inbox_total: inbox, new: inbox - lastInbox } });
            last = key; lastInbox = inbox; first = false;
          }
        } else { fails += 1; state("reconnecting"); }
      } catch { fails += 1; state("reconnecting"); }
    }
    if (!stopped) timer = setTimeout(() => void tick(), fails ? Math.min(MAIL_POLL_MS * 2 ** Math.min(fails, 3), 30_000) : MAIL_POLL_MS);
  };
  void tick();
  return () => { stopped = true; if (timer) clearTimeout(timer); };
}

// ================================================================== Q1d: compose, send, undo, drafts, DKIM (every call goes through the same kernel doors as the rest)
import { sendTarget, type Compose } from "./mail_pure";

export type Queued = { outbox_id: string; message_id: string; state: "queued" | "scheduled"; not_before: string; undo_until: string };
export type SendResult = { ok: true; queued: Queued } | { ok: false; error: string; needsDkim?: boolean };
/** Send. The server answers needs_touch with the exact target; the browser computes the SAME target itself and refuses to touch for anything else (a hostile answer cannot make you approve another mail). */
export async function send(box: string, c: Compose, o: { schedule?: string; draft?: string } = {}): Promise<SendResult> {
  const body = { box, ...c, ...(o.schedule ? { schedule_at: o.schedule } : {}), ...(o.draft ? { draft: o.draft } : {}) };
  let r = await post("/founder/v1/mail/send", body);
  if (r.status === 200 && r.body?.needs_touch) {
    const mine = await sendTarget(box, c, o.schedule ?? "");
    if (r.body.action !== "mail.send" || r.body.target !== mine) return { ok: false, error: "The server asked for a touch on a different mail than the one on your screen. Nothing was sent." };
    const p = await prove({ action: "mail.send", target: mine });
    if (!p.ok) return { ok: false, error: p.error };
    r = await post("/founder/v1/mail/send", { ...body, grant: p.result?.grant, nonce: p.nonce });
  }
  if (r.status === 200 && r.body?.ok && r.body.queued) return { ok: true, queued: r.body.queued as Queued };
  return { ok: false, error: r.body?.error || `HTTP ${r.status}`, needsDkim: !!r.body?.needs_dkim };
}
export async function undo(box: string, outbox: string): Promise<{ ok: boolean; error?: string }> { const r = await post("/founder/v1/mail/undo", { box, outbox }); return r.status === 200 && r.body?.ok ? { ok: true } : { ok: false, error: r.body?.error || `HTTP ${r.status}` }; }
/** QC1b: the sealed address book, opened by the server (top 500 by frecency). Signed GET, kernel-verified. [] = nothing yet or the door is not answering (typing simply shows no suggestions). */
export async function contacts(box: string): Promise<import("./book").Contact[]> { const d = (await get(`/founder/v1/mail/contacts?${q({ box })}`)).data; return Array.isArray(d?.items) ? d.items.filter((c: any) => c && typeof c.addr === "string") : []; }
/** QC1b: forget (removed for good, a blind tombstone keeps mail that merely arrives from bringing them back), pin or unpin one contact. */
export async function contactAct(box: string, contact: string, op: "forget" | "pin" | "unpin"): Promise<{ ok: boolean; error?: string }> { const r = await post("/founder/v1/mail/contact", { box, contact, op }); return r.status === 200 && r.body?.ok ? { ok: true } : { ok: false, error: r.body?.error ?? "could not change this contact" }; }
/** QC3a: Send now. Skips the rest of the 30 s hold (signed door, E185). Idempotent: pressing twice answers ok both times. */
export async function release(box: string, outbox: string): Promise<{ ok: boolean; error?: string }> { const r = await post("/founder/v1/mail/release", { box, outbox }); return r.status === 200 && r.body?.ok ? { ok: true } : { ok: false, error: r.body?.error || `HTTP ${r.status}` }; }
export async function cancel(box: string, outbox: string): Promise<{ ok: boolean; error?: string }> { const r = await post("/founder/v1/mail/cancel", { box, outbox }); return r.status === 200 && r.body?.ok ? { ok: true } : { ok: false, error: r.body?.error || `HTTP ${r.status}` }; }
/** Q1b4: the evidence behind one mail's ring (inbound) or the sending facts (outbound). Signed GET, kernel-verified. null = door not answering. */
export async function authFacts(box: string, message: string): Promise<{ direction: "in" | "out"; evidence?: any; facts?: any } | null> { const d = (await get(`/founder/v1/mail/auth?${q({ box, message })}`)).data; return d?.connected ? d : null; }
export async function discard(box: string, message: string): Promise<{ ok: boolean; error?: string }> { const r = await post("/founder/v1/mail/discard", { box, message }); return r.status === 200 && r.body?.ok ? { ok: true } : { ok: false, error: r.body?.error || `HTTP ${r.status}` }; }
export type OutRow = { outbox_id: string; message_id: string; state: string; not_before: string; undo_until: string; rcpt: number; attempts: number; last_error: string | null; tls: string | null; dkim: boolean; finished_at: string | null };
export async function outbox(box: string): Promise<OutRow[] | null> { const r = (await get(`/founder/v1/mail/outbox?box=${encodeURIComponent(box)}`)).data; return r?.connected ? (r.outbox as OutRow[]) : null; }

export type DraftContent = Partial<Compose> & { to?: string[] };
export type DraftHead = { id: string; version: number; reply_to: string | null; updated_at: string };
export async function draftSave(box: string, c: Partial<Compose>, d: { draft?: string; expected: number; reply_to?: string }): Promise<{ ok: true; id: string; version: number } | { ok: false; stale: boolean; error: string }> {
  const r = await post("/founder/v1/mail/draft", { box, ...c, draft: d.draft, expected: d.expected, reply_to: d.reply_to });
  if (r.status === 200 && r.body?.ok) return { ok: true, id: r.body.draft.draft_id, version: r.body.draft.version };
  return { ok: false, stale: r.status === 409 || !!r.body?.stale, error: r.body?.error || `HTTP ${r.status}` };
}
export async function drafts(box: string): Promise<DraftHead[] | null> { const r = (await get(`/founder/v1/mail/drafts?box=${encodeURIComponent(box)}`)).data; return r?.connected ? (r.drafts as DraftHead[]) : null; }
export async function draftOpen(box: string, id: string): Promise<{ id: string; version: number; reply_to: string | null; content: DraftContent } | null> { const r = (await get(`/founder/v1/mail/drafts?box=${encodeURIComponent(box)}&id=${encodeURIComponent(id)}`)).data; return r?.draft ?? null; }
export async function draftDiscard(box: string, draft: string): Promise<boolean> { const r = await post("/founder/v1/mail/draft/discard", { box, draft }); return r.status === 200 && !!r.body?.ok; }

export type DkimRow = { id: string; selector: string; alg: string; dns_name: string; dns_type: string; dns_value: string; created_at: string };
export async function dkimKeys(box: string): Promise<DkimRow[] | null> { const r = (await get(`/founder/v1/mail/dkim?box=${encodeURIComponent(box)}`)).data; return r?.connected ? (r.keys as DkimRow[]) : null; }
/** Create a signing key (the key pair is made on the server; only the public half comes back as the DNS record). Needs a touch on this exact box + selector + algorithm. */
export async function dkimCreate(box: string, selector: string, alg: "ed25519-sha256" | "rsa-sha256"): Promise<{ ok: true; name: string; value: string } | { ok: false; error: string }> {
  const body = { box, selector, alg }; let r = await post("/founder/v1/mail/dkim", body);
  if (r.status === 200 && r.body?.needs_touch) {
    const want = `dkim:${box}:${selector}:${alg}`;
    if (r.body.action !== "mail.key" || r.body.target !== want) return { ok: false, error: "The server asked for a touch on something else. Nothing was created." };
    const p = await prove({ action: "mail.key", target: want }); if (!p.ok) return { ok: false, error: p.error };
    r = await post("/founder/v1/mail/dkim", { ...body, grant: p.result?.grant, nonce: p.nonce });
  }
  return r.status === 200 && r.body?.ok ? { ok: true, name: r.body.dns_name, value: r.body.dns_value } : { ok: false, error: r.body?.error || `HTTP ${r.status}` };
}

/** E182: the real ON/OFF switch for sending. null = door unavailable (E182 not run), never a guess. */
export type Sending = { send_enabled: boolean; undo_seconds: number; waiting: number; changed_at_ms: number | null };
export async function sendingState(): Promise<Sending | null> { const d = (await get("/founder/v1/mail/sending")).data; return d?.connected && d.sending ? d.sending as Sending : null; }
export async function sendingSet(on: boolean): Promise<{ ok: boolean; error?: string }> { const r = await post("/founder/v1/mail/sending", { on }); return r.status === 200 && r.body?.ok ? { ok: true } : { ok: false, error: r.body?.error || `HTTP ${r.status}` }; }

/** SYS-LIVE: the live pulse of the running Rust process (signed answer, verified by the kernel in api.get). null = door unavailable. */
export type Pulse = { seq: number; now_ms: number; started_ms: number; uptime_s: number; build: string; build_time: string; tokio: { workers: number; alive_tasks: number; queue_depth: number }; db_ms: number | null; sending: Sending | null };
export async function pulse(): Promise<Pulse | null> { const d = (await get("/founder/v1/system/pulse")).data; return d?.connected && typeof d.now_ms === "number" ? d as Pulse : null; }
