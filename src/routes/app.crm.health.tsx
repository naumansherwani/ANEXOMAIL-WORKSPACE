import { createFileRoute } from "@tanstack/react-router";

import { Chip, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useCrmHealth, type CrmHealthRelationship, type CrmHealthRow } from "@/lib/crm";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/crm/health")({
  head: () => ({
    meta: [
      { title: "Health - ANEXOMAIL CRM" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: HealthPage,
});

const REL_LABEL: Record<CrmHealthRelationship, string> = {
  active: "Active",
  cooling: "Cooling",
  cold: "Cold",
};

const REL_STYLE: Record<CrmHealthRelationship, string> = {
  active: "bg-emerald-500/15 text-emerald-500",
  cooling: "bg-amber-500/15 text-amber-500",
  cold: "bg-rose-500/15 text-rose-500",
};

const GROUPS: { rank: number; label: string; hint: string }[] = [
  { rank: 1, label: "Waiting for your reply", hint: "They wrote last. Answer these first." },
  { rank: 2, label: "Cooling", hint: "No contact for 15 to 45 days." },
  { rank: 3, label: "Cold", hint: "No contact for more than 45 days." },
  { rank: 4, label: "Active", hint: "In touch within the last 14 days." },
];

function PersonRow({ row }: { row: CrmHealthRow }) {
  const { t } = useLocale();
  return (
    <li className="flex flex-wrap items-center gap-2 rounded-xl border border-border px-ax-3 py-ax-2">
      <a
        href={`/app/crm/relationships?email=${encodeURIComponent(row.email)}`}
        className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground"
      >
        {row.name || row.email}
      </a>
      <span className={cn("ax-caption rounded-full px-2 py-0.5 font-semibold", REL_STYLE[row.relationship])}>
        {t(REL_LABEL[row.relationship])}
      </span>
      <Chip>{row.last_direction === "in" ? t("They wrote last") : t("You wrote last")}</Chip>
      <span className="ax-caption text-muted-foreground">
        {row.days_since <= 0 ? t("Today") : `${row.days_since} ${t("days ago")}`}
        {" · "}
        {relativeTime(row.last_contact_at)}
      </span>
    </li>
  );
}

function HealthPage() {
  const { t } = useLocale();
  const query = useCrmHealth();

  return (
    <div className="mx-auto w-full max-w-4xl px-ax-5 py-ax-6">
      <SectionTitle
        title={t("Health")}
        hint={t("Which relationships need you. Counted from real mail in both directions.")}
      />

      <CardBody
        query={{
          data: query.data,
          isPending: query.isPending,
          error: query.error ?? null,
          refetch: () => void query.refetch(),
        }}
        endpoint="/rpc/crm.health"
        skeleton={<StatSkeleton rows={5} />}
      >
        {(data) =>
          data.people.length === 0 ? (
            <p className="ax-caption text-muted-foreground">
              {t("No one to show yet. People appear here once they are on your book and you have exchanged mail.")}
            </p>
          ) : (
            <div className="space-y-ax-5">
              {GROUPS.map((g) => {
                const rows = data.people.filter((p) => p.rank_group === g.rank);
                if (rows.length === 0) return null;
                return (
                  <section key={g.rank}>
                    <h3 className="text-[13px] font-bold text-foreground">
                      {t(g.label)} ({rows.length})
                    </h3>
                    <p className="ax-caption mb-ax-2 text-muted-foreground">{t(g.hint)}</p>
                    <ul className="space-y-ax-2">
                      {rows.map((row) => (
                        <PersonRow key={row.contact_id} row={row} />
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
