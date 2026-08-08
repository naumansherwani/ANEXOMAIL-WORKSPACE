/**
 * Founder Preview — locked founder rule: the founder must be able to walk every
 * page of the product before launch, even when a workspace session is not
 * available yet on this device.
 *
 * This is a VIEW key only. It does not mint a session, does not fake data and
 * does not touch the backend. Every panel still calls the real API, so unwired
 * endpoints show honest "not wired" / empty states (NO MOCK rule intact).
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
