import { expect, test } from "bun:test";
import { domainOf, domainsOf, lockView, needCheck, nextTryText, provenLine, type TlsFact } from "./tls_pure";
const f = (o: Partial<TlsFact>): TlsFact => ({ domain: "x.com", verdict: "pq", ...o });
test("domains come from addresses, lower case, distinct, valid only", () => {
  expect(domainOf("Ali@Example.COM")).toBe("example.com"); expect(domainOf("nope")).toBe("");
  expect(domainsOf(["a@B.com", "c@b.com", "d@e.org", "bad", "x@-y.com", "z@localhost"])).toEqual(["b.com", "e.org"]);
  expect(domainsOf(Array.from({ length: 80 }, (_, i) => `u@d${i}.com`)).length).toBe(50);
});
test("only domains without an answer are checked, at most 10", () => {
  const now = Date.now();
  expect(needCheck(["a.com", "b.com"], { "a.com": f({ domain: "a.com" }) }, now)).toEqual(["b.com"]);
  expect(needCheck(["a.com"], { "a.com": f({ verdict: "checking", checked_at: new Date(now - 5_000).toISOString() }) }, now)).toEqual([]);
  expect(needCheck(["a.com"], { "a.com": f({ verdict: "checking", checked_at: new Date(now - 200_000).toISOString() }) }, now)).toEqual(["a.com"]);
  expect(needCheck(Array.from({ length: 30 }, (_, i) => `d${i}.com`), {}, now).length).toBe(10);
});
test("every verdict has a tone, a label and a spoken text; there is no unknown", () => {
  const all = ["pq", "classic13", "classic12", "none", "refused", "unreachable", "nomail", "checking"] as const;
  for (const v of all) { const l = lockView(f({ verdict: v })); expect(l.label.length).toBeGreaterThan(3); expect(l.aria.length).toBeGreaterThan(10); expect(JSON.stringify(l).toLowerCase()).not.toContain("unknown"); }
  expect(lockView(undefined).tone).toBe("checking"); expect(lockView(undefined).dotted).toBe(true);
  expect(lockView(f({ verdict: "pq" })).tone).toBe("pq"); expect(lockView(f({ verdict: "classic13" })).tone).toBe("classic"); expect(lockView(f({ verdict: "classic12" })).tone).toBe("old");
  expect(lockView(f({ verdict: "none" })).tone).toBe("warn"); expect(lockView(f({ verdict: "nomail" })).tone).toBe("nomail");
});
test("the tooltip carries group, version, certificate, source and time", () => {
  const l = lockView(f({ kex_group: "X25519MLKEM768", tls_version: "TLSv1.3", cert_verified: false, source: "probe", checked_at: new Date().toISOString() }));
  const t = l.lines.join(" | "); expect(t).toContain("X25519MLKEM768"); expect(t).toContain("1.3"); expect(t).toContain("NOT verified"); expect(t).toContain("a check from our server"); expect(t).toContain("Checked");
});
test("an unreachable domain shows its reason and its next try", () => {
  const now = Date.parse("2026-11-18T10:00:00Z"); const l = lockView(f({ verdict: "unreachable", next_try_at: "2026-11-18T10:05:00Z", detail: { detail: "mx.x.com: connection refused", hosts_tried: ["mx.x.com"] } }), now);
  expect(l.label).toContain("next try"); expect(l.dotted).toBe(true); expect(l.lines.join(" ")).toContain("connection refused"); expect(l.lines.join(" ")).toContain("mx.x.com");
  expect(lockView(f({ verdict: "unreachable", next_try_at: null }), now).lines.join(" ")).toContain("No more tries");
  expect(nextTryText("2026-11-18T09:00:00Z", now)).toContain("any moment");
});
test("the proven line names only real deliveries and says when the check was wrong", () => {
  const facts = { "a.com": f({ domain: "a.com", source: "sent", proven_verdict: "pq" }), "b.com": f({ domain: "b.com", source: "sent", proven_verdict: "classic13", mismatch: true }), "c.com": f({ domain: "c.com", source: "probe" }) };
  const s = provenLine(facts, ["a.com", "b.com", "c.com"]); expect(s).toContain("a.com: post-quantum"); expect(s).toContain("b.com: TLS 1.3 (the check had predicted another lock)"); expect(s).not.toContain("c.com");
  expect(provenLine(facts, ["c.com"])).toBe("");
});
