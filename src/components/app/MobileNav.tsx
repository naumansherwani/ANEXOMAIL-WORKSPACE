import { Link } from "@tanstack/react-router";
import { Check, LayoutGrid, type LucideIcon } from "lucide-react";
import { useState } from "react";

import { Sheet, SheetContent, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { useLocale } from "@/lib/i18n";
import { cn } from "@/lib/utils";

/**
 * Phone navigation (Rule 19). Pehle yeh 7-14 items ki side-scroll patti thi: Domains / CRM jaise tabs
 * screen ke bahar chhup jate the aur kisi ko pata hi nahi chalta tha. Ab: sirf 4 asli tabs + "More"
 * (baqi sab ek badi, 44px+ tiles wali sheet mein) — thumb ke neeche, home-bar ke upar (safe-area).
 * Workspace badalna bhi yahin (phone par header ka org dropdown nahi dikhta).
 */

export type NavItem = { to: string; label: string; icon: LucideIcon };
export type NavOrg = { id: string; name: string; role?: string };

// Mail company ka dil hai, Home pehle-run ka setup dikhata hai (8k) — dono hamesha bar mein.
const PRIORITY = ["/app", "/app/mail/inbox", "/app/people", "/app/calendar", "/app/work"];
const rank = (to: string) => {
  const i = PRIORITY.indexOf(to);
  return i === -1 ? PRIORITY.length : i;
};

const tabBase =
  "relative flex min-h-14 min-w-0 flex-1 basis-0 flex-col items-center justify-center gap-1 px-1 text-[11px] font-semibold leading-none transition-colors focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-[var(--cyan-accent)]";

export function MobileNav({
  items,
  isActive,
  orgs = [],
  activeOrgId,
  onSwitchOrg,
}: {
  items: NavItem[];
  isActive: (item: NavItem) => boolean;
  orgs?: NavOrg[];
  activeOrgId?: string | null;
  onSwitchOrg?: (id: string) => void;
}) {
  const { t } = useLocale();
  const [more, setMore] = useState(false);

  const ranked = [...items].sort((a, b) => rank(a.to) - rank(b.to));
  const needMore = ranked.length > 5 || orgs.length > 1;
  const tabs = needMore ? ranked.slice(0, 4) : ranked;
  const rest = needMore ? ranked.slice(4) : [];
  const moreActive = rest.some(isActive);

  return (
    <>
      <nav
        aria-label={t("Workspace navigation")}
        className="flex shrink-0 items-stretch border-t border-border bg-sidebar pb-[env(safe-area-inset-bottom,0px)] pl-[env(safe-area-inset-left,0px)] pr-[env(safe-area-inset-right,0px)] sm:hidden"
      >
        {tabs.map((item) => {
          const active = isActive(item);
          return (
            <Link
              key={item.to}
              to={item.to}
              aria-current={active ? "page" : undefined}
              className={cn(tabBase, "ax-press", active ? "text-foreground" : "text-muted-foreground")}
            >
              {active && (
                <span aria-hidden="true" className="absolute inset-x-[28%] top-0 h-[2px] rounded-full bg-primary" />
              )}
              <item.icon className="size-5 shrink-0" aria-hidden="true" />
              <span className="max-w-full truncate">{t(item.label)}</span>
            </Link>
          );
        })}
        {needMore && (
          <button
            type="button"
            onClick={() => setMore(true)}
            aria-haspopup="dialog"
            aria-expanded={more}
            className={cn(tabBase, "ax-press", moreActive ? "text-foreground" : "text-muted-foreground")}
          >
            {moreActive && (
              <span aria-hidden="true" className="absolute inset-x-[28%] top-0 h-[2px] rounded-full bg-primary" />
            )}
            <LayoutGrid className="size-5 shrink-0" aria-hidden="true" />
            <span>{t("More")}</span>
          </button>
        )}
      </nav>

      <Sheet open={more} onOpenChange={setMore}>
        <SheetContent
          side="bottom"
          className="max-h-[85dvh] overflow-y-auto rounded-t-2xl px-4 pb-[max(1.25rem,env(safe-area-inset-bottom,0px))] pt-5 sm:hidden"
        >
          <SheetHeader className="text-left">
            <SheetTitle className="ax-heading">{t("More")}</SheetTitle>
          </SheetHeader>

          {rest.length > 0 && (
            <ul className="mt-4 grid grid-cols-3 gap-2">
              {rest.map((item) => {
                const active = isActive(item);
                return (
                  <li key={item.to}>
                    <Link
                      to={item.to}
                      onClick={() => setMore(false)}
                      aria-current={active ? "page" : undefined}
                      className={cn(
                        "ax-press flex min-h-[4.5rem] flex-col items-center justify-center gap-1.5 rounded-xl border p-2 text-center text-[12px] font-semibold leading-tight",
                        active
                          ? "border-[var(--cyan-accent)]/60 bg-[var(--cyan-accent)]/5 text-foreground"
                          : "border-border text-muted-foreground",
                      )}
                    >
                      <item.icon className="size-5 shrink-0" aria-hidden="true" />
                      <span className="max-w-full truncate">{t(item.label)}</span>
                    </Link>
                  </li>
                );
              })}
            </ul>
          )}

          {orgs.length > 1 && (
            <section className="mt-5" aria-label={t("Workspaces")}>
              <p className="ax-eyebrow">{t("Workspaces")}</p>
              <ul className="mt-2 grid gap-1.5">
                {orgs.map((org) => {
                  const on = org.id === activeOrgId;
                  return (
                    <li key={org.id}>
                      <button
                        type="button"
                        onClick={() => {
                          setMore(false);
                          onSwitchOrg?.(org.id);
                        }}
                        aria-pressed={on}
                        className={cn(
                          "ax-press flex min-h-11 w-full items-center gap-2 rounded-xl border px-3 text-left text-[13px] font-semibold",
                          on ? "border-[var(--cyan-accent)]/60 text-foreground" : "border-border text-muted-foreground",
                        )}
                      >
                        <span className="min-w-0 flex-1 truncate">{org.name}</span>
                        {org.role ? <span className="shrink-0 text-[10px] uppercase">{org.role}</span> : null}
                        {on ? <Check className="size-4 shrink-0 text-[var(--cyan-accent)]" aria-hidden="true" /> : null}
                      </button>
                    </li>
                  );
                })}
              </ul>
            </section>
          )}
        </SheetContent>
      </Sheet>
    </>
  );
}
