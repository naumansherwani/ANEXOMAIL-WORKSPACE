// Public-site stand-ins (landing / plans / get-started / onboarding). Anonymous visitor by default.
import { useSyncExternalStore } from "react";

export class ApiError extends Error {
  status = 0;
  code?: string;
  isNotImplemented = false;
}
export const api = async <T,>(_path: string, _opts?: unknown): Promise<T> => {
  throw new ApiError("offline (harness)");
};
export const sessionToken = () => null;
export const useQuery = (_o: unknown) => ({ data: undefined, isLoading: false, isError: true, error: null });

const hash = () => location.hash;
const sub = (cb: () => void) => (window.addEventListener("hashchange", cb), () => window.removeEventListener("hashchange", cb));
// Hash flags: signed (logged-in business user) — default anonymous.
export const useAuth = () => {
  const h = useSyncExternalStore(sub, hash);
  const signed = h.includes("signed");
  return {
    session: signed ? { user: { email: "pro.buyer@anexomail.com", workspace_plan: "pro", account_kind: "personal", anexomail_address: "pro.buyer@anexomail.com" } } : null,
    organisation: null,
    loading: false,
    ready: true,
    signOut: async () => undefined,
  };
};
export const useLocale = () => ({ t: (s: string) => s, locale: "en", ready: true });
export const setLocale = () => undefined;
export const publicLocaleAllowed = () => false;
export const collectDeviceSignals = async () => ({});
