import { createFileRoute } from "@tanstack/react-router";

import { SettingsScope } from "@/components/app/settings/SettingsBits";

export const Route = createFileRoute("/app/settings/ai")({
  component: () => (
    <SettingsScope scope="ai" title="AI settings" blurb="Leo behaviour for this workspace. AI billing lives on ai.anexomail.com only." />
  ),
});
