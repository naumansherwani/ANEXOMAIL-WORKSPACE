import { useEffect, useRef, useState } from "react";
import { get, put, signOut, deviceStatus } from "./api.js";

// Full name: the account profile first, else the signed-in session's own name. Never invented (FC26).
export function jwtName() {
  try {
    const t = window.localStorage.getItem("anexo.session.token"); if (!t) return "";
    const p = JSON.parse(decodeURIComponent(escape(atob(t.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")))));
    const m = p.user_metadata || {};
    return String(m.display_name || m.full_name || m.name || p.name || "").trim().slice(0, 60);
  } catch { return ""; }
}
export const nameOf = (p) => String(p?.display_name || "").trim() || jwtName();
// Initials: first + last name. A leading "Muhammad"-type prefix is skipped when real names follow it (Muhammad Nauman Sherwani -> NS).
const PREFIX = /^(muhammad|mohammad|mohammed|mohd|md|mr|mrs|ms|dr)\.?$/i;
export const callName = (n) => { const w = String(n || "").trim().split(/\s+/).filter(Boolean); return (w.length >= 2 && PREFIX.test(w[0]) ? w[1] : w[0]) || ""; };
export function initials(n, e) {
  let w = String(n || "").trim().split(/\s+/).filter(Boolean);
  if (w.length >= 3 && PREFIX.test(w[0])) w = w.slice(1);
  if (!w.length) w = [String(e || "?").split("@")[0]];
  const a = w[0][0] || "?", b = w.length > 1 ? w[w.length - 1][0] : "";
  return (a + b).toUpperCase();
}

export function Avatar({ p, size = 36 }) {
  return <span className="av" style={{ width: size, height: size, fontSize: Math.round(size * 0.38) }} aria-hidden="true">{p?.avatar_url ? <img src={p.avatar_url} alt="" /> : initials(nameOf(p), p?.email)}</span>;
}

// Scale to <=320px, JPEG; step the quality down until it fits the server limit (130 KB). The user never sees "too large" for a normal photo.
export async function shrink(file) {
  if (!/^image\/(jpeg|png|webp)$/.test(file.type)) throw new Error("Choose a jpg, png or webp photo.");
  const bmp = await createImageBitmap(file);
  const s = Math.min(1, 320 / Math.max(bmp.width, bmp.height)), w = Math.max(1, Math.round(bmp.width * s)), h = Math.max(1, Math.round(bmp.height * s));
  const c = document.createElement("canvas"); c.width = w; c.height = h; c.getContext("2d").drawImage(bmp, 0, 0, w, h);
  for (const q of [0.88, 0.78, 0.68, 0.55, 0.42]) {
    const u = c.toDataURL("image/jpeg", q);
    if (u.length <= 170000) return u;
  }
  throw new Error("This photo is too detailed to shrink — choose another one.");
}

// Very faint light that follows the cursor around the photo (CSS vars; no re-render).
const glow = (e) => { const b = e.currentTarget.getBoundingClientRect(); e.currentTarget.style.setProperty("--gx", `${e.clientX - b.left}px`); e.currentTarget.style.setProperty("--gy", `${e.clientY - b.top}px`); };

export function AccountMenu({ p, go, fxOn, setFx }) {
  const [open, setOpen] = useState(false), ref = useRef(null);
  useEffect(() => {
    if (!open) return;
    const away = (e) => { if (ref.current && !ref.current.contains(e.target)) setOpen(false); };
    const esc = (e) => { if (e.key === "Escape") setOpen(false); };
    document.addEventListener("pointerdown", away); document.addEventListener("keydown", esc);
    return () => { document.removeEventListener("pointerdown", away); document.removeEventListener("keydown", esc); };
  }, [open]);
  const ds = deviceStatus();
  const item = (label, fn) => <button role="menuitem" className="mi" onClick={() => { setOpen(false); fn(); }}>{label}</button>;
  return (
    <div className="acct" ref={ref}>
      <button className="avbtn" onPointerMove={glow} aria-label="Account" aria-haspopup="menu" aria-expanded={open} onClick={() => setOpen((v) => !v)}><Avatar p={p} size={36} /></button>
      {open && <div className="menu" role="menu">
        <div className="mhead"><Avatar p={p} size={44} /><div><b>{nameOf(p) || "Founder"}</b><span>{p?.email || ""}</span><i className="rolechip">Founder · Chairman</i></div></div>
        {item("Profile & photo", () => go("profile"))}
        {item("Devices & sessions", () => go("profile"))}
        {item("Audit ledger", () => go("audit"))}
        {item(`Graphics: ${fxOn ? "On" : "Off"}`, () => setFx((v) => !v))}
        <div className="msep" />
        <div className="mnote">This browser: {ds.mode === "device" ? `approved · ${ds.label}` : ds.mode === "legacy" ? "approval not active yet" : "checking"}</div>
        {item("Sign out", signOut)}
      </div>}
    </div>
  );
}

export function ProfileView({ p, reload }) {
  const [busy, setBusy] = useState(false), [msg, setMsg] = useState(null), file = useRef(null);
  const ds = deviceStatus();
  async function choose(e) {
    const f = e.target.files?.[0]; e.target.value = ""; if (!f) return;
    setBusy(true); setMsg(null);
    try {
      const url = await shrink(f);
      const r = await put("/founder/v1/profile/avatar", { avatar_url: url });
      if (r.status === 200) { setMsg({ ok: true, t: "Photo saved. It is also your photo in the user app." }); reload(); }
      else setMsg({ ok: false, t: r.body?.error || `Not saved (HTTP ${r.status})` });
    } catch (x) { setMsg({ ok: false, t: x.message }); }
    setBusy(false);
  }
  async function remove() {
    setBusy(true); setMsg(null);
    const r = await put("/founder/v1/profile/avatar", { avatar_url: null });
    setMsg(r.status === 200 ? { ok: true, t: "Photo removed." } : { ok: false, t: r.body?.error || `Not removed (HTTP ${r.status})` });
    if (r.status === 200) reload();
    setBusy(false);
  }
  return (
    <div className="grid">
      <section className="card prof">
        <div className="kicker">PROFILE</div>
        <div className="profrow">
          <button className="bigav" onClick={() => file.current?.click()} disabled={busy} aria-label="Change profile photo"><Avatar p={p} size={96} /><span className="cam">{busy ? "Saving…" : "Change"}</span></button>
          <div><div className="big" style={{ fontSize: 24 }}>{nameOf(p) || "Founder"}</div><div className="dim">{p?.email}</div><span className="rolechip">Founder · Chairman</span></div>
        </div>
        <input ref={file} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={choose} />
        <div className="row"><button className="btn" disabled={busy} onClick={() => file.current?.click()}>Upload photo</button>{p?.avatar_url && <button disabled={busy} onClick={remove}>Remove</button>}</div>
        {msg && <div className={msg.ok ? "note" : "err banner"} role="status">{msg.t}</div>}
        {p && !p.profile_found && <div className="note">{p.profile_state === "query_failed" ? "The profile could not be read from the database (query failed), so a photo cannot be saved right now." : "This account has no profile row in account_profiles, so a photo cannot be saved. Sign in once through the user app to create it, or tell me and I will add a safe create step."}</div>}
        <div className="src">Photos are shrunk in your browser to fit (jpg, png, webp). Stored on your account profile; every change is written to the audit ledger.</div>
      </section>
      <section className="card">
        <div className="kicker">THIS DEVICE</div>
        <div className="big" style={{ fontSize: 20 }}>{ds.mode === "device" ? "Approved" : ds.mode === "legacy" ? "Approval not active" : "Checking"}</div>
        <div className="dim">{ds.label || "—"}</div>
        <div className="src">The full list of your approved devices, with one-click revoke, arrives with the Devices screen (after F2). Until then, list and revoke on the server with founder-device.sh.</div>
      </section>
    </div>
  );
}
