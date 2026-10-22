import { useRef, useState } from "react";
import { Download, FileText, Loader2, Paperclip, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  eventFilePrecheck,
  useAddEventFile,
  useEventFiles,
  useRemoveEventFile,
  type EventFile,
} from "@/lib/calendar-files";
import { fmtBytes } from "@/lib/mail-attachments-core";
import { downloadAttachment, useAttachLimits } from "@/lib/mail-attachments";
import { notify } from "@/lib/notify";

/**
 * Files on a meeting (calendar #5): agenda, slides, a contract. The organiser adds and removes; the organiser and the workspace guests
 * open and download. Same upload pipeline as mail attachments (type check, virus scan, quota, de-duplication) — nothing new to trust.
 */
export function EventFiles({ eventId }: { eventId: string }) {
  const list = useEventFiles(eventId);
  const limits = useAttachLimits();
  const add = useAddEventFile(eventId);
  const remove = useRemoveEventFile(eventId);
  const pick = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState<{ name: string; pct: number } | null>(null);
  const [over, setOver] = useState(false);

  // 404/501: this server has no meeting files yet — say nothing rather than show a broken box
  if (list.error && (list.error.isNotImplemented || list.error.code === "sql_missing")) return null;
  if (list.isPending)
    return <p className="ax-caption mt-ax-6 text-muted-foreground">Loading files…</p>;
  if (list.error) {
    return (
      <section className="mt-ax-6">
        <p className="ax-eyebrow">Files</p>
        <p className="ax-caption mt-ax-2 text-muted-foreground">
          Files could not be loaded.{" "}
          <button
            type="button"
            className="underline underline-offset-4"
            onClick={() => void list.refetch()}
          >
            Try again
          </button>
        </p>
      </section>
    );
  }

  const { files, can_add: canAdd, max_files: maxFiles } = list.data;
  if (files.length === 0 && !canAdd) return null;

  const upload = async (picked: FileList | File[]) => {
    let have = files.length;
    for (const file of Array.from(picked)) {
      const why = eventFilePrecheck(file, have, {
        max_files: maxFiles,
        cap_bytes: limits.data?.message_cap_bytes,
      });
      if (why) {
        notify.failed("Could not add file", { description: why });
        continue;
      }
      setBusy({ name: file.name, pct: 0 });
      try {
        await add.mutateAsync({ file, onProgress: (pct) => setBusy({ name: file.name, pct }) });
        have += 1;
        notify.done("File added", `${file.name} is on this meeting. Guests were not e-mailed.`);
      } catch (e) {
        notify.failed("Could not add file", { description: (e as Error).message });
      }
    }
    setBusy(null);
  };

  const open = async (f: EventFile) => {
    try {
      await downloadAttachment(f.id, f.filename);
    } catch (e) {
      notify.failed("Could not download", { description: (e as Error).message });
    }
  };

  return (
    <section
      className="mt-ax-6"
      aria-label="Meeting files"
      onDragOver={(e) => {
        if (canAdd && e.dataTransfer.types.includes("Files")) {
          e.preventDefault();
          setOver(true);
        }
      }}
      onDragLeave={() => setOver(false)}
      onDrop={(e) => {
        setOver(false);
        if (canAdd && e.dataTransfer.files.length) {
          e.preventDefault();
          void upload(e.dataTransfer.files);
        }
      }}
    >
      <div className="flex items-center gap-2">
        <p className="ax-eyebrow">Files</p>
        {canAdd && (
          <>
            <input
              ref={pick}
              type="file"
              multiple
              className="sr-only"
              tabIndex={-1}
              onChange={(e) => {
                if (e.target.files?.length) void upload(e.target.files);
                e.target.value = "";
              }}
            />
            <Button
              type="button"
              size="sm"
              variant="outline"
              className="ml-auto min-h-11 sm:min-h-8"
              disabled={!!busy || files.length >= maxFiles}
              onClick={() => pick.current?.click()}
            >
              <Paperclip className="size-4" />
              Add file
            </Button>
          </>
        )}
      </div>

      {files.length === 0 && !busy ? (
        <p
          className={`ax-caption mt-ax-2 rounded-md border border-dashed px-3 py-3 text-muted-foreground ${over ? "border-foreground" : "border-border"}`}
        >
          Add the agenda, slides or a contract. Guests in your workspace can open them from this
          meeting.
        </p>
      ) : (
        <ul
          className={`mt-ax-2 divide-y divide-border rounded-md border ${over ? "border-foreground" : "border-border"}`}
        >
          {files.map((f) => (
            <li key={f.id} className="flex items-center gap-ax-3 px-ax-3 py-ax-2">
              <FileText className="size-4 shrink-0 text-steel" aria-hidden="true" />
              <button
                type="button"
                onClick={() => void open(f)}
                className="ax-focus min-h-11 min-w-0 flex-1 truncate text-left text-[13px] text-foreground underline-offset-4 hover:underline sm:min-h-0"
                title={`Download ${f.filename}`}
              >
                {f.filename}
              </button>
              <span className="ax-caption shrink-0 tabular-nums text-muted-foreground">
                {fmtBytes(f.size_bytes)}
                {!f.scanned ? " · not scanned" : ""}
              </span>
              <button
                type="button"
                aria-label={`Download ${f.filename}`}
                onClick={() => void open(f)}
                className="ax-focus ax-press grid size-11 shrink-0 place-items-center rounded-md text-muted-foreground sm:size-8"
              >
                <Download className="size-4" />
              </button>
              {f.can_remove && (
                <button
                  type="button"
                  aria-label={`Remove ${f.filename}`}
                  disabled={remove.isPending}
                  onClick={() =>
                    remove.mutate(
                      { id: f.id },
                      {
                        onSuccess: () => notify.done("File removed", "Guests were not e-mailed."),
                        onError: (e) =>
                          notify.failed("Could not remove", { description: e.message }),
                      },
                    )
                  }
                  className="ax-focus ax-press grid size-11 shrink-0 place-items-center rounded-md text-muted-foreground sm:size-8"
                >
                  <Trash2 className="size-4" />
                </button>
              )}
            </li>
          ))}
          {busy && (
            <li className="flex items-center gap-ax-3 px-ax-3 py-ax-2" aria-live="polite">
              <Loader2 className="size-4 shrink-0 animate-spin text-steel" aria-hidden="true" />
              <span className="min-w-0 flex-1 truncate text-[13px] text-muted-foreground">
                {busy.name}
              </span>
              <span className="ax-caption shrink-0 tabular-nums text-muted-foreground">
                {busy.pct}%
              </span>
            </li>
          )}
        </ul>
      )}
    </section>
  );
}
