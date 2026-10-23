/**
 * "Travelling" status (World clock W4) — the pure rules. The person types where they are going and when; nothing is tracked.
 *
 * Tickets are written in LOCAL time at each end (departure at home, arrival at the destination), so the form takes exactly that
 * and `zonedToUtc` turns each into one UTC instant. The account stores plain UTC (SQL E78 / Rust clean_travel check the same shape).
 * While "in transit" only in-app reminder pop-ups are held. Mail is never held: inbound mail ALWAYS arrives (product promise).
 */
export type Trip = { to_city: string; to_zone: string; depart_at: string; arrive_at: string };
export type TripPhase = "upcoming" | "transit" | "landed" | "over";

/** How long after landing the status stays visible ("Landed in Tokyo — local time …"). Matches the Rust rule (48 h). */
export const LANDED_KEEP_MS = 48 * 3_600_000;
export const TRIP_MAX_MS = 72 * 3_600_000;

const ISO_UTC = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;

export function isTrip(x: unknown): x is Trip {
  if (!x || typeof x !== "object") return false;
  const t = x as Record<string, unknown>;
  return (
    typeof t["to_city"] === "string" &&
    t["to_city"].length > 0 &&
    typeof t["to_zone"] === "string" &&
    t["to_zone"].length > 0 &&
    typeof t["depart_at"] === "string" &&
    ISO_UTC.test(t["depart_at"]) &&
    typeof t["arrive_at"] === "string" &&
    ISO_UTC.test(t["arrive_at"])
  );
}

export function tripPhase(t: Trip, nowMs: number): TripPhase {
  const d = Date.parse(t.depart_at);
  const a = Date.parse(t.arrive_at);
  if (!Number.isFinite(d) || !Number.isFinite(a)) return "over";
  if (nowMs < d) return "upcoming";
  if (nowMs < a) return "transit";
  if (nowMs < a + LANDED_KEEP_MS) return "landed";
  return "over";
}

/** Reminder pop-ups wait while the person is in the air. Everything else (mail, the calendar itself) carries on. */
export const holdsReminders = (t: Trip | null | undefined, nowMs: number): boolean =>
  !!t && tripPhase(t, nowMs) === "transit";

/** Offset (minutes east of UTC) of time zone `zone` at the instant `ms`. Null for an unknown zone name. */
function offsetMin(ms: number, zone: string): number | null {
  try {
    const p = new Intl.DateTimeFormat("en-US", {
      timeZone: zone,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    }).formatToParts(new Date(ms));
    const g = (k: string) => Number(p.find((x) => x.type === k)?.value);
    const asUtc = Date.UTC(
      g("year"),
      g("month") - 1,
      g("day"),
      g("hour"),
      g("minute"),
      g("second"),
    );
    return Math.round((asUtc - Math.floor(ms / 1000) * 1000) / 60_000);
  } catch {
    return null;
  }
}

/**
 * `YYYY-MM-DDTHH:mm` typed as wall-clock time in `zone` -> the UTC instant, as `YYYY-MM-DDTHH:mm:00Z`. Null when the text is not a real
 * time or the zone is unknown. A time that does not exist (spring-forward gap) or exists twice (autumn) resolves to one instant deterministically.
 */
export function zonedToUtc(local: string, zone: string): string | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/.exec(local);
  if (!m) return null;
  const [y, mo, d, h, mi] = m.slice(1).map(Number) as [number, number, number, number, number];
  const naive = Date.UTC(y, mo - 1, d, h, mi);
  const back = new Date(naive);
  if (
    back.getUTCFullYear() !== y ||
    back.getUTCMonth() !== mo - 1 ||
    back.getUTCDate() !== d ||
    back.getUTCHours() !== h
  )
    return null; // 02-30 etc.
  let guess = naive;
  for (let i = 0; i < 3; i++) {
    const off = offsetMin(guess, zone);
    if (off === null) return null;
    const next = naive - off * 60_000;
    if (next === guess) break;
    guess = next;
  }
  return new Date(guess).toISOString().replace(/\.\d{3}Z$/, "Z");
}

export type TripCheck = { ok: true; trip: Trip } | { ok: false; error: string };

/** Everything the form can know before it asks the server. The server (Rust + SQL) repeats these rules. */
export function buildTrip(
  input: { city: string; zone: string; departLocal: string; arriveLocal: string },
  departZone: string,
  nowMs: number,
): TripCheck {
  const city = input.city.trim().slice(0, 60);
  if (!city || !input.zone) return { ok: false, error: "Choose where you are going." };
  const dep = zonedToUtc(input.departLocal, departZone);
  const arr = zonedToUtc(input.arriveLocal, input.zone);
  if (!dep) return { ok: false, error: "Enter the departure date and time." };
  if (!arr) return { ok: false, error: "Enter the arrival date and time." };
  const d = Date.parse(dep);
  const a = Date.parse(arr);
  if (a <= d)
    return {
      ok: false,
      error: "Arrival must be after departure (check both are in local time at each end).",
    };
  if (a - d > TRIP_MAX_MS) return { ok: false, error: "A trip can be at most 72 hours long." };
  if (a < nowMs - LANDED_KEEP_MS)
    return { ok: false, error: "That trip ended more than 48 hours ago." };
  return { ok: true, trip: { to_city: city, to_zone: input.zone, depart_at: dep, arrive_at: arr } };
}

/** Short, plain sentence for the popover. `fmt` formats an instant in the viewer's zone, `fmtAt` in the destination's. */
export function tripLine(
  t: Trip,
  nowMs: number,
  fmt: (iso: string) => string,
  fmtAt: (iso: string, zone: string) => string,
): string {
  switch (tripPhase(t, nowMs)) {
    case "upcoming":
      return `Trip to ${t.to_city} · leaves ${fmt(t.depart_at)}`;
    case "transit":
      return `In transit to ${t.to_city} · lands ${fmt(t.arrive_at)} your time (${fmtAt(t.arrive_at, t.to_zone)} there)`;
    case "landed":
      return `Landed in ${t.to_city} · local time ${fmtAt(new Date(nowMs).toISOString(), t.to_zone)}`;
    default:
      return "";
  }
}
