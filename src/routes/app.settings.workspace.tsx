import { createFileRoute } from "@tanstack/react-router";

import { SettingsScope } from "@/components/app/settings/SettingsBits";

export const Route = createFileRoute("/app/settings/workspace")({
  component: () => (
    <SettingsScope scope="workspace" title="Workspace" blurb="Company-wide behaviour. Every change shows its blast radius before you save." />
  ),
});
