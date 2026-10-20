import { createFileRoute } from "@tanstack/react-router";

import { ImportMailPage } from "@/components/app/migrate/ImportMailPage";

// Customer door to Import mail (every plan). Same screen as the founder's /app/admin/migrate.
export const Route = createFileRoute("/app/import")({
  head: () => ({
    meta: [
      { title: "Import mail — ANEXOMAIL" },
      {
        name: "description",
        content: "Copy the mail from Gmail, Outlook, Zoho or any IMAP mailbox into ANEXOMAIL. Read-only on the old side, with a sealed receipt.",
      },
      { property: "og:title", content: "Import mail — ANEXOMAIL" },
      { property: "og:description", content: "Bring your old mailbox over. Nothing at the old provider is changed." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: ImportMailPage,
});
