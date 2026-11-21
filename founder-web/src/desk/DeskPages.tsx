import { useEffect } from "react";
import { BrandMark } from "../signin/BrandMark";
import { Button } from "../signin/ui/button";
import { DESK_SESSION_KEY, deskGuard, deskPage } from "./desk_pure";
import { DeskSignIn } from "./DeskSignIn";

const hasSession = () => { try { return !!window.localStorage.getItem(DESK_SESSION_KEY); } catch { return false; } };
const go = (to: string) => window.location.replace(to);

/** The brand band: the Desk is always visibly the Desk, never mistaken for the founder tab. */
function Band() { return <div role="banner" className="sticky top-0 z-10 flex items-center justify-between gap-3 bg-[oklch(0.295_0.066_258)] px-4 py-2 text-[12px] font-semibold uppercase tracking-[0.2em] text-white"><span>Admin Desk</span><span className="opacity-70 normal-case tracking-normal">admindesk.anexomail.com</span></div>; }

function Landing() {
  return (
    <main className="fa flex min-h-screen flex-col bg-background"><Band />
      <section className="mx-auto flex w-full max-w-[44rem] flex-1 flex-col items-center justify-center gap-6 px-6 py-16 text-center">
        <BrandMark home={false} />
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">ANEXOMAIL</p>
        <h1 className="text-balance text-4xl font-semibold tracking-tight text-foreground">Admin Desk</h1>
        <p className="max-w-[34rem] text-pretty text-muted-foreground">Where company mail is heard and solved. For ANEXOMAIL staff only.</p>
        <p className="max-w-[34rem] text-pretty text-sm text-muted-foreground">Our engine runs in milliseconds; our support should too. Own the issue, fix the root, leave zero open loops.</p>
        <Button className="ax-press min-h-11 px-8" onClick={() => go("/adminlogin")}>Sign in</Button>
      </section>
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
