# TOP BAR PLAN (his word 22 Nov 2026 11:26 PKT, image of the concept top bar: Search, Quick actions, theme, bell, profile)
His question: which phase does the top bar (Search, Quick actions, Bell and the rest) belong to? His law: the original Anexomail UI/UX stays INTACT; additive only, his haan before any pixel changes.
## Answer: NEW Desk phase T "Top bar", after S1 (rail order) and S2/S5 (Customers, Cases), because Search and Quick actions need real data to search and act on. Today (checked in founder-web/src/desk/DeskShell.tsx) the Desk shell has none of them.
| Item in the concept | Desk decision | Needs first | Advance technology |
|---|---|---|---|
| Search | YES: one box searches cases, customers (opaque company ref), runbooks; typed reason is NOT needed for search, only for opening a company lookup | S2 Customers, S5 Cases, S3 Knowledge | PostgreSQL full text + trigram behind a signed door, Rule 52 kernel-verified results, React 19 |
| Quick actions | YES: a keyboard-first action list (new note, assign to me, open runbook, escalate); each action is an existing signed door, list comes from fadm_action by the person's relation | AD7 queues, D5b, D5c | React 19 + TS, Framer Motion, kernel-verified action list |
| Bell | YES: assignments, SLA warnings, alerts of the glitch rules (AD2 alerts exist) | D2 alerts (exist), AD7 SLA clocks | Server push over WebTransport with the kernel, never a third-party push |
| Theme toggle | YES, colours only, from the D8 eye-comfort palette decision | D8 his pick | CSS design tokens |
| Profile + sign out | exists already in the shell | none | existing |
| Workspace switcher (Northwind Studio) | NO: the Desk is one workspace | none | none |
| Breadcrumb tags "Protected preview", "browser router" | NO: no phase or tech names visible to employees (rule 14) | none | none |
| Orb/"OpsPilot" logo, sidebar group names | NOT copied; the Desk keeps its own Anexomail look and identity | none | none |
Order inside T: T1 Search, T2 Quick actions, T3 Bell, T4 Theme. Every step: backup in backups/desk, before/after check, 390 / 820 / 1200+ look, his haan first.
