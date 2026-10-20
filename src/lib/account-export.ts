/**
 * G36 — asli data export. Rust `/rpc/account.export.ticket` ek-bar ka ticket deta hai, phir browser seedha
 * `GET /file/account-export?t=…` kholta hai (streaming ZIP: mail, attachments, contacts, calendar).
 * Blocked account ko yeh sirf 72 ghante ki export window mein milta hai (server dekhta hai).
 */
import { useQuery } from "@tanstack/react-query";

import { ApiError } from "@/lib/api";
import type { IntegrityState } from "@/lib/account-integrity";
import { rpc } from "@/lib/rpc";

const BASE = (import.meta.env["VITE_API_URL"] as string | undefined)?.replace(/\/$/, "") ?? "";

export async function startExport(): Promise<void> {
  const res = await rpc<{ url: string; expires_in: number }>("account.export.ticket", {});
  if (!res?.url) throw new ApiError("The server did not give an export link.", 502, "no_ticket");
  // Chhupa iframe: server `Content-Disposition: attachment` deta hai to download shuru, aur agar server galti de (JSON error) to
  // poora tab us JSON par nahi jata — app screen par hi rehti hai (blocked screen band nahi hoti).
  const frame = document.createElement("iframe");
  frame.setAttribute("aria-hidden", "true");
  frame.tabIndex = -1;
  frame.style.cssText = "position:fixed;width:0;height:0;border:0;opacity:0;pointer-events:none";
  frame.src = `${BASE}${res.url}`;
  document.body.appendChild(frame);
  window.setTimeout(() => frame.remove(), 10 * 60_000);
}

export function exportErrorMessage(e: unknown): string {
  const code = e instanceof ApiError ? (e.code ?? "") : "";
  if (code === "export_window_closed") return "The export window for this account has closed.";
  if (code === "purged") return "This account's data has been permanently deleted.";
  if (e instanceof ApiError && e.message) return e.message;
  return "Could not start the export. Try again.";
}

export type MyIntegrity = {
  unknown?: boolean;
  state: IntegrityState;
  reason?: string | null;
  warned_at?: string | null;
  blocked_at?: string | null;
  export_until?: string | null;
  export_hours_left?: number | null;
  purge_after?: string | null;
};

/** Apni integrity halat — sab plans (Rust `account.integrity.me`). */
export function useMyIntegrity(enabled = true) {
  return useQuery<MyIntegrity>({
    queryKey: ["account", "integrity-me"],
    enabled,
    staleTime: 60_000,
    retry: false,
    queryFn: () => rpc<MyIntegrity>("account.integrity.me", {}),
  });
}

export type AppealResult = { ok: boolean; appeal_id?: string; devices?: number; error?: string; message?: string };

/** Blocked user ka apna appeal (E46): device hash user ko nahi chahiye, server us ke banned devices dhoondta hai. */
export async function sendAppeal(statement: string): Promise<AppealResult> {
  return rpc<AppealResult>("account.integrity.appeal", { statement });
}
