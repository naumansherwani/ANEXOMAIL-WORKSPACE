import { useState } from "react";
import { setSetting } from "./api.js";
import { useCity } from "./city.js";
import { nearestPlace, placeLabel, searchPlaces } from "./places.js";

// Founder Settings Center — S1 (plan: docs/claude/FOUNDER-SETTINGS-CENTER-PORT-28OCT.md). Every control here is wired to a real server setting (E108).
const TABS = [["personal", "Personal"], ["appearance", "Appearance"]];

function Switch({ on, label, onChange, busy }) {
  return <button className={`switch ${on ? "on" : ""}`} role="switch" aria-checked={on} aria-label={label} disabled={busy} onClick={() => onChange(!on)}><i /></button>;
}

export function SettingsView({ p, fx, setFx, slim, setSlim, reload }) {
  const [tab, setTab] = useState("personal"), [busy, setBusy] = useState(false), [msg, setMsg] = useState(null);
  const city = useCity(), [q, setQ] = useState(""), [found, setFound] = useState(null), [problem, setProblem] = useState(null), [locating, setLocating] = useState(false);
  const hits = searchPlaces(q);
  const pick = (pl) => { setFound(null); setQ(""); setProblem(null); save("personal.home", { city: pl.city, country: pl.country, iana: pl.iana, lat: pl.lat, lon: pl.lon }); };
  const detect = () => {
    setProblem(null); setFound(null);
    if (!("geolocation" in navigator)) { setProblem("This browser cannot detect your location. Search for your city below."); return; }
    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => { setLocating(false); const n = nearestPlace(pos.coords.latitude, pos.coords.longitude); if (n) setFound(n); else setProblem("Could not work out a city from that. Search for it below."); },
      (err) => { setLocating(false); setProblem(err.code === 1 ? "Location is blocked for this site. Allow it in the address bar, or search for your city below." : err.code === 3 ? "That took too long. Try again, or search for your city below." : "Your device could not work out where it is. Search for your city below."); },
      { enableHighAccuracy: false, timeout: 12000, maximumAge: 600000 });
  };
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
          <div className="setcity">
            <div className="setrow nobr">
              <div><b>Home city</b>
                <p className="dim">The whole workspace — clock, greeting (sunset-aware), dates and times — follows this city.</p>
                <p className="citynow"><span className="chip ok">{city.source === "home" ? placeLabel(city) : `Following this device · ${city.city}`}</span>
                  {city.source === "home" && city.device !== city.iana && <span className="chip warn">This device is currently in a different zone ({city.device.split("/").pop().replace(/_/g, " ")})</span>}</p></div>
              {city.source === "home" && <button className="ghost" disabled={busy} onClick={() => save("personal.home", null)}>Use device city</button>}
            </div>
            <div className="row left"><button className="ghost" disabled={busy || locating} onClick={detect}>{locating ? "Detecting…" : "Detect my city"}</button>
              <span className="dim small">Asks your browser once. The nearest city is chosen on your device — your exact position is never sent or saved.</span></div>
            {found && <div className="note" role="status">Closest city we have: <b>{placeLabel(found.place)}</b>{found.km >= 1 ? ` (about ${Math.round(found.km)} km away)` : ""}.
              <div className="row left"><button disabled={busy} onClick={() => pick(found.place)}>Use {found.place.city}</button><button className="ghost" onClick={() => setFound(null)}>Not this</button></div></div>}
            {problem && <div className="err banner" role="alert">{problem}</div>}
            <label className="fld"><span className="dim small">Or search your city</span>
              <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Lahore, Dubai, London…" autoComplete="off" maxLength={40} /></label>
            {q.trim() && <ul className="hits">{hits.length === 0 ? <li className="dim">No city by that name in our list. Try a bigger city nearby.</li> :
              hits.map((pl) => <li key={`${pl.city}-${pl.country}`}><button className="hit" disabled={busy} onClick={() => pick(pl)}><span>{pl.city}</span><em>{pl.country}</em></button></li>)}</ul>}
          </div>
          <div className="setrow"><div><b>Name and photo</b><p className="dim">Change them on your Profile page (Account menu → Profile &amp; photo).</p></div></div>
          {msg && <div className={msg.ok ? "note" : "err banner"} role="status">{msg.t}</div>}
          <div className="src">Saved on your founder account; the server checks the time zone against the real zone database. With no home city set, everything follows the city your device is in and adapts when you travel.</div>
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
