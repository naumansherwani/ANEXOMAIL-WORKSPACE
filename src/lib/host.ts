/**
 * HOST-AWARE SURFACE (PARALLEL AI BUILD LOCK, 24 Aug 2026)
 *
 * Ek codebase, do surfaces:
 *   - anexomail.com        = business workspace (founder side, pre-launch lock)
 *   - ai.anexomail.com     = LEO AI product — SAME build, SAME PM2 process.
 *     Awam ko sirf `/` (AI landing) nazar aata hai; /app/* mirror unlock key
 *     ke peeche. Do repo / do design system kabhi nahi.
 */

export function hostName(): string {
  if (typeof window === "undefined") return "";
  return window.location.hostname.toLowerCase();
}

/** ai.anexomail.com — awam ka AI product host (mirror of everything, gated). */
export function isAiHost(): boolean {
  return hostName() === "ai.anexomail.com";
}

/** anexochat.anexomail.com — ANEXOChat apna host. */
export function isChatHost(): boolean {
  return hostName() === "anexochat.anexomail.com";
}

/** Founder-only hosts (Caddy IP allowlist) + local/preview dev. */
export function isFounderHost(): boolean {
  const h = hostName();
  return (
    h === "founderworkspace.anexomail.com" ||
    h === "aiemail.anexomail.com" ||
    h === "localhost" ||
    h === "127.0.0.1" ||
    h.endsWith(".lovable.app") ||
    h.endsWith(".lovableproject.com")
  );
}

/**
 * AI host par awam ke liye khula path — sirf `/` (AI landing + coming soon +
 * package feature list). Baqi sab paths lock ke peeche.
 */
export function aiPublicPathAllowed(pathname: string): boolean {
  return pathname === "/" || pathname === "";
}
