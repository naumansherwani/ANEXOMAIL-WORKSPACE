import { createFileRoute } from "@tanstack/react-router";
import { CalendarDays, CheckSquare, KanbanSquare, Mail, Activity } from "lucide-react";
import { useState } from "react";

import { Chip, HealthRing, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Input } from "@/components/ui/input";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";
import { money, STAGE_LABEL, useCrmLive, useCrmMemory, type DealStage } from "@/lib/crm";
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

/** Risk label derives from the recorded health score — never a guess. */
function riskFromHealth(score: number | null): { label: string; tone: "good" | "warn" | "bad" } | null {
  if (score == null) return null;
  if (score < 40) return { label: "High", tone: "bad" };
  if (score < 70) return { label: "Medium", tone: "warn" };
  return { label: "Low", tone: "good" };
}

const KIND_ICON: Record<string, typeof Mail> = {
  mail: Mail,
  meeting: CalendarDays,
  calendar: CalendarDays,
  deal: KanbanSquare,
  task: CheckSquare,
  work: CheckSquare,
};

function RelationshipsPage() {
  const { t } = useLocale();
  const { email: qEmail } = Route.useSearch();
  const [picked, setPicked] = useState(qEmail);
  const [filter, setFilter] = useState<Filter>("all");
  const live = useCrmLive();
  const memory = useCrmMemory(picked || undefined);

  const pickedPerson = live.data?.people.find((p) => p.primary_address === picked) ?? null;

  return (
    <div className="relative mx-auto w-full max-w-[1400px] px-6 py-8 lg:px-8">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-72 bg-[radial-gradient(60%_90%_at_85%_-20%,oklch(0.455_0.093_258_/_12%),transparent_65%)]" />

      <div className="relative">
        <SectionTitle
          title={t("Relationships")}
          hint={t("People from real mail. Open one — mail, deals and work sit together.")}
        />

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
                {(data) => {
                  const dealValue = data.deals.reduce((s, d) => s + Number(d.value ?? 0), 0);
                  const currency = data.deals[0]?.currency ?? "GBP";
                  const openDeals = data.deals.filter(
                    (d) => !["won", "lost"].includes(d.stage),
                  );
                  const risk = riskFromHealth(pickedPerson?.health_score ?? null);
                  return (
                    <div className="space-y-4">
                      {/* Identity header */}
                      <div className="ax-plane rounded-[18px] p-5">
                        <div className="flex items-start gap-4">
                          <HealthRing value={pickedPerson?.health_score ?? null} />
                          <div className="min-w-0 flex-1">
                            <p className="truncate text-[17px] font-bold tracking-tight text-foreground">
                              {data.person
                                ? String(
                                    (data.person as { display_name?: string }).display_name ||
                                      data.email,
                                  )
                                : data.email}
                            </p>
                            <div className="mt-1.5 flex flex-wrap gap-1.5">
                              {pickedPerson?.company_name ? (
                                <Chip>{pickedPerson.company_name}</Chip>
                              ) : null}
                              {pickedPerson?.relationship ? (
                                <Chip>{t(pickedPerson.relationship)}</Chip>
                              ) : null}
                              {risk ? <Chip tone={risk.tone}>{t("Risk")}: {t(risk.label)}</Chip> : null}
                            </div>
                          </div>
                        </div>
                        <div className="mt-4 grid grid-cols-3 gap-3 border-t border-border/70 pt-4">
                          <div>
                            <p className="ax-caption text-steel">{t("Deal value")}</p>
                            <p className="mt-0.5 text-[15px] font-bold tabular-nums text-foreground">
                              {data.deals.length > 0 ? money(dealValue, currency) : "—"}
                            </p>
                          </div>
                          <div>
                            <p className="ax-caption text-steel">{t("Open deals")}</p>
                            <p className="mt-0.5 text-[15px] font-bold tabular-nums text-foreground">
                              {openDeals.length}
                            </p>
                          </div>
                          <div>
                            <p className="ax-caption text-steel">{t("Open threads")}</p>
                            <p className="mt-0.5 text-[15px] font-bold tabular-nums text-foreground">
                              {pickedPerson?.open_threads ?? 0}
                            </p>
                          </div>
                        </div>
                      </div>

                      {/* Next best action — the one thing to do */}
                      {data.next_actions.length > 0 ? (
                        <div className="ax-plane rounded-[18px] border-foreground/20 p-5">
                          <p className="text-[11px] font-bold uppercase tracking-[0.14em] text-steel">
                            {t("Next best action")}
                          </p>
                          <p className="mt-2 text-[14px] font-semibold text-foreground">
                            {t(data.next_actions[0]!.action)}
                          </p>
                          <p className="ax-caption mt-1 text-muted-foreground">
                            {data.next_actions[0]!.why}
                          </p>
                          <a
                            href={data.next_actions[0]!.href}
                            className="ax-press mt-3 inline-flex h-9 items-center rounded-lg bg-primary px-3.5 text-[12.5px] font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
                          >
                            {t("Open")}
                          </a>
                          {data.next_actions.length > 1 ? (
                            <ul className="mt-3 space-y-1.5 border-t border-border/70 pt-3">
                              {data.next_actions.slice(1, 4).map((a, i) => (
                                <li key={i} className="flex items-baseline justify-between gap-2">
                                  <span className="min-w-0 truncate text-[12px] text-muted-foreground">
                                    {t(a.action)} — {a.why}
                                  </span>
                                  <a
                                    href={a.href}
                                    className="shrink-0 text-[11px] font-semibold text-foreground underline underline-offset-4"
                                  >
                                    {t("Open")}
                                  </a>
                                </li>
                              ))}
                            </ul>
                          ) : null}
                        </div>
                      ) : null}

                      {/* Pipeline */}
                      <div className="ax-plane rounded-[18px] p-5">
                        <h3 className="text-[11px] font-bold uppercase tracking-[0.14em] text-steel">
                          {t("Pipeline")}
                        </h3>
                        {data.deals.length === 0 ? (
                          <p className="ax-caption mt-2 text-muted-foreground">
                            {t("No deal on this address yet.")}
                          </p>
                        ) : (
                          <ul className="mt-2.5 space-y-2">
                            {data.deals.map((d) => (
                              <li key={d.id} className="flex items-center justify-between gap-2">
                                <span className="min-w-0 truncate text-[13px] font-semibold text-foreground">
                                  {d.title}
                                </span>
                                <span className="flex shrink-0 items-center gap-2">
                                  <Chip>{t(STAGE_LABEL[d.stage as DealStage] ?? d.stage)}</Chip>
                                  <span className="text-[12.5px] font-bold tabular-nums text-foreground">
                                    {money(d.value, d.currency)}
                                  </span>
                                </span>
                              </li>
                            ))}
                          </ul>
                        )}
                      </div>

                      {/* Work */}
                      <div className="ax-plane rounded-[18px] p-5">
                        <h3 className="text-[11px] font-bold uppercase tracking-[0.14em] text-steel">
                          {t("Work")}
                        </h3>
                        {data.tasks.length === 0 ? (
                          <p className="ax-caption mt-2 text-muted-foreground">
                            {t("No work object linked yet.")}
                          </p>
                        ) : (
                          <ul className="mt-2.5 space-y-1.5">
                            {data.tasks.map((task) => (
                              <li key={task.id} className="flex items-center gap-2 text-[13px]">
                                <CheckSquare className="size-3.5 shrink-0 text-steel" />
                                <span className="min-w-0 truncate text-foreground">{task.title}</span>
                                <span className="shrink-0 text-[11px] text-muted-foreground">
                                  {t(task.status)}
                                  {task.due_at ? ` · ${relativeTime(task.due_at)}` : ""}
                                </span>
                              </li>
                            ))}
                          </ul>
                        )}
                      </div>

                      {/* Timeline */}
                      <div className="ax-plane rounded-[18px] p-5">
                        <h3 className="text-[11px] font-bold uppercase tracking-[0.14em] text-steel">
                          {t("Timeline")}
                        </h3>
                        {data.timeline.length === 0 ? (
                          <p className="ax-caption mt-2 text-muted-foreground">
                            {t("No mail on record for this address.")}
                          </p>
                        ) : (
                          <ol className="relative mt-3 space-y-3 ps-4 before:absolute before:inset-y-1 before:start-1 before:w-px before:bg-border">
                            {data.timeline.map((e, i) => {
                              const Icon = KIND_ICON[e.kind] ?? Activity;
                              return (
                                <li key={`${e.at}-${i}`} className="relative flex items-center gap-2.5">
                                  <span className="absolute -start-[13px] flex size-4 items-center justify-center rounded-full border border-border bg-card">
                                    <Icon className="size-2.5 text-steel" />
                                  </span>
                                  <a
                                    href={e.href}
                                    className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground"
                                  >
                                    {e.title}
                                  </a>
                                  <span className="ax-caption shrink-0 text-muted-foreground">
                                    {relativeTime(e.at)}
                                  </span>
                                </li>
                              );
                            })}
                          </ol>
                        )}
                      </div>
                    </div>
                  );
                }}
              </CardBody>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
