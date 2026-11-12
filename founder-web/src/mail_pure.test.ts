import { describe, expect, test } from "bun:test";
import { compact, glide, merge, pill, proofChip, rowText, verdicts, keyCmd, when, ago, isGatedView, FOLDERS, type Row } from "./mail_pure";

const R = (o: Partial<Row>): Row => ({ id: "a", thread_id: "t", folder: "inbox", direction: "in", received_ms: 1, size: 10, attach: 0, read: false, starred: false, draft: false, thread_count: 1, spf: "none", dkim: "none", dmarc: "none", arc: "none", lookalike: false, scan: "clean", tls: null, domain: null, seal_mode: "vault", gated: false, ...o });
describe("numbers", () => {
  test("compact", () => { expect([0, 999, 1000, 1234, 12_345, 1_250_000, -4, NaN].map(compact)).toEqual(["0", "999", "1k", "1.2k", "12k", "1.2M", "0", "0"]); });
  test("glide lands exactly and never overshoots", () => {
    expect(glide(3, 10, 0)).toBe(3); expect(glide(3, 10, 1)).toBe(10); expect(glide(3, 10, 2)).toBe(10); expect(glide(3, 10, NaN)).toBe(10);
    let last = 3; for (let t = 0; t <= 1; t += 0.05) { const v = glide(3, 10, t); expect(v).toBeGreaterThanOrEqual(last); expect(v).toBeLessThanOrEqual(10); last = v; }
    expect(glide(10, 3, 0.5)).toBeLessThan(10);
  });
  test("ago and when", () => { const n = Date.UTC(2026, 10, 13, 12); expect(ago(n - 30_000, n)).toBe("just now"); expect(ago(n - 5 * 60_000, n)).toBe("5 min ago"); expect(ago(0, n)).toBe("never"); expect(when(n, n)).toMatch(/^\d\d:\d\d$/); expect(when(n - 3 * 86400_000, n)).toMatch(/Nov$/); });
});
describe("rows", () => {
  test("a gated row leaks nothing", () => { const t = rowText(R({ gated: true, folder: "quarantine", sum: { subject: "SECRET", from: "x@y" } })); expect(t.locked).toBe(true); expect(JSON.stringify(t)).not.toContain("SECRET"); });
  test("a broken row is shown as unreadable, not hidden", () => { expect(rowText(R({ broken: true, sum: null })).subject).toBe("This message does not verify"); });
  test("an opened row shows sender, subject, snippet", () => { expect(rowText(R({ sum: { from_name: "Hana", from: "h@x.org", subject: "Clause 7", snippet: "hi" } }))).toMatchObject({ who: "Hana", subject: "Clause 7", snippet: "hi", locked: false }); });
  test("merge dedupes by id and keeps newest first", () => { const m = merge([R({ id: "a", received_ms: 5 }), R({ id: "b", received_ms: 9 })], [R({ id: "a", received_ms: 5, read: true }), R({ id: "c", received_ms: 7 })]); expect(m.map((r) => r.id)).toEqual(["b", "c", "a"]); expect(m[2].read).toBe(true); });
  test("quarantine and vault are the gated views", () => { expect(FOLDERS.filter((f) => f.gated).map((f) => f.key)).toEqual(["quarantine", "vault"]); expect(isGatedView("inbox")).toBe(false); });
});
describe("verdicts", () => {
  test("none is 'not checked', never a pass", () => { const v = verdicts(R({})); expect(v.find((x) => x.k === "spf")).toMatchObject({ text: "SPF not checked", tone: "off" }); });
  test("pass, fail, infected, look-alike", () => { const v = verdicts(R({ spf: "pass", dkim: "fail", scan: "infected", lookalike: true, tls: "tls13_pq" })); expect(v.map((x) => x.tone)).toEqual(["ok", "bad", "off", "bad", "bad", "ok"]); });
});
describe("ledger anchor chip", () => {
  const ok = { scope: "message" as const, found: true, anchored: true, seq: 41, row_hash: "a".repeat(64), prev_hash: "b".repeat(64), body_sha256_ledger: "c".repeat(64), body_sha256_now: "c".repeat(64), match: true, chain_ok_from_here: true, audit_seq: null };
  test("verified only when everything holds", () => { const c = proofChip(ok); expect(c.state).toBe("verified"); expect(c.detail.join(" ")).toContain("no Merkle proof is claimed"); });
  test("an audit anchor is named when there is one", () => { expect(proofChip({ ...ok, audit_seq: 7 }).detail.join(" ")).toContain("audit anchor #7"); });
  test("not anchored, mismatch, broken chain, missing proof are never green", () => {
    expect(proofChip({ ...ok, anchored: false }).state).toBe("unanchored"); expect(proofChip({ ...ok, match: false }).state).toBe("mismatch");
    expect(proofChip({ ...ok, chain_ok_from_here: false }).state).toBe("broken"); expect(proofChip(null).state).toBe("unknown"); expect(proofChip({ scope: "message", found: false }).state).toBe("unknown");
  });
});
describe("header pill", () => {
  test("all three measured", () => { const p = pill("h3", true, { seal_mode: "recipient_pq", key_id: "k1" }); expect([p.quic.ok, p.dbsc.ok, p.seal.ok]).toEqual([true, true, true]); expect(p.seal.text).toBe("PQC sealed"); });
  test("a failed check is stated, not hidden", () => { const p = pill("h2", false, { seal_mode: "recipient_pq", key_id: null }); expect(p.quic).toEqual({ ok: false, text: "H2 (not QUIC)" }); expect(p.dbsc.text).toBe("DBSC not verified"); expect(p.seal).toEqual({ ok: false, text: "PQC key missing" }); });
  test("vault mode says AES-256, not PQC", () => { expect(pill("h3", true, { seal_mode: "vault" }).seal.text).toBe("AES-256 sealed"); expect(pill(null, null, null).seal.ok).toBe(false); });
});
describe("keys", () => {
  test("single keys, g-prefix, modifiers ignored", () => { expect(keyCmd("j", {}, null)).toEqual({ cmd: "next" }); expect(keyCmd("g", {}, null)).toEqual({ pending: "g" }); expect(keyCmd("v", {}, "g")).toEqual({ cmd: "folder", arg: "vault" }); expect(keyCmd("j", { ctrl: true }, null)).toBeNull(); expect(keyCmd("x", {}, "g")).toBeNull(); });
});
