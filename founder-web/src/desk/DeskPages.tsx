import { useEffect } from "react";
import { BrandMark } from "../signin/BrandMark";
import { Button } from "../signin/ui/button";
import { DESK_SESSION_KEY, deskGuard, deskPage } from "./desk_pure";
import { DeskSignIn } from "./DeskSignIn";
import { DeskScene } from "./DeskScene";
import { DeskTelemetry } from "./DeskTelemetry";
import { HoverA } from "../signin/BrandLoader";

const hasSession = () => { try { return !!window.localStorage.getItem(DESK_SESSION_KEY); } catch { return false; } };
const go = (to: string) => window.location.replace(to);

/** The brand band: the Desk is always visibly the Desk, never mistaken for the founder tab. */
function Band() { return <div role="banner" className="sticky top-0 z-10 flex items-center justify-between gap-3 bg-[oklch(0.295_0.066_258)] px-4 py-2 text-[12px] font-semibold uppercase tracking-[0.2em] text-white"><span>Admin Desk</span><span className="opacity-70 normal-case tracking-normal">admindesk.anexomail.com</span></div>; }

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
          <button type="button" className="ax-a-hover" onClick={() => go("/adminlogin")} style={{ minHeight: 54, padding: "0 34px", border: 0, borderRadius: 16, cursor: "pointer", fontSize: 16, fontWeight: 600, color: "#04122B", background: "linear-gradient(180deg,#9CCBFF,#5FA8FF)", boxShadow: "0 10px 34px rgba(95,168,255,.4),0 1px 0 rgba(255,255,255,.6) inset", display: "inline-flex", alignItems: "center", gap: 10 }}><HoverA />Sign in</button>
          <p style={{ margin: "6px 0 0", fontSize: 11, letterSpacing: ".1em", color: "#8FA6CC" }}>Rust · Tokio · axum · Rust WASM kernel · WebAuthn passkeys · Three.js</p>
        </section>
      </DeskScene>
    </main>
  );
}

function Dashboard() {
  return (
    <main className="fa min-h-screen bg-background"><Band />
      <section className="mx-auto w-full max-w-[60rem] px-6 py-10">
        <h1 className="text-3xl font-semibold tracking-tight text-foreground">Dashboard</h1>
        <p className="mt-2 text-muted-foreground">You are signed in to the Admin Desk. The company mailboxes connect here in the next step (R3b); nothing is shown until they are real.</p>
        <Button variant="outline" className="ax-press mt-6 min-h-11" onClick={() => { try { window.localStorage.removeItem(DESK_SESSION_KEY); } catch { /* ignore */ } go("/adminlogin"); }}>Sign out</Button>
      </section>
    </main>
  );
}

/** One component, three pages by path (/, /adminlogin, /dashboard). The guard sends a visitor without a session away from the dashboard. */
export function DeskApp() {
  const page = deskPage(window.location.pathname), g = deskGuard(page, hasSession());
  useEffect(() => { if (g === "to_login") go("/adminlogin"); else if (g === "to_dashboard") go("/dashboard"); }, [g]);
  if (g !== "stay") return null;
  return page === "adminlogin" ? <DeskSignIn /> : page === "dashboard" ? <Dashboard /> : <Landing />;
}
