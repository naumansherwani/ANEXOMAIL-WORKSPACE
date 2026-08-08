import { createFileRoute } from "@tanstack/react-router";
import { Download, FileCheck2 } from "lucide-react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Chip, ProofTileCard, SectionTitle } from "@/components/app/org/OrgBits";
import { Button } from "@/components/ui/button";
import { useCompliance, useOwnershipProof } from "@/lib/org";

export const Route = createFileRoute("/app/org/compliance")({
  head: () => ({
    meta: [
      { title: "Compliance — ANEXOMAIL Organization Center" },
      {
        name: "description",
        content:
          "Retention, export, deletion, data region and subprocessors on one page, with a downloadable evidence pack.",
      },
      { property: "og:title", content: "Compliance — ANEXOMAIL Organization Center" },
      { property: "og:description", content: "Retention, export, deletion and data region in one snapshot." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CompliancePage,
});

function CompliancePage() {
  const snapshot = useCompliance();
  const proof = useOwnershipProof();

  return (
    <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10">
      <SectionTitle
        title="Compliance snapshot"
        hint="Only what your own workspace settings say — nothing here is a certification claim."
      />
      <CardBody
        query={{
          data: snapshot.data,
          isPending: snapshot.isPending,
          error: snapshot.error ?? null,
          refetch: () => void snapshot.refetch(),
        }}
        endpoint="/api/org/compliance"
        skeleton={<StatSkeleton rows={5} />}
      >
        {(data) => (
          <>
            <div className="ax-plane rounded-2xl p-ax-5">
              <ul className="ax-caption grid gap-2 text-muted-foreground sm:grid-cols-2">
                <li>
                  Retention:{" "}
                  <span className="font-semibold text-foreground">
                    {data.retention_days === null ? "not set" : `${data.retention_days} days`}
                  </span>
                </li>
                <li>
                  Data region:{" "}
                  <span className="font-semibold text-foreground">{data.data_region ?? "not set"}</span>
                </li>
                <li className="flex items-center gap-2">
                  Export <Chip tone={data.export_enabled ? "good" : "warn"}>{data.export_enabled ? "one click" : "off"}</Chip>
                </li>
                <li className="flex items-center gap-2">
                  Delete <Chip tone={data.delete_is_real ? "good" : "warn"}>{data.delete_is_real ? "real delete" : "soft only"}</Chip>
                </li>
              </ul>
              <div className="mt-ax-4 flex flex-wrap gap-2">
                <Button variant="secondary" disabled={!data.evidence_pack_ready} asChild={false}>
                  <span className="flex items-center gap-2">
                    <Download className="size-4" aria-hidden="true" />
                    {data.evidence_pack_ready ? "Download evidence pack" : "Evidence pack not ready"}
                  </span>
                </Button>
                {data.dpa_url && (
                  <Button variant="secondary" asChild>
                    <a href={data.dpa_url} target="_blank" rel="noreferrer">
                      <FileCheck2 className="size-4" aria-hidden="true" /> Data processing terms
                    </a>
                  </Button>
                )}
              </div>
            </div>

            {data.subprocessors.length > 0 && (
              <div className="mt-ax-4">
                <SectionTitle title="Subprocessors" hint="Who touches your data and why." />
                <ul className="space-y-1.5">
                  {data.subprocessors.map((s) => (
                    <li
                      key={s.name}
                      className="flex flex-wrap items-center gap-2 rounded-xl border border-border px-ax-3 py-ax-2"
                    >
                      <span className="text-[13px] font-semibold text-foreground">{s.name}</span>
                      <span className="ax-caption text-muted-foreground">{s.purpose}</span>
                      <Chip>{s.region}</Chip>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </>
        )}
      </CardBody>

      <section className="mt-10">
        <SectionTitle
          title="Ownership proof wall"
          hint="Green tiles you can hand to a client or an investor — the PDF is generated on the server."
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
              <div className="mt-ax-3">
                {data.pdf_url ? (
                  <Button variant="secondary" asChild>
                    <a href={data.pdf_url} target="_blank" rel="noreferrer">
                      <Download className="size-4" aria-hidden="true" /> Proof PDF
                      {data.domain ? ` — ${data.domain}` : ""}
                    </a>
                  </Button>
                ) : (
                  <p className="ax-caption text-muted-foreground">
                    Proof PDF appears here once the server has generated it.
                  </p>
                )}
              </div>
            </>
          )}
        </CardBody>
      </section>
    </div>
  );
}