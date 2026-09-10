/**
 * 28 original locales = awam + family testers.
 * anexomail.com + ai.anexomail.com.
 * Founder host + founder account stay English.
 * Family testers (Humza / Raana / Masood) get the picker since 11 Sep 2026 —
 * founder reviews the awam view from Humza's account.
 */

import type { Session } from "@/lib/auth";
import { FOUNDER_MAILBOXES } from "@/lib/founder-plan";
import { isAiHost, isPublicMailHost } from "@/lib/host";

function addrOf(session: Session | null | undefined): string {
  return String(session?.user.anexomail_address || session?.user.email || "")
    .trim()
    .toLowerCase();
}

export function localeHostsAllowed(): boolean {
  return isPublicMailHost() || isAiHost();
}

export function isFounderSession(session: Session | null | undefined): boolean {
  if (!session) return false;
  if (session.user.is_founder) return true;
  const addr = addrOf(session);
  if (!addr) return false;
  return FOUNDER_MAILBOXES.some((m) => m.address.toLowerCase() === addr);
}

/** Picker + translations. Signed-out awam + family testers on the two hosts = yes. */
export function publicLocaleAllowed(session: Session | null | undefined): boolean {
  if (!localeHostsAllowed()) return false;
  return !isFounderSession(session);
}
