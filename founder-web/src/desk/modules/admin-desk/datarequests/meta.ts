import type { DeskModule } from "../../types";
/** Data requests: Export and delete requests with deadline clock and proof of completion. Planned in phase R5d; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "datarequests",
  "group": "Admin Desk",
  "label": "Data requests",
  "what": "Export and delete requests with deadline clock and proof of completion",
  "tech": "Rust jobs, Postgres, ledger",
  "phase": "R5d",
  "founderSource": null,
  "status": "planned"
};
