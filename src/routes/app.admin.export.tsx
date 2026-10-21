import { BrandSpinner } from "@/components/state/BrandLoader";
import { createFileRoute, Link } from "@tanstack/react-router";
import { Download } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { notify } from "@/lib/notify";
import { downloadOrgExport, exportErrorText } from "@/lib/org-export";

export const Route = createFileRoute("/app/admin/export")({
  head: () => ({
    meta: [{ title: "Export — ANEXOMAIL Admin" }, { name: "robots", content: "noindex" }],
  }),
  component: ExportPage,
});

const INCLUDED = [
  "Workspace members and their roles",
  "Mail thread records",
  "Calendar events",
  "Tasks",
  "CRM leads and deals",
];

function ExportPage() {
  const [busy, setBusy] = useState(false);

  const run = () => {
    setBusy(true);
    downloadOrgExport()
      .then(() => notify.done("Export downloaded", "Everything listed on this page is in the file."))
      .catch((e: unknown) => notify.failed("Export failed", { description: exportErrorText(e) }))
      .finally(() => setBusy(false));
  };

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <p className="ax-eyebrow">Freedom</p>
      <h2 className="mt-3 text-2xl text-foreground sm:text-3xl">Export your data</h2>
      <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
        One click, no ticket, no waiting period. The file is built on the spot and the export is written to the audit log.
      </p>

      <section className="ax-plane mt-ax-6 rounded-2xl p-ax-4 sm:p-ax-5" aria-labelledby="export-now">
        <h3 id="export-now" className="ax-heading text-foreground">
          Everything in one JSON file
        </h3>
        <ul className="mt-ax-3 grid gap-1.5 text-sm text-muted-foreground sm:grid-cols-2">
          {INCLUDED.map((i) => (
            <li key={i} className="flex gap-2">
              <span aria-hidden="true" className="text-cyan-accent">
                ✓
              </span>
              {i}
            </li>
          ))}
        </ul>
        <div className="mt-ax-4 flex flex-wrap items-center gap-3">
          <Button className="ax-tap max-sm:w-full" onClick={run} disabled={busy}>
            {busy ? (
              <BrandSpinner className="size-4" aria-hidden="true" />
            ) : (
              <Download className="size-4" aria-hidden="true" />
            )}
            {busy ? "Building your file…" : "Export all data (JSON)"}
          </Button>
          <p className="ax-caption text-muted-foreground">Workspace owner only.</p>
        </div>
      </section>

      <section className="mt-ax-6" aria-labelledby="export-mail">
        <h3 id="export-mail" className="ax-heading text-foreground">
          Taking your mail itself with you
        </h3>
        <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
          The JSON file holds records, not message files. To move the mail itself, add the mailbox to any mail app (Apple
          Mail, Outlook, Thunderbird) over IMAP and copy the folders across — the mailboxes speak standard IMAP, so
          nothing is locked in. A one-click download of mailboxes as .eml / mbox files is not built yet.
        </p>
        <p className="mt-3 text-sm text-muted-foreground">
          Bringing mail <em>in</em> from Google Workspace or Zoho?{" "}
          <Link to="/app/integrations" className="ax-focus font-semibold text-foreground underline underline-offset-2">
            Open Integrations
          </Link>
          .
        </p>
      </section>
    </div>
  );
}
