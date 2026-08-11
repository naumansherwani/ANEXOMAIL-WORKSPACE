import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/app/admin/export")({
  head: () => ({
    meta: [
      { title: "Export — ANEXOMAIL Admin" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: ExportPage,
});

const items = [
  "Mailboxes, in a standard format any mail client can read",
  "Contacts and shared address membership",
  "Calendars and invitations",
  "Tasks, notes and thread history",
];

function ExportPage() {
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-10 md:px-10">
      <p className="ax-eyebrow">Freedom</p>
      <h2 className="mt-3 text-3xl text-foreground">Export & revoke</h2>
      <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
        Your data leaves as easily as it arrived. One click, no ticket, no waiting period.
        Delete means deleted.
      </p>

      <ul className="mt-8 space-y-2.5">
        {items.map((i) => (
          <li
            key={i}
            className="rounded-xl border border-border bg-card px-4 py-3 text-sm text-muted-foreground"
          >
            {i}
          </li>
        ))}
      </ul>

      <p className="mt-8 text-sm text-muted-foreground">
        Nothing to export yet — this becomes available with your first mailbox.
      </p>
    </div>
  );
}