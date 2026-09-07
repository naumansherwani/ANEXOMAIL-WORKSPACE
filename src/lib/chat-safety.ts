/**
 * ANEXOCHAT — PHASE 19/20/21/22 client
 *
 *   19 Device Safety Vault   — signals minimize → hash → sealed vault
 *   20 Device Trust          — dekho, aur ek click mein access maar do
 *   21 Safety Reporting      — new → under_review → action → resolved
 *   22 Work Execution Chain  — message → work → owner → dependency →
 *                              deadline → completion → evidence
 *
 * PRIMARY = Rust /rpc/chat.* (WebTransport/QUIC ke saath), Bun sirf fallback.
 * Koi cheez local storage mein "sach" ban kar nahi baithti: har state DB row hai.
 * Client kabhi canvas/audio/font fingerprint nahi bhejta — sirf 5 coarse signals.
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { chatCall } from "@/lib/chat-transport";

/* ── Phase 19/20 ───────────────────────────────────────────────────── */

export type VaultDevice = {
  device_hash: string;
  label: string;
  platform_class: string | null;
  browser_class: string | null;
  state: "trusted" | "pending" | "suspicious" | "revoked" | "banned";
  reasons: string[];
  registrations: number;
  first_seen_at: string;
  last_seen_at: string;
  retain_until: string;
};

export type VaultPolicy = {
  retain_days: number;
  signals_collected: string[];
  legal_basis: string;
  purpose: string;
  biometric: boolean;
  purged_at: string | null;
};

export const VAULT_TONE: Record<VaultDevice["state"], string> = {
  trusted: "text-emerald-400",
  pending: "text-muted-foreground",
  suspicious: "text-amber-400",
  revoked: "text-steel",
  banned: "text-red-400",
};

/** MINIMIZATION: sirf yeh paanch signals — koi silent fingerprinting nahi. */
export function collectDeviceSignals() {
  if (typeof window === "undefined") return {};
  const w = Math.round(window.screen.width / 320) * 320;
  const h = Math.round(window.screen.height / 320) * 320;
  return {
    ua: navigator.userAgent,
    tz_offset_minutes: -new Date().getTimezoneOffset(),
    screen_bucket: `${w}x${h}`,
    language: navigator.language,
  };
}

export function useDeviceTrust(enabled = true) {
  return useQuery<{ devices: VaultDevice[]; policy: VaultPolicy }, ApiError>({
    queryKey: ["chat", "device", "trust"],
    queryFn: () =>
      chatCall("chat.device.trust.list", undefined, { path: "/api/chat/device/trust" }),
    enabled,
    retry: false,
  });
}

export function useRegisterDevice() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; state?: string; reasons?: string[]; error?: string },
    ApiError,
    void
  >({
    mutationFn: () => {
      const body = { signals: collectDeviceSignals() };
      return chatCall("chat.device.vault", body, {
        path: "/api/chat/device/vault",
        method: "POST",
        body,
      });
    },
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "device", "trust"] }),
  });
}

export function useSetDeviceTrust() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; state: string; sessions_killed: number },
    ApiError,
    { device_hash: string; state: "trusted" | "suspicious" | "revoked" }
  >({
    mutationFn: (input) =>
      chatCall("chat.device.trust.set", input, {
        path: "/api/chat/device/trust",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "device", "trust"] }),
  });
}

/* ── Phase 21 ──────────────────────────────────────────────────────── */

export type ReportReason =
  | "spam"
  | "harassment"
  | "threat"
  | "illegal_content"
  | "malware"
  | "impersonation"
  | "other";

export const REPORT_REASONS: { id: ReportReason; label: string }[] = [
  { id: "spam", label: "Spam" },
  { id: "harassment", label: "Harassment" },
  { id: "threat", label: "Threat or violence" },
  { id: "illegal_content", label: "Illegal content" },
  { id: "malware", label: "Malware or dangerous file" },
  { id: "impersonation", label: "Impersonation" },
  { id: "other", label: "Something else" },
];

export type SafetyReport = {
  id: string;
  subject_kind: "message" | "person" | "file" | "conversation";
  reason: ReportReason;
  severity: number;
  state: "new" | "under_review" | "action" | "resolved";
  conversation_id: string | null;
  reporter: string;
  subject: string;
  note: string | null;
  evidence_sealed: boolean;
  evidence_hash: string | null;
  assigned_to: string | null;
  created_at: string;
  updated_at: string;
  outcome: string | null;
};

export const REPORT_FLOW = ["new", "under_review", "action", "resolved"] as const;

export function nextReportState(state: SafetyReport["state"]) {
  const i = REPORT_FLOW.indexOf(state);
  return i >= 0 && i < REPORT_FLOW.length - 1 ? REPORT_FLOW[i + 1]! : null;
}

export function useReportSubject() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; report_id?: string; error?: string; notice?: string },
    ApiError,
    {
      subject_kind: SafetyReport["subject_kind"];
      subject_id: string;
      reason: ReportReason;
      note?: string | undefined;
    }
  >({
    mutationFn: (input) =>
      chatCall("chat.safety.report", input, {
        path: "/api/chat/safety/report",
        method: "POST",
        body: input,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["chat", "safety"] });
    },
  });
}

export function useSafetyStanding() {
  return useQuery<
    {
      reports_filed: number;
      open_reports: number;
      enforcement: { action: string; reason: string; until: string | null; at: string }[];
      can_review: boolean;
    },
    ApiError
  >({
    queryKey: ["chat", "safety", "standing"],
    queryFn: () =>
      chatCall("chat.safety.standing", undefined, { path: "/api/chat/safety/standing" }),
    retry: false,
  });
}

export function useSafetyQueue(state?: SafetyReport["state"] | "all") {
  const q = state && state !== "all" ? state : undefined;
  return useQuery<
    { ok: boolean; reports: SafetyReport[]; counts: Record<string, number> | null; error?: string },
    ApiError
  >({
    queryKey: ["chat", "safety", "queue", q ?? "all"],
    queryFn: () =>
      chatCall(
        "chat.safety.queue",
        { state: q ?? "" },
        { path: `/api/chat/safety/queue${q ? `?state=${q}` : ""}` },
      ),
    retry: false,
  });
}

export function useAdvanceReport() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; state: string },
    ApiError,
    {
      report_id: string;
      to_state: SafetyReport["state"];
      note?: string | undefined;
      action?: string | undefined;
      until?: string | null | undefined;

    }
  >({
    mutationFn: (input) =>
      chatCall("chat.safety.advance", input, {
        path: "/api/chat/safety/advance",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "safety"] }),
  });
}

/** Sealed evidence kholna = audit row. Bina wajah kholna mumkin nahi. */
export function useRevealEvidence() {
  return useMutation<
    { ok: boolean; evidence: string | null; evidence_hash: string | null; logged?: boolean },
    ApiError,
    { report_id: string; justification: string }
  >({
    mutationFn: (input) =>
      chatCall("chat.safety.reveal", input, {
        path: "/api/chat/safety/reveal",
        method: "POST",
        body: input,
      }),
  });
}

/* ── Phase 22 ──────────────────────────────────────────────────────── */

export type WorkSuggestion = {
  message_id: string;
  conversation_id: string;
  kind: "task" | "promise" | "decision";
  title: string;
  owner_user_id: string | null;
  owner_name: string | null;
  due_at: string | null;
  due_phrase: string | null;
  source: string;
  deterministic: boolean;
};

export type WorkBoardItem = {
  id: string;
  kind: "task" | "promise" | "decision";
  title: string;
  state: "open" | "blocked" | "done" | "cancelled";
  owner_user_id: string | null;
  due_at: string | null;
  depends_on: string | null;
  conversation_id: string;
  message_id: string | null;
  completed_at: string | null;
  overdue: boolean;
  evidence_count: number;
};

export type WorkChain = {
  item: {
    id: string;
    kind: string;
    title: string;
    state: string;
    owner_user_id: string | null;
    created_by: string;
    created_at: string;
    due_at: string | null;
    depends_on: string | null;
    completed_by: string | null;
    completed_at: string | null;
    retention_class: string;
  };
  source_message: { id?: string; seq?: number; sent_at?: string; visible: boolean; body: string | null };
  provenance: Record<string, unknown>;
  parsed: Record<string, unknown>;
  dependency: { id: string; title: string; state: string } | null;
  evidence: { kind: string; ref: string; sha256: string | null; at: string }[];
  events: { action: string; from_state: string | null; to_state: string | null; at: string }[];
  chain_intact: boolean;
};

export function useWorkSuggestion(messageId: string | null) {
  return useQuery<WorkSuggestion, ApiError>({
    queryKey: ["chat", "work", "suggest", messageId],
    queryFn: () =>
      chatCall(
        "chat.work.suggest",
        { message_id: messageId },
        { path: `/api/chat/work/suggest?message_id=${encodeURIComponent(messageId!)}` },
      ),
    enabled: Boolean(messageId),
    retry: false,
  });
}

export function useWorkBoard(enabled = true) {
  return useQuery<
    { items: WorkBoardItem[]; plan: { plan: string; allowed: boolean; limit: number | null } },
    ApiError
  >({
    queryKey: ["chat", "work", "board"],
    queryFn: () => chatCall("chat.work.board", undefined, { path: "/api/chat/work/board" }),
    enabled,
    retry: false,
    refetchInterval: 20_000,
  });
}

export function useWorkChain(itemId: string | null) {
  return useQuery<WorkChain, ApiError>({
    queryKey: ["chat", "work", "chain", itemId],
    queryFn: () =>
      chatCall(
        "chat.work.chain",
        { item_id: itemId },
        { path: `/api/chat/work/chain?item_id=${encodeURIComponent(itemId!)}` },
      ),
    enabled: Boolean(itemId),
    retry: false,
  });
}

export function useWorkFromMessage() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; item_id?: string; error?: string; plan?: string; limit?: number },
    ApiError,
    {
      message_id: string;
      kind?: string | undefined;
      title?: string | undefined;
      owner_user_id?: string | null | undefined;
      due_at?: string | null | undefined;
    }
  >({
    mutationFn: (input) =>
      chatCall("chat.work.from_message", input, {
        path: "/api/chat/work/from-message",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "work"] }),
  });
}

export function useWorkDepend() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; error?: string },
    ApiError,
    { item_id: string; depends_on: string }
  >({
    mutationFn: (input) =>
      chatCall("chat.work.depend", input, {
        path: "/api/chat/work/depend",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "work"] }),
  });
}

/** Evidence ke bina completion namumkin — server hi mana kar deta hai. */
export function useCompleteWork() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; error?: string; message?: string; evidence_count?: number },
    ApiError,
    { item_id: string; evidence?: { kind: "file" | "link" | "note" | "message"; ref: string } | undefined }
  >({
    mutationFn: (input) =>
      chatCall("chat.work.complete", input, {
        path: "/api/chat/work/complete",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "work"] }),
  });
}

/* ── messenger basics ──────────────────────────────────────────────── */

export function useStarMessage() {
  const qc = useQueryClient();
  return useMutation<{ ok: boolean; starred: boolean }, ApiError, { message_id: string }>({
    mutationFn: (input) =>
      chatCall("chat.message.star", input, {
        path: "/api/chat/messages/star",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "messages"] }),
  });
}

export function useForwardMessage() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; to_conversation: string },
    ApiError,
    { message_id: string; to_conversation_id: string }
  >({
    mutationFn: (input) =>
      chatCall("chat.message.forward", input, {
        path: "/api/chat/messages/forward",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat"] }),
  });
}
