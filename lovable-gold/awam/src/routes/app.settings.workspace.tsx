import { createFileRoute } from "@tanstack/react-router";

import { SettingsScope } from "@/components/app/settings/SettingsBits";

export const Route = createFileRoute("/app/settings/workspace")({
  head: () => ({
    meta: [
      { title: "Settings · Workspace — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Settings · Workspace in ANEXOMAIL Workspace — real data from your own workspace, with proof of where every number came from.",
      },
      { property: "og:title", content: "Settings · Workspace — ANEXOMAIL Workspace" },
      { property: "og:description", content: "Settings · Workspace in ANEXOMAIL Workspace." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: () => (
    <SettingsScope
      scope="workspace"
      title="Workspace"
      blurb="Company-wide behaviour. Every change shows its blast radius before you save."
    />
  ),
});
