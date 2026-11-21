import type { DeskModule } from "../../types";
/** Policy: Who may do what: permits, forbids, AAGUID hardware list, break-glass. Planned in phase ON9; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "policy",
  "group": "Company",
  "label": "Policy",
  "what": "Who may do what: permits, forbids, AAGUID hardware list, break-glass",
  "tech": "Postgres policy engine (AD2), Rust",
  "phase": "ON9",
  "founderSource": null,
  "status": "planned"
};
