import { Link } from "@tanstack/react-router";
import { ChevronDown, FileText, Link2, X } from "lucide-react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useEffect, useRef, useState } from "react";

import { Button } from "@/components/ui/button";
import { fmtBytes } from "@/lib/mail-attachments-core";
import { referenceLine, type FileFamily, type FileHit, type FileVersion } from "@/lib/outcomes";

const when = (iso: string | null) =>
  iso
    ? new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })
    : "";
const who = (v: FileVersion) =>
  v.direction === "out" ? "You" : v.by_name || v.by_address || "Unknown";

function change(v: FileVersion): string {
  if (v.same_as_older === true) return "same content as the version before";
  if (v.same_as_older === false) {
    const d = v.size_delta ?? 0;
    return d === 0
      ? "content changed, same size"
      : `content changed, ${d > 0 ? "+" : "−"}${fmtBytes(Math.abs(d))}`;
  }
  return v.version === 1 ? "first version" : "";
}

/**
 * "the latest CRM sheet" likhte hi: asli file ka sach (server E99) — kaun ne bheji, kis thread mein, kitne versions, har version mein kya badla
 * (content wahi/naya + size). Cell-level diff NAHI (file andar se nahi kholi jati). User ki marzi: reference line email mein daalo ya band karo.
 */
export function FileContextCard({
  hits,
  dismissed,
  onDismiss,
  onInsert,
}: {
  hits: FileHit[];
  dismissed: Set<string>;
  onDismiss: (q: string) => void;
  onInsert: (line: string) => void;
}) {
  const reduce = useReducedMotion();
  const [open, setOpen] = useState<string | null>(null);
  const shown = hits.filter((h) => !dismissed.has(h.query));
  const wrap = useRef<HTMLDivElement>(null);
  const count = shown.length;
  // Chhoti screen/overlay mein card neeche scroll ke andar chhup jata tha: naya card aaye to nazar ke andar laao.
  useEffect(() => {
    if (count > 0) wrap.current?.scrollIntoView({ block: "nearest", behavior: "smooth" });
  }, [count]);
  if (count === 0) return null;
  const fade = reduce
    ? {}
    : {
        initial: { opacity: 0, y: 4 },
        animate: { opacity: 1, y: 0 },
        exit: { opacity: 0, y: -4 },
        transition: { duration: 0.15 },
      };

  return (
    <div ref={wrap} className="flex flex-col gap-2" aria-live="polite" data-testid="file-context">
      <AnimatePresence initial={false}>
        {shown.map((h) => {
          const fam: FileFamily = h.files[0]!;
          const latest = fam.versions[0]!;
          const expanded = open === h.query;
          return (
            <motion.div
              key={h.query}
              {...fade}
              className="ax-plane flex flex-col gap-2 rounded-xl p-ax-3"
              data-testid="file-card"
            >
              <div className="flex items-start gap-2">
                <FileText className="mt-0.5 size-4 shrink-0 text-primary" aria-hidden />
                <div className="min-w-0 flex-1">
                  <p className="ax-label text-foreground">
                    {h.latest ? "Latest" : "Found"}:{" "}
                    <span className="font-medium normal-case">{latest.filename}</span>
                  </p>
                  <p className="truncate text-xs text-muted-foreground">
                    v{latest.version} of {fam.total_versions} · {fmtBytes(latest.size_bytes)} ·{" "}
                    {who(latest)}
                    {latest.sent_at ? ` · ${when(latest.sent_at)}` : ""}
                    {latest.thread_subject ? ` · “${latest.thread_subject}”` : ""}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => onDismiss(h.query)}
                  aria-label="Hide this file card"
                  className="ax-press rounded p-1 text-muted-foreground hover:text-foreground"
                >
                  <X className="size-4" />
                </button>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <Button
                  type="button"
                  size="sm"
                  className="ax-press"
                  onClick={() => onInsert(referenceLine(fam, fmtBytes))}
                >
                  <Link2 className="size-4" aria-hidden />
                  Add reference line
                </Button>
                {latest.thread_id ? (
                  <Button asChild variant="secondary" size="sm" className="ax-press">
                    <Link
                      to="/app/mail/$folder/$threadId"
                      params={{
                        folder: latest.direction === "out" ? "sent" : "inbox",
                        threadId: latest.thread_id,
                      }}
                      target="_blank"
                    >
                      Open the conversation
                    </Link>
                  </Button>
                ) : null}
                {fam.versions.length > 1 ? (
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="ax-press"
                    aria-expanded={expanded}
                    onClick={() => setOpen(expanded ? null : h.query)}
                  >
                    {fam.total_versions} versions{" "}
                    <ChevronDown
                      className={`size-4 transition-transform ${expanded ? "rotate-180" : ""}`}
                      aria-hidden
                    />
                  </Button>
                ) : null}
              </div>
              {expanded ? (
                <ul
                  className="flex flex-col gap-1 border-t border-border pt-2 text-xs"
                  data-testid="file-versions"
                >
                  {fam.versions.map((v) => (
                    <li
                      key={v.id}
                      className="flex flex-wrap items-baseline gap-x-2 text-muted-foreground"
                    >
                      <span className="font-medium text-foreground">v{v.version}</span>
                      <span className="truncate">{v.filename}</span>
                      <span>{fmtBytes(v.size_bytes)}</span>
                      <span>
                        {who(v)}
                        {v.sent_at ? `, ${when(v.sent_at)}` : ""}
                      </span>
                      {change(v) ? <span className="text-foreground/80">— {change(v)}</span> : null}
                    </li>
                  ))}
                </ul>
              ) : null}
            </motion.div>
          );
        })}
      </AnimatePresence>
    </div>
  );
}
