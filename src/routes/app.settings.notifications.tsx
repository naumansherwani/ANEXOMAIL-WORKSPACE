import { createFileRoute } from "@tanstack/react-router";

import { SettingsScope } from "@/components/app/settings/SettingsBits";

export const Route = createFileRoute("/app/settings/notifications")({
  head: () => ({
    meta: [
      { title: "Settings · Notifications — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Settings · Notifications · Workspace in ANEXOMAIL Workspace — real data from your own workspace, with proof of where every number came from.",
      },
      { property: "og:title", content: "Settings · Notifications — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "Settings · Notifications · Workspace in ANEXOMAIL Workspace.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: () => (
    <SettingsScope
      scope="notifications"
      title="Notifications"
      blurb="Who is allowed to interrupt you, and when silence is enforced."
    />
  ),
});
