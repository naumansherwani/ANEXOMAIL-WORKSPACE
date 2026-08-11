import { createFileRoute } from "@tanstack/react-router";

import { SettingsScope } from "@/components/app/settings/SettingsBits";

export const Route = createFileRoute("/app/settings/appearance")({
  component: () => (
    <SettingsScope scope="appearance" title="Appearance" blurb="Density, theme and motion. Instant, no reload, no layout jump." />
  ),
});
