/**
 * Expiry watch (blueprint 8o) — founder-only.
 *
 * Server par `anexomail-expiry-watch` (systemd timer, din mein 2 baar) mail TLS, website certs, domain renewal,
 * DKIM aur mail DNS dekhta hai aur `/var/lib/anexomail/expiry-watch.json` likhta hai. Rust `founder.expiry.watch`
 * wohi file parhta hai (founder gate server par). Frontend kuch hisaab nahi karta — sirf dikhata hai (NO DUPLICATE).
 * Rust abhi build nahi hua / founder nahi / file nahi => hook error deta hai aur tile chup rehti hai (galat dar nahi).
 */

import { useQuery } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpc } from "@/lib/rpc";

export type ExpiryStatus = "ok" | "warn" | "crit" | "unknown";

export type ExpiryItem = {
  id: string;
  group: "tls" | "web" | "domain" | "dkim" | "dns";
  label: string;
  target: string;
  status: ExpiryStatus;
  detail: string;
  days_left?: number;
  expires_at?: string;
};

export type ExpiryReport =
  | { available: false; reason: string }
  | {
      available: true;
      version: number;
      checked_at: string;
      overall: ExpiryStatus;
      headline: { id: string; label: string; days_left: number | null; status: ExpiryStatus };
      items: ExpiryItem[];
      /** Report file kitni purani hai (seconds). */
      age_secs: number | null;
      /** 36 ghante se purani => monitor ruk gaya ho sakta hai. */
      stale: boolean;
    };

export const useExpiryWatch = (enabled: boolean) =>
  useQuery<ExpiryReport, ApiError>({
    queryKey: ["founder", "expiry-watch"],
    queryFn: () => rpc<ExpiryReport>("founder.expiry.watch"),
    enabled,
    retry: false,
    staleTime: 5 * 60_000,
    refetchInterval: 15 * 60_000,
    refetchOnWindowFocus: false,
  });
