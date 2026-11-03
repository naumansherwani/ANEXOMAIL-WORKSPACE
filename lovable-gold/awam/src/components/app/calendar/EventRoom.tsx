import { DoorOpen, Loader2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { notify } from "@/lib/notify";
import { roomError, useBookRoom, useRoomState, useRooms } from "@/lib/rooms";

/**
 * Room on a meeting (calendar #8). Shows the rooms free for this time; the organiser books or releases one.
 * The server re-checks at the moment of booking, so two people can never get the same room at overlapping times.
 */
export function EventRoom({
  eventId,
  from,
  to,
  isOrganiser,
}: {
  eventId: string;
  from: string;
  to: string;
  isOrganiser: boolean;
}) {
  const rooms = useRooms();
  const has = (rooms.data?.rooms.length ?? 0) > 0;
  const state = useRoomState(from, to, eventId, has);
  const book = useBookRoom(eventId);

  // no rooms set up (or server without E82): say nothing
  if (rooms.isPending || rooms.error || !has) return null;

  const act = (room_id: string, release: boolean, name: string) =>
    book.mutate(
      { room_id, release },
      {
        onSuccess: (r) => {
          const over = (r as { over_capacity?: boolean } | undefined)?.over_capacity;
          notify.done(
            release
              ? `${name} released`
              : over
                ? `${name} booked (more guests than seats)`
                : `${name} booked`,
          );
        },
        onError: (e) => notify.failed(roomError(e)),
      },
    );

  return (
    <section className="mt-ax-6">
      <p className="ax-eyebrow">Room</p>
      {state.isPending ? (
        <p className="ax-caption mt-ax-2 text-muted-foreground">Checking rooms…</p>
      ) : (
        <ul className="mt-ax-2 flex flex-col gap-2">
          {(state.data?.rooms ?? []).map((r) => (
            <li
              key={r.id}
              className="flex items-center gap-2 rounded-lg border border-border px-ax-3 py-2"
            >
              <DoorOpen className="size-4 shrink-0 text-muted-foreground" aria-hidden />
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm">{r.name}</p>
                <p className="ax-caption truncate text-muted-foreground">
                  {[
                    r.kind === "resource" ? "Resource" : null,
                    r.capacity ? `${r.capacity} seats` : null,
                    r.location,
                  ]
                    .filter(Boolean)
                    .join(" · ") || " "}
                </p>
              </div>
              {r.mine ? (
                isOrganiser ? (
                  <Button
                    size="sm"
                    variant="outline"
                    disabled={book.isPending}
                    onClick={() => act(r.id, true, r.name)}
                  >
                    Release
                  </Button>
                ) : (
                  <span className="ax-caption text-muted-foreground">Booked</span>
                )
              ) : r.busy ? (
                <span className="ax-caption text-muted-foreground">Busy</span>
              ) : (
                isOrganiser && (
                  <Button
                    size="sm"
                    variant="outline"
                    disabled={book.isPending}
                    onClick={() => act(r.id, false, r.name)}
                  >
                    {book.isPending ? (
                      <Loader2 className="size-3.5 animate-spin" aria-hidden />
                    ) : (
                      "Book"
                    )}
                  </Button>
                )
              )}
            </li>
          ))}
        </ul>
      )}
      <p className="ax-caption mt-ax-2 text-muted-foreground">
        A room that shows Busy is held by another meeting at this time.
      </p>
    </section>
  );
}
