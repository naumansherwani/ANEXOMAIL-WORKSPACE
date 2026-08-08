import { createFileRoute } from "@tanstack/react-router";
import { AlertTriangle, UserMinus, Users } from "lucide-react";
import { useState } from "react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Chip, SectionTitle } from "@/components/app/org/OrgBits";
import { Button } from "@/components/ui/button";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import {
  useBlastRadius,
  useOrgMembers,
  useRevokeMember,
  type BlastRadius,
  type OrgMember,
} from "@/lib/org";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/org/members")({
  head: () => ({
    meta: [
      { title: "Members — ANEXOMAIL Organization Center" },
      {
        name: "description",
        content:
          "Every member, their role, device count and MFA state — with one-click revoke that shows the blast radius first.",
      },
      { property: "og:title", content: "Members — ANEXOMAIL Organization Center" },
      { property: "og:description", content: "Members, roles, MFA and instant revoke with handover." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: MembersPage,
});

const FILTERS: (OrgMember["status"] | "all")[] = ["active", "invited", "suspended", "revoked", "all"];

function MembersPage() {
  const [status, setStatus] = useState<OrgMember["status"] | "all">("active");
  const members = useOrgMembers(status);
  const blast = useBlastRadius();
  const revoke = useRevokeMember();
  const [pending, setPending] = useState<{ member: OrgMember; radius: BlastRadius | null } | null>(
    null,
  );

  const startRevoke = (member: OrgMember) => {
    setPending({ member, radius: null });
    blast.mutate(
      { user_id: member.user_id },
      {
        onSuccess: (radius) => setPending({ member, radius }),
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Blast radius not wired yet" : "Could not check", {
            description: e.message,
          }),
      },
    );
  };

  const confirmRevoke = () => {
    if (!pending) return;
    revoke.mutate(
      { user_id: pending.member.user_id },
      {
        onSuccess: (r) => {
          notify.done("Access revoked", `Sessions, devices and aliases closed in ${r.ms}ms.`);
          setPending(null);
        },
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Revoke not wired yet" : "Could not revoke", {
            description: e.message,
          }),
      },
    );
  };

  return (
    <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0 flex-1">
          <SectionTitle
            title="Members"
            hint="One row per person. Revoke shows what breaks before anything is closed."
          />
        </div>
        <div className="flex flex-wrap gap-1">
          {FILTERS.map((f) => (
            <button
              key={f}
              type="button"
              onClick={() => setStatus(f)}
              className={cn(
                "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold capitalize",
                status === f
                  ? "border-cyan-accent/50 bg-secondary text-foreground"
                  : "border-border text-muted-foreground",
              )}
            >
              {f}
            </button>
          ))}
        </div>
      </div>

      {pending && (
        <div className="mt-ax-4 rounded-2xl border border-warning/40 bg-warning/5 p-ax-5">
          <div className="flex items-center gap-2">
            <AlertTriangle className="size-4 text-warning" aria-hidden="true" />
            <p className="text-[13px] font-bold text-foreground">
              Offboarding blast radius — {pending.member.email}
            </p>
          </div>
          {pending.radius === null ? (
            <p className="ax-caption mt-2 text-muted-foreground">Measuring on the server…</p>
          ) : (
            <ul className="ax-caption mt-2 grid gap-1 text-muted-foreground sm:grid-cols-2">
              <li>{pending.radius.threads_orphaned} threads would lose their owner</li>
              <li>{pending.radius.shared_addresses} shared addresses to reassign</li>
              <li>{pending.radius.pending_approvals} approvals still pending</li>
              <li>{pending.radius.calendar_events} future meetings organised</li>
            </ul>
          )}
          <p className="ax-caption mt-2 text-muted-foreground">
            {pending.radius?.transfer_to
              ? `Ownership transfers to ${pending.radius.transfer_to}. Company data never dies.`
              : "Ownership transfers to the manager on record."}
          </p>
          <div className="mt-ax-4 flex flex-wrap gap-2">
            <Button variant="destructive" disabled={revoke.isPending} onClick={confirmRevoke}>
              <UserMinus className="size-4" aria-hidden="true" /> Revoke everything now
            </Button>
            <Button variant="secondary" onClick={() => setPending(null)}>
              Cancel
            </Button>
          </div>
        </div>
      )}

      <div className="mt-ax-4">
        <CardBody
          query={{
            data: members.data,
            isPending: members.isPending,
            error: members.error ?? null,
            refetch: () => void members.refetch(),
          }}
          endpoint="/api/org/members"
          skeleton={<StatSkeleton rows={6} />}
        >
          {(data) =>
            data.members.length === 0 ? (
              <p className="ax-caption text-muted-foreground">No members in this state.</p>
            ) : (
              <ul className="space-y-ax-2">
                {data.members.map((m) => (
                  <li key={m.user_id} className="ax-plane rounded-2xl p-ax-4">
                    <div className="flex flex-wrap items-center gap-ax-3">
                      <Users className="size-4 text-steel" aria-hidden="true" />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-[13px] font-semibold text-foreground">
                          {m.display_name ?? m.email}
                        </p>
                        <p className="ax-caption truncate text-muted-foreground">{m.email}</p>
                      </div>
                      <Chip>{m.role}</Chip>
                      {m.department && <Chip>{m.department}</Chip>}
                      <Chip tone={m.mfa ? "good" : "warn"}>{m.mfa ? "MFA on" : "no MFA"}</Chip>
                      <Chip tone={m.status === "active" ? "good" : m.status === "revoked" ? "bad" : "quiet"}>
                        {m.status}
                      </Chip>
                      <span className="ax-caption text-muted-foreground">
                        {m.sessions} session{m.sessions === 1 ? "" : "s"}
                        {m.last_active_at ? ` · ${relativeTime(m.last_active_at)}` : ""}
                      </span>
                      {m.status !== "revoked" && (
                        <Button size="sm" variant="secondary" onClick={() => startRevoke(m)}>
                          Revoke
                        </Button>
                      )}
                    </div>
                  </li>
                ))}
              </ul>
            )
          }
        </CardBody>
      </div>
    </div>
  );
}