/**
 * Text size (phone/tablet/laptop) — "zoom kitna chaiye" user khud chunta hai, har device par yaad rehta hai.
 *
 * Kyun CSS `zoom` nahi: poore app par zoom lagane se popover/dropdown apni jagah se hat jate hain (live test 23 Oct: world-clock card kone mein khula).
 * Isliye: html ka font-size (rem wali sab cheezein) + `--ax-ts` jo styles.css mein px-literal text (text-[11px] jaisa, 800+ jagah) ko bhi scale karta hai.
 * Default (100%) par kuch nahi lagta — `data-ax-ts` attribute hi nahi. Pinch-zoom alag cheez hai aur hamesha chalta hai.
 */
import { useCallback, useEffect, useState } from "react";

export const TEXT_SIZES = [90, 100, 115, 130, 150] as const;
export type TextSize = (typeof TEXT_SIZES)[number];
export const TEXT_SIZE_KEY = "ax.textSize";

export function cleanTextSize(v: unknown): TextSize {
  const n = typeof v === "string" ? Number(v) : typeof v === "number" ? v : NaN;
  return (TEXT_SIZES as readonly number[]).includes(n) ? (n as TextSize) : 100;
}

export function readTextSize(): TextSize {
  try {
    return cleanTextSize(window.localStorage.getItem(TEXT_SIZE_KEY));
  } catch {
    return 100;
  }
}

/** <html> par lagao. 100 = kuch nahi (attribute + variable hata do). */
export function paintTextSize(size: TextSize, el: HTMLElement = document.documentElement) {
  if (size === 100) {
    el.removeAttribute("data-ax-ts");
    el.style.removeProperty("--ax-ts");
    return;
  }
  el.setAttribute("data-ax-ts", String(size));
  el.style.setProperty("--ax-ts", String(size / 100));
}

export function useTextSize() {
  const [size, setSize] = useState<TextSize>(100);

  useEffect(() => {
    const s = readTextSize();
    setSize(s);
    paintTextSize(s);
    const onStorage = () => {
      const n = readTextSize();
      setSize(n);
      paintTextSize(n);
    };
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, []);

  const set = useCallback((next: TextSize) => {
    try {
      window.localStorage.setItem(TEXT_SIZE_KEY, String(next));
    } catch {
      /* private mode — is tab ke liye chalega */
    }
    setSize(next);
    paintTextSize(next);
  }, []);

  return [size, set] as const;
}
