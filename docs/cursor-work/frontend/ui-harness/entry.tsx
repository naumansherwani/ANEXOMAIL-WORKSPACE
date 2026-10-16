import { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";

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

document.documentElement.classList.add("dark");
createRoot(document.getElementById("root")!).render(<Shell />);
