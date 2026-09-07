import { Eye, Flag, Gavel, Loader2 } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  REPORT_REASONS,
  nextReportState,
  useAdvanceReport,
  useReportSubject,
  useRevealEvidence,
  useSafetyQueue,
  useSafetyStanding,
  type ReportReason,
  type SafetyReport,
} from "@/lib/chat-safety";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

/**
 * PHASE 21 — Safety reporting.
 * Report banate waqt message ka content SEAL ho jata hai: reviewer ko default
 * sirf metadata milta hai, aur kholne par wajah ke saath audit row banti hai.
 */
export function ReportForm({
  subjectKind = "message",
  subjectId = "",
}: {
  subjectKind?: SafetyReport["subject_kind"];
  subjectId?: string;
}) {
  const [kind, setKind] = useState<SafetyReport["subject_kind"]>(subjectKind);
  const [subject, setSubject] = useState(subjectId);
  const [reason, setReason] = useState<ReportReason>("harassment");
  const [note, setNote] = useState("");
  const report = useReportSubject();

  return (
    <form
      className="ax-plane space-y-ax-3 rounded-2xl p-ax-4"
      onSubmit={(e) => {
        e.preventDefault();
        if (!subject.trim()) return;
        report.mutate(
          { subject_kind: kind, subject_id: subject.trim(), reason, note: note.trim() || undefined },
          {
            onSuccess: (r) =>
              r.ok
                ? (setSubject(""),
                  setNote(""),
                  notify.done("Report filed", r.notice ?? "A reviewer will pick it up."))
                : notify.failed("Report not filed", { description: r.error ?? "Try again." }),
            onError: (e2) => notify.failed("Report not filed", { description: e2.message }),
          },
        );
      }}
    >
      <h3 className="ax-label text-foreground">
        <Flag className="mr-1.5 inline size-3.5" aria-hidden="true" />
        Report something
      </h3>
      <div className="flex flex-wrap gap-2">
        {(["message", "person", "file", "conversation"] as const).map((k) => (
          <button
            key={k}
            type="button"
            onClick={() => setKind(k)}
            className={`ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold ${
              kind === k
                ? "border-cyan-accent/50 bg-secondary text-foreground"
                : "border-border text-muted-foreground"
            }`}
          >
            {k}
          </button>
        ))}
      </div>
      <Input
        value={subject}
        onChange={(e) => setSubject(e.target.value)}
        placeholder={`ID of the ${kind} you are reporting`}
        className="h-8 text-xs"
      />
      <select
        value={reason}
        onChange={(e) => setReason(e.target.value as ReportReason)}
        aria-label="Reason"
        className="w-full rounded-xl border border-border bg-transparent px-3 py-2 text-xs text-foreground"
      >
        {REPORT_REASONS.map((r) => (
          <option key={r.id} value={r.id}>
            {r.label}
          </option>
        ))}
      </select>
      <Input
        value={note}
        onChange={(e) => setNote(e.target.value)}
        placeholder="What happened? (optional)"
        className="h-8 text-xs"
      />
      <Button size="sm" type="submit" disabled={!subject.trim() || report.isPending}>
        {report.isPending && <Loader2 className="size-3.5 animate-spin" />}
        File report
      </Button>
      <p className="ax-caption text-steel">
        Message text is sealed. Reviewers see who, when and why — not the words — unless they
        record a reason to open it.
      </p>
    </form>
  );
}

export function MyStanding() {
  const q = useSafetyStanding();
  if (q.isPending) return <p className="ax-caption text-muted-foreground">Loading…</p>;
  if (q.error)
    return <p className="ax-caption text-amber-400">Standing didn&apos;t load: {q.error.message}</p>;
  const d = q.data!;
  return (
    <div className="ax-plane rounded-2xl p-ax-4 text-[12px]">
      <h3 className="ax-label text-foreground">Your standing</h3>
      <p className="ax-caption mt-1 text-muted-foreground">
        {d.reports_filed} report(s) filed · {d.open_reports} still open
      </p>
      {d.enforcement.length === 0 ? (
        <p className="ax-caption mt-1 text-emerald-400">No action has ever been taken on your account.</p>
      ) : (
        <ul className="ax-caption mt-ax-3 space-y-1 text-amber-400">
          {d.enforcement.map((e, i) => (
            <li key={i}>
              {e.action} — {e.reason} · {relativeTime(e.at)}
              {e.until ? ` · until ${new Date(e.until).toLocaleDateString()}` : ""}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/** PHASE 21 — review queue: new → under_review → action → resolved, koi step kood nahi sakta. */
export function SafetyReviewQueue() {
  const [filter, setFilter] = useState<SafetyReport["state"] | "all">("new");
  const q = useSafetyQueue(filter);
  const advance = useAdvanceReport();
  const reveal = useRevealEvidence();
  const [opened, setOpened] = useState<Record<string, string>>({});

  if (q.isPending) return <p className="ax-caption text-muted-foreground">Loading queue…</p>;
  if (q.error) return <p className="ax-caption text-amber-400">{q.error.message}</p>;
  if (q.data && q.data.ok === false)
    return (
      <p className="ax-caption text-muted-foreground">
        This queue is for Business Pro, AI Executive and founder accounts.
      </p>
    );

  const reports = q.data?.reports ?? [];

  return (
    <section className="space-y-ax-3">
      <div className="flex flex-wrap gap-2">
        {(["new", "under_review", "action", "resolved", "all"] as const).map((s) => (
          <button
            key={s}
            type="button"
            onClick={() => setFilter(s)}
            className={`ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold ${
              filter === s
                ? "border-cyan-accent/50 bg-secondary text-foreground"
                : "border-border text-muted-foreground"
            }`}
          >
            {s.replace("_", " ")}
            {q.data?.counts?.[s] ? ` · ${q.data.counts[s]}` : ""}
          </button>
        ))}
      </div>

      {reports.length === 0 ? (
        <p className="ax-caption text-muted-foreground">Nothing in this state.</p>
      ) : (
        <ul className="space-y-ax-3">
          {reports.map((r) => {
            const next = nextReportState(r.state);
            return (
              <li key={r.id} className="ax-plane rounded-2xl p-ax-4">
                <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                  <span className="font-semibold text-foreground">
                    {r.subject_kind} · {r.reason.replace(/_/g, " ")}
                  </span>
                  <span className={r.severity >= 4 ? "text-red-400" : "text-amber-400"}>
                    severity {r.severity}
                  </span>
                  <span className="text-muted-foreground">{r.state.replace("_", " ")}</span>
                  <span className="ml-auto text-steel">{relativeTime(r.created_at)}</span>
                </div>
                <p className="ax-caption mt-1 text-muted-foreground">
                  reporter {r.reporter}… → subject {r.subject}…
                  {r.note ? ` · “${r.note}”` : ""}
                </p>
                <p className="ax-caption mt-1 text-steel">
                  {r.evidence_sealed
                    ? `evidence sealed · hash ${r.evidence_hash?.slice(0, 16)}…`
                    : "no message content attached"}
                </p>

                {opened[r.id] && (
                  <p className="ax-caption mt-ax-3 rounded-xl border border-border p-ax-3 text-foreground">
                    {opened[r.id]}
                  </p>
                )}

                <div className="mt-ax-3 flex flex-wrap gap-2">
                  {next && (
                    <Button
                      size="sm"
                      variant="secondary"
                      disabled={advance.isPending}
                      onClick={() =>
                        advance.mutate(
                          {
                            report_id: r.id,
                            to_state: next,
                            action: next === "action" ? "warned" : undefined,
                          },
                          {
                            onSuccess: () => notify.done("Moved forward", `Now ${next.replace("_", " ")}.`),
                            onError: (e) =>
                              notify.failed("Could not move this report", { description: e.message }),
                          },
                        )
                      }
                    >
                      <Gavel className="size-3.5" />
                      Move to {next.replace("_", " ")}
                    </Button>
                  )}
                  {r.evidence_sealed && r.state !== "new" && !opened[r.id] && (
                    <Button
                      size="sm"
                      variant="ghost"
                      disabled={reveal.isPending}
                      onClick={() => {
                        const why = window.prompt(
                          "Why do you need to read the reported content? (logged, min 12 characters)",
                        );
                        if (!why || why.trim().length < 12) return;
                        reveal.mutate(
                          { report_id: r.id, justification: why.trim() },
                          {
                            onSuccess: (res) =>
                              setOpened((o) => ({
                                ...o,
                                [r.id]: res.evidence ?? "Nothing sealed for this report.",
                              })),
                            onError: (e) =>
                              notify.failed("Could not open the evidence", { description: e.message }),
                          },
                        );
                      }}
                    >
                      <Eye className="size-3.5" />
                      Open sealed evidence
                    </Button>
                  )}
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
