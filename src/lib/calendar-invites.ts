/**
 * What the person is told about their calendar invitations. One place, truth only:
 * the numbers come from the engine's own report; if the engine gave no report, we say nothing was e-mailed.
 */

import type { InviteSummary } from "@/lib/calendar";
import { notify } from "@/lib/notify";

/** Plain-language reason for a per-guest failure code the engine reports. */
export function inviteReason(code?: string) {
  if (!code) return "unknown reason";
  if (code === "daily_invite_limit") return "daily invitation limit reached";
  if (/5\d\d|4\d\d/.test(code)) return `mail server said ${code.slice(0, 80)}`;
  return code.slice(0, 80);
}

/** The one place that decides what the person is told about their invitations. Truth only. */
export function reportInvites({
  invite,
  guests,
  invites,
  ignored,
  threadId,
}: {
  invite: boolean;
  guests: number;
  invites: InviteSummary | undefined;
  ignored: string[];
  threadId?: string;
}) {
  const extra = ignored.length ? ` Ignored (not valid addresses): ${ignored.join(", ")}.` : "";
  if (guests === 0) {
    notify.done("Meeting created", threadId ? "Linked to this conversation." : "It's on your calendar.");
    return;
  }
  if (!invite) {
    notify.info("Saved — no invitations sent", `You chose not to e-mail the guests.${extra}`);
    return;
  }
  if (!invites) {
    notify.failed("Saved, but the guests were NOT e-mailed", {
      description:
        "The calendar engine update that sends invitations is not live yet. The meeting is on your calendar.",
    });
    return;
  }
  const notSent = invites.failed + invites.skipped;
  if (invites.sent === 0 && notSent === 0) {
    notify.info("Saved", `${invites.note || "No guests to invite."}${extra}`);
    return;
  }
  if (notSent === 0) {
    notify.done(
      `Invitation sent to ${invites.sent} ${invites.sent === 1 ? "person" : "people"}`,
      `They can answer from the e-mail.${extra}`,
    );
    return;
  }
  const first = invites.results.find((r) => r.status !== "sent");
  notify.failed(`${invites.sent} sent, ${notSent} not sent`, {
    description: first
      ? `${first.address}: ${inviteReason(first.error)}. Open the meeting to resend.${extra}`
      : `Open the meeting to resend.${extra}`,
  });
}
