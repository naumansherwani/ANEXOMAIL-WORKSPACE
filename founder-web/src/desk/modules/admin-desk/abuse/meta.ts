import type { DeskModule } from "../../types";
/** Abuse and safety: Spam and abuse reports, blocks, review queue. Planned in phase R5e; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "abuse",
  "group": "Admin Desk",
  "label": "Abuse and safety",
  "what": "Spam and abuse reports, blocks, review queue",
  "tech": "Rust, Postgres, ClamAV for files",
  "phase": "R5e",
  "founderSource": null,
  "status": "planned"
};
