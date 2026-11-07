// J8d — vault lease: the pure parts (no DOM, no network), so they are unit-tested. Technology: TypeScript strict. The judge of "is this lease good" is the WASM kernel (lease@1 through kernel.ts);
// the proof format must match the Rust verifier (server/founder/src/lease.rs `verify_proof`): message `anexo-lease-proof@1|<device uuid, lower>|<ts ms>`, signature = raw r||s (WebCrypto ECDSA P-256 output), JWK {kty,crv,x,y}.

export const PROOF_PREFIX = "anexo-lease-proof@1";
export const proofText = (deviceUuid: string, tsMs: number): string => `${PROOF_PREFIX}|${deviceUuid.toLowerCase()}|${Math.trunc(tsMs)}`;

export function b64u(bytes: Uint8Array): string {
  let s = ""; for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
export function b64uDecode(t: string): Uint8Array<ArrayBuffer> {
  const pad = "=".repeat((4 - (t.length % 4)) % 4);
  const bin = atob((t + pad).replace(/-/g, "+").replace(/_/g, "/"));
  const out = new Uint8Array(new ArrayBuffer(bin.length)); for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i); return out;
}

export type Phase = "starting" | "live" | "expired" | "locked" | "waiting" | "off";
export type Why = string | undefined;

/** Refusals that are final for this device: renewing again would only repeat the refusal. The vault stays locked until the founder approves a new device. */
const FINAL = new Set(["revoked", "not_approved", "not_your_device", "unknown_device", "key_mismatch"]);
export type Next = { phase: Phase; retryMs: number | null; wipe: boolean; text: string };

/** What the page does after a renew call failed. `attempt` counts failures in a row (1 = first). */
export function afterFailure(status: number, why: Why, attempt: number): Next {
  const n = Math.max(1, attempt);
  if (why && FINAL.has(why)) return { phase: "locked", retryMs: null, wipe: true, text: why === "revoked" ? "This device was revoked. Its vault stays locked." : why === "key_mismatch" ? "This is not the device key the lease was bound to. The vault stays locked." : "This device is not approved. The vault stays locked." };
  if (status === 429) return { phase: "waiting", retryMs: Math.min(30_000 * n, 300_000), wipe: false, text: why === "too_many" ? "Too many renewals this hour. Waiting before the next try." : "Renewed a moment ago. Trying again shortly." };
  if (status === 409) return { phase: "waiting", retryMs: Math.min(60_000 * n, 300_000), wipe: false, text: why === "proof_replayed" ? "That device proof was already used. Trying again with a fresh one." : "The server clock went backwards. Waiting." };
  if (why === "key_required" || why === "proof_stale") return n >= 3 ? { phase: "waiting", retryMs: 120_000, wipe: false, text: "The device proof keeps being refused. Check that this device clock is right." } : { phase: "waiting", retryMs: 5_000 * n, wipe: false, text: "The device proof was out of date. Trying again." };
  if (status === 0 || status >= 500 || status === 503) return { phase: "waiting", retryMs: Math.min(5_000 * 2 ** (n - 1), 300_000), wipe: false, text: "The server could not be reached. The vault locks itself when the lease ends." };
  return { phase: "waiting", retryMs: Math.min(15_000 * n, 300_000), wipe: false, text: "The lease could not be renewed. Trying again." };
}

/** When to ask for the next lease: at 40% of the lease left (a 15 min lease renews at 6 min left), never sooner than 5 s, never later than 5 min from now. */
export function nextRenewMs(remainingMs: number, ttlMs: number): number {
  if (!(remainingMs > 0)) return 0;
  const target = Math.max(0, remainingMs - ttlMs * 0.4);
  return Math.min(Math.max(target, 5_000), 300_000);
}

export const secondsLeft = (remainingMs: number): number => Math.max(0, Math.floor(remainingMs / 1000));
export function clockText(sec: number): string { const m = Math.floor(sec / 60), s = sec % 60; return `${m}:${String(s).padStart(2, "0")}`; }

export const SERIAL_KEY = (device: string) => `anexo.lease.serial.${device.toLowerCase()}`;
/** The highest serial ever accepted on this device: an older lease is a replay (the kernel refuses it). Stored as a plain integer; anything else counts as 0. */
export function parseSerial(v: string | null): number { const n = Number(v); return Number.isInteger(n) && n >= 0 && n < 2 ** 53 ? n : 0; }

/** The words for the card. Only states the server and the kernel can actually reach. */
export function phaseText(phase: Phase, secs: number): { title: string; tone: "ok" | "warn" | "fail" | "off"; sub: string } {
  switch (phase) {
    case "live": return { title: `Unlocked, locks itself in ${clockText(secs)}`, tone: "ok", sub: "The server renews this automatically while the device is approved." };
    case "starting": return { title: "Getting the lease…", tone: "off", sub: "Asking the server for a short lease for this device." };
    case "waiting": return { title: "Waiting to renew", tone: "warn", sub: "The last lease is still counting down." };
    case "expired": return { title: "Locked: the lease ended", tone: "fail", sub: "The vault key was wiped from memory. It comes back with the next lease." };
    case "locked": return { title: "Locked for good on this device", tone: "fail", sub: "The server will not renew it." };
    default: return { title: "Off", tone: "off", sub: "No lease is running." };
  }
}

/** Device list row state from GET /founder/v1/vault/status. */
export type DeviceRow = { device_id: string; label: string; state: "live" | "expired" | "revoked" | "none"; seconds_left: number; serial?: number | null; chain_head?: string | null; issued_last_hour?: number };
export function sortRows(rows: DeviceRow[], mine: string | null): DeviceRow[] {
  const rank = { live: 0, expired: 1, none: 2, revoked: 3 } as const;
  return [...rows].sort((a, b) => (a.device_id === mine ? -1 : b.device_id === mine ? 1 : 0) || rank[a.state] - rank[b.state] || a.label.localeCompare(b.label));
}
