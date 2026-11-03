import { createFileRoute } from "@tanstack/react-router";

import { AuthPage } from "./auth";

/** Create your account — anexomail.com/signup (founder 2 Nov 2026: sign-up must not live at /auth). Same page as /auth, opened in sign-up mode. */
export const Route = createFileRoute("/signup")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Create your account — ANEXOMAIL Workspace" },
      { name: "description", content: "Create your ANEXOMAIL account and workspace." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: () => <AuthPage startMode="signup" />,
});
