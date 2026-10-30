// Founder API (same origin). The existing sign-in is the ONLY login (Rule 68); this file never stores or copies its token.
// F1a: the session token is exchanged ONCE per 15 minutes for a founder token (aud=anexo-founder, device-bound) which lives in MEMORY only.
// If the server has no token service yet (install pending), calls fall back to the session token and the page says so plainly.
import { verifyBody } from "./kernel";
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
function deviceLabel() {
  const ua = navigator.userAgent || "", p = (navigator as Navigator & { userAgentData?: { platform?: string } }).userAgentData?.platform || navigator.platform || "";
  const br = /Edg\//.test(ua) ? "Edge" : /OPR\//.test(ua) ? "Opera" : /Firefox\//.test(ua) ? "Firefox" : /Chrome\//.test(ua) ? "Chrome" : /Safari\//.test(ua) ? "Safari" : "Browser";
  return `${br} on ${String(p).replace(/[^ -~]/g, "").slice(0, 30) || "device"}`.slice(0, 80);
}

let ft: string | null = null, fexp = 0, inflight: Promise<string | null> | null = null, mode = "none", dlabel = "", rk: string | null = null; // rk = per-token request key (memory only)
export const deviceStatus = () => ({ mode, label: dlabel }); // "device" = founder token in use · "legacy" = fallback to session token · "none"

async function exchange(): Promise<string | null> {
  const t = tok(); if (!t) throw expired();
  const id = deviceId();
  if (!id) { mode = "legacy"; return null; }
  let r: Response;
  try { r = await fetch("/founder/v1/exchange", { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${t}` }, body: JSON.stringify({ device_id: id, label: deviceLabel() }), cache: "no-store" }); }
  catch { mode = "legacy"; return null; }
  if (r.status === 401) throw expired();
  let j: any = {}; try { j = await r.json(); } catch {}
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
/** Get the founder token ready (one shared exchange) so timings measure the answer, not the sign-in. */
export const warm = async () => { try { await bearer(); } catch { /* the probes below report the real error */ } };
export const forget = () => { ft = null; fexp = 0; rk = null; };

// F2a: every write is signed with the per-token key (HMAC-SHA256 over METHOD, path, timestamp, body hash). Replays older than 60 s and changed bodies are refused by the server.
const b64u = (s: string) => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));
const hex = (buf: ArrayBuffer) => [...new Uint8Array(buf)].map((x) => x.toString(16).padStart(2, "0")).join("");
async function writeHeaders(method: string, path: string, bodyStr: string, token: string): Promise<Record<string, string>> {
  const h: Record<string, string> = { "content-type": "application/json", authorization: `Bearer ${token}` };
  if (!rk || token !== ft) return h; // legacy session token (grace): no request key exists
  const ts = Math.floor(Date.now() / 1000), enc = new TextEncoder();
  const bh = hex(await crypto.subtle.digest("SHA-256", enc.encode(bodyStr)));
  const key = await crypto.subtle.importKey("raw", b64u(rk), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  h["x-fo-ts"] = String(ts); h["x-fo-sig"] = hex(await crypto.subtle.sign("HMAC", key, enc.encode(`${method}\n${path}\n${ts}\n${bh}`)));
  return h;
}

const auth = async (path: string) => (path.startsWith("/founder/v1/") && !path.startsWith("/founder/v1/exchange") ? bearer() : tok());
const SIGNED = (path: string) => path.startsWith("/founder/v1/") && !path.startsWith("/founder/v1/keys") && !path.startsWith("/founder/v1/exchange");
/** F2b: verify the raw body in the WASM kernel FIRST; only the verified `data` text is parsed. Failure = nothing is shown (enforce). */
async function readSigned<T>(r: Response, path: string): Promise<Envelope<T>> {
  if (!SIGNED(path)) return r.json();
  const v = await verifyBody(await r.arrayBuffer());
  if (!v.ok) throw new Error(`Answer hidden: ${v.reason}`);
  return { data: JSON.parse(v.data) as T, verified: true };
}
export async function get<T = any>(path: string, retry = true): Promise<Envelope<T>> {
  const t = await auth(path); if (!t) throw expired();
  const r = await fetch(path, { headers: { authorization: `Bearer ${t}` }, cache: "no-store" });
  if (r.status === 401 && retry && ft && t === ft) { forget(); return get(path, false); } // revoked / expired founder token -> one fresh exchange
  if (r.status === 401) throw expired();
  if (r.status === 403) throw new Error("This account is not a founder account");
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return readSigned<T>(r, path);
}
export async function post(path: string, body: unknown): Promise<WriteResult> {
  const t = await auth(path); if (!t) throw expired();
  const bs = JSON.stringify(body);
  const r = await fetch(path, { method: "POST", headers: await writeHeaders("POST", path, bs, t), body: bs });
  if (r.status === 401) { forget(); throw expired(); }
  let j: any = null;
  try { j = r.ok && SIGNED(path) ? (await readSigned(r, path)).data : await r.json(); } catch (e) { if (r.ok) throw e; }
  return { status: r.status, body: j };
}
export async function put(path: string, body: unknown): Promise<WriteResult> {
  const t = await auth(path); if (!t) throw expired();
  const bs = JSON.stringify(body);
  const r = await fetch(path, { method: "PUT", headers: await writeHeaders("PUT", path, bs, t), body: bs });
  if (r.status === 401) { forget(); throw expired(); }
  let j: any = null;
  try { j = r.ok && SIGNED(path) ? (await readSigned(r, path)).data : await r.json(); } catch (e) { if (r.ok) throw e; }
  return { status: r.status, body: j };
}
// Sign out of THIS browser only: drops the session copy + the in-memory founder token. The device approval stays (server side).
export function signOut() { forget(); try { window.localStorage.removeItem(KEY); window.localStorage.removeItem("anexo.session.last"); } catch {} window.location.replace("/founderlogin"); }

// Founder settings (E108): one signed write per change; value null = back to default.
export const setSetting = (key: string, value: unknown) => put("/founder/v1/settings", { key, value });
