import { CheckCircle2, GitBranch, Link2, ShieldCheck } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import {
  useCompleteWork,
  useWorkBoard,
  useWorkChain,
  useWorkDepend,
  type WorkBoardItem,
} from "@/lib/chat-safety";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

/**
 * PHASE 22 — WORK EXECUTION CHAIN.
 * Message → work object → owner → dependency → deadline → completion →
 * evidence. Item apni conversation se kabhi nahi tootta: provenance snapshot
 * create ke waqt likh diya jata hai, aur completion bina evidence namumkin hai.
 */
export function WorkChainBoard() {
  const board = useWorkBoard();
  const [open, setOpen] = useState<string | null>(null);
  const [depFrom, setDepFrom] = useState<string | null>(null);
  const depend = useWorkDepend();
  const complete = useCompleteWork();

  const items = board.data?.items ?? [];
  const plan = board.data?.plan;

  const finish = (item: WorkBoardItem) => {
    const ref = window.prompt("Completion evidence — a link, a file id, or a short note:");
    if (!ref || !ref.trim()) return;
    complete.mutate(
      {
        item_id: item.id,
        evidence: { kind: ref.startsWith("http") ? "link" : "note", ref: ref.trim() },
      },
      {
        onSuccess: (r) =>
          r.ok
            ? notify.done(
                "Closed with evidence",
                `${r.evidence_count} piece(s) of evidence on file.`,
              )
            : notify.failed("Not closed", { description: r.message ?? r.error ?? "Try again." }),
        onError: (e) => notify.failed("Not closed", { description: e.message }),
      },
    );
  };

  return (
    <section className="space-y-ax-3">
      <header className="flex flex-wrap items-center gap-ax-3">
        <h3 className="ax-label text-foreground">
          <GitBranch className="mr-1.5 inline size-3.5" aria-hidden="true" />
          Execution chain
        </h3>
        {plan && (
          <span className="ax-caption text-steel">
            {plan.plan} · {plan.limit ? `${plan.limit} open objects` : "open objects"}
          </span>
        )}
      </header>

      {board.isPending ? (
        <p className="ax-caption text-muted-foreground">Loading work objects…</p>
      ) : board.error ? (
        <p className="ax-caption text-amber-400">Board didn&apos;t load: {board.error.message}</p>
      ) : items.length === 0 ? (
        <p className="ax-caption text-muted-foreground">
          Nothing open. Work objects appear here the moment a conversation creates one.
        </p>
      ) : (
        <ul className="space-y-ax-3">
          {items.map((item) => (
            <li key={item.id} className="ax-plane rounded-2xl p-ax-4">
              <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                <span className="font-semibold text-foreground">{item.title}</span>
                <span className="text-muted-foreground">{item.kind}</span>
                <span
                  className={item.state === "blocked" ? "text-amber-400" : "text-muted-foreground"}
                >
                  {item.state}
                </span>
                {item.due_at && (
                  <span className={item.overdue ? "text-red-400" : "text-muted-foreground"}>
                    due {relativeTime(item.due_at)}
                  </span>
                )}
                <span className="ml-auto text-steel">{item.evidence_count} evidence</span>
              </div>

              <div className="mt-ax-3 flex flex-wrap gap-2">
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => setOpen(open === item.id ? null : item.id)}
                >
                  <ShieldCheck className="size-3.5" />
                  {open === item.id ? "Hide chain" : "Show chain"}
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={depend.isPending}
                  onClick={() => {
                    if (!depFrom) {
                      setDepFrom(item.id);
                      notify.done("Pick the blocker", "Now choose the item this one waits for.");
                      return;
                    }
                    if (depFrom === item.id) {
                      setDepFrom(null);
                      return;
                    }
                    depend.mutate(
                      { item_id: depFrom, depends_on: item.id },
                      {
                        onSuccess: (r) => {
                          setDepFrom(null);
                          if (r.ok) {
                            notify.done("Dependency set", "The waiting item is now blocked.");
                          } else {
                            notify.failed("Dependency not set", {
                              description: r.error ?? "Try again.",
                            });
                          }
                        },
                        onError: (e) => {
                          setDepFrom(null);
                          notify.failed("Dependency not set", { description: e.message });
                        },
                      },
                    );
                  }}
                >
                  <Link2 className="size-3.5" />
                  {depFrom === item.id
                    ? "Cancel link"
                    : depFrom
                      ? "Blocks the picked item"
                      : "Waits for…"}
                </Button>
                {item.state !== "done" && (
                  <Button
                    size="sm"
                    variant="secondary"
                    disabled={complete.isPending}
                    onClick={() => finish(item)}
                  >
                    <CheckCircle2 className="size-3.5" />
                    Close with evidence
                  </Button>
                )}
              </div>

              {open === item.id && <ChainDetail itemId={item.id} />}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function ChainDetail({ itemId }: { itemId: string }) {
  const q = useWorkChain(itemId);
  if (q.isPending)
    return <p className="ax-caption mt-ax-3 text-muted-foreground">Loading chain…</p>;
  if (q.error) return <p className="ax-caption mt-ax-3 text-amber-400">{q.error.message}</p>;
  const c = q.data!;
  const p = c.provenance as Record<string, string>;

  return (
    <div className="mt-ax-3 space-y-2 rounded-xl border border-border p-ax-3 text-[11px]">
      <p className="text-foreground">
        Source message{" "}
        {c.source_message.visible
          ? `— “${c.source_message.body?.slice(0, 140)}”`
          : "— hidden from the normal view, provenance kept"}
      </p>
      <p className="text-muted-foreground">
        conversation {String(p["conversation_id"] ?? "—").slice(0, 8)}… · sender{" "}
        {String(p["sender_id"] ?? "—").slice(0, 8)}… · sent{" "}
        {p["sent_at"] ? new Date(p["sent_at"]).toLocaleString() : "—"}
      </p>
      <p className="text-steel">body hash {String(p["body_hash"] ?? "—").slice(0, 24)}…</p>
      {c.dependency && (
        <p className="text-amber-400">
          waits for “{c.dependency.title}” ({c.dependency.state})
        </p>
      )}
      <p className="text-muted-foreground">
        owner {c.item.owner_user_id?.slice(0, 8) ?? "—"}… · due{" "}
        {c.item.due_at ? new Date(c.item.due_at).toLocaleString() : "no deadline"} ·{" "}
        {c.item.completed_at
          ? `closed ${new Date(c.item.completed_at).toLocaleString()}`
          : "not closed"}
      </p>
      <ul className="space-y-1 text-muted-foreground">
        {c.evidence.map((e, i) => (
          <li key={i}>
            evidence · {e.kind} · {e.ref.slice(0, 48)} · {relativeTime(e.at)}
          </li>
        ))}
      </ul>
      <ul className="space-y-1 text-steel">
        {c.events.map((e, i) => (
          <li key={i}>
            {e.action}
            {e.to_state ? ` → ${e.to_state}` : ""} · {relativeTime(e.at)}
          </li>
        ))}
      </ul>
      <p className={c.chain_intact ? "text-emerald-400" : "text-red-400"}>
        {c.chain_intact ? "Chain intact — provenance proven" : "Provenance missing"} · retention{" "}
        {c.item.retention_class.replace(/_/g, " ")}
      </p>
    </div>
  );
}
