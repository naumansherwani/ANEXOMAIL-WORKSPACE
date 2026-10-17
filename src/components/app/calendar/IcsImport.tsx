/**
 * Calendar → "Import .ics" (switching from Google / Zoho / Outlook / Apple Calendar).
 * The file is read in the browser (src/lib/ics.ts); only events the person confirms are created, one by one, through the same
 * calendar.create route a hand-made meeting uses. Every skip is counted and shown — nothing disappears silently.
 */
import { useQueryClient } from "@tanstack/react-query";
import { CalendarPlus, Loader2, Upload, X } from "lucide-react";
import { useMemo, useRef, useState } from "react";

import { Button } from "@/components/ui/button";
import {
  IMPORT_BACK_DAYS,
  IMPORT_FORWARD_DAYS,
  importKey,
  parseIcs,
  type IcsEvent,
  type IcsPlan,
} from "@/lib/ics";
import { notify } from "@/lib/notify";
import { rpcOrRest } from "@/lib/rpc";

export type LoadedIcs = IcsPlan & { fileName: string };

const STORE = "ax:ics-imported";
const MAX_FILE_BYTES = 8 * 1024 * 1024;

// "Already imported" memory lives only in this browser (storage can be blocked: everything is try/caught, worst case a
// second import of the same file adds the events again).
const readStore = (): Set<string> => {
  try {
    return new Set<string>(JSON.parse(window.localStorage.getItem(STORE) || "[]"));
  } catch {
    return new Set();
  }
};
const writeStore = (s: Set<string>) => {
  try {
    window.localStorage.setItem(STORE, JSON.stringify([...s].slice(-5000)));
  } catch {
    /* blocked storage: nothing to do */
  }
};

export function IcsPickButton({ onLoaded }: { onLoaded: (p: LoadedIcs) => void }) {
  const ref = useRef<HTMLInputElement>(null);
  return (
    <>
      <button
        type="button"
        onClick={() => ref.current?.click()}
        aria-label="Import a calendar file (.ics)"
        title="Import .ics — from Google, Zoho, Outlook or Apple Calendar"
        className="ax-press ax-focus ax-tap ax-caption inline-flex items-center justify-center rounded-md border border-border px-1.5 py-1 font-semibold text-muted-foreground"
      >
        <Upload className="size-3.5" aria-hidden="true" />
      </button>
      <input
        ref={ref}
        type="file"
        accept=".ics,text/calendar"
        className="sr-only"
        tabIndex={-1}
        aria-hidden="true"
        onChange={async (e) => {
          const file = e.target.files?.[0];
          e.target.value = "";
          if (!file) return;
          if (file.size > MAX_FILE_BYTES) {
            notify.failed("That file is too big", {
              description: "A calendar export is rarely over 8 MB — is this the right file?",
            });
            return;
          }
          onLoaded({ ...parseIcs(await file.text()), fileName: file.name });
        }}
      />
    </>
  );
}

export function IcsImportPanel({
  plan,
  onClose,
  onShow,
}: {
  plan: LoadedIcs;
  onClose: () => void;
  /** Jump the calendar to the earliest imported event so the person sees the result straight away. */
  onShow: (firstEvent: Date) => void;
}) {
  const qc = useQueryClient();
  const known = useMemo(readStore, [plan]);
  const todo = useMemo(() => plan.events.filter((e) => !known.has(importKey(e))), [plan, known]);
  const already = plan.events.length - todo.length;
  const [withPeople, setWithPeople] = useState(false);
  const [running, setRunning] = useState(false);
  const [finished, setFinished] = useState(false);
  const [done, setDone] = useState(0);
  const [added, setAdded] = useState(0);
  const [failed, setFailed] = useState(0);
  const [firstError, setFirstError] = useState("");
  const [first, setFirst] = useState<Date | null>(null);
  const cancelled = useRef(false);
  const s = plan.stats;

  const payload = (e: IcsEvent) => ({
    title: e.title,
    starts_at: e.starts_at,
    duration_minutes: e.duration_minutes,
    attendees: withPeople ? e.attendees : [],
    agenda: e.agenda,
    ...(e.location ? { location: e.location } : {}),
    ...(e.timezone ? { timezone: e.timezone } : {}),
  });

  const run = async () => {
    setRunning(true);
    setFinished(false);
    cancelled.current = false;
    let ok = 0;
    let bad = 0;
    let err = "";
    let earliest = Infinity;
    const store = readStore();
    const queue = [...todo];
    const worker = async () => {
      while (queue.length && !cancelled.current) {
        const e = queue.shift()!;
        const body = payload(e);
        try {
          await rpcOrRest("calendar.create", { path: "/api/calendar/events", method: "POST", body }, body);
          ok++;
          store.add(importKey(e));
          earliest = Math.min(earliest, Date.parse(e.starts_at));
        } catch (x) {
          bad++;
          err ||= x instanceof Error ? x.message : "Request failed";
        }
        setDone(ok + bad);
        setAdded(ok);
        setFailed(bad);
      }
    };
    await Promise.all([worker(), worker(), worker()]);
    writeStore(store);
    void qc.invalidateQueries({ queryKey: ["calendar"] });
    void qc.invalidateQueries({ queryKey: ["dashboard"] });
    setFirstError(err);
    setFirst(Number.isFinite(earliest) ? new Date(earliest) : null);
    setRunning(false);
    setFinished(true);
    if (ok) notify.done(`${ok} event${ok === 1 ? "" : "s"} imported`, `From ${plan.fileName}`);
  };

  const lines: string[] = [];
  if (s.seriesExpanded) lines.push(`${s.seriesExpanded} repeating series expanded over the next ${Math.round(IMPORT_FORWARD_DAYS / 30)} months`);
  if (s.seriesFirstOnly) lines.push(`${s.seriesFirstOnly} repeating rule${s.seriesFirstOnly === 1 ? "" : "s"} we can't read yet — first occurrence only`);
  if (s.allDaySkipped) lines.push(`${s.allDaySkipped} all-day event${s.allDaySkipped === 1 ? "" : "s"} skipped (not supported yet)`);
  if (s.cancelledSkipped) lines.push(`${s.cancelledSkipped} cancelled event${s.cancelledSkipped === 1 ? "" : "s"} skipped`);
  if (s.outsideWindow) lines.push(`${s.outsideWindow} older than ${IMPORT_BACK_DAYS} days or too far ahead — skipped`);
  if (s.unknownZone) lines.push(`${s.unknownZone} with a time zone we couldn't read — placed in your device's time zone`);
  if (already) lines.push(`${already} already imported from this browser — skipped`);
  if (s.capped) lines.push("Limited to the first 500 events — import again for the rest");

  return (
    <section
      role="region"
      aria-label="Import calendar file"
      className="border-b border-border bg-secondary/40 px-ax-3 py-ax-3"
    >
      <div className="flex items-start gap-2">
        <CalendarPlus className="mt-0.5 size-4 shrink-0 text-cyan-accent" aria-hidden="true" />
        <div className="min-w-0 flex-1">
          <p className="ax-label truncate text-foreground" title={plan.fileName}>
            {plan.fileName}
          </p>
          <p className="ax-caption mt-0.5" aria-live="polite">
            {s.found === 0
              ? "No events found — is this a calendar (.ics) file?"
              : finished
                ? `Added ${added}${failed ? ` · ${failed} failed` : ""}.`
                : running
                  ? `Importing ${done} of ${todo.length}…`
                  : `${s.found} event${s.found === 1 ? "" : "s"} found · ${todo.length} will be added`}
          </p>
        </div>
        <button
          type="button"
          onClick={() => {
            cancelled.current = true;
            onClose();
          }}
          aria-label="Close import"
          className="ax-press ax-focus ax-tap inline-flex items-center justify-center rounded-md p-1 text-muted-foreground"
        >
          <X className="size-4" aria-hidden="true" />
        </button>
      </div>

      {running && (
        <div
          role="progressbar"
          aria-valuemin={0}
          aria-valuemax={todo.length}
          aria-valuenow={done}
          aria-label="Import progress"
          className="mt-2 h-1.5 overflow-hidden rounded-full bg-border"
        >
          <div
            className="h-full rounded-full bg-cyan-accent transition-[width]"
            style={{ width: `${todo.length ? Math.round((done / todo.length) * 100) : 0}%` }}
          />
        </div>
      )}

      {!running && !finished && s.found > 0 && (
        <>
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
          <label className="ax-tap mt-2 flex items-start gap-2 text-[12px] text-foreground">
            <input
              type="checkbox"
              checked={withPeople}
              onChange={(e) => setWithPeople(e.target.checked)}
              className="mt-0.5 size-4 shrink-0 accent-[var(--cyan-accent)]"
            />
            <span>
              Also save who was invited
              <span className="ax-caption block">Off by default — events are created for you alone.</span>
            </span>
          </label>
          <div className="mt-3 flex flex-wrap gap-2">
            <Button size="sm" onClick={() => void run()} disabled={todo.length === 0}>
              <Upload className="size-3.5" aria-hidden="true" />
              Import {todo.length} event{todo.length === 1 ? "" : "s"}
            </Button>
            <Button size="sm" variant="outline" onClick={onClose}>
              Cancel
            </Button>
          </div>
        </>
      )}

      {running && (
        <div className="mt-3 flex items-center gap-2">
          <Loader2 className="size-3.5 animate-spin text-muted-foreground" aria-hidden="true" />
          <Button
            size="sm"
            variant="outline"
            onClick={() => {
              cancelled.current = true;
            }}
          >
            Stop after this one
          </Button>
        </div>
      )}

      {finished && (
        <div className="mt-3 space-y-2">
          {failed > 0 && (
            <p className="ax-caption text-destructive">
              {failed} could not be added{firstError ? ` — ${firstError}` : ""}. Pick the same file again to retry only those.
            </p>
          )}
          <div className="flex flex-wrap gap-2">
            {first && (
              <Button
                size="sm"
                onClick={() => {
                  onShow(first);
                  onClose();
                }}
              >
                Show on calendar
              </Button>
            )}
            <Button size="sm" variant={first ? "outline" : "default"} onClick={onClose}>
              Done
            </Button>
          </div>
        </div>
      )}
    </section>
  );
}
