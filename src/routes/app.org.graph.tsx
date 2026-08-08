import { createFileRoute } from "@tanstack/react-router";
import { Network } from "lucide-react";
import { useState } from "react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Chip, OrgGraphCanvas, SectionTitle } from "@/components/app/org/OrgBits";
import { useOrgGraph } from "@/lib/org";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/org/graph")({
  head: () => ({
    meta: [
      { title: "Live org graph — ANEXOMAIL Organization Center" },
      {
        name: "description",
        content:
          "Your real organisation drawn from real conversations: who talks to whom, who is central, and where work gets stuck.",
      },
      { property: "og:title", content: "Live org graph — ANEXOMAIL Organization Center" },
      {
        property: "og:description",
        content: "A living map of who talks to whom, built from real mail traffic.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: GraphPage,
});

const WINDOWS = [7, 30, 90];

function GraphPage() {
  const [days, setDays] = useState(30);
  const [selected, setSelected] = useState<string | null>(null);
  const graph = useOrgGraph(days);

  return (
    <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0 flex-1">
          <SectionTitle
            title="Live org graph"
            hint="Not a chart you maintain — the server draws it from who actually emails whom."
          />
        </div>
        <div className="flex gap-1">
          {WINDOWS.map((w) => (
            <button
              key={w}
              type="button"
              onClick={() => setDays(w)}
              className={cn(
                "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold",
                days === w
                  ? "border-cyan-accent/50 bg-secondary text-foreground"
                  : "border-border text-muted-foreground",
              )}
            >
              {w} days
            </button>
          ))}
        </div>
      </div>

      <CardBody
        query={{
          data: graph.data,
          isPending: graph.isPending,
          error: graph.error ?? null,
          refetch: () => void graph.refetch(),
        }}
        endpoint="/api/org/graph"
        skeleton={<StatSkeleton rows={6} />}
      >
        {(data) =>
          data.nodes.length === 0 ? (
            <p className="ax-caption text-muted-foreground">
              Not enough conversation in this window to draw the graph.
            </p>
          ) : (
            <div className="grid gap-ax-4 lg:grid-cols-[1.4fr_1fr]">
              <div className="ax-plane rounded-2xl p-ax-4">
                <OrgGraphCanvas
                  nodes={data.nodes}
                  edges={data.edges}
                  selected={selected}
                  onSelect={(id) => setSelected((prev) => (prev === id ? null : id))}
                />
                <p className="ax-caption mt-2 flex items-center gap-1.5 text-muted-foreground">
                  <Network className="size-3.5" aria-hidden="true" /> Thicker line = more
                  conversation. Amber node = bottleneck.
                </p>
              </div>
              <ul className="space-y-1.5">
                {data.nodes.map((n) => (
                  <li
                    key={n.id}
                    className={cn(
                      "cursor-pointer rounded-xl border px-ax-3 py-ax-2",
                      selected === n.id ? "border-foreground" : "border-border",
                    )}
                    onClick={() => setSelected((prev) => (prev === n.id ? null : n.id))}
                  >
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                        {n.label}
                      </span>
                      <Chip>{n.role}</Chip>
                      {n.bottleneck && <Chip tone="warn">bottleneck</Chip>}
                    </div>
                    <p className="ax-caption mt-0.5 truncate text-muted-foreground">
                      {n.email}
                      {n.department ? ` · ${n.department}` : ""}
                      {n.centrality !== null ? ` · centrality ${Math.round(n.centrality)}` : ""}
                    </p>
                  </li>
                ))}
              </ul>
            </div>
          )
        }
      </CardBody>
    </div>
  );
}