import { PhoneCall, Radio, UserX } from "lucide-react";
import { useState } from "react";

import { StateBlock } from "@/components/state/StateBlock";
import { useCallBoard, useCallRecord } from "@/lib/chat-call-record";
import { bytesLabel } from "@/lib/chat-files";
import { cn } from "@/lib/utils";

const stamp = (iso: string | null | undefined) =>
  iso ? `${new Date(iso).toISOString().slice(0, 19).replace("T", " ")} UTC` : "—";
const msStamp = (ms: number) => `${new Date(ms).toISOString().slice(11, 19)} UTC`;
const minutes = (ms: number | null | undefined) =>
  ms == null ? "Not recorded" : `${Math.floor(ms / 60000)}m ${Math.round((ms % 60000) / 1000)}s`;

/**
 * ANEXOVideoCall PHASE 31 — the business record of a call.
 *
 * Who joined and when, who never joined, how long it actually ran, which files
 * were shared inside the call with the same checks as any other file, and what
 * work came out of it. The length is taken from the join and leave moments, not
 * estimated. Media stays on our own relay servers.
 */
export function CallRecordPanel() {
  const board = useCallBoard(null, 15);
  const calls = board.data?.calls ?? [];
  const [picked, setPicked] = useState<string | null>(null);
  const sessionId = picked ?? calls[0]?.id ?? null;
  const record = useCallRecord(sessionId);

  return (
    <section className="space-y-ax-4">
      <div>
        <h2 className="ax-heading flex items-center gap-2 text-foreground">
          <PhoneCall className="size-4" aria-hidden="true" /> Call records
        </h2>
        <p className="ax-caption text-muted-foreground">
          Real join and leave moments, real length, and what came out of the call.
        </p>
      </div>

      {board.data?.allowed === false ? (
        <StateBlock
          tone="quiet"
          title="Calls are included from Business upwards"
          body="Business includes group calls of 8, Business Pro 40, and the AI Executive plan 60."
        />
      ) : calls.length === 0 ? (
        <StateBlock
          tone="quiet"
          title="No calls recorded yet"
          body="Start a call from a conversation and its record appears here."
        />
      ) : (
        <>
          <div className="flex flex-wrap gap-1.5">
            {calls.map((c) => (
              <button
                key={c.id}
                type="button"
                onClick={() => setPicked(c.id)}
                className={cn(
                  "ax-press ax-caption rounded-full border px-2.5 py-1",
                  sessionId === c.id
                    ? "border-cyan-accent/50 bg-secondary text-foreground"
                    : "border-border text-muted-foreground",
                )}
              >
                {stamp(c.started_at)} · {c.joins} joined
                {c.never_joined > 0 ? ` · ${c.never_joined} did not` : ""}
              </button>
            ))}
          </div>

          <div className="ax-plane space-y-ax-3 rounded-xl p-ax-4">
            <dl className="grid gap-ax-2 text-xs sm:grid-cols-3">
              <div>
                <dt className="ax-caption text-steel">Length</dt>
                <dd className="text-muted-foreground">{minutes(record.data?.duration_ms)}</dd>
              </div>
              <div>
                <dt className="ax-caption text-steel">Taken from</dt>
                <dd className="text-muted-foreground">
                  {record.data?.duration_source ?? "Not recorded"}
                </dd>
              </div>
              <div>
                <dt className="ax-caption text-steel">Time to connect</dt>
                <dd className="text-muted-foreground">
                  {record.data?.call?.setup_ms == null
                    ? "Not recorded"
                    : `${record.data.call.setup_ms} ms`}
                </dd>
              </div>
            </dl>

            <p className="ax-caption flex items-center gap-2 text-steel">
              <Radio className="size-3.5" aria-hidden="true" />
              {record.data?.call?.path === "relay"
                ? "Media went through our own relay server."
                : record.data?.call?.path === "p2p"
                  ? "Media went directly between the devices."
                  : "The media route was not recorded."}
            </p>

            <div>
              <p className="ax-caption text-steel">Who joined, and when</p>
              <ul className="mt-1 space-y-0.5 text-xs text-muted-foreground">
                {(record.data?.join_truth ?? []).length === 0 ? (
                  <li>Nothing recorded.</li>
                ) : (
                  record.data!.join_truth!.map((j, i) => (
                    <li key={i}>
                      {j.user_id} · {j.event} · {msStamp(j.at_ms)}
                      {j.path ? ` · ${j.path}` : ""}
                    </li>
                  ))
                )}
              </ul>
            </div>

            {(record.data?.never_joined ?? []).length > 0 && (
              <div>
                <p className="ax-caption flex items-center gap-2 text-amber-400">
                  <UserX className="size-3.5" aria-hidden="true" /> Invited but never joined
                </p>
                <ul className="mt-1 space-y-0.5 text-xs text-muted-foreground">
                  {record.data!.never_joined!.map((u) => (
                    <li key={u}>{u}</li>
                  ))}
                </ul>
              </div>
            )}

            {(record.data?.transport_switches ?? []).length > 0 && (
              <div>
                <p className="ax-caption text-steel">Route changes during the call</p>
                <ul className="mt-1 space-y-0.5 text-xs text-muted-foreground">
                  {record.data!.transport_switches!.map((t, i) => (
                    <li key={i}>
                      {t.path}
                      {t.relay_host ? ` · ${t.relay_host}` : ""} · {msStamp(t.at_ms)}
                      {t.reason ? ` · ${t.reason}` : ""}
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {(record.data?.files ?? []).length > 0 && (
              <div>
                <p className="ax-caption text-steel">Files shared inside the call</p>
                <ul className="mt-1 space-y-0.5 text-xs text-muted-foreground">
                  {record.data!.files!.map((f) => (
                    <li key={f.version_id}>
                      {f.name ?? f.version_id} · {bytesLabel(f.bytes ?? 0)} ·{" "}
                      {(f.evidence ?? []).map((e) => e.state).join(" → ") || "no steps recorded"}
                    </li>
                  ))}
                </ul>
              </div>
            )}

            <div>
              <p className="ax-caption text-steel">What came out of it</p>
              <ul className="mt-1 space-y-0.5 text-xs text-muted-foreground">
                {(record.data?.work ?? []).length === 0 ? (
                  <li>No recorded outcome.</li>
                ) : (
                  record.data!.work!.map((w, i) => (
                    <li key={i}>
                      {w.object_type} · {w.object_id}
                      {w.note ? ` · ${w.note}` : ""} · {msStamp(w.at_ms)}
                    </li>
                  ))
                )}
              </ul>
            </div>
          </div>
        </>
      )}
    </section>
  );
}
