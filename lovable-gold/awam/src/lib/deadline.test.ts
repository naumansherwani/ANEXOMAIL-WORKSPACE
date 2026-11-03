import { describe, expect, test } from "bun:test";

import { billingDeadline, describeDeadline, inWord } from "@/lib/deadline";

const now = Date.UTC(2026, 9, 23, 2, 0);
const iso = (h: number) => new Date(now + h * 3600_000).toISOString();

describe("billingDeadline", () => {
  test("trial wins while it runs", () => {
    expect(
      billingDeadline(
        { state: "trialing", renews_at: iso(500) },
        { state: "trial", trial_ends_at: iso(6) },
        now,
      )?.kind,
    ).toBe("trial");
  });
  test("active plan shows the renewal", () => {
    expect(
      billingDeadline({ state: "active", renews_at: iso(48) }, { state: "active" }, now)?.kind,
    ).toBe("renews");
  });
  test("cancelled plan shows when it ends", () => {
    expect(
      billingDeadline({ state: "cancelled", cancel_at: iso(72), renews_at: iso(72) }, null, now)
        ?.kind,
    ).toBe("ends");
  });
  test("past_due is 'due', never 'renews'", () => {
    expect(billingDeadline({ state: "past_due", renews_at: iso(10) }, null, now)?.kind).toBe("due");
  });
  test("nothing for lifetime, none, past dates or bad strings", () => {
    expect(
      billingDeadline({ lifetime: true, state: "active", renews_at: iso(5) }, null, now),
    ).toBeNull();
    expect(billingDeadline({ state: "none" }, null, now)).toBeNull();
    expect(billingDeadline({ state: "active", renews_at: iso(-3) }, null, now)).toBeNull();
    expect(billingDeadline({ state: "active", renews_at: "soon" }, null, now)).toBeNull();
  });
});

describe("describeDeadline", () => {
  test("uses the person's zone and a plain countdown", () => {
    const d = { kind: "renews" as const, atMs: Date.UTC(2026, 10, 6, 9, 0) };
    const s = describeDeadline(d, "Asia/Karachi", "Karachi", now);
    expect(s).toContain("Plan renews");
    expect(s).toMatch(/2:00\s?pm/i);
    expect(s).toContain("Karachi time");
    expect(s).toContain("in 14 days");
  });
  test("inWord", () => {
    expect(inWord(20 * 60_000)).toBe("in 20 min");
    expect(inWord(5 * 3600_000)).toBe("in 5 h");
  });
});
