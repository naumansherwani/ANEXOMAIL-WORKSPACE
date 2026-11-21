import { useEffect, useState, type ReactNode } from "react";
import { BrandMark } from "../signin/BrandMark";

/** Admin Desk shell (R4-1, UI step 1, 22 Nov 2026): cinematic night-office look of the Desk login, calm work screen (ONE hero moment: the greeting).
 *  Pure presentation: every value comes in as a prop from a Desk-signed answer the kernel verified. No founder import, no raw fetch, no mock data.
 *  One build for 390 / 820 / 1200+: a left glass rail from 820 up, a bottom tab bar below it (CSS only, no JS size switch). Honours reduced motion and forced colours. */
export type ShellMe = { email: string; name: string | null; role: string; expires_at: string };
type NavItem = { key: string; label: string; glyph: ReactNode; live: boolean };
const ico = (d: string) => <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={d} /></svg>;
const NAV: NavItem[] = [
  { key: "dashboard", label: "Dashboard", glyph: ico("M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"), live: true },
  { key: "inboxes", label: "Inboxes", glyph: ico("M3 13l3-8h12l3 8v6a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1zM3 13h5l1 3h6l1-3h5"), live: false },
  { key: "cases", label: "Cases", glyph: ico("M4 5h16v11H8l-4 4zM8 9h8M8 12h5"), live: false },
  { key: "team", label: "Team", glyph: ico("M9 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM3 20a6 6 0 0 1 12 0M17 11a2.5 2.5 0 1 0 0-5M16 14.5A5 5 0 0 1 21 20"), live: false },
  { key: "audit", label: "Audit", glyph: ico("M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6zM9 12l2 2 4-4"), live: false },
];

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
const initials = (s: string) => s.trim().split(/\s+/).slice(0, 2).map((w) => w[0]?.toUpperCase() ?? "").join("") || "?";

const CSS = `
.dsk{font-family:Inter,ui-sans-serif,system-ui,-apple-system,'Segoe UI',sans-serif;--ink:#E8EEF9;--mute:#9FB3D6;--glass:rgba(12,22,46,.62);--line:rgba(160,200,255,.16);--amber:255,170,70;position:relative;min-height:100dvh;color:var(--ink);background:linear-gradient(180deg,#060B19 0%,#0A1730 48%,#0F3460 100%);overflow-x:hidden}
.dsk::before{content:"";position:fixed;inset:0;pointer-events:none;background:radial-gradient(55% 45% at 94% 0%,rgba(var(--amber),.26),transparent 62%),radial-gradient(60% 55% at 6% 100%,rgba(15,52,96,.85),transparent 70%)}
.dsk::after{content:"";position:fixed;inset:0;pointer-events:none;background:repeating-linear-gradient(90deg,transparent 0,transparent 14vw,rgba(160,200,255,.05) 14vw,rgba(160,200,255,.05) calc(14vw + 1px));box-shadow:inset 0 0 180px rgba(0,0,0,.55)}
.dsk-rail{position:fixed;z-index:20;left:0;right:0;bottom:0;display:flex;justify-content:space-around;gap:2px;padding:6px max(8px,env(safe-area-inset-left)) calc(6px + env(safe-area-inset-bottom)) max(8px,env(safe-area-inset-right));background:var(--glass);backdrop-filter:blur(18px) saturate(140%);-webkit-backdrop-filter:blur(18px) saturate(140%);border-top:1px solid var(--line)}
.dsk-brand,.dsk-who{display:none}
.dsk-nav{flex:1;min-width:0;min-height:48px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;border:0;border-radius:14px;background:transparent;color:var(--mute);font-family:inherit;font-size:11px;font-weight:500;line-height:1.1;cursor:pointer}
.dsk-nav[aria-current=page]{color:#fff;background:rgba(111,166,242,.16)}
.dsk-nav[aria-disabled=true]{opacity:.55;cursor:default}
.dsk-nav:focus-visible,.dsk-out:focus-visible{outline:2px solid #BFD6FF;outline-offset:2px}
.dsk-main{position:relative;z-index:1;margin:0 auto;max-width:68rem;padding:28px max(16px,env(safe-area-inset-left)) calc(96px + env(safe-area-inset-bottom)) max(16px,env(safe-area-inset-right))}
.dsk-top{display:flex;align-items:flex-start;justify-content:space-between;gap:16px}
.dsk-hi{margin:0;color:var(--mute);font-size:14px}
.dsk-h1{margin:4px 0 0;font-size:clamp(30px,5.4vw,52px);line-height:1.05;font-weight:600;letter-spacing:-.03em;text-wrap:balance;background:linear-gradient(180deg,#fff 0%,#BFD6FF 60%,#6FA6F2 100%);-webkit-background-clip:text;background-clip:text;color:transparent}
.dsk-clock{font-variant-numeric:tabular-nums;font-size:clamp(22px,3.4vw,34px);font-weight:300;letter-spacing:.02em;color:#D5E1F7;text-align:right;white-space:nowrap}
.dsk-clock small{display:block;margin-top:2px;font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:500}
.dsk-grid{display:grid;gap:14px;margin-top:30px;grid-template-columns:repeat(auto-fit,minmax(min(100%,15rem),1fr))}
.dsk-card{min-width:0;padding:18px 20px;border:1px solid var(--line);border-radius:18px;background:var(--glass);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);box-shadow:0 10px 30px rgba(2,8,22,.35)}
.dsk-k{margin:0;font-size:11px;letter-spacing:.16em;text-transform:uppercase;color:var(--mute)}
.dsk-v{margin:8px 0 0;font-size:17px;font-weight:600;overflow-wrap:anywhere}
.dsk-n{margin:8px 0 0;font-size:13.5px;line-height:1.5;color:var(--mute)}
.dsk-hollow{display:inline-block;width:10px;height:10px;margin-right:8px;border:1.5px solid var(--mute);border-radius:50%;vertical-align:-1px}
.dsk-out{margin-top:26px;min-height:44px;padding:0 22px;border:1px solid var(--line);border-radius:14px;background:rgba(255,255,255,.04);color:var(--ink);font-family:inherit;font-size:14px;font-weight:600;cursor:pointer}
.dsk-err{margin-top:20px;padding:12px 16px;border:1px solid rgba(var(--amber),.5);border-radius:14px;color:#FFD9A8;background:rgba(var(--amber),.08);font-size:14px}
@media (min-width:820px){
 .dsk-rail{top:0;right:auto;bottom:0;width:232px;flex-direction:column;justify-content:flex-start;gap:6px;padding:22px 14px;border-top:0;border-right:1px solid var(--line)}
 .dsk-brand{display:block;margin:0 6px 18px}.dsk-brand b{display:block;margin-top:8px;font-size:12px;letter-spacing:.2em;text-transform:uppercase;color:#fff}
 .dsk-nav{flex:0 0 auto;flex-direction:row;justify-content:flex-start;gap:12px;padding:0 14px;font-size:14px;text-align:left}
 .dsk-who{display:flex;align-items:center;gap:10px;margin-top:auto;padding:12px 8px 0;border-top:1px solid var(--line);font-size:13px;color:var(--mute)}
 .dsk-who i{display:grid;place-items:center;width:34px;height:34px;border-radius:50%;background:rgba(111,166,242,.2);color:#fff;font-style:normal;font-weight:600;font-size:13px}
 .dsk-who span{min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
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
  const d = new Date(now), first = me?.name?.trim().split(/\s+/)[0] || me?.email.split("@")[0] || "";
  const end = me ? parseWhen(me.expires_at) : null;
  const clock = d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" }), date = d.toLocaleDateString(undefined, { weekday: "long", day: "numeric", month: "long" });
  return (
    <div className="dsk"><style>{CSS}</style>
      <nav className="dsk-rail" aria-label="Admin Desk">
        <div className="dsk-brand"><BrandMark home={false} /><b>Admin Desk</b></div>
        {NAV.map((n) => <button key={n.key} type="button" className="dsk-nav" aria-current={n.live ? "page" : undefined} aria-disabled={n.live ? undefined : true} title={n.live ? undefined : "Opens when it is connected"} onClick={(e) => { if (!n.live) e.preventDefault(); }}>{n.glyph}<span>{n.label}</span></button>)}
        {me && <div className="dsk-who"><i aria-hidden="true">{initials(me.name || me.email)}</i><span>{me.name || me.email}</span></div>}
      </nav>
      <main className="dsk-main">
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
