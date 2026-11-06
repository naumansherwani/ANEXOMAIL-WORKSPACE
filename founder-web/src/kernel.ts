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

/** Step 5K: does this audit row hash lead to this root through this path (`L:<hex>,R:<hex>`)? The kernel (merkle@1) decides; any failure = false. */
export function merkleVerify(row: string, path: string, root: string): Promise<boolean> {
  return new Promise((resolve) => {
    const id = ++seq;
    waiting.set(id, (m) => resolve(m.code === 0 && m.data === "1"));
    w().postMessage({ id, merkle: { row, path, root } });
  });
}

/** G5a: is the ledger of `second` entries (root `sr`) an extension of the ledger of `first` entries (root `fr`)? RFC 9162 proof, checked by the kernel (merkle@2). Any failure = false. */
export function consistencyVerify(first: number, second: number, fr: string, sr: string, proof: string[]): Promise<boolean | null> {
  return new Promise((resolve) => {
    if (!Number.isSafeInteger(first) || !Number.isSafeInteger(second) || first < 1 || second < first || second > 0xffffffff) { resolve(false); return; }
    const id = ++seq;
    // true = the kernel accepted; false = the kernel REFUSED the proof; null = the kernel could not run at all (never reported as a refusal)
    waiting.set(id, (m) => resolve(m.code === 100 ? null : m.code === 0 && m.data === "1"));
    w().postMessage({ id, consistency: { first, second, fr, sr, proof: proof.join(",") } });
  });
}

/** G5b: is `note` the C2SP signed checkpoint of (size, root) under the audit-log key `pub` (64 hex) named `name`? The kernel (checkpoint@1) decides. true = valid; false = the kernel REFUSED it; null = the kernel could not run (never reported as a refusal). */
export function checkpointVerify(note: string, name: string, pub: string, size: string, root: string): Promise<boolean | null> {
  return new Promise((resolve) => {
    const id = ++seq;
    waiting.set(id, (m) => resolve(m.code === 100 ? null : m.code === 0 && m.data === "1"));
    w().postMessage({ id, checkpoint: { note, name, pub, size, root } });
  });
}

/** G5c: what does this evidence (hex) claim about `digest` (sha256 of the signed note)? kind 1 = RFC 3161 token, 2 = OpenTimestamps file. The kernel (anchor@1) re-derives it.
 *  string = the claim; null = the kernel REFUSED the evidence; undefined = the kernel could not run (never reported as a refusal). */
export function anchorInspect(kind: 1 | 2, ev: string, digest: string): Promise<string | null | undefined> {
  return new Promise((resolve) => {
    const id = ++seq;
    waiting.set(id, (m) => resolve(m.code === 100 ? undefined : m.code === 0 ? String(m.data ?? "") : null));
    w().postMessage({ id, anchor: { kind, ev, digest } });
  });
}

export type PortableReport = { ok: boolean; passed?: string[]; failed_step?: string; problem?: string; facts?: { horizon_cp: number; head_cp: number; horizon_size: number; head_size: number; origin: string; tsa: number; bitcoin: boolean; anchored_ms: number; proof_hashes: number; not_covered_rows: number } };

/** G5d part 3: judge the whole portable bundle (text exactly as sent + its sha256) with the kernel (portable@1). Resolves with the report (ok or the first failed step); undefined = the kernel could not run or answered nonsense (never reported as a refusal). */
export function portableVerify(text: string, sha: string): Promise<PortableReport | undefined> {
  return new Promise((resolve) => {
    const id = ++seq;
    waiting.set(id, (m) => {
      if (m.code !== 0 || typeof m.data !== "string") { resolve(undefined); return; }
      try { const r = JSON.parse(m.data.slice(1)) as PortableReport; resolve(typeof r?.ok === "boolean" && r.ok === (m.data[0] === "1") ? r : undefined); } catch { resolve(undefined); }
    });
    w().postMessage({ id, portable: { text, sha } });
  });
}

export type ActionReport = { ok: boolean; hash?: string; challenge?: string; canonical?: string; problem?: string };
/** J3: re-derive the digest + WebAuthn challenge of a protected action in the kernel (action@1, same rules as the SQL). Resolves with the report; undefined = the kernel could not run (never shown as a refusal). */
export function actionCheck(input: { action: string; target: string; params: Record<string, string>; nonce: string; hash?: string; challenge?: string }): Promise<ActionReport | undefined> {
  return new Promise((resolve) => {
    const id = ++seq;
    waiting.set(id, (m) => {
      if (m.code !== 0 || typeof m.data !== "string") { resolve(undefined); return; }
      try { const r = JSON.parse(m.data.slice(1)) as ActionReport; resolve(typeof r?.ok === "boolean" && r.ok === (m.data[0] === "1") ? r : undefined); } catch { resolve(undefined); }
    });
    w().postMessage({ id, action: { input: JSON.stringify(input) } });
  });
}

export type LeaseData = { type: "vault-lease@1"; device_id: string; serial: number; issued_ms: number; expires_ms: number; ttl_s: number; nonce: string; key_thumb: string; half: string };
export type LeaseClocks = { received_wall_ms: number; received_mono_ms: number; now_wall_ms: number; now_mono_ms: number };
export type LeaseReport = { ok: boolean; state: "live" | "expired" | "refused"; remaining_ms: number; serial?: number; reason?: string };
/** J8c: is this vault lease good for THIS device right now? The kernel (lease@1) judges shape, serial (no replay of an older lease), clock skew and the time left on the MONOTONIC clock. undefined = the kernel could not run. */
export function leaseCheck(data: LeaseData, deviceId: string, pinnedSerial: number, clocks: LeaseClocks): Promise<LeaseReport | undefined> {
  return new Promise((resolve) => {
    const id = ++seq;
    waiting.set(id, (m) => {
      if (m.code !== 0 || typeof m.data !== "string") { resolve(undefined); return; }
      try { const r = JSON.parse(m.data.slice(1)) as LeaseReport; resolve(typeof r?.ok === "boolean" && r.ok === (m.data[0] === "1") ? r : undefined); } catch { resolve(undefined); }
    });
    w().postMessage({ id, lease: { op: "check", input: JSON.stringify({ data, device_id: deviceId, pinned_serial: pinnedSerial, ...clocks }) } });
  });
}
/** J8c: vault key = HKDF-SHA256(local half, server half) computed in the kernel. Resolves with base64url of 32 bytes; undefined = bad input or no kernel. */
export function leaseVaultKey(localHalf: string, serverHalf: string, deviceId: string): Promise<string | undefined> {
  return new Promise((resolve) => {
    const id = ++seq;
    waiting.set(id, (m) => { resolve(m.code === 0 && typeof m.data === "string" && m.data[0] === "1" ? m.data.slice(1) : undefined); });
    w().postMessage({ id, lease: { op: "key", input: JSON.stringify({ local: localHalf, half: serverHalf, device_id: deviceId }) } });
  });
}
