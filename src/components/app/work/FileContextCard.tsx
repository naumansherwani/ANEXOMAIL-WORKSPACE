import { FileStack, GitCompare, Link2, Network, ShieldAlert } from "lucide-react";
import { useState } from "react";

import { StateBlock } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  type FileLinkObject,
  useFileContext,
  useFileDuplicates,
  useFileGraph,
  useFileLink,
  useFileStale,
  useFileUnlink,
  useVersionDiff,
} from "@/lib/chat-file-context";
import { bytesLabel, useFileEngine, useFileVersions } from "@/lib/chat-files";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

const stamp = (iso: string | null | undefined) =>
  iso ? `${new Date(iso).toISOString().slice(0, 19).replace("T", " ")} UTC` : "—";

const OBJECTS: FileLinkObject[] = [
  "work_item",
  "decision",
  "promise",
  "mail_thread",
  "message",
  "person",
  "company",
];

/**
 * PHASE 31 — a file with its whole story attached.
 *
 * Who sent it, in which conversation, with the sealed hash, every step it
 * passed through, what work it belongs to, whether the same bytes already
 * exist elsewhere, and whether a later decision has left this copy behind.
 * Links are made by people with a written reason — nothing is guessed.
 */
export function FileContextCard() {
  const engine = useFileEngine();
  const files = engine.data?.files ?? [];
  const [picked, setPicked] = useState<string | null>(null);
  const fileId = picked ?? files[0]?.file_id ?? null;

  const card = useFileContext(fileId);
  const dupes = useFileDuplicates(fileId);
  const stale = useFileStale(fileId);
  const versions = useFileVersions(fileId);
  const [showGraph, setShowGraph] = useState(false);
  const graph = useFileGraph(fileId, showGraph);

  const vs = versions.data?.versions ?? [];
  const [from, setFrom] = useState<number | null>(null);
  const [to, setTo] = useState<number | null>(null);
  const diff = useVersionDiff(fileId, from, to);

  const link = useFileLink();
  const unlink = useFileUnlink();
  const [objectType, setObjectType] = useState<FileLinkObject>("work_item");
  const [objectId, setObjectId] = useState("");
  const [reason, setReason] = useState("");

  const notEntitled = card.data?.allowed === false;

  const addLink = () => {
    if (!fileId || objectId.trim().length < 4 || reason.trim().length < 8) return;
    link.mutate(
      { file_id: fileId, object_type: objectType, object_id: objectId.trim(), reason: reason.trim() },
      {
        onSuccess: (r) =>
          r.ok
            ? (setObjectId(""), setReason(""), notify.done("Linked", "The reason is recorded."))
            : notify.failed("Not linked", { description: r.reason ?? "" }),
        onError: (e) => notify.failed("Not linked", { description: e.message }),
      },
    );
  };

  return (
    <section className="space-y-ax-4">
      <div>
        <h2 className="ax-heading flex items-center gap-2 text-foreground">
          <FileStack className="size-4" aria-hidden="true" /> File context
        </h2>
        <p className="ax-caption text-muted-foreground">
          Where a file came from, what it belongs to, and whether it is still the current one.
        </p>
      </div>

      {notEntitled ? (
        <StateBlock
          tone="quiet"
          title="Included from Business upwards"
          body="File context, duplicate detection and stale-file warnings are part of the Business plan and above."
        />
      ) : files.length === 0 ? (
        <StateBlock
          tone="quiet"
          title="No files yet"
          body="Send a file in a conversation and its full story appears here."
        />
      ) : (
        <>
          <div className="flex flex-wrap gap-1.5">
            {files.slice(0, 12).map((f) => (
              <button
                key={f.file_id}
                type="button"
                onClick={() => {
                  setPicked(f.file_id);
                  setFrom(null);
                  setTo(null);
                }}
                className={cn(
                  "ax-press ax-caption max-w-[16rem] truncate rounded-full border px-2.5 py-1",
                  fileId === f.file_id
                    ? "border-cyan-accent/50 bg-secondary text-foreground"
                    : "border-border text-muted-foreground",
                )}
              >
                {f.name}
              </button>
            ))}
          </div>

          <div className="ax-plane space-y-ax-3 rounded-xl p-ax-4">
            <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
              <p className="text-sm font-semibold text-foreground">
                {card.data?.file?.name ?? "—"}
              </p>
              <p className="ax-caption text-steel">
                version {card.data?.file?.current_version ?? "—"} ·{" "}
                {bytesLabel(card.data?.file?.latest_bytes ?? 0)}
              </p>
            </div>
            <dl className="grid gap-ax-2 text-xs sm:grid-cols-2">
              <div>
                <dt className="ax-caption text-steel">Sent by</dt>
                <dd className="text-muted-foreground">
                  {card.data?.uploader
                    ? `${card.data.uploader.user_id} · ${stamp(card.data.uploader.at)}`
                    : "Not recorded"}
                </dd>
              </div>
              <div>
                <dt className="ax-caption text-steel">Conversation</dt>
                <dd className="text-muted-foreground">
                  {card.data?.conversation?.title ?? card.data?.conversation?.id ?? "Not recorded"}
                </dd>
              </div>
              <div className="sm:col-span-2">
                <dt className="ax-caption text-steel">Sealed hash</dt>
                <dd className="truncate font-mono text-[11px] text-muted-foreground">
                  {card.data?.uploader?.sha256 ?? "Not sealed"}
                </dd>
              </div>
            </dl>

            <div>
              <p className="ax-caption text-steel">Steps carried out</p>
              <ul className="mt-1 flex flex-wrap gap-1.5">
                {(card.data?.evidence ?? []).length === 0 ? (
                  <li className="ax-caption text-muted-foreground">Nothing recorded yet.</li>
                ) : (
                  card.data!.evidence!.map((e, i) => (
                    <li
                      key={`${e.state}-${i}`}
                      className="ax-caption rounded-full border border-border px-2 py-0.5 text-muted-foreground"
                    >
                      {e.state} · {stamp(e.at)}
                    </li>
                  ))
                )}
              </ul>
            </div>

            {(card.data?.related_work ?? []).length > 0 && (
              <div>
                <p className="ax-caption text-steel">Work this file belongs to</p>
                <ul className="mt-1 space-y-1 text-xs text-muted-foreground">
                  {card.data!.related_work!.map((w) => (
                    <li key={w.work_id}>
                      {w.kind} · {w.title} · {w.status}
                      {w.due_at ? ` · due ${stamp(w.due_at)}` : ""}
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>

          {(stale.data?.flags ?? []).length > 0 && (
            <div className="ax-plane space-y-ax-2 rounded-xl border-amber-500/30 p-ax-4">
              <p className="ax-caption flex items-center gap-2 text-amber-400">
                <ShieldAlert className="size-3.5" aria-hidden="true" /> A later decision may have
                moved past this copy
              </p>
              <ul className="space-y-1 text-xs text-muted-foreground">
                {stale.data!.flags!.map((f) => (
                  <li key={f.decision_id}>
                    {f.decision_title} decided {stamp(f.decided_at)} · this file version{" "}
                    {f.file_version} is from {stamp(f.file_version_at)} · linked because “
                    {f.evidence.link_reason}”
                  </li>
                ))}
              </ul>
            </div>
          )}

          {(dupes.data?.duplicates ?? []).length > 0 && (
            <div className="ax-plane space-y-ax-2 rounded-xl p-ax-4">
              <p className="ax-caption text-steel">
                Same bytes elsewhere (matched by hash) · pool saving{" "}
                {bytesLabel(dupes.data?.pool_saving_bytes ?? 0)}
              </p>
              <ul className="space-y-1 text-xs text-muted-foreground">
                {dupes.data!.duplicates!.map((d) => (
                  <li key={`${d.file_id}-${d.version}`}>
                    {d.name} · version {d.version} · {bytesLabel(d.bytes)} · {stamp(d.uploaded_at)}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {vs.length > 1 && (
            <div className="ax-plane space-y-ax-2 rounded-xl p-ax-4">
              <p className="ax-caption flex items-center gap-2 text-steel">
                <GitCompare className="size-3.5" aria-hidden="true" /> Compare two versions
              </p>
              <div className="flex flex-wrap items-center gap-2">
                {vs.slice(0, 8).map((v) => (
                  <button
                    key={v.version}
                    type="button"
                    onClick={() => (from == null ? setFrom(v.version) : setTo(v.version))}
                    className={cn(
                      "ax-press ax-caption rounded-full border px-2 py-0.5",
                      from === v.version || to === v.version
                        ? "border-cyan-accent/50 bg-secondary text-foreground"
                        : "border-border text-muted-foreground",
                    )}
                  >
                    v{v.version}
                  </button>
                ))}
                {(from != null || to != null) && (
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => {
                      setFrom(null);
                      setTo(null);
                    }}
                  >
                    Clear
                  </Button>
                )}
              </div>
              {diff.data && (
                <div className="text-xs text-muted-foreground">
                  {diff.data.diff_available === false ? (
                    <p>{diff.data.reason ?? "No text captured for these versions."}</p>
                  ) : (
                    <>
                      <p className="ax-caption text-steel">
                        line comparison · unchanged {diff.data.unchanged_lines ?? 0}
                        {diff.data.truncated ? ` · showing first ${diff.data.line_cap}` : ""}
                      </p>
                      <ul className="mt-1 space-y-0.5 font-mono text-[11px]">
                        {(diff.data.added ?? []).map((l, i) => (
                          <li key={`a${i}`} className="text-emerald-400">
                            + {l}
                          </li>
                        ))}
                        {(diff.data.removed ?? []).map((l, i) => (
                          <li key={`r${i}`} className="text-red-400">
                            − {l}
                          </li>
                        ))}
                      </ul>
                    </>
                  )}
                </div>
              )}
            </div>
          )}

          <div className="ax-plane space-y-ax-2 rounded-xl p-ax-4">
            <p className="ax-caption flex items-center gap-2 text-steel">
              <Link2 className="size-3.5" aria-hidden="true" /> Links made by people
            </p>
            <ul className="space-y-1.5 text-xs text-muted-foreground">
              {(card.data?.links ?? []).length === 0 ? (
                <li>No links yet.</li>
              ) : (
                card.data!.links!.map((l) => (
                  <li key={l.id} className="flex flex-wrap items-center gap-2">
                    <span>
                      {l.object_type} · {l.label ?? l.object_id} · “{l.reason}” ·{" "}
                      {stamp(l.linked_at)}
                    </span>
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => {
                        const why = window.prompt("Why is this link being removed? (8+ characters)");
                        if (!why || why.trim().length < 8) return;
                        unlink.mutate(
                          { link_id: l.id, reason: why.trim() },
                          {
                            onSuccess: (r) =>
                              r.ok
                                ? notify.done("Link removed", "The reason is recorded.")
                                : notify.failed("Not removed", { description: r.reason ?? "" }),
                            onError: (e) => notify.failed("Not removed", { description: e.message }),
                          },
                        );
                      }}
                    >
                      Remove
                    </Button>
                  </li>
                ))
              )}
            </ul>
            <div className="flex flex-wrap items-center gap-2">
              <select
                value={objectType}
                onChange={(e) => setObjectType(e.target.value as FileLinkObject)}
                className="h-8 rounded-md border border-border bg-background px-2 text-xs text-foreground"
              >
                {OBJECTS.map((o) => (
                  <option key={o} value={o}>
                    {o}
                  </option>
                ))}
              </select>
              <Input
                value={objectId}
                onChange={(e) => setObjectId(e.target.value)}
                placeholder="What it belongs to (id)"
                className="h-8 max-w-[16rem] text-xs"
              />
              <Input
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder="Why (8+ characters)"
                className="h-8 max-w-[18rem] text-xs"
              />
              <Button
                size="sm"
                variant="outline"
                disabled={link.isPending || objectId.trim().length < 4 || reason.trim().length < 8}
                onClick={addLink}
              >
                Link
              </Button>
            </div>
          </div>

          <div>
            <Button size="sm" variant="outline" onClick={() => setShowGraph((v) => !v)}>
              <Network className="size-3.5" />
              {showGraph ? "Hide connections" : "Show connections"}
            </Button>
            {showGraph &&
              (graph.data?.allowed === false ? (
                <p className="ax-caption mt-ax-2 text-steel">
                  The connections map is part of Business Pro and the AI Business plans.
                </p>
              ) : (
                <ul className="mt-ax-2 space-y-1 text-xs text-muted-foreground">
                  {(graph.data?.edges ?? []).map((e, i) => (
                    <li key={i}>
                      {e.kind} → {e.to}
                      {e.reason ? ` · “${e.reason}”` : ""}
                      {e.source ? ` · from ${e.source}` : ""}
                    </li>
                  ))}
                  {(graph.data?.edges ?? []).length === 0 && <li>No recorded connections.</li>}
                </ul>
              ))}
          </div>
        </>
      )}
    </section>
  );
}
