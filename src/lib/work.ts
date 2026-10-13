/**
 * Work — thread-level Tasks & Notes (Step 6, Rust-only /rpc/work.*).
 * Pro+ feature: Rust returns 403 "feature_not_available" for Basic plan.
 * NO MOCK rule: nothing faked here — errors surface honestly.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { ApiError } from "@/lib/api";
import { rpc } from "@/lib/rpc";

export type WorkTask = {
  id: string;
  org_id: string;
  thread_id: string | null;
  title: string;
  status: "todo" | "doing" | "waiting" | "done";
  owner: string | null;
  created_by: string;
  created_at: string;
  due_at: string | null;
  completed_at: string | null;
};

export type WorkNote = {
  id: string;
  org_id: string;
  thread_id: string | null;
  body: string;
  updated_by: string;
  updated_at: string;
};

/** Thread ke tasks laata hai. Basic plan par Rust 403 dega — component handle karega. */
export function useThreadTasks(threadId: string | undefined) {
  return useQuery<WorkTask[], ApiError>({
    queryKey: ["work", "tasks", threadId],
    queryFn: () => rpc<WorkTask[]>("work.tasks.list", { thread_id: threadId }),
    enabled: Boolean(threadId),
    retry: false,
  });
}

/** Thread ka note laata hai (ek thread = ek note, upsert semantics). */
export function useThreadNote(threadId: string | undefined) {
  return useQuery<WorkNote[], ApiError>({
    queryKey: ["work", "notes", threadId],
    queryFn: () => rpc<WorkNote[]>("work.notes.list", { thread_id: threadId }),
    enabled: Boolean(threadId),
    retry: false,
  });
}

export function useCreateTask(threadId: string) {
  const qc = useQueryClient();
  return useMutation<WorkTask, ApiError, { title: string }>({
    mutationFn: ({ title }) => rpc<WorkTask>("work.tasks.create", { title, thread_id: threadId }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["work", "tasks", threadId] });
    },
  });
}

export function useUpdateTaskStatus(threadId: string) {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { id: string; status: WorkTask["status"] }>({
    mutationFn: ({ id, status }) => rpc("work.tasks.update", { id, status }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["work", "tasks", threadId] });
    },
  });
}

export function useUpsertNote(threadId: string) {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { body: string }>({
    mutationFn: ({ body }) => rpc("work.notes.upsert", { thread_id: threadId, body }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["work", "notes", threadId] });
    },
  });
}
