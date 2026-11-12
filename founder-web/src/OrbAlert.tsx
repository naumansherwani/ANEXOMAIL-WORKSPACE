import { useEffect, useState } from "react";
import { get } from "./api";
import type { DbscStatus } from "./dbsc_pure";
import { orbAlert, type OrbAlertView } from "./orbalert_pure";
import "./orbline.css";

// LA-4 (additive): drawn only when /dbsc/status reports blocked or would-be-blocked requests in 24 h. Quiet = renders nothing. Links to the Devices board.
export function OrbAlert({ go }: { go?: (v: string) => void }) {
  const [v, setV] = useState<OrbAlertView | null>(null);
  useEffect(() => {
    let alive = true;
    const run = async () => { try { const e = await get<DbscStatus>("/founder/v1/dbsc/status"); if (alive) setV(orbAlert(e.data)); } catch { /* a blip keeps the last state */ } };
    void run(); const t = setInterval(run, 60000);
    return () => { alive = false; clearInterval(t); };
  }, []);
  if (!v) return null;
  return (
    <p className="orbalert" data-tone={v.tone} role="status">
      <span className="orbalert-dot" aria-hidden="true" />
      <a href="#/devices" aria-label={v.sr} onClick={go ? (e) => { e.preventDefault(); go("devices"); } : undefined}>{v.text}</a>
    </p>
  );
}
