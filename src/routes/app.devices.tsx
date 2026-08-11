import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { Download, Laptop, Smartphone, Trash2, WifiOff } from "lucide-react";

import { AppShell } from "@/components/app/AppShell";
import { CardBody } from "@/components/app/dashboard/DashboardCard";
import { ListSkeleton } from "@/components/state/Skeletons";
import { clearOffline, offlineSize } from "@/lib/offline";
import { deviceLabel, useClaimHandoff, useHandoffDrafts } from "@/lib/handoff";
import { notify } from "@/lib/notify";
import { useNetwork, type DataMode } from "@/lib/network";

export const Route = createFileRoute("/app/devices")({
  head: () => ({
    meta: [
      { title: "Devices & offline — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: DevicesPage,
});

const MODES: { id: DataMode; label: string; blurb: string }[] = [
  { id: "auto", label: "Auto", blurb: "Follows the radio — drops to low on 2G or Save-Data." },
  { id: "low", label: "Low data", blurb: "Text first, images off. A thread stays under 50KB." },
  { id: "full", label: "Full", blurb: "Everything loads, whatever the network." },
];

function DevicesPage() {
  const net = useNetwork();
  const drafts = useHandoffDrafts();
  const claim = useClaimHandoff();
  const [cache, setCache] = useState<{ threads: number; thread: number; drafts: number } | null>(null);
  const [standalone, setStandalone] = useState(false);

  useEffect(() => {
    void offlineSize().then(setCache);
    setStandalone(window.matchMedia("(display-mode: standalone)").matches);
  }, []);

  return (
    <AppShell>
      <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
        <p className="ax-eyebrow">Cross-platform</p>
        <h1 className="ax-heading mt-2 text-foreground">This device, and the ones you left mid-sentence</h1>
        <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
          Install it like an app, read your mail with no signal, and pick a draft back up exactly where the
          cursor was.
        </p>

        <section className="ax-plane mt-ax-6 rounded-2xl p-5">
          <p className="ax-eyebrow">This device</p>
          <div className="mt-3 grid gap-2 text-sm">
            <Row icon={<Laptop className="size-3.5" />} label="Identity" value={deviceLabel()} />
            <Row
              icon={<Download className="size-3.5" />}
              label="Installed"
              value={standalone ? "Yes — running standalone" : "Not installed"}
            />
            <Row
              icon={<WifiOff className="size-3.5" />}
              label="Network"
              value={`${net.online ? "Online" : "Offline"} · ${net.effectiveType}${net.saveData ? " · Save-Data" : ""}`}
            />
            <Row
              icon={<Smartphone className="size-3.5" />}
              label="Offline cache"
              value={
                cache
                  ? `${cache.threads} lists · ${cache.thread} threads · ${cache.drafts} drafts`
                  : "reading…"
              }
            />
          </div>
          <button
            type="button"
            onClick={async () => {
              await clearOffline();
              setCache({ threads: 0, thread: 0, drafts: 0 });
              notify.done("Offline copies deleted from this device");
            }}
            className="ax-press mt-4 inline-flex items-center gap-1.5 rounded-lg border border-border bg-card px-2.5 py-1.5 text-xs font-semibold text-foreground"
          >
            <Trash2 className="size-3.5" aria-hidden="true" /> Delete offline copies
          </button>
        </section>

        <section className="ax-plane mt-ax-4 rounded-2xl p-5">
          <p className="ax-eyebrow">Data mode</p>
          <div className="mt-3 grid gap-2 sm:grid-cols-3">
            {MODES.map((m) => (
              <button
                key={m.id}
                type="button"
                onClick={() => net.setMode(m.id)}
                className={
                  "ax-press rounded-xl border p-3 text-left " +
                  (net.mode === m.id ? "border-ring/50 bg-secondary" : "border-border bg-card")
                }
              >
                <span className="text-sm font-semibold text-foreground">{m.label}</span>
                <span className="mt-1 block text-[11px] leading-relaxed text-muted-foreground">{m.blurb}</span>
              </button>
            ))}
          </div>
          <p className="mt-3 text-[11px] text-muted-foreground">
            Currently resolved: <span className="text-foreground">{net.lowData ? "low data" : "full"}</span>.
          </p>
        </section>

        <section className="ax-plane mt-ax-4 rounded-2xl p-5">
          <p className="ax-eyebrow">Handoff — drafts open elsewhere</p>
          <div className="mt-3">
            <CardBody
              query={{
                data: drafts.data,
                isPending: drafts.isPending,
                error: drafts.error ?? null,
                refetch: () => void drafts.refetch(),
              }}
              endpoint="GET /api/mail/handoff"
              skeleton={<ListSkeleton rows={3} label="Loading drafts" />}
            >
              {(d) =>
                d.drafts.length === 0 ? (
                  <p className="text-sm text-muted-foreground">
                    Nothing waiting. Start a mail on one device and it appears here on the others.
                  </p>
                ) : (
                  <ul className="space-y-1.5">
                    {d.drafts.map((draft) => (
                      <li
                        key={draft.id}
                        className="flex flex-wrap items-center gap-3 rounded-xl border border-border bg-card px-3 py-2 text-sm"
                      >
                        <span className="min-w-0 flex-1 truncate font-semibold text-foreground">
                          {draft.subject || draft.to_address || "(no subject)"}
                        </span>
                        <span className="text-[11px] text-muted-foreground">{draft.device_label}</span>
                        <span className="text-[11px] text-steel">cursor {draft.cursor_position}</span>
                        <button
                          type="button"
                          onClick={() =>
                            claim.mutate(
                              { id: draft.id },
                              {
                                onSuccess: () => notify.done("Draft moved to this device"),
                                onError: (error) =>
                                  notify.failed("Couldn't pick it up", { description: error.message }),
                              },
                            )
                          }
                          className="ax-press rounded-lg border border-border bg-secondary px-2.5 py-1 text-[11px] font-semibold text-foreground"
                        >
                          Continue here
                        </button>
                      </li>
                    ))}
                  </ul>
                )
              }
            </CardBody>
          </div>
        </section>
      </div>
    </AppShell>
  );
}

function Row({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="flex items-center gap-3 border-b border-border/60 pb-2 last:border-0 last:pb-0">
      <span className="text-muted-foreground">{icon}</span>
      <span className="text-muted-foreground">{label}</span>
      <span className="ml-auto truncate font-semibold text-foreground">{value}</span>
    </div>
  );
}