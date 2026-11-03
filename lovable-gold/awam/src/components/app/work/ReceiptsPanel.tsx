import { BadgeCheck, FileCheck2, Radio, ShieldCheck, UserMinus } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  HANDOVER_STATUS_LABEL,
  type HandoverStatus,
  useAssignHandover,
  useBuildHandover,
  useCompleteHandover,
  useHandoverBoard,
  useHandoverPack,
  useIssueCertificate,
  useReadWithoutResponse,
  useReceiptReplay,
} from "@/lib/chat-receipts";
import { useHealthBoard } from "@/lib/chat-timeline";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

const clock = (iso: string | null) =>
  iso ? `${new Date(iso).toISOString().slice(11, 19)} UTC` : "—";

const STATUS_TONE: Record<HandoverStatus, string> = {
  confirmed_fact: "text-emerald-400",
  pending: "text-amber-400",
  overdue: "text-red-400",
  historical_decision: "text-steel",
  open_dependency: "text-amber-400",
};

/**
 * PHASE 28 — receipts that show what happened, and the handover pack that stops
 * work disappearing when a person leaves.
 *
 * Every line here comes from a record: the moment a message was sent, the
 * moments it reached people and was read, and the file steps that were actually
 * carried out. What never happened is written down too — nothing delivered, or
 * read with no reply since. The certificate can be checked by someone outside
 * the company without signing in, and it carries no message text.
 */
export function ReceiptsPanel() {
  const board = useHealthBoard();
  const rows = board.data?.conversations ?? [];
  const [selected, setSelected] = useState<string | null>(null);
  const current = selected ?? rows[0]?.conversation_id ?? null;

  const replay = useReceiptReplay(current);
  const silent = useReadWithoutResponse(24);
  const certificate = useIssueCertificate();
  const [cert, setCert] = useState<string | null>(null);

  return (
    <section className="space-y-ax-4">
      <div>
        <h2 className="ax-heading flex items-center gap-2 text-foreground">
          <BadgeCheck className="size-4" aria-hidden="true" /> Receipts
        </h2>
        <p className="ax-caption text-muted-foreground">
          Sent, reached, read — with the exact times. What did not happen is written here too.
        </p>
      </div>

      {rows.length > 0 && (
        <div className="flex flex-wrap gap-1">
          {rows.slice(0, 8).map((r) => (
            <button
              key={r.conversation_id}
              type="button"
              onClick={() => {
                setSelected(r.conversation_id);
                setCert(null);
              }}
              className={cn(
                "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold",
                current === r.conversation_id
                  ? "border-cyan-accent/50 bg-secondary text-foreground"
                  : "border-border text-muted-foreground",
              )}
            >
              {r.title}
            </button>
          ))}
        </div>
      )}

      {/* receipt replay — delivery history, frame by frame */}
      <div className="ax-plane rounded-2xl p-ax-4">
        <p className="ax-caption flex items-center gap-2 font-semibold text-foreground">
          <Radio className="size-3.5" aria-hidden="true" /> Delivery history
        </p>
        {replay.data?.error ? (
          <p className="ax-caption mt-ax-2 text-muted-foreground">{replay.data.error}</p>
        ) : (replay.data?.frames ?? []).length === 0 ? (
          <p className="ax-caption mt-ax-2 text-muted-foreground">Nothing recorded yet.</p>
        ) : (
          <ul className="mt-ax-2 space-y-1">
            {(replay.data?.frames ?? [])
              .slice(-40)
              .reverse()
              .map((f, i) => (
                <li key={`${f.message_id}-${f.kind}-${i}`} className="ax-caption flex gap-2">
                  <span className="w-24 shrink-0 text-steel">{clock(f.at)}</span>
                  <span
                    className={cn(
                      "w-20 shrink-0 font-semibold",
                      f.kind === "read"
                        ? "text-emerald-400"
                        : f.kind === "delivered"
                          ? "text-cyan-accent"
                          : "text-foreground",
                    )}
                  >
                    {f.kind === "sent" ? "Sent" : f.kind === "delivered" ? "Reached" : "Read"}
                  </span>
                  <span className="min-w-0 flex-1 truncate text-muted-foreground">
                    {f.actor}
                    {f.device?.platform_class && f.device.platform_class !== "unknown"
                      ? ` · ${f.device.platform_class}`
                      : ""}
                    {f.device?.timezone_bucket && f.device.timezone_bucket !== "unknown"
                      ? ` · ${f.device.timezone_bucket}`
                      : ""}
                  </span>
                </li>
              ))}
          </ul>
        )}
      </div>

      {/* read but no reply — measured silence, not an accusation */}
      <div className="ax-plane rounded-2xl p-ax-4">
        <p className="ax-caption flex items-center gap-2 font-semibold text-foreground">
          <UserMinus className="size-3.5" aria-hidden="true" /> Read, no reply yet (24h+)
        </p>
        {(silent.data?.items ?? []).length === 0 ? (
          <p className="ax-caption mt-ax-2 text-muted-foreground">Nothing waiting like this.</p>
        ) : (
          <ul className="mt-ax-2 space-y-ax-2">
            {(silent.data?.items ?? []).slice(0, 10).map((s) => (
              <li
                key={`${s.message_id}-${s.reader_id}`}
                className="ax-caption text-muted-foreground"
              >
                <span className="font-semibold text-foreground">{s.reader}</span> read your message
                in <span className="text-foreground">{s.title}</span> · {relativeTime(s.read_at)} ·{" "}
                {s.hours_since}h with no reply recorded
              </li>
            ))}
          </ul>
        )}
        {silent.data?.note && <p className="ax-caption mt-ax-2 text-steel">{silent.data.note}</p>}
      </div>

      {/* certificate — verifiable outside, no message text inside */}
      <div className="ax-plane rounded-2xl p-ax-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <p className="ax-caption flex items-center gap-2 font-semibold text-foreground">
            <ShieldCheck className="size-3.5" aria-hidden="true" /> Receipt certificate
          </p>
          <Button
            size="sm"
            variant="outline"
            disabled={!current || certificate.isPending}
            onClick={() =>
              current &&
              certificate.mutate(
                { conversation_id: current },
                {
                  onSuccess: (d) => {
                    if (d.error) {
                      notify.failed("Could not issue", { description: d.error });
                      return;
                    }
                    setCert(d.verify_token ?? null);
                    notify.done("Certificate issued", "It can be checked without signing in.");
                  },
                  onError: (e) => notify.failed("Could not issue", { description: e.message }),
                },
              )
            }
          >
            Issue
          </Button>
        </div>
        <p className="ax-caption mt-ax-2 text-muted-foreground">
          A sealed summary of this conversation: how many messages, how many reached people, how
          many were read — and the seal that proves nothing was changed. No message text is
          included.
        </p>
        {cert && (
          <p className="ax-caption mt-ax-2 break-all text-foreground">
            Check code: <span className="text-cyan-accent">{cert}</span>
          </p>
        )}
      </div>

      <HandoverPacks />
    </section>
  );
}

/** ZERO-LOSS HANDOVER PACK — nothing is invented; every item names its source. */
function HandoverPacks() {
  const board = useHandoverBoard();
  const [open, setOpen] = useState<string | null>(null);
  const pack = useHandoverPack(open);
  const build = useBuildHandover();
  const assign = useAssignHandover();
  const complete = useCompleteHandover();
  const [person, setPerson] = useState("");

  const packs = board.data?.packs ?? [];

  return (
    <div className="ax-plane rounded-2xl p-ax-4">
      <p className="ax-caption flex items-center gap-2 font-semibold text-foreground">
        <FileCheck2 className="size-3.5" aria-hidden="true" /> Handover pack
      </p>
      <p className="ax-caption mt-1 text-muted-foreground">
        When someone leaves a project or the company, this collects what is actually on record:
        conversations, open work, promises, decisions, files and anything still blocked. Missing
        context is never made up.
      </p>

      <div className="mt-ax-3 flex flex-wrap items-center gap-2">
        <Input
          value={person}
          onChange={(e) => setPerson(e.target.value)}
          placeholder="Person leaving (their user id)"
          className="h-8 max-w-xs text-xs"
        />
        <Button
          size="sm"
          variant="outline"
          disabled={build.isPending || person.trim().length < 8}
          onClick={() =>
            build.mutate(
              { outgoing_user: person.trim() },
              {
                onSuccess: (d) => {
                  if (d.error) {
                    notify.failed("Could not build", { description: d.error });
                    return;
                  }
                  setPerson("");
                  setOpen(d.pack_id ?? null);
                  notify.done("Pack built", `${d.items ?? 0} items on record.`);
                },
                onError: (e) => notify.failed("Could not build", { description: e.message }),
              },
            )
          }
        >
          Build pack
        </Button>
      </div>

      {packs.length === 0 ? (
        <p className="ax-caption mt-ax-3 text-muted-foreground">No handover packs yet.</p>
      ) : (
        <ul className="mt-ax-3 space-y-ax-2">
          {packs.map((p) => (
            <li key={p.pack_id}>
              <button
                type="button"
                onClick={() => setOpen(open === p.pack_id ? null : p.pack_id)}
                className="ax-press ax-caption w-full rounded-xl border border-border px-3 py-2 text-left"
              >
                <span className="font-semibold text-foreground">{p.outgoing}</span>
                <span className="text-muted-foreground">
                  {" "}
                  → {p.incoming ?? "no owner yet"} · {p.items} items
                  {p.overdue > 0 ? ` · ${p.overdue} overdue` : ""} · {p.state}
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}

      {open && pack.data && !pack.data.error && (
        <div className="mt-ax-3 space-y-ax-2">
          <ul className="space-y-1">
            {(pack.data.items ?? []).map((i) => (
              <li key={i.id} className="ax-caption text-muted-foreground">
                <span className={cn("font-semibold", STATUS_TONE[i.status])}>
                  {HANDOVER_STATUS_LABEL[i.status]}
                </span>{" "}
                · <span className="text-foreground">{i.title}</span>
                {i.due_at ? ` · due ${new Date(i.due_at).toISOString().slice(0, 10)}` : ""}
                <span className="text-steel"> · from {i.source}</span>
              </li>
            ))}
          </ul>
          <div className="flex flex-wrap items-center gap-2">
            <Button
              size="sm"
              variant="outline"
              disabled={assign.isPending}
              onClick={() => {
                const incoming = window.prompt("Who takes this over? (their user id)")?.trim();
                if (!incoming) return;
                const reason = window.prompt("Why this person? (8+ characters)")?.trim();
                if (!reason || reason.length < 8) {
                  notify.failed("A reason is required", { description: "At least 8 characters." });
                  return;
                }
                assign.mutate(
                  { pack_id: open, incoming_user: incoming, reason },
                  {
                    onSuccess: (d) =>
                      d.error
                        ? notify.failed("Could not assign", { description: d.error })
                        : notify.done("Assigned", "The handover now has an owner."),
                    onError: (e) => notify.failed("Could not assign", { description: e.message }),
                  },
                );
              }}
            >
              Assign owner
            </Button>
            <Button
              size="sm"
              variant="outline"
              disabled={complete.isPending}
              onClick={() => {
                const reason = window
                  .prompt("Confirm handover complete — why? (8+ characters)")
                  ?.trim();
                if (!reason || reason.length < 8) {
                  notify.failed("A reason is required", { description: "At least 8 characters." });
                  return;
                }
                complete.mutate(
                  { pack_id: open, reason },
                  {
                    onSuccess: (d) =>
                      d.error
                        ? notify.failed("Not complete yet", {
                            description:
                              d.error === "items_without_owner"
                                ? `${d.count ?? 0} items still have no owner.`
                                : d.error,
                          })
                        : notify.done("Handover complete", "Recorded with your reason."),
                    onError: (e) => notify.failed("Could not complete", { description: e.message }),
                  },
                );
              }}
            >
              Confirm complete
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
