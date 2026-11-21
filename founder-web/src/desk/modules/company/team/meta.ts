import type { DeskModule } from "../../types";
/** Team: Staff accounts, joiner, mover, leaver, recovery, access review. Planned in phase ON1-ON8; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "team",
  "group": "Company",
  "label": "Team",
  "what": "Staff accounts, joiner, mover, leaver, recovery, access review",
  "tech": "Rust, webauthn-rs, AD2 SQL (live)",
  "phase": "ON1-ON8",
  "founderSource": null,
  "status": "planned"
};
