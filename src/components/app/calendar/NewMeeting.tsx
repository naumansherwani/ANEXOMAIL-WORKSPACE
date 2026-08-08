import { CalendarPlus, Lock } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useCreateMeeting } from "@/lib/calendar";
import { notify } from "@/lib/notify";

/**
 * Thread -> Meeting in one step. When `threadId` is present the thread IS the
 * context: the server attaches the meeting to it and drops the invite reply
 * back into the same conversation.
 *
 * Agenda gate (locked): with no agenda the button stays disabled — a meeting
 * without a purpose is never created.
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
  const [title, setTitle] = useState(defaultTitle ?? "");
  const [attendees, setAttendees] = useState(defaultAttendees ?? "");
  const [when, setWhen] = useState(defaultLocalDateTime());
  const [duration, setDuration] = useState(30);
  const [agenda, setAgenda] = useState("");
  const [location, setLocation] = useState("");

  const agendaOk = agenda.trim().length >= 10;
  const ready = title.trim().length > 1 && when && agendaOk;

  const submit = () => {
    if (!ready) return;
    create.mutate(
      {
        title: title.trim(),
        starts_at: new Date(when).toISOString(),
        duration_minutes: duration,
        attendees: attendees
          .split(/[,;\s]+/)
          .map((a) => a.trim())
          .filter(Boolean),
        agenda: agenda.trim(),
        ...(location.trim() ? { location: location.trim() } : {}),
        ...(threadId ? { thread_id: threadId } : {}),
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      },
      {
        onSuccess: (data) => {
          notify.done("Meeting created", threadId ? "The invite is in the thread." : "It's on your calendar.");
          onCreated(data.event.id);
        },
        onError: (error) =>
          notify.failed(error.isNotImplemented ? "Not wired yet" : "Could not create", {
            description: error.isNotImplemented ? "Waiting on POST /api/calendar/events." : error.message,
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

      <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Title" className="h-8 text-xs" />
      <Input
        value={attendees}
        onChange={(e) => setAttendees(e.target.value)}
        placeholder="Attendees, comma separated"
        className="h-8 text-xs"
      />
      <div className="flex gap-2">
        <Input
          type="datetime-local"
          value={when}
          onChange={(e) => setWhen(e.target.value)}
          className="h-8 flex-1 text-xs"
        />
        <select
          value={duration}
          onChange={(e) => setDuration(Number(e.target.value))}
          className="ax-focus h-8 rounded-md border border-border bg-background px-2 text-xs text-foreground"
        >
          {[15, 25, 30, 45, 60, 90].map((m) => (
            <option key={m} value={m}>
              {m}m
            </option>
          ))}
        </select>
      </div>
      <Input
        value={location}
        onChange={(e) => setLocation(e.target.value)}
        placeholder="Location or link (optional)"
        className="h-8 text-xs"
      />
      <textarea
        value={agenda}
        onChange={(e) => setAgenda(e.target.value)}
        rows={3}
        placeholder={
          threadId
            ? "Agenda — LEO pre-fills this from the thread once wired."
            : "Agenda — what has to be decided?"
        }
        className="ax-focus w-full resize-y rounded-md border border-border bg-transparent px-2 py-1.5 text-xs text-foreground outline-none placeholder:text-steel"
      />
      {!agendaOk && (
        <p className="ax-caption flex items-center gap-1.5 text-amber-400">
          <Lock className="size-3" />
          Agenda gate: no agenda, no meeting.
        </p>
      )}

      <div className="flex items-center gap-2">
        <Button size="sm" disabled={!ready || create.isPending} onClick={submit}>
          {create.isPending ? "Creating…" : "Create"}
        </Button>
        <Button size="sm" variant="ghost" onClick={onCancel}>
          Cancel
        </Button>
      </div>
    </div>
  );
}

function defaultLocalDateTime() {
  const d = new Date();
  d.setMinutes(d.getMinutes() + 60 - (d.getMinutes() % 15), 0, 0);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}