// J8d — the vault lease engine in the browser. Technology: WebCrypto (non-extractable ECDSA P-256 device key in IndexedDB) + WASM kernel lease@1 (judges every lease) + signed answers from the Rust server.
// This module only holds the key in MEMORY while a lease is live. Nothing is encrypted with it yet (consumers come later); that is said plainly on the card.
import { deviceUuid, get, post } from "./api";
import { leaseCheck, leaseVaultKey, type LeaseData } from "./kernel";
import { SERIAL_KEY, afterFailure, b64u, nextRenewMs, parseSerial, proofText, secondsLeft, type Phase } from "./lease_pure";

export type LeaseView = { phase: Phase; secs: number; serial: number; device: string | null; text: string; hasKey: boolean; renewing: boolean };
let view: LeaseView = { phase: "off", secs: 0, serial: 0, device: null, text: "", hasKey: false, renewing: false };
const subs = new Set<() => void>();
const set = (p: Partial<LeaseView>) => { view = { ...view, ...p }; subs.forEach((f) => f()); };
export const leaseView = () => view;
export const leaseSubscribe = (f: () => void) => { subs.add(f); return () => { subs.delete(f); }; };

// ---- device key + local half: IndexedDB, the private key is non-extractable (the browser itself refuses to export it) ----
type Rec = { id: string; pair: CryptoKeyPair; local: string };
const DB = "anexo-vault", STORE = "device";
const idb = (): Promise<IDBDatabase> => new Promise((ok, no) => { const r = indexedDB.open(DB, 1); r.onupgradeneeded = () => r.result.createObjectStore(STORE, { keyPath: "id" }); r.onsuccess = () => ok(r.result); r.onerror = () => no(r.error); });
const idbGet = async (id: string): Promise<Rec | undefined> => { const d = await idb(); return new Promise((ok, no) => { const q = d.transaction(STORE).objectStore(STORE).get(id); q.onsuccess = () => ok(q.result as Rec | undefined); q.onerror = () => no(q.error); }); };
const idbPut = async (r: Rec): Promise<void> => { const d = await idb(); return new Promise((ok, no) => { const t = d.transaction(STORE, "readwrite"); t.objectStore(STORE).put(r); t.oncomplete = () => ok(); t.onerror = () => no(t.error); }); };
const idbDel = async (id: string): Promise<void> => { try { const d = await idb(); await new Promise<void>((ok) => { const t = d.transaction(STORE, "readwrite"); t.objectStore(STORE).delete(id); t.oncomplete = () => ok(); t.onerror = () => ok(); }); } catch { /* nothing to delete */ } };

async function material(device: string): Promise<Rec> {
  const have = await idbGet(device); if (have) return have;
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, false, ["sign", "verify"]) as CryptoKeyPair;
  const rec: Rec = { id: device, pair, local: b64u(crypto.getRandomValues(new Uint8Array(32))) };
  await idbPut(rec); return rec;
}

// ---- engine state (memory only) ----
let key: string | null = null, serverHalf: string | null = null, data: LeaseData | null = null, rWall = 0, rMono = 0;
let renewT: ReturnType<typeof setTimeout> | undefined, tickT: ReturnType<typeof setInterval> | undefined, fails = 0, running = false, locked = false;
const lsGet = (k: string) => { try { return window.localStorage.getItem(k); } catch { return null; } };
const lsSet = (k: string, v: string) => { try { window.localStorage.setItem(k, v); } catch { /* private window */ } };

/** The vault key is readable only while the lease is live; this is the ONLY door to it. */
export const vaultKey = (): string | null => (view.phase === "live" ? key : null);

function wipe() { key = null; serverHalf = null; data = null; set({ hasKey: false }); }
function clock() { return { received_wall_ms: rWall, received_mono_ms: rMono, now_wall_ms: Date.now(), now_mono_ms: Math.round(performance.now()) }; }

async function tick() {
  if (!data || !view.device) return;
  const rep = await leaseCheck(data, view.device, data.serial - 1 /* the lease in hand is judged against "one older", so it is not a replay of itself */, clock());
  if (!rep) return;
  if (rep.state === "live") set({ secs: secondsLeft(rep.remaining_ms), phase: "live" });
  else { wipe(); set({ phase: locked ? "locked" : "expired", secs: 0, text: "" }); schedule(2_000); }
}

function schedule(ms: number) { clearTimeout(renewT); if (!locked) renewT = setTimeout(() => void renew(), ms); }

/** Ask the server for a lease: sign a fresh proof with the non-extractable key, let the kernel judge the answer, derive the vault key. Never throws. */
export async function renew(): Promise<void> {
  if (!view.device || locked || view.renewing) return;
  set({ renewing: true });
  try {
    const dev = view.device, m = await material(dev);
    const jwk = await crypto.subtle.exportKey("jwk", m.pair.publicKey);
    const ts = Date.now();
    const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, m.pair.privateKey, new TextEncoder().encode(proofText(dev, ts))));
    const t0 = Date.now(), p0 = Math.round(performance.now());
    const r = await post("/founder/v1/vault/lease", { jwk: { kty: jwk.kty, crv: jwk.crv, x: jwk.x, y: jwk.y }, ts, proof: b64u(sig) });
    if (r.status !== 200 || !r.body) {
      fails += 1; const n = afterFailure(r.status, r.body?.why ?? r.body?.reason, fails);
      if (n.wipe) { locked = true; wipe(); await idbDel(dev); }
      set({ phase: n.phase === "waiting" && view.phase === "live" ? "live" : n.phase, text: n.text }); if (n.retryMs) schedule(n.retryMs); return;
    }
    const d = r.body as LeaseData;
    const pinned = parseSerial(lsGet(SERIAL_KEY(dev)));
    rWall = t0; rMono = p0;
    const rep = await leaseCheck(d, dev, pinned, { received_wall_ms: t0, received_mono_ms: p0, now_wall_ms: Date.now(), now_mono_ms: Math.round(performance.now()) });
    if (!rep || rep.state !== "live") { fails += 1; set({ text: rep ? `The kernel refused this lease (${rep.reason ?? "unknown"}).` : "The kernel could not run." }); schedule(30_000); return; }
    const k = await leaseVaultKey(m.local, d.half, dev);
    if (!k) { fails += 1; set({ text: "The vault key could not be derived." }); schedule(30_000); return; }
    lsSet(SERIAL_KEY(dev), String(d.serial));
    data = d; serverHalf = d.half; key = k; fails = 0; void serverHalf;
    set({ phase: "live", secs: secondsLeft(rep.remaining_ms), serial: d.serial, text: "", hasKey: true });
    schedule(nextRenewMs(rep.remaining_ms, d.ttl_s * 1000));
  } catch (e) {
    fails += 1; const n = afterFailure(0, undefined, fails); set({ text: n.text }); if (n.retryMs) schedule(n.retryMs); void e;
  } finally { set({ renewing: false }); }
}

/** Start once after sign-in. Safe to call again. */
export async function startLease(): Promise<void> {
  if (running) return; running = true;
  try {
    const dev = await deviceUuid();
    if (!dev || !globalThis.indexedDB || !crypto?.subtle) { running = false; set({ phase: "off", text: dev ? "This browser cannot hold a device key." : "No approved device on this sign-in." }); return; }
    set({ device: dev, phase: "starting", serial: parseSerial(lsGet(SERIAL_KEY(dev))) });
    tickT = setInterval(() => void tick(), 1000);
    const wake = () => { if (document.visibilityState === "visible" && (view.phase !== "live" || view.secs < 600)) void renew(); };
    document.addEventListener("visibilitychange", wake); window.addEventListener("online", wake);
    await renew();
  } catch { running = false; set({ phase: "off", text: "The vault lease could not start." }); }
}
export function stopLease() { clearTimeout(renewT); clearInterval(tickT); wipe(); running = false; locked = false; set({ phase: "off", secs: 0, device: null, text: "" }); }

export type StatusDevice = { device_id: string; label: string; state: "live" | "expired" | "revoked" | "none"; seconds_left: number; serial?: number | null; chain_head?: string | null; issued_last_hour?: number };
export async function deviceStatus(): Promise<StatusDevice[]> {
  const r = await get<{ devices: StatusDevice[] }>("/founder/v1/vault/status");
  return Array.isArray(r.data?.devices) ? r.data.devices : [];
}
