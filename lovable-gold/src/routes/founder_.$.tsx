import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short paths — `/founder/crm`, `/founder/revenue`, `/founder/launch/qa` …
 * har ek seedha apne asli `/app/founder/*` surface par jata hai. Koi 404 nahi.
 */
export const Route = createFileRoute("/founder_/$")({
  beforeLoad: ({ params }) => {
    const rest = (params as { _splat?: string })._splat ?? "";
    throw redirect({ href: rest ? `/app/founder/${rest}` : "/app/founder" });
  },
});
