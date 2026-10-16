# ANEXOMAIL — Cinematic UI standard (locked 17 Oct 2026, founder ki maang)

Founder ka sawal: "cinematic / cinema feel UI kya hota hai?" Jawab: **screen ko film ke frame ki tarah banana — jahan har cheez ka ek maqsad ho, ek roshni ho, aur jo cheez dikhaye woh sirf ek ho.** Yeh sajawat nahi, nizam hai. Yeh qaide `src/styles.css` mein pehle se likhe hain; yeh file unhein har screen par laagu karne ka maiyaar hai.

## Aath qaide (src/styles.css se, aam zubaan mein)

| # | Qaida | Matlab | Kaise dikhta hai |
|---|---|---|---|
| 1 | **Ek roshni** | Poori screen par ek hi light source (upar, halka neela). Kahin aur se chamak nahi. | `ax-keylight` page ke upar; kartein andhere mein ubharti hain |
| 2 | **Teen gehrai ki tahein** | Stage (peeche) → plane (card) → raised (menu/toast). Har tah ka apna saya. | `ax-plane`, `shadow-elev-*` |
| 3 | **Reveal, slide nahi** | Cheez dheere "zaahir" hoti hai (opacity + 8px), idhar-udhar nahi udti. | `ax-in`, `ax-stagger` (45 ms ke fasle par) |
| 4 | **Pacing** | Do rafta: tez (tap/press) aur "calm" (380 ms). Beech ki cheez nahi. | `ax-press`, `ax-tap` |
| 5 | **Type = camera** | Sirf chhe naap: display, title, heading, body, label, caption. Satvan banana mana. | `ax-title`… |
| 6 | **Roshni ka zaviya** | Hover par card thoda uthta hai aur kinara chamakta hai, jaise roshni us par pari. | `ax-lift` |
| 7 | **Grain + vignette** | Halka dana aur kinaron par andhera — screen "chhapi hui" nahi, "filmayi hui" lage. | `ax-grain`, `ax-vignette` |
| 8 | **Khamoshi** | Kaam hone par ek dafa halka sa nabz (confirm), phir bilkul sakoon. Har waqt ghoomti cheezein nahi. | `ax-confirm`, `ax-celebrate`; `ax-breathe` sirf "intezar" ke liye |

`prefers-reduced-motion` global handle hai: harkat band, mazmoon wahi.

## "Vercel se aage" ka asli matlab (haqeeqat)

Vercel/Linear jaisi screens achhi hain kyunke saaf, tez aur khamosh hain. Hum us se aage isliye jaa sakte hain kyunke ANEXOMAIL ki screen par **nateeja** dikhaya ja sakta hai (aap ka apna address "From" mein), jo generic dashboard nahi dikha sakta. "Duniya ka best" ka koi napne wala number nahi hota; asli maiyaar yeh checklist hai:

1. Pehle 5 second mein user ko pata chale: yeh kya hai, ab ek kaam kya hai. (Ek hi bara button.)
2. Khali state "kuch nahi" nahi dikhata — nateeja dikhata hai (preview) aur agla qadam.
3. Loading par text nahi, wahi shakal jo aane wali hai (`ax-shimmer` skeleton).
4. Har intezar ka ek zinda nishaan hai (ginti, nabz) — user ko "kya hua?" nahi poochna parta.
5. Har kaam hone par ek dafa halka jashn, phir khamoshi.
6. Galat/error: seedhi insani zubaan, ek hi `ax-shake`, "dobara koshish" ka button.
7. 390 px phone par bhi wahi tajurba; keyboard/screen reader ke liye `aria-*`, `role=status/alert`.
8. Type sirf chhe naap mein; rang sirf tokens se (`--primary`, `--cyan-accent`, success/warning/danger).

## Kaise verify hota hai (sandbox mein, server par nahi)

`docs/cursor-work/frontend/ui-harness/` asli `src/styles.css` + asli page code ko Tailwind 4 se compile karke Chromium mein screenshot leta hai. Is se rang, spacing, layout, loading skeleton, 390 px aur har state (khali / list / wizard 1–3 / verified / error) dekhi jati hai. **Yeh asli server nahi hai:** data nakli (stubs) hai, aur founder ka browser/screen/zoom alag ho sakta hai. Isliye status **READY** rehta hai jab tak founder asli browser mein na dekh le (Rule 5).

## Poori website ka rasta (founder ka "once for all")

Founder ka maqsad: **ek business user pehle din business email bana le.** Is liye screens us user ke safar ki tarteeb mein banti/theek hoti hain, har ek harness screenshot se pehle, phir founder ki aankh se:

| # | Screen | Safar mein kya | Cinematic status |
|---|---|---|---|
| 1 | Landing / Signup (`/`, `/auth`) | Domain batana, plan, payment | TODO (audit baqi) |
| 2 | Dashboard (`/app`) | "Finish setup" → Domains | TODO (Greeting `ax-display` hai; baqi kartein audit) |
| 3 | **Domains & addresses** (`/app/domains`) | Domain jodna, 5 DNS records, address banana | **READY** (17 Oct, harness verified; founder ka browser dekhna baqi) |
| 4 | Compose (`From: you@company`) | Pehli mail bhejna | TODO (#7 proof baqi) |
| 5 | Inbox / Mail | Aane wali mail, address label | TODO |
| 6 | People, Calendar, Work, CRM | Roz ka kaam | TODO |
| 7 | Settings / Org / Billing | Team, plan, upgrade | TODO |

Tarteeb Rule 14 ke saath chalti hai: founder jo screen kamzor bataye wahi pehle. Har screen ka kaam: harness stub → screenshots (desktop + 390 px) → theek → sha-guarded single-file block (pm2 restart + save) → founder ka asli screenshot → tab hi DONE.

## Zaroori note (founder ka, 17 Oct 2026)

`axonetis.com` founder ka **doosra project** hai; uske subdomains (`probuyer.axonetis.com` …) sirf **test domain** hain. ANEXOMAIL domain bechta nahi: product ka maqsad hai ke user **apne** domain par business email kaise banaye. Isliye Domains wizard hamesha "aap ka apna domain, apne registrar par DNS" ke tareeqe par rehta hai.
