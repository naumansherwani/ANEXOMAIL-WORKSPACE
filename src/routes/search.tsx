import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/search
 * Sirf ek chhota pata; asli surface /app/search hi rehta hai.
 */
export const Route = createFileRoute("/search")({
  beforeLoad: () => {
    throw redirect({ to: "/app/search", search: { q: "" } });
  },
});
