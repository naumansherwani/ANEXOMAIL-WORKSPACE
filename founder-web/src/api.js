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

let ft = null, fexp = 0, inflight = null, mode = "none", dlabel = "";
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
  if (r.status === 200 && j.token) { ft = j.token; fexp = j.exp * 1000; mode = "device"; dlabel = j.device || ""; return ft; }
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
export const forget = () => { ft = null; fexp = 0; };

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
  const r = await fetch(path, { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${t}` }, body: JSON.stringify(body) });
  if (r.status === 401) { forget(); throw expired(); }
  let j = null; try { j = await r.json(); } catch {}
  return { status: r.status, body: j };
}
