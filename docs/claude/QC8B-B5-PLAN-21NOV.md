# QC8b b5 FORCED-COLORS + CONTRAST: plan, search points, code (his word 21 Nov 2026 05:21 PKT: "b5 web search deep, duniya ke advance codes nikal ke phir codes likho")
TECHNOLOGY: CSS @media (forced-colors: active) + (prefers-contrast: more), system colour keywords (Highlight, CanvasText), outline/border shapes instead of colour or shadow. NEW FILE founder-web/src/a11y_contrast.css (imported by my own KeyLayer.tsx). ZERO-MUTATION: only added rules; normal look measured unchanged.

## Search points (pages READ: MDN @media forced-colors, Firefox HCM CSS checklist, Chrome colour guide; others titles only)
1. forced-colors:active (MDN, Baseline widely available since Sept 2022): author colour, background-color, border-color, outline-color are replaced by system colours; box-shadow and text-shadow become none; non-url background-image becomes none; color-scheme forced to "light dark". forced-color-adjust:none opts an element out (only where colour IS the information).
2. Firefox HCM checklist: replace drop shadows with a 1px+ solid border; gradients/semi-opaque surfaces become solid; controls need a solid border of at least 1px; interactive SVG must use palette colours; selected and disabled states cannot rely on colour alone; a bare prefers-contrast query also hits HCM users; test on real Windows HCM.
3. Chrome colour guide: do not use background-image, box-shadow or border-image for borders or state, give an outline or border; use prefers-contrast:more only to reinforce accents that already meet minimum contrast; system keywords CanvasText / LinkText / ButtonText / Highlight / GrayText in forced-colors fallbacks. Advanced: color-mix() in oklab, relative colours in oklch (NOT used here: this step must not touch the normal look).
4. WCAG 1.4.1 Use of Colour and 1.4.11 Non-text Contrast: state (selected, unread, focus) must also be a shape.

## What is wrong today (repo audit, mailbox.css)
- .mbx-r.on = background + border colour only (line 71) -> vanishes in forced colours. - .mbx-dot = background colour only (line 75) -> forced to Canvas = invisible. - marked rows already fixed in keylayer.css. - No prefers-contrast rule in the mail list.
## Code
forced-colors: open row (class on or aria-current from b2) = 3px Highlight outline; unread dot = 4px CanvasText border (border-box, still 8px disc); row :focus-visible = 2px Highlight ring (double on the open row). prefers-contrast:more: 2px currentColor outline on open row, 3px focus ring, outlined dot, dashed outline on marked rows.
## Proof
Sandbox Playwright with REAL mailbox.css + keylayer.css + a11y_contrast.css: normal = outline none, dot border 0, dot bg unchanged (look identical); forced-colors emulation = outline solid 3px, dot border 4px solid, dot still 8px; contrast:more = outline solid 2px. LIVE in his Chrome: not possible without his Windows High Contrast; sandbox emulation = the proof, stated plainly.
