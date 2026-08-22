import { Copy, EyeOff, Pencil, Pin, Reply, Smile, Trash2 } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

import { Tick } from "@/components/app/chat/Ticks";
import {
  DELETE_WINDOW_MS,
  EDIT_WINDOW_MS,
  STATE_LABEL,
  messageState,
  withinWindow,
  type ChatMessage,
  type MessageState,
  type OutboxItem,
} from "@/lib/chat";

/**
 * Virtualized message stream — windowed rendering so a huge conversation opens
 * without a skeleton. Messenger parity: reactions, reply quote, edit (5 min),
 * delete for me / for everyone (1 hour), pin, copy. Provenance chip on hover.
 * Har state DB se aata hai — koi guess nahi.
 */
const ROW_ESTIMATE = 108;
const OVERSCAN = 12;
const QUICK = ["👍", "❤️", "😂", "🙏", "🔥", "✅"];

export type MessageActions = {
  onReact: (messageId: string, emoji: string) => void;
  onReply: (message: ChatMessage) => void;
  onEdit: (message: ChatMessage) => void;
  onDeleteForEveryone: (messageId: string) => void;
  onHide: (messageId: string) => void;
  onPin: (messageId: string, pin: boolean) => void;
};

export function MessageStream({
  messages,
  pending,
  actions,
}: {
  /** Oldest -> newest. */
  messages: ChatMessage[];
  pending: OutboxItem[];
  actions: MessageActions;
}) {
  const scroller = useRef<HTMLDivElement>(null);
  const [range, setRange] = useState({ start: 0, end: 40 });

  const total = messages.length;

  useEffect(() => {
    const el = scroller.current;
    if (!el) return;
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
    return () => el.removeEventListener("scroll", onScroll);
  }, [total]);

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

  const pinned = useMemo(() => messages.filter((m) => m.pinned_at), [messages]);

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      {pinned.length ? (
        <div className="shrink-0 border-b border-border bg-card/60 px-4 py-2 text-[11px] text-muted-foreground">
          <span className="inline-flex items-center gap-1.5">
            <Pin className="size-3" /> {pinned.length} pinned
          </span>{" "}
          · {pinned.at(-1)!.sender_name}: {pinned.at(-1)!.body.slice(0, 90)}
        </div>
      ) : null}
      <div ref={scroller} className="min-h-0 flex-1 overflow-y-auto px-4 py-4">
        <div style={{ height: range.start * ROW_ESTIMATE }} aria-hidden />
        <ul className="flex flex-col gap-2">
          {window_.map((m) => (
            <Bubble key={m.id} message={m} actions={actions} />
          ))}
          {pending.map((p) => (
            <PendingBubble key={p.client_msg_id} item={p} />
          ))}
        </ul>
        <div style={{ height: Math.max(0, (total - range.end) * ROW_ESTIMATE) }} aria-hidden />
      </div>
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

function IconBtn({
  label,
  onClick,
  children,
}: {
  label: string;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      onClick={onClick}
      className="ax-press rounded-md border border-border p-1 text-muted-foreground hover:text-foreground"
    >
      {children}
    </button>
  );
}

function Bubble({ message, actions }: { message: ChatMessage; actions: MessageActions }) {
  const state = messageState(message);
  const [picker, setPicker] = useState(false);
  const canEdit = message.mine && withinWindow(message.created_at, EDIT_WINDOW_MS);
  const canUnsend = message.mine && withinWindow(message.created_at, DELETE_WINDOW_MS);
  const reactions = message.reactions ?? [];

  return (
    <li className={"group flex " + (message.mine ? "justify-end" : "justify-start")}>
      <div className="max-w-[min(38rem,85%)]">
        {message.reply_to_id ? (
          <div className="mb-1 rounded-lg border-l-2 border-primary/50 bg-muted/40 px-2 py-1 text-[11px] text-muted-foreground">
            {message.reply_to_sender ?? "Teammate"}: {message.reply_to_body ?? "message removed"}
          </div>
        ) : null}
        <div
          className={
            "rounded-2xl px-3.5 py-2.5 text-sm leading-relaxed " +
            (message.mine
              ? "bg-primary/12 text-foreground"
              : "border border-border bg-card text-foreground")
          }
        >
          {message.body}
          {message.edited_at ? (
            <span className="ml-1.5 text-[11px] text-muted-foreground">(edited)</span>
          ) : null}
        </div>

        {reactions.length ? (
          <div className="mt-1 flex flex-wrap gap-1">
            {reactions.map((r) => (
              <button
                key={r.emoji}
                type="button"
                onClick={() => actions.onReact(message.id, r.emoji)}
                className={
                  "rounded-full border px-1.5 py-0.5 text-[11px] " +
                  (r.mine ? "border-primary/60 text-foreground" : "border-border text-muted-foreground")
                }
              >
                {r.emoji} {r.count}
              </button>
            ))}
          </div>
        ) : null}

        <div className="mt-1 flex flex-wrap items-center gap-1.5 text-[11px] text-muted-foreground">
          <StateIcon state={state} />
          <span>{STATE_LABEL[state]}</span>
          <span aria-hidden>·</span>
          <span>{stamp(message.created_at)}</span>

          <span className="ml-1 hidden items-center gap-1 group-hover:inline-flex">
            <IconBtn label="React" onClick={() => setPicker((v) => !v)}>
              <Smile className="size-3" />
            </IconBtn>
            <IconBtn label="Reply" onClick={() => actions.onReply(message)}>
              <Reply className="size-3" />
            </IconBtn>
            <IconBtn label="Copy" onClick={() => void navigator.clipboard.writeText(message.body)}>
              <Copy className="size-3" />
            </IconBtn>
            <IconBtn
              label={message.pinned_at ? "Unpin" : "Pin"}
              onClick={() => actions.onPin(message.id, !message.pinned_at)}
            >
              <Pin className="size-3" />
            </IconBtn>
            {canEdit ? (
              <IconBtn label="Edit (5 minutes)" onClick={() => actions.onEdit(message)}>
                <Pencil className="size-3" />
              </IconBtn>
            ) : null}
            <IconBtn label="Delete for me" onClick={() => actions.onHide(message.id)}>
              <EyeOff className="size-3" />
            </IconBtn>
            {canUnsend ? (
              <IconBtn
                label="Delete for everyone (1 hour)"
                onClick={() => actions.onDeleteForEveryone(message.id)}
              >
                <Trash2 className="size-3" />
              </IconBtn>
            ) : null}
          </span>

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

        {picker ? (
          <div className="mt-1 flex gap-1">
            {QUICK.map((emoji) => (
              <button
                key={emoji}
                type="button"
                className="ax-press rounded-md border border-border px-1.5 py-0.5 text-sm"
                onClick={() => {
                  actions.onReact(message.id, emoji);
                  setPicker(false);
                }}
              >
                {emoji}
              </button>
            ))}
          </div>
        ) : null}
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
