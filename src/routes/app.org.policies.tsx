import { createFileRoute } from "@tanstack/react-router";
import { FlaskConical, ScrollText } from "lucide-react";
import { useState } from "react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Chip, SectionTitle } from "@/components/app/org/OrgBits";
import { Button } from "@/components/ui/button";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { usePolicies, useSimulatePolicy, useTogglePolicy, type PolicySimulation } from "@/lib/org";

export const Route = createFileRoute("/app/org/policies")({
  head: () => ({
    meta: [
      { title: "Policies — ANEXOMAIL Organization Center" },
      {
        name: "description",
        content:
          "Turn a policy on only after the dry-run tells you exactly how many members and workflows it will affect.",
      },
      { property: "og:title", content: "Policies — ANEXOMAIL Organization Center" },
      { property: "og:description", content: "Policy list with a dry-run simulator before anything goes live." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: PoliciesPage,
});

function PoliciesPage() {
  const policies = usePolicies();
  const simulate = useSimulatePolicy();
  const toggle = useTogglePolicy();
  const [sim, setSim] = useState<PolicySimulation | null>(null);

  const runSimulation = (policyId: string) => {
    setSim(null);
    simulate.mutate(
      { policy_id: policyId },
      {
        onSuccess: (result) => setSim(result),
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Simulator not wired yet" : "Could not simulate", {
            description: e.message,
          }),
      },
    );
  };

  const flip = (policyId: string, enabled: boolean) =>
    toggle.mutate(
      { policy_id: policyId, enabled },
      {
        onSuccess: () => notify.done(enabled ? "Policy live" : "Policy off", "The server confirmed it."),
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Policy toggle not wired yet" : "Could not apply", {
            description: e.message,
          }),
      },
    );

  return (
    <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10">
      <SectionTitle
        title="Policies"
        hint="Guess-work zero: simulate first, then switch it on. Every change lands in the ledger."
      />

      {sim && (
        <div className="mb-ax-4 rounded-2xl border border-cyan-accent/40 bg-secondary/60 p-ax-5">
          <div className="flex items-center gap-2">
            <FlaskConical className="size-4 text-steel" aria-hidden="true" />
            <p className="text-[13px] font-bold text-foreground">Dry-run result</p>
            <Chip tone={sim.workflows_broken > 0 ? "warn" : "good"}>
              {sim.workflows_broken > 0 ? "needs a look" : "safe"}
            </Chip>
          </div>
          <p className="ax-caption mt-2 text-muted-foreground">
            {sim.members_blocked} member{sim.members_blocked === 1 ? "" : "s"} would be blocked ·{" "}
            {sim.workflows_broken} workflow{sim.workflows_broken === 1 ? "" : "s"} would break.
          </p>
          {sim.examples.length > 0 && (
            <ul className="ax-caption mt-2 list-disc space-y-0.5 pl-5 text-muted-foreground">
              {sim.examples.map((e) => (
                <li key={e}>{e}</li>
              ))}
            </ul>
          )}
        </div>
      )}

      <CardBody
        query={{
          data: policies.data,
          isPending: policies.isPending,
          error: policies.error ?? null,
          refetch: () => void policies.refetch(),
        }}
        endpoint="/api/org/policies"
        skeleton={<StatSkeleton rows={5} />}
      >
        {(data) =>
          data.policies.length === 0 ? (
            <p className="ax-caption text-muted-foreground">No policies defined yet.</p>
          ) : (
            <ul className="space-y-ax-2">
              {data.policies.map((p) => (
                <li key={p.id} className="ax-plane rounded-2xl p-ax-4">
                  <div className="flex flex-wrap items-center gap-ax-3">
                    <ScrollText className="size-4 text-steel" aria-hidden="true" />
                    <p className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                      {p.name}
                    </p>
                    <Chip>{p.kind}</Chip>
                    <Chip tone={p.enabled ? "good" : "quiet"}>{p.enabled ? "live" : "off"}</Chip>
                    <Button
                      size="sm"
                      variant="secondary"
                      disabled={simulate.isPending}
                      onClick={() => runSimulation(p.id)}
                    >
                      Dry-run
                    </Button>
                    <Button
                      size="sm"
                      variant={p.enabled ? "secondary" : "default"}
                      disabled={toggle.isPending}
                      onClick={() => flip(p.id, !p.enabled)}
                    >
                      {p.enabled ? "Turn off" : "Turn on"}
                    </Button>
                  </div>
                  <p className="ax-caption mt-1 text-muted-foreground">
                    {p.description}
                    {p.updated_at ? ` · changed ${relativeTime(p.updated_at)}` : ""}
                  </p>
                </li>
              ))}
            </ul>
          )
        }
      </CardBody>
    </div>
  );
}