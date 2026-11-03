import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/work
 * Sirf ek chhota pata; asli surface /app/work hi rehta hai.
 */
export const Route = createFileRoute("/work")({
  beforeLoad: () => {
    throw redirect({ to: "/app/work" });
  },
});
