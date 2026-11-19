import { describe, expect, test } from "bun:test";
import { asEmoji, cleanCode, codeFromFile, codeOf, fileProblem, isCompany, matchPack, quotaLabel, quotaTone, tokenOf, tokens, NO_QUOTA, type CompanyItem } from "./company_emoji_pure";
import { withTone } from "./emoji_pure";

const it = (shortcode: string, alt = ""): CompanyItem => ({ shortcode, alt, sha256: "a".repeat(64), bytes: 1000, w: 64, h: 64 });
const pack = [it("acme", "Acme Corp logo"), it("acme-logo"), it("team-badge", "Blue badge"), it("zeta"), it("launch-2026", "Launch day")];

describe("company_emoji_pure", () => {
  test("cleanCode mirrors SQL + Rust", () => {
    expect(cleanCode(" :Acme: ")).toEqual({ ok: true, code: "acme" });
    for (const bad of ["a", "-ab", "ab-", "a b", "a".repeat(25), "چائے"]) expect(cleanCode(bad).ok).toBe(false);
    expect(cleanCode("a".repeat(24)).ok).toBe(true);
    expect(cleanCode("Official").ok).toBe(false);
    expect(cleanCode(":admin:").ok).toBe(false);
  });
  test("tokens: same rule as Rust", () => {
    expect(tokens("hi :acme: and :acme: :team-2: 12:30:45 :Bad: :x:")).toEqual(["acme", "team-2"]);
    expect(tokens(":ab::cd:")).toEqual(["ab", "cd"]);
    expect(tokens("12:30:45 and a:b:c")).toEqual([]);
    expect(tokens("(:acme:)")).toEqual(["acme"]);
  });
  test("pseudo emoji works with the picker helpers", () => {
    const e = asEmoji(it("acme", "Acme Corp logo"));
    expect(isCompany(e)).toBe(true);
    expect(codeOf(e)).toBe("acme");
    expect(withTone(e, "dark").unicode).toBe(":acme: ");
    expect(e.label).toBe("acme (Acme Corp logo)");
    expect(tokenOf("acme")).toBe(":acme: ");
  });
  test("matchPack ranks exact > prefix > word > alt > contains", () => {
    expect(matchPack(pack, "acme").map((c) => c.shortcode)).toEqual(["acme", "acme-logo"]);
    expect(matchPack(pack, "logo").map((c) => c.shortcode)).toEqual(["acme-logo", "acme"]); // word of the code first, alt word second
    expect(matchPack(pack, "blue").map((c) => c.shortcode)).toEqual(["team-badge"]);
    expect(matchPack(pack, "day").map((c) => c.shortcode)).toEqual(["launch-2026"]);
    expect(matchPack(pack, ":zet").map((c) => c.shortcode)).toEqual(["zeta"]);
    expect(matchPack(pack, "nothing")).toEqual([]);
    expect(matchPack(pack, "").map((c) => c.shortcode)).toEqual(["acme", "acme-logo", "launch-2026", "team-badge", "zeta"]);
  });
  test("quota text + tone", () => {
    expect(quotaLabel(NO_QUOTA)).toBe("Not in your plan");
    expect(quotaTone(NO_QUOTA)).toBe("off");
    expect(quotaLabel({ plan: "business", limit: 10, used: 7, left: 3, enabled: true })).toBe("7 of 10 used");
    expect(quotaTone({ plan: "business", limit: 10, used: 9, left: 1, enabled: true })).toBe("near");
    expect(quotaTone({ plan: "business", limit: 10, used: 10, left: 0, enabled: true })).toBe("full");
    expect(quotaTone({ plan: "business", limit: 10, used: 2, left: 8, enabled: true })).toBe("ok");
  });
  test("fileProblem", () => {
    expect(fileProblem({ name: "a.png", size: 5000, type: "image/png" })).toBeNull();
    expect(fileProblem({ name: "a.svg", size: 5000, type: "image/svg+xml" })).toContain("PNG or WebP");
    expect(fileProblem({ name: "a.png", size: 600 * 1024, type: "image/png" })).toContain("too big");
    expect(fileProblem({ name: "a.webp", size: 10, type: "image/webp" })).toContain("empty");
  });
  test("codeFromFile", () => {
    expect(codeFromFile("Acme Logo (1).png")).toBe("acme-logo-1");
    expect(codeFromFile("a.png")).toBe("");
    expect(codeFromFile("OFFICIAL.png")).toBe("");
    expect(codeFromFile("x".repeat(40) + ".png").length).toBeLessThanOrEqual(24);
  });
});
