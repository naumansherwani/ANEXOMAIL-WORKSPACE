// K6.3 (Rule 52): the thin host shim of the ONE Rust/Tokio WASM kernel, founder lane. The kernel (module flive@1) holds ALL the protocol and verification logic;
// this file only does what a wasm module cannot: the browser's own WebTransport, timers and clock, through the kernel's host ABI (sys.rs).
// No DOM, no network of its own, no business logic: connect / bidi / write / read / close / sleep / now, and "kernel says X" forwarded as a plain message.
export type WtStream = { readable: ReadableStream<Uint8Array>; writable: WritableStream<Uint8Array> };
export type WtSession = { ready: Promise<unknown>; closed: Promise<unknown>; createBidirectionalStream(): Promise<WtStream>; close(): void };
export type WtCtor = new (url: string) => WtSession;
export type HostExports = { memory: WebAssembly.Memory; kernel_alloc(n: number): number; kernel_free(p: number, n: number): void; kernel_tick(): void; kernel_host_complete(id: number, status: number, ptr: number, len: number): number };
export type Timers = { setTimeout(fn: () => void, ms: number): unknown };

export const OP = { CONNECT: 1, BIDI: 2, WRITE: 3, READ: 4, FINISH: 5, CLOSE: 6, SLEEP: 7, NOW: 8 } as const;
export const EMIT = { FLIVE_STATE: 6, FLIVE_FRAME: 7, FLIVE_DROP: 8 } as const;
const MAX_CHUNK = 4 << 20; // a single read larger than this is not a live frame: refuse (the kernel reconnects)

type Handle = { kind: "session"; wt: WtSession } | { kind: "stream"; w: WritableStreamDefaultWriter<Uint8Array>; r: ReadableStreamDefaultReader<Uint8Array> };

export function createHost(WT: WtCtor | null, getEx: () => HostExports, onEmit: (kind: number, a: number, b: number, data: Uint8Array) => void, timers: Timers = { setTimeout: (f, ms) => setTimeout(f, ms) }, nowMs: () => number = Date.now) {
  const handles = new Map<number, Handle>();
  const pre = new Map<string, WtSession>(); // KP3 pre-connect: a session dialled while the wasm still downloads; the kernel's CONNECT for the same URL takes it (single use, 15 s life)
  let next = 1, scheduled = false, burst = 0;
  const le32 = (n: number) => new Uint8Array([n & 255, (n >>> 8) & 255, (n >>> 16) & 255, (n >>> 24) & 255]);
  const complete = (id: number, status: number, data: Uint8Array = new Uint8Array(0)) => {
    if (id === 0) return; // fire-and-forget (OP_CLOSE)
    const k = getEx(), p = k.kernel_alloc(Math.max(1, data.length));
    new Uint8Array(k.memory.buffer).set(data, p);
    try { k.kernel_host_complete(id, status, p, data.length); } finally { k.kernel_free(p, Math.max(1, data.length)); }
  };
  const closeHandle = (h: number) => {
    const e = handles.get(h); if (!e) return; handles.delete(h);
    try { if (e.kind === "session") e.wt.close(); else { e.r.cancel().catch(() => undefined); e.w.abort().catch(() => undefined); } } catch { /* already closed */ }
  };
  const wake = () => {
    if (scheduled) return; scheduled = true;
    const run = () => { scheduled = false; burst = 0; getEx().kernel_tick(); };
    if (++burst > 200) { burst = 0; timers.setTimeout(run, 0); } else queueMicrotask(run); // a long run of wake-ups gives the page room to breathe
  };
  const call = (op: number, id: number, handle: number, ptr: number, len: number) => {
    const arg = new Uint8Array(getEx().memory.buffer).slice(ptr, ptr + len); // the kernel may reuse its buffer after this call returns
    void (async () => {
      await Promise.resolve(); // never a synchronous answer (no re-entrancy into the kernel poll)
      try {
        switch (op) {
          case OP.CONNECT: {
            if (!WT) return complete(id, -1);
            const url = new TextDecoder().decode(arg), early = pre.get(url); pre.delete(url);
            let wt: WtSession | null = null;
            if (early) { try { await early.ready; wt = early; } catch { wt = null; } } // a failed early dial is not an error: dial fresh below
            if (!wt) { wt = new WT(url); await wt.ready; }
            const h = next++; handles.set(h, { kind: "session", wt });
            void wt.closed.then(() => handles.delete(h), () => handles.delete(h));
            return complete(id, 0, le32(h));
          }
          case OP.BIDI: {
            const s = handles.get(handle); if (!s || s.kind !== "session") return complete(id, -1);
            const bi = await s.wt.createBidirectionalStream(), h = next++;
            handles.set(h, { kind: "stream", w: bi.writable.getWriter(), r: bi.readable.getReader() });
            return complete(id, 0, le32(h));
          }
          case OP.WRITE: { const s = handles.get(handle); if (!s || s.kind !== "stream") return complete(id, -1); await s.w.write(arg); return complete(id, 0); }
          case OP.FINISH: { const s = handles.get(handle); if (!s || s.kind !== "stream") return complete(id, -1); await s.w.close(); return complete(id, 0); }
          case OP.READ: {
            const s = handles.get(handle); if (!s || s.kind !== "stream") return complete(id, -1);
            const { value, done } = await s.r.read();
            if (value && value.length > MAX_CHUNK) return complete(id, -1);
            return complete(id, 0, done || !value ? new Uint8Array(0) : value);
          }
          case OP.CLOSE: closeHandle(handle); return complete(id, 0);
          case OP.SLEEP: timers.setTimeout(() => complete(id, 0), handle); return;
          case OP.NOW: { const b = new Uint8Array(8); new DataView(b.buffer).setBigInt64(0, BigInt(Math.floor(nowMs() / 1000)), true); return complete(id, 0, b); }
          default: return complete(id, -1);
        }
      } catch { complete(id, -1); }
    })();
  };
  const preconnect = (url: string) => {
    if (!WT || pre.has(url)) return;
    try {
      const wt = new WT(url); pre.set(url, wt);
      wt.ready.catch(() => { if (pre.get(url) === wt) pre.delete(url); }); wt.closed.catch(() => undefined);
      timers.setTimeout(() => { if (pre.get(url) === wt) { pre.delete(url); try { wt.close(); } catch { /* gone */ } } }, 15000);
    } catch { /* unsupported: the kernel dials itself */ }
  };
  return {
    preconnect,
    env: {
      host_wake: wake,
      host_call: call,
      host_emit: (kind: number, a: number, b: number, ptr: number, len: number) => onEmit(kind, a, b, new Uint8Array(getEx().memory.buffer).slice(ptr, ptr + len)),
    },
    openHandles: () => handles.size,
  };
}
