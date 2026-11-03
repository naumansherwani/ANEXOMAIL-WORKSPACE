/**
 * ANEXOMAIL WASM KERNEL — browser-side host (Rule 52). Rust (async, Tokio LocalSet) wasm ke andar chalta hai; yeh file sirf host hai:
 * wasm load + SHA-256 pin check, memory helpers, aur WebTransport / timers jo Rust ko chahiye (ABI: web-wasm/src/sys.rs).
 * Koi React nahi, koi `window` ki nirbharta nahi (WebTransport constructor inject hota hai) => bun test mein asli wasm chalta hai.
 */

export type KernelInfo = { kernel: string; version: string; abi: number; modules: string[] };

export type WTBidi = { readable: ReadableStream<Uint8Array>; writable: WritableStream<Uint8Array> };
export type WTSession = { ready: Promise<void>; closed: Promise<unknown>; close: () => void; createBidirectionalStream: () => Promise<WTBidi> };
export type WTCtor = new (url: string, opts?: unknown) => WTSession;

export type KernelOptions = {
  /** wasm bytes (loadKernelFromUrl fetch karke deta hai). */
  bytes: ArrayBuffer | Uint8Array;
  /** Pinned SHA-256 (hex). Mismatch => load se inkaar. */
  sha256?: string;
  WT?: WTCtor | null;
  /** WebTransport(url, opts) ke liye (testing: serverCertificateHashes). */
  wtOptions?: unknown;
  /** Rust ke ticks ke beech setTimeout/queueMicrotask. Tests inject kar sakte hain. */
  timers?: { setTimeout: (fn: () => void, ms: number) => unknown; clearTimeout: (t: unknown) => void };
};

export type LiveListener = {
  onState?: (webtransport: boolean, detail: string) => void;
  onEvent?: (topic: (typeof LIVE_TOPICS)[number]) => void;
  onResync?: () => void;
};
export type IntentPromise = {
  phrase: string; action: string; due_date: string | null; due_label: string | null; due_exact: boolean; confidence: number; lang: "en" | "ur";
};
export type IntentScan = { promises: IntentPromise[] };
export type FileMention = { phrase: string; query: string; explicit: boolean; latest: boolean };
export type FileScan = { mentions: FileMention[] };
export type IntentCost = {
  seconds_each: number; seconds_total: number; cost_minor: number; call_minutes: number; call_cost_minor: number; suggest_call: boolean; saving_minor: number;
};
export const LIVE_TOPICS = ["mail", "calendar", "crm", "work", "people", "org"] as const;

// Rust sys.rs ke saath ek jaise
const OP = { CONNECT: 1, BIDI: 2, WRITE: 3, READ: 4, FINISH: 5, CLOSE: 6, SLEEP: 7 } as const;
const EMIT = { LIVE_STATE: 1, LIVE_EVENT: 2, LIVE_RESYNC: 3, RPC_STATE: 4, RPC_DONE: 5 } as const;

export const SNIFF = { OK: 0, MISMATCH: 1, EXECUTABLE: 2, UNKNOWN: 3 } as const;

type Exports = {
  memory: WebAssembly.Memory;
  kernel_alloc(len: number): number;
  kernel_free(ptr: number, len: number): void;
  kernel_out_ptr(): number;
  kernel_out_len(): number;
  kernel_abi(): number;
  kernel_info(): number;
  kernel_tick(): void;
  kernel_host_complete(id: number, status: number, ptr: number, len: number): number;
  sha256_new(): number;
  sha256_update(h: number, ptr: number, len: number): number;
  sha256_finish(h: number): number;
  sha256_drop(h: number): void;
  hmac_sha256(kp: number, kl: number, mp: number, ml: number): number;
  hmac_verify(kp: number, kl: number, mp: number, ml: number, tp: number, tl: number): number;
  sniff_check(np: number, nl: number, hp: number, hl: number): number;
  rank_run(qp: number, ql: number, ip: number, il: number, limit: number): number;
  intent_scan(tp: number, tl: number, nowUnix: bigint, tzMin: number): number;
  intent_cost(words: number, recipients: number, rate: number, wpm: number): number;
  filectx_scan(tp: number, tl: number): number;
  live_start(up: number, ul: number, tp: number, tl: number, seed: number): number;
  live_set_token(h: number, tp: number, tl: number): void;
  live_stop(h: number): void;
  rpc_start(up: number, ul: number, seed: number): void;
  rpc_stop(): void;
  rpc_mark_down(): void;
  rpc_is_up(): number;
  rpc_call(id: number, ptr: number, len: number): void;
};

export const hexOf = (b: Uint8Array) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");

export async function sha256Hex(bytes: ArrayBuffer | Uint8Array): Promise<string> {
  const u8 = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const view = new Uint8Array(u8.byteLength);
  view.set(u8);
  return hexOf(new Uint8Array(await crypto.subtle.digest("SHA-256", view)));
}

export class KernelError extends Error {}

const enc = new TextEncoder();
const dec = new TextDecoder();

export class Kernel {
  readonly info: KernelInfo;
  private x!: Exports;
  private WT: WTCtor | null;
  private wtOptions: unknown;
  private timers: NonNullable<KernelOptions["timers"]>;
  private handles = new Map<number, { kind: "session"; wt: WTSession; rpc: boolean } | { kind: "stream"; w: WritableStreamDefaultWriter<Uint8Array>; r: ReadableStreamDefaultReader<Uint8Array> }>();
  private nextHandle = 1;
  private scheduled = false;
  private burst = 0;
  private live = new Map<number, LiveListener>();
  private rpcWaiters = new Map<number, (r: { status: number; body: Uint8Array }) => void>();
  private nextCall = 1;
  private rpcListeners = new Set<(up: boolean) => void>();

  private constructor(opts: KernelOptions, instanceInfo: { info: KernelInfo }) {
    this.info = instanceInfo.info;
    this.WT = opts.WT ?? null;
    this.wtOptions = opts.wtOptions;
    this.timers = opts.timers ?? { setTimeout: (fn, ms) => setTimeout(fn, ms), clearTimeout: (t) => clearTimeout(t as ReturnType<typeof setTimeout>) };
  }

  static async load(opts: KernelOptions): Promise<Kernel> {
    if (opts.sha256) {
      const got = await sha256Hex(opts.bytes);
      if (got !== opts.sha256.toLowerCase()) throw new KernelError(`kernel wasm hash mismatch (expected ${opts.sha256.slice(0, 12)}…, got ${got.slice(0, 12)}…)`);
    }
    // Instance banane se pehle import closures chahiye, isliye ek shell
    // eslint-disable-next-line prefer-const
    let self: Kernel;
    const imports = {
      env: {
        host_wake: () => self.wake(),
        host_call: (op: number, id: number, handle: number, ptr: number, len: number) => self.hostCall(op, id, handle, ptr, len),
        host_emit: (kind: number, a: number, b: number, ptr: number, len: number) => self.hostEmit(kind, a, b, ptr, len),
      },
    };
    const bytes = opts.bytes instanceof Uint8Array ? opts.bytes : new Uint8Array(opts.bytes);
    const { instance } = await WebAssembly.instantiate(bytes as BufferSource, imports);
    const x = instance.exports as unknown as Exports;
    if (typeof x.kernel_abi !== "function" || x.kernel_abi() !== 1) throw new KernelError("kernel ABI mismatch");
    const n = x.kernel_info();
    const info = JSON.parse(dec.decode(new Uint8Array(x.memory.buffer, x.kernel_out_ptr(), n))) as KernelInfo;
    self = new Kernel(opts, { info });
    self.x = x;
    return self;
  }

  /* ------------------------------------------------------------ memory */
  private u8() {
    return new Uint8Array(this.x.memory.buffer);
  }
  private put(b: Uint8Array): { ptr: number; len: number } {
    const ptr = this.x.kernel_alloc(Math.max(1, b.length));
    this.u8().set(b, ptr);
    return { ptr, len: b.length };
  }
  private free(p: { ptr: number; len: number }) {
    this.x.kernel_free(p.ptr, Math.max(1, p.len));
  }
  private withBytes<T>(b: Uint8Array, f: (p: { ptr: number; len: number }) => T): T {
    const p = this.put(b);
    try {
      return f(p);
    } finally {
      this.free(p);
    }
  }
  private out(n: number): Uint8Array {
    return this.u8().slice(this.x.kernel_out_ptr(), this.x.kernel_out_ptr() + n);
  }

  /* ---------------------------------------------------------- executor */
  private wake() {
    if (this.scheduled) return;
    this.scheduled = true;
    const run = () => {
      this.scheduled = false;
      this.burst = 0;
      this.x.kernel_tick();
    };
    // Lagataar jagne par UI ko saans: 200 microtask ke baad macrotask.
    if (++this.burst > 200) {
      this.burst = 0;
      this.timers.setTimeout(run, 0);
    } else {
      queueMicrotask(run);
    }
  }

  private complete(id: number, status: number, data: Uint8Array = new Uint8Array(0)) {
    this.withBytes(data, (p) => this.x.kernel_host_complete(id, status, p.ptr, p.len));
  }

  private hostCall(op: number, id: number, handle: number, ptr: number, len: number) {
    const arg = this.u8().slice(ptr, ptr + len); // Rust ka buffer call ke baad badal sakta hai
    void (async () => {
      await Promise.resolve(); // kabhi synchronous jawab nahi (Rust poll ke andar re-entrancy)
      try {
        switch (op) {
          case OP.CONNECT: {
            if (!this.WT) return this.complete(id, -1);
            const url = dec.decode(arg);
            const wt = new this.WT(url, this.wtOptions);
            await wt.ready;
            const h = this.nextHandle++;
            const rpc = url.endsWith("/wt/rpc");
            this.handles.set(h, { kind: "session", wt, rpc });
            void wt.closed.then(
              () => this.sessionDied(h),
              () => this.sessionDied(h),
            );
            return this.complete(id, 0, le32(h));
          }
          case OP.BIDI: {
            const s = this.handles.get(handle);
            if (!s || s.kind !== "session") return this.complete(id, -1);
            const bi = await s.wt.createBidirectionalStream();
            const h = this.nextHandle++;
            this.handles.set(h, { kind: "stream", w: bi.writable.getWriter(), r: bi.readable.getReader() });
            return this.complete(id, 0, le32(h));
          }
          case OP.WRITE: {
            const s = this.handles.get(handle);
            if (!s || s.kind !== "stream") return this.complete(id, -1);
            await s.w.write(arg);
            return this.complete(id, 0);
          }
          case OP.FINISH: {
            const s = this.handles.get(handle);
            if (!s || s.kind !== "stream") return this.complete(id, -1);
            await s.w.close();
            return this.complete(id, 0);
          }
          case OP.READ: {
            const s = this.handles.get(handle);
            if (!s || s.kind !== "stream") return this.complete(id, -1);
            const { value, done } = await s.r.read();
            return this.complete(id, 0, done || !value ? new Uint8Array(0) : value);
          }
          case OP.CLOSE: {
            this.closeHandle(handle);
            return this.complete(id, 0);
          }
          case OP.SLEEP: {
            this.timers.setTimeout(() => this.complete(id, 0), handle);
            return;
          }
          default:
            return this.complete(id, -1);
        }
      } catch {
        this.complete(id, -1);
      }
    })();
    // OP_CLOSE fire-and-forget (id=0): jawab nahi chahiye
  }

  private closeHandle(h: number) {
    const e = this.handles.get(h);
    if (!e) return;
    this.handles.delete(h);
    try {
      if (e.kind === "session") e.wt.close();
      else {
        e.r.cancel().catch(() => undefined);
        e.w.abort().catch(() => undefined);
      }
    } catch {
      /* pehle se band */
    }
  }

  private sessionDied(h: number) {
    const e = this.handles.get(h);
    if (e?.kind === "session" && e.rpc) this.x.rpc_mark_down();
    this.handles.delete(h);
  }

  private hostEmit(kind: number, a: number, b: number, ptr: number, len: number) {
    const data = this.u8().slice(ptr, ptr + len);
    switch (kind) {
      case EMIT.LIVE_STATE:
        for (const l of this.live.values()) l.onState?.(a === 1, dec.decode(data));
        break;
      case EMIT.LIVE_EVENT: {
        const t = LIVE_TOPICS[a];
        if (t) for (const l of this.live.values()) l.onEvent?.(t);
        break;
      }
      case EMIT.LIVE_RESYNC:
        for (const l of this.live.values()) l.onResync?.();
        break;
      case EMIT.RPC_STATE:
        for (const f of this.rpcListeners) f(a === 1);
        break;
      case EMIT.RPC_DONE: {
        const w = this.rpcWaiters.get(a);
        this.rpcWaiters.delete(a);
        w?.({ status: b | 0, body: data });
        break;
      }
    }
  }

  /* ----------------------------------------------------------- modules */
  /** Streaming SHA-256: Blob/File ko chunk-chunk padho (memory flat), hex digest. */
  async sha256Blob(blob: Blob, chunk = 1 << 20, onProgress?: (done: number, total: number) => void): Promise<string> {
    const h = this.x.sha256_new();
    try {
      for (let off = 0; off < blob.size; off += chunk) {
        const part = new Uint8Array(await blob.slice(off, Math.min(blob.size, off + chunk)).arrayBuffer());
        this.withBytes(part, (p) => this.x.sha256_update(h, p.ptr, p.len));
        onProgress?.(Math.min(blob.size, off + chunk), blob.size);
      }
      const n = this.x.sha256_finish(h);
      if (n !== 32) throw new KernelError("sha256 failed");
      return hexOf(this.out(n));
    } catch (e) {
      this.x.sha256_drop(h);
      throw e;
    }
  }

  sha256Bytes(b: Uint8Array): string {
    const h = this.x.sha256_new();
    this.withBytes(b, (p) => this.x.sha256_update(h, p.ptr, p.len));
    return hexOf(this.out(this.x.sha256_finish(h)));
  }

  /** HMAC-SHA256 (hex). Key kernel ke andar hi use hoti hai. */
  hmacSha256(key: Uint8Array, msg: Uint8Array): string {
    return hexOf(this.withBytes(key, (k) => this.withBytes(msg, (m) => this.out(this.x.hmac_sha256(k.ptr, k.len, m.ptr, m.len)))));
  }

  /** Constant-time tag check. */
  hmacVerify(key: Uint8Array, msg: Uint8Array, tag: Uint8Array): boolean {
    return this.withBytes(key, (k) => this.withBytes(msg, (m) => this.withBytes(tag, (t) => this.x.hmac_verify(k.ptr, k.len, m.ptr, m.len, t.ptr, t.len)))) === 1;
  }

  /** 0 ok · 1 naam/bytes mismatch · 2 executable · 3 anjaan type (server dekhega). */
  sniff(name: string, head: Uint8Array): number {
    const nb = enc.encode(name);
    return this.withBytes(nb, (n) => this.withBytes(head.subarray(0, 4096), (h) => this.x.sniff_check(n.ptr, n.len, h.ptr, h.len)));
  }

  /** items ke indices, behtareen pehle. */
  rank(query: string, items: string[], limit = 50): number[] {
    const q = enc.encode(query);
    const it = enc.encode(items.join("\n"));
    const n = this.withBytes(q, (qp) => this.withBytes(it, (ip) => this.x.rank_run(qp.ptr, qp.len, ip.ptr, ip.len, limit)));
    const raw = this.out(n * 4);
    const dv = new DataView(raw.buffer, raw.byteOffset, raw.byteLength);
    return Array.from({ length: n }, (_, i) => dv.getUint32(i * 4, true));
  }

  /** Email text mein wade + deadline (deterministic, English + Roman Urdu). nowUnix = UTC seconds, tzMin = UTC se farq minutes (+300 Karachi). */
  intentScan(text: string, nowUnix: number, tzMin: number): IntentScan {
    const t = enc.encode(text.slice(0, 20000));
    const n = this.withBytes(t, (p) => this.x.intent_scan(p.ptr, p.len, BigInt(Math.floor(nowUnix)), tzMin | 0));
    return JSON.parse(new TextDecoder().decode(this.out(n))) as IntentScan;
  }

  /** Email padhne ka waqt/paisa: words x recipients x rate (minor unit / ghanta). SQL attention_cost() se bit-ba-bit same integers. */
  intentCost(words: number, recipients: number, rateMinorPerHour: number, wpm = 0): IntentCost {
    const n = this.x.intent_cost(Math.max(0, words | 0), Math.max(0, recipients | 0), Math.max(0, rateMinorPerHour | 0), Math.max(0, wpm | 0));
    return JSON.parse(new TextDecoder().decode(this.out(n))) as IntentCost;
  }

  /** Email text mein file ka zikr ("the latest CRM sheet", "Q3_budget.xlsx"): sirf pehchaan, asli file server se aati hai. */
  fileScan(text: string): FileScan {
    const t = enc.encode(text.slice(0, 20000));
    const n = this.withBytes(t, (p) => this.x.filectx_scan(p.ptr, p.len));
    return JSON.parse(new TextDecoder().decode(this.out(n))) as FileScan;
  }

  liveStart(url: string, token: string, l: LiveListener): { setToken: (t: string) => void; stop: () => void } {
    const u = enc.encode(url);
    const t = enc.encode(token);
    const h = this.withBytes(u, (up) => this.withBytes(t, (tp) => this.x.live_start(up.ptr, up.len, tp.ptr, tp.len, (Math.random() * 0xffffffff) >>> 0)));
    this.live.set(h, l);
    return {
      setToken: (nt) => this.withBytes(enc.encode(nt), (p) => this.x.live_set_token(h, p.ptr, p.len)),
      stop: () => {
        this.live.delete(h);
        this.x.live_stop(h);
      },
    };
  }

  rpcStart(baseUrl: string) {
    this.withBytes(enc.encode(baseUrl), (p) => this.x.rpc_start(p.ptr, p.len, (Math.random() * 0xffffffff) >>> 0));
  }
  rpcStop() {
    this.x.rpc_stop();
  }
  get rpcUp(): boolean {
    return this.x.rpc_is_up() === 1;
  }
  onRpcState(f: (up: boolean) => void): () => void {
    this.rpcListeners.add(f);
    return () => this.rpcListeners.delete(f);
  }

  /** Ek generic call: kernel ke WebTransport par. `unavailable` => session nahi (caller plain fetch par jaye). */
  rpcCall(request: Uint8Array, timeoutMs = 20_000): Promise<{ status: number; body: Uint8Array }> {
    const id = this.nextCall++;
    return new Promise((resolve) => {
      const timer = this.timers.setTimeout(() => {
        if (this.rpcWaiters.delete(id)) resolve({ status: 504, body: new Uint8Array(0) });
      }, timeoutMs);
      this.rpcWaiters.set(id, (r) => {
        this.timers.clearTimeout(timer);
        resolve(r);
      });
      this.withBytes(request, (p) => this.x.rpc_call(id, p.ptr, p.len));
    });
  }
}

const le32 = (n: number) => {
  const b = new Uint8Array(4);
  new DataView(b.buffer).setUint32(0, n, true);
  return b;
};
