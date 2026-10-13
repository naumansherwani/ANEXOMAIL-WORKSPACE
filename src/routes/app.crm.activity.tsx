import { createFileRoute } from "@tanstack/react-router";

import { Chip, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { relativeTime } from "@/lib/mail";
import { useLocale } from "@/lib/i18n";
import { useCrmActivities, useCrmEvidence, type CrmActivity } from "@/lib/crm";

export const Route = createFileRoute("/app/crm/activity")({
  head: () => ({
    meta: [
      { title: "Activity timeline — ANEXOMAIL CRM" },
      {
        name: "description",
        content:
          "One timeline for every touch on an account: mail in, mail out, calls, meetings, notes and stage changes.",
      },
      { property: "og:title", content: "Activity timeline — ANEXOMAIL CRM" },
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
  const { t } = useLocale();
  const activities = useCrmActivities();
  const evidence = useCrmEvidence();

  return (
    <div className="mx-auto w-full max-w-4xl px-ax-5 py-ax-6">
      <SectionTitle
        title={t("Activity")}
        hint={t("Written by the system as work happens. Nobody logs activity by hand in ANEXOMAIL.")}
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
              {t("No activity yet. The first inbound thread starts the timeline.")}
            </p>
          ) : (
            <ol className="space-y-ax-2">
              {data.activities.map((a) => (
                <li key={a.id} className="ax-plane rounded-2xl p-ax-4">
                  <div className="flex flex-wrap items-center gap-ax-3">
                    <Chip>{t(KIND_LABEL[a.kind])}</Chip>
                    <p className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                      {a.subject ?? a.contact_email ?? "—"}
                    </p>
                    <span className="ax-caption text-muted-foreground">
                      {a.actor ?? t("system")} · {relativeTime(a.created_at)}
                    </span>
                  </div>
                  {a.body && <p className="ax-body mt-1">{a.body}</p>}
                </li>
              ))}
            </ol>
          )
        }
      </CardBody>

      <div className="mt-ax-6">
        <SectionTitle
          title={t("Evidence")}
          hint={t("Decision, why, source row, action, result. Written when work happens — not by hand.")}
        />
        <CardBody
          query={{
            data: evidence.data,
            isPending: evidence.isPending,
            error: evidence.error ?? null,
            refetch: () => void evidence.refetch(),
          }}
          endpoint="/api/crm/evidence"
          skeleton={<StatSkeleton rows={4} />}
        >
          {(data) =>
            data.entries.length === 0 ? (
              <p className="ax-caption text-muted-foreground">{t("No evidence rows yet.")}</p>
            ) : (
              <ol className="space-y-ax-2">
                {data.entries.map((row) => (
                  <li key={row.id} className="ax-plane rounded-2xl p-ax-4">
                    <p className="text-[13px] font-semibold text-foreground">{row.decision}</p>
                    {row.why ? <p className="ax-caption mt-1 text-muted-foreground">{row.why}</p> : null}
                    <p className="ax-caption mt-1 text-steel">
                      {[row.source_table, row.source_id, row.action, row.result].filter(Boolean).join(" · ")}
                    </p>
                    <p className="ax-caption mt-1 text-muted-foreground">
                      {row.actor ?? t("system")} · {relativeTime(row.created_at)}
                    </p>
                  </li>
                ))}
              </ol>
            )
          }
        </CardBody>
      </div>
    </div>
  );
}
