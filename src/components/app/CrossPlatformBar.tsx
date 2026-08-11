/**
 * Phase 28 — Cross-Platform surface bits: install prompt, offline badge,
 * low-data badge and the device handoff banner. All client-only, all honest —
 * nothing here claims a send.
 */

import { useEffect, useState } from "react";
import { Download, Laptop, SignalLow, WifiOff } from "lucide-react";

import { useNetwork } from "@/lib/network";
import { deviceId, useClaimHandoff, useHandoffDrafts } from "@/lib/handoff";
import { notify } from "@/lib/notify";

type InstallPrompt = Event & { prompt: () => Promise<void>; userChoice?: Promise<unknown> };

export function CrossPlatformBar() {
  const net = useNetwork();
  const [prompt, setPrompt] = useState<InstallPrompt | null>(null);
  const [installed, setInstalled] = useState(false);

  useEffect(() => {
    const onPrompt = (event: Event) => {
      event.preventDefault();
      setPrompt(event as InstallPrompt);
    };
    const onInstalled = () => {
      setInstalled(true);
      setPrompt(null);
    };
    window.addEventListener("beforeinstallprompt", onPrompt);
    window.addEventListener("appinstalled", onInstalled);
    setInstalled(window.matchMedia("(display-mode: standalone)").matches);
    return () => {
      window.removeEventListener("beforeinstallprompt", onPrompt);
      window.removeEventListener("appinstalled", onInstalled);
    };
  }, []);

  const chips: { key: string; icon: React.ReactNode; text: string; onClick?: () => void }[] = [];

  if (!net.online) {
    chips.push({
      key: "offline",
      icon: <WifiOff className="size-3" aria-hidden="true" />,
      text: "Offline — reading cached mail",
    });
  }
  if (net.lowData) {
    chips.push({
      key: "low",
      icon: <SignalLow className="size-3" aria-hidden="true" />,
      text: "Low data mode — images off",
    });
  }
  if (prompt && !installed) {
    chips.push({
      key: "install",
      icon: <Download className="size-3" aria-hidden="true" />,
      text: "Install ANEXOMAIL",
      onClick: () => {
        void prompt.prompt();
        setPrompt(null);
      },
    });
  }

  if (chips.length === 0) return null;

  return (
    <div className="pointer-events-auto fixed left-1/2 top-2 z-50 flex -translate-x-1/2 flex-wrap items-center justify-center gap-1.5">
      {chips.map((chip) =>
        chip.onClick ? (
          <button
            key={chip.key}
            type="button"
            onClick={chip.onClick}
            className="ax-press flex items-center gap-1.5 rounded-full border border-border bg-card/95 px-2.5 py-1 text-[11px] font-semibold text-foreground backdrop-blur"
          >
            {chip.icon}
            {chip.text}
          </button>
        ) : (
          <span
            key={chip.key}
            className="flex items-center gap-1.5 rounded-full border border-border bg-card/95 px-2.5 py-1 text-[11px] font-semibold text-muted-foreground backdrop-blur"
          >
            {chip.icon}
            {chip.text}
          </span>
        ),
      )}
    </div>
  );
}

/**
 * Handoff banner — a draft left open on another device. Real rows only:
 * if the endpoint isn't wired the banner simply never appears.
 */
export function HandoffBanner({ onResume }: { onResume?: (draftId: string) => void }) {
  const drafts = useHandoffDrafts();
  const claim = useClaimHandoff();
  const [dismissed, setDismissed] = useState<string[]>([]);

  const mine = deviceId();
  const other = (drafts.data?.drafts ?? []).find(
    (d) => d.device_id !== mine && !dismissed.includes(d.id) && (d.body ?? "").trim().length > 0,
  );
  if (!other) return null;

  return (
    <div className="flex flex-wrap items-center gap-3 border-b border-border bg-secondary/60 px-4 py-2">
      <Laptop className="size-3.5 shrink-0 text-muted-foreground" aria-hidden="true" />
      <p className="min-w-0 flex-1 truncate text-[12px] text-foreground">
        <span className="font-semibold">{other.device_label}</span>: “
        {(other.subject ?? other.body ?? "").slice(0, 60)}” — cursor at {other.cursor_position}
      </p>
      <button
        type="button"
        onClick={() =>
          claim.mutate(
            { id: other.id },
            {
              onSuccess: () => {
                notify.done("Draft moved to this device");
                onResume?.(other.id);
              },
              onError: (error) => notify.failed("Couldn't pick it up", { description: error.message }),
            },
          )
        }
        className="ax-press shrink-0 rounded-lg border border-border bg-card px-2.5 py-1 text-[11px] font-semibold text-foreground"
      >
        Continue here
      </button>
      <button
        type="button"
        onClick={() => setDismissed((list) => [...list, other.id])}
        className="shrink-0 text-[11px] text-muted-foreground"
      >
        Dismiss
      </button>
    </div>
  );
}