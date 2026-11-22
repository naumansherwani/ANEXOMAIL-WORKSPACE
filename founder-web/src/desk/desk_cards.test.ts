import { expect, test } from "bun:test";
import { CARDS, alertFilter, asAlerts, cardProblems, cardById, deskSub, filterAlerts, route } from "./desk_cards";
test("the registry has no dead card: every card has a route, a phase, and says what it waits for", () => { expect(cardProblems()).toEqual([]); expect(CARDS.length).toBeGreaterThanOrEqual(11); });
test("the registry checker really catches a dead card", () => {
  const bad = { id: "x", label: "X", track: "nope" as never, phase: "Z", wired: true, onBar: false, what: "w", waits: "" };
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
