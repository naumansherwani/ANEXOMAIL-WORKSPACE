/**
 * Files on a meeting (calendar #5) — client side of the Rust `calendar.files.*` procs (SQL E74).
 *
 * No new storage: the file goes up through the same upload route as mail attachments (type check, virus scan, workspace quota, de-duplication
 * inside the workspace), then is tied to the meeting. The organiser adds and removes; the organiser and the guests who belong to the workspace
 * can see and download. A repeating meeting keeps one set of files for the whole series.
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { BLOCKED_EXT, extOf, fmtBytes } from "@/lib/mail-attachments-core";
import { removeAttachment, uploadAttachment } from "@/lib/mail-attachments";
import { rpc } from "@/lib/rpc";

export type EventFile = {
  id: string;
  filename: string;
  mime_type: string | null;
  size_bytes: number;
  created_at: string;
  can_remove: boolean;
  scanned: boolean;
};

export type EventFiles = { files: EventFile[]; can_add: boolean; max_files: number };

/** Before uploading: can this file go on the meeting? null = fine, otherwise the plain reason to show. Server decides again. */
export function eventFilePrecheck(
  file: { name: string; size: number },
  have: number,
  limits: { max_files: number; cap_bytes?: number },
): string | null {
  if (file.size === 0) return `${file.name} is empty.`;
  if (BLOCKED_EXT.has(extOf(file.name))) {
    return `${file.name}: .${extOf(file.name)} files can't be added because they can run on someone's computer. Put it in a .zip if you really need to share it.`;
  }
  if (have >= limits.max_files)
    return `A meeting can carry up to ${limits.max_files} files. Remove one first.`;
  if (limits.cap_bytes && file.size > limits.cap_bytes) {
    return `${file.name} is ${fmtBytes(file.size)}. A file can be up to ${fmtBytes(limits.cap_bytes)}.`;
  }
  return null;
}

/** The meeting's own id: a repeating meeting's day is "<id>~<epoch>"; files belong to the whole series. */
export function baseEventId(id: string): string {
  const i = id.indexOf("~");
  return i < 0 ? id : id.slice(0, i);
}

const key = (id: string) => ["calendar", "files", baseEventId(id)] as const;

export function useEventFiles(eventId: string, enabled = true) {
  return useQuery<EventFiles, ApiError>({
    queryKey: key(eventId),
    enabled,
    staleTime: 30_000,
    retry: false,
    queryFn: () => rpc<EventFiles>("calendar.files.list", { event_id: baseEventId(eventId) }),
  });
}

export function useAddEventFile(eventId: string) {
  const qc = useQueryClient();
  return useMutation<
    { id: string; filename: string; size_bytes: number },
    ApiError,
    { file: File; onProgress?: (pct: number) => void }
  >({
    mutationFn: async ({ file, onProgress }) => {
      const up = await uploadAttachment(file, { onProgress });
      try {
        return await rpc("calendar.files.attach", {
          event_id: baseEventId(eventId),
          attachment_id: up.id,
        });
      } catch (e) {
        // the upload is staged but never tied: take it back so it does not sit in the user's waiting list
        await removeAttachment(up.id).catch(() => undefined);
        throw e;
      }
    },
    onSettled: () => void qc.invalidateQueries({ queryKey: key(eventId) }),
  });
}

export function useRemoveEventFile(eventId: string) {
  const qc = useQueryClient();
  return useMutation<{ removed: number }, ApiError, { id: string }>({
    mutationFn: ({ id }) => rpc("calendar.files.remove", { event_id: baseEventId(eventId), id }),
    onSettled: () => void qc.invalidateQueries({ queryKey: key(eventId) }),
  });
}
