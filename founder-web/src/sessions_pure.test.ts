import { describe, expect, test } from "bun:test";
import { ago, alerts, canClose, closeWarning, countryName, flag, freshness, hasAlert, kindInfo, ms, othersLive, parseBoard, parseLedger, parseSession, reasonText, remaining, revokeText, ring, rowText, span, visible, type Board, type Sess } from "./sessions_pure";

const H = (c: string) => c.repeat(64);
const raw = (o: Record<string, unknown> = {}) => ({
  sid: "a".repeat(12), sid_hash: H("a"), current: true, live: true, method: "passkey", device: "d".repeat(12), key_source: "webcrypto", key_fp: "f".repeat(16), claimed_browser: "chrome", proven_browser: "chrome",
  spoof: { level: "ok", score: 0, reasons: [] }, protocol: "quic", path_badge: "HTTP/3 QUIC (WebTransport)", kernel: "0.14.0", integrity: { state: "verified", last_verified_at: "2026-11-10T20:00:00Z", ok: 5, fail: 0 },
  country: "PK", geo_state: "ok", net_flips: 0, fail_streak: 0, created_at: "2026-11-10T19:00:00Z", last_seen_at: "2026-11-10T20:00:00Z", revoked_at: null, revoke_reason: null, ...o,
});
const board = (o: Record<string, unknown> = {}) => ({ ok: true, sessions: [raw()], live: 1, live_with_alert: 0, policy: { geo_mode: "observe", countries: ["PK"], max_live: 20, idle_s: 86400, absolute_s: 604800 }, anchor: { ok: true, anchors_checked: 1 }, ledger_chain: { ok: true, checked: 9 }, limits: ["x"], ...o });
const S = (o: Record<string, unknown> = {}) => parseSession(raw(o)) as Sess;

describe("parsing never invents", () => {
  test("a good board parses and a not-ok / garbage board is null (the screen says 'not answering')", () => {
    const b = parseBoard({ data: board() });
    expect(b?.sessions.length).toBe(1);
    expect(b?.chainOk && b?.anchorOk).toBe(true);
    expect(b?.policy?.geoMode).toBe("observe");
    for (const bad of [null, undefined, 5, "x", [], {}, { ok: false }, { data: { ok: false, error: "shape" } }]) expect(parseBoard(bad)).toBeNull();
  });
  test("a row without a real 64-hex id is dropped, wrong types fall back, strings are bounded", () => {
    expect(parseSession(raw({ sid_hash: "short" }))).toBeNull();
    expect(parseSession(raw({ sid_hash: undefined }))).toBeNull();
    const s = S({ key_source: "evil", country: "pk", integrity: { state: 7 }, spoof: { level: "bogus", score: 9999, reasons: ["a", 3, null, "b"] }, kernel: undefined, created_at: "nonsense", device: "x".repeat(99) });
    expect([s.keySource, s.country, s.integrity.state, s.spoof.level, s.spoof.score, s.spoof.reasons, s.kernel, s.createdAt, s.device.length]).toEqual(["unknown", null, "unknown", "ok", 100, ["a", "b"], "unknown", null, 12]);
  });
  test("time parsing: ISO and epoch ms ok, invalid = null never now", () => {
    expect(ms("2026-11-10T20:00:00Z")).toBe(Date.parse("2026-11-10T20:00:00Z"));
    expect(ms(1700000000000)).toBe(1700000000000);
    for (const v of [null, undefined, "", "x", NaN, 0, -5, {}]) expect(ms(v)).toBeNull();
  });
  test("ledger rows: bad rows dropped, capped, facts only as an object", () => {
    const rows = parseLedger({ data: { rows: [{ id: 5, at_ms: 1, kind: "revoked", sid: "s", net: "n", kernel: "k", protocol: "h2", country: "PK", facts: { a: 1 } }, { id: -1 }, "x", { id: 6, kind: 3, facts: [1] }] } });
    expect(rows.map((r) => r.id)).toEqual([5, 6]);
    expect(rows[1].kind).toBe("unknown");
    expect(rows[1].facts).toEqual({});
    expect(parseLedger(null)).toEqual([]);
    expect(parseLedger({ rows: Array.from({ length: 500 }, (_, i) => ({ id: i })) }).length).toBe(200);
  });
});

describe("words: every SQL code has a sentence, unknown ones are shown as themselves", () => {
  test("known + unknown kinds, reasons and revoke reasons", () => {
    for (const k of ["registered", "seen", "net_flapping", "identity_drift", "geo_moved", "geo_refused", "session_cap", "anchored", "spoof_blocked", "nuke_others", "policy_changed", "expired", "integrity_fail", "revoked", "kernel_changed", "protocol_changed", "net_changed", "spoof_alert", "geo_observed"]) expect(kindInfo(k).text.startsWith("Unknown")).toBe(false);
    expect(kindInfo("<img onerror=1>").text).toBe("Unknown event (<img onerror=1>)");
    expect(reasonText("device_key_changed")).toBe("The device key changed");
    expect(reasonText("zzz")).toBe("Unknown reason (zzz)");
    expect(revokeText(null)).toBe("");
    expect(revokeText("session_shared")).toContain("sharing");
    expect(revokeText("weird")).toBe("Closed (weird)");
  });
  test("flags, country names, spans and relative time", () => {
    expect(flag("PK")).toBe("🇵🇰");
    expect(flag("pk")).toBe("");
    expect(flag(null)).toBe("");
    expect(countryName("PK")).toBe("Pakistan");
    expect(countryName(null)).toBe("Unknown country");
    expect(span(30)).toBe("30 s");
    expect(span(1800)).toBe("30 min");
    expect(span(86400)).toBe("24 h");
    expect(span(604800)).toBe("7 d");
    expect(span(-1)).toBe("unknown");
    const now = 1_000_000_000_000;
    expect(ago(null, now)).toBe("unknown");
    expect(ago(now - 10_000, now)).toBe("just now");
    expect(ago(now - 5 * 60_000, now)).toBe("5 minutes ago");
    expect(ago(now - 3 * 3600_000, now)).toBe("3 hours ago");
    expect(ago(now - 2 * 86400_000, now)).toBe("2 days ago");
  });
});

describe("the Trust Ring says only what is true", () => {
  const b = parseBoard({ data: board() }) as Board;
  test("all good = clear except the TCP/QUIC path, which warns when it is TCP", () => {
    expect(ring(S(), b).verdict).toBe("clear");
    const tcp = ring(S({ protocol: "h2", path_badge: "HTTP/2 over TCP" }), b);
    expect(tcp.verdict).toBe("attention");
    expect(tcp.arcs.find((a) => a.id === "path")?.state).toBe("warn");
  });
  test("a broken chain or a missed anchor is an alert and the text says why", () => {
    const broken = parseBoard({ data: board({ ledger_chain: { ok: false, broken_at: 42 } }) }) as Board;
    const r = ring(S(), broken);
    expect(r.verdict).toBe("alert");
    expect(r.arcs.find((a) => a.id === "chain")?.detail).toContain("row 42");
    const anchor = parseBoard({ data: board({ anchor: { ok: false, why: "rows_before_head_differ" } }) }) as Board;
    expect(ring(S(), anchor).arcs.find((a) => a.id === "chain")?.detail).toContain("rows_before_head_differ");
  });
  test("spoof, failed integrity, changed key = alert; no key = warn; missing data = unknown, never green", () => {
    expect(ring(S({ spoof: { level: "spoof", score: 90, reasons: ["claims_one_browser_proves_another"] } }), b).verdict).toBe("alert");
    expect(ring(S({ integrity: { state: "failed" } }), b).verdict).toBe("alert");
    expect(ring(S({ spoof: { level: "ok", score: 80, reasons: ["device_key_changed"] } }), b).arcs[0].state).toBe("bad");
    expect(ring(S({ key_source: "none", key_fp: "" }), b).arcs[0].state).toBe("warn");
    expect(ring(S({ spoof: { level: "suspect", score: 40, reasons: [] } }), b).verdict).toBe("attention");
    expect(ring(null, null).verdict).toBe("unknown");
    expect(ring(null, b).verdict).not.toBe("clear");
    const noChain = parseBoard({ data: board({ ledger_chain: {}, anchor: {} }) }) as Board;
    expect(ring(S(), noChain).arcs[3].state).toBe("unknown");
  });
});

describe("list, alerts, actions", () => {
  const list = [S(), S({ sid_hash: H("b"), sid: "b".repeat(12), current: false, claimed_browser: "firefox", proven_browser: "firefox", country: "DE" }),
    S({ sid_hash: H("c"), sid: "c".repeat(12), current: false, live: false, revoked_at: "2026-11-10T21:00:00Z", revoke_reason: "founder_nuke", country: "US" }),
    S({ sid_hash: H("d"), sid: "d".repeat(12), current: false, spoof: { level: "suspect", score: 40, reasons: ["no_device_key"] } })];
  test("filters and search", () => {
    expect(visible(list, "all", "").length).toBe(4);
    expect(visible(list, "live", "").length).toBe(3);
    expect(visible(list, "closed", "").length).toBe(1);
    expect(visible(list, "alert", "").length).toBe(1);
    expect(visible(list, "all", "germany").length).toBe(1);
    expect(visible(list, "all", "FIREFOX").length).toBe(1);
    expect(visible(list, "all", "zzzz").length).toBe(0);
    expect(visible(list, "all", "  ").length).toBe(4);
    expect(hasAlert(S({ net_flips: 3 }))).toBe(true);
    expect(hasAlert(S({ fail_streak: 1 }))).toBe(true);
    expect(hasAlert(S())).toBe(false);
  });
  test("alert strip counts only alert kinds from the last 24 hours, newest first", () => {
    const now = 1_000_000_000_000, mk = (id: number, kind: string, ago: number) => ({ id, atMs: now - ago, kind, sid: "", net: "", kernel: "", protocol: "h2", country: null, facts: {} });
    const a = alerts([mk(1, "geo_moved", 1000), mk(2, "geo_moved", 5000), mk(3, "seen", 10), mk(4, "net_flapping", 500), mk(5, "identity_drift", 30 * 3600_000), { ...mk(6, "geo_moved", 0), atMs: null }], now);
    expect(a.map((x) => [x.kind, x.count])).toEqual([["net_flapping", 1], ["geo_moved", 2]]);
  });
  test("row text and close warnings", () => {
    expect(rowText({ id: 1, atMs: 1, kind: "net_flapping", sid: "", net: "", kernel: "k", protocol: "h2", country: "PK", facts: { flips: 4 } })).toBe("The network keeps flipping: two machines may share this session · Pakistan · TCP · h2 · 4 network changes");
    expect(closeWarning(list[0])).toContain("signed out");
    expect(closeWarning(list[1])).toContain("Germany");
    expect(canClose(list[2])).toBe(false);
    expect(othersLive(parseBoard({ data: board({ sessions: list.map((s) => ({ ...raw(), sid_hash: s.sidHash, current: s.current, live: s.live })) }) }))).toBe(2);
    expect(othersLive(null)).toBe(0);
  });
  test("remaining time uses the smaller of idle and absolute; unknown stays unknown; freshness", () => {
    const pol = parseBoard({ data: board() })!.policy, now = Date.parse("2026-11-10T20:10:00Z");
    const r = remaining(S(), pol, now)!;
    expect(r.why).toBe("idle");
    expect(Math.round(r.secs)).toBe(86400 - 600);
    expect(remaining(S({ live: false }), pol, now)).toBeNull();
    expect(remaining(S(), null, now)).toBeNull();
    expect(remaining(S({ created_at: "2026-11-03T20:09:00Z" }), pol, now)!.why).toBe("absolute");
    expect(freshness(null, 1)).toBe("never");
    expect(freshness(1000, 1000 + 20000)).toBe("fresh");
    expect(freshness(1000, 1000 + 40000)).toBe("stale");
  });
});

import { bodyOf, changeText, changed, draftOf, parseBegun, parseCountries, refusalText, validate } from "./policy_change";
describe("D2b-5 policy change (pure)", () => {
  const pol = { geoMode: "off", countries: [], spoofAction: "alert", staleAfterS: 900, maxLive: 20, failLimit: 10, flapLimit: 4, flapAction: "alert", idleS: 86400, absoluteS: 604800 } as const;
  test("countries are parsed, upper-cased, de-duplicated, sorted; junk is named", () => {
    expect(parseCountries("pk, US  us;pk")).toEqual({ ok: ["PK", "US"], bad: [] });
    expect(parseCountries("PK, PAK, 1")).toEqual({ ok: ["PK"], bad: ["PAK", "1"] });
    expect(parseCountries("")).toEqual({ ok: [], bad: [] });
  });
  test("validate says the first problem in words and accepts a good change", () => {
    const d = { ...draftOf(pol), maxLive: 15 };
    expect(validate(d, "tightening the cap", pol)).toBe("");
    expect(validate(d, "short", pol)).toContain("8 to 200");
    expect(validate(d, "has <tag> inside", pol)).toContain("8 to 200");
    expect(validate(draftOf(pol), "no change at all here", pol)).toContain("Nothing is different");
    expect(validate({ ...d, geoMode: "enforce" }, "enforce without country", pol)).toContain("at least one allowed country");
    expect(validate({ ...d, countries: "PAK" }, "bad country code here", pol)).toContain("not a country code");
    expect(validate({ ...d, maxLive: 1 }, "cap too small here", pol)).toContain("Live sessions must be between 2 and 200");
    expect(validate({ ...d, idleS: 604801, absoluteS: 3600 }, "absolute below idle", pol)).toContain("absolute limit cannot be shorter");
  });
  test("changed ignores country order/case and body carries only the named fields", () => {
    const withC = { ...pol, countries: ["PK", "US"] };
    expect(changed({ ...draftOf(withC), countries: "us, pk" }, withC)).toBe(false);
    expect(changed({ ...draftOf(withC), countries: "pk" }, withC)).toBe(true);
    const b = bodyOf({ ...draftOf(pol), geoMode: "observe", countries: "pk, us" }, "  watching first  ");
    expect(b).toEqual({ geo_mode: "observe", countries: ["PK", "US"], spoof_action: "alert", stale_after_s: 900, max_live: 20, fail_limit: 10, flap_limit: 4, flap_action: "alert", idle_s: 86400, absolute_s: 604800, reason: "watching first" });
  });
  test("a begin answer is parsed only when complete; refusals never leak raw errors", () => {
    expect(parseBegun({})).toBeNull();
    expect(parseBegun({ ceremony: "c", hash: "h", options: {}, nonce: "n" })).toBeNull();
    const ok = parseBegun({ ceremony: "c", hash: "h", options: { challenge: "x" }, nonce: "n", params: { a: "1" }, changes: [{ field: "geo_mode", label: "Location lock", from: "off", to: "enforce" }, { nope: 1 }] });
    expect(ok?.changes.length).toBe(1);
    expect(changeText(ok!.changes[0])).toBe("Location lock: off → enforce");
    expect(changeText({ field: "countries", label: "Allowed countries", from: [], to: ["PK"] })).toBe("Allowed countries: none → PK");
    expect(refusalText(422, { error: "would_lock_you_out", note: "Refused: lock-out." })).toBe("Refused: lock-out.");
    expect(refusalText(429, null)).toContain("Too many");
    expect(refusalText(500, { error: "x".repeat(300) })).toBe("The change was not made.");
    expect(refusalText(403, { error: "your network changed while you were confirming: start again" })).toContain("network changed");
  });
});
