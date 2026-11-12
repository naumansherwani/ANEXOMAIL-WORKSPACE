// Founder API (same origin). The existing sign-in is the ONLY login (Rule 68); this file never stores or copies its token.
// F1a: the session token is exchanged ONCE per 15 minutes for a founder token (aud=anexo-founder, device-bound) which lives in MEMORY only.
// If the server has no token service yet (install pending), calls fall back to the session token and the page says so plainly.
import { verifyBody, kernelRpc, rpcAvailable, kernelRpcStart } from "./kernel";
import { KERNEL } from "./kernel.pin";
// D2b: the kernel build this browser runs travels with every founder request, so Devices & Sessions can see a build change inside one session (a claim, never proof).
const KV = { "x-founder-kernel": KERNEL.version } as const;
import { openSealed, seal } from "./snap_seal";
import { browserName } from "./devicelabel";
import { EXPIRES_KEY, REFRESH_KEY, TICK_MS, classifyRefresh, knownExpiry, needsRefresh } from "./session";
const KEY = "anexo.session.token", DEV = "anexo.founder.device";
const tok = () => { try { return window.localStorage.getItem(KEY); } catch { return null; } };
export const hasToken = () => !!tok();
const expired = () => new Error("Session expired — sign in again");
export class DevicePending extends Error { code: string | null; revoked: boolean; constructor(code: string | null, revoked: boolean) { super(revoked ? "device_revoked" : "device_pending"); this.name = "DevicePending"; this.code = code; this.revoked = !!revoked; } }
/** Signed envelope every /founder/v1 GET returns: {data, ts, sig_ed, kid}. The WASM kernel verifies the raw body before `data` is parsed (F2b). */
export type Envelope<T = any> = { data: T; ts?: number; sig?: string; sig_ed?: string; kid?: string; verified?: boolean };
export type WriteResult = { status: number; body: any };

// Device id: random per browser, stored only as a device binding (not a login). The server keeps only its SHA-256.
function deviceId() {
  try {
    let d = window.localStorage.getItem(DEV);
    if (!d || !/^[A-Za-z0-9_-]{32,128}$/.test(d)) {
      const b = new Uint8Array(32); crypto.getRandomValues(b);
      d = btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
      window.localStorage.setItem(DEV, d);
    }
    return d;
  } catch { return null; }
}
export function deviceLabel() {
  const ua = navigator.userAgent || "", p = (navigator as Navigator & { userAgentData?: { platform?: string } }).userAgentData?.platform || navigator.platform || "";
  const br = browserName(ua);
  return `${br} on ${String(p).replace(/[^ -~]/g, "").slice(0, 30) || "device"}`.slice(0, 80);
}

let keyTried = false;   // E158: one key registration per page load, so a live chip session that keeps the slot can never loop
let proofTried = false;   // K8d-S4: one proof-key registration per page load
let psrc = "";   // S3b: where this device's ML-DSA key lives, as the server reports it ("webcrypto" | "kernel" | "" = no hybrid key yet)
let ft: string | null = null, fexp = 0, inflight: Promise<string | null> | null = null, mode = "none", dlabel = "", rk: string | null = null; // rk = per-token request key (memory only)
export const deviceStatus = () => ({ mode, label: dlabel, psrc }); // "device" = founder token in use · "legacy" = fallback to session token · "none"

// FS1: the sign-in is RENEWED, not allowed to die. One shared refresh (single flight); the session only ends when the refresh token itself is dead (see session.ts).
const lsGet = (k: string) => { try { return window.localStorage.getItem(k); } catch { return null; } };
const lsSet = (k: string, v: string) => { try { window.localStorage.setItem(k, v); } catch { /* private window: renewal simply cannot persist */ } };
let renewing: Promise<boolean> | null = null;
/** true = a fresh session token is now stored. false = nothing changed (dead refresh token clears it; a blip keeps it). Never throws. */
export function renewSession(): Promise<boolean> {
  if (renewing) return renewing;
  const rt = lsGet(REFRESH_KEY); if (!rt) return Promise.resolve(false);
  renewing = (async () => {
    try {
      const r = await fetch("/founder/v1/auth/refresh", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ refresh_token: rt }), cache: "no-store" });
      let j: { token?: unknown; refresh_token?: unknown; expires_at?: unknown } = {}; try { j = await r.json(); } catch { /* not json */ }
      const got = typeof j.token === "string" && j.token.length > 20;
      const out = classifyRefresh(r.status, got);
      if (out === "renewed") {
        lsSet(KEY, j.token as string);
        if (typeof j.refresh_token === "string" && j.refresh_token) lsSet(REFRESH_KEY, j.refresh_token);
        if (typeof j.expires_at === "number") lsSet(EXPIRES_KEY, String(j.expires_at));
        return true;
      }
      if (out === "revoked") {
        // Two tabs can renew at the same moment with the same old refresh token: the loser is told "dead", yet the winner already stored a NEW one. Only a refresh token that is still the one we sent is really dead.
        if (lsGet(REFRESH_KEY) !== rt) return true;
        try { window.localStorage.removeItem(REFRESH_KEY); window.localStorage.removeItem(EXPIRES_KEY); } catch { /* ignore */ }
      }
      return false;
    } catch { return false; } // offline / DNS: keep everything, the next tick tries again
  })().finally(() => { renewing = null; });
  return renewing;
}
/** Renew early when the token is within RENEW_BEFORE_S of its end. Safe to call often. */
export async function keepSessionFresh(): Promise<void> {
  const t = tok(); if (!t) return;
  if (needsRefresh(knownExpiry(lsGet(EXPIRES_KEY), t), Math.floor(Date.now() / 1000), !!lsGet(REFRESH_KEY))) await renewSession();
}
if (typeof window !== "undefined") {
  const tick = () => { void keepSessionFresh(); };
  window.setInterval(tick, TICK_MS);
  window.addEventListener("online", tick);
  document.addEventListener("visibilitychange", () => { if (document.visibilityState === "visible") tick(); });
}

import * as dk from "./devicekey";
import { shouldRegister, shouldWaitForKernel, KERNEL_WAIT_MS } from "./devicekey_pure";
async function exchange(again = true): Promise<string | null> {
  await keepSessionFresh();
  const t = tok(); if (!t) throw expired();
  const id = deviceId();
  if (!id) { mode = "legacy"; return null; }
  let r: Response;
  const proof = await dk.exchangeProof(id).catch(() => null);   // K7b: only when this device already has a key; otherwise the exchange is exactly as before
  const init = () => ({ method: "POST", headers: { ...KV, "content-type": "application/json", authorization: `Bearer ${t}`, ...(proof ? { "x-device-proof": proof } : {}) }, body: JSON.stringify({ device_id: id, label: deviceLabel() }) });
  // K8d-S4: once this device holds a hybrid PROOF KEY (ES256 + ML-DSA-65, beside its chip key) the exchange goes over the KERNEL (WebTransport). fetch stays ONLY for the bootstrap of a new
  // device / the DBSC chip registration (browser HTTP stack, by spec) and as the fallback when the kernel is down or the chip needs a browser re-registration.
  const viaFetch = () => fetch("/founder/v1/exchange", { ...init(), cache: "no-store" } as RequestInit);
  const ready = !!proof && (await dk.proofKeyReady().catch(() => false));
  if (ready && !rpcAvailable()) await kernelRpcStart(3000).catch(() => false);   // the kernel session is still opening at page start: wait for it (3 s at most) instead of silently taking fetch
  const kernelFirst = ready && rpcAvailable();
  try {
    r = kernelFirst ? await net("/founder/v1/exchange", init()).catch(() => viaFetch()) : await viaFetch();
    if (kernelFirst && (r.status === 404 || r.status === 502 || r.status === 503 || (r.status === 401 && (await r.clone().json().catch(() => ({}))).error === "dbsc_required"))) r = await viaFetch();
  }
  catch { mode = "legacy"; return null; }
  if (r.status === 401) { if (again && (await renewSession())) return exchange(false); throw expired(); } // an expired session token: renew once, then ask again
  let j: any = {}; try { j = await r.json(); } catch {}
  if (r.status === 200 && j.dk) psrc = typeof j.dk.psrc === "string" ? j.dk.psrc : "";
  const pqOk = await dk.hybridCapable().catch(() => false);   // S3b: WebCrypto ML-DSA or the kernel fallback
  if (r.status === 200 && j.dk && j.dk.proof === true) void dk.proofKeyMark();   // the server has the key: make sure this browser knows
  if (r.status === 200 && j.dk && j.dk.proof === false) dk.proofKeyForget();   // the server has no proof key for this device: the local flag is stale
  if (r.status === 200 && j.token && pqOk && j.dk && j.dk.mode !== "off" && j.dk.proof === false && !proofTried) { proofTried = true; void dk.registerProofKey(id, t, net); }   // next exchange goes over the kernel
  if (r.status === 200 && j.token && shouldRegister(j.dk, pqOk) && !keyTried) { keyTried = true; void dk.register(id, t, net, pqOk && j.dk?.pq === false).then((ok) => { if (ok) forget(); }); }   // E158: once the key is registered, the next call re-exchanges WITH the proof so the session row gets its key; K7b: an unbound device binds; K7 wire fix: a bound device that proved no key this time re-binds (any browser, any phone); fire and forget
  if (r.status === 200 && j.token) { ft = j.token; rk = j.req_key || null; fexp = j.exp * 1000; mode = "device"; dlabel = j.device || ""; return ft; }
  if (r.status === 403 && j.error === "device_pending") throw new DevicePending(j.code, false);
  if (r.status === 403 && j.error === "device_revoked") throw new DevicePending(null, true);
  if (r.status === 403) throw new Error("This account is not a founder account");
  if (r.status === 429) throw new Error("Too many device attempts — try again in 15 minutes");
  mode = "legacy"; return null; // 502/503: token service not installed yet -> honest fallback (server still accepts the session token during grace)
}
async function bearer(): Promise<string | null> {
  if (ft && fexp - 60000 > Date.now()) return ft;
  if (!inflight) inflight = exchange().finally(() => { inflight = null; });
  const x = await inflight;
  return x || tok();
}
/** J8d: the id of THIS device, read from the founder token (`did`). Not a secret and not trusted for anything: the server checks the signed token itself. null = no device token (legacy sign-in). */
export async function deviceUuid(): Promise<string | null> {
  const t = await bearer(); if (!t || mode !== "device") return null;
  try { const p = t.split(".")[1].replace(/-/g, "+").replace(/_/g, "/"); const j = JSON.parse(atob(p + "=".repeat((4 - (p.length % 4)) % 4))); return typeof j.did === "string" && /^[0-9a-f-]{36}$/i.test(j.did) ? j.did.toLowerCase() : null; } catch { return null; }
}
/** Get the founder token ready (one shared exchange) so timings measure the answer, not the sign-in. */
export const warm = async () => { try { await bearer(); } catch { /* the probes below report the real error */ } };
export const forget = () => { ft = null; fexp = 0; rk = null; };

// F2a: every write is signed with the per-token key (HMAC-SHA256 over METHOD, path, timestamp, body hash). Replays older than 60 s and changed bodies are refused by the server.
const b64u = (s: string) => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));
const hex = (buf: ArrayBuffer) => [...new Uint8Array(buf)].map((x) => x.toString(16).padStart(2, "0")).join("");
async function writeHeaders(method: string, path: string, bodyStr: string, token: string): Promise<Record<string, string>> {
  const h: Record<string, string> = { ...KV, "content-type": "application/json", authorization: `Bearer ${token}` };
  if (!rk || token !== ft) return h; // legacy session token (grace): no request key exists
  const ts = Math.floor(Date.now() / 1000), enc = new TextEncoder();
  const bh = hex(await crypto.subtle.digest("SHA-256", enc.encode(bodyStr)));
  const key = await crypto.subtle.importKey("raw", b64u(rk), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  h["x-fo-ts"] = String(ts); h["x-fo-sig"] = hex(await crypto.subtle.sign("HMAC", key, enc.encode(`${method}\n${path}\n${ts}\n${bh}`)));
  return h;
}

const auth = async (path: string) => (path.startsWith("/founder/v1/") && !path.startsWith("/founder/v1/exchange") ? bearer() : tok());
const SIGNED = (path: string) => path.startsWith("/founder/v1/") && !path.startsWith("/founder/v1/keys") && !path.startsWith("/founder/v1/exchange");
// Instant refresh: the last Bridge answer this TAB verified is kept (session storage, cleared on sign-out/close) and shown straight away after F5,
// verified AGAIN by the kernel (signature only; age up to a day) and labelled with its real time. The live answer replaces it as soon as it arrives.
const SNAP_PATH = "/founder/v1/bridge", SNAP = "anexo.f.snap.bridge";
// G2: the snapshot at rest is CIPHERTEXT (AES-256-GCM under a key derived from this device's vault key, snap_seal.ts). The key exists only while the vault lease is live (lease.ts registers it here),
// so with no live lease nothing is written and nothing can be read. Plain text is never stored. When the lease ends the stored record is deleted (clearSnap).
let snapKeyFn: (() => Promise<{ key: CryptoKey; device: string } | null>) | null = null;
export const registerSnapKey = (f: () => Promise<{ key: CryptoKey; device: string } | null>) => { snapKeyFn = f; };
// G2: a record written by an older build is plain text; anything that is not a sealed {v:1,iv,c} record is deleted at load, so no plain snapshot can linger.
(() => { try { const raw = window.sessionStorage.getItem(SNAP); if (!raw) return; let ok = false; try { const o = JSON.parse(raw); ok = o && o.v === 1 && typeof o.iv === "string" && typeof o.c === "string"; } catch { ok = false; } if (!ok) window.sessionStorage.removeItem(SNAP); } catch { /* storage shut */ } })();
export const clearSnap = () => { try { window.sessionStorage.removeItem(SNAP); } catch { /* nothing to clear */ } };
const waitKey = async (ms: number) => { for (let i = 0; i <= ms / 150; i++) { const k = snapKeyFn ? await snapKeyFn() : null; if (k) return k; await new Promise((ok) => setTimeout(ok, 150)); } return null; };
const saveSnap = async (buf: ArrayBuffer) => {
  try { const k = snapKeyFn ? await snapKeyFn() : null; if (!k) return; window.sessionStorage.setItem(SNAP, await seal(k.key, new TextDecoder().decode(buf), k.device, Date.now())); }
  catch { /* storage blocked or no key: just no instant paint */ }
};
export async function lastBridge(): Promise<{ data: any; at: Date } | null> {
  try {
    const raw = window.sessionStorage.getItem(SNAP); if (!raw) return null;
    const k = await waitKey(2500); if (!k) return null;                          // no live lease = the record stays shut
    const o = await openSealed(k.key, raw, k.device); if (!o) return null;       // tampered / other device / other key = nothing
    if (Date.now() - o.t > 86_400_000) return null;
    const v = await verifyBody(new TextEncoder().encode(o.plain).buffer as ArrayBuffer, 90_000, true);
    return v.ok ? { data: JSON.parse(v.data), at: new Date(o.t) } : null;
  } catch { return null; }
}
/** F2b: verify the raw body in the WASM kernel FIRST; only the verified `data` text is parsed. Failure = nothing is shown (enforce). */
async function readSigned<T>(r: Response, path: string): Promise<Envelope<T>> {
  if (!SIGNED(path)) return r.json();
  const raw = await r.arrayBuffer(), keep = path === SNAP_PATH ? raw.slice(0) : null;
  const v = await verifyBody(raw);
  if (!v.ok) throw new Error(`Answer hidden: ${v.reason}`);
  if (keep) void saveSnap(keep);
  return { data: JSON.parse(v.data) as T, verified: true };
}
// Same GET asked twice at the same moment (shell + a page) shares one network call and one verification.

/** K8d (Rule 52): every founder API call travels through the Rust WASM kernel over WebTransport (HTTP/3, QUIC). fetch is only the read fallback when the kernel session is not up BEFORE sending; a write is never repeated after an ambiguous break. */
let kernelWaitFailedAt = 0;
/** AUDIT 3 (12 Nov): while the kernel session is reconnecting a call used to fall straight to fetch (seen live 00:22: /sessions/board, /sessions/ledger). Now it waits up to 1.2 s for the kernel first;
 *  if the kernel does not come back, the next 30 s go to fetch at once (no repeated waiting), so the page never stalls. Only once this browser has used the kernel (proof key ready). */
export async function net(path: string, init: { method?: string; headers?: Record<string, string>; body?: string }): Promise<Response> {
  const m = (init.method || "GET").toUpperCase();
  if ((m === "GET" || m === "POST" || m === "PUT") && shouldWaitForKernel(rpcAvailable(), dk.proofKeyWanted(), Date.now(), kernelWaitFailedAt)) {
    if (!(await kernelRpcStart(KERNEL_WAIT_MS).catch(() => false))) kernelWaitFailedAt = Date.now();
  }
  if ((m === "GET" || m === "POST" || m === "PUT") && rpcAvailable()) {
    const body = init.body == null ? null : new TextEncoder().encode(init.body);
    const r = await kernelRpc(m, path, init.headers || {}, body);
    if (r) return new Response(r.body.length ? (r.body as unknown as BodyInit) : null, { status: r.status, headers: { "content-type": r.contentType || "application/json" } });
    if (m !== "GET") throw new Error("The connection broke while saving. Not repeated automatically; check and try again.");
  }
  return fetch(path, { ...init, cache: "no-store" } as RequestInit);
}
const liveGets = new Map<string, Promise<Envelope<any>>>();
export function get<T = any>(path: string, retry = true): Promise<Envelope<T>> {
  const k = retry ? path : "";
  if (k) { const p = liveGets.get(k); if (p) return p as Promise<Envelope<T>>; }
  const run = getOnce<T>(path, retry);
  if (k) { liveGets.set(k, run); const done = () => { if (liveGets.get(k) === run) liveGets.delete(k); }; run.then(done, done); }
  return run;
}
async function getOnce<T = any>(path: string, retry = true): Promise<Envelope<T>> {
  const t = await auth(path); if (!t) throw expired();
  const r = await net(path, { headers: { ...KV, authorization: `Bearer ${t}` } });
  if (r.status === 401 && retry && ft && t === ft) { forget(); return getOnce(path, false); } // revoked / expired founder token -> one fresh exchange
  if (r.status === 401) throw expired();
  if (r.status === 403) throw new Error("This account is not a founder account");
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return readSigned<T>(r, path);
}
/** K6.3: the current founder token for the kernel's WebTransport hello (same token as the SSE header). null = signed out. */
export const liveToken = () => auth("/founder/v1/live/stream");
/** 4b-3: open a Server-Sent-Events stream with the founder token (EventSource cannot send an Authorization header). The caller reads `response.body`; every frame is verified by the kernel in live.ts. */
export async function openStream(path: string, lastId: number, signal: AbortSignal, retry = true): Promise<Response> {
  const t = await auth(path); if (!t) throw expired();
  const r = await fetch(path, { headers: { ...KV, authorization: `Bearer ${t}`, accept: "text/event-stream", ...(lastId > 0 ? { "last-event-id": String(lastId) } : {}) }, cache: "no-store", signal });
  if (r.status === 401 && retry && ft && t === ft) { forget(); return openStream(path, lastId, signal, false); } // revoked / expired founder token -> one fresh exchange
  if (r.status === 401) throw expired();
  if (r.status === 403) throw new Error("This account is not a founder account");
  if (!r.ok || !r.body) throw new Error(`HTTP ${r.status}`);
  return r;
}
export async function post(path: string, body: unknown): Promise<WriteResult> {
  const t = await auth(path); if (!t) throw expired();
  const bs = JSON.stringify(body);
  const r = await net(path, { method: "POST", headers: await writeHeaders("POST", path, bs, t), body: bs });
  if (r.status === 401) { forget(); throw expired(); }
  let j: any = null;
  try { j = r.ok && SIGNED(path) ? (await readSigned(r, path)).data : await r.json(); } catch (e) { if (r.ok) throw e; }
  return { status: r.status, body: j };
}
export async function put(path: string, body: unknown): Promise<WriteResult> {
  const t = await auth(path); if (!t) throw expired();
  const bs = JSON.stringify(body);
  const r = await net(path, { method: "PUT", headers: await writeHeaders("PUT", path, bs, t), body: bs });
  if (r.status === 401) { forget(); throw expired(); }
  let j: any = null;
  try { j = r.ok && SIGNED(path) ? (await readSigned(r, path)).data : await r.json(); } catch (e) { if (r.ok) throw e; }
  return { status: r.status, body: j };
}
// Sign out of THIS browser only: drops the session copy + the in-memory founder token. The device approval stays (server side).
export function signOut() { const tk = tok(); forget(); try { window.sessionStorage.removeItem(SNAP); } catch {} try { window.localStorage.removeItem(KEY); window.localStorage.removeItem("anexo.session.last"); } catch {} try { void fetch("/founder/v1/auth/logout", { method: "POST", headers: tk ? { authorization: `Bearer ${tk}` } : {}, keepalive: true }); } catch {} window.location.replace("/"); }

// Founder settings (E108): one signed write per change; value null = back to default.
export const setSetting = (key: string, value: unknown) => put("/founder/v1/settings", { key, value });
