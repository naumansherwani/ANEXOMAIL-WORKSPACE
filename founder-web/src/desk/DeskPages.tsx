import { useEffect, useState } from "react";
import { recordServices } from "./desk_trend_pure";
import { asServices } from "./desk_bridge_pure";
import { BrandMark } from "../signin/BrandMark";
import { DESK_SESSION_KEY, deskGuard, deskPage } from "./desk_pure";
import { DeskSignIn } from "./DeskSignIn";
import { DeskScene } from "./DeskScene";
import { DeskTelemetry } from "./DeskTelemetry";
import { DeskShell, type ShellMe } from "./DeskShell";
import { HoverA } from "../signin/BrandLoader";
import { deskCall, DeskRefused, refusedMessage } from "./desk_kernel";
import { openBridge, type Snapshot } from "./desk_stream";
import { DeskBoot } from "./DeskBoot";
import { barModel } from "./desk_bridge_pure";
import { CHORD_MS, chordTarget, comboTarget, deskSub, typingTarget } from "./desk_cards";

const hasSession = () => { try { return !!window.localStorage.getItem(DESK_SESSION_KEY); } catch { return false; } };
const go = (to: string) => window.location.replace(to);
import { markSelectors, origin, remember } from "./desk_return_pure";
const here = () => ({ path: window.location.pathname, search: window.location.search, hash: window.location.hash });

function Landing() {
  return (
    <main className="fa">
      <DeskScene>
        <DeskTelemetry />
        <section aria-label="Admin Desk" style={{ width: "100%", maxWidth: 760, display: "flex", flexDirection: "column", alignItems: "center", gap: 22, textAlign: "center" }}>
          <div style={{ transform: "scale(1.25)", marginBottom: 6 }}><BrandMark home={false} /></div>
          <h1 style={{ margin: 0, fontWeight: 600, fontSize: "clamp(44px,8vw,92px)", lineHeight: 1.02, letterSpacing: "-0.035em", textWrap: "balance" as const, background: "linear-gradient(180deg,#FFFFFF 0%,#BFD6FF 55%,#6FA6F2 100%)", WebkitBackgroundClip: "text", backgroundClip: "text", color: "transparent" }}>Admin Desk</h1>
          <p style={{ margin: 0, maxWidth: 520, fontSize: "clamp(16px,2.2vw,19px)", lineHeight: 1.55, color: "#B7C6E2", textWrap: "balance" as const }}>Where company mail is heard and solved. For ANEXOMAIL staff only.</p>
          <p style={{ margin: 0, maxWidth: 560, padding: "12px 20px", fontSize: 14, lineHeight: 1.55, color: "#D5E1F7", textWrap: "balance" as const, border: "1px solid rgba(160,200,255,.22)", borderRadius: 16, background: "rgba(10,18,38,.5)", backdropFilter: "blur(14px)" }}>Our engine runs in milliseconds; our support should too. Own the issue, fix the root, leave zero open loops.</p>
          <button type="button" className="ax-a-hover" onClick={() => go("/adminlogin")} style={{ minHeight: 54, padding: "0 34px", border: 0, borderRadius: 16, cursor: "pointer", fontSize: 16, fontWeight: 600, color: "oklch(0.975 0.004 250)", background: "oklch(0.455 0.093 258)", boxShadow: "0 8px 24px rgba(4,18,43,.45)", display: "inline-flex", alignItems: "center", gap: 10 }}><HoverA />Sign in</button>
          <p style={{ margin: "6px 0 0", fontSize: 11, letterSpacing: ".1em", color: "#8FA6CC" }}>Rust · Tokio · axum · Rust WASM kernel · WebAuthn passkeys · Three.js</p>
        </section>
      </DeskScene>
    </main>
  );
}

type Me = ShellMe;
const isMe = (j: unknown): j is Me => !!j && typeof j === "object" && typeof (j as Me).email === "string" && typeof (j as Me).role === "string";
const dropSession = () => { try { window.localStorage.removeItem(DESK_SESSION_KEY); } catch { /* ignore */ } };

/** Dashboard: ONLY real data, every line from a Desk-signed answer the kernel verified (/desk/v1/auth/me). The look lives in DeskShell. */
function Dashboard() {
  const [loc, setLoc] = useState(here);
  // D1: cards move inside this one page with the History API; the stream below stays open. Back restores the previous page.
  useEffect(() => { const on = () => setLoc(here()); window.addEventListener("popstate", on); return () => window.removeEventListener("popstate", on); }, []);
  // coming back to the Dashboard: the card you opened wears the red mark and scrolls into view (his 23 Nov 03:38 word)
  useEffect(() => {
    document.querySelectorAll("[data-from]").forEach((e) => e.removeAttribute("data-from"));
    const id = origin(loc.path); if (!id) return;
    const t = window.setTimeout(() => { for (const sel of markSelectors(id)) { const a = document.querySelector<HTMLElement>(sel); if (!a) continue; const card = (a.closest(".dcb-card") as HTMLElement | null) ?? a; card.setAttribute("data-from", "true"); card.scrollIntoView({ block: "center" }); return; } }, 60);
    return () => window.clearTimeout(t);
  }, [loc.path]);
  const nav = (to: string) => { remember(to); window.history.pushState(null, "", to); setLoc(here()); const id = to.split("#")[1]; window.setTimeout(() => (id ? document.getElementById(id) : null)?.scrollIntoView({ block: "center" }) ?? window.scrollTo(0, 0), 0); };
  // D1b (his 22 Nov 07:33): keyboard shortcuts, "g" then a letter. Not while typing, not with Ctrl / Alt / Meta.
  useEffect(() => {
    let armed = 0;
    const on = (e: KeyboardEvent) => {
      if (e.ctrlKey || e.metaKey || e.repeat || typingTarget(e.target as HTMLElement | null)) return;
      const c = comboTarget(e); if (c) { e.preventDefault(); nav(c); return; } // Alt+Shift+letter (his 08:04 word)
      if (e.altKey) return;
      const r = chordTarget(Date.now() < armed, e.key);
      if (r === "arm") { armed = Date.now() + CHORD_MS; return; }
      armed = 0; if (r) { e.preventDefault(); nav(r); }
    };
    window.addEventListener("keydown", on); return () => window.removeEventListener("keydown", on);
  }, []);
  const [me, setMe] = useState<Me | null>(null), [err, setErr] = useState(""), [out, setOut] = useState(false), [live, setLive] = useState<Snapshot>({ state: "connecting", data: {} });
  // Phase C2: the live Bridge stream (WebTransport, Rule 52 verified in the kernel). Starts once the account answer is trusted; stops on sign-out.
  useEffect(() => { if (!me) return; return openBridge(setLive); }, [me]);
  // D3b: only verified, live ticks feed the trend (a stale or connecting stream adds nothing).
  useEffect(() => { if (live.state === "live") recordServices(asServices(live.data.services)); }, [live]);
  useEffect(() => {
    let live = true;
    deskCall("GET", "/desk/v1/auth/me").then((r) => {
      if (!live) return;
      if (r.status === 401) { dropSession(); go("/adminlogin"); return; }
      if (r.status === 200 && isMe(r.json)) setMe(r.json); else setErr("The Desk could not load your account. Try again in a moment.");
    }, (e) => { if (live) setErr(e instanceof DeskRefused ? refusedMessage(e.message) : "Cannot reach the server. Check your connection and try again."); });
    return () => { live = false; };
  }, []);
  async function signOut() { setOut(true); try { await deskCall("POST", "/desk/v1/auth/logout"); } catch { /* the local session is dropped anyway */ } dropSession(); go("/adminlogin"); }
  if (!me && !err) return <DeskBoot />; // loading: the Anexomail mark + ADMIN DESK (no big heading)
  return <DeskShell me={me} err={err} out={out} onSignOut={signOut} live={live.state} bar={barModel(live.state, live.data)} act={(b) => deskCall("POST", "/desk/v1/bridge/alerts/act", b).then((r) => r.status, () => 0)} snap={live} sub={deskSub(loc.path)} search={loc.search} hash={loc.hash} nav={nav} />;
}

/** One component, three pages by path (/, /adminlogin, /dashboard). The guard sends a visitor without a session away from the dashboard. */
export function DeskApp() {
  const page = deskPage(window.location.pathname), g = deskGuard(page, hasSession());
  useEffect(() => { if (g === "to_login") go("/adminlogin"); else if (g === "to_dashboard") go("/dashboard"); }, [g]);
  if (g !== "stay") return null;
  return page === "adminlogin" ? <DeskSignIn /> : page === "dashboard" ? <Dashboard /> : <Landing />;
}
