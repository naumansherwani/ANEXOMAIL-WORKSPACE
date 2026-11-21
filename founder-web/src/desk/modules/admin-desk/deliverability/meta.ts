import type { DeskModule } from "../../types";
/** Deliverability: Bounces, complaints, DKIM/SPF/DMARC, MTA-STS and DANE health per company. Planned in phase R4-10; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "deliverability",
  "group": "Admin Desk",
  "label": "Deliverability",
  "what": "Bounces, complaints, DKIM/SPF/DMARC, MTA-STS and DANE health per company",
  "tech": "Rust, DNS, Postgres",
  "phase": "R4-10",
  "founderSource": "Mail Desk",
  "status": "planned"
};
