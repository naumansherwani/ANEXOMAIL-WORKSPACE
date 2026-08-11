import { createFileRoute } from "@tanstack/react-router";
import { Brain } from "lucide-react";

import { Section, StackBar, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { hours, useDeepWork } from "@/lib/analytics";

export const Route = createFileRoute("/app/analytics/deep-work")({ component: DeepWorkPage });

/** Feature 3 — Deep work map: asli kaam vs inbox mein phansa waqt. */
function DeepWorkPage() {
  const q = useDeepWork();
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
        <Section
          eyebrow={<><Brain className="size-3.5" aria-hidden="true" /> Deep work map</>}
          title="Real work versus inbox"
          blurb="The week split honestly: focused work, inbox, meetings — and where your best window is."
        >
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/analytics/deep-work"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(d) => (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                  <Stat label="Deep work" value={hours(d.deep_hours)} />
                  <Stat label="Inbox" value={hours(d.inbox_hours)} />
                  <Stat label="Meetings" value={hours(d.meeting_hours)} />
                  <Stat
                    label="Longest focus"
                    value={`${d.longest_focus_minutes}m`}
                    {...(d.best_window ? { hint: `best window ${d.best_window}` } : {})}
                  />
                </div>
                <p className="ax-caption mt-ax-3 text-muted-foreground">
                  Fragmentation {d.fragmentation}/100 — lower means fewer broken stretches.
                </p>
                <div className="mt-ax-5">
                  <StackBar
                    rows={d.days.map((x) => ({ label: x.day, values: [x.deep, x.inbox, x.meeting] }))}
                    keys={[
                      { label: "Deep", className: "bg-foreground" },
                      { label: "Inbox", className: "bg-steel" },
                      { label: "Meetings", className: "bg-border" },
                    ]}
                  />
                </div>
              </>
            )}
          </CardBody>
        </Section>
      </div>
    </div>
  );
}
