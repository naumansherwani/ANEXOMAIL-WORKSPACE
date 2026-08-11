import { createFileRoute } from "@tanstack/react-router";

import { SettingsScope } from "@/components/app/settings/SettingsBits";

export const Route = createFileRoute("/app/settings/notifications")({
  component: () => (
    <SettingsScope scope="notifications" title="Notifications" blurb="Who is allowed to interrupt you, and when silence is enforced." />
  ),
});
