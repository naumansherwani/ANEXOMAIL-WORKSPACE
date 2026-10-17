// Harness for the REAL /app routes. Hash = "<page>[?search]": #cal, #people, #people?id=c1, #work, #work-basicplan, #crm, #crm/pipeline|leads|relationships|collab|activity|tasks|reports|accounts, #admin-members, #admin-teams, #chips, add ?empty=1 for empty states
// Shell mirrors AppShell: 56px header, <main flex min-h-0 flex-1 flex-col md:flex-row>, phone bottom bar (placeholder, same height).
import { useEffect, useSyncExternalStore } from "react";
import { createRoot } from "react-dom/client";

import { Route as CalendarRoute } from "@/routes/app.calendar";
import { Route as DashboardRoute } from "@/routes/app.index";
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
import { CrossPlatformBar } from "@/components/app/CrossPlatformBar";
import { PlanSurfaceGate } from "@/components/app/PlanSurfaceGate";
import { InboxWelcome } from "@/components/app/mail/InboxWelcome";
import { Route as AdminLayoutRoute } from "@/routes/app.admin";
import { Route as AdminIndexRoute } from "@/routes/app.admin.index";
import { Route as AdminHealthRoute } from "@/routes/app.admin.health";
import { Route as AdminStorageRoute } from "@/routes/app.admin.storage";
import { Route as AdminMonitoringRoute } from "@/routes/app.admin.monitoring";
import { Route as AdminLogsRoute } from "@/routes/app.admin.logs";
import { Route as AdminReportsRoute } from "@/routes/app.admin.reports";
import { Route as AdminDiagnosticsRoute } from "@/routes/app.admin.diagnostics";
import { Route as AdminAuditRoute } from "@/routes/app.admin.audit";
import { Route as AdminExportRoute } from "@/routes/app.admin.export";
import { Route as AdminMembersRoute } from "@/routes/app.admin.members";
import { Route as AdminTeamsRoute } from "@/routes/app.admin.teams";
import { Route as OrgAuditRoute } from "@/routes/app.org.audit";

type R = { component: () => JSX.Element; crm?: boolean };
const CRM: Record<string, unknown> = { leads: CrmLeadsRoute, pipeline: CrmPipelineRoute, relationships: CrmRelRoute, collab: CrmCollabRoute, activity: CrmActivityRoute, tasks: CrmTasksRoute, reports: CrmReportsRoute, accounts: CrmAccountsRoute };
// #chips: the REAL CrossPlatformBar with a synthetic beforeinstallprompt (shoot with WAIT>=9000: the chip waits 8 s on purpose).
const ChipsRoute = {
  component: () => {
    useEffect(() => {
      const t = setTimeout(() => { const ev = new Event("beforeinstallprompt") as Event & { prompt: () => Promise<void> }; ev.prompt = async () => {}; window.dispatchEvent(ev); }, 300);
      return () => clearTimeout(t);
    }, []);
    return (
      <div className="min-h-0 flex-1 p-6">
        <div className="mx-auto flex h-10 max-w-md items-center rounded-full border border-border px-4 text-sm text-muted-foreground">Search mail, people, threads…</div>
        <p className="mt-6 text-sm text-muted-foreground">The install chip must never sit on the search field above, and never on the public site.</p>
        <CrossPlatformBar />
      </div>
    );
  },
};
// #<page>?gate=1&plan=basic[&personal]: the REAL PlanSurfaceGate for that path ("#chat?gate=1&plan=basic&personal" => /app/chat locked for Personal Basic).
const GateRoute = { component: () => <PlanSurfaceGate><div className="p-6 text-sm">THE REAL PAGE OPENS HERE (not locked)</div></PlanSurfaceGate> };
// #inbox[?share=1]: the REAL empty-inbox welcome inside a list-panel-sized column (share=1 fakes navigator.share so the Share button shows).
const InboxRoute = {
  component: () => {
    if (/[?&]share=1/.test(location.hash)) (navigator as unknown as { share: () => Promise<void> }).share = async () => undefined;
    return (
      <div className="flex min-h-0 flex-1">
        <div className="w-full border-border md:w-[19rem] md:border-r lg:w-[22rem]">
          <div className="flex h-14 items-center border-b border-border px-4 text-sm font-bold">Inbox</div>
          <InboxWelcome onCompose={() => undefined} />
        </div>
        <div className="hidden flex-1 items-center justify-center text-sm text-muted-foreground md:flex">Nothing selected</div>
      </div>
    );
  },
};
// #admin/<health|storage|monitoring|logs|reports|diagnostics|audit|export|addresses|members|teams> (and #admin for Domains): the REAL admin layout (section nav) around the real page.
const ADMIN_PAGES: Record<string, unknown> = { "": AdminIndexRoute, health: AdminHealthRoute, storage: AdminStorageRoute, monitoring: AdminMonitoringRoute, logs: AdminLogsRoute, reports: AdminReportsRoute, diagnostics: AdminDiagnosticsRoute, audit: AdminAuditRoute, export: AdminExportRoute, members: AdminMembersRoute, teams: AdminTeamsRoute };
const AdminRoute = {
  component: () => {
    const sub = location.hash.replace(/^#\/?/, "").replace(/^app\//, "").split("?")[0].split("/")[1] ?? "";
    const Page = ((ADMIN_PAGES[sub] ?? AdminIndexRoute) as R).component;
    (globalThis as unknown as { __axOutlet: () => JSX.Element }).__axOutlet = () => <Page />;
    const Layout = (AdminLayoutRoute as unknown as R).component;
    return <Layout />;
  },
};
const pick = (h: string): R => {
  if (/[?&]gate=1/.test(h)) return GateRoute as unknown as R;
  const b = h.replace(/^#\/?/, "").replace(/^app\//, "").split("?")[0];
  if (b.startsWith("chips")) return ChipsRoute as unknown as R;
  if (b.startsWith("inbox")) return InboxRoute as unknown as R;
  if (b.startsWith("dashboard")) return DashboardRoute as unknown as R;
  if (b === "admin" || b.startsWith("admin/")) return AdminRoute as unknown as R;
  if (b === "org/audit") return OrgAuditRoute as unknown as R;
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
