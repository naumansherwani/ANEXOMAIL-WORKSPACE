import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { NEVER_LINE, POLICY_SENTENCE, SIX, approvalState, approvalWords, checkedWords, companyOk, doneCount, noPromise, parseRunbooks, parseTicks, sayFilled } from "./desk_runbook_pure";
const seed = JSON.parse(readFileSync(new URL("../../../docs/claude/admin-desk/runbooks.seed.json", import.meta.url), "utf8")) as { runbooks: { key: string; title: string; parts: Record<string, string>; steps: string[]; say_text: string }[] };
const wire = (r: (typeof seed.runbooks)[number], i: number) => ({ key: r.key, sort: i + 1, title: r.title, version_id: i + 1, version: "1.0.0", parts: r.parts, steps: r.steps, say_text: r.say_text, changelog: "x1", updated_at: "2026-11-23T00:00:00Z", approved_at: null, validated_at: null, stale: true });
describe("runbook pure logic", () => {
  test("the nine seeded runbooks parse, have six parts, the fixed never line, and no promise word", () => {
    expect(seed.runbooks.length).toBe(9);
    for (const r of seed.runbooks) { expect(Object.keys(r.parts)).toEqual([...SIX]); expect(r.parts.never).toContain(NEVER_LINE); expect(noPromise(r.say_text)).toBe(true); expect(noPromise(r.parts.say)).toBe(true); expect(r.steps.length).toBe(6); }
    const p = parseRunbooks(seed.runbooks.map(wire)); expect(p?.length).toBe(9); expect(p?.[0].key).toBe("R1");
  });
  test("no-promise list: every banned word fails, the policy sentence passes", () => {
    for (const b of ["I promise", "a guarantee", "It will be fixed", "will be restored", "a refund", "a credit", "compensation", "a discount", "it is free", "within 2 hours", "I will make sure", "100 percent", "for sure", "definitely"]) expect(noPromise(b)).toBe(false);
    expect(noPromise(POLICY_SENTENCE)).toBe(true); expect(noPromise("I can see your account.")).toBe(true); expect(noPromise("freedom of choice")).toBe(true);
  });
  test("fail closed: any odd shape is null", () => {
    const good = seed.runbooks.map(wire);
    expect(parseRunbooks(null)).toBeNull(); expect(parseRunbooks({})).toBeNull();
    expect(parseRunbooks([{ ...good[0], parts: { ...good[0].parts, extra: "x" } }])).toBeNull();
    expect(parseRunbooks([{ ...good[0], parts: { ...good[0].parts, clock: "" } }])).toBeNull();
    expect(parseRunbooks([{ ...good[0], steps: [] }])).toBeNull(); expect(parseRunbooks([{ ...good[0], steps: Array(13).fill("a") }])).toBeNull();
    expect(parseRunbooks([{ ...good[0], version_id: "1" }])).toBeNull(); expect(parseRunbooks([null])).toBeNull();
  });
  test("approval and checked words, 90-day stale", () => {
    const r = parseRunbooks(seed.runbooks.map(wire))![0];
    expect(approvalState(r)).toBe("draft"); expect(approvalWords(r)).toContain("Draft, waiting for the Chairman");
    const a = { ...r, approvedAt: "2026-11-23T01:00:00Z" }; expect(approvalState(a)).toBe("approved"); expect(approvalWords(a)).toContain("2026-11-23");
    expect(checkedWords(r, Date.now())).toBe("Not checked against real work yet");
    const v = { ...r, validatedAt: "2026-11-20T00:00:00Z", stale: false }; expect(checkedWords(v, Date.parse("2026-11-23T10:00:00Z"))).toBe("Checked 3 days ago");
    expect(checkedWords({ ...v, stale: true }, Date.parse("2027-03-01T00:00:00Z"))).toContain("check again");
  });
  test("say-this fills [case] and lists the other brackets", () => {
    const f = sayFilled("I have opened case [case] for [feature].", "C-1234"); expect(f.text).toBe("I have opened case C-1234 for [feature]."); expect(f.open).toEqual(["[feature]"]);
    expect(sayFilled("case [case]", "").open).toEqual(["[case]"]);
  });
  test("ticks parse and count; company shape", () => {
    expect(parseTicks([{ step: 0, done: true, by: "A", at: "t" }, { step: 1, done: false, by: "A", at: "t" }])?.length).toBe(2); expect(parseTicks([{ step: "0" }])).toBeNull();
    expect(doneCount(6, parseTicks([{ step: 0, done: true, by: "A", at: "t" }, { step: 1, done: false, by: "A", at: "t" }]))).toBe(1); expect(doneCount(6, null)).toBe(0);
    expect(companyOk("TESTCO001")).toBe(true); expect(companyOk("abc")).toBe(false); expect(companyOk("a b c d e f")).toBe(false);
  });
});
test("screen: asks only through deskCall, no phase names, no money words, slow answers for another company are dropped", () => {
  const t = readFileSync(new URL("./DeskRunbooks.tsx", import.meta.url), "utf8");
  expect(t).toContain("deskCall("); expect(t).not.toMatch(/\bfetch\(|WebSocket|XMLHttpRequest/); expect(t).toContain("curCo.current !== sent");
  const shown = [...t.matchAll(/>([^<>{}]{3,})</g)].map((m) => m[1]).join(" "); expect(shown).not.toMatch(/\b(1k|D5b|phase)\b/i); expect(shown).not.toMatch(/\b(invoice|card number|amount|price|£)\b/i);
  expect(t).toContain("Data unavailable".length ? "UNAVAILABLE_TEXT" : "");
});
