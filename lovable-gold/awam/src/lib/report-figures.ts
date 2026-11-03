/**
 * Organisation report numbers arrive as { snake_case_key: number }. This turns a key into a human label and a value into
 * a figure with its unit — no new data, just honest wording (no "avg first reply minutes 44").
 */

const LABELS: Record<string, string> = {
  threads_started: "Conversations started",
  messages_handled: "Messages handled",
  messages_received: "Messages received",
  messages_sent: "Messages sent",
  incidents_recorded: "Incidents recorded",
  self_heals: "Problems fixed automatically",
  delivery_events: "Delivery events",
};

const UNITS: { suffix: string; format: (n: number) => string }[] = [
  { suffix: "_percent", format: (n) => `${trim(n)}%` },
  { suffix: "_minutes", format: (n) => `${trim(n)} min` },
  { suffix: "_hours", format: (n) => `${trim(n)} h` },
  { suffix: "_gb", format: (n) => `${trim(n)} GB` },
  { suffix: "_gbp", format: (n) => `£${n.toLocaleString("en-GB", { maximumFractionDigits: 2 })}` },
];

const trim = (n: number) => (Number.isInteger(n) ? n.toLocaleString("en-GB") : n.toLocaleString("en-GB", { maximumFractionDigits: 1 }));

const sentence = (s: string) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : s);

/** "avg_first_reply_minutes" → "Avg first reply";  "spend_gbp" → "Spend";  known keys use a hand-written label. */
export function reportLabel(key: string): string {
  const known = LABELS[key];
  if (known) return known;
  let k = key;
  for (const u of UNITS) if (k.endsWith(u.suffix)) k = k.slice(0, -u.suffix.length);
  return sentence(k.replace(/_/g, " ").trim());
}

/** 98.4 under "delivery_rate_percent" → "98.4%";  5120 → "5,120";  non-numbers are shown as given. */
export function reportValue(key: string, value: unknown): string {
  const n = typeof value === "number" ? value : typeof value === "string" && value.trim() !== "" ? Number(value) : NaN;
  if (!Number.isFinite(n)) return String(value ?? "—");
  const unit = UNITS.find((u) => key.endsWith(u.suffix));
  return unit ? unit.format(n) : trim(n);
}
