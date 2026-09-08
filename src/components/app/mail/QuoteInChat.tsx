import { Quote } from "lucide-react";
import { useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";

import {
  useDiscussInChat,
  useEmailThreadConversation,
  useQuoteEmailInChat,
} from "@/lib/chat-email-bridge";
import { chatCall } from "@/lib/chat-transport";
import { deviceLabel } from "@/lib/chat";
import { notify } from "@/lib/notify";

/**
 * Phase 29 — quote email in chat. User email body mein text select karta hai,
 * "Quote in chat" dabata hai: (1) linked conversation (reuse ya open),
 * (2) ASLI chat message `chat.send` se banta hai, (3) `email_quote_to_chat`
 * usi message id + mail thread + selected text ka SHA256 seal likhta hai.
 * Selection na ho to button disabled — koi text invent nahi hota.
 */
export function QuoteInChat({
  threadId,
  mailMessageId,
  containerRef,
}: {
  threadId: string;
  mailMessageId: string;
  containerRef: React.RefObject<HTMLElement | null>;
}) {
  const navigate = useNavigate();
  const link = useEmailThreadConversation(threadId);
  const discuss = useDiscussInChat();
  const quote = useQuoteEmailInChat();
  const [selected, setSelected] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const read = () => {
      const sel = typeof window !== "undefined" ? window.getSelection() : null;
      const root = containerRef.current;
      if (!sel || sel.isCollapsed || !root || !sel.anchorNode || !root.contains(sel.anchorNode)) {
        return;
      }
      setSelected(sel.toString().trim().slice(0, 4000));
    };
    document.addEventListener("selectionchange", read);
    return () => document.removeEventListener("selectionchange", read);
  }, [containerRef]);

  const run = async () => {
    if (!selected) return;
    setBusy(true);
    try {
      let conversationId = link.data?.linked ? link.data.conversation_id : undefined;
      if (!conversationId) {
        const r = await discuss.mutateAsync({ mail_thread_id: threadId });
        conversationId = r.conversation_id;
        if (!conversationId) {
          notify.failed(r.error ?? "Could not link a chat to this thread");
          return;
        }
      }
      const body = `> ${selected.replace(/\n/g, "\n> ")}`;
      const clientMsgId = crypto.randomUUID();
      const sent = await chatCall<{ id: string }>(
        "chat.send",
        {
          conversation_id: conversationId,
          client_msg_id: clientMsgId,
          body,
          device: deviceLabel(),
          reply_to_id: null,
        },
        {
          path: "/api/chat/messages",
          method: "POST",
          body: {
            conversation_id: conversationId,
            client_msg_id: clientMsgId,
            body,
            device: deviceLabel(),
            reply_to_id: null,
          },
        },
      );
      const q = await quote.mutateAsync({
        message_id: sent.id,
        mail_thread_id: threadId,
        quoted_text: selected,
        mail_message_id: mailMessageId,
      });
      if (q.ok === false || q.error) {
        notify.failed(q.error ?? "Quote seal refused", {
          description: "Message was posted, but the email quote link was not recorded.",
        });
        return;
      }
      notify.done("Quoted in chat", q.quoted_hash ? `Sealed ${q.quoted_hash.slice(0, 12)}…` : undefined);
      void navigate({ to: "/app/chat", search: { c: conversationId } as never });
    } catch (e) {
      const err = e as { isNotImplemented?: boolean; message?: string };
      notify.failed(err.isNotImplemented ? "Not wired yet" : "Quote failed", {
        description: err.isNotImplemented ? "Waiting on chat.send / chat.bridge.quote." : err.message,
      });
    } finally {
      setBusy(false);
    }
  };

  return (
    <button
      type="button"
      disabled={!selected || busy}
      title={selected ? "Post the selected text into the linked chat" : "Select text in this message first"}
      className="ax-press rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground disabled:opacity-50"
      onClick={run}
    >
      <Quote className="mr-1 inline size-3" />
      {busy ? "Quoting…" : selected ? `Quote in chat (${selected.length})` : "Quote in chat"}
    </button>
  );
}
