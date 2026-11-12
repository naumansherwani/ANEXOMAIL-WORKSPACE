import { describe, expect, test } from "bun:test";
import { act, dotShade, DIM_CAP, DIM_FACTOR, flow, idleLabels } from "./laneflow_pure";

const L = (label: string, n: number | null) => ({ label, n });
describe("LA-7 map particles", () => {
  test("no idle lane = the old drawing exactly", () => {
    const ls = [L("New leads", 3), L("Polar events, 24 h", 9)];
    expect(flow(ls, new Set())).toEqual({ live: act(12), dim: 0 });
  });
  test("zero is quiet: no dots at all", () => { expect(flow([L("New leads", 0)], new Set())).toEqual({ live: 0, dim: 0 }); });
  test("an idle lane gives a few dim dots, the rest stay live", () => {
    const f = flow([L("a", 20), L("b", 40)], new Set(["b"]));
    expect(f.live).toBe(act(20)); expect(f.dim).toBe(Math.min(DIM_CAP, act(40)));
  });
  test("dim dots are capped and never bigger than live ceiling", () => { expect(flow([L("b", 100000)], new Set(["b"])).dim).toBe(DIM_CAP); expect(flow([L("a", 100000)], new Set()).live).toBe(70); });
  test("unknown count never draws and never dims", () => { expect(flow([L("a", null)], new Set())).toEqual({ live: 0, dim: 0 }); });
  test("shade: live 1, dim factor, rest 0", () => {
    const f = { live: 2, dim: 2 };
    expect([0, 1, 2, 3, 4].map((i) => dotShade(i, f))).toEqual([1, 1, DIM_FACTOR, DIM_FACTOR, 0]);
  });
  test("idleLabels uses the same rule as the row dimming", () => {
    const lt = { polar_events: { age_secs: 4000 }, leads: { age_secs: 5 } } as never;
    const s = idleLabels([L("Polar events, 24 h", 5), L("New leads", 2)], lt);
    expect(s.has("Polar events, 24 h")).toBe(true); expect(s.has("New leads")).toBe(false);
  });
});
