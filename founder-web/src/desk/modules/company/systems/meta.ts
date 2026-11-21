import type { DeskModule } from "../../types";
/** Systems: Per-tenant health, capacity and speed. Planned in phase R5b; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "systems",
  "group": "Company",
  "label": "Systems",
  "what": "Per-tenant health, capacity and speed",
  "tech": "Rust probes, Postgres",
  "phase": "R5b",
  "founderSource": "Systems",
  "status": "planned"
};
