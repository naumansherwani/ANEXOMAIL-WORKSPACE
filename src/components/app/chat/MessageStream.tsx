import { Check, CheckCheck, Clock, Loader2, ShieldAlert } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

import {
  STATE_LABEL,
  messageState,
  type ChatMessage,
  type MessageState,
  type OutboxItem,
} from "@/lib/chat";

/**
 * Virtualized message stream — windowed rendering so a 500K-word conversation
 * opens without a skeleton. Provenance chip on hover: who, when, delivery truth.
 */
const ROW_ESTIMATE = 92;
const OVERSCAN = 12;

export function MessageStream({
  messages,
  pending,
}: {
  /** Oldest -> newest. */
  messages: ChatMessage[];
  pending: OutboxItem[];
}) {
  const scroller = useRef<HTMLDivElement>(null);
  const [range, setRange] = useState({ start: 0, end: 40 });
  const [height, setHeight] = useState(600);

  const total = messages.length;

  useEffect(() => {
    const el = scroller.current;
    if (!el) return;
    const measure = () => setHeight(el.clientHeight || 600);
    measure();
    const onScroll = () => {
      const visible = Math.ceil((el.clientHeight || 600) / ROW_ESTIMATE);
      const first = Math.floor(el.scrollTop / ROW_ESTIMATE);
      setRange({
        start: Math.max(0, first - OVERSCAN),
        end: Math.min(total, first + visible + OVERSCAN),
      });
    };
    onScroll();
    el.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", measure);
    return () => {
      el.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", measure);
    };
  }, [total]);

  // Newest message stays in view when the tail grows.
  const lastSeq = messages.at(-1)?.seq ?? 0;
  useEffect(() => {
    const el = scroller.current;
    if (!el) return;
    el.scrollTop = el.scrollHeight;
  }, [lastSeq, pending.length]);

  const window_ = useMemo(
    () => messages.slice(range.start, Math.max(range.end, range.start + 1)),
    [messages, range],
  );

  return (
    <div ref={scroller} className="min-h-0 flex-1 overflow-y-auto px-4 py-4" style={{ maxHeight: height ? undefined : 600 }}>
      <div style={{ height: range.start * ROW_ESTIMATE }} aria-hidden />
      <ul className="flex flex-col gap-2">
        {window_.map((m) => (
          <Bubble key={m.id} message={m} />
        ))}
        {pending.map((p) => (
          <PendingBubble key={p.client_msg_id} item={p} />
        ))}
      </ul>
      <div
        style={{ height: Math.max(0, (total - range.end) * ROW_ESTIMATE) }}
        aria-hidden
      />
    </div>
  );
}

function StateIcon({ state }: { state: MessageState }) {
  if (state === "sending") return <Loader2 className="size-3 animate-spin" />;
  if (state === "waiting") return <Clock className="size-3" />;
  if (state === "failed") return <ShieldAlert className="size-3" />;
  if (state === "read") return <CheckCheck className="size-3" />;
  if (state === "delivered") return <CheckCheck className="size-3 opacity-60" />;
  return <Check className="size-3 opacity-60" />;
}

function stamp(value: string) {
  return new Date(value).toLocaleString(undefined, {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function Bubble({ message }: { message: ChatMessage }) {
  const state = messageState(message);
  return (
    <li className={"group flex " + (message.mine ? "justify-end" : "justify-start")}>
      <div className="max-w-[min(38rem,85%)]">
        <div
          className={
            "rounded-2xl px-3.5 py-2.5 text-sm leading-relaxed " +
            (message.mine
              ? "bg-primary/12 text-foreground"
              : "border border-border bg-card text-foreground")
          }
        >
          {message.body}
        </div>
        <div className="mt-1 flex items-center gap-1.5 text-[11px] text-muted-foreground">
          <StateIcon state={state} />
          <span>{STATE_LABEL[state]}</span>
          <span aria-hidden>·</span>
          <span>{stamp(message.created_at)}</span>
          {/* Provenance chip — hover se poori sach: kis ne, kab, kis device se */}
          <span className="ml-1 hidden rounded-full border border-border px-1.5 py-0.5 group-hover:inline">
            {message.sender_name} · #{message.seq} · {message.device_label ?? "device unknown"} ·{" "}
            {message.read_at
              ? `read ${stamp(message.read_at)}`
              : message.delivered_at
                ? `delivered ${stamp(message.delivered_at)}`
                : "delivery not confirmed yet"}
          </span>
        </div>
      </div>
    </li>
  );
}

function PendingBubble({ item }: { item: OutboxItem }) {
  const state: MessageState = item.attempts > 0 ? "waiting" : "sending";
  return (
    <li className="flex justify-end">
      <div className="max-w-[min(38rem,85%)]">
        <div className="rounded-2xl border border-dashed border-border px-3.5 py-2.5 text-sm leading-relaxed text-foreground">
          {item.body}
        </div>
        <div className="mt-1 flex items-center gap-1.5 text-[11px] text-muted-foreground">
          <StateIcon state={state} />
          <span>{STATE_LABEL[state]}</span>
          <span aria-hidden>·</span>
          <span>queued {stamp(item.queued_at)}</span>
          {item.last_error ? <span>· {item.last_error}</span> : null}
        </div>
      </div>
    </li>
  );
}