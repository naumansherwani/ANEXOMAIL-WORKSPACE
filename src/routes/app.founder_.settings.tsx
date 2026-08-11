import { createFileRoute } from "@tanstack/react-router";
import { SlidersHorizontal } from "lucide-react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Stat } from "@/components/app/settings/SettingsBits";
import { useFounderSettings } from "@/lib/settings";

export const Route = createFileRoute("/app/founder_/settings")({
  component: FounderSettings,
});

/** Phase 23 — founder god-view: har tenant ki setting sehat, drift aur reverts. */
function FounderSettings() {
  const q = useFounderSettings();

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-4xl px-6 py-8 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <SlidersHorizontal className="size-3.5" aria-hidden="true" /> Settings god-view
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">Who changed what, everywhere</h2>

        <div className="mt-ax-5">
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/founder/settings/overview"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(o) => (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                  <Stat label="Tenants" value={String(o.tenants)} />
                  <Stat label="Changes 24h" value={String(o.changes_24h)} />
                  <Stat label="Reverts 7d" value={String(o.reverts_7d)} />
                  <Stat label="Pending scheduled" value={String(o.pending_scheduled)} />
                </div>

                <h3 className="ax-heading mt-ax-6 text-foreground">Riskiest tenants</h3>
                <ul className="mt-ax-3 space-y-1.5">
                  {o.risky_tenants.map((t) => (
                    <li key={t.tenant} className="ax-plane flex items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]">
                      <span className="font-semibold text-foreground">{t.tenant}</span>
                      <span className="text-steel">{t.risky} risky settings</span>
                      <span className="ml-auto text-foreground">{t.score}/100</span>
                    </li>
                  ))}
                </ul>

                <h3 className="ax-heading mt-ax-6 text-foreground">Most changed settings</h3>
                <ul className="mt-ax-3 space-y-1.5">
                  {o.most_changed.map((m) => (
                    <li key={m.key} className="ax-plane flex items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]">
                      <span className="font-semibold text-foreground">{m.key}</span>
                      <span className="ml-auto text-steel">{m.changes} changes</span>
                    </li>
                  ))}
                </ul>
              </>
            )}
          </CardBody>
        </div>
      </div>
    </div>
  );
}
