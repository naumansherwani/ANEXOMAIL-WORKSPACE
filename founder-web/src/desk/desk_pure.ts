// ADMIN DESK (R3a1, 21 Nov 2026): pure helpers for the Desk pages (landing / adminlogin / dashboard). No browser APIs here, so they are unit-tested.
export const DESK_SESSION_KEY = "anexo.desk.session"; // own key: a founder session can never open the Desk and the reverse (own audience "desk", own origin)
export const DESK_HOST = "admindesk.anexomail.com";
export const DESK_LOGIN_PATH = "/desk/v1/auth/login"; // Rust door of R3a2 (owner identity SQL first); until it exists the page says so plainly

/** Which page the Desk shows for a path. Unknown paths go to the landing page (the Desk has exactly three pages). */
export function deskPage(path: string): "landing" | "adminlogin" | "dashboard" {
  const p = path.replace(/\/+$/, "") || "/";
  return p === "/adminlogin" ? "adminlogin" : p === "/dashboard" ? "dashboard" : "landing";
}
/** The dashboard needs a Desk session; without one the visitor is sent to /adminlogin. */
export function deskGuard(page: ReturnType<typeof deskPage>, hasSession: boolean): "stay" | "to_login" | "to_dashboard" {
  if (page === "dashboard" && !hasSession) return "to_login";
  if (page === "adminlogin" && hasSession) return "to_dashboard";
  return "stay";
}
/** Plain words for the login answer. 404/405 = the Desk door is not on the server yet (honest, never a fake sign-in). */
export function deskLoginMessage(status: number): string {
  if (status === 404 || status === 405) return "Admin Desk sign-in is not connected on the server yet.";
  if (status === 401 || status === 403) return "That email and password did not match.";
  if (status === 423 || status === 429) return "Too many attempts. Wait a little and try again.";
  if (status === 0) return "Cannot reach the server. Check your connection and try again.";
  return "Sign-in did not complete. Try again.";
}
