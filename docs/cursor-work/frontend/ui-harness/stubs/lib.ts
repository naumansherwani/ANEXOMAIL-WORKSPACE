import { useSyncExternalStore } from "react";
export const useLocale = () => ({ t: (s: string) => s });
export const notify = {
  done: (m: string) => (window as unknown as { __toast?: (m: string) => void }).__toast?.(m),
  info: (m: string, d?: string) => (window as unknown as { __toast?: (m: string) => void }).__toast?.(m + (d ? " — " + d : "")),
  failed: (m: string) => (window as unknown as { __toast?: (m: string) => void }).__toast?.(m),
};
export const normalizeWorkspacePlan = (p?: string) => p ?? "pro";
export const packageCopyName = (p: string) => (p === "pro" ? "Pro" : p);
export const useSummary = () => {
  const scenario = useSyncExternalStore(
    (cb) => (window.addEventListener("hashchange", cb), () => window.removeEventListener("hashchange", cb)),
    () => location.hash,
  );
  const hosted = scenario.includes("hosted");
  return {
    data: {
      domain: hosted ? null : "probuyer.axonetis.com",
      domain_status: hosted ? "none" : "pending",
      domain_hosted: hosted,
      domain_verified: false,
    },
  };
};
// Dashboard analytics: dashmail => sent>0 | dashnomail (default) => sent 0 | dashnoanalytics => no data (plan has none)
export const useAnalytics = (_enabled: boolean) => {
  const h = useSyncExternalStore(
    (cb) => (window.addEventListener("hashchange", cb), () => window.removeEventListener("hashchange", cb)),
    () => location.hash,
  );
  if (h.includes("noanalytics")) return { data: undefined };
  return { data: { range_days: 30, received: 12, sent: h.includes("dashmail") ? 3 : 0, avg_first_reply_seconds: null, delivery_rate: null, series: [] } };
};

// ---- 8o founder expiry watch. Hash: expok | expwarn | expcrit | expunknown | expstale | expnone | expfail | nofounder
export const useAuth = () => {
  const h = location.hash;
  return { session: { user: { is_founder: !h.includes("nofounder") } } };
};
type It = { id: string; group: string; label: string; target: string; status: string; detail: string; days_left?: number };
const base = (): It[] => [
  { id: "mail-tls", group: "tls", label: "Mail TLS (IMAP/SMTP)", target: "mail.anexomail.com", status: "ok", detail: "993: 76d · 587: 76d", days_left: 76 },
  { id: "web:anexomail.com", group: "web", label: "Website HTTPS", target: "anexomail.com", status: "ok", detail: "61d left", days_left: 61 },
  { id: "web:www.anexomail.com", group: "web", label: "Website HTTPS", target: "www.anexomail.com", status: "ok", detail: "61d left", days_left: 61 },
  { id: "web:mail.anexomail.com", group: "web", label: "Website HTTPS", target: "mail.anexomail.com", status: "ok", detail: "76d left", days_left: 76 },
  { id: "domain:anexomail.com", group: "domain", label: "Domain renewal", target: "anexomail.com", status: "ok", detail: "expires 2027-08-13 (300d)", days_left: 300 },
  { id: "dkim:anexomail.com", group: "dkim", label: "DKIM signing key", target: "mail._domainkey.anexomail.com", status: "ok", detail: "DNS matches the signing key · key age 120d" },
  { id: "mx", group: "dns", label: "MX record", target: "anexomail.com", status: "ok", detail: "points to mail.anexomail.com" },
  { id: "spf", group: "dns", label: "SPF record", target: "anexomail.com", status: "ok", detail: "present" },
  { id: "dmarc", group: "dns", label: "DMARC record", target: "anexomail.com", status: "ok", detail: "present" },
  { id: "ptr", group: "dns", label: "Reverse DNS (PTR)", target: "203.0.113.5", status: "ok", detail: "203.0.113.5 → mail.anexomail.com" },
];
const set = (items: It[], id: string, patch: Partial<It>) => items.map((i) => (i.id === id ? { ...i, ...patch } : i));
export const useExpiryWatch = (_enabled: boolean) => {
  const h = useSyncExternalStore(
    (cb) => (window.addEventListener("hashchange", cb), () => window.removeEventListener("hashchange", cb)),
    () => location.hash,
  );
  if (h.includes("expfail")) return { data: undefined };
  if (h.includes("expnone")) return { data: { available: false, reason: "no_report_yet" } };
  let items = base();
  let overall = "ok";
  let headline = { id: "mail-tls", label: "Mail TLS", days_left: 76, status: "ok" };
  if (h.includes("expwarn")) {
    items = set(items, "web:www.anexomail.com", { status: "warn", detail: "15d left", days_left: 15 });
    items = set(items, "ptr", { status: "warn", detail: "203.0.113.5 resolves to static.5.113.0.203.clients.your-server.de, not mail.anexomail.com (set it in the Hetzner panel)" });
    overall = "warn";
  }
  if (h.includes("expcrit")) {
    items = set(items, "mail-tls", { status: "crit", days_left: 5, detail: "993: 5d · 587: 5d — port 993 ka cert phone/Outlook ko valid nahi lagega: certificate has expired" });
    items = set(items, "domain:anexomail.com", { status: "crit", days_left: 25, detail: "expires 2026-11-11 (25d)" });
    items = set(items, "dkim:anexomail.com", { status: "crit", detail: "DNS public key does not match the server's signing key — signed mail fails DKIM · key age 120d" });
    items = set(items, "web:www.anexomail.com", { status: "warn", detail: "15d left", days_left: 15 });
    headline = { id: "mail-tls", label: "Mail TLS", days_left: 5, status: "crit" };
    overall = "crit";
  }
  if (h.includes("expunknown")) {
    items = set(items, "domain:anexomail.com", { status: "unknown", days_left: undefined, detail: "Could not read the expiry date (RDAP: timed out). Check it at your registrar." });
    items = set(items, "dkim:anexomail.com", { status: "unknown", detail: "OpenDKIM key table not found (/etc/opendkim/KeyTable) — set DKIM_KEYTABLE in /etc/anexomail/expiry-watch.env" });
    overall = "unknown";
  }
  const stale = h.includes("expstale");
  return { data: { available: true, version: 1, checked_at: "2026-10-17T03:47:02Z", overall, headline, items, age_secs: stale ? 61 * 3600 : 3 * 3600, stale } };
};
