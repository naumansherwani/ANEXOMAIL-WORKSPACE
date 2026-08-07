import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import { KeyRound, Laptop, ShieldCheck, Loader2 } from "lucide-react";

import { Panel } from "@/components/app/Panel";
import { ListSkeleton } from "@/components/state/Skeletons";
import { StateBlock } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
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
  const { session } = useAuth();
  const queryClient = useQueryClient();

  const sessions = useQuery<DeviceSession[], ApiError>({
    queryKey: ["auth", "sessions"],
    queryFn: () => api<DeviceSession[]>("/api/auth/sessions"),
    retry: false,
  });

  const revoke = useMutation({
    mutationFn: (id: string) => api(`/api/auth/sessions/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      notify.done("Session revoked", "That device has been signed out.");
      void queryClient.invalidateQueries({ queryKey: ["auth", "sessions"] });
    },
    onError: (error: ApiError) => notify.failed("Could not revoke that session", { description: error.message }),
  });

  return (
    <Panel className="flex-1" title="Account & sessions">
      <div className="space-y-ax-5 p-ax-4">
        <section className="rounded-xl border border-border bg-card p-ax-4">
          <h2 className="ax-label text-foreground">Signed in as</h2>
          <p className="ax-body mt-1">{session?.user.email ?? "—"}</p>
          <div className="mt-ax-3 flex flex-wrap gap-ax-2">
            <Button
              variant="outline"
              className="ax-press"
              onClick={() =>
                void enrollPasskey().catch((error: unknown) =>
                  notify.failed("Passkey not added", {
                    description: error instanceof Error ? error.message : undefined,
                  }),
                )
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
                  .catch((error: unknown) =>
                    notify.failed("Two-step setup unavailable", {
                      description: error instanceof Error ? error.message : undefined,
                    }),
                  )
              }
            >
              <ShieldCheck className="size-4" />
              {session?.user.mfa_enabled ? "Manage two-step" : "Turn on two-step"}
            </Button>
          </div>
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
              <StateBlock
                kind="error"
                title="Sessions didn't load"
                description={sessions.error.message}
                actionLabel="Try again"
                onAction={() => void sessions.refetch()}
              />
            ) : !sessions.data?.length ? (
              <StateBlock
                kind="empty"
                title="No other devices"
                description="You're only signed in here."
              />
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
    </Panel>
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