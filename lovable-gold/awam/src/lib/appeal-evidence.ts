/**
 * E72 — appeal ke saboot (browser <-> Rust).
 *   POST {BASE}/file/appeal-evidence       (raw bytes, progress ke saath)   -> id
 *   GET  {BASE}/file/appeal-evidence/get   (Bearer; malik ya reviewer; blob se save)
 *   RPC  appeal.evidence.limits / .remove / .list
 * Server hi asli faisla karta hai (type allowlist + asli bytes, virus, hadein, dedup); qaide `appeal-evidence-core.ts`.
 */
import { useQuery } from "@tanstack/react-query";

import { ApiError, sessionToken } from "@/lib/api";
import { evidenceErrorText, type EvidenceLimits } from "@/lib/appeal-evidence-core";
import { rpc } from "@/lib/rpc";

const BASE = (import.meta.env["VITE_API_URL"] as string | undefined)?.replace(/\/$/, "") ?? "";

export function useEvidenceLimits(enabled = true) {
  return useQuery<EvidenceLimits>({
    queryKey: ["appeal", "evidence-limits"],
    enabled,
    staleTime: 60_000,
    retry: false,
    queryFn: () => rpc<EvidenceLimits>("appeal.evidence.limits", {}),
  });
}

export type EvidenceUpload = {
  id: string;
  filename: string;
  size_bytes: number;
  deduped: boolean;
  scanned: boolean;
};

/** Ek file upload; progress 0..100. Reject par `ApiError` (message insaani, code server ka). */
export function uploadEvidence(
  file: File,
  opts: { onProgress?: (pct: number) => void; signal?: AbortSignal } = {},
): Promise<EvidenceUpload> {
  return new Promise((resolve, reject) => {
    const token = sessionToken.get();
    if (!token) return reject(new ApiError("Please sign in again.", 401, "unauthorized"));
    const xhr = new XMLHttpRequest();
    xhr.open("POST", `${BASE}/file/appeal-evidence`);
    xhr.setRequestHeader("authorization", `Bearer ${token}`);
    xhr.setRequestHeader("x-file-name", encodeURIComponent(file.name));
    xhr.setRequestHeader("x-file-type", file.type || "application/octet-stream");
    xhr.responseType = "text";
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable && opts.onProgress)
        opts.onProgress(Math.min(99, Math.round((e.loaded / e.total) * 100)));
    };
    xhr.onerror = () =>
      reject(new ApiError("Could not reach the server. Check your connection.", 0, "network"));
    xhr.ontimeout = () => reject(new ApiError("The upload took too long.", 0, "timeout"));
    xhr.onabort = () => reject(new ApiError("Cancelled.", 0, "aborted"));
    xhr.onload = () => {
      let body: {
        result?: { data?: EvidenceUpload };
        error?: { code?: string; limit_bytes?: number; message?: string };
      } | null = null;
      try {
        body = JSON.parse(xhr.responseText);
      } catch {
        /* non-JSON (proxy error page) */
      }
      if (xhr.status >= 200 && xhr.status < 300 && body?.result?.data?.id) {
        opts.onProgress?.(100);
        return resolve(body.result.data);
      }
      const code: string | undefined = body?.error?.code;
      const limit: number | undefined = body?.error?.limit_bytes;
      const serverMsg: string = body?.error?.message ?? "";
      const message =
        xhr.status === 413 && !code
          ? "This file is too large to upload."
          : evidenceErrorText(code, serverMsg, limit);
      reject(new ApiError(message, xhr.status, code));
    };
    opts.signal?.addEventListener("abort", () => xhr.abort());
    xhr.send(file);
  });
}

export async function removeEvidence(id: string): Promise<void> {
  await rpc("appeal.evidence.remove", { id });
}

export type AppealFile = {
  id: string;
  filename: string;
  mime: string;
  size_bytes: number;
  scanned: boolean;
  created_at: string;
};

/** Ek appeal ki judi hui files (malik ya reviewer). */
export function useAppealFiles(appealId: string | null, enabled = true) {
  return useQuery<{ files: AppealFile[] }>({
    queryKey: ["appeal", "files", appealId],
    enabled: enabled && !!appealId,
    staleTime: 30_000,
    retry: false,
    queryFn: () => rpc<{ files: AppealFile[] }>("appeal.evidence.list", { appeal_id: appealId }),
  });
}

/** File download: Bearer ke saath fetch -> blob -> save. */
export async function downloadEvidence(id: string, filename: string): Promise<void> {
  const token = sessionToken.get();
  if (!token) throw new ApiError("Please sign in again.", 401, "unauthorized");
  let res: Response;
  try {
    res = await fetch(`${BASE}/file/appeal-evidence/get?id=${encodeURIComponent(id)}`, {
      headers: { authorization: `Bearer ${token}` },
    });
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
      code === "file_missing" || res.status === 404
        ? "This file is no longer available."
        : "Could not download this file.",
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
