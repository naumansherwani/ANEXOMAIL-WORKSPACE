import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * `/app/mail` ka apna landing folder: inbox. Mail ka asli surface
 * `/app/mail/$folder` hai, is liye yeh route seedha inbox par le jata hai.
 */
export const Route = createFileRoute("/app/mail/")({
  beforeLoad: () => {
    throw redirect({ to: "/app/mail/$folder", params: { folder: "inbox" } });
  },
});
