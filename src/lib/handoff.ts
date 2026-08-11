/**
 * Phase 28 — Cross-Platform: device handoff.
 *
 * A draft (and its cursor position) lives in Supabase 4 through the backend,
 * so a mail started on desktop opens on the phone at the same character.
 * NO DUPLICATE rule: the browser stores nothing but the device identity.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api, type ApiError } from "@/lib/api";

const DEVICE_KEY = "ax.device.id";

export function deviceId(): string {
  if (typeof window === "undefined") return "ssr";
  let id = window.localStorage.getItem(DEVICE_KEY);
  if (!id) {
    id = crypto.randomUUID();
    window.localStorage.setItem(DEVICE_KEY, id);
  }
  return id;
}

export function deviceLabel(): string {
  if (typeof navigator === "undefined") return "Unknown device";
  const ua = navigator.userAgent;
  const kind = /iPhone|Android.*Mobile/.test(ua)
    ? "Phone"
    : /iPad|Tablet|Android/.test(ua)
      ? "Tablet"
      : "Desktop";
  const os = /Mac/.test(ua)
    ? "macOS"
    : /Windows/.test(ua)
      ? "Windows"
      : /Android/.test(ua)
        ? "Android"
        : /iPhone|iPad/.test(ua)
          ? "iOS"
          : "Linux";
  return `${kind} · ${os}`;
}

export type HandoffDraft = {
  id: string;
  device_id: string;
  device_label: string;
  thread_id: string | null;
  to_address: string | null;
  subject: string | null;
  body: string | null;
  cursor_position: number;
  updated_at: string;
};

export function useHandoffDrafts(enabled = true) {
  return useQuery<{ drafts: HandoffDraft[] }, ApiError>({
    queryKey: ["handoff", "drafts"],
    queryFn: () => api<{ drafts: HandoffDraft[] }>("/api/mail/handoff"),
    enabled,
    retry: false,
    refetchInterval: 20_000,
    staleTime: 10_000,
  });
}

export type HandoffSave = {
  thread_id?: string | null;
  to_address?: string | null;
  subject?: string | null;
  body: string;
  cursor_position: number;
};

export function useSaveHandoff() {
  const qc = useQueryClient();
  return useMutation<{ id: string }, ApiError, HandoffSave>({
    mutationFn: (payload) =>
      api<{ id: string }>("/api/mail/handoff", {
        method: "POST",
        body: JSON.stringify({
          ...payload,
          device_id: deviceId(),
          device_label: deviceLabel(),
        }),
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["handoff", "drafts"] }),
  });
}

export function useClaimHandoff() {
  const qc = useQueryClient();
  return useMutation<HandoffDraft, ApiError, { id: string }>({
    mutationFn: ({ id }) =>
      api<HandoffDraft>(`/api/mail/handoff/${id}/claim`, {
        method: "POST",
        body: JSON.stringify({ device_id: deviceId(), device_label: deviceLabel() }),
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["handoff", "drafts"] }),
  });
}