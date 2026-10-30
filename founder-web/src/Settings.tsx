import { useState, type ReactNode } from "react";
import { setSetting } from "./api";
import { useCity } from "./city";
import { nearestPlace, placeLabel, searchPlaces, type Place } from "./places";
import type { Prof, Msg as MsgT } from "./types";
import { Switch } from "@/components/ui/switch";
import { Button } from "@/components/ui/button";
import { Avatar, nameOf } from "./Profile";

// Founder Settings Center — S1 (plan: docs/claude/FOUNDER-SETTINGS-CENTER-PORT-28OCT.md). Every control here is wired to a real server setting (E108).
const I: Record<string, ReactNode> = {
  personal: <path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm-7 8a7 7 0 0 1 14 0" />,
  appearance: <><circle cx="12" cy="12" r="4" /><path d="M12 3v2m0 14v2M3 12h2m14 0h2M5.6 5.6 7 7m10 10 1.4 1.4M5.6 18.4 7 17M17 7l1.4-1.4" /></>,
  pin: <><path d="M12 21s7-6.2 7-11a7 7 0 1 0-14 0c0 4.8 7 11 7 11Z" /><circle cx="12" cy="10" r="2.5" /></>,
  search: <><circle cx="11" cy="11" r="6" /><path d="m20 20-4-4" /></>,
};
const Ico = ({ k }: { k: string }) => <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{I[k]}</svg>;
const TABS = [["personal", "Personal", "Name, photo and home city"], ["appearance", "Appearance", "Graphics and sidebar"]];
const SOON = [["Time machine & Drift", "after F2c"], ["Privacy", "after passkey"], ["Notifications", "with Decide / Mail Desk"]];

type Props = { p: Prof | null; fx: boolean; setFx: (v: boolean) => void; slim: boolean; setSlim: (v: boolean) => void; reload: () => Promise<void> | void; go?: (v: string) => void };
export function SettingsView({ p, fx, setFx, slim, setSlim, reload, go }: Props) {
  const [tab, setTab] = useState("personal"), [busy, setBusy] = useState(false), [msg, setMsg] = useState<MsgT>(null);
  const city = useCity(), [q, setQ] = useState(""), [found, setFound] = useState<{ place: Place; km: number } | null>(null), [problem, setProblem] = useState<string | null>(null), [locating, setLocating] = useState(false);
  const hits = searchPlaces(q);
  const pick = (pl: Place) => { setFound(null); setQ(""); setProblem(null); save("personal.home", { city: pl.city, country: pl.country, iana: pl.iana, lat: pl.lat, lon: pl.lon }); };
  const detect = () => {
    setProblem(null); setFound(null);
    if (!("geolocation" in navigator)) { setProblem("This browser cannot detect your location. Search for your city instead."); return; }
    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => { setLocating(false); const n = nearestPlace(pos.coords.latitude, pos.coords.longitude); if (n) setFound(n); else setProblem("Could not work out a city from that. Search for it instead."); },
      (err) => { setLocating(false); setProblem(err.code === 1 ? "Location is blocked for this site. Allow it in the address bar, or search for your city." : err.code === 3 ? "That took too long. Try again, or search for your city." : "Your device could not work out where it is. Search for your city."); },
      { enableHighAccuracy: false, timeout: 12000, maximumAge: 600000 });
  };
  async function save(key: string, value: unknown, local?: () => void) {
    setBusy(true); setMsg(null); if (local) local();
    try {
      const r = await setSetting(key, value);
      if (r.status === 200) { setMsg({ ok: true, t: "Saved." }); await reload(); }
      else setMsg({ ok: false, t: r.body?.error || `Not saved (HTTP ${r.status})` });
    } catch (x) { setMsg({ ok: false, t: (x as Error).message }); }
    setBusy(false);
  }
  const Msg = () => msg ? <div className={msg.ok ? "toast ok" : "toast bad"} role="status">{msg.t}</div> : null;
  return (
    <div className="setpage">
      {p && p.available === false && <div className="toast bad">Settings storage is not available yet — run the E108 SQL (sql-run.sh) on the server. Changes cannot be saved until then.</div>}
      <div className="setgrid">
        <nav className="setnav" aria-label="Settings sections">
          {TABS.map(([k, n, d]) => <button key={k} className={`setitem ${tab === k ? "on" : ""}`} aria-current={tab === k} onClick={() => { setTab(k); setMsg(null); }}><Ico k={k} /><span><b>{n}</b><small>{d}</small></span></button>)}
          <div className="setsoon"><div className="sidehead">COMING, IN ORDER</div>{SOON.map(([n, w]) => <div key={n} className="soonrow"><span>{n}</span><em>{w}</em></div>)}</div>
        </nav>
        <div className="setmain">
          {tab === "personal" && <>
            <section className="panel">
              <div className="panelhead"><h2>Profile</h2></div>
              <div className="prow">
                <Avatar p={p} size={56} />
                <div className="pwho"><b>{p ? nameOf(p) : "—"}</b><span className="dim">{p?.email}</span></div>
                {go && <Button variant="ghost" size="mini" onClick={() => go("profile")}>Edit name &amp; photo</Button>}
              </div>
            </section>
            <section className="panel">
              <div className="panelhead"><h2>Home city</h2><p className="dim">The clock, greeting (sunset-aware), dates and every time in the workspace follow this city.</p></div>
              <div className="cityhero">
                <span className="pinico"><Ico k="pin" /></span>
                <div className="cityname"><b>{city.city}</b><span className="dim">{city.source === "home" ? `${city.country || ""} · saved as your home city` : "following this device — changes when you travel"}</span></div>
                {city.source === "home" && <Button variant="ghost" size="mini" disabled={busy} onClick={() => save("personal.home", null)}>Use device city</Button>}
              </div>
              {city.source === "home" && city.device !== city.iana && <div className="toast warn">This device is currently in a different zone ({(city.device.split("/").pop() ?? "").replace(/_/g, " ")}). Times still follow {city.city}.</div>}
              <div className="cityact">
                <label className="searchbox"><Ico k="search" /><input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search a city — Lahore, Dubai, London…" autoComplete="off" maxLength={40} aria-label="Search your city" />
                  {q.trim() && <ul className="hits pop">{hits.length === 0 ? <li className="dim">No city by that name in our list. Try a bigger city nearby.</li> :
                    hits.map((pl) => <li key={`${pl.city}-${pl.country}`}><button type="button" className="hit" disabled={busy} onClick={() => pick(pl)}><span>{pl.city}</span><em>{pl.country}</em></button></li>)}</ul>}
                </label>
                <Button variant="ghost" disabled={busy || locating} onClick={detect}>{locating ? "Detecting…" : "Detect my city"}</Button>
              </div>
              <p className="dim small">“Detect” asks your browser once and picks the nearest city on your device. Your exact position is never sent or saved.</p>
              {found && <div className="toast ok" role="status">Closest city: <b>{placeLabel(found.place)}</b>{found.km >= 1 ? ` (about ${Math.round(found.km)} km away)` : ""}.
                <span className="inl"><button className="mini" disabled={busy} onClick={() => pick(found.place)}>Use {found.place.city}</button><button className="ghost mini" onClick={() => setFound(null)}>Not this</button></span></div>}
              {problem && <div className="toast bad" role="alert">{problem}</div>}
              <Msg />
            </section>
          </>}
          {tab === "appearance" && <section className="panel">
            <div className="panelhead"><h2>Appearance</h2></div>
            <div className="setrow"><div><b>Graphics</b><p className="dim">Animated glowing edge and soft background light. Turn off for a plain, fastest-possible screen.</p></div>
              <Switch checked={fx} aria-label="Graphics" disabled={busy} onCheckedChange={(v) => save("appearance.graphics", v, () => setFx(v))} /></div>
            <div className="setrow last"><div><b>Compact sidebar</b><p className="dim">Start with the sidebar collapsed to icons.</p></div>
              <Switch checked={slim} aria-label="Compact sidebar" disabled={busy} onCheckedChange={(v) => save("appearance.sidebar_slim", v, () => setSlim(v))} /></div>
            <Msg />
          </section>}
        </div>
      </div>
    </div>
  );
}
