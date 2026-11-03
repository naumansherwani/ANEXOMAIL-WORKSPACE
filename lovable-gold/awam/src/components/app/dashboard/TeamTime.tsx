import { Users } from "lucide-react";
import { useMemo } from "react";

import { DashboardCard } from "@/components/app/dashboard/DashboardCard";
import { useAuth } from "@/lib/auth";
import { useLocale } from "@/lib/i18n";
import { CELL_WHY, ZONE_CLASS, cellZone, useOverlap, type CellCode } from "@/lib/overlap";
import { useMembers } from "@/lib/team";
import { cityOf, fmtTimeIn, zoneCity } from "@/lib/timeFormat";
import { cn } from "@/lib/utils";

/**
 * "Team time" — who is in their day right now, and the next 24 hours for each person (one cell per hour).
 * Same data and same honesty as the calendar's Overlap Matrix: each person's own working hours + free/busy, a guest is judged by
 * the clock only. Shows nothing for a one-person workspace and nothing if the engine update is not live yet (no placeholder).
 * No package branch: every plan and family account sees the same card (Rule 37 / Rule 40).
 */

const MAX_ROWS = 8;

export function TeamTime({ enabled }: { enabled: boolean }) {
  const { organisation } = useAuth();
  const { t } = useLocale();
  const members = useMembers(enabled ? organisation?.id : undefined);
  const addresses = useMemo(
    () =>
      (members.data?.members ?? [])
        .filter((m) => m.status !== "revoked" && m.status !== "invited" && m.email)
        .map((m) => m.email)
        .slice(0, MAX_ROWS),
    [members.data],
  );
  const mine = useMemo(() => zoneCity().iana, []);
  const ov = useOverlap({ addresses, days: 1, stepMin: 60, minutes: 60 }, enabled && addresses.length >= 2);

  if (!enabled || addresses.length < 2 || ov.isError || !ov.data) return null;
  const { members: rows, grid, best } = ov.data;
  const first = new Date(best[0]?.start ?? grid.from);

  return (
    <DashboardCard
      title={t("Team time")}
      hint={t("Who is in their own day, next 24 hours (each person's own working hours).")}
      icon={<Users className="size-4" />}
      to="/app/calendar"
      ctaLabel={t("Plan a meeting")}
    >
      <ul className="space-y-1.5">
        {rows.slice(0, MAX_ROWS).map((m) => {
          const nowCell = (m.row[0] ?? "x") as CellCode;
          const who = m.you ? t("You") : m.name || m.address.split("@")[0] || m.address;
          return (
            <li key={m.address} className="flex items-center gap-ax-3">
              <span className="w-24 shrink-0 sm:w-32">
                <span className="block truncate text-[12px] font-semibold text-foreground">{who}</span>
                <span className="block truncate text-[10px] text-muted-foreground">
                  {m.tz ? `${cityOf(m.tz)} ${fmtTimeIn(new Date(), m.tz)}` : t("zone unknown")}
                </span>
              </span>
              <span
                className="flex min-w-0 flex-1 overflow-hidden rounded-sm"
                role="img"
                aria-label={`${who}: ${CELL_WHY[nowCell]}`}
              >
                {Array.from(m.row).map((c, i) => (
                  <span
                    key={i}
                    title={`${who} — ${CELL_WHY[c as CellCode] ?? ""}`}
                    className={cn("h-5 min-w-0 flex-1 border-r border-background/60", ZONE_CLASS[cellZone(c)], c === "u" && "opacity-50")}
                  />
                ))}
              </span>
            </li>
          );
        })}
      </ul>
      <p className="ax-caption mt-ax-3 text-muted-foreground">
        {best[0]?.all_green
          ? `${t("Best hour for everyone")}: ${fmtTimeIn(first, mine)} (${cityOf(mine)} ${t("time")}).`
          : t("No hour in the next 24 hours is inside everyone's day.")}
      </p>
    </DashboardCard>
  );
}
