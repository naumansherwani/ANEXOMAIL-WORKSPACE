// QC4b features 2 + 3: Reply / Reply all / Forward under the mail, 44 px each (keys r, a, f are wired in MailBox).
import type { ReplyKind } from "./reply_start";

export function MailReplyBar({ canAll, hasSel, onPick }: { canAll: boolean; hasSel: boolean; onPick: (k: ReplyKind) => void }) {
  // mousedown is stopped so pressing a button never clears the text the reader selected
  const b = (k: ReplyKind, label: string, key: string) => (
    <button type="button" className="mbx-rb" onMouseDown={(e) => e.preventDefault()} onClick={() => onPick(k)} aria-keyshortcuts={key} title={`${label} (${key})`}>{label}<kbd>{key}</kbd></button>);
  return (
    <div className="mbx-replybar" role="group" aria-label="Reply or forward">
      {b("reply", hasSel ? "Reply to selection" : "Reply", "r")}
      {canAll && b("all", "Reply all", "a")}
      {b("forward", "Forward", "f")}
    </div>
  );
}
