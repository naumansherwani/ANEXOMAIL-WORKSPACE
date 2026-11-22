import type { DeskModule } from "../../types";
/** Systems: Per-tenant health, capacity and speed. Live since phase D7 (22 Nov 2026): plain status for every employee; technical rows only for owner / admin / engineer. */
export const meta: DeskModule = {
  "key": "systems",
  "group": "Company",
  "label": "Systems",
  "what": "Is the Desk working? Plain status for every employee, with what to tell customers (Desk-own, not the Founder view)",
  "tech": "Rust probes, Postgres",
  "phase": "D7",
  "founderSource": "Systems",
  "status": "live"
};
