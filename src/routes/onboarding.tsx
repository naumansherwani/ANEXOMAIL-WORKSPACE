import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useEffect, useRef, useState } from "react";
import { Building2, Loader2, LogIn } from "lucide-react";

import { BrandMark } from "@/components/site/BrandMark";
import { WorkspaceKindCards } from "@/components/site/WorkspaceKindCards";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { api, ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useLocale } from "@/lib/i18n";

export const Route = createFileRoute("/onboarding")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Create your account for workspace — ANEXOMAIL" },
      {
        name: "description",
        content: "Choose account type: Personal or Business. Then open your ANEXOMAIL inbox.",
      },
      { property: "og:title", content: "Create your account for workspace — ANEXOMAIL" },
      {
        property: "og:description",
        content: "Personal mail, or a named business workspace with your organisation domain.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: OnboardingPage,
});

type Path = "choose" | "business-name";

function OnboardingPage() {
  const navigate = useNavigate();
  const { session, status, refresh } = useAuth();

  const [path, setPath] = useState<Path>("choose");
  const [org, setOrg] = useState("");
  const [orgDomain, setOrgDomain] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const autoKind = useRef(false);

  useEffect(() => {
    if (status !== "signed-in" || !session) return;
    // FOUNDER PROTOCOL: founder par awam ka org onboarding kabhi nahi.
    if (session.user.is_founder) {
      void navigate({ to: "/app", replace: true });
      return;
    }
    if (!session.user.anexomail_address) {
      void navigate({ to: "/claim", replace: true });
      return;
    }
    if (session.user.onboarded) {
      window.location.replace("/dashboard");
      return;
    }
    if (autoKind.current || busy || path !== "choose") return;
    const kind = session.user.account_kind;
    const stored =
      typeof window !== "undefined" ? window.sessionStorage.getItem("anexo.pending.workspace_kind") : null;
    const chosen = stored === "personal" || stored === "business" ? stored : kind;
    if (chosen === "business") {
      autoKind.current = true;
      setPath("business-name");
      return;
    }
    if (chosen === "personal") {
      autoKind.current = true;
      void goPersonal();
    }
  }, [status, session, navigate, busy, path]);

  const fail = (e: unknown) =>
    setError(
      e instanceof ApiError
        ? e.isNotImplemented
          ? "This step isn't live on the server yet."
          : e.message
        : "Something went wrong.",
    );

  const goPersonal = async () => {
    setError(null);
    setBusy(true);
    try {
      await api("/api/workspace/personal", { method: "POST", body: "{}" });
      await refresh();
      window.location.replace("/dashboard");
    } catch (e) {
      fail(e);
    } finally {
      setBusy(false);
    }
  };

  const createOrg = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await api("/api/workspace/organisations", {
        method: "POST",
        body: JSON.stringify({ name: org, domain: orgDomain }),
      });
      await api("/api/auth/onboarding/complete", { method: "POST" });
      await refresh();
      window.sessionStorage.removeItem("anexo.pending.workspace_kind");
      window.location.replace("/dashboard");
    } catch (e) {
      fail(e);
    } finally {
      setBusy(false);
    }
  };

  return status !== "signed-in" ? (
    <OnboardingIntro loading={status === "loading"} />
  ) : (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden bg-background px-4 py-16">
      <div
        aria-hidden
        className="pointer-events-none absolute left-1/2 top-[-14rem] h-[30rem] w-[54rem] -translate-x-1/2 rounded-full bg-cyan-accent/10 blur-[130px]"
      />

      <div className="ax-in relative w-full max-w-[42rem]">
        <div className="flex justify-center">
          <BrandMark />
        </div>

        <div className="mt-ax-4 rounded-2xl border border-border bg-card p-ax-5 shadow-2xl">
          {path === "choose" && (
            <div className="space-y-ax-3">
              <WorkspaceKindCards
                busy={busy}
                onPersonal={() => void goPersonal()}
                onBusiness={() => setPath("business-name")}
              />

              {error && (
                <p role="alert" className="ax-caption text-destructive">
                  {error}
                </p>
              )}
            </div>
          )}

          {path === "business-name" && (
            <form onSubmit={createOrg} className="space-y-ax-3">
              <div className="text-center">
                <Building2 className="mx-auto size-5 text-cyan-accent" />
                <h1 className="ax-heading mt-ax-2 text-foreground">Your organisation</h1>
                <p className="ax-caption mt-1">
                  Name the company workspace, then the domain it will send from.
                </p>
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="org" className="ax-caption text-foreground">
                  Organisation name
                </Label>
                <Input id="org" required minLength={2} value={org} onChange={(e) => setOrg(e.target.value)} />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="org-domain" className="ax-caption text-foreground">
                  Organisation domain
                </Label>
                <Input
                  id="org-domain"
                  required
                  value={orgDomain}
                  onChange={(e) => setOrgDomain(e.target.value)}
                  autoComplete="off"
                />
              </div>

              {error && (
                <p role="alert" className="ax-caption text-destructive">
                  {error}
                </p>
              )}

              <Button type="submit" className="ax-press w-full" disabled={busy}>
                {busy && <Loader2 className="size-4 animate-spin" />}
                Continue
              </Button>
              <Button
                type="button"
                variant="ghost"
                className="w-full"
                disabled={busy}
                onClick={() => {
                  setError(null);
                  setPath("choose");
                }}
              >
                Back
              </Button>
            </form>
          )}
        </div>
      </div>
    </main>
  );
}

function OnboardingIntro({ loading }: { loading: boolean }) {
  const { t } = useLocale();
  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden bg-background px-4 py-16">
      <div className="ax-in relative w-full max-w-[28rem] text-center">
        <BrandMark />
        <h1 className="ax-heading mt-ax-5 text-foreground">{t("Create your account for workspace")}</h1>
        <p className="ax-body mt-ax-2">
          {t("Sign in first. Then choose Personal or Business — no domain required on day one.")}
        </p>
        {loading ? (
          <p className="ax-caption mt-ax-4 flex items-center justify-center gap-2">
            <Loader2 className="size-4 animate-spin" />
            Checking your session…
          </p>
        ) : (
          <div className="mt-ax-4 flex flex-col gap-2">
            <Button asChild className="ax-press w-full">
              <Link to="/auth">
                <LogIn className="size-4" />
                Sign in
              </Link>
            </Button>
            <Button asChild variant="ghost" className="w-full">
              <Link to="/auth" search={{ mode: "signup" }}>
                Create your account for workspace
              </Link>
            </Button>
          </div>
        )}
      </div>
    </main>
  );
}
