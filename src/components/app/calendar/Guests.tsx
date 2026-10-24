import { InlineLoading } from "@/components/state/BrandLoader";
import { Ban, CalendarClock, Check, CircleHelp, Clock, Mail, RefreshCw, X } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  useGuests,
  useResendInvites,
  useUpdateMeeting,
  whenLabel,
  type CalendarEvent,
  type GuestRow,
  type RsvpResponse,
} from "@/lib/calendar";
import { inviteReason } from "@/lib/calendar-invites";
import { notify } from "@/lib/notify";
import { withoutRooms } from "@/lib/rooms";
import { cn } from "@/lib/utils";

/**
 * Guests, answers and invitation ledger for one meeting.
 *
 * Everything shown here is what the engine recorded: who was e-mailed (and what the mail
 * server answered), who clicked Yes / Maybe / No, and when. Only the organiser can
 * reschedule, cancel or re-send — the engine enforces it, this panel just hides the buttons.
 */

const CHIP: Record<RsvpResponse, { label: string; cls: string; Icon: typeof Check }> = {
  accepted: {
    label: "Yes",
    cls: "border-emerald-500/40 bg-emerald-500/10 text-emerald-400",
    Icon: Check,
  },
  tentative: {
    label: "Maybe",
    cls: "border-amber-400/40 bg-amber-400/10 text-amber-400",
    Icon: CircleHelp,
  },
  declined: { label: "No", cls: "border-danger/40 bg-danger/10 text-danger", Icon: X },
  needs_action: {
    label: "Waiting",
    cls: "border-border bg-secondary text-muted-foreground",
    Icon: Clock,
  },
};

function inviteLine(g: GuestRow) {
  if (g.invite_status === "sent") {
    return g.invite_sent_at
      ? `Invitation e-mailed ${new Date(g.invite_sent_at).toLocaleString(undefined, {
          day: "numeric",
          month: "short",
          hour: "2-digit",
          minute: "2-digit",
        })}`
      : "Invitation e-mailed";
  }
  if (g.invite_status === "failed")
    return `Invitation failed — ${inviteReason(g.invite_error ?? undefined)}`;
  return "No invitation e-mailed";
}

export function Guests({ event }: { event: CalendarEvent }) {
  const guests = useGuests(event.id);
  const update = useUpdateMeeting();
  const resend = useResendInvites();
  const [mode, setMode] = useState<"" | "reschedule" | "cancel">("");
  const [notifyGuests, setNotifyGuests] = useState(true);
  // repeating meeting: change just this one, or the whole series
  const inSeries = Boolean(event.recurring) && event.id.includes("~");
  const [scope, setScope] = useState<"this" | "all">("this");
  const minutes = Math.max(
    5,
    Math.round((new Date(event.ends_at).getTime() - new Date(event.starts_at).getTime()) / 60_000),
  );
  const [when, setWhen] = useState(() => toLocalInput(new Date(event.starts_at)));
  const [duration, setDuration] = useState(minutes);

  if (guests.isPending) {
    return (
      <section className="mt-ax-6" aria-busy="true">
        <p className="ax-eyebrow">Guests</p>
        <InlineLoading label="Loading answers…" />
      </section>
    );
  }

  if (guests.error || !guests.data) {
    if (event.attendees.length === 0) return null;
    return (
      <section className="mt-ax-6">
        <p className="ax-eyebrow">Guests</p>
        <ul className="mt-ax-2 divide-y divide-border rounded-md border border-border">
          {event.attendees.map((a) => (
            <li key={a.address} className="truncate px-ax-3 py-ax-2 text-[13px] text-foreground">
              {a.display_name || a.address}
            </li>
          ))}
        </ul>
        <p className="ax-caption mt-ax-2 text-muted-foreground">
          Answers and invitation status are not available yet — the calendar engine update is
          pending.
        </p>
      </section>
    );
  }

  const data = guests.data;
  const rows = withoutRooms(data.attendees);
  const cancelled = data.status === "cancelled";
  const tally = {
    accepted: rows.filter((r) => r.response === "accepted").length,
    tentative: rows.filter((r) => r.response === "tentative").length,
    declined: rows.filter((r) => r.response === "declined").length,
    needs_action: rows.filter((r) => r.response === "needs_action").length,
  };
  const waiting = rows.filter(
    (r) =>
      r.response === "needs_action" &&
      r.address.toLowerCase() !== (data.organiser ?? "").toLowerCase(),
  ).length;

  const label = () => whenLabel(new Date(when).toISOString(), duration);

  const onResend = () =>
    resend.mutate(
      { id: event.id, when_label: whenLabel(event.starts_at, minutes) },
      {
        onSuccess: (res) => {
          const bad = res.invites.failed + res.invites.skipped;
          if (bad === 0) {
            notify.done(
              res.invites.sent > 0
                ? `Invitation re-sent to ${res.invites.sent}`
                : "Nothing to re-send",
              res.invites.note || undefined,
            );
          } else {
            const first = res.invites.results.find((r) => r.status !== "sent");
            notify.failed(`${res.invites.sent} re-sent, ${bad} not sent`, {
              description: first ? `${first.address}: ${inviteReason(first.error)}` : undefined,
            });
          }
          void guests.refetch();
        },
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Not live yet" : "Could not re-send", {
            description: e.message,
          }),
      },
    );

  const onReschedule = () => {
    const startsAt = new Date(when);
    if (Number.isNaN(startsAt.getTime())) return;
    update.mutate(
      {
        id: event.id,
        starts_at: startsAt.toISOString(),
        duration_minutes: duration,
        notify: notifyGuests,
        when_label: label(),
        ...(inSeries ? { scope } : {}),
      },
      {
        onSuccess: (res) => {
          if (!notifyGuests) notify.done("Meeting moved", "Guests were not told.");
          else if (!res.invites)
            notify.failed("Moved, but the guests were NOT told", {
              description: "The invitation engine did not report back.",
            });
          else if (res.invites.failed + res.invites.skipped > 0)
            notify.failed(
              `Moved — ${res.invites.sent} told, ${res.invites.failed + res.invites.skipped} not`,
              {
                description: "Open Guests to see who and re-send.",
              },
            );
          else notify.done("Meeting moved", `${res.invites.sent} guest(s) received the new time.`);
          setMode("");
          void guests.refetch();
        },
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Not live yet" : "Could not move", {
            description: e.message,
          }),
      },
    );
  };

  const onCancel = () =>
    update.mutate(
      { id: event.id, cancel: true, notify: notifyGuests, ...(inSeries ? { scope } : {}) },
      {
        onSuccess: (res) => {
          if (!notifyGuests) notify.done("Meeting cancelled", "Guests were not told.");
          else if (!res.invites)
            notify.failed("Cancelled, but the guests were NOT told", {
              description: "The invitation engine did not report back.",
            });
          else if (res.invites.failed + res.invites.skipped > 0)
            notify.failed(
              `Cancelled — ${res.invites.sent} told, ${res.invites.failed + res.invites.skipped} not`,
              {
                description: "Some cancellation e-mails could not be sent.",
              },
            );
          else notify.done("Meeting cancelled", `${res.invites.sent} guest(s) told.`);
          setMode("");
          void guests.refetch();
        },
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Not live yet" : "Could not cancel", {
            description: e.message,
          }),
      },
    );

  return (
    <section className="mt-ax-6">
      <div className="flex flex-wrap items-center gap-2">
        <p className="ax-eyebrow">Guests</p>
        {cancelled && (
          <span className="inline-flex items-center gap-1 rounded-full border border-danger/40 bg-danger/10 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-danger">
            <Ban className="size-3" aria-hidden="true" />
            Cancelled
          </span>
        )}
        <span className="ax-caption ml-auto text-muted-foreground">
          {tally.accepted} yes · {tally.tentative} maybe · {tally.declined} no ·{" "}
          {tally.needs_action} waiting
        </span>
      </div>

      <ul className="mt-ax-2 divide-y divide-border rounded-md border border-border">
        {rows.length === 0 && (
          <li className="px-ax-3 py-ax-2 text-[13px] text-muted-foreground">
            No guests on this meeting.
          </li>
        )}
        {rows.map((g) => {
          const chip = CHIP[g.response] ?? CHIP.needs_action;
          const isOrganiser = g.address.toLowerCase() === (data.organiser ?? "").toLowerCase();
          return (
            <li
              key={g.address}
              className="flex flex-wrap items-center gap-x-ax-3 gap-y-1 px-ax-3 py-ax-2"
            >
              <span className="min-w-0 flex-1 basis-40 break-all text-[13px] text-foreground">
                {g.address}
              </span>
              <span
                className={cn(
                  "inline-flex shrink-0 items-center gap-1 rounded-full border px-2 py-0.5 text-[11px] font-bold",
                  chip.cls,
                )}
              >
                <chip.Icon className="size-3" aria-hidden="true" />
                {chip.label}
              </span>
              <span
                className={cn(
                  "ax-caption basis-full text-muted-foreground",
                  g.invite_status === "failed" && "text-danger",
                )}
              >
                {isOrganiser ? "Organiser" : inviteLine(g)}
                {g.rsvp_at
                  ? ` · answered ${new Date(g.rsvp_at).toLocaleString(undefined, {
                      day: "numeric",
                      month: "short",
                      hour: "2-digit",
                      minute: "2-digit",
                    })}`
                  : ""}
                {g.rsvp_at && g.rsvp_via === "calendar_app" ? " · from their calendar app" : ""}
                {g.rsvp_comment ? ` · “${g.rsvp_comment}”` : ""}
              </span>
            </li>
          );
        })}
      </ul>

      {data.is_organiser && !cancelled && (
        <div className="mt-ax-3 flex flex-wrap gap-2">
          {waiting > 0 && (
            <Button
              size="sm"
              variant="outline"
              className="ax-tap"
              disabled={resend.isPending}
              onClick={onResend}
            >
              <RefreshCw className="size-4" aria-hidden="true" />
              {resend.isPending ? "Sending…" : `Re-send to ${waiting} waiting`}
            </Button>
          )}
          <Button
            size="sm"
            variant="outline"
            className="ax-tap"
            onClick={() => setMode(mode === "reschedule" ? "" : "reschedule")}
            aria-expanded={mode === "reschedule"}
          >
            <CalendarClock className="size-4" aria-hidden="true" />
            Reschedule
          </Button>
          <Button
            size="sm"
            variant="ghost"
            className="ax-tap text-danger"
            onClick={() => setMode(mode === "cancel" ? "" : "cancel")}
            aria-expanded={mode === "cancel"}
          >
            <Ban className="size-4" aria-hidden="true" />
            Cancel meeting
          </Button>
        </div>
      )}

      {mode === "reschedule" && (
        <div className="mt-ax-3 space-y-ax-2 rounded-md border border-border p-ax-3">
          {inSeries && <ScopeChoice scope={scope} onChange={setScope} />}
          <div className="flex gap-2">
            <Input
              type="datetime-local"
              value={when}
              onChange={(e) => setWhen(e.target.value)}
              className="h-9 flex-1 text-base sm:text-xs"
            />
            <select
              value={duration}
              onChange={(e) => setDuration(Number(e.target.value))}
              className="ax-focus h-9 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
            >
              {[...new Set([15, 25, 30, 45, 60, 90, minutes])]
                .sort((a, b) => a - b)
                .map((m) => (
                  <option key={m} value={m}>
                    {m}m
                  </option>
                ))}
            </select>
          </div>
          <label className="ax-tap flex items-center gap-2 text-[12px] text-foreground">
            <input
              type="checkbox"
              checked={notifyGuests}
              onChange={(e) => setNotifyGuests(e.target.checked)}
              className="size-4 accent-[var(--cyan-accent)]"
            />
            <Mail className="size-3.5" aria-hidden="true" />
            Tell the guests (everyone is asked to answer again)
          </label>
          <Button size="sm" className="ax-tap" disabled={update.isPending} onClick={onReschedule}>
            {update.isPending ? "Moving…" : "Move meeting"}
          </Button>
        </div>
      )}

      {mode === "cancel" && (
        <div className="mt-ax-3 space-y-ax-2 rounded-md border border-danger/40 p-ax-3">
          <p className="text-[13px] text-foreground">
            Cancel “{event.title}”?{" "}
            {inSeries && scope === "all"
              ? "Every meeting in the series leaves your calendar and the guests’ calendars."
              : "It leaves your calendar and the guests’ calendars."}
          </p>
          {inSeries && <ScopeChoice scope={scope} onChange={setScope} />}
          <label className="ax-tap flex items-center gap-2 text-[12px] text-foreground">
            <input
              type="checkbox"
              checked={notifyGuests}
              onChange={(e) => setNotifyGuests(e.target.checked)}
              className="size-4 accent-[var(--cyan-accent)]"
            />
            <Mail className="size-3.5" aria-hidden="true" />
            Send a cancellation to the guests
          </label>
          <div className="flex gap-2">
            <Button
              size="sm"
              variant="destructive"
              className="ax-tap"
              disabled={update.isPending}
              onClick={onCancel}
            >
              {update.isPending ? "Cancelling…" : "Cancel meeting"}
            </Button>
            <Button size="sm" variant="ghost" className="ax-tap" onClick={() => setMode("")}>
              Keep it
            </Button>
          </div>
        </div>
      )}
    </section>
  );
}

function toLocalInput(d: Date) {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** "This event only / All events in the series" — shown for repeating meetings. */
function ScopeChoice({
  scope,
  onChange,
}: {
  scope: "this" | "all";
  onChange: (s: "this" | "all") => void;
}) {
  const opts: { v: "this" | "all"; label: string }[] = [
    { v: "this", label: "This event only" },
    { v: "all", label: "All events in the series" },
  ];
  return (
    <div role="radiogroup" aria-label="Apply to" className="flex flex-wrap gap-2">
      {opts.map((o) => (
        <button
          key={o.v}
          type="button"
          role="radio"
          aria-checked={scope === o.v}
          onClick={() => onChange(o.v)}
          className={`ax-press ax-focus ax-tap rounded-full border px-3 py-1 text-[12px] font-semibold ${
            scope === o.v
              ? "border-transparent bg-foreground text-background"
              : "border-border text-muted-foreground"
          }`}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}
