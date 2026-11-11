// F2b: the WASM kernel runs here, off the UI thread (Rule 52: Worker). It only verifies; it never touches the DOM or the network except to fetch its own .wasm.
import { KERNEL } from "./kernel.pin";
import { createHost, type HostExports, type WtCtor } from "./kernel.host";

type Ex = { memory: WebAssembly.Memory; kernel_alloc(n: number): number; kernel_free(p: number, n: number): void; kernel_out_ptr(): number; kernel_out_len(): number; envelope_verify(p: number, l: number, now: number, skew: number): number; merkle_verify(r: number, rl: number, p: number, pl: number, o: number, ol: number): number; merkle_consistency_verify(a: number, b: number, fr: number, frl: number, sr: number, srl: number, p: number, pl: number): number; anchor_inspect(kind: number, e: number, el: number, d: number, dl: number): number; checkpoint_verify(n: number, nl: number, nm: number, nml: number, pk: number, pkl: number, sz: number, szl: number, rt: number, rtl: number): number; portable_verify(t: number, tl: number, s: number, sl: number): number; lease_check(p: number, l: number): number; lease_vault_key(p: number, l: number): number; action_check(p: number, l: number): number; flive_start(u: number, ul: number, t: number, tl: number, seed: number): number; flive_set_token(h: number, t: number, tl: number): void; flive_stop(h: number): void } & HostExports;
const hex = (b: ArrayBuffer) => [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
let ex: Promise<Ex> | null = null;

function load(): Promise<Ex> {
  ex ??= (async () => {
    const buf = await (await fetch(KERNEL.url, { cache: "force-cache" })).arrayBuffer();
    if (hex(await crypto.subtle.digest("SHA-256", buf)) !== KERNEL.sha256) throw new Error("kernel hash mismatch"); // pinned: wrong bytes never run
    let kx: Ex | null = null; // K6.3: the REAL host ABI (WebTransport, timers, clock) for the kernel's async modules (flive@1); verify-only calls never use it
    const host = createHost((self as unknown as { WebTransport?: WtCtor }).WebTransport ?? null, () => kx as Ex, (kind, a, b, data) => (self as unknown as Worker).postMessage({ flive: true, kind, a, b, data }, [data.buffer]));
    const { instance } = await WebAssembly.instantiate(buf, host as unknown as WebAssembly.Imports);
    kx = instance.exports as unknown as Ex;
    return kx;
  })();
  return ex;
}

self.onmessage = async (ev: MessageEvent<{ id: number; flive?: { op: "start" | "token" | "stop"; url?: string; token?: string; h?: number }; body: ArrayBuffer; now: number; skew: number; warm?: boolean; merkle?: { row: string; path: string; root: string }; portable?: { text: string; sha: string }; lease?: { op: "check" | "key"; input: string }; action?: { input: string }; consistency?: { first: number; second: number; fr: string; sr: string; proof: string }; checkpoint?: { note: string; name: string; pub: string; size: string; root: string }; anchor?: { kind: number; ev: string; digest: string } }>) => {
  if (ev.data.flive) { // K6.3: live over WebTransport, run by the kernel (flive@1, Rust/Tokio); this only starts/stops it and forwards its emits
    const { id, flive: a } = ev.data;
    try {
      const k = await load(), enc = new TextEncoder(), put = (t: string) => { const b = enc.encode(t), p = k.kernel_alloc(Math.max(b.length, 1)); new Uint8Array(k.memory.buffer, p, b.length).set(b); return [p, b.length] as const; };
      let h = a.h ?? 0;
      if (a.op === "start") { const [u, t] = [put(a.url ?? ""), put(a.token ?? "")]; h = k.flive_start(u[0], u[1], t[0], t[1], (crypto.getRandomValues(new Uint32Array(1))[0] | 1) >>> 0); for (const x of [u, t]) k.kernel_free(x[0], Math.max(x[1], 1)); }
      else if (a.op === "token") { const t = put(a.token ?? ""); k.flive_set_token(h, t[0], t[1]); k.kernel_free(t[0], Math.max(t[1], 1)); }
      else k.flive_stop(h);
      (self as unknown as Worker).postMessage({ id, code: 0, data: String(h) });
    } catch (e) { (self as unknown as Worker).postMessage({ id, code: 100, error: String(e) }); }
    return;
  }
  const rp = (ev.data as unknown as { id: number; rpc?: { op: "start" | "call" | "stop"; base?: string; cid?: number; bytes?: ArrayBuffer } }); // K8d: the founder API over the kernel's WebTransport session (rpc@1, Rust/Tokio)
  if (rp.rpc) {
    const { id, rpc: a } = rp;
    try {
      const k = (await load()) as unknown as { memory: WebAssembly.Memory; kernel_alloc(n: number): number; kernel_free(p: number, n: number): void; rpc_start(p: number, l: number, seed: number): void; rpc_call(cid: number, p: number, l: number): void; rpc_stop(): void };
      const put = (b: Uint8Array) => { const p = k.kernel_alloc(Math.max(b.length, 1)); new Uint8Array(k.memory.buffer, p, b.length).set(b); return [p, b.length] as const; };
      if (a.op === "start") { const u = put(new TextEncoder().encode(a.base ?? "")); k.rpc_start(u[0], u[1], (crypto.getRandomValues(new Uint32Array(1))[0] | 1) >>> 0); k.kernel_free(u[0], Math.max(u[1], 1)); }
      else if (a.op === "call") { const b = put(new Uint8Array(a.bytes ?? new ArrayBuffer(0))); k.rpc_call(a.cid ?? 0, b[0], b[1]); k.kernel_free(b[0], Math.max(b[1], 1)); }
      else k.rpc_stop();
      (self as unknown as Worker).postMessage({ id, code: 0, data: "ok" });
    } catch (e) { (self as unknown as Worker).postMessage({ id, code: 100, error: String(e) }); }
    return;
  }
  if (ev.data.merkle) { // step 5K: audit-ledger inclusion proof checked by the kernel (merkle@1) in this browser
    const { id, merkle: m } = ev.data;
    try {
      const k = await load(), enc = new TextEncoder(), put = (t: string) => { const b = enc.encode(t), p = k.kernel_alloc(Math.max(b.length, 1)); new Uint8Array(k.memory.buffer, p, b.length).set(b); return [p, b.length] as const; };
      const [r, p, o] = [put(m.row), put(m.path), put(m.root)], code = k.merkle_verify(r[0], r[1], p[0], p[1], o[0], o[1]);
      for (const x of [r, p, o]) k.kernel_free(x[0], Math.max(x[1], 1));
      (self as unknown as Worker).postMessage({ id, code: code === 1 ? 0 : 1, data: code === 1 ? "1" : "0" });
    } catch (e) { (self as unknown as Worker).postMessage({ id, code: 100, error: String(e) }); }
    return;
  }
  if (ev.data.consistency) { // G5a: RFC 9162 consistency proof between two roots, checked by the kernel (merkle@2) in this browser
    const { id, consistency: c } = ev.data;
    try {
      const k = await load(), enc = new TextEncoder(), put = (t: string) => { const b = enc.encode(t), p = k.kernel_alloc(Math.max(b.length, 1)); new Uint8Array(k.memory.buffer, p, b.length).set(b); return [p, b.length] as const; };
      const [f, s2, p] = [put(c.fr), put(c.sr), put(c.proof)], code = k.merkle_consistency_verify(c.first, c.second, f[0], f[1], s2[0], s2[1], p[0], p[1]);
      for (const x of [f, s2, p]) k.kernel_free(x[0], Math.max(x[1], 1));
      (self as unknown as Worker).postMessage({ id, code: code === 1 ? 0 : 1, data: code === 1 ? "1" : "0" });
    } catch (e) { (self as unknown as Worker).postMessage({ id, code: 100, error: String(e) }); }
    return;
  }
  if (ev.data.checkpoint) { // G5b: C2SP signed checkpoint (Ed25519 by the audit-log key) checked by the kernel (checkpoint@1) in this browser
    const { id, checkpoint: c } = ev.data;
    try {
      const k = await load(), enc = new TextEncoder(), put = (t: string) => { const b = enc.encode(t), p = k.kernel_alloc(Math.max(b.length, 1)); new Uint8Array(k.memory.buffer, p, b.length).set(b); return [p, b.length] as const; };
      const a = [put(c.note), put(c.name), put(c.pub), put(c.size), put(c.root)], code = k.checkpoint_verify(a[0][0], a[0][1], a[1][0], a[1][1], a[2][0], a[2][1], a[3][0], a[3][1], a[4][0], a[4][1]);
      for (const x of a) k.kernel_free(x[0], Math.max(x[1], 1));
      (self as unknown as Worker).postMessage({ id, code: code === 1 ? 0 : 1, data: code === 1 ? "1" : "0" });
    } catch (e) { (self as unknown as Worker).postMessage({ id, code: 100, error: String(e) }); }
    return;
  }
  if (ev.data.lease) { // J8c: the vault lease (shape, serial, clock skew, monotonic time left) judged by the kernel (lease@1); or the vault key = HKDF(local half, server half)
    const { id, lease: a } = ev.data;
    try {
      const k = await load(), x = new TextEncoder().encode(a.input), p = k.kernel_alloc(Math.max(x.length, 1));
      new Uint8Array(k.memory.buffer, p, x.length).set(x);
      const ok = a.op === "key" ? k.lease_vault_key(p, x.length) : k.lease_check(p, x.length), out = new TextDecoder().decode(new Uint8Array(k.memory.buffer, k.kernel_out_ptr(), k.kernel_out_len()).slice());
      k.kernel_free(p, Math.max(x.length, 1));
      (self as unknown as Worker).postMessage({ id, code: 0, data: (ok === 1 ? "1" : "0") + out });
    } catch (e) { (self as unknown as Worker).postMessage({ id, code: 100, error: String(e) }); }
    return;
  }
  if (ev.data.action) { // J3: the protected action's canonical text, digest and WebAuthn challenge re-derived by the kernel (action@1) BEFORE the key is touched
    const { id, action: a } = ev.data;
    try {
      const k = await load(), x = new TextEncoder().encode(a.input), p = k.kernel_alloc(Math.max(x.length, 1));
      new Uint8Array(k.memory.buffer, p, x.length).set(x);
      const ok = k.action_check(p, x.length), out = new TextDecoder().decode(new Uint8Array(k.memory.buffer, k.kernel_out_ptr(), k.kernel_out_len()).slice());
      k.kernel_free(p, Math.max(x.length, 1));
      (self as unknown as Worker).postMessage({ id, code: 0, data: (ok === 1 ? "1" : "0") + out });
    } catch (e) { (self as unknown as Worker).postMessage({ id, code: 100, error: String(e) }); }
    return;
  }
  if (ev.data.portable) { // G5d part 3: the whole pin-portability bundle (sha, shape, horizon, head, outside time, consistency) judged by the kernel (portable@1) in this browser
    const { id, portable: b } = ev.data;
    try {
      const k = await load(), enc = new TextEncoder(), put = (t: string) => { const x = enc.encode(t), p = k.kernel_alloc(Math.max(x.length, 1)); new Uint8Array(k.memory.buffer, p, x.length).set(x); return [p, x.length]; };
      const [t, h] = [put(b.text), put(b.sha)], ok = k.portable_verify(t[0], t[1], h[0], h[1]);
      const out = new TextDecoder().decode(new Uint8Array(k.memory.buffer, k.kernel_out_ptr(), k.kernel_out_len()).slice()); // the JSON report is there whether ok or not
      for (const x of [t, h]) k.kernel_free(x[0], Math.max(x[1], 1));
      (self as unknown as Worker).postMessage({ id, code: 0, data: (ok === 1 ? "1" : "0") + out });
    } catch (e) { (self as unknown as Worker).postMessage({ id, code: 100, error: String(e) }); }
    return;
  }
  if (ev.data.anchor) { // G5c: what an RFC 3161 token / OpenTimestamps proof claims about the note digest, re-derived by the kernel (anchor@1) in this browser
    const { id, anchor: a } = ev.data;
    try {
      const k = await load(), enc = new TextEncoder(), put = (t: string) => { const b = enc.encode(t), p = k.kernel_alloc(Math.max(b.length, 1)); new Uint8Array(k.memory.buffer, p, b.length).set(b); return [p, b.length] as const; };
      const [e, d] = [put(a.ev), put(a.digest)], code = k.anchor_inspect(a.kind, e[0], e[1], d[0], d[1]);
      const out = code === 1 ? new TextDecoder().decode(new Uint8Array(k.memory.buffer, k.kernel_out_ptr(), k.kernel_out_len()).slice()) : "";
      for (const x of [e, d]) k.kernel_free(x[0], Math.max(x[1], 1));
      (self as unknown as Worker).postMessage({ id, code: code === 1 ? 0 : 1, data: out });
    } catch (e) { (self as unknown as Worker).postMessage({ id, code: 100, error: String(e) }); }
    return;
  }
  if (ev.data.warm) { try { await load(); } catch { /* the first real verify reports the error */ } return; } // refresh speed: fetch + hash + compile the kernel while the data calls are still in flight
  const { id, body, now, skew } = ev.data;
  try {
    const k = await load();
    const src = new Uint8Array(body), p = k.kernel_alloc(src.length);
    new Uint8Array(k.memory.buffer, p, src.length).set(src);
    const code = k.envelope_verify(p, src.length, now, skew);
    let data: string | undefined;
    if (code === 0) { // verified: only now is the signed `data` slice turned into text (verify first, then parse)
      const o = new DataView(k.memory.buffer, k.kernel_out_ptr(), 8);
      data = new TextDecoder().decode(src.subarray(o.getUint32(0, true), o.getUint32(4, true)));
    }
    k.kernel_free(p, src.length);
    (self as unknown as Worker).postMessage({ id, code, data });
  } catch (e) {
    (self as unknown as Worker).postMessage({ id, code: 100, error: String(e) }); // kernel could not start
  }
};
