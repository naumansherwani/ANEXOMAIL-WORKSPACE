import { createFileRoute } from "@tanstack/react-router";
import { CalendarClock, Gauge } from "lucide-react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Stat } from "@/components/app/settings/SettingsBits";
import { useDrift, useScheduled } from "@/lib/settings";

export const Route = createFileRoute("/app/settings/health")({
  component: SettingsHealth,
});

/** Features 4 + 5 — drift vs safe baseline, aur scheduled change with auto-rollback. */
function SettingsHealth() {
  const drift = useDrift();
  const scheduled = useScheduled();

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl space-y-ax-6 px-6 py-8 md:px-8">
        <section>
          <p className="ax-eyebrow flex items-center gap-2">
            <Gauge className="size-3.5" aria-hidden="true" /> Drift vs baseline
          </p>
          <h2 className="ax-h2 mt-1 text-foreground">How far you are from the safe defaults</h2>
          <div className="mt-ax-4">
            <CardBody
              query={{
                data: drift.data,
                isPending: drift.isPending,
                error: drift.error ?? null,
                refetch: () => void drift.refetch(),
              }}
              endpoint="/api/settings/drift"
              skeleton={<StatSkeleton rows={4} />}
            >
              {(d) => (
                <>
                  <div className="grid gap-ax-3 sm:grid-cols-4">
                    <Stat label="Score" value={`${d.score}/100`} />
                    <Stat label="Aligned" value={String(d.aligned)} />
                    <Stat label="Looser" value={String(d.loose)} />
                    <Stat label="Risky" value={String(d.risky)} />
                  </div>
                  <ul className="mt-ax-4 space-y-1.5">
                    {d.items.map((i) => (
                      <li key={i.key} className="ax-plane flex flex-wrap items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]">
                        <span className="font-semibold text-foreground">{i.label}</span>
                        <span className="text-steel">{i.drift}</span>
                        <span className="ml-auto text-muted-foreground">recommended: {i.recommended}</span>
                      </li>
                    ))}
                  </ul>
                </>
              )}
            </CardBody>
          </div>
        </section>

        <section>
          <p className="ax-eyebrow flex items-center gap-2">
            <CalendarClock className="size-3.5" aria-hidden="true" /> Scheduled changes
          </p>
          <h2 className="ax-h2 mt-1 text-foreground">Apply later, roll back automatically</h2>
          <p className="ax-caption mt-1 text-muted-foreground">
            A risky change can land out of hours and undo itself if delivery or sign-in breaks.
          </p>
          <div className="mt-ax-4">
            <CardBody
              query={{
                data: scheduled.data,
                isPending: scheduled.isPending,
                error: scheduled.error ?? null,
                refetch: () => void scheduled.refetch(),
              }}
              endpoint="/api/settings/scheduled"
              skeleton={<StatSkeleton rows={3} />}
            >
              {(d) =>
                d.changes.length === 0 ? (
                  <p className="ax-caption text-muted-foreground">Nothing scheduled.</p>
                ) : (
                  <ul className="space-y-1.5">
                    {d.changes.map((c) => (
                      <li key={c.id} className="ax-plane flex flex-wrap items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]">
                        <span className="font-semibold text-foreground">{c.key}</span>
                        <span className="text-muted-foreground">→ {c.to_value}</span>
                        <span className="text-steel">{new Date(c.apply_at).toLocaleString("en-GB")}</span>
                        <span className="ml-auto text-steel">
                          {c.state}
                          {c.auto_rollback_minutes ? ` · rollback ${c.auto_rollback_minutes}m` : ""}
                        </span>
                      </li>
                    ))}
                  </ul>
                )
              }
            </CardBody>
          </div>
        </section>
      </div>
    </div>
  );
}
