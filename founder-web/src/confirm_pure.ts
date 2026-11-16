// Q1b4 step d: the question asked BEFORE a delete (his 17 Nov 02:54 order: "trash par click karo to poochta bhi nahi"). Pure, so the exact words are tested.
// Rules: say exactly what will happen, use verbs on the buttons (never OK/Cancel), the SAFE button is the default focus, nothing here changes data.
export type Ask = { title: string; body: string; yes: string; no: string; danger: boolean; skip?: boolean };
export function deleteQuestion(folder: string, direction: "in" | "out", subject?: string | null): Ask {
  const what = subject && subject.trim() ? `"${subject.trim().slice(0, 60)}"` : "this mail";
  if (direction === "out" && (folder === "outbox" || folder === "drafts")) return { title: "Discard this unsent mail?", body: `${what} has not been sent yet. If you discard it, it will never be sent.`, yes: "Discard mail", no: "Keep it", danger: true };
  if (folder === "trash") return { title: "Already in Trash", body: `${what} is already in Trash. Nothing more is removed from here.`, yes: "OK", no: "Close", danger: false, skip: true };
  if (direction === "out") return { title: "Move to Trash?", body: `${what} was already sent. Moving it to Trash only hides your copy; the people who received it still have it.`, yes: "Move to Trash", no: "Keep it", danger: true };
  return { title: "Move to Trash?", body: `${what} moves to Trash. You can restore it from Trash.`, yes: "Move to Trash", no: "Keep it", danger: true };
}
/** Enter must never confirm a delete by accident: only an explicit click or Enter while the red button itself has focus. */
export function confirmKey(key: string, onYes: boolean): "yes" | "no" | "none" { return key === "Escape" ? "no" : key === "Enter" && onYes ? "yes" : "none"; }
