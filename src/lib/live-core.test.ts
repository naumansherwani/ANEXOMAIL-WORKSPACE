import { describe, expect, test } from "bun:test";

import { allKeys, backoffMs, isAuthError, parseFrame, startLive, TOPIC_KEYS, type WTLike } from "./live-core";

describe("live-core", () => {
  test("parseFrame", () => {
    expect(parseFrame('{"type":"ready"}').kind).toBe("ready");
    expect(parseFrame('{"type":"event","topic":"crm","seq":3}')).toEqual({ kind: "event", topic: "crm" });
    expect(parseFrame('{"type":"mail","unread":1}')).toEqual({ kind: "event", topic: "mail" });
    expect(parseFrame('{"type":"event","topic":"chat"}').kind).toBe("ignore");
    expect(parseFrame("garbage").kind).toBe("ignore");
    expect(parseFrame('{"type":"error","code":"unauthorized"}')).toEqual({ kind: "error", code: "unauthorized" });
  });
  test("backoff grows, caps at 30s, jitter <= 25%", () => {
    expect([0, 1, 2, 3, 4, 5, 9].map((n) => backoffMs(n))).toEqual([1000, 2000, 4000, 8000, 16000, 30000, 30000]);
    expect(backoffMs(0, 0.999)).toBeLessThanOrEqual(1250);
  });
  test("auth errors stop the hammering", () => {
    expect(isAuthError("session_ended")).toBe(true);
    expect(isAuthError("boom")).toBe(false);
  });

  function fakeWT(lines: string[][]) {
    let n = 0;
    const written: string[] = [];
    class FakeWT implements WTLike {
      ready = Promise.resolve();
      close() {}
      async createBidirectionalStream() {
        const batch = lines[Math.min(n++, lines.length - 1)];
        const enc = new TextEncoder();
        const readable = new ReadableStream<Uint8Array>({
          start(c) {
            batch.forEach((l) => c.enqueue(enc.encode(l + "\n")));
            c.close();
          },
        });
        const writable = new WritableStream<Uint8Array>({ write(ch) { written.push(new TextDecoder().decode(ch)); } });
        return { readable, writable };
      }
    }
    return { FakeWT, written, count: () => n };
  }

  test("ready => full resync; event => only its topic keys; reconnects after drop", async () => {
    const { FakeWT, written, count } = fakeWT([['{"type":"ready"}', '{"type":"event","topic":"crm","seq":1}']]);
    const inv: string[][][] = [];
    const states: string[] = [];
    const ctl = startLive({
      url: () => "https://x:3443",
      token: () => "tok",
      WT: () => FakeWT as unknown as new (u: string) => WTLike,
      invalidate: (k) => inv.push(k),
      onState: (s) => states.push(s.transport),
      sleep: async () => {
        await new Promise((r) => setTimeout(r, 5));
      },
      rand: () => 0,
    });
    await new Promise((r) => setTimeout(r, 80));
    ctl.stop();
    expect(inv[0]).toEqual(allKeys());
    expect(inv[1]).toEqual(TOPIC_KEYS.crm);
    expect(states).toContain("webtransport");
    expect(states).toContain("poll");
    expect(count()).toBeGreaterThan(1); // reconnected
    expect(JSON.parse(written[0])).toMatchObject({ token: "tok", mode: "events" });
  });

  test("no token or no WebTransport => poll, no throw", async () => {
    const states: string[] = [];
    const ctl = startLive({ url: () => "", token: () => null, WT: () => null, invalidate: () => {}, onState: (s) => states.push(s.transport), sleep: () => new Promise(() => {}) });
    await new Promise((r) => setTimeout(r, 10));
    ctl.stop();
    expect(states).toEqual(["poll"]);
  });
});
