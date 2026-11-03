/**
 * ANEXOChat · PHASE 11 — MULTITASKING (pop-out + split view)
 *
 * FOUNDER LOCK: panel kabhi nahi chhutta. Split view do asli conversations
 * side-by-side kholta hai (dono live, dono ki apni draft), aur pop-out ek
 * conversation ko alag window mein bhejta hai. Koi mock, koi screenshot.
 */
import { useCallback, useEffect, useState } from "react";

const SPLIT_KEY = "ax.chat.split";

export function useSplitView() {
  const [secondId, setSecondId] = useState<string | null>(null);

  useEffect(() => {
    if (typeof window === "undefined") return;
    setSecondId(window.localStorage.getItem(SPLIT_KEY) || null);
  }, []);

  const set = useCallback((id: string | null) => {
    setSecondId(id);
    if (typeof window === "undefined") return;
    if (id) window.localStorage.setItem(SPLIT_KEY, id);
    else window.localStorage.removeItem(SPLIT_KEY);
  }, []);

  return { secondId, set };
}

/**
 * Pop-out — asli browser window jo usi /app/chat route par khulti hai aur
 * conversation deep-link se open hota hai. Naya tab nahi, floating pane.
 */
export function popOutConversation(conversationId: string): boolean {
  if (typeof window === "undefined") return false;
  const url = `${window.location.origin}/app/chat?c=${encodeURIComponent(conversationId)}&pane=1`;
  const win = window.open(
    url,
    `anexochat-${conversationId}`,
    "popup=yes,width=520,height=760,noopener=no",
  );
  return Boolean(win);
}

/** Pop-out pane mein list/nav chhupa dete hain — sirf conversation. */
export function isPaneMode(): boolean {
  if (typeof window === "undefined") return false;
  return new URLSearchParams(window.location.search).get("pane") === "1";
}

export function deepLinkConversation(): string | null {
  if (typeof window === "undefined") return null;
  return new URLSearchParams(window.location.search).get("c");
}
