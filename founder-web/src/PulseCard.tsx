// SYS-LIVE (his 16 Nov 07:10 order): a LIVE pulse of the running Rust server on the Systems page. Every 5 s the page asks the signed door /founder/v1/system/pulse (the WASM kernel verifies the answer).
// The clock shown is the SERVER clock (offset taken from the signed body), so it ticks by itself and proves the server answered; if no fresh answer arrives for 12 s the badge says Stale, never a frozen "Live".
import { useEffect, useRef, useState } from "react";
import * as api from "./mail_api";
import { fmtUp, pulseState } from "./pulse_pure";
import "./pulse.css";

export function PulseCard() {
  const [p, setP] = useState<api.Pulse | null>(null), [ok, setOk] = useState<number | null>(null), [now, setNow] = useState(Date.now()), off = useRef(0), [bad, setBad] = useState(false);
  useEffect(() => {
    let on = true;
    const go = () => { if (document.hidden) return; api.pulse().then((r) => { if (!on) return; if (r) { off.current = r.now_ms - Date.now(); setP(r); setOk(Date.now()); setBad(false); } else setBad(true); }).catch(() => on && setBad(true)); };
    go(); const t = window.setInterval(go, 5000), c = window.setInterval(() => setNow(Date.now()), 1000), v = () => { if (!document.hidden) go(); };
    document.addEventListener("visibilitychange", v);
    return () => { on = false; window.clearInterval(t); window.clearInterval(c); document.removeEventListener("visibilitychange", v); };
  }, []);
  const st = pulseState(ok, now), server = new Date(now + off.current);
  const clock = p ? server.toLocaleTimeString([], { hour12: false }) : "--:--:--", day = p ? server.toLocaleDateString([], { day: "numeric", month: "short", year: "numeric" }) : "";
  const up = p ? p.uptime_s + Math.max(0, Math.floor((now - (ok ?? now)) / 1000)) : 0;
  return (
    <div className="pl">
      <div className="pl-top"><span className={`pl-badge ${st}`} role="status"><i aria-hidden="true" />{st === "live" ? "Live" : st === "stale" ? "Stale, no fresh answer" : "Waiting for the server"}</span>
        <span className="pl-clock" aria-label="Server clock">{clock}</span><span className="dim small">{day} · server clock</span></div>
      {bad && <p className="dim small" role="alert">The pulse door did not answer (the run of the new Rust install is needed once). The page keeps asking every 5 seconds.</p>}
      {p && <div className="sm-hb">
        <div><span className="sm-k">Running for (liveness)</span><b>{fmtUp(up)}</b><em>beat #{p.seq} · since {new Date(p.started_ms).toLocaleString([], { hour12: false })}</em></div>
        <div><span className="sm-k">Server build</span><b>{p.build}</b><em>{p.build_time === "unknown" ? "install time not recorded" : `installed ${new Date(p.build_time).toLocaleString([], { hour12: false })}`}</em></div>
        <div><span className="sm-k">Database answered in</span><b>{p.db_ms === null ? "no answer" : `${p.db_ms} ms`}</b><em>readiness: real round trip, just now</em></div>
        <div><span className="sm-k">Rust engine (Tokio)</span><b>{p.tokio.alive_tasks} tasks</b><em>{p.tokio.workers} workers, queue {p.tokio.queue_depth}</em></div>
        <div><span className="sm-k">Outgoing mail</span><b>{p.sending ? (p.sending.send_enabled ? "ON" : "OFF") : "unknown"}</b><em>{p.sending ? `${p.sending.waiting} waiting in the Outbox` : "switch door not answering"}</em></div>
      </div>}
      <p className="dim small">Asked every 5 seconds over the signed kernel door. This is the running server, not a file.</p>
    </div>
  );
}
