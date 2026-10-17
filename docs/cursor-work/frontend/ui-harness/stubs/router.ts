// createFileRoute("/x")({ component, validateSearch }) -> returns the options plus a reactive Route.useSearch().
// The harness "URL" is the hash: "#people?id=c1&view=people". useNavigate({search}) rewrites that hash (so selecting a row really
// changes the page); Link renders an <a href="#to">.
import { createElement, useSyncExternalStore } from "react";

const sub = (cb: () => void) => (window.addEventListener("hashchange", cb), () => window.removeEventListener("hashchange", cb));
const hash = () => (typeof window !== "undefined" ? window.location.hash : "");
const hashSearch = (): Record<string, unknown> => Object.fromEntries(new URLSearchParams(hash().split("?")[1] ?? ""));

export const createFileRoute = () => (opts: Record<string, unknown>) => ({
  ...opts,
  useSearch: () => {
    useSyncExternalStore(sub, hash, () => "");
    const v = opts.validateSearch as ((s: Record<string, unknown>) => unknown) | undefined;
    return v ? v(hashSearch()) : hashSearch();
  },
  useParams: () => ({}),
});
export const Link = (p: { to?: string; children?: unknown; className?: string }) =>
  createElement("a", { href: "#" + (p.to ?? ""), className: p.className }, p.children as never);
export const useNavigate = () => (o?: { search?: Record<string, unknown> }) => {
  if (!o?.search) return undefined;
  const base = hash().slice(1).split("?")[0];
  const qs = new URLSearchParams(Object.entries(o.search).filter(([, v]) => v !== "" && v != null && v !== false).map(([k, v]) => [k, String(v)])).toString();
  window.location.hash = base + (qs ? "?" + qs : "");
  return undefined;
};
export const useRouter = () => ({ navigate: () => undefined });
export const useSearch = () => ({});
export const useParams = () => ({});
export const useRouterState = () => ({ location: { pathname: "/" } });
