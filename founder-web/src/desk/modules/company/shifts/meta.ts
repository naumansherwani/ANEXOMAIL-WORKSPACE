import type { DeskModule } from "../../types";
/** Shifts: Shift hours, capacity, leave; office IP list. Planned in phase ON10; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "shifts",
  "group": "Company",
  "label": "Shifts",
  "what": "Shift hours, capacity, leave; office IP list",
  "tech": "Postgres (AD2 fadm_shift, fadm_ip_allow), Rust",
  "phase": "ON10",
  "founderSource": null,
  "status": "planned"
};
