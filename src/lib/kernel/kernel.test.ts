import { createHash, randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";
import { describe, expect, test } from "bun:test";

import { Kernel, KernelError, LIVE_TOPICS, SNIFF, sha256Hex, type WTCtor, type WTSession } from "./kernel";
import { KERNEL_PIN } from "./pin.gen";

const bytes = () => readFileSync(`public${KERNEL_PIN.url}`);
const flush = (ms = 0) => new Promise((r) => setTimeout(r, ms));
const enc = new TextEncoder();
const dec = new TextDecoder();

/** Fake WebTransport: `script(url, session)` har naye session par server ka kirdar nibhata hai. */
type Server = {
  onBidi: (reqBytes: () => Promise<Uint8Array>, write: (b: Uint8Array) => Promise<void>, end: () => Promise<void>, url: string) => Promise<void>;
  refuse?: boolean;
};
function fakeWT(server: Server) {
  const sessions: { url: string; close: () => void; closeFromServer: () => void }[] = [];
  const Ctor = class implements WTSession {
    ready: Promise<void>;
    closed: Promise<unknown>;
    private resolveClosed!: () => void;
    private isClosed = false;
    constructor(public url: string) {
      this.closed = new Promise<void>((r) => (this.resolveClosed = r));
      this.ready = server.refuse ? Promise.reject(new Error("refused")) : Promise.resolve();
      this.ready.catch(() => undefined);
      sessions.push({ url, close: () => this.close(), closeFromServer: () => this.close() });
    }
    close() {
      if (!this.isClosed) {
        this.isClosed = true;
        this.resolveClosed();
      }
    }
    async createBidirectionalStream() {
      if (this.isClosed) throw new Error("closed");
      const toServer = new TransformStream<Uint8Array, Uint8Array>();
      const toClient = new TransformStream<Uint8Array, Uint8Array>();
      const sr = toServer.readable.getReader();
      const sw = toClient.writable.getWriter();
      const readAll = async () => {
        const parts: Uint8Array[] = [];
        for (;;) {
          const { value, done } = await sr.read();
          if (done) break;
          parts.push(value);
        }
        return new Uint8Array(Buffer.concat(parts));
      };
      void server.onBidi(readAll, (b) => sw.write(b), () => sw.close(), this.url).catch(() => undefined); // client ne stream gira diya => server ka write fail hona normal hai
      return { readable: toClient.readable, writable: toServer.writable };
    }
  };
  return { Ctor: Ctor as unknown as WTCtor, sessions };
}

/** Time ko haath mein: setTimeout fake, tick() se aage badhta hai. */
function fakeTimers() {
  let now = 0;
  const q: { at: number; fn: () => void; id: number }[] = [];
  const delays: number[] = [];
  let n = 0;
  return {
    delays,
    timers: {
      setTimeout: (fn: () => void, ms: number) => {
        const id = ++n;
        delays.push(ms);
        q.push({ at: now + ms, fn, id });
        return id;
      },
      clearTimeout: (id: unknown) => {
        const i = q.findIndex((t) => t.id === id);
        if (i >= 0) q.splice(i, 1);
      },
    },
    async advance(ms: number) {
      const end = now + ms;
      for (;;) {
        q.sort((a, b) => a.at - b.at);
        const next = q[0];
        if (!next || next.at > end) break;
        q.shift();
        now = next.at;
        next.fn();
        await flush();
      }
      now = end;
      await flush();
    },
    pending: () => q.map((t) => t.at - now),
  };
}

describe("kernel wasm — load, pin, version", () => {
  test("the shipped wasm matches its pin and reports the Cargo version + modules", async () => {
    expect(await sha256Hex(bytes())).toBe(KERNEL_PIN.sha256);
    const k = await Kernel.load({ bytes: bytes(), sha256: KERNEL_PIN.sha256 });
    expect(k.info.version).toBe(KERNEL_PIN.version);
    expect(k.info.abi).toBe(1);
    expect(k.info.modules).toEqual(["sha256@1", "sniff@1", "rank@1", "live@1", "rpc@1"]);
    const cargo = readFileSync("web-wasm/Cargo.toml", "utf8").match(/^version\s*=\s*"([^"]+)"/m)?.[1];
    expect(cargo).toBe(KERNEL_PIN.version);
  });
  test("a tampered or wrong-pin wasm is refused", async () => {
    const bad = new Uint8Array(bytes());
    bad[bad.length - 1] ^= 1;
    await expect(Kernel.load({ bytes: bad, sha256: KERNEL_PIN.sha256 })).rejects.toThrow(KernelError);
    await expect(Kernel.load({ bytes: bytes(), sha256: "0".repeat(64) })).rejects.toThrow(/mismatch/);
  });
});

describe("kernel — sha256 / sniff / rank (real wasm)", () => {
  test("sha256 equals node's for many sizes and chunkings", async () => {
    const k = await Kernel.load({ bytes: bytes(), sha256: KERNEL_PIN.sha256 });
    for (const size of [0, 1, 55, 56, 63, 64, 65, 1000, (1 << 20) - 1, 1 << 20, (1 << 20) + 1, 3_333_333]) {
      const data = randomBytes(size);
      const want = createHash("sha256").update(data).digest("hex");
      expect(await k.sha256Blob(new Blob([data]))).toBe(want);
      expect(await k.sha256Blob(new Blob([data]), 4099)).toBe(want);
    }
    expect(k.sha256Bytes(enc.encode("abc"))).toBe("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  });
  test("a 40 MB file streams through without growing memory beyond a few MB", async () => {
    const k = await Kernel.load({ bytes: bytes(), sha256: KERNEL_PIN.sha256 });
    const big = new Uint8Array(40 << 20).map((_, i) => (i * 7) & 255);
    const want = createHash("sha256").update(big).digest("hex");
    let last = 0;
    expect(await k.sha256Blob(new Blob([big]), 1 << 20, (d) => (last = d))).toBe(want);
    expect(last).toBe(big.length);
    // @ts-expect-error — test: wasm memory ka size dekhna
    expect(k.x.memory.buffer.byteLength).toBeLessThan(16 << 20);
  });
  test("sniff catches disguised executables and mismatches", async () => {
    const k = await Kernel.load({ bytes: bytes(), sha256: KERNEL_PIN.sha256 });
    expect(k.sniff("a.png", new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))).toBe(SNIFF.OK);
    expect(k.sniff("holiday.png", enc.encode("MZ\x90\x00"))).toBe(SNIFF.EXECUTABLE);
    expect(k.sniff("x.pdf", enc.encode("GIF89a"))).toBe(SNIFF.MISMATCH);
    expect(k.sniff("a.7z", enc.encode("7z"))).toBe(SNIFF.UNKNOWN);
    expect(k.sniff("نام.txt", enc.encode("ٹھیک ہے"))).toBe(SNIFF.OK);
  });
  test("rank returns best-first indices, handles unicode and 100k items", async () => {
    const k = await Kernel.load({ bytes: bytes(), sha256: KERNEL_PIN.sha256 });
    expect(k.rank("foo", ["xxfooxx", "foo bar", "bar foo", "foo", "f-o-o"])).toEqual([3, 1, 2, 0, 4]);
    expect(k.rank("اردو", ["hello", "اردو زبان"])).toEqual([1]);
    const big = Array.from({ length: 100_000 }, (_, i) => `thread ${i} subject`);
    const t = performance.now();
    expect(k.rank("thread 99999", big, 3)[0]).toBe(99_999);
    expect(performance.now() - t).toBeLessThan(500);
  });
});

describe("kernel — live (Rust async state machine on a fake WebTransport)", () => {
  test("hello, ready, events, reassembled split frame, resync", async () => {
    const hellos: string[] = [];
    const { Ctor, sessions } = fakeWT({
      async onBidi(req, write, _end, url) {
        // live: client hello likhta hai aur stream khula rakhta hai — server pehla chunk padh kar jawab deta hai
        void req(); // hello padhta rahe (real server bhi padhta hai); warna write backpressure mein atak jata
        hellos.push(url);
        await write(enc.encode('{"type":"ready"}\n{"type":"event","topic":"crm"}\n{"type":"event","to'));
        await flush(5);
        await write(enc.encode('pic":"org"}\n'));
      },
    });
    const ft = fakeTimers();
    const k = await Kernel.load({ bytes: bytes(), sha256: KERNEL_PIN.sha256, WT: Ctor, timers: ft.timers });
    const seen: string[] = [];
    const states: [boolean, string][] = [];
    let resyncs = 0;
    const live = k.liveStart("https://x.example/", "tok", {
      onState: (wt, d) => states.push([wt, d]),
      onEvent: (t) => seen.push(t),
      onResync: () => resyncs++,
    });
    await flush(30);
    expect(hellos).toEqual(["https://x.example/wt/events"]);
    expect(seen).toEqual(["crm", "org"]);
    expect(resyncs).toBe(1);
    expect(states[0]).toEqual([true, "Live over WebTransport / QUIC (Rust engine)"]);
    live.stop();
    expect(sessions.length).toBe(1);
  });
  test("a refused connection falls back to 'poll' honestly and backs off 1s, 2s, 4s", async () => {
    const { Ctor, sessions } = fakeWT({ refuse: true, onBidi: async () => undefined });
    const ft = fakeTimers();
    const k = await Kernel.load({ bytes: bytes(), sha256: KERNEL_PIN.sha256, WT: Ctor, timers: ft.timers });
    const states: boolean[] = [];
    const live = k.liveStart("https://x", "t", { onState: (wt) => states.push(wt) });
    await flush(10);
    expect(sessions.length).toBe(1);
    expect(states.every((s) => s === false)).toBe(true);
    await ft.advance(1300);
    expect(sessions.length).toBe(2);
    await ft.advance(2600);
    expect(sessions.length).toBe(3);
    // Rust ne har dafa jo intezar maanga: 1 s, 2 s, 4 s (+ 0..25% jitter)
    const waits = ft.delays.filter((d) => d >= 1000);
    expect(waits.length).toBeGreaterThanOrEqual(3);
    [1000, 2000, 4000].forEach((base, i) => {
      expect(waits[i]!).toBeGreaterThanOrEqual(base);
      expect(waits[i]!).toBeLessThanOrEqual(Math.round(base * 1.25));
    });
    live.stop();
  });
  test("no WebTransport in this browser => poll state, no crash", async () => {
    const ft = fakeTimers();
    const k = await Kernel.load({ bytes: bytes(), sha256: KERNEL_PIN.sha256, WT: null, timers: ft.timers });
    const states: boolean[] = [];
    const live = k.liveStart("https://x", "t", { onState: (wt) => states.push(wt) });
    await flush(10);
    expect(states.length).toBeGreaterThan(0);
    expect(states.every((s) => !s)).toBe(true);
    live.stop();
  });
  test("topic names line up with live-core.ts", () => {
    expect([...LIVE_TOPICS]).toEqual(["mail", "calendar", "crm", "work", "people", "org"]);
  });
});

describe("kernel — rpc over ONE session (fake server echoes proc/input)", () => {
  const echo: Server = {
    async onBidi(req, write, end, url) {
      if (!url.endsWith("/wt/rpc")) return;
      const r = JSON.parse(dec.decode(await req())) as { proc: string; input: unknown; token: string };
      await write(enc.encode(JSON.stringify({ status: r.token === "good" ? 200 : 401, body: { proc: r.proc, input: r.input } })));
      await end();
    },
  };
  const call = (k: Kernel, proc: string, input: unknown, token = "good") =>
    k.rpcCall(enc.encode(JSON.stringify({ token, proc, input }))).then((r) => ({ status: r.status, json: r.body.length ? JSON.parse(dec.decode(r.body)) : null }));

  test("50 parallel calls share one session and each gets its own answer", async () => {
    const { Ctor, sessions } = fakeWT(echo);
    const k = await Kernel.load({ bytes: bytes(), sha256: KERNEL_PIN.sha256, WT: Ctor });
    const ups: boolean[] = [];
    k.onRpcState((u) => ups.push(u));
    k.rpcStart("https://x.example");
    await flush(10);
    expect(k.rpcUp).toBe(true);
    const results = await Promise.all(Array.from({ length: 50 }, (_, i) => call(k, "mail.threads", { n: i })));
    results.forEach((r, i) => {
      expect(r.status).toBe(200);
      expect(r.json).toEqual({ status: 200, body: { proc: "mail.threads", input: { n: i } } });
    });
    expect(sessions.filter((s) => s.url.endsWith("/wt/rpc")).length).toBe(1);
    expect(ups).toEqual([true]);
    k.rpcStop();
  });
  test("before the session is up, a call answers 503 at once (caller uses fetch) — never hangs", async () => {
    const { Ctor } = fakeWT({ refuse: true, onBidi: async () => undefined });
    const k = await Kernel.load({ bytes: bytes(), sha256: KERNEL_PIN.sha256, WT: Ctor });
    const r = await call(k, "x", {});
    expect(r.status).toBe(503);
    expect(k.rpcUp).toBe(false);
  });
  test("when the server drops the session, state goes down and the supervisor reconnects", async () => {
    const { Ctor, sessions } = fakeWT(echo);
    const ft = fakeTimers();
    const k = await Kernel.load({ bytes: bytes(), sha256: KERNEL_PIN.sha256, WT: Ctor, timers: ft.timers });
    const ups: boolean[] = [];
    k.onRpcState((u) => ups.push(u));
    k.rpcStart("https://x");
    await flush(10);
    expect(k.rpcUp).toBe(true);
    sessions[0]!.closeFromServer();
    await flush(10);
    expect(k.rpcUp).toBe(false);
    expect(ups).toEqual([true, false]);
    expect((await call(k, "p", {})).status).toBe(503);
    await ft.advance(1300);
    await flush(10);
    expect(k.rpcUp).toBe(true);
    expect((await call(k, "p", { again: 1 })).json.body.input).toEqual({ again: 1 });
    k.rpcStop();
  });
  test("oversize request (>1 MiB) is refused locally with 413; big responses stream through", async () => {
    const big = new Uint8Array(3 << 20).fill(97);
    const { Ctor } = fakeWT({
      async onBidi(req, write, end) {
        await req();
        for (let i = 0; i < big.length; i += 65536) await write(big.subarray(i, i + 65536));
        await end();
      },
    });
    const k = await Kernel.load({ bytes: bytes(), sha256: KERNEL_PIN.sha256, WT: Ctor });
    k.rpcStart("https://x");
    await flush(10);
    expect((await k.rpcCall(new Uint8Array((1 << 20) + 1))).status).toBe(413);
    const r = await k.rpcCall(enc.encode("{}"));
    expect(r.status).toBe(200);
    expect(r.body.length).toBe(big.length);
    k.rpcStop();
  });
  test("a response over 8 MiB is cut with 413, not buffered forever", async () => {
    const chunk = new Uint8Array(1 << 20).fill(1);
    const { Ctor } = fakeWT({
      async onBidi(req, write, end) {
        await req();
        for (let i = 0; i < 10; i++) await write(chunk);
        await end();
      },
    });
    const k = await Kernel.load({ bytes: bytes(), sha256: KERNEL_PIN.sha256, WT: Ctor });
    k.rpcStart("https://x");
    await flush(10);
    expect((await k.rpcCall(enc.encode("{}"))).status).toBe(413);
    k.rpcStop();
  });
});
