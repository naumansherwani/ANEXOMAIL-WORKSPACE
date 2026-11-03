import { describe, expect, test } from "bun:test";

import { bearerOf, founderVerdict, makeFounderGate, type FounderGateDeps } from "./founder-gate-core";

const users: Record<string, { id: string; email: string }> = {
  "t-founder": { id: "u-f", email: "Naumansherwani.Founder@anexomail.com" },
  "t-account": { id: "u-acc", email: "second.founder@anexomail.com" },
  "t-customer": { id: "u-c", email: "buyer@acme.co.uk" },
  "t-noemail": { id: "u-n", email: "" },
};
const deps = (over: Partial<FounderGateDeps> = {}): FounderGateDeps => ({
  emails: ["naumansherwani.founder@anexomail.com"],
  getUser: async (t) => users[t] ?? null,
  isFounderAccount: async (id) => id === "u-acc",
  ...over,
});

describe("founderVerdict", () => {
  test("no token or unknown token → unauthorized", async () => {
    expect(await founderVerdict("", deps())).toBe("unauthorized");
    expect(await founderVerdict("nope", deps())).toBe("unauthorized");
  });
  test("founder email (any case) and founder_accounts row pass", async () => {
    expect(await founderVerdict("t-founder", deps())).toBe("ok");
    expect(await founderVerdict("t-account", deps())).toBe("ok");
  });
  test("every customer is founder_only, including one with no email", async () => {
    expect(await founderVerdict("t-customer", deps())).toBe("founder_only");
    expect(await founderVerdict("t-noemail", deps({ emails: [""] }))).toBe("founder_only");
  });
  test("a failing lookup never promotes a customer", async () => {
    const d = deps({ isFounderAccount: async () => { throw new Error("db down"); } });
    expect(await founderVerdict("t-customer", d)).toBe("founder_only");
    expect(await founderVerdict("t-founder", d)).toBe("ok");
  });
  test("a failing auth lookup is unauthorized, not an exception", async () => {
    const d = deps({ getUser: async () => { throw new Error("auth down"); } });
    expect(await founderVerdict("t-founder", d)).toBe("unauthorized");
  });
});

describe("middleware", () => {
  const run = async (token: string | null) => {
    let status = 0, body: any, nexted = false;
    const res: any = { status: (s: number) => ((status = s), res), json: (b: any) => ((body = b), res) };
    const req: any = { headers: token ? { authorization: `Bearer ${token}` } : {} };
    await makeFounderGate(deps())(req, res, () => { nexted = true; });
    return { status, body, nexted };
  };
  test("founder reaches the router (next called, nothing sent)", async () => {
    expect(await run("t-founder")).toEqual({ status: 0, body: undefined, nexted: true });
  });
  test("a CORS preflight (OPTIONS, no token) is let through — it carries no data", async () => {
    let nexted = false;
    const res: any = { status: () => res, json: () => res };
    await makeFounderGate(deps())({ method: "OPTIONS", headers: {} }, res, () => { nexted = true; });
    expect(nexted).toBe(true);
  });
  test("signed out → 401, customer → 403, router never reached", async () => {
    expect(await run(null)).toEqual({ status: 401, body: { error: "unauthorized" }, nexted: false });
    expect(await run("t-customer")).toEqual({ status: 403, body: { error: "founder_only" }, nexted: false });
  });
});

describe("bearerOf", () => {
  test("extracts the token, ignores other schemes", () => {
    expect(bearerOf({ headers: { authorization: "Bearer abc " } })).toBe("abc");
    expect(bearerOf({ headers: { authorization: "Basic abc" } })).toBe("");
    expect(bearerOf({})).toBe("");
  });
});
