// Founder API (same origin). The existing sign-in is the ONLY login (Rule 68); this file never stores or copies its token.
// F1a: the session token is exchanged ONCE per 15 minutes for a founder token (aud=anexo-founder, device-bound) which lives in MEMORY only.
// If the server has no token service yet (install pending), calls fall back to the session token and the page says so plainly.
const KEY = "anexo.session.token", DEV = "anexo.founder.device";
const tok = () => { try { return window.localStorage.getItem(KEY); } catch { return null; } };
export const hasToken = () => !!tok();
const expired = () => new Error("Session expired — sign in again");
export class DevicePending extends Error { constructor(code, revoked) { super(revoked ? "device_revoked" : "device_pending"); this.name = "DevicePending"; this.code = code; this.revoked = !!revoked; } }

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
  const ua = navigator.userAgent || "", p = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || "";
  const br = /Edg\//.test(ua) ? "Edge" : /OPR\//.test(ua) ? "Opera" : /Firefox\//.test(ua) ? "Firefox" : /Chrome\//.test(ua) ? "Chrome" : /Safari\//.test(ua) ? "Safari" : "Browser";
  return `${br} on ${String(p).replace(/[^ -~]/g, "").slice(0, 30) || "device"}`.slice(0, 80);
}

let ft = null, fexp = 0, inflight = null, mode = "none", dlabel = "", rk = null; // rk = per-token request key (memory only)
export const deviceStatus = () => ({ mode, label: dlabel }); // "device" = founder token in use · "legacy" = fallback to session token · "none"

async function exchange() {
  const t = tok(); if (!t) throw expired();
  const id = deviceId();
  if (!id) { mode = "legacy"; return null; }
  let r;
  try { r = await fetch("/founder/v1/exchange", { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${t}` }, body: JSON.stringify({ device_id: id, label: deviceLabel() }), cache: "no-store" }); }
  catch { mode = "legacy"; return null; }
  if (r.status === 401) throw expired();
  let j = {}; try { j = await r.json(); } catch {}
  if (r.status === 200 && j.token) { ft = j.token; rk = j.req_key || null; fexp = j.exp * 1000; mode = "device"; dlabel = j.device || ""; return ft; }
  if (r.status === 403 && j.error === "device_pending") throw new DevicePending(j.code, false);
  if (r.status === 403 && j.error === "device_revoked") throw new DevicePending(null, true);
  if (r.status === 403) throw new Error("This account is not a founder account");
  if (r.status === 429) throw new Error("Too many device attempts — try again in 15 minutes");
  mode = "legacy"; return null; // 502/503: token service not installed yet -> honest fallback (server still accepts the session token during grace)
}
async function bearer() {
  if (ft && fexp - 60000 > Date.now()) return ft;
  if (!inflight) inflight = exchange().finally(() => { inflight = null; });
  const x = await inflight;
  return x || tok();
}
export const forget = () => { ft = null; fexp = 0; rk = null; };

// F2a: every write is signed with the per-token key (HMAC-SHA256 over METHOD, path, timestamp, body hash). Replays older than 60 s and changed bodies are refused by the server.
const b64u = (s) => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));
const hex = (buf) => [...new Uint8Array(buf)].map((x) => x.toString(16).padStart(2, "0")).join("");
async function writeHeaders(method, path, bodyStr, token) {
  const h = { "content-type": "application/json", authorization: `Bearer ${token}` };
  if (!rk || token !== ft) return h; // legacy session token (grace): no request key exists
  const ts = Math.floor(Date.now() / 1000), enc = new TextEncoder();
  const bh = hex(await crypto.subtle.digest("SHA-256", enc.encode(bodyStr)));
  const key = await crypto.subtle.importKey("raw", b64u(rk), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  h["x-fo-ts"] = String(ts); h["x-fo-sig"] = hex(await crypto.subtle.sign("HMAC", key, enc.encode(`${method}\n${path}\n${ts}\n${bh}`)));
  return h;
}

const auth = async (path) => (path.startsWith("/founder/v1/") && !path.startsWith("/founder/v1/exchange") ? bearer() : tok());
export async function get(path, retry = true) {
  const t = await auth(path); if (!t) throw expired();
  const r = await fetch(path, { headers: { authorization: `Bearer ${t}` }, cache: "no-store" });
  if (r.status === 401 && retry && ft && t === ft) { forget(); return get(path, false); } // revoked / expired founder token -> one fresh exchange
  if (r.status === 401) throw expired();
  if (r.status === 403) throw new Error("This account is not a founder account");
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return r.json(); // {data, ts, sig} — browser-side signature verify = F2b (WASM kernel); the UI says plainly it is not verified yet
}
export async function post(path, body) {
  const t = await auth(path); if (!t) throw expired();
  const bs = JSON.stringify(body);
  const r = await fetch(path, { method: "POST", headers: await writeHeaders("POST", path, bs, t), body: bs });
  if (r.status === 401) { forget(); throw expired(); }
  let j = null; try { j = await r.json(); } catch {}
  return { status: r.status, body: j };
}
export async function put(path, body) {
  const t = await auth(path); if (!t) throw expired();
  const bs = JSON.stringify(body);
  const r = await fetch(path, { method: "PUT", headers: await writeHeaders("PUT", path, bs, t), body: bs });
  if (r.status === 401) { forget(); throw expired(); }
  let j = null; try { j = await r.json(); } catch {}
  return { status: r.status, body: j };
}
// Sign out of THIS browser only: drops the session copy + the in-memory founder token. The device approval stays (server side).
export function signOut() { forget(); try { window.localStorage.removeItem(KEY); window.localStorage.removeItem("anexo.session.last"); } catch {} window.location.replace("/founderlogin"); }
