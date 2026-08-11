import { createFileRoute } from "@tanstack/react-router";
import { Inbox, RefreshCw, Trash2 } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { EmptyState } from "@/components/app/Panel";
import { Verdict } from "@/components/app/premium/PremiumBits";
import { Note } from "@/components/app/release/ReleaseBits";
import { SkeletonLine } from "@/components/state/Skeletons";
import { useNetwork } from "@/lib/network";
import { notify } from "@/lib/notify";
import { useOutbox } from "@/lib/release";

export const Route = createFileRoute("/app/mail/outbox")({
  head: () => ({
    meta: [
      { title: "Outbox — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: OutboxPage,
});

/**
 * Feature 4 — Offline outbox with truth. Mail IndexedDB mein queue hoti hai,
 * exponential retry, aur "sent" tab tak nahi jab tak server confirm na kare.
 */
function OutboxPage() {
  const net = useNetwork();
  const outbox = useOutbox();
  const items = outbox.items;

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Inbox className="size-3.5" aria-hidden="true" /> Outbox</>}
        title="Queued on this device, sent only when proven"
        blurb="Offline mail waits here with its own retry clock. Nothing moves to Sent until the server confirms delivery — we do not fake a send."
      >
        <div className="flex flex-wrap items-center gap-ax-3">
          <button
            type="button"
            disabled={outbox.flushing || !net.online}
            onClick={() =>
              void outbox.flush().then((r) => {
                if (r.sent > 0) notify.done(`${r.sent} sent`, r.failed ? `${r.failed} still queued` : undefined);
                else if (r.failed > 0) notify.info("Still queued", "Retry scheduled with backoff.");
                else notify.info("Nothing to flush");
              })
            }
            className="ax-press inline-flex items-center gap-1.5 rounded-lg bg-foreground px-3 py-2 text-[12px] font-semibold text-background disabled:opacity-50"
          >
            <RefreshCw className="size-3.5" aria-hidden="true" />
            {outbox.flushing ? "Sending…" : "Send queued mail"}
          </button>
          <span className="ax-caption text-muted-foreground">
            {net.online ? "Online — the queue flushes automatically" : "Offline — queued safely on this device"}
          </span>
        </div>

        {items === null ? (
          <div className="mt-ax-5 space-y-2">
            <SkeletonLine className="h-3" width="80%" />
            <SkeletonLine className="h-3" width="60%" />
          </div>
        ) : items.length === 0 ? (
          <div className="mt-ax-5">
            <EmptyState
              icon={<Inbox className="size-5" />}
              title="Outbox is empty"
              body="Anything you send without a connection lands here until it is really delivered."
            />
          </div>
        ) : (
          <>
            <div className="mt-ax-5 grid gap-ax-3 sm:grid-cols-3">
              <Stat label="Queued" value={String(items.filter((i) => i.state === "queued").length)} />
              <Stat label="Failed" value={String(items.filter((i) => i.state === "failed").length)} hint="after 6 tries" />
              <Stat label="Total on device" value={String(items.length)} />
            </div>
            <ul className="mt-ax-4 space-y-1.5">
              {items.map((i) => (
                <Row key={i.key}>
                  <Verdict verdict={i.state === "failed" ? "fail" : i.state === "sending" ? "watch" : "watch"}>
                    {i.state}
                  </Verdict>
                  <span className="min-w-0 flex-1">
                    <span className="block font-semibold text-foreground">{i.subject || "(no subject)"}</span>
                    <span className="block truncate text-steel">
                      {i.to} · try {i.attempts}
                      {i.error ? ` · ${i.error}` : ""}
                    </span>
                  </span>
                  <span className="text-muted-foreground">
                    {i.next_retry_at > Date.now()
                      ? `retry in ${Math.max(1, Math.round((i.next_retry_at - Date.now()) / 1000))}s`
                      : "ready"}
                  </span>
                  <button
                    type="button"
                    aria-label={`Discard ${i.subject}`}
                    onClick={() => void outbox.drop(i.key).then(() => notify.done("Removed from outbox"))}
                    className="ax-press ml-auto text-steel hover:text-foreground"
                  >
                    <Trash2 className="size-3.5" aria-hidden="true" />
                  </button>
                </Row>
              ))}
            </ul>
            <Note>Retries back off: 5s, 10s, 20s… up to 15 minutes. After six failures an item waits for you.</Note>
          </>
        )}
      </Section>
    </div>
  );
}
