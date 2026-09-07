/**
 * ANEXOChat · PHASE 13/14/15 — FILE ENGINE panel
 *
 * Sach bolne wala UI: pooled storage aur transfer volume alag dikhte hain,
 * progress sirf verified chunks se, resume/pause asli transfer identity par,
 * aur transport label wahi jo asal mein use ho raha hai (HTTP/3 ya fallback).
 */
import { useRef, useState } from "react";
import { FileStack, History, Pause, Play, UploadCloud } from "lucide-react";

import { Row, Stat } from "@/components/app/analytics/AnalyticsBits";
import {
  bytesLabel,
  useFileEngine,
  useFileTransfers,
  useFileVersions,
  type TransferUi,
} from "@/lib/chat-files";

const STATE_COPY: Record<TransferUi["state"], string> = {
  preparing: "Preparing",
  transferring: "Transferring",
  paused: "Paused",
  verifying: "Verifying",
  done: "Stored",
  failed: "Failed",
  rejected: "Refused",
};

function TransferRow({
  t,
  onPause,
  onResume,
}: {
  t: TransferUi;
  onPause: () => void;
  onResume: () => void;
}) {
  return (
    <li className="rounded-lg border border-border/60 p-ax-4">
      <div className="flex flex-wrap items-baseline gap-2">
        <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{t.name}</span>
        <span className="text-sm text-foreground">
          {bytesLabel(t.bytesDone)} / {bytesLabel(t.bytes)}
        </span>
        <span className="text-sm text-steel">{Math.floor(t.percent)}%</span>
      </div>
      <div
        className="mt-2 h-2 w-full overflow-hidden rounded-full bg-muted"
        role="progressbar"
        aria-valuenow={Math.floor(t.percent)}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={`${t.name} transfer progress`}
      >
        <div
          className={`h-full ${t.state === "failed" || t.state === "rejected" ? "bg-destructive" : t.state === "paused" ? "bg-amber-500" : "bg-primary"}`}
          style={{ width: `${Math.min(t.percent, 100)}%` }}
        />
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-ax-3 text-sm">
        <span className="text-foreground">{STATE_COPY[t.state]}</span>
        <span className="text-muted-foreground">{t.detail}</span>
        <span className="text-steel">
          {t.transport === "rust-quic"
            ? "HTTP/3 · QUIC"
            : t.transport === "bun-fallback"
              ? "fallback path"
              : "offline"}
        </span>
        {t.repaired > 0 && <span className="text-steel">{t.repaired} chunk repaired</span>}
        {t.state === "transferring" && (
          <button type="button" onClick={onPause} className="inline-flex items-center gap-1 text-primary">
            <Pause className="size-3.5" aria-hidden="true" /> Pause
          </button>
        )}
        {(t.state === "paused" || t.state === "failed") && (
          <button type="button" onClick={onResume} className="inline-flex items-center gap-1 text-primary">
            <Play className="size-3.5" aria-hidden="true" /> Resume
          </button>
        )}
      </div>
    </li>
  );
}

function VersionList({ fileId }: { fileId: string }) {
  const q = useFileVersions(fileId);
  if (q.isPending) return <p className="mt-2 text-sm text-steel">Loading versions…</p>;
  const versions = q.data?.versions ?? [];
  if (!versions.length) return <p className="mt-2 text-sm text-steel">No stored version yet.</p>;
  return (
    <ul className="mt-2 space-y-1 text-sm">
      {versions.map((v) => (
        <li key={v.version_id} className="flex flex-wrap gap-2 text-muted-foreground">
          <span className="text-foreground">v{v.version}</span>
          <span>{bytesLabel(v.bytes)}</span>
          <span>{v.state}</span>
          <span>{v.ready_at ? new Date(v.ready_at).toLocaleString() : "in transfer"}</span>
        </li>
      ))}
    </ul>
  );
}

export function FileTransfers({ conversationId = null }: { conversationId?: string | null }) {
  const engine = useFileEngine();
  const { items, add, pause, resume, online } = useFileTransfers(conversationId);
  const input = useRef<HTMLInputElement | null>(null);
  const [openFile, setOpenFile] = useState<string | null>(null);

  const pool = engine.data?.pool;

  return (
    <section className="mt-ax-6 rounded-lg border border-border/60 p-ax-4">
      <h2 className="ax-heading flex items-center gap-2 text-foreground">
        <FileStack className="size-4" aria-hidden="true" /> Workspace file engine
      </h2>
      <p className="mt-1 text-sm text-muted-foreground">
        Transfer and storage are separate: transfer is what moves, storage is what stays. Progress
        counts only chunks the server has verified.
      </p>

      {engine.error && (
        <Row>
          <span className="text-muted-foreground">
            File engine reachable nahi — endpoint /api/chat/file/state.
          </span>
        </Row>
      )}

      {pool && (
        <>
          <div className="mt-ax-3 grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
            <Stat label="Plan" value={pool.plan.replace("_", " ")} />
            <Stat label="Single file max" value={bytesLabel(pool.max_file_bytes)} />
            <Stat
              label="Pooled storage"
              value={`${bytesLabel(pool.stored_bytes)} / ${bytesLabel(pool.pool_bytes)}`}
              hint={`${bytesLabel(pool.remaining_bytes)} remaining`}
            />
            <Stat
              label="Transfer this month"
              value={bytesLabel(pool.transfer_month_bytes)}
              hint={
                pool.transfer_unlimited
                  ? "unlimited volume"
                  : pool.transfer_month_limit
                    ? `of ${bytesLabel(pool.transfer_month_limit)}`
                    : "no limit recorded"
              }
            />
          </div>
          <div className="mt-2 h-2 w-full overflow-hidden rounded-full bg-muted">
            <div className="h-full bg-primary" style={{ width: `${Math.min(pool.percent, 100)}%` }} />
          </div>
        </>
      )}

      {pool && !pool.entitled ? (
        <Row>
          <span className="text-muted-foreground">
            File engine Business aur Business Pro ke saath aata hai.
          </span>
        </Row>
      ) : (
        <div className="mt-ax-4">
          <input
            ref={input}
            type="file"
            multiple
            className="sr-only"
            onChange={(e) => {
              const files = Array.from(e.target.files ?? []);
              e.target.value = "";
              if (files.length) void add(files);
            }}
          />
          <button
            type="button"
            onClick={() => input.current?.click()}
            className="inline-flex items-center gap-2 rounded-md border border-border/60 px-ax-4 py-2 text-sm font-semibold text-foreground hover:border-primary"
          >
            <UploadCloud className="size-4" aria-hidden="true" /> Choose files
          </button>
          <span className="ml-ax-3 text-sm text-steel">
            {online ? "Connection live" : "Connection gone — transfers paused, nothing lost"}
          </span>
        </div>
      )}

      {items.length > 0 && (
        <ul className="mt-ax-4 space-y-ax-3">
          {items.map((t) => (
            <TransferRow key={t.key} t={t} onPause={() => pause(t.key)} onResume={() => resume(t.key)} />
          ))}
        </ul>
      )}

      {(engine.data?.transfers.length ?? 0) > 0 && (
        <>
          <h3 className="mt-ax-6 font-semibold text-foreground">Transfers on other devices</h3>
          <ul className="mt-2 space-y-1 text-sm text-muted-foreground">
            {engine.data!.transfers.map((t) => (
              <li key={t.transfer_id} className="flex flex-wrap gap-2">
                <span className="text-foreground">{t.name ?? "file"}</span>
                <span>
                  {bytesLabel(t.bytes_done)} / {bytesLabel(t.bytes_total)}
                </span>
                <span>{t.state}</span>
                <span className="text-steel">{new Date(t.last_seen_at).toLocaleString()}</span>
              </li>
            ))}
          </ul>
        </>
      )}

      <h3 className="mt-ax-6 flex items-center gap-2 font-semibold text-foreground">
        <History className="size-4" aria-hidden="true" /> Stored files & versions
      </h3>
      {(engine.data?.files.length ?? 0) === 0 ? (
        <p className="mt-2 text-sm text-steel">Koi file store nahi hui — pehla transfer yahan aayega.</p>
      ) : (
        <ul className="mt-2 space-y-2">
          {engine.data!.files.map((f) => (
            <li key={f.file_id} className="rounded-lg border border-border/60 p-ax-3">
              <button
                type="button"
                className="flex w-full flex-wrap items-baseline gap-2 text-left"
                onClick={() => setOpenFile(openFile === f.file_id ? null : f.file_id)}
                aria-expanded={openFile === f.file_id}
              >
                <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{f.name}</span>
                <span className="text-sm text-foreground">{bytesLabel(f.bytes)}</span>
                <span className="text-sm text-steel">
                  v{f.version} · {f.versions} kept
                </span>
              </button>
              {openFile === f.file_id && <VersionList fileId={f.file_id} />}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export default FileTransfers;
