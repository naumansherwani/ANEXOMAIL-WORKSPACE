// F2b: the WASM kernel runs here, off the UI thread (Rule 52: Worker). It only verifies; it never touches the DOM or the network except to fetch its own .wasm.
import { KERNEL } from "./kernel.pin";

type Ex = { memory: WebAssembly.Memory; kernel_alloc(n: number): number; kernel_free(p: number, n: number): void; kernel_out_ptr(): number; kernel_out_len(): number; envelope_verify(p: number, l: number, now: number, skew: number): number };
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

self.onmessage = async (ev: MessageEvent<{ id: number; body: ArrayBuffer; now: number; skew: number; warm?: boolean }>) => {
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
