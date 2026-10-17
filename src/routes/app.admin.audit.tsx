import { createFileRoute } from "@tanstack/react-router";

import { LedgerPanel } from "@/components/app/org/LedgerPanel";

export const Route = createFileRoute("/app/admin/audit")({
  head: () => ({
    meta: [{ title: "Audit — ANEXOMAIL Admin" }, { name: "robots", content: "noindex" }],
  }),
  component: AuditPage,
});

/** What is recorded today: exactly the actions routes/org.ts writes to the ledger — nothing implied beyond that. */
function AuditPage() {
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <LedgerPanel
        title="Audit log"
        hint="Tamper-evident: every entry carries the hash of the one before it. Recorded: member revokes, policy changes, session kills, break-glass grants, new mailboxes, exports and the kill switch. Sign-ins aren't recorded yet."
        empty="Nothing recorded yet. The first member revoke, policy change, new mailbox or export writes the first entry."
      />
    </div>
  );
}
