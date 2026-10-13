import { createFileRoute } from "@tanstack/react-router";

import { SettingsScope } from "@/components/app/settings/SettingsBits";

export const Route = createFileRoute("/app/settings/privacy")({
  head: () => ({
    meta: [
      { title: "Settings · Privacy — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Settings · Privacy · Workspace in ANEXOMAIL Workspace — real data from your own workspace, with proof of where every number came from.",
      },
      { property: "og:title", content: "Settings · Privacy — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "Settings · Privacy · Workspace in ANEXOMAIL Workspace.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: () => (
    <SettingsScope
      scope="privacy"
      title="Privacy"
      blurb="Tracking, read receipts, retention and who can see what. Off by default."
    />
  ),
});
