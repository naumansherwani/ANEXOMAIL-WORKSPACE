# AWAM PACKAGES: PROPOSAL + CEO ASSESSMENT (founder 7 Nov 2026 21:51 PKT; written 22:30 PKT); FOUNDER DECISIONS A-G ANSWERED 7 Nov 2026 22:12 PKT (section 6 = FINAL, read it first)
STATUS: DECIDED BUT NOT BUILT (nothing live). Nothing here is live, nothing in code, landing, Polar or prices is touched ("Polar payments, prices, landing = NO TOUCH" stays). Awam side only; the founder lane never reads this. Where a value below differs from a LOCKED founder decision, the locked value wins until he says so (list in section 2).

## 1. The chart he pasted (verbatim values)
| Package | Flat monthly | User cap | Shared storage | Email attachment | ANEXOChat file | Monthly outbound transfer pool |
|---|---|---|---|---|---|---|
| Basic | £40 | 5 | 25 GB | 25 MB | not included | 250 GB |
| Pro | £105 | 20 | 300 GB | 35 MB | not included | 1 TB |
| Business | £360 | 60 | 1.5 TB | 45 MB | 500 MB | 3 TB |
| Business Pro | £2,850 | 570 | 10 TB | 100 MB | 1.5 GB | 28.5 TB |
| Business Premium | £21,000 | 7,000 | 70 TB* | 100 MB | 4 GB | 350 TB |
| Business Max (NEW) | £115,000 | unlimited seats | 250 TB* | 250 MB* | 10 GB* | 500 TB included* |
* Premium and Max storage / transfer / file limits are recommendations, not locked values. Not a public promise until Hetzner egress capacity and cost are verified; beyond the pool only an agreed capacity pack, never an automatic surprise bill. "Unlimited" for Max = unlimited SEATS, never unlimited storage or traffic.
Bandwidth rule: the pool = the whole organisation's monthly OUTBOUND data (attachments, downloads, chat files, calls); uploads and incoming mail are not counted; 70% and 85% alerts to the admin; at 100% big transfers and calls are slowed or paused, basic email and incoming mail keep working; nothing is deleted; no extra charge without admin approval. 50 GB per seat per month is the allowance basis (Max's 500 TB = about 10,000 seats at that rate).
Feature ladder: Basic email+calendar+contacts; Pro + team scheduling, shared calendars, more admin; Business + team chat/file sharing, org admin, pooled transfer; Business Pro + multiple teams, advanced admin/audit, big files; Business Premium + central policies, migration help, priority support; Max + named migration/support, agreed capacity.

## 2. Where the chart DIFFERS from what is already LOCKED in the repo (founder must pick; I do NOT change locked values by myself)
| Item | Pasted chart | Locked in repo (source) | My recommendation |
|---|---|---|---|
| Basic storage / mailboxes | 25 GB | 15 GB shared, 3 mailboxes (founder 26 Oct 05:45 correction, PRICING-POSITIONING-26OCT §7) | keep LOCKED 15 GB until he says otherwise |
| Business Pro email attachment | 100 MB | 60 MB (his words 26 Oct 03:09 "bussiness pro ... 60MB aur 100MB enterprise walon ke liye") | keep LOCKED 60 MB |
| Business Premium user cap | 7,000 | unlimited users on the PRICE page, 21,000 cap in the product (START-HERE §3: Premium cap 21,000) | take 7,000: at 21,000 seats £21,000 is £1 per seat, too thin for support + storage; the arithmetic in the chart (£3 per seat at 7,000) is the safer floor. His call |
| Business Premium storage | 70 TB | 15 TB | take 70 TB: 15 TB over 7,000 seats is only ~2.1 GB each (the chart itself says so) |
| Monthly transfer per user | one pool of 50 GB x seats for every plan | ANEXOChat chart: 50 / 150 / 400 GB per user per month for Business / Business Pro / Business Premium | keep the LOCKED per-user numbers for ANEXOChat files; the pool idea covers email + downloads + calls on top |
| Business Max | £115,000, unlimited seats | does not exist | new tier, his call; keep "unlimited" = seats only |
Business Pro stays NEVER unlimited (570 users) either way.

## 3. How it compares (CEO read; competitor numbers from third-party UK articles, ex-VAT, annual billing: verify on each vendor's own page before ANY public claim)
Competitor per-user prices: Google Workspace Starter £5.90 (30 GB) / Standard £11.50 (2 TB) / Plus £17.25 (5 TB); Microsoft 365 Business Basic £4.60 (1 TB) / Standard £9.60 / Premium £16.90; Proton Workspace (USD) Mail Essentials $6.99 (15 GB) / Standard $12.99 (1 TB) / Premium $19.99 (3 TB). Sources: comparethecloud.net UK GBP article, ifeeltech.com Proton Workspace review.
| Our package at FULL seats | Per seat | Versus Google Starter / M365 Basic (cheapest per-seat plans) |
|---|---|---|
| Basic £40 / 5 | £8.00 | MORE expensive than both (£5.90 / £4.60) |
| Pro £105 / 20 | £5.25 | cheaper than Google Standard £11.50 and M365 Standard £9.60; close to the cheapest plans |
| Business £360 / 60 | £6.00 | about the price of the cheapest plans, with chat + files + admin that they sell higher |
| Business Pro £2,850 / 570 | £5.00 | M365 Basic at 570 seats = £2,622, i.e. we are NOT cheaper than the cheapest Microsoft plan; we win on features and pooled model, not on raw price |
| Business Premium £21,000 / 7,000 | £3.00 | M365 Basic £32,200, Google Starter £41,300: clearly cheaper |
| Business Max £115,000 | unlimited | beyond 7,000 seats we are cheaper the more seats exist (flat) |
Honest strengths: flat organisation price (no per-seat arithmetic), a clear pooled allowance, never an automatic surprise bill, migration help, no "unlimited" lies. Honest weaknesses: (1) Basic costs more per seat than the giants; (2) storage per seat is small (Business 1.5 TB / 60 = 25 GB each; Premium 70 TB / 7,000 = 10 GB) against 1-2 TB per user at Microsoft/Google, so heavy users must be told plainly it is a SHARED pool; (3) Proton's lead is trust, audits and a free plan, not price; (4) Proton's own gaps (no team chat, basic admin, Sheets without pivot tables, no Linux Drive) are our openings.

## 4. What I would ADD so people like Anexomail (all awam lane; each one is already a phase or small)
1. **Import from Google / Microsoft / Proton in one click in every package** (Proton ships Easy Switch; AX-P1/P3). The biggest reason people do NOT switch is moving their mail.
2. **The 48-hour trial stays and ends with an export button** (docs/packages/TRIAL-48H-DESIGN.md): no card, no lock-in.
3. **Price-lock promise** (a price never rises for an existing customer for 3 years) and **cancel anytime + full export**: costs nothing, wins trust that Google/Microsoft lost with price rises.
4. **Pass (passwords + passkeys) and Calendar included in EVERY package** (AX-P4, AX-P2): Proton sells these as the reason to buy; for us they cost little.
5. **Shared-pool meter in the admin screen** with the 70% / 85% alerts, a plain "what happens at 100%" sentence, and "your data is never deleted": the chart's bandwidth rule made visible.
6. **Verifiable security as a feature, not a claim** (AX-P10): post-quantum mail keys, the user can verify the code they were served, hash-chain audit for Business Pro and up.
7. **Uptime SLA + named support from Business Pro up**, migration assistance at Premium, named migration at Max (the chart already lists this; write the numbers when Hetzner capacity is known).
8. **A small free plan or a long trial for individuals** is how Proton fills the top of the funnel; the repo has a PERSONAL-PLANS-REMOVAL plan (2 Nov), so this is a founder decision: do we want any free entry at all.
9. **AnexoSuite (AX-P11, last)**: Word / Excel / Sheets / Docs built in is the answer to "I will keep Microsoft for documents".
10. **Honest public wording**: never "cheapest in the world" until the normalized comparison (same seats, same features, current official pages) is done; "flat price for the whole company" is already a true, strong sentence.

## 5. Decisions needed from him (one line each, he answers with a number or "haan")
A. Premium cap 7,000 (recommended) or 21,000? B. Premium storage 70 TB (recommended) or 15 TB? C. Business Pro attachment 60 MB (locked) or 100 MB? D. Basic storage 15 GB (locked) or 25 GB? E. Add Business Max at £115,000 (seats unlimited, storage/traffic capped)? F. Free entry plan: yes or no? G. Verify Hetzner egress capacity and cost BEFORE any 350-500 TB number is public.
Nothing is edited in code, landing, Polar or plans.ts until he answers and says "go".

## 6. FINAL DECISIONS (founder, 7 Nov 2026 22:12 PKT, his words in quotes). Awam side. Nothing is built or live; Premium + Max are added AFTER the founder lane is finished.
| # | Decision |
|---|---|
| A | Business Premium = **7,000 users, FINAL** ("yeh likha aye ga package card pe"). This REPLACES the old 21,000 cap for Premium. |
| B | Premium storage **70 TB, shared**; "baad main isko zyada karenge jab samajh aye gi" (raise later once capacity is understood). |
| C | Business Pro email attachment **60 MB**; Business Premium **100 MB**; Business Max **£115,000, unlimited seats, 250 TB*, 250 MB*, 10 GB* ANEXOChat file, 500 TB included*** (the * = limits still to be verified, see G). |
| D | Basic (and every other plan) card values stay EXACTLY as they are in the repo and on the server (Basic 15 GB shared, 3 mailboxes, etc.). Nothing changes. |
| E | Business Max £115,000: **YES**, added together with the new Premium values AFTER the founder lane is finished. |
| F | No separate free plan. The **48-hour trial is the only free entry**. |
| G | Hetzner egress capacity + cost verified by me (below). |
Rules he added to the "what I would add" list (all packages unless stated):
1. **One-click import from Google, Microsoft and Proton in EVERY package.**
2. **48-hour trial -> paid = only the package changes; everything else the same; features follow the package.** The trial ends with an export option.
3. **Price lock = 2 YEARS** (not 3), "phir dekhenge"; cancel + full export. Every package gets a **features list shown by the system**; **when a new feature is added the user gets an instant alert in that same place (the features list) and it also shows inside the app on refresh** (a per-package "what's new" feed: SQL table of feature releases per plan + in-app notice; awam lane, to be built).
3b. **Pass and Calendar in EVERY package.**
4. Admin screen: pool meter, 70% / 85% alerts, "your data is never deleted" line: **YES**.
5. Verifiable security (post-quantum mail keys, the user can check which code they were served), uptime SLA + named support from Business Pro up, AnexoSuite last: accepted.
6. Public wording: "flat price for the whole company"; never "cheapest in the world" without the full same-seats comparison.
## G: Hetzner egress, checked 7 Nov 2026 22:30 PKT (docs.hetzner.com/robot/general/traffic, egresscost.com/hetzner)
- Dedicated server with a **1 Gbit uplink: unlimited traffic by default** (the traffic page states no bandwidth limit; its fair-use wording is not on that page: confirm with Hetzner support in writing before relying on it). **10 Gbit uplink: 20 TB per month included, then about EUR 1 per TB**, only OUTGOING traffic counts, calendar months.
- Cloud servers: 20 TB included in the EU, 1 TB in the US, 0.5 TB in Singapore; overage EUR 1 per TB.
- **Cost is NOT the problem; capacity is.** A 1 Gbit link running flat out for a month moves about 324 TB (1 Gbit/s x 2.59 million s), so Premium's 350 TB pool and Max's 500 TB pool cannot be carried by one 1 Gbit server even at 100% use. Real traffic peaks, so plan 10 Gbit uplinks or several servers. On a 10 Gbit uplink 500 TB costs about EUR 480 of overage (500 - 20 = 480 TB x EUR 1) and 350 TB about EUR 330: small against £21,000 / £115,000.
- Rule stays: 350-500 TB figures are NOT a public promise until Hetzner confirms the uplink and fair-use in writing for the chosen server; beyond the pool = an agreed capacity pack, never an automatic bill.
