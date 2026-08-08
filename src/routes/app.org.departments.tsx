import { createFileRoute } from "@tanstack/react-router";
import { ArrowRight, Building, Timer } from "lucide-react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Chip, SectionTitle } from "@/components/app/org/OrgBits";
import { useDepartments } from "@/lib/org";

export const Route = createFileRoute("/app/org/departments")({
  head: () => ({
    meta: [
      { title: "Departments — ANEXOMAIL Organization Center" },
      {
        name: "description",
        content:
          "Departments are real routing units: a shared address, an SLA, an escalation chain and a monthly budget.",
      },
      { property: "og:title", content: "Departments — ANEXOMAIL Organization Center" },
      {
        property: "og:description",
        content: "Shared address, SLA, escalation chain and budget per department.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: DepartmentsPage,
});

function money(value: number | null, currency: string | null) {
  if (value === null) return "no budget set";
  return `${currency === "GBP" ? "£" : `${currency ?? ""} `}${value.toLocaleString()} / month`;
}

function DepartmentsPage() {
  const departments = useDepartments();

  return (
    <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10">
      <SectionTitle
        title="Departments"
        hint="Not labels — routing units. Mail lands, the SLA runs, escalation is automatic."
      />
      <CardBody
        query={{
          data: departments.data,
          isPending: departments.isPending,
          error: departments.error ?? null,
          refetch: () => void departments.refetch(),
        }}
        endpoint="/api/org/departments"
        skeleton={<StatSkeleton rows={5} />}
      >
        {(data) =>
          data.departments.length === 0 ? (
            <p className="ax-caption text-muted-foreground">
              No departments yet. Each one gets a shared address and its own SLA.
            </p>
          ) : (
            <ul className="space-y-ax-2">
              {data.departments.map((d) => (
                <li key={d.id} className="ax-plane rounded-2xl p-ax-5">
                  <div className="flex flex-wrap items-center gap-ax-3">
                    <Building className="size-4 text-steel" aria-hidden="true" />
                    <p className="min-w-0 flex-1 truncate text-[13px] font-bold text-foreground">
                      {d.name}
                    </p>
                    <Chip>
                      {d.members} member{d.members === 1 ? "" : "s"}
                    </Chip>
                    <Chip tone={d.breached_sla > 0 ? "bad" : "good"}>
                      {d.breached_sla > 0 ? `${d.breached_sla} SLA breached` : "SLA clean"}
                    </Chip>
                  </div>
                  <div className="ax-caption mt-2 grid gap-1 text-muted-foreground sm:grid-cols-2">
                    <p>{d.shared_address ?? "no shared address yet"}</p>
                    <p className="flex items-center gap-1.5">
                      <Timer className="size-3.5" aria-hidden="true" />
                      {d.sla_minutes === null ? "no SLA set" : `first reply within ${d.sla_minutes} min`}
                    </p>
                    <p>{d.open_threads} open threads</p>
                    <p>{money(d.budget_monthly, d.currency)}</p>
                  </div>
                  {d.escalation_chain.length > 0 && (
                    <p className="ax-caption mt-2 flex flex-wrap items-center gap-1 text-muted-foreground">
                      {d.escalation_chain.map((step, i) => (
                        <span key={`${d.id}-${step}`} className="flex items-center gap-1">
                          {i > 0 && <ArrowRight className="size-3" aria-hidden="true" />}
                          <span className="rounded-md bg-secondary px-1.5 py-0.5 text-foreground">
                            {step}
                          </span>
                        </span>
                      ))}
                    </p>
                  )}
                </li>
              ))}
            </ul>
          )
        }
      </CardBody>
    </div>
  );
}