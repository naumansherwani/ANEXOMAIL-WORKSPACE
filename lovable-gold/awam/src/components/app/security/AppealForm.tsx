import { FileText, Loader2, Paperclip, X } from "lucide-react";
import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { removeEvidence, uploadEvidence, useEvidenceLimits } from "@/lib/appeal-evidence";
import {
  anyUploading,
  DRAFT_KEY,
  EVIDENCE_ACCEPT,
  precheck,
  readyIds,
  statementState,
  type EvidenceItem,
} from "@/lib/appeal-evidence-core";
import { fmtBytes } from "@/lib/mail-attachments-core";

export type AppealSubmit = (
  statement: string,
  evidenceIds: string[],
) => Promise<{ ok: boolean; message?: string }>;

function readDraft(): string {
  try {
    return window.localStorage.getItem(DRAFT_KEY) ?? "";
  } catch {
    return "";
  }
}
function writeDraft(v: string) {
  try {
    if (v) window.localStorage.setItem(DRAFT_KEY, v);
    else window.localStorage.removeItem(DRAFT_KEY);
  } catch {
    /* storage blocked: draft just isn't kept */
  }
}

/**
 * E72 — appeal ka form: 20..20,000 characters (live ginti), draft browser mein bachta hai, aur saboot ki files
 * (screenshot / PDF / document; drag-drop ya button) jo Rust par stream hoti hain. Files pehle upload, phir appeal ke saath jud jati hain.
 */
export function AppealForm({
  onSubmit,
  pending,
  submitLabel = "File appeal",
  rows = 6,
  placeholder = "Why is this block wrong?",
  header,
}: {
  onSubmit: AppealSubmit;
  pending: boolean;
  submitLabel?: string;
  rows?: number;
  placeholder?: string;
  header?: ReactNode;
}) {
  const [text, setText] = useState(readDraft);
  const [items, setItems] = useState<EvidenceItem[]>([]);
  const [msg, setMsg] = useState<string | null>(null);
  const [drag, setDrag] = useState(false);
  const input = useRef<HTMLInputElement>(null);
  const limitsQ = useEvidenceLimits();
  const limits = limitsQ.data;
  const canAttach = !!limits?.eligible && limits.storage_ready !== false;
  const st = statementState(text, limits?.statement_min, limits?.statement_max);

  useEffect(() => writeDraft(text), [text]);

  const patch = useCallback(
    (key: string, p: Partial<EvidenceItem>) =>
      setItems((cur) => cur.map((i) => (i.key === key ? { ...i, ...p } : i))),
    [],
  );

  const addFiles = (files: FileList | File[]) => {
    if (!limits) return;
    setMsg(null);
    let working = items;
    for (const file of Array.from(files)) {
      const why = precheck(file, working, limits);
      if (why) {
        setMsg(why);
        continue;
      }
      const key = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const item: EvidenceItem = {
        key,
        name: file.name,
        size: file.size,
        status: "uploading",
        progress: 0,
      };
      working = [...working, item];
      setItems(working);
      // ek ek karke: server par bhi ek user = ek waqt mein ek upload
      queue.current = queue.current.then(() =>
        uploadEvidence(file, { onProgress: (p) => patch(key, { progress: p }) })
          .then((r) =>
            patch(key, {
              status: "ready",
              progress: 100,
              id: r.id,
              deduped: r.deduped,
              scanned: r.scanned,
            }),
          )
          .catch((e: Error) => patch(key, { status: "error", error: e.message })),
      );
    }
  };
  const queue = useRef<Promise<void>>(Promise.resolve());

  const drop = (key: string, id?: string) => {
    setItems((cur) => cur.filter((i) => i.key !== key));
    if (id) void removeEvidence(id).catch(() => undefined);
  };

  const submit = async () => {
    setMsg(null);
    if (!st.ok)
      return setMsg(
        st.tooLong ? st.label : `Write at least ${limits?.statement_min ?? 20} characters.`,
      );
    if (anyUploading(items)) return setMsg("Wait for the files to finish uploading.");
    const r = await onSubmit(text.trim(), readyIds(items));
    if (r.ok) {
      setText("");
      writeDraft("");
      setItems([]);
      void limitsQ.refetch();
    } else if (r.message) setMsg(r.message);
  };

  return (
    <div className="space-y-ax-2">
      {header}
      <textarea
        value={text}
        onChange={(e) => setText(e.target.value)}
        rows={rows}
        aria-label={placeholder}
        placeholder={`${placeholder} (at least ${limits?.statement_min ?? 20} characters)`}
        className="w-full resize-y rounded-xl border border-border bg-transparent p-ax-3 text-xs text-foreground outline-none focus:border-cyan-accent/60"
      />
      <p
        className={`ax-caption ${st.tooLong ? "text-destructive" : "text-muted-foreground"}`}
        aria-live="polite"
        data-testid="appeal-count"
      >
        {st.label}
      </p>

      {canAttach ? (
        <div
          onDragOver={(e) => {
            e.preventDefault();
            setDrag(true);
          }}
          onDragLeave={() => setDrag(false)}
          onDrop={(e) => {
            e.preventDefault();
            setDrag(false);
            addFiles(e.dataTransfer.files);
          }}
          className={`rounded-xl border border-dashed p-ax-3 ${drag ? "border-cyan-accent/70 bg-cyan-accent/5" : "border-border"}`}
        >
          <div className="flex flex-wrap items-center gap-2">
            <Button
              type="button"
              size="sm"
              variant="ghost"
              onClick={() => input.current?.click()}
              disabled={items.length >= (limits?.max_files ?? 5)}
            >
              <Paperclip className="size-3.5" />
              Attach evidence
            </Button>
            <span className="ax-caption text-muted-foreground">
              Screenshots, PDF, text, email or Office files · up to {limits?.max_files} files,{" "}
              {fmtBytes(limits?.max_file_bytes ?? 0)} each
            </span>
          </div>
          <input
            ref={input}
            type="file"
            multiple
            hidden
            accept={EVIDENCE_ACCEPT}
            onChange={(e) => {
              if (e.target.files) addFiles(e.target.files);
              e.target.value = "";
            }}
          />
          {items.length > 0 && (
            <ul className="mt-ax-2 space-y-1.5" data-testid="appeal-files">
              {items.map((i) => (
                <li key={i.key} className="flex items-center gap-2 text-xs">
                  {i.status === "uploading" ? (
                    <Loader2 className="size-3.5 animate-spin" aria-hidden="true" />
                  ) : (
                    <FileText className="size-3.5" aria-hidden="true" />
                  )}
                  <span className="min-w-0 flex-1 truncate text-foreground">{i.name}</span>
                  <span
                    className={i.status === "error" ? "text-destructive" : "text-muted-foreground"}
                  >
                    {i.status === "uploading"
                      ? `${i.progress}%`
                      : i.status === "error"
                        ? i.error
                        : fmtBytes(i.size)}
                  </span>
                  <button
                    type="button"
                    aria-label={`Remove ${i.name}`}
                    className="text-muted-foreground hover:text-foreground"
                    onClick={() => drop(i.key, i.id)}
                  >
                    <X className="size-3.5" />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      ) : limits && limits.eligible && limits.storage_ready === false ? (
        <p className="ax-caption text-muted-foreground">
          File attachments are unavailable right now. You can still send your appeal as text.
        </p>
      ) : null}

      {msg && (
        <p role="alert" className="ax-caption text-destructive">
          {msg}
        </p>
      )}
      <Button
        type="button"
        size="sm"
        disabled={pending || !st.ok || anyUploading(items)}
        onClick={() => void submit()}
      >
        {submitLabel}
      </Button>
    </div>
  );
}
