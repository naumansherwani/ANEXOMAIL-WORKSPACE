/**
 * What a person is told about a batch of team invitations. Pure (no network, no React) so it is unit-tested:
 * docs/cursor-work/frontend/tests/team-report.test.ts. Truth rule: the numbers come from the engine's own report
 * (`invited` / `resent` / `failed`), never from "the request returned 200".
 */

export type TeamRole = "owner" | "admin" | "member" | "viewer";

export type InviteResult = {
  ok?: boolean;
  role?: TeamRole;
  invited?: string[];
  resent?: string[];
  failed?: { email: string; error: string }[];
  already_member?: string[];
  invalid?: number;
  duplicate?: number;
  over_cap?: number;
};

/** One honest sentence about an invitation batch, from the engine's own report. */
export function summariseInvites(res: InviteResult | undefined, asked: number): {
  tone: "done" | "partial" | "failed" | "info";
  title: string;
  detail: string;
} {
  if (!res) return { tone: "info", title: "Sent", detail: "" };
  // old route: { invited: [...] } only
  const sent = (res.invited?.length ?? 0) + (res.resent?.length ?? 0);
  const failed = res.failed ?? [];
  const bits: string[] = [];
  if (res.already_member?.length) bits.push(`Already in the organisation: ${res.already_member.join(", ")}.`);
  if (res.invalid) bits.push(`${res.invalid} not valid ${res.invalid === 1 ? "address" : "addresses"} skipped.`);
  if (res.duplicate) bits.push(`${res.duplicate} repeated.`);
  if (res.over_cap) bits.push(`${res.over_cap} more than 50 at once — send them again separately.`);
  if (res.resent?.length) bits.push(`Sent again: ${res.resent.join(", ")}.`);
  if (failed.length) {
    const first = failed[0];
    bits.push(
      `Not delivered: ${failed.map((f) => f.email).join(", ")} (${(first?.error ?? "mail server refused").slice(0, 80)}). The invitation is saved — use Resend.`,
    );
  }
  const extra = bits.join(" ");
  if (sent > 0 && failed.length === 0) {
    return {
      tone: "done",
      title: `${sent} invitation${sent === 1 ? "" : "s"} e-mailed`,
      detail: extra || "They join when they open the link and press Join.",
    };
  }
  if (sent > 0) return { tone: "partial", title: `${sent} sent, ${failed.length} not sent`, detail: extra };
  if (failed.length) return { tone: "failed", title: "Invitations not delivered", detail: extra };
  return { tone: "info", title: asked ? "Nothing to send" : "Nothing sent", detail: extra || "Check the addresses." };
}

