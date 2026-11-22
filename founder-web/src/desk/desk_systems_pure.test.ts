import { expect, test } from "bun:test";
import { canSeeTech, systemsModel } from "./desk_systems_pure";
const svc = (service: string, state: string) => ({ service, label: service, critical: true, state, last_latency_ms: 9, age_s: 2, uptime_24h: 99 });
const all = (st: string) => ["mail_in", "mail_out", "h3_edge", "tls", "db", "signer", "clamav", "ledger"].map((s) => svc(s, st));
test("roles: only owner, admin, engineer see technical rows", () => { expect(canSeeTech("Owner")).toBe(true); expect(canSeeTech("admin")).toBe(true); expect(canSeeTech("agent")).toBe(false); expect(canSeeTech("")).toBe(false); });
test("all operational = Working, no banner, frontline sees no technical rows", () => {
  const m = systemsModel("live", { services: all("operational") }, "agent");
  expect(m.overall).toBe("ok"); expect(m.banner).toBeNull(); expect(m.areas.every((a) => a.words === "Working" && a.tech.length === 0)).toBe(true);
});
test("an outage gives words, the customer wording and a banner", () => {
  const rows = all("operational").map((s) => (s.service === "clamav" ? { ...s, state: "outage" } : s));
  const m = systemsModel("live", { services: rows }, "agent");
  expect(m.overall).toBe("outage"); expect(m.areas.find((a) => a.id === "virus")!.tell).toContain("Attachments"); expect(m.banner).toContain("Virus scanning");
});
test("not measured is never called Working", () => {
  const m = systemsModel("live", { services: [svc("db", "operational"), svc("signer", "operational")] }, "owner");
  expect(m.areas.find((a) => a.id === "records")!.level).toBe("ok"); expect(m.areas.find((a) => a.id === "mail")!.level).toBe("unknown"); expect(m.overall).toBe("unknown");
});
test("owner sees technical rows, stale and connecting are honest", () => {
  expect(systemsModel("live", { services: all("operational") }, "owner").areas[0].tech.length).toBe(2);
  const s = systemsModel("stale", { services: all("operational") }, "owner"); expect(s.overall).toBe("stale"); expect(s.areas.every((a) => a.tech.length === 0 && a.words === "Not answering")).toBe(true);
  expect(systemsModel("connecting", {}, "agent").headline).toBe("Connecting…");
});
