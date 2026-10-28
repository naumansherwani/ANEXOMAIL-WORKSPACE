import { useMemo, useState } from "react";
import { setSetting } from "./api.js";
import { browserZone } from "./greeting.js";

// Founder Settings Center — S1 (plan: docs/claude/FOUNDER-SETTINGS-CENTER-PORT-28OCT.md). Every control here is wired to a real server setting (E108).
const TABS = [["personal", "Personal"], ["appearance", "Appearance"]];

function Switch({ on, label, onChange, busy }) {
  return <button className={`switch ${on ? "on" : ""}`} role="switch" aria-checked={on} aria-label={label} disabled={busy} onClick={() => onChange(!on)}><i /></button>;
}

export function SettingsView({ p, fx, setFx, slim, setSlim, reload }) {
  const [tab, setTab] = useState("personal"), [busy, setBusy] = useState(false), [msg, setMsg] = useState(null);
  const zones = useMemo(() => { try { return Intl.supportedValuesOf("timeZone"); } catch { return []; } }, []);
  async function save(key, value, local) {
    setBusy(true); setMsg(null); if (local) local();
    try {
      const r = await setSetting(key, value);
      if (r.status === 200) { setMsg({ ok: true, t: "Saved." }); await reload(); }
      else setMsg({ ok: false, t: r.body?.error || `Not saved (HTTP ${r.status})` });
    } catch (x) { setMsg({ ok: false, t: x.message }); }
    setBusy(false);
  }
  return (
    <div className="col">
      <div className="tabs" role="tablist" aria-label="Settings sections">
        {TABS.map(([k, n]) => <button key={k} role="tab" aria-selected={tab === k} className={`tab ${tab === k ? "on" : ""}`} onClick={() => { setTab(k); setMsg(null); }}>{n}</button>)}
      </div>
      {p && p.available === false && <div className="note">Settings storage is not available yet — run the E108 SQL (sql-run.sh) on the server. Changes cannot be saved until then.</div>}
      {tab === "personal" && (
        <section className="card setcard">
          <div className="kicker">PERSONAL</div>
          <div className="setrow">
            <div><b>Home timezone</b><p className="dim">Your greeting, day-part and clock follow this zone. Default: this device ({browserZone().split("/").pop().replace(/_/g, " ")}).</p></div>
            <select aria-label="Home timezone" value={p?.timezone || ""} disabled={busy} onChange={(e) => save("personal.timezone", e.target.value || null)}>
              <option value="">Device default</option>
              {p?.timezone && !zones.includes(p.timezone) && <option value={p.timezone}>{p.timezone}</option>}
              {zones.map((z) => <option key={z} value={z}>{z.replace(/_/g, " ")}</option>)}
            </select>
          </div>
          <div className="setrow"><div><b>Name and photo</b><p className="dim">Change them on your Profile page (Account menu → Profile &amp; photo).</p></div></div>
          {msg && <div className={msg.ok ? "note" : "err banner"} role="status">{msg.t}</div>}
          <div className="src">Saved on your founder account and checked by the server against the real timezone database.</div>
        </section>
      )}
      {tab === "appearance" && (
        <section className="card setcard">
          <div className="kicker">APPEARANCE</div>
          <div className="setrow"><div><b>Graphics</b><p className="dim">Animated glowing edge and soft background light. Turn off for a plain, fastest-possible screen.</p></div>
            <Switch on={fx} label="Graphics" busy={busy} onChange={(v) => save("appearance.graphics", v, () => setFx(v))} /></div>
          <div className="setrow"><div><b>Compact sidebar</b><p className="dim">Start with the sidebar collapsed to icons.</p></div>
            <Switch on={slim} label="Compact sidebar" busy={busy} onChange={(v) => save("appearance.sidebar_slim", v, () => setSlim(v))} /></div>
          {msg && <div className={msg.ok ? "note" : "err banner"} role="status">{msg.t}</div>}
          <div className="src">Saved on your founder account, so every approved device shows the same.</div>
        </section>
      )}
      <div className="src setnext">Coming in order: Notifications (needs a delivery channel — Mail Desk, F5) · Privacy (session and passkey controls — after F2b) · Time machine, Drift &amp; schedule (after F2c). Nothing is shown here until it works for real.</div>
    </div>
  );
}
