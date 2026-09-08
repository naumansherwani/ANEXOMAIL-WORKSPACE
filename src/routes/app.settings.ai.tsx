import { createFileRoute } from "@tanstack/react-router";

import { SettingsScope } from "@/components/app/settings/SettingsBits";

export const Route = createFileRoute("/app/settings/ai")({
  head: () => ({
    meta: [
      { title: "Settings · Ai — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Settings · Ai · Workspace in ANEXOMAIL Workspace — real data from your own workspace, with proof of where every number came from.",
      },
      { property: "og:title", content: "Settings · Ai — ANEXOMAIL Workspace" },
      { property: "og:description", content: "Settings · Ai · Workspace in ANEXOMAIL Workspace." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: () => (
    <SettingsScope
      scope="ai"
      title="AI settings"
      blurb="Leo behaviour for this workspace. AI billing lives on ai.anexomail.com only."
    />
  ),
});
