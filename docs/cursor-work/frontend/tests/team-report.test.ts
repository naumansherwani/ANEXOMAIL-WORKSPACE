import { describe, expect, test } from "bun:test";

import { summariseInvites } from "../../../../src/lib/team-report";

describe("summariseInvites — what the person is told comes from the engine's own report", () => {
  test("everything delivered", () => {
    const r = summariseInvites({ invited: ["a@x.com", "b@x.com"], failed: [] }, 2);
    expect(r.tone).toBe("done");
    expect(r.title).toBe("2 invitations e-mailed");
  });

  test("one delivered is singular", () => {
    expect(summariseInvites({ invited: ["a@x.com"] }, 1).title).toBe("1 invitation e-mailed");
  });

  test("a delivery failure is never reported as success", () => {
    const r = summariseInvites({ invited: [], failed: [{ email: "a@x.com", error: "550 5.1.1 user unknown" }] }, 1);
    expect(r.tone).toBe("failed");
    expect(r.title).toBe("Invitations not delivered");
    expect(r.detail).toContain("a@x.com");
    expect(r.detail).toContain("550 5.1.1");
    expect(r.detail).toContain("Resend");
  });

  test("partial: counts and names who was not reached", () => {
    const r = summariseInvites(
      { invited: ["a@x.com"], failed: [{ email: "b@x.com", error: "smtp connect timeout" }], already_member: ["c@x.com"], invalid: 1 },
      3,
    );
    expect(r.tone).toBe("partial");
    expect(r.title).toBe("1 sent, 1 not sent");
    expect(r.detail).toContain("Already in the organisation: c@x.com");
    expect(r.detail).toContain("1 not valid address skipped");
  });

  test("a re-send counts as sent and says so", () => {
    const r = summariseInvites({ invited: [], resent: ["a@x.com"] }, 1);
    expect(r.tone).toBe("done");
    expect(r.detail).toContain("Sent again: a@x.com");
  });

  test("nothing to send (only members / invalid) is information, not success", () => {
    const r = summariseInvites({ invited: [], failed: [], already_member: ["me@x.com"], invalid: 2, duplicate: 1 }, 4);
    expect(r.tone).toBe("info");
    expect(r.title).toBe("Nothing to send");
    expect(r.detail).toContain("2 not valid addresses");
  });

  test("over the per-request cap is told, never dropped silently", () => {
    const r = summariseInvites({ invited: ["a@x.com"], over_cap: 20 }, 71);
    expect(r.detail).toContain("20 more than 50");
  });

  test("a missing report is not a success claim", () => {
    expect(summariseInvites(undefined, 3).tone).toBe("info");
  });
});
