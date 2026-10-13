import {
  BadgeCheck,
  Forward,
  Gavel,
  ListChecks,
  Mail,
  Receipt,
  ShieldCheck,
  Star,
  X,
} from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { ChatConversation, ChatMessage } from "@/lib/chat";
import { useDecisionMark } from "@/lib/chat-decisions";
import { useCreateEmailDraft } from "@/lib/chat-email-bridge";
import { useReceiptPack } from "@/lib/chat-receipts";
import {
  useForwardMessage,
  useStarMessage,
  useWorkFromMessage,
  useWorkSuggestion,
} from "@/lib/chat-safety";
import { useMarkImportant, useMessageProvenance } from "@/lib/chat-timeline";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

/**
 * Per-message truth drawer — Phase 19/22/24/25/27/28/30 ke message-level arms
 * ek jagah: star · forward · important · decision · work-from-message ·
 * receipt pack · provenance · email draft. Har button asli RPC hai; engine
 * jo nahi jaanti woh UI "not recorded" likhta hai, kabhi invent nahi karta.
 */
export function MessageTruth({
  message,
  conversationId,
  conversations,
  onClose,
}: {
  message: ChatMessage;
  conversationId: string;
  conversations: ChatConversation[];
  onClose: () => void;
}) {
  const [tab, setTab] = useState<"actions" | "receipts" | "provenance">("actions");
  return (
    <aside
      aria-label="Message actions and truth"
      className="shrink-0 border-t border-border bg-card/70 px-4 py-3 text-xs"
    >
      <div className="flex items-start gap-2">
        <p className="min-w-0 flex-1 text-muted-foreground">
          <span className="font-semibold text-foreground">{message.sender_name}</span> · #
          {message.seq} · {message.body.slice(0, 120)}
        </p>
        <button type="button" aria-label="Close" onClick={onClose} className="ax-press">
          <X className="size-3.5" />
        </button>
      </div>
      <div className="mt-2 flex gap-1">
        {(["actions", "receipts", "provenance"] as const).map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setTab(t)}
            className={cn(
              "ax-press rounded-full border px-2.5 py-0.5 text-[11px] font-semibold capitalize",
              tab === t
                ? "border-cyan-accent/50 bg-secondary text-foreground"
                : "border-border text-muted-foreground",
            )}
          >
            {t}
          </button>
        ))}
      </div>
      <div className="mt-2">
        {tab === "actions" ? (
          <Actions
            message={message}
            conversationId={conversationId}
            conversations={conversations}
          />
        ) : tab === "receipts" ? (
          <Receipts messageId={message.id} />
        ) : (
          <Provenance messageId={message.id} />
        )}
      </div>
    </aside>
  );
}

function Actions({
  message,
  conversationId,
  conversations,
}: {
  message: ChatMessage;
  conversationId: string;
  conversations: ChatConversation[];
}) {
  const star = useStarMessage();
  const forward = useForwardMessage();
  const important = useMarkImportant();
  const decision = useDecisionMark();
  const workFrom = useWorkFromMessage();
  const suggestion = useWorkSuggestion(message.id);
  const emailDraft = useCreateEmailDraft();

  const [forwardTo, setForwardTo] = useState("");
  const [reason, setReason] = useState("");
  const [decisionTitle, setDecisionTitle] = useState(message.body.slice(0, 80));
  const [emailSubject, setEmailSubject] = useState("");
  const [emailTo, setEmailTo] = useState("");

  const fail = (title: string) => (error: { isNotImplemented: boolean; message: string }) =>
    notify.failed(error.isNotImplemented ? "Not wired yet" : title, {
      description: error.message,
    });

  const targets = conversations.filter((c) => c.conversation_id !== conversationId);

  return (
    <div className="grid gap-3 md:grid-cols-2">
      {/* Star + Important */}
      <div className="rounded-lg border border-border p-2">
        <div className="flex flex-wrap items-center gap-1.5">
          <Button
            size="sm"
            variant="outline"
            disabled={star.isPending}
            onClick={() =>
              star.mutate(
                { message_id: message.id },
                {
                  onSuccess: (r) => notify.done(r.starred ? "Starred" : "Star removed"),
                  onError: fail("Could not star"),
                },
              )
            }
          >
            <Star className="mr-1 size-3" /> Star
          </Button>
          <Button
            size="sm"
            variant="outline"
            disabled={important.isPending || reason.trim().length < 3}
            onClick={() =>
              important.mutate(
                { message_id: message.id, important: true, reason: reason.trim() },
                {
                  onSuccess: (r) =>
                    r.ok
                      ? notify.done("Marked important", "It now sits on the timeline lane.")
                      : notify.failed(r.error ?? "Engine refused"),
                  onError: fail("Could not mark"),
                },
              )
            }
          >
            <BadgeCheck className="mr-1 size-3" /> Important
          </Button>
        </div>
        <Input
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="Why is this important? (3+ chars — human reason, engine guesses nothing)"
          className="mt-1.5 h-8 text-xs"
        />
      </div>

      {/* Forward */}
      <div className="rounded-lg border border-border p-2">
        <div className="flex items-center gap-1.5">
          <select
            aria-label="Forward to conversation"
            value={forwardTo}
            onChange={(e) => setForwardTo(e.target.value)}
            className="h-8 min-w-0 flex-1 rounded-md border border-border bg-transparent px-2 text-xs text-foreground"
          >
            <option value="">Forward to…</option>
            {targets.map((c) => (
              <option key={c.conversation_id} value={c.conversation_id}>
                {c.other_name ?? c.subject ?? "Conversation"}
              </option>
            ))}
          </select>
          <Button
            size="sm"
            variant="outline"
            disabled={!forwardTo || forward.isPending}
            onClick={() =>
              forward.mutate(
                { message_id: message.id, to_conversation_id: forwardTo },
                {
                  onSuccess: () => {
                    notify.done("Forwarded", "Original sender and time travel with it.");
                    setForwardTo("");
                  },
                  onError: fail("Could not forward"),
                },
              )
            }
          >
            <Forward className="mr-1 size-3" /> Send
          </Button>
        </div>
        {!targets.length ? (
          <p className="mt-1.5 text-[11px] text-muted-foreground">
            No other conversation to forward into yet.
          </p>
        ) : null}
      </div>

      {/* Decision (Phase 24) */}
      <div className="rounded-lg border border-border p-2">
        <div className="flex items-center gap-1.5">
          <Input
            value={decisionTitle}
            onChange={(e) => setDecisionTitle(e.target.value)}
            placeholder="Decision title"
            className="h-8 text-xs"
          />
          <Button
            size="sm"
            variant="outline"
            disabled={decision.isPending || decisionTitle.trim().length < 3}
            onClick={() =>
              decision.mutate(
                { message_id: message.id, title: decisionTitle.trim() },
                {
                  onSuccess: (r) =>
                    r.ok === false || r.error
                      ? notify.failed(r.error ?? "Engine refused")
                      : notify.done("Decision recorded", "Body hash sealed from this message."),
                  onError: fail("Could not record decision"),
                },
              )
            }
          >
            <Gavel className="mr-1 size-3" /> Decision
          </Button>
        </div>
        <p className="mt-1.5 text-[11px] text-muted-foreground">
          Maker, UTC time and SHA-256 of this exact message are sealed with it.
        </p>
      </div>

      {/* Work from message (Phase 21) */}
      <div className="rounded-lg border border-border p-2">
        {suggestion.isPending ? (
          <p className="text-[11px] text-muted-foreground">Reading this message for work…</p>
        ) : suggestion.data ? (
          <p className="text-[11px] text-muted-foreground">
            Suggests <span className="font-semibold text-foreground">{suggestion.data.kind}</span>:{" "}
            {suggestion.data.title}
            {suggestion.data.owner_name ? ` · owner ${suggestion.data.owner_name}` : ""}
            {suggestion.data.due_phrase ? ` · due “${suggestion.data.due_phrase}”` : ""}
            {suggestion.data.deterministic ? " · deterministic parse" : ""}
          </p>
        ) : (
          <p className="text-[11px] text-muted-foreground">
            {suggestion.error?.isNotImplemented
              ? "Work suggestion arm not reachable."
              : "No work pattern found in this message."}
          </p>
        )}
        <Button
          size="sm"
          variant="outline"
          className="mt-1.5"
          disabled={workFrom.isPending}
          onClick={() =>
            workFrom.mutate(
              {
                message_id: message.id,
                kind: suggestion.data?.kind,
                title: suggestion.data?.title ?? message.body.slice(0, 80),
                owner_user_id: suggestion.data?.owner_user_id ?? null,
                due_at: suggestion.data?.due_at ?? null,
              },
              {
                onSuccess: (r) =>
                  r.ok
                    ? notify.done("Work item created", "Open Work to follow it through.")
                    : notify.failed(
                        r.error ?? "Plan limit",
                        r.limit ? { description: `Limit ${r.limit} on ${r.plan ?? "plan"}.` } : {},
                      ),
                onError: fail("Could not create work"),
              },
            )
          }
        >
          <ListChecks className="mr-1 size-3" /> Make it work
        </Button>
      </div>

      {/* Email draft (Phase 30) */}
      <div className="rounded-lg border border-border p-2 md:col-span-2">
        <div className="grid gap-1.5 md:grid-cols-[1fr_1fr_auto]">
          <Input
            value={emailSubject}
            onChange={(e) => setEmailSubject(e.target.value)}
            placeholder="Email subject"
            className="h-8 text-xs"
          />
          <Input
            value={emailTo}
            onChange={(e) => setEmailTo(e.target.value)}
            placeholder="Recipients, comma separated"
            className="h-8 text-xs"
          />
          <Button
            size="sm"
            variant="outline"
            disabled={
              emailDraft.isPending || emailSubject.trim().length < 2 || !emailTo.includes("@")
            }
            onClick={() =>
              emailDraft.mutate(
                {
                  conversation_id: conversationId,
                  subject: emailSubject.trim(),
                  recipients: emailTo
                    .split(",")
                    .map((s) => s.trim())
                    .filter((s) => s.includes("@")),
                  message_ids: [message.id],
                },
                {
                  onSuccess: (r) =>
                    r.ok === false || r.error
                      ? notify.failed(r.error ?? "Engine refused")
                      : notify.done(
                          "Email draft created",
                          "Find it in Mail → Drafts with citations.",
                        ),
                  onError: fail("Could not create draft"),
                },
              )
            }
          >
            <Mail className="mr-1 size-3" /> Draft email
          </Button>
        </div>
        <p className="mt-1.5 text-[11px] text-muted-foreground">
          The draft cites this message by hash — nothing is paraphrased by the engine.
        </p>
      </div>
    </div>
  );
}

function Receipts({ messageId }: { messageId: string }) {
  const q = useReceiptPack(messageId);
  if (q.isPending) return <p className="text-muted-foreground">Reading receipt pack…</p>;
  if (q.isError)
    return (
      <p className="text-muted-foreground">
        {q.error.isNotImplemented ? "Receipt arm not reachable." : q.error.message}
      </p>
    );
  const pack = q.data;
  if (!pack || pack.error)
    return <p className="text-muted-foreground">{pack?.error ?? "No pack."}</p>;
  return (
    <div>
      <p className="text-muted-foreground">
        <Receipt className="mr-1 inline size-3" />
        {pack.recipients ?? 0} recipient{pack.recipients === 1 ? "" : "s"}
        {pack.engine_invents_nothing ? " · engine invents nothing" : ""}
      </p>
      <ul className="mt-1.5 grid gap-1 md:grid-cols-2">
        {(pack.steps ?? []).map((s) => (
          <li
            key={s.step}
            className="flex items-center gap-2 rounded-md border border-border px-2 py-1"
          >
            <span
              className={cn(
                "size-2 rounded-full",
                s.recorded ? "bg-emerald-500" : "bg-muted-foreground/40",
              )}
              aria-hidden
            />
            <span className="capitalize text-foreground">{s.step}</span>
            <span className="ml-auto text-muted-foreground">
              {s.recorded
                ? `${s.at ? relativeTime(s.at) : "recorded"}${
                    s.people != null && s.of != null ? ` · ${s.people}/${s.of}` : ""
                  }`
                : "not recorded"}
            </span>
          </li>
        ))}
      </ul>
      {pack.negative_receipts?.length ? (
        <p className="mt-1.5 text-[11px] text-muted-foreground">
          {pack.negative_receipts.length} negative receipt(s): someone has not opened it yet — that
          is stated, not hidden.
        </p>
      ) : null}
      {pack.note ? <p className="mt-1 text-[11px] text-muted-foreground">{pack.note}</p> : null}
    </div>
  );
}

function Provenance({ messageId }: { messageId: string }) {
  const q = useMessageProvenance(messageId);
  if (q.isPending) return <p className="text-muted-foreground">Reading provenance…</p>;
  if (q.isError)
    return (
      <p className="text-muted-foreground">
        {q.error.isNotImplemented ? "Provenance arm not reachable." : q.error.message}
      </p>
    );
  const p = q.data;
  if (!p) return null;
  return (
    <dl className="grid gap-x-4 gap-y-1 text-[11px] md:grid-cols-2">
      <Row k="Sent by" v={p.sent_by ?? "unknown"} />
      <Row k="Sent at (UTC)" v={p.sent_at_utc} />
      <Row k="Transport" v={p.transport_label} />
      <Row k="Device" v={p.device_label ?? "not recorded"} />
      <Row k="Workspace" v={p.workspace ?? "not recorded"} />
      <Row k="Sequence" v={`#${p.seq}`} />
      <p className="mt-1 flex items-center gap-1 text-muted-foreground md:col-span-2">
        <ShieldCheck className="size-3" /> Sealed per-conversation hash chain — edits after sealing
        show up as breaks, never silently.
      </p>
    </dl>
  );
}

function Row({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex justify-between gap-2 border-b border-border/60 py-0.5">
      <dt className="text-muted-foreground">{k}</dt>
      <dd className="truncate text-foreground">{v}</dd>
    </div>
  );
}
