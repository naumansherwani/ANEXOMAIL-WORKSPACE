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
