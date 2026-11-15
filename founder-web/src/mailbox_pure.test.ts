import { describe, expect, test } from "bun:test";
import { parseQuery, matchQuery, describeQuery, suggest, freshRows, arrivalLine, speedWords, isEmptyQuery, layoutFor } from "./mailbox_pure";
import type { Row } from "./mail_pure";

const R = (o: Partial<Row>): Row => ({ id: "a", thread_id: "t", folder: "inbox", direction: "in", received_ms: 1, size: 10, attach: 0, read: false, starred: false, draft: false, thread_count: 1, spf: "none", dkim: "none", dmarc: "none", arc: "none", lookalike: false, scan: "clean", tls: null, domain: null, seal_mode: "vault", gated: false, sum: { subject: "Draft agreement v3", from: "bilal@example.com", from_name: "Bilal Ahmed", snippet: "liability cap", to: ["me@x.com"] }, ...o });

describe("parseQuery", () => {
  test("operators and words", () => {
    const q = parseQuery('from:Bilal is:unread has:file "draft agreement" extra');
    expect(q.from).toEqual(["bilal"]); expect(q.unread).toBe(true); expect(q.file).toBe(true); expect(q.words).toEqual(["draft agreement", "extra"]);
  });
  test("unknown key:value stays a word, nothing dropped", () => { expect(parseQuery("size:big").words).toEqual(["size:big"]); });
  test("empty", () => { expect(isEmptyQuery(parseQuery("   "))).toBe(true); expect(describeQuery(parseQuery(""))).toBe(""); });
});
describe("matchQuery", () => {
  test("flags", () => {
    expect(matchQuery(R({ read: true }), parseQuery("is:unread"))).toBe(false);
    expect(matchQuery(R({ attach: 2 }), parseQuery("has:file"))).toBe(true);
    expect(matchQuery(R({ attach: 0 }), parseQuery("has:file"))).toBe(false);
    expect(matchQuery(R({ starred: true }), parseQuery("is:starred"))).toBe(true);
    expect(matchQuery(R({ thread_count: 3 }), parseQuery("is:thread"))).toBe(true);
  });
  test("text", () => {
    expect(matchQuery(R({}), parseQuery("from:bilal agreement"))).toBe(true);
    expect(matchQuery(R({}), parseQuery("from:sana"))).toBe(false);
    expect(matchQuery(R({}), parseQuery("liability"))).toBe(true);
    expect(matchQuery(R({}), parseQuery("to:me@x"))).toBe(true);
    expect(matchQuery(R({}), parseQuery("subject:v3"))).toBe(true);
  });
  test("sealed rows never match text, but flags still apply", () => {
    expect(matchQuery(R({ gated: true, sum: null }), parseQuery("agreement"))).toBe(false);
    expect(matchQuery(R({ gated: true, sum: null }), parseQuery("is:unread"))).toBe(true);
    expect(matchQuery(R({ broken: true, sum: null }), parseQuery("from:x"))).toBe(false);
  });
  test("empty query matches everything", () => { expect(matchQuery(R({ gated: true, sum: null }), parseQuery(""))).toBe(true); });
});
describe("describeQuery", () => { test("plain sentence", () => { expect(describeQuery(parseQuery("is:unread has:file from:ayesha"))).toBe("Showing mail unread, with a file, from ayesha"); }); });
describe("suggest", () => {
  test("prefix + senders from loaded rows only", () => {
    expect(suggest([R({})], "")).toContain("from:bilal"); expect(suggest([R({})], "is:u")).toEqual(["is:unread"]);
    expect(suggest([R({ gated: true, sum: null })], "").some((x) => x.startsWith("from:"))).toBe(false);
  });
});
describe("arrivals", () => {
  test("only new unread inbound rows, capped", () => {
    const a = R({ id: "1" }), b = R({ id: "2" }), c = R({ id: "3", read: true }), d = R({ id: "4", direction: "out" });
    expect(freshRows([a], [b, c, d, a]).map((r) => r.id)).toEqual(["2"]);
    expect(freshRows([], [R({ id: "1" }), R({ id: "2" }), R({ id: "3" }), R({ id: "5" })], 2).length).toBe(2);
  });
  test("a sealed row leaks nothing", () => { expect(arrivalLine(R({ gated: true, sum: null, folder: "vault" }))).toEqual({ who: "Confidential thread", what: "needs your key to open" }); expect(arrivalLine(R({})).who).toBe("Bilal Ahmed"); });
});
describe("speedWords", () => {
  test("null without a measurement, never a fake number", () => { expect(speedWords(null)).toBeNull(); expect(speedWords({ p50: null, n: 0 })).toBeNull(); expect(speedWords({ p50: 800, n: 0 })).toBeNull(); });
  test("ms and s", () => { expect(speedWords({ p50: 420, n: 1 })).toEqual({ value: "420", unit: "ms median", note: "from 1 real mail" }); expect(speedWords({ p50: 1800, n: 5 })).toEqual({ value: "1.8", unit: "s median", note: "from 5 real mails" }); });
});
describe("layoutFor", () => { test("breakpoints", () => { expect(layoutFor(390)).toBe("phone"); expect(layoutFor(820)).toBe("tablet"); expect(layoutFor(1200)).toBe("desktop"); }); });
