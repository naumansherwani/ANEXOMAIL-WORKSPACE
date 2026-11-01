# CHAIRMAN MAP — kaun si cheez kahan dikhegi (founder 1 Nov 07:33: "bridge mein kya aye ga, dashboard pe kya aye ga clear rakho; mere samne her cheez ho"; user-side UI/UX same-to-same)
Checked LIVE in founder Chrome 07:34 PKT (not from memory). Master docs: FOUNDER-BRIDGE-VS-DASHBOARD-28OCT.md (split rule), FOUNDER-PARITY-30OCT.md (user->founder deck table), FOUNDER-UI-DESIGN-28OCT.md (tokens).

## 1. Teen jagah, teen kaam (ek cheez = ek ghar; baqi jagah sirf link)
| Jagah | Sawal jo jawab deti hai | Qaida |
|---|---|---|
| **Dashboard** (abhi "Systems health": 13 cards, 10 of 10 endpoints) | "Company aur system kaisa hai?" (noun/trend, read-only) | har feature ka EK card: chip + ek line + click = us deck mein |
| **Bridge** | "Mujh se ABHI kya chahiye?" (verb, action) | sirf EXCEPTION/queue: late jawab, critical issue, failed payment; khali ho to "Nothing needs attention" |
| **Deck pages** (Finance, People, Mail Desk, AI, Release, Move-In, Systems, Control, Audit, **Inbox**) | poori tafseel + kaam | chairman ko jo bhi dekhna ho, yahan; Dashboard card + Bridge exception dono yahan ka darwaza |
Chairman ko "sab kuch dikhe": har deck ka ek Dashboard card zaroor (kuch na ho to "Ready"/"Waiting for first data" saaf wajah ke saath, kabhi nakli number nahi).

## 2. ABHI (live) kya kahan hai
**Dashboard (13 cards):** Signed answers, Approved device, Audit ledger, Billing, Revenue records, Customers, Host separation, Live feed, Channels, Stream health, **Inbox** (naya), Action registry, Settings + "Recent changes".
**Bridge:** Arriving (New leads, Polar events, New subscriptions) · Leaving (Mail failed, Webhook errors, Rejected signatures) · Needs attention (Mail Outbox, Expiry Watch) · Polar webhook detail.
**Sidebar abhi:** Dashboard, Bridge, Finance, People, Mail Desk, AI, Release, Move-In, Systems, Control, Audit ledger + group "Workspace (user app)" (User dashboard, Mail, People, Calendar, Work, CRM, Org, Analytics, Safety, ANEXOChat, AI, Speed, Founder, Admin).

## 3. Naye features ka ghar (Inbox / Channels / Stream health)
| Feature | Dashboard | Bridge | Deck page |
|---|---|---|---|
| Inbox (Glitch+Support) | card "Inbox": open issues, new, reasons (HAZIR) | sirf exception: critical khula, jawab ki der, SLA breach (P2) | naya **Inbox** page: list/filter/detail/status buttons (P2) |
| Channels | card "Channels" (HAZIR) | channel degraded ho to row | Inbox page ke upar channel strip (P2) |
| Stream health | card (HAZIR) | fail par row | Systems (F6) |
| Company Mail | card "Channels" mein | — | Mail Desk (step 11) |
Sidebar mein "Inbox" naya item Bridge ke baad (P2). FOUNDER KA FAISLA CHAHIYE: sidebar naam "Inbox" theek?

## 4. User-side UI/UX features -> founder parity (same UX, latest technology, DATA KABHI MIX NAHI)
Qaida (FC18/FC22): founder ke apne component/endpoint/table; user ki React files import nahi hoti; token, host, table alag. UX wohi: tarteeb, naam, shortcuts, behaviour.
| User shell / UX feature (src/components/app) | Founder mein abhi | Gap | Step |
|---|---|---|---|
| AppShell (sidebar, rail, bottom bar) | HAI (236 px sidebar, 64 px rail, floating bottom bar) | — | done |
| CommandPalette (Ctrl+K) | HAI (Palette.tsx) | "acts" version N8 | 13 |
| MobileNav | HAI (Home/Bridge/Finance/People/More) | — | done |
| PullRefresh | NAHI | refresh target (F5 leftover) | UI polish |
| ZoomButtons + Text size | NAHI | Settings->Appearance text size | S2 (6) |
| TouchScrollbar / HScroll | NAHI | phone scrollbar/table scroll | UI polish |
| ConfirmButton | PARTIAL (Decks reason sheet) | shared component | 8 |
| WorkspaceLoader (splash) | HAI (splash) | — | done |
| ComposeOverlay (mail compose) | NAHI | Mail Desk | 11 |
| FeatureGate / PlanSurfaceGate | n/a (founder ke gates G1/G2/G3) | — | — |
| CrossPlatformBar | NAHI | founder cross-device (N9 PWA) | 7 |
| i18n | NAHI (English only, Rule 67) | — | — |
| Feature areas: ai, analytics, billing, calendar, chat, compose, crm, dashboard, files, mail, migrate, org, people, premium, release, safety, search, security, settings, trial, work | Dashboard, Settings (2 tabs), Profile hain; baqi decks | FOUNDER-PARITY-30OCT.md table (92 user files -> decks) | 6-13 |
Tarteeb: FOUNDER-MASTER-AUDIT-01NOV.md (4d Inbox -> 5 Merkle -> 6 S2 -> 7 passkey -> 8 Decide -> 9 Finance -> 10 People -> 11 Mail Desk -> 12 Systems -> 13 Control).

## 5. Live mein mili ek asli kami (L8)
Stream health card 07:34 par "Down: 75% of streams closed within 20 seconds". Wajah asli hai: aaj mein ne baar-baar page reload kiya (har reload = chhota session). SLO ka qaida kamzor hai: bohat kam sessions par percentage bhi "fail" ho jata hai. FIX (P2 ke SQL E113 mein): kam az kam 20 band sessions ka sample, warna "Collecting"; aur reload (client_gone) ko reconnect-storm mein na ginna jab tak lagataar na ho. Tab tak card laal rahe ga (jhoot nahi, par gumrah-kun).
