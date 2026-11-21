import { useEffect, useState, type ReactNode } from "react";
import { BrandMark } from "../signin/BrandMark";
import { MODULES } from "./modules/registry";

/** Admin Desk shell (R4-1, UI step 1, 22 Nov 2026): cinematic night-office look of the Desk login, calm work screen (ONE hero moment: the greeting).
 *  Pure presentation: every value comes in as a prop from a Desk-signed answer the kernel verified. No founder import, no raw fetch, no mock data.
 *  One build for 390 / 820 / 1200+: a left glass rail from 820 up, a bottom tab bar below it (CSS only, no JS size switch). Honours reduced motion and forced colours. */
export type ShellMe = { email: string; name: string | null; role: string; expires_at: string };
type NavItem = { key: string; label: string; glyph: ReactNode; live: boolean; group: string };
const ico = (d: string) => <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={d} /></svg>;
/** Groups follow his word (22 Nov 02:43): company mailboxes sit under ANEXOMAIL WORKSPACE, and the folder ADMIN DESK holds everything about the users' problems. */
const GLYPH: Record<string, string> = {
  inboxes: "M3 13l3-8h12l3 8v6a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1zM3 13h5l1 3h6l1-3h5", cases: "M4 5h16v11H8l-4 4zM8 9h8M8 12h5", movein: "M3 12h13M12 6l6 6-6 6M20 4v16",
  team: "M9 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM3 20a6 6 0 0 1 12 0M17 11a2.5 2.5 0 1 0 0-5M16 14.5A5 5 0 0 1 21 20", audit: "M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6zM9 12l2 2 4-4",
  people: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0", analytics: "M4 20V10M10 20V4M16 20v-7M22 20H2", bridge: "M3 17c3-8 15-8 18 0M3 17h18M7 17v-4M12 17v-6M17 17v-4", alerts: "M12 4a6 6 0 0 0-6 6v4l-2 3h16l-2-3v-4a6 6 0 0 0-6-6zM10 20a2 2 0 0 0 4 0",
  policy: "M5 4h14v16H5zM9 9h6M9 13h6", shifts: "M12 7v5l3 2M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z", sla: "M12 7v5l3 2M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z",
};
const DEFAULT_GLYPH = "M12 8v8M8 12h8M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z";
/** The rail is built from the module registry (modules/registry.ts): one list, never a second copy here. Groups follow his word (22 Nov 02:49): cases sit under ANEXOMAIL WORKSPACE, user problems and Managed Move-In under ADMIN DESK. */
const NAV: NavItem[] = [
  { key: "dashboard", group: "", label: "Dashboard", glyph: ico("M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"), live: true },
  ...MODULES.map((m): NavItem => ({ key: m.key, group: m.group, label: m.label, glyph: ico(GLYPH[m.key] ?? DEFAULT_GLYPH), live: m.status === "live" })),
];
const PIN_KEY = "anexo.desk.pins";
const readPins = (): string[] => { try { const v = JSON.parse(window.localStorage.getItem(PIN_KEY) || "[]"); return Array.isArray(v) ? v.filter((x) => typeof x === "string") : []; } catch { return []; } };
const writePins = (p: string[]) => { try { window.localStorage.setItem(PIN_KEY, JSON.stringify(p)); } catch { /* per-viewer convenience only */ } };
/** Pinned items float to a "Pinned" group at the top; unpinning puts them back in their own group. */
export function orderNav(items: NavItem[], pins: string[]): { label: string; items: NavItem[] }[] {
  const pinned = items.filter((n) => pins.includes(n.key) && n.key !== "dashboard"), rest = items.filter((n) => !pinned.includes(n));
  const out: { label: string; items: NavItem[] }[] = [];
  for (const n of rest) { const g = out.find((x) => x.label === n.group); if (g) g.items.push(n); else out.push({ label: n.group, items: [n] }); }
  if (pinned.length) out.splice(out.length && out[0].label === "" ? 1 : 0, 0, { label: "Pinned", items: pinned });   // Dashboard stays on top, Pinned right under it
  return out;
}

// Postgres sends "2026-11-22 13:58:12.54+05" (offset without minutes, long fraction): normalise so every browser parses it.
export function parseWhen(iso: string): Date | null {
  const n = iso.trim().replace(" ", "T").replace(/(\.\d{3})\d*/, "$1").replace(/([+-]\d{2})$/, "$1:00"), d = new Date(n);
  return isNaN(d.getTime()) ? null : d;
}
export function remaining(end: Date | null, now: number): string {
  if (!end) return "";
  const m = Math.floor((end.getTime() - now) / 60000);
  if (m <= 0) return "ended";
  const h = Math.floor(m / 60), r = m % 60;
  return h > 0 ? `${h} h ${r} min` : `${r} min`;
}
export function greeting(h: number): string { return h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"; }

const CSS = `
.dsk{font-family:Inter,ui-sans-serif,system-ui,-apple-system,'Segoe UI',sans-serif;--ink:#E8EEF9;--mute:#9FB3D6;--glass:rgba(12,22,46,.62);--line:rgba(160,200,255,.16);--amber:255,170,70;position:relative;min-height:100dvh;color:var(--ink);background:linear-gradient(180deg,#060B19 0%,#0A1730 48%,#0F3460 100%);overflow-x:hidden}
.dsk::before{content:"";position:fixed;inset:0;pointer-events:none;background:radial-gradient(55% 45% at 94% 0%,rgba(var(--amber),.26),transparent 62%),radial-gradient(60% 55% at 6% 100%,rgba(15,52,96,.85),transparent 70%)}
.dsk::after{content:"";position:fixed;inset:0;pointer-events:none;background:repeating-linear-gradient(90deg,transparent 0,transparent 14vw,rgba(160,200,255,.05) 14vw,rgba(160,200,255,.05) calc(14vw + 1px));box-shadow:inset 0 0 180px rgba(0,0,0,.55)}
.dsk-rail{overflow-x:auto;scrollbar-width:none;position:fixed;z-index:20;left:0;right:0;bottom:0;display:flex;justify-content:space-around;gap:2px;padding:6px max(8px,env(safe-area-inset-left)) calc(6px + env(safe-area-inset-bottom)) max(8px,env(safe-area-inset-right));background:var(--glass);backdrop-filter:blur(18px) saturate(140%);-webkit-backdrop-filter:blur(18px) saturate(140%);border-top:1px solid var(--line)}
.dsk-brand,.dsk-grp,.dsk-pin{display:none}.dsk-scroll{display:contents}
.dsk-nav{flex:1 0 64px;min-width:0;text-align:center;min-height:48px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;border:0;border-radius:14px;background:transparent;color:var(--mute);font-family:inherit;font-size:11px;font-weight:500;line-height:1.1;cursor:pointer}
.dsk-nav[aria-current=page]{color:#fff;background:rgba(111,166,242,.16)}
.dsk-nav[aria-disabled=true]{opacity:.55;cursor:default}
.dsk-nav:focus-visible,.dsk-out:focus-visible{outline:2px solid #BFD6FF;outline-offset:2px}
.dsk-main{position:relative;z-index:1;margin:0 auto;max-width:68rem;padding:28px max(16px,env(safe-area-inset-left)) calc(96px + env(safe-area-inset-bottom)) max(16px,env(safe-area-inset-right))}
.dsk-top{display:flex;align-items:flex-start;justify-content:space-between;gap:16px}
.dsk-hi{margin:0;color:var(--mute);font-size:14px}
.dsk-h1{margin:4px 0 0;font-size:clamp(30px,5.4vw,52px);line-height:1.05;font-weight:600;letter-spacing:-.03em;text-wrap:balance;background:linear-gradient(180deg,#fff 0%,#BFD6FF 60%,#6FA6F2 100%);-webkit-background-clip:text;background-clip:text;color:transparent}
.dsk-clock{font-variant-numeric:tabular-nums;font-size:clamp(22px,3.4vw,34px);font-weight:300;letter-spacing:.02em;color:#D5E1F7;text-align:right;white-space:nowrap}
.dsk-clock small{display:block;margin-top:2px;font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:500}
.dsk-bar{display:flex;align-items:center;justify-content:flex-end;gap:10px;margin:-8px 0 14px;position:relative}
.dsk-chip{display:inline-flex;align-items:center;gap:8px;min-height:36px;padding:0 14px;border:1px solid var(--line);border-radius:999px;background:var(--glass);font-size:13px;font-weight:600;color:var(--ink)}
.dsk-chip i{width:9px;height:9px;border-radius:50%;background:#6FA6F2;box-shadow:0 0 0 3px rgba(111,166,242,.25)}
.dsk-av{display:grid;place-items:center;width:44px;height:44px;border:1px solid var(--line);border-radius:50%;background:rgba(111,166,242,.2);color:#fff;font:inherit;font-weight:600;cursor:pointer}
.dsk-menu{position:absolute;z-index:30;right:0;top:52px;width:min(300px,calc(100vw - 32px));padding:14px;border:1px solid var(--line);border-radius:18px;background:rgba(10,18,38,.96);backdrop-filter:blur(18px);box-shadow:0 18px 40px rgba(2,8,22,.55)}
.dsk-menu b{display:block;font-size:15px}.dsk-menu small{display:block;margin-top:2px;color:var(--mute);overflow-wrap:anywhere}
.dsk-role{display:inline-block;margin:8px 0 6px;padding:3px 10px;border-radius:999px;background:rgba(111,166,242,.2);font-size:12px;font-weight:600;text-transform:capitalize}
.dsk-menu button{display:block;width:100%;min-height:44px;margin-top:6px;border:0;border-radius:12px;background:transparent;color:var(--ink);font-family:inherit;font-size:14px;text-align:left;padding:0 10px;cursor:pointer}
.dsk-menu button:hover:not(:disabled){background:rgba(255,255,255,.06)}.dsk-menu button:disabled{color:var(--mute);cursor:default}
.dsk-grid{display:grid;gap:14px;margin-top:30px;grid-template-columns:repeat(auto-fit,minmax(min(100%,15rem),1fr))}
.dsk-card{min-width:0;padding:18px 20px;border:1px solid var(--line);border-radius:18px;background:var(--glass);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);box-shadow:0 10px 30px rgba(2,8,22,.35)}
.dsk-k{margin:0;font-size:11px;letter-spacing:.16em;text-transform:uppercase;color:var(--mute)}
.dsk-v{margin:8px 0 0;font-size:17px;font-weight:600;overflow-wrap:anywhere}
.dsk-n{margin:8px 0 0;font-size:13.5px;line-height:1.5;color:var(--mute)}
.dsk-hollow{display:inline-block;width:10px;height:10px;margin-right:8px;border:1.5px solid var(--mute);border-radius:50%;vertical-align:-1px}
.dsk-out{margin-top:26px;min-height:44px;padding:0 22px;border:1px solid var(--line);border-radius:14px;background:rgba(255,255,255,.04);color:var(--ink);font-family:inherit;font-size:14px;font-weight:600;cursor:pointer}
.dsk-err{margin-top:20px;padding:12px 16px;border:1px solid rgba(var(--amber),.5);border-radius:14px;color:#FFD9A8;background:rgba(var(--amber),.08);font-size:14px}
html{scrollbar-width:thin;scrollbar-color:rgba(111,166,242,.45) transparent}
.dsk *::-webkit-scrollbar,.dsk::-webkit-scrollbar{width:10px;height:10px}.dsk *::-webkit-scrollbar-thumb{background:rgba(111,166,242,.38);border-radius:8px;border:2px solid transparent;background-clip:content-box}.dsk *::-webkit-scrollbar-thumb:hover{background:rgba(111,166,242,.6);background-clip:content-box}
.dsk-row{display:contents}
@media (min-width:820px){
 .dsk-scroll{display:flex;flex-direction:column;gap:4px;flex:1;min-height:0;overflow-y:auto;overflow-x:hidden;scrollbar-width:thin;scrollbar-color:rgba(111,166,242,.4) transparent;padding-right:2px}
 .dsk-grp{display:block;margin:16px 10px 4px;font-size:10.5px;letter-spacing:.18em;text-transform:uppercase;color:var(--mute);opacity:.85}
 .dsk-row{position:relative;display:flex;align-items:center}.dsk-row .dsk-nav{flex:1}
 .dsk-pin{display:grid;place-items:center;position:absolute;right:6px;width:34px;height:34px;border:0;border-radius:10px;background:transparent;color:var(--mute);cursor:pointer;opacity:0}
 .dsk-row:hover .dsk-pin,.dsk-row:focus-within .dsk-pin,.dsk-pin[aria-pressed=true]{opacity:1}.dsk-pin[aria-pressed=true]{color:#BFD6FF}.dsk-pin:focus-visible{outline:2px solid #BFD6FF}
 .dsk-rail{top:0;right:auto;bottom:0;width:232px;flex-direction:column;justify-content:flex-start;gap:6px;padding:22px 14px;border-top:0;border-right:1px solid var(--line)}
 .dsk-brand{display:block;margin:0 6px 10px}
 .dsk-nav{flex:0 0 auto;width:100%;flex-direction:row;justify-content:flex-start;gap:12px;padding:0 14px;font-size:14px;text-align:left}
 .dsk-main{margin-left:232px;max-width:none;padding:40px 40px 48px}
 .dsk-main>*{max-width:62rem}
}
@media (prefers-reduced-motion:no-preference){.dsk-card{animation:dskIn .5s ease both}.dsk-grid .dsk-card:nth-child(2){animation-delay:.06s}.dsk-grid .dsk-card:nth-child(3){animation-delay:.12s}.dsk-grid .dsk-card:nth-child(4){animation-delay:.18s}}
@keyframes dskIn{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:none}}
@media (forced-colors:active){.dsk-card,.dsk-rail{border:1px solid CanvasText}}
`;

export function DeskShell({ me, err, out, onSignOut }: { me: ShellMe | null; err: string; out: boolean; onSignOut: () => void }) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => { const t = window.setInterval(() => setNow(Date.now()), 15000); return () => window.clearInterval(t); }, []);
  const [menu, setMenu] = useState(false), [pins, setPins] = useState<string[]>(readPins), groups = orderNav(NAV, pins), toggle = (k: string) => setPins((p) => { const n = p.includes(k) ? p.filter((x) => x !== k) : [...p, k]; writePins(n); return n; });
  const d = new Date(now), first = me?.name?.trim().split(/\s+/)[0] || me?.email.split("@")[0] || "";
  const end = me ? parseWhen(me.expires_at) : null;
  const clock = d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" }), date = d.toLocaleDateString(undefined, { weekday: "long", day: "numeric", month: "long" });
  return (
    <div className="dsk"><style>{CSS}</style>
      <nav className="dsk-rail" aria-label="Admin Desk">
        <div className="dsk-brand"><BrandMark home={false} /></div>
        <div className="dsk-scroll">
          {groups.map((g) => (
            <div key={g.label || "top"} style={{ display: "contents" }}>
              {g.label && <p className="dsk-grp">{g.label}</p>}
              {g.items.map((n) => (
                <div className="dsk-row" key={n.key}>
                  <button type="button" className="dsk-nav" aria-current={n.live ? "page" : undefined} aria-disabled={n.live ? undefined : true} title={n.live ? undefined : "Opens when it is connected"} onClick={(e) => { if (!n.live) e.preventDefault(); }}>{n.glyph}<span>{n.label}</span></button>
                  {n.key !== "dashboard" && <button type="button" className="dsk-pin" aria-pressed={pins.includes(n.key)} aria-label={(pins.includes(n.key) ? "Unpin " : "Pin ") + n.label} onClick={() => toggle(n.key)}>{ico("M9 4h6l-1 6 3 3v2H7v-2l3-3zM12 15v5")}</button>}
                </div>
              ))}
            </div>
          ))}
        </div>
      </nav>
      <main className="dsk-main">
        <div className="dsk-bar">
          {me && <span className="dsk-chip" title="Every answer on this page was signed by the Desk and verified in your browser"><i aria-hidden="true" />Live · verified</span>}
          {me && <button type="button" className="dsk-av" aria-label="Account menu" aria-expanded={menu} onClick={() => setMenu((v) => !v)}>{(me.name || me.email).trim().split(/\s+/).slice(0, 2).map((w) => w[0]?.toUpperCase() ?? "").join("") || "?"}</button>}
          {me && menu && <div className="dsk-menu" role="menu"><b>{me.name || first}</b><small>{me.email}</small><span className="dsk-role">{me.role}</span>
            <button type="button" role="menuitem" disabled title="Opens when it is connected">Profile and photo</button><button type="button" role="menuitem" disabled title="Opens when it is connected">Settings</button><button type="button" role="menuitem" disabled title="Opens when it is connected">Devices and sessions</button>
            <button type="button" role="menuitem" disabled={out} onClick={onSignOut}>{out ? "Signing out…" : "Sign out"}</button></div>}
        </div>
        <header className="dsk-top">
          <div><p className="dsk-hi">{greeting(d.getHours())}{first ? "," : ""}</p><h1 className="dsk-h1">{me ? (me.name || first) : err ? "Dashboard" : "Loading your desk…"}</h1></div>
          <div className="dsk-clock" aria-label={`${clock}, ${date}`}>{clock}<small>{date}</small></div>
        </header>
        {err && <p role="alert" className="dsk-err">{err}</p>}
        {me && (
          <section className="dsk-grid" aria-label="Your account">
            <div className="dsk-card"><p className="dsk-k">Signed in as</p><p className="dsk-v">{me.email}</p></div>
            <div className="dsk-card"><p className="dsk-k">Role</p><p className="dsk-v" style={{ textTransform: "capitalize" }}>{me.role}</p></div>
            <div className="dsk-card"><p className="dsk-k">Session</p><p className="dsk-v">{end ? `${remaining(end, now)} left` : "active"}</p>{end && <p className="dsk-n">Ends {end.toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" })}</p>}</div>
            <div className="dsk-card"><p className="dsk-k">Company mailboxes</p><p className="dsk-n"><span className="dsk-hollow" aria-hidden="true" />Not connected yet. They appear here when they are real.</p></div>
            <div className="dsk-card"><p className="dsk-k">Cases</p><p className="dsk-n"><span className="dsk-hollow" aria-hidden="true" />Not connected yet.</p></div>
            <div className="dsk-card"><p className="dsk-k">Team</p><p className="dsk-n"><span className="dsk-hollow" aria-hidden="true" />Not connected yet.</p></div>
          </section>
        )}
        <button type="button" className="dsk-out" disabled={out} onClick={onSignOut}>{out ? "Signing out…" : "Sign out"}</button>
      </main>
    </div>
  );
}
