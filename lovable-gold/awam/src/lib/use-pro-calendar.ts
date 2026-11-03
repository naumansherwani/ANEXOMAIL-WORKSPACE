import { useAuth } from "@/lib/auth";
import { showProCalendar, surfaceFromSession } from "@/lib/plan-surface";

/**
 * Calendar Pro tools (Overlap Matrix, Focus Ring, meeting cost) — Pro and above.
 * UI sirf aaina hai; asli rok server par (Rust `calendar.overlap`: feature_not_available).
 */
export function useProCalendar(): boolean {
  const { session, organisation } = useAuth();
  const { billed, kind } = surfaceFromSession(session?.user, organisation?.slug);
  return showProCalendar(billed, null, kind);
}
