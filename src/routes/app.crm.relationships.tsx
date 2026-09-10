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

function RelationshipsPage() {
  const { t } = useLocale();
  const { email: qEmail } = Route.useSearch();
  const [picked, setPicked] = useState(qEmail);
  const live = useCrmLive();
  const memory = useCrmMemory(picked || undefined);

  return (
    <div className="mx-auto grid w-full max-w-6xl gap-ax-5 px-ax-5 py-ax-6 lg:grid-cols-[18rem_1fr]">
      <div>
        <SectionTitle title={t("Relationships")} hint={t("People from real mail. Open one to see mail, deals and work together.")} />
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
          {(data) =>
            data.people.length === 0 ? (
              <p className="ax-caption text-muted-foreground">{t("No people yet. Mail someone — People fills from the thread.")}</p>
            ) : (
              <ul className="space-y-1">
                {data.people.map((p) => (
                  <li key={p.id}>
                    <button
                      type="button"
                      onClick={() => setPicked(p.primary_address)}
                      className={cn(
                        "ax-press flex w-full items-center gap-2 rounded-xl border px-3 py-2 text-left",
                        picked === p.primary_address
                          ? "border-foreground bg-secondary"
                          : "border-border hover:bg-secondary/60",
                      )}
                    >
                      <HealthRing value={p.health_score} />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-[13px] font-semibold text-foreground">
                          {p.display_name || p.primary_address}
                        </p>
                        <p className="ax-caption truncate text-muted-foreground">{p.primary_address}</p>
                        <div className="mt-1 flex flex-wrap gap-1">
                          {p.relationship ? <Chip>{p.relationship}</Chip> : null}
                        </div>
                      </div>
                    </button>
                  </li>
                ))}
              </ul>
            )
          }
        </CardBody>
      </div>

      <div>
        <SectionTitle title={t("Customer memory")} hint={t("Recorded mail, deals and tasks for this address. Nothing invented.")} />
        <Input
          className="mb-ax-3"
          value={picked}
          onChange={(e) => setPicked(e.target.value)}
          placeholder="name@company.com"
          aria-label={t("Person email")}
        />
        {!picked.includes("@") ? (
          <p className="ax-caption text-muted-foreground">{t("Choose a person or type their address.")}</p>
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
              <div className="space-y-ax-4">
                <p className="text-[13px] text-foreground">
                  {data.person
                    ? String((data.person as { display_name?: string }).display_name || data.email)
                    : data.email}
                </p>
                {data.next_actions.length > 0 ? (
                  <ul className="space-y-2">
                    {data.next_actions.map((a, i) => (
                      <li key={i} className="rounded-xl border border-border p-ax-3">
                        <p className="text-[13px] font-semibold text-foreground">{t(a.action)}</p>
                        <p className="ax-caption text-muted-foreground">{a.why}</p>
                        <a href={a.href} className="ax-caption font-semibold underline">
                          {t("Open")}
                        </a>
                      </li>
                    ))}
                  </ul>
                ) : null}
                <div>
                  <h3 className="ax-caption mb-2 font-bold uppercase text-muted-foreground">{t("Pipeline")}</h3>
                  {data.deals.length === 0 ? (
                    <p className="ax-caption text-muted-foreground">{t("No deal on this address yet.")}</p>
                  ) : (
                    <ul className="space-y-1">
                      {data.deals.map((d) => (
                        <li key={d.id} className="flex justify-between text-[13px]">
                          <span>{d.title}</span>
                          <span>{money(d.value, d.currency)}</span>
                        </li>
                      ))}
                    </ul>
                  )}
                </div>
                <div>
                  <h3 className="ax-caption mb-2 font-bold uppercase text-muted-foreground">{t("Work")}</h3>
                  {data.tasks.length === 0 ? (
                    <p className="ax-caption text-muted-foreground">{t("No work object linked yet.")}</p>
                  ) : (
                    <ul className="space-y-1">
                      {data.tasks.map((task) => (
                        <li key={task.id} className="text-[13px]">
                          {task.title} · {task.status}
                          {task.due_at ? ` · ${task.due_at}` : ""}
                        </li>
                      ))}
                    </ul>
                  )}
                </div>
                <div>
                  <h3 className="ax-caption mb-2 font-bold uppercase text-muted-foreground">{t("Timeline")}</h3>
                  {data.timeline.length === 0 ? (
                    <p className="ax-caption text-muted-foreground">{t("No mail on record for this address.")}</p>
                  ) : (
                    <ol className="space-y-2">
                      {data.timeline.map((e, i) => (
                        <li key={`${e.at}-${i}`}>
                          <a href={e.href} className="text-[13px] font-semibold text-foreground">
                            {e.title}
                          </a>
                          <p className="ax-caption text-muted-foreground">
                            {e.kind} · {relativeTime(e.at)}
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
  );
}
