import { createFileRoute, useNavigate, Link } from "@tanstack/react-router";
import { useState } from "react";
import { KeyRound, Mail, ShieldCheck, Loader2 } from "lucide-react";

import { BrandMark } from "@/components/site/BrandMark";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { api, ApiError, sessionToken } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/auth")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Sign in — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Sign in to your ANEXOMAIL workspace, or create the account that owns your domain.",
      },
      { property: "og:title", content: "Sign in — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "Sign in to the ANEXOMAIL workspace on your own domain.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AuthPage,
});

type Mode = "login" | "signup" | "link";

type LoginResult =
  | { token: string; mfa_required?: false }
  | { mfa_required: true; challenge_id: string };

function AuthPage() {
  const navigate = useNavigate();
  const { refresh } = useAuth();

  const [mode, setMode] = useState<Mode>("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [code, setCode] = useState("");
  const [challengeId, setChallengeId] = useState<string | null>(null);
  const [linkSent, setLinkSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const finish = async (token: string) => {
    sessionToken.set(token);
    await refresh();
    const session = await api<{ user: { onboarded: boolean } }>("/api/auth/session");
    void navigate({ to: session.user.onboarded ? "/app" : "/onboarding" });
  };

  const fail = (e: unknown) => {
    const message =
      e instanceof ApiError
        ? e.isNotImplemented
          ? "This sign-in method isn't live on the server yet."
          : e.message
        : "Something went wrong.";
    setError(message);
  };

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    setBusy(true);
    try {
      if (challengeId) {
        const res = await api<{ token: string }>("/api/auth/mfa/verify", {
          method: "POST",
          body: JSON.stringify({ challenge_id: challengeId, code }),
          auth: false,
        });
        await finish(res.token);
        return;
      }

      if (mode === "link") {
        await api("/api/auth/magic-link", {
          method: "POST",
          body: JSON.stringify({ email, redirect_to: `${window.location.origin}/auth/callback` }),
          auth: false,
        });
        setLinkSent(true);
        notify.done("Link sent", `Check ${email} to finish signing in.`);
        return;
      }

      if (mode === "signup") {
        const res = await api<{ token: string }>("/api/auth/signup", {
          method: "POST",
          body: JSON.stringify({ email, password, name }),
          auth: false,
        });
        await finish(res.token);
        return;
      }

      const res = await api<LoginResult>("/api/auth/login", {
        method: "POST",
        body: JSON.stringify({ email, password }),
        auth: false,
      });
      if ("mfa_required" in res && res.mfa_required) {
        setChallengeId(res.challenge_id);
        return;
      }
      await finish(res.token);
    } catch (e) {
      fail(e);
    } finally {
      setBusy(false);
    }
  };

  const passkey = async () => {
    setError(null);
    if (!("credentials" in navigator) || !window.PublicKeyCredential) {
      setError("This device doesn't support passkeys.");
      return;
    }
    setBusy(true);
    try {
      const options = await api<{ publicKey: PublicKeyCredentialRequestOptionsJSON }>(
        "/api/auth/passkey/options",
        { method: "POST", body: JSON.stringify({ email }), auth: false },
      );
      const credential = await navigator.credentials.get({
        publicKey: PublicKeyCredential.parseRequestOptionsFromJSON(options.publicKey),
      });
      if (!credential) throw new Error("cancelled");
      const res = await api<{ token: string }>("/api/auth/passkey/verify", {
        method: "POST",
        body: JSON.stringify((credential as PublicKeyCredential).toJSON()),
        auth: false,
      });
      await finish(res.token);
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
        className="pointer-events-none absolute left-1/2 top-[-12rem] h-[28rem] w-[52rem] -translate-x-1/2 rounded-full bg-cyan-accent/10 blur-[120px]"
      />

      <div className="ax-in relative w-full max-w-[27rem]">
        <div className="flex justify-center">
          <Link to="/" className="ax-focus rounded-md">
            <BrandMark />
          </Link>
        </div>

        <div className="mt-ax-5 rounded-2xl border border-border bg-card p-ax-5 shadow-2xl">
          {challengeId ? (
            <Header
              title="Two-step verification"
              sub="Enter the 6-digit code from your authenticator app."
            />
          ) : mode === "signup" ? (
            <Header title="Create your workspace" sub="One account owns the domain and the org." />
          ) : mode === "link" ? (
            <Header title="Email me a link" sub="No password. The link signs you straight in." />
          ) : (
            <Header title="Sign in" sub="Your mail, people, calendar and work — one surface." />
          )}

          {linkSent ? (
            <div className="mt-ax-4 rounded-xl border border-border bg-secondary/50 p-ax-4 text-center">
              <Mail className="mx-auto size-5 text-cyan-accent" />
              <p className="ax-label mt-ax-2 text-foreground">Link sent to {email}</p>
              <p className="ax-caption mt-1">It expires in 15 minutes and works once.</p>
              <Button
                variant="ghost"
                className="mt-ax-3"
                onClick={() => {
                  setLinkSent(false);
                  setMode("login");
                }}
              >
                Use a password instead
              </Button>
            </div>
          ) : (
            <form onSubmit={submit} className="mt-ax-4 space-y-ax-3">
              {challengeId ? (
                <Field
                  id="code"
                  label="Authentication code"
                  value={code}
                  onChange={setCode}
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  placeholder="123456"
                />
              ) : (
                <>
                  {mode === "signup" && (
                    <Field
                      id="name"
                      label="Your name"
                      value={name}
                      onChange={setName}
                      autoComplete="name"
                      placeholder="Nauman Sherwani"
                    />
                  )}
                  <Field
                    id="email"
                    label="Work email"
                    type="email"
                    value={email}
                    onChange={setEmail}
                    autoComplete="email"
                    placeholder="you@yourdomain.com"
                  />
                  {mode !== "link" && (
                    <Field
                      id="password"
                      label="Password"
                      type="password"
                      value={password}
                      onChange={setPassword}
                      autoComplete={mode === "signup" ? "new-password" : "current-password"}
                      placeholder="••••••••••••"
                    />
                  )}
                </>
              )}

              {error && (
                <p role="alert" className="ax-caption text-destructive">
                  {error}
                </p>
              )}

              <Button type="submit" className="ax-press w-full" disabled={busy}>
                {busy && <Loader2 className="size-4 animate-spin" />}
                {challengeId
                  ? "Verify and continue"
                  : mode === "signup"
                    ? "Create workspace"
                    : mode === "link"
                      ? "Send me the link"
                      : "Sign in"}
              </Button>
            </form>
          )}

          {!challengeId && !linkSent && (
            <>
              <div className="my-ax-4 flex items-center gap-3">
                <div aria-hidden className="ax-hairline h-px flex-1" />
                <span className="ax-caption">or</span>
                <div aria-hidden className="ax-hairline h-px flex-1" />
              </div>

              <div className="space-y-ax-2">
                <Button
                  type="button"
                  variant="outline"
                  className="ax-press w-full"
                  onClick={passkey}
                  disabled={busy}
                >
                  <KeyRound className="size-4" />
                  Continue with a passkey
                </Button>
                {mode !== "link" && (
                  <Button
                    type="button"
                    variant="ghost"
                    className="w-full"
                    onClick={() => {
                      setError(null);
                      setMode("link");
                    }}
                  >
                    <Mail className="size-4" />
                    Email me a sign-in link
                  </Button>
                )}
              </div>

              <p className="ax-caption mt-ax-4 text-center">
                {mode === "signup" ? "Already have a workspace?" : "New here?"}{" "}
                <button
                  type="button"
                  className="ax-focus rounded font-semibold text-cyan-accent"
                  onClick={() => {
                    setError(null);
                    setMode(mode === "signup" ? "login" : "signup");
                  }}
                >
                  {mode === "signup" ? "Sign in" : "Create a workspace"}
                </button>
              </p>
            </>
          )}
        </div>

        <p className="ax-caption mt-ax-4 flex items-center justify-center gap-1.5">
          <ShieldCheck className="size-3.5 text-cyan-accent" />
          Sessions are device-bound and revocable from your account at any time.
        </p>
      </div>
    </main>
  );
}

function Header({ title, sub }: { title: string; sub: string }) {
  return (
    <div className="text-center">
      <h1 className="ax-heading text-foreground">{title}</h1>
      <p className="ax-caption mt-1">{sub}</p>
    </div>
  );
}

function Field({
  id,
  label,
  value,
  onChange,
  ...rest
}: {
  id: string;
  label: string;
  value: string;
  onChange: (v: string) => void;
} & Omit<React.ComponentProps<typeof Input>, "onChange" | "value" | "id">) {
  return (
    <div className="space-y-1.5">
      <Label htmlFor={id} className="ax-caption text-foreground">
        {label}
      </Label>
      <Input
        id={id}
        value={value}
        required
        onChange={(e) => onChange(e.target.value)}
        {...rest}
      />
    </div>
  );
}