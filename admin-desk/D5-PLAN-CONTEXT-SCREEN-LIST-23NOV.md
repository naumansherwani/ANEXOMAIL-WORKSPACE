# 1j D5 PLAN CONTEXT SCREEN, POINT LIST (23 Nov 2026 03:1x PKT). Written BEFORE code, from web research + D5-SUBPHASES-22NOV.md + PLAN-CONTEXT-AND-RUNBOOKS-22NOV.md
Sources read: saasui.design usage-quota UX patterns, kinde.com usage dashboards and caps/alerts UX, Zuora entitlements view, Reltio entitlement and usage summary, Workday consumption console (links in the chat reply).
Order lock: 1j is NOW; 1k..1o follow; nothing here changes the order.

| # | Point (what the screen does) | From | Advance technology next to it |
|---|---|---|---|
| P1 | Employee types a REASON first (min length), then the lookup runs. No reason, no call (audit-first). | D5 design, audit law | React 19 form + deskLookup (Rule 52 kernel seals the request) |
| P2 | Package name + version + effective-from in one header line. | contract fields | kernel-verified fields only |
| P3 | Included vs ACTUALLY enabled features side by side; a feature included but not enabled (or enabled but not included) is marked in words, not colour only. | Zuora/Reltio entitlement vs usage | pure diff function, unit-tested |
| P4 | Usage bars (storage, seats, attachment): number + percent + words; 90% = "Near limit" (yellow), 95% = "Almost full" (high); never a block; role=progressbar with aria-valuenow. | saasui, kinde | pure threshold function, Tailwind 4 tokens, Framer Motion bar (reduced-motion aware) |
| P5 | Service state chip with icon + words: Active / Not active yet / Grace period / Suspended / Setting up, plus "since when". | D5 design | pure state map (5 states), unit-tested |
| P6 | One finance-safe flag: "payment received, service not active" with its start time; no amount, card or invoice anywhere. | D5 design, NO-MONEY gate | contract field only, gate-checked |
| P7 | Freshness line on the screen: "Data as of HH:MM:SS (N s ago)", ticks every second; after 15 s it says "Older than 15 s, look up again" and the numbers are greyed, never silently kept. | kinde stale-data guidance, 1i fresh 15 s | kernel lookup_view freshness + pure age function |
| P8 | Data unavailable / refused / frozen shown in plain words ("Data unavailable"); old data is cleared the moment a new lookup starts or fails. | 1i fail-closed | LookupState from deskLookup |
| P9 | SLA target shown beside the plan, plain words. | D5 design | contract field |
| P10 | One build for 390 / 820 / 1200+ (cards stack, bars full width, 44 px targets, no sideways scroll). Keyboard: Enter submits, focus goes to result heading. | Rule 34 + 19, a11y | CSS grid minmax/clamp, no JS size switch |
| P11 | The card "plans" on the Dashboard flips wired:true; route /dashboard/plans opens this screen (History API, registry-driven). | existing registry | desk_cards.ts one-line flip, test updated |
| P12 | No phase names ("P1", "1j") in employee-visible text. | standing law | text test |

Tests required before commit: pure functions (diff, thresholds, state map, age) bun tests; component render at three widths in the harness; tsc clean; gates. Then hostile audit, then ONE install line, then my Chrome look (signed-in session if present), then GREEN.

## AUDIT + AUTOFIX (23 Nov 03:2x PKT, his order "ek bhi nahi chodo")
Loopholes found and closed in code (each has a test): L1 a stale answer stayed on screen greyed -> now REMOVED after 15 s (same law as the server); L2 an old company's answer stayed while typing another company -> result cleared on company change; L3 answer did not say which company -> company shown in the heading; L4 button could hammer the Control Plane -> 3 s cooldown; L5 "not known of 100" for attachment size -> shows "limit 100"; L6 raw SR code -> "Reason class SRn" (classes are a draft until he approves the words; shown as the code only).
Research points added beyond P1-P12: stale removal not dimming (kinde stale-data guidance), answer bound to its company (Zuora/Reltio per-tenant views), caps shown as information not a block (saasui), cooldown to protect the source.
Still open, said plainly: signed-in live look after install; SR class words wait for his approval; Framer Motion not used yet.
