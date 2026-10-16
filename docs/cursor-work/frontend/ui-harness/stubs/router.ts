// createFileRoute("/x")({ component }) -> returns the options object so the harness can mount `component`.
export const createFileRoute = () => (opts: Record<string, unknown>) => opts;
export const Link = (p: { to?: string; children?: unknown; className?: string }) => null as unknown as JSX.Element;
