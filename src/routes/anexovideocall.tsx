import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/anexovideocall
 * Sirf ek chhota pata; asli surface /app/chat hi rehta hai.
 */
export const Route = createFileRoute("/anexovideocall")({
  beforeLoad: () => {
    throw redirect({ to: "/app/chat" });
  },
});
