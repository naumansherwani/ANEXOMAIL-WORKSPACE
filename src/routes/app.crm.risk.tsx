import { createFileRoute } from "@tanstack/react-router";

import { SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useCrmRisk, type CrmRiskKind, type CrmRiskRow } from "@/lib/crm";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";

export const Route = createFileRoute("/app/crm/risk")({
  head: () => ({
    meta: [
      { title: "Risk - ANEXOMAIL CRM" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: RiskPage,
});

const KIND_TITLE: Record<CrmRiskKind, string> = {
  deal_cold: "Deals going cold",
  promise_overdue: "Overdue promises",
  reply_waiting: "Waiting for your reply",
};

const ORDER: CrmRiskKind[] = ["deal_cold", "promise_overdue", "reply_waiting"];

function RiskRow({ r }: { r: CrmRiskRow }) {
  const { t } = useLocale();
  return (
    <li className="rounded-xl border border-border p-ax-3">
      <p className="text-[13px] font-semibold text-foreground">{r.title}</p>
      <p className="ax-caption mt-0.5 text-muted-foreground">{r.reason}</p>
      <p className="ax-caption mt-1 flex flex-wrap items-center gap-x-3 text-muted-foreground">
        {r.person_email ? (
          <a
            href={`/app/crm/relationships?email=${encodeURIComponent(r.person_email)}`}
            className="underline underline-offset-4"
          >
            {r.person_email}
          </a>
        ) : null}
        <a
          href={r.href}
          className="underline underline-offset-4"
        >
          {t("Open")}
        </a>
        {r.at ? <span>{relativeTime(r.at)}</span> : null}
      </p>
    </li>
  );
}

function RiskPage() {
  const { t } = useLocale();
  const query = useCrmRisk();

  return (
    <div className="mx-auto w-full max-w-4xl px-ax-5 py-ax-6">
      <SectionTitle
        title={t("Risk")}
        hint={t("Only what can go wrong, each with the reason. Every item opens the place where you fix it.")}
      />

      <CardBody
        query={{
          data: query.data,
          isPending: query.isPending,
          error: query.error ?? null,
          refetch: () => void query.refetch(),
        }}
        endpoint="/rpc/crm.risk"
        skeleton={<StatSkeleton rows={4} />}
      >
        {(data) =>
          data.risks.length === 0 ? (
            <p className="ax-caption text-muted-foreground">
              {t("No risks right now. A cold deal, an overdue promise or a reply you owe will show up here.")}
            </p>
          ) : (
            <div className="space-y-ax-5">
              {ORDER.map((k) => {
                const rows = data.risks.filter((r) => r.kind === k);
                if (rows.length === 0) return null;
                return (
                  <section key={k}>
                    <h3 className="mb-ax-2 text-[13px] font-bold text-foreground">
                      {t(KIND_TITLE[k])} ({rows.length})
                    </h3>
                    <ul className="space-y-ax-2">
                      {rows.map((r, i) => (
                        <RiskRow key={`${r.kind}-${i}`} r={r} />
                      ))}
                    </ul>
                  </section>
                );
              })}
            </div>
          )
        }
      </CardBody>
    </div>
  );
}
