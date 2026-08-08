import { createFileRoute } from "@tanstack/react-router";
import { KeyRound, MapPin, Monitor, Siren } from "lucide-react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Chip, SectionTitle } from "@/components/app/org/OrgBits";
import { Button } from "@/components/ui/button";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { useAnomalies, useBreakGlass, useGrantBreakGlass, useKillSession, useOrgSessions } from "@/lib/org";

export const Route = createFileRoute("/app/org/security")({
  head: () => ({
    meta: [
      { title: "Security — ANEXOMAIL Organization Center" },
      {
        name: "description",
        content:
          "Live sessions and devices with a one-click kill, impossible-travel alerts and time-boxed break-glass access.",
      },
      { property: "og:title", content: "Security — ANEXOMAIL Organization Center" },
      { property: "og:description", content: "Session map, device kill, anomaly alerts, break-glass access." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: SecurityPage,
});

function SecurityPage() {
  const sessions = useOrgSessions();
  const alerts = useAnomalies();
  const grants = useBreakGlass();
  const kill = useKillSession();
  const grant = useGrantBreakGlass();

  const killDevice = (id: string) =>
    kill.mutate(
      { session_id: id },
      {
        onSuccess: () => notify.done("Device signed out", "That session is dead everywhere."),
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Kill device not wired yet" : "Could not sign out", {
            description: e.message,
          }),
      },
    );

  const openBreakGlass = () =>
    grant.mutate(
      { reason: "Emergency admin access from Security page", minutes: 30 },
      {
        onSuccess: () => notify.done("Break-glass open", "30 minutes only. Everyone was notified."),
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Break-glass not wired yet" : "Could not open", {
            description: e.message,
          }),
      },
    );

  return (
    <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10">
      <SectionTitle
        title="Session and device map"
        hint="Every live session with its city and device. One click ends it everywhere."
      />
      <CardBody
        query={{
          data: sessions.data,
          isPending: sessions.isPending,
          error: sessions.error ?? null,
          refetch: () => void sessions.refetch(),
        }}
        endpoint="/api/org/sessions"
        skeleton={<StatSkeleton rows={5} />}
      >
        {(data) =>
          data.sessions.length === 0 ? (
            <p className="ax-caption text-muted-foreground">No live sessions right now.</p>
          ) : (
            <ul className="space-y-1.5">
              {data.sessions.map((s) => (
                <li
                  key={s.id}
                  className="flex flex-wrap items-center gap-2 rounded-xl border border-border px-ax-3 py-ax-2"
                >
                  <Monitor className="size-3.5 text-steel" aria-hidden="true" />
                  <span className="text-[13px] font-semibold text-foreground">{s.email}</span>
                  <span className="ax-caption flex items-center gap-1 text-muted-foreground">
                    <MapPin className="size-3" aria-hidden="true" />
                    {[s.city, s.country].filter(Boolean).join(", ") || "unknown location"}
                    {s.ip ? ` · ${s.ip}` : ""}
                  </span>
                  <span className="ax-caption text-muted-foreground">
                    {[s.device, s.browser].filter(Boolean).join(" · ") || "unknown device"}
                  </span>
                  {s.current && <Chip tone="good">this device</Chip>}
                  <span className="ax-caption ml-auto text-muted-foreground">
                    {relativeTime(s.last_seen_at)}
                  </span>
                  <Button
                    size="sm"
                    variant="secondary"
                    disabled={kill.isPending}
                    onClick={() => killDevice(s.id)}
                  >
                    Kill
                  </Button>
                </li>
              ))}
            </ul>
          )
        }
      </CardBody>

      <section className="mt-10">
        <SectionTitle
          title="Anomaly alerts"
          hint="Impossible travel, new country, token reuse and mass export — the server freezes first, asks later."
        />
        <CardBody
          query={{
            data: alerts.data,
            isPending: alerts.isPending,
            error: alerts.error ?? null,
            refetch: () => void alerts.refetch(),
          }}
          endpoint="/api/org/anomalies"
          skeleton={<StatSkeleton rows={3} />}
        >
          {(data) =>
            data.alerts.length === 0 ? (
              <p className="ax-caption text-muted-foreground">Nothing suspicious recorded.</p>
            ) : (
              <ul className="space-y-ax-2">
                {data.alerts.map((a) => (
                  <li key={a.id} className="ax-plane rounded-2xl p-ax-4">
                    <div className="flex flex-wrap items-center gap-ax-3">
                      <Siren className="size-4 text-steel" aria-hidden="true" />
                      <p className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                        {a.email}
                      </p>
                      <Chip>{a.kind.replace(/_/g, " ")}</Chip>
                      <Chip tone={a.severity === "high" ? "bad" : a.severity === "medium" ? "warn" : "quiet"}>
                        {a.severity}
                      </Chip>
                      <Chip tone={a.state === "frozen" ? "bad" : a.state === "cleared" ? "good" : "warn"}>
                        {a.state}
                      </Chip>
                      <span className="ax-caption text-muted-foreground">
                        {relativeTime(a.created_at)}
                      </span>
                    </div>
                    <p className="ax-caption mt-1 text-muted-foreground">{a.detail}</p>
                  </li>
                ))}
              </ul>
            )
          }
        </CardBody>
      </section>

      <section className="mt-10">
        <SectionTitle
          title="Break-glass access"
          hint="Emergency admin power for 30 minutes. Everyone is notified and the ledger keeps a permanent red entry."
        />
        <div className="ax-plane rounded-2xl p-ax-5">
          <div className="flex flex-wrap items-center gap-ax-3">
            <KeyRound className="size-4 text-steel" aria-hidden="true" />
            <p className="min-w-0 flex-1 text-[13px] font-semibold text-foreground">
              Open emergency access
            </p>
            <Button variant="secondary" disabled={grant.isPending} onClick={openBreakGlass}>
              Break glass (30 min)
            </Button>
          </div>
          <div className="mt-ax-4">
            <CardBody
              query={{
                data: grants.data,
                isPending: grants.isPending,
                error: grants.error ?? null,
                refetch: () => void grants.refetch(),
              }}
              endpoint="/api/org/break-glass"
              skeleton={<StatSkeleton rows={2} />}
            >
              {(data) =>
                data.grants.length === 0 ? (
                  <p className="ax-caption text-muted-foreground">
                    Never used. That is the number you want to keep.
                  </p>
                ) : (
                  <ul className="space-y-1.5">
                    {data.grants.map((g) => (
                      <li
                        key={g.id}
                        className="flex flex-wrap items-center gap-2 rounded-xl border border-danger/30 px-ax-3 py-ax-2"
                      >
                        <span className="text-[13px] font-semibold text-foreground">{g.actor}</span>
                        <Chip tone={g.state === "active" ? "bad" : "quiet"}>{g.state}</Chip>
                        <span className="ax-caption text-muted-foreground">{g.reason}</span>
                        <span className="ax-caption ml-auto text-muted-foreground">
                          {relativeTime(g.granted_at)}
                        </span>
                      </li>
                    ))}
                  </ul>
                )
              }
            </CardBody>
          </div>
        </div>
      </section>
    </div>
  );
}