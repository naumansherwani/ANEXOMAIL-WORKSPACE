import { useEffect, useState, useSyncExternalStore } from "react";
import { deviceStatus, get } from "./api";
import { parseBoard } from "./sessions_pure";
import { orbLine, orbLineHidden, setOrbLineHidden, type OrbLine as Line } from "./orbline_pure";
import { Switch } from "@/components/ui/switch";
import "./orbline.css";

const sub = (cb: () => void) => { window.addEventListener("orbline-change", cb); return () => window.removeEventListener("orbline-change", cb); };

// LA-3 (additive): one small line in the hero text. Data = this session's row of /sessions/board (protocol, key source) + deviceStatus().psrc. Read-only, refreshed every 60 s.
export function OrbLine() {
  const hidden = useSyncExternalStore(sub, orbLineHidden, () => false);
  const [line, setLine] = useState<Line | null>(null);
  useEffect(() => {
    if (hidden) return;
    let alive = true;
    const run = async () => {
      try {
        const e = await get("/founder/v1/sessions/board");
        const b = (e.data as { available?: boolean })?.available === false ? null : parseBoard(e.data);
        const me = b?.sessions.find((s) => s.current);
        if (alive) setLine(me ? orbLine({ protocol: me.protocol, keySource: me.keySource, psrc: deviceStatus().psrc }) : null);
      } catch { /* keep the last line; a blip never invents one */ }
    };
    void run(); const t = setInterval(run, 60000);
    return () => { alive = false; clearInterval(t); };
  }, [hidden]);
  if (hidden || !line) return null;
  return (
    <p className="orbline" data-tone={line.tone} aria-label={line.sr}>
      {line.parts.map((p, i) => <span key={p.text}>{i > 0 && <i aria-hidden="true"> · </i>}<b data-tone={p.tone}>{p.text}</b></span>)}
    </p>
  );
}

/** Settings row (this device): show or hide the line. Default on. */
export function OrbLineSwitch() {
  const hidden = useSyncExternalStore(sub, orbLineHidden, () => false);
  return (
    <div className="setrow"><div><b>Connection line under the status</b><p className="dim">One small line on the Dashboard: HTTP/3 QUIC · Hardware key · ML-DSA-65. Shown only for facts the server confirmed. This device only.</p></div>
      <Switch checked={!hidden} aria-label="Connection line" onCheckedChange={(v) => setOrbLineHidden(!v)} /></div>
  );
}
