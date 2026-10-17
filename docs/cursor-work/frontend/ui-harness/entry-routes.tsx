// Harness for the REAL /app routes. Hash = "<page>[?search]": #cal, #people, #people?id=c1, #work, #work-basicplan, #crm, #crm/pipeline|leads|relationships|collab|activity|tasks|reports|accounts, #admin-members, #admin-teams, add ?empty=1 for empty states
// Shell mirrors AppShell: 56px header, <main flex min-h-0 flex-1 flex-col md:flex-row>, phone bottom bar (placeholder, same height).
import { useSyncExternalStore } from "react";
import { createRoot } from "react-dom/client";

import { Route as CalendarRoute } from "@/routes/app.calendar";
import { Route as PeopleRoute } from "@/routes/app.people";
import { Route as WorkRoute } from "@/routes/app.work";
import { CrmStage } from "@/components/app/crm/CrmStage";
import { Route as CrmIndexRoute } from "@/routes/app.crm.index";
import { Route as CrmLeadsRoute } from "@/routes/app.crm.leads";
import { Route as CrmPipelineRoute } from "@/routes/app.crm.pipeline";
import { Route as CrmRelRoute } from "@/routes/app.crm.relationships";
import { Route as CrmCollabRoute } from "@/routes/app.crm.collab";
import { Route as CrmActivityRoute } from "@/routes/app.crm.activity";
import { Route as CrmTasksRoute } from "@/routes/app.crm.tasks";
import { Route as CrmReportsRoute } from "@/routes/app.crm.reports";
import { Route as CrmAccountsRoute } from "@/routes/app.crm.accounts";
import { Route as BillingRoute } from "@/routes/app.billing";
import { Route as AccountRoute } from "@/routes/app.account";
import { Route as AdminMembersRoute } from "@/routes/app.admin.members";
import { Route as AdminTeamsRoute } from "@/routes/app.admin.teams";

type R = { component: () => JSX.Element; crm?: boolean };
const CRM: Record<string, unknown> = { leads: CrmLeadsRoute, pipeline: CrmPipelineRoute, relationships: CrmRelRoute, collab: CrmCollabRoute, activity: CrmActivityRoute, tasks: CrmTasksRoute, reports: CrmReportsRoute, accounts: CrmAccountsRoute };
const pick = (h: string): R => {
  const b = h.replace(/^#\/?/, "").replace(/^app\//, "").split("?")[0];
  if (b.startsWith("admin-members")) return AdminMembersRoute as unknown as R;
  if (b.startsWith("admin-teams")) return AdminTeamsRoute as unknown as R;
  if (b.startsWith("account")) return AccountRoute as unknown as R;
  if (b.startsWith("billing")) return BillingRoute as unknown as R;
  if (b.startsWith("crm")) { const sub = b.split("/")[1]; return { ...((CRM[sub] ?? CrmIndexRoute) as R), crm: true }; }
  if (b.startsWith("people")) return PeopleRoute as unknown as R;
  if (b.startsWith("work")) return WorkRoute as unknown as R;
  return CalendarRoute as unknown as R;
};
const sub = (cb: () => void) => (window.addEventListener("hashchange", cb), () => window.removeEventListener("hashchange", cb));

function Shell() {
  const h = useSyncExternalStore(sub, () => location.hash, () => "");
  const picked = pick(h);
  const Page = picked.component;
  return (
    <div className="flex h-dvh flex-col overflow-hidden bg-background">
      <div className="flex h-14 shrink-0 items-center gap-3 border-b border-border px-4 text-sm font-bold">
        ANEXOMAIL <span className="ax-caption text-muted-foreground">WORKSPACE</span>
      </div>
      <div className="flex min-h-0 flex-1">
        <nav className="hidden w-[190px] shrink-0 flex-col gap-1 border-r border-sidebar-border bg-sidebar p-3 text-sm md:flex">
          {["Dashboard", "Mail", "People", "Calendar", "Work", "CRM", "Domains"].map((r) => (
            <span key={r} className="px-3 py-2 text-muted-foreground">{r}</span>
          ))}
        </nav>
        <main className="flex min-h-0 min-w-0 flex-1 flex-col overflow-y-auto overflow-x-hidden md:flex-row">
          {picked.crm ? <CrmStage><Page /></CrmStage> : <Page />}
        </main>
      </div>
      <div className="flex h-16 shrink-0 items-center justify-around border-t border-border bg-card text-[11px] text-muted-foreground md:hidden">
        <span>Dashboard</span><span>Mail</span><span>People</span><span>Calendar</span><span>More</span>
      </div>
    </div>
  );
}
createRoot(document.getElementById("root")!).render(<Shell />);
