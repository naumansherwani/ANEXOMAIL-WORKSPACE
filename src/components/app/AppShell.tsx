import { Link, useNavigate, useRouterState } from "@tanstack/react-router";
import {
  CalendarDays,
  Building2,
  CheckSquare,
  ChevronDown,
  ChevronsLeft,
  ChevronsRight,
  Crown,
  Gauge,
  Inbox,
  KanbanSquare,
  LogOut,
  Mail,
  MessageSquare,
  Search,
  Shield,
  Sparkles,
  UserCircle2,
  Users,
} from "lucide-react";
import { useEffect, useState, type ReactNode } from "react";

import { BrandMark } from "@/components/site/BrandMark";
import { CommandPalette, useCommandPalette } from "@/components/app/CommandPalette";
import { TrialStrip } from "@/components/app/trial/TrialStrip";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { notify } from "@/lib/notify";

type RailItem = {
  to: string;
  label: string;
  icon: typeof Inbox;
  exact?: boolean;
  match?: string;
};

const primary: RailItem[] = [
  { to: "/app", label: "Today", icon: Inbox, exact: true },
  { to: "/app/mail/inbox", label: "Mail", icon: Mail, match: "/app/mail" },
  { to: "/app/chat", label: "ANEXOChat", icon: MessageSquare },
  { to: "/app/people", label: "People", icon: Users },
  { to: "/app/crm", label: "CRM", icon: KanbanSquare, match: "/app/crm" },
  { to: "/app/org", label: "Org", icon: Building2, match: "/app/org" },
  { to: "/app/calendar", label: "Calendar", icon: CalendarDays },
  { to: "/app/work", label: "Work", icon: CheckSquare },
  { to: "/app/ai-center", label: "AI", icon: Sparkles },
  { to: "/app/perf", label: "Speed", icon: Gauge, match: "/app/perf" },
  { to: "/app/founder", label: "Founder", icon: Crown },
  { to: "/app/admin", label: "Admin", icon: Shield, match: "/app/admin" },
];

/**
 * One surface, three panels, zero page reload.
 * Rail (this file) + list panel + detail panel come from the route below it.
 */
/**
 * Every workspace page needs exactly one <h1> for screen readers and document
 * outline. Panels use <h2>/<h3> for their own sections, so the shell owns the
 * page-level heading and derives it from the route path — one place, all pages.
 */
function pageHeading(pathname: string): string {
  const parts = pathname.replace(/\/+$/, "").split("/").filter(Boolean);
  if (parts.length <= 1) return "Workspace dashboard";
  const words = parts
    .slice(1)
    .filter((p) => p !== "founder_" && p !== "revenue_")
    .map((p) => p.replace(/-/g, " "))
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1));
  return words.join(" · ") || "Workspace";
}

export function AppShell({ children }: { children: ReactNode }) {
  const { open, setOpen } = useCommandPalette();
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const navigate = useNavigate();
  const { session, organisation, refresh, signOut } = useAuth();
  // Rail pin state — expanded by default on desktop, collapsed on tablet.
  // Persisted so the founder's choice survives navigation and reloads.
  const [collapsed, setCollapsed] = useState(false);
  useEffect(() => {
    const saved = window.localStorage.getItem("ax.rail.collapsed");
    if (saved === "true" || saved === "false") setCollapsed(saved === "true");
    else setCollapsed(window.innerWidth < 1100);
  }, []);
  const toggleRail = () => {
    setCollapsed((c) => {
      window.localStorage.setItem("ax.rail.collapsed", String(!c));
      return !c;
    });
  };

  const switchOrg = async (id: string) => {
    try {
      await api("/api/workspace/active-organisation", {
        method: "PATCH",
        body: JSON.stringify({ organisation_id: id }),
      });
      await refresh();
    } catch (error) {
      notify.failed("Could not switch workspace", {
        description: error instanceof Error ? error.message : "Please try again.",
      });
    }
  };

  const handleSignOut = async () => {
    await signOut();
    void navigate({ to: "/auth", replace: true });
  };

  const isActive = (item: RailItem) =>
    item.exact
      ? pathname === "/app" || pathname === "/app/"
      : pathname.startsWith(item.match ?? item.to);

  return (
    <div
      className="flex h-screen flex-col overflow-hidden bg-background"
      style={{ paddingBottom: "var(--ax-bottom-strip, 0px)" }}
    >
      <CommandPalette open={open} onOpenChange={setOpen} />

      {/* Top bar — brand, org, one search entry for the entire product */}
      <header className="flex h-14 shrink-0 items-center gap-3 border-b border-border px-4">
        <Link to="/" className="shrink-0">
          <BrandMark compact className="md:hidden" />
          <span className="hidden md:inline-flex">
            <BrandMark />
          </span>
        </Link>

        <DropdownMenu>
          <DropdownMenuTrigger className="ax-focus ml-1 hidden items-center gap-1.5 rounded-lg border border-border bg-secondary px-2.5 py-1.5 text-xs font-semibold text-foreground transition-colors hover:bg-surface-2 sm:inline-flex">
            {organisation?.name ?? "No organisation yet"}
            <ChevronDown className="size-3.5 text-steel" />
          </DropdownMenuTrigger>
          <DropdownMenuContent align="start" className="w-60">
            <DropdownMenuLabel>Workspaces</DropdownMenuLabel>
            {session?.organisations.length ? (
              session.organisations.map((org) => (
                <DropdownMenuItem key={org.id} onSelect={() => void switchOrg(org.id)}>
                  <span className="truncate">{org.name}</span>
                  <span className="ml-auto text-[10px] uppercase text-muted-foreground">
                    {org.role}
                  </span>
                </DropdownMenuItem>
              ))
            ) : (
              <DropdownMenuItem onSelect={() => void navigate({ to: "/onboarding" })}>
                Create your organisation
              </DropdownMenuItem>
            )}
          </DropdownMenuContent>
        </DropdownMenu>

        <button
          type="button"
          onClick={() => setOpen(true)}
          className="ml-auto flex w-full max-w-md items-center gap-2 rounded-xl border border-border bg-card px-3 py-2 text-left text-sm text-muted-foreground transition-colors hover:border-ring/50"
        >
          <Search className="size-4 shrink-0 text-steel" />
          <span className="truncate">Search mail, people, calendar, work…</span>
          <kbd className="ml-auto hidden shrink-0 rounded-md border border-border bg-secondary px-1.5 py-0.5 font-sans text-[10px] font-semibold text-steel sm:block">
            ⌘K
          </kbd>
        </button>

        <DropdownMenu>
          <DropdownMenuTrigger
            aria-label="Account"
            className="ax-focus ax-tap ml-1 flex size-9 shrink-0 items-center justify-center rounded-full border border-border bg-secondary text-foreground transition-colors hover:bg-surface-2"
          >
            <UserCircle2 className="size-5" />
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-60">
            <DropdownMenuLabel className="truncate">
              {session?.user.email ?? "Signed in"}
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={() => void navigate({ to: "/app/account" })}>
              <UserCircle2 className="size-4" />
              Account &amp; sessions
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => void handleSignOut()}>
              <LogOut className="size-4" />
              Sign out
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </header>
      <TrialStrip />

      <div className="flex min-h-0 flex-1">
        {/* Rail */}
        <nav
          aria-label="Workspace navigation"
          data-collapsed={collapsed ? "true" : "false"}
          style={{ width: collapsed ? "4.25rem" : "13.75rem" }}
          className="hidden min-h-0 shrink-0 flex-col border-r border-border bg-sidebar transition-[width] duration-200 md:flex"
        >
          <div className="flex min-h-0 flex-1 flex-col gap-0.5 overflow-y-auto p-2.5">
            {primary.map((item) => {
              const active = isActive(item);
              return (
                <Link
                  key={item.to}
                  to={item.to}
                  title={collapsed ? item.label : undefined}
                  aria-label={item.label}
                  className={`flex items-center gap-2.5 rounded-xl py-2.5 text-sm font-medium transition-colors ${
                    collapsed ? "justify-center px-0" : "px-3"
                  } ${
                    active
                      ? "bg-secondary text-foreground"
                      : "text-muted-foreground hover:bg-secondary/60 hover:text-foreground"
                  }`}
                >
                  <item.icon className="size-4 shrink-0" />
                  {!collapsed && <span className="truncate">{item.label}</span>}
                </Link>
              );
            })}
          </div>

          {/* Bottom: context line + pin control — always visible, never clipped */}
          <div className="shrink-0 border-t border-border p-2.5">
            {!collapsed && (
              <p className="px-1 pb-2 text-[11px] leading-relaxed text-muted-foreground">
                Threads carry an owner, a status and a due date — mail is work, not a list.
              </p>
            )}
            <button
              type="button"
              onClick={toggleRail}
              title={collapsed ? "Expand navigation" : "Collapse navigation"}
              aria-label={collapsed ? "Expand navigation" : "Collapse navigation"}
              aria-pressed={collapsed}
              className={`ax-focus flex w-full items-center gap-2 rounded-lg px-2 py-2 text-[11px] font-semibold text-muted-foreground transition-colors hover:bg-secondary/60 hover:text-foreground ${
                collapsed ? "justify-center" : ""
              }`}
            >
              {collapsed ? (
                <ChevronsRight className="size-4 shrink-0" />
              ) : (
                <>
                  <ChevronsLeft className="size-4 shrink-0" />
                  <span>Collapse</span>
                </>
              )}
            </button>
          </div>
        </nav>

        {/* Panels */}
        <main className="flex min-h-0 min-w-0 flex-1 flex-col md:flex-row">
          <h1 className="sr-only">{pageHeading(pathname)}</h1>
          {children}
        </main>
      </div>

      {/* Mobile bar */}
      <nav
        aria-label="Workspace navigation"
        className="flex shrink-0 items-stretch gap-0.5 overflow-x-auto border-t border-border bg-sidebar px-1 [scrollbar-width:none] md:hidden"
      >
        {primary.map((item) => {
          const active = isActive(item);
          return (
            <Link
              key={item.to}
              to={item.to}
              className={`flex min-w-[3.75rem] shrink-0 flex-col items-center gap-1 py-2.5 text-[10px] font-semibold ${
                active ? "text-foreground" : "text-muted-foreground"
              }`}
            >
              <item.icon className="size-4" />
              {item.label}
            </Link>
          );
        })}
      </nav>
    </div>
  );
}