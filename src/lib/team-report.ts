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
  /** valid new invitations not created because the plan has no free seat for them */
  over_seats?: number;
  /** "sara@acme.com" when a work address will be created at join; null/absent otherwise */
  work_address?: string | null;
};

/** `team.seats` — the database's own count (never a guess). `enforced:false` = no limit applies (unlimited plan or seats unknown). */
export type SeatState = {
  plan?: string | null;
  enforced?: boolean;
  unlimited?: boolean;
  known?: boolean;
  seats?: number | null;
  used?: number | null;
  pending?: number | null;
  free?: number | null;
  /** E34 not applied on the server yet */
  sql_missing?: boolean;
  domains?: { id: string; domain: string }[];
};

/** What happened to the work address at join time (`team.invite.accept`). */
export type WorkMail = { status: "created" | "pending" | "failed"; address?: string; error?: string };

const plural = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`;

/** One honest line about seats for the Members page. tone "none" = show nothing. */
export function describeSeats(s: SeatState | undefined): { line: string; tone: "none" | "ok" | "warn" | "full" } {
  if (!s || s.sql_missing) return { line: "", tone: "none" };
  const used = s.used ?? 0;
  const waiting = s.pending ?? 0;
  const wait = waiting > 0 ? ` · ${plural(waiting, "invitation", "invitations")} waiting` : "";
  if (s.unlimited) return { line: `Unlimited people on your plan · ${plural(used, "person", "people")} in${wait}`, tone: "ok" };
  if (!s.enforced || !s.seats) return { line: "", tone: "none" };
  const free = s.free ?? Math.max(s.seats - used - waiting, 0);
  const base = `${used} of ${plural(s.seats, "seat", "seats")} used${wait}`;
  if (free <= 0) return { line: `${base} — no free seat. Add seats in Billing to invite more people.`, tone: "full" };
  return { line: `${base} · ${plural(free, "seat", "seats")} free`, tone: free === 1 ? "warn" : "ok" };
}

/** The joiner's sentence about their work address. */
export function describeWorkMail(m: WorkMail | undefined): string {
  if (!m || m.status === "pending") return "Your organiser can add a work address for you from Domains.";
  if (m.status === "created") return m.address ? `Your work address ${m.address} is ready.` : "Your work address is ready.";
  switch (m.error) {
    case "address_taken":
      return "The work address planned for you is already taken — ask your organiser for another.";
    case "mailbox_limit":
      return "The organisation has used all its mailboxes — ask your organiser to free one or upgrade.";
    case "domain_not_verified":
    case "domain_not_found":
      return "The organisation's domain is not verified yet — your work address comes once it is.";
    default:
      return "Your work address could not be created yet — ask your organiser.";
  }
}

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
  if (res.over_seats)
    bits.push(
      `${plural(res.over_seats, "more person", "more people")} would go over your seats — not invited. Add seats in Billing, then invite them.`,
    );
  if (res.work_address) bits.push(`Work address ${res.work_address} is created when they join.`);
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

