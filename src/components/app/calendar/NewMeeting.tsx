import { CalendarPlus, Lock, Mail, Search } from "lucide-react";
import { useState } from "react";

import { FindTime } from "@/components/app/calendar/FindTime";
import { OverlapMatrix } from "@/components/app/calendar/OverlapMatrix";
import { useProCalendar } from "@/lib/use-pro-calendar";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useCreateMeeting, whenLabel } from "@/lib/calendar";
import { RepeatPicker } from "@/components/app/calendar/RepeatPicker";
import { REMINDER_CHOICES, outsideHours, useCalPrefs } from "@/lib/calprefs";
import { reportInvites } from "@/lib/calendar-invites";
import { NO_REPEAT, buildRrule, type RepeatSpec } from "@/lib/recurrence";
import { notify } from "@/lib/notify";
import { isRoomAddress } from "@/lib/rooms";

/**
 * Thread -> Meeting in one step. When `threadId` is present the thread IS the
 * context: the server attaches the meeting to it.
 *
 * Agenda gate (locked): with no agenda the button stays disabled — a meeting
 * without a purpose is never created.
 *
 * Invitations (Calendar v2): every guest gets a real calendar invitation e-mail
 * (.ics) they can answer Yes / Maybe / No — in Gmail, Outlook, Apple Calendar or
 * from the link. The result below is what the engine REPORTED, never assumed:
 * if the engine did not answer with an invitation report, we say plainly that
 * nothing was e-mailed.
 */
export function NewMeeting({
  threadId,
  defaultTitle,
  defaultAttendees,
  onCreated,
  onCancel,
}: {
  threadId?: string;
  defaultTitle?: string;
  defaultAttendees?: string;
  onCreated: (id: string) => void;
  onCancel: () => void;
}) {
  const create = useCreateMeeting();
  const prefs = useCalPrefs();
  const [calendarKey, setCalendarKey] = useState("");
  const [remind, setRemind] = useState(10);
  const [title, setTitle] = useState(defaultTitle ?? "");
  const [attendees, setAttendees] = useState(defaultAttendees ?? "");
  const [when, setWhen] = useState(defaultLocalDateTime());
  const [duration, setDuration] = useState(30);
  const [agenda, setAgenda] = useState("");
  const [location, setLocation] = useState("");
  const [invite, setInvite] = useState(true);
  const [finding, setFinding] = useState(false);
  const proCal = useProCalendar();
  const [repeat, setRepeat] = useState<RepeatSpec>(NO_REPEAT);

  const agendaOk = agenda.trim().length >= 10;
  const ready = title.trim().length > 1 && when && agendaOk;
  const typedList = parseAddresses(attendees);
  const guestList = typedList.filter((a) => !isRoomAddress(a));
  const roomTyped = typedList.length !== guestList.length;

  const submit = () => {
    if (!ready) return;
    const startsAt = new Date(when).toISOString();
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    const rrule = buildRrule(repeat, new Date(when));
    create.mutate(
      {
        title: title.trim(),
        starts_at: startsAt,
        duration_minutes: duration,
        attendees: guestList,
        agenda: agenda.trim(),
        ...(location.trim() ? { location: location.trim() } : {}),
        ...(threadId ? { thread_id: threadId } : {}),
        timezone: zone,
        invite,
        ...(calendarKey ? { calendar_key: calendarKey } : {}),
        remind_min: [remind],
        when_label: whenLabel(startsAt, duration, zone),
        ...(rrule ? { rrule, tz_offset_min: -new Date(when).getTimezoneOffset() } : {}),
      },
      {
        onSuccess: (data) => {
          reportInvites({
            invite,
            guests: guestList.length,
            invites: data.invites,
            ignored: data.ignored?.invalid ?? [],
            threadId,
          });
          onCreated(data.event.id);
        },
        onError: (error) =>
          notify.failed(error.isNotImplemented ? "Not wired yet" : "Could not create", {
            description: error.isNotImplemented
              ? "Waiting on POST /api/calendar/events."
              : error.message,
          }),
      },
    );
  };

  return (
    <div className="space-y-ax-3 border-b border-border px-ax-4 py-ax-4">
      <p className="ax-eyebrow flex items-center gap-1.5">
        <CalendarPlus className="size-3.5" />
        New meeting
      </p>

      <Input
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        placeholder="Title"
        className="h-8 text-base sm:text-xs"
      />
      <Input
        value={attendees}
        onChange={(e) => setAttendees(e.target.value)}
        placeholder="Guests' e-mail addresses, comma separated"
        inputMode="email"
        className="h-8 text-base sm:text-xs"
      />
      <div className="flex gap-2">
        <Input
          type="datetime-local"
          value={when}
          onChange={(e) => setWhen(e.target.value)}
          className="h-8 flex-1 text-base sm:text-xs"
        />
        <select
          value={duration}
          onChange={(e) => setDuration(Number(e.target.value))}
          className="ax-focus h-8 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
        >
          {[15, 25, 30, 45, 60, 90].map((m) => (
            <option key={m} value={m}>
              {m}m
            </option>
          ))}
        </select>
      </div>

      {(() => {
        const away = when ? outsideHours(new Date(when), prefs) : null;
        return away ? (
          <p className="ax-caption text-amber-400">
            {away === "ooo"
              ? "You are marked out of office on this day."
              : "This is outside your working hours."}
          </p>
        ) : null;
      })()}

      <div className="flex gap-2">
        {prefs.calendars.length > 1 && (
          <select
            value={calendarKey}
            onChange={(e) => setCalendarKey(e.target.value)}
            aria-label="Calendar"
            className="ax-focus h-8 min-w-0 flex-1 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
          >
            <option value="">Calendar: {prefs.calendars[0]?.name}</option>
            {prefs.calendars.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        )}
        <select
          value={remind}
          onChange={(e) => setRemind(Number(e.target.value))}
          aria-label="Reminder (in app)"
          className="ax-focus h-8 min-w-0 flex-1 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
        >
          {REMINDER_CHOICES.map((r) => (
            <option key={r.min} value={r.min}>
              {r.label} · in app
            </option>
          ))}
        </select>
      </div>

      <RepeatPicker value={repeat} onChange={setRepeat} start={new Date(when)} />

      <button
        type="button"
        onClick={() => setFinding((v) => !v)}
        aria-expanded={finding}
        className="ax-press ax-focus ax-tap ax-caption inline-flex items-center gap-1.5 rounded-md border border-border px-2 py-1 font-semibold text-foreground"
      >
        <Search className="size-3.5" aria-hidden="true" />
        {finding ? "Hide find a time" : "Find a time for everyone"}
      </button>
      {finding && (
        <div className="space-y-ax-3">
          {proCal && (
            <OverlapMatrix
              addresses={guestList}
              durationMin={duration}
              onPick={(value) => {
                setWhen(value);
                setFinding(false);
              }}
            />
          )}
          <FindTime
            attendees={guestList}
            duration={duration}
            onPick={(value) => {
              setWhen(value);
              setFinding(false);
            }}
          />
        </div>
      )}

      <Input
        value={location}
        onChange={(e) => setLocation(e.target.value)}
        placeholder="Location or link (optional)"
        className="h-8 text-base sm:text-xs"
      />
      <textarea
        value={agenda}
        onChange={(e) => setAgenda(e.target.value)}
        rows={3}
        placeholder={
          threadId
            ? "Agenda for this thread — what has to be decided?"
            : "Agenda — what has to be decided?"
        }
        className="ax-focus w-full resize-y rounded-md border border-border bg-transparent px-2 py-1.5 text-base text-foreground outline-none placeholder:text-steel sm:text-xs"
      />
      {!agendaOk && (
        <p className="ax-caption flex items-center gap-1.5 text-amber-400">
          <Lock className="size-3" />
          Agenda gate: no agenda, no meeting.
        </p>
      )}

      {roomTyped && (
        <p role="note" className="ax-caption text-amber-400">
          A room is not a guest and was left out. Create the meeting, then book the room in its Room
          section.
        </p>
      )}

      {guestList.length > 0 && (
        <label className="ax-tap flex items-start gap-2 text-[12px] text-foreground">
          <input
            type="checkbox"
            checked={invite}
            onChange={(e) => setInvite(e.target.checked)}
            className="mt-0.5 size-4 shrink-0 accent-[var(--cyan-accent)]"
          />
          <span>
            <span className="flex items-center gap-1.5 font-semibold">
              <Mail className="size-3.5" aria-hidden="true" />
              E-mail an invitation to {guestList.length}{" "}
              {guestList.length === 1 ? "guest" : "guests"}
            </span>
            <span className="ax-caption block text-muted-foreground">
              Works in Gmail, Outlook and Apple Calendar. Each guest answers Yes / Maybe / No and
              you see it here. The agenda goes with it.
            </span>
          </span>
        </label>
      )}

      <div className="flex items-center gap-2">
        <Button size="sm" className="ax-tap" disabled={!ready || create.isPending} onClick={submit}>
          {create.isPending
            ? "Creating…"
            : guestList.length > 0 && invite
              ? "Create & invite"
              : "Create"}
        </Button>
        <Button size="sm" className="ax-tap" variant="ghost" onClick={onCancel}>
          Cancel
        </Button>
      </div>
    </div>
  );
}

function parseAddresses(raw: string) {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const part of raw.split(/[,;\s]+/)) {
    const a = part.trim();
    if (!a || seen.has(a.toLowerCase())) continue;
    seen.add(a.toLowerCase());
    out.push(a);
  }
  return out;
}

function defaultLocalDateTime() {
  const d = new Date();
  d.setMinutes(d.getMinutes() + 60 - (d.getMinutes() % 15), 0, 0);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
