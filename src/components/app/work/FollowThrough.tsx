import { useState } from "react";

import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { useFollowThrough } from "@/lib/calendar";
import { cn } from "@/lib/utils";

/**
 * Follow-through score — kept vs broken promises, per person and per team.
 * The score is server calculated from real completions, never estimated here.
 */
export function FollowThroughTable() {
  const [scope, setScope] = useState<"person" | "team">("person");
  const query = useFollowThrough(scope);

  return (
    <div>
      <div className="mb-ax-3 flex items-center gap-1">
        {(["person", "team"] as const).map((s) => (
          <button
            key={s}
            type="button"
            onClick={() => setScope(s)}
            className={cn(
              "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold capitalize",
              scope === s
                ? "border-cyan-accent/50 bg-secondary text-foreground"
                : "border-border text-muted-foreground",
            )}
          >
            {s === "person" ? "Per person" : "Team"}
          </button>
        ))}
      </div>

      {query.error ? (
        query.error.isNotImplemented || query.error.code === "no_api_url" ? (
          <NotWired endpoint="GET /api/work/follow-through" />
        ) : (
          <ErrorState body={query.error.message} onRetry={() => void query.refetch()} />
        )
      ) : query.isPending ? (
        <ListSkeleton rows={4} label="Scoring follow-through" />
      ) : (query.data?.rows.length ?? 0) === 0 ? (
        <p className="ax-caption rounded-xl border border-border px-ax-3 py-ax-3 text-muted-foreground">
          No committed promises yet, so there is nothing to score.
        </p>
      ) : (
        <ul className="divide-y divide-border rounded-xl border border-border">
          {query.data?.rows.map((row) => (
            <li key={row.subject} className="flex items-center gap-ax-3 px-ax-3 py-ax-2">
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[13px] font-semibold text-foreground">
                  {row.display_name || row.subject}
                </span>
                <span className="ax-caption block text-muted-foreground">
                  {row.kept_on_time} on time · {row.kept_late} late · {row.broken} broken of{" "}
                  {row.promises_made}
                </span>
              </span>
              <span
                className={cn(
                  "shrink-0 text-sm font-bold",
                  row.score === null
                    ? "text-steel"
                    : row.score >= 80
                      ? "text-success"
                      : row.score >= 50
                        ? "text-amber-400"
                        : "text-danger",
                )}
              >
                {row.score === null ? "—" : `${row.score}%`}
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}