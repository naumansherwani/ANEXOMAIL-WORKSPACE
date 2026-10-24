import { describe, expect, it } from "vitest";

import { isRoomAddress, roomError, withoutRooms } from "./rooms";

describe("rooms", () => {
  it("recognises only real room addresses", () => {
    expect(isRoomAddress("room-0123456789ab@rooms.anexomail.com")).toBe(true);
    expect(isRoomAddress(" ROOM-0123456789AB@rooms.anexomail.com ")).toBe(true);
    expect(isRoomAddress("room-0123456789ab@evil.com")).toBe(false);
    expect(isRoomAddress("someone@rooms.anexomail.com")).toBe(false);
  });
  it("explains a busy room in plain words", () => {
    expect(roomError({ code: "room_busy" })).toMatch(/already booked/);
    expect(roomError({ message: "x" })).toBe("x");
    expect(roomError(null)).toMatch(/Try again/);
  });
  it("never lists a room as a guest", () => {
    const rows = [{ address: "a@x.com" }, { address: "room-0123456789ab@rooms.anexomail.com" }];
    expect(withoutRooms(rows)).toEqual([{ address: "a@x.com" }]);
    const clean = [{ address: "a@x.com" }];
    expect(withoutRooms(clean)).toBe(clean);
  });
});
