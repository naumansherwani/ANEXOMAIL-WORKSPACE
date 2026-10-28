import { useEffect, useRef, useState } from "react";
import { get, put, signOut, deviceStatus } from "./api.js";

const initials = (n, e) => (String(n || e || "?").trim().split(/\s+/).slice(0, 2).map((x) => x[0]).join("") || "?").toUpperCase();

export function Avatar({ p, size = 36 }) {
  return <span className="av" style={{ width: size, height: size, fontSize: Math.round(size * 0.38) }} aria-hidden="true">{p?.avatar_url ? <img src={p.avatar_url} alt="" /> : initials(p?.display_name, p?.email)}</span>;
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
      <button className="avbtn" aria-label="Account" aria-haspopup="menu" aria-expanded={open} onClick={() => setOpen((v) => !v)}><Avatar p={p} size={36} /></button>
      {open && <div className="menu" role="menu">
        <div className="mhead"><Avatar p={p} size={44} /><div><b>{p?.display_name || "Founder"}</b><span>{p?.email || ""}</span><i className="rolechip">Founder · Chairman</i></div></div>
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
          <div><div className="big" style={{ fontSize: 24 }}>{p?.display_name || "Founder"}</div><div className="dim">{p?.email}</div><span className="rolechip">Founder · Chairman</span></div>
        </div>
        <input ref={file} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={choose} />
        <div className="row"><button className="btn" disabled={busy} onClick={() => file.current?.click()}>Upload photo</button>{p?.avatar_url && <button disabled={busy} onClick={remove}>Remove</button>}</div>
        {msg && <div className={msg.ok ? "note" : "err banner"} role="status">{msg.t}</div>}
        {p && !p.profile_found && <div className="note">No profile row was found for this account, so a photo cannot be saved yet.</div>}
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
