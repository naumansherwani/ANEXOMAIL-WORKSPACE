import { Download, Eye, Paperclip } from "lucide-react";
import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { fetchAttachmentBlob, saveBlob } from "@/lib/mail-attachments";
import { fmtBytes, previewInfo, type PreviewKind } from "@/lib/mail-attachments-core";
import { notify } from "@/lib/notify";

const TEXT_CAP = 200_000; // chars — bari text file poori screen par nahi dalte

/**
 * EK common file chip poori website ke liye (mail, calendar files, CRM, chat): user ko do raaste —
 * "Preview" (live dekho, download ke baghair) ya "Download" (purana routine). Jo type mehfooz preview nahi
 * ho sakta (zip, docx, svg, exe...) wahan seedha Download. Bytes ek hi darwaze (fetchAttachmentBlob) se.
 */
export function AttachmentChip({
  id,
  filename,
  sizeBytes,
  className,
}: {
  id: string;
  filename: string;
  sizeBytes: number;
  className?: string;
}) {
  const info = previewInfo(filename);
  const [open, setOpen] = useState(false);

  const download = () =>
    fetchAttachmentBlob(id)
      .then((b) => {
        saveBlob(b, filename);
        notify.done("Downloaded", filename);
      })
      .catch((e: Error) => notify.failed("Download failed", { description: e.message }));

  const chip = (
    <button
      type="button"
      data-testid="attachment-download"
      onClick={info ? undefined : download}
      className={
        className ??
        "ax-press ax-hit flex items-center gap-1.5 rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground hover:text-foreground"
      }
    >
      <Paperclip className="size-3" />
      <span className="max-w-[40vw] truncate sm:max-w-xs">{filename}</span>
      <span className="text-steel">{fmtBytes(sizeBytes)}</span>
    </button>
  );

  if (!info) return chip;
  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>{chip}</DropdownMenuTrigger>
        <DropdownMenuContent align="start">
          <DropdownMenuItem onSelect={() => setOpen(true)} data-testid="attachment-preview">
            <Eye className="size-4" /> Preview
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={() => void download()}>
            <Download className="size-4" /> Download
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
      {open ? (
        <PreviewDialog
          id={id}
          filename={filename}
          kind={info.kind}
          mime={info.mime}
          onClose={() => setOpen(false)}
          onDownload={() => void download()}
        />
      ) : null}
    </>
  );
}

function PreviewDialog({
  id,
  filename,
  kind,
  mime,
  onClose,
  onDownload,
}: {
  id: string;
  filename: string;
  kind: PreviewKind;
  mime: string;
  onClose: () => void;
  onDownload: () => void;
}) {
  const [src, setSrc] = useState<string | null>(null);
  const [text, setText] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    let url: string | null = null;
    let dead = false;
    fetchAttachmentBlob(id)
      .then(async (raw) => {
        if (dead) return;
        // Type server se nahi, apni list se (octet-stream par bhi sahi dikhe; galat type inline nahi chalta).
        const blob = new Blob([raw], { type: mime });
        if (kind === "text") {
          const t = await blob.text();
          if (!dead) setText(t.length > TEXT_CAP ? `${t.slice(0, TEXT_CAP)}\n\n… (preview cut — Download for the full file)` : t);
          return;
        }
        url = URL.createObjectURL(blob);
        setSrc(url);
      })
      .catch((e: Error) => !dead && setErr(e.message));
    return () => {
      dead = true;
      if (url) URL.revokeObjectURL(url);
    };
  }, [id, kind, mime]);

  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent className="max-h-[90dvh] w-[min(56rem,calc(100vw-1.5rem))] max-w-none overflow-hidden p-0">
        <DialogHeader className="flex-row items-center gap-2 border-b border-border px-ax-4 py-ax-3">
          <DialogTitle className="min-w-0 flex-1 truncate text-sm">{filename}</DialogTitle>
          <Button type="button" size="sm" variant="secondary" onClick={onDownload} className="mr-8">
            <Download className="size-4" /> Download
          </Button>
        </DialogHeader>
        <div className="flex max-h-[calc(90dvh-4rem)] min-h-40 items-center justify-center overflow-auto p-ax-3">
          {err ? (
            <p className="text-sm text-destructive">{err}</p>
          ) : kind === "text" ? (
            text === null ? (
              <Loading />
            ) : (
              <pre className="w-full whitespace-pre-wrap break-words text-xs text-foreground">{text}</pre>
            )
          ) : !src ? (
            <Loading />
          ) : kind === "image" ? (
            <img src={src} alt={filename} className="max-h-[75dvh] max-w-full object-contain" />
          ) : kind === "pdf" ? (
            <iframe src={src} title={filename} className="h-[75dvh] w-full rounded border-0" />
          ) : kind === "video" ? (
            <video src={src} controls className="max-h-[75dvh] max-w-full" />
          ) : (
            <audio src={src} controls className="w-full" />
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}

const Loading = () => <p className="text-sm text-muted-foreground">Opening…</p>;
