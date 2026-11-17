// Founder presence: Live while he works, Idle after 30 minutes of no activity, Offline when the browser has no network.
// Pure (no DOM): the component feeds it events and a clock. His word 17 Nov 2026 05:47 PKT.
export const IDLE_AFTER_MS = 30 * 60 * 1000;
export type Presence = "live" | "idle" | "offline";
export function presence(now: number, lastActive: number, online: boolean, hidden = false): Presence {
  if (!online) return "offline";
  // a hidden tab still counts the time since the last real touch; the clock never runs backwards
  const quiet = Math.max(0, now - lastActive);
  return quiet >= IDLE_AFTER_MS ? "idle" : (hidden && quiet >= IDLE_AFTER_MS) ? "idle" : "live";
}
export const PRESENCE_TEXT: Record<Presence, { label: string; tip: string }> = {
  live: { label: "Live", tip: "Founder / Chairman is working now" },
  idle: { label: "Idle", tip: "No activity for 30 minutes" },
  offline: { label: "Offline", tip: "This browser has no network" },
};
