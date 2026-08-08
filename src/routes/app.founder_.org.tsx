import { createFileRoute, Link } from "@tanstack/react-router";
import { Building2, Crown, Power, ShieldCheck } from "lucide-react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Chip, OrgStat, SectionTitle } from "@/components/app/org/OrgBits";
import { Button } from "@/components/ui/button";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { useFounderOrgKillSwitch, useFounderOrgList, useFounderOrgState } from "@/lib/org";

/**
 * Founder god-view over every organisation. Lives on
 * founderworkspace.anexomail.com (IP allowlisted in Caddy) — awam never sees it.
 * Awam surface is /app/org only.
 */
export const Route = createFileRoute("/app/founder_/org")({
  head: () => ({
    meta: [
      { title: "Founder org control — ANEXOMAIL" },
      {
        name: "description",
        content:
          "God-view over every organisation: global write kill switch, seats, revenue truth, ledger health and break-glass state.",
      },
      { property: "og:title", content: "Founder org control — ANEXOMAIL" },
      { property: "og:description", content: "Kill switch, seats, revenue truth and ledger health." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: FounderOrg,
});

function FounderOrg() {
  const state = useFounderOrgState();
  const list = useFounderOrgList();
  const toggle = useFounderOrgKillSwitch();

  const flip = (
    patch: { org_writes_enabled?: boolean; organisation_id?: string; writes_enabled?: boolean },
    label: string,
  ) =>
    toggle.mutate(patch, {
      onSuccess: () => notify.done(label, "The server confirmed the new state."),
      onError: (e) =>
        notify.failed(e.isNotImplemented ? "Kill switch not wired yet" : "Could not apply", {
          description: e.message,
        }),
    });

  const s = state.data;

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10">
        <p className="ax-eyebrow flex items-center gap-2">
          <Crown className="size-3.5" aria-hidden="true" /> Founder only · IP locked
        </p>
        <h1 className="ax-h2 mt-1">Organisation control</h1>
        <p className="ax-caption mt-1 text-muted-foreground">
          Everything on this page is server truth. Nothing here is estimated.
        </p>

        <div className="mt-ax-5">
          <CardBody
            query={{
              data: state.data,
              isPending: state.isPending,
              error: state.error ?? null,
              refetch: () => void state.refetch(),
            }}
            endpoint="/api/founder/org/state"
            skeleton={<StatSkeleton rows={4} />}
          >
            {(d) => (
              <>
                <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
                  <OrgStat label="Organisations" value={String(d.organisations)} />
                  <OrgStat label="Users" value={String(d.users)} />
                  <OrgStat label="Paid seats" value={String(d.seats_paid)} />
                  <OrgStat
                    label="MRR"
                    value={`${d.currency === "GBP" ? "£" : `${d.currency} `}${d.mrr.toLocaleString()}`}
                  />
                </div>
                <div className="ax-plane mt-ax-4 rounded-2xl p-ax-5">
                  <div className="flex flex-wrap items-center gap-ax-3">
                    <Power className="size-4 text-steel" aria-hidden="true" />
                    <p className="min-w-0 flex-1 text-[13px] font-bold text-foreground">
                      Global org writes
                    </p>
                    <Chip tone={d.org_writes_enabled ? "good" : "bad"}>
                      {d.org_writes_enabled ? "live" : "frozen"}
                    </Chip>
                    <Button
                      variant="secondary"
                      disabled={toggle.isPending}
                      onClick={() =>
                        flip(
                          { org_writes_enabled: !d.org_writes_enabled },
                          d.org_writes_enabled ? "Writes frozen" : "Writes live",
                        )
                      }
                    >
                      {d.org_writes_enabled ? "Freeze everything" : "Unfreeze"}
                    </Button>
                  </div>
                  <p className="ax-caption mt-2 flex flex-wrap items-center gap-ax-3 text-muted-foreground">
                    <span className="flex items-center gap-1.5">
                      <ShieldCheck className="size-3.5" aria-hidden="true" />
                      Ledger{" "}
                      {d.ledger_ok === null ? "unknown" : d.ledger_ok ? "chain intact" : "chain broken"}
                    </span>
                    <span>{d.break_glass_active} break-glass active</span>
                    <span>
                      last write {d.last_write_at ? relativeTime(d.last_write_at) : "never"}
                    </span>
                  </p>
                </div>
              </>
            )}
          </CardBody>
        </div>

        <section className="mt-10">
          <SectionTitle
            title="Every organisation"
            hint="Per-tenant freeze. One click stops writes for that org alone."
          />
          <CardBody
            query={{
              data: list.data,
              isPending: list.isPending,
              error: list.error ?? null,
              refetch: () => void list.refetch(),
            }}
            endpoint="/api/founder/org/list"
            skeleton={<StatSkeleton rows={6} />}
          >
            {(data) =>
              data.organisations.length === 0 ? (
                <p className="ax-caption text-muted-foreground">No organisations yet.</p>
              ) : (
                <ul className="space-y-1.5">
                  {data.organisations.map((o) => (
                    <li
                      key={o.id}
                      className="flex flex-wrap items-center gap-2 rounded-xl border border-border px-ax-3 py-ax-2"
                    >
                      <Building2 className="size-3.5 text-steel" aria-hidden="true" />
                      <span className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                        {o.name}
                      </span>
                      <span className="ax-caption text-muted-foreground">
                        {o.primary_domain ?? "no domain"} · {o.seats_used}/{o.seats_paid} seats
                        {o.plan ? ` · ${o.plan}` : ""}
                      </span>
                      {o.security_score !== null && (
                        <Chip tone={o.security_score >= 80 ? "good" : o.security_score >= 50 ? "warn" : "bad"}>
                          score {o.security_score}
                        </Chip>
                      )}
                      <Chip tone={o.writes_enabled ? "good" : "bad"}>
                        {o.writes_enabled ? "live" : "frozen"}
                      </Chip>
                      <Button
                        size="sm"
                        variant="secondary"
                        disabled={toggle.isPending}
                        onClick={() =>
                          flip(
                            { organisation_id: o.id, writes_enabled: !o.writes_enabled },
                            o.writes_enabled ? "Tenant frozen" : "Tenant live",
                          )
                        }
                      >
                        {o.writes_enabled ? "Freeze" : "Unfreeze"}
                      </Button>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </section>

        {!s && (
          <p className="ax-caption mt-ax-4 text-muted-foreground">
            Awam surface:{" "}
            <Link to="/app/org" className="underline">
              /app/org
            </Link>
          </p>
        )}
      </div>
    </div>
  );
}