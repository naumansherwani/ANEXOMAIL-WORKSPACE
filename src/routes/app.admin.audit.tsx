import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/app/admin/audit")({
  head: () => ({
    meta: [
      { title: "Audit — ANEXOMAIL Admin" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AuditPage,
});

function AuditPage() {
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-10 md:px-10">
      <p className="ax-eyebrow">Proof</p>
      <h1 className="mt-3 text-3xl text-foreground">Audit log</h1>
      <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
        Sign-ins, role changes, address changes, exports and revokes — recorded with who,
        what, when and from where. Readable by owners and admins, deletable by nobody.
      </p>
      <p className="mt-8 text-sm text-muted-foreground">
        No entries yet. The log starts with the first action in your organisation.
      </p>
    </div>
  );
}