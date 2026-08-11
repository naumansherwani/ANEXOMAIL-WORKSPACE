/**
 * ANEXOMAIL Workspace — Information Architecture (Phase 2, locked).
 *
 * Single source of truth for navigation, folders, roles and hierarchy.
 * Nothing here is display copy for the public site; this is the app surface.
 *
 * Hierarchy: Organization -> Domain -> Address (personal | shared)
 *            -> Mailbox -> Thread -> Message
 */

export type WorkspaceRole = "owner" | "admin" | "member";

export const ROLES: {
  id: WorkspaceRole;
  label: string;
  summary: string;
}[] = [
  {
    id: "owner",
    label: "Owner",
    summary: "Owns the organisation, billing and the domain. Cannot be removed.",
  },
  {
    id: "admin",
    label: "Admin",
    summary: "Manages domains, addresses, members, audit and exports.",
  },
  {
    id: "member",
    label: "Member",
    summary: "Uses their own mailbox and any shared address they are added to.",
  },
];

/**
 * Per-address capability, not a global role — keeps the role list short
 * while still giving shared addresses (sales@, support@) an owner.
 */
export const ADDRESS_MANAGER_FLAG = {
  id: "manager",
  label: "Address manager",
  summary:
    "Set on a single shared address. Can add or remove people on that address and change its routing.",
} as const;

export type MailFolder =
  | "inbox"
  | "assigned"
  | "waiting"
  | "sent"
  | "drafts"
  | "archive"
  | "spam"
  | "trash";

export const MAIL_FOLDERS: { id: MailFolder; label: string }[] = [
  { id: "inbox", label: "Inbox" },
  { id: "assigned", label: "Assigned to me" },
  { id: "waiting", label: "Waiting" },
  { id: "sent", label: "Sent" },
  { id: "drafts", label: "Drafts" },
  { id: "archive", label: "Archive" },
  { id: "spam", label: "Spam" },
  { id: "trash", label: "Trash" },
];

export function isMailFolder(value: string): value is MailFolder {
  return MAIL_FOLDERS.some((f) => f.id === value);
}

/** Thread is the unit of work — this is the status ladder for it. */
export const THREAD_STATUSES = ["open", "waiting", "done"] as const;
export type ThreadStatus = (typeof THREAD_STATUSES)[number];

export const ADMIN_SECTIONS: {
  to: string;
  label: string;
  summary: string;
}[] = [
  { to: "/app/admin", label: "Domains", summary: "DNS, DKIM, SPF, DMARC, TLS" },
  { to: "/app/admin/members", label: "Members", summary: "People and roles" },
  { to: "/app/admin/teams", label: "Teams", summary: "Groups that own shared work" },
  {
    to: "/app/admin/addresses",
    label: "Addresses",
    summary: "Personal and shared addresses",
  },
  { to: "/app/admin/audit", label: "Audit", summary: "Every action, who and when" },
  { to: "/app/admin/export", label: "Export", summary: "Take your data out, any time" },
  // Phase 25 — Admin Center
  { to: "/app/admin/health", label: "Health", summary: "Checks that fix themselves" },
  { to: "/app/admin/monitoring", label: "Monitoring", summary: "Delivery watchtower, live" },
  { to: "/app/admin/storage", label: "Storage", summary: "Days until full, not just used" },
  { to: "/app/admin/logs", label: "Logs", summary: "Readable logs and incidents" },
  { to: "/app/admin/reports", label: "Reports", summary: "Board-ready, real numbers" },
  { to: "/app/admin/diagnostics", label: "Diagnostics", summary: "Whole-stack signed proof pack" },
];