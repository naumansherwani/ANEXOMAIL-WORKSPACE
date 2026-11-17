import { describe, expect, test } from "bun:test";
import { IDLE_AFTER_MS, presence } from "./presence_pure";
describe("presence", () => {
  test("live while active", () => { expect(presence(1000, 1000, true)).toBe("live"); expect(presence(IDLE_AFTER_MS - 1, 0, true)).toBe("live"); });
  test("idle at exactly 30 minutes", () => { expect(presence(IDLE_AFTER_MS, 0, true)).toBe("idle"); expect(presence(IDLE_AFTER_MS * 3, 0, true)).toBe("idle"); });
  test("offline wins over everything", () => { expect(presence(0, 0, false)).toBe("offline"); expect(presence(IDLE_AFTER_MS * 2, 0, false)).toBe("offline"); });
  test("a clock that went backwards does not make him idle", () => { expect(presence(0, 5000, true)).toBe("live"); });
});
