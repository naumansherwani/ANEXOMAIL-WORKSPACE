import { useMutation, useQuery } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import { CalendarClock, CalendarX, Globe, MapPin } from "lucide-react";
import { useMemo, useState } from "react";

import { SlotPicker } from "@/components/book/SlotPicker";
import { BrandMark } from "@/components/site/BrandMark";
import { Button } from "@/components/ui/button";
import type { ApiError } from "@/lib/api";
import {
  allZones,
  fmtClock,
  fmtDay,
  localZone,
  manageCancel,
  manageLookup,
  manageReschedule,
  minutesLabel,
  pageGet,
  zoneLabel,
  type ManageView,
  type PublicPage,
} from "@/lib/booking";

/**
 * /book/manage?t=<token> — the page behind "Move or cancel" in a booking confirmation e-mail.
 *
 * The token is a random uuid for exactly one booking. Opening the link changes nothing (mail scanners open links);
 * cancelling and moving need a deliberate press.
 */
export const Route = createFileRoute("/book/manage")({
  ssr: false,
  validateSearch: (search: Record<string, unknown>) => ({
    t: typeof search["t"] === "string" ? (search["t"] as string).slice(0, 64) : "",
  }),
  head: () => ({
    meta: [
      { title: "Your booking — ANEXOMAIL" },
      { name: "robots", content: "noindex, nofollow" },
      { name: "referrer", content: "no-referrer" },
    ],
  }),
  component: ManagePage,
});

function ManagePage() {
  const { t } = Route.useSearch();
  const q = useQuery<ManageView, ApiError>({
    queryKey: ["booking", "manage", t],
    queryFn: () => manageLookup(t),
    enabled: t.length > 0,
    retry: false,
    staleTime: 0,
  });
  return (
    <main className="min-h-[100dvh] bg-background px-4 py-8 pb-[max(2rem,env(safe-area-inset-bottom))] sm:px-6 sm:py-12">
      <div className="mx-auto w-full max-w-xl">
        <BrandMark />
        <div className="mt-8">
          {!t ? (
            <Notice title="This link is incomplete" body="Open the link from your confirmation e-mail again." />
          ) : q.isPending ? (
            <p className="text-sm text-muted-foreground" aria-busy="true">
              Opening your booking…
            </p>
          ) : q.error ? (
            <Notice
              title={q.error.status === 404 || q.error.status === 400 ? "This booking link is not valid" : "Could not open the booking"}
              body={
                q.error.status === 404 || q.error.status === 400
                  ? "It may have been mistyped. Use the link from your confirmation e-mail."
                  : "Please try again in a minute. Nothing was changed."
              }
              onRetry={q.error.status >= 500 || q.error.status === 0 ? () => void q.refetch() : undefined}
            />
          ) : (
            <Booking token={t} view={q.data} onChanged={() => void q.refetch()} />
          )}
        </div>
      </div>
    </main>
  );
}

function Notice({ title, body, onRetry }: { title: string; body: string; onRetry?: () => void }) {
  return (
    <div role="alert" className="rounded-xl border border-border bg-card p-5">
      <p className="text-base font-bold text-foreground">{title}</p>
      <p className="mt-1.5 text-sm text-muted-foreground">{body}</p>
      {onRetry && (
        <Button size="sm" variant="outline" className="ax-tap mt-4" onClick={onRetry}>
          Try again
        </Button>
      )}
    </div>
  );
}

function Booking({ token, view, onChanged }: { token: string; view: ManageView; onChanged: () => void }) {
  const [tz, setTz] = useState(view.visitor_tz && view.visitor_tz.length > 0 ? view.visitor_tz : localZone());
  const [mode, setMode] = useState<"view" | "move" | "cancel">("view");
  const [picked, setPicked] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const zones = useMemo(() => allZones(tz), [tz]);
  const cancelled = view.status === "cancelled";
  const page = useQuery<PublicPage, ApiError>({
    queryKey: ["booking", "page", view.handle],
    queryFn: () => pageGet(view.handle),
    enabled: mode === "move",
    retry: false,
  });

  const cancel = useMutation<unknown, ApiError, void>({
    mutationFn: () => manageCancel(token),
    onSuccess: () => {
      setMessage("Your booking is cancelled. The host was told.");
      setMode("view");
      onChanged();
    },
    onError: (e) => setError(e.message),
  });
  const move = useMutation<unknown, ApiError, void>({
    mutationFn: () => manageReschedule(token, picked as string),
    onSuccess: () => {
      setMessage("Your booking was moved. A new invitation is on its way.");
      setMode("view");
      setPicked(null);
      onChanged();
    },
    onError: (e) => {
      setError(e.message);
      if (e.status === 409) setPicked(null);
    },
  });

  const end = new Date(new Date(view.starts_at).getTime() + view.minutes * 60_000).toISOString();
  return (
    <div className="space-y-4">
      <header className="rounded-xl border border-border bg-card p-5">
        <p className="ax-eyebrow">{cancelled ? "Booking cancelled" : "Your booking"}</p>
        <h1 className={`mt-1 text-xl font-extrabold tracking-tight text-foreground ${cancelled ? "line-through opacity-70" : ""}`}>
          {view.title}
        </h1>
        <ul className="mt-4 space-y-2 text-sm text-foreground">
          <li className="flex items-start gap-2.5">
            <CalendarClock className="mt-0.5 size-4 shrink-0 text-steel" aria-hidden="true" />
            <span>
              {fmtDay(view.starts_at, tz)}
              <br />
              <span className="tabular-nums">
                {fmtClock(view.starts_at, tz)}–{fmtClock(end, tz)}
              </span>{" "}
              · {minutesLabel(view.minutes)}
            </span>
          </li>
          {view.host_name && (
            <li className="flex items-start gap-2.5">
              <span className="mt-0.5 size-4 shrink-0 text-center text-steel" aria-hidden="true">
                ◦
              </span>
              <span>with {view.host_name}</span>
            </li>
          )}
          {view.location && (
            <li className="flex items-start gap-2.5">
              <MapPin className="mt-0.5 size-4 shrink-0 text-steel" aria-hidden="true" />
              <span className="min-w-0 break-words">{view.location}</span>
            </li>
          )}
          <li className="flex items-center gap-2.5">
            <Globe className="size-4 shrink-0 text-steel" aria-hidden="true" />
            <select
              value={tz}
              onChange={(e) => setTz(e.target.value)}
              aria-label="Time zone"
              className="ax-focus ax-tap min-w-0 max-w-full truncate rounded-md border border-border bg-background px-2 py-1 text-base text-foreground sm:text-xs"
            >
              {zones.map((z) => (
                <option key={z} value={z}>
                  {zoneLabel(z)}
                </option>
              ))}
            </select>
          </li>
        </ul>
      </header>

      {message && (
        <p role="status" className="rounded-lg border border-border bg-secondary px-4 py-3 text-sm text-foreground">
          {message}
        </p>
      )}
      {error && (
        <p role="alert" className="text-sm text-danger">
          {error}
        </p>
      )}

      {!cancelled && view.can_change && mode === "view" && (
        <div className="flex flex-wrap gap-2">
          {view.enabled && view.reschedules < 3 && (
            <Button
              variant="outline"
              className="ax-tap"
              onClick={() => {
                setError(null);
                setMessage(null);
                setMode("move");
              }}
            >
              <CalendarClock className="size-4" aria-hidden="true" /> Move to another time
            </Button>
          )}
          <Button
            variant="outline"
            className="ax-tap"
            onClick={() => {
              setError(null);
              setMessage(null);
              setMode("cancel");
            }}
          >
            <CalendarX className="size-4" aria-hidden="true" /> Cancel booking
          </Button>
        </div>
      )}
      {!cancelled && !view.can_change && mode === "view" && (
        <p className="text-sm text-muted-foreground">This meeting has already started, so it can no longer be changed here.</p>
      )}

      {mode === "cancel" && (
        <div role="alertdialog" aria-label="Confirm cancel" className="space-y-3 rounded-xl border border-border bg-card p-5">
          <p className="text-sm font-semibold text-foreground">Cancel this booking?</p>
          <p className="text-sm text-muted-foreground">The host is told right away and the time becomes free again.</p>
          <div className="flex gap-2">
            <Button variant="destructive" className="ax-tap" disabled={cancel.isPending} onClick={() => cancel.mutate()}>
              {cancel.isPending ? "Cancelling…" : "Yes, cancel it"}
            </Button>
            <Button variant="ghost" className="ax-tap" onClick={() => setMode("view")}>
              Keep it
            </Button>
          </div>
        </div>
      )}

      {mode === "move" && (
        <section className="space-y-4 rounded-xl border border-border bg-card p-5">
          <h2 className="text-base font-bold text-foreground">Pick a new time</h2>
          {page.isPending ? (
            <p className="text-sm text-muted-foreground">Loading free times…</p>
          ) : page.error ? (
            <p className="text-sm text-muted-foreground">The host is not taking new times right now. You can still cancel.</p>
          ) : (
            <SlotPicker
              handle={view.handle}
              minutes={view.minutes}
              tz={tz}
              maxDays={page.data.max_days}
              picked={picked}
              onPick={setPicked}
            />
          )}
          {picked && (
            <div className="flex flex-wrap items-center gap-2 border-t border-border pt-4">
              <p className="text-sm font-semibold text-foreground">
                {fmtDay(picked, tz)} · {fmtClock(picked, tz)}
              </p>
              <Button className="ax-tap" disabled={move.isPending} onClick={() => move.mutate()}>
                {move.isPending ? "Moving…" : "Confirm new time"}
              </Button>
            </div>
          )}
          <Button variant="ghost" className="ax-tap" onClick={() => setMode("view")}>
            Back
          </Button>
        </section>
      )}
    </div>
  );
}
