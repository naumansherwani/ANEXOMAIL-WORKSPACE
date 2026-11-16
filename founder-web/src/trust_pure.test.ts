import { describe, expect, test } from "bun:test";
import { ringSegments, gradeTone, unrated, ringLabel, arcs, reasonLine, outLine, sentMs, hhmmss } from "./trust_pure";
const F = (o: any = {}) => ({ spf: "pass", dkim: "pass", dmarc: "pass", arc: "none", lookalike: false, scan: "clean", tls: "tls13_pq", score: 100, grade: "A+", ...o });
describe("ring", () => {
  test("always eight segments in a fixed order", () => { expect(ringSegments(F()).map((s) => s.key)).toEqual(["spf", "dkim", "dmarc", "arc", "tls", "scan", "sender", "look"]); expect(ringSegments(F({ spf: "none" }))).toHaveLength(8); });
  test("none is grey and says not checked, never green", () => { const s = ringSegments(F({ spf: "none", dkim: "none", dmarc: "none", tls: null }), null); expect(s[0]).toMatchObject({ tone: "off", text: "not checked" }); expect(s[4]).toMatchObject({ tone: "off" }); expect(s[6]).toMatchObject({ tone: "off", text: "no history yet" }); });
  test("failures are red, soft failures amber", () => { const s = ringSegments(F({ spf: "softfail", dkim: "fail", dmarc: "permerror", lookalike: true, scan: "infected", tls: "none" })); expect(s[0].tone).toBe("warn"); expect(s[1].tone).toBe("bad"); expect(s[2].tone).toBe("bad"); expect(s[7].tone).toBe("bad"); expect(s[5].text).toBe("virus found"); expect(s[4]).toMatchObject({ tone: "bad", text: "no TLS" }); });
  test("tls words", () => { expect(ringSegments(F({ tls: "tls12" }))[4]).toMatchObject({ tone: "warn", text: "TLS 1.2" }); expect(ringSegments(F({ tls: "tls13" }))[4].text).toBe("TLS 1.3"); });
  test("sender history", () => { expect(ringSegments(F(), true)[6]).toMatchObject({ tone: "ok" }); expect(ringSegments(F(), false)[6]).toMatchObject({ tone: "warn", text: "first mails" }); });
  test("grades and the unrated state", () => { expect(["A+", "A", "B"].map(gradeTone)).toEqual(["ok", "ok", "ok"]); expect(["C", "D"].map(gradeTone)).toEqual(["warn", "warn"]); expect(gradeTone("F")).toBe("bad"); expect(gradeTone(null)).toBe("off");
    expect(unrated({ score: null, grade: null })).toBe(true); expect(unrated({ score: 0, grade: "F" })).toBe(false); expect(ringLabel(F())).toBe("Trust 100 of 100, grade A+"); expect(ringLabel(F({ score: null, grade: null }))).toBe("Trust: not checked"); });
  test("arcs cover the circle with gaps and never overlap", () => { const a = arcs(); expect(a).toHaveLength(8); for (let i = 0; i < 8; i++) { expect(a[i].end).toBeGreaterThan(a[i].start); if (i) expect(a[i].start).toBeGreaterThan(a[i - 1].end); } expect(a[7].end).toBeLessThan(360); });
  test("reason lines carry the points", () => { expect(reasonLine({ code: "x", delta: 55, text: "DMARC passed" })).toBe("+55 DMARC passed"); expect(reasonLine({ code: "x", delta: 0, text: "No DMARC" })).toBe("·No DMARC"); });
});
describe("outgoing facts (G3)", () => {
  const d = new Date(2026, 10, 17, 2, 41, 7).getTime();
  test("accepted: signed, TLS, the time of the 250", () => { const s = outLine({ found: true, accepted: true, sent_ms: d, reply: "250 2.0.0 OK", tls: "tls13_pq", dkim_signed: true, signatures: [{ selector: "a", alg: "ed25519-sha256" }, { selector: "b", alg: "rsa-sha256" }] }); expect(s).toBe("Signed by anexomail.com (Ed25519 + RSA), delivered over TLS 1.3 post-quantum, accepted by the receiver at 02:41:07 (250)."); });
  test("not yet accepted: no sent time", () => { const s = outLine({ found: true, accepted: false, state: "queued", signatures: [] }); expect(s).toContain("waiting to be sent"); expect(s).not.toMatch(/\d\d:\d\d:\d\d/); expect(s).toContain("Not signed"); });
  test("failed and retrying", () => { expect(outLine({ found: true, state: "failed", attempts: 3, dkim_signed: true })).toContain("not delivered (try 3)"); expect(outLine({ found: true, state: "sending" })).toContain("being delivered now"); expect(outLine(null)).toContain("not available"); });
  test("sent time is the 250 only", () => { expect(sentMs({ direction: "out", sent_ms: 5 })).toBe(5); expect(sentMs({ direction: "out", sent_ms: null })).toBeNull(); expect(sentMs({ direction: "in", sent_ms: 5 })).toBeNull(); expect(hhmmss(d)).toBe("02:41:07"); });
});
