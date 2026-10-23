/**
 * Pull-to-refresh (phone) — app ka apna, browser ka nahi.
 *
 * Browser ka pull-to-refresh poora page reload karta tha (likha hua draft kho jata tha), isliye shell mein woh band hai (overscroll-behavior: none).
 * Yeh uski jagah: upar se neeche kheencho -> sirf DATA taza hota hai (queries refetch), page reload NAHI, draft salamat.
 * Sirf touch par, sirf jab har scroll dabba sabse upar ho, aur kabhi text likhte waqt / dialog ke andar nahi.
 */

export const PULL_THRESHOLD = 72; // px (damped) jis ke baad chhodne par refresh
export const PULL_MAX = 120;

/** Ungli ki asli doori -> dikhne wali doori (resistance: jitna kheencho utna bhaari). */
export function damped(dy: number): number {
  if (!(dy > 0)) return 0;
  return Math.min(PULL_MAX, dy * 0.5);
}

export function pullReady(shown: number): boolean {
  return shown >= PULL_THRESHOLD;
}

/** Kya yeh gesture pull-to-refresh ban sakta hai? dx/dy = ungli ki harkat. Seedha neeche (zyada vertical) hona chahiye. */
export function isPullGesture(dx: number, dy: number): boolean {
  return dy > 8 && Math.abs(dy) > Math.abs(dx) * 1.5;
}

type ElLike = {
  scrollTop: number;
  scrollHeight: number;
  clientHeight: number;
  parentElement: ElLike | null;
  tagName?: string;
  isContentEditable?: boolean;
  getAttribute?: (n: string) => string | null;
  matches?: (s: string) => boolean;
  overflowY?: string; // test mein; browser mein getComputedStyle
};

const BLOCK = 'input, textarea, select, [contenteditable="true"], [role="dialog"], [data-no-pull]';

/**
 * Touch kahan shuru hui? Wahan se upar tak koi bhi scroll hone wala dabba (overflow-y auto/scroll aur asal mein scroll hota ho)
 * agar upar se neeche scrolled hai to pull nahi. Block wale element ke andar bhi nahi.
 */
export function canStartPull(start: ElLike | null, overflowOf: (e: ElLike) => string): boolean {
  for (let e = start; e; e = e.parentElement) {
    if (e.matches?.(BLOCK) || e.isContentEditable) return false;
    const oy = overflowOf(e);
    if (
      (oy === "auto" || oy === "scroll") &&
      e.scrollHeight > e.clientHeight + 1 &&
      e.scrollTop > 0
    )
      return false;
  }
  return true;
}
