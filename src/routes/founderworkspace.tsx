import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/founderworkspace
 * Sirf ek chhota pata; asli surface /app/founder hi rehta hai.
 */
export const Route = createFileRoute("/founderworkspace")({
  beforeLoad: () => {
    throw redirect({ to: "/app/founder" });
  },
});
