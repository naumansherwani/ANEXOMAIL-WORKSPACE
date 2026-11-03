/**
 * ANEXOMAIL — B4 (R5): event-driven live updates over WebTransport/QUIC for the WHOLE app (every plan, every account kind).
 * One shared connection, topics = mail | calendar | crm | work | people | org. The Rust hub pushes a line per change; this file turns
 * lines into React-Query invalidations. No React in here (unit-tested with a fake WebTransport).
 *
 * Honest fallback: no WebTransport / refused / dropped => state "poll" and the normal (slower) query polling keeps the screen true.
 * Reconnect: exponential backoff 1,2,4,8,16,30 s (+jitter), full resync (invalidate everything subscribed) after every reconnect and when
 * the tab becomes visible again, so a laptop that slept never shows stale data.
 */
export const LIVE_TOPICS = ["mail", "calendar", "crm", "work", "people", "org"] as const;
export type LiveTopic = (typeof LIVE_TOPICS)[number];

/** topic -> React-Query key roots to refresh. */
export const TOPIC_KEYS: Record<LiveTopic, string[][]> = {
  mail: [["mail"], ["dashboard"]],
  calendar: [["calendar"], ["dashboard"]],
  crm: [["crm"], ["contacts"], ["companies"]],
  work: [["work"]],
  people: [["contacts"], ["companies"]],
  org: [["org"], ["workspace"]],
};

export type Frame =
  | { kind: "ready" }
  | { kind: "event"; topic: LiveTopic }
  | { kind: "ping" }
  | { kind: "error"; code: string }
  | { kind: "ignore" };

export function parseFrame(line: string): Frame {
  let j: { type?: string; topic?: string; code?: string };
  try {
    j = JSON.parse(line) as typeof j;
  } catch {
    return { kind: "ignore" };
  }
  if (j.type === "ready") return { kind: "ready" };
  if (j.type === "ping") return { kind: "ping" };
  if (j.type === "error") return { kind: "error", code: String(j.code ?? "error") };
  if (j.type === "mail") return { kind: "event", topic: "mail" }; // old mode:"mail" frame
  if (j.type === "event" && (LIVE_TOPICS as readonly string[]).includes(String(j.topic))) return { kind: "event", topic: j.topic as LiveTopic };
  return { kind: "ignore" };
}

/** ms to wait before reconnect attempt n (0-based). `rand` in [0,1) adds up to 25% jitter. */
export function backoffMs(attempt: number, rand = 0): number {
  const base = Math.min(1000 * 2 ** Math.min(attempt, 5), 30_000);
  return Math.round(base * (1 + 0.25 * rand));
}

/** Errors that mean "stop hammering": the login is gone, not the network. */
export function isAuthError(code: string): boolean {
  return ["unauthorized", "session_ended", "token_required", "no_workspace", "too_many_listeners"].includes(code);
}

export type LiveState = { transport: "webtransport" | "poll"; detail: string };

export type WTLike = {
  ready: Promise<void>;
  close: () => void;
  createBidirectionalStream: () => Promise<{ readable: ReadableStream<Uint8Array>; writable: WritableStream<Uint8Array> }>;
};

export type LiveDeps = {
  url: () => string;
  token: () => string | null | undefined;
  WT: (() => (new (u: string) => WTLike) | null) | undefined;
  invalidate: (keys: string[][]) => void;
  onState: (s: LiveState) => void;
  sleep?: (ms: number) => Promise<void>;
  rand?: () => number;
};

const POLL: LiveState = { transport: "poll", detail: "HTTP poll (WebTransport unavailable)" };

export function allKeys(topics: readonly LiveTopic[] = LIVE_TOPICS): string[][] {
  return topics.flatMap((t) => TOPIC_KEYS[t]);
}

/** Start the shared connection. Returns stop(). Never throws. */
export function startLive(d: LiveDeps): { stop: () => void; resync: () => void } {
  let stopped = false;
  let current: WTLike | null = null;
  const sleep = d.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  const rand = d.rand ?? Math.random;

  const run = async () => {
    let attempt = 0;
    while (!stopped) {
      const url = d.url();
      const token = d.token();
      const Ctor = d.WT?.() ?? null;
      if (!url || !token || !Ctor) {
        d.onState(POLL);
        await sleep(15_000); // nothing to connect to (yet): login or env may appear later
        continue;
      }
      let fatal = false;
      try {
        const wt = new Ctor(`${url}/wt/events`);
        current = wt;
        await wt.ready;
        const stream = await wt.createBidirectionalStream();
        const w = stream.writable.getWriter();
        await w.write(new TextEncoder().encode(JSON.stringify({ token, mode: "events", topics: LIVE_TOPICS })));
        w.releaseLock();
        const reader = stream.readable.getReader();
        const dec = new TextDecoder();
        let buf = "";
        let opened = false;
        while (!stopped) {
          const { value, done } = await reader.read();
          if (done) break;
          buf += dec.decode(value, { stream: true });
          const lines = buf.split("\n");
          buf = lines.pop() ?? "";
          for (const line of lines) {
            if (!line.trim()) continue;
            const f = parseFrame(line);
            if (f.kind === "ready") {
              opened = true;
              attempt = 0;
              d.onState({ transport: "webtransport", detail: "Live over WebTransport / QUIC (Rust engine)" });
              d.invalidate(allKeys()); // resync: anything missed while we were away
            } else if (f.kind === "event") {
              d.invalidate(TOPIC_KEYS[f.topic]);
            } else if (f.kind === "error") {
              d.onState({ transport: "poll", detail: `HTTP poll (live push closed: ${f.code})` });
              if (isAuthError(f.code)) fatal = true;
              buf = "";
              break;
            }
          }
          if (fatal) break;
          if (!opened && buf.length > 65_536) break;
        }
      } catch {
        /* network / refused: fall through to backoff */
      } finally {
        try {
          current?.close();
        } catch {
          /* already closed */
        }
        current = null;
      }
      if (stopped) return;
      d.onState(POLL);
      await sleep(fatal ? 60_000 : backoffMs(attempt++, rand()));
    }
  };
  void run();
  return {
    stop: () => {
      stopped = true;
      try {
        current?.close();
      } catch {
        /* already closed */
      }
    },
    resync: () => d.invalidate(allKeys()),
  };
}
