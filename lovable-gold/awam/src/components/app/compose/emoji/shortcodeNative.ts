// QC1e-D2 awam glue (20 Nov 2026). The awam message box is GhostTextArea (CORE-FREEZE, takes no extra props), so the ":" shortcode hook is attached to the real <textarea> with native listeners instead.
// keydown runs in the CAPTURE phase on the textarea itself: when the list is open, Enter / Tab / Arrows / Escape are ours and stopped there (the ghost-text Tab and the compose Escape never see them); list closed = nothing is touched.
import { useEffect, useRef } from "react";
import type { Shortcode } from "./EmojiShortcode";

export function useShortcodeNative(area: React.RefObject<HTMLTextAreaElement | null>, sc: Shortcode): void {
  const live = useRef(sc); live.current = sc;
  useEffect(() => {
    const t = area.current; if (!t) return;
    const kd = (ev: KeyboardEvent) => { (ev as unknown as { nativeEvent: KeyboardEvent }).nativeEvent = ev; live.current.bind.onKeyDown(ev as unknown as React.KeyboardEvent<HTMLTextAreaElement>); };
    const ku = () => live.current.bind.onKeyUp(), ck = () => live.current.bind.onClick(), bl = () => live.current.bind.onBlur();
    const cs = () => live.current.bind.onCompositionStart(), ce = () => live.current.bind.onCompositionEnd();
    t.addEventListener("keydown", kd, true); t.addEventListener("keyup", ku); t.addEventListener("click", ck); t.addEventListener("blur", bl); t.addEventListener("compositionstart", cs); t.addEventListener("compositionend", ce);
    return () => { t.removeEventListener("keydown", kd, true); t.removeEventListener("keyup", ku); t.removeEventListener("click", ck); t.removeEventListener("blur", bl); t.removeEventListener("compositionstart", cs); t.removeEventListener("compositionend", ce); };
  }, [area]);
  useEffect(() => {
    const t = area.current; if (!t) return; const b = sc.bind;
    t.setAttribute("aria-autocomplete", "list"); t.setAttribute("aria-expanded", String(b["aria-expanded"]));
    if (b["aria-controls"]) t.setAttribute("aria-controls", b["aria-controls"]); else t.removeAttribute("aria-controls");
    if (b["aria-activedescendant"]) t.setAttribute("aria-activedescendant", b["aria-activedescendant"]); else t.removeAttribute("aria-activedescendant");
  });
}
