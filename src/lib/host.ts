/**
 * HOST-AWARE SURFACE (locked 5 Sep 2026 — SINGLE FOUNDER HOST)
 *
 * Ek codebase, teen surfaces:
 *   - anexomail.com                    = business workspace (awam, pre-launch lock)
 *   - founderworkspace.anexomail.com   = THE ONLY founder host (Caddy allowlist)
 *   - ai.anexomail.com                 = LEO AI product (awam ko sirf `/`)
 *
 * `aiemail.anexomail.com` RETIRED hai — na domain hai, na Caddy block. Founder ka
 * har surface (AI workbench samet) founderworkspace.anexomail.com ke andar hai.
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

/** Founder host (Caddy IP allowlist) + local/preview dev. Sirf ek host. */
export function isFounderHost(): boolean {
  const h = hostName();
  return (
    h === "founderworkspace.anexomail.com" ||
    h === "localhost" ||
    h === "127.0.0.1" ||
    h.endsWith(".lovable.app") ||
    h.endsWith(".lovableproject.com")
  );
}

/**
 * FOUNDER SURFACE GUARD: `/app/founder*` (Founder view) sirf founder host par
 * render hota hai. Awam host par path exist karta hai magar surface band —
 * host-guard permanent hai, kisi flag par nahi.
 */
export function founderSurfaceAllowed(): boolean {
  return isFounderHost();
}

/**
 * AI host par awam ke liye khula path — sirf `/` (AI landing + coming soon +
 * package feature list). Baqi sab paths lock ke peeche.
 */
export function aiPublicPathAllowed(pathname: string): boolean {
  return pathname === "/" || pathname === "";
}
