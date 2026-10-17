import { createFileRoute } from "@tanstack/react-router";

import { LedgerPanel } from "@/components/app/org/LedgerPanel";

export const Route = createFileRoute("/app/org/audit")({
  head: () => ({
    meta: [
      { title: "Audit ledger — ANEXOMAIL Organization Center" },
      {
        name: "description",
        content:
          "An append-only, hash-chained record of every action in your organisation — verify the chain yourself in one click.",
      },
      { property: "og:title", content: "Audit ledger — ANEXOMAIL Organization Center" },
      {
        property: "og:description",
        content: "Hash-chained, append-only audit you can verify yourself.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AuditPage,
});

function AuditPage() {
  return (
    <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10">
      <LedgerPanel
        title="Audit ledger"
        hint="Append-only and tamper-evident. Each entry carries the hash of the one before it, so an edited entry breaks the chain and shows up the moment you verify."
        empty="Nothing recorded yet. Member revokes, policy changes, session kills, break-glass grants, new mailboxes and exports appear here the moment they happen."
      />
    </div>
  );
}
