import { Check, Copy, Link2, Plus, Trash2, X } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Sheet, SheetContent, SheetDescription, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import {
  allZones,
  fmtClock,
  fmtDay,
  localZone,
  minutesLabel,
  useBookingList,
  useBookingPage,
  useDeleteBookingPage,
  useHostCancel,
  useSaveBookingPage,
  zoneLabel,
  type HostBooking,
  type HostPage,
} from "@/lib/booking";
import { useCalPrefs } from "@/lib/calprefs";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

const LENGTHS = [15, 20, 30, 45, 60, 90];
const BUFFERS = [0, 5, 10, 15, 30, 60];
const NOTICE: [number, string][] = [
  [0, "No notice"],
  [60, "1 hour"],
  [240, "4 hours"],
  [720, "12 hours"],
  [1440, "1 day"],
  [2880, "2 days"],
  [10080, "1 week"],
];
const HORIZON = [7, 14, 30, 60, 90, 180];

const field =
  "ax-focus ax-tap h-9 w-full rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs";

/**
 * "Booking page" — a public link (anexomail.com/book/<name>) where anyone can book a free time with you.
 * Free times come from your Calendar settings (working hours, out of office) and your real calendar, so you are
 * never double-booked. Off until you switch it on.
 */
export function BookingButton({ className }: { className?: string }) {
  const [open, setOpen] = useState(false);
  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <button
          type="button"
          aria-label="Booking page"
          title="Booking page — let people book time with you"
          className={cn(
            "ax-press ax-focus ax-tap inline-flex items-center justify-center rounded-md border border-border px-1.5 py-1 text-muted-foreground",
            className,
          )}
        >
          <Link2 className="size-3.5" aria-hidden="true" />
        </button>
      </SheetTrigger>
      <SheetContent side="right" className="w-full gap-0 overflow-y-auto p-0 sm:max-w-[520px]">
        <SheetTitle className="sr-only">Booking page</SheetTitle>
        <SheetDescription className="sr-only">A public link where people book a free time with you</SheetDescription>
        {open && <Body />}
      </SheetContent>
    </Sheet>
  );
}

type Draft = {
  handle: string;
  title: string;
  host_name: string;
  description: string;
  durations: number[];
  buffer_min: number;
  min_notice_min: number;
  max_days: number;
  timezone: string;
  location: string;
  calendar_key: string;
  enabled: boolean;
};

function draftOf(p: HostPage | null, suggested: string): Draft {
  return {
    handle: p?.handle ?? suggested,
    title: p?.title ?? "Book a meeting",
    host_name: p?.host_name ?? "",
    description: p?.description ?? "",
    durations: p?.durations ?? [30],
    buffer_min: p?.buffer_min ?? 0,
    min_notice_min: p?.min_notice_min ?? 240,
    max_days: p?.max_days ?? 30,
    timezone: p?.timezone ?? localZone(),
    location: p?.location ?? "",
    calendar_key: p?.calendar_key ?? "",
    enabled: p?.enabled ?? false,
  };
}

function Body() {
  const q = useBookingPage();
  const prefs = useCalPrefs();
  const save = useSaveBookingPage();
  const del = useDeleteBookingPage();
  const [d, setD] = useState<Draft | null>(null);
  /** Konsa link khula hai: page id, "new" (abhi banaya ja raha), ya null = pehla. */
  const [activeId, setActiveId] = useState<string | "new" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (q.data && !d) setD(draftOf(q.data.page, q.data.suggested_handle));
  }, [q.data, d]);

  const zones = useMemo(() => allZones(d?.timezone), [d?.timezone]);
  const origin = typeof window === "undefined" ? "https://anexomail.com" : window.location.origin;

  if (q.isPending || (q.data && !d)) {
    return <p className="p-ax-4 text-sm text-muted-foreground" aria-busy="true">Opening…</p>;
  }
  if (q.error || !d) {
    const missing = q.error?.status === 501 || q.error?.status === 404;
    return (
      <div className="p-ax-4">
        <p className="text-sm font-semibold text-foreground">{missing ? "Booking pages are being installed" : "Could not open booking settings"}</p>
        <p className="mt-1 text-sm text-muted-foreground">
          {missing ? "This will work as soon as the update is switched on. Nothing is lost." : "Please try again in a minute."}
        </p>
        {!missing && (
          <Button size="sm" variant="outline" className="ax-tap mt-3" onClick={() => void q.refetch()}>
            Try again
          </Button>
        )}
      </div>
    );
  }

  const set = <K extends keyof Draft>(k: K, v: Draft[K]) => setD((x) => (x ? { ...x, [k]: v } : x));
  const link = `${origin}/book/${d.handle}`;
  const pages = q.data?.pages ?? (q.data?.page ? [q.data.page] : []);
  const saved = activeId === "new" ? null : (pages.find((x) => x.id === activeId) ?? pages[0] ?? null);
  const used = q.data?.links_used ?? pages.length;
  const limit = q.data?.links_limit ?? null;
  const atCap = limit !== null && used >= limit;
  const suggested = q.data?.suggested_handle ?? "";
  const pick = (pg: HostPage) => {
    setActiveId(pg.id);
    setD(draftOf(pg, suggested));
    setError(null);
  };
  const startNew = () => {
    setActiveId("new");
    setD(draftOf(null, `${suggested}-${pages.length + 1}`.slice(0, 30)));
    setError(null);
  };
  const dirty = JSON.stringify(d) !== JSON.stringify(draftOf(saved, activeId === "new" ? d.handle : suggested));
  const handleOk = /^[a-z0-9](?:[a-z0-9-]{1,28})[a-z0-9]$/.test(d.handle) && !d.handle.includes("--");
  const ready = handleOk && d.title.trim().length >= 2 && d.durations.length >= 1;

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(link);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      notify.info("Copy this link", link);
    }
  };

  const onSave = () => {
    setError(null);
    save.mutate(
      {
        ...(activeId === "new" ? { new: true } : saved ? { page_id: saved.id } : {}),
        handle: d.handle,
        title: d.title.trim(),
        host_name: d.host_name.trim(),
        description: d.description.trim() || null,
        durations: d.durations,
        buffer_min: d.buffer_min,
        min_notice_min: d.min_notice_min,
        max_days: d.max_days,
        timezone: d.timezone,
        location: d.location.trim() || null,
        calendar_key: d.calendar_key || null,
        enabled: d.enabled,
      },
      {
        onSuccess: (s) => {
          const all = s.pages ?? (s.page ? [s.page] : []);
          const now = all.find((x) => x.handle === d.handle) ?? all[0] ?? null;
          setActiveId(now?.id ?? null);
          setD(draftOf(now, s.suggested_handle));
          notify.done(d.enabled ? "Booking page is live" : "Saved — the page is off");
        },
        onError: (e) => setError(e.status === 501 ? "Booking pages are not switched on yet." : e.message),
      },
    );
  };

  const opts = (list: number[], cur: number) => (list.includes(cur) ? list : [...list, cur].sort((a, b) => a - b));

  return (
    <div className="space-y-ax-4 px-ax-4 py-ax-4">
      <p className="ax-eyebrow flex items-center gap-1.5">
        <Link2 className="size-3.5" aria-hidden="true" /> Booking page
      </p>

      <div className="space-y-1.5">
        <div className="flex flex-wrap items-center gap-1.5" role="tablist" aria-label="Your booking links">
          {pages.map((pg) => (
            <button
              key={pg.id}
              type="button"
              role="tab"
              aria-selected={saved?.id === pg.id}
              onClick={() => pick(pg)}
              className={cn(
                "ax-focus ax-tap max-w-[10rem] truncate rounded-md border px-2 py-1 text-xs",
                saved?.id === pg.id ? "border-[var(--cyan-accent)] text-foreground" : "border-border text-muted-foreground",
              )}
            >
              {pg.title || pg.handle}
            </button>
          ))}
          {activeId === "new" && <span className="rounded-md border border-dashed border-border px-2 py-1 text-xs text-foreground">New link</span>}
          <Button size="sm" variant="outline" className="ax-tap h-7 gap-1 px-2 text-xs" onClick={startNew} disabled={atCap || activeId === "new"}>
            <Plus className="size-3" aria-hidden="true" /> New link
          </Button>
        </div>
        <p className="ax-caption text-muted-foreground">
          {used} of {limit === null ? "unlimited" : limit} booking link{limit === 1 ? "" : "s"} used
          {atCap ? " — upgrade your plan for more." : "."}
        </p>
      </div>

      <label className="ax-tap flex items-start gap-2 text-[12px] text-foreground">
        <input
          type="checkbox"
          checked={d.enabled}
          onChange={(e) => set("enabled", e.target.checked)}
          className="mt-0.5 size-4 shrink-0 accent-[var(--cyan-accent)]"
        />
        <span>
          <span className="block font-semibold">Let people book time with me</span>
          <span className="ax-caption block text-muted-foreground">
            Visitors see only your free times, never what is in your calendar. Switch off any time.
          </span>
        </span>
      </label>

      <div className="space-y-1">
        <span className="ax-caption text-muted-foreground">Your link</span>
        <div className="flex gap-2">
          <div className="flex min-w-0 flex-1 items-center rounded-md border border-border bg-background px-2 text-xs text-muted-foreground">
            <span className="shrink-0">{origin.replace(/^https?:\/\//, "")}/book/</span>
            <input
              value={d.handle}
              onChange={(e) => set("handle", e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, ""))}
              aria-label="Page name"
              maxLength={30}
              className="ax-focus h-9 min-w-0 flex-1 bg-transparent text-base text-foreground outline-none sm:text-xs"
            />
          </div>
          <Button size="sm" variant="outline" className="ax-tap" onClick={() => void copy()} disabled={!handleOk}>
            {copied ? <Check className="size-4" aria-hidden="true" /> : <Copy className="size-4" aria-hidden="true" />}
            {copied ? "Copied" : "Copy"}
          </Button>
        </div>
        {!handleOk && <p className="ax-caption text-amber-400">3-30 letters, numbers or single hyphens.</p>}
      </div>

      <Input value={d.title} onChange={(e) => set("title", e.target.value)} placeholder="Page title" maxLength={100} className="h-9 text-base sm:text-xs" aria-label="Page title" />
      <Input value={d.host_name} onChange={(e) => set("host_name", e.target.value)} placeholder="Your name shown to visitors" maxLength={80} className="h-9 text-base sm:text-xs" aria-label="Your name" />
      <textarea
        value={d.description}
        onChange={(e) => set("description", e.target.value)}
        rows={3}
        maxLength={500}
        placeholder="What is this for? (optional)"
        aria-label="Description"
        className="ax-focus w-full resize-y rounded-md border border-border bg-transparent px-2 py-1.5 text-base text-foreground outline-none placeholder:text-steel sm:text-xs"
      />

      <div className="space-y-1">
        <span className="ax-caption text-muted-foreground">Meeting lengths (up to 5)</span>
        <div className="flex flex-wrap gap-2">
          {LENGTHS.map((m) => {
            const on = d.durations.includes(m);
            return (
              <button
                key={m}
                type="button"
                aria-pressed={on}
                onClick={() => {
                  const next = on ? d.durations.filter((x) => x !== m) : [...d.durations, m].sort((a, b) => a - b);
                  if (next.length >= 1 && next.length <= 5) set("durations", next);
                }}
                className={cn(
                  "ax-press ax-focus ax-tap rounded-full border px-3 py-1 text-xs font-semibold",
                  on ? "border-cyan-accent bg-secondary text-foreground" : "border-border text-muted-foreground",
                )}
              >
                {minutesLabel(m)}
              </button>
            );
          })}
        </div>
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <label className="space-y-1">
          <span className="ax-caption text-muted-foreground">Gap between meetings</span>
          <select value={d.buffer_min} onChange={(e) => set("buffer_min", Number(e.target.value))} className={field}>
            {opts(BUFFERS, d.buffer_min).map((m) => (
              <option key={m} value={m}>
                {m === 0 ? "None" : `${m} min`}
              </option>
            ))}
          </select>
        </label>
        <label className="space-y-1">
          <span className="ax-caption text-muted-foreground">Minimum notice</span>
          <select value={d.min_notice_min} onChange={(e) => set("min_notice_min", Number(e.target.value))} className={field}>
            {(NOTICE.some(([m]) => m === d.min_notice_min) ? NOTICE : [...NOTICE, [d.min_notice_min, minutesLabel(d.min_notice_min)] as [number, string]]).map(([m, l]) => (
              <option key={m} value={m}>
                {l}
              </option>
            ))}
          </select>
        </label>
        <label className="space-y-1">
          <span className="ax-caption text-muted-foreground">Book up to</span>
          <select value={d.max_days} onChange={(e) => set("max_days", Number(e.target.value))} className={field}>
            {opts(HORIZON, d.max_days).map((m) => (
              <option key={m} value={m}>
                {m} days ahead
              </option>
            ))}
          </select>
        </label>
      </div>

      <label className="block space-y-1">
        <span className="ax-caption text-muted-foreground">Your time zone (working hours are read in this zone)</span>
        <select value={d.timezone} onChange={(e) => set("timezone", e.target.value)} className={field}>
          {zones.map((z) => (
            <option key={z} value={z}>
              {zoneLabel(z)}
            </option>
          ))}
        </select>
      </label>

      <Input value={d.location} onChange={(e) => set("location", e.target.value)} placeholder="Location or video link (optional)" maxLength={200} className="h-9 text-base sm:text-xs" aria-label="Location" />

      {prefs.calendars.length > 1 && (
        <label className="block space-y-1">
          <span className="ax-caption text-muted-foreground">Put bookings in calendar</span>
          <select value={d.calendar_key} onChange={(e) => set("calendar_key", e.target.value)} className={field}>
            <option value="">{prefs.calendars[0]?.name}</option>
            {prefs.calendars.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </label>
      )}

      <p className="ax-caption text-muted-foreground">
        Free times follow your working hours and out-of-office days in Calendar settings, and skip anything already in your calendar.
      </p>

      {error && (
        <p role="alert" className="text-sm text-danger">
          {error}
        </p>
      )}
      <div className="flex items-center gap-2">
        <Button size="sm" className="ax-tap" disabled={!ready || !dirty || save.isPending} onClick={onSave}>
          {save.isPending ? "Saving…" : "Save"}
        </Button>
        {saved && pages.length > 0 && (
          <Button
            size="sm"
            variant="ghost"
            className="ax-tap gap-1 text-muted-foreground"
            disabled={del.isPending}
            onClick={() =>
              del.mutate(saved.id, {
                onSuccess: (s2) => {
                  const rest = s2.pages ?? (s2.page ? [s2.page] : []);
                  setActiveId(rest[0]?.id ?? null);
                  setD(draftOf(rest[0] ?? null, s2.suggested_handle));
                  notify.done("Booking link removed");
                },
                onError: (e) => setError(e.status === 409 ? "This link has upcoming bookings. Cancel them first." : e.message),
              })
            }
          >
            <Trash2 className="size-3.5" aria-hidden="true" /> Remove
          </Button>
        )}
        {saved?.enabled && !dirty && (
          <a
            href={`/book/${saved.handle}`}
            target="_blank"
            rel="noreferrer"
            className="ax-focus ax-tap ax-caption font-semibold text-cyan-accent underline-offset-2 hover:underline"
          >
            Open my page
          </a>
        )}
      </div>

      {saved && <Upcoming />}
    </div>
  );
}

function Upcoming() {
  const q = useBookingList();
  const cancel = useHostCancel();
  const [ask, setAsk] = useState<string | null>(null);
  const tz = localZone();
  const rows = q.data?.bookings ?? [];
  const now = Date.now();
  const upcoming = rows.filter((b) => b.status === "confirmed" && new Date(b.ends_at).getTime() > now).reverse();
  const past = rows.filter((b) => !upcoming.includes(b)).slice(0, 10);

  const row = (b: HostBooking, canCancel: boolean) => (
    <li key={b.id} className="space-y-1 rounded-lg border border-border px-3 py-2">
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <p className={cn("truncate text-sm font-semibold text-foreground", b.status === "cancelled" && "line-through opacity-60")}>{b.visitor_name}</p>
          <p className="ax-caption break-all text-muted-foreground">{b.visitor_email}</p>
          <p className="ax-caption tabular-nums text-muted-foreground">
            {fmtDay(b.starts_at, tz, { weekday: "short", day: "numeric", month: "short" })} · {fmtClock(b.starts_at, tz)}–{fmtClock(b.ends_at, tz)}
            {b.status === "cancelled" ? " · cancelled" : ""}
          </p>
          {b.note && <p className="ax-caption mt-1 break-words text-foreground">“{b.note}”</p>}
        </div>
        {canCancel &&
          (ask === b.id ? (
            <div className="flex shrink-0 gap-1">
              <Button
                size="sm"
                variant="destructive"
                className="ax-tap"
                disabled={cancel.isPending}
                onClick={() =>
                  cancel.mutate(b.id, {
                    onSuccess: () => {
                      setAsk(null);
                      notify.done("Booking cancelled", "The visitor was told.");
                    },
                    onError: (e) => notify.failed("Could not cancel", { description: e.message }),
                  })
                }
              >
                Cancel it
              </Button>
              <Button size="sm" variant="ghost" className="ax-tap" onClick={() => setAsk(null)} aria-label="Keep it">
                <X className="size-4" aria-hidden="true" />
              </Button>
            </div>
          ) : (
            <Button size="sm" variant="outline" className="ax-tap shrink-0" onClick={() => setAsk(b.id)}>
              Cancel
            </Button>
          ))}
      </div>
    </li>
  );

  return (
    <section className="space-y-2 border-t border-border pt-ax-4">
      <p className="ax-eyebrow">Bookings</p>
      {q.isPending ? (
        <p className="text-sm text-muted-foreground">Loading…</p>
      ) : upcoming.length === 0 && past.length === 0 ? (
        <p className="text-sm text-muted-foreground">No one has booked yet. Share your link to get started.</p>
      ) : (
        <>
          {upcoming.length > 0 && <ul className="space-y-2">{upcoming.map((b) => row(b, true))}</ul>}
          {past.length > 0 && (
            <>
              <p className="ax-caption pt-1 text-muted-foreground">Earlier</p>
              <ul className="space-y-2 opacity-80">{past.map((b) => row(b, false))}</ul>
            </>
          )}
        </>
      )}
    </section>
  );
}
