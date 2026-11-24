import { describe, expect, test } from "bun:test";
import { chainWords, kindWords, parseBoard, probeWords } from "./desk_ledger_pure";
const good = () => ({ generated_at: "2026-11-24T04:00:00Z", lines: 40, newest_seq: 40, newest_at: "2026-11-24T03:59:00Z", window_lines: 40, chain_ok: true, probe: { ok: true, at: "2026-11-24T03:58:00Z" },
  tail: [{ seq: 40, at: "2026-11-24T03:59:00Z", kind: "package.publish", role: "owner" }, { seq: 39, at: "2026-11-24T03:58:00Z", kind: "alert.act", role: "agent" }], kinds_24h: [{ kind: "package.publish", n: 5 }, { kind: "alert.act", n: 2 }] });
describe("ledger board", () => {
  test("a good answer parses", () => { const b = parseBoard(good())!; expect(b.lines).toBe(40); expect(b.tail.length).toBe(2); expect(b.kinds[0].n).toBe(5); expect(chainWords(b).level).toBe("ok"); });
  test("a broken chain is shown as the loudest sentence, not hidden", () => { const g = good(); g.chain_ok = false; const b = parseBoard(g)!; expect(chainWords(b).level).toBe("outage"); expect(chainWords(b).text).toContain("does NOT verify"); });
  test("a probe that never ran is words, not a guess", () => { const g = good(); g.probe = { ok: null as unknown as boolean, at: null as unknown as string }; const b = parseBoard(g)!; expect(probeWords(b)).toContain("not run yet"); });
  test("a failed whole-chain probe says FAILED", () => { const g = good(); g.probe = { ok: false, at: "2026-11-24T03:58:00Z" }; expect(probeWords(parseBoard(g)!)).toContain("FAILED"); });
  test("fail-closed on every wrong shape", () => {
    const bad = (f: (v: any) => void) => { const v: any = good(); f(v); expect(parseBoard(v)).toBeNull(); };
    expect(parseBoard(null)).toBeNull(); expect(parseBoard({})).toBeNull();
    bad((v) => (v.tail[0].seq = 39)); bad((v) => (v.tail[1].seq = 41)); bad((v) => (v.tail[1].seq = 40)); bad((v) => (v.tail[0].role = "a@b.c"));
    bad((v) => (v.tail[0].kind = "Has Space")); bad((v) => (v.tail[0].detail = { x: 1 })); bad((v) => (v.window_lines = 41)); bad((v) => (v.window_lines = 2001));
    bad((v) => (v.lines = 10)); bad((v) => (v.kinds_24h = [{ kind: "a", n: 1 }, { kind: "b", n: 2 }])); bad((v) => (v.kinds_24h[0].n = 0)); bad((v) => (v.chain_ok = "yes"));
    bad((v) => (v.generated_at = "yesterday")); bad((v) => delete v.probe); bad((v) => (v.email = "a@b.c")); bad((v) => (v.probe = { ok: true, at: null }));
    bad((v) => (v.tail = Array.from({ length: 21 }, (_, i) => ({ seq: 40 - i, at: "2026-11-24T03:59:00Z", kind: "alert.act", role: "system" }))));
    bad((v) => (v.kinds_24h = Array.from({ length: 9 }, (_, i) => ({ kind: "k" + i, n: 9 - i }))));
  });
  test("an empty ledger is a real answer", () => { const b = parseBoard({ ...good(), lines: 0, newest_seq: null, newest_at: null, window_lines: 0, tail: [], kinds_24h: [] })!; expect(b.lines).toBe(0); expect(chainWords(b).text).toContain("empty"); });
  test("words never carry a detail or an address", () => { const t = JSON.stringify(parseBoard(good())); expect(t.includes("@")).toBe(false); expect(kindWords("package.publish")).toBe("package publish"); });
});
