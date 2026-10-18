import { useMutation, useQuery } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";
import { Building2, Check, Clock, Mail, ShieldCheck, UserPlus } from "lucide-react";
import { useEffect, useState } from "react";

import { BrandMark } from "@/components/site/BrandMark";
import { Button } from "@/components/ui/button";
import { api, type ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import {
  ROLE_LABEL,
  describeWorkMail,
  forgetInvite,
  inviteAccept,
  inviteLookup,
  recalledInvite,
  rememberInvite,
  useMyInvitations,
  type JoinResult,
  type JoinView,
  type TeamRole,
} from "@/lib/team";

/**
 * /join?t=<token> — the page behind the button in a team invitation e-mail.
 *
 * Public to look at (the person may not have an account yet); joining needs a signed-in account and one
 * explicit press on "Join" (mail scanners and link previews open links — opening NEVER joins anyone).
 * The role and the organisation come from the invitation on the server, never from this page or the URL.
 *
 * Signed out: the token is remembered for this browser tab, the person signs in or creates an account, and the
 * sign-in flow brings them straight back here. Without a token: the invitations waiting for the signed-in
 * person's CONFIRMED e-mail address are listed.
 */
export const Route = createFileRoute("/join")({
  ssr: false,
  validateSearch: (search: Record<string, unknown>) => ({
    t: typeof search["t"] === "string" ? (search["t"] as string).slice(0, 64) : "",
  }),
  head: () => ({
    meta: [
      { title: "Join an organisation — ANEXOMAIL" },
      { name: "robots", content: "noindex, nofollow" },
      { name: "referrer", content: "no-referrer" },
    ],
  }),
  component: JoinPage,
});

const WHY: Record<string, { title: string; body: string }> = {
  invite_not_found: {
    title: "This invitation link is not valid",
    body: "It may have been mistyped. Ask the person who invited you to send it again.",
  },
  revoked: {
    title: "This invitation was withdrawn",
    body: "The organisation cancelled it. Ask them to invite you again if this is a mistake.",
  },
  expired: {
    title: "This invitation has expired",
    body: "Invitations work for 14 days. Ask the organisation to send a fresh one.",
  },
  used: {
    title: "This invitation was already used",
    body: "Someone has already joined with it. Ask the organisation for a new invitation.",
  },
  seats_full: {
    title: "No free seat right now",
    body: "This organisation has no free seat right now. Ask the organiser to add a seat — your invitation stays valid.",
  },
};

function JoinPage() {
  const { t } = Route.useSearch();
  const { status } = useAuth();
  const [token, setToken] = useState(t);

  // after sign-in the app returns here without the query string: pick the token up again
  useEffect(() => {
    if (t) {
      setToken(t);
      return;
    }
    const kept = recalledInvite();
    if (kept) setToken(kept);
  }, [t]);

  return (
    <main className="min-h-[100dvh] bg-background px-4 py-8 pb-[max(2rem,env(safe-area-inset-bottom))] sm:px-6 sm:py-12">
      <div className="mx-auto w-full max-w-md">
        <BrandMark />
        <div className="mt-8">
          {token ? (
            <Invitation token={token} signedIn={status === "signed-in"} authLoading={status === "loading"} />
          ) : status === "signed-in" ? (
            <Waiting />
          ) : status === "loading" ? (
            <p className="text-sm text-muted-foreground" aria-busy="true">
              Opening…
            </p>
          ) : (
            <Notice
              title="This link is incomplete"
              body="Open the Join button from the invitation e-mail again."
            />
          )}
        </div>
      </div>
    </main>
  );
}

function Notice({ title, body, action }: { title: string; body: string; action?: React.ReactNode }) {
  return (
    <div role="alert" className="rounded-xl border border-border bg-card p-5">
      <p className="text-base font-bold text-foreground">{title}</p>
      <p className="mt-1.5 text-sm text-muted-foreground">{body}</p>
      {action ? <div className="mt-4">{action}</div> : null}
    </div>
  );
}

/** Signed in, no token: the invitations waiting for this person's confirmed address. */
function Waiting() {
  const mine = useMyInvitations(true);
  const list = mine.data?.invitations ?? [];
  if (mine.isPending) {
    return (
      <p className="text-sm text-muted-foreground" aria-busy="true">
        Looking for invitations…
      </p>
    );
  }
  if (!list.length) {
    return (
      <Notice
        title="No invitations waiting"
        body="When an organisation invites your e-mail address, it shows up here. You can also open the link from the invitation e-mail."
        action={
          <Button asChild size="sm" variant="outline" className="ax-tap">
            <Link to="/app">Back to your workspace</Link>
          </Button>
        }
      />
    );
  }
  return (
    <div className="space-y-3">
      <p className="ax-eyebrow">Invitations for you</p>
      {list.map((inv) => (
        <div key={inv.token} className="rounded-xl border border-border bg-card p-4">
          <p className="text-base font-bold text-foreground">{inv.org_name || "An organisation"}</p>
          <p className="mt-1 text-sm text-muted-foreground">
            {inv.invited_by ? `${inv.invited_by} invited you` : "You were invited"} as {ROLE_LABEL[inv.role as TeamRole] ?? inv.role}.
          </p>
          <Button asChild size="sm" className="ax-tap mt-3">
            <Link to="/join" search={{ t: inv.token }}>
              Open invitation
            </Link>
          </Button>
        </div>
      ))}
    </div>
  );
}

function Invitation({ token, signedIn, authLoading }: { token: string; signedIn: boolean; authLoading: boolean }) {
  const { session, refresh } = useAuth();
  const lookup = useQuery<JoinView, ApiError>({
    queryKey: ["join", token],
    queryFn: () => inviteLookup(token),
    retry: false,
    staleTime: 0,
  });
  const [joined, setJoined] = useState<JoinResult | null>(null);

  const join = useMutation<JoinResult, ApiError, void>({
    mutationFn: () => inviteAccept(token),
    onSuccess: (res) => {
      forgetInvite();
      setJoined(res);
    },
  });

  // a dead link must not keep pulling this browser tab back to /join after every sign-in
  const dead = Boolean(lookup.error) || (lookup.data !== undefined && lookup.data.status !== "pending");
  useEffect(() => {
    if (dead) forgetInvite();
  }, [dead]);

  const open = async (orgId: string) => {
    try {
      await api("/api/workspace/active-organisation", {
        method: "PATCH",
        body: JSON.stringify({ organisation_id: orgId }),
      });
    } catch {
      /* the app opens the first organisation; the switcher is one tap away */
    }
    await refresh();
    window.location.replace("/dashboard");
  };

  if (lookup.isPending) {
    return (
      <p className="text-sm text-muted-foreground" aria-busy="true">
        Opening your invitation…
      </p>
    );
  }
  if (lookup.error) {
    const code = lookup.error.code ?? "";
    const known = WHY[code];
    const transient = lookup.error.status >= 500 || lookup.error.status === 0 || lookup.error.status === 501;
    return (
      <Notice
        title={known?.title ?? (transient ? "Could not open the invitation" : WHY["invite_not_found"]!.title)}
        body={known?.body ?? (transient ? "Please try again in a minute. Nothing was changed." : WHY["invite_not_found"]!.body)}
        action={
          transient ? (
            <Button size="sm" variant="outline" className="ax-tap" onClick={() => void lookup.refetch()}>
              Try again
            </Button>
          ) : undefined
        }
      />
    );
  }

  const view = lookup.data;
  if (view.status !== "pending" && !joined) {
    const why = WHY[view.status === "accepted" ? "used" : view.status] ?? WHY["invite_not_found"]!;
    return <Notice title={why.title} body={why.body} />;
  }

  const role = ROLE_LABEL[view.role] ?? view.role;
  const me = session?.user.email ?? "";
  const differentAccount = signedIn && me && view.email && me.toLowerCase() !== view.email.toLowerCase();
  const days = Math.max(0, Math.ceil((new Date(view.expires_at).getTime() - Date.now()) / 86_400_000));

  return (
    <div className="space-y-5">
      <header className="rounded-xl border border-border bg-card p-5">
        <p className="ax-eyebrow">{joined ? "You're in" : "You're invited"}</p>
        <h1 className="mt-1 flex items-start gap-2.5 text-xl font-extrabold tracking-tight text-foreground">
          <Building2 className="mt-1 size-5 shrink-0 text-cyan-accent" aria-hidden="true" />
          <span className="min-w-0 break-words">{joined?.org_name ?? view.org_name}</span>
        </h1>
        <ul className="mt-4 space-y-2 text-sm text-foreground">
          <li className="flex items-start gap-2.5">
            <ShieldCheck className="mt-0.5 size-4 shrink-0 text-steel" aria-hidden="true" />
            <span>
              {joined ? "You joined as" : "You join as"} <b>{ROLE_LABEL[(joined?.role ?? view.role) as TeamRole] ?? role}</b>
            </span>
          </li>
          {view.invited_by && (
            <li className="flex items-start gap-2.5">
              <UserPlus className="mt-0.5 size-4 shrink-0 text-steel" aria-hidden="true" />
              <span className="min-w-0 break-all">Invited by {view.invited_by}</span>
            </li>
          )}
          {!joined && view.mailbox && (
            <li className="flex items-start gap-2.5">
              <Mail className="mt-0.5 size-4 shrink-0 text-steel" aria-hidden="true" />
              <span className="min-w-0 break-all">
                Your work address will be <b>{view.mailbox}</b>
              </span>
            </li>
          )}
          {!joined && (
            <li className="flex items-start gap-2.5">
              <Clock className="mt-0.5 size-4 shrink-0 text-steel" aria-hidden="true" />
              <span>{days <= 1 ? "Works until tomorrow" : `Works for ${days} more days`}</span>
            </li>
          )}
        </ul>
        {!joined && (
          <p className="mt-4 break-all text-xs text-muted-foreground">
            Invitation for <span className="text-foreground">{view.email}</span>
          </p>
        )}
      </header>

      {joined ? (
        <div className="rounded-xl border border-emerald-500/40 bg-emerald-500/10 p-4" role="status">
          <p className="flex items-center gap-2 text-sm font-bold text-emerald-300">
            <Check className="size-4" aria-hidden="true" />
            {joined.already ? "You are already in this organisation." : "Welcome — you are now a member."}
          </p>
          {joined.mailbox && (
            <p className="mt-2 break-words text-sm text-foreground">{describeWorkMail(joined.mailbox)}</p>
          )}
          <Button className="ax-tap mt-3 w-full" size="lg" onClick={() => void open(joined.org_id)}>
            Open {joined.org_name}
          </Button>
        </div>
      ) : authLoading ? (
        <p className="text-sm text-muted-foreground" aria-busy="true">
          Checking your sign-in…
        </p>
      ) : signedIn ? (
        <div className="space-y-3">
          <p className="text-xs text-muted-foreground">
            Signed in as <span className="break-all text-foreground">{me}</span>
          </p>
          {differentAccount && (
            <p className="rounded-lg border border-border bg-secondary/50 p-3 text-xs text-muted-foreground">
              This invitation was sent to {view.email}. You can join with the account you are signed in with.
            </p>
          )}
          <Button className="ax-tap w-full" size="lg" disabled={join.isPending} onClick={() => join.mutate()}>
            {join.isPending ? "Joining…" : `Join ${view.org_name}`}
          </Button>
          {join.error && (
            <p role="alert" className="text-sm text-danger">
              {WHY[join.error.code ?? ""]?.body ?? "You were not added. Nothing was changed — please try again."}
            </p>
          )}
        </div>
      ) : (
        <div className="space-y-3">
          <p className="text-sm text-foreground">Sign in or create your account, then press Join. You will come straight back here.</p>
          <Button asChild className="ax-tap w-full" size="lg" onClick={() => rememberInvite(token)}>
            <Link to="/auth">Sign in to join</Link>
          </Button>
          <Button asChild className="ax-tap w-full" size="lg" variant="outline" onClick={() => rememberInvite(token)}>
            <Link to="/auth" search={{ mode: "signup" }}>
              Create an account
            </Link>
          </Button>
        </div>
      )}
      {!joined && (
        <p className="pt-4 text-center text-[11px] text-muted-foreground">
          Opening this page never adds you to anything — you join when you press Join.
        </p>
      )}
    </div>
  );
}
