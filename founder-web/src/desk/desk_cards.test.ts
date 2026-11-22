import { expect, test } from "bun:test";
import { CARDS, chordTarget, shortcutLabel, typingTarget, alertFilter, asAlerts, cardProblems, cardById, deskSub, filterAlerts, route } from "./desk_cards";
test("the registry has no dead card: every card has a route, a phase, and says what it waits for", () => { expect(cardProblems()).toEqual([]); expect(CARDS.length).toBeGreaterThanOrEqual(11); });
test("the registry checker really catches a dead card", () => {
  const bad = { id: "x", key: "a", label: "X", track: "nope" as never, phase: "Z", wired: true, onBar: false, what: "w", waits: "" };
  expect(cardProblems([bad]).length).toBeGreaterThan(0); expect(cardProblems([{ ...bad, track: null, wired: false }])).toContain("x: not wired, must say what it waits for");
});
test("routes and subs", () => { expect(route("alerts")).toBe("/dashboard/alerts"); expect(deskSub("/dashboard/alerts/")).toBe("alerts"); expect(deskSub("/dashboard")).toBe(""); expect(cardById("nope")).toBeNull(); });
const rows = asAlerts([
  { id: "a", severity: "critical", status: "new" }, { id: "b", severity: "critical", status: "resolved" }, { id: "c", severity: "high", status: "new" }, { id: "d", severity: "info", status: "ack" },
])!;
test("P1 = critical and not closed; unacked = new (same as the summary SQL)", () => {
  expect(filterAlerts(rows, alertFilter("?severity=p1")).map((r) => r.id)).toEqual(["a"]);
  expect(filterAlerts(rows, alertFilter("?status=unacked")).map((r) => r.id)).toEqual(["a", "c"]);
  expect(filterAlerts(rows, alertFilter("")).length).toBe(4); expect(asAlerts("x")).toBeNull(); expect(asAlerts([{ id: 1 }])).toBeNull();
});

test("shortcuts: g arms, then a letter opens its card, g d goes home, keys are unique", () => {
  expect(chordTarget(false, "g")).toBe("arm"); expect(chordTarget(false, "a")).toBeNull();
  expect(chordTarget(true, "a")).toBe("/dashboard/alerts"); expect(chordTarget(true, "S")).toBe("/dashboard/services"); expect(chordTarget(true, "d")).toBe("/dashboard"); expect(chordTarget(true, "z")).toBeNull();
  expect(shortcutLabel("alerts")).toBe("G then A"); expect(shortcutLabel("home")).toBe("G then D");
  expect(new Set(CARDS.map((c) => c.key)).size).toBe(CARDS.length);
  expect(typingTarget({ tagName: "INPUT" })).toBe(true); expect(typingTarget({ tagName: "DIV" })).toBe(false); expect(typingTarget(null)).toBe(false);
});
