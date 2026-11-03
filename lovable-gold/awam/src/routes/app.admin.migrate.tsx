import { createFileRoute } from "@tanstack/react-router";

import { ImportMailPage } from "@/components/app/migrate/ImportMailPage";

export const Route = createFileRoute("/app/admin/migrate")({
  head: () => ({
    meta: [
      { title: "Import mail — ANEXOMAIL Admin" },
      {
        name: "description",
        content: "Copy the mail from your old provider into ANEXOMAIL. Read-only on the old side, with a sealed receipt.",
      },
      { property: "og:title", content: "Import mail — ANEXOMAIL Admin" },
      { property: "og:description", content: "Bring your old mailbox over. Nothing at the old provider is changed." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: ImportMailPage,
});
