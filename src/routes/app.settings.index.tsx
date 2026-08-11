import { createFileRoute } from "@tanstack/react-router";

import { SettingsScope } from "@/components/app/settings/SettingsBits";

export const Route = createFileRoute("/app/settings/")({
  component: () => (
    <SettingsScope scope="personal" title="Personal" blurb="Your own workspace — name, signature, defaults. Nothing here leaks to anyone else." />
  ),
});
