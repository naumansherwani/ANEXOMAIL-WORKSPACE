import { BrandSpinner } from "@/components/state/BrandLoader";
import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { MailPlus, ShieldCheck, Trash2, UserMinus } from "lucide-react";

import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState, StateBlock } from "@/components/state/StateBlock";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { ADDRESS_MANAGER_FLAG, ROLES, type WorkspaceRole } from "@/lib/ia";
import { notify } from "@/lib/notify";
import {
  describeSeats,
  summariseInvites,
  useInvitations,
  useMembers,
  useSeats,
  useTeamMutations,
  type TeamInvitation,
  type TeamMember,
} from "@/lib/team";

export const Route = createFileRoute("/app/admin/members")({
  head: () => ({
    meta: [
      { title: "Members & roles — ANEXOMAIL Admin" },
      {
        name: "description",
        content:
          "Manage the people in your ANEXOMAIL organisation, their roles and pending invitations.",
      },
      { property: "og:title", content: "Members & roles — ANEXOMAIL Admin" },
      { property: "og:description", content: "People, roles and pending invitations." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: MembersPage,
});

type Member = TeamMember;
type Invitation = TeamInvitation;

function MembersPage() {
  const { organisation, session } = useAuth();
  const canManage = organisation?.role === "owner" || organisation?.role === "admin";
  const isOwner = organisation?.role === "owner";

  const members = useMembers(organisation?.id);
  const invitations = useInvitations(organisation?.id, canManage);
  const { setRole, remove: removeMember, invite, revoke: revokeInvite, resend } = useTeamMutations(organisation?.id);
  const seats = useSeats(organisation?.id, true);
  const seatLine = describeSeats(seats.data);

  // Removing someone ends their access at once: never on a single tap (on a phone the role pills sit
  // right beside the remove icon). Ask first.
  const [confirmRemove, setConfirmRemove] = useState<Member | null>(null);

  const [emails, setEmails] = useState("");
  const [role, setRoleValue] = useState<WorkspaceRole>("member");
  // optional work address for ONE person: "sara" -> sara@<verified domain>, created for them when they join
  const [mailbox, setMailbox] = useState("");
  const [domainId, setDomainId] = useState("");
  const domains = seats.data?.domains ?? [];

  const sendInvites = (list: string[]) =>
    invite.mutate(
      {
        emails: list,
        role,
        ...(mailbox.trim() ? { mailbox: mailbox.trim(), ...(domainId ? { domain_id: domainId } : {}) } : {}),
      },
      {
        onSuccess: (res) => {
          const sum = summariseInvites(res, list.length);
          if (sum.tone === "done") notify.done(sum.title, sum.detail);
          else if (sum.tone === "info") notify.info(sum.title, sum.detail);
          else notify.failed(sum.title, { description: sum.detail });
          if (sum.tone === "done" || sum.tone === "partial") {
            setEmails("");
            setMailbox("");
          }
        },
        onError: (e: ApiError) => notify.failed("Invitations not sent", { description: e.message }),
      },
    );

  const doResend = (inv: Invitation) =>
    resend.mutate(inv.id, {
      onSuccess: () => notify.done("Invitation sent again", `${inv.email} gets a fresh e-mail with the same link.`),
      onError: (e: ApiError) => notify.failed("Not sent", { description: e.message }),
    });

  // Owners and yourself are never editable here; everyone else (when you manage) gets role pills + remove.
  const editable = (m: Member) =>
    canManage && m.role !== "owner" && m.user_id !== session?.user.id && (isOwner || m.role !== "admin");

  if (!organisation) {
    return (
      <div className="mx-auto w-full max-w-3xl px-6 py-10 md:px-10">
        <StateBlock
          title="No organisation yet"
          body="Create your organisation first — members and roles live inside it."
        />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-3xl px-ax-4 py-ax-6 md:px-10 md:py-10">
      <p className="ax-eyebrow">People</p>
      <h2 className="mt-3 text-3xl text-foreground">Members &amp; roles</h2>
      <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
        Three roles, deliberately. Extra power is granted per address instead of adding another tier
        nobody can explain.
      </p>

      {canManage && (
        <form
          className="mt-8 rounded-2xl border border-border bg-card p-5"
          onSubmit={(event) => {
            event.preventDefault();
            const list = emails
              .split(/[\s,;]+/)
              .map((e) => e.trim())
              .filter(Boolean);
            if (!list.length) return;
            sendInvites(list);
          }}
        >
          <h2 className="ax-label text-foreground">Invite people</h2>
          {seatLine.tone !== "none" && (
            <p
              className={`ax-caption mt-1 ${seatLine.tone === "full" ? "text-danger" : seatLine.tone === "warn" ? "text-warning" : "text-muted-foreground"}`}
              role={seatLine.tone === "full" ? "alert" : undefined}
            >
              {seatLine.line}
            </p>
          )}
          <div className="mt-3 space-y-1.5">
            <Label htmlFor="invite-emails" className="ax-caption text-foreground">
              Emails
            </Label>
            <Input
              id="invite-emails"
              value={emails}
              onChange={(event) => setEmails(event.target.value)}
              placeholder="sara@yourcompany.com, ali@yourcompany.com"
            />
          </div>
          {domains.length > 0 && (
            <div className="mt-3 space-y-1.5">
              <Label htmlFor="invite-mailbox" className="ax-caption text-foreground">
                Work address <span className="text-muted-foreground">(optional, one person)</span>
              </Label>
              <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
                <Input
                  id="invite-mailbox"
                  value={mailbox}
                  onChange={(event) => setMailbox(event.target.value)}
                  placeholder="sara"
                  autoCapitalize="none"
                  autoCorrect="off"
                  spellCheck={false}
                  className="w-full sm:w-48"
                />
                <div className="flex min-w-0 items-center gap-2">
                  <span className="text-sm text-muted-foreground" aria-hidden="true">
                    @
                  </span>
                  {domains.length === 1 ? (
                    <span className="min-w-0 break-all text-sm text-foreground">{domains[0]!.domain}</span>
                  ) : (
                    <select
                      aria-label="Domain for the work address"
                      value={domainId}
                      onChange={(event) => setDomainId(event.target.value)}
                      className="ax-tap min-w-0 flex-1 rounded-md border border-border bg-background px-2 py-2 text-base sm:flex-none"
                    >
                      <option value="">{domains[0]!.domain}</option>
                      {domains.slice(1).map((d) => (
                        <option key={d.id} value={d.id}>
                          {d.domain}
                        </option>
                      ))}
                    </select>
                  )}
                </div>
              </div>
              <p className="ax-caption text-muted-foreground">
                Created for them the moment they join. Leave empty to add it later from Domains.
              </p>
            </div>
          )}
          <div className="mt-3 flex flex-wrap items-center gap-2">
            {ROLES.filter((r) => r.id !== "owner" && (isOwner || r.id !== "admin")).map((r) => (
              <button
                key={r.id}
                type="button"
                onClick={() => setRoleValue(r.id)}
                className={`ax-focus ax-press ax-tap inline-flex items-center justify-center rounded-full px-3.5 py-1.5 text-xs font-semibold ${
                  role === r.id
                    ? "bg-cyan-accent/15 text-cyan-accent"
                    : "bg-secondary text-muted-foreground"
                }`}
              >
                {r.label}
              </button>
            ))}
            <Button type="submit" className="ax-press w-full sm:ml-auto sm:w-auto" disabled={invite.isPending}>
              {invite.isPending ? (
                <BrandSpinner className="size-4" />
              ) : (
                <MailPlus className="size-4" />
              )}
              Send invitations
            </Button>
          </div>
        </form>
      )}

      <section className="mt-8">
        <h2 className="ax-label text-foreground">In this organisation</h2>
        <div className="mt-3">
          {members.isLoading ? (
            <ListSkeleton rows={4} />
          ) : members.error ? (
            <ErrorState
              body={
                members.error.isNotImplemented
                  ? "Members aren't live on the server yet."
                  : members.error.message
              }
              onRetry={() => void members.refetch()}
            />
          ) : !members.data?.members.length ? (
            <StateBlock
              title="Only you so far"
              body="Invite your first people above — they land in the same surface you're in."
            />
          ) : (
            <ul className="space-y-2">
              {members.data.members.map((m) => (
                <li
                  key={m.id}
                  className="ax-row flex flex-wrap items-center gap-3 rounded-xl border border-border bg-card px-4 py-3"
                >
                  {/* Phone: the full address gets the whole line (an admin must see exactly who they are changing) and the
                      controls drop below it; from sm up it is one row again. */}
                  <div className={`min-w-0 ${editable(m) ? "basis-full sm:flex-1 sm:basis-0" : "flex-1"}`}>
                    {m.name ? <p className="ax-label truncate text-foreground">{m.name}</p> : null}
                    <p
                      title={m.email}
                      className={`break-all sm:truncate ${m.name ? "ax-caption" : "ax-label text-foreground"}`}
                    >
                      {m.email}
                    </p>
                  </div>
                  {editable(m) ? (
                    <div className="flex w-full items-center gap-2 sm:w-auto sm:gap-3">
                      {(isOwner ? (["admin", "member"] as WorkspaceRole[]) : (["member"] as WorkspaceRole[])).map((r) => (
                        <button
                          key={r}
                          type="button"
                          disabled={setRole.isPending}
                          onClick={() =>
                            setRole.mutate(
                              { id: m.id, role: r },
                              {
                                onSuccess: () => notify.done("Role updated", "The change applies on their next request."),
                                onError: (e: ApiError) => notify.failed("Role not changed", { description: e.message }),
                              },
                            )
                          }
                          className={`ax-focus ax-tap inline-flex items-center justify-center rounded-full px-3.5 py-1 text-xs font-semibold ${
                            m.role === r
                              ? "bg-cyan-accent/15 text-cyan-accent"
                              : "bg-secondary text-muted-foreground"
                          }`}
                        >
                          {r}
                        </button>
                      ))}
                      <Button
                        variant="ghost"
                        size="sm"
                        className="ax-press ml-auto text-destructive sm:ml-0"
                        disabled={removeMember.isPending}
                        onClick={() => setConfirmRemove(m)}
                        aria-label={`Remove ${m.email}`}
                      >
                        <UserMinus className="size-4" />
                      </Button>
                    </div>
                  ) : (
                    <span className="ax-caption inline-flex items-center gap-1.5 rounded-full bg-secondary px-2.5 py-1 font-semibold">
                      <ShieldCheck className="size-3.5 text-cyan-accent" />
                      {m.role}
                    </span>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>

      {canManage && (
        <section className="mt-8">
          <h2 className="ax-label text-foreground">Pending invitations</h2>
          <div className="mt-3">
            {invitations.isLoading ? (
              <ListSkeleton rows={2} />
            ) : invitations.error ? (
              <ErrorState
                body={
                  invitations.error.isNotImplemented
                    ? "Invitations aren't live on the server yet."
                    : invitations.error.message
                }
                onRetry={() => void invitations.refetch()}
              />
            ) : !invitations.data?.invitations.length ? (
              <p className="ax-caption">Nothing pending.</p>
            ) : (
              <ul className="space-y-2">
                {invitations.data.invitations.map((inv) => (
                  <li
                    key={inv.id}
                    className="ax-row flex items-center gap-3 rounded-xl border border-dashed border-border px-4 py-3"
                  >
                    <div className="min-w-0 flex-1">
                      <p className="ax-label break-all text-foreground sm:truncate">{inv.email}</p>
                      <p className="ax-caption">
                        {inv.role}
                        {inv.expired
                          ? " · expired — press Resend"
                          : inv.expires_at
                            ? ` · expires ${new Date(inv.expires_at).toLocaleDateString()}`
                            : ""}
                      </p>
                      {inv.send_error ? (
                        <p className="ax-caption text-amber-400">E-mail not delivered — press Resend.</p>
                      ) : inv.last_sent_at ? (
                        <p className="ax-caption">E-mailed {new Date(inv.last_sent_at).toLocaleString()}</p>
                      ) : null}
                    </div>
                    <Button
                      variant="outline"
                      size="sm"
                      className="ax-press ax-tap"
                      disabled={resend.isPending}
                      onClick={() => doResend(inv)}
                      aria-label={`Send the invitation to ${inv.email} again`}
                    >
                      Resend
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="ax-press text-destructive"
                      disabled={revokeInvite.isPending}
                      onClick={() =>
                        revokeInvite.mutate(inv.id, {
                          onSuccess: () => notify.done("Invitation revoked", "That link no longer works."),
                          onError: (e: ApiError) => notify.failed("Invitation not revoked", { description: e.message }),
                        })
                      }
                      aria-label={`Revoke invitation for ${inv.email}`}
                    >
                      <Trash2 className="size-4" />
                    </Button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>
      )}

      <section className="mt-8 space-y-3">
        <h2 className="ax-label text-foreground">What each role can do</h2>
        {ROLES.map((r) => (
          <div key={r.id} className="ax-plane rounded-2xl p-5">
            <h3 className="text-base font-bold text-foreground">{r.label}</h3>
            <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">{r.summary}</p>
          </div>
        ))}
        <div className="rounded-2xl border border-dashed border-border p-5">
          <h3 className="text-base font-bold text-foreground">{ADDRESS_MANAGER_FLAG.label}</h3>
          <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
            {ADDRESS_MANAGER_FLAG.summary}
          </p>
        </div>
      </section>

      <AlertDialog open={Boolean(confirmRemove)} onOpenChange={(o) => !o && setConfirmRemove(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Remove {confirmRemove?.name ?? confirmRemove?.email}?</AlertDialogTitle>
            <AlertDialogDescription>
              {confirmRemove?.email} loses access to this organisation straight away.
              You can invite them again later.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Keep them</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => {
                const target = confirmRemove;
                setConfirmRemove(null);
                if (target)
                  removeMember.mutate(target.id, {
                    onSuccess: () => notify.done("Member removed", "They no longer have access to this organisation."),
                    onError: (e: ApiError) => notify.failed("Member not removed", { description: e.message }),
                  });
              }}
            >
              Remove member
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
