import { useEffect, useRef, useState } from "react";
import { setSetting, signOut, deviceStatus } from "./api";
import type { Prof, Msg } from "./types";

// Full name: the account profile first, else the signed-in session's own name. Never invented (FC26).
export function jwtName() {
  try {
    const t = window.localStorage.getItem("anexo.session.token"); if (!t) return "";
    const p = JSON.parse(decodeURIComponent(escape(atob(t.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")))));
    const m = p.user_metadata || {};
    return String(m.display_name || m.full_name || m.name || p.name || "").trim().slice(0, 60);
  } catch { return ""; }
}
export const nameOf = (p?: Pick<Prof, "display_name"> | null) => String(p?.display_name || "").trim() || jwtName();
// Initials: first + last name. A leading "Muhammad"-type prefix is skipped when real names follow it (Muhammad Nauman Sherwani -> NS).
const PREFIX = /^(muhammad|mohammad|mohammed|mohd|md|mr|mrs|ms|dr)\.?$/i;
export const callName = (n?: string | null) => { const w = String(n || "").trim().split(/\s+/).filter(Boolean); return (w.length >= 2 && PREFIX.test(w[0]) ? w[1] : w[0]) || ""; };
export function initials(n?: string | null, e?: string | null) {
  let w = String(n || "").trim().split(/\s+/).filter(Boolean);
  if (w.length >= 3 && PREFIX.test(w[0])) w = w.slice(1);
  if (!w.length) w = [String(e || "?").split("@")[0]];
  const a = w[0][0] || "?", b = w.length > 1 ? w[w.length - 1][0] : "";
  return (a + b).toUpperCase();
}

export function Avatar({ p, size = 36 }: { p?: Prof | null; size?: number }) {
  return <span className="av" style={{ width: size, height: size, fontSize: Math.round(size * 0.38) }} aria-hidden="true">{p?.avatar_url ? <img src={p.avatar_url} alt="" /> : initials(nameOf(p), p?.email)}</span>;
}

// Scale to <=320px, JPEG; step the quality down until it fits the server limit (130 KB). The user never sees "too large" for a normal photo.
export async function shrink(file: File): Promise<string> {
  if (!/^image\/(jpeg|png|webp)$/.test(file.type)) throw new Error("Choose a jpg, png or webp photo.");
  const bmp = await createImageBitmap(file);
  const s = Math.min(1, 320 / Math.max(bmp.width, bmp.height)), w = Math.max(1, Math.round(bmp.width * s)), h = Math.max(1, Math.round(bmp.height * s));
  const c = document.createElement("canvas"); c.width = w; c.height = h; c.getContext("2d")!.drawImage(bmp, 0, 0, w, h);
  for (const q of [0.88, 0.78, 0.68, 0.55, 0.42]) {
    const u = c.toDataURL("image/jpeg", q);
    if (u.length <= 170000) return u;
  }
  throw new Error("This photo is too detailed to shrink — choose another one.");
}

// Very faint light that follows the cursor around the photo (CSS vars; no re-render).
const glow = (e: React.PointerEvent<HTMLElement>) => { const b = e.currentTarget.getBoundingClientRect(); e.currentTarget.style.setProperty("--gx", `${e.clientX - b.left}px`); e.currentTarget.style.setProperty("--gy", `${e.clientY - b.top}px`); };

export function AccountMenu({ p, go }: { p: Prof | null; go: (v: string) => void }) {
  const [open, setOpen] = useState(false), ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const away = (e: PointerEvent) => { if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false); };
    const esc = (e: KeyboardEvent) => { if (e.key === "Escape") setOpen(false); };
    document.addEventListener("pointerdown", away); document.addEventListener("keydown", esc);
    return () => { document.removeEventListener("pointerdown", away); document.removeEventListener("keydown", esc); };
  }, [open]);
  const ds = deviceStatus();
  const item = (label: string, fn: () => void) => <button role="menuitem" className="mi" onClick={() => { setOpen(false); fn(); }}>{label}</button>;
  return (
    <div className="acct" ref={ref}>
      <button className="avbtn" onPointerMove={glow} aria-label="Account" aria-haspopup="menu" aria-expanded={open} onClick={() => setOpen((v) => !v)}><Avatar p={p} size={36} /></button>
      {open && <div className="menu" role="menu">
        <div className="mhead"><Avatar p={p} size={44} /><div><b>{nameOf(p) || "Founder"}</b><span>{p?.email || ""}</span><i className="rolechip">Founder · Chairman</i></div></div>
        {item("Profile & photo", () => go("profile"))}
        {item("Settings", () => go("settings"))}
        {item("Devices & sessions", () => go("profile"))}
        {item("Audit ledger", () => go("audit"))}
        <div className="msep" />
        <div className="mnote">This browser: {ds.mode === "device" ? `approved · ${ds.label}` : ds.mode === "legacy" ? "approval not active yet" : "checking"}</div>
        {item("Sign out", signOut)}
      </div>}
    </div>
  );
}

export function ProfileView({ p, reload }: { p: Prof | null; reload: () => Promise<void> | void }) {
  const [busy, setBusy] = useState(false), [msg, setMsg] = useState<Msg>(null), [nm, setNm] = useState<string | null>(null), file = useRef<HTMLInputElement>(null);
  const ds = deviceStatus();
  const shown = nm ?? (p?.display_name || "");
  async function save(key: string, value: unknown, okText: string) {
    setBusy(true); setMsg(null);
    try {
      const r = await setSetting(key, value);
      if (r.status === 200) { setMsg({ ok: true, t: okText }); setNm(null); await reload(); }
      else setMsg({ ok: false, t: r.body?.error || `Not saved (HTTP ${r.status})` });
    } catch (x) { setMsg({ ok: false, t: (x as Error).message }); }
    setBusy(false);
  }
  async function choose(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0]; e.target.value = ""; if (!f) return;
    try { await save("personal.avatar", await shrink(f), "Photo saved."); } catch (x) { setMsg({ ok: false, t: (x as Error).message }); }
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
        <div className="row"><button className="btn" disabled={busy} onClick={() => file.current?.click()}>Upload photo</button>{p?.avatar_url && <button disabled={busy} onClick={() => save("personal.avatar", null, "Photo removed.")}>Remove</button>}</div>
        <label className="fld"><span className="dim small">Display name</span>
          <span className="fldrow"><input value={shown} maxLength={60} placeholder={nameOf(p) || "Your name"} onChange={(e) => setNm(e.target.value)} />
            <button disabled={busy || nm === null || nm === (p?.display_name || "")} onClick={() => save("personal.display_name", nm!.trim() === "" ? null : nm!.trim(), "Name saved.")}>Save</button></span></label>
        {msg && <div className={msg.ok ? "note" : "err banner"} role="status">{msg.t}</div>}
        {p && p.available === false && <div className="note">Settings storage is not available yet — run the E108 SQL (sql-run.sh) on the server.</div>}
        <div className="src">Photos are shrunk in your browser to fit (jpg, png, webp). Stored in your founder settings, separate from the user app; every change is written to the audit ledger.</div>
      </section>
      <section className="card">
        <div className="kicker">THIS DEVICE</div>
        <div className="big" style={{ fontSize: 20 }}>{ds.mode === "device" ? "Approved" : ds.mode === "legacy" ? "Approval not active" : "Checking"}</div>
        <div className="dim">{ds.label || "—"}</div>
        <div className="src">The full list of your approved devices, with one-click revoke, arrives with the Devices screen (after F2c). Until then, list and revoke on the server with founder-device.sh.</div>
      </section>
    </div>
  );
}
