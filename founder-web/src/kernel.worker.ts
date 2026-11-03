// F2b: the WASM kernel runs here, off the UI thread (Rule 52: Worker). It only verifies; it never touches the DOM or the network except to fetch its own .wasm.
import { KERNEL } from "./kernel.pin";

type Ex = { memory: WebAssembly.Memory; kernel_alloc(n: number): number; kernel_free(p: number, n: number): void; kernel_out_ptr(): number; kernel_out_len(): number; envelope_verify(p: number, l: number, now: number, skew: number): number; merkle_verify(r: number, rl: number, p: number, pl: number, o: number, ol: number): number; merkle_consistency_verify(a: number, b: number, fr: number, frl: number, sr: number, srl: number, p: number, pl: number): number; anchor_inspect(kind: number, e: number, el: number, d: number, dl: number): number; checkpoint_verify(n: number, nl: number, nm: number, nml: number, pk: number, pkl: number, sz: number, szl: number, rt: number, rtl: number): number; portable_verify(t: number, tl: number, s: number, sl: number): number };
const hex = (b: ArrayBuffer) => [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
let ex: Promise<Ex> | null = null;

function load(): Promise<Ex> {
  ex ??= (async () => {
    const buf = await (await fetch(KERNEL.url, { cache: "force-cache" })).arrayBuffer();
    if (hex(await crypto.subtle.digest("SHA-256", buf)) !== KERNEL.sha256) throw new Error("kernel hash mismatch"); // pinned: wrong bytes never run
    const { instance } = await WebAssembly.instantiate(buf, { env: { host_wake() {}, host_call() {}, host_emit() {} } });
    return instance.exports as unknown as Ex;
  })();
  return ex;
}

self.onmessage = async (ev: MessageEvent<{ id: number; body: ArrayBuffer; now: number; skew: number; warm?: boolean; merkle?: { row: string; path: string; root: string }; portable?: { text: string; sha: string }; consistency?: { first: number; second: number; fr: string; sr: string; proof: string }; checkpoint?: { note: string; name: string; pub: string; size: string; root: string }; anchor?: { kind: number; ev: string; digest: string } }>) => {
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
