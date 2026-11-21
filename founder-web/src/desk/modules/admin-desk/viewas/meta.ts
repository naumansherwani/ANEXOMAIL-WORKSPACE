import type { DeskModule } from "../../types";
/** View as user: Look at a user's account with his consent, time-boxed, read-only, loud in the ledger. Planned in phase R5c; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "viewas",
  "group": "Admin Desk",
  "label": "View as user",
  "what": "Look at a user's account with his consent, time-boxed, read-only, loud in the ledger",
  "tech": "Relation tuples (JIT), two-person rule, hash ledger",
  "phase": "R5c",
  "founderSource": null,
  "status": "planned"
};
