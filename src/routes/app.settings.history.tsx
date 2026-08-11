import { createFileRoute } from "@tanstack/react-router";
import { History } from "lucide-react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useRevertSetting, useSettingHistory } from "@/lib/settings";

export const Route = createFileRoute("/app/settings/history")({
  component: TimeMachine,
});

/** Feature 1 — Time Machine: poore workspace ki setting timeline, one-click revert. */
function TimeMachine() {
  const q = useSettingHistory();
  const revert = useRevertSetting();

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <History className="size-3.5" aria-hidden="true" /> Time machine
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">Every setting change, reversible</h2>
        <p className="ax-caption mt-1 text-muted-foreground">
          Who changed what, when, and why — and one click to put it back exactly as it was.
        </p>

        <div className="mt-ax-5">
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/settings/history"
            skeleton={<StatSkeleton rows={6} />}
          >
            {(d) =>
              d.versions.length === 0 ? (
                <p className="ax-caption text-muted-foreground">Nothing has been changed yet.</p>
              ) : (
                <ol className="space-y-1.5">
                  {d.versions.map((v) => (
                    <li key={v.id} className="ax-plane flex flex-wrap items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]">
                      <span className="w-40 font-semibold text-foreground">{v.key}</span>
                      <span className="text-muted-foreground">
                        {v.from_value ?? "—"} → {v.to_value ?? "—"}
                      </span>
                      <span className="text-steel">{new Date(v.changed_at).toLocaleString("en-GB")}</span>
                      <span className="text-steel">{v.changed_by}</span>
                      <span className="ml-auto">
                        {v.reverted ? (
                          <span className="text-steel">reverted</span>
                        ) : (
                          <button
                            type="button"
                            className="ax-press rounded-md bg-secondary px-2 py-0.5 font-semibold text-foreground"
                            disabled={revert.isPending}
                            onClick={() => revert.mutate({ version_id: v.id })}
                          >
                            Revert
                          </button>
                        )}
                      </span>
                    </li>
                  ))}
                </ol>
              )
            }
          </CardBody>
        </div>
      </div>
    </div>
  );
}
