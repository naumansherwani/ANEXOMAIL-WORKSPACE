/**
 * VISITOR PREVIEW MODE (founder-only).
 *
 * Founder ko poori public website bilkul waise dekhni hai jaise ek anjaan
 * visitor ko dikhti hai — bina logout kiye. Ye sirf RENDER LAYER hai:
 * session zinda rehta hai, sirf UI use ignore karta hai.
 *
 * ON:  ?preview=public   (ya top-bar toggle)
 * OFF: ?preview=off      (ya badge ka "exit")
 */

const KEY = "ax.visitor.preview";

export function visitorPreviewEnabled(): boolean {
  if (typeof window === "undefined") return false;
  try {
    return window.sessionStorage.getItem(KEY) === "on";
  } catch {
    return false;
  }
}

export function setVisitorPreview(on: boolean) {
  if (typeof window === "undefined") return;
  try {
    if (on) window.sessionStorage.setItem(KEY, "on");
    else window.sessionStorage.removeItem(KEY);
  } catch {
    /* ignore */
  }
}

/** `?preview=public` / `?preview=off` ko padh ke state set karta hai. */
export function visitorPreviewFromUrl(): boolean {
  if (typeof window === "undefined") return false;
  try {
    const value = new URLSearchParams(window.location.search).get("preview");
    if (value === "public" || value === "1" || value === "on") {
      setVisitorPreview(true);
      return true;
    }
    if (value === "off" || value === "0" || value === "exit") {
      setVisitorPreview(false);
      return false;
    }
  } catch {
    /* ignore */
  }
  return visitorPreviewEnabled();
}