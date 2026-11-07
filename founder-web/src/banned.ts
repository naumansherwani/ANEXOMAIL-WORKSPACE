// Countries where ANEXOMAIL is not available (GEO1). Founder copy of banned-countries/banned.json (founder code never imports awam code, Rule 73); banned.test.ts fails on any drift.
export const BANNED = [
  { iso2: "AF", name: "Afghanistan", dial: "93" },
  { iso2: "IL", name: "Israel", dial: "972" },
  { iso2: "KP", name: "North Korea", dial: "850" },
  { iso2: "SY", name: "Syria", dial: "963" },
] as const;
export const BANNED_ISO = BANNED.map((b) => b.iso2) as readonly string[];
export const BANNED_DIALS = BANNED.map((b) => b.dial) as readonly string[];
