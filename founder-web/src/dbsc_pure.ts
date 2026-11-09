// K7 — Device-bound sessions (DBSC), the pure part: turn the server's /founder/v1/dbsc/status answer into words. No fetch, no DOM, nothing invented.
export type DbscDevice = { id: string; label: string; bound: boolean; source?: "dbsc" | "webcrypto" | null; since: string | null; refreshes: number; last_refresh_at: string | null };
export type DbscStatus = {
  mode: "off" | "observe" | "enforce"; available: boolean; this_device?: string | null; devices?: DbscDevice[]; note?: string; limit?: string;
  report?: { verdict: string; sessions_active: number; refreshes_24h: number; rejects_24h: number; would_block_24h: number; blocked_24h: number; chain?: { ok: boolean; checked: number } };
};
export type DbscView = { tone: "ok" | "warn" | "off"; headline: string; detail: string };

export function ago(iso: string | null | undefined, now = Date.now()): string {
  if (!iso) return "never";
  const t = Date.parse(iso); if (!Number.isFinite(t)) return "never";
  const s = Math.max(0, (now - t) / 1000);
  return s < 90 ? "just now" : s < 5400 ? `${Math.round(s / 60)} min ago` : s < 129600 ? `${Math.round(s / 3600)} h ago` : `${Math.round(s / 86400)} d ago`;
}

export function view(s: DbscStatus): DbscView {
  if (!s.available) return { tone: "off", headline: "Not available yet", detail: s.note ?? "The server did not answer." };
  const r = s.report, bound = (s.devices ?? []).filter((d) => d.bound).length, total = (s.devices ?? []).length;
  if (s.mode === "off") return { tone: "off", headline: "Off", detail: "The server is not asking browsers to bind sessions yet. Nothing changes until it is switched to observe." };
  if (r?.chain && !r.chain.ok) return { tone: "warn", headline: "Ledger chain broken", detail: "The DBSC event ledger failed its hash check. Treat this as an incident." };
  const mode = s.mode === "enforce" ? "Enforced" : "Watching (not blocking)";
  if (bound === 0) return { tone: "warn", headline: `${mode}: no device bound yet`, detail: "Every device binds itself at its next sign-in: Chrome with a secure chip uses the chip, every other browser and phone uses a non-extractable browser key." };
  const extra = r && r.rejects_24h > 0 ? ` ${r.rejects_24h} proof${r.rejects_24h > 1 ? "s were" : " was"} refused in 24 h.` : "";
  const would = s.mode === "observe" && r && r.would_block_24h > 0 ? ` ${r.would_block_24h} request${r.would_block_24h > 1 ? "s" : ""} would have been blocked.` : "";
  return { tone: extra ? "warn" : "ok", headline: `${mode}: ${bound} of ${total} device${total > 1 ? "s" : ""} bound`, detail: `A stolen login cannot mint a founder token from another machine on a bound device.${extra}${would}` };
}
