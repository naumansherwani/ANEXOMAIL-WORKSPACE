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
  const a = document.createElement("a");
  a.href = `${BASE}${res.url}`;
  a.rel = "noopener";
  document.body.appendChild(a);
  a.click();
  a.remove();
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
