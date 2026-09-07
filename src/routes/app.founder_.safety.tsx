import { createFileRoute } from "@tanstack/react-router";

import { SafetyReviewQueue } from "@/components/app/safety/SafetyPanels";

export const Route = createFileRoute("/app/founder_/safety")({
  head: () => ({
    meta: [
      { title: "Founder view — safety review — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Founder review queue for reported messages, people, files and conversations, with logged evidence reveals and enforcement history.",
      },
      { property: "og:title", content: "Founder view — safety review" },
      {
        property: "og:description",
        content: "Every state change and every evidence reveal is recorded against a reviewer.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: FounderSafetyPage,
});

function FounderSafetyPage() {
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-4xl space-y-ax-4 px-6 py-8 md:px-8">
        <h2 className="ax-heading text-foreground">Founder view — safety review</h2>
        <p className="ax-caption text-muted-foreground">
          Same engine as the public surface. Reviewers act on metadata; opening reported content
          requires a written reason and leaves a permanent record.
        </p>
        <SafetyReviewQueue />
      </div>
    </div>
  );
}
