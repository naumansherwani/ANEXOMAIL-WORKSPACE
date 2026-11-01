# Founder vs awam Settings Center — side-by-side check (1 Nov 2026, 12:40 PKT)
Method: both accounts open in the founder's Chrome (awam https://anexomail.com/app/settings/*, founder https://founderworkspace.anexomail.com/#/settings), every tab read as text and looked at in a screenshot. Founder side was hard-reloaded (service worker + cache cleared) so the check is of the installed S1c/S1d build.

## Matches (no action)
All 15 awam rows exist on the founder side with Explain / Blast radius / History; Appearance has both blocks plus Ambient Studio; Time machine lists all 22 keys with human names; Drift measures 11 items (awam: 13 — different baselines by design); Schedule form offers all 14 schedulable keys. Real write test (Block tracking pixels on→off→on) saved, blast radius real, ledger entries proven in the browser.

## Mistakes found (each gets a fix in S1e)
| # | Where | What is wrong | Fix |
|---|---|---|---|
| M1 | Personal tab | Awam's FIRST row is "Display name" (with Explain / Blast radius / History). The founder Personal tab has no such row: the name is only editable on the separate Profile page, so Drift shows "Display name is set — Looser than baseline" while the profile shows a name (it comes from the account, not from the saved setting). | Display name row inside Personal (same door `personal.display_name`, same RowTools). |
| M2 | Settings left list | Item text starts at different x positions (Personal 383, Workspace 378, Appearance 380 …): the icon boxes shrink with the text. Looks unfinished next to the cinematic look. | Fixed icon box (flex 0 0 18px), text column aligned. |
| M3 | Live test limit | The browser tool cannot resize the real Chrome viewport (innerWidth stays 1536), so 820 / 390 are proven only in the local harness, not in the real browser. | Not a code bug. Stated honestly; the founder checks his phone / tablet, I do not claim it. |
| M4 | Drift list | Display name drift (M1) is the only non-aligned item, so the score shows 95. After M1 the founder can resolve it from Personal. | Follows from M1. |
| M5 | Founder's own account | My live write test left Animations = Reduced (his own toggle at 12:26) and Block tracking pixels toggled twice. Both are in the Time machine and undoable. | Reported, not touched. |

## Deliberate differences (not mistakes)
Founder left-list layout and cinematic look vs awam top tabs; AI settings placeholder (step 16, Rule 71); Ambient Studio; ledger entry + browser proof on every version; no Drift baseline for choices (undo window, retention, only-VIPs).
