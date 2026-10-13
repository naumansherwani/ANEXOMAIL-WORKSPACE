import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";

import { Chip, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { usePromiseDecision } from "@/lib/calendar";
import {
  useCrmPromiseTask,
  useCrmPromisesBoard,
  type CrmPromisePhase,
  type CrmPromiseRow,
  type CrmPromiseSide,
} from "@/lib/crm";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/crm/promises")({
  head: () => ({
    meta: [
      { title: "Promises - ANEXOMAIL CRM" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: PromisesPage,
});

const PHASE_LABEL: Record<CrmPromisePhase, string> = {
  suggested: "To confirm",
  pending: "Pending",
  kept: "Kept",
  late: "Kept late",
  broken: "Broken",
};

const PHASE_STYLE: Record<CrmPromisePhase, string> = {
  suggested: "bg-secondary text-foreground",
  pending: "bg-secondary text-foreground",
  kept: "bg-emerald-500/15 text-emerald-500",
  late: "bg-amber-500/15 text-amber-500",
  broken: "bg-rose-500/15 text-rose-500",
};

function PromiseCard({ p, onChanged }: { p: CrmPromiseRow; onChanged: () => void }) {
  const { t } = useLocale();
  const decide = usePromiseDecision();
  const task = useCrmPromiseTask();
  const [date, setDate] = useState("");
  const busy = decide.isPending || task.isPending;
  const person = p.side === "mine" ? p.promised_to : p.promised_by;

  const decideNow = (decision: "commit" | "dismiss") =>
    decide.mutate(
      { id: p.id, decision },
      {
        onSuccess: () => {
          notify.done(
            decision === "commit" ? t("Tracked") : t("Dismissed"),
            decision === "commit" ? t("It is on your task board now.") : t("It will not be suggested again."),
          );
          onChanged();
        },
        onError: (e) => notify.failed(t("Could not save"), { description: e.message }),
      },
    );

  const markKept = () => {
    if (!p.task_id) return;
    task.mutate(
      { task_id: p.task_id, status: "done" },
      {
        onSuccess: () => notify.done(t("Marked kept"), p.title),
        onError: (e) => notify.failed(t("Could not save"), { description: e.message }),
      },
    );
  };

  const moveDate = () => {
    if (!p.task_id || !date) return;
    task.mutate(
      { task_id: p.task_id, due_at: new Date(`${date}T17:00:00`).toISOString() },
      {
        onSuccess: () => {
          setDate("");
          notify.done(t("Date moved"), p.title);
        },
        onError: (e) => notify.failed(t("Could not save"), { description: e.message }),
      },
    );
  };

  return (
    <li className="rounded-xl border border-border p-ax-3">
      <div className="flex flex-wrap items-center gap-2">
        <span className={cn("ax-caption rounded-full px-2 py-0.5 font-semibold", PHASE_STYLE[p.phase])}>
          {t(PHASE_LABEL[p.phase])}
        </span>
        <Chip>{p.side === "mine" ? t("I promised") : t("They promised")}</Chip>
        <span className="ax-caption ms-auto text-muted-foreground">
          {p.due_at ? `${t("Due")} ${new Date(p.due_at).toLocaleDateString()}` : t("No date")}
        </span>
      </div>
      <p className="mt-ax-2 text-[13px] font-semibold text-foreground">{p.title}</p>
      <p className="ax-caption mt-0.5 flex flex-wrap items-center gap-x-2 text-muted-foreground">
        {person ? (
          <a
            href={`/app/crm/relationships?email=${encodeURIComponent(person)}`}
            className="underline underline-offset-4"
          >
            {person}
          </a>
        ) : null}
        {p.thread_id ? (
          <a
            href={`/app/mail/inbox/${p.thread_id}`}
            className="underline underline-offset-4"
          >
            {t("Open thread")}
          </a>
        ) : null}
        <span>{relativeTime(p.detected_at)}</span>
      </p>
      <div className="mt-ax-3 flex flex-wrap items-center gap-2">
        {p.phase === "suggested" ? (
          <>
            <button
              type="button"
              disabled={busy}
              onClick={() => decideNow("commit")}
              className="ax-press rounded-lg bg-primary px-3 py-1.5 text-[12px] font-semibold text-primary-foreground"
            >
              {p.side === "mine" ? t("Make it a task") : t("Track it")}
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => decideNow("dismiss")}
              className="ax-press rounded-lg border border-border px-3 py-1.5 text-[12px] font-semibold text-muted-foreground"
            >
              {t("Not a promise")}
            </button>
          </>
        ) : null}
        {(p.phase === "pending" || p.phase === "broken") && p.task_id ? (
          <>
            <button
              type="button"
              disabled={busy}
              onClick={markKept}
              className="ax-press rounded-lg bg-primary px-3 py-1.5 text-[12px] font-semibold text-primary-foreground"
            >
              {t("Mark kept")}
            </button>
            <input
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
              className="rounded-lg border border-border bg-transparent px-2 py-1 text-[12px] text-foreground outline-none"
            />
            <button
              type="button"
              disabled={busy || !date}
              onClick={moveDate}
              className="ax-press rounded-lg border border-border px-3 py-1.5 text-[12px] font-semibold text-foreground"
            >
              {t("Move date")}
            </button>
          </>
        ) : null}
        {p.completed_at ? (
          <span className="ax-caption text-muted-foreground">
            {t("Finished")} {relativeTime(p.completed_at)}
          </span>
        ) : null}
      </div>
    </li>
  );
}

function PromisesPage() {
  const { t } = useLocale();
  const [side, setSide] = useState<CrmPromiseSide | "all">("all");
  const query = useCrmPromisesBoard(side);
  const SIDES: (CrmPromiseSide | "all")[] = ["all", "mine", "theirs"];
  const SIDE_LABEL: Record<CrmPromiseSide | "all", string> = {
    all: "All",
    mine: "My promises",
    theirs: "Their promises",
  };

  return (
    <div className="mx-auto w-full max-w-4xl px-ax-5 py-ax-6">
      <SectionTitle
        title={t("Promises")}
        hint={t("What you said you would do, and what they said. Kept, late or broken, from real dates.")}
      />

      <div className="mb-4 flex flex-wrap gap-1.5">
        {SIDES.map((s) => (
          <button
            key={s}
            type="button"
            onClick={() => setSide(s)}
            className={cn(
              "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold transition-colors",
              side === s
                ? "border-foreground/50 bg-secondary text-foreground"
                : "border-border text-muted-foreground",
            )}
          >
            {t(SIDE_LABEL[s])}
          </button>
        ))}
      </div>

      <CardBody
        query={{
          data: query.data,
          isPending: query.isPending,
          error: query.error ?? null,
          refetch: () => void query.refetch(),
        }}
        endpoint="/rpc/crm.promises.board"
        skeleton={<StatSkeleton rows={5} />}
      >
        {(data) =>
          data.promises.length === 0 ? (
            <p className="ax-caption text-muted-foreground">
              {t("No promises found in the last 30 days. When a mail says it will send something by a day, it appears here for you to confirm.")}
            </p>
          ) : (
            <ul className="space-y-ax-2">
              {data.promises.map((p) => (
                <PromiseCard key={p.id} p={p} onChanged={() => void query.refetch()} />
              ))}
            </ul>
          )
        }
      </CardBody>
    </div>
  );
}
