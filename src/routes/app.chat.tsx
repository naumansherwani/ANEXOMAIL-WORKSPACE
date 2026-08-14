import { createFileRoute } from "@tanstack/react-router";
import { Send, WifiOff } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import { AtmosphereControl, AtmosphereStage, useAtmosphere } from "@/components/app/chat/Atmosphere";
import { ConversationRow, HealthChip } from "@/components/app/chat/ChatBits";
import { MessageStream } from "@/components/app/chat/MessageStream";
import { WorkStrip } from "@/components/app/chat/WorkStrip";
import { DetailPanel, EmptyState, ListPanel } from "@/components/app/Panel";
import { StateBlock } from "@/components/state/StateBlock";
import {
  deviceLabel,
  useChatBootstrap,
  useChatSend,
  useConversations,
  useMarkRead,
  useMessages,
  usePresence,
  useStartDirect,
  useTypingPing,
} from "@/lib/chat";
import { chatCall, useChatLive } from "@/lib/chat-transport";

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
  const [openId, setOpenId] = useState<string | null>(null);
  const messages = useMessages(openId);
  const presence = usePresence(openId, entitled);
  const { send, pending } = useChatSend(openId);
  const markRead = useMarkRead(openId);
  const startDirect = useStartDirect();
  const typingPing = useTypingPing(openId);
  const [draft, setDraft] = useState("");
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
              </div>
              <div className="mt-2">
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
              </div>
            </header>

            <WorkStrip conversationId={openId!} />

            <MessageStream messages={ordered} pending={pending} />

            <div className="shrink-0 border-t border-border px-4 py-3">
              <p className="mb-1.5 h-4 text-[11px] text-muted-foreground">
                {typingNames.length
                  ? `${typingNames.join(", ")} ${typingNames.length === 1 ? "is" : "are"} typing`
                  : ""}
              </p>
              <form
                className="flex items-end gap-2"
                onSubmit={(e) => {
                  e.preventDefault();
                  const body = draft.trim();
                  if (!body) return;
                  setDraft("");
                  typingPing(false);
                  send.mutate(body);
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