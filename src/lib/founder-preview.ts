/**
 * Founder Preview — VIEW KEY ONLY (toolbar / page index).
 * Does not mint a session and does not fake data.
 *
 * `/app` PRODUCT GATE is separate: sticky localStorage must NOT skip login.
 * Tour without a session is only the current URL `?founder=1` (see
 * `workspaceTourFromUrl`). Otherwise `/app` goes to `/auth`.
 */

const KEY = "ax.founder.preview";

export function founderPreviewEnabled(): boolean {
  if (typeof window === "undefined") return false;
  try {
    return window.localStorage.getItem(KEY) === "on";
  } catch {
    return false;
  }
}

export function setFounderPreview(on: boolean) {
  if (typeof window === "undefined") return;
  try {
    if (on) window.localStorage.setItem(KEY, "on");
    else window.localStorage.removeItem(KEY);
  } catch {
    /* ignore quota */
  }
}

/**
 * Founder deep-link: any URL with `?founder=1` opens in founder access, so the
 * founder can jump straight into any page from the page map, a bookmark or a
 * pasted link without going through sign-in first.
 */
export function founderPreviewFromUrl(): boolean {
  if (typeof window === "undefined") return false;
  try {
    const value = new URLSearchParams(window.location.search).get("founder");
    if (value === "1" || value === "on") {
      setFounderPreview(true);
      return true;
    }
    if (value === "0" || value === "off") {
      setFounderPreview(false);
      return false;
    }
  } catch {
    /* ignore */
  }
  return founderPreviewEnabled();
}

/**
 * Workspace tour without a session — this URL only.
 * Does not read/write localStorage, so a leftover FOUNDER VIEW cannot keep
 * `/app` open as "no session" mail/chat 401s.
 */
export function workspaceTourFromUrl(): boolean {
  if (typeof window === "undefined") return false;
  try {
    const value = new URLSearchParams(window.location.search).get("founder");
    return value === "1" || value === "on";
  } catch {
    return false;
  }
}
