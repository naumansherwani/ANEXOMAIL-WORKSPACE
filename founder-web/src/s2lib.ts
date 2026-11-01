// Pure wording helpers for Settings S2 (no imports, so they are unit-tested without the browser worker).
export const LABEL: Record<string, string> = {
  "personal.display_name": "Display name", "personal.avatar": "Profile photo", "personal.home": "Home city",
  "appearance.graphics": "Graphics", "appearance.sidebar_slim": "Compact sidebar",
  "appearance.text_scale": "Text size", "appearance.animations": "Animations", "appearance.transitions": "Transitions", "appearance.celebration": "Celebration",
  "appearance.focus_ring": "High-contrast focus ring", "appearance.density": "Density", "appearance.reduce_motion": "Reduce motion",
  "appearance.ambient": "Ambient look", "appearance.ambient_favs": "Favourite looks",
  "personal.undo_send": "Undo send window", "personal.send_check": "Send confidence check",
  "workspace.retention_days": "Retention window", "workspace.require_passkey": "Require passkey for every sign-in", "workspace.flag_external": "Flag external recipients",
  "notifications.quiet_hours": "Quiet hours", "notifications.only_vips": "Only VIPs interrupt", "privacy.block_trackers": "Block tracking pixels",
};
export const label = (k: string) => LABEL[k] ?? k;

export function fmtVal(key: string, v: unknown): string {
  if (v === null || v === undefined) return "default";
  if (typeof v === "boolean") return v ? "On" : "Off";
  if (key === "appearance.text_scale" && typeof v === "number") return v === 100 ? "Default" : `${v}%`;
  if (key === "personal.undo_send" && typeof v === "number") return v === 0 ? "Off" : `${v} s`;
  if (key === "workspace.retention_days" && typeof v === "number") return v === 0 ? "Forever" : v % 365 === 0 ? `${v / 365} year${v === 365 ? "" : "s"}` : `${v} days`;
  if (key === "appearance.ambient" && typeof v === "object") return "custom look";
  if (key === "appearance.ambient_favs" && Array.isArray(v)) return `${v.length} saved`;
  if (key === "personal.home" && typeof v === "object") { const o = v as { city?: string; country?: string }; return [o.city, o.country].filter(Boolean).join(", "); }
  if (typeof v === "string" && /^[a-z]+$/.test(v) && key.startsWith("appearance.")) return v[0].toUpperCase() + v.slice(1);
  if (typeof v === "string") return v.length > 40 ? `${v.slice(0, 40)}…` : v;
  return JSON.stringify(v);
}
export function ago(ms: number, now = Date.now()): string {
  const s = Math.max(0, Math.round((now - ms) / 1000));
  if (s < 60) return "just now";
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
  return `${Math.floor(s / 86400)} d ago`;
}
export const when = (ms: number) => new Date(ms).toLocaleString(undefined, { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
export function whatChanged(it: { key: string; hash_only: boolean; was_default: boolean; now_default: boolean; from: unknown; to: unknown }): string {
  const l = label(it.key);
  if (it.hash_only) return it.now_default ? `${l} removed` : `${l} changed`;
  if (it.now_default) return `${l} went back to the default (was ${fmtVal(it.key, it.from)})`;
  if (it.was_default) return `${l} set to ${fmtVal(it.key, it.to)}`;
  return `${l} changed from ${fmtVal(it.key, it.from)} to ${fmtVal(it.key, it.to)}`;
}
