import { createFileRoute } from "@tanstack/react-router";
import { PlugZap } from "lucide-react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useFounderIntegrations } from "@/lib/integrations";

export const Route = createFileRoute("/app/founder_/integrations")({
  component: FounderIntegrations,
});

/** Phase 22 — founder god-view: har tenant ka connection, migration aur delivery sach. */
function FounderIntegrations() {
  const overview = useFounderIntegrations();

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-4xl px-6 py-8 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <PlugZap className="size-3.5" aria-hidden="true" /> Integrations god-view
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">Every connection, every failure</h2>

        <div className="mt-ax-5">
          <CardBody
            query={{
              data: overview.data,
              isPending: overview.isPending,
              error: overview.error ?? null,
              refetch: () => void overview.refetch(),
            }}
            endpoint="/api/founder/integrations/overview"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(o) => (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-3">
                  <Stat label="Connections" value={String(o.connections)} />
                  <Stat label="Needs re-auth" value={String(o.needs_reauth)} />
                  <Stat label="Migrations running" value={String(o.migrations_running)} />
                  <Stat label="Migrations failed" value={String(o.migrations_failed)} />
                  <Stat label="Threads migrated 30d" value={o.threads_migrated_30d.toLocaleString()} />
                </div>

                <h3 className="ax-heading mt-ax-6 text-foreground">By provider</h3>
                <ul className="mt-ax-3 space-y-1.5">
                  {o.by_provider.map((p) => (
                    <li
                      key={p.provider}
                      className="ax-plane flex items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]"
                    >
                      <span className="w-40 font-semibold text-foreground">{p.provider}</span>
                      <span className="text-muted-foreground">{p.connections} connections</span>
                      <span className="ml-auto text-steel">{p.failures} failures</span>
                    </li>
                  ))}
                </ul>

                <h3 className="ax-heading mt-ax-6 text-foreground">Worst delivery scores</h3>
                <ul className="mt-ax-3 space-y-1.5">
                  {o.worst_delivery.map((d) => (
                    <li
                      key={d.domain}
                      className="ax-plane flex items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]"
                    >
                      <span className="font-semibold text-foreground">{d.domain}</span>
                      <span className="ml-auto text-steel">{d.score}/100</span>
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

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="ax-plane rounded-2xl p-ax-4">
      <p className="ax-caption text-muted-foreground">{label}</p>
      <p className="mt-1 text-[19px] font-bold text-foreground">{value}</p>
    </div>
  );
}
