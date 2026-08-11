import { Link, createFileRoute } from "@tanstack/react-router";
import { Building2, ShieldCheck, Users } from "lucide-react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Chip, OrgStat, ProofTileCard, SectionTitle } from "@/components/app/org/OrgBits";
import { relativeTime } from "@/lib/mail";
import { useOrgOverview, useOwnershipProof, usePrivilegeRadar } from "@/lib/org";

export const Route = createFileRoute("/app/org/")({
  head: () => ({
    meta: [
      { title: "Organisation overview — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Seats, security score, domain ownership proof and open risks for your organisation in one view.",
      },
      { property: "og:title", content: "Organisation overview — ANEXOMAIL Workspace" },
      { property: "og:description", content: "Seats, security score, proof and risks in one view." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: OrgOverviewPage,
});

function OrgOverviewPage() {
  const overview = useOrgOverview();
  const proof = useOwnershipProof();
  const radar = usePrivilegeRadar();
  const o = overview.data;

  return (
    <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10">
      <p className="ax-eyebrow flex items-center gap-2">
        <Building2 className="size-3.5" aria-hidden="true" /> Overview
      </p>
      <h2 className="mt-3 text-3xl text-foreground">{o?.name ?? "Your organisation"}</h2>
      <p className="mt-4 max-w-2xl text-sm leading-relaxed text-muted-foreground">
        Everything about who works here, what they can do, and the proof that this domain is
        yours. Every number below is read from the server — nothing is estimated here.
      </p>

      <div className="mt-8 grid gap-3 sm:grid-cols-4">
        <OrgStat
          label="Seats used"
          value={o ? `${o.seats_used}/${o.seats_total}` : "—"}
          hint={o?.plan ?? undefined}
        />
        <OrgStat label="Active members" value={o ? String(o.members_active) : "—"} />
        <OrgStat label="Departments" value={o ? String(o.departments) : "—"} />
        <OrgStat
          label="Security score"
          value={o?.security_score !== null && o?.security_score !== undefined ? String(o.security_score) : "—"}
          hint={o ? `${o.open_risks} open risk${o.open_risks === 1 ? "" : "s"}` : undefined}
        />
      </div>

      <section className="mt-10">
        <SectionTitle
          title="Ownership proof"
          hint="SPF, DKIM, DMARC, MTA-STS, TLS-RPT and DNSSEC as the server last measured them."
        />
        <CardBody
          query={{
            data: proof.data,
            isPending: proof.isPending,
            error: proof.error ?? null,
            refetch: () => void proof.refetch(),
          }}
          endpoint="/api/org/proof"
          skeleton={<StatSkeleton rows={3} />}
        >
          {(data) => (
            <>
              <div className="grid gap-2 sm:grid-cols-3">
                {data.tiles.map((t) => (
                  <ProofTileCard key={t.key} tile={t} />
                ))}
              </div>
              <p className="ax-caption mt-ax-3 text-muted-foreground">
                Full evidence pack lives on{" "}
                <Link to="/app/org/compliance" className="font-semibold text-foreground underline-offset-4 hover:underline">
                  Compliance
                </Link>
                .
              </p>
            </>
          )}
        </CardBody>
      </section>

      <section className="mt-10">
        <SectionTitle
          title="Least-privilege radar"
          hint="Admin power nobody is using is the cheapest risk to remove."
        />
        <CardBody
          query={{
            data: radar.data,
            isPending: radar.isPending,
            error: radar.error ?? null,
            refetch: () => void radar.refetch(),
          }}
          endpoint="/api/org/privilege-radar"
          skeleton={<StatSkeleton rows={3} />}
        >
          {(data) =>
            data.findings.length === 0 ? (
              <p className="ax-caption text-muted-foreground">
                No unused privilege found. Everyone with power is using it.
              </p>
            ) : (
              <ul className="space-y-ax-2">
                {data.findings.map((f) => (
                  <li key={f.user_id} className="ax-plane rounded-2xl p-ax-4">
                    <div className="flex flex-wrap items-center gap-ax-3">
                      <Users className="size-4 text-steel" aria-hidden="true" />
                      <p className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                        {f.email}
                      </p>
                      <Chip>{f.role}</Chip>
                      <Chip tone="warn">{f.days_unused}d unused</Chip>
                    </div>
                    <p className="ax-caption mt-1 text-muted-foreground">{f.recommendation}</p>
                  </li>
                ))}
              </ul>
            )
          }
        </CardBody>
      </section>

      <p className="ax-caption mt-10 flex items-center gap-2 text-muted-foreground">
        <ShieldCheck className="size-3.5" aria-hidden="true" />
        {o?.last_audit_at
          ? `Last audit entry ${relativeTime(o.last_audit_at)}.`
          : "Audit ledger is append-only and hash-chained."}
      </p>
    </div>
  );
}