// ADMIN DESK desk_plan_pure.ts (D5, phase 1j, 23 Nov 2026): pure logic of the Plan context screen. No network, no browser. Words are plain; no phase names.
// Input = the fields of a kernel-verified lookup (desk_lookup_pure LookupState "data"). Anything missing or odd is shown as "not known", never invented.
export const PLAN_FIELDS = ["package_id", "package_version", "package_effective_from", "features_included", "features_enabled", "limit_storage", "limit_seats", "limit_attachment", "usage_storage", "usage_seats", "service_state", "payment_received_service_not_active", "payment_flag_since", "grace_days_left", "suspension_class", "suspension_since", "sla_target", "data_freshness"];
export const FRESH_SECS = 15;
export const MIN_REASON = 10;

export type Mark = "ok" | "near" | "almost" | "over" | "unknown";
export type Meter = { label: string; used: number | null; limit: number | null; percent: number | null; mark: Mark; words: string };
const num = (v: unknown): number | null => (typeof v === "number" && Number.isFinite(v) && v >= 0 ? v : null);
const str = (v: unknown): string | null => (typeof v === "string" && v.trim() ? v.trim() : null);

/** 90% = near (yellow), 95% = almost full (high). Over 100% is told, never blocked. */
export function markFor(percent: number | null): Mark {
  if (percent === null) return "unknown";
  if (percent > 100) return "over";
  if (percent >= 95) return "almost";
  if (percent >= 90) return "near";
  return "ok";
}
export function meter(label: string, used: unknown, limit: unknown): Meter {
  const u = num(used), l = num(limit);
  const percent = u !== null && l !== null && l > 0 ? Math.round((u / l) * 1000) / 10 : null;
  const mark = markFor(percent);
  const words = mark === "unknown" ? "Not known" : mark === "over" ? "Over the limit" : mark === "almost" ? "Almost full" : mark === "near" ? "Near the limit" : "Within the limit";
  return { label, used: u, limit: l, percent, mark, words };
}
export function meters(f: Record<string, unknown>): Meter[] {
  return [meter("Storage", f.usage_storage, f.limit_storage), meter("Seats", f.usage_seats, f.limit_seats), meter("Attachment size", null, f.limit_attachment)];
}

export type FeatureDiff = { included: string[]; enabled: string[]; both: string[]; includedNotEnabled: string[]; enabledNotIncluded: string[] };
const list = (v: unknown): string[] => (Array.isArray(v) ? [...new Set(v.filter((x): x is string => typeof x === "string" && x.trim() !== "").map((x) => x.trim()))].sort() : []);
export function featureDiff(f: Record<string, unknown>): FeatureDiff {
  const included = list(f.features_included), enabled = list(f.features_enabled);
  return { included, enabled, both: included.filter((x) => enabled.includes(x)), includedNotEnabled: included.filter((x) => !enabled.includes(x)), enabledNotIncluded: enabled.filter((x) => !included.includes(x)) };
}

export type StateKey = "active" | "not_active_yet" | "grace_period" | "suspended" | "setting_up" | "unknown";
const STATES: Record<Exclude<StateKey, "unknown">, { words: string; level: "good" | "wait" | "warn" | "bad" }> = {
  active: { words: "Active", level: "good" },
  not_active_yet: { words: "Not active yet", level: "wait" },
  grace_period: { words: "Grace period", level: "warn" },
  suspended: { words: "Suspended", level: "bad" },
  setting_up: { words: "Setting up", level: "wait" },
};
export type ServiceView = { key: StateKey; words: string; level: "good" | "wait" | "warn" | "bad" | "none"; since: string | null; detail: string | null };
export function serviceView(f: Record<string, unknown>): ServiceView {
  const raw = str(f.service_state), key = (raw && raw in STATES ? raw : "unknown") as StateKey;
  if (key === "unknown") return { key, words: "Not known", level: "none", since: null, detail: null };
  const days = num(f.grace_days_left);
  const detail = key === "grace_period" && days !== null ? `${days} day${days === 1 ? "" : "s"} left` : key === "suspended" ? str(f.suspension_class) : null;
  const since = key === "suspended" ? str(f.suspension_since) : null;
  return { key, words: STATES[key].words, level: STATES[key].level, since, detail };
}

/** The ONE finance-safe flag. No amount, no card, no invoice: a yes/no and its start time. */
export function paymentFlag(f: Record<string, unknown>): { on: boolean; since: string | null; words: string } {
  const on = f.payment_received_service_not_active === true;
  return { on, since: on ? str(f.payment_flag_since) : null, words: on ? "Payment received, service not active" : "No payment flag" };
}

/** Seconds since the answer was signed; null if unknown. */
export function ageSecs(answeredAt: number, nowSecs: number): number | null {
  return Number.isFinite(answeredAt) && Number.isFinite(nowSecs) ? Math.max(0, Math.floor(nowSecs - answeredAt)) : null;
}
export const isStale = (age: number | null) => age === null || age > FRESH_SECS;
export function freshnessWords(age: number | null): string {
  if (age === null) return "Time not known. Look up again.";
  return age > FRESH_SECS ? `Older than ${FRESH_SECS} s (${age} s). Look up again.` : `Fresh, ${age} s old`;
}
export const reasonOk = (r: string) => r.trim().length >= MIN_REASON;
export const companyOk = (c: string) => /^[A-Za-z0-9_.:-]{3,64}$/.test(c.trim());
