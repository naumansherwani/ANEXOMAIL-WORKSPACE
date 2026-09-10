import { createFileRoute, Link } from "@tanstack/react-router";
import { Building2 } from "lucide-react";

import { HealthRing, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useCompanies } from "@/lib/contacts";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";

export const Route = createFileRoute("/app/crm/accounts")({
  head: () => ({
    meta: [
      { title: "Accounts — ANEXOMAIL CRM" },
      {
        name: "description",
        content:
          "Every company you actually talk to — people, open threads and health from recorded mail, not a imported list.",
      },
      { property: "og:title", content: "Accounts — ANEXOMAIL CRM" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AccountsPage,
});

function AccountsPage() {
  const { t } = useLocale();
  const companies = useCompanies({});

  return (
    <div className="mx-auto w-full max-w-6xl px-ax-5 py-ax-6">
      <SectionTitle
        title={t("Accounts")}
        hint={t("Companies built from your real conversations. A company appears here only when mail with its domain exists.")}
      />

      <CardBody
        query={{
          data: companies.data,
          isPending: companies.isPending,
          error: companies.error ?? null,
          refetch: () => void companies.refetch(),
        }}
        endpoint="/api/companies"
        skeleton={<StatSkeleton rows={6} />}
      >
        {(data) =>
          data.companies.length === 0 ? (
            <div className="ax-plane flex min-h-[10rem] flex-col items-center justify-center gap-2 rounded-2xl p-ax-6 text-center">
              <Building2 className="size-5 text-steel" />
              <p className="text-sm font-semibold text-foreground">{t("No accounts yet")}</p>
              <p className="ax-caption max-w-sm text-muted-foreground">
                {t("Accounts grow out of mail. When the first conversation lands, the company appears here with its people.")}
              </p>
            </div>
          ) : (
            <div className="ax-plane divide-y divide-border rounded-2xl">
              {data.companies.map((c) => (
                <Link
                  key={c.domain}
                  to="/app/people"
                  search={{ view: "companies", id: c.domain, q: "", filter: "all", tag: "" }}
                  className="ax-press flex items-center gap-ax-4 px-ax-4 py-ax-3"
                >
                  <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-secondary text-steel">
                    <Building2 className="size-4" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-semibold text-foreground">
                      {c.name || c.domain}
                    </span>
                    <span className="ax-caption block truncate text-muted-foreground">
                      {c.domain} · {c.people_count} {t("people")} · {c.open_threads} {t("open threads")}
                      {c.last_contact_at ? ` · ${relativeTime(c.last_contact_at)}` : ""}
                    </span>
                  </span>
                  <HealthRing value={c.health_score} />
                </Link>
              ))}
            </div>
          )
        }
      </CardBody>
    </div>
  );
}
