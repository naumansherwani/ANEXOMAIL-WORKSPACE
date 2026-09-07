import { Mail, MailPlus, Quote } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import {
  useEmailChatContext,
  useEmailDraft,
  useEmailDraftBoard,
  useEmailDraftConsent,
  useMessageEscalations,
  useSendEmailDraft,
} from "@/lib/chat-email-bridge";
import { useHealthBoard } from "@/lib/chat-timeline";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

/**
 * PHASE 29 / 30 — the bridge between the formal record and the instant one.
 *
 * Email stays the formal record; chat stays the fast lane. A conversation shows
 * which email thread it belongs to, and a formal email built from chat carries a
 * footnote for every line: who said it, the exact time, and the seal of the
 * original words. People whose words are quoted are told, and if they object,
 * that objection stays visible.
 */
export function EmailBridge() {
  const board = useHealthBoard();
  const rows = board.data?.conversations ?? [];
  const [selected, setSelected] = useState<string | null>(null);
  const current = selected ?? rows[0]?.conversation_id ?? null;

  const context = useEmailChatContext(current);
  const drafts = useEmailDraftBoard(current);
  const [open, setOpen] = useState<string | null>(null);
  const draft = useEmailDraft(open);
  const consent = useEmailDraftConsent();
  const send = useSendEmailDraft();

  return (
    <section className="space-y-ax-4">
      <div>
        <h2 className="ax-heading flex items-center gap-2 text-foreground">
          <Mail className="size-4" aria-hidden="true" /> Email and chat
        </h2>
        <p className="ax-caption text-muted-foreground">
          {context.data?.badge ?? "The formal record lives in ANEXOMAIL. Chat never replaces it."}
        </p>
      </div>

      {rows.length > 0 && (
        <div className="flex flex-wrap gap-1">
          {rows.slice(0, 8).map((r) => (
            <button
              key={r.conversation_id}
              type="button"
              onClick={() => {
                setSelected(r.conversation_id);
                setOpen(null);
              }}
              className={cn(
                "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold",
                current === r.conversation_id
                  ? "border-cyan-accent/50 bg-secondary text-foreground"
                  : "border-border text-muted-foreground",
              )}
            >
              {r.title}
            </button>
          ))}
        </div>
      )}

      <div className="ax-plane rounded-2xl p-ax-4">
        <p className="ax-caption font-semibold text-foreground">Linked email threads</p>
        {(context.data?.links ?? []).length === 0 ? (
          <p className="ax-caption mt-ax-2 text-muted-foreground">
            This conversation is not linked to an email thread yet.
          </p>
        ) : (
          <ul className="mt-ax-2 space-y-1">
            {(context.data?.links ?? []).map((l) => (
              <li key={l.link_id} className="ax-caption text-muted-foreground">
                <span className="text-foreground">{l.subject ?? "Subject not on record"}</span> ·{" "}
                {l.origin === "email_to_chat" ? "opened from email" : "escalated to email"} ·{" "}
                {relativeTime(l.created_at)}
                <span className="text-steel"> · {l.subject_source}</span>
              </li>
            ))}
          </ul>
        )}
        {(context.data?.quotes ?? []).length > 0 && (
          <p className="ax-caption mt-ax-2 flex items-center gap-2 text-steel">
            <Quote className="size-3.5" aria-hidden="true" />
            {(context.data?.quotes ?? []).length} quoted email passages, each sealed with the original
            wording.
          </p>
        )}
      </div>

      <div className="ax-plane rounded-2xl p-ax-4">
        <p className="ax-caption flex items-center gap-2 font-semibold text-foreground">
          <MailPlus className="size-3.5" aria-hidden="true" /> Formal emails from chat
        </p>
        {drafts.data?.error ? (
          <p className="ax-caption mt-ax-2 text-muted-foreground">{drafts.data.error}</p>
        ) : (drafts.data?.drafts ?? []).length === 0 ? (
          <p className="ax-caption mt-ax-2 text-muted-foreground">
            No formal emails written from this conversation yet.
          </p>
        ) : (
          <ul className="mt-ax-2 space-y-ax-2">
            {(drafts.data?.drafts ?? []).map((d) => (
              <li key={d.draft_id}>
                <button
                  type="button"
                  onClick={() => setOpen(open === d.draft_id ? null : d.draft_id)}
                  className="ax-press ax-caption w-full rounded-xl border border-border px-3 py-2 text-left"
                >
                  <span className="font-semibold text-foreground">{d.subject}</span>
                  <span className="text-muted-foreground">
                    {" "}
                    · {d.state} · {d.citations} quoted lines
                    {d.objections > 0 ? ` · ${d.objections} objection(s)` : ""}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )}

        {open && draft.data && !draft.data.error && (
          <div className="mt-ax-3 space-y-ax-2">
            <p className="ax-caption whitespace-pre-wrap text-muted-foreground">{draft.data.body}</p>
            <ul className="space-y-1">
              {(draft.data.citations ?? []).map((c) => (
                <li key={c.message_id} className="ax-caption text-steel">
                  line {c.line_no} · {c.sender} · {c.sent_at_ms} · seal {c.body_hash.slice(0, 12)}…
                </li>
              ))}
            </ul>
            {(draft.data.attachments ?? []).length > 0 && (
              <ul className="space-y-1">
                {(draft.data.attachments ?? []).map((a) => (
                  <li key={a.version_id} className="ax-caption text-muted-foreground">
                    {a.filename} · {a.version_state}
                    {a.lineage
                      ? ` · ${a.lineage.filter((s) => s.recorded).map((s) => s.step).join(" → ")}`
                      : " · no checks on record"}
                  </li>
                ))}
              </ul>
            )}
            {(draft.data.consent ?? []).length > 0 && (
              <ul className="space-y-1">
                {(draft.data.consent ?? []).map((c) => (
                  <li
                    key={`${c.user_id}-${c.at}`}
                    className={cn(
                      "ax-caption",
                      c.state === "objected" ? "text-red-400" : "text-muted-foreground",
                    )}
                  >
                    {c.person} · {c.state}
                    {c.reason ? ` · ${c.reason}` : ""}
                  </li>
                ))}
              </ul>
            )}
            <div className="flex flex-wrap gap-2">
              <Button
                size="sm"
                variant="outline"
                disabled={consent.isPending}
                onClick={() =>
                  consent.mutate(
                    { draft_id: open, state: "acknowledged" },
                    {
                      onSuccess: (d) =>
                        d.error
                          ? notify.failed("Not recorded", { description: d.error })
                          : notify.done("Noted", "Your acknowledgement is on record."),
                      onError: (e) => notify.failed("Not recorded", { description: e.message }),
                    },
                  )
                }
              >
                I acknowledge
              </Button>
              <Button
                size="sm"
                variant="outline"
                disabled={consent.isPending}
                onClick={() => {
                  const reason = window.prompt("Why do you object? (8+ characters)")?.trim();
                  if (!reason || reason.length < 8) {
                    notify.failed("A reason is required", { description: "At least 8 characters." });
                    return;
                  }
                  consent.mutate(
                    { draft_id: open, state: "objected", reason },
                    {
                      onSuccess: (d) =>
                        d.error
                          ? notify.failed("Not recorded", { description: d.error })
                          : notify.done("Objection recorded", "It stays visible on this email."),
                      onError: (e) => notify.failed("Not recorded", { description: e.message }),
                    },
                  );
                }}
              >
                I object
              </Button>
              <Button
                size="sm"
                variant="outline"
                disabled={send.isPending || draft.data.state === "sent"}
                onClick={() => {
                  const id = window.prompt("Formal email id from ANEXOMAIL")?.trim();
                  if (!id) return;
                  send.mutate(
                    { draft_id: open, mail_message_id: id },
                    {
                      onSuccess: (d) =>
                        d.error
                          ? notify.failed("Not sent", { description: d.error })
                          : notify.done("Recorded as sent", "Chat now shows it went to email."),
                      onError: (e) => notify.failed("Not sent", { description: e.message }),
                    },
                  );
                }}
              >
                Mark sent in ANEXOMAIL
              </Button>
            </div>
          </div>
        )}
        <p className="ax-caption mt-ax-2 text-steel">
          {draft.data?.formal_record ?? "Formal record: ANEXOMAIL."}
        </p>
      </div>
    </section>
  );
}

/** Permanent marker on a chat message once it became a formal email. */
export function EscalatedBadge({ messageId }: { messageId: string }) {
  const q = useMessageEscalations(messageId);
  if (!q.data?.label) return null;
  return <span className="ax-caption text-cyan-accent">{q.data.label}</span>;
}
