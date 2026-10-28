import { useState } from "react";

// Founder Settings Center — S1 start (plan: docs/claude/FOUNDER-SETTINGS-CENTER-PORT-28OCT.md).
// Real settings only. Graphics is a per-device preference today; saving it on the account (synced to every approved device) arrives with E108.
const TABS = [["appearance", "Appearance"]];

export function SettingsView({ fx, setFx }) {
  const [tab, setTab] = useState("appearance");
  return (
    <div className="col">
      <div className="tabs" role="tablist" aria-label="Settings sections">
        {TABS.map(([k, n]) => <button key={k} role="tab" aria-selected={tab === k} className={`tab ${tab === k ? "on" : ""}`} onClick={() => setTab(k)}>{n}</button>)}
      </div>
      {tab === "appearance" && (
        <section className="card setcard">
          <div className="kicker">APPEARANCE</div>
          <div className="setrow">
            <div><b>Graphics</b><p className="dim">Animated glowing edge and soft background light. Turn off for a plain, fastest-possible screen.</p></div>
            <button className={`switch ${fx ? "on" : ""}`} role="switch" aria-checked={fx} aria-label="Graphics" onClick={() => setFx((v) => !v)}><i /></button>
          </div>
          <div className="src">Saved on this device. Syncing settings across all your approved devices comes with the settings database step (E108).</div>
        </section>
      )}
    </div>
  );
}
