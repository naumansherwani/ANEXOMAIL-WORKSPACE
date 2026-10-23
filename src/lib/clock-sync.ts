/**
 * Device-clock check + own connection speed (World clock W4).
 *
 * What it does: asks the server for its clock a few times (`/rpc/time.now`, public, reads nothing, stores nothing), keeps the
 * answer that took the SHORTEST round-trip (the least jitter, like NTP), and says how far this device's clock is from the server's.
 * The honest limit: a browser cannot know the one-way delay, so the answer is "within ± half the round-trip" — usually a few
 * milliseconds to a few tens of milliseconds. We say that, and we never claim microsecond or atomic-clock precision.
 *
 * The same pings give the person's OWN connection numbers (median and slowest-5%, plus the protocol the browser negotiated).
 * They are shown only to this person, are not sent anywhere and are not stored. Other members' numbers are deliberately not shown.
 */

export type Sample = { rttMs: number; offsetMs: number };
export type ClockReading = {
  /** server minus device, in ms: positive = this device is BEHIND the server, negative = AHEAD. */
  offsetMs: number;
  /** half of the best round-trip: the real uncertainty of `offsetMs`. */
  errorMs: number;
  rtts: number[];
  protocol: string;
};

const BASE = (import.meta.env["VITE_API_URL"] as string | undefined)?.replace(/\/$/, "") ?? "";

/** Nearest-rank percentile of an already sorted list (p in 0..100). Empty list -> 0. */
export function percentile(sorted: number[], p: number): number {
  if (sorted.length === 0) return 0;
  const rank = Math.max(1, Math.ceil((p / 100) * sorted.length));
  return sorted[Math.min(sorted.length, rank) - 1] as number;
}

export function latencyStats(rtts: number[]): { p50: number; p95: number; n: number } {
  const s = rtts.filter((x) => Number.isFinite(x) && x >= 0).sort((a, b) => a - b);
  return { p50: percentile(s, 50), p95: percentile(s, 95), n: s.length };
}

/** The sample with the shortest round-trip wins (ties: the later one). Null when there is nothing usable. */
export function bestSample(samples: Sample[]): Sample | null {
  let best: Sample | null = null;
  for (const s of samples) {
    if (!Number.isFinite(s.rttMs) || !Number.isFinite(s.offsetMs) || s.rttMs < 0) continue;
    if (!best || s.rttMs <= best.rttMs) best = s;
  }
  return best;
}

export type Drift = { tone: "ok" | "warn"; text: string; fix?: string };

/** Words for the badge. In sync = within 1 s (and within the measuring error); otherwise say how far and which way. */
export function describeDrift(offsetMs: number, errorMs: number): Drift {
  const abs = Math.abs(offsetMs);
  const plus = errorMs >= 1 ? ` (± ${Math.round(errorMs)} ms)` : "";
  if (abs < 1000) return { tone: "ok", text: `Device clock is in sync${plus}` };
  const secs = abs < 10_000 ? (abs / 1000).toFixed(1) : String(Math.round(abs / 1000));
  const unit = abs >= 120_000 ? `${Math.round(abs / 60_000)} min` : `${secs} s`;
  const way = offsetMs < 0 ? "fast" : "slow";
  return {
    tone: "warn",
    text: `Your device clock is ${unit} ${way}`,
    fix:
      offsetMs < 0
        ? "You may join meetings late by your own clock's reckoning. Turn on automatic date & time in your system settings."
        : "You may join meetings early by your own clock's reckoning. Turn on automatic date & time in your system settings.",
  };
}

export const protocolLabel = (p: string): string =>
  p === "h3" ? "HTTP/3" : p === "h2" ? "HTTP/2" : p.startsWith("http/1") ? "HTTP/1.1" : "";

async function ping(): Promise<{ sample: Sample; protocol: string } | null> {
  const url = `${BASE}/rpc/time.now`;
  const wall0 = Date.now();
  const p0 = performance.now();
  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      cache: "no-store",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ input: null }),
    });
  } catch {
    return null;
  }
  const text = await res.text();
  const p1 = performance.now();
  if (!res.ok) return null;
  let ms = NaN;
  try {
    const j = JSON.parse(text) as { result?: { data?: { ms?: number } }; ms?: number };
    ms = Number(j.result?.data?.ms ?? j.ms);
  } catch {
    return null;
  }
  if (!Number.isFinite(ms) || ms <= 0) return null;
  const rttMs = p1 - p0;
  // The server answered somewhere inside the round-trip; the middle is the best guess, ± rtt/2 is the honest error bar.
  const offsetMs = ms - (wall0 + rttMs / 2);
  let protocol = "";
  try {
    const e = performance.getEntriesByName(url).at(-1) as PerformanceResourceTiming | undefined;
    protocol = e?.nextHopProtocol ?? "";
  } catch {
    protocol = "";
  }
  return { sample: { rttMs, offsetMs }, protocol };
}

/** Take `n` readings (default 7, one after the other so they do not queue behind each other). Null if the server could not be reached. */
export async function measureClock(n = 7): Promise<ClockReading | null> {
  const samples: Sample[] = [];
  let protocol = "";
  for (let i = 0; i < n; i++) {
    const r = await ping();
    if (r) {
      samples.push(r.sample);
      if (r.protocol) protocol = r.protocol;
    }
  }
  const best = bestSample(samples);
  if (!best) return null;
  return {
    offsetMs: best.offsetMs,
    errorMs: best.rttMs / 2,
    rtts: samples.map((s) => s.rttMs),
    protocol,
  };
}
