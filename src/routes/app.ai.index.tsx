import { createFileRoute, redirect } from "@tanstack/react-router";

/** `/app/ai` ka landing = AI email center (Leo, Jimmy, Sherlock, industry desks). */
export const Route = createFileRoute("/app/ai/")({
  head: () => ({
    meta: [
      { title: "AI — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Ai · Workspace in ANEXOMAIL Workspace — real data from your own workspace, with proof of where every number came from.",
      },
      { property: "og:title", content: "Ai — ANEXOMAIL Workspace" },
      { property: "og:description", content: "AI in ANEXOMAIL Workspace." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  beforeLoad: () => {
    throw redirect({ to: "/app/ai-center" });
  },
});
