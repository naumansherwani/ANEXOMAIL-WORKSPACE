import type { DeskModule } from "../../types";
/** Plans: Which plan a company is on and what it entitles (support lane, response hours, priority). Planned in phase R3p; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "plans",
  "group": "Admin Desk",
  "label": "Plans",
  "what": "Which plan a company is on and what it entitles (support lane, response hours, priority)",
  "tech": "Signed Polar webhook receiver (HMAC), Postgres fadm_plans",
  "phase": "R3p",
  "founderSource": null,
  "status": "planned"
};
