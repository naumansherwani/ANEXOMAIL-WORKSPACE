import { expect, test } from "bun:test";
import { deskGuard, deskLoginMessage, deskPage } from "./desk_pure";
test("three pages, unknown goes to landing", () => {
  expect(deskPage("/")).toBe("landing"); expect(deskPage("/adminlogin")).toBe("adminlogin"); expect(deskPage("/adminlogin/")).toBe("adminlogin");
  expect(deskPage("/dashboard")).toBe("dashboard"); expect(deskPage("/dashboard/alerts")).toBe("dashboard"); expect(deskPage("/founderlogin")).toBe("landing"); expect(deskPage("/x/y")).toBe("landing");
});
test("dashboard needs a session, login with a session goes on", () => {
  expect(deskGuard("dashboard", false)).toBe("to_login"); expect(deskGuard("dashboard", true)).toBe("stay");
  expect(deskGuard("adminlogin", true)).toBe("to_dashboard"); expect(deskGuard("adminlogin", false)).toBe("stay"); expect(deskGuard("landing", false)).toBe("stay");
});
test("login messages are plain and honest", () => {
  expect(deskLoginMessage(404)).toContain("not connected"); expect(deskLoginMessage(401)).toContain("did not match");
  expect(deskLoginMessage(429)).toContain("Too many"); expect(deskLoginMessage(0)).toContain("Cannot reach");
});
