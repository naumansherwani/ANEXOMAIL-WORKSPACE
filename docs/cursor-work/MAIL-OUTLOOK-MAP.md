# ANEXOMAIL MAIL — Outlook ka UI dekh kar ORIGINAL feature map (founder hukm 22 Oct 07:47) — PROPOSAL, code nahi
Outlook (outlook.live.com) live dekha: left app-rail (Mail, Calendar, People, To Do, Word/Excel/PowerPoint, Apps); ribbon tabs Home/View/Help;
folder pane (Favourites + account folders: Inbox, Junk, Drafts, Sent, Deleted, Archive, Conversation History, Notes, Groups); message list (Focused|Other, sort, filter);
reading pane; Settings = Account / General / Email / Calendar / People; Email settings: Message list, Reading pane, Folder pane, Compose, Smart suggestions, Attachments,
Rules, Conditional formatting, Sweep, Junk email, Customise actions, Message handling, Forwarding and IMAP, Subscriptions. View: Messages, Expand conversation, Zoom, Sync, Layout, Folder pane, Density, Immersive reader.
Ribbon Home: New email, Delete, Archive, Move to, Report junk/phishing, Reply all, Mark all read, Flag, Undo (+ "..." Sweep/Pin/Snooze/Categorise).

## Rules jo is map par lagte hain
Rule 37 universal UI (har package ko ek hi screen) · Rule 40 (family/lifetime = UNLIMITED, real-buyer jaisi nazar; sirf PAID packages gated; capability plan-surface.ts se, tier literal nahi) · plans.ts locked cards/prices TOUCH NAHI (sirf unki features ke andar rehna) · privacy (mail content kabhi training/analytics mein nahi) · Bun fallback rehta hai.

## Placement (hamari original tarteeb, copy nahi)
| Jagah | Outlook | ANEXOMAIL |
|---|---|---|
| Rail (left, narrow) | Mail/Calendar/People/To Do/Office | Dashboard · Mail · People · Calendar · Work · CRM · Domains (BANA) |
| Folder pane | Favourites + folders | MailRail: folders + labels + accounts (BANA). Add: Favourites (pin folder/label), Archive, Snoozed, Scheduled, Notes? (Work mein) |
| List | Focused/Other, filter, sort | ThreadList (BANA). Add: Focused/Other toggle (AI-free rule-based, default OFF), filter chips (Unread/Flagged/Attach/Mentions), sort |
| Reading | pane, conversation | Thread page + ThreadInsights/Discuss in chat (BANA) — ANEXOMAIL ki khaas cheez |
| Compose | rich editor, undo send | InlineReply + compose (BANA: undo send 30s B3) |
| Ribbon actions | Delete/Archive/Move/Flag/Sweep | ThreadHeaderActions (BANA). Add: Move to, Flag, Pin, Sweep |
| Settings | Email/Calendar/People | /app/settings/* (BANA: ai, appearance, health, history, notifications, privacy, workspace). Add: Mail (rules, signature, forwarding/IMAP, layout) |

## Feature -> package (Basic £23 / Pro £46 / Business £97 / Business Pro £2850; family+lifetime = sab UNLIMITED)
| Feature | Haal | Basic | Pro | Business | B.Pro |
|---|---|---|---|---|---|
| Inbox/Sent/Drafts/Archive/Trash/Spam, labels, search, Cmd+K | BANA | ✔ | ✔ | ✔ | ✔ |
| Undo send 30 s | BANA (B3) | ✔ | ✔ | ✔ | ✔ |
| Aliases, contacts, calendar | BANA | ✔ | ✔ | ✔ | ✔ |
| Reading pane layout / density / text size / zoom (Outlook View) | baaki | ✔ | ✔ | ✔ | ✔ |
| Favourites folders, flag, pin, Move to, mark all read, filter chips | baaki | ✔ | ✔ | ✔ | ✔ |
| Signature, auto-reply (out-of-office mail) | baaki | ✔ | ✔ | ✔ | ✔ |
| Forwarding + IMAP/POP access | baaki | ✔ | ✔ | ✔ | ✔ |
| Snooze + schedule send | BANA (snooze), schedule baaki | — | ✔ | ✔ | ✔ |
| Email templates (quick parts) | baaki | — | ✔ | ✔ | ✔ |
| Rules (auto-move/label/forward) + Sweep | baaki | basic 3 rules | unlimited | unlimited+shared | ✔ |
| Shared inbox + collision guard | BANA | — | ✔ | ✔ | ✔ |
| Boards, notes, tasks, thread analytics | BANA | — | ✔ | ✔ | ✔ |
| Focused/Other, conditional formatting, categories (colour tags) | baaki | — | ✔ | ✔ | ✔ |
| Roles/departments, policies, audit ledger, access revoke, export | BANA | — | — | ✔ | ✔ |
| Shared rules/templates for whole org, delegate access | baaki | — | — | ✔ | ✔ |
| Immersive reader / read-aloud, translate | baaki | ✔ | ✔ | ✔ | ✔ |
Gating sirf plans.ts ke locked feature words ke mutabiq; naye feature "capability" key se (plan-surface.ts), family = hamesha ON.

## Build order (tarteeb, har ek: SQL -> Rust -> Web, sandbox + 390/820/1440 + founder output = GREEN)
M1 View/layout settings (density, reading pane right/bottom/off, zoom, folder pane collapse) — sirf web, sab packages
M2 Favourites + Move to + Flag/Pin + filter chips + mark-all-read
M3 Signature + auto-reply (out-of-office mail) + Forwarding/IMAP page
M4 Rules + Sweep (Rust engine; Basic 3, Pro+ unlimited)
M5 Schedule send (Pro+) + Templates (Pro+)
M6 Focused/Other + categories + conditional formatting (Pro+)
M7 Shared/delegate access (Business+)
Roadmap order me iske BAAD: calendar #4 (world-clock/team overlay/ICS), G16 portal P2.

## Founder faisle chahiye
1) Rules limit Basic mein 3 ya koi nahi?  2) Focused/Other pehle version mein ya baad?  3) Pehle M1 se shuru (sirf web, risk zero)?
