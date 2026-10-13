import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * `/app/mail` ka apna landing folder: inbox. Mail ka asli surface
 * `/app/mail/$folder` hai, is liye yeh route seedha inbox par le jata hai.
 */
export const Route = createFileRoute("/app/mail/")({
  head: () => ({
    meta: [
      { title: "Mail — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Mail · Workspace in ANEXOMAIL Workspace — real data from your own workspace, with proof of where every number came from.",
      },
      { property: "og:title", content: "Mail — ANEXOMAIL Workspace" },
      { property: "og:description", content: "Mail · Workspace in ANEXOMAIL Workspace." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  beforeLoad: () => {
    throw redirect({ to: "/app/mail/$folder", params: { folder: "inbox" } });
  },
});
