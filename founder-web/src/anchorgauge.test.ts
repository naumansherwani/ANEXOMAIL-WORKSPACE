import { describe, expect, test } from "bun:test";
import { asAnchorView, claimAgrees, judgeAnchor, type Checked, type Ev } from "./anchorgauge";
const D = "a".repeat(64), fmt = (ms: number) => String(ms);
const tsa: Ev = { provider: "freetsa", kind: "rfc3161", stage: "tsa_token", evidence_hex: "30", parsed: { gen_time_ms: 1000, signer_pin: "b".repeat(64) } };
const btc: Ev = { provider: "ots-alice", kind: "ots", stage: "ots_bitcoin", evidence_hex: "00", parsed: { btc_height: 900000, commit_hex: "c".repeat(64) } };
const pend: Ev = { provider: "ots-bob", kind: "ots", stage: "ots_pending", evidence_hex: "00", parsed: { commit_hex: "d".repeat(64) } };
const view = (lvl = "ok", ev: Ev[] = [tsa, btc]) => asAnchorView({ connected: true, anchor: { found: true, cp_id: 7, signed_ms: 1, note: "n", digest_hex: D, level: "strong", evidence: ev }, pulse: { level: lvl, why: "w" } });
const ok = (e: Ev): Checked => ({ ev: e, kernel: e === tsa ? `1000|01|${"b".repeat(64)}|x|9` : e === btc ? `bitcoin|900000|${"c".repeat(64)}` : `pending|0|${"d".repeat(64)}` });

describe("time anchor gauge (G5c)", () => {
  test("missing SQL / bad shapes give no claim", () => {
    expect(asAnchorView(null)).toBeNull();
    expect(asAnchorView({ connected: false })).toBeNull();
    expect(asAnchorView({ connected: true, anchor: { found: true, note: "n", digest_hex: "zz", evidence: [] }, pulse: {} })).toBeNull();
    expect(judgeAnchor(null, null, [], fmt).state).toBe("unknown");
    expect(judgeAnchor(null, null, [], fmt, true).state).toBe("fail");
  });
  test("kernel-confirmed TSA + Bitcoin = time-anchored, Strong", () => {
    const v = judgeAnchor(view(), true, [ok(tsa), ok(btc)], fmt);
    expect(v.state).toBe("ok"); expect(v.chip).toBe("Strong");
    expect(v.text).toContain("time-anchored"); expect(v.text).toContain("Bitcoin block 900000");
    expect(v.text.toLowerCase()).not.toContain("witness");
  });
  test("a stored summary the kernel does not reproduce is a FAIL", () => {
    expect(judgeAnchor(view(), true, [{ ev: tsa, kernel: `999|01|${"b".repeat(64)}|x|9` }], fmt).state).toBe("fail");
    expect(judgeAnchor(view(), true, [{ ev: btc, kernel: null }], fmt).state).toBe("fail");
    expect(judgeAnchor(view(), false, [ok(tsa)], fmt).state).toBe("fail");
  });
  test("pending only is NOT a time claim", () => {
    const v = judgeAnchor(view("ok", [pend]), true, [ok(pend)], fmt);
    expect(v.state).toBe("warn"); expect(v.text).toContain("not time-anchored yet"); expect(v.chip).toBeUndefined();
  });
  test("kernel down never shows green", () => {
    expect(judgeAnchor(view(), true, [{ ev: tsa, kernel: undefined }], fmt).state).toBe("unknown");
    expect(claimAgrees({ ev: tsa, kernel: undefined })).toBeNull();
  });
  test("server pulse warn/fail wins over a good evidence row", () => {
    expect(judgeAnchor(view("fail"), true, [ok(tsa)], fmt).state).toBe("fail");
    expect(judgeAnchor(view("warn"), true, [ok(tsa)], fmt).text).toContain("w");
  });
});
