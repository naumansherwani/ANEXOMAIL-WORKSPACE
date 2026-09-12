import { createFileRoute, useNavigate, Link } from "@tanstack/react-router";
import { useEffect, useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";

import { AuthCinema } from "@/components/site/AuthCinema";
import { CinematicSplash } from "@/components/site/CinematicSplash";
import { WorkspaceKindCards } from "@/components/site/WorkspaceKindCards";
import { Eye, EyeOff, KeyRound, Mail, ShieldCheck, Loader2 } from "lucide-react";

import { BrandMark } from "@/components/site/BrandMark";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { api, ApiError, sessionToken } from "@/lib/api";
import { useAuth, type Session } from "@/lib/auth";
import { collectDeviceSignals } from "@/lib/chat-safety";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

const KIND_KEY = "anexo.pending.workspace_kind";

function lastNameFromLegal(full: string) {
  const parts = full.trim().split(/\s+/).filter(Boolean);
  return parts.length > 1 ? parts[parts.length - 1] : "";
}

export const Route = createFileRoute("/auth")({
  ssr: false,
  validateSearch: (search: Record<string, unknown>) => ({
    mode:
      search.mode === "signup" || search.mode === "reset" || search.mode === "forgot"
        ? search.mode
        : undefined,
    recovery: typeof search.recovery === "string" ? search.recovery : undefined,
  }),
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

type Mode = "login" | "kind" | "signup" | "link" | "forgot" | "reset";

// LOCKED: social sign-in (Google / Apple / GitHub) ANEXOMAIL par nahi hai.
// User khud account banata hai (email + password) → Supabase → dashboard.

type LoginResult =
  | ({ token: string; mfa_required?: false } & Session)
  | { mfa_required: true; challenge_id: string };

function AuthPage() {
  const navigate = useNavigate();
  const { acceptSession } = useAuth();
  const search = Route.useSearch();

  const [mode, setMode] = useState<Mode>(() => {
    if (search.mode === "signup") return "kind";
    if (search.mode === "reset" || search.mode === "forgot") return search.mode;
    return "login";
  });
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirm, setPasswordConfirm] = useState("");
  const [name, setName] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [workRole, setWorkRole] = useState("");
  const [avatarUrl, setAvatarUrl] = useState("");
  const [recoveryKind, setRecoveryKind] = useState("gmail");
  const [recoveryEmail, setRecoveryEmail] = useState("");
  const [code, setCode] = useState("");
  const [challengeId, setChallengeId] = useState<string | null>(null);
  const [linkSent, setLinkSent] = useState(false);
  /** Passkey enrolment gate — signup ke baad lazmi step. */
  const [enrol, setEnrol] = useState(false);
  const [enrolBlocked, setEnrolBlocked] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [showSplash, setShowSplash] = useState(false);
  const [redirectTo, setRedirectTo] = useState<string | null>(null);
  const [workspaceKind, setWorkspaceKind] = useState<"personal" | "business" | null>(null);
  const [moreDetails, setMoreDetails] = useState(false);
  const lastNameTouched = useRef(false);
  const fromSignup = useRef(false);

  const finish = async (token: string, authenticated?: Session) => {
    sessionToken.set(token);
    const session = authenticated ?? (await api<Session>("/api/auth/session"));
    acceptSession(session);
    window.sessionStorage.removeItem("anexo.pending.checkout");
    // Polar checkout founder ke polar-rust-payment PM2 :3400 par hai — yahan
    // login polar.sh pe nahi bhejte. Awam ANEXOMAIL pages pe rehta hai.
    // FOUNDER PROTOCOL: founder ko awam ka claim/onboarding kabhi nahi — seedha /app.
    const stored =
      typeof window !== "undefined" ? window.sessionStorage.getItem(KIND_KEY) : null;
    const kind =
      session.user.account_kind ||
      (stored === "personal" || stored === "business" ? stored : null);
    const createdNow = fromSignup.current;
    fromSignup.current = false;
    let target = "/onboarding";
    if (session.user.is_founder) target = "/app";
    else if (createdNow) target = "/plans";
    else if (!session.user.anexomail_address) target = "/claim";
    else if (kind === "personal") {
      try {
        await api("/api/workspace/personal", { method: "POST", body: "{}" });
      } catch {
        /* session still opens; onboarding can retry */
      }
      window.sessionStorage.removeItem(KIND_KEY);
      target = "/dashboard";
    } else if (session.user.onboarded) target = "/dashboard";
    setRedirectTo(target);
    setShowSplash(true);
  };

  const fail = (e: unknown) => {
    const raw =
      e instanceof ApiError
        ? e.message
        : e instanceof Error
          ? e.message
          : "";
    const message =
      e instanceof ApiError && e.isNotImplemented
        ? "This sign-in method isn't live on the server yet."
        : raw === "password_mismatch"
          ? "Passwords do not match."
          : /invalid login|invalid_credentials/i.test(raw)
            ? "That email and password did not match. Use your @anexomail.com address."
            : raw || "Something went wrong.";
    setError(message);
  };

  const pickKind = (kind: "personal" | "business") => {
    setError(null);
    setWorkspaceKind(kind);
    try {
      window.sessionStorage.setItem(KIND_KEY, kind);
    } catch {
      /* ignore */
    }
    setMode("signup");
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

      if (mode === "forgot") {
        const res = await api<{ ok: boolean; sent_to?: string }>("/api/auth/forgot-password", {
          method: "POST",
          body: JSON.stringify({ email }),
          auth: false,
        });
        setLinkSent(true);
        notify.done(
          "Reset link sent",
          res.sent_to === "recovery"
            ? "If this account has a recovery inbox, the link went there — not only to ANEXOMAIL."
            : `Check ${email} to choose a new password.`,
        );
        return;
      }

      if (mode === "reset") {
        if (password !== passwordConfirm) throw new Error("password_mismatch");
        const accessToken = new URLSearchParams(window.location.hash.replace(/^#/, "")).get(
          "access_token",
        );
        await api("/api/auth/reset-password", {
          method: "POST",
          body: JSON.stringify({
            access_token: accessToken,
            recovery: search.recovery,
            password,
          }),
          auth: false,
        });
        notify.done("Password updated", "You can now sign in with your new password.");
        setPassword("");
        setPasswordConfirm("");
        setMode("login");
        return;
      }

      if (mode === "signup") {
        if (password !== passwordConfirm) throw new Error("password_mismatch");
        const stored = window.sessionStorage.getItem(KIND_KEY);
        const kind =
          workspaceKind ||
          (stored === "personal" || stored === "business" ? stored : null);
        if (!kind) {
          setMode("kind");
          return;
        }
        const res = await api<{
          token?: string;
          confirmation_required?: boolean;
          family?: boolean;
          needs_passkey?: boolean;
        }>("/api/auth/signup", {
          method: "POST",
          body: JSON.stringify({
            email,
            password,
            legal_name: name,
            display_name: displayName.trim() || lastNameFromLegal(name) || name.trim(),
            work_role: workRole || null,
            avatar_url: avatarUrl || null,
            preferences: {
              locale: navigator.language,
              workspace_kind: kind,
            },
            recovery_kind: recoveryKind,
            recovery_email: recoveryEmail,
            signals: collectDeviceSignals(),
          }),
          auth: false,
        });
        if (res.confirmation_required || !res.token) {
          setLinkSent(true);
          notify.done("Confirm your email", `We sent a confirmation link to ${email}.`);
          return;
        }
        sessionToken.set(res.token);
        fromSignup.current = true;
        if (res.family || !res.needs_passkey) {
          await finish(res.token);
          return;
        }
        setEnrol(true);
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
      await finish(res.token, res);
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

  /**
   * Passkey enrolment (WebAuthn create) — signup ke foran baad, lazmi.
   * Server abhi register endpoint na de to sach bolte hain, fake nahi karte.
   */
  const enrolPasskey = async () => {
    setError(null);
    setEnrolBlocked(null);
    if (!("credentials" in navigator) || !window.PublicKeyCredential) {
      setEnrolBlocked(
        "This device can't create a passkey. Open the link on a phone or laptop with Face ID, Touch ID, fingerprint or Windows Hello.",
      );
      return;
    }
    setBusy(true);
    try {
      const options = await api<{ publicKey: PublicKeyCredentialCreationOptionsJSON }>(
        "/api/auth/passkey/register/options",
        { method: "POST", body: JSON.stringify({ email }) },
      );
      const credential = await navigator.credentials.create({
        publicKey: PublicKeyCredential.parseCreationOptionsFromJSON(options.publicKey),
      });
      if (!credential) throw new Error("cancelled");
      const res = await api<{ token?: string }>("/api/auth/passkey/register/verify", {
        method: "POST",
        body: JSON.stringify((credential as PublicKeyCredential).toJSON()),
      });
      notify.done("Passkey saved", "This device can now sign you in without a password.");
      setEnrol(false);
      const token = res.token ?? sessionToken.get();
      if (!token) throw new Error("session_missing");
      await finish(token);
    } catch (e) {
      if (e instanceof ApiError && e.isNotImplemented) {
        setEnrolBlocked(
          "Passkey enrolment isn't live on the server yet — it will be required as soon as it is.",
        );
      } else {
        fail(e);
      }
    } finally {
      setBusy(false);
    }
  };

  // ── Passkey enrolment screen (post-signup) — centred, no split ──
  if (enrol) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-background px-4 py-16">
        <div className="ax-in w-full max-w-[27rem] rounded-2xl border border-border bg-card p-ax-5 text-center shadow-2xl">
          <BrandMark />
          <ShieldCheck className="mx-auto mt-ax-4 size-6 text-cyan-accent" aria-hidden="true" />
          <h1 className="ax-heading mt-ax-3 text-foreground">Add your passkey</h1>
          <p className="ax-caption mt-2">
            Face ID, Touch ID, fingerprint or Windows Hello on this device. If this device cannot
            do that, continue with your password — we will not fake a saved passkey.
          </p>
          {enrolBlocked && (
            <p role="alert" className="ax-caption mt-ax-3 text-destructive">
              {enrolBlocked}
            </p>
          )}
          {error && (
            <p role="alert" className="ax-caption mt-ax-3 text-destructive">
              {error}
            </p>
          )}
          <Button className="ax-press mt-ax-4 w-full" onClick={enrolPasskey} disabled={busy}>
            {busy && <Loader2 className="size-4 animate-spin" />}
            <KeyRound className="size-4" />
            Create my passkey
          </Button>
          <Button
            variant="ghost"
            className="mt-ax-2 w-full"
            onClick={() => {
              const token = sessionToken.get();
              if (!token) {
                setEnrolBlocked("Your session expired. Sign in again.");
                return;
              }
              setEnrol(false);
              void finish(token);
            }}
          >
            Continue with password on this device
          </Button>
          {enrolBlocked && (
            <p className="ax-caption mt-ax-2">
              Open ANEXOMAIL on a phone or laptop with Face ID, Touch ID or Windows Hello to add a
              passkey later from Account.
            </p>
          )}
          <p className="ax-caption mt-ax-3">
            Two days of real, limited workspace access start the moment you continue.
          </p>
        </div>
      </main>
    );
  }

  // ── Main auth surface — cinematic split layout ──
  return (
    <>
      <main className="flex min-h-screen overflow-hidden bg-background">
        {/* LEFT — Cinematic panel (desktop only) */}
        <AuthCinema className="hidden lg:flex" />

        {/* RIGHT — Form panel */}
        <div className="flex flex-1 items-center justify-center px-6 py-12 lg:px-14">
          <div className={cn("ax-in w-full", mode === "kind" ? "max-w-[42rem]" : "max-w-[28rem]")}>

            <div className="mb-6 lg:hidden">
              <Link to="/" className="ax-focus rounded-md">
                <BrandMark />
              </Link>
            </div>

            {/* Card */}
            <div className="rounded-2xl border border-border bg-card p-ax-5 shadow-2xl">
              {mode === "kind" && !challengeId && !linkSent ? (
                <>
                  <WorkspaceKindCards
                    busy={busy}
                    onPersonal={() => pickKind("personal")}
                    onBusiness={() => pickKind("business")}
                  />
                  <p className="ax-caption mt-ax-4 text-center">
                    Already have a workspace?{" "}
                    <button
                      type="button"
                      className="ax-focus rounded font-semibold text-cyan-accent"
                      onClick={() => {
                        setError(null);
                        setMode("login");
                      }}
                    >
                      Sign in
                    </button>
                  </p>
                </>
              ) : (
                <>
              {/* Animated header — smooth morph on mode switch */}
              <AnimatePresence mode="wait">
                <motion.div
                  key={challengeId ? "mfa-header" : mode + "-header"}
                  initial={{ opacity: 0, y: 6 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -6 }}
                  transition={{ duration: 0.2, ease: "easeOut" }}
                >
                  {challengeId ? (
                    <Header
                      title="Two-step verification"
                      sub="Enter the 6-digit code from your authenticator app."
                    />
                  ) : mode === "signup" ? (
                    <Header
                      title="Create your account"
                      sub={
                        workspaceKind === "business"
                          ? "Business workspace — then choose your plan."
                          : "Personal workspace — then choose your plan."
                      }
                    />
                  ) : mode === "link" ? (
                    <Header title="Email me a link" sub="No password. The link signs you straight in." />
                  ) : mode === "forgot" ? (
                    <Header
                      title="Reset your password"
                      sub="If you saved a recovery inbox, the link goes there — Gmail, iCloud or whatever you chose."
                    />
                  ) : mode === "reset" ? (
                    <Header title="Choose a new password" sub="Use 6 to 15 characters." />
                  ) : (
                    <Header title="Sign in" sub="Your mail, people, calendar and work — one surface." />
                  )}
                </motion.div>
              </AnimatePresence>

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
                <AnimatePresence mode="wait">
                  <motion.form
                    key={challengeId ? "mfa" : mode}
                    initial={{ opacity: 0, x: 12 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, x: -12 }}
                    transition={{ duration: 0.22, ease: "easeOut" }}
                    onSubmit={submit}
                    className="mt-ax-4 space-y-ax-3"
                  >
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
                          <>
                            <Field
                              id="signup-legal-name"
                              label="Full legal name"
                              value={name}
                              onChange={(v) => {
                                setName(v);
                                if (!lastNameTouched.current) setDisplayName(lastNameFromLegal(v));
                              }}
                              autoComplete="off"
                              placeholder="Your full name"
                            />
                            <Field
                              id="signup-last-name"
                              label="Last name"
                              value={displayName}
                              onChange={(v) => {
                                lastNameTouched.current = true;
                                setDisplayName(v);
                              }}
                              autoComplete="off"
                            />
                            <button
                              type="button"
                              className="ax-caption font-semibold text-cyan-accent"
                              onClick={() => setMoreDetails((v) => !v)}
                            >
                              {moreDetails ? "Hide extra details" : "Add work role and photo (optional)"}
                            </button>
                            {moreDetails ? (
                              <>
                            <Field
                              id="work-role"
                              label="Work role"
                              value={workRole}
                              onChange={setWorkRole}
                              placeholder="Founder, designer, operations…"
                              required={false}
                            />
                            <Field
                              id="avatar-url"
                              label="Profile photo URL (optional)"
                              type="url"
                              value={avatarUrl}
                              onChange={setAvatarUrl}
                              placeholder="https://…"
                              required={false}
                            />
                              </>
                            ) : null}
                          </>
                        )}
                        {mode !== "reset" && (
                          <Field
                            id="email"
                            label="Email"
                            type="email"
                            value={email}
                            onChange={setEmail}
                            autoComplete="email"
                            placeholder="name@anexomail.com"
                          />
                        )}
                        {mode !== "link" && mode !== "forgot" && (
                          <>
                            <PasswordField
                              id="password"
                              label="Password"
                              value={password}
                              onChange={setPassword}
                              autoComplete={mode === "login" ? "current-password" : "new-password"}
                              placeholder={mode === "signup" || mode === "reset" ? "6–15 characters" : undefined}
                            />
                            {/* Password strength bar — signup only */}
                            {mode === "signup" && <PasswordStrength password={password} />}
                          </>
                        )}
                        {(mode === "signup" || mode === "reset") && (
                          <PasswordField
                            id="password-confirm"
                            label="Confirm password"
                            value={passwordConfirm}
                            onChange={setPasswordConfirm}
                            autoComplete="new-password"
                          />
                        )}
                        {mode === "signup" && (
                          <>
                            <div className="space-y-1.5">
                              <Label htmlFor="recovery-kind" className="ax-caption text-foreground">
                                Recovery account
                              </Label>
                              <select
                                id="recovery-kind"
                                className="flex h-10 w-full rounded-md border border-border bg-background px-3 text-sm"
                                value={recoveryKind}
                                onChange={(event) => setRecoveryKind(event.target.value)}
                              >
                                <option value="gmail">Gmail</option>
                                <option value="apple">Apple / iCloud email</option>
                                <option value="outlook">Outlook</option>
                                <option value="other_email">Other email I can open</option>
                              </select>
                              <p className="ax-caption">
                                Reset links go here. SMS is not live yet. Not Sign in with Apple.
                              </p>
                            </div>
                            <Field
                              id="recovery-email"
                              label="Recovery email"
                              type="email"
                              value={recoveryEmail}
                              onChange={setRecoveryEmail}
                              autoComplete="off"
                              placeholder="you@gmail.com"
                            />
                          </>
                        )}
                      </>
                    )}

                    {error && (
                      <motion.p
                        initial={{ opacity: 0, y: -4 }}
                        animate={{ opacity: 1, y: 0 }}
                        role="alert"
                        className="ax-caption text-destructive"
                      >
                        {error}
                      </motion.p>
                    )}

                    <Button type="submit" className="ax-press w-full" disabled={busy}>
                      {busy && <Loader2 className="size-4 animate-spin" />}
                      {challengeId
                        ? "Verify and continue"
                        : mode === "signup"
                          ? "Create account"
                          : mode === "forgot"
                            ? "Send reset link"
                            : mode === "reset"
                              ? "Save new password"
                              : mode === "link"
                                ? "Send me the link"
                                : "Sign in"}
                    </Button>
                  </motion.form>
                </AnimatePresence>
              )}

              {!challengeId && !linkSent && (
                <>
                  {mode === "login" && (
                    <Button
                      type="button"
                      variant="ghost"
                      className="mt-ax-2 w-full"
                      onClick={() => {
                        setError(null);
                        setMode("forgot");
                      }}
                    >
                      Forgot your password?
                    </Button>
                  )}
                  {mode === "login" ? (
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
                  </div>
                    </>
                  ) : null}

                  {mode === "signup" ? (
                    <p className="ax-caption mt-ax-3 text-center">
                      Next you choose a plan on{" "}
                      <span className="font-semibold text-foreground">anexomail.com/plans</span>.
                    </p>
                  ) : null}

                  <p className="ax-caption mt-ax-4 text-center">
                    {mode === "signup"
                      ? "Already have a workspace?"
                      : mode === "forgot" || mode === "reset"
                        ? "Remembered it?"
                        : "New here?"}{" "}
                    {mode === "login" ? (
                      <button
                        type="button"
                        className="ax-focus rounded font-semibold text-cyan-accent"
                        onClick={() => {
                          setError(null);
                          setMode("kind");
                        }}
                      >
                        Create your account for workspace
                      </button>
                    ) : mode === "signup" ? (
                      <>
                        <button
                          type="button"
                          className="ax-focus rounded font-semibold text-cyan-accent"
                          onClick={() => {
                            setError(null);
                            setMode("kind");
                          }}
                        >
                          Back
                        </button>
                        {" · "}
                        <button
                          type="button"
                          className="ax-focus rounded font-semibold text-cyan-accent"
                          onClick={() => {
                            setError(null);
                            setMode("login");
                          }}
                        >
                          Sign in
                        </button>
                      </>
                    ) : (
                      <button
                        type="button"
                        className="ax-focus rounded font-semibold text-cyan-accent"
                        onClick={() => {
                          setError(null);
                          setMode("login");
                        }}
                      >
                        Sign in
                      </button>
                    )}
                  </p>
                </>
              )}
                </>
              )}
            </div>

            {/* Shield footer */}
            <p className="ax-caption mt-ax-4 flex items-center justify-center gap-1.5">
              <ShieldCheck className="size-3.5 text-cyan-accent" />
              Sessions are device-bound and revocable from your account at any time.
            </p>
          </div>
        </div>
      </main>

      <CinematicSplash
        open={showSplash}
        onDone={() => {
          if (!redirectTo) return;
          // In-app navigate — session memory (acceptSession) rehti hai.
          // window.location.replace reload karta tha → gate dobara /auth bounce.
          void navigate({ to: redirectTo });
        }}
      />
    </>
  );
}

// ── Sub-components ────────────────────────────────────────────────────────────

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
      <Input id={id} value={value} required onChange={(e) => onChange(e.target.value)} {...rest} />
    </div>
  );
}

function PasswordField({
  id,
  label,
  value,
  onChange,
  autoComplete,
  placeholder,
}: {
  id: string;
  label: string;
  value: string;
  onChange: (value: string) => void;
  autoComplete: string;
  placeholder?: string;
}) {
  const [visible, setVisible] = useState(false);
  return (
    <div className="space-y-1.5">
      <Label htmlFor={id} className="ax-caption text-foreground">
        {label}
      </Label>
      <div className="relative">
        <Input
          id={id}
          type={visible ? "text" : "password"}
          value={value}
          required
          minLength={6}
          maxLength={15}
          autoComplete={autoComplete}
          className="pr-10"
          placeholder={placeholder}
          onChange={(event) => onChange(event.target.value)}
        />
        <button
          type="button"
          className="absolute inset-y-0 right-0 flex w-10 items-center justify-center text-muted-foreground transition-colors hover:text-foreground focus-visible:outline-none"
          aria-label={visible ? "Hide password" : "Show password"}
          title={visible ? "Hide password" : "Show password"}
          onClick={() => setVisible((current) => !current)}
        >
          {visible ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
        </button>
      </div>
    </div>
  );
}

/** Password strength bar — signup mode only. 4-bar visual indicator. */
function PasswordStrength({ password }: { password: string }) {
  if (!password) return null;
  const score = getPasswordScore(password);
  const labels = ["", "Weak", "Fair", "Good", "Strong"];
  const colours = [
    "",
    "bg-destructive",
    "bg-orange-400",
    "bg-yellow-400",
    "bg-green-500",
  ];
  return (
    <motion.div
      initial={{ opacity: 0, y: -4 }}
      animate={{ opacity: 1, y: 0 }}
      className="space-y-1.5"
    >
      <div className="flex gap-1" aria-hidden>
        {[1, 2, 3, 4].map((i) => (
          <div
            key={i}
            className={`h-1 flex-1 rounded-full transition-all duration-300 ${i <= score ? colours[score] : "bg-border"}`}
          />
        ))}
      </div>
      <p className="ax-caption text-right">
        {labels[score]}{" "}
        {score < 3 && <span className="text-muted-foreground">— add numbers or symbols</span>}
      </p>
    </motion.div>
  );
}

function getPasswordScore(pw: string): 1 | 2 | 3 | 4 {
  let s = 0;
  if (pw.length >= 8) s++;
  if (/[A-Z]/.test(pw)) s++;
  if (/[0-9]/.test(pw)) s++;
  if (/[^A-Za-z0-9]/.test(pw)) s++;
  return (Math.max(1, s) as 1 | 2 | 3 | 4);
}
