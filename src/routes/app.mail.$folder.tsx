import { Outlet, createFileRoute, notFound } from "@tanstack/react-router";
import { Mail, PenLine } from "lucide-react";

import { DetailPanel, EmptyState, ListPanel } from "@/components/app/Panel";
import { MAIL_FOLDERS, isMailFolder } from "@/lib/ia";

export const Route = createFileRoute("/app/mail/$folder")({
  loader: ({ params }) => {
    if (!isMailFolder(params.folder)) throw notFound();
    return { folder: params.folder };
  },
  head: ({ loaderData }) => {
    const label = loaderData
      ? MAIL_FOLDERS.find((f) => f.id === loaderData.folder)?.label
      : undefined;
    return {
      meta: [
        { title: `${label ?? "Mail"} — ANEXOMAIL Workspace` },
        { name: "robots", content: "noindex" },
      ],
    };
  },
  component: MailFolderPage,
  notFoundComponent: UnknownFolder,
});

function UnknownFolder() {
  return (
    <EmptyState
      icon={<Mail className="size-5" />}
      title="That folder doesn't exist"
      body="Pick a folder from the list, or press Cmd+K to jump anywhere in the workspace."
    />
  );
}

function MailFolderPage() {
  const { folder } = Route.useLoaderData();
  const label = MAIL_FOLDERS.find((f) => f.id === folder)?.label ?? "Mail";

  return (
    <>
      <ListPanel
        title={label}
        action={
          <button
            type="button"
            className="inline-flex items-center gap-1.5 rounded-lg border border-border bg-secondary px-2.5 py-1.5 text-xs font-semibold text-foreground transition-colors hover:bg-surface-2"
          >
            <PenLine className="size-3.5" />
            Compose
          </button>
        }
      >
        <EmptyState
          icon={<Mail className="size-5" />}
          title="No mailbox connected"
          body="Once your domain is verified and an address is created, threads land here with an owner, a status and a due date."
        />
      </ListPanel>

      <DetailPanel>
        <Outlet />
      </DetailPanel>
    </>
  );
}