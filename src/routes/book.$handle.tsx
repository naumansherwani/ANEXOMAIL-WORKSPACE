import { useMutation, useQuery } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import { CalendarCheck, Clock, Globe, MapPin } from "lucide-react";
import { useMemo, useRef, useState } from "react";

import { SlotPicker } from "@/components/book/SlotPicker";
import { BrandMark } from "@/components/site/BrandMark";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { ApiError } from "@/lib/api";
import {
  allZones,
  bookSlot,
  fmtClock,
  fmtDay,
  localZone,
  minutesLabel,
  pageGet,
  zoneLabel,
  type Booked,
  type PublicPage,
} from "@/lib/booking";
import { cn } from "@/lib/utils";

/**
 * /book/<handle> — a person's public booking page. Public on purpose: the visitor needs no account.
 *
 * The engine decides which times are free and re-checks the chosen one when you press Confirm; the database refuses a
 * second booking of the same time. Opening this page never books anything.
 */
export const Route = createFileRoute("/book/$handle")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Book a meeting — ANEXOMAIL" },
      { name: "robots", content: "noindex, nofollow" },
      { name: "referrer", content: "no-referrer" },
    ],
  }),
  component: BookPage,
});

function BookPage() {
  const { handle } = Route.useParams();
  const page = useQuery<PublicPage, ApiError>({
    queryKey: ["booking", "page", handle],
    queryFn: () => pageGet(handle),
    retry: false,
    staleTime: 60_000,
  });

  return (
    <main className="min-h-[100dvh] bg-background px-4 py-8 pb-[max(2rem,env(safe-area-inset-bottom))] sm:px-6 sm:py-12">
      <div className="mx-auto w-full max-w-4xl">
        <BrandMark />
        <div className="mt-8">
          {page.isPending ? (
            <p className="text-sm text-muted-foreground" aria-busy="true">
              Opening the booking page…
            </p>
          ) : page.error ? (
            <div role="alert" className="mx-auto max-w-md rounded-xl border border-border bg-card p-5">
              <p className="text-base font-bold text-foreground">
                {page.error.status === 404 ? "This booking page is not available" : "Could not open the booking page"}
              </p>
              <p className="mt-1.5 text-sm text-muted-foreground">
                {page.error.status === 404
                  ? "The link may be mistyped, or the owner switched the page off."
                  : "Please try again in a minute. Nothing was booked."}
              </p>
              {page.error.status !== 404 && (
                <Button size="sm" variant="outline" className="ax-tap mt-4" onClick={() => void page.refetch()}>
                  Try again
                </Button>
              )}
            </div>
          ) : (
            <Booking page={page.data} />
          )}
        </div>
        <p className="mt-10 text-center text-[11px] text-muted-foreground">
          Scheduling by ANEXOMAIL · your details go to the host only
        </p>
      </div>
    </main>
  );
}

function Booking({ page }: { page: PublicPage }) {
  const [minutes, setMinutes] = useState(page.durations[0] ?? 30);
  const [tz, setTz] = useState(localZone());
  const [picked, setPicked] = useState<string | null>(null);
  const [version, setVersion] = useState(0);
  const [done, setDone] = useState<Booked | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const zones = useMemo(() => allZones(tz), [tz]);
  const formRef = useRef<HTMLDivElement | null>(null);

  if (done) return <Confirmed done={done} tz={tz} />;

  return (
    <div className="grid gap-6 md:grid-cols-[minmax(0,17rem)_minmax(0,1fr)]">
      <aside className="space-y-3 rounded-xl border border-border bg-card p-5 md:self-start">
        {page.host_name && <p className="ax-eyebrow">{page.host_name}</p>}
        <h1 className="text-xl font-extrabold tracking-tight text-foreground">{page.title}</h1>
        {page.description && <p className="whitespace-pre-line text-sm text-muted-foreground">{page.description}</p>}
        <ul className="space-y-2 text-sm text-foreground">
          <li className="flex items-center gap-2.5">
            <Clock className="size-4 shrink-0 text-steel" aria-hidden="true" />
            <span>{minutesLabel(minutes)}</span>
          </li>
          {page.location && (
            <li className="flex items-start gap-2.5">
              <MapPin className="mt-0.5 size-4 shrink-0 text-steel" aria-hidden="true" />
              <span className="min-w-0 break-words">{page.location}</span>
            </li>
          )}
        </ul>
        {page.durations.length > 1 && (
          <div role="group" aria-label="Meeting length" className="flex flex-wrap gap-2 pt-1">
            {page.durations.map((d) => (
              <button
                key={d}
                type="button"
                onClick={() => {
                  setMinutes(d);
                  setPicked(null);
                }}
                aria-pressed={minutes === d}
                className={cn(
                  "ax-press ax-focus ax-tap rounded-full border px-3 py-1.5 text-sm font-semibold",
                  minutes === d ? "border-cyan-accent bg-secondary text-foreground" : "border-border text-muted-foreground",
                )}
              >
                {minutesLabel(d)}
              </button>
            ))}
          </div>
        )}
      </aside>

      <section className="min-w-0 space-y-4 rounded-xl border border-border bg-card p-5">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h2 className="text-base font-bold text-foreground">Pick a time</h2>
          <label className="ax-caption flex min-w-0 items-center gap-1.5 text-muted-foreground">
            <Globe className="size-3.5 shrink-0" aria-hidden="true" />
            <span className="sr-only">Your time zone</span>
            <select
              value={tz}
              onChange={(e) => setTz(e.target.value)}
              className="ax-focus ax-tap min-w-0 max-w-[14rem] truncate rounded-md border border-border bg-background px-2 py-1 text-base text-foreground sm:text-xs"
            >
              {zones.map((z) => (
                <option key={z} value={z}>
                  {zoneLabel(z)}
                </option>
              ))}
            </select>
          </label>
        </div>

        {notice && (
          <p role="alert" className="rounded-lg border border-border bg-secondary px-3 py-2 text-sm text-foreground">
            {notice}
          </p>
        )}
        <SlotPicker
          handle={page.handle}
          minutes={minutes}
          tz={tz}
          maxDays={page.max_days}
          picked={picked}
          version={version}
          onPick={(s) => {
            setNotice(null);
            setPicked(s);
            window.setTimeout(() => formRef.current?.scrollIntoView({ behavior: "smooth", block: "nearest" }), 60);
          }}
        />

        <div ref={formRef}>
          {picked && (
            <Form
              page={page}
              minutes={minutes}
              tz={tz}
              start={picked}
              onChange={() => setPicked(null)}
              onTaken={(m) => {
                setNotice(m);
                setPicked(null);
                setVersion((v) => v + 1);
              }}
              onDone={setDone}
            />
          )}
        </div>
      </section>
    </div>
  );
}

function Form({
  page,
  minutes,
  tz,
  start,
  onChange,
  onTaken,
  onDone,
}: {
  page: PublicPage;
  minutes: number;
  tz: string;
  start: string;
  onChange: () => void;
  onTaken: (message: string) => void;
  onDone: (b: Booked) => void;
}) {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [note, setNote] = useState("");
  const [website, setWebsite] = useState(""); // honeypot — people never see it
  const [error, setError] = useState<string | null>(null);
  const end = new Date(new Date(start).getTime() + minutes * 60_000).toISOString();
  const valid = name.trim().length > 0 && /^[^@\s<>"]+@[^@\s<>"]+\.[^@\s<>"]{2,}$/.test(email.trim());

  const send = useMutation<Booked, ApiError, void>({
    mutationFn: () =>
      bookSlot({ handle: page.handle, start, minutes, name: name.trim(), email: email.trim(), tz, note: note.trim(), website }),
    onSuccess: onDone,
    onError: (e) => {
      setError(e.message);
      if (e.code === "taken" || e.status === 409) onTaken(e.message);
    },
  });

  return (
    <form
      className="mt-2 space-y-3 border-t border-border pt-4"
      onSubmit={(e) => {
        e.preventDefault();
        if (!valid || send.isPending) return;
        setError(null);
        send.mutate();
      }}
    >
      <div className="flex flex-wrap items-center justify-between gap-2 rounded-lg bg-secondary px-3 py-2">
        <p className="text-sm font-semibold text-foreground">
          {fmtDay(start, tz)} · {fmtClock(start, tz)}–{fmtClock(end, tz)}
        </p>
        <button type="button" onClick={onChange} className="ax-focus ax-caption font-semibold text-cyan-accent underline-offset-2 hover:underline">
          Change time
        </button>
      </div>
      <Input
        value={name}
        onChange={(e) => setName(e.target.value)}
        placeholder="Your name"
        autoComplete="name"
        maxLength={80}
        aria-label="Your name"
        className="h-11 text-base"
      />
      <Input
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Your e-mail"
        type="email"
        inputMode="email"
        autoComplete="email"
        maxLength={254}
        aria-label="Your e-mail"
        className="h-11 text-base"
      />
      <textarea
        value={note}
        onChange={(e) => setNote(e.target.value)}
        rows={3}
        maxLength={1000}
        placeholder="Anything the host should know? (optional)"
        aria-label="Note for the host"
        className="ax-focus w-full resize-y rounded-md border border-border bg-transparent px-3 py-2 text-base text-foreground outline-none placeholder:text-steel"
      />
      <input
        type="text"
        name="website"
        value={website}
        onChange={(e) => setWebsite(e.target.value)}
        tabIndex={-1}
        autoComplete="off"
        aria-hidden="true"
        className="absolute left-[-9999px] h-0 w-0 opacity-0"
      />
      {error && (
        <p role="alert" className="text-sm text-danger">
          {error}
        </p>
      )}
      <Button type="submit" className="ax-tap w-full sm:w-auto" disabled={!valid || send.isPending}>
        {send.isPending ? "Booking…" : "Confirm booking"}
      </Button>
      <p className="ax-caption text-muted-foreground">
        You will get a confirmation by e-mail with a calendar invitation and a link to move or cancel.
      </p>
    </form>
  );
}

function Confirmed({ done, tz }: { done: Booked; tz: string }) {
  return (
    <div className="mx-auto max-w-md space-y-4 rounded-xl border border-border bg-card p-6 text-center" role="status">
      <CalendarCheck className="mx-auto size-10 text-emerald-400" aria-hidden="true" />
      <h1 className="text-xl font-extrabold tracking-tight text-foreground">You're booked</h1>
      <div className="space-y-1 text-sm text-foreground">
        <p className="font-semibold">{done.title}</p>
        <p>{fmtDay(done.starts_at, tz)}</p>
        <p className="tabular-nums">
          {fmtClock(done.starts_at, tz)}–{fmtClock(done.ends_at, tz)} · {zoneLabel(tz)}
        </p>
        {done.host_name && <p className="text-muted-foreground">with {done.host_name}</p>}
        {done.location && <p className="break-words text-muted-foreground">{done.location}</p>}
      </div>
      <p className="text-sm text-muted-foreground">
        {done.mail_sent
          ? "A confirmation with a calendar invitation is on its way to your inbox."
          : "We could not send the confirmation e-mail — keep this page's link to move or cancel."}
      </p>
      <a
        href={new URL(done.manage_url, window.location.origin).pathname + new URL(done.manage_url, window.location.origin).search}
        className="ax-press ax-focus ax-tap inline-flex items-center justify-center rounded-md border border-border px-4 py-2 text-sm font-semibold text-foreground"
      >
        Move or cancel this booking
      </a>
    </div>
  );
}
