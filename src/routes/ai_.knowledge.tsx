import { createFileRoute } from "@tanstack/react-router";
import { BookOpen, Quote, Search } from "lucide-react";

import { ComingSoonGate } from "@/components/site/ComingSoonGate";

export const Route = createFileRoute("/ai_/knowledge")({
  head: () => ({
    meta: [
      { title: "AI Knowledge — Coming Soon | ANEXOMAIL AI" },
      {
        name: "description",
        content:
          "The ANEXOMAIL AI knowledge workspace — documents, memory and cited answers — is part of the separate AI product.",
      },
      { property: "og:title", content: "AI Knowledge — Coming Soon | ANEXOMAIL AI" },
      {
        property: "og:description",
        content: "Documents, memory and answers that always show their sources.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: () => (
    <ComingSoonGate
      title="The knowledge workspace is not open yet."
      body="Your own documents, your own memory, answers that always quote the source. It belongs to the separate AI product — your mailbox is never used to train anything."
      cards={[
        { icon: BookOpen, title: "Personal + business", body: "Two scopes, kept apart. Nothing leaks from your private notes into the company space." },
        { icon: Search, title: "Real recall", body: "Search across documents and real threads, ranked by the server — no guessing." },
        { icon: Quote, title: "Citations or nothing", body: "If the source is not there, the answer is refused instead of invented." },
      ]}
    />
  ),
});
