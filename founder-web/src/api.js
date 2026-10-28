// Founder API (same origin). Token SIRF memory mein (reload = dobara login: military usool). Rule 63: sirf asli jawab.
let token = null;
export const hasToken = () => !!token;
export const logout = () => { token = null; };
export async function login(email, password) {
  const r = await fetch("/founder/v1/login", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email, password }) });
  if (r.status === 429) throw new Error("Bohat koshishen — 15 minute baad dobara.");
  if (!r.ok) throw new Error("Inkar. Email/password theek nahi ya founder nahi.");
  const j = await r.json();
  token = j.access_token;
  return j;
}
export async function get(path) {
  const r = await fetch(path, { headers: { authorization: `Bearer ${token}` }, cache: "no-store" });
  if (r.status === 401) { token = null; throw new Error("session khatam"); }
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return r.json(); // {data, ts, sig} — sig ka browser-side verify = F2b (WASM kernel); abhi UI saaf likhti hai ke verify NAHI hua
}
