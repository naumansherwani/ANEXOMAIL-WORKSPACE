import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/people
 * Sirf ek chhota pata; asli surface /app/people hi rehta hai.
 */
export const Route = createFileRoute("/people")({
  beforeLoad: () => {
    throw redirect({ to: "/app/people", search: { view: "people", id: "", q: "", filter: "all", tag: "" } });
  },
});
