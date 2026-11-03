import {
  AlertTriangle,
  Fingerprint,
  Link2Off,
  ListTree,
  ShieldCheck,
  Stethoscope,
} from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import {
  HEALTH_LABEL,
  HEALTH_TONE,
  LENS_LABEL,
  type Collision,
  type CollisionAction,
  type ConversationHealth,
  type TimelineEvent,
  type TimelineLens,
  useCollisionAct,
  useCollisionScan,
  useConversationTimeline,
  useHealthBoard,
  useMessageProvenance,
} from "@/lib/chat-timeline";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

const clock = (iso: string) => new Date(iso).toISOString().slice(11, 16) + " UTC";

const day = (iso: string) => new Date(iso).toISOString().slice(0, 10);

const LENSES: TimelineLens[] = [
  "all",
  "outcome",
  "important",
  "messages",
  "files",
  "tasks",
  "promises",
  "decisions",
];

/**
 * PHASE 25/26/27 — one honest line through a conversation.
 *
 * The left column is every matter with a real state (on track · waiting ·
 * blocked · completed) plus the owner and the next date. The timeline puts what
 * was said next to what actually resulted, and every entry carries its own
 * record. Provenance shows who sent a message, the exact UTC time, who has it,
 * and whether the sealed copy still matches. Warnings only ever come from a
 * dependency a person recorded — nothing is guessed.
 */
export function ConversationTruth() {
  const board = useHealthBoard();
  const [selected, setSelected] = useState<string | null>(null);
  const [lens, setLens] = useState<TimelineLens>("all");
  const [proof, setProof] = useState<string | null>(null);

  const rows = board.data?.conversations ?? [];
  const current = selected ?? rows[0]?.conversation_id ?? null;
  const health = rows.find((r) => r.conversation_id === current) ?? null;

  const timeline = useConversationTimeline(current, lens);
  const collisions = useCollisionScan(current, !!board.data?.collision && !!current);

  if (board.data && !board.data.plan) {
    return (
      <section className="space-y-ax-3">
        <h2 className="ax-heading text-foreground">Conversation truth</h2>
        <p className="ax-caption text-muted-foreground">
          Conversation health, the outcome timeline and message provenance are part of Business and
          above.
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-ax-4">
      <header className="flex flex-wrap items-center gap-ax-3">
        <h2 className="ax-heading text-foreground">
          <Stethoscope className="mr-2 inline size-4" aria-hidden="true" />
          Conversation health &amp; outcome timeline
        </h2>
        <span className="ax-caption text-steel">{rows.length} matter(s)</span>
      </header>

      <p className="ax-caption text-muted-foreground">
        <ShieldCheck className="mr-1.5 inline size-3.5" aria-hidden="true" />
        Every entry below comes from a real record — a message, a file with its proof, a task, a
        promise or a decision. Nothing here is guessed, and what was said is kept separate from what
        actually happened.
      </p>

      {board.isPending ? (
        <p className="ax-caption text-muted-foreground">Reading your conversations…</p>
      ) : board.error ? (
        <p className="ax-caption text-amber-400">Didn&apos;t load: {board.error.message}</p>
      ) : rows.length === 0 ? (
        <p className="ax-caption text-muted-foreground">
          No conversations yet. Once people start talking, each one gets its own state, owner and
          timeline here.
        </p>
      ) : (
        <div className="grid gap-ax-4 lg:grid-cols-[18rem_1fr]">
          <ul className="space-y-ax-2">
            {rows.map((h) => (
              <li key={h.conversation_id}>
                <button
                  type="button"
                  onClick={() => {
                    setSelected(h.conversation_id);
                    setProof(null);
                  }}
                  className={cn(
                    "ax-press ax-plane w-full rounded-2xl p-ax-3 text-left text-[12px]",
                    current === h.conversation_id && "border-cyan-accent/50",
                  )}
                >
                  <p className="font-semibold text-foreground">{h.title}</p>
                  <p className={cn("ax-caption mt-1", HEALTH_TONE[h.state])}>
                    {HEALTH_LABEL[h.state]}
                    {h.owner ? ` · ${h.owner}` : ""}
                    {h.due_at ? ` · due ${relativeTime(h.due_at)}` : ""}
                  </p>
                  <p className="ax-caption mt-1 text-steel">
                    {h.open_items} open · {h.overdue_items} overdue · {h.blocked_items} blocked
                  </p>
                </button>
              </li>
            ))}
          </ul>

          <div className="space-y-ax-4">
            {health && <HealthReasons health={health} />}

            {board.data?.collision && (
              <Collisions
                items={(collisions.data?.collisions ?? []).filter((c) => c.state === "open")}
                loading={collisions.isPending}
              />
            )}

            <div className="flex flex-wrap items-center gap-1">
              {LENSES.map((l) => (
                <button
                  key={l}
                  type="button"
                  onClick={() => setLens(l)}
                  className={cn(
                    "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold",
                    lens === l
                      ? "border-cyan-accent/50 bg-secondary text-foreground"
                      : "border-border text-muted-foreground",
                  )}
                >
                  {LENS_LABEL[l]}
                </button>
              ))}
            </div>

            {timeline.isPending ? (
              <p className="ax-caption text-muted-foreground">Building the timeline…</p>
            ) : timeline.error ? (
              <p className="ax-caption text-amber-400">
                Timeline didn&apos;t load: {timeline.error.message}
              </p>
            ) : (timeline.data?.events ?? []).length === 0 ? (
              <p className="ax-caption text-muted-foreground">
                Nothing recorded under this view yet.
              </p>
            ) : (
              <ol className="space-y-ax-2">
                {(timeline.data?.events ?? []).map((e, i) => (
                  <TimelineRow
                    key={`${e.object_id}-${e.kind}-${e.at}-${i}`}
                    event={e}
                    showDay={i === 0 || day(e.at) !== day(timeline.data!.events[i - 1]!.at)}
                    proofOpen={proof === e.object_id && e.object_type === "message"}
                    onProof={() => setProof(proof === e.object_id ? null : e.object_id)}
                  />
                ))}
              </ol>
            )}
          </div>
        </div>
      )}
    </section>
  );
}

function HealthReasons({ health }: { health: ConversationHealth }) {
  return (
    <div className="ax-plane rounded-2xl p-ax-4 text-[12px]">
      <p className="font-semibold text-foreground">{health.title}</p>
      <p className={cn("ax-caption mt-1", HEALTH_TONE[health.state])}>
        {HEALTH_LABEL[health.state]}
        {health.owner ? ` · Owner: ${health.owner}` : " · no owner yet"}
        {health.due_at ? ` · Due: ${relativeTime(health.due_at)}` : ""}
      </p>
      {health.reasons.length > 0 && (
        <ul className="mt-ax-2 space-y-1">
          {health.reasons.map((r) => (
            <li key={r.reason} className="ax-caption text-muted-foreground">
              · {r.reason} <span className="text-steel">(from {r.evidence})</span>
            </li>
          ))}
        </ul>
      )}
      {health.chain && (
        <p className="ax-caption mt-ax-2 text-steel">
          <Fingerprint className="mr-1.5 inline size-3.5" aria-hidden="true" />
          {health.chain.sealed_messages} message(s) sealed ·{" "}
          {health.chain.chain_intact
            ? "record intact"
            : `record breaks at #${health.chain.first_break?.seq}`}
          {health.chain.edited_after_sealing > 0
            ? ` · ${health.chain.edited_after_sealing} edited after sending`
            : ""}
        </p>
      )}
    </div>
  );
}

function TimelineRow({
  event,
  showDay,
  proofOpen,
  onProof,
}: {
  event: TimelineEvent;
  showDay: boolean;
  proofOpen: boolean;
  onProof: () => void;
}) {
  return (
    <li>
      {showDay && <p className="ax-caption mb-1 text-steel">{day(event.at)}</p>}
      <div
        className={cn(
          "ax-plane rounded-2xl p-ax-3 text-[12px]",
          event.lane === "outcome" ? "border-cyan-accent/30" : "",
        )}
      >
        <p className="font-semibold text-foreground">
          <span className="mr-2 text-steel">{clock(event.at)}</span>
          {event.label}
          <span className="ax-caption ml-2 text-steel">
            {event.lane === "outcome" ? "outcome" : "said"}
          </span>
        </p>
        {event.detail && <p className="ax-caption mt-1 text-muted-foreground">{event.detail}</p>}
        <p className="ax-caption mt-1 text-steel">
          {event.actor ?? "unknown"}
          {typeof event.evidence?.["state"] === "string"
            ? ` · ${String(event.evidence["state"])}`
            : ""}
          {typeof event.evidence?.["owner"] === "string"
            ? ` · owner ${String(event.evidence["owner"])}`
            : ""}
          {typeof event.evidence?.["evidence_count"] === "number"
            ? ` · ${String(event.evidence["evidence_count"])} proof item(s)`
            : ""}
        </p>
        {event.object_type === "message" && (
          <div className="mt-ax-2">
            <Button size="sm" variant="ghost" onClick={onProof}>
              <Fingerprint className="size-3.5" aria-hidden="true" />
              {proofOpen ? "Hide proof" : "Where this came from"}
            </Button>
            {proofOpen && <Provenance messageId={event.object_id} />}
          </div>
        )}
      </div>
    </li>
  );
}

function Provenance({ messageId }: { messageId: string }) {
  const q = useMessageProvenance(messageId);
  if (q.isPending) return <p className="ax-caption mt-1 text-muted-foreground">Checking…</p>;
  if (q.error)
    return <p className="ax-caption mt-1 text-amber-400">Not available: {q.error.message}</p>;
  const p = q.data!;
  if (p.error) return <p className="ax-caption mt-1 text-amber-400">{p.error}</p>;
  return (
    <div className="mt-1 space-y-1 border-l border-border pl-ax-3">
      <p className="ax-caption text-muted-foreground">
        Sent by {p.sent_by ?? "unknown"}
        {p.workspace ? ` · Workspace ${p.workspace}` : ""} · {p.sent_at_utc}
      </p>
      <p className="ax-caption text-muted-foreground">
        {p.delivery_confirmed
          ? `Confirmed on every recipient's device (${p.delivery_count}/${p.recipients})`
          : `Confirmed by ${p.delivery_count} of ${p.recipients} recipient(s)`}
        {p.read_count > 0 ? ` · opened by ${p.read_count}` : ""}
      </p>
      <p className={cn("ax-caption", p.integrity_verified ? "text-emerald-400" : "text-amber-400")}>
        {p.integrity_verified ? "Integrity verified" : "Integrity note"} — {p.integrity_note}
      </p>
      <p className="ax-caption text-steel">
        {p.transport_label}
        {p.device_label ? ` · ${p.device_label}` : ""}
        {p.seal_hash ? ` · proof ${p.seal_hash.slice(0, 12)}…` : ""}
      </p>
    </div>
  );
}

function Collisions({ items, loading }: { items: Collision[]; loading: boolean }) {
  const act = useCollisionAct();

  const run = (c: Collision, action: CollisionAction) => {
    const reason = window.prompt(
      action === "dismiss"
        ? "Why is this warning not a problem? (at least 8 characters — it stays on record)"
        : action === "resolve_dependency"
          ? "Why does this no longer depend on the other one? (at least 8 characters)"
          : action === "change_deadline"
            ? "Why is the date moving? (at least 8 characters — the first date stays on record)"
            : "Why is someone else taking this on? (at least 8 characters)",
    );
    if (!reason || reason.trim().length < 8) {
      notify.failed("Nothing changed", {
        description: "Every action here needs a written reason of at least 8 characters.",
      });
      return;
    }
    let newDue: string | undefined;
    let newOwner: string | undefined;
    if (action === "change_deadline") {
      const raw = window.prompt("New date and time (YYYY-MM-DD HH:MM, UTC):");
      if (!raw) return;
      const parsed = new Date(raw.replace(" ", "T") + (raw.includes("Z") ? "" : "Z"));
      if (Number.isNaN(parsed.getTime())) {
        notify.failed("Nothing changed", { description: "That date could not be read." });
        return;
      }
      newDue = parsed.toISOString();
    }
    if (action === "reassign") {
      const raw = window.prompt("Who takes it on? (their user id)");
      if (!raw?.trim()) return;
      newOwner = raw.trim();
    }
    act.mutate(
      {
        collision_id: c.id,
        action,
        reason: reason.trim(),
        ...(newDue ? { new_due: newDue } : {}),
        ...(newOwner ? { new_owner: newOwner } : {}),
      },
      {
        onSuccess: (r) =>
          r.ok
            ? notify.done("Recorded", "Your reason is on the record with this warning.")
            : notify.failed("Not recorded", {
                description: r.message ?? r.error ?? "Try again.",
              }),
        onError: (e) => notify.failed("Not recorded", { description: e.message }),
      },
    );
  };

  if (loading) return <p className="ax-caption text-muted-foreground">Checking commitments…</p>;

  if (items.length === 0)
    return (
      <p className="ax-caption text-muted-foreground">
        <ShieldCheck className="mr-1.5 inline size-3.5" aria-hidden="true" />
        No clashing commitments. Warnings only appear when something people linked themselves is
        about to break.
      </p>
    );

  return (
    <div className="space-y-ax-2">
      <p className="ax-caption text-amber-400">
        <AlertTriangle className="mr-1.5 inline size-3.5" aria-hidden="true" />
        {items.length} commitment(s) at risk because of a link someone recorded.
      </p>
      {items.map((c) => (
        <div key={c.id} className="ax-plane rounded-2xl p-ax-3 text-[12px]">
          <p className="font-semibold text-foreground">{c.evidence.item?.title ?? "Commitment"}</p>
          <p className="ax-caption mt-1 text-muted-foreground">{c.evidence.why}</p>
          <p className="ax-caption mt-1 text-steel">
            Waiting on: {c.evidence.blocker?.title ?? "another commitment"}
            {c.evidence.blocker?.owner ? ` · ${c.evidence.blocker.owner}` : ""}
            {c.evidence.blocker?.due_at
              ? ` · was due ${relativeTime(c.evidence.blocker.due_at)}`
              : ""}
          </p>
          <p className="ax-caption mt-1 text-steel">
            {c.severity === "critical" ? "Already late" : "At risk"} · recorded link, not a guess
          </p>
          <div className="mt-ax-3 flex flex-wrap gap-2">
            <Button
              size="sm"
              variant="outline"
              disabled={act.isPending}
              onClick={() => run(c, "change_deadline")}
            >
              Move the date
            </Button>
            <Button
              size="sm"
              variant="outline"
              disabled={act.isPending}
              onClick={() => run(c, "reassign")}
            >
              Hand it over
            </Button>
            <Button
              size="sm"
              variant="ghost"
              disabled={act.isPending}
              onClick={() => run(c, "resolve_dependency")}
            >
              <Link2Off className="size-3.5" aria-hidden="true" />
              Unlink them
            </Button>
            <Button
              size="sm"
              variant="ghost"
              disabled={act.isPending}
              onClick={() => run(c, "dismiss")}
            >
              Not a problem
            </Button>
          </div>
          {c.log.length > 0 && (
            <ul className="mt-ax-2 space-y-0.5">
              {c.log.slice(0, 4).map((l, i) => (
                <li key={`${l.at}-${i}`} className="ax-caption text-steel">
                  <ListTree className="mr-1 inline size-3" aria-hidden="true" />
                  {l.action.replace(/_/g, " ")}
                  {l.reason ? ` — ${l.reason}` : ""} · {relativeTime(l.at)}
                </li>
              ))}
            </ul>
          )}
        </div>
      ))}
    </div>
  );
}
