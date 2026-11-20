import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import * as api from "./mail_api";
import { createDeviceKey, keyHistory, loadWrapped, lock, unlockDeviceKey, unlocked } from "./mail_keys";

// DK3 (20 Nov 2026) - Mail device key, inside Settings > Privacy > Security keys (additive section, no other screen changes).
// The private halves are made in this browser's kernel, kept only wrapped by your passkey, and wiped on lock. The server holds the PUBLIC half only, so it cannot read post-quantum mail.
export function MailDeviceKey() {
  const [box, setBox] = useState(""), [active, setActive] = useState<{ key_id: string; fingerprint?: string } | null>(null), [here, setHere] = useState(false), [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false), [note, setNote] = useState<{ ok: boolean; t: string } | null>(null), [off, setOff] = useState(false);
  const refresh = useCallback(async (b: string) => {
    const h = await keyHistory(b); const a = h?.keys?.find((k) => k.status === "active") ?? null; setActive(a);
    setHere(a ? !!(await loadWrapped(b, a.key_id)) : false); setOpen(!!unlocked(b));
  }, []);
  useEffect(() => { let on = true; (async () => { try { const r = await api.boxes(); const b = r.boxes?.[0]?.id; if (!on) return; if (!r.connected || !b) { setOff(true); return; } setBox(b); await refresh(b); } catch { if (on) setOff(true); } })(); return () => { on = false; }; }, [refresh]);
  if (off) return null;
  const run = async (f: () => Promise<{ ok: boolean; error?: string }>, done: string) => { setBusy(true); setNote(null); const r = await f(); setBusy(false); setNote({ ok: r.ok, t: r.ok ? done : r.error ?? "That did not work." }); await refresh(box); };
  return <section className="panel" aria-label="Mail device key">
    <div className="panelhead"><h2>Mail device key</h2>
      <p className="dim">Post-quantum mail (ML-KEM-768 + X25519) is opened only on this device. The key is made in the browser kernel, kept wrapped by your passkey and wiped when you lock. The server holds the public half only.</p></div>
    <div className="setrow"><div><b>{active ? `Active key ${active.key_id}` : "No device key yet"}</b>
      <p className="dim">{active ? `Fingerprint ${(active.fingerprint ?? "").slice(0, 16)}… · ${here ? "this device holds it" : "NOT on this device (recovery with your two hardware keys)"} · ${open ? "unlocked for this session" : "locked"}` : "Until a key exists, new mail stays sealed with the vault key."}</p></div>
      <span style={{ display: "flex", gap: 6, alignItems: "center" }}>
        <Button variant="ghost" size="mini" disabled={busy || !box} onClick={() => void run(() => createDeviceKey(box), active ? "New key made and registered (the old one stays for old mail)." : "Device key made and registered.")}>{active ? "Rotate key" : "Create key"}</Button>
        {active && here && !open && <Button variant="ghost" size="mini" disabled={busy} onClick={() => void run(() => unlockDeviceKey(box, active.key_id), "Unlocked for this session.")}>Unlock</Button>}
        {open && <Button variant="ghost" size="mini" disabled={busy} onClick={() => { lock(); void refresh(box); setNote({ ok: true, t: "Locked. The private key is wiped from memory." }); }}>Lock now</Button>}
      </span></div>
    {note && <p role="status" className={note.ok ? "dim" : "err"}>{note.t}</p>}
  </section>;
}
