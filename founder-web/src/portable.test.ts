// G5d part 3 guard: the Portable pin wording and the "never trust an off-shape answer" rules.
import { expect, test } from "bun:test";
import { asPortableView, judgePortable } from "./portable";

const sha = "a".repeat(64), fmt = (ms: number) => `T${ms}`;
const good = { connected: true, found: true, bundle_text: "{\"v\":1}", bundle_sha: sha, horizon_cp: 2, head_cp: 3, rust_check: { ok: true } };
const facts = { horizon_cp: 2, head_cp: 3, horizon_size: 4, head_size: 9, origin: "o", tsa: 2, bitcoin: false, anchored_ms: 1000, proof_hashes: 2, not_covered_rows: 4 };

test("only the exact route shape reaches the kernel", () => {
  expect(asPortableView(good)).toEqual({ text: "{\"v\":1}", sha, rustOk: true, horizonCp: 2, headCp: 3 });
  expect(asPortableView({ connected: true, found: false })).toBe("none");
  expect(asPortableView({ connected: false })).toBe("none");
  for (const bad of [null, 3, { ...good, bundle_sha: "xyz" }, { ...good, bundle_sha: "A".repeat(64) }, { ...good, bundle_text: 5 }, { ...good, bundle_text: "x".repeat(2_000_001) }]) expect(asPortableView(bad as any)).toBeNull();
  expect((asPortableView({ ...good, rust_check: undefined }) as any).rustOk).toBeNull();
});
test("kernel accepted: one honest sentence with the dated authorities and the uncovered rows", () => {
  const v = judgePortable(asPortableView(good), { ok: true, passed: [], facts }, fmt);
  expect(v.state).toBe("ok");
  expect(v.text).toContain("seal #3 extends seal #2 unchanged");
  expect(v.text).toContain("2 time authorities");
  expect(v.text).toContain("T1000");
  expect(v.text).toContain("first 4 entries are before the horizon and not covered");
  expect(v.text).not.toContain("witness");
  expect(judgePortable(asPortableView(good), { ok: true, facts: { ...facts, bitcoin: true, tsa: 1, not_covered_rows: 0 } }, fmt).text).toContain("1 time authority and Bitcoin");
});
test("a kernel refusal is a FAIL naming the step; a kernel that could not run is only unknown", () => {
  const v = judgePortable(asPortableView(good), { ok: false, failed_step: "consistency", problem: "x" }, fmt);
  expect(v.state).toBe("fail"); expect(v.text).toContain("head extends the horizon");
  expect(judgePortable(asPortableView(good), undefined, fmt).state).toBe("unknown");
});
test("the server's Rust re-check disagreeing with the kernel is a FAIL", () => {
  expect(judgePortable(asPortableView({ ...good, rust_check: { ok: false } }), { ok: true, facts }, fmt).state).toBe("fail");
});
test("route down = fail, no bundle yet = unknown, junk = warn", () => {
  expect(judgePortable(null, undefined, fmt, true).state).toBe("fail");
  expect(judgePortable("none", undefined, fmt).state).toBe("unknown");
  expect(judgePortable(null, undefined, fmt).state).toBe("warn");
});
