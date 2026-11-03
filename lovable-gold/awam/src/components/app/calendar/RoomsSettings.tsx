import { DoorOpen, Loader2, Trash2 } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { notify } from "@/lib/notify";
import { MAX_ROOMS, roomError, useArchiveRoom, useCreateRoom, useRooms } from "@/lib/rooms";

/** Rooms & resources (calendar #8). Owners and admins add or remove; everyone in the workspace sees them when booking a meeting. */
export function RoomsSettings() {
  const list = useRooms();
  const create = useCreateRoom();
  const archive = useArchiveRoom();
  const [name, setName] = useState("");
  const [seats, setSeats] = useState("");
  const [where, setWhere] = useState("");
  const [kind, setKind] = useState<"room" | "resource">("room");

  if (list.error && (list.error.isNotImplemented || list.error.code === "sql_missing")) return null;
  if (list.isPending) return null;
  const rooms = list.data?.rooms ?? [];
  const canManage = list.data?.can_manage ?? false;
  if (!canManage && rooms.length === 0) return null;

  const add = () => {
    const n = Number(seats);
    create.mutate(
      {
        name: name.trim(),
        kind,
        capacity: seats && Number.isInteger(n) && n > 0 ? n : undefined,
        location: where.trim() || undefined,
      },
      {
        onSuccess: () => {
          setName("");
          setSeats("");
          setWhere("");
          notify.done("Room added");
        },
        onError: (e) => notify.failed(roomError(e)),
      },
    );
  };

  return (
    <section className="mt-ax-6">
      <p className="ax-eyebrow">Rooms & resources</p>
      <p className="ax-caption mt-ax-1 text-muted-foreground">
        A booked room shows on the meeting and can't be double-booked. Rooms never receive email.
      </p>
      {rooms.length > 0 && (
        <ul className="mt-ax-3 flex flex-col gap-2">
          {rooms.map((r) => (
            <li
              key={r.id}
              className="flex items-center gap-2 rounded-lg border border-border px-ax-3 py-2"
            >
              <DoorOpen className="size-4 shrink-0 text-muted-foreground" aria-hidden />
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm">{r.name}</p>
                <p className="ax-caption truncate text-muted-foreground">
                  {[
                    r.kind === "resource" ? "Resource" : "Room",
                    r.capacity ? `${r.capacity} seats` : null,
                    r.location,
                  ]
                    .filter(Boolean)
                    .join(" · ")}
                </p>
              </div>
              {canManage && (
                <Button
                  size="icon"
                  variant="ghost"
                  aria-label={`Remove ${r.name}`}
                  disabled={archive.isPending}
                  onClick={() =>
                    archive.mutate(
                      { id: r.id },
                      {
                        onSuccess: () => notify.done("Room removed"),
                        onError: (e) => notify.failed(roomError(e)),
                      },
                    )
                  }
                >
                  <Trash2 className="size-4" aria-hidden />
                </Button>
              )}
            </li>
          ))}
        </ul>
      )}
      {canManage && rooms.length < MAX_ROOMS && (
        <form
          className="mt-ax-3 flex flex-wrap items-end gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            if (name.trim()) add();
          }}
        >
          <Input
            value={name}
            maxLength={60}
            placeholder="Name, e.g. Board room"
            aria-label="Room name"
            onChange={(e) => setName(e.target.value)}
            className="h-9 min-w-[10rem] flex-1 text-base sm:text-sm"
          />
          <Input
            value={seats}
            inputMode="numeric"
            maxLength={5}
            placeholder="Seats"
            aria-label="Seats"
            onChange={(e) => setSeats(e.target.value.replace(/\D/g, ""))}
            className="h-9 w-20 text-base sm:text-sm"
          />
          <Input
            value={where}
            maxLength={120}
            placeholder="Where (optional)"
            aria-label="Where"
            onChange={(e) => setWhere(e.target.value)}
            className="h-9 min-w-[8rem] flex-1 text-base sm:text-sm"
          />
          <select
            value={kind}
            aria-label="Type"
            onChange={(e) => setKind(e.target.value as "room" | "resource")}
            className="h-9 rounded-md border border-border bg-background px-2 text-base sm:text-sm"
          >
            <option value="room">Room</option>
            <option value="resource">Resource</option>
          </select>
          <Button type="submit" size="sm" disabled={!name.trim() || create.isPending}>
            {create.isPending ? <Loader2 className="size-3.5 animate-spin" aria-hidden /> : "Add"}
          </Button>
        </form>
      )}
    </section>
  );
}
