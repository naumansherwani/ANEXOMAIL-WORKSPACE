import { createFileRoute } from "@tanstack/react-router";

import { MyStanding, ReportForm, SafetyReviewQueue } from "@/components/app/safety/SafetyPanels";
import { useSafetyStanding } from "@/lib/chat-safety";

export const Route = createFileRoute("/app/safety")({
  head: () => ({
    meta: [
      { title: "Safety — report and review — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Report a message, person, file or conversation. Reviewers see metadata first; opening sealed content is always logged.",
      },
      { property: "og:title", content: "Safety — report and review — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "Reports move new → under review → action → resolved, with no skipped steps.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: SafetyPage,
});

function SafetyPage() {
  const standing = useSafetyStanding();

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl space-y-ax-5 px-6 py-8 md:px-8">
        <h2 className="ax-heading text-foreground">Safety</h2>
        <p className="ax-caption text-muted-foreground">
          Reporting is metadata-first. A reviewer can see who reported what and why; the words
          themselves stay sealed until someone records a reason to open them.
        </p>

        <ReportForm />
        <MyStanding />

        {standing.data?.can_review && (
          <section className="space-y-ax-3">
            <h3 className="ax-label text-foreground">Review queue</h3>
            <SafetyReviewQueue />
          </section>
        )}
      </div>
    </div>
  );
}
