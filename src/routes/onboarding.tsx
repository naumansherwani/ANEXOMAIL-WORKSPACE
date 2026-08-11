import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { ArrowLeft, Building2, Globe, Loader2, LogIn, Rocket, Users } from "lucide-react";

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
        content:
          "Name your organisation, claim your domain and invite your first people to ANEXOMAIL.",
      },
      { property: "og:title", content: "Set up your workspace — ANEXOMAIL" },
      {
        property: "og:description",
        content: "Name your organisation, claim your domain, invite your team.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: OnboardingPage,
});

function OnboardingPage() {
  const navigate = useNavigate();
  const { session, status, refresh } = useAuth();

  const [step, setStep] = useState(0);
  const [org, setOrg] = useState("");
  const [domain, setDomain] = useState("");
  const [invites, setInvites] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Identity comes first: no workspace setup without an @anexomail.com address.
    if (status === "signed-in" && session && !session.user.anexomail_address)
      void navigate({ to: "/claim", replace: true });
  }, [status, session, navigate]);

  const fail = (e: unknown) =>
    setError(
      e instanceof ApiError
        ? e.isNotImplemented
          ? "This step isn't live on the server yet."
          : e.message
        : "Something went wrong.",
    );

  const createOrg = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await api("/api/workspace/organisations", {
        method: "POST",
        body: JSON.stringify({ name: org, domain: domain.trim() || null }),
      });
      await refresh();
      setStep(1);
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
      void navigate({ to: "/app", replace: true });
    } catch (e) {
      fail(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    status !== "signed-in" ? (
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

        <ol className="mt-ax-5 flex items-center justify-center gap-2" aria-label="Setup progress">
          {["Organisation", "Your people"].map((label, i) => (
            <li key={label} className="flex items-center gap-2">
              <span
                className={`ax-caption rounded-full px-2.5 py-1 font-semibold ${
                  i === step
                    ? "bg-cyan-accent/15 text-cyan-accent"
                    : i < step
                      ? "bg-secondary text-foreground"
                      : "text-muted-foreground"
                }`}
              >
                {label}
              </span>
              {i === 0 && <span aria-hidden className="ax-hairline h-px w-6" />}
            </li>
          ))}
        </ol>

        <div className="mt-ax-4 rounded-2xl border border-border bg-card p-ax-5 shadow-2xl">
          {step === 0 ? (
            <form onSubmit={createOrg} className="space-y-ax-3">
              <div className="text-center">
                <Building2 className="mx-auto size-5 text-cyan-accent" />
                <h1 className="ax-heading mt-ax-2 text-foreground">Name your organisation</h1>
                <p className="ax-caption mt-1">
                  {session?.user.email ?? "You"} becomes the owner — billing and domain sit here.
                </p>
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="org" className="ax-caption text-foreground">
                  Organisation name
                </Label>
                <Input
                  id="org"
                  required
                  value={org}
                  onChange={(e) => setOrg(e.target.value)}
                  placeholder="NEXATECT Global Ltd"
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="domain" className="ax-caption text-foreground">
                  Your domain <span className="text-muted-foreground">(optional now)</span>
                </Label>
                <div className="relative">
                  <Globe className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-steel" />
                  <Input
                    id="domain"
                    className="pl-9"
                    value={domain}
                    onChange={(e) => setDomain(e.target.value)}
                    placeholder="yourcompany.com"
                  />
                </div>
                <p className="ax-caption">
                  DNS, DKIM, SPF and DMARC get verified in the Ownership Center.
                </p>
              </div>

              {error && (
                <p role="alert" className="ax-caption text-destructive">
                  {error}
                </p>
              )}

              <Button type="submit" className="ax-press w-full" disabled={busy}>
                {busy && <Loader2 className="size-4 animate-spin" />}
                Create organisation
              </Button>
            </form>
          ) : (
            <form onSubmit={sendInvites} className="space-y-ax-3">
              <div className="text-center">
                <Users className="mx-auto size-5 text-cyan-accent" />
                <h1 className="ax-heading mt-ax-2 text-foreground">Bring your people in</h1>
                <p className="ax-caption mt-1">
                  Paste emails separated by commas. You can always invite more later.
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
                  placeholder="sara@yourcompany.com, ali@yourcompany.com"
                />
              </div>

              {error && (
                <p role="alert" className="ax-caption text-destructive">
                  {error}
                </p>
              )}

              <Button type="submit" className="ax-press w-full" disabled={busy}>
                {busy && <Loader2 className="size-4 animate-spin" />}
                {invites.trim() ? "Send invites and open workspace" : "Open my workspace"}
              </Button>
            </form>
          )}
        </div>
      </div>
    </main>
    )
  );
}

const explains = [
  {
    title: "What onboarding is",
    body: "The short setup that turns a signed-in account into a working company workspace: your organisation, your domain, and the people who need a mailbox.",
  },
  {
    title: "Who it is for",
    body: "The person who owns the company's email — usually a founder, an office manager or whoever holds the domain. Everyone else is invited later and skips this entirely.",
  },
  {
    title: "What happens during it",
    body: "Two steps. First you name the organisation and, if you are ready, add your domain. Then you paste in the email addresses of the people you want, and they get an invitation.",
  },
  {
    title: "What you will need",
    body: "Your company name, the domain you already own (optional at this point), and the email addresses of the people you want in. Nothing else — no card details are asked for here.",
  },
  {
    title: "After you sign in",
    body: "You land on step one immediately. It takes a couple of minutes, and the workspace opens at the end of it. You can add domains, people and shared addresses at any time after.",
  },
  {
    title: "What about DNS",
    body: "We generate the exact MX, SPF, DKIM and DMARC records your domain needs and verify them for you in the Ownership Center. The domain stays registered in your name.",
  },
];

/** Public face of /onboarding: explains setup instead of showing a bare sign-in. */
function OnboardingIntro({ loading }: { loading: boolean }) {
  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden bg-background px-4 py-16">
      <div
        aria-hidden
        className="pointer-events-none absolute left-1/2 top-[-14rem] h-[30rem] w-[54rem] -translate-x-1/2 rounded-full bg-cyan-accent/10 blur-[130px]"
      />
      <div className="ax-in relative w-full max-w-2xl">
        <Link
          to="/"
          className="ax-focus ax-caption mb-ax-3 inline-flex items-center gap-1.5 rounded-md text-muted-foreground transition-colors hover:text-foreground"
        >
          <ArrowLeft className="size-3.5" aria-hidden="true" />
          Back to home
        </Link>
        <div className="flex justify-center">
          <BrandMark />
        </div>

        <div className="mt-ax-5 text-center">
          <Rocket className="mx-auto size-5 text-cyan-accent" aria-hidden="true" />
          <h1 className="mt-3 text-3xl text-foreground md:text-4xl">Set up your workspace</h1>
          <p className="mx-auto mt-4 max-w-xl text-sm leading-relaxed text-muted-foreground">
            Two steps: name your organisation, then bring your people in. Sign in and you start at
            step one.
          </p>
        </div>

        <div className="mt-8 grid gap-4 sm:grid-cols-2">
          {explains.map((e) => (
            <article key={e.title} className="rounded-2xl border border-border bg-card p-5">
              <h2 className="text-sm font-bold text-foreground">{e.title}</h2>
              <p className="mt-2 text-[13px] leading-relaxed text-muted-foreground">{e.body}</p>
            </article>
          ))}
        </div>

        <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
          <Link
            to="/auth"
            className="inline-flex items-center gap-2 rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
          >
            {loading ? (
              <Loader2 className="size-4 animate-spin" aria-hidden="true" />
            ) : (
              <LogIn className="size-4" aria-hidden="true" />
            )}
            Sign in to start setup
          </Link>
          <Link
            to="/move-in"
            className="rounded-xl border border-border bg-card px-5 py-3 text-sm font-semibold text-foreground transition-colors hover:bg-surface-2"
          >
            Rather we did it for you?
          </Link>
        </div>
      </div>
    </main>
  );
}