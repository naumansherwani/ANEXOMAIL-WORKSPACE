/**
 * ANEXOChat · PHASE 11 — IMAGE / SCREENSHOT ATTACHMENTS
 *
 * FOUNDER LOCK:
 *   - Drag-drop + Ctrl/Cmd+V paste. Har file ka apna asli progress (XHR),
 *     fake "100%" kabhi nahi.
 *   - EXIF strip client par: canvas se re-encode hota hai, GPS/camera metadata
 *     saath nahi jata. Thumbnail bhi client par banta hai (fast open).
 *   - Upload ticket backend se aata hai (`chat.attachment.ticket`), signed
 *     URL par seedha Supabase Storage — service key browser par kabhi nahi.
 *   - Row commit ke baad hi attachment message ke saath dikhata hai.
 */
import { chatCall } from "@/lib/chat-transport";

export const MAX_BYTES = 25 * 1024 * 1024; // 25 MB per image
const THUMB_EDGE = 320;

export type UploadState = "preparing" | "uploading" | "committing" | "done" | "failed";

export type Upload = {
  id: string;
  name: string;
  bytes: number;
  progress: number; // asli 0-100 XHR reading
  state: UploadState;
  error: string | null;
  attachment_id: string | null;
  preview_url: string | null;
  width: number | null;
  height: number | null;
};

export type ChatAttachment = {
  id: string;
  message_id: string | null;
  url: string;
  thumb_url: string | null;
  width: number | null;
  height: number | null;
  bytes: number;
  content_type: string;
  filename: string;
};

type Ticket = {
  attachment_id: string;
  upload_url: string;
  thumb_upload_url: string | null;
  path: string;
};

export function isImage(file: File): boolean {
  return /^image\/(png|jpe?g|webp|gif|avif)$/i.test(file.type);
}

/** Canvas re-encode = EXIF/GPS gone. Pixels wahi, metadata nahi. */
async function decode(file: File): Promise<{ bitmap: ImageBitmap; width: number; height: number }> {
  const bitmap = await createImageBitmap(file);
  return { bitmap, width: bitmap.width, height: bitmap.height };
}

async function toBlob(bitmap: ImageBitmap, maxEdge: number | null, type: string): Promise<Blob> {
  const scale = maxEdge ? Math.min(1, maxEdge / Math.max(bitmap.width, bitmap.height)) : 1;
  const w = Math.max(1, Math.round(bitmap.width * scale));
  const h = Math.max(1, Math.round(bitmap.height * scale));
  const canvas = document.createElement("canvas");
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("This browser could not process the image.");
  ctx.drawImage(bitmap, 0, 0, w, h);
  return await new Promise<Blob>((resolve, reject) =>
    canvas.toBlob(
      (b) => (b ? resolve(b) : reject(new Error("Image could not be re-encoded."))),
      type,
      0.92,
    ),
  );
}

/** Asli per-file progress ke liye XHR (fetch stream upload har browser par nahi). */
function put(url: string, blob: Blob, onProgress: (pct: number) => void): Promise<void> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open("PUT", url, true);
    xhr.setRequestHeader("content-type", blob.type || "application/octet-stream");
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) onProgress(Math.round((e.loaded / e.total) * 100));
    };
    xhr.onload = () =>
      xhr.status >= 200 && xhr.status < 300
        ? resolve()
        : reject(new Error(`Upload failed (${xhr.status})`));
    xhr.onerror = () => reject(new Error("Upload failed — network dropped."));
    xhr.send(blob);
  });
}

export async function uploadImage(
  conversationId: string,
  file: File,
  onChange: (patch: Partial<Upload>) => void,
): Promise<string | null> {
  if (!isImage(file)) {
    onChange({ state: "failed", error: "Only PNG, JPEG, WebP, GIF or AVIF images." });
    return null;
  }
  if (file.size > MAX_BYTES) {
    onChange({ state: "failed", error: "Image is larger than 25 MB." });
    return null;
  }

  try {
    onChange({ state: "preparing", progress: 0 });
    const { bitmap, width, height } = await decode(file);
    const type = file.type === "image/gif" ? "image/png" : file.type;
    const clean = await toBlob(bitmap, null, type); // EXIF strip
    const thumb = await toBlob(bitmap, THUMB_EDGE, "image/webp");
    bitmap.close?.();

    const payload = {
      conversation_id: conversationId,
      filename: file.name,
      content_type: type,
      bytes: clean.size,
      width,
      height,
    };
    const ticket = await chatCall<Ticket>("chat.attachment.ticket", payload, {
      path: "/api/chat/attachments/ticket",
      method: "POST",
      body: payload,
    });

    onChange({
      state: "uploading",
      attachment_id: ticket.attachment_id,
      width,
      height,
      preview_url: URL.createObjectURL(thumb),
    });

    await put(ticket.upload_url, clean, (pct) => onChange({ progress: pct }));
    if (ticket.thumb_upload_url) {
      await put(ticket.thumb_upload_url, thumb, () => {}).catch(() => {});
    }

    onChange({ state: "committing", progress: 100 });
    const commit = { attachment_id: ticket.attachment_id, width, height };
    await chatCall<{ ok: boolean }>("chat.attachment.commit", commit, {
      path: "/api/chat/attachments/commit",
      method: "POST",
      body: commit,
    });
    onChange({ state: "done" });
    return ticket.attachment_id;
  } catch (error) {
    onChange({ state: "failed", error: (error as Error).message });
    return null;
  }
}

/** Profile picture — wahi honest pipeline, alag ticket. */
export async function uploadAvatar(
  file: File,
  onChange: (patch: Partial<Upload>) => void,
): Promise<string | null> {
  if (!isImage(file)) {
    onChange({ state: "failed", error: "Please choose an image." });
    return null;
  }
  try {
    onChange({ state: "preparing", progress: 0 });
    const { bitmap } = await decode(file);
    const square = await toBlob(bitmap, 512, "image/webp");
    bitmap.close?.();
    const ticket = await chatCall<{ upload_url: string; path: string }>(
      "chat.avatar.ticket",
      { content_type: "image/webp", bytes: square.size },
      {
        path: "/api/chat/profile/avatar/ticket",
        method: "POST",
        body: { content_type: "image/webp", bytes: square.size },
      },
    );
    onChange({ state: "uploading" });
    await put(ticket.upload_url, square, (pct) => onChange({ progress: pct }));
    onChange({ state: "committing", progress: 100 });
    const res = await chatCall<{ avatar_url: string }>(
      "chat.avatar.commit",
      { path: ticket.path },
      { path: "/api/chat/profile/avatar/commit", method: "POST", body: { path: ticket.path } },
    );
    onChange({ state: "done" });
    return res.avatar_url;
  } catch (error) {
    onChange({ state: "failed", error: (error as Error).message });
    return null;
  }
}

export function newUpload(file: File): Upload {
  return {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    name: file.name,
    bytes: file.size,
    progress: 0,
    state: "preparing",
    error: null,
    attachment_id: null,
    preview_url: null,
    width: null,
    height: null,
  };
}

export function filesFromPaste(e: ClipboardEvent): File[] {
  const items = Array.from(e.clipboardData?.items ?? []);
  return items
    .filter((i) => i.kind === "file")
    .map((i) => i.getAsFile())
    .filter((f): f is File => Boolean(f && isImage(f)));
}
