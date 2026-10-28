// Founder API (same origin). NO separate login: the founder signs in through the existing /auth page (Rule 68).
// The session token is only READ from that sign-in (never written or copied); the Rust service verifies it (ES256 + founder_accounts).
// F1a replaces this with a short-lived founder-only token from /founder/v1/exchange (memory only).
const KEY = "anexo.session.token";
const tok = () => { try { return window.localStorage.getItem(KEY); } catch { return null; } };
export const hasToken = () => !!tok();
const expired = () => new Error("Session expired — sign in again");
export async function get(path) {
  const t = tok(); if (!t) throw expired();
  const r = await fetch(path, { headers: { authorization: `Bearer ${t}` }, cache: "no-store" });
  if (r.status === 401) throw expired();
  if (r.status === 403) throw new Error("This account is not a founder account");
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return r.json(); // {data, ts, sig} — browser-side signature verify = F2b (WASM kernel); the UI says plainly it is not verified yet
}
export async function post(path, body) {
  const t = tok(); if (!t) throw expired();
  const r = await fetch(path, { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${t}` }, body: JSON.stringify(body) });
  if (r.status === 401) throw expired();
  let j = null; try { j = await r.json(); } catch {}
  return { status: r.status, body: j };
}
