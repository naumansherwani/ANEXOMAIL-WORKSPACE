import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { BANNED } from "./banned";
import { countryList, numberProblem, toE164 } from "./countries";

const truth = JSON.parse(readFileSync(new URL("../../banned-countries/banned.json", import.meta.url), "utf8")).countries as { iso2: string; dial: string; name: string }[];

test("the founder copy equals banned-countries/banned.json", () => {
  expect(BANNED.map((b) => [b.iso2, b.dial, b.name])).toEqual(truth.map((b) => [b.iso2, b.dial, b.name]));
});
test("every other copy in the code matches the same file (no drift)", () => {
  const rs = readFileSync(new URL("../../server/rust/signx_core.rs", import.meta.url), "utf8");
  const awam = readFileSync(new URL("../../src/lib/countries.ts", import.meta.url), "utf8");
  const caddy = readFileSync(new URL("../../server/caddy/geoblock-gen.py", import.meta.url), "utf8");
  const sql = readFileSync(new URL("../../docs/cursor-work/sql/E146_founder_banned_countries.sql", import.meta.url), "utf8");
  for (const b of truth) {
    expect(rs).toContain(`"${b.iso2}"`); expect(rs).toContain(`"${b.dial}"`);
    expect(awam).toContain(`"${b.iso2}"`); expect(awam).toContain(`"${b.dial}"`);
    expect(caddy).toContain(`"${b.iso2}"`);
    expect(sql).toContain(`'${b.iso2}'`); expect(sql).toContain(`'${b.dial}'`);
  }
  expect(rs).toContain(`[&str; ${truth.length}]`);
});
test("the country list has everybody except the banned ones", () => {
  const l = countryList("en"), iso = new Set(l.map((c) => c.iso2));
  for (const b of truth) expect(iso.has(b.iso2)).toBe(false);
  for (const ok of ["PK", "GB", "US", "AE", "PS", "IR", "JO", "LB", "CU", "TR"]) expect(iso.has(ok)).toBe(true);
  expect(l.length).toBeGreaterThan(200);
});
test("numbers: banned prefixes refused, normal ones pass, shape is checked", () => {
  expect(numberProblem(toE164("92", "0300 1234567"))).toBeNull();
  expect(toE164("92", "0300 1234567")).toBe("+923001234567");
  expect(numberProblem(toE164("963", "944 123 456"))).toContain("not available");
  expect(numberProblem(toE164("93", "701234567"))).toContain("not available");
  expect(numberProblem(toE164("972", "501234567"))).toContain("not available");
  expect(numberProblem(toE164("850", "191234567"))).toContain("not available");
  expect(numberProblem(toE164("970", "599123456"))).toBeNull();
  expect(numberProblem(toE164("92", "12"))).toContain("country code");
});
