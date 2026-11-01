// G4 (E120) guard: the rollback/rewrite check and the gauge wording are pure and must never regress.
import { expect, test } from "bun:test";
import { asSeal, fmtAge, judgePin, ledgerGauge, shouldAdvancePin, withExtension, type Seal } from "./sealpin";

const h = (c: string) => c.repeat(64);
const seal = (id: number, root = h("a"), cp = h("b"), upto = id * 50): Seal => ({ id, upto_seq: upto, root, cp_hash: cp });
const t = (ms: number) => `T${ms}`;

test("asSeal accepts only the exact database shape", () => {
  expect(asSeal({ id: 3, upto_seq: 150, root: h("a"), cp_hash: h("b") })).toEqual(seal(3));
  for (const bad of [null, 5, {}, { id: 0, upto_seq: 1, root: h("a"), cp_hash: h("b") }, { id: 1, upto_seq: 1, root: "xyz", cp_hash: h("b") },
    { id: 1, upto_seq: 1, root: h("A"), cp_hash: h("b") }, { id: 1.5, upto_seq: 1, root: h("a"), cp_hash: h("b") }, { id: 1, upto_seq: 1, root: h("a") }]) expect(asSeal(bad as any)).toBeNull();
});
test("first visit remembers; the same seal matches", () => {
  expect(judgePin(null, seal(2), null).state).toBe("new");
  expect(judgePin(seal(2), seal(2), null).state).toBe("same");
});
test("a server that is behind what this browser saw is a ROLLBACK, also when it shows no seal at all", () => {
  expect(judgePin(seal(5), seal(3), null).state).toBe("rollback");
  expect(judgePin(seal(5), null, null).state).toBe("rollback");
  expect(judgePin(seal(5), { ...seal(5), upto_seq: 200 }, null).state).toBe("rollback"); // same id but it now covers fewer entries: also a rollback
});
test("same id but different root or cp_hash is a REWRITE", () => {
  expect(judgePin(seal(2), seal(2, h("c")), null).state).toBe("rewritten");
  expect(judgePin(seal(2), seal(2, h("a"), h("d")), null).state).toBe("rewritten");
});
test("when the server moved ahead, the old seal must still read the same", () => {
  expect(judgePin(seal(2), seal(4), seal(2)).state).toBe("advanced");
  expect(judgePin(seal(2), seal(4), seal(2, h("c"))).state).toBe("rewritten");
  expect(judgePin(seal(2), seal(4), "error").state).toBe("unchecked");
  expect(judgePin(seal(2), seal(4), null).state).toBe("unchecked");
});
test("the pin moves forward only after a proven-good verdict, never after a rollback or rewrite", () => {
  for (const [v, want] of [["new", true], ["advanced", true], ["same", false], ["unchecked", false], ["rollback", false], ["rewritten", false]] as const) expect(shouldAdvancePin({ state: v, text: "" })).toBe(want);
});
test("age wording", () => {
  expect(fmtAge(10)).toBe("just now"); expect(fmtAge(600)).toBe("10 min ago"); expect(fmtAge(7200)).toBe("2 h ago"); expect(fmtAge(3 * 86400)).toBe("3 days ago"); expect(fmtAge(-5)).toBe("just now");
});

const pulse = (o: any = {}) => ({ connected: true, pulse: { level: "ok", rows: 60, lag_rows: 10, every_rows: 50, checker: "ok", sealer_stalled: false,
  last_checkpoint: { id: 1, upto_seq: 50, created_ms: 1000 }, full_check: { age_s: 600, rows: 60, chain_ok: true, cp_ok: true }, ...o } });
test("a healthy ledger is ok and says every real fact", () => {
  const g = ledgerGauge(pulse(), { n: 5, ok: 5 }, { state: "same", text: "seal #1 matches what this browser remembered" }, t);
  expect(g.state).toBe("ok"); expect(g.chip).toBe("#1");
  expect(g.text).toContain("60 entries, sealed up to entry 50 at T1000, 10 since");
  expect(g.text).toContain("full check 10 min ago: 60 entries intact");
  expect(g.text).toContain("5 of 5 entries proven in this browser");
  expect(g.text).toContain("matches what this browser remembered");
});
test("not answering / not installed / E120 not installed never invent a claim", () => {
  expect(ledgerGauge(null, null, null, t)).toEqual({ state: "fail", text: "Not answering" });
  expect(ledgerGauge({ connected: false, note: "Install" }, null, null, t).state).toBe("unknown");
  const old = pulse(); delete (old.pulse as any).checker; delete (old.pulse as any).full_check;
  const g = ledgerGauge(old, null, null, t); expect(g.state).toBe("ok"); expect(g.text).not.toContain("full check");
});
test("every loophole turns the gauge: never checked, stale checker, stalled sealer, failed proof, rollback", () => {
  expect(ledgerGauge(pulse({ checker: "never", full_check: null }), null, null, t).state).toBe("warn");
  expect(ledgerGauge(pulse({ checker: "stale" }), null, null, t).state).toBe("warn");
  expect(ledgerGauge(pulse({ sealer_stalled: true }), null, null, t).state).toBe("warn");
  expect(ledgerGauge(pulse(), "failed", null, t).state).toBe("warn");
  expect(ledgerGauge(pulse(), "failed", null, t).text).toContain("browser proof unavailable");
  expect(ledgerGauge(pulse(), { n: 5, ok: 4 }, null, t).state).toBe("fail");
  expect(ledgerGauge(pulse(), null, { state: "rollback", text: "this browser saw seal #5" }, t).state).toBe("fail");
  expect(ledgerGauge(pulse(), null, { state: "rewritten", text: "seal #1 differs" }, t).text).toContain("Seal #1 differs");
  expect(ledgerGauge(pulse({ full_check: { age_s: 5, rows: 9, chain_ok: false, chain_bad_seq: 3, cp_ok: true }, level: "fail" }), null, null, t).text).toContain("chain broken at entry 3");
});
test("fail is never softened by a later warn", () => {
  const g = ledgerGauge(pulse({ level: "fail", sealer_stalled: true, checker: "stale" }), "failed", null, t);
  expect(g.state).toBe("fail");
});

test("a kernel-checked consistency proof upgrades or overrules the seal comparison", () => {
  const pin = seal(2), cur = seal(4);
  const adv = judgePin(pin, cur, seal(2)), unc = judgePin(pin, cur, "error"), same1 = judgePin(seal(4), seal(4), null);
  expect(withExtension(adv, "ok", pin, cur).state).toBe("advanced");
  expect(withExtension(adv, "ok", pin, cur).text).toContain("RFC 9162");
  expect(withExtension(unc, "ok", pin, cur).state).toBe("advanced");           // the proof settles a seal that could not be re-asked
  expect(withExtension(adv, "bad", pin, cur).state).toBe("rewritten");         // a refused proof beats a matching-looking seal
  expect(withExtension(unc, "bad", pin, cur).state).toBe("rewritten");
  expect(withExtension(adv, "absent", pin, cur)).toEqual(adv);                  // E121 not installed: the old comparison stays
  expect(withExtension(same1, "ok", seal(4), seal(4))).toEqual(same1);
  const rb = judgePin(seal(5), seal(3), null);
  expect(withExtension(rb, "ok", seal(5), seal(3)).state).toBe("rollback");     // a proof can never rescue a rollback
});

test("a server that moved ahead but gives NO usable proof can never move the remembered seal forward", () => {
  const pin = seal(2), cur = seal(4), adv = judgePin(pin, cur, seal(2));
  const na = withExtension(adv, "na", pin, cur);
  expect(na.state).toBe("unchecked");
  expect(shouldAdvancePin(na)).toBe(false);
  expect(shouldAdvancePin(withExtension(adv, "ok", pin, cur))).toBe(true);
  expect(shouldAdvancePin(withExtension(adv, "absent", pin, cur))).toBe(true);
  expect(shouldAdvancePin(withExtension(adv, "bad", pin, cur))).toBe(false);
  expect(withExtension(judgePin(pin, cur, "error"), "na", pin, cur).state).toBe("unchecked");   // stays unchecked
  const rb = judgePin(seal(5), seal(3), null);
  expect(withExtension(rb, "na", seal(5), seal(3))).toEqual(rb);
  expect(withExtension(rb, "ok", seal(5), seal(3)).state).toBe("rollback");
  const rw = judgePin(seal(2), seal(2, h("c")), null);
  expect(withExtension(rw, "ok", seal(2), seal(2, h("c"))).state).toBe("rewritten");
});
