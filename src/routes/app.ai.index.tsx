import { createFileRoute, redirect } from "@tanstack/react-router";

/** `/app/ai` ka landing = AI email center (Leo, Jimmy, Sherlock, industry desks). */
export const Route = createFileRoute("/app/ai/")({
  beforeLoad: () => {
    throw redirect({ to: "/app/ai-center" });
  },
});
