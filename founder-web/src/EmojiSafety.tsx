// QC1e-D1 (his order 19 Nov 13:29, order D1 first): NEW-EMOJI SAFETY under the message box. Anexomail only: Gmail and WhatsApp never warn.
// An emoji from a Unicode release newer than the common phone may show as an empty box on an older phone. This line appears only when the text really has one, names it, and one tap swaps it for its name in words.
// Data is the bundled emojibase release table (lazy chunk, loaded only when the text has an emoji). No network, no storage.
import { useEffect, useMemo, useState } from "react";
import { hasEmoji, inWords, nameIndex, newerEmoji, versionMap } from "./emoji_pure";
import { loadData, loadVersions } from "./EmojiPicker";
import "./emoji.css";

export function EmojiSafety({ text, onChange }: { text: string; onChange: (v: string) => void }) {
  const [tables, setTables] = useState<{ vm: Map<string, number>; names: Map<string, string> } | null>(null);
  const wants = hasEmoji(text);
  useEffect(() => {
    if (!wants || tables) return; let live = true;
    Promise.all([loadVersions(), loadData()]).then(([v, d]) => { if (live) setTables({ vm: versionMap(v), names: nameIndex(d.all) }); }).catch(() => { /* no table, no warning: we only warn when we know */ });
    return () => { live = false; };
  }, [wants, tables]);
  const flags = useMemo(() => (tables && wants ? newerEmoji(text, tables.vm, tables.names) : []), [tables, wants, text]);
  if (!flags.length) return null;
  return (
    <p className="emo-safe small" role="status">
      <span aria-hidden="true">{flags.map((f) => f.emoji).join(" ")}</span>
      <span>{flags.length === 1 ? ` ${flags[0].name} is new (Unicode ${flags[0].version}) and may show as an empty box on older phones.` : ` ${flags.length} emoji are new and may show as empty boxes on older phones.`}</span>
      <button type="button" className="mx-btn alt emo-words" onClick={() => onChange(inWords(text, flags))}>Use words</button>
    </p>
  );
}
