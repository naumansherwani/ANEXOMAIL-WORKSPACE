import { describe, expect, test } from "bun:test";
import {
  applyFix, attemptLine, badgeOf, describeWhen, domainOf, fromLocalInput, headline, humanDuration, MANY_LIMIT, partsIn, pollMs, presendChecks, presets, reasonLine, retryLine,
  scheduleOf, shouldWarn, stepTime, clockOf, stepTitle, toLocalInput, warnKey, zonedToMs, type Step, type TimelineView,
} from "./presend_pure";

const Z = (s: string) => Date.parse(s);
const ok = { to: ["a@x.com"], cc: [] as string[], bcc: [] as string[], subject: "Hello", text: "Hi there" };

describe("calm bar: what it notices", () => {
  test("a clean mail has no warning", () => expect(presendChecks(ok)).toEqual([]));
  test("an empty or blank subject is noticed, a real one is not", () => {
    expect(presendChecks({ ...ok, subject: "" }).map((w) => w.key)).toEqual(["subject"]);
    expect(presendChecks({ ...ok, subject: "   \t" }).map((w) => w.key)).toEqual(["subject"]);
    expect(presendChecks({ ...ok, subject: "x" })).toEqual([]);
  });
  test("exactly 20 people is fine, 21 gets the Bcc suggestion", () => {
    const mk = (n: number) => Array.from({ length: n }, (_, i) => `p${i}@x.com`);
    expect(MANY_LIMIT).toBe(20);
    expect(presendChecks({ ...ok, to: mk(20) })).toEqual([]);
    const w = presendChecks({ ...ok, to: mk(11), cc: mk(10).map((a) => "c" + a) });
    expect(w.map((x) => x.key)).toEqual(["many"]);
    expect(w[0]!.text).toContain("21 people");
    expect(w[0]!.fix?.kind).toBe("cc_to_bcc");
  });
  test("Bcc people are never counted (the whole point of Bcc)", () => {
    const mk = (n: number) => Array.from({ length: n }, (_, i) => `p${i}@x.com`);
    expect(presendChecks({ ...ok, bcc: mk(300) })).toEqual([]);
  });
  test("many in To only: the fix moves all but the first To; a single To has no fix", () => {
    const to = Array.from({ length: 25 }, (_, i) => `p${i}@x.com`);
    expect(presendChecks({ ...ok, to })[0]!.fix?.kind).toBe("to_to_bcc");
  });
  test("an unfilled {placeholder} is listed by name", () => {
    const w = presendChecks({ ...ok, text: "Dear {first_name}, see {link}" });
    expect(w.map((x) => x.key)).toEqual(["placeholder"]);
    expect(w[0]!.items).toEqual(["first_name", "link"]);
    expect(w[0]!.text).toContain("{first_name} {link}");
  });
  test("a domain with no mail server (QC1c) is named, once, however many people use it", () => {
    const tls = { "nomail.test": { verdict: "nomail" }, "x.com": { verdict: "pq" } };
    const w = presendChecks({ ...ok, to: ["a@nomail.test", "b@NoMail.test"], cc: ["c@x.com"], tls });
    expect(w.map((x) => x.key)).toEqual(["nomail"]);
    expect(w[0]!.items).toEqual(["nomail.test"]);
    expect(w[0]!.text).toContain("does not accept mail");
  });
  test("other lock verdicts (unreachable, classic, checking) are not warnings here", () => {
    for (const verdict of ["unreachable", "classic12", "none", "checking", "pq"]) expect(presendChecks({ ...ok, tls: { "x.com": { verdict } } })).toEqual([]);
  });
  test("several problems keep a fixed order", () => {
    const w = presendChecks({ ...ok, subject: "", text: "{a}", to: ["a@bad.test"], tls: { "bad.test": { verdict: "nomail" } } });
    expect(w.map((x) => x.key)).toEqual(["subject", "placeholder", "nomail"]);
  });
  test("domainOf survives odd input", () => {
    expect(domainOf("A@Example.COM")).toBe("example.com");
    for (const x of ["", "nodomain", "@x.com", "a@"]) expect(domainOf(x)).toBe("");
  });
});

describe("calm bar: it warns, it never blocks", () => {
  test("first press shows the bar, 'Send anyway' (acked) lets the same set through", () => {
    const w = presendChecks({ ...ok, subject: "" });
    expect(shouldWarn(w, "")).toBe(true);
    expect(shouldWarn(w, warnKey(w))).toBe(false);
  });
  test("nothing to say = never warn, whatever was acked", () => { expect(shouldWarn([], "")).toBe(false); expect(shouldWarn([], "old")).toBe(false); });
  test("a NEW problem after Send anyway brings the bar back once", () => {
    const a = presendChecks({ ...ok, subject: "" }), b = presendChecks({ ...ok, subject: "", text: "{x}" });
    expect(shouldWarn(b, warnKey(a))).toBe(true);
  });
  test("fixing the problem removes the bar (no stale ack needed)", () => { expect(shouldWarn(presendChecks(ok), "anything"))
    .toBe(false); });
  test("the fingerprint changes when the items change", () => {
    expect(warnKey(presendChecks({ ...ok, text: "{a}" }))).not.toBe(warnKey(presendChecks({ ...ok, text: "{b}" })));
  });
});

describe("one-press fixes lose nobody", () => {
  test("Cc moves to Bcc, duplicates are not added, case is ignored", () => {
    const r = applyFix("cc_to_bcc", { to: ["a@x.com"], cc: ["B@x.com", "c@x.com"], bcc: ["b@x.com"] });
    expect(r).toEqual({ to: ["a@x.com"], cc: [], bcc: ["b@x.com", "c@x.com"] });
  });
  test("To keeps its first person, the rest go to Bcc", () => {
    const r = applyFix("to_to_bcc", { to: ["a@x.com", "b@x.com", "c@x.com"], cc: ["d@x.com"], bcc: [] });
    expect(r).toEqual({ to: ["a@x.com"], cc: ["d@x.com"], bcc: ["b@x.com", "c@x.com"] });
  });
  test("empty To is safe", () => expect(applyFix("to_to_bcc", { to: [], cc: [], bcc: [] })).toEqual({ to: [], cc: [], bcc: [] }));
  test("the total number of distinct people never changes", () => {
    const l = { to: ["a@x.com", "b@x.com"], cc: ["c@x.com"], bcc: ["d@x.com"] }, n = (x: typeof l) => new Set([...x.to, ...x.cc, ...x.bcc]).size;
    expect(n(applyFix("cc_to_bcc", l))).toBe(n(l)); expect(n(applyFix("to_to_bcc", l))).toBe(n(l));
  });
});

describe("Asia/Karachi clock", () => {
  test("wall clock of an instant", () => {
    const p = partsIn(Z("2026-11-20T02:30:00Z"));
    expect([p.y, p.mo, p.d, p.h, p.mi, p.wd]).toEqual([2026, 11, 20, 7, 30, 5]);
  });
  test("midnight is hour 0, not 24", () => expect(partsIn(Z("2026-11-19T19:00:00Z")).h).toBe(0));
  test("wall time to instant, both ways", () => {
    expect(new Date(zonedToMs(2026, 11, 21, 9, 0)).toISOString()).toBe("2026-11-21T04:00:00.000Z");
    expect(toLocalInput(Z("2026-11-21T04:00:00Z"))).toBe("2026-11-21T09:00");
  });
  test("a zone with daylight time still lands right (New York, 9 Mar 2026 is EDT)", () => {
    expect(new Date(zonedToMs(2026, 3, 9, 9, 0, "America/New_York")).toISOString()).toBe("2026-03-09T13:00:00.000Z");
    expect(new Date(zonedToMs(2026, 3, 6, 9, 0, "America/New_York")).toISOString()).toBe("2026-03-06T14:00:00.000Z");
  });
});

describe("schedule presets", () => {
  const keys = (t: string) => presets(Z(t)).map((p) => p.key);
  test("Friday 07:30: all four, at the right instants", () => {
    const p = presets(Z("2026-11-20T02:30:00Z"));
    expect(p.map((x) => x.key)).toEqual(["later", "tonight", "tomorrow", "monday"]);
    expect(p.map((x) => x.at)).toEqual(["2026-11-20T05:30:00Z", "2026-11-20T15:00:00Z", "2026-11-21T04:00:00Z", "2026-11-23T04:00:00Z"]);
    expect(p.map((x) => x.when)).toEqual(["Today 10:30", "Today 20:00", "Tomorrow 09:00", "Mon 23 Nov, 09:00"]);
  });
  test("Later today rounds UP to the next five minutes", () => {
    expect(presets(Z("2026-11-20T02:32:10Z"))[0]!.at).toBe("2026-11-20T05:35:00Z");
    expect(presets(Z("2026-11-20T02:35:00Z"))[0]!.at).toBe("2026-11-20T05:35:00Z");
  });
  test("Later today vanishes when +3 h is already tomorrow", () => {
    expect(keys("2026-11-20T16:00:00Z")).toEqual(["tomorrow", "monday"]);          // 21:00 PKT
    expect(keys("2026-11-20T18:00:00Z")).toEqual(["tomorrow", "monday"]);          // 23:00 PKT
  });
  test("Tonight needs 30 minutes: 19:30 yes, 19:31 no", () => {
    expect(keys("2026-11-20T14:30:00Z")).toContain("tonight");                      // 19:30 PKT
    expect(keys("2026-11-20T14:31:00Z")).not.toContain("tonight");                  // 19:31 PKT
  });
  test("Tonight and Later today never show as two buttons for nearly the same time", () => {
    expect(keys("2026-11-20T12:00:00Z")).toEqual(["later", "tomorrow", "monday"]);       // 17:00 PKT: later = 20:00 = tonight, one button
    expect(keys("2026-11-20T11:40:00Z")).toEqual(["later", "tomorrow", "monday"]);       // 16:40 PKT: later 19:40 is 20 min from tonight
  });
  test("when Tonight comes before Later today the buttons are in time order", () => {
    expect(keys("2026-11-20T14:00:00Z")).toEqual(["tonight", "later", "tomorrow", "monday"]);   // 19:00 PKT: tonight 20:00, later 22:00 (same day)
  });
  test("Sunday: tomorrow IS Monday, so the Monday preset is not repeated", () => {
    expect(keys("2026-11-22T05:00:00Z")).toEqual(["later", "tonight", "tomorrow"]);
  });
  test("Saturday: Monday is two days away and is offered", () => {
    const p = presets(Z("2026-11-21T05:00:00Z")).find((x) => x.key === "monday")!;
    expect(p.at).toBe("2026-11-23T04:00:00Z"); expect(p.when).toBe("Mon 23 Nov, 09:00");
  });
  test("Monday: the next Monday is a week away", () => {
    expect(presets(Z("2026-11-23T05:00:00Z")).find((x) => x.key === "monday")!.at).toBe("2026-11-30T04:00:00Z");
  });
  test("crossing a month and a year end", () => {
    const p = presets(Z("2026-12-31T05:00:00Z"));                                    // Thu 31 Dec 10:00 PKT
    expect(p.find((x) => x.key === "tomorrow")!.at).toBe("2027-01-01T04:00:00Z");
    expect(p.find((x) => x.key === "monday")!.at).toBe("2027-01-04T04:00:00Z");
  });
  test("every preset is at least a minute ahead, strictly rising, whole minutes, UTC with Z", () => {
    for (let h = 0; h < 24 * 8; h++) {
      const now = Z("2026-11-20T00:00:00Z") + h * 3_600_000 + 17_000;
      const p = presets(now); let last = now;
      for (const x of p) { const t = Date.parse(x.at); expect(t).toBeGreaterThanOrEqual(now + 60_000); expect(t).toBeGreaterThan(last); last = t; expect(x.at).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:00Z$/); }
      expect(p.some((x) => x.key === "tomorrow")).toBe(true);
    }
  });
  test("labels read like a person said them", () => {
    expect(describeWhen(Z("2026-11-20T15:00:00Z"), Z("2026-11-20T02:30:00Z"))).toBe("Today 20:00");
    expect(describeWhen(Z("2026-11-21T04:00:00Z"), Z("2026-11-20T02:30:00Z"))).toBe("Tomorrow 09:00");
    expect(describeWhen(Z("2026-11-27T04:00:00Z"), Z("2026-11-20T02:30:00Z"))).toBe("Fri 27 Nov, 09:00");
  });
});

describe("custom time (datetime-local read in Karachi)", () => {
  test("a good value becomes the UTC instant", () => expect(fromLocalInput("2026-11-21T09:00")).toBe(Z("2026-11-21T04:00:00Z")));
  test("garbage and impossible dates are refused, not silently moved", () => {
    for (const v of ["", "2026-11-21", "2026-11-21 09:00", "2026-02-31T10:00", "2026-13-01T10:00", "2026-11-21T24:00", "x"]) expect(fromLocalInput(v)).toBeNull();
  });
  test("a time that does not exist (spring-forward gap) is refused", () => expect(fromLocalInput("2026-03-08T02:30", "America/New_York")).toBeNull());
  test("round trip", () => { const ms = Z("2026-12-05T11:25:00Z"); expect(fromLocalInput(toLocalInput(ms))).toBe(ms); });
  const now = Z("2026-11-20T02:30:00Z");
  test("nothing chosen = send now, no schedule", () => expect(scheduleOf("", now)).toEqual({ ok: true, at: "" }));
  test("a minute ahead is the edge", () => {
    expect(scheduleOf("2026-11-20T07:31", now)).toEqual({ ok: true, at: "2026-11-20T02:31:00Z" });
    expect(scheduleOf("2026-11-20T07:30", now)).toEqual({ ok: false, error: "Pick a time at least a minute from now." });
    expect(scheduleOf("2026-11-19T07:30", now).ok).toBe(false);
  });
  test("an impossible date gets its own plain reason", () => expect(scheduleOf("2026-02-31T10:00", now)).toEqual({ ok: false, error: "That date and time does not exist." }));
});

const view = (o: Partial<TimelineView> = {}, retry: Partial<TimelineView["retry"]> = {}): TimelineView => ({
  message_id: "m", phase: "deferred", tone: "warn", final: false, live: true, server_now: null, steps: [], attempts: [], events_truncated: false,
  outbox: { rcpt: 1, tls: null, dkim: null, sent_now: false, scheduled_by_founder: false, created_at: null, finished_at: null },
  retry: { attempts: 1, max_attempts: 12, remaining: 11, next_in_seconds: 240, give_up_in_seconds: 549_360, last_error: null, smtp_reply: null, explain: null, ...retry }, ...o,
});
const step = (key: Step["key"], state: Step["state"], detail: Step["detail"] = {}): Step => ({ key, state, at_ms: null, at: null, detail });

describe("step times", () => {
  test("ledger time wins, outbox time is the fallback, nothing is nothing", () => {
    expect(clockOf(Z("2026-11-20T09:02:11Z"))).toBe("14:02:11");
    expect(stepTime({ at_ms: Z("2026-11-20T09:02:11Z"), at: "2026-11-20T00:00:00Z" })).toBe("14:02:11");
    expect(stepTime({ at_ms: null, at: "2026-11-20T09:02:11Z" })).toBe("14:02:11");
    expect(stepTime({ at_ms: null, at: null })).toBe(""); expect(stepTime({ at_ms: null, at: "garbage" })).toBe(""); expect(clockOf(NaN)).toBe("");
  });
});

describe("timeline words", () => {
  test("durations read naturally and never say 0", () => {
    expect(humanDuration(0)).toBe("1 second"); expect(humanDuration(1)).toBe("1 second"); expect(humanDuration(45)).toBe("45 seconds");
    expect(humanDuration(60)).toBe("1 min"); expect(humanDuration(240)).toBe("4 min"); expect(humanDuration(7200)).toBe("2 hours"); expect(humanDuration(3600)).toBe("1 hour");
    expect(humanDuration(86_400)).toBe("1 day"); expect(humanDuration(549_360)).toBe("6 days"); expect(humanDuration(-5)).toBe("1 second");
  });
  test("accepted never says inbox, read or delivered", () => {
    for (const p of ["undo", "queued", "scheduled", "handing_off", "retrying", "deferred", "accepted", "failed", "cancelled", "undone", "unknown"] as const) expect(headline(p).toLowerCase()).not.toMatch(/inbox|\bread\b|\bdelivered\b(?<!not be delivered)/);
    expect(headline("accepted")).toBe("Accepted by the recipient's server");
  });
  test("step titles follow state and detail", () => {
    expect(stepTitle(step("hold", "active"))).toBe("Undo window running");
    expect(stepTitle(step("hold", "done", { sent_now: true }))).toBe("Send now pressed, undo window closed");
    expect(stepTitle(step("hold", "done", { undone: true }))).toBe("Taken back inside the undo window");
    expect(stepTitle(step("scheduled", "active"))).toBe("Waiting for the time you chose");
    expect(stepTitle(step("handoff", "done", { attempts: 3 }))).toBe("Handed over (3 tries)");
    expect(stepTitle(step("handoff", "done", { attempts: 1 }))).toBe("Handed over (1 try)");
    expect(stepTitle(step("handoff", "active", { attempts: 2 }))).toBe("Handing over, try 2");
    expect(stepTitle(step("outcome", "done", { phase: "accepted" }))).toBe("Accepted by the recipient's server");
    expect(stepTitle(step("outcome", "waiting", { phase: "deferred" }))).toBe("Waiting for the next try");
    expect(stepTitle(step("outcome", "failed", { phase: "failed" }))).toBe("Could not be delivered");
  });
  test("attempt lines say what happened and when (Karachi)", () => {
    expect(attemptLine({ n: 1, result: "deferred", at_ms: Z("2026-11-20T09:02:11Z") })).toBe("Try 1, 14:02:11: delayed (temporary refusal)");
    expect(attemptLine({ n: 2, result: "accepted", at_ms: null, tls: "tls13_pq" })).toBe("Try 2: accepted, post-quantum TLS");
    expect(attemptLine({ n: 3, result: "failed", at_ms: null })).toBe("Try 3: refused for good");
    expect(attemptLine({ n: 4, result: "in_flight", at_ms: null })).toBe("Try 4: in progress");
  });
  test("the retry sentence names the next try and the give-up horizon", () => {
    expect(retryLine(view())).toBe("The next try is in 4 min. We keep trying for up to about 6 days.");
    expect(retryLine(view({}, { next_in_seconds: 0 }))).toBe("The next try is happening now. We keep trying for up to about 6 days.");
    expect(retryLine(view({}, { next_in_seconds: null, give_up_in_seconds: null }))).toBeNull();
    expect(retryLine(view({ phase: "accepted" }))).toBeNull();
    expect(retryLine(view({ phase: "failed" }))).toBeNull();
  });
  test("the reason line is the server's plain explanation or nothing", () => {
    expect(reasonLine(view())).toBeNull();
    expect(reasonLine(view({}, { explain: { class: "permanent", code: "5.1.1", kind: "no_such_user", plain: "The address does not exist." } }))).toBe("The address does not exist.");
  });
  test("only mail that needs a glance gets a badge", () => {
    expect(badgeOf("accepted")).toBeNull(); expect(badgeOf("unknown")).toBeNull();
    expect(badgeOf("deferred")).toEqual({ text: "Delayed", tone: "warn" }); expect(badgeOf("retrying")).toEqual({ text: "Delayed", tone: "warn" });
    expect(badgeOf("failed")).toEqual({ text: "Failed", tone: "bad" }); expect(badgeOf("undo")?.text).toBe("Undo"); expect(badgeOf("scheduled")?.text).toBe("Scheduled");
  });
  test("polling: fast while leaving, slow while waiting, never when final", () => {
    expect(pollMs(view({ phase: "handing_off" }))).toBe(3000);
    expect(pollMs(view({ phase: "undo" }))).toBe(3000);
    expect(pollMs(view({ phase: "scheduled" }))).toBe(60_000);
    expect(pollMs(view({ phase: "deferred" }, { next_in_seconds: 240 }))).toBe(60_000);
    expect(pollMs(view({ phase: "deferred" }, { next_in_seconds: 1 }))).toBe(5_000);
    expect(pollMs(view({ phase: "deferred" }, { next_in_seconds: null }))).toBe(30_000);
    for (const phase of ["accepted", "failed", "cancelled", "undone"] as const) expect(pollMs(view({ phase, final: true }))).toBeNull();
    expect(pollMs(view({ phase: "unknown" }))).toBeNull();
  });
});
