/**
 * WebTransport (QUIC, udp/3443) ka ek hi pata — mail live stamp, chat live stream, call signaling.
 *
 * 20 Oct 2026 (server ki live jaankari): Rust WT server ka certificate SIRF `anexochat.anexomail.com` ke naam par hai.
 * Pehle mail `https://<jo bhi host>:3443` (yani anexomail.com:3443) se judta tha => naam mismatch => QUIC kabhi nahi
 * judta tha, hamesha HTTP poll. Chat/call ke liye env na ho to WT bilkul band tha. Ab: env ho to wahi, warna
 * certificate wala asli naam. Na jude to har jagah pehle jaisa sacha fallback (poll / rows).
 */
const WT_HOST = "anexochat.anexomail.com";
const WT_PORT = 3443;

export function wtBaseUrl(): string {
  const env = (import.meta.env["VITE_ANEXOCHAT_WT_URL"] as string | undefined)?.replace(/\/$/, "");
  if (env) return env;
  if (typeof window === "undefined") return "";
  const h = window.location.hostname;
  // sirf apne production hosts par (preview / localhost par nahi)
  if (h === "anexomail.com" || h.endsWith(".anexomail.com")) return `https://${WT_HOST}:${WT_PORT}`;
  return "";
}
