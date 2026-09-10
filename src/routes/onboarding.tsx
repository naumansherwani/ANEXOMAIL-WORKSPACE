import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { ArrowLeft, Building2, Loader2, LogIn, Mail, Rocket, Users } from "lucide-react";

import { BrandMark } from "@/components/site/BrandMark";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { api, ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/onboarding")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Set up your workspace — ANEXOMAIL" },
      {
        name: "description",
        content: "Choose Personal or Business — then open your ANEXOMAIL inbox.",
      },
      { property: "og:title", content: "Set up your workspace — ANEXOMAIL" },
      {
        property: "og:description",
        content: "Personal mail or a named business workspace. Domain comes later.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: OnboardingPage,
});

type Path = "choose" | "business-name" | "business-people";

function OnboardingPage() {
  const navigate = useNavigate();
  const { session, status, refresh } = useAuth();

  const [path, setPath] = useState<Path>("choose");
  const [org, setOrg] = useState("");
  const [invites, setInvites] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
      void navigate({ to: "/app", replace: true });
    }
  }, [status, session, navigate]);

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
      void navigate({ to: "/app/mail/$folder", params: { folder: "inbox" }, replace: true });
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
        body: JSON.stringify({ name: org }),
      });
      await refresh();
      setPath("business-people");
    } catch (e) {
      fail(e);
    } finally {
      setBusy(false);
    }
  };

  const sendInvites = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    setBusy(true);
    const emails = invites
      .split(/[\s,;]+/)
      .map((e) => e.trim())
      .filter(Boolean);
    try {
      if (emails.length) {
        await api("/api/workspace/invitations", {
          method: "POST",
          body: JSON.stringify({ emails, role: "member" }),
        });
        notify.done("Invitations sent", `${emails.length} people invited.`);
      }
      await api("/api/auth/onboarding/complete", { method: "POST" });
      await refresh();
      void navigate({ to: "/app/mail/$folder", params: { folder: "inbox" }, replace: true });
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

      <div className="ax-in relative w-full max-w-[30rem]">
        <div className="flex justify-center">
          <BrandMark />
        </div>

        <div className="mt-ax-4 rounded-2xl border border-border bg-card p-ax-5 shadow-2xl">
          {path === "choose" && (
            <div className="space-y-ax-3">
              <div className="text-center">
                <Rocket className="mx-auto size-5 text-cyan-accent" />
                <h1 className="ax-heading mt-ax-2 text-foreground">How will you use ANEXOMAIL?</h1>
                <p className="ax-caption mt-1">
                  Personal is just your mail. Business adds a named company workspace — domain
                  comes later in Ownership Center.
                </p>
              </div>

              <button
                type="button"
                disabled={busy}
                onClick={() => void goPersonal()}
                className="ax-press flex w-full flex-col items-start gap-1 rounded-xl border border-border bg-background px-4 py-3 text-left hover:border-cyan-accent/40"
              >
                <span className="flex items-center gap-2 font-semibold text-foreground">
                  <Mail className="size-4 text-cyan-accent" />
                  Personal
                </span>
                <span className="ax-caption">
                  Just my mail — Chat and VideoCall by plan. No company setup.
                </span>
              </button>

              <button
                type="button"
                disabled={busy}
                onClick={() => setPath("business-name")}
                className="ax-press flex w-full flex-col items-start gap-1 rounded-xl border border-border bg-background px-4 py-3 text-left hover:border-cyan-accent/40"
              >
                <span className="flex items-center gap-2 font-semibold text-foreground">
                  <Building2 className="size-4 text-cyan-accent" />
                  Business
                </span>
                <span className="ax-caption">
                  Name your organisation, then invite people when you are ready.
                </span>
              </button>

              {error && (
                <p role="alert" className="ax-caption text-destructive">
                  {error}
                </p>
              )}
              {busy && (
                <p className="ax-caption flex items-center justify-center gap-2">
                  <Loader2 className="size-4 animate-spin" />
                  Opening your inbox…
                </p>
              )}
            </div>
          )}

          {path === "business-name" && (
            <form onSubmit={createOrg} className="space-y-ax-3">
              <div className="text-center">
                <Building2 className="mx-auto size-5 text-cyan-accent" />
                <h1 className="ax-heading mt-ax-2 text-foreground">Name your organisation</h1>
                <p className="ax-caption mt-1">
                  Only the name for now. Custom domain and DNS come later in Ownership Center.
                </p>
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="org" className="ax-caption text-foreground">
                  Organisation name
                </Label>
                <Input
                  id="org"
                  required
                  minLength={2}
                  value={org}
                  onChange={(e) => setOrg(e.target.value)}
                  placeholder="ANEXOMAIL"
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

          {path === "business-people" && (
            <form onSubmit={sendInvites} className="space-y-ax-3">
              <div className="text-center">
                <Users className="mx-auto size-5 text-cyan-accent" />
                <h1 className="ax-heading mt-ax-2 text-foreground">Bring your people in</h1>
                <p className="ax-caption mt-1">
                  Optional now. Paste emails separated by commas, or skip and invite later.
                </p>
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="invites" className="ax-caption text-foreground">
                  Invite by email
                </Label>
                <Input
                  id="invites"
                  value={invites}
                  onChange={(e) => setInvites(e.target.value)}
                  placeholder="sara@anexomail.com, ali@anexomail.com"
                />
              </div>

              {error && (
                <p role="alert" className="ax-caption text-destructive">
                  {error}
                </p>
              )}

              <Button type="submit" className="ax-press w-full" disabled={busy}>
                {busy && <Loader2 className="size-4 animate-spin" />}
                {invites.trim() ? "Send invites and open mail" : "Skip and open mail"}
              </Button>
            </form>
          )}
        </div>
      </div>
    </main>
  );
}

function OnboardingIntro({ loading }: { loading: boolean }) {
  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden bg-background px-4 py-16">
      <div className="ax-in relative w-full max-w-[28rem] text-center">
        <BrandMark />
        <h1 className="ax-heading mt-ax-5 text-foreground">Set up your workspace</h1>
        <p className="ax-body mt-ax-2">
          Sign in first. Then choose Personal or Business — no domain required on day one.
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
              <Link to="/plans">
                <ArrowLeft className="size-4" />
                Choose a plan first
              </Link>
            </Button>
          </div>
        )}
      </div>
    </main>
  );
}
