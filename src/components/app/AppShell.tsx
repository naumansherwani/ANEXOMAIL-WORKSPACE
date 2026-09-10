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
import { ChatRailLink } from "@/components/app/chat/ChatRailLink";
import { TrialStrip } from "@/components/app/trial/TrialStrip";
import { founderSurfaceAllowed, isAiHost, isPublicMailHost } from "@/lib/host";
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
import { useAccountState } from "@/lib/trial";

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
  const account = useAccountState();
  const trialAllowed = new Set(account.data?.trial_features ?? []);
  // FOUNDER HOST GUARD (permanent): Founder view sirf founderworkspace host par.
  // Hydration-safe — SSR par hostname nahi hota, is liye effect ke baad set hota hai.
  const [founderHost, setFounderHost] = useState(false);
  const [publicMailHost, setPublicMailHost] = useState(true);
  const [aiHost, setAiHost] = useState(false);
  useEffect(() => {
    setFounderHost(founderSurfaceAllowed());
    setPublicMailHost(isPublicMailHost());
    setAiHost(isAiHost());
  }, []);
  const allowed = account.data?.trial_limited
    ? primary.filter((item) => {
        if (item.to === "/app") return trialAllowed.has("today");
        if (item.to.startsWith("/app/mail")) return trialAllowed.has("mail");
        if (item.to === "/app/people") return trialAllowed.has("people");
        if (item.to === "/app/calendar") return trialAllowed.has("calendar");
        return false;
      })
    : primary;
  const visiblePrimary = allowed.filter((item) => {
    if (item.to.startsWith("/app/founder")) return founderHost;
    if (aiHost || founderHost) return true;
    if (!publicMailHost) return true;
    // anexomail.com = personal mail. Image-3 (Today/CRM/AI/Admin) yahan nahi — ai host pe hai.
    const hideOnAwam = new Set([
      "/app",
      "/app/crm",
      "/app/org",
      "/app/work",
      "/app/ai-center",
      "/app/perf",
      "/app/admin",
      "/app/founder",
    ]);
    return !hideOnAwam.has(item.to);
  });
  const mailboxLabel =
    session?.user.anexomail_address || session?.user.email || organisation?.name || "ANEXOMAIL";
  const brandHome = publicMailHost ? "/app/mail/inbox" : "/app";
  const founderBlocked = pathname.startsWith("/app/founder") && !founderHost;
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
    if (session?.active_organisation_id === id) return;
    if ((session?.organisations.length ?? 0) <= 1) return;
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
        <Link to={brandHome} className="shrink-0" aria-label="Stay in ANEXOMAIL workspace">
          <BrandMark compact className="md:hidden" />
          <span className="hidden md:inline-flex">
            <BrandMark />
          </span>
        </Link>

        {publicMailHost ? (
          <span className="ml-1 hidden max-w-[18rem] truncate rounded-lg border border-border bg-secondary px-2.5 py-1.5 text-xs font-semibold text-foreground sm:inline-flex">
            {mailboxLabel}
          </span>
        ) : (
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
        )}

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
            className="ax-focus ax-tap ml-1 flex size-9 shrink-0 items-center justify-center overflow-hidden rounded-full border border-border bg-secondary text-foreground transition-colors hover:bg-surface-2"
          >
            {session?.user.avatar_url ? (
              <img src={session.user.avatar_url} alt="" className="size-9 object-cover" />
            ) : (
              <UserCircle2 className="size-5" />
            )}
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-72">
            <DropdownMenuLabel className="space-y-0.5 font-normal">
              <span className="block text-sm font-semibold text-foreground">
                {session?.user.display_name || session?.user.name || "Account"}
              </span>
              <span className="block break-all text-xs font-medium text-muted-foreground">
                {session?.user.anexomail_address || session?.user.email || "Signed in"}
              </span>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={() => void navigate({ to: "/app/account" })}>
              <UserCircle2 className="size-4" />
              Profile, photo &amp; sessions
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
            {visiblePrimary.map((item) => {
              const active = isActive(item);
              // PHASE 6: ANEXOChat naye tab mein khulta hai + real unread badge
              if (item.to === "/app/chat") {
                return <ChatRailLink key={item.to} collapsed={collapsed} active={active} />;
              }
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
          {founderBlocked ? (
            <div className="flex flex-1 items-center justify-center px-6 py-16">
              <div className="max-w-sm text-center">
                <p className="ax-eyebrow">Founder view</p>
                <h2 className="mt-3 text-lg font-bold text-foreground">Not available here</h2>
                <p className="mt-2 text-sm text-muted-foreground">
                  Founder view only opens on the founder workspace host.
                </p>
                <Link
                  to="/app"
                  className="ax-focus mt-5 inline-flex rounded-lg border border-border px-3 py-1.5 text-xs font-semibold text-foreground"
                >
                  Back to workspace
                </Link>
              </div>
            </div>
          ) : (
            children
          )}
        </main>
      </div>

      {/* Mobile bar */}
      <nav
        aria-label="Workspace navigation"
        className="flex shrink-0 items-stretch gap-0.5 overflow-x-auto border-t border-border bg-sidebar px-1 [scrollbar-width:none] md:hidden"
      >
        {visiblePrimary.map((item) => {
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
