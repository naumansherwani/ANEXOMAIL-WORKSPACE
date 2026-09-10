import { createFileRoute } from "@tanstack/react-router";
import { UserPlus } from "lucide-react";
import { useState } from "react";

import { CaptureLead } from "@/components/app/crm/CrmCapture";
import { Chip, ScoreBar, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { useLocale } from "@/lib/i18n";
import { useConvertLead, useCrmLeads, type Lead } from "@/lib/crm";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/crm/leads")({
  head: () => ({
    meta: [
      { title: "Leads — ANEXOMAIL CRM" },
      {
        name: "description",
        content: "Capture a person, work them, convert to a deal. Scores stay empty until mail behaviour exists.",
      },
      { property: "og:title", content: "Leads — ANEXOMAIL CRM" },
      { property: "og:description", content: "Leads scored from real email behaviour." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: LeadsPage,
});

const STATES: (Lead["state"] | "all")[] = ["new", "working", "converted", "dropped", "all"];

function LeadsPage() {
  const { t } = useLocale();
  const [state, setState] = useState<Lead["state"] | "all">("new");
  const leads = useCrmLeads(state);
  const convert = useConvertLead();

  return (
    <div className="mx-auto w-full max-w-6xl px-ax-5 py-ax-6">
      <SectionTitle
        title={t("Leads")}
        hint={t("Your book of people who are not a deal yet. Capture one here — scores appear only when mail behaviour exists.")}
      />
      <CaptureLead />

      <div className="mb-ax-4 flex flex-wrap gap-1">
        {STATES.map((s) => (
          <button
            key={s}
            type="button"
            onClick={() => setState(s)}
            className={cn(
              "ax-press rounded-full border px-3 py-1 text-[12px] font-semibold capitalize transition-colors",
              state === s
                ? "border-foreground bg-secondary text-foreground"
                : "border-border text-muted-foreground hover:text-foreground",
            )}
          >
            {t(s)}
          </button>
        ))}
      </div>

      <CardBody
        query={{
          data: leads.data,
          isPending: leads.isPending,
          error: leads.error ?? null,
          refetch: () => void leads.refetch(),
        }}
        endpoint="/api/crm/leads"
        skeleton={<StatSkeleton rows={6} />}
      >
        {(data) =>
          data.leads.length === 0 ? (
            <p className="ax-caption text-muted-foreground">
              {t("No leads in this state. Capture one above — we do not invent inbound people.")}
            </p>
          ) : (
            <ul className="space-y-ax-2">
              {data.leads.map((l) => (
                <li key={l.id} className="ax-plane rounded-2xl p-ax-4">
                  <div className="flex flex-wrap items-center gap-ax-3">
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-[13px] font-semibold text-foreground">
                        {l.display_name ?? l.email}
                      </p>
                      <p className="ax-caption truncate text-muted-foreground">
                        {l.email}
                        {l.company ? ` · ${l.company}` : ""}
                        {l.source ? ` · via ${l.source}` : ""}
                      </p>
                    </div>
                    {l.score !== null && <ScoreBar value={l.score} />}
                    <Chip tone={l.state === "converted" ? "good" : "quiet"}>{l.state}</Chip>
                    <span className="ax-caption text-muted-foreground">
                      {l.last_touch_at ? relativeTime(l.last_touch_at) : t("Never touched")}
                    </span>
                    {l.state !== "converted" && (
                      <Button
                        size="sm"
                        variant="secondary"
                        disabled={convert.isPending}
                        onClick={() =>
                          convert.mutate(
                            { id: l.id },
                            {
                              onSuccess: () => notify.done("Lead converted", "A deal was created."),
                              onError: (e) =>
                                notify.failed(
                                  e.isNotImplemented
                                    ? "Convert not wired yet"
                                    : "Could not convert",
                                  { description: e.message },
                                ),
                            },
                          )
                        }
                      >
                        <UserPlus className="size-4" aria-hidden="true" /> {t("Convert")}
                      </Button>
                    )}
                  </div>
                  {l.score_reason && (
                    <p className="ax-caption mt-1.5 text-muted-foreground">{l.score_reason}</p>
                  )}
                </li>
              ))}
            </ul>
          )
        }
      </CardBody>
    </div>
  );
}
