/**
 * Founder Command Deck + AI Email Center — Founder surface.
 *
 * NO DUPLICATE rule: mailbox provisioning, DNS/DKIM checks, agent routing,
 * Leo drafts and Jimmy escalations ALL live on the server (Server 2 -> Supabase 4).
 * This file speaks transport only.
 * NO MOCK rule: a missing endpoint surfaces as an honest "not wired" state.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

/* ------------------------------------------------------------------ types */

export type MailboxKind = "founder" | "agent" | "industry" | "support" | "system";

export type FounderMailbox = {
  address: string;
  display_name: string | null;
  kind: MailboxKind;
  domain: string;
  /** Server truth: mailbox exists in Postfix/Dovecot and Supabase. */
  provisioned: boolean;
  /** DKIM/SPF/DMARC verdict for this mailbox's domain. */
  dns_ok: boolean;
  /** Which AI owns replies for this address, if any. */
  agent: string | null;
  aliases: string[];
  messages_total: number;
  last_message_at: string | null;
};

export type AiAgent = {
  id: string;
  name: string;
  role: string;
  address: string;
  reports_to: string | null;
  /** "live" only when the server can actually route mail to this agent. */
  status: "live" | "provisioning" | "offline";
  model: string | null;
  drafts_pending: number;
  replies_sent: number;
  avg_reply_seconds: number | null;
  escalations: number;
};

export type AiMailItem = {
  id: string;
  agent: string;
  from_address: string;
  to_address: string;
  subject: string;
  preview: string;
  /** Server-side confidence gate: low confidence never auto-sends. */
  confidence: number | null;
  state: "draft" | "sent" | "escalated" | "held";
  escalated_to: string | null;
  created_at: string;
};

export type FounderOverview = {
  founder_addresses: string[];
  domains: { domain: string; dns_ok: boolean; mailboxes: number }[];
  workspace_host: string | null;
  mailboxes_total: number;
  mailboxes_provisioned: number;
};

/* ------------------------------------------------------------------ reads */

export function useFounderOverview() {
  return useQuery<FounderOverview, ApiError>({
    queryKey: ["founder", "overview"],
    queryFn: () =>
      rpcOrRest<FounderOverview>("founder.overview", { path: "/api/founder/overview" }),
    retry: false,
  });
}

export function useFounderMailboxes() {
  return useQuery<{ mailboxes: FounderMailbox[] }, ApiError>({
    queryKey: ["founder", "mailboxes"],
    queryFn: () =>
      rpcOrRest<{ mailboxes: FounderMailbox[] }>("founder.mailboxes", {
        path: "/api/founder/mailboxes",
      }),
    retry: false,
  });
}

export function useAiAgents() {
  return useQuery<{ agents: AiAgent[] }, ApiError>({
    queryKey: ["founder", "agents"],
    queryFn: () =>
      rpcOrRest<{ agents: AiAgent[] }>("founder.agents", { path: "/api/founder/ai-agents" }),
    retry: false,
  });
}

export function useAiMail(state: AiMailItem["state"] | "all") {
  return useQuery<{ items: AiMailItem[] }, ApiError>({
    queryKey: ["founder", "ai-mail", state],
    queryFn: () =>
      rpcOrRest<{ items: AiMailItem[] }>(
        "founder.aiMail",
        { path: `/api/founder/ai-mail?state=${state}` },
        { state },
      ),
    retry: false,
  });
}

/* --------------------------------------------------------------- mutations */

/** Server creates the mailbox for real (Postfix + Dovecot + Supabase row). */
export function useProvisionMailboxes() {
  const qc = useQueryClient();
  return useMutation<{ created: string[] }, ApiError, { addresses?: string[] }>({
    mutationFn: (input) =>
      rpcOrRest<{ created: string[] }>(
        "founder.provisionMailboxes",
        { path: "/api/founder/mailboxes/provision", method: "POST", body: input },
        input,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["founder"] });
    },
  });
}

/** Approve a Leo/agent draft so the server sends it. */
export function useApproveAiDraft() {
  const qc = useQueryClient();
  return useMutation<{ sent: boolean }, ApiError, { id: string }>({
    mutationFn: (input) =>
      rpcOrRest<{ sent: boolean }>(
        "founder.approveAiDraft",
        { path: "/api/founder/ai-mail/approve", method: "POST", body: input },
        input,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["founder", "ai-mail"] });
    },
  });
}
