// Founder-only port of src/components/site/BrandMark.tsx (FC18: same real logo, awam file untouched).
import { useId } from "react";

export function Brand() {
  const u = useId().replace(/[^a-zA-Z0-9]/g, "");
  const gA = `fa${u}`, gB = `fb${u}`, gE = `fe${u}`;
  return (
    <a className="brand-lockup" href="/app" aria-label="ANEXOMAIL Workspace">
      <svg viewBox="0 0 64 64" role="img" aria-label="ANEXOMAIL Workspace" width="32" height="32">
        <defs>
          <linearGradient id={gA} x1="12" y1="4" x2="54" y2="60"><stop offset="0%" stopColor="oklch(0.50 0.098 258)" /><stop offset="100%" stopColor="oklch(0.295 0.066 258)" /></linearGradient>
          <linearGradient id={gB} x1="20" y1="18" x2="46" y2="46"><stop offset="0%" stopColor="oklch(0.375 0.080 258)" /><stop offset="100%" stopColor="oklch(0.245 0.052 258)" /></linearGradient>
          <linearGradient id={gE} x1="4" y1="4" x2="60" y2="60"><stop offset="0%" stopColor="oklch(0.975 0.004 250)" /><stop offset="60%" stopColor="oklch(0.80 0.012 252)" /><stop offset="100%" stopColor="oklch(0.60 0.016 253)" /></linearGradient>
        </defs>
        <path d="M32 4 L61 59 L45.5 59 L32 32 L18.5 59 L3 59 Z" fill={`url(#${gA})`} stroke={`url(#${gE})`} strokeWidth="1.6" strokeLinejoin="miter" />
        <path d="M32 19 L43 41 L21 41 Z" fill={`url(#${gB})`} stroke={`url(#${gE})`} strokeWidth="1.3" strokeLinejoin="miter" />
        <path d="M9 52 L56 33" stroke={`url(#${gE})`} strokeWidth="1.1" strokeLinecap="round" opacity="0.9" />
        <circle cx="15" cy="49.6" r="2.4" fill="oklch(0.975 0.004 250)" /><circle cx="32" cy="42.7" r="2.4" fill="oklch(0.975 0.004 250)" /><circle cx="50" cy="35.4" r="2.4" fill="oklch(0.975 0.004 250)" />
      </svg>
      <span className="wm"><b>ANEXOMAIL</b><span aria-hidden="true">{"WORKSPACE".split("").map((c, i) => <i key={i}>{c}</i>)}</span></span>
    </a>
  );
}

const P = {
  bridge: "M3 12l9-8 9 8M5 10v10h14V10",
  finance: "M4 19V9M10 19V5M16 19v-7M22 19H2",
  people: "M2.5 20c.8-3.5 3.4-5 6.5-5s5.7 1.5 6.5 5M17 11a3 3 0 1 0 0-6M18 15c2 .4 3.4 1.9 3.8 4M9 4.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7z",
  mail_desk: "M5 5h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2zM3 7l9 6 9-6",
  release: "M12 3c4 2 6 6 5 11l-5 5-5-5c-1-5 1-9 5-11zM9 19l-3 2M15 19l3 2",
  move_in: "M4 12h12M12 6l6 6-6 6M20 4v16",
  systems: "M4 4h16a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zM4 14h16a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-4a1 1 0 0 1 1-1zM7 7h.01M7 17h.01",
  control: "M4 7h10M18 7h2M4 17h2M10 17h10M16 5a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM8 15a2 2 0 1 0 0 4 2 2 0 0 0 0-4z",
  ai: "M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8zM19 16l.7 2 2 .7-2 .7-.7 2-.7-2-2-.7 2-.7z",
  audit: "M6 3h9l4 4v14H6zM14 3v5h5M9 13h7M9 17h7",
};
export const Icon = ({ k }) => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={P[k] || P.bridge} /></svg>
);
