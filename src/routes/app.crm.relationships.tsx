import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";

import { Chip, HealthRing, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Input } from "@/components/ui/input";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";
import { money, useCrmLive, useCrmMemory } from "@/lib/crm";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/crm/relationships")({
  validateSearch: (search: Record<string, unknown>) => ({
    email: typeof search["email"] === "string" ? search["email"] : "",
  }),
  head: () => ({
    meta: [{ title: "Relationships — ANEXOMAIL CRM" }, { name: "robots", content: "noindex" }],
  }),
  component: RelationshipsPage,
});

type Filter = "all" | "healthy" | "at_risk" | "silent" | "new";
const FILTERS: Filter[] = ["all", "healthy", "at_risk", "silent", "new"];

const DAY = 86_400_000;

function matches(
  p: { health_score: number | null; last_contact_at: string | null },
  filter: Filter,
): boolean {
  const last = p.last_contact_at ? new Date(p.last_contact_at).getTime() : null;
  const age = last == null ? null : Date.now() - last;
  switch (filter) {
    case "healthy":
      return (p.health_score ?? 0) >= 70;
    case "at_risk":
      return p.health_score != null && p.health_score < 40;
    case "silent":
      return age == null || age > 14 * DAY;
    case "new":
      return age != null && age <= 7 * DAY;
    default:
      return true;
  }
}

const FILTER_LABEL: Record<Filter, string> = {
  all: "All",
  healthy: "Healthy",
  at_risk: "At risk",
  silent: "Silent",
  new: "New",
};

function RelationshipsPage() {
  const { t } = useLocale();
  const { email: qEmail } = Route.useSearch();
  const [picked, setPicked] = useState(qEmail);
  const [filter, setFilter] = useState<Filter>("all");
  const live = useCrmLive();
  const memory = useCrmMemory(picked || undefined);

  return (
    <div className="relative mx-auto w-full max-w-[1400px] px-6 py-8 lg:px-8">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-72 bg-[radial-gradient(60%_90%_at_85%_-20%,oklch(0.455_0.093_258_/_12%),transparent_65%)]" />

      <div className="relative">
        <SectionTitle
          title={t("Relationships")}
          hint={t("People from real mail. Open one — mail, deals and work sit together.")}
        />

        {/* Filter chips */}
        <div className="mb-4 flex flex-wrap gap-1.5">
          {FILTERS.map((f) => (
            <button
              key={f}
              type="button"
              onClick={() => setFilter(f)}
              className={cn(
                "ax-press rounded-full border px-3 py-1.5 text-[12px] font-semibold transition-colors",
                filter === f
                  ? "border-foreground bg-secondary text-foreground"
                  : "border-border text-muted-foreground hover:text-foreground",
              )}
            >
              {t(FILTER_LABEL[f])}
            </button>
          ))}
        </div>

        <div className="grid gap-6 xl:grid-cols-[1fr_26.25rem]">
          {/* People table */}
          <CardBody
            query={{
              data: live.data,
              isPending: live.isPending,
              error: live.error ?? null,
              refetch: () => void live.refetch(),
            }}
            endpoint="/api/crm/live"
            skeleton={<StatSkeleton rows={8} />}
          >
            {(data) => {
              const people = data.people.filter((p) => matches(p, filter));
              return people.length === 0 ? (
                <div className="ax-plane flex min-h-[10rem] flex-col items-center justify-center gap-2 rounded-2xl p-6 text-center">
                  <p className="text-sm font-semibold text-foreground">{t("No one in this view")}</p>
                  <p className="ax-caption max-w-sm text-muted-foreground">
                    {t("People fill in from real mail. Change the filter or write the first email.")}
                  </p>
                </div>
              ) : (
                <div className="ax-plane overflow-hidden rounded-2xl">
                  <div className="hidden grid-cols-[1.4fr_1fr_72px_96px_64px] gap-3 border-b border-border px-4 py-2.5 text-[11px] font-semibold uppercase tracking-[0.1em] text-steel md:grid">
                    <span>{t("Name")}</span>
                    <span>{t("Company")}</span>
                    <span>{t("Health")}</span>
                    <span>{t("Last contact")}</span>
                    <span className="text-end">{t("Open")}</span>
                  </div>
                  <ul className="divide-y divide-border">
                    {people.map((p) => (
                      <li key={p.id}>
                        <button
                          type="button"
                          onClick={() => setPicked(p.primary_address)}
                          className={cn(
                            "ax-press grid w-full grid-cols-1 items-center gap-2 px-4 py-3.5 text-start transition-colors md:grid-cols-[1.4fr_1fr_72px_96px_64px] md:gap-3",
                            picked === p.primary_address ? "bg-secondary/70" : "hover:bg-secondary/40",
                          )}
                          style={{ minHeight: 68 }}
                        >
                          <span className="flex min-w-0 items-center gap-3">
                            <HealthRing value={p.health_score} />
                            <span className="min-w-0">
                              <span className="block truncate text-[13.5px] font-semibold text-foreground">
                                {p.display_name || p.primary_address}
                              </span>
                              <span className="ax-caption block truncate text-muted-foreground">
                                {p.primary_address}
                              </span>
                            </span>
                          </span>
                          <span className="truncate text-[12.5px] text-muted-foreground">
                            {p.company_name ?? "—"}
                          </span>
                          <span className="text-[12.5px] font-bold tabular-nums text-foreground">
                            {p.health_score ?? "—"}
                          </span>
                          <span className="text-[12px] text-muted-foreground">
                            {p.last_contact_at ? relativeTime(p.last_contact_at) : t("Never")}
                          </span>
                          <span className="text-end text-[12.5px] font-bold tabular-nums text-foreground">
                            {p.open_threads}
                          </span>
                        </button>
                      </li>
                    ))}
                  </ul>
                </div>
              );
            }}
          </CardBody>

          {/* Customer command panel — 420px */}
          <div className="min-w-0">
            <SectionTitle
              title={t("Customer memory")}
              hint={t("Recorded mail, deals and tasks for this address. Nothing invented.")}
            />
            <Input
              className="mb-3"
              value={picked}
              onChange={(e) => setPicked(e.target.value)}
              placeholder="name@company.com"
              aria-label={t("Person email")}
            />
            {!picked.includes("@") ? (
              <p className="ax-caption text-muted-foreground">
                {t("Choose a person or type their address.")}
              </p>
            ) : (
              <CardBody
                query={{
                  data: memory.data,
                  isPending: memory.isPending,
                  error: memory.error ?? null,
                  refetch: () => void memory.refetch(),
                }}
                endpoint="/api/crm/memory"
                skeleton={<StatSkeleton rows={8} />}
              >
                {(data) => (
                  <div className="space-y-4">
                    <p className="text-[15px] font-bold tracking-tight text-foreground">
                      {data.person
                        ? String((data.person as { display_name?: string }).display_name || data.email)
                        : data.email}
                    </p>

                    {data.next_actions.length > 0 ? (
                      <div>
                        <h3 className="ax-caption mb-2 font-bold uppercase tracking-[0.12em] text-steel">
                          {t("Next best action")}
                        </h3>
                        <ul className="space-y-2">
                          {data.next_actions.map((a, i) => (
                            <li key={i} className="rounded-xl border border-border bg-background/40 p-3">
                              <p className="text-[13px] font-semibold text-foreground">{t(a.action)}</p>
                              <p className="ax-caption mt-0.5 text-muted-foreground">{a.why}</p>
                              <a
                                href={a.href}
                                className="ax-caption mt-1 inline-block font-semibold text-foreground underline underline-offset-4"
                              >
                                {t("Open")}
                              </a>
                            </li>
                          ))}
                        </ul>
                      </div>
                    ) : null}

                    <div>
                      <h3 className="ax-caption mb-2 font-bold uppercase tracking-[0.12em] text-steel">
                        {t("Pipeline")}
                      </h3>
                      {data.deals.length === 0 ? (
                        <p className="ax-caption text-muted-foreground">
                          {t("No deal on this address yet.")}
                        </p>
                      ) : (
                        <ul className="space-y-1">
                          {data.deals.map((d) => (
                            <li key={d.id} className="flex justify-between text-[13px]">
                              <span className="truncate">{d.title}</span>
                              <span className="shrink-0 tabular-nums">{money(d.value, d.currency)}</span>
                            </li>
                          ))}
                        </ul>
                      )}
                    </div>

                    <div>
                      <h3 className="ax-caption mb-2 font-bold uppercase tracking-[0.12em] text-steel">
                        {t("Work")}
                      </h3>
                      {data.tasks.length === 0 ? (
                        <p className="ax-caption text-muted-foreground">
                          {t("No work object linked yet.")}
                        </p>
                      ) : (
                        <ul className="space-y-1">
                          {data.tasks.map((task) => (
                            <li key={task.id} className="text-[13px]">
                              {task.title} · {t(task.status)}
                              {task.due_at ? ` · ${relativeTime(task.due_at)}` : ""}
                            </li>
                          ))}
                        </ul>
                      )}
                    </div>

                    <div>
                      <h3 className="ax-caption mb-2 font-bold uppercase tracking-[0.12em] text-steel">
                        {t("Timeline")}
                      </h3>
                      {data.timeline.length === 0 ? (
                        <p className="ax-caption text-muted-foreground">
                          {t("No mail on record for this address.")}
                        </p>
                      ) : (
                        <ol className="space-y-2">
                          {data.timeline.map((e, i) => (
                            <li key={`${e.at}-${i}`}>
                              <a href={e.href} className="text-[13px] font-semibold text-foreground">
                                {e.title}
                              </a>
                              <p className="ax-caption text-muted-foreground">
                                {t(e.kind.replace("_", " "))} · {relativeTime(e.at)}
                              </p>
                            </li>
                          ))}
                        </ol>
                      )}
                    </div>
                  </div>
                )}
              </CardBody>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
