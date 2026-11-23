// ADMIN DESK Phase C2 (22 Nov 2026): the live Bridge stream client. WebTransport over HTTP/3 (QUIC) to the Desk's own UDP 4400 endpoint, path /wt/bridge.
// HIS LAW 22 Nov 04:38: HTTP fallback is BANNED. If WebTransport is missing or the connection fails, the state is "offline" and the client retries WebTransport; it never polls.
// Rule 52: the hello MAC and EVERY frame are made/verified by the Desk's Rust WASM kernel (stream_hello, verify_frame, frame_is_stale). A line that fails is dropped
// and the stream is closed; nothing unverified reaches the page. No founder code, key or kernel.
import init, { stream_hello, verify_frame, frame_is_stale } from "./kernel/anexomail_desk_kernel.js";
import { DESK_SESSION_KEY } from "./desk_pure";
import { DESK_PIN_KEY } from "./desk_kernel";
import { backoffMs, fatal, overall, splitLines, TRACKS, type StreamState, type Track } from "./desk_stream_pure";

export type Frames = Partial<Record<Track, unknown>>;
export type Snapshot = { state: StreamState; data: Frames };
const URL_BASE = "https://admindesk.anexomail.com:4400/wt/bridge";
const hex = (b: Uint8Array) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
const read = (k: string) => { try { return window.localStorage.getItem(k); } catch { return null; } };

/** Start the stream. Returns stop(). onChange fires on every verified frame and every state change. */
export function openBridge(onChange: (s: Snapshot) => void): () => void {
  let stopped = false, attempt = 0, everConnected = false, connected = false, wt = null as WebTransport | null;
  const lastSeq: Record<Track, number> = { summary: 0, services: 0, alerts: 0, plans: 0 };
  const lastAt: Partial<Record<Track, number>> = {};
  const data: Frames = {};
  let shown: StreamState | "" = "";
  const emit = (force = false) => { const st = overall(connected, everConnected, lastAt, Date.now(), (a) => frame_is_stale(a / 1000, Date.now() / 1000)); if (force || st !== shown) { shown = st; onChange({ state: st, data: { ...data } }); } };
  const timer = window.setInterval(() => emit(), 1000); // the 12 s stale rule is the KERNEL's (frame_is_stale); this only re-evaluates it each second

  async function once(): Promise<void> {
    await init();
    const token = read(DESK_SESSION_KEY), pub = read(DESK_PIN_KEY);
    if (!token || !pub) throw new Error("no_session");
    if (typeof WebTransport === "undefined") throw new Error("no_webtransport");
    wt = new WebTransport(URL_BASE); await wt.ready;
    const bi = await wt.createBidirectionalStream();
    const w = bi.writable.getWriter();
    const nonce = hex(crypto.getRandomValues(new Uint8Array(16)));
    await w.write(new TextEncoder().encode(stream_hello(token, nonce, Math.floor(Date.now() / 1000))));
    for (const t of TRACKS) { lastSeq[t] = 0; delete lastAt[t]; }
    connected = true; everConnected = true; emit(true);
    const rd = bi.readable.getReader(), dec = new TextDecoder(); let buf = "";
    for (;;) {
      const { value, done } = await rd.read(); if (done || stopped) break;
      buf += dec.decode(value, { stream: true });
      const sp = splitLines(buf); if (!sp) throw new Error("protocol");
      buf = sp.rest;
      for (const line of sp.lines) {
        if (line.startsWith("ERR ")) { if (fatal(line)) stopped = true; throw new Error(line); }
        const track = (() => { try { const b = JSON.parse(JSON.parse(line).body) as { track?: string }; return TRACKS.find((t) => t === b.track); } catch { return undefined; } })();
        if (!track) throw new Error("bad_frame");
        const body = JSON.parse(verify_frame(pub, Math.floor(Date.now() / 1000), lastSeq[track], line)) as { seq: number; data: unknown };
        lastSeq[track] = body.seq; lastAt[track] = Date.now(); data[track] = body.data; attempt = 0; emit(true);
      }
    }
  }
  (async () => {
    while (!stopped) {
      try { await once(); } catch { /* any failure = offline, then retry WebTransport (no other transport exists for the Desk) */ }
      connected = false; try { wt?.close(); } catch { /* already closed */ } wt = null; emit(true);
      if (stopped) break;
      await new Promise((r) => window.setTimeout(r, backoffMs(attempt++, Math.random())));
    }
  })();
  emit(true);
  return () => { stopped = true; window.clearInterval(timer); try { wt?.close(); } catch { /* already closed */ } };
}
