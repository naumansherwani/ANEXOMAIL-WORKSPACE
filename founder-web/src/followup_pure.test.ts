import { describe, expect, test } from "bun:test";
import { presetDue, dueOk, forMessage, chipText, dueCount, type Followup } from "./followup_pure";
const N = Date.UTC(2026, 10, 20, 12);
const F = (o: Partial<Followup>): Followup => ({ id: "i", message_id: "m", thread_id: "t", due_ms: N + 3_600_000, state: "waiting", rearms: 0, ...o });
describe("followup", () => {
  test("presets are inside the window", () => { for (const d of [1, 3, 7, 90, 500, 0]) expect(dueOk(presetDue(N, d), N)).toBe(true); });
  test("window edges", () => { expect(dueOk(N + 59_000, N)).toBe(false); expect(dueOk(N + 60_000, N)).toBe(true); expect(dueOk(N + 91 * 86_400_000, N)).toBe(false); expect(dueOk(NaN, N)).toBe(false); });
  test("forMessage", () => { expect(forMessage([F({})], "m")?.id).toBe("i"); expect(forMessage([F({})], "x")).toBeUndefined(); });
  test("chip words", () => {
    expect(chipText(undefined, N)).toEqual({ text: "Remind me if no reply", tone: "idle" });
    expect(chipText(F({ due_ms: N + 10 * 60_000 }), N).text).toBe("Reminder in 10 min");
    expect(chipText(F({}), N).text).toBe("Reminder in 1 h");
    expect(chipText(F({ due_ms: N + 3 * 86_400_000 }), N).text).toBe("Reminder in 3 days");
    expect(chipText(F({ state: "due" }), N).tone).toBe("due");
    expect(chipText(F({ due_ms: N - 1 }), N).tone).toBe("due");
  });
  test("dueCount", () => { expect(dueCount([F({}), F({ state: "due" }), F({ due_ms: N - 5 })], N)).toBe(2); });
});
