// E182: the real ON/OFF switch for outgoing mail (his 16 Nov 06:21 order: hand icon, real working). Systems > Mail health and the "Real outgoing mail" pill in the Brain list.
// It reads the real state from the server and writes through the ledgered door: OFF = mails wait in the Outbox, nothing is sent, incoming mail untouched. No mock state: the switch shows what the server answered.
import { useCallback, useEffect, useState } from "react";
import * as api from "./mail_api";
import "./sendswitch.css";

export function SendSwitch({ compact = false }: { compact?: boolean }) {
  const [s, setS] = useState<api.Sending | null | undefined>(undefined), [busy, setBusy] = useState(false), [err, setErr] = useState("");
  const load = useCallback(() => { api.sendingState().then(setS).catch(() => setS(null)); }, []);
  useEffect(() => { load(); const t = window.setInterval(load, 15000); return () => window.clearInterval(t); }, [load]);
  const flip = async () => { if (!s || busy) return; setBusy(true); setErr(""); const r = await api.sendingSet(!s.send_enabled); if (!r.ok) setErr(r.error || "Could not change it"); load(); setBusy(false); };
  if (s === undefined) return <span className="ss ss-wait dim small">Checking…</span>;
  if (s === null) return <span className="ss ss-wait dim small">Switch not available yet (E182 SQL step not run)</span>;
  const on = s.send_enabled;
  return (
    <span className={`ss ${compact ? "ss-c" : ""}`}>
      <button type="button" role="switch" aria-checked={on} aria-label={on ? "Sending is ON, press to turn OFF" : "Sending is OFF, press to turn ON"} className={`ss-sw ${on ? "on" : "off"}`} disabled={busy} onClick={() => void flip()}>
        <svg className="ss-hand" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 11V5.5a1.5 1.5 0 0 1 3 0V10m0 0V4.5a1.5 1.5 0 0 1 3 0V10m0 0V6.5a1.5 1.5 0 0 1 3 0V13c0 4-2.5 7-6.5 7-3 0-4.6-1.6-6-4l-2-3.4a1.4 1.4 0 0 1 2.4-1.4L9 14" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg>
        <i className="ss-knob" aria-hidden="true" />
        <span className="ss-t">{busy ? "…" : on ? "Sending ON" : "Sending OFF"}</span>
      </button>
      {!compact && <span className="dim small ss-note">{on ? "Mail leaves 30 seconds after you press Send." : "Mail waits in the Outbox, nothing is sent."}{s.waiting > 0 ? ` ${s.waiting} waiting.` : ""}</span>}
      {err && <span role="alert" className="ss-err small">{err}</span>}
    </span>
  );
}
