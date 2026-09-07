/**
 * PHASE 29 — EMAIL → CHAT · PHASE 30 — CHAT → EMAIL (client transport only).
 *
 * PRIMARY = Rust /rpc/chat.bridge.* | chat.email.* (:3200 + QUIC/WT);
 * Bun /api/chat/bridge/* | /api/chat/email/* sirf fallback.
 *
 * LOCKED TRUTH:
 *  - Email FORMAL RECORD hai, chat instant layer. Chat kabhi apne aap ko formal
 *    record nahi kehta; badge hamesha "Formal record lives in ANEXOMAIL".
 *  - Ek email thread ↔ ek chat conversation ka permanent link; duplicate nahi.
 *  - Quote ke saath asli body ka hash; farq ho to UI sach bolta hai.
 *  - Formal email ki har line par citation: sender · UTC ms · body_hash.
 *  - Jin logon ke messages quote hue unhe notice; objection log hota hai.
 *  - Email banne par chat message par permanent "Escalated to email" marker.
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { chatCall } from "@/lib/chat-transport";

/* ── Phase 29: email → chat ──────────────────────────────────────────── */

export type EmailChatLink = {
  link_id: string;
  mail_thread_id: string;
  mail_message_id: string | null;
  origin: "email_to_chat" | "chat_to_email";
  subject: string | null;
  subject_source: string;
  work_item_id: string | null;
  created_at: string;
};

export type EmailChatContext = {
  conversation_id?: string;
  links?: EmailChatLink[];
  quotes?: {
    quote_id: string;
    message_id: string;
    mail_message_id: string | null;
    quoted_hash: string;
    at: string;
  }[];
  formal_record?: string;
  badge?: string;
  chat_is_formal_record?: boolean;
  error?: string;
};

export function useEmailChatContext(conversationId: string | null) {
  return useQuery<EmailChatContext, ApiError>({
    queryKey: ["chat", "bridge", "context", conversationId],
    queryFn: () =>
      chatCall(
        "chat.bridge.context",
        { conversation_id: conversationId },
        { path: `/api/chat/bridge/context/${conversationId}` },
      ),
    enabled: !!conversationId,
    retry: false,
  });
}

export function useEmailThreadConversation(mailThreadId: string | null) {
  return useQuery<
    {
      linked?: boolean;
      conversation_id?: string;
      link_id?: string;
      work_item_id?: string | null;
      may_open?: boolean;
      note?: string;
    },
    ApiError
  >({
    queryKey: ["chat", "bridge", "thread", mailThreadId],
    queryFn: () =>
      chatCall(
        "chat.bridge.thread",
        { mail_thread_id: mailThreadId },
        { path: `/api/chat/bridge/thread/${mailThreadId}` },
      ),
    enabled: !!mailThreadId,
    retry: false,
  });
}

export function useDiscussInChat() {
  const qc = useQueryClient();
  return useMutation<
    {
      ok?: boolean;
      conversation_id?: string;
      conversation_created?: boolean;
      badge?: string;
      error?: string;
    },
    ApiError,
    {
      mail_thread_id: string;
      mail_message_id?: string;
      conversation_id?: string;
      subject?: string;
    }
  >({
    mutationFn: (input) =>
      chatCall("chat.bridge.discuss", input, {
        path: "/api/chat/bridge/discuss",
        method: "POST",
        body: input,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["chat", "bridge"] });
      void qc.invalidateQueries({ queryKey: ["chat", "conversations"] });
    },
  });
}

export function useDiscussPresence() {
  return useMutation<
    {
      people?: {
        email: string;
        user_id: string | null;
        has_anexochat_account: boolean;
        in_workspace: boolean;
        last_seen_at: string | null;
        presence: string;
      }[];
      error?: string;
    },
    ApiError,
    { emails: string[] }
  >({
    mutationFn: (input) =>
      chatCall("chat.bridge.presence", input, {
        path: "/api/chat/bridge/presence",
        method: "POST",
        body: input,
      }),
  });
}

export function useSilentThreadRescue() {
  const qc = useQueryClient();
  return useMutation<
    { ok?: boolean; conversation_id?: string; work_item_id?: string; error?: string; note?: string },
    ApiError,
    {
      mail_thread_id: string;
      title: string;
      owner_user_id: string;
      due_at: string;
      mail_message_id?: string;
    }
  >({
    mutationFn: (input) =>
      chatCall("chat.bridge.rescue", input, {
        path: "/api/chat/bridge/rescue",
        method: "POST",
        body: input,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["chat", "bridge"] });
      void qc.invalidateQueries({ queryKey: ["chat", "work"] });
    },
  });
}

export function useQuoteEmailInChat() {
  const qc = useQueryClient();
  return useMutation<
    { ok?: boolean; quote_id?: string; quoted_hash?: string; error?: string },
    ApiError,
    { message_id: string; mail_thread_id: string; quoted_text: string; mail_message_id?: string }
  >({
    mutationFn: (input) =>
      chatCall("chat.bridge.quote", input, {
        path: "/api/chat/bridge/quote",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "bridge"] }),
  });
}

/* ── Phase 30: chat → email ──────────────────────────────────────────── */

export type EmailCitation = {
  line_no: number;
  message_id: string;
  sender: string;
  sent_at_ms: string;
  body_hash: string;
  seal_source: string;
};

export type EmailDraft = {
  draft_id?: string;
  conversation_id?: string;
  state?: "draft" | "awaiting_consent" | "sent" | "discarded";
  subject?: string;
  recipients?: string[];
  body?: string;
  decision_id?: string | null;
  mail_message_id?: string | null;
  sent_at?: string | null;
  created_at?: string;
  citations?: EmailCitation[];
  consent?: { user_id: string; person: string; state: string; reason: string | null; at: string }[];
  attachments?: {
    version_id: string;
    filename: string;
    bytes: number;
    version_state: string;
    lineage: { step: string; recorded: boolean; at: string | null; evidence: string }[] | null;
  }[];
  objections?: number;
  formal_record?: string;
  replaces_email?: boolean;
  error?: string;
};

export type EmailDraftBoard = {
  drafts?: {
    draft_id: string;
    conversation_id: string;
    title: string;
    subject: string;
    state: string;
    recipients: string[];
    citations: number;
    objections: number;
    sent_at: string | null;
    created_at: string;
  }[];
  allowed?: boolean;
  formal_record?: string;
  error?: string;
};

export function useEmailDraftBoard(conversationId?: string | null) {
  return useQuery<EmailDraftBoard, ApiError>({
    queryKey: ["chat", "email", "drafts", conversationId ?? "all"],
    queryFn: () =>
      chatCall(
        "chat.email.board",
        conversationId ? { conversation_id: conversationId } : {},
        {
          path: conversationId
            ? `/api/chat/email/drafts?c=${encodeURIComponent(conversationId)}`
            : "/api/chat/email/drafts",
        },
      ),
    retry: false,
  });
}

export function useEmailDraft(draftId: string | null) {
  return useQuery<EmailDraft, ApiError>({
    queryKey: ["chat", "email", "draft", draftId],
    queryFn: () =>
      chatCall(
        "chat.email.get",
        { draft_id: draftId },
        { path: `/api/chat/email/draft/${draftId}` },
      ),
    enabled: !!draftId,
    retry: false,
  });
}

export function useCreateEmailDraft() {
  const qc = useQueryClient();
  return useMutation<
    { ok?: boolean; draft_id?: string; citations?: number; error?: string; note?: string },
    ApiError,
    {
      conversation_id: string;
      subject: string;
      recipients: string[];
      message_ids: string[];
      intro?: string;
    }
  >({
    mutationFn: (input) =>
      chatCall("chat.email.draft", input, {
        path: "/api/chat/email/draft",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "email"] }),
  });
}

export function useEmailDraftConsent() {
  const qc = useQueryClient();
  return useMutation<
    { ok?: boolean; objections?: number; error?: string; note?: string },
    ApiError,
    { draft_id: string; state: "acknowledged" | "objected"; reason?: string }
  >({
    mutationFn: (input) =>
      chatCall("chat.email.consent", input, {
        path: `/api/chat/email/draft/${input.draft_id}/consent`,
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "email"] }),
  });
}

export function useSendEmailDraft() {
  const qc = useQueryClient();
  return useMutation<
    { ok?: boolean; state?: string; mail_message_id?: string; error?: string; note?: string },
    ApiError,
    { draft_id: string; mail_message_id: string }
  >({
    mutationFn: (input) =>
      chatCall("chat.email.send", input, {
        path: `/api/chat/email/draft/${input.draft_id}/send`,
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "email"] }),
  });
}

export function useDecisionToEmail() {
  const qc = useQueryClient();
  return useMutation<
    { ok?: boolean; draft_id?: string; version?: number; error?: string },
    ApiError,
    { decision_id: string }
  >({
    mutationFn: (input) =>
      chatCall("chat.email.decision", input, {
        path: `/api/chat/email/decision/${input.decision_id}`,
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "email"] }),
  });
}

export function useMessageEscalations(messageId: string | null) {
  return useQuery<
    {
      message_id?: string;
      escalations?: {
        draft_id: string;
        at: string;
        state: string;
        subject: string;
        mail_message_id: string | null;
      }[];
      label?: string | null;
      error?: string;
    },
    ApiError
  >({
    queryKey: ["chat", "email", "escalations", messageId],
    queryFn: () =>
      chatCall(
        "chat.email.escalations",
        { message_id: messageId },
        { path: `/api/chat/email/escalations/${messageId}` },
      ),
    enabled: !!messageId,
    retry: false,
  });
}
