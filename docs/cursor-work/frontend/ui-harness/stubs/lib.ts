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
