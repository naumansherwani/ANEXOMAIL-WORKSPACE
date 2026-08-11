import { createFileRoute } from "@tanstack/react-router";
import { ScrollText } from "lucide-react";
import { useState } from "react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useIncidents, useLogs } from "@/lib/admin-center";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/admin/logs")({ component: LogsPage });

const LEVELS = ["all", "error", "warn", "info"] as const;

/** Feature 5 — Log lens + Feature 3 — Incident timeline, ek hi jagah. */
function LogsPage() {
  const [level, setLevel] = useState<string>("all");
  const [q, setQ] = useState("");
  const logs = useLogs(level, q);
  const incidents = useIncidents();

  return (
    <div className="mx-auto w-full max-w-3xl space-y-ax-8 px-6 py-8 md:px-8">
      <Section
        eyebrow={<><ScrollText className="size-3.5" aria-hidden="true" /> Log lens</>}
        title="Logs a human can read"
        blurb="Every line carries its trace id and a one-sentence translation of what actually happened."
      >
        <div className="flex flex-wrap items-center gap-2">
          {LEVELS.map((l) => (
            <button
              key={l}
              type="button"
              onClick={() => setLevel(l)}
              className={cn(
                "ax-press rounded-lg px-2.5 py-1.5 text-[12px] font-semibold transition-colors",
                level === l ? "bg-foreground text-background" : "bg-secondary text-muted-foreground",
              )}
            >
              {l}
            </button>
          ))}
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search message, route or trace id"
            className="ax-plane min-w-0 flex-1 rounded-lg px-3 py-1.5 text-[12px] text-foreground outline-none"
          />
        </div>

        <div className="mt-ax-4">
          <CardBody
            query={{ data: logs.data, isPending: logs.isPending, error: logs.error ?? null, refetch: () => void logs.refetch() }}
            endpoint="/api/admin/logs"
            skeleton={<StatSkeleton rows={6} />}
          >
            {(d) => (
              <ul className="space-y-1.5">
                {d.logs.map((l) => (
                  <Row key={l.id}>
                    <span className="text-steel">{new Date(l.at).toLocaleTimeString("en-GB")}</span>
                    <span
                      className={cn(
                        "font-bold",
                        l.level === "error" ? "text-red-400" : l.level === "warn" ? "text-amber-400" : "text-steel",
                      )}
                    >
                      {l.level}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-foreground">{l.plain ?? l.message}</span>
                      <span className="block truncate text-steel">
                        {l.route ?? l.source}
                        {l.status ? ` · ${l.status}` : ""}
                        {l.duration_ms ? ` · ${l.duration_ms}ms` : ""}
                        {l.trace_id ? ` · ${l.trace_id}` : ""}
                      </span>
                    </span>
                  </Row>
                ))}
              </ul>
            )}
          </CardBody>
        </div>
      </Section>

      <Section
        eyebrow={<>Incident timeline</>}
        title="What happened, minute by minute"
        blurb="Blame-free replay: detection, every action taken, recovery, and the prevention that came out of it."
      >
        <CardBody
          query={{
            data: incidents.data,
            isPending: incidents.isPending,
            error: incidents.error ?? null,
            refetch: () => void incidents.refetch(),
          }}
          endpoint="/api/admin/incidents"
          skeleton={<StatSkeleton rows={4} />}
        >
          {(d) => (
            <ul className="space-y-ax-4">
              {d.incidents.map((i) => (
                <li key={i.id} className="ax-plane rounded-2xl p-ax-4">
                  <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                    <span className="font-semibold text-foreground">{i.title}</span>
                    <span
                      className={cn(
                        "font-bold",
                        i.severity === "critical" ? "text-red-400" : i.severity === "major" ? "text-amber-400" : "text-steel",
                      )}
                    >
                      {i.severity}
                    </span>
                    <span className="text-muted-foreground">{i.status}</span>
                    {i.minutes != null && <span className="text-steel">{i.minutes}m</span>}
                    <span className="ml-auto text-steel">{new Date(i.started_at).toLocaleString("en-GB")}</span>
                  </div>
                  <ol className="mt-ax-3 space-y-1.5 border-l border-border pl-ax-4">
                    {i.events.map((e, idx) => (
                      <li key={idx} className="text-[12px]">
                        <span className="text-steel">{new Date(e.at).toLocaleTimeString("en-GB")}</span>{" "}
                        <span className="text-muted-foreground">{e.actor}</span>{" "}
                        <span className="text-foreground">{e.message}</span>
                      </li>
                    ))}
                  </ol>
                  {i.prevention && (
                    <p className="ax-caption mt-ax-3 text-muted-foreground">
                      <span className="font-semibold text-foreground">Prevention:</span> {i.prevention}
                    </p>
                  )}
                </li>
              ))}
            </ul>
          )}
        </CardBody>
      </Section>
    </div>
  );
}
