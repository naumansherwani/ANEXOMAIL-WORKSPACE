/**
 * Phase 28 — Cross-Platform surface bits: install prompt, offline badge,
 * low-data badge and the device handoff banner. All client-only, all honest —
 * nothing here claims a send.
 */

import { useEffect, useState } from "react";
import { useRouterState } from "@tanstack/react-router";
import { Download, Laptop, SignalLow, WifiOff, X } from "lucide-react";

import { useNetwork } from "@/lib/network";
import { deviceId, useClaimHandoff, useHandoffDrafts } from "@/lib/handoff";
import { notify } from "@/lib/notify";

type InstallPrompt = Event & { prompt: () => Promise<void>; userChoice?: Promise<unknown> };

// Once someone says "not now" the install chip stays away for 30 days. Storage can throw (private window, blocked site data),
// so every read/write is wrapped and the chip simply behaves as "not dismissed".
const INSTALL_DISMISS_KEY = "ax:install-dismissed";
const INSTALL_QUIET_MS = 30 * 24 * 60 * 60 * 1000;
function installDismissed(): boolean {
  try {
    const at = Number(window.localStorage.getItem(INSTALL_DISMISS_KEY) || 0);
    return at > 0 && Date.now() - at < INSTALL_QUIET_MS;
  } catch {
    return false;
  }
}

export function CrossPlatformBar() {
  const net = useNetwork();
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const [prompt, setPrompt] = useState<InstallPrompt | null>(null);
  const [installed, setInstalled] = useState(false);
  const [quiet, setQuiet] = useState(false);
  // Never during the first seconds: the person came to read mail, not to be sold an install.
  const [settled, setSettled] = useState(false);

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
    setQuiet(installDismissed());
    const timer = window.setTimeout(() => setSettled(true), 8000);
    return () => {
      window.removeEventListener("beforeinstallprompt", onPrompt);
      window.removeEventListener("appinstalled", onInstalled);
      window.clearTimeout(timer);
    };
  }, []);

  const inApp = pathname === "/app" || pathname.startsWith("/app/");
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
  // Install is offered inside the app only (never on the public site), once things have settled, and never again for 30 days after "x".
  const showInstall = Boolean(prompt) && !installed && !quiet && settled && inApp;
  if (showInstall && prompt) {
    chips.push({
      key: "install",
      icon: <Download className="size-3.5" aria-hidden="true" />,
      text: "Install ANEXOMAIL",
      onClick: () => {
        void prompt.prompt();
        setPrompt(null);
      },
    });
  }

  if (chips.length === 0) return null;

  const dismissInstall = () => {
    try {
      window.localStorage.setItem(INSTALL_DISMISS_KEY, String(Date.now()));
    } catch {
      /* storage blocked: the chip just comes back next visit */
    }
    setQuiet(true);
  };

  // Bottom, not top: the top centre is the search field. On phones sit above the bottom navigation bar (4rem) + home indicator.
  return (
    <div className="pointer-events-none fixed inset-x-0 bottom-[calc(4.75rem+env(safe-area-inset-bottom))] z-50 flex justify-center px-ax-4 md:bottom-5">
      <div className="pointer-events-auto flex max-w-full flex-wrap items-center justify-center gap-1.5">
        {chips.map((chip) =>
          chip.onClick ? (
            <span
              key={chip.key}
              className="flex items-center rounded-full border border-border bg-card/95 shadow-lg backdrop-blur"
            >
              <button
                type="button"
                onClick={chip.onClick}
                className="ax-focus ax-press ax-tap flex items-center gap-1.5 rounded-full py-1 ps-3.5 pe-2 text-[12px] font-semibold text-foreground"
              >
                {chip.icon}
                {chip.text}
              </button>
              <button
                type="button"
                onClick={dismissInstall}
                aria-label="Not now — don't offer to install again for a while"
                className="ax-focus ax-press ax-tap flex items-center justify-center rounded-full pe-2.5 ps-1.5 text-muted-foreground hover:text-foreground"
              >
                <X className="size-3.5" aria-hidden="true" />
              </button>
            </span>
          ) : (
            <span
              key={chip.key}
              className="flex items-center gap-1.5 rounded-full border border-border bg-card/95 px-3 py-1.5 text-[12px] font-semibold text-muted-foreground shadow-lg backdrop-blur"
            >
              {chip.icon}
              {chip.text}
            </span>
          ),
        )}
      </div>
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
              onError: (error) =>
                notify.failed("Couldn't pick it up", { description: error.message }),
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
