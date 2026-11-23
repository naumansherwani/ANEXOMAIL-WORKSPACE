// ADMIN DESK boot / loading screen (22 Nov 2026, his word: "loading anexomail original logo ke saath aur admin desk"). Same look as desk.html's static boot, so the
// hand-over from the browser-painted screen to React is invisible. Desk-own copy of the founder boot pattern (never imported). Pure presentation, no data, no network.
export function DeskBoot() {
  return (
    <div className="boot" role="status" aria-label="Loading ANEXOMAIL Command Center OS">
      <svg viewBox="0 0 64 64" aria-hidden="true"><defs>
<linearGradient id="ba" x1="12" y1="4" x2="54" y2="60"><stop offset="0%" stopColor="oklch(0.50 0.098 258)"/><stop offset="100%" stopColor="oklch(0.295 0.066 258)"/></linearGradient>
<linearGradient id="bb" x1="20" y1="18" x2="46" y2="46"><stop offset="0%" stopColor="oklch(0.375 0.080 258)"/><stop offset="100%" stopColor="oklch(0.245 0.052 258)"/></linearGradient>
<linearGradient id="be" x1="4" y1="4" x2="60" y2="60"><stop offset="0%" stopColor="oklch(0.975 0.004 250)"/><stop offset="60%" stopColor="oklch(0.80 0.012 252)"/><stop offset="100%" stopColor="oklch(0.60 0.016 253)"/></linearGradient></defs>
<path d="M32 4 L61 59 L45.5 59 L32 32 L18.5 59 L3 59 Z" fill="url(#ba)" stroke="url(#be)" strokeWidth="1.6" strokeLinejoin="miter"/>
<path d="M32 19 L43 41 L21 41 Z" fill="url(#bb)" stroke="url(#be)" strokeWidth="1.3" strokeLinejoin="miter"/>
<path d="M9 52 L56 33" stroke="url(#be)" strokeWidth="1.1" strokeLinecap="round" opacity=".9"/>
<circle cx="15" cy="49.6" r="2.4" fill="oklch(0.975 0.004 250)"/><circle cx="32" cy="42.7" r="2.4" fill="oklch(0.975 0.004 250)"/><circle cx="50" cy="35.4" r="2.4" fill="oklch(0.975 0.004 250)"/></svg>
      <b>ANEXOMAIL</b><small>COMMAND CENTER OS</small><div className="bar"><i /></div>
    </div>
  );
}
