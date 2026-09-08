import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/chat
 * Sirf ek chhota pata; asli surface /app/chat hi rehta hai.
 */
export const Route = createFileRoute("/chat")({
  beforeLoad: () => {
    throw redirect({ to: "/app/chat" });
  },
});
