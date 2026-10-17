/**
 * Organisation authorisation — pure functions (no imports, no I/O) so they can be unit-tested without a database.
 * server/routes/org.ts calls these; server/lib/org-authz.test.ts proves them.
 *
 * Why this exists: before this file every /api/org/* write (revoke a member, toggle a policy, kill a session, grant
 * break-glass) and every /api/founder/org/* route only checked "is there a signed-in user". Any customer could call them.
 */

export type OrgRole = "owner" | "admin" | "manager" | "member" | "viewer";

/** Same capability table the Roles page shows (CAPS in routes/org.ts) — one source of truth for who may do what. */
export const CAP_ROLES = {
  "org.members.revoke": ["owner", "admin"],
  "org.policies.write": ["owner", "admin"],
  "org.sessions.kill": ["owner", "admin"],
  "org.break_glass": ["owner", "admin"],
  "org.audit.read": ["owner", "admin"],
  "org.export": ["owner"],
  "org.mailboxes.create": ["owner", "admin", "manager"],
} as const satisfies Record<string, readonly OrgRole[]>;

export type Cap = keyof typeof CAP_ROLES;

export const normaliseRole = (r: unknown): OrgRole | null => {
  const v = String(r ?? "").trim().toLowerCase();
  return v === "owner" || v === "admin" || v === "manager" || v === "member" || v === "viewer" ? v : null;
};

/** A founder is treated as the owner of whatever workspace they are looking at; everyone else needs the role. */
export const roleAllows = (role: OrgRole | null, cap: Cap, founder = false): boolean =>
  founder || (role !== null && (CAP_ROLES[cap] as readonly OrgRole[]).includes(role));

/** Who may revoke whom: nobody revokes themselves or the owner; only an owner revokes an admin. */
export function revokeVerdict(
  actorRole: OrgRole | null,
  actorId: string,
  targetRole: OrgRole | null,
  targetId: string,
  founder = false,
): "ok" | "forbidden" | "self" | "owner_protected" | "admin_needs_owner" | "not_a_member" {
  if (targetRole === null) return "not_a_member";
  if (actorId === targetId) return "self";
  if (!roleAllows(actorRole, "org.members.revoke", founder)) return "forbidden";
  if (targetRole === "owner") return "owner_protected";
  if (targetRole === "admin" && actorRole !== "owner" && !founder) return "admin_needs_owner";
  return "ok";
}

/** FOUNDER_EMAILS env (comma list) with the same defaults routes/founder.ts uses. */
export const parseFounderEmails = (env: string | undefined, fallback: string): string[] =>
  (env || fallback)
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);

export const isFounderEmail = (email: unknown, list: readonly string[]): boolean => {
  const e = String(email ?? "").trim().toLowerCase();
  return e !== "" && list.includes(e);
};

/** org_members rows differ by schema generation: org_id | organisation_id | organization_id. status 'revoked' is not a member. */
export function orgIdFromMemberRow(row: Record<string, unknown> | null | undefined): string | null {
  if (!row) return null;
  const status = String(row["status"] ?? "active").toLowerCase();
  if (status === "revoked" || status === "removed" || status === "suspended") return null;
  const id = row["org_id"] ?? row["organisation_id"] ?? row["organization_id"];
  return typeof id === "string" && id ? id : null;
}
