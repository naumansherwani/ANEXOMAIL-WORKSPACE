import { expect, test } from "bun:test";
import { changedPlans, parsePlanDigest, planKey } from "./desk_plans_pure";
const fp = (c: string) => c.repeat(64), d = (...x: [string, number, string][]) => ({ n: x.length, plans: x.map(([pkg, version, c]) => ({ pkg, version, fp: fp(c) })) });
test("a well-formed digest parses, a wrong shape never does", () => {
  expect(parsePlanDigest(d(["basic", 1, "a"]))?.n).toBe(1);
  expect(parsePlanDigest(null)).toBeNull(); expect(parsePlanDigest({ n: 2, plans: [] })).toBeNull(); expect(parsePlanDigest({ n: 1, plans: [{ pkg: "Basic", version: 1, fp: fp("a") }] })).toBeNull();
  expect(parsePlanDigest({ n: 1, plans: [{ pkg: "basic", version: 0, fp: fp("a") }] })).toBeNull(); expect(parsePlanDigest({ n: 1, plans: [{ pkg: "basic", version: 1, fp: "zz" }] })).toBeNull();
  expect(parsePlanDigest({ n: 65, plans: [] })).toBeNull();
});
test("an empty catalogue is a real digest (zero is data)", () => { expect(parsePlanDigest({ n: 0, plans: [] })).toEqual({ n: 0, plans: [] }); expect(planKey(parsePlanDigest({ n: 0, plans: [] }))).toBe(""); });
test("a changed feature changes the key and names the plan; a new plan counts; the same digest changes nothing", () => {
  const a = parsePlanDigest(d(["basic", 1, "a"], ["pro", 1, "b"])), b = parsePlanDigest(d(["basic", 1, "a"], ["pro", 2, "c"])), c = parsePlanDigest(d(["basic", 1, "a"], ["pro", 1, "b"], ["business", 1, "d"]));
  expect(planKey(a)).not.toBe(planKey(b)); expect(changedPlans(a, b)).toEqual(["pro"]); expect(changedPlans(a, c)).toEqual(["business"]); expect(changedPlans(a, a)).toEqual([]); expect(changedPlans(null, b)).toEqual([]);
});
