import type { DeskModule } from "../../types";
/** People: Organisations, users, devices and permissions: metadata only, never message content. Planned in phase R5a; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "people",
  "group": "Admin Desk",
  "label": "People",
  "what": "Organisations, users, devices and permissions: metadata only, never message content",
  "tech": "Rust, Postgres RLS, signed read doors",
  "phase": "R5a",
  "founderSource": "People",
  "status": "planned"
};
