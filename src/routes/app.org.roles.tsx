import { createFileRoute } from "@tanstack/react-router";
import { Check, Minus } from "lucide-react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Chip, SectionTitle } from "@/components/app/org/OrgBits";
import { usePrivilegeRadar, useOrgRoles } from "@/lib/org";

export const Route = createFileRoute("/app/org/roles")({
  head: () => ({
    meta: [
      { title: "Roles — ANEXOMAIL Organization Center" },
      {
        name: "description",
        content:
          "A capability matrix that shows exactly what each role can do, plus a radar for admin power nobody is using.",
      },
      { property: "og:title", content: "Roles — ANEXOMAIL Organization Center" },
      { property: "og:description", content: "Capability matrix per role and least-privilege radar." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: RolesPage,
});

function RolesPage() {
  const roles = useOrgRoles();
  const radar = usePrivilegeRadar();

  return (
    <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10">
      <SectionTitle
        title="Roles and capabilities"
        hint="No hidden powers. Every capability the server enforces is printed here."
      />

      <CardBody
        query={{
          data: roles.data,
          isPending: roles.isPending,
          error: roles.error ?? null,
          refetch: () => void roles.refetch(),
        }}
        endpoint="/api/org/roles"
        skeleton={<StatSkeleton rows={6} />}
      >
        {(data) => (
          <>
            <ul className="grid gap-2 sm:grid-cols-2">
              {data.roles.map((r) => (
                <li key={r.role} className="ax-plane rounded-2xl p-ax-4">
                  <div className="flex items-center gap-2">
                    <p className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                      {r.label}
                    </p>
                    <Chip>
                      {r.members} member{r.members === 1 ? "" : "s"}
                    </Chip>
                  </div>
                  <p className="ax-caption mt-1 text-muted-foreground">{r.description}</p>
                </li>
              ))}
            </ul>

            <div className="mt-ax-5 overflow-x-auto rounded-2xl border border-border">
              <table className="w-full border-collapse text-left">
                <thead>
                  <tr className="border-b border-border">
                    <th className="ax-caption px-ax-3 py-ax-2 font-semibold text-muted-foreground">
                      Capability
                    </th>
                    {data.roles.map((r) => (
                      <th
                        key={r.role}
                        className="ax-caption px-ax-3 py-ax-2 text-center font-semibold text-muted-foreground"
                      >
                        {r.label}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {data.capabilities.map((c) => (
                    <tr key={c.key} className="border-b border-border last:border-0">
                      <td className="px-ax-3 py-ax-2 text-[13px] text-foreground">{c.label}</td>
                      {data.roles.map((r) => (
                        <td key={r.role} className="px-ax-3 py-ax-2 text-center">
                          {c.roles.includes(r.role) ? (
                            <Check className="mx-auto size-4 text-success" aria-label="allowed" />
                          ) : (
                            <Minus className="mx-auto size-4 text-steel" aria-label="not allowed" />
                          )}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </CardBody>

      <section className="mt-10">
        <SectionTitle
          title="Least-privilege radar"
          hint="Power that sits unused for 90 days is the first thing an auditor asks about."
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
              <p className="ax-caption text-muted-foreground">Nothing to downgrade right now.</p>
            ) : (
              <ul className="space-y-1.5">
                {data.findings.map((f) => (
                  <li
                    key={f.user_id}
                    className="flex flex-wrap items-center gap-2 rounded-xl border border-border px-ax-3 py-ax-2"
                  >
                    <span className="text-[13px] font-semibold text-foreground">{f.email}</span>
                    <Chip>{f.role}</Chip>
                    <Chip tone="warn">{f.days_unused}d unused</Chip>
                    <span className="ax-caption ml-auto text-muted-foreground">
                      {f.recommendation}
                    </span>
                  </li>
                ))}
              </ul>
            )
          }
        </CardBody>
      </section>
    </div>
  );
}