import { expect, test } from "bun:test";
import { ACT_LABEL, CARDS, actBody, actMessage, actsFor, chordTarget, comboTarget, needsConfirm, shortcutLabel, typingTarget, alertFilter, asAlerts, cardProblems, cardById, deskSub, filterAlerts, route } from "./desk_cards";
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
  expect(filterAlerts(rows, alertFilter("?severity=urgent")).map((r) => r.id)).toEqual(["a"]);
  expect(filterAlerts(rows, alertFilter("?status=unacked")).map((r) => r.id)).toEqual(["a", "c"]);
  expect(filterAlerts(rows, alertFilter("")).length).toBe(4); expect(asAlerts("x")).toBeNull(); expect(asAlerts([{ id: 1 }])).toBeNull(); expect(asAlerts([{ id: {}, severity: "high", status: "new" }])).toBeNull();
});

test("shortcuts: g arms, then a letter opens its card, g d goes home, keys are unique", () => {
  expect(chordTarget(false, "g")).toBe("arm"); expect(chordTarget(false, "a")).toBeNull();
  expect(chordTarget(true, "a")).toBe("/dashboard/alerts"); expect(chordTarget(true, "S")).toBe("/dashboard/services"); expect(chordTarget(true, "d")).toBe("/dashboard"); expect(chordTarget(true, "z")).toBeNull();
  expect(shortcutLabel("alerts")).toBe("Alt+Shift+A"); expect(shortcutLabel("home")).toBe("Alt+Shift+D");
  expect(new Set(CARDS.map((c) => c.key)).size).toBe(CARDS.length);
  expect(typingTarget({ tagName: "INPUT" })).toBe(true); expect(typingTarget({ tagName: "DIV" })).toBe(false); expect(typingTarget(null)).toBe(false);
});

test("the database sends id as a number and detail as an object: both are read", () => {
  const r = asAlerts([{ id: 42, severity: "critical", status: "new", detail: { service: "clamav", state: "outage" }, assignee: null }])!;
  expect(r[0].num).toBe(42); expect(r[0].id).toBe("42"); expect(r[0].detail).toBe("service: clamav · state: outage");
});
test("modifier shortcut: Alt+Shift+letter opens the card, others do not", () => {
  const e = (code: string, o: object = {}) => ({ code, altKey: true, shiftKey: true, ctrlKey: false, metaKey: false, ...o });
  expect(comboTarget(e("KeyA"))).toBe("/dashboard/alerts"); expect(comboTarget(e("KeyD"))).toBe("/dashboard"); expect(comboTarget(e("KeyZ"))).toBeNull();
  expect(comboTarget(e("KeyA", { ctrlKey: true }))).toBeNull(); expect(comboTarget(e("KeyA", { shiftKey: false }))).toBeNull(); expect(comboTarget(e("Digit1"))).toBeNull();
});
test("D2 alert actions follow the status, closing needs a confirm, bodies match the door", () => {
  expect(actsFor("new")).toEqual(["ack", "resolve", "false_positive"]); expect(actsFor("ack")).toEqual(["progress", "resolve", "false_positive"]); expect(actsFor("resolved")).toEqual([]);
  expect(needsConfirm("resolve")).toBe(true); expect(needsConfirm("ack")).toBe(false); expect(ACT_LABEL.false_positive).toBe("False alarm");
  expect(actBody(7, "ack")).toEqual({ alert: 7, event: "ack" }); expect(actBody(7, "resolve")).toEqual({ alert: 7, event: "status", status: "resolved" });
  expect(actMessage(200).ok).toBe(true); expect(actMessage(403).text).toContain("yourself"); expect(actMessage(422).ok).toBe(false); expect(actMessage(500).ok).toBe(false);
});

import { ctrlHomeTarget as _ctrlHome } from "./desk_cards";
import { describe as _d, test as _t, expect as _e } from "bun:test";
_d("Ctrl+D goes to the Dashboard (his 23 Nov 06:42 word)", () => {
  const k = (o: Partial<{ code: string; altKey: boolean; shiftKey: boolean; ctrlKey: boolean; metaKey: boolean }>) => ({ code: "KeyD", altKey: false, shiftKey: false, ctrlKey: true, metaKey: false, ...o });
  _t("Ctrl+D only", () => { _e(_ctrlHome(k({}))).toBe("/dashboard"); _e(_ctrlHome(k({ shiftKey: true }))).toBeNull(); _e(_ctrlHome(k({ altKey: true }))).toBeNull(); _e(_ctrlHome(k({ metaKey: true }))).toBeNull(); _e(_ctrlHome(k({ ctrlKey: false }))).toBeNull(); _e(_ctrlHome(k({ code: "KeyE" }))).toBeNull(); });
});

test("a card can sit on a digit key: Alt+Shift+8 opens Customers and plans", () => { const e = { code: "Digit8", altKey: true, shiftKey: true, ctrlKey: false, metaKey: false }; expect(comboTarget(e)).toBe("/dashboard/customers"); expect(comboTarget({ ...e, ctrlKey: true })).toBeNull(); });
