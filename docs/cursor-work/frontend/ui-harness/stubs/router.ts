// createFileRoute("/x")({ component }) -> returns the options object so the harness can mount `component`.
import { createElement } from "react";

// Route.useSearch() reads the query part of the harness hash (e.g. "#auth?mode=signup") through the route's own validateSearch.
const hashSearch = (): Record<string, unknown> => {
  const q = (typeof window !== "undefined" ? window.location.hash : "").split("?")[1] ?? "";
  return Object.fromEntries(new URLSearchParams(q));
};
export const createFileRoute = () => (opts: Record<string, unknown>) => ({
  ...opts,
  useSearch: () => {
    const v = opts.validateSearch as ((s: Record<string, unknown>) => unknown) | undefined;
    return v ? v(hashSearch()) : hashSearch();
  },
  useParams: () => ({}),
});
export const Link = (p: { to?: string; children?: unknown; className?: string }) =>
  createElement("a", { href: "#" + (p.to ?? ""), className: p.className }, p.children as never);
export const useNavigate = () => () => undefined;
export const useRouter = () => ({ navigate: () => undefined });
export const useSearch = () => ({});
export const useParams = () => ({});
export const useRouterState = () => ({ location: { pathname: "/" } });
