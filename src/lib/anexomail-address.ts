/** Workspace identity domain — locked. User never types this. */
export const ANEXOMAIL_DOMAIN = "anexomail.com";

/** Keep only the mailbox name. Full paste `name@anything` becomes `name`. */
export function anexomailLocalPart(raw: string): string {
  const trimmed = raw.trim().toLowerCase();
  const before = trimmed.includes("@") ? trimmed.slice(0, trimmed.indexOf("@")) : trimmed;
  return before.replace(/[^a-z0-9._-]/g, "");
}

/** Always `local@anexomail.com`. Empty local → empty string. */
export function anexomailAddress(raw: string): string {
  const local = anexomailLocalPart(raw);
  return local ? `${local}@${ANEXOMAIL_DOMAIN}` : "";
}
