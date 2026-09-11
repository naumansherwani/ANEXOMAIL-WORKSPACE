import { GitBranch, History, Link2, Link2Off, Mail, ScrollText, ShieldCheck } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import {
  DECISION_LABEL,
  DECISION_TONE,
  type DecisionRow,
  useDecision,
  useDecisionAmend,
  useDecisionBoard,
  useDecisionLink,
  useDecisionUnlink,
} from "@/lib/chat-decisions";
import { useDecisionToEmail } from "@/lib/chat-email-bridge";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { isChatEntitlementError } from "@/lib/chat-transport";

const utc = (iso: string) => new Date(iso).toISOString().replace("T", " ").slice(0, 16) + " UTC";

/**
 * PHASE 24 — DECISION LEDGER + DECISION IMPACT MAP.
 * "Migration Friday at 02:00." → marked as a decision → maker, UTC timestamp,
 * source conversation, and provenance hash. A decision is never silently
 * rewritten: every change writes a new version and the old one stays readable.
 * The impact map only shows links a person made, with a written reason —
 * anything merely nearby is shown separately as "possibly affected".
 */
export function DecisionLedger() {
  const { t } = useLocale();
  const board = useDecisionBoard();
  // PHASE 30 — decision → cited email draft (consent gate on send, never auto-sent).
  const toEmail = useDecisionToEmail();
  const [open, setOpen] = useState<string | null>(null);
  const amend = useDecisionAmend();

  const decisions = board.data?.decisions ?? [];
  const summary = board.data?.summary ?? {};

  const change = (d: DecisionRow, kind: "amended" | "superseded" | "reversed") => {
    const reason = window.prompt(
      kind === "amended"
        ? "What changed, and why? (at least 12 characters — the old version stays on record)"
        : kind === "superseded"
          ? "Why is this decision replaced? (at least 12 characters)"
          : "Why is this decision reversed? (at least 12 characters)",
    );
    if (!reason || reason.trim().length < 12) {
      notify.failed("Nothing recorded", {
        description: "A decision only changes with a written reason of at least 12 characters.",
      });
      return;
    }
    const title =
      kind === "amended"
        ? (window.prompt("New wording of the decision (leave empty to keep):", d.title) ?? "")
        : "";
    amend.mutate(
      {
        decision_id: d.id,
        reason: reason.trim(),
        change: kind,
        ...(title.trim() && title.trim() !== d.title ? { title: title.trim() } : {}),
      },
      {
        onSuccess: (r) =>
          r.ok
            ? notify.done(
                kind === "amended"
                  ? `Version ${r.version} recorded`
                  : kind === "superseded"
                    ? "Marked as replaced"
                    : "Marked as reversed",
                `Version ${r.previous_version} is still readable — nothing was overwritten.`,
              )
            : notify.failed("Not recorded", { description: r.message ?? r.error ?? "Try again." }),
        onError: (e) => notify.failed("Not recorded", { description: e.message }),
      },
    );
  };

  if (board.data && !board.data.plan) {
    return (
      <section className="space-y-ax-3">
        <h2 className="ax-heading text-foreground">Decision ledger</h2>
        <p className="ax-caption text-muted-foreground">
          Decision ledger is part of Business and above.
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-ax-3">
      <header className="flex flex-wrap items-center gap-ax-3">
        <h2 className="ax-heading text-foreground">
          <ScrollText className="mr-2 inline size-4" aria-hidden="true" />
          Decision ledger
        </h2>
        <span className="ax-caption text-steel">
          {summary.total ?? 0} recorded · {summary.active ?? 0} standing · {summary.amended ?? 0}{" "}
          changed · {summary.superseded ?? 0} replaced · {summary.reversed ?? 0} reversed
        </span>
      </header>

      <p className="ax-caption text-muted-foreground">
        <ShieldCheck className="mr-1.5 inline size-3.5" aria-hidden="true" />A decision is never
        rewritten in place. Changing one writes a new version with a written reason, and every
        earlier version stays readable.
      </p>

      {board.isPending ? (
        <p className="ax-caption text-muted-foreground">Reading the ledger…</p>
      ) : board.error && isChatEntitlementError(board.error) ? (
        <p className="ax-caption text-muted-foreground">
          {t("Decisions from ANEXOChat appear here. Nothing is recorded yet.")}
        </p>
      ) : board.error ? (
        <p className="ax-caption text-amber-400">Ledger didn&apos;t load: {board.error.message}</p>
      ) : decisions.length === 0 ? (
        <p className="ax-caption text-muted-foreground">
          No decisions recorded yet. In a conversation, choose &ldquo;Mark as decision&rdquo; on the
          message that settled it.
        </p>
      ) : (
        <ul className="space-y-ax-2">
          {decisions.map((d) => (
            <li key={d.id} className="ax-plane rounded-2xl p-ax-4 text-[12px]">
              <p className="font-semibold text-foreground">{d.title}</p>
              {d.detail && <p className="ax-caption mt-1 text-muted-foreground">{d.detail}</p>}
              <p className="ax-caption mt-1 text-steel">
                Made by {d.made_by_email ?? d.made_by} · {utc(d.decided_at)} · Source ANEXOChat ·
                version {d.version}
              </p>
              <p className={`ax-caption mt-1 ${DECISION_TONE[d.state]}`}>
                {DECISION_LABEL[d.state]}
                {d.affects_count > 0
                  ? ` · ${d.affects_count} linked item(s), ${d.open_affected} still open`
                  : " · nothing linked yet"}
              </p>
              <p className="ax-caption mt-1 text-steel">
                Recorded {relativeTime(d.recorded_at)} · proof {d.body_hash.slice(0, 12)}…
              </p>

              <div className="mt-ax-3 flex flex-wrap gap-2">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => setOpen(open === d.id ? null : d.id)}
                >
                  <GitBranch className="size-3.5" aria-hidden="true" />
                  {open === d.id ? "Hide impact" : "Impact & history"}
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  disabled={d.state !== "active" || amend.isPending}
                  onClick={() => change(d, "amended")}
                >
                  Change decision
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={d.state !== "active" || amend.isPending}
                  onClick={() => change(d, "superseded")}
                >
                  Replaced
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={d.state === "reversed" || amend.isPending}
                  onClick={() => change(d, "reversed")}
                >
                  Reverse
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={toEmail.isPending}
                  onClick={() =>
                    toEmail.mutate(
                      { decision_id: d.id },
                      {
                        onSuccess: (r) =>
                          r.ok === false
                            ? notify.failed(r.error ?? "Could not draft email")
                            : notify.done(
                                "Email draft created",
                                "Cited draft is in Mail → Drafts; nothing was sent.",
                              ),
                        onError: (e) =>
                          notify.failed(e.isNotImplemented ? "Not wired yet" : "Draft failed", {
                            description: e.message,
                          }),
                      },
                    )
                  }
                >
                  <Mail className="size-3.5" aria-hidden="true" />
                  Email this decision
                </Button>
              </div>

              {open === d.id && <DecisionDetailView id={d.id} />}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function DecisionDetailView({ id }: { id: string }) {
  const q = useDecision(id);
  const link = useDecisionLink();
  const unlink = useDecisionUnlink();

  const d = q.data;
  const impact = d?.impact;

  const addLink = (objectType: "task" | "promise", objectId: string, label: string) => {
    const reason = window.prompt(
      `Why does this decision affect “${label}”? (at least 8 characters)`,
    );
    if (!reason || reason.trim().length < 8) {
      notify.failed("Nothing linked", {
        description: "A link is a record — write why in at least 8 characters.",
      });
      return;
    }
    link.mutate(
      { decision_id: id, object_type: objectType, object_id: objectId, reason: reason.trim() },
      {
        onSuccess: (r) =>
          r.ok
            ? notify.done("Linked", `“${label}” now shows under this decision.`)
            : notify.failed("Not linked", { description: r.message ?? r.error ?? "Try again." }),
        onError: (e) => notify.failed("Not linked", { description: e.message }),
      },
    );
  };

  const removeLink = (linkId: string, label: string) => {
    const reason = window.prompt(`Why remove the link to “${label}”? (at least 8 characters)`);
    if (!reason || reason.trim().length < 8) {
      notify.failed("Nothing removed", { description: "Write why in at least 8 characters." });
      return;
    }
    unlink.mutate(
      { link_id: linkId, reason: reason.trim() },
      {
        onSuccess: (r) =>
          r.ok
            ? notify.done("Link removed", "The removal itself stays on record.")
            : notify.failed("Not removed", { description: r.message ?? r.error ?? "Try again." }),
        onError: (e) => notify.failed("Not removed", { description: e.message }),
      },
    );
  };

  if (q.isPending) return <p className="ax-caption mt-ax-3 text-muted-foreground">Loading…</p>;
  if (q.error)
    return <p className="ax-caption mt-ax-3 text-amber-400">Didn&apos;t load: {q.error.message}</p>;
  if (!d?.decision) return null;

  return (
    <div className="mt-ax-3 space-y-ax-3 border-t border-border pt-ax-3">
      {!d.decision.message_visible && (
        <p className="ax-caption text-amber-400">
          The original message is no longer visible, but this decision and its proof stay on record.
        </p>
      )}

      {impact?.impact_allowed === false ? (
        <p className="ax-caption text-muted-foreground">
          The impact map is part of Business Pro and above.
        </p>
      ) : (
        <>
          <p className="ax-caption text-muted-foreground">
            <Link2 className="mr-1.5 inline size-3.5" aria-hidden="true" />
            Affected by this decision — only what a person linked, with the reason they wrote:
          </p>
          {(impact?.affects ?? []).length === 0 ? (
            <p className="ax-caption text-steel">Nothing linked yet.</p>
          ) : (
            <ul className="ax-caption space-y-1 text-foreground">
              {impact!.affects.map((a) => (
                <li key={a.link_id}>
                  ↓ {a.relation} {a.object_type}: {a.label ?? a.object_id}
                  {a.object_state ? ` · ${a.object_state}` : ""}
                  {a.due_at ? ` · due ${utc(a.due_at)}` : ""}
                  <span className="text-steel"> · {a.link_reason}</span>
                  <button
                    type="button"
                    className="ax-press ml-2 text-steel underline"
                    onClick={() => removeLink(a.link_id, a.label ?? a.object_id)}
                  >
                    <Link2Off className="inline size-3" aria-hidden="true" /> remove
                  </button>
                </li>
              ))}
            </ul>
          )}

          {(impact?.potentially_affected ?? []).length > 0 && (
            <>
              <p className="ax-caption text-muted-foreground">
                Possibly affected — open work in the same conversation. Nothing here is linked, and
                nothing is assumed:
              </p>
              <ul className="ax-caption space-y-1 text-steel">
                {impact!.potentially_affected.map((p) => (
                  <li key={p.object_id}>
                    {p.object_type}: {p.label}
                    {p.due_at ? ` · due ${utc(p.due_at)}` : ""}
                    <button
                      type="button"
                      className="ax-press ml-2 text-cyan-accent underline"
                      onClick={() => addLink(p.object_type, p.object_id, p.label)}
                    >
                      link as affected
                    </button>
                  </li>
                ))}
              </ul>
            </>
          )}

          {(impact?.removed_links ?? []).length > 0 && (
            <p className="ax-caption text-steel">
              {impact!.removed_links.length} link(s) were removed earlier — the removals stay on
              record.
            </p>
          )}
        </>
      )}

      <p className="ax-caption text-muted-foreground">
        <History className="mr-1.5 inline size-3.5" aria-hidden="true" />
        History — every version stays readable:
      </p>
      <ul className="ax-caption space-y-1 text-steel">
        {d.history.map((h) => (
          <li key={h.version}>
            v{h.version} · {h.change} · {utc(h.decided_at)} · {relativeTime(h.at)}
            {h.reason ? ` · ${h.reason}` : ""}
            <span className="text-foreground"> — {h.title}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
