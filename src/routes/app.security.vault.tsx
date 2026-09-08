import { createFileRoute } from "@tanstack/react-router";

import { AccountIntegrityPanel } from "@/components/app/security/AccountIntegrityPanel";
import { DeviceAppealPanel } from "@/components/app/security/DeviceAppealPanel";
import { DeviceVaultPanel } from "@/components/app/security/DeviceVaultPanel";

export const Route = createFileRoute("/app/security/vault")({
  head: () => ({
    meta: [
      { title: "Device safety vault — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Sealed, non-biometric device identity for abuse prevention, with one-click revoke and a published retention policy.",
      },
      { property: "og:title", content: "Device safety vault — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content:
          "Five coarse signals, hashed and sealed. Revoke a device and its sessions die instantly.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: VaultPage,
});

function VaultPage() {
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <DeviceVaultPanel />
      <AccountIntegrityPanel />
      <DeviceAppealPanel />
    </div>
  );
}
