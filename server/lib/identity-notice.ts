/**
 * E71 — tell a person their sign-up was approved (they would otherwise sit on "waiting for a quick review" forever).
 * Outbox pattern: SQL hands out "approved, not yet told" accounts (identity_notice_pending) and records the outcome
 * (identity_notice_done). A failed send is retried (max 6, 5 minutes apart) and a success is never repeated.
 * Only APPROVALS are announced. A rejection sends nothing: no reason, no hint, no confirmation of anything (the person simply
 * stays unable to sign in).
 */
export type NoticeRow = { account_id: string; to_email: string; display_name: string | null };
export type NoticeDeps = {
  pending: (limit: number) => Promise<NoticeRow[]>;
  send: (m: { to: string; subject: string; text: string }) => Promise<boolean>;
  done: (account: string, ok: boolean) => Promise<void>;
};

const SIGN_IN_URL = "https://anexomail.com/auth";

export function approvalMail(name: string | null | undefined, probationDays = 7): { subject: string; text: string } {
  const first = String(name || "").replace(/[\r\n<>]/g, " ").trim().split(/\s+/)[0]?.slice(0, 40) || "";
  return {
    subject: "Your ANEXOMAIL account is ready",
    text: [
      first ? `Hi ${first},` : "Hi,",
      "",
      "Thanks for waiting. We finished a quick review of your new ANEXOMAIL account and it is approved. You can sign in now:",
      SIGN_IN_URL,
      "",
      `For the first ${probationDays} days a few things are limited while the account is new: messages go to up to 20 people at a time, up to 50 messages a day, and invitations, public links and bulk imports unlock afterwards (or as soon as you subscribe to a plan).`,
      "",
      "If you did not create this account, you can ignore this email.",
      "",
      "— ANEXOMAIL",
    ].join("\n"),
  };
}

/** One pass of the outbox. Never throws; returns how many were sent / failed. */
export async function runNotices(deps: NoticeDeps, limit = 20): Promise<{ sent: number; failed: number }> {
  let rows: NoticeRow[] = [];
  try {
    rows = await deps.pending(limit);
  } catch {
    return { sent: 0, failed: 0 };
  }
  let sent = 0;
  let failed = 0;
  for (const r of rows) {
    let ok = false;
    try {
      const m = approvalMail(r.display_name);
      ok = await deps.send({ to: r.to_email, subject: m.subject, text: m.text });
    } catch {
      ok = false;
    }
    try {
      await deps.done(r.account_id, ok);
    } catch {
      /* SQL keeps attempts+5min spacing: worst case one retry later */
    }
    if (ok) sent++;
    else failed++;
  }
  return { sent, failed };
}
