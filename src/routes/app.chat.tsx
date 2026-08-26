import { createFileRoute } from "@tanstack/react-router";
import { Paperclip, PhoneCall, PictureInPicture2, Search, Send, WifiOff, X } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

import { AtmosphereControl, AtmosphereStage, useAtmosphere } from "@/components/app/chat/Atmosphere";
import { ConversationRow, HealthChip } from "@/components/app/chat/ChatBits";
import { CinemaStage, useCinema } from "@/components/app/chat/CinemaStage";
import { MessageStream } from "@/components/app/chat/MessageStream";
import { VideoCallOverlay } from "@/components/app/chat/VideoCall";
import { WorkStrip } from "@/components/app/chat/WorkStrip";
import { DetailPanel, EmptyState, ListPanel } from "@/components/app/Panel";
import { StateBlock } from "@/components/state/StateBlock";
import {
  deviceLabel,
  useChatSearch,
  useConversationPrefs,
  useDeleteMessage,
  useEditMessage,
  useHideMessage,
  usePinMessage,
  useReact,
  useChatBootstrap,
  useChatSend,
  useConversations,
  useMarkRead,
  useMessages,
  usePresence,
  useStartDirect,
  useTypingPing,
} from "@/lib/chat";
import type { ChatMessage } from "@/lib/chat";
import { chatCall, useChatLive } from "@/lib/chat-transport";
import { useCall } from "@/lib/chat-call";
import { useVideoGate } from "@/lib/chat-video";
import { filesFromPaste, newUpload, uploadImage, type Upload } from "@/lib/chat-attachments";
import { useDraft } from "@/lib/chat-drafts";
import { deepLinkConversation, isPaneMode, popOutConversation } from "@/lib/chat-multitask";

export const Route = createFileRoute("/app/chat")({
  head: () => ({
    meta: [
      { title: "ANEXOChat — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: ChatPage,
});

function ChatPage() {
  const atmosphere = useAtmosphere();
  const bootstrap = useChatBootstrap();
  const entitled = bootstrap.isSuccess;
  const conversations = useConversations(entitled);
  // Phase 11 multitasking: pop-out window `?c=<id>` deep link se seedha khulti hai.
  const [openId, setOpenId] = useState<string | null>(() =>
    typeof window === "undefined" ? null : deepLinkConversation(),
  );
  const pane = isPaneMode();
  const messages = useMessages(openId);
  const presence = usePresence(openId, entitled);
  const { send, pending } = useChatSend(openId);
  const markRead = useMarkRead(openId);
  const startDirect = useStartDirect();
  const typingPing = useTypingPing(openId);
  // Phase 11 drafts: har conversation ka apna saved draft (localStorage, device pe).
  const draftBox = useDraft(openId);
  // Phase 11 attachments: drag-drop / paste / picker — progress + errors asli.
  const [uploads, setUploads] = useState<Upload[]>([]);
  const fileRef = useRef<HTMLInputElement>(null);

  function addFiles(files: File[]) {
    if (!openId || !files.length) return;
    for (const file of files) {
      const u = newUpload(file);
      setUploads((prev) => [...prev, u]);
      void uploadImage(openId, file, () => setUploads((prev) => [...prev]));
    }
  }
  const [replyTo, setReplyTo] = useState<ChatMessage | null>(null);
  const [query, setQuery] = useState("");
  const react = useReact(openId);
  const editMessage = useEditMessage(openId);
  const deleteMessage = useDeleteMessage(openId);
  const hideMessage = useHideMessage(openId);
  const pinMessage = usePinMessage(openId);
  const prefs = useConversationPrefs(openId);
  const search = useChatSearch(query);
  const [online, setOnline] = useState(true);
  const live = useChatLive(openId);

  useEffect(() => {
    const sync = () => setOnline(navigator.onLine);
    sync();
    window.addEventListener("online", sync);
    window.addEventListener("offline", sync);
    return () => {
      window.removeEventListener("online", sync);
      window.removeEventListener("offline", sync);
    };
  }, []);

  // Presence truth: apna heartbeat bhejte hain, doosre ka DB se padhte hain.
  useEffect(() => {
    if (!entitled) return;
    const ping = () =>
      void chatCall<{ ok: boolean }>(
        "chat.presence.ping",
        { device: deviceLabel() },
        { path: "/api/chat/presence", method: "POST", body: { device: deviceLabel() } },
      ).catch(() => {});
    ping();
    const timer = window.setInterval(ping, 30_000);
    return () => window.clearInterval(timer);
  }, [entitled]);

  const list = conversations.data?.conversations ?? [];
  const active = list.find((c) => c.conversation_id === openId) ?? null;
  const cinema = useCinema(atmosphere.calm, atmosphere.effect);
  const gate = useVideoGate(entitled);
  const call = useCall(openId, bootstrap.data?.user_id ?? null, active?.other_user_id ?? null);
  const ordered = useMemo(
    () => [...(messages.data?.messages ?? [])].sort((a, b) => a.seq - b.seq),
    [messages.data],
  );

  // Read receipt sirf tab jab message asal mein screen par aaya.
  useEffect(() => {
    const last = ordered.at(-1);
    if (!openId || !last || last.mine) return;
    markRead.mutate(last.seq);
  }, [openId, ordered, markRead]);

  const typingNames = (presence.data?.typing ?? [])
    .map((t) => bootstrap.data?.members.find((m) => m.user_id === t.user_id)?.display_name)
    .filter(Boolean) as string[];

  const teammates = (bootstrap.data?.members ?? []).filter(
    (m) => m.user_id !== bootstrap.data?.user_id,
  );

  if (bootstrap.isLoading) {
    return (
      <div className="px-6 py-8">
        <StateBlock title="Opening ANEXOChat" body="Checking your workspace access." />
      </div>
    );
  }

  if (bootstrap.isError) {
    const forbidden = bootstrap.error?.status === 403;
    return (
      <div className="px-6 py-8">
        <StateBlock
          title={forbidden ? "ANEXOChat is on Business plans" : "ANEXOChat is not reachable"}
          body={
            forbidden
              ? "ANEXOChat is included with Business and Business Pro. Basic and Pro do not include it."
              : bootstrap.error?.message ?? "The workspace server did not answer."
          }
        />
      </div>
    );
  }

  return (
    <div className="relative flex min-h-0 flex-1 flex-col md:flex-row">
      <AtmosphereStage band={atmosphere.band} effect={atmosphere.effect} calm={atmosphere.calm} />
      <CinemaStage band={atmosphere.band} effect={atmosphere.effect} quality={cinema.quality} />

      {/* Phase 11 multitasking: pop-out pane (?pane=1) mein sirf detail dikhta hai. */}
      {pane ? null : (
      <ListPanel
        title="ANEXOChat"
        mobileHidden={Boolean(openId)}
        action={
          <span className="text-[11px] text-muted-foreground" title={live.detail}>
            {list.length} {list.length === 1 ? "conversation" : "conversations"} ·{" "}
            {live.transport === "webtransport" ? "WebTransport live" : "HTTP/3 polling"}
          </span>
        }
      >
        <div className="border-b border-border px-3 py-2">
          <label className="sr-only" htmlFor="ax-chat-search">
            Search messages
          </label>
          <div className="flex items-center gap-2 rounded-lg border border-border px-2 py-1.5">
            <Search className="size-3.5 text-muted-foreground" />
            <input
              id="ax-chat-search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search messages"
              className="w-full bg-transparent text-xs text-foreground outline-none"
            />
          </div>
          {query.trim().length >= 2 ? (
            <div className="mt-2 flex flex-col gap-1">
              {(search.data?.results ?? []).length === 0 ? (
                <p className="text-[11px] text-muted-foreground">
                  {search.isFetching ? "Searching" : "No message matches that text."}
                </p>
              ) : (
                (search.data?.results ?? []).map((hit) => (
                  <button
                    key={hit.id}
                    type="button"
                    onClick={() => {
                      setOpenId(hit.conversation_id);
                      setQuery("");
                    }}
                    className="rounded-lg border border-border px-2 py-1 text-left text-[11px] text-muted-foreground hover:text-foreground"
                  >
                    <span className="font-semibold text-foreground">{hit.sender_name}</span>{" "}
                    {hit.body.slice(0, 70)}
                  </button>
                ))
              )}
            </div>
          ) : null}
        </div>

        {list.length === 0 ? (
          <div className="p-4">
            <EmptyState
              title="No conversations yet"
              body={
                teammates.length
                  ? "Start a direct conversation with someone in this workspace."
                  : "Nobody else is in this chat workspace yet, so there is nothing to open."
              }
              action={
                teammates.length ? (
                  <div className="flex flex-col gap-1">
                    {teammates.map((m) => (
                      <button
                        key={m.user_id}
                        type="button"
                        className="ax-press rounded-lg border border-border px-3 py-1.5 text-xs text-foreground"
                        onClick={() =>
                          startDirect.mutate(m.user_id, {
                            onSuccess: (r: { conversation_id: string }) =>
                              setOpenId(r.conversation_id),
                          })
                        }
                      >
                        Message {m.display_name ?? "teammate"}
                      </button>
                    ))}
                  </div>
                ) : undefined
              }
            />
          </div>
        ) : (
          list.map((c) => (
            <ConversationRow
              key={c.conversation_id}
              conversation={c}
              active={c.conversation_id === openId}
              onOpen={() => setOpenId(c.conversation_id)}
            />
          ))
        )}
      </ListPanel>
      )}

      <DetailPanel mobileVisible={Boolean(openId)}>
        {!active ? (
          <div className="p-6">
            <EmptyState
              title="Pick a conversation"
              body="Every message here is stored in your workspace and every state is real."
            />
          </div>
        ) : (
          <div className="flex h-full min-h-0 flex-col">
            <header className="shrink-0 border-b border-border px-4 py-3">
              <div className="flex flex-wrap items-center gap-2">
                <h2 className="text-sm font-bold tracking-tight text-foreground">
                  {active.other_name ?? "Conversation"}
                </h2>
                <HealthChip health={active.health} reason={active.health_reason} />
                {!online ? (
                  <span className="inline-flex items-center gap-1 rounded-full border border-border px-2 py-0.5 text-[11px] text-muted-foreground">
                    <WifiOff className="size-3" /> Offline — messages will wait
                  </span>
                ) : null}
                {gate.data?.allowed ? (
                  <button
                    type="button"
                    onClick={() => void call.start()}
                    className="ax-press ml-auto inline-flex items-center gap-1.5 rounded-full border border-border px-2.5 py-1 text-[11px] text-foreground"
                  >
                    <PhoneCall className="size-3" /> Video call
                  </button>
                ) : (
                  <span className="ml-auto text-[11px] text-muted-foreground">
                    ANEXOVideoChat is on Business Pro
                  </span>
                )}
                <button
                  type="button"
                  onClick={() => prefs.mutate({ mute_minutes: 60 })}
                  className="rounded-full border border-border px-2.5 py-1 text-[11px] text-muted-foreground hover:text-foreground"
                >
                  Mute 1h
                </button>
                <button
                  type="button"
                  onClick={() => active && popOutConversation(active.conversation_id)}
                  aria-label="Open this chat in a side window"
                  title="Open in side window"
                  className="rounded-full border border-border px-2.5 py-1 text-[11px] text-muted-foreground hover:text-foreground"
                >
                  <PictureInPicture2 className="size-3.5" />
                </button>
                <button
                  type="button"
                  onClick={() => prefs.mutate({ archived: true })}
                  className="rounded-full border border-border px-2.5 py-1 text-[11px] text-muted-foreground hover:text-foreground"
                >
                  Archive
                </button>
              </div>
              <div className="mt-2 flex flex-wrap items-center gap-2">
                <AtmosphereControl
                  band={atmosphere.band}
                  effect={atmosphere.effect}
                  calm={atmosphere.calm}
                  caption={atmosphere.caption}
                  mode={atmosphere.mode}
                  onEffect={atmosphere.setEffect}
                  onMode={atmosphere.setMode}
                  onCalm={atmosphere.setCalm}
                />
                <select
                  aria-label="Cinematic quality"
                  value={cinema.pref}
                  onChange={(e) =>
                    cinema.setQuality(e.target.value as "auto" | "off" | "low" | "high")
                  }
                  className="rounded-full border border-border bg-transparent px-2.5 py-1 text-xs text-foreground"
                >
                  <option value="auto">Cinema: auto</option>
                  <option value="high">Cinema: high</option>
                  <option value="low">Cinema: low</option>
                  <option value="off">Cinema: off</option>
                </select>
                {cinema.soundable ? (
                  <button
                    type="button"
                    onClick={() => cinema.setSound(!cinema.sound)}
                    className="rounded-full border border-border px-2.5 py-1 text-xs text-muted-foreground hover:text-foreground"
                  >
                    {cinema.sound ? "Sound on" : "Sound off"}
                  </button>
                ) : null}
              </div>
            </header>

            <WorkStrip conversationId={openId!} />

            <MessageStream
              messages={ordered}
              pending={pending}
              actions={{
                onReact: (message_id, emoji) => react.mutate({ message_id, emoji }),
                onReply: (m) => setReplyTo(m),
                onEdit: (m) => {
                  const next = window.prompt("Edit message", m.body);
                  if (next && next.trim() && next !== m.body) {
                    editMessage.mutate({ message_id: m.id, body: next.trim() });
                  }
                },
                onDeleteForEveryone: (id) => deleteMessage.mutate(id),
                onHide: (id) => hideMessage.mutate(id),
                onPin: (message_id, pin) => pinMessage.mutate({ message_id, pin }),
              }}
            />

            <VideoCallOverlay
              phase={call.phase}
              detail={call.detail}
              stats={call.stats}
              remote={call.remote}
              local={call.local}
              incoming={call.incoming}
              signaling={call.signaling}
              turnAvailable={call.turnAvailable}
              showTechnical={gate.data?.allowed === true}
              quality={call.quality}
              onQuality={(next) => void call.setQuality(next)}
              capture={call.capture}
              codecs={call.codecs}
              maxRung={call.maxRung}
              onAnswer={() => void call.answer()}
              onHangup={call.hangup}
            />

            <div className="shrink-0 border-t border-border px-4 py-3">
              <p className="mb-1.5 h-4 text-[11px] text-muted-foreground">
                {typingNames.length
                  ? `${typingNames.join(", ")} ${typingNames.length === 1 ? "is" : "are"} typing`
                  : ""}
              </p>
              {replyTo ? (
                <div className="mb-2 flex items-start gap-2 rounded-lg border-l-2 border-primary/60 bg-muted/40 px-2 py-1 text-[11px] text-muted-foreground">
                  <span className="min-w-0 flex-1">
                    Replying to {replyTo.sender_name}: {replyTo.body.slice(0, 90)}
                  </span>
                  <button type="button" aria-label="Cancel reply" onClick={() => setReplyTo(null)}>
                    <X className="size-3" />
                  </button>
                </div>
              ) : null}
              <form
                className="flex items-end gap-2"
                onSubmit={(e) => {
                  e.preventDefault();
                  const body = draft.trim();
                  if (!body) return;
                  setDraft("");
                  typingPing(false);
                  send.mutate({ body, reply_to_id: replyTo?.id ?? null });
                  setReplyTo(null);
                }}
              >
                <textarea
                  value={draft}
                  rows={2}
                  onChange={(e) => {
                    setDraft(e.target.value);
                    typingPing(e.target.value.trim().length > 0);
                  }}
                  onBlur={() => typingPing(false)}
                  placeholder="Write a message"
                  className="min-h-[2.75rem] flex-1 resize-y rounded-xl border border-border bg-transparent px-3 py-2 text-sm text-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring"
                />
                <button
                  type="submit"
                  disabled={!draft.trim()}
                  className="ax-press inline-flex items-center gap-1.5 rounded-xl bg-primary px-3.5 py-2 text-sm font-semibold text-primary-foreground disabled:opacity-50"
                >
                  <Send className="size-4" />
                  Send
                </button>
              </form>
              <p className="mt-1.5 text-[11px] text-muted-foreground">
                Offline, a message waits here as “Waiting to send”. It is never shown as sent
                until the workspace has it.
              </p>
            </div>
          </div>
        )}
      </DetailPanel>
    </div>
  );
}