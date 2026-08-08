import { createFileRoute } from "@tanstack/react-router";

import { Chip, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { relativeTime } from "@/lib/mail";
import { useCrmActivities, type CrmActivity } from "@/lib/crm";

export const Route = createFileRoute("/app/crm/activity")({
  head: () => ({
    meta: [
      { title: "Activity timeline — ANEXOMAIL AI CRM" },
      {
        name: "description",
        content:
          "One timeline for every touch on an account: mail in, mail out, calls, meetings, notes and stage changes.",
      },
      { property: "og:title", content: "Activity timeline — ANEXOMAIL AI CRM" },
      { property: "og:description", content: "Every account touch on one timeline." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: ActivityPage,
});

const KIND_LABEL: Record<CrmActivity["kind"], string> = {
  email_in: "Mail in",
  email_out: "Mail out",
  call: "Call",
  meeting: "Meeting",
  note: "Note",
  stage_change: "Stage change",
  task: "Task",
};

function ActivityPage() {
  const activities = useCrmActivities();

  return (
    <div className="mx-auto w-full max-w-4xl px-ax-5 py-ax-6">
      <SectionTitle
        title="Activity"
        hint="Written by the system as work happens. Nobody logs activity by hand in ANEXOMAIL."
      />

      <CardBody
        query={{
          data: activities.data,
          isPending: activities.isPending,
          error: activities.error ?? null,
          refetch: () => void activities.refetch(),
        }}
        endpoint="/api/crm/activities"
        skeleton={<StatSkeleton rows={7} />}
      >
        {(data) =>
          data.activities.length === 0 ? (
            <p className="ax-caption text-muted-foreground">
              No activity yet. The first inbound thread starts the timeline.
            </p>
          ) : (
            <ol className="space-y-ax-2">
              {data.activities.map((a) => (
                <li key={a.id} className="ax-plane rounded-2xl p-ax-4">
                  <div className="flex flex-wrap items-center gap-ax-3">
                    <Chip>{KIND_LABEL[a.kind]}</Chip>
                    <p className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                      {a.subject ?? a.contact_email ?? "—"}
                    </p>
                    <span className="ax-caption text-muted-foreground">
                      {a.actor ?? "system"} · {relativeTime(a.created_at)}
                    </span>
                  </div>
                  {a.body && <p className="ax-body mt-1">{a.body}</p>}
                </li>
              ))}
            </ol>
          )
        }
      </CardBody>
    </div>
  );
}
