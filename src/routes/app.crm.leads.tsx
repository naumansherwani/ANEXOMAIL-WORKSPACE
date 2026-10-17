import { createFileRoute } from "@tanstack/react-router";
import { Check, MailPlus, UserPlus, Users } from "lucide-react";
import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

import { CaptureLead } from "@/components/app/crm/CrmCapture";
import { Chip, ScoreBar, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { useLocale } from "@/lib/i18n";
import {
  useConvertLead,
  useCrmLeadSuggestions,
  useCrmLeads,
  useCreateLead,
  useMoveLeadsToPeople,
  type Lead,
  type SuggestedLead,
} from "@/lib/crm";
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

const STATES: (Lead["state"] | "all")[] = ["new", "working", "converted", "moved", "dropped", "all"];

function LeadsPage() {
  const { t } = useLocale();
  const [state, setState] = useState<Lead["state"] | "all">("new");
  const leads = useCrmLeads(state);
  const convert = useConvertLead();

  return (
    <div className="mx-auto w-full max-w-6xl px-ax-4 py-ax-5 md:px-ax-5 md:py-ax-6">
      <SectionTitle
        title={t("Leads")}
        hint={t("Your book of people who are not a deal yet. Capture one here — scores appear only when mail behaviour exists.")}
      />
      <CaptureLead />
      <ImportedLeadsBar />
      <SuggestedFromMail />

      <div className="mb-ax-4 flex flex-wrap gap-2">
        {STATES.map((s) => (
          <button
            key={s}
            type="button"
            onClick={() => setState(s)}
            className={cn(
              "ax-press ax-hit rounded-full border px-3 py-1 text-[12px] font-semibold capitalize transition-colors",
              state === s
                ? "border-foreground bg-secondary text-foreground"
                : "border-border text-muted-foreground hover:text-foreground",
            )}
          >
            {s === "moved" ? t("in People") : t(s)}
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
                    <div className="min-w-0 flex-1 basis-full sm:basis-0">
                      <p className="break-words text-[13px] font-semibold text-foreground sm:truncate">
                        {l.display_name ?? l.email}
                      </p>
                      <p className="ax-caption break-words text-muted-foreground sm:truncate">
                        {l.email}
                        {l.company ? ` · ${l.company}` : ""}
                        {l.source ? ` · via ${l.source}` : ""}
                      </p>
                    </div>
                    {l.score !== null && <ScoreBar value={l.score} />}
                    <Chip tone={l.state === "converted" ? "good" : "quiet"}>
                      {l.state === "moved" ? t("in People") : l.state}
                    </Chip>
                    <span className="ax-caption text-muted-foreground">
                      {l.last_touch_at ? relativeTime(l.last_touch_at) : t("Never touched")}
                    </span>
                    {l.state !== "converted" && l.state !== "moved" && (
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

/**
 * Leads that arrived from an imported contacts file and are still new. One bulk question — "Move these to People?" —
 * so a switcher with 800 contacts is not left converting them one by one. Asks first, moves only on "Yes".
 */
function ImportedLeadsBar() {
  const { t } = useLocale();
  const qc = useQueryClient();
  const newLeads = useCrmLeads("new");
  const move = useMoveLeadsToPeople();
  const [asking, setAsking] = useState(false);
  const [hidden, setHidden] = useState(false);
  const n = (newLeads.data?.leads ?? []).filter((l: Lead) => l.source === "import").length;
  if (n === 0 || hidden) return null;

  return (
    <section className="mb-ax-4 rounded-2xl border border-cyan-accent/30 bg-card/60 p-ax-4" aria-label={t("Imported leads")}>
      <div className="flex flex-wrap items-center gap-2">
        <Users className="size-4 shrink-0 text-cyan-accent" aria-hidden="true" />
        <p className="min-w-0 flex-1 basis-full text-[13px] font-bold text-foreground sm:basis-0">
          {n} {t(n === 1 ? "imported lead is waiting" : "imported leads are waiting")}
        </p>
        {!asking ? (
          <Button size="sm" variant="secondary" onClick={() => setAsking(true)}>
            <Users className="size-4" aria-hidden="true" /> {t("Move to People?")}
          </Button>
        ) : null}
      </div>
      {asking && (
        <div className="mt-2">
          <p className="ax-caption text-muted-foreground">
            {t("People is for the ones you already know. Everyone in this list moves; nothing is emailed.")}
          </p>
          <div className="mt-2 flex flex-wrap gap-2">
            <Button
              size="sm"
              disabled={move.isPending}
              onClick={() =>
                move.mutate(
                  { source: "import" },
                  {
                    onSuccess: (r) => {
                      void qc.invalidateQueries({ queryKey: ["contacts"] });
                      void qc.invalidateQueries({ queryKey: ["companies"] });
                      notify.done(t("Moved to People"), `${r.moved}`);
                      setAsking(false);
                    },
                    onError: (e) => notify.failed(t("Could not move them"), { description: e.message }),
                  },
                )
              }
            >
              <Check className="size-4" aria-hidden="true" /> {t("Yes, move")} {n}
            </Button>
            <Button size="sm" variant="outline" disabled={move.isPending} onClick={() => (setAsking(false), setHidden(true))}>
              {t("Not now")}
            </Button>
          </div>
        </div>
      )}
    </section>
  );
}

/** Real people who wrote you in the last 30 days. Accept puts them on the book. */
function SuggestedFromMail() {
  const { t } = useLocale();
  const sug = useCrmLeadSuggestions();
  const accept = useCreateLead();
  const [done, setDone] = useState<Set<string>>(new Set());

  const list = (sug.data?.suggestions ?? []).filter((s) => !done.has(s.email));
  if (list.length === 0) return null;

  return (
    <section className="mb-ax-4 rounded-2xl border border-cyan-accent/30 bg-card/60 p-ax-4">
      <div className="mb-3 flex flex-wrap items-center gap-2">
        <MailPlus className="size-4 text-cyan-accent" aria-hidden="true" />
        <p className="text-[13px] font-bold text-foreground">{t("From your mail — last 30 days")}</p>
        <Chip tone="quiet">{list.length}</Chip>
        <p className="ax-caption basis-full text-muted-foreground sm:ml-auto sm:basis-auto">
          {t("Real senders. Accept to put them on the book.")}
        </p>
      </div>
      <ul className="grid grid-cols-1 gap-1.5 sm:grid-cols-2 lg:grid-cols-3">
        {list.slice(0, 9).map((s: SuggestedLead) => (
          <li
            key={s.email}
            className="flex items-center gap-2 rounded-xl border border-border/70 bg-card/80 px-2.5 py-2"
          >
            <div className="min-w-0 flex-1">
              <p className="truncate text-[12.5px] font-semibold text-foreground">{s.email}</p>
              <p className="ax-caption text-muted-foreground">
                {s.message_count} {t("mail")} · {relativeTime(s.last_mail_at)}
              </p>
            </div>
            <Button
              size="sm"
              variant="secondary"
              className="ax-press ax-hit h-7 shrink-0 px-2 text-[11px]"
              disabled={accept.isPending}
              onClick={() =>
                accept.mutate(
                  { email: s.email },
                  {
                    onSuccess: () => {
                      setDone((d) => new Set(d).add(s.email));
                      notify.done(t("On the book"), s.email);
                    },
                    onError: (e) =>
                      notify.failed(t("Could not save lead"), { description: e.message }),
                  },
                )
              }
            >
              <Check className="size-3.5" aria-hidden="true" /> {t("Accept")}
            </Button>
          </li>
        ))}
      </ul>
    </section>
  );
}

