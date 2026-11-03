/**
 * People → "Import" (switching from Google Contacts / Outlook / Zoho / Apple / LinkedIn).
 *
 * The file is read and understood in the browser (src/lib/contacts-import.ts). Only the rows the person confirms are
 * sent, 500 at a time, and the server re-validates every one. Nothing here ever emails anybody.
 *
 * Where they land:
 *   - plans WITH CRM  -> Leads first (nobody is "a person you know" until you say so), then one bulk question:
 *                        "Move these N to People?". They can also choose People straight away.
 *   - plans WITHOUT CRM (Personal Basic, Basic) -> straight into People, because there is no Leads page to look in.
 * Every skipped row is counted and shown.
 */
import { BrandSpinner } from "@/components/state/BrandLoader";
import { Link } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { Check, Upload, UserPlus, X } from "lucide-react";
import { useRef, useState } from "react";

import { Button } from "@/components/ui/button";
import { ApiError } from "@/lib/api";
import {
  IMPORT_BATCH,
  IMPORT_MAX_ROWS,
  batches,
  parseContacts,
  type ImportPlan,
} from "@/lib/contacts-import";
import { notify } from "@/lib/notify";
import { rpcOrRest } from "@/lib/rpc";

export type LoadedContacts = ImportPlan & { fileName: string };

const MAX_FILE_BYTES = 10 * 1024 * 1024;

/** Outlook's "Unicode text" CSV and some Windows tools save UTF-16; everything else is UTF-8. */
async function readText(file: File): Promise<string> {
  const buf = await file.arrayBuffer();
  const b = new Uint8Array(buf.slice(0, 2));
  if (b[0] === 0xff && b[1] === 0xfe) return new TextDecoder("utf-16le").decode(buf);
  if (b[0] === 0xfe && b[1] === 0xff) return new TextDecoder("utf-16be").decode(buf);
  return new TextDecoder("utf-8").decode(buf);
}

export function ContactsPickButton({ onLoaded }: { onLoaded: (p: LoadedContacts) => void }) {
  const ref = useRef<HTMLInputElement>(null);
  return (
    <>
      <button
        type="button"
        onClick={() => ref.current?.click()}
        aria-label="Import contacts from a file"
        title="Import contacts — a .vcf or .csv file from Google, Outlook, Zoho or Apple"
        className="ax-press ax-focus ax-tap ax-caption inline-flex items-center justify-center gap-1.5 rounded-md border border-border px-2.5 py-1 font-semibold text-muted-foreground hover:text-foreground"
      >
        <Upload className="size-3.5" aria-hidden="true" />
        Import
      </button>
      <input
        ref={ref}
        type="file"
        accept=".vcf,.csv,text/vcard,text/x-vcard,text/csv"
        className="sr-only"
        tabIndex={-1}
        aria-hidden="true"
        onChange={async (e) => {
          const file = e.target.files?.[0];
          e.target.value = "";
          if (!file) return;
          if (file.size > MAX_FILE_BYTES) {
            notify.failed("That file is too big", {
              description: "An address-book export is rarely over 10 MB — is this the right file?",
            });
            return;
          }
          onLoaded({ ...parseContacts(await readText(file), file.name), fileName: file.name });
        }}
      />
    </>
  );
}

type Result = {
  created: number;
  alreadyThere: number;
  invalid: number;
  duplicate: number;
  failedRows: number;
  firstError: string;
};

const zero = (): Result => ({ created: 0, alreadyThere: 0, invalid: 0, duplicate: 0, failedRows: 0, firstError: "" });

type ServerCounts = {
  created?: number;
  already_leads?: number;
  already_in_people?: number;
  invalid?: number;
  duplicate?: number;
};

export function ContactsImportPanel({
  plan,
  hasCrm,
  onClose,
}: {
  plan: LoadedContacts;
  /** The plan has CRM (Leads exist). Without it the only sensible place is People. */
  hasCrm: boolean;
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const [toLeads, setToLeads] = useState(hasCrm);
  const [running, setRunning] = useState(false);
  const [finished, setFinished] = useState(false);
  const [done, setDone] = useState(0);
  const [res, setRes] = useState<Result>(zero());
  const [moving, setMoving] = useState(false);
  const [moved, setMoved] = useState<null | { moved: number; added: number }>(null);
  const [keptInLeads, setKeptInLeads] = useState(false);
  const cancelled = useRef(false);
  const s = plan.stats;
  const total = plan.rows.length;
  const where = toLeads ? "Leads" : "People";

  const refresh = () => {
    for (const k of ["contacts", "companies", "search", "crm", "dashboard"]) {
      void qc.invalidateQueries({ queryKey: [k] });
    }
  };

  const run = async () => {
    setRunning(true);
    setFinished(false);
    setMoved(null);
    setKeptInLeads(false);
    cancelled.current = false;
    const acc = zero();
    let sent = 0;
    for (const part of batches(plan.rows, IMPORT_BATCH)) {
      if (cancelled.current) break;
      const body = { rows: part };
      try {
        const out = await (toLeads
          ? rpcOrRest<ServerCounts>("crm.leadsImport", { path: "/api/crm/leads/import", method: "POST", body }, body)
          : rpcOrRest<ServerCounts>("people.import", { path: "/api/contacts/import", method: "POST", body }, body));
        acc.created += out.created ?? 0;
        acc.alreadyThere += (out.already_leads ?? 0) + (out.already_in_people ?? 0);
        acc.invalid += out.invalid ?? 0;
        acc.duplicate += out.duplicate ?? 0;
      } catch (x) {
        acc.failedRows += part.length;
        const err = x as ApiError;
        acc.firstError ||=
          err.status === 403 && toLeads
            ? "Your package has no Leads — import into People instead."
            : err.message || "Request failed";
        if (err.status === 403 || err.status === 401) break; // retrying the next batch would fail the same way
      }
      sent += part.length;
      setDone(sent);
      setRes({ ...acc });
    }
    setRes({ ...acc });
    setRunning(false);
    setFinished(true);
    refresh();
    if (acc.created) notify.done(`${acc.created} ${acc.created === 1 ? "person" : "people"} imported`, `Into ${where} from ${plan.fileName}`);
  };

  const moveAll = async () => {
    setMoving(true);
    try {
      const body = { source: "import" };
      const out = await rpcOrRest<{ moved?: number; added_to_people?: number }>(
        "crm.leadsMoveToPeople",
        { path: "/api/crm/leads/move-to-people", method: "POST", body },
        body,
      );
      setMoved({ moved: out.moved ?? 0, added: out.added_to_people ?? 0 });
      refresh();
      notify.done("Moved to People", `${out.moved ?? 0} lead${out.moved === 1 ? "" : "s"}`);
    } catch (x) {
      notify.failed("Could not move them", { description: x instanceof Error ? x.message : "Please try again." });
    } finally {
      setMoving(false);
    }
  };

  const lines: string[] = [];
  if (s.noEmail) lines.push(`${s.noEmail} without an email address — skipped`);
  if (s.invalidEmail) lines.push(`${s.invalidEmail} with an email that doesn't look right — skipped`);
  if (s.duplicate) lines.push(`${s.duplicate} repeated inside the file — counted once`);
  if (s.extraEmails) lines.push(`${s.extraEmails} extra address${s.extraEmails === 1 ? "" : "es"} on the same person — first one kept`);
  if (s.capped) lines.push(`Limited to the first ${IMPORT_MAX_ROWS.toLocaleString()} people — import again for the rest`);

  const readyToMove = finished && toLeads && res.created > 0 && !moved && !keptInLeads;

  return (
    <section role="region" aria-label="Import contacts" className="border-b border-border bg-secondary/40 px-ax-3 py-ax-3">
      <div className="flex items-start gap-2">
        <UserPlus className="mt-0.5 size-4 shrink-0 text-cyan-accent" aria-hidden="true" />
        <div className="min-w-0 flex-1">
          <p className="ax-label truncate text-foreground" title={plan.fileName}>
            {plan.fileName}
          </p>
          <p className="ax-caption mt-0.5" aria-live="polite">
            {plan.format === "unknown"
              ? "No email column found — is this a contacts file (.vcf or .csv with an Email column)?"
              : total === 0
                ? "No people with an email address found in this file."
                : finished
                  ? `${res.created} added to ${where}${res.failedRows ? ` · ${res.failedRows} failed` : ""}.`
                  : running
                    ? `Importing ${done} of ${total}…`
                    : `${s.found} found · ${total} can be imported`}
          </p>
        </div>
        <button
          type="button"
          onClick={() => {
            cancelled.current = true;
            onClose();
          }}
          aria-label="Close import"
          className="ax-press ax-focus ax-tap inline-flex shrink-0 items-center justify-center rounded-md p-1 text-muted-foreground"
        >
          <X className="size-4" aria-hidden="true" />
        </button>
      </div>

      {running && (
        <div
          role="progressbar"
          aria-valuemin={0}
          aria-valuemax={total}
          aria-valuenow={done}
          aria-label="Import progress"
          className="mt-2 h-1.5 overflow-hidden rounded-full bg-border"
        >
          <div className="h-full rounded-full bg-cyan-accent transition-[width]" style={{ width: `${total ? Math.round((done / total) * 100) : 0}%` }} />
        </div>
      )}

      {!running && !finished && total > 0 && (
        <>
          <ul className="mt-2 space-y-1" aria-label="First people in the file">
            {plan.rows.slice(0, 4).map((r) => (
              <li key={r.email} className="ax-caption flex min-w-0 gap-1.5">
                <span aria-hidden="true">·</span>
                <span className="min-w-0 truncate text-foreground">
                  {r.display_name ? `${r.display_name} — ` : ""}
                  <span className="text-muted-foreground">{r.email}</span>
                </span>
              </li>
            ))}
            {total > 4 && <li className="ax-caption text-muted-foreground">…and {total - 4} more</li>}
          </ul>

          {lines.length > 0 && (
            <ul className="ax-caption mt-2 space-y-1">
              {lines.map((l) => (
                <li key={l} className="flex gap-1.5">
                  <span aria-hidden="true">·</span>
                  <span>{l}</span>
                </li>
              ))}
            </ul>
          )}

          <p className="ax-caption mt-2 text-foreground">
            {hasCrm
              ? toLeads
                ? "They go to Leads first — you choose who becomes a person."
                : "They are added straight to People."
              : "They are added to People."}{" "}
            <span className="text-muted-foreground">Nothing is emailed to anyone.</span>
          </p>

          {hasCrm && (
            <label className="ax-tap mt-1 flex items-start gap-2 text-[12px] text-foreground">
              <input
                type="checkbox"
                checked={!toLeads}
                onChange={(e) => setToLeads(!e.target.checked)}
                className="mt-0.5 size-4 shrink-0 accent-[var(--cyan-accent)]"
              />
              <span>Add them straight to People instead</span>
            </label>
          )}

          <div className="mt-3 flex flex-wrap gap-2">
            <Button size="sm" onClick={() => void run()}>
              <Upload className="size-3.5" aria-hidden="true" />
              Import {total} {total === 1 ? "person" : "people"}
            </Button>
            <Button size="sm" variant="outline" onClick={onClose}>
              Cancel
            </Button>
          </div>
        </>
      )}

      {!running && !finished && total === 0 && (
        <div className="mt-3">
          <Button size="sm" variant="outline" onClick={onClose}>
            Close
          </Button>
        </div>
      )}

      {running && (
        <div className="mt-3 flex items-center gap-2">
          <BrandSpinner className="size-3.5 text-muted-foreground" aria-hidden="true" />
          <Button size="sm" variant="outline" onClick={() => (cancelled.current = true)}>
            Stop after this batch
          </Button>
        </div>
      )}

      {finished && (
        <div className="mt-3 space-y-2">
          <ul className="ax-caption space-y-1">
            {res.alreadyThere > 0 && (
              <li className="flex gap-1.5">
                <span aria-hidden="true">·</span>
                <span>{res.alreadyThere} already {toLeads ? "in Leads or People" : "in People"} — left exactly as they were</span>
              </li>
            )}
            {res.failedRows > 0 && (
              <li className="flex gap-1.5 text-destructive">
                <span aria-hidden="true">·</span>
                <span>
                  {res.failedRows} could not be added{res.firstError ? ` — ${res.firstError}` : ""}. Pick the same file again to retry; people already added are skipped.
                </span>
              </li>
            )}
          </ul>

          {readyToMove && (
            <div className="rounded-xl border border-cyan-accent/30 bg-card/60 p-ax-3">
              <p className="text-[13px] font-bold text-foreground">Move these {res.created} to People?</p>
              <p className="ax-caption mt-0.5 text-muted-foreground">
                People is for the ones you already know. Or keep them in Leads and convert them one at a time.
              </p>
              <div className="mt-2 flex flex-wrap gap-2">
                <Button size="sm" onClick={() => void moveAll()} disabled={moving}>
                  {moving ? <BrandSpinner className="size-3.5" aria-hidden="true" /> : <Check className="size-3.5" aria-hidden="true" />}
                  Move {res.created} to People
                </Button>
                <Button size="sm" variant="outline" onClick={() => setKeptInLeads(true)} disabled={moving}>
                  Keep in Leads
                </Button>
              </div>
            </div>
          )}

          {moved && (
            <p className="ax-caption text-foreground" aria-live="polite">
              {moved.moved} moved to People{moved.added !== moved.moved ? ` (${moved.moved - moved.added} were already there)` : ""}.
            </p>
          )}

          <div className="flex flex-wrap gap-2">
            {toLeads && (keptInLeads || (!moved && !readyToMove)) && res.created > 0 && (
              <Button size="sm" asChild>
                <Link to="/app/crm/leads">Open Leads</Link>
              </Button>
            )}
            <Button size="sm" variant={res.created > 0 ? "outline" : "default"} onClick={onClose} disabled={moving}>
              Done
            </Button>
          </div>
        </div>
      )}
    </section>
  );
}
