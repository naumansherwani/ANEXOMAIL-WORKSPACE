import { createFileRoute } from "@tanstack/react-router";

import { Chip, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useCrmNext, type CrmNextRow, type CrmNextSource } from "@/lib/crm";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";

export const Route = createFileRoute("/app/crm/next")({
  head: () => ({
    meta: [
      { title: "Next - ANEXOMAIL CRM" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: NextPage,
});

const SOURCE_LABEL: Record<CrmNextSource, string> = {
  risk: "From Risk",
  promises: "From Promises",
  health: "From Health",
};

function NextItem({ n, row }: { n: number; row: CrmNextRow }) {
  const { t } = useLocale();
  return (
    <li className="rounded-xl border border-border p-ax-3">
      <div className="flex flex-wrap items-center gap-2">
        <span className="ax-caption font-bold text-foreground">{n}</span>
        <Chip>{t(SOURCE_LABEL[row.source])}</Chip>
        <p className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">{row.title}</p>
      </div>
      <p className="ax-caption mt-0.5 text-muted-foreground">{row.reason}</p>
      <p className="ax-caption mt-1 flex flex-wrap items-center gap-x-3 text-muted-foreground">
        {row.person_email ? (
          <a
            href={`/app/crm/relationships?email=${encodeURIComponent(row.person_email)}`}
            className="underline underline-offset-4"
          >
            {row.person_email}
          </a>
        ) : null}
        <a href={row.href} className="underline underline-offset-4">
          {t("Open")}
        </a>
        {row.at ? <span>{relativeTime(row.at)}</span> : null}
      </p>
    </li>
  );
}

function NextPage() {
  const { t } = useLocale();
  const query = useCrmNext();

  return (
    <div className="mx-auto w-full max-w-4xl px-ax-5 py-ax-6">
      <SectionTitle
        title={t("Next")}
        hint={t("What to do today. Built only from Risk, Promises and Health, and each item says where it came from.")}
      />

      <CardBody
        query={{
          data: query.data,
          isPending: query.isPending,
          error: query.error ?? null,
          refetch: () => void query.refetch(),
        }}
        endpoint="/rpc/crm.next"
        skeleton={<StatSkeleton rows={5} />}
      >
        {(data) =>
          data.next.length === 0 ? (
            <p className="ax-caption text-muted-foreground">
              {t("Nothing needs you right now. When something does, it will be listed here in order.")}
            </p>
          ) : (
            <ol className="space-y-ax-2">
              {data.next.map((row, i) => (
                <NextItem key={`${row.source}-${i}`} n={i + 1} row={row} />
              ))}
            </ol>
          )
        }
      </CardBody>
    </div>
  );
}
