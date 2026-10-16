// createFileRoute("/x")({ component }) -> returns the options object so the harness can mount `component`.
import { createElement } from "react";

export const createFileRoute = () => (opts: Record<string, unknown>) => opts;
export const Link = (p: { to?: string; children?: unknown; className?: string }) =>
  createElement("a", { href: "#" + (p.to ?? ""), className: p.className }, p.children as never);
