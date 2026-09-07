import { Gavel, ShieldQuestion } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { notify } from "@/lib/notify";
import {
  useDecideDeviceAppeal,
  useDeviceAppealQueue,
  useOpenDeviceAppeal,
} from "@/lib/promise-engine";

/**
 * PHASE 23 loophole fix — DEVICE BAN APPEAL.
 * A block only ever lands on a device shape, never on an IP or a network, so
 * shared office and cafe machines never take somebody else's punishment. Every
 * block can be appealed, and every decision is written down with a reason.
 */
export function DeviceAppealPanel({ deviceHash }: { deviceHash?: string | null }) {
  const [hash, setHash] = useState(deviceHash ?? "");
  const [statement, setStatement] = useState("");
  const open = useOpenDeviceAppeal();
  const queue = useDeviceAppealQueue("all");
  const decide = useDecideDeviceAppeal();

  const submit = () => {
    if (!hash.trim() || statement.trim().length < 20) {
      notify.failed("Tell us more", {
        description: "We need the device id and at least 20 characters explaining the block.",
      });
      return;
    }
    open.mutate(
      { device_hash: hash.trim(), statement: statement.trim() },
      {
        onSuccess: (r) =>
          r.ok
            ? (setStatement(""),
              notify.done("Appeal filed", "A human reviews it and the decision is written down."))
            : notify.failed("Not filed", { description: r.message ?? r.error ?? "Try again." }),
        onError: (e) => notify.failed("Not filed", { description: e.message }),
      },
    );
  };

  const act = (id: string, decision: "reviewing" | "granted" | "denied") => {
    let reason = "";
    if (decision !== "reviewing") {
      reason = window.prompt("Reason for this decision (at least 12 characters):") ?? "";
      if (reason.trim().length < 12) {
        notify.failed("Reason required", { description: "Write at least 12 characters." });
        return;
      }
    }
    decide.mutate(
      { appeal_id: id, decision, reason: reason.trim() || undefined },
      {
        onSuccess: (r) =>
          r.ok
            ? notify.done("Decision recorded", `Appeal is now ${r.state}.`)
            : notify.failed("Not recorded", { description: r.message ?? r.error ?? "Try again." }),
        onError: (e) => notify.failed("Not recorded", { description: e.message }),
      },
    );
  };

  const appeals = queue.data?.appeals ?? [];
  const isReviewer = queue.data?.allowed ?? false;

  return (
    <section className="ax-plane mt-ax-5 space-y-ax-3 rounded-2xl p-ax-5">
      <header>
        <h3 className="ax-label text-foreground">
          <ShieldQuestion className="mr-1.5 inline size-3.5" aria-hidden="true" />
          Appeal a blocked device
        </h3>
        <p className="ax-caption mt-1 text-muted-foreground">
          A block lands on one device only — never on your internet connection or your office
          network, so nobody else on shared WiFi is punished for it. If a block is wrong, say so
          here: a person reads it and the decision is recorded with a reason.
        </p>
      </header>

      <div className="space-y-ax-2">
        <Input
          value={hash}
          onChange={(e) => setHash(e.target.value)}
          placeholder="Device id from your device list"
          className="h-8 text-xs"
        />
        <textarea
          value={statement}
          onChange={(e) => setStatement(e.target.value)}
          rows={3}
          placeholder="Why is this block wrong? (at least 20 characters)"
          className="w-full rounded-xl border border-border bg-transparent p-ax-3 text-xs text-foreground outline-none focus:border-cyan-accent/60"
        />
        <Button size="sm" disabled={open.isPending} onClick={submit}>
          <Gavel className="size-3.5" />
          File appeal
        </Button>
      </div>

      {isReviewer && (
        <div className="space-y-ax-2 border-t border-border pt-ax-3">
          <p className="ax-label text-foreground">Appeal queue</p>
          {appeals.length === 0 ? (
            <p className="ax-caption text-muted-foreground">No appeals waiting.</p>
          ) : (
            <ul className="space-y-ax-2">
              {appeals.map((a) => (
                <li key={a.id} className="rounded-xl border border-border p-ax-3">
                  <p className="ax-caption text-steel">
                    {a.device_hash} · {a.state} · {new Date(a.created_at).toLocaleString()}
                  </p>
                  <p className="mt-1 text-[13px] text-foreground">{a.statement}</p>
                  {a.decision_reason && (
                    <p className="ax-caption mt-1 text-muted-foreground">
                      Decision: {a.decision_reason}
                    </p>
                  )}
                  {a.state !== "granted" && a.state !== "denied" && (
                    <div className="mt-ax-2 flex flex-wrap gap-2">
                      {a.state === "new" && (
                        <Button size="sm" variant="ghost" onClick={() => act(a.id, "reviewing")}>
                          Start review
                        </Button>
                      )}
                      <Button size="sm" onClick={() => act(a.id, "granted")}>
                        Unblock device
                      </Button>
                      <Button size="sm" variant="ghost" onClick={() => act(a.id, "denied")}>
                        Keep the block
                      </Button>
                    </div>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </section>
  );
}
