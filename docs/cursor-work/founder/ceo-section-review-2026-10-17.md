# CEO review — har section, mobile pehle, viral soch (17 Oct 2026)

Founder ka hukm (17 Oct 04:26 + 04:43): har section dekho (Dashboard, Mail, People, Calendar, Work, CRM, Domains), gaps/loopholes dhoondo, batao competitor se kaise aage nikalna hai, aur "yeh duniya mein viral kaise hoga". Rule 19: mobile + tablet pehle din se.

**Sach ka hisaab:** "Maujood hai" sirf repo ke code (hooks/routes) se likha hai — server par chalta dekha hua nahi (Rule 5: READY/DONE alag). Zoho/Google ke tathya `competitive-baseline-zoho-google-2026-10-17.md` mein official pages se verify hain. Baqi competitors (Gmail, Outlook, Superhuman, HubSpot, Calendly) ke baare mein jo likha hai woh aam jaankari hai, aaj dobara verify nahi kiya — isliye "dekho" ke taur par, faisle se pehle check.

---

## A. Viral kaise hoga (sab se zaroori, tarteeb se)

Email ka viral loop seedha hai: **jo mail bhejta hai, uska har receiver ek nayi aankh hai.** Aur ANEXOMAIL ka asli faida ek line mein: "apne domain par business email, 5 minute mein, aur Gmail se purani mail le aao".

| # | Loop | Kyun kaam karega | Kaun faisla kare | Status |
|---|---|---|---|---|
| V1 | **Bheji hui mail ke neeche chhoti, hatane-wali line** "Sent with ANEXOMAIL — your own-domain email in 5 minutes" (Hotmail ne 1996 mein yahi kiya aur bahut tezi se barha — aam taur par quote hota hai, aaj verify nahi kiya) | Har mail ek ad hai, kharcha zero | **Founder** (brand + users ki mail badalti hai). Meri raay: free/Basic par default ON, paid par OFF (perk) | M8 TODO |
| V2 | **"Meri mail mere domain par — 60 second mein"**: login ke saath hi `naam@anexomail.com` kaam karta hai, DNS ke intezar mein bhi (8h). User ko pehli hi minute mein asli mail bhejna/aana dikhe (8f) | Pehle 60 second mein "wow" na aaye to user chala jata hai | Mera (code) | 8f TODO (agla) |
| V3 | **Gmail/purani mail le aao** (IMAP import, 8j) | #1 wajah ke log switch nahi karte: purani mail chhodna. Yahi sab se bada acquisition hathiyar | Mera, par pehle server fact-finding (13.7) | 8j TODO |
| V4 | **Teammate ko invite — ek tap** (phone par `navigator.share`) + shared inbox | Business mail akeli cheez nahi, team ki hoti hai; har invite ek naya user | Mera | M8 TODO |
| V5 | **Public booking link** (Calendar ki availability se; Calendly jaisa) — receiver ko ANEXOMAIL ka page dikhta hai | Calendar mein availability/focus windows pehle se hain (`useAvailability`, `useFocusWindows`) | Mera, baad mein | naya |
| V6 | **Phone par app jaisa** (install, push) | Roz khulne wali cheez hi phailti hai | Mera; push = Rust backend kaam | M7 READY (iOS hint), push TODO |
| V7 | **Urdu / RTL** — Pakistan ke users ke liye apni zubaan | Header abhi `dir="ltr"` majboor hai; `LanguagePicker` pehle se hai | Mera | M9 TODO |
| V8 | Referral credit | Payment (Polar) no-touch hai; founder tay kare | Founder | idea |

**Meri tajweez:** V2 + V3 pehle (user ko jeet ke dikhao aur nikalna aasaan karo), phir V1 (founder ki haan par), phir V4/V5.

---

## B. Phone / tablet — kya mila, kya baqi (Rule 19)

**Ho chuka (READY, harness 390/820/1440):** M1 dvh + safe-area + viewport, M2 MobileNav (4 tabs + More + workspace switch), M3 compose poori screen, M4 global (16 px input, tap delay, 44 px hit-area), M7 iPhone install hint, M10 `<main>` scroll safety net.

**Baqi (sach):**
- Asli `ComposeStudio` ka andar ka layout phone par (stub se sirf dabba dekha) — M6.
- Asli iPhone par notch/home-bar, keyboard, swipe — sirf asli phone dikhayega; founder ka 30 second ka check.
- People, Calendar, Work, CRM, Billing, Account, Admin ka phone audit — M6.
- Funnel (landing → signup → onboarding → plans → checkout) asli phone par — M5. Static dekha: pages pehle se responsive.

---

## C. Har section

### Dashboard
- **Hai:** greeting, widget grid, analytics, activity, quick actions, upcoming, ab setup checklist (8k) + iPhone hint.
- **Gap:** naya user ko "pehle kya karun" ka seedha jawab chahiye — checklist ne diya, magar "pehli mail" ka qadam abhi bhi DNS verify hone tak bhookha rehta hai (loophole).
- **Aage nikalna:** checklist ka "pehli mail" qadam **login address `@anexomail.com` se pehle din** poora ho sake (8f), DNS ke bina. Google/Zoho yahan user ko admin console par chhor dete hain.
- **Phone:** compact (ho gaya).

### Mail (dil)
- **Hai (code se):** threads, labels, folders, multi-address unified inbox + address chips, snooze/star/move, categories, live updates (WebTransport/poll), swipe archive/snooze, long-press, offline reading, low-data mode, master-detail phone par.
- **Gap:** (1) phone par chhote touch targets (theek kiye); (2) iPhone zoom (theek); (3) IMAP/SMTP settings page nahi — Outlook/phone Mail app wale kaise jurein (8i); (4) catch-all/forwarding/vacation (8m); (5) `mail.send` abhi Bun se jata hai (Rust-first ke khilaf, R1).
- **Aage nikalna:** Superhuman-jaisi rafta + thread par "owner/status/due" (blueprint mein pehle se: "mail is work") — yahi differentiator hai; phone par isay saaf dikhana.

### People
- **Hai:** contacts + companies, list/detail panel.
- **Gap:** import (Google Contacts/CSV/vCard) ka rasta dikhna chahiye — warna naya user khali People dekhta hai. (Code mein import ka suboot nahi dekha — verify.)
- **Aage nikalna:** mail se khud contacts banna + "last spoke" / follow-up reminder.

### Calendar
- **Hai (hooks se):** events, availability, focus windows, team load, tasks, promises, follow-through, notes, meeting banana, `.ics` export ("no lock-in").
- **Gap:** phone par month grid (7 columns) chhota — day/agenda view default hona chahiye phone par; public booking link nahi (V5).
- **Aage nikalna:** "promise engine" (mail mein kiya wada khud calendar/task banta hai) — Google/Zoho ke paas nahi; isko phone par pehli screen par dikhao.

### Work
- **Hai:** list/detail panels, tasks, boards.
- **Gap:** phone par board (columns) — horizontal scroll theek, magar "aaj ka kaam" list pehle dikhni chahiye.
- **Aage nikalna:** mail → task ek tap (pehle se `useTaskAction`/`useDealToWork` jaisi cheezen hain) — phone par swipe se.

### CRM
- **Hai:** overview, leads + AI suggestions, deals pipeline, activities, evidence, approvals, audit, lead→deal convert, deal→work, thread attach.
- **Gap:** pipeline columns `w-72` — phone par horizontal scroll; deal ko phone par stage badalne ka aasaan tareeqa (drag nahi, "Move to…" menu).
- **Aage nikalna:** CRM mail ke andar hi (thread se deal) — HubSpot ko alag tab chahiye. Ye ANEXOMAIL ka asli faida hai.

### Domains
- **Hai (live, READY):** wizard, registrar auto-pehchan, existing-mail guard (8c), "IT wale ko bhejo" (8g), "inbox DNS ke intezar mein bhi chalta hai" (8h).
- **Gap:** 8d (waqt ka andaza), 8e (domain pehle se kisi aur ke paas), 8f (pehli mail ka test), 8l (ek-click DNS, Domain Connect).
- **Aage nikalna:** verify hote hi khud test mail — Zoho/Google yahan khamosh rehte hain.

---

## D. Order (tajweez; Rule 14 ke mutabiq blueprint mein)

1. M5/M6 phone audit baqi hissa (jahan user pehle girta hai).
2. 8f pehli mail ka test (V2) — `useSendMail` se, frontend; `mail.send` Bun se jata hai (R1 mein Rust).
3. 13.7 server fact-finding → 8i (IMAP/SMTP settings) → 8j (import) (V3).
4. R1: `mail.send` + `org.mailboxes.*` Rust par (Tokio); Rust code READY jab tak server par `cargo build --release` green na ho.
5. M8 viral (V1/V4) — founder ki haan par.
6. M9 Urdu/RTL, V5 booking link.

**Founder ke faisle chahiye:** V1 (mail ke neeche line, kis plan par), V8 (referral), 8l (Domain Connect, bahar ka kaam).
