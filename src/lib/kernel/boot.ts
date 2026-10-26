/**
 * ANEXOMAIL WASM KERNEL — app ka ek hi darwaza (Rule 52). Lazy singleton: wasm fetch -> SHA-256 pin check -> ek WebTransport/QUIC
 * connection (rpc@1) + live@1. Kuch bhi fail ho (WebTransport nahi, wasm hash mismatch, server band) to `null` / 503 — caller ka purana
 * fetch/TS raasta chalta rehta hai; kernel kabhi page ko nahi rokta.
 */
import { sessionToken } from "@/lib/api";
import { wtBaseUrl } from "@/lib/wt-url";

import { Kernel, type WTCtor } from "./kernel";
import { KERNEL_PIN } from "./pin.gen";

let loading: Promise<Kernel | null> | null = null;
let ready: Kernel | null = null;

export function kernelIfReady(): Kernel | null {
  return ready;
}

/** Pehli call load shuru karti hai; baad ki calls wahi promise. Server-side (SSR) par hamesha null. */
export function getKernel(): Promise<Kernel | null> {
  if (typeof window === "undefined") return Promise.resolve(null);
  loading ??= (async () => {
    try {
      const WT = (window as unknown as { WebTransport?: WTCtor }).WebTransport;
      const base = wtBaseUrl();
      const res = await fetch(KERNEL_PIN.url, { credentials: "omit", cache: "force-cache" });
      if (!res.ok) return null;
      const k = await Kernel.load({ bytes: await res.arrayBuffer(), sha256: KERNEL_PIN.sha256, WT: WT ?? null });
      if (WT && base) k.rpcStart(base);
      ready = k;
      exposeDiagnostics(k);
      void reportOnce(k, Boolean(WT && base));
      return k;
    } catch {
      return null; // hash mismatch / wasm unsupported => purana raasta
    }
  })();
  return loading;
}

const enc = new TextEncoder();
const dec = new TextDecoder();

export type KernelReply = { status: number; body: unknown };

/** Kernel ke WebTransport par ek proc. `null` = kernel tayyar nahi / session nahi => caller fetch par jaye. */
export async function kernelRpc(proc: string, input: unknown): Promise<KernelReply | null> {
  const k = ready;
  const token = sessionToken.get();
  if (!k || !k.rpcUp || !token) return null; // login ke bagair (public procs) => seedha fetch, wahi jo pehle tha
  const r = await k.rpcCall(enc.encode(JSON.stringify({ token, proc, input: input ?? null })));
  if (r.status !== 200 || r.body.length === 0) return null; // 503/504/413 => fetch
  try {
    const f = JSON.parse(dec.decode(r.body)) as { status?: number; body?: unknown };
    if (f.status === 401) return null; // token purana/refresh ho raha hai: fetch ka authoritative jawab (refresh wahi sambhalta hai)
    return typeof f.status === "number" ? { status: f.status, body: f.body } : null;
  } catch {
    return null;
  }
}

const API = (import.meta.env["VITE_API_URL"] as string | undefined)?.replace(/\/$/, "") ?? "";
let reported = false;

/** Dastoor (E90 Article 9): sirf host, version, wasm hash, transport. Token/email/content kabhi nahi. Fail => chup, page par koi asar nahi. */
async function reportOnce(k: Kernel, wantWt: boolean): Promise<void> {
  if (reported) return;
  reported = true;
  try {
    await new Promise((r) => setTimeout(r, 2500)); // rpc session ko judne ka moqa
    const token = sessionToken.get();
    if (!token) return;
    const transport = wantWt && k.rpcUp ? "webtransport" : "fetch";
    await fetch(`${API}/rpc/kernel.report`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${token}` },
      body: JSON.stringify({ input: { host: window.location.hostname, version: k.info.version, sha256: KERNEL_PIN.sha256, transport } }),
    });
  } catch {
    /* telemetry kabhi kaam nahi rokti */
  }
}

/** Browser console / support ke liye: `anexoKernel.rpcUp`, `.info`, `.version`. Sirf padhne wale getters; koi secret nahi. */
function exposeDiagnostics(k: Kernel): void {
  try {
    Object.defineProperty(window, "anexoKernel", {
      configurable: true,
      value: Object.freeze({
        get rpcUp() {
          return k.rpcUp;
        },
        get info() {
          return k.info;
        },
        version: KERNEL_PIN.version,
        sha256: KERNEL_PIN.sha256,
      }),
    });
  } catch {
    /* diagnostics optional */
  }
}
