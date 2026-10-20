/**
 * G38 — bheji jane wali mail ke attachments (browser <-> Rust).
 *   POST {BASE}/file/attach       (raw bytes, progress ke saath)   -> id
 *   GET  {BASE}/file/attach/get   (Bearer; blob se save)
 *   RPC  mail.attach.limits / mail.attach.remove
 * Server hi asli faisla karta hai (type, virus, quota, dedup); qaide `mail-attachments-core.ts`.
 */
import { useQuery } from "@tanstack/react-query";

import { ApiError, sessionToken } from "@/lib/api";
import { rpc } from "@/lib/rpc";
import { attachErrorText, type AttachLimits } from "@/lib/mail-attachments-core";

const BASE = (import.meta.env["VITE_API_URL"] as string | undefined)?.replace(/\/$/, "") ?? "";

export type AttachLimitsResponse = AttachLimits & {
  plan?: string;
  org_limit_bytes?: number;
  org_used_bytes?: number;
  storage_ready?: boolean;
  scanning?: boolean;
};

export function useAttachLimits(enabled = true) {
  return useQuery<AttachLimitsResponse>({
    queryKey: ["mail", "attach-limits"],
    enabled,
    staleTime: 5 * 60_000,
    retry: false,
    queryFn: () => rpc<AttachLimitsResponse>("mail.attach.limits", {}),
  });
}

export type UploadResult = { id: string; filename: string; size_bytes: number; deduped: boolean; scanned: boolean };

/** Ek file upload; progress 0..100. Reject par `ApiError` (message insaani, code server ka). */
export function uploadAttachment(
  file: File,
  opts: { onProgress?: (pct: number) => void; signal?: AbortSignal } = {},
): Promise<UploadResult> {
  return new Promise((resolve, reject) => {
    const token = sessionToken.get();
    if (!token) return reject(new ApiError("Please sign in again.", 401, "unauthorized"));
    const xhr = new XMLHttpRequest();
    xhr.open("POST", `${BASE}/file/attach`);
    xhr.setRequestHeader("authorization", `Bearer ${token}`);
    xhr.setRequestHeader("x-file-name", encodeURIComponent(file.name));
    xhr.setRequestHeader("x-file-type", file.type || "application/octet-stream");
    xhr.responseType = "text";
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable && opts.onProgress) opts.onProgress(Math.min(99, Math.round((e.loaded / e.total) * 100)));
    };
    xhr.onerror = () => reject(new ApiError("Could not reach the server. Check your connection.", 0, "network"));
    xhr.ontimeout = () => reject(new ApiError("The upload took too long.", 0, "timeout"));
    xhr.onabort = () => reject(new ApiError("Cancelled.", 0, "aborted"));
    xhr.onload = () => {
      let body: any = null;
      try {
        body = JSON.parse(xhr.responseText);
      } catch {
        /* non-JSON (proxy error page) */
      }
      if (xhr.status >= 200 && xhr.status < 300 && body?.result?.data?.id) {
        opts.onProgress?.(100);
        return resolve(body.result.data as UploadResult);
      }
      const code: string | undefined = body?.error?.code;
      const limit: number | undefined = body?.error?.limit_bytes;
      const serverMsg: string = body?.error?.message ?? "";
      const message =
        xhr.status === 413 && !code
          ? "This file is too large to upload."
          : attachErrorText(code, serverMsg, limit);
      reject(new ApiError(message, xhr.status, code));
    };
    opts.signal?.addEventListener("abort", () => xhr.abort());
    xhr.send(file);
  });
}

export async function removeAttachment(id: string): Promise<void> {
  await rpc("mail.attach.remove", { id });
}

/** Bheji hui (ya abhi staged) file download: Bearer ke saath fetch -> blob -> save. */
export async function downloadAttachment(id: string, filename: string): Promise<void> {
  const token = sessionToken.get();
  if (!token) throw new ApiError("Please sign in again.", 401, "unauthorized");
  let res: Response;
  try {
    res = await fetch(`${BASE}/file/attach/get?id=${encodeURIComponent(id)}`, { headers: { authorization: `Bearer ${token}` } });
  } catch {
    throw new ApiError("Could not reach the server.", 0, "network");
  }
  if (!res.ok) {
    let code: string | undefined;
    try {
      code = (await res.json())?.error?.code;
    } catch {
      /* ignore */
    }
    throw new ApiError(
      code === "file_missing" || res.status === 404 ? "This file is no longer available." : "Could not download this file.",
      res.status,
      code,
    );
  }
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.rel = "noopener";
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
}
