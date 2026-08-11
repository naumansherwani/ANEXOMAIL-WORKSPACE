import { createFileRoute } from "@tanstack/react-router";
import { Map as MapIcon } from "lucide-react";
import { useState } from "react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Verdict } from "@/components/app/premium/PremiumBits";
import { notify } from "@/lib/notify";
import { useRoadmap, useRoadmapAdd } from "@/lib/release";

export const Route = createFileRoute("/app/founder_/launch/roadmap")({ component: RoadmapPage });

/** v2.0 board — impact × effort, and which money road each item feeds. */
function RoadmapPage() {
  const q = useRoadmap();
  const add = useRoadmapAdd();
  const [title, setTitle] = useState("");
  const [area, setArea] = useState("mail");
  const [impact, setImpact] = useState(3);
  const [effort, setEffort] = useState(2);
  const [revenue, setRevenue] = useState("");

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><MapIcon className="size-3.5" aria-hidden="true" /> v2.0 roadmap</>}
        title="Everything v1.0 does not do"
        blurb="After the lock, new work lands here — ranked by impact over effort, with the revenue road it serves written next to it."
      >
        <form
          className="ax-plane grid gap-ax-3 rounded-2xl p-ax-4 sm:grid-cols-2"
          onSubmit={(e) => {
            e.preventDefault();
            if (!title.trim()) return;
            add.mutate(
              { title: title.trim(), area, impact, effort, revenue_link: revenue.trim() || null },
              {
                onSuccess: () => {
                  setTitle("");
                  setRevenue("");
                  notify.done("Added to v2.0");
                },
                onError: (err) =>
                  notify.failed("Could not add", {
                    description: err.isNotImplemented
                      ? "Waiting on POST /api/founder/release/roadmap."
                      : err.message,
                  }),
              },
            );
          }}
        >
          <label className="sm:col-span-2">
            <span className="ax-caption block text-muted-foreground">Item</span>
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="What should v2.0 do"
              className="mt-1 w-full rounded-lg border border-border bg-card px-2.5 py-1.5 text-[13px] text-foreground outline-none"
            />
          </label>
          <label>
            <span className="ax-caption block text-muted-foreground">Area</span>
            <input
              value={area}
              onChange={(e) => setArea(e.target.value)}
              className="mt-1 w-full rounded-lg border border-border bg-card px-2.5 py-1.5 text-[13px] text-foreground outline-none"
            />
          </label>
          <label>
            <span className="ax-caption block text-muted-foreground">Revenue road</span>
            <input
              value={revenue}
              onChange={(e) => setRevenue(e.target.value)}
              placeholder="subscriptions / migration / partner / SLA"
              className="mt-1 w-full rounded-lg border border-border bg-card px-2.5 py-1.5 text-[13px] text-foreground outline-none"
            />
          </label>
          <label>
            <span className="ax-caption block text-muted-foreground">Impact {impact}</span>
            <input type="range" min={1} max={5} value={impact} onChange={(e) => setImpact(Number(e.target.value))} className="mt-2 w-full" />
          </label>
          <label>
            <span className="ax-caption block text-muted-foreground">Effort {effort}</span>
            <input type="range" min={1} max={5} value={effort} onChange={(e) => setEffort(Number(e.target.value))} className="mt-2 w-full" />
          </label>
          <button
            type="submit"
            disabled={add.isPending}
            className="ax-press rounded-lg bg-foreground px-3 py-2 text-[12px] font-semibold text-background disabled:opacity-50 sm:col-span-2"
          >
            {add.isPending ? "Saving…" : "Add to v2.0"}
          </button>
        </form>

        <div className="mt-ax-5">
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/founder/release/roadmap"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(d) =>
              d.items.length === 0 ? (
                <p className="ax-caption text-muted-foreground">
                  Empty board — add the first v2.0 item above.
                </p>
              ) : (
                <ul className="space-y-1.5">
                  {[...d.items]
                    .sort((a, b) => b.impact / b.effort - a.impact / a.effort)
                    .map((i) => (
                      <Row key={i.id}>
                        <Verdict verdict={i.state === "shipped" ? "green" : i.state === "building" ? "watch" : "fail"}>
                          {i.state}
                        </Verdict>
                        <span className="min-w-0 flex-1">
                          <span className="block font-semibold text-foreground">{i.title}</span>
                          <span className="block truncate text-steel">
                            {i.area}
                            {i.revenue_link ? ` · ${i.revenue_link}` : ""}
                          </span>
                        </span>
                        <span className="text-steel">
                          impact {i.impact} · effort {i.effort}
                        </span>
                        <span className="ml-auto font-bold text-foreground">
                          {(i.impact / Math.max(1, i.effort)).toFixed(1)}×
                        </span>
                      </Row>
                    ))}
                </ul>
              )
            }
          </CardBody>
        </div>
      </Section>
    </div>
  );
}
