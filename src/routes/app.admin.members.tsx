import { createFileRoute } from "@tanstack/react-router";

import { ADDRESS_MANAGER_FLAG, ROLES } from "@/lib/ia";

export const Route = createFileRoute("/app/admin/members")({
  head: () => ({
    meta: [
      { title: "Members — ANEXOMAIL Admin" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: MembersPage,
});

function MembersPage() {
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-10 md:px-10">
      <p className="ax-eyebrow">People</p>
      <h1 className="mt-3 text-3xl text-foreground">Members & roles</h1>
      <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
        Three roles, deliberately. Extra power is granted per address instead of adding
        another tier nobody can explain.
      </p>

      <ul className="mt-8 space-y-3">
        {ROLES.map((r) => (
          <li key={r.id} className="ax-plane rounded-2xl p-5">
            <h2 className="text-base font-bold text-foreground">{r.label}</h2>
            <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
              {r.summary}
            </p>
          </li>
        ))}
        <li className="rounded-2xl border border-dashed border-border p-5">
          <h2 className="text-base font-bold text-foreground">
            {ADDRESS_MANAGER_FLAG.label}
          </h2>
          <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
            {ADDRESS_MANAGER_FLAG.summary}
          </p>
        </li>
      </ul>

      <p className="mt-8 text-sm text-muted-foreground">
        No members yet — invitations open once a domain is verified.
      </p>
    </div>
  );
}