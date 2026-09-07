import { AlertTriangle, BellRing, CalendarClock, History, UserCog, XCircle } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import {
  PROMISE_LABEL,
  PROMISE_TONE,
  type PromiseItem,
  usePromiseBoard,
  usePromiseHistory,
  usePromiseKeep,
  usePromiseRecover,
} from "@/lib/promise-engine";

/**
 * PHASE 23 — PROMISE RECOVERY ENGINE.
 * Jab wada toot raha ho: remind karo, deadline badlo (wajah ke saath),
 * owner badlo, downstream asar likho, ya wada band karo. Engine khud kuch
 * nahi karti — har action insaan ka hai aur poora ledger append-only hai.
 * "Kept" bina evidence namumkin: server hi mana kar deta hai.
 */
export function PromiseRecovery() {
  const board = usePromiseBoard();
  const recover = usePromiseRecover();
  const keep = usePromiseKeep();
  const [openHistory, setOpenHistory] = useState<string | null>(null);

  const items = board.data?.items ?? [];
  const summary = board.data?.summary ?? {};
  const canReassign = board.data?.reassign?.allowed ?? false;

  const run = (
    input: Parameters<typeof recover.mutate>[0],
    okTitle: string,
    okBody: (r: { body?: string; to?: string | null }) => string,
  ) =>
    recover.mutate(input, {
      onSuccess: (r) =>
        r.ok
          ? notify.done(okTitle, okBody(r))
          : notify.failed("Not saved", { description: r.message ?? r.error ?? "Try again." }),
      onError: (e) => notify.failed("Not saved", { description: e.message }),
    });

  const remind = (item: PromiseItem) => {
    const reason = window.prompt("Reminder note (optional) — it goes into the conversation:") ?? "";
    run(
      { item_id: item.id, action: "remind", reason: reason.trim() || undefined },
      "Reminder sent",
      (r) => r.body ?? "The conversation now carries the reminder.",
    );
  };

  const changeDeadline = (item: PromiseItem) => {
    const when = window.prompt("New deadline (YYYY-MM-DD HH:MM):", "");
    if (!when?.trim()) return;
    const parsed = new Date(when.trim().replace(" ", "T"));
    if (Number.isNaN(parsed.getTime())) {
      notify.failed("Date not understood", { description: "Use YYYY-MM-DD HH:MM." });
      return;
    }
    const reason = window.prompt("Why is the deadline moving? (at least 8 characters)") ?? "";
    if (reason.trim().length < 8) {
      notify.failed("Reason required", {
        description: "A moved deadline is a record. Write why in at least 8 characters.",
      });
      return;
    }
    run(
      {
        item_id: item.id,
        action: "deadline_change",
        new_due_at: parsed.toISOString(),
        reason: reason.trim(),
      },
      "Deadline moved on the record",
      () => "The original promise date stays visible for ever.",
    );
  };

  const reassign = (item: PromiseItem) => {
    const owner = window.prompt("New owner — paste their user id:") ?? "";
    if (!owner.trim()) return;
    const reason = window.prompt("Why the handover? (at least 8 characters)") ?? "";
    if (reason.trim().length < 8) {
      notify.failed("Reason required", { description: "Write at least 8 characters." });
      return;
    }
    run(
      { item_id: item.id, action: "reassign", new_owner_id: owner.trim(), reason: reason.trim() },
      "Owner handed over",
      () => "The first owner stays on the record.",
    );
  };

  const setImpact = (item: PromiseItem) => {
    const impact =
      window.prompt("What breaks downstream if this slips?", item.downstream_impact ?? "") ?? "";
    if (!impact.trim()) return;
    run({ item_id: item.id, action: "impact_set", downstream_impact: impact.trim() }, "Impact recorded", () => impact.trim());
  };

  const cancel = (item: PromiseItem) => {
    const reason = window.prompt("Why is this promise being dropped? (at least 8 characters)") ?? "";
    if (reason.trim().length < 8) {
      notify.failed("Reason required", { description: "Write at least 8 characters." });
      return;
    }
    run(
      { item_id: item.id, action: "cancelled", reason: reason.trim() },
      "Promise closed as dropped",
      () => "It stays in the history with the reason.",
    );
  };

  const markKept = (item: PromiseItem) => {
    const ref = window.prompt("Proof it was kept — a link, a file id, or a short note:") ?? "";
    if (!ref.trim()) return;
    keep.mutate(
      {
        item_id: item.id,
        evidence: { kind: ref.startsWith("http") ? "link" : "note", ref: ref.trim() },
      },
      {
        onSuccess: (r) =>
          r.ok
            ? notify.done("Kept, with proof", `${r.evidence_count} piece(s) of evidence on file.`)
            : notify.failed("Not closed", { description: r.message ?? r.error ?? "Try again." }),
        onError: (e) => notify.failed("Not closed", { description: e.message }),
      },
    );
  };

  if (board.isPending) {
    return <p className="ax-caption text-muted-foreground">Reading the promise ledger…</p>;
  }
  if (board.error) {
    return <p className="ax-caption text-amber-400">Ledger didn&apos;t load: {board.error.message}</p>;
  }
  if (board.data && !board.data.plan.allowed) {
    return (
      <p className="ax-caption rounded-xl border border-border px-ax-3 py-ax-3 text-muted-foreground">
        Promise recovery is part of Business, Business Pro and the AI plans. Your plan is{" "}
        {board.data.plan.plan}.
      </p>
    );
  }

  return (
    <section className="space-y-ax-3">
      <header className="flex flex-wrap items-center gap-ax-3">
        <h3 className="ax-label text-foreground">
          <AlertTriangle className="mr-1.5 inline size-3.5" aria-hidden="true" />
          Promise recovery
        </h3>
        <span className="ax-caption text-steel">
          {summary.overdue ?? 0} overdue · {summary.due_soon ?? 0} due soon · {summary.slipped ?? 0}{" "}
          moved · {summary.kept ?? 0} kept ({summary.kept_late ?? 0} late)
        </span>
      </header>

      {items.length === 0 ? (
        <p className="ax-caption text-muted-foreground">
          No promises on the board. They appear the moment a conversation makes one.
        </p>
      ) : (
        <ul className="space-y-ax-3">
          {items.map((item) => (
            <li key={item.id} className="ax-plane rounded-2xl p-ax-4">
              <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                <span className="font-semibold text-foreground">{item.title}</span>
                <span className={PROMISE_TONE[item.promise_state]}>
                  {PROMISE_LABEL[item.promise_state]}
                </span>
                {item.due_at && (
                  <span className="text-muted-foreground">due {relativeTime(item.due_at)}</span>
                )}
                {item.deadline_changes > 0 && item.original_due_at && (
                  <span className="text-amber-400">
                    moved {item.deadline_changes}× · first promised{" "}
                    {new Date(item.original_due_at).toLocaleDateString()}
                  </span>
                )}
                <span className="ml-auto text-steel">
                  {item.reminders_sent} reminder(s) · {item.evidence_count} evidence
                </span>
              </div>

              {item.downstream_impact && (
                <p className="ax-caption mt-ax-2 text-muted-foreground">
                  If it slips: {item.downstream_impact}
                </p>
              )}

              <div className="mt-ax-3 flex flex-wrap gap-2">
                {item.state !== "done" && item.state !== "cancelled" && (
                  <>
                    <Button size="sm" variant="ghost" disabled={recover.isPending} onClick={() => remind(item)}>
                      <BellRing className="size-3.5" />
                      Remind
                    </Button>
                    <Button
                      size="sm"
                      variant="ghost"
                      disabled={recover.isPending}
                      onClick={() => changeDeadline(item)}
                    >
                      <CalendarClock className="size-3.5" />
                      Move deadline
                    </Button>
                    {canReassign && (
                      <Button
                        size="sm"
                        variant="ghost"
                        disabled={recover.isPending}
                        onClick={() => reassign(item)}
                      >
                        <UserCog className="size-3.5" />
                        Hand over
                      </Button>
                    )}
                    <Button size="sm" variant="ghost" disabled={recover.isPending} onClick={() => setImpact(item)}>
                      Impact
                    </Button>
                    <Button size="sm" disabled={keep.isPending} onClick={() => markKept(item)}>
                      Kept — with proof
                    </Button>
                    <Button size="sm" variant="ghost" disabled={recover.isPending} onClick={() => cancel(item)}>
                      <XCircle className="size-3.5" />
                      Dropped
                    </Button>
                  </>
                )}
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => setOpenHistory(openHistory === item.id ? null : item.id)}
                >
                  <History className="size-3.5" />
                  {openHistory === item.id ? "Hide history" : "History"}
                </Button>
              </div>

              {openHistory === item.id && <PromiseTrail itemId={item.id} />}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function PromiseTrail({ itemId }: { itemId: string }) {
  const history = usePromiseHistory(itemId);
  if (history.isPending) {
    return <p className="ax-caption mt-ax-3 text-muted-foreground">Opening the trail…</p>;
  }
  if (history.error) {
    return <p className="ax-caption mt-ax-3 text-amber-400">{history.error.message}</p>;
  }
  const data = history.data;
  if (!data) return null;

  return (
    <div className="mt-ax-3 space-y-ax-2 rounded-xl border border-border p-ax-3">
      <p className="ax-caption text-steel">
        First promised{" "}
        {data.item.original_due_at
          ? new Date(data.item.original_due_at).toLocaleString()
          : "with no date"}{" "}
        · append-only record
      </p>
      {data.log.length === 0 ? (
        <p className="ax-caption text-muted-foreground">Nothing has changed since it was made.</p>
      ) : (
        <ol className="space-y-1">
          {data.log.map((row, i) => (
            <li key={`${row.at}-${i}`} className="ax-caption text-muted-foreground">
              <span className="font-semibold text-foreground">{row.action.replace(/_/g, " ")}</span>{" "}
              {new Date(row.at).toLocaleString()}
              {row.reason ? ` — ${row.reason}` : ""}
            </li>
          ))}
        </ol>
      )}
      {data.evidence.length > 0 && (
        <p className="ax-caption text-muted-foreground">
          Evidence: {data.evidence.map((e) => `${e.kind}:${e.ref}`).join(" · ")}
        </p>
      )}
    </div>
  );
}
