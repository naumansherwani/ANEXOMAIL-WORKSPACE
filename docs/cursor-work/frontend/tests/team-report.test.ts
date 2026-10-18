import { describe, expect, test } from "bun:test";

import { describeSeats, describeWorkMail, summariseInvites } from "../../../../src/lib/team-report";

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

describe("seats — the database's own count, said honestly", () => {
  test("no information => says nothing (never a made-up limit)", () => {
    expect(describeSeats(undefined).tone).toBe("none");
    expect(describeSeats({ sql_missing: true }).tone).toBe("none");
    expect(describeSeats({ enforced: false, known: false }).line).toBe("");
    expect(describeSeats({ enforced: true, seats: 0 }).tone).toBe("none");
  });

  test("Business Pro is unlimited people", () => {
    const r = describeSeats({ unlimited: true, enforced: false, used: 41, pending: 2 });
    expect(r.tone).toBe("ok");
    expect(r.line).toBe("Unlimited people on your plan · 41 people in · 2 invitations waiting");
    expect(describeSeats({ unlimited: true, used: 1, pending: 0 }).line).toBe("Unlimited people on your plan · 1 person in");
  });

  test("per-seat plan: used / free / full", () => {
    const ok = describeSeats({ enforced: true, seats: 10, used: 4, pending: 1, free: 5 });
    expect(ok).toEqual({ line: "4 of 10 seats used · 1 invitation waiting · 5 seats free", tone: "ok" });
    expect(describeSeats({ enforced: true, seats: 3, used: 2, pending: 0, free: 1 }).tone).toBe("warn");
    const full = describeSeats({ enforced: true, seats: 1, used: 1, pending: 0, free: 0 });
    expect(full.tone).toBe("full");
    expect(full.line).toBe("1 of 1 seat used — no free seat. Add seats in Billing to invite more people.");
  });

  test("free is worked out when the server did not send it, and never negative", () => {
    expect(describeSeats({ enforced: true, seats: 5, used: 7, pending: 3 }).tone).toBe("full");
  });
});

describe("invitations that hit the seat limit or ask for a work address", () => {
  test("refused-for-seats are told, not dropped silently", () => {
    const r = summariseInvites({ invited: ["a@x.com"], over_seats: 2 }, 3);
    expect(r.tone).toBe("done");
    expect(r.detail).toContain("2 more people would go over your seats");
    expect(summariseInvites({ invited: ["a@x.com"], over_seats: 1 }, 2).detail).toContain("1 more person would go over");
  });

  test("the planned work address is named", () => {
    const r = summariseInvites({ invited: ["sara@x.com"], work_address: "sara@acme.com" }, 1);
    expect(r.detail).toContain("Work address sara@acme.com is created when they join.");
    expect(summariseInvites({ invited: ["a@x.com"], work_address: null }, 1).detail).not.toContain("Work address");
  });
});

describe("what a new joiner is told about their work address", () => {
  test("created / pending / each failure", () => {
    expect(describeWorkMail({ status: "created", address: "sara@acme.com" })).toBe("Your work address sara@acme.com is ready.");
    expect(describeWorkMail({ status: "pending" })).toContain("organiser can add a work address");
    expect(describeWorkMail(undefined)).toContain("organiser can add a work address");
    expect(describeWorkMail({ status: "failed", error: "address_taken" })).toContain("already taken");
    expect(describeWorkMail({ status: "failed", error: "mailbox_limit" })).toContain("used all its mailboxes");
    expect(describeWorkMail({ status: "failed", error: "domain_not_verified" })).toContain("not verified");
    expect(describeWorkMail({ status: "failed", error: "mailbox_failed" })).toContain("could not be created");
  });
});
