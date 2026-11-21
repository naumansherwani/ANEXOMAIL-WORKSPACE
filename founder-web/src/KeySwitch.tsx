import { Switch } from "@/components/ui/switch";
import { useSingleKeys } from "./KeyLayer";
import { setSingle } from "./keys_store";
import { pushSwitch } from "./keys_sync";

// QC8a: the Settings row for the single-letter keys (WCAG 2.1.4). Browser copy is the fast one; the server copy (E199) makes every device follow it.
export function KeySwitch() {
  const on = useSingleKeys();
  return (
    <div className="setrow"><div><b>Single-letter keyboard shortcuts</b><p className="dim">j, k, c, e, s, u, r, a, f, / and g-then-letter in Mail. Switch off if a screen reader or voice control types into them by mistake. This device only; Ctrl keys, arrows, Enter and Esc keep working. Press ? to see all keys.</p></div>
      <Switch checked={on} aria-label="Single-letter keyboard shortcuts" onCheckedChange={(v) => { setSingle(v); pushSwitch(v); }} /></div>
  );
}
