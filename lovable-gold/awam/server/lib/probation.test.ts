import { describe, expect, test } from "bun:test";
import { countRecipients, probationMessage, probationRule, probationTake } from "./probation";

describe("countRecipients", () => {
  test("arrays and strings, deduplicated case-insensitively across to/cc/bcc", () => {
    expect(countRecipients({ to: ["A@x.com", "b@x.com"], cc: "a@x.com, c@x.com; d@x.com", bcc: ["B@X.com"] })).toBe(4);
  });
  test("names and angle brackets", () => {
    expect(countRecipients({ to: "Ann <ann@x.com>, \"Bob\" <bob@y.org>" })).toBe(2);
  });
  test("junk in, zero out — never throws", () => {
    expect(countRecipients(null)).toBe(0);
    expect(countRecipients({ to: 5, cc: { a: 1 }, bcc: [null, 3] })).toBe(0);
    expect(countRecipients("x")).toBe(0);
  });
});

describe("probationRule", () => {
  test("send routes count, minimum 1 recipient", () => {
    expect(probationRule("POST", "/mail/send", { to: ["a@x.com", "b@x.com"] })).toEqual({ kind: "send", recipients: 2 });
    expect(probationRule("POST", "/mail/schedule/", { to: "" })).toEqual({ kind: "send", recipients: 1 });
    expect(probationRule("post", "/mail/outbox/send?x=1", { to: "a@x.com" })).toEqual({ kind: "send", recipients: 1 });
  });
  test("bulk imports", () => {
    expect(probationRule("POST", "/contacts/import", {})).toEqual({ kind: "bulk", recipients: 0 });
    expect(probationRule("POST", "/crm/leads/import", {})).toEqual({ kind: "bulk", recipients: 0 });
  });
  test("everything else is untouched (reads, drafts, other posts)", () => {
    expect(probationRule("GET", "/mail/send", {})).toBeNull();
    expect(probationRule("POST", "/mail/drafts", {})).toBeNull();
    expect(probationRule("POST", "/mail/send/extra", {})).toBeNull();
    expect(probationRule("POST", "/auth/login", {})).toBeNull();
  });
});

describe("probationTake", () => {
  const rule = { kind: "send" as const, recipients: 3 };
  test("SQL deny is honoured with reason, limit, until", async () => {
    const v = await probationTake("u", rule, async () => ({ data: { ok: false, reason: "probation_daily", limit: 50, until: "2026-10-30T00:00:00Z" }, error: null }));
    expect(v).toEqual({ ok: false, reason: "probation_daily", limit: 50, until: "2026-10-30T00:00:00Z" });
  });
  test("SQL allow", async () => {
    expect((await probationTake("u", rule, async () => ({ data: { ok: true, probation: false }, error: null }))).ok).toBe(true);
  });
  test("fail-open on error, null, garbage and throw — outage never locks the product", async () => {
    expect((await probationTake("u", rule, async () => ({ data: null, error: { message: "function does not exist" } }))).ok).toBe(true);
    expect((await probationTake("u", rule, async () => ({ data: null, error: null }))).ok).toBe(true);
    expect((await probationTake("u", rule, async () => ({ data: "weird", error: null }))).ok).toBe(true);
    expect((await probationTake("u", rule, async () => { throw new Error("boom"); })).ok).toBe(true);
  });
  test("passes the right arguments", async () => {
    let seen: any;
    await probationTake("uid-1", { kind: "bulk", recipients: 0 }, async (fn, args) => { seen = { fn, args }; return { data: { ok: true }, error: null }; });
    expect(seen).toEqual({ fn: "identity_probation_take", args: { p_account: "uid-1", p_kind: "bulk", p_recipients: 0 } });
  });
});

describe("probationMessage", () => {
  test("states the limit and the end date; never mentions identity internals", () => {
    const m = probationMessage({ ok: false, reason: "probation_recipients", limit: 20, until: "2026-10-30T10:00:00Z" });
    expect(m).toContain("20 people");
    expect(m).toContain("2026-10-30");
    for (const bad of [/finger/i, /vault/i, /hold/i, /banned/i, /review/i]) expect(m).not.toMatch(bad);
  });
  test("every reason has its own wording", () => {
    const set = new Set(["probation_recipients", "probation_daily", "probation_invites", "probation_links", "probation_bulk", "x"].map((r) => probationMessage({ ok: false, reason: r })));
    expect(set.size).toBe(6);
  });
});
