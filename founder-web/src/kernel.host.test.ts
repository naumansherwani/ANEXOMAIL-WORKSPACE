// K6.3 guard: the host shim of the Rust kernel (WebTransport ops, clock, timers, emits) against a fake WebTransport and fake kernel exports.
import { expect, test } from "bun:test";
import { createHost, EMIT, OP, type HostExports, type WtCtor } from "./kernel.host";

function fake() {
  const memory = new WebAssembly.Memory({ initial: 2 });
  let top = 1024; const done: { id: number; status: number; data: number[] }[] = []; let ticks = 0;
  const ex: HostExports = {
    memory, kernel_alloc: (n) => { const p = top; top += n + 8; return p; }, kernel_free: () => undefined, kernel_tick: () => { ticks++; },
    kernel_host_complete: (id, status, ptr, len) => { done.push({ id, status, data: [...new Uint8Array(memory.buffer).slice(ptr, ptr + len)] }); return 1; },
  };
  const put = (b: Uint8Array) => { const p = ex.kernel_alloc(b.length); new Uint8Array(memory.buffer).set(b, p); return [p, b.length] as const; };
  return { ex, done, put, ticks: () => ticks };
}
const settle = () => new Promise((r) => setTimeout(r, 5));

test("connect, bidi, hello write, read frames, EOF, close: the whole session over a fake WebTransport", async () => {
  const f = fake(), wrote: number[][] = []; let closed = false, urlSeen = "";
  const chunks = [new TextEncoder().encode("event: snapshot\n"), new TextEncoder().encode("data: {}\n\n")];
  const WT: WtCtor = class { ready = Promise.resolve(); closed = new Promise(() => undefined); constructor(u: string) { urlSeen = u; }
    async createBidirectionalStream() {
      let i = 0;
      return { readable: new ReadableStream<Uint8Array>({ pull(c) { if (i < chunks.length) c.enqueue(chunks[i++]); else c.close(); } }), writable: new WritableStream<Uint8Array>({ write(b) { wrote.push([...b]); } }) };
    }
    close() { closed = true; } } as unknown as WtCtor;
  const h = createHost(WT, () => f.ex, () => undefined);
  const url = f.put(new TextEncoder().encode("https://f.example:4443/wt/live"));
  h.env.host_call(OP.CONNECT, 1, 0, url[0], url[1]); await settle();
  expect(urlSeen).toBe("https://f.example:4443/wt/live"); expect(f.done[0]).toMatchObject({ id: 1, status: 0, data: [1, 0, 0, 0] });
  h.env.host_call(OP.BIDI, 2, 1, 0, 0); await settle(); expect(f.done[1]).toMatchObject({ id: 2, status: 0, data: [2, 0, 0, 0] });
  const hello = f.put(new TextEncoder().encode("ANX1 tok\n"));
  h.env.host_call(OP.WRITE, 3, 2, hello[0], hello[1]); await settle(); expect(wrote).toEqual([[...new TextEncoder().encode("ANX1 tok\n")]]);
  h.env.host_call(OP.READ, 4, 2, 0, 0); await settle(); h.env.host_call(OP.READ, 5, 2, 0, 0); await settle(); h.env.host_call(OP.READ, 6, 2, 0, 0); await settle();
  expect(new TextDecoder().decode(new Uint8Array(f.done[3].data))).toBe("event: snapshot\n"); expect(f.done[4].data.length).toBe(10); expect(f.done[5]).toMatchObject({ status: 0, data: [] }); // EOF = status 0 + empty
  h.env.host_call(OP.CLOSE, 0, 1, 0, 0); await settle(); expect(closed).toBe(true); expect(f.done.length).toBe(6); expect(h.openHandles()).toBe(1); // fire-and-forget close answers nobody
});

test("no WebTransport = connect fails cleanly (the kernel then reports it and the page falls back to SSE)", async () => {
  const f = fake(), h = createHost(null, () => f.ex, () => undefined), u = f.put(new TextEncoder().encode("https://x"));
  h.env.host_call(OP.CONNECT, 9, 0, u[0], u[1]); await settle(); expect(f.done[0]).toMatchObject({ id: 9, status: -1 });
  h.env.host_call(99, 10, 0, 0, 0); await settle(); expect(f.done[1]).toMatchObject({ id: 10, status: -1 }); // unknown op
  h.env.host_call(OP.READ, 11, 77, 0, 0); await settle(); expect(f.done[2]).toMatchObject({ id: 11, status: -1 }); // unknown handle
});

test("clock is the browser clock in unix seconds (8 bytes LE) and sleep waits then completes", async () => {
  const f = fake(), timers: (() => void)[] = [], h = createHost(null, () => f.ex, () => undefined, { setTimeout: (fn) => { timers.push(fn); return 0; } }, () => 1_700_000_123_999);
  h.env.host_call(OP.NOW, 1, 0, 0, 0); await settle();
  expect(new DataView(new Uint8Array(f.done[0].data).buffer).getBigInt64(0, true)).toBe(1_700_000_123n);
  h.env.host_call(OP.SLEEP, 2, 5000, 0, 0); await settle(); expect(f.done.length).toBe(1); timers.pop()!(); expect(f.done[1]).toMatchObject({ id: 2, status: 0 });
});

test("wake schedules exactly one kernel tick, emits are copied out of kernel memory", async () => {
  const f = fake(), seen: [number, number, string][] = [], h = createHost(null, () => f.ex, (k, a, _b, d) => seen.push([k, a, new TextDecoder().decode(d)]));
  h.env.host_wake(); h.env.host_wake(); h.env.host_wake(); await settle(); expect(f.ticks()).toBe(1);
  const p = f.put(new TextEncoder().encode("{\"v\":1}")); h.env.host_emit(EMIT.FLIVE_FRAME, 2, 0, p[0], p[1]);
  new Uint8Array(f.ex.memory.buffer).fill(0, p[0], p[0] + p[1]); expect(seen).toEqual([[7, 2, "{\"v\":1}"]]); // later changes of kernel memory do not alter what was forwarded
});
