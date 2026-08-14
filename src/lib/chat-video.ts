/**
 * ANEXOVideoChat — plan gate only.
 *
 * PHASE 10A LOCK: asli call engine `src/lib/chat-call.ts` hai (Trickle ICE,
 * ICE restart, TURN fallback, simulcast, realtime signaling). Phase 7 ka
 * polling-based P2P engine yahan se hata diya gaya hai — do engine rakhna
 * duplicate/dead code tha, aur polling primary kabhi nahi hota.
 *
 * Gate DB se: `chat_video_allowed()` = founder + business_pro. Baki plans ko
 * button nahi milta, aur server bhi 403 deta hai.
 */
import { useQuery } from "@tanstack/react-query";

import { type ApiError } from "@/lib/api";
import { chatCall } from "@/lib/chat-transport";

export function useVideoGate(enabled: boolean) {
  return useQuery<{ allowed: boolean; plan_required: string }, ApiError>({
    queryKey: ["chat", "video", "gate"],
    queryFn: () =>
      chatCall<{ allowed: boolean; plan_required: string }>("chat.video.gate", undefined, {
        path: "/api/chat/video/gate",
      }),
    enabled,
    retry: false,
    staleTime: 300_000,
  });
}
