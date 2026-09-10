import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Eye, EyeOff, KeyRound, Laptop, ShieldCheck, Loader2 } from "lucide-react";

import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState, StateBlock } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { api, ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/account")({
  head: () => ({
    meta: [
      { title: "Account & sessions — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Review the devices signed in to your ANEXOMAIL account, revoke sessions and manage passkeys and two-step verification.",
      },
      { property: "og:title", content: "Account & sessions — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "Devices, sessions, passkeys and two-step verification for your account.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AccountPage,
});

type DeviceSession = {
  id: string;
  device: string | null;
  browser: string | null;
  ip: string | null;
  location: string | null;
  last_seen_at: string;
  current: boolean;
};

function AccountPage() {
  const { session, refresh } = useAuth();
  const queryClient = useQueryClient();
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [passwordVisible, setPasswordVisible] = useState(false);
  const [displayName, setDisplayName] = useState("");
  const [photoBusy, setPhotoBusy] = useState(false);

  const [recoveryKind, setRecoveryKind] = useState("gmail");
  const [recoveryEmail, setRecoveryEmail] = useState("");

  const sessions = useQuery<DeviceSession[], ApiError>({
    queryKey: ["auth", "sessions"],
    queryFn: () => api<DeviceSession[]>("/api/auth/sessions"),
    retry: false,
  });

  const passkeys = useQuery<{ id: string; device_name: string; created_at: string; last_used_at: string | null }[], ApiError>({
    queryKey: ["auth", "passkeys"],
    queryFn: () =>
      api<{ id: string; device_name: string; created_at: string; last_used_at: string | null }[]>(
        "/api/auth/passkey/list",
      ),
    retry: false,
  });

  const recovery = useQuery<{ set: boolean; kind: string | null; hint: string | null; sms_note: string }, ApiError>({
    queryKey: ["auth", "recovery"],
    queryFn: () =>
      api<{ set: boolean; kind: string | null; hint: string | null; sms_note: string }>("/api/auth/recovery"),
    retry: false,
  });

  const revoke = useMutation({
    mutationFn: (id: string) => api(`/api/auth/sessions/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      notify.done("Session revoked", "That device has been signed out.");
      void queryClient.invalidateQueries({ queryKey: ["auth", "sessions"] });
    },
    onError: (error: ApiError) =>
      notify.failed("Could not revoke that session", { description: error.message }),
  });

  const changePassword = useMutation({
    mutationFn: async () => {
      if (newPassword !== confirmPassword) throw new Error("New passwords do not match.");
      return api("/api/auth/change-password", {
        method: "POST",
        body: JSON.stringify({ current_password: currentPassword, new_password: newPassword }),
      });
    },
    onSuccess: () => {
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
      notify.done("Password changed", "Other signed-in devices have been revoked.");
      void queryClient.invalidateQueries({ queryKey: ["auth", "sessions"] });
    },
    onError: (error: Error) => notify.failed("Password not changed", { description: error.message }),
  });

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto max-w-2xl space-y-ax-5 p-ax-4">
        <h2 className="ax-heading text-foreground">Profile &amp; sessions</h2>
        <section className="rounded-xl border border-border bg-card p-ax-4">
          <div className="flex items-start gap-ax-3">
            <div className="size-16 shrink-0 overflow-hidden rounded-full border border-border bg-secondary">
              {session?.user.avatar_url ? (
                <img src={session.user.avatar_url} alt="" className="size-16 object-cover" />
              ) : (
                <span className="flex size-16 items-center justify-center text-lg font-semibold text-muted-foreground">
                  {(session?.user.display_name || session?.user.email || "?").slice(0, 1).toUpperCase()}
                </span>
              )}
            </div>
            <div className="min-w-0 flex-1">
              <h2 className="ax-label text-foreground">Your ANEXOMAIL address</h2>
              <p className="ax-body mt-1 break-all text-foreground">
                {session?.user.anexomail_address || session?.user.email || "—"}
              </p>
              <p className="ax-caption mt-1">This is your mailbox. It does not change when you add a photo.</p>
            </div>
          </div>
          <form
            className="mt-ax-4 space-y-ax-3"
            onSubmit={(event) => {
              event.preventDefault();
              const name = displayName.trim() || session?.user.display_name || session?.user.name || "";
              void api("/api/auth/profile", {
                method: "PATCH",
                body: JSON.stringify({ display_name: name }),
              })
                .then(() => {
                  notify.done("Profile saved", "Your display name is updated.");
                  void refresh();
                })
                .catch((error: unknown) =>
                  notify.failed("Profile not saved", {
                    description: error instanceof Error ? error.message : "Try again.",
                  }),
                );
            }}
          >
            <div className="space-y-1.5">
              <Label htmlFor="display-name">Display name</Label>
              <Input
                id="display-name"
                value={displayName}
                placeholder={session?.user.display_name || session?.user.name || "Your name"}
                onChange={(event) => setDisplayName(event.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="photo">Profile photo</Label>
              <Input
                id="photo"
                type="file"
                accept="image/jpeg,image/png,image/webp"
                disabled={photoBusy}
                onChange={(event) => {
                  const file = event.target.files?.[0];
                  event.target.value = "";
                  if (!file) return;
                  if (file.size > 130_000) {
                    notify.failed("Photo too large", { description: "Use a jpg or png under 130 KB." });
                    return;
                  }
                  setPhotoBusy(true);
                  const reader = new FileReader();
                  reader.onload = () => {
                    const avatar_url = String(reader.result || "");
                    void api("/api/auth/profile", {
                      method: "PATCH",
                      body: JSON.stringify({ avatar_url }),
                    })
                      .then(() => {
                        notify.done("Photo saved", "Your profile picture is on this account.");
                        void refresh();
                      })
                      .catch((error: unknown) =>
                        notify.failed("Photo not saved", {
                          description: error instanceof Error ? error.message : "Try again.",
                        }),
                      )
                      .finally(() => setPhotoBusy(false));
                  };
                  reader.onerror = () => {
                    setPhotoBusy(false);
                    notify.failed("Photo not read", { description: "Pick another image." });
                  };
                  reader.readAsDataURL(file);
                }}
              />
              <p className="ax-caption">jpg / png / webp, under 130 KB. Optional.</p>
            </div>
            <Button type="submit">Save name</Button>
          </form>
        </section>

        <section className="rounded-xl border border-border bg-card p-ax-4">
          <h2 className="ax-label text-foreground">Security</h2>
          <div className="mt-ax-3 flex flex-wrap gap-ax-2">
            <Button
              variant="outline"
              className="ax-press"
              onClick={() =>
                void enrollPasskey()
                  .then(() => void queryClient.invalidateQueries({ queryKey: ["auth", "passkeys"] }))
                  .catch((error: unknown) => {
                    notify.failed("Passkey not added", {
                      description: error instanceof Error ? error.message : "Please try again.",
                    });
                  })
              }
            >
              <KeyRound className="size-4" />
              Add a passkey
            </Button>
            <Button
              variant="outline"
              className="ax-press"
              onClick={() =>
                void api<{ otpauth_url: string }>("/api/auth/mfa/enroll", { method: "POST" })
                  .then((res) => window.open(res.otpauth_url, "_blank", "noopener"))
                  .catch((error: unknown) => {
                    notify.failed("Two-step setup unavailable", {
                      description: error instanceof Error ? error.message : "Please try again.",
                    });
                  })
              }
            >
              <ShieldCheck className="size-4" />
              {session?.user.mfa_enabled ? "Manage two-step" : "Turn on two-step"}
            </Button>
          </div>
        </section>

        <section className="rounded-xl border border-border bg-card p-ax-4">
          <h2 className="ax-label text-foreground">Change password</h2>
          <p className="ax-caption mt-1">Use 6 to 15 characters. Other signed-in devices will be signed out.</p>
          <form className="mt-ax-3 space-y-ax-3" onSubmit={(event) => { event.preventDefault(); changePassword.mutate(); }}>
            <PasswordInput id="current-password" label="Current password" value={currentPassword} onChange={setCurrentPassword} visible={passwordVisible} />
            <PasswordInput id="new-password" label="New password" value={newPassword} onChange={setNewPassword} visible={passwordVisible} />
            <PasswordInput id="confirm-password" label="Confirm new password" value={confirmPassword} onChange={setConfirmPassword} visible={passwordVisible} />
            <div className="flex items-center justify-between gap-3">
              <Button type="button" variant="ghost" onClick={() => setPasswordVisible((value) => !value)}>
                {passwordVisible ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
                {passwordVisible ? "Hide passwords" : "Show passwords"}
              </Button>
              <Button type="submit" disabled={changePassword.isPending || !currentPassword || !newPassword || !confirmPassword}>
                {changePassword.isPending && <Loader2 className="size-4 animate-spin" />}
                Update password
              </Button>
            </div>
          </form>
        </section>

        <section className="rounded-xl border border-border bg-card p-ax-4">
          <h2 className="ax-label text-foreground">Passkeys</h2>
          <p className="ax-caption mt-1">
            Face ID / Touch ID / Windows Hello on this site only. Remove a passkey if the phone is lost.
          </p>
          <div className="mt-ax-3">
            {passkeys.isLoading ? (
              <ListSkeleton rows={2} />
            ) : passkeys.error ? (
              <ErrorState body={passkeys.error.message} onRetry={() => void passkeys.refetch()} />
            ) : !passkeys.data?.length ? (
              <p className="ax-caption">No passkey on this account yet. Password still works.</p>
            ) : (
              <ul className="space-y-2">
                {passkeys.data.map((item) => (
                  <li
                    key={item.id}
                    className="flex items-center justify-between gap-3 rounded-lg border border-border px-3 py-2"
                  >
                    <span className="ax-caption truncate text-foreground">{item.device_name}</span>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() =>
                        void api(`/api/auth/passkey/${item.id}`, { method: "DELETE" })
                          .then(() => {
                            notify.done("Passkey removed", "That device can no longer sign in with Face ID.");
                            void queryClient.invalidateQueries({ queryKey: ["auth", "passkeys"] });
                          })
                          .catch((error: unknown) =>
                            notify.failed("Could not remove passkey", {
                              description: error instanceof Error ? error.message : "Try again.",
                            }),
                          )
                      }
                    >
                      Remove
                    </Button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>

        <section className="rounded-xl border border-border bg-card p-ax-4">
          <h2 className="ax-label text-foreground">Recovery account</h2>
          <p className="ax-caption mt-1">
            {recovery.data?.set
              ? `On file: ${recovery.data.hint} (${recovery.data.kind}). Reset links go there.`
              : "Add a Gmail, iCloud or other inbox you can open. Not Sign in with Apple."}
          </p>
          <p className="ax-caption mt-1">{recovery.data?.sms_note}</p>
          <form
            className="mt-ax-3 space-y-ax-3"
            onSubmit={(event) => {
              event.preventDefault();
              void api("/api/auth/recovery", {
                method: "POST",
                body: JSON.stringify({ kind: recoveryKind, email: recoveryEmail }),
              })
                .then(() => {
                  notify.done("Recovery saved", "Password reset will go to that inbox.");
                  setRecoveryEmail("");
                  void queryClient.invalidateQueries({ queryKey: ["auth", "recovery"] });
                })
                .catch((error: unknown) =>
                  notify.failed("Recovery not saved", {
                    description: error instanceof Error ? error.message : "Try again.",
                  }),
                );
            }}
          >
            <div className="space-y-1.5">
              <Label htmlFor="recovery-kind">Kind</Label>
              <select
                id="recovery-kind"
                className="flex h-10 w-full rounded-md border border-border bg-background px-3 text-sm"
                value={recoveryKind}
                onChange={(event) => setRecoveryKind(event.target.value)}
              >
                <option value="gmail">Gmail</option>
                <option value="apple">Apple / iCloud email</option>
                <option value="outlook">Outlook</option>
                <option value="other_email">Other email</option>
              </select>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="recovery-email">Recovery email</Label>
              <Input
                id="recovery-email"
                type="email"
                required
                value={recoveryEmail}
                onChange={(event) => setRecoveryEmail(event.target.value)}
              />
            </div>
            <Button type="submit">Save recovery</Button>
          </form>
        </section>

        <section>
          <h2 className="ax-label text-foreground">Devices</h2>
          <p className="ax-caption mt-1">
            Every session is device-bound. Revoke one and that device signs out immediately.
          </p>

          <div className="mt-ax-3">
            {sessions.isLoading ? (
              <ListSkeleton rows={3} />
            ) : sessions.error ? (
              <ErrorState
                title="Sessions didn't load"
                body={sessions.error.message}
                onRetry={() => void sessions.refetch()}
              />
            ) : !sessions.data?.length ? (
              <StateBlock title="No other devices" body="You're only signed in here." />
            ) : (
              <ul className="ax-stagger divide-y divide-border rounded-xl border border-border bg-card">
                {sessions.data.map((s) => (
                  <li key={s.id} className="ax-in flex items-center gap-3 p-ax-3">
                    <Laptop className="size-4 shrink-0 text-steel" />
                    <div className="min-w-0">
                      <p className="ax-label truncate text-foreground">
                        {s.browser ?? "Unknown browser"} · {s.device ?? "Unknown device"}
                        {s.current && (
                          <span className="ml-2 rounded-full bg-cyan-accent/15 px-2 py-0.5 text-[10px] font-semibold text-cyan-accent">
                            This device
                          </span>
                        )}
                      </p>
                      <p className="ax-caption truncate">
                        {[s.location, s.ip, new Date(s.last_seen_at).toLocaleString()]
                          .filter(Boolean)
                          .join(" · ")}
                      </p>
                    </div>
                    {!s.current && (
                      <Button
                        variant="ghost"
                        className="ml-auto shrink-0"
                        disabled={revoke.isPending}
                        onClick={() => revoke.mutate(s.id)}
                      >
                        {revoke.isPending && revoke.variables === s.id && (
                          <Loader2 className="size-4 animate-spin" />
                        )}
                        Revoke
                      </Button>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}

function PasswordInput({ id, label, value, onChange, visible }: { id: string; label: string; value: string; onChange: (value: string) => void; visible: boolean }) {
  return (
    <div className="space-y-1.5">
      <Label htmlFor={id}>{label}</Label>
      <Input id={id} type={visible ? "text" : "password"} value={value} minLength={6} maxLength={15} required autoComplete={id === "current-password" ? "current-password" : "new-password"} onChange={(event) => onChange(event.target.value)} />
    </div>
  );
}

/** WebAuthn registration — the backend owns the challenge and the credential store. */
async function enrollPasskey() {
  if (!window.PublicKeyCredential) throw new Error("This device doesn't support passkeys.");
  const options = await api<{ publicKey: PublicKeyCredentialCreationOptionsJSON }>(
    "/api/auth/passkey/register/options",
    { method: "POST" },
  );
  const credential = await navigator.credentials.create({
    publicKey: PublicKeyCredential.parseCreationOptionsFromJSON(options.publicKey),
  });
  if (!credential) throw new Error("Passkey creation was cancelled.");
  await api("/api/auth/passkey/register/verify", {
    method: "POST",
    body: JSON.stringify((credential as PublicKeyCredential).toJSON()),
  });
  notify.done("Passkey added", "You can now sign in without a password.");
}
