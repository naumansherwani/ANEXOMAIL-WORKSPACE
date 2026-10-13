import { createFileRoute } from "@tanstack/react-router";

import { SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import {
  money,
  useCrmGraphView,
  useCrmTeamGraph,
  type CrmGraphDeal,
  type CrmGraphPerson,
  type CrmTeamRow,
} from "@/lib/crm";
import { useLocale } from "@/lib/i18n";

export const Route = createFileRoute("/app/crm/graph")({
  head: () => ({
    meta: [
      { title: "Graph - ANEXOMAIL CRM" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: GraphPage,
});

function PersonLine({ p }: { p: CrmGraphPerson }) {
  return (
    <li className="text-[13px]">
      <a
        href={`/app/crm/relationships?email=${encodeURIComponent(p.email)}`}
        className="font-semibold text-foreground underline underline-offset-4"
      >
        {p.name || p.email}
      </a>
      {p.name ? <span className="ax-caption ms-2 text-muted-foreground">{p.email}</span> : null}
    </li>
  );
}

function DealLine({ d }: { d: CrmGraphDeal }) {
  return (
    <li className="flex flex-wrap items-center gap-2 text-[13px]">
      <a
        href="/app/crm/pipeline"
        className="font-semibold text-foreground underline underline-offset-4"
      >
        {d.title}
      </a>
      <span className="ax-caption text-muted-foreground">
        {d.stage} {" · "} {money(Number(d.value), d.currency)}
      </span>
    </li>
  );
}

function TeamSection() {
  const { t } = useLocale();
  const query = useCrmTeamGraph();
  const rows = query.data?.team ?? [];
  if (rows.length === 0) return null;

  const byPerson = new Map<string, CrmTeamRow[]>();
  for (const r of rows) {
    const list = byPerson.get(r.person_email) ?? [];
    list.push(r);
    byPerson.set(r.person_email, list);
  }
  const people = Array.from(byPerson.entries()).sort((a, b) => b[1].length - a[1].length);

  return (
    <section className="mt-ax-5 rounded-xl border border-border p-ax-3">
      <h3 className="text-[14px] font-bold text-foreground">
        {t("Who in your team talks to whom")} ({people.length})
      </h3>
      <p className="ax-caption mb-ax-2 text-muted-foreground">
        {t("Outside people your teammates have exchanged mail with. Counted from real mail.")}
      </p>
      <ul className="space-y-ax-2">
        {people.map(([email, list]) => (
          <li key={email} className="text-[13px]">
            <a
              href={`/app/crm/relationships?email=${encodeURIComponent(email)}`}
              className="font-semibold text-foreground underline underline-offset-4"
            >
              {email}
            </a>
            {list.length > 1 ? (
              <span className="ax-caption ms-2 rounded-full bg-secondary px-2 py-0.5 font-semibold text-foreground">
                {list.length} {t("teammates")}
              </span>
            ) : null}
            <ul className="ms-ax-3 mt-0.5 space-y-0.5">
              {list.map((r) => (
                <li key={r.mailbox} className="ax-caption text-muted-foreground">
                  {r.member_email} {" · "} {r.messages} {t("mails")}
                </li>
              ))}
            </ul>
          </li>
        ))}
      </ul>
    </section>
  );
}

function GraphPage() {
  const { t } = useLocale();
  const query = useCrmGraphView();

  return (
    <div className="mx-auto w-full max-w-4xl px-ax-5 py-ax-6">
      <SectionTitle
        title={t("Graph")}
        hint={t("Who is inside each company and which deals they are on. Built from your real contacts and deals.")}
      />

      <CardBody
        query={{
          data: query.data,
          isPending: query.isPending,
          error: query.error ?? null,
          refetch: () => void query.refetch(),
        }}
        endpoint="/rpc/crm.graph"
        skeleton={<StatSkeleton rows={5} />}
      >
        {(data) => {
          const g = data.graph;
          const empty =
            g.companies.length === 0 && g.individuals.length === 0 && g.loose_deals.length === 0;
          if (empty) {
            return (
              <p className="ax-caption text-muted-foreground">
                {t("Nothing connected yet. People and deals appear here once they are on your book.")}
              </p>
            );
          }
          return (
            <div className="space-y-ax-5">
              {g.companies.map((c) => (
                <section key={c.company} className="rounded-xl border border-border p-ax-3">
                  <h3 className="text-[14px] font-bold text-foreground">{c.company}</h3>
                  {c.people.length > 0 ? (
                    <div className="mt-ax-2">
                      <p className="ax-caption text-muted-foreground">{t("People")} ({c.people.length})</p>
                      <ul className="mt-1 space-y-1">
                        {c.people.map((p) => (
                          <PersonLine key={p.id} p={p} />
                        ))}
                      </ul>
                    </div>
                  ) : null}
                  {c.deals.length > 0 ? (
                    <div className="mt-ax-2">
                      <p className="ax-caption text-muted-foreground">{t("Deals")} ({c.deals.length})</p>
                      <ul className="mt-1 space-y-1">
                        {c.deals.map((d) => (
                          <DealLine key={d.id} d={d} />
                        ))}
                      </ul>
                    </div>
                  ) : null}
                </section>
              ))}
              {g.individuals.length > 0 ? (
                <section className="rounded-xl border border-border p-ax-3">
                  <h3 className="text-[14px] font-bold text-foreground">
                    {t("Individuals")} ({g.individuals.length})
                  </h3>
                  <p className="ax-caption mb-1 text-muted-foreground">
                    {t("People on a personal email address, so no company is shown.")}
                  </p>
                  <ul className="space-y-1">
                    {g.individuals.map((p) => (
                      <PersonLine key={p.id} p={p} />
                    ))}
                  </ul>
                </section>
              ) : null}
              {g.loose_deals.length > 0 ? (
                <section className="rounded-xl border border-border p-ax-3">
                  <h3 className="text-[14px] font-bold text-foreground">
                    {t("Deals without a company")} ({g.loose_deals.length})
                  </h3>
                  <ul className="mt-1 space-y-1">
                    {g.loose_deals.map((d) => (
                      <DealLine key={d.id} d={d} />
                    ))}
                  </ul>
                </section>
              ) : null}
            </div>
          );
        }}
      </CardBody>
      <TeamSection />
    </div>
  );
}
