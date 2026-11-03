import { sessionToken } from "@/lib/api";

const API_BASE = (import.meta.env["VITE_API_URL"] as string | undefined)?.replace(/\/$/, "") ?? "";

/**
 * "One-click data export" — owner-only GET /api/org/export: a real JSON bundle (members, mail thread records, calendar events,
 * tasks, CRM leads and deals), audit-logged on the server. Shared by Organisation → Compliance and Admin → Export.
 * Throws Error(code) with the server's code ("owner_only", "no_org", "export_failed_<status>").
 */
export async function downloadOrgExport(): Promise<void> {
  const token = sessionToken.get();
  const res = await fetch(`${API_BASE}/api/org/export`, {
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { error?: string } | null;
    throw new Error(body?.error ?? `export_failed_${res.status}`);
  }
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `anexomail-export-${new Date().toISOString().slice(0, 10)}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

/** Human sentence for an export failure code. */
export const exportErrorText = (e: unknown): string => {
  const m = e instanceof Error ? e.message : "";
  if (m === "owner_only") return "Only the workspace owner can export all data.";
  if (m === "no_org") return "This account has no workspace to export yet.";
  if (m.startsWith("export_failed_5")) return "The server could not build the file. Try again in a minute.";
  return m || "Try again.";
};
