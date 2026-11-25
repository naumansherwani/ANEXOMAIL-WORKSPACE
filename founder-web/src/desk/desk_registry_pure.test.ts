import { expect, test } from "bun:test";
import { buildHistory, buildNumber, checkWords, countryCodeOk, lookupWords, numberOk, parseCheck, parseCountries, parseHistory, parseLookup, parseRegisters, registerLabel } from "./desk_registry_pure";

const T = "123e4567-e89b-12d3-a456-426614174000";
const reg = (o: Record<string, unknown> = {}) => ({ id: 7, ra_code: "RA000475", name: "Corporate Registry", authority: "Securities and Exchange Commission", website: "www.secp.gov.pk", shape_known: false, ...o });
const found = (o: Record<string, unknown> = {}) => ({ state: "found", tenant_id: T, since: "2026-11-25T07:00:00+00", shape_state: "shape_unproven", name_state: "ok", tenant_name: "Acme Ltd", ...o });

test("country code and number checks are strict", () => {
  expect(countryCodeOk("PK")).toBe(true); for (const b of ["pk", "PAK", "P", "P1", ""]) expect(countryCodeOk(b)).toBe(false);
  expect(numberOk("0086650")).toBe(true); expect(numberOk(" DE-HRB 12345 ")).toBe(true);
  for (const b of ["", "   ", "a\nb", "x".repeat(81), "\u0007"]) expect(numberOk(b)).toBe(false);
});
test("parseCountries accepts the exact shape and fails closed", () => {
  expect(parseCountries({ countries: [{ code: "PK", country: "Pakistan", registers: 2 }] })).toEqual([{ code: "PK", country: "Pakistan", registers: 2 }]);
  expect(parseCountries({ countries: [] })).toEqual([]);
  for (const bad of [null, "x", {}, { countries: "x" }, { countries: [{ code: "pk", country: "Pakistan", registers: 2 }] }, { countries: [{ code: "PK", country: "", registers: 2 }] },
    { countries: [{ code: "PK", country: "Pakistan", registers: 0 }] }, { countries: [{ code: "PK", country: "Pakistan", registers: 1.5 }] }, { countries: Array.from({ length: 401 }, () => ({ code: "PK", country: "P", registers: 1 })) }]) expect(parseCountries(bad)).toBeNull();
});
test("parseRegisters accepts the exact shape and fails closed", () => {
  expect(parseRegisters({ registers: [reg()] })).toEqual([{ id: 7, raCode: "RA000475", name: "Corporate Registry", authority: "Securities and Exchange Commission", website: "www.secp.gov.pk", shapeKnown: false }]);
  for (const bad of [null, {}, { registers: [reg({ id: 0 })] }, { registers: [reg({ ra_code: "XX1" })] }, { registers: [reg({ shape_known: "no" })] }, { registers: [reg({ name: "a\nb" })] }, { registers: [reg({ website: 5 })] },
    { registers: Array.from({ length: 101 }, () => reg()) }]) expect(parseRegisters(bad)).toBeNull();
});
test("buildNumber gives the exact body or null", () => {
  expect(buildNumber(7, " 0086650 ")).toEqual({ registry_id: 7, number: "0086650" });
  expect(buildNumber(null, "1")).toBeNull(); expect(buildNumber(0, "1")).toBeNull(); expect(buildNumber(1.5, "1")).toBeNull(); expect(buildNumber(7, "  ")).toBeNull();
  expect(buildHistory(T.toUpperCase())).toEqual({ tenant_id: T }); expect(buildHistory("nope")).toBeNull(); expect(buildHistory("00000000-0000-0000-0000-000000000000")).toBeNull();
});
test("check words are closed and honest about an unproven shape", () => {
  for (const w of ["ok", "wrong_shape", "shape_unknown", "bad_number", "no_register"]) expect(parseCheck({ check: w })).toBe(w);
  expect(parseCheck({ check: "refused" })).toBeNull(); expect(parseCheck({ check: 5 })).toBeNull(); expect(parseCheck(null)).toBeNull();
  expect(checkWords("shape_unknown")).toContain("No number shape has been proven"); expect(checkWords(null)).toContain("could not check");
});
test("parseLookup: states without a company, a found company with its name state, and fail closed", () => {
  for (const s of ["none", "no_right", "no_register", "bad_number"]) expect(parseLookup({ state: s })).toEqual({ state: s });
  expect(parseLookup(found())).toEqual({ state: "found", tenantId: T, since: "2026-11-25T07:00:00+00", shapeState: "shape_unproven", nameState: "ok", tenantName: "Acme Ltd" });
  expect(parseLookup(found({ name_state: "missing", tenant_name: null }))).toMatchObject({ nameState: "missing", tenantName: null });
  for (const bad of [null, "x", { state: "refused" }, found({ tenant_id: "nope" }), found({ tenant_id: "00000000-0000-0000-0000-000000000000" }), found({ shape_state: "x" }), found({ name_state: "x" }),
    found({ name_state: "ok", tenant_name: null }), found({ name_state: "missing", tenant_name: "Acme" }), found({ tenant_name: "a\nb" })]) expect(parseLookup(bad)).toBeNull();
});
test("lookup words never show a name that was not confirmed", () => {
  expect(lookupWords(parseLookup(found()))).toBe("This number belongs to Acme Ltd.");
  expect(lookupWords(parseLookup(found({ name_state: "missing", tenant_name: null })))).toContain("Do not use it");
  expect(lookupWords(parseLookup(found({ name_state: "unavailable", tenant_name: null })))).toContain("could not be confirmed");
  expect(lookupWords(parseLookup({ state: "none" }))).toContain("Nothing is guessed"); expect(lookupWords(null)).toContain("could not verify");
});
test("parseHistory accepts the exact shape and fails closed", () => {
  const h = (o: Record<string, unknown> = {}) => ({ id: 3, register: "Corporate Registry", country: "PK", ra_code: "RA000475", number: "0086650", shape_state: "shape_unproven", valid_from: "2026-11-25T07:00:00+00", valid_to: null, ended_why: null, ...o });
  expect(parseHistory({ items: [h()] })).toEqual([{ id: 3, register: "Corporate Registry", country: "PK", raCode: "RA000475", number: "0086650", shapeState: "shape_unproven", validFrom: "2026-11-25T07:00:00+00", validTo: null, endedWhy: null }]);
  for (const bad of [null, {}, { items: [h({ id: "3" })] }, { items: [h({ number: "x".repeat(65) })] }, { items: [h({ valid_from: 5 })] }, { items: [h({ valid_to: 5 })] }, { items: Array.from({ length: 101 }, () => h()) }]) expect(parseHistory(bad)).toBeNull();
});
test("register label says when a shape is not proven", () => {
  expect(registerLabel({ id: 7, raCode: "RA000475", name: "Corporate Registry", authority: "SECP", website: "", shapeKnown: false })).toBe("Corporate Registry (RA000475) - number shape not proven");
  expect(registerLabel({ id: 8, raCode: "RA000001", name: "", authority: "Central Registry", website: "", shapeKnown: true })).toBe("Central Registry (RA000001)");
});
