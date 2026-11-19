# RESERVED FOR ANEXOCHAT = AWAM SIDE (his 01:52: all done D1 + D2 work stays intact, only the motion + its related advanced work goes to AnexoChat for awam) (his word 20 Nov 2026 01:50 PKT: 'rehne do, yeh anexochat ke liye reserve kero'). NOT mounted anywhere; not bundled. Motion version of the ':' shortcode list (motion/react: list fades + rises 6 px in 0.14 s, one shared-layout highlight pill springs row to row, reduced motion = none) + its CSS. Proven in real Chromium 20 Nov 01:50 (opacity 0.73 -> 1.0, pill 100 -> 144 px; reduce = instant). Use it when the AnexoChat message box gets the emoji box (AWAM-BLUEPRINT QC1e 'where else').

## EmojiShortcodeList (replace the plain one in EmojiShortcode.tsx)
```tsx
/** The list. Put it inside the .emo-over wrapper, next to EmojiDock. Motion = the same engine as the picker (motion/react): the list fades and rises 6 px (0.14 s), and the highlight is ONE shared-layout pill that springs from row to row. Reduced motion (the OS or the app's Animations setting) = no movement at all. */
export function EmojiShortcodeList({ sc }: { sc: Shortcode }) {
  const reduce = useReducedMotion(), hl = { type: "spring" as const, stiffness: 520, damping: 42, mass: 0.6 };
  return (
    <>
      <AnimatePresence initial={false}>
        {sc.open && (
          <motion.ul key="l" className="emo-sc" id={sc.listId} role="listbox" aria-label="Emoji suggestions" style={{ transformOrigin: "bottom left" }}
            initial={reduce ? false : { opacity: 0, y: 6, scale: 0.98 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={reduce ? { opacity: 0, transition: { duration: 0 } } : { opacity: 0, y: 4, scale: 0.98 }} transition={{ duration: 0.14, ease: [0.2, 0.8, 0.2, 1] }}>
            {sc.items.map((it, i) => (
              <li key={it.e.hexcode} id={`${sc.listId}-${i}`} role="option" aria-selected={i === sc.active} className="emo-sc-i" onMouseEnter={() => sc.setActive(i)} onMouseDown={(ev) => { ev.preventDefault(); sc.pick(i); }}>
                {i === sc.active && <motion.span layoutId={`${sc.listId}-hl`} className="emo-sc-hl" aria-hidden="true" transition={reduce ? { duration: 0 } : hl} />}
                <span className="emo-sc-g" aria-hidden="true">{it.unicode}</span><span className="emo-sc-n">{it.label}</span>
              </li>
            ))}
          </motion.ul>
        )}
      </AnimatePresence>
      {sc.open && <p className="sr" role="status" aria-live="polite">{sc.items.length} emoji suggestions</p>}
    </>
  );
}
```

## CSS (replace .emo-sc-i / .emo-sc-i.on / .emo-sc-g / .emo-sc-n in emoji.css)
```css
.emo-sc-i{position:relative;display:flex;align-items:center;gap:10px;min-height:44px;padding:0 10px;border-radius:10px;cursor:pointer;font-size:14px;color:inherit}
.emo-sc-hl{position:absolute;inset:0;border-radius:10px;background:rgba(43,136,216,.22);z-index:0}
.emo-sc-g{position:relative;z-index:1;font-size:22px;line-height:1;flex:none}.emo-sc-n{position:relative;z-index:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
```
