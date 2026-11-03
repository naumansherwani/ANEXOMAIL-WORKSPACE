/**
 * The wired founder gate: mount once in index.ts, BEFORE every router that serves /api/founder/*:
 *     app.use("/api/founder", founderGate);
 * Founder identity = an email in FOUNDER_EMAILS (same default list as routes/founder.ts) or a row in founder_accounts.
 */
import { admin } from "./supa";
import { makeFounderGate } from "./founder-gate-core";
import { parseFounderEmails } from "./org-authz";

const EMAILS = parseFounderEmails(
  process.env.FOUNDER_EMAILS,
  "naumansherwani.founder@anexomail.com,naumansherwani.founder@nexatect.com",
);

export const founderGate = makeFounderGate({
  emails: EMAILS,
  getUser: async (token) => {
    const { data } = await admin.auth.getUser(token);
    return data?.user ? { id: data.user.id, email: data.user.email } : null;
  },
  isFounderAccount: async (userId) => {
    const r = await admin.from("founder_accounts").select("user_id").eq("user_id", userId).limit(1);
    return Boolean(r.data?.length);
  },
});
