// Q1c: the Mail page's only network door. GET answers are signature-checked by api.get (WASM kernel); the live stream frames are verified by the kernel too and dropped if they fail.
import { get, post, openStream } from "./api";
import { rpcAvailable, verifyBody } from "./kernel";
import { prove } from "./passkey";
import { takeFrames } from "./sse";
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
/** The live channel (SSE fallback of the QUIC channel; same frames). Every frame is verified by the kernel first. Returns stop(). Reconnects with a short back-off. */
export function live(box: string, on: (m: LiveMsg) => void, state: (s: "live" | "reconnecting") => void): () => void {
  const ac = new AbortController(); let lastId = 0, wait = 1000;
  (async () => {
    while (!ac.signal.aborted) {
      try {
        const res = await openStream(`/founder/v1/mail/stream?${q({ box })}`, lastId, ac.signal); state("live"); wait = 1000;
        const rd = res.body!.getReader(), dec = new TextDecoder(); let buf = "";
        for (;;) {
          const { done, value } = await rd.read(); if (done) break;
          buf += dec.decode(value, { stream: true }); const t = takeFrames(buf); buf = t.rest;
          for (const f of t.frames) {
            if (f.kind !== "frame") continue;
            const v = await verifyBody(new TextEncoder().encode(f.data).buffer as ArrayBuffer, 120, true); if (!v.ok) continue;
            if (f.id) lastId = Number(f.id) || lastId;
            try { on({ event: f.event as LiveMsg["event"], data: JSON.parse(v.data) }); } catch { /* a frame that is not JSON is dropped */ }
          }
        }
      } catch { /* network or sign-in trouble: back off below */ }
      if (ac.signal.aborted) return; state("reconnecting");
      await new Promise((r) => setTimeout(r, wait)); wait = Math.min(wait * 2, 15000);
    }
  })();
  return () => ac.abort();
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
export async function cancel(box: string, outbox: string): Promise<{ ok: boolean; error?: string }> { const r = await post("/founder/v1/mail/cancel", { box, outbox }); return r.status === 200 && r.body?.ok ? { ok: true } : { ok: false, error: r.body?.error || `HTTP ${r.status}` }; }
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
