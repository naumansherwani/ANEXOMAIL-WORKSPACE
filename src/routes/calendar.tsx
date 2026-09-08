import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/calendar
 * Sirf ek chhota pata; asli surface /app/calendar hi rehta hai.
 */
export const Route = createFileRoute("/calendar")({
  beforeLoad: () => {
    throw redirect({ to: "/app/calendar" });
  },
});
