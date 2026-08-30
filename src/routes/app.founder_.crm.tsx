import { createFileRoute, Link } from "@tanstack/react-router";
import { Crown, Power, ScrollText, ShieldCheck, Users } from "lucide-react";

import { Chip, CrmStat, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import {
  useCrmAudit,
  useCrmKillSwitch,
  useFounderCrmState,
  useTeamPermissions,
} from "@/lib/crm";

/**
 * Founder CRM founder view. Lives on founderworkspace.anexomail.com (IP allowlisted
 * in Caddy) — no separate subdomain, no DNS, no extra certificate.
 * Public users reach the CRM at aicrm.anexomail.com -> /app/crm only.
 */
export const Route = createFileRoute("/app/founder_/crm")({
  head: () => ({
    meta: [
      { title: "Founder CRM control — ANEXOMAIL" },
      {
        name: "description",
        content:
          "Founder view over the AI CRM: kill switch, tenant totals, team permissions and the full audit trail.",
      },
      { property: "og:title", content: "Founder CRM control — ANEXOMAIL" },
      { property: "og:description", content: "Kill switch, permissions and audit for the AI CRM." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: FounderCrm,
});

function FounderCrm() {
  const state = useFounderCrmState();
  const audit = useCrmAudit();
  const permissions = useTeamPermissions();
  const toggle = useCrmKillSwitch();

  const flip = (patch: { crm_enabled?: boolean; ai_enabled?: boolean }) =>
    toggle.mutate(patch, {
      onSuccess: () => notify.done("Switch applied", "The server confirmed the new state."),
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
          <Crown className="size-3.5" aria-hidden="true" /> Founder · CRM control
        </p>
        <h2 className="mt-3 text-3xl text-foreground">CRM founder view</h2>
        <p className="mt-4 max-w-2xl text-sm leading-relaxed text-muted-foreground">
          The public CRM lives at <code className="rounded-md bg-secondary px-1.5 py-0.5 text-foreground">aicrm.anexomail.com</code>.
          This page only exists on the founder host, so the public never sees the switches.
        </p>

        <div className="mt-8 grid gap-3 sm:grid-cols-4">
          <CrmStat label="Organisations" value={s ? String(s.organisations) : "—"} />
          <CrmStat label="Users" value={s ? String(s.users) : "—"} />
          <CrmStat label="Deals" value={s ? String(s.deals) : "—"} />
          <CrmStat label="Leads" value={s ? String(s.leads) : "—"} />
        </div>

        <section className="ax-plane mt-3 rounded-2xl p-ax-5">
          <div className="flex flex-wrap items-center gap-3">
            <Power className="size-4 text-steel" aria-hidden="true" />
            <div className="min-w-0 flex-1">
              <p className="text-[13px] font-semibold text-foreground">Kill switch</p>
              <p className="ax-caption text-muted-foreground">
                Stops every public CRM write instantly. Reads stay available so nobody loses data.
                {s?.last_write_at ? ` Last write ${relativeTime(s.last_write_at)}.` : ""}
              </p>
            </div>
            <Chip tone={s?.crm_enabled ? "good" : "bad"}>
              {s === undefined ? "state unknown" : s.crm_enabled ? "CRM live" : "CRM frozen"}
            </Chip>
            <Chip tone={s?.ai_enabled ? "good" : "quiet"}>
              {s === undefined ? "AI unknown" : s.ai_enabled ? "AI on" : "AI off"}
            </Chip>
          </div>
          <div className="mt-ax-4 flex flex-wrap gap-2">
            <Button
              variant={s?.crm_enabled ? "secondary" : "default"}
              disabled={toggle.isPending}
              onClick={() => flip({ crm_enabled: !(s?.crm_enabled ?? true) })}
            >
              {s?.crm_enabled ? "Freeze CRM writes" : "Unfreeze CRM writes"}
            </Button>
            <Button
              variant="secondary"
              disabled={toggle.isPending}
              onClick={() => flip({ ai_enabled: !(s?.ai_enabled ?? true) })}
            >
              {s?.ai_enabled ? "Turn AI off" : "Turn AI on"}
            </Button>
            <Button asChild variant="secondary">
              <Link to="/app/crm">Open public CRM</Link>
            </Button>
          </div>
        </section>

        <section className="mt-10">
          <SectionTitle
            title="Team permissions"
            hint="Server truth per member. A viewer can never send as a shared address."
          />
          <CardBody
            query={{
              data: permissions.data,
              isPending: permissions.isPending,
              error: permissions.error ?? null,
              refetch: () => void permissions.refetch(),
            }}
            endpoint="/api/crm/permissions"
            skeleton={<StatSkeleton rows={4} />}
          >
            {(data) =>
              data.members.length === 0 ? (
                <p className="ax-caption text-muted-foreground">No members yet.</p>
              ) : (
                <ul className="space-y-ax-2">
                  {data.members.map((m) => (
                    <li key={m.user_id} className="ax-plane rounded-2xl p-ax-4">
                      <div className="flex flex-wrap items-center gap-ax-3">
                        <Users className="size-4 text-steel" aria-hidden="true" />
                        <p className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                          {m.email}
                        </p>
                        <Chip>{m.role}</Chip>
                        <Chip tone={m.can_see_all_deals ? "good" : "quiet"}>
                          {m.can_see_all_deals ? "all deals" : "own deals"}
                        </Chip>
                        <Chip tone={m.can_send_as_shared ? "good" : "quiet"}>
                          {m.can_send_as_shared ? "shared send" : "no shared send"}
                        </Chip>
                        <Chip tone={m.can_approve ? "good" : "quiet"}>
                          {m.can_approve ? "can approve" : "no approvals"}
                        </Chip>
                      </div>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </section>

        <section className="mt-10">
          <SectionTitle
            title="Audit trail"
            hint="Every CRM write with actor, target and IP. Append-only on the server."
          />
          <CardBody
            query={{
              data: audit.data,
              isPending: audit.isPending,
              error: audit.error ?? null,
              refetch: () => void audit.refetch(),
            }}
            endpoint="/api/crm/audit"
            skeleton={<StatSkeleton rows={6} />}
          >
            {(data) =>
              data.entries.length === 0 ? (
                <p className="ax-caption text-muted-foreground">No CRM writes recorded yet.</p>
              ) : (
                <ul className="space-y-1.5">
                  {data.entries.map((e) => (
                    <li
                      key={e.id}
                      className="flex flex-wrap items-center gap-2 rounded-xl border border-border px-ax-3 py-ax-2"
                    >
                      <ScrollText className="size-3.5 text-steel" aria-hidden="true" />
                      <span className="text-[13px] font-semibold text-foreground">{e.action}</span>
                      <span className="ax-caption text-muted-foreground">
                        {e.actor}
                        {e.target ? ` → ${e.target}` : ""}
                        {e.ip ? ` · ${e.ip}` : ""}
                      </span>
                      <span className="ax-caption ml-auto text-muted-foreground">
                        {relativeTime(e.created_at)}
                      </span>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </section>

        <p className="ax-caption mt-10 flex items-center gap-2 text-muted-foreground">
          <ShieldCheck className="size-3.5" aria-hidden="true" /> Founder host only — Caddy IP
          allowlist guards this URL before the app is even reached.
        </p>
      </div>
    </div>
  );
}
