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
let pending = true; // kernel load abhi chal raha hai

/** Haqeeqat ki ginti: kitni calls kernel (WebTransport) se gayin, kitni fetch par; kitni tag ke saath. `anexoKernel.stats` se dikhti hai. */
const stats = { kernel: 0, fetch: 0, tagged: 0, untagged: 0, ticketOk: 0, ticketFail: 0, lastFallback: "" };
/** Kaun se procs fetch par gaye (Bun fallback / kernel nahi) — migration ka asli bacha hua kaam. Max 80 naam. */
const fallbackProcs: Record<string, string> = {};
export function noteFetch(reason = "fetch", proc = ""): void {
  stats.fetch++;
  stats.lastFallback = reason;
  if (proc && (proc in fallbackProcs || Object.keys(fallbackProcs).length < 80)) fallbackProcs[proc] = reason;
}

/**
 * Kernel ko page ke saath hi jagao (pehli use ka intezar nahi). AppShell mount par idle mein. SSR par kuch nahi.
 */
export function warmKernel(): void {
  if (typeof window === "undefined") return;
  const go = () => void getKernel();
  const ric = (window as unknown as { requestIdleCallback?: (f: () => void, o?: { timeout: number }) => number }).requestIdleCallback;
  if (ric) ric(go, { timeout: 1500 });
  else setTimeout(go, 0);
}

/* ---- E90 request tag: ticket (15 min) + session key. Key sirf memory mein (window par nahi), kernel hmac@1 se har request par tag. ---- */
type Ticket = { ticket: string; key: Uint8Array; expMs: number };
let tk: Ticket | null = null;
let tkLoading: Promise<void> | null = null;

async function ensureTicket(): Promise<void> {
  if (tk && tk.expMs - Date.now() > 60_000) return;
  tkLoading ??= (async () => {
    try {
      const token = sessionToken.get();
      if (!token) return;
      const res = await fetch(`${API}/rpc/kernel.ticket`, {
        method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${token}` },
        body: JSON.stringify({ input: { host: window.location.hostname } }),
      });
      if (!res.ok) throw new Error(String(res.status));
      const j = (await res.json()) as { result?: { data?: Record<string, unknown> } } & Record<string, unknown>;
      const d = (j.result?.data ?? j) as { ticket?: string; session_key?: string; expires_at?: string };
      if (!d.ticket || !d.session_key) throw new Error("bad_ticket");
      tk = { ticket: d.ticket, key: enc.encode(d.session_key), expMs: d.expires_at ? Date.parse(d.expires_at) : Date.now() + 840_000 };
      stats.ticketOk++;
    } catch {
      stats.ticketFail++;
      tk = null;
    } finally {
      tkLoading = null;
    }
  })();
  await tkLoading;
}

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
      if (!res.ok) {
        pending = false;
        return null;
      }
      const k = await Kernel.load({ bytes: await res.arrayBuffer(), sha256: KERNEL_PIN.sha256, WT: WT ?? null });
      if (WT && base) k.rpcStart(base);
      ready = k;
      exposeDiagnostics(k);
      void ensureTicket();
      void reportOnce(k, Boolean(WT && base));
      pending = false;
      return k;
    } catch {
      pending = false;
      return null; // hash mismatch / wasm unsupported => purana raasta
    }
  })();
  return loading;
}

const enc = new TextEncoder();
const dec = new TextDecoder();

export type KernelReply = { status: number; body: unknown };

/** Early-boot: page ki pehli calls kernel ke jaagne se pehle chal parti thin (kernel_not_used). Ab thora sa (max EARLY_WAIT_MS) intezar,
 *  sirf jab kernel abhi load/connect ho raha ho. Kernel ban chuka ya mumkin hi nahi (WebTransport nahi / load fail) => foran jawab, koi intezar nahi. */
export const EARLY_WAIT_MS = 400;
let settledNoKernel = false;

export async function waitUntil(cond: () => boolean, maxMs: number, stepMs = 20): Promise<boolean> {
  const t0 = Date.now();
  while (!cond()) {
    if (Date.now() - t0 >= maxMs) return false;
    await new Promise((r) => setTimeout(r, stepMs));
  }
  return true;
}

async function kernelForCall(): Promise<Kernel | null> {
  if (ready && ready.rpcUp) return ready;
  if (settledNoKernel || typeof window === "undefined") return null;
  const hasWT = typeof (window as unknown as { WebTransport?: unknown }).WebTransport === "function";
  if (!hasWT) {
    settledNoKernel = true;
    return null;
  }
  const t0 = Date.now();
  const k = await Promise.race([getKernel(), new Promise<null>((r) => setTimeout(() => r(null), EARLY_WAIT_MS))]);
  if (!k) {
    if (!loadPending()) settledNoKernel = true; // load poora hua aur null nikla => kernel nahi, dobara intezar nahi
    return null;
  }
  if (k.rpcUp) return k;
  const left = EARLY_WAIT_MS - (Date.now() - t0);
  return left > 0 && (await waitUntil(() => k.rpcUp, left)) ? k : null;
}

function loadPending(): boolean {
  return pending;
}


/** Kernel ke WebTransport par ek proc. `null` = kernel tayyar nahi / session nahi => caller fetch par jaye. */
export async function kernelRpc(proc: string, input: unknown): Promise<KernelReply | null> {
  const token = sessionToken.get();
  if (!token) return null; // login ke bagair (public procs) => seedha fetch, wahi jo pehle tha
  const k = await kernelForCall();
  if (!k) return null;
  const inputText = JSON.stringify(input ?? null);
  const env: Record<string, unknown> = { token, proc };
  if (proc !== "kernel.ticket" && proc !== "kernel.report") await ensureTicket();
  if (tk && proc !== "kernel.ticket" && proc !== "kernel.report") {
    const ts = String(Math.floor(Date.now() / 1000));
    const hash = k.sha256Bytes(enc.encode(inputText));
    env["ticket"] = tk.ticket;
    env["ts"] = ts;
    env["tag"] = k.hmacSha256(tk.key, enc.encode(`${proc}.${ts}.${hash}`));
    stats.tagged++;
  } else {
    stats.untagged++;
  }
  // input ka text wahi jo hash hua (server input_raw ka hash isi se match karta hai)
  const body = JSON.stringify(env).slice(0, -1) + `,"input":${inputText}}`;
  const r = await k.rpcCall(enc.encode(body));
  if (r.status !== 200 || r.body.length === 0) return null; // 503/504/413 => fetch
  try {
    const f = JSON.parse(dec.decode(r.body)) as { status?: number; body?: unknown };
    if (f.status === 401) {
      tk = null; // token/ticket purana: dobara lo; is call ka authoritative jawab fetch se
      return null;
    }
    if (typeof f.status !== "number") return null;
    stats.kernel++;
    return { status: f.status, body: f.body };
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
        get stats() {
          return { ...stats, tagReady: tk !== null };
        },
        get fallbackProcs() {
          return { ...fallbackProcs };
        },
        version: KERNEL_PIN.version,
        sha256: KERNEL_PIN.sha256,
      }),
    });
  } catch {
    /* diagnostics optional */
  }
}
