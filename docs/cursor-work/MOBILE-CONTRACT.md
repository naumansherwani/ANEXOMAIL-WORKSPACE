# MOBILE CONTRACT — phone + tablet ek hi baar theek (founder 23 Oct 2026, "billion mobile users, bar bar fix nahi")

Rule 19/34 ka amali roop. Har UI badlav in sab par khara utre, tab hi GREEN.

## Naap
| Device | Width | Content | Layout |
|---|---|---|---|
| Phone | 390 (aur 360 bhi) | ~342–358 | EK column |
| Tablet | 820 | ~772–788 | DO column (rail + content), app jaisa, "mobile stretched" nahi |
| Laptop | 1200–1440 | 1100–1400 | poora |

## Qaide (code mein)
1. **Koi horizontal page-scroll nahi.** Har toolbar/row `flex-wrap` ya `min-w-0`; nowrap row kabhi nahi jo bade font par page chauda kar de. `ListPanel` body `overflow-x-hidden` + phone par `w-full`.
2. **Touch >= 44 px** (`ax-tap`); phone par toolbar ke secondary buttons "⋯" menu mein (CalendarClassic misal).
3. **Input 16 px** (styles.css), `100dvh`, safe-area, keyboard khule to action button na chhupe.
4. **Zoom:** viewport mein `maximum-scale`/`user-scalable=no` KABHI nahi — pinch-zoom hamesha. App ke gesture (pull-to-refresh) zoomed halat mein band (`visualViewport.scale > 1.02`).
5. **Text size** (Settings -> Appearance, `lib/text-size.ts`): 90/100/115/130/150%, html font-size + px-literal text (`text-[11px]` ...) ka override `html[data-ax-ts]`. Naya px-size (text-[Npx], N pehle se list mein nahi) ho to styles.css ki list mein jodo. CSS `zoom` KABHI nahi (popover khisak jate hain — live test 23 Oct).
5b. **In-context zoom — SIRF jahan zaroorat (founder 23 Oct):** mail padhne ki body (A−/A+, `READ_ZOOM`) aur calendar Week/Day ghante ki unchai (`GRID_HOUR`). `lib/zoom-prefs.ts` + `ZoomButtons`. Baaqi screens (dashboard, lists, settings, forms) par zoom control NAHI — wahan Text size + pinch kaafi. Naya zoom control jodne se pehle poochho: "kya yeh content dense/lamba hai?"
6. **Pull-to-refresh:** `PullRefresh.tsx` — sirf data taza, reload nahi (draft salamat). Browser ka PTR shell mein band.
7. **Scroll bar:** touch screens par patla, theme-rang ka dikhta hai (styles.css `@media (pointer: coarse)`).
8. Tablet par jahan do column ho sakte hain wahan phone ka single-column nahi (ListPanel `stackBelow="lg"` ya `md:flex-row`).

## Check (har badlav)
- Chrome mein same-origin iframe 360 / 390 / 820 / 1440: `documentElement.scrollWidth == clientWidth` aur koi element `right > width`.
- Ek baar `html[data-ax-ts=130]` laga kar dekho (text bada, layout na toote).
- Founder ka phone screenshot final saboot (uska font/size alag ho sakta hai — 23 Oct: bade phone font par nowrap row ne page chauda kiya).

## Itihas
- 23 Oct: nowrap rows -> wrap; Panel w-full; CalendarClassic phone toolbar; PullRefresh; Text size; scrollbar.
