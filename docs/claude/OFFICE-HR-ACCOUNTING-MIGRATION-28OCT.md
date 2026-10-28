# Office editor + HR + Accounting + 1-click migration — founder hukm 28 Oct 2026 05:13 PKT
Halat: PLAN (code nahi). Founder ka kaam (F1a-F9) is se rukta nahi: "founder mat bhulna" — founder phases pehle chalte hain, yeh product features alag lane mein.

## 1. Docs + Sheets editor — SAB packages mein (Rule 58 ko BADALTA hai)
Founder: log is liye peeche hat-te hain ke online document kaam nahi; Collabora ya OnlyOffice dashboard ke andar; bina extra fee Word/Excel edit => M365 ($14/user) ki wajah khatam. "Docs/Sheets editor yeh sab packages mein dalo."
- **Rule 58 supersede:** purana (Business+ only, apna Rust CRDT) ab sirf **Show (slides)** aur full collaborative-CRDT ke liye bacha; Docs + Sheets editor = **Basic, Pro, Business, Business Pro, Enterprise (+ Personal plans)** sab. Gate Rule 53 ke mutabiq `PACKAGE-FEATURE-FORMULA.md` mein pehle likha jayega, phir code.
- **Technology:** open-source editor engine alag service (alag Linux user, sandbox, sirf localhost) + **WOPI** host Rust (`anexomail-rust`) mein: file Supabase storage se, token short-lived, Bearer plan-gate server par (`resolve_plan`). Editor iframe sirf `docs.anexomail.com` (alag origin, CSP). Files .docx/.xlsx/.odt/.ods/.csv.
- **Engine ka faisla (founder se):** Collabora (CODE/ Online) ya OnlyOffice. SACH: dono ke free/community versions par **connection/document ki had** aur AGPL/licence shartein hain (OnlyOffice Community ~20 simultaneous connections; Collabora free "CODE" production-support nahi deta, commercial subscription hoti hai). Hazaron users ke liye paid/self-host licence ya apna engine lagega — pehle licence + capacity check (G30 jaisa naya-dependency rule: founder ki ijazat).
- Attachment se seedha "Edit online" (AttachmentChip mein tisra option), mail se aayi docx edit karke wapas reply attach.

## 2. HR + Accounting — integrated
Founder: "HR, Accounting sab kuch integrated add karo." Abhi repo mein inka koi code/plan nahi (grep khali). Pehle scope chahiye (sawal neeche). Rakhne ka usool: ek Rust proc family (`hr_*`, `acct_*`), Supabase tables, org-scoped RLS, har amal audit, Rule 52 kernel; payroll/tax country-specific hota hai => pehle ek mulk (UK £ kyunke prices £ mein hain) phir baqi.

## 3. 1-click self-migration — SAB packages mein
Founder: competitor migration ke £568 charge karte hain; ANEXOMAIL mein **automated 1-click, user khud Google/Microsoft se shift kare, free**.
- Jo pehle se hai: Move-In IMAP import (I3-38 MATCHES-CODE, `mig_imap/mig_mime/mig_run`, sab packages Y).
- Jo naya: **Google (Gmail/Calendar/Contacts/Drive) aur Microsoft 365 (Graph: mail/calendar/contacts/OneDrive)** ka OAuth "Connect -> Start" — user ka apna consent, hamare paas token sirf migration tak (phir delete), resume/retry, progress live (WebTransport), dedup, verification report (count match). Google/Microsoft ke app-verification (OAuth review) lagte hain — lamba waqt, abhi se shuru.
- Hamesha user ki ijazat se uska apna data; kisi aur ka nahi.

## 4. Founder se sawal (jawab ke baad hi gate/code)
1. Engine: Collabora ya OnlyOffice — ya licence/capacity dekhne ke baad main sifarish karoon?
2. HR kya kya: employees directory, leave, attendance, payroll, hiring? Accounting kya kya: invoices, expenses, bank feed, VAT, P&L? (pehle chhota — invoices+expenses?)
3. HR/Accounting kis package se shuru (Business+ suggest)?
4. Show (slides) ab bhi Business+ only?
