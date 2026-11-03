import { useMutation, useQuery } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import {
  Ban,
  CalendarDays,
  Check,
  CircleHelp,
  Clock,
  MapPin,
  TriangleAlert,
  X,
} from "lucide-react";
import { useState } from "react";

import { BrandMark } from "@/components/site/BrandMark";
import { Button } from "@/components/ui/button";
import type { ApiError } from "@/lib/api";
import { rsvpLookup, rsvpRespond, type RsvpResponse, type RsvpView } from "@/lib/calendar";
import { cn } from "@/lib/utils";

/**
 * /rsvp?t=<token>[&r=yes|maybe|no] — the page behind the buttons in a calendar invitation e-mail.
 *
 * Public on purpose: the guest may not have an ANEXOMAIL account. The token is a random uuid the engine
 * issued for exactly one guest on exactly one meeting; it reveals the meeting title, time and the
 * guest's own answer — nothing else.
 *
 * Safety: opening the link NEVER records an answer (mail scanners and link-preview bots open links).
 * `r=` only pre-selects a button; the answer is recorded when the guest taps "Send my answer".
 */
export const Route = createFileRoute("/rsvp")({
  ssr: false,
  validateSearch: (search: Record<string, unknown>) => ({
    t: typeof search["t"] === "string" ? (search["t"] as string).slice(0, 64) : "",
    r: ["yes", "maybe", "no"].includes(String(search["r"]))
      ? (String(search["r"]) as Choice)
      : undefined,
  }),
  head: () => ({
    meta: [
      { title: "Answer an invitation — ANEXOMAIL" },
      { name: "robots", content: "noindex, nofollow" },
      { name: "referrer", content: "no-referrer" },
    ],
  }),
  component: RsvpPage,
});

type Choice = "yes" | "maybe" | "no";

const CHOICES: { id: Choice; label: string; Icon: typeof Check; on: string }[] = [
  {
    id: "yes",
    label: "Yes, I'll be there",
    Icon: Check,
    on: "border-emerald-500 bg-emerald-500/15 text-emerald-300",
  },
  {
    id: "maybe",
    label: "Maybe",
    Icon: CircleHelp,
    on: "border-amber-400 bg-amber-400/15 text-amber-300",
  },
  { id: "no", label: "No, I can't", Icon: X, on: "border-danger bg-danger/15 text-danger" },
];

const WORDS: Record<RsvpResponse, string> = {
  accepted: "Yes",
  tentative: "Maybe",
  declined: "No",
  needs_action: "not answered yet",
};

function RsvpPage() {
  const { t, r } = Route.useSearch();
  const lookup = useQuery<RsvpView, ApiError>({
    queryKey: ["rsvp", t],
    queryFn: () => rsvpLookup(t),
    enabled: t.length > 0,
    retry: false,
    staleTime: 0,
  });

  return (
    <main className="min-h-[100dvh] bg-background px-4 py-8 pb-[max(2rem,env(safe-area-inset-bottom))] sm:px-6 sm:py-12">
      <div className="mx-auto w-full max-w-md">
        <BrandMark />
        <div className="mt-8">
          {!t ? (
            <Notice
              title="This link is incomplete"
              body="Open the answer buttons from the invitation e-mail again."
            />
          ) : lookup.isPending ? (
            <p className="text-sm text-muted-foreground" aria-busy="true">
              Opening your invitation…
            </p>
          ) : lookup.error ? (
            <Notice
              title={
                lookup.error.status === 404 || lookup.error.status === 400
                  ? "This invitation link is not valid"
                  : "Could not open the invitation"
              }
              body={
                lookup.error.status === 404 || lookup.error.status === 400
                  ? "It may have been mistyped or the meeting was removed. Ask the organiser to send it again."
                  : "Please try again in a minute. Nothing was changed."
              }
              onRetry={
                lookup.error.status >= 500 || lookup.error.status === 0
                  ? () => void lookup.refetch()
                  : undefined
              }
            />
          ) : (
            <Invitation token={t} preselect={r} view={lookup.data} />
          )}
        </div>
        <p className="mt-10 text-center text-[11px] text-muted-foreground">
          Sent with ANEXOMAIL Calendar · your answer goes to the organiser only
        </p>
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

function Invitation({
  token,
  preselect,
  view,
}: {
  token: string;
  preselect: Choice | undefined;
  view: RsvpView;
}) {
  const [choice, setChoice] = useState<Choice | null>(preselect ?? null);
  const [note, setNote] = useState("");
  const [noteOpen, setNoteOpen] = useState(false);
  const [done, setDone] = useState<RsvpView | null>(null);
  const send = useMutation<RsvpView, ApiError, void>({
    mutationFn: () => rsvpRespond(token, choice as Choice, note),
    onSuccess: (res) => {
      if (res.error === "cancelled") setDone({ ...view, cancelled: true });
      else setDone(res);
    },
  });

  const current = done ?? view;
  const start = new Date(current.starts_at);
  const end = new Date(current.ends_at);
  const day = start.toLocaleDateString(undefined, {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });
  const clock = (d: Date) =>
    d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" });
  const zone =
    new Intl.DateTimeFormat(undefined, { timeZoneName: "short" })
      .formatToParts(start)
      .find((p) => p.type === "timeZoneName")?.value ?? "";
  const answered = current.response !== "needs_action";

  return (
    <div className="space-y-5">
      <header className="rounded-xl border border-border bg-card p-5">
        <p className="ax-eyebrow">{current.cancelled ? "Meeting cancelled" : "You're invited"}</p>
        <h1
          className={cn(
            "mt-1 text-xl font-extrabold tracking-tight text-foreground",
            current.cancelled && "line-through opacity-70",
          )}
        >
          {current.title}
        </h1>
        <ul className="mt-4 space-y-2 text-sm text-foreground">
          <li className="flex items-start gap-2.5">
            <CalendarDays className="mt-0.5 size-4 shrink-0 text-steel" aria-hidden="true" />
            <span>{day}</span>
          </li>
          <li className="flex items-start gap-2.5">
            <Clock className="mt-0.5 size-4 shrink-0 text-steel" aria-hidden="true" />
            <span>
              {clock(start)} – {clock(end)}{" "}
              {zone && <span className="text-muted-foreground">({zone}, your time)</span>}
            </span>
          </li>
          {current.location && (
            <li className="flex items-start gap-2.5">
              <MapPin className="mt-0.5 size-4 shrink-0 text-steel" aria-hidden="true" />
              {/^https?:\/\//i.test(current.location) ? (
                <a
                  href={current.location}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="min-w-0 break-all text-cyan-accent underline-offset-4 hover:underline"
                >
                  {current.location}
                </a>
              ) : (
                <span className="min-w-0 break-words">{current.location}</span>
              )}
            </li>
          )}
        </ul>
        {current.organiser && (
          <p className="mt-4 text-xs text-muted-foreground">
            Organised by <span className="break-all text-foreground">{current.organiser}</span>
          </p>
        )}
        {current.agenda && (
          <div className="mt-4 border-t border-border pt-4">
            <p className="ax-eyebrow">Agenda</p>
            <p className="mt-1.5 whitespace-pre-wrap break-words text-sm text-foreground">
              {current.agenda}
            </p>
          </div>
        )}
      </header>

      {!current.cancelled && !answered && current.conflicts && current.conflicts.count > 0 && (
        <div
          role="status"
          className="flex items-start gap-2.5 rounded-xl border border-amber-400/40 bg-amber-400/10 p-4 text-sm text-amber-300"
        >
          <TriangleAlert className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
          <div className="min-w-0">
            <p className="font-semibold">
              {current.conflicts.count === 1
                ? "You already have another meeting at this time."
                : `You already have ${current.conflicts.count} other meetings at this time.`}
            </p>
            <ul className="mt-1 space-y-0.5 text-xs text-amber-200/90">
              {current.conflicts.overlaps.map((o) => (
                <li key={`${o.starts_at}-${o.ends_at}`}>
                  {clock(new Date(o.starts_at))} – {clock(new Date(o.ends_at))}
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}

      {current.cancelled ? (
        <div className="flex items-start gap-2.5 rounded-xl border border-danger/40 bg-danger/10 p-4 text-sm text-danger">
          <Ban className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
          This meeting was cancelled by the organiser. No answer is needed.
        </div>
      ) : done ? (
        <div
          className="rounded-xl border border-emerald-500/40 bg-emerald-500/10 p-4"
          role="status"
        >
          <p className="text-sm font-bold text-emerald-300">
            Thank you — your answer is {WORDS[done.response]}.
          </p>
          <p className="mt-1 text-xs text-muted-foreground">
            The organiser can see it now. You can change it any time with the same link.
          </p>
          <Button size="sm" variant="outline" className="ax-tap mt-3" onClick={() => setDone(null)}>
            Change my answer
          </Button>
        </div>
      ) : (
        <div className="space-y-3">
          <p className="text-sm font-semibold text-foreground">
            {answered
              ? `Your current answer: ${WORDS[current.response]}. Change it?`
              : "Will you come?"}
          </p>
          <div className="grid gap-2">
            {CHOICES.map(({ id, label, Icon, on }) => (
              <button
                key={id}
                type="button"
                aria-pressed={choice === id}
                onClick={() => setChoice(id)}
                className={cn(
                  "ax-press ax-focus flex min-h-12 items-center gap-2.5 rounded-xl border px-4 text-left text-sm font-semibold transition-colors",
                  choice === id ? on : "border-border text-foreground hover:bg-secondary",
                )}
              >
                <Icon className="size-4 shrink-0" aria-hidden="true" />
                {label}
              </button>
            ))}
          </div>
          {noteOpen ? (
            <label className="block text-xs text-muted-foreground">
              A note for the organiser (optional)
              <textarea
                value={note}
                onChange={(e) => setNote(e.target.value.slice(0, 500))}
                rows={2}
                className="ax-focus mt-1 w-full resize-y rounded-lg border border-border bg-transparent px-3 py-2 text-base text-foreground outline-none placeholder:text-steel"
                placeholder="e.g. I can join for the first half"
              />
            </label>
          ) : (
            <button
              type="button"
              onClick={() => setNoteOpen(true)}
              className="ax-press ax-focus ax-tap text-xs font-semibold text-cyan-accent underline-offset-4 hover:underline"
            >
              + Add a note for the organiser
            </button>
          )}
          <Button
            className="ax-tap w-full"
            size="lg"
            disabled={!choice || send.isPending}
            onClick={() => send.mutate()}
          >
            {send.isPending ? "Sending…" : choice ? "Send my answer" : "Choose an answer"}
          </Button>
          {send.error && (
            <p role="alert" className="text-sm text-danger">
              {send.error.status === 404
                ? "This invitation link is no longer valid."
                : "Your answer was not saved. Please try again."}
            </p>
          )}
        </div>
      )}
    </div>
  );
}
