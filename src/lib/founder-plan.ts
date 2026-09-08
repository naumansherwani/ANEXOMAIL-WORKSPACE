/**
 * Founder + AI address plan (locked config, not data).
 *
 * This is the provisioning TARGET. Whether a mailbox actually exists is
 * server truth (`/api/founder/mailboxes`) — the deck shows plan vs reality
 * side by side so nothing is ever claimed as live before it is.
 */

import type { MailboxKind } from "@/lib/founder";

export type PlannedMailbox = {
  address: string;
  display_name: string;
  kind: MailboxKind;
  note: string;
  /** AI that owns replies for this address. */
  agent?: string;
};

export const FOUNDER_WORKSPACE_HOST = "founderworkspace.anexomail.com";

/**
 * FINAL list (locked 8 Sep 2026). Sirf yeh addresses banti hain — aur koi nahi.
 * postmaster@ / abuse@ / dmarc@ sirf forward hain (koi inbox nahi) -> resolved@.
 */
export const FOUNDER_MAILBOXES: PlannedMailbox[] = [
  {
    address: "naumansherwani.founder@anexomail.com",
    display_name: "Muhammad Nauman Sherwani",
    kind: "founder",
    note: "Founder ka ek hi inbox. Company addresses ki copy isi mein aati hai.",
  },
];

/** Family accounts — aam user ki tarah, AI Executive ke saray premium features. */
export const FAMILY_MAILBOXES: PlannedMailbox[] = [
  {
    address: "humzasherwani@anexomail.com",
    display_name: "Humza Sherwani",
    kind: "founder",
    note: "Family account. Private inbox — founder inbox mein copy kabhi nahi.",
  },
  {
    address: "raanasherwani@anexomail.com",
    display_name: "Raana Sherwani",
    kind: "founder",
    note: "Family account. Private inbox — founder inbox mein copy kabhi nahi.",
  },
];

export const SUPPORT_MAILBOXES: PlannedMailbox[] = [
  {
    address: "resolved@anexomail.com",
    display_name: "ANEXOMAIL Resolved",
    kind: "support",
    note: "Support ka asli inbox. postmaster, abuse aur DMARC reports bhi yahin.",
    agent: "Leo",
  },
  {
    address: "moveyourbusiness@anexomail.com",
    display_name: "ANEXOMAIL Move-Ins",
    kind: "support",
    note: "Move-in aur Priority Support inquiries.",
    agent: "Leo",
  },
  {
    address: "hello@anexomail.com",
    display_name: "ANEXOMAIL",
    kind: "support",
    note: "First contact aur sales sawal.",
    agent: "Leo",
  },
  {
    address: "billing@anexomail.com",
    display_name: "ANEXOMAIL Billing",
    kind: "support",
    note: "Invoices aur plan changes. Money topics approval ke baghair nahi jaate.",
    agent: "Leo",
  },
  {
    address: "noreply@anexomail.com",
    display_name: "ANEXOMAIL (no reply)",
    kind: "system",
    note: "Outbound system mail. Inbound silently discard.",
  },
];

export const AI_MAILBOXES: PlannedMailbox[] = [
  {
    address: "leo@anexomail.com",
    display_name: "Leo — ANEXOMAIL AI",
    kind: "agent",
    note: "Workspace AI reply pipeline.",
    agent: "Leo",
  },
];

export const PLANNED_MAILBOXES: PlannedMailbox[] = [
  ...FOUNDER_MAILBOXES,
  ...FAMILY_MAILBOXES,
  ...SUPPORT_MAILBOXES,
  ...AI_MAILBOXES,
];


export const KIND_LABEL: Record<MailboxKind, string> = {
  founder: "Founder",
  agent: "AI",
  industry: "Industry AI",
  support: "Support",
  system: "System",
};
