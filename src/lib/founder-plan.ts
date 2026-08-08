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

export const FOUNDER_MAILBOXES: PlannedMailbox[] = [
  {
    address: "naumansherwani.founder@anexomail.com",
    display_name: "Muhammad Nauman Sherwani",
    kind: "founder",
    note: "Primary founder mailbox on the product domain. Private, never AI-answered.",
  },
  {
    address: "naumansherwani.founder@nexatect.com",
    display_name: "Muhammad Nauman Sherwani — NEXATECT",
    kind: "founder",
    note: "Parent-company founder mailbox. Same inbox, separate identity when sending.",
  },
];

export const SUPPORT_MAILBOXES: PlannedMailbox[] = [
  {
    address: "support@anexomail.com",
    display_name: "ANEXOMAIL Support",
    kind: "support",
    note: "Leo answers like a human. Target resolution under 4 minutes, no tickets.",
    agent: "Leo",
  },
  {
    address: "hello@anexomail.com",
    display_name: "ANEXOMAIL",
    kind: "support",
    note: "First contact and sales questions.",
    agent: "Leo",
  },
  {
    address: "billing@anexomail.com",
    display_name: "ANEXOMAIL Billing",
    kind: "support",
    note: "Invoices and plan changes. Money topics are draft-only until approved.",
    agent: "Leo",
  },
  {
    address: "noreply@anexomail.com",
    display_name: "ANEXOMAIL (no reply)",
    kind: "system",
    note: "Outbound system mail. Inbound is silently discarded.",
  },
];

export const AI_MAILBOXES: PlannedMailbox[] = [
  {
    address: "leo@anexomail.com",
    display_name: "Leo — ANEXOMAIL AI",
    kind: "agent",
    note: "Workspace AI. Primary responder, escalates to Jimmy when out of depth.",
    agent: "Leo",
  },
  {
    address: "jimmyjohn@nexatect.com",
    display_name: "Jimmy John — Supreme Commander",
    kind: "agent",
    note: "CEO of the AI layer. Escalation target, never the first responder.",
    agent: "Jimmy John",
  },
  {
    address: "sherlock@nexatect.com",
    display_name: "Sherlock — Deputy",
    kind: "agent",
    note: "Validation layer. Checks a draft three times before it leaves.",
    agent: "Sherlock",
  },
  { address: "aria.tth@nexatect.com", display_name: "Aria — Travel & hospitality", kind: "industry", note: "Industry desk.", agent: "Aria" },
  { address: "orion.airlines@nexatect.com", display_name: "Captain Orion — Airlines", kind: "industry", note: "Industry desk.", agent: "Captain Orion" },
  { address: "rex@nexatect.com", display_name: "Rex — Car rental", kind: "industry", note: "Industry desk.", agent: "Rex" },
  { address: "lyra@nexatect.com", display_name: "Dr. Lyra — Healthcare", kind: "industry", note: "Industry desk.", agent: "Dr. Lyra" },
  { address: "sage.education@nexatect.com", display_name: "Professor Sage — Education", kind: "industry", note: "Industry desk.", agent: "Professor Sage" },
  { address: "atlas.logistics@nexatect.com", display_name: "Atlas — Logistics", kind: "industry", note: "Industry desk.", agent: "Atlas" },
  { address: "vega.ee@nexatect.com", display_name: "Vega — Events & entertainment", kind: "industry", note: "Industry desk.", agent: "Vega" },
  { address: "kai.railways@nexatect.com", display_name: "Conductor Kai — Railways", kind: "industry", note: "Industry desk.", agent: "Conductor Kai" },
];

export const PLANNED_MAILBOXES: PlannedMailbox[] = [
  ...FOUNDER_MAILBOXES,
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
