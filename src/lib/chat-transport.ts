/**
 * ANEXOChat — TRANSPORT CHAIN (blueprint PART 0 + PHASE 2, locked).
 *
 * PRIMARY   : Rust engine — tRPC-style `/rpc/chat.*` (Caddy HTTP/3) +
 *             WebTransport / QUIC push stream for live messages.
 * FALLBACK  : Bun service `/api/chat/*` (port 3300) — sirf jab Rust
 *             procedure ya WebTransport available na ho.
 * TRUTH     : states sirf DB rows se. Transport label kabhi jhoot nahi bolta.
 */

import { useEffect, useRef, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";

import { ApiError, api, sessionToken } from "./api";
import { rpc } from "./rpc";

export type ChatTransport = "webtransport" | "rust" | "bun" | "offline";

/** Rust pe route na ho / reachable na ho to Bun fallback — same contract. */
export async function chatCall<T>(
  procedure: string,
  input: Record<string, unknown> | undefined,
  fallback: { path: string; method?: "GET" | "POST"; body?: unknown },
): Promise<T> {
  try {
    return await rpc<T>(procedure, input ?? {});
  } catch (error) {
    const err = error as ApiError;
    const canFallback = [0, 404, 501, 502, 503, 504].includes(err.status);
    if (!canFallback) throw err;
    return api<T>(fallback.path, {
      method: fallback.method ?? (fallback.body ? "POST" : "GET"),
      ...(fallback.body ? { body: JSON.stringify(fallback.body) } : {}),
    });
  }
}

const WT_URL = (import.meta.env['VITE_ANEXOCHAT_WT_URL'] as string | undefined)?.replace(/\/$/, "");

export function webTransportSupported(): boolean {
  return typeof window !== "undefined" && "WebTransport" in window && Boolean(WT_URL);
}

/**
 * Live push stream over WebTransport/QUIC. Frames sirf asli DB rows laate hain;
 * har frame par React Query invalidate hota hai. WT na ho to `poll` — aur UI
 * wahi likhta hai jo sach hai.
 */
export function useChatLive(conversationId: string | null): {
  transport: "webtransport" | "poll";
  detail: string;
} {
  const queryClient = useQueryClient();
  const [live, setLive] = useState(false);
  const [detail, setDetail] = useState("Polling over HTTP/3 (WebTransport unavailable)");
  const closer = useRef<(() => void) | null>(null);

  useEffect(() => {
    closer.current?.();
    closer.current = null;
    setLive(false);

    if (!conversationId || !webTransportSupported()) return;
    const token = sessionToken.get();
    if (!token) return;

    let stopped = false;
    let transport: { close: () => void } | null = null;

    (async () => {
      try {
        const WT = (window as unknown as { WebTransport: new (url: string) => any }).WebTransport;
        const wt = new WT(`${WT_URL}/wt/chat`);
        transport = wt;
        await wt.ready;
        const stream = await wt.createBidirectionalStream();
        const writer = stream.writable.getWriter();
        await writer.write(
          new TextEncoder().encode(
            JSON.stringify({ token, conversation_id: conversationId, after_seq: 0 }),
          ),
        );
        writer.releaseLock();

        const reader = stream.readable.getReader();
        const decoder = new TextDecoder();
        let buffer = "";
        setLive(true);
        setDetail("Live over WebTransport / QUIC (Rust engine)");

        while (!stopped) {
          const { value, done } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() ?? "";
          for (const line of lines) {
            if (!line.trim()) continue;
            let frame: { type?: string } = {};
            try {
              frame = JSON.parse(line);
            } catch {
              continue;
            }
            if (frame.type === "messages") {
              await queryClient.invalidateQueries({ queryKey: ["chat", "messages", conversationId] });
              await queryClient.invalidateQueries({ queryKey: ["chat", "conversations"] });
            }
            if (frame.type === "error") {
              setLive(false);
              setDetail("Polling over HTTP/3 (WebTransport refused this session)");
            }
          }
        }
      } catch {
        setLive(false);
        setDetail("Polling over HTTP/3 (WebTransport unavailable)");
      }
    })();

    closer.current = () => {
      stopped = true;
      try {
        transport?.close();
      } catch {
        /* already closed */
      }
    };
    return () => closer.current?.();
  }, [conversationId, queryClient]);

  return { transport: live ? "webtransport" : "poll", detail };
}
