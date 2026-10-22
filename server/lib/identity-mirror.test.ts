import { afterAll, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync, appendFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { canonEmail, decide, hmacHex, isNotInstalled, Mirror, Outbox, signalsRaw } from "./identity-mirror";

const dir = mkdtempSync(join(tmpdir(), "idv-"));
afterAll(() => rmSync(dir, { recursive: true, force: true }));
const H = (c: string) => c.repeat(64);

describe("parity with SQL (E68/E69) — same vectors as CHECK_E69", () => {
  test("hmac vectors", () => {
    expect(hmacHex("email", "a@b.com", "k")).toBe("63421a113608fece1cb4ee68e688cce63c4fa2fec389a00b32f99f3d493452b6");
    expect(hmacHex("device_key", "dk-1", "k")).toBe("ff7275b6820ec180d412d136d6db70aa3b438b4bc0c62dea759db9e1d2ed326f");
  });
  test("email canon", () => {
    expect(canonEmail("Ali.Khan+x@GoogleMail.com")).toBe("alikhan@gmail.com");
    expect(canonEmail("A+b@Outlook.com")).toBe("a@outlook.com");
    expect(canonEmail("nope")).toBeNull();
    expect(canonEmail("@x.com")).toBeNull();
    expect(canonEmail(null)).toBeNull();
  });
  test("signalsRaw: only given inputs, device key lowercased", () => {
    const s = signalsRaw({ email: "a@b.com", deviceKey: "DK-1", network: null }, "k");
    expect(s.map((x) => x.kind)).toEqual(["email", "device_key"]);
    expect(s[1]!.hmac).toBe("ff7275b6820ec180d412d136d6db70aa3b438b4bc0c62dea759db9e1d2ed326f");
  });
});

describe("mirror", () => {
  test("full then incremental; removal; expiry; weak kinds ignored", () => {
    const m = new Mirror();
    expect(m.ready).toBe(false);
    m.apply({ rows: [{ k: "email", h: H("a"), a: true, e: null }, { k: "device_key", h: H("b"), a: true, e: 100 }, { k: "network", h: H("c"), a: true, e: null }], cursor_t: "2026-10-22T10:00:00Z", cursor_id: 3, more: false, full: true });
    expect(m.ready).toBe(true);
    expect(m.size).toBe(2); // network never enters
    expect(m.deny([{ kind: "email", hmac: H("a") }], 50)).toEqual(["email"]);
    expect(m.deny([{ kind: "device_key", hmac: H("b") }], 50)).toEqual(["device_key"]);
    expect(m.deny([{ kind: "device_key", hmac: H("b") }], 100)).toEqual([]); // expired
    expect(m.deny([{ kind: "email", hmac: H("z") }], 50)).toEqual([]);
    m.apply({ rows: [{ k: "email", h: H("a"), a: false, e: null }], cursor_t: "2026-10-22T11:00:00Z", cursor_id: 4, more: false, full: false });
    expect(m.deny([{ kind: "email", hmac: H("a") }], 50)).toEqual([]);
    expect(m.cursorId).toBe(4);
    m.apply({ rows: [], cursor_t: null, cursor_id: 0, more: false, full: false });
    expect(m.cursorId).toBe(4); // empty page keeps the cursor
  });
  test("full resync replaces everything; junk rows ignored", () => {
    const m = new Mirror();
    m.apply({ rows: [{ k: "email", h: H("a"), a: true, e: null }], cursor_t: "t", cursor_id: 1, more: false, full: true });
    m.apply({ rows: [{ k: "email", h: "zz", a: true, e: null }, { k: "bogus", h: H("d"), a: true, e: null }], cursor_t: null, cursor_id: 0, more: false, full: true });
    expect(m.size).toBe(0);
  });
});

describe("outbox", () => {
  test("add/list/save, survives a torn last line, hashes only", () => {
    const o = new Outbox(join(dir, "sub", "ob.jsonl"));
    expect(o.size).toBe(0);
    o.add("11111111-1111-1111-1111-111111111111", [{ kind: "email", hmac: H("a") }]);
    o.add("22222222-2222-2222-2222-222222222222", [{ kind: "device_key", hmac: H("b") }]);
    appendFileSync(join(dir, "sub", "ob.jsonl"), '{"id":"torn","acc');
    expect(o.size).toBe(2);
    const items = o.list();
    o.save(items.slice(1));
    expect(o.size).toBe(1);
    expect(JSON.stringify(o.list())).not.toContain("@");
    o.save([]);
    expect(o.size).toBe(0);
    writeFileSync(join(dir, "empty.jsonl"), "");
    expect(new Outbox(join(dir, "empty.jsonl")).size).toBe(0);
  });
});

describe("policy", () => {
  const okDb = (decision: string) => ({ ok: true as const, value: { decision, matched: ["email"], appealable: true } });
  test("mirror deny wins without asking the database", () => {
    expect(decide({ mirrorReady: true, mirrorDeny: ["email"], db: { ok: false, notInstalled: false } })).toMatchObject({ kind: "deny", via: "mirror" });
  });
  test("database answer is authoritative otherwise", () => {
    expect(decide({ mirrorReady: true, mirrorDeny: [], db: okDb("deny") })).toMatchObject({ kind: "deny", via: "database" });
    expect(decide({ mirrorReady: true, mirrorDeny: [], db: okDb("review") })).toMatchObject({ kind: "allow", review: true });
    expect(decide({ mirrorReady: false, mirrorDeny: [], db: okDb("allow") })).toMatchObject({ kind: "allow", via: "database" });
  });
  test("database down: mirror ready => allow; no mirror => CLOSED; vault not installed => stay out of the way", () => {
    expect(decide({ mirrorReady: true, mirrorDeny: [], db: { ok: false, notInstalled: false } })).toMatchObject({ kind: "allow", via: "mirror" });
    expect(decide({ mirrorReady: false, mirrorDeny: [], db: { ok: false, notInstalled: false } })).toEqual({ kind: "closed" });
    expect(decide({ mirrorReady: false, mirrorDeny: [], db: { ok: false, notInstalled: true } })).toMatchObject({ kind: "allow", via: "not_installed" });
  });
  test("not-installed detection", () => {
    expect(isNotInstalled({ code: "PGRST202" })).toBe(true);
    expect(isNotInstalled({ code: "42883" })).toBe(true);
    expect(isNotInstalled({ message: "Could not find the function public.x in the schema cache" })).toBe(true);
    expect(isNotInstalled({ code: "57014", message: "timeout" })).toBe(false);
  });
});
