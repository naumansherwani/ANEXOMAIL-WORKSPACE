// F2b (Rule 52): every /founder/v1 answer is verified by the WASM kernel (Rust, Ed25519, pinned key) BEFORE any of it is parsed or shown.
// Enforce mode: if the kernel cannot start or the check fails, no data reaches the screen.
import workerUrl from "./kernel.worker.ts?worker&url"; // Vite bundles the worker as its own file and gives its URL

export type Verdict = { ok: true; data: string } | { ok: false; code: number; reason: string };

const REASON: Record<number, string> = {
  1: "The answer was malformed.",
  2: "The answer was not signed.",
  3: "The answer was signed with an unknown key.",
  4: "The answer is too old or this device's clock is wrong.",
  5: "The signature does not match: the answer was altered.",
  6: "The answer was ambiguous (duplicate field).",
  100: "The security kernel could not start.",
};

let worker: Worker | null = null;
let seq = 0;
const waiting = new Map<number, (m: { code: number; data?: string; error?: string }) => void>();

// The server sends `require-trusted-types-for 'script'`: a Worker URL must be a TrustedScriptURL. One narrow policy: only our own /_cc/assets/ scripts.
const ttPolicy = (window as unknown as { trustedTypes?: { createPolicy(n: string, o: { createScriptURL(u: string): string }): { createScriptURL(u: string): string } } }).trustedTypes?.createPolicy("anexo-kernel-worker", {
  createScriptURL(u: string) { const x = new URL(u, location.href); if (x.origin !== location.origin || !x.pathname.startsWith("/_cc/assets/")) throw new Error("blocked worker url"); return x.href; },
});

function w(): Worker {
  if (!worker) {
    const href = workerUrl, early = (window as unknown as { __kw?: Worker }).__kw; // early.js may already have started it
    worker = early ?? new Worker((ttPolicy ? ttPolicy.createScriptURL(href) : href) as string, { type: "module" });
    worker.onmessage = (ev) => { const f = waiting.get(ev.data.id); if (f) { waiting.delete(ev.data.id); f(ev.data); } };
    worker.onerror = () => { for (const [id, f] of waiting) { waiting.delete(id); f({ code: 100 }); } };
  }
  return worker;
}

/** Start the worker and compile the kernel right at page start, in parallel with the first data calls (page refresh no longer waits for it). */
export const warmKernel = () => { try { w().postMessage({ warm: true }); } catch { /* verify will report */ } };

export type TrustState = "starting" | "verified" | "failed";
let state: TrustState = "starting", detail = "";
const subs = new Set<() => void>();
export const trust = { get: () => ({ state, detail }), sub: (f: () => void) => { subs.add(f); return () => { subs.delete(f); }; } };
function set(s: TrustState, d: string) { state = s; detail = d; subs.forEach((f) => f()); }

/** Verify a raw response body. Resolves with the signed `data` text, or a refusal (never both). */
export function verifyBody(body: ArrayBuffer, skewSecs = 120, quiet = false): Promise<Verdict> {
  return new Promise((resolve) => {
    const id = ++seq;
    waiting.set(id, (m) => {
      if (m.code === 0 && m.data !== undefined) { if (!quiet) set("verified", "Signature checked by the WASM kernel"); resolve({ ok: true, data: m.data }); }
      else { const reason = REASON[m.code] ?? "Verification failed."; if (!quiet) set("failed", reason); resolve({ ok: false, code: m.code, reason }); }
    });
    w().postMessage({ id, body, now: Math.floor(Date.now() / 1000), skew: skewSecs }, [body]);
  });
}
