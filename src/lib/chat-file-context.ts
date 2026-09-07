/**
 * PHASE 31 (ANEXOChat) — FILE CONTEXT + RELATIONSHIP GRAPH · client transport.
 *
 * PRIMARY = Rust /rpc/file.context.* (:3200 + QUIC/WT); Bun /api/chat/file/context/*
 * sirf fallback. Truth Supabase #4 mein.
 *
 * LOCKED: engine koi link invent nahi karti (`engine_invents_nothing`),
 * diff deterministic line-presence hai (`ai_used: false`), aur har link/unlink
 * insaani 8+ char wajah ke saath append-only log mein jata hai.
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { chatCall } from "@/lib/chat-transport";

export type FileLinkObject =
  | "work_item"
  | "decision"
  | "promise"
  | "mail_thread"
  | "message"
  | "person"
  | "company";

export type FileLink = {
  id: string;
  object_type: FileLinkObject;
  object_id: string;
  label: string | null;
  reason: string;
  linked_by: string;
  linked_at: string;
};

export type ContextCard = {
  allowed?: boolean;
  found?: boolean;
  reason?: string;
  engine_invents_nothing?: boolean;
  file?: {
    id: string;
    name: string;
    content_type: string | null;
    current_version: number;
    latest_bytes: number | null;
    updated_at: string;
  };
  uploader?: { user_id: string; at: string; version: number; sha256: string | null } | null;
  conversation?: { id: string; title: string | null } | null;
  evidence?: { state: string; actor: string | null; at: string }[];
  links?: FileLink[];
  related_work?: {
    work_id: string;
    kind: string;
    title: string;
    status: string;
    owner_id: string | null;
    due_at: string | null;
  }[];
};

export function useFileContext(fileId: string | null) {
  return useQuery<ContextCard, ApiError>({
    queryKey: ["chat", "file-context", "card", fileId],
    queryFn: () =>
      chatCall(
        "file.context.card",
        { file_id: fileId },
        { path: `/api/chat/file/context/${fileId}` },
      ),
    enabled: !!fileId,
    retry: false,
  });
}

export type Duplicates = {
  allowed?: boolean;
  found?: boolean;
  reason?: string;
  sha256?: string | null;
  match_basis?: string;
  pool_saving_bytes?: number;
  duplicates?: {
    file_id: string;
    name: string;
    conversation_id: string | null;
    version: number;
    bytes: number;
    uploaded_by: string | null;
    uploaded_at: string;
  }[];
};

export function useFileDuplicates(fileId: string | null) {
  return useQuery<Duplicates, ApiError>({
    queryKey: ["chat", "file-context", "duplicates", fileId],
    queryFn: () =>
      chatCall(
        "file.context.duplicates",
        { file_id: fileId },
        { path: `/api/chat/file/context/${fileId}/duplicates` },
      ),
    enabled: !!fileId,
    retry: false,
  });
}

export type StaleCheck = {
  allowed?: boolean;
  found?: boolean;
  reason?: string;
  current_version?: number;
  current_version_at?: string | null;
  flags?: {
    decision_id: string;
    decision_title: string;
    decision_version: number;
    decided_at: string;
    file_version: number;
    file_version_at: string | null;
    stale: boolean;
    evidence: {
      link_reason: string | null;
      linked_by: string | null;
      linked_at: string | null;
      decision_body_hash: string | null;
    };
  }[];
};

export function useFileStale(fileId: string | null) {
  return useQuery<StaleCheck, ApiError>({
    queryKey: ["chat", "file-context", "stale", fileId],
    queryFn: () =>
      chatCall(
        "file.context.stale",
        { file_id: fileId },
        { path: `/api/chat/file/context/${fileId}/stale` },
      ),
    enabled: !!fileId,
    retry: false,
  });
}

export type FileGraph = {
  allowed?: boolean;
  found?: boolean;
  reason?: string;
  engine_invents_edges?: boolean;
  nodes?: { type: string; id: string; label: string }[];
  edges?: {
    from: string;
    to: string;
    kind: string;
    source?: string;
    reason?: string | null;
    linked_by?: string | null;
    recorded: boolean;
  }[];
};

export function useFileGraph(fileId: string | null, enabled = true) {
  return useQuery<FileGraph, ApiError>({
    queryKey: ["chat", "file-context", "graph", fileId],
    queryFn: () =>
      chatCall(
        "file.context.graph",
        { file_id: fileId },
        { path: `/api/chat/file/context/${fileId}/graph` },
      ),
    enabled: !!fileId && enabled,
    retry: false,
  });
}

export type VersionDiff = {
  allowed?: boolean;
  diff_available?: boolean;
  reason?: string;
  diff_method?: string;
  ai_used?: boolean;
  from?: { version: number; lines: number; sha256: string; sent_in_message: string | null };
  to?: { version: number; lines: number; sha256: string; sent_in_message: string | null };
  unchanged_lines?: number;
  added?: string[] | null;
  removed?: string[] | null;
  truncated?: boolean;
  line_cap?: number;
};

export function useVersionDiff(fileId: string | null, from: number | null, to: number | null) {
  return useQuery<VersionDiff, ApiError>({
    queryKey: ["chat", "file-context", "diff", fileId, from, to],
    queryFn: () =>
      chatCall(
        "file.context.diff",
        { file_id: fileId, from, to },
        { path: `/api/chat/file/context/${fileId}/diff?from=${from}&to=${to}` },
      ),
    enabled: !!fileId && from != null && to != null,
    retry: false,
  });
}

export function useFileLink() {
  const qc = useQueryClient();
  return useMutation<
    { ok?: boolean; reason?: string; link_id?: string },
    ApiError,
    {
      file_id: string;
      object_type: FileLinkObject;
      object_id: string;
      reason: string;
      label?: string;
    }
  >({
    mutationFn: (input) =>
      chatCall("file.context.link", input, {
        path: "/api/chat/file/context/link",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "file-context"] }),
  });
}

export function useFileUnlink() {
  const qc = useQueryClient();
  return useMutation<
    { ok?: boolean; reason?: string; removed?: boolean },
    ApiError,
    { link_id: string; reason: string }
  >({
    mutationFn: (input) =>
      chatCall("file.context.unlink", input, {
        path: "/api/chat/file/context/unlink",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "file-context"] }),
  });
}
