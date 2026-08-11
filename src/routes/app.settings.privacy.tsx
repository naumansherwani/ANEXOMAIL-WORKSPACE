import { createFileRoute } from "@tanstack/react-router";

import { SettingsScope } from "@/components/app/settings/SettingsBits";

export const Route = createFileRoute("/app/settings/privacy")({
  component: () => (
    <SettingsScope scope="privacy" title="Privacy" blurb="Tracking, read receipts, retention and who can see what. Off by default." />
  ),
});
