import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { Building2, Globe, Loader2, Users } from "lucide-react";

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
    if (status === "signed-out") void navigate({ to: "/auth", replace: true });
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
  );
}