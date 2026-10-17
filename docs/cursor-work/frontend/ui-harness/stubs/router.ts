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
// Link: also honours activeOptions/activeProps/inactiveProps (+ aria-current) the way TanStack does, from the hash "URL".
type LinkProps = {
  to?: string; children?: unknown; className?: string;
  activeOptions?: { exact?: boolean }; activeProps?: { className?: string }; inactiveProps?: { className?: string };
};
export const Link = (p: LinkProps) => {
  useSyncExternalStore(sub, hash, () => "");
  const path = "/app/" + hash().replace(/^#\/?/, "").replace(/^app\//, "").split("?")[0];
  const to = p.to ?? "";
  const here = path.replace(/\/+$/, "");
  const active = p.activeProps || p.inactiveProps ? (p.activeOptions?.exact ? here === to : here === to || here.startsWith(to + "/")) : false;
  const cls = [p.className, active ? p.activeProps?.className : p.inactiveProps?.className].filter(Boolean).join(" ");
  return createElement("a", { href: "#" + to, className: cls || undefined, "aria-current": active ? "page" : undefined }, p.children as never);
};
// Outlet: the harness sets globalThis.__axOutlet to the child page for the current hash.
export const Outlet = () => ((globalThis as unknown as { __axOutlet?: () => unknown }).__axOutlet?.() ?? null) as never;
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
// pathname mirrors the hash so route-aware chrome (CrmStage nav) highlights the page: "#crm/pipeline" or "#/app/crm/pipeline" -> "/app/crm/pipeline".
export const useRouterState = <T = { location: { pathname: string } }>(o?: { select?: (s: { location: { pathname: string } }) => T }) => {
  useSyncExternalStore(sub, hash, () => "");
  const s = { location: { pathname: "/app/" + hash().replace(/^#\/?/, "").replace(/^app\//, "").split("?")[0] } };
  return (o?.select ? o.select(s) : s) as T;
};
