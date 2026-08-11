import { createFileRoute } from "@tanstack/react-router";
import { Bomb, MonitorSmartphone } from "lucide-react";

import { Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { RISK_TONE, useKillSecuritySession, useKillSwitch, useSecuritySessions } from "@/lib/security-platform";

export const Route = createFileRoute("/app/security/sessions")({ component: SessionsPage });

/** Feature 6 — Blast-radius kill switch: sab sessions + devices ek click, ledger proof. */
function SessionsPage() {
  const q = useSecuritySessions();
  const kill = useKillSecuritySession();
  const blast = useKillSwitch();

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><MonitorSmartphone className="size-3.5" aria-hidden="true" /> Live sessions</>}
        title="Everything signed in, right now"
        blurb="Each session shows where it is and how risky it looks. One click ends it everywhere — no waiting for a token to expire."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/security/sessions"
          skeleton={<StatSkeleton rows={4} />}
        >
          {(d) =>
            d.sessions.length === 0 ? (
              <p className="ax-caption text-muted-foreground">No live sessions right now.</p>
            ) : (
              <ul className="space-y-1.5">
                {d.sessions.map((s) => (
                  <li
                    key={s.id}
                    className="flex flex-wrap items-center gap-2 rounded-xl border border-border px-ax-3 py-ax-2 text-[12px]"
                  >
                    <span className="font-semibold text-foreground">{s.device_label ?? "Unknown device"}</span>
                    <span className="text-muted-foreground">
                      {[s.city, s.country].filter(Boolean).join(", ") || "unknown location"}
                      {s.ip ? ` · ${s.ip}` : ""}
                    </span>
                    <span className={RISK_TONE[s.risk]}>{s.risk} risk</span>
                    {s.current && <span className="text-emerald-400">this device</span>}
                    <span className="ml-auto text-steel">{relativeTime(s.last_seen_at)}</span>
                    <Button
                      size="sm"
                      variant="secondary"
                      disabled={kill.isPending}
                      onClick={() =>
                        kill.mutate(
                          { session_id: s.id },
                          {
                            onSuccess: () => notify.done("Session ended", "That device is signed out."),
                            onError: (e) =>
                              notify.failed(e.isNotImplemented ? "Not wired yet" : "Could not end session", {
                                description: e.message,
                              }),
                          },
                        )
                      }
                    >
                      Kill
                    </Button>
                  </li>
                ))}
              </ul>
            )
          }
        </CardBody>
      </Section>

      <section className="mt-10">
        <Section
          eyebrow={<><Bomb className="size-3.5" aria-hidden="true" /> Blast-radius kill switch</>}
          title="Lost a laptop? End the whole blast radius."
          blurb="Every session dies, every device except this one is blocked, and the ledger keeps a permanent signed entry of who pulled it and when."
        >
          <Button
            variant="secondary"
            disabled={blast.isPending}
            onClick={() =>
              blast.mutate(
                { reason: "Kill switch pulled from Security page" },
                {
                  onSuccess: (r) =>
                    notify.done(
                      "Blast radius cleared",
                      `${r.sessions_killed} sessions ended, ${r.devices_blocked} devices blocked.`,
                    ),
                  onError: (e) =>
                    notify.failed(e.isNotImplemented ? "Kill switch not wired yet" : "Could not run kill switch", {
                      description: e.message,
                    }),
                },
              )
            }
          >
            {blast.isPending ? "Clearing…" : "Pull the kill switch"}
          </Button>
        </Section>
      </section>
    </div>
  );
}