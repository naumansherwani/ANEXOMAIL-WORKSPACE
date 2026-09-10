/**
 * 28 original locales = awam only.
 * anexomail.com + ai.anexomail.com.
 * Founder host, founder account, family testers (Humza / Raana / Masood) = English, no picker.
 */

import type { Session } from "@/lib/auth";
import { FAMILY_MAILBOXES, FOUNDER_MAILBOXES } from "@/lib/founder-plan";
import { isAiHost, isPublicMailHost } from "@/lib/host";

function addrOf(session: Session | null | undefined): string {
  return String(session?.user.anexomail_address || session?.user.email || "")
    .trim()
    .toLowerCase();
}

export function localeHostsAllowed(): boolean {
  return isPublicMailHost() || isAiHost();
}

export function isFounderOrFamilySession(session: Session | null | undefined): boolean {
  if (!session) return false;
  if (session.user.is_founder) return true;
  const addr = addrOf(session);
  if (!addr) return false;
  return (
    FOUNDER_MAILBOXES.some((m) => m.address.toLowerCase() === addr) ||
    FAMILY_MAILBOXES.some((m) => m.address.toLowerCase() === addr)
  );
}

/** Picker + translations. Signed-out awam on the two hosts = yes. */
export function publicLocaleAllowed(session: Session | null | undefined): boolean {
  if (!localeHostsAllowed()) return false;
  return !isFounderOrFamilySession(session);
}
