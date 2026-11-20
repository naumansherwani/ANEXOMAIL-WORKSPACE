// Q1b4 step d: the question asked BEFORE a delete (his 17 Nov 02:54 order: "trash par click karo to poochta bhi nahi"). Pure, so the exact words are tested.
// Rules: say exactly what will happen, use verbs on the buttons (never OK/Cancel), the SAFE button is the default focus, nothing here changes data.
export type Ask = { title: string; body: string; yes: string; no: string; danger: boolean; skip?: boolean; forever?: boolean };
export function deleteQuestion(folder: string, direction: "in" | "out", subject?: string | null): Ask {
  const what = subject && subject.trim() ? `"${subject.trim().slice(0, 60)}"` : "this mail";
  if (direction === "out" && (folder === "outbox" || folder === "drafts")) return { title: "Discard this unsent mail?", body: `${what} has not been sent yet. If you discard it, it will never be sent.`, yes: "Discard mail", no: "Keep it", danger: true };
  if (folder === "trash") return { title: "Delete forever?", body: `${what} will be deleted for good. This cannot be undone, and it cannot be restored from Trash. You will be asked to touch your security key to confirm.`, yes: "Delete forever", no: "Keep it", danger: true, forever: true };   // QC5 (20 Nov 2026)
  if (direction === "out") return { title: "Move to Trash?", body: `${what} was already sent. Moving it to Trash only hides your copy; the people who received it still have it.`, yes: "Move to Trash", no: "Keep it", danger: true };
  return { title: "Move to Trash?", body: `${what} moves to Trash. You can restore it from Trash.`, yes: "Move to Trash", no: "Keep it", danger: true };
}
/** Enter must never confirm a delete by accident: only an explicit click or Enter while the red button itself has focus. */
export function confirmKey(key: string, onYes: boolean): "yes" | "no" | "none" { return key === "Escape" ? "no" : key === "Enter" && onYes ? "yes" : "none"; }

/** QC5: Empty Trash for the mails listed now (at most 100 per touch; the door takes 1..100 ids and each touch is bound to exactly those ids). */
export const FOREVER_BATCH = 100;
export function emptyTrashQuestion(n: number): Ask {
  const k = Math.min(Math.max(0, Math.floor(n) || 0), FOREVER_BATCH);
  return { title: k === 1 ? "Delete 1 mail forever?" : `Delete ${k} mails forever?`, body: `${k === 1 ? "This mail" : "These mails"} in Trash will be deleted for good. This cannot be undone. You will be asked to touch your security key once.${n > FOREVER_BATCH ? ` Only the first ${FOREVER_BATCH} are deleted now; press Empty Trash again for the rest.` : ""}`, yes: "Delete forever", no: "Keep them", danger: true, forever: true, skip: k === 0 };
}
export const foreverIds = (ids: string[]): string[] => ids.slice(0, FOREVER_BATCH);
