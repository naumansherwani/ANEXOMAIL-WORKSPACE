import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";

// Rule 57: har Bun endpoint ka package map mein likha hona zaroori (website mix na ho).
const csv = readFileSync(new URL("../../docs/claude/ENDPOINT-PACKAGE-MAP.csv", import.meta.url), "utf8").trim().split("\n").slice(1);
const OK = new Set(["basic", "pro", "business", "business_pro", "founder", "ai_soon", "internal"]);

describe("endpoint -> package map (Rule 57)", () => {
  test("every endpoint has a known package", () => {
    expect(csv.length).toBeGreaterThan(500);
    const bad = csv.filter((l) => !OK.has(l.split(",")[3] ?? ""));
    expect(bad).toEqual([]);
  });
  test("Pro CRM base is pro; CRM collab is business; chat is business", () => {
    const find = (p: string) => csv.find((l) => l.includes(p))?.split(",")[3];
    expect(find("/api/crm/overview")).toBe("pro");
    expect(find("/api/crm/approvals")).toBe("business");
    expect(find("/api/conversations")).toBe("business");
    expect(find("/api/mail/threads")).toBe("basic");
  });
});
