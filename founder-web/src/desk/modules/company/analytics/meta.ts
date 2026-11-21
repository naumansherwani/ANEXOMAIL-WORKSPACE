import type { DeskModule } from "../../types";
/** Analytics: Real KPIs only: first response, resolution time, backlog, reopen rate, per team. Planned in phase R3g; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "analytics",
  "group": "Company",
  "label": "Analytics",
  "what": "Real KPIs only: first response, resolution time, backlog, reopen rate, per team",
  "tech": "Postgres views, Rust, Three.js light charts",
  "phase": "R3g",
  "founderSource": null,
  "status": "planned"
};
