import { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";

import { ComposeOverlay } from "@/components/app/ComposeOverlay";
import { MobileNav, type NavItem } from "@/components/app/MobileNav";
import { InstallHint } from "@/components/app/dashboard/InstallHint";
import { SetupChecklist } from "@/components/app/dashboard/SetupChecklist";
import { CalendarDays, CheckSquare, Globe, Inbox, KanbanSquare, Mail, ShieldCheck, Users } from "lucide-react";
import { Route } from "@/routes/app.domains";

const Page = (Route as unknown as { component: () => JSX.Element }).component;

const RAIL = ["Dashboard", "Mail", "People", "Calendar", "Work", "CRM", "Domains"];

function Toast() {
  const [msg, setMsg] = useState<string | null>(null);
  useEffect(() => {
    (window as unknown as { __toast: (m: string) => void }).__toast = (m) => {
      setMsg(m);
      setTimeout(() => setMsg(null), 3200);
    };
  }, []);
  return msg ? (
    <div className="fixed bottom-6 right-6 z-50 rounded-xl border border-border bg-card px-4 py-3 text-sm shadow-lg">{msg}</div>
  ) : null;
}

// Mirrors AppShell: h-screen overflow-hidden shell, rail, <main flex min-h-0 …>{page}</main>.
function Shell() {
  return (
    <div className="flex h-screen flex-col overflow-hidden bg-background">
      <div className="flex h-14 shrink-0 items-center gap-3 border-b border-border px-4 text-sm font-bold">
        ANEXOMAIL <span className="ax-caption text-muted-foreground">WORKSPACE</span>
      </div>
      <div className="flex min-h-0 flex-1">
        <nav className="hidden w-[190px] shrink-0 flex-col gap-1 border-r border-sidebar-border bg-sidebar p-3 text-sm md:flex">
          {RAIL.map((r) => (
            <span key={r} className={r === "Domains" ? "rounded-lg bg-sidebar-accent px-3 py-2 font-semibold" : "px-3 py-2 text-muted-foreground"}>
              {r}
            </span>
          ))}
        </nav>
        <main className="flex min-h-0 min-w-0 flex-1 flex-col md:flex-row">
          <h1 className="sr-only">Domains &amp; addresses</h1>
          <Page />
        </main>
      </div>
      <Toast />
    </div>
  );
}

// Dashboard stand-in: real SetupChecklist inside the real page padding; Greeting/widgets are plain placeholders.
function DashShell() {
  return (
    <div className="flex h-screen flex-col overflow-hidden bg-background">
      <div className="flex h-14 shrink-0 items-center gap-3 border-b border-border px-4 text-sm font-bold">
        ANEXOMAIL <span className="ax-caption text-muted-foreground">WORKSPACE</span>
      </div>
      <div className="flex min-h-0 flex-1">
        <nav className="hidden w-[190px] shrink-0 flex-col gap-1 border-r border-sidebar-border bg-sidebar p-3 text-sm md:flex">
          {RAIL.map((r) => (
            <span key={r} className={r === "Dashboard" ? "rounded-lg bg-sidebar-accent px-3 py-2 font-semibold" : "px-3 py-2 text-muted-foreground"}>
              {r}
            </span>
          ))}
        </nav>
        <main className="flex min-h-0 min-w-0 flex-1 flex-col">
          <div className="min-h-0 flex-1 overflow-y-auto">
            <div className="mx-auto w-full max-w-6xl px-6 py-10 md:px-10 md:py-14">
              <h1 className="ax-display">Good evening, Nauman</h1>
              <p className="ax-body mt-1 text-muted-foreground">Here is your day.</p>
              <SetupChecklist enabled onCompose={() => (window as unknown as { __toast?: (m: string) => void }).__toast?.("compose opened")} />
              <InstallHint forceShow={location.hash.includes("ios")} />
              <div className="mt-ax-7 grid gap-ax-5 sm:grid-cols-2 lg:grid-cols-4">
                {["Inbox", "Sent today", "Drafts", "Calendar"].map((x) => (
                  <div key={x} className="ax-plane rounded-2xl p-ax-5">
                    <p className="ax-eyebrow">{x}</p>
                    <p className="ax-title mt-2">0</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </main>
      </div>
      <Toast />
    </div>
  );
}

// Phone shell: same skeleton as AppShell (h-dvh column: header, main, MobileNav). #nav | #navfew | #navorgs | #navdomains | #compose | #composemin
const ALL: NavItem[] = [
  { to: "/app", label: "Dashboard", icon: Inbox },
  { to: "/app/mail/inbox", label: "Mail", icon: Mail },
  { to: "/app/people", label: "People", icon: Users },
  { to: "/app/calendar", label: "Calendar", icon: CalendarDays },
  { to: "/app/work", label: "Work", icon: CheckSquare },
  { to: "/app/crm", label: "CRM", icon: KanbanSquare },
  { to: "/app/domains", label: "Domains", icon: Globe },
  { to: "/app/safety", label: "Safety", icon: ShieldCheck },
];
function PhoneShell() {
  const h = location.hash;
  const items = h.includes("navfew") ? ALL.slice(0, 4) : ALL;
  const activeTo = h.includes("navdomains") ? "/app/domains" : "/app/mail/inbox";
  const orgs = h.includes("navorgs") ? [{ id: "o1", name: "Acme Studio", role: "owner" }, { id: "o2", name: "Probuyer Labs", role: "admin" }] : [];
  const [composing, setComposing] = useState(h.includes("compose"));
  return (
    <div className="flex h-dvh flex-col overflow-hidden bg-background">
      <header
        className="flex shrink-0 items-center gap-3 border-b border-border"
        style={{ height: "calc(3.5rem + env(safe-area-inset-top, 0px))", paddingTop: "env(safe-area-inset-top, 0px)", paddingLeft: "max(1rem, env(safe-area-inset-left, 0px))", paddingRight: "max(1rem, env(safe-area-inset-right, 0px))" }}
      >
        <span className="text-sm font-bold">ANEXOMAIL</span>
        <div className="flex min-w-0 flex-1 items-center rounded-xl border border-border bg-card px-3 py-2 text-sm text-muted-foreground">
          <span className="truncate">Search mail, people, calendar, work…</span>
        </div>
        <span className="grid size-9 place-items-center rounded-full border border-border bg-secondary text-xs">N</span>
      </header>
      <main className="flex min-h-0 min-w-0 flex-1 flex-col overflow-y-auto overflow-x-hidden md:flex-row">
        <div className={h.includes("tall") ? "px-4 py-4" : "min-h-0 flex-1 overflow-y-auto px-4 py-4"}>
          <p className="ax-eyebrow">Inbox</p>
          <div className="mt-2 flex items-center gap-1 overflow-x-auto py-3" data-pills>
            {["All", "Unread", "Starred"].map((x) => (
              <button key={x} type="button" className="ax-hit shrink-0 rounded-full bg-secondary px-2.5 py-1 text-[11px] font-semibold">{x}</button>
            ))}
            {["Abs"].map((x) => (
              <button key={x} type="button" data-abs className="ax-hit absolute right-2 top-[4.5rem] rounded-full bg-secondary px-2.5 py-1 text-[11px] font-semibold">{x}</button>
            ))}
          </div>
          {Array.from({ length: 14 }, (_, i) => (
            <div key={i} className="border-b border-border py-3">
              <p className="text-sm font-semibold">Sender {i + 1}</p>
              <p className="ax-caption text-muted-foreground">Subject line number {i + 1} — preview text</p>
            </div>
          ))}
          <button type="button" className="ax-tap mt-3 rounded-lg border border-border px-3 py-2 text-sm" onClick={() => setComposing(true)}>Compose</button>
        </div>
      </main>
      <MobileNav items={items} isActive={(i) => i.to === activeTo} orgs={orgs} activeOrgId="o1" onSwitchOrg={(id) => (window as unknown as { __toast?: (m: string) => void }).__toast?.("switch " + id)} />
      {composing && <ComposeOverlay onClose={() => setComposing(false)} />}
      <Toast />
    </div>
  );
}

document.documentElement.classList.add("dark");
const hh = location.hash;
createRoot(document.getElementById("root")!).render(
  hh.startsWith("#nav") || hh.startsWith("#compose") ? <PhoneShell /> : hh.startsWith("#dash") ? <DashShell /> : <Shell />,
);
