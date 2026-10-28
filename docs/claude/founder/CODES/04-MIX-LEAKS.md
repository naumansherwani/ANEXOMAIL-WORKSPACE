# 04 MIX — awam mein ghusa founder (alag karna hai, F9 / F1a)
1. src/routes/__root.tsx -> `<FounderBar/>` har awam page par mount. (hatao F9)
2. FounderBar `onFounderHost()`: localhost, *.lovable.app, *.lovableproject.com ko founder host maanta hai.
3. 33 app.founder* routes awam React bundle mein. -> naye founder-web mein.
4. src/lib/host.ts isFounderHost/founderSurfaceAllowed + SiteLock.tsx founder branch. -> founder awam host logic se nikalo.
5. src/lib/auth.tsx session `is_founder` + ExpiryWatch.tsx (awam dashboard par founder patti, `founder.expiry.watch`). -> Systems deck (F5).
6. server/routes/auth.ts: FOUNDER_PASSWORD path, ensureFounderOrg (founder ke liye awam org+mail_account banata hai), founder_accounts upsert. -> F1a.
7. Public (awam) aur founder routes EK hi file mein: revenue.ts (/revenue/lead public), movein.ts (/movein/request,capacity,sweep public), glitch.ts (/glitch/report,trigger,sweep public), storage.ts (/storage/accept,commit,sweep internal). Alag router already hai (founderRouter) — F9 mein founder hissa Rust mein, public wahi rahega.
8. Data mix: founder overview endpoints awam tables (revenue_accounts, mail_outbox, crm_*) seedha admin client se padhte hain; `safe()` fallback khali data deta hai.
9. org.ts/crm.ts: god-view (/founder/org/*, /founder/crm/*) awam org router ke andar.
10. 188 aur files ka "founder" lafz zyada tar isFounder check/comment hai; billing-sync, polar, account-deletion, create-accounts founder_accounts ko chhoo-te hain (data-level, theek, naya audit chahiye).
