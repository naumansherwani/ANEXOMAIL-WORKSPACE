import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { ArrowLeft, AtSign, Check, Loader2, LogIn, ShieldCheck, X } from "lucide-react";

import { BrandMark } from "@/components/site/BrandMark";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { api, ApiError, sessionToken } from "@/lib/api";
import { useAuth } from "@/lib/auth";

/**
 * Identity claim — locked rule: signing in with Google, Apple or GitHub only
 * proves who you are. Before the workspace opens, every account must own an
 * `@anexomail.com` identity. No skip, no back door.
 */
export const Route = createFileRoute("/claim")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Claim your @anexomail.com address — ANEXOMAIL" },
      {
        name: "description",
        content:
          "Pick the @anexomail.com address that becomes your workspace identity. Your own company domain can be added later.",
      },
      { property: "og:title", content: "Claim your @anexomail.com address" },
      {
        property: "og:description",
        content: "Your workspace identity on anexomail.com — one address, yours for good.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: ClaimPage,
});

const DOMAIN = "anexomail.com";
const RULE = /^[a-z0-9]([a-z0-9.-]{1,28})[a-z0-9]$/;

type Availability =
  | { state: "idle" }
  | { state: "checking" }
  | { state: "free" }
  | { state: "taken"; reason: string }
  | { state: "unavailable"; reason: string };

function ClaimPage() {
  const navigate = useNavigate();
  const { session, status, refresh } = useAuth();

  const [username, setUsername] = useState("");
  const [availability, setAvailability] = useState<Availability>({ state: "idle" });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const normalised = username.trim().toLowerCase();
  const valid = RULE.test(normalised);
  const address = `${normalised || "you"}@${DOMAIN}`;

  useEffect(() => {
    if (session?.user.anexomail_address) void navigate({ to: "/onboarding", replace: true });
  }, [status, session, navigate]);

  // Live availability against the real directory. Debounced, never guessed.
  useEffect(() => {
    if (!valid) {
      setAvailability({ state: "idle" });
      return;
    }
    setAvailability({ state: "checking" });
    const timer = window.setTimeout(() => {
      void (async () => {
        try {
          const res = await api<{ available: boolean; reason?: string }>(
            `/api/auth/identity/check?username=${encodeURIComponent(normalised)}`,
          );
          setAvailability(
            res.available
              ? { state: "free" }
              : { state: "taken", reason: res.reason ?? "Already taken." },
          );
        } catch (e) {
          setAvailability({
            state: "unavailable",
            reason:
              e instanceof ApiError && e.isNotImplemented
                ? "The address directory isn't live on the server yet."
                : e instanceof ApiError
                  ? e.message
                  : "Could not check this address.",
          });
        }
      })();
    }, 350);
    return () => window.clearTimeout(timer);
  }, [normalised, valid]);

  const claim = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const res = await api<{ address: string; token?: string }>("/api/auth/identity/claim", {
        method: "POST",
        body: JSON.stringify({ username: normalised }),
      });
      if (res.token) sessionToken.set(res.token);
      await refresh();
      void navigate({ to: "/onboarding", replace: true });
    } catch (e) {
      setError(
        e instanceof ApiError
          ? e.isNotImplemented
            ? "Address claiming isn't live on the server yet."
            : e.message
          : "Could not claim this address.",
      );
    } finally {
      setBusy(false);
    }
  };

  return (
    status !== "signed-in" ? (
      <ClaimIntro loading={status === "loading"} />
    ) : (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden bg-background px-4 py-16">
      <div
        aria-hidden
        className="pointer-events-none absolute left-1/2 top-[-13rem] h-[29rem] w-[53rem] -translate-x-1/2 rounded-full bg-cyan-accent/10 blur-[125px]"
      />

      <div className="ax-in relative w-full max-w-[29rem]">
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

        <div className="mt-ax-5 rounded-2xl border border-border bg-card p-ax-5 shadow-2xl">
          <div className="text-center">
            <AtSign className="mx-auto size-5 text-cyan-accent" />
            <h1 className="ax-heading mt-ax-2 text-foreground">Claim your address</h1>
            <p className="ax-caption mt-1">
              {session?.user.email ? `${session.user.email} is verified. ` : ""}
              Every workspace starts with one identity on {DOMAIN}. Your own company domain can be
              added after this.
            </p>
          </div>

          <form onSubmit={claim} className="mt-ax-4 space-y-ax-3">
            <div className="space-y-1.5">
              <Label htmlFor="username" className="ax-caption text-foreground">
                Choose your username
              </Label>
              <div className="flex items-center gap-2">
                <Input
                  id="username"
                  required
                  autoFocus
                  value={username}
                  onChange={(e) => setUsername(e.target.value.replace(/\s+/g, ""))}
                  placeholder="nauman"
                  autoComplete="off"
                  spellCheck={false}
                />
                <span className="ax-label shrink-0 text-muted-foreground">@{DOMAIN}</span>
              </div>

              <p className="ax-caption flex items-center gap-1.5">
                {availability.state === "checking" && (
                  <>
                    <Loader2 className="size-3.5 animate-spin text-cyan-accent" />
                    Checking {address}…
                  </>
                )}
                {availability.state === "free" && (
                  <>
                    <Check className="size-3.5 text-cyan-accent" />
                    <span className="text-foreground">{address}</span> is yours.
                  </>
                )}
                {availability.state === "taken" && (
                  <>
                    <X className="size-3.5 text-destructive" />
                    {availability.reason}
                  </>
                )}
                {availability.state === "unavailable" && (
                  <span className="text-destructive">{availability.reason}</span>
                )}
                {availability.state === "idle" &&
                  "3–30 characters, lowercase letters, numbers, dots and dashes."}
              </p>
            </div>

            {error && (
              <p role="alert" className="ax-caption text-destructive">
                {error}
              </p>
            )}

            <Button
              type="submit"
              className="ax-press w-full"
              disabled={busy || !valid || availability.state !== "free"}
            >
              {busy && <Loader2 className="size-4 animate-spin" />}
              Claim {valid ? address : "my address"}
            </Button>
          </form>
        </div>

        <p className="ax-caption mt-ax-4 flex items-center justify-center gap-1.5 text-center">
          <ShieldCheck className="size-3.5 text-cyan-accent" />
          This address is permanent and only ever belongs to you.
        </p>
      </div>
    </main>
    )
  );
}

const explains = [
  {
    title: "What claiming means",
    body: `Your workspace identity is one permanent address on ${DOMAIN}, for example nauman@${DOMAIN}. Claiming it reserves that name for you for good — it is never recycled and never given to anyone else.`,
  },
  {
    title: "Who this page is for",
    body: "Anyone who has just signed in for the first time. Signing in with Google, Apple or GitHub only proves who you are; it does not give you a mailbox. This step does.",
  },
  {
    title: "Why you have to sign in first",
    body: "An address can only be reserved against a verified person, otherwise names could be grabbed in bulk by anyone. So the check runs against your signed-in account, and the name is held the moment you claim it.",
  },
  {
    title: "What happens after this",
    body: "You pick a name, we check it live against the real directory, and the moment you claim it you go straight to workspace setup — your organisation, your own company domain, and your first people.",
  },
];

/** Public face of /claim: explains the step instead of showing a bare sign-in. */
function ClaimIntro({ loading }: { loading: boolean }) {
  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden bg-background px-4 py-16">
      <div
        aria-hidden
        className="pointer-events-none absolute left-1/2 top-[-13rem] h-[29rem] w-[53rem] -translate-x-1/2 rounded-full bg-cyan-accent/10 blur-[125px]"
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
          <AtSign className="mx-auto size-5 text-cyan-accent" aria-hidden="true" />
          <h1 className="mt-3 text-3xl text-foreground md:text-4xl">
            Claim your @{DOMAIN} address
          </h1>
          <p className="mx-auto mt-4 max-w-xl text-sm leading-relaxed text-muted-foreground">
            One address becomes your workspace identity. It takes a few seconds, and it happens
            before anything else — your own company domain is added right after.
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
            Sign in to claim your address
          </Link>
          <Link
            to="/plans"
            className="rounded-xl border border-border bg-card px-5 py-3 text-sm font-semibold text-foreground transition-colors hover:bg-surface-2"
          >
            See plans first
          </Link>
        </div>

        <p className="ax-caption mt-6 flex items-center justify-center gap-1.5 text-center">
          <ShieldCheck className="size-3.5 text-cyan-accent" aria-hidden="true" />
          Your address is permanent and only ever belongs to you.
        </p>
      </div>
    </main>
  );
}