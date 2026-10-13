import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";

import { Chip, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useCrmTimeline, type CrmTimelineKind } from "@/lib/crm";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/crm/timeline")({
  head: () => ({
    meta: [
      { title: "Timeline - ANEXOMAIL CRM" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: TimelinePage,
});

const KIND_LABEL: Record<CrmTimelineKind, string> = {
  email_in: "Mail in",
  email_out: "Mail out",
  meeting: "Meeting",
  task: "Task",
  deal: "Deal",
  promise: "Promise",
};

const FILTERS: (CrmTimelineKind | "all")[] = [
  "all",
  "email_in",
  "email_out",
  "meeting",
  "task",
  "deal",
  "promise",
];

const PAGE = 50;
const MAX = 200;

function TimelinePage() {
  const { t } = useLocale();
  const [kind, setKind] = useState<CrmTimelineKind | "all">("all");
  const [limit, setLimit] = useState(PAGE);
  const query = useCrmTimeline(kind === "all" ? [] : [kind], limit);

  return (
    <div className="mx-auto w-full max-w-4xl px-ax-5 py-ax-6">
      <SectionTitle
        title={t("Timeline")}
        hint={t("What happened, newest first. Mail, meetings, tasks, deals and promises in one place.")}
      />

      <div className="mb-4 flex flex-wrap gap-1.5">
        {FILTERS.map((f) => (
          <button
            key={f}
            type="button"
            onClick={() => {
              setKind(f);
              setLimit(PAGE);
            }}
            className={cn(
              "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold transition-colors",
              kind === f
                ? "border-foreground/50 bg-secondary text-foreground"
                : "border-border text-muted-foreground",
            )}
          >
            {f === "all" ? t("All") : t(KIND_LABEL[f])}
          </button>
        ))}
      </div>

      <CardBody
        query={{
          data: query.data,
          isPending: query.isPending,
          error: query.error ?? null,
          refetch: () => void query.refetch(),
        }}
        endpoint="/rpc/crm.timeline"
        skeleton={<StatSkeleton rows={7} />}
      >
        {(data) =>
          data.timeline.length === 0 ? (
            <p className="ax-caption text-muted-foreground">
              {t("Nothing here yet. Mail, meetings, tasks, deals and promises show up as they happen.")}
            </p>
          ) : (
            <div>
              <ol className="relative space-y-3 ps-4 before:absolute before:inset-y-1 before:start-1 before:w-px before:bg-border">
                {data.timeline.map((e, i) => (
                  <li key={`${e.at}-${i}`} className="relative flex flex-wrap items-center gap-2">
                    <span className="absolute -start-3.5 top-1.5 size-2 rounded-full bg-foreground" />
                    <Chip>{t(KIND_LABEL[e.kind] ?? e.kind)}</Chip>
                    <a
                      href={e.href}
                      className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground"
                    >
                      {e.title}
                    </a>
                    {e.person_email ? (
                      <a
                        href={`/app/crm/relationships?email=${encodeURIComponent(e.person_email)}`}
                        className="max-w-[14rem] truncate text-[11px] text-muted-foreground underline underline-offset-4"
                      >
                        {e.person_name || e.person_email}
                      </a>
                    ) : null}
                    <span className="ax-caption text-muted-foreground">{relativeTime(e.at)}</span>
                  </li>
                ))}
              </ol>
              {data.timeline.length >= limit && limit < MAX ? (
                <button
                  type="button"
                  onClick={() => setLimit((l) => Math.min(l + PAGE, MAX))}
                  className="ax-press mt-4 rounded-lg border border-border px-3 py-1.5 text-[12px] font-semibold text-foreground"
                >
                  {t("Show older")}
                </button>
              ) : null}
            </div>
          )
        }
      </CardBody>
    </div>
  );
}
