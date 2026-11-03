/**
 * World clock W5 — billing deadline line.
 *
 * Reads the dates our own billing tables already hold (subscription renews_at / cancel_at, trial_ends_at). Polar is never touched.
 * Shows nothing when there is no real future date, and makes no claim about banks or card clearing.
 */
export type Deadline = { kind: "trial" | "renews" | "ends" | "due"; atMs: number };

type Sub = {
  state?: string;
  renews_at?: string | null;
  cancel_at?: string | null;
  lifetime?: boolean;
} | null;
type Acct = { state?: string; trial_ends_at?: string | null } | null;

const ms = (iso?: string | null): number | null => {
  if (!iso) return null;
  const t = Date.parse(iso);
  return Number.isFinite(t) ? t : null;
};

export function billingDeadline(
  sub: Sub | undefined,
  acct: Acct | undefined,
  nowMs: number,
): Deadline | null {
  if (sub?.lifetime) return null;
  const trial = acct?.state === "trial" ? ms(acct.trial_ends_at) : null;
  if (trial !== null && trial > nowMs) return { kind: "trial", atMs: trial };
  const cancel = sub?.state === "cancelled" ? ms(sub.cancel_at) : null;
  if (cancel !== null && cancel > nowMs) return { kind: "ends", atMs: cancel };
  const renew = ms(sub?.renews_at);
  if (renew !== null && renew > nowMs && (sub?.state === "active" || sub?.state === "trialing")) {
    return { kind: "renews", atMs: renew };
  }
  if (renew !== null && renew > nowMs && sub?.state === "past_due")
    return { kind: "due", atMs: renew };
  return null;
}

export function inWord(deltaMs: number): string {
  const min = Math.max(1, Math.round(deltaMs / 60000));
  if (min < 60) return `in ${min} min`;
  const h = Math.round(min / 60);
  if (h < 48) return `in ${h} h`;
  return `in ${Math.round(h / 24)} days`;
}

const LEAD: Record<Deadline["kind"], string> = {
  trial: "Trial ends",
  renews: "Plan renews",
  ends: "Plan ends",
  due: "Payment due",
};

/** "Plan renews Fri 6 Nov, 2:00 PM Karachi time · in 14 days" */
export function describeDeadline(d: Deadline, zone: string, city: string, nowMs: number): string {
  const when = new Intl.DateTimeFormat("en-GB", {
    timeZone: zone,
    weekday: "short",
    day: "numeric",
    month: "short",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  }).format(new Date(d.atMs));
  return `${LEAD[d.kind]} ${when.replace(" at ", ", ")} ${city} time · ${inWord(d.atMs - nowMs)}`;
}
