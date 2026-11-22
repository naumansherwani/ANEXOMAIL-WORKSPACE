import { expect, test } from "bun:test";
import { asServices, asSummary, barModel, duration, ago } from "./desk_bridge_pure";
const svc = (service: string, state: string, extra: object = {}) => ({ service, label: service.toUpperCase(), critical: true, state, age_s: 3, last_latency_ms: 42, uptime_24h: 99.9, ...extra });
const sum = (p1: number) => ({ p1_open: p1, high_open: 2, unacked: 1, oldest_unacked_s: 125, incidents_open: 0, advisories_open: 0, critical_not_ok: 0, critical_unknown: 0, ledger_ok: true });
test("live bar shows the real numbers and rows", () => {
  const b = barModel("live", { summary: sum(0), services: [svc("db", "operational"), svc("tls", "degraded"), svc("clamav", "unknown")] });
  expect(b.fresh).toBe(true); expect(b.p1).toBe(0); expect(b.pulse).toBe(false); expect(b.high).toBe(2); expect(b.oldestUnacked).toBe("2 min 5 s"); expect(b.ledger).toBe("Chain verified");
  const by = Object.fromEntries(b.rows.map((r) => [r.key, r])); expect(by.db.state).toBe("ok"); expect(by.db.detail).toBe("42 ms · 3 s ago"); expect(by.tls.state).toBe("degraded"); expect(by.clamav.state).toBe("unknown"); expect(by.clamav.detail).toBe(""); // not measured = no made-up latency or age
  expect(by.h3_edge.text).toBe("Not measured"); expect(by.stream.text).toBe("Live · verified");
});
test("P1 >= 1 turns the red pulse on, only while the data is fresh", () => {
  expect(barModel("live", { summary: sum(1), services: [] }).pulse).toBe(true);
  expect(barModel("stale", { summary: sum(1), services: [] }).pulse).toBe(false);
});
test("a stale or offline stream shows Stale everywhere, never the last green", () => {
  for (const st of ["stale", "offline", "connecting"] as const) {
    const b = barModel(st, { summary: sum(0), services: [svc("db", "operational")] });
    expect(b.fresh).toBe(false); expect(b.p1).toBeNull(); expect(b.ledger).toBe("Not measured yet");
    expect(b.rows.every((r) => r.state === "stale" && r.text === "Stale · not answering")).toBe(true);
  }
});
test("nothing is invented: SLA and prices say they are not connected, garbage input is refused", () => {
  const b = barModel("live", {}); expect(b.sla).toBe("No cases yet"); expect(b.prices).toContain("not connected"); expect(b.p1).toBeNull();
  expect(asSummary({ p1_open: "1" })).toBeNull(); expect(asSummary(null)).toBeNull(); expect(asServices([{ service: 1 }])).toBeNull(); expect(asServices("x")).toBeNull();
});
test("time words", () => { expect(ago(3)).toBe("3 s ago"); expect(ago(300)).toBe("5 min ago"); expect(ago(null)).toBeNull(); expect(duration(3725)).toBe("1 h 2 min"); });
