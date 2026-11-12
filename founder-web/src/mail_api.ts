// Q1c: the Mail page's only network door. GET answers are signature-checked by api.get (WASM kernel); the live stream frames are verified by the kernel too and dropped if they fail.
import { get, post, openStream } from "./api";
import { verifyBody } from "./kernel";
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
