import { describe, expect, test } from "bun:test";
import { ago, fmtVal, whatChanged } from "./s2lib";

describe("Settings S2 wording (no invented numbers)", () => {
  test("values read like words", () => {
    expect(fmtVal("appearance.graphics", true)).toBe("On");
    expect(fmtVal("appearance.graphics", false)).toBe("Off");
    expect(fmtVal("appearance.graphics", null)).toBe("default");
    expect(fmtVal("personal.home", { city: "Lahore", country: "Pakistan" })).toBe("Lahore, Pakistan");
    expect(fmtVal("personal.display_name", "x".repeat(60))).toBe(`${"x".repeat(40)}…`);
  });
  test("relative time", () => {
    const now = 1_800_000_000_000;
    expect(ago(now - 5_000, now)).toBe("just now");
    expect(ago(now - 5 * 60_000, now)).toBe("5 min ago");
    expect(ago(now - 3 * 3_600_000, now)).toBe("3 h ago");
    expect(ago(now - 2 * 86_400_000, now)).toBe("2 d ago");
    expect(ago(now + 9_000, now)).toBe("just now");
  });
  test("what changed, in plain English", () => {
    const base = { key: "appearance.graphics", hash_only: false, was_default: false, now_default: false, from: true, to: false };
    expect(whatChanged(base)).toBe("Graphics changed from On to Off");
    expect(whatChanged({ ...base, was_default: true, from: null })).toBe("Graphics set to Off");
    expect(whatChanged({ ...base, now_default: true, to: null })).toBe("Graphics went back to the default (was On)");
    expect(whatChanged({ key: "personal.avatar", hash_only: true, was_default: true, now_default: false, from: null, to: null })).toBe("Profile photo changed");
  });
});
