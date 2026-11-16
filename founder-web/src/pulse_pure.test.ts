import { describe, expect, test } from "bun:test";
import { fmtUp, pulseState, STALE_AFTER_MS } from "./pulse_pure";
describe("SYS-LIVE pulse badge", () => {
  test("no answer yet = wait", () => expect(pulseState(null, 1000)).toBe("wait"));
  test("fresh answer = live", () => expect(pulseState(1000, 1000 + STALE_AFTER_MS)).toBe("live"));
  test("uptime words", () => { expect(fmtUp(59)).toBe("59 s"); expect(fmtUp(125)).toBe("2 min 5 s"); expect(fmtUp(7260)).toBe("2 h 1 min"); expect(fmtUp(90000)).toBe("1 d 1 h"); });
  test("old answer = stale, never a frozen live", () => expect(pulseState(1000, 1001 + STALE_AFTER_MS)).toBe("stale"));
});
