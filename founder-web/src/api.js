// Founder API (same origin). Token lives in memory only (reload = sign in again). Rule 63: real answers only.
let token = null;
export const hasToken = () => !!token;
export const logout = () => { token = null; };
export async function login(email, password) {
  const r = await fetch("/founder/v1/login", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email, password }) });
  if (r.status === 429) throw new Error("Too many attempts — try again in 15 minutes.");
  if (!r.ok) throw new Error("Access denied. Check your email and password.");
  const j = await r.json();
  token = j.access_token;
  return j;
}
export async function get(path) {
  const r = await fetch(path, { headers: { authorization: `Bearer ${token}` }, cache: "no-store" });
  if (r.status === 401) { token = null; throw new Error("Session expired — sign in again"); }
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return r.json(); // {data, ts, sig} — sig ka browser-side verify = F2b (WASM kernel); abhi UI saaf likhti hai ke verify NAHI hua
}
export async function post(path, body) {
  const r = await fetch(path, { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${token}` }, body: JSON.stringify(body) });
  if (r.status === 401) { token = null; throw new Error("Session expired — sign in again"); }
  let j = null; try { j = await r.json(); } catch {}
  return { status: r.status, body: j };
}
