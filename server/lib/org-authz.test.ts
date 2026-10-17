import { describe, expect, test } from "bun:test";

import {
  CAP_ROLES,
  isFounderEmail,
  normaliseRole,
  orgIdFromMemberRow,
  parseFounderEmails,
  revokeVerdict,
  roleAllows,
} from "./org-authz";

describe("roleAllows", () => {
  test("viewer, member and manager can never revoke / toggle / kill / break-glass", () => {
    for (const cap of ["org.members.revoke", "org.policies.write", "org.sessions.kill", "org.break_glass"] as const)
      for (const r of ["viewer", "member", "manager"] as const) expect(roleAllows(r, cap)).toBe(false);
  });
  test("owner and admin can; export is owner only", () => {
    expect(roleAllows("owner", "org.members.revoke")).toBe(true);
    expect(roleAllows("admin", "org.policies.write")).toBe(true);
    expect(roleAllows("admin", "org.export")).toBe(false);
    expect(roleAllows("owner", "org.export")).toBe(true);
  });
  test("no role (not a member) is denied, founder is allowed", () => {
    expect(roleAllows(null, "org.audit.read")).toBe(false);
    expect(roleAllows(null, "org.audit.read", true)).toBe(true);
  });
  test("every capability lists only real roles", () => {
    for (const roles of Object.values(CAP_ROLES)) for (const r of roles) expect(normaliseRole(r)).toBe(r);
  });
});

describe("normaliseRole", () => {
  test("accepts known roles in any case, rejects junk", () => {
    expect(normaliseRole(" Owner ")).toBe("owner");
    expect(normaliseRole("superuser")).toBeNull();
    expect(normaliseRole(undefined)).toBeNull();
    expect(normaliseRole("")).toBeNull();
  });
});

describe("revokeVerdict", () => {
  test("owner revokes member and admin", () => {
    expect(revokeVerdict("owner", "o", "member", "m")).toBe("ok");
    expect(revokeVerdict("owner", "o", "admin", "a")).toBe("ok");
  });
  test("admin revokes member but not another admin or the owner", () => {
    expect(revokeVerdict("admin", "a1", "member", "m")).toBe("ok");
    expect(revokeVerdict("admin", "a1", "admin", "a2")).toBe("admin_needs_owner");
    expect(revokeVerdict("admin", "a1", "owner", "o")).toBe("owner_protected");
  });
  test("a plain member is forbidden; nobody revokes themselves; strangers are not found", () => {
    expect(revokeVerdict("member", "m1", "member", "m2")).toBe("forbidden");
    expect(revokeVerdict("viewer", "v", "member", "m2")).toBe("forbidden");
    expect(revokeVerdict("owner", "o", "owner", "o")).toBe("self");
    expect(revokeVerdict("owner", "o", null, "ghost")).toBe("not_a_member");
  });
  test("the owner cannot be revoked even by the founder acting inside the org", () => {
    expect(revokeVerdict("owner", "f", "owner", "o", true)).toBe("owner_protected");
  });
});

describe("founder identity", () => {
  const list = parseFounderEmails(undefined, "A@x.com, b@y.com ,,");
  test("parses, trims, lower-cases, drops blanks", () => expect(list).toEqual(["a@x.com", "b@y.com"]));
  test("env overrides the default", () => expect(parseFounderEmails("z@z.com", "a@x.com")).toEqual(["z@z.com"]));
  test("matches case-insensitively; customers never match", () => {
    expect(isFounderEmail("B@Y.com", list)).toBe(true);
    expect(isFounderEmail("customer@acme.co.uk", list)).toBe(false);
    expect(isFounderEmail(undefined, list)).toBe(false);
    expect(isFounderEmail("", [""])).toBe(false);
  });
});

describe("orgIdFromMemberRow", () => {
  test("reads whichever id column the schema generation has", () => {
    expect(orgIdFromMemberRow({ org_id: "o1" })).toBe("o1");
    expect(orgIdFromMemberRow({ organisation_id: "o2" })).toBe("o2");
    expect(orgIdFromMemberRow({ organization_id: "o3", status: "active" })).toBe("o3");
  });
  test("a revoked member has no organisation any more", () => {
    expect(orgIdFromMemberRow({ org_id: "o1", status: "revoked" })).toBeNull();
    expect(orgIdFromMemberRow({ org_id: "o1", status: "REMOVED" })).toBeNull();
  });
  test("missing / malformed rows give null, never a guess", () => {
    expect(orgIdFromMemberRow(undefined)).toBeNull();
    expect(orgIdFromMemberRow({})).toBeNull();
    expect(orgIdFromMemberRow({ org_id: 12 })).toBeNull();
  });
});
