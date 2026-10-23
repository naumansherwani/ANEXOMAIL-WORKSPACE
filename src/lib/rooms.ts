/**
 * Rooms & resources (calendar #8) — client side of the Rust `calendar.rooms.*` procs (SQL E82).
 * A room is a pseudo-guest (room-xxxx@rooms.anexomail.com): booking it adds it to the meeting, and the same conflict engine then
 * refuses a second booking at an overlapping time. Rooms never receive mail. Owners/admins manage rooms; the organiser books them.
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpc } from "@/lib/rpc";

export type Room = {
  id: string;
  name: string;
  kind: "room" | "resource";
  capacity: number | null;
  location: string | null;
  address: string;
};
export type RoomState = Room & { busy: boolean; mine: boolean };

export const MAX_ROOMS = 200;
const ROOM_ADDR = /^room-[0-9a-f]{12}@rooms\.anexomail\.com$/i;

/** True for a room's pseudo address — keep it out of guest lists and mail. */
export function isRoomAddress(a: string): boolean {
  return ROOM_ADDR.test(a.trim());
}

/** Plain-language text for the server's error code. */
export function roomError(e: { code?: string; message?: string } | null | undefined): string {
  switch (e?.code) {
    case "room_busy":
      return "That room is already booked at this time. Pick another room or time.";
    case "name_taken":
      return "A room with that name already exists.";
    case "too_many":
      return `You can have up to ${MAX_ROOMS} rooms.`;
    case "forbidden":
      return "Only workspace owners and admins can manage rooms.";
    case "not_organiser":
      return "Only the organiser can change rooms on this meeting.";
    case "sql_missing":
      return "Rooms are not set up on the server yet.";
    default:
      return e?.message || "Could not complete that. Try again.";
  }
}

const KEY = ["rooms"] as const;

export function useRooms() {
  return useQuery<{ rooms: Room[]; can_manage: boolean }, ApiError>({
    queryKey: KEY,
    queryFn: () => rpc("calendar.rooms.list", {}),
    retry: false,
    staleTime: 30_000,
  });
}

export function useCreateRoom() {
  const qc = useQueryClient();
  return useMutation<
    unknown,
    ApiError,
    { name: string; kind: "room" | "resource"; capacity?: number; location?: string }
  >({
    mutationFn: (p) => rpc("calendar.rooms.create", p),
    onSuccess: () => void qc.invalidateQueries({ queryKey: KEY }),
  });
}

export function useArchiveRoom() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { id: string }>({
    mutationFn: (p) => rpc("calendar.rooms.archive", p),
    onSuccess: () => void qc.invalidateQueries({ queryKey: KEY }),
  });
}

/** Which rooms are free for this meeting's time (its own booking never counts as busy). */
export function useRoomState(from: string, to: string, excludeEvent: string, enabled: boolean) {
  return useQuery<{ rooms: RoomState[] }, ApiError>({
    queryKey: ["rooms", "state", from, to, excludeEvent],
    queryFn: () => rpc("calendar.rooms.state", { from, to, exclude_event: excludeEvent }),
    enabled,
    retry: false,
    staleTime: 10_000,
  });
}

export function useBookRoom(eventId: string) {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { room_id: string; release?: boolean }>({
    mutationFn: ({ room_id, release }) =>
      rpc(release ? "calendar.rooms.release" : "calendar.rooms.book", {
        event_id: eventId,
        room_id,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["rooms", "state"] });
      void qc.invalidateQueries({ queryKey: ["calendar"] });
      void qc.invalidateQueries({ queryKey: ["calendar", "guests"] });
    },
  });
}
