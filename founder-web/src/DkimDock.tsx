// Q1d-1a a4: founder-only mount of the DKIM panel UNDER the mailbox. MailBox.tsx is preserved for awam (inherit law), so the founder panel is NOT mounted inside it:
// App.tsx renders <MailBox /> and this dock side by side. It reads the founder's mailbox list itself (kernel door) and shows one panel per mailbox; nothing for awam.
import { useEffect, useState } from "react";
import { boxes } from "./mail_api";
import type { Box } from "./mail_pure";
import { DkimPanel } from "./DkimPanel";

export function DkimDock() {
  const [bx, setBx] = useState<Box[]>([]);
  useEffect(() => { let on = true; boxes().then((r) => { if (on && r?.connected) setBx(r.boxes); }).catch(() => {}); return () => { on = false; }; }, []);
  if (bx.length === 0) return null;
  return <div className="dk-dock">{bx.map((b) => <div key={b.id}>{bx.length > 1 && <p className="mbx-cap dk-for">{b.address}</p>}<DkimPanel box={b.id} /></div>)}</div>;
}
