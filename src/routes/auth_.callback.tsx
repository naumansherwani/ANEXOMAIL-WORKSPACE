import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { Loader2 } from "lucide-react";

import { BrandMark } from "@/components/site/BrandMark";
import { Button } from "@/components/ui/button";
import { api, ApiError, sessionToken } from "@/lib/api";
import { useAuth } from "@/lib/auth";

export const Route = createFileRoute("/auth_/callback")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Finishing sign-in — ANEXOMAIL Workspace" },
      {
        name: "description",
        content: "Completing your ANEXOMAIL sign-in link.",
      },
      { property: "og:title", content: "Finishing sign-in — ANEXOMAIL Workspace" },
      { property: "og:description", content: "Completing your ANEXOMAIL sign-in link." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CallbackPage,
});

function CallbackPage() {
  const navigate = useNavigate();
  const { refresh } = useAuth();
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const token = params.get("token");
    if (!token) {
      setError("This link is missing its verification token.");
      return;
    }

    void (async () => {
      try {
        const res = await api<{ token: string; user: { onboarded: boolean } }>(
          "/api/auth/magic-link/verify",
          { method: "POST", body: JSON.stringify({ token }), auth: false },
        );
        sessionToken.set(res.token);
        await refresh();
        void navigate({ to: res.user.onboarded ? "/app" : "/onboarding", replace: true });
      } catch (e) {
        setError(
          e instanceof ApiError
            ? e.isNotImplemented
              ? "Sign-in links aren't live on the server yet."
              : e.message
            : "This link could not be verified.",
        );
      }
    })();
  }, [navigate, refresh]);

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="ax-in w-full max-w-sm text-center">
        <div className="flex justify-center">
          <BrandMark />
        </div>
        {error ? (
          <div role="alert" className="mt-ax-5">
            <h1 className="ax-heading text-foreground">Link didn't work</h1>
            <p className="ax-body mt-ax-2">{error}</p>
            <Button className="ax-press mt-ax-4" onClick={() => navigate({ to: "/auth" })}>
              Back to sign in
            </Button>
          </div>
        ) : (
          <p className="ax-body mt-ax-5 flex items-center justify-center gap-2">
            <Loader2 className="size-4 animate-spin text-cyan-accent" />
            Finishing your sign-in…
          </p>
        )}
      </div>
    </main>
  );
}