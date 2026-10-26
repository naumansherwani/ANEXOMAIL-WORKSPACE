# Trial data — real data se mix NAHI
- Trial ka apna `organisations` row `kind='trial'` (SQL: kind check mein 'trial' jodna). Sab queries jo company-wide ginti karti hain (storage pool, analytics, CRM stats, org.members count, billing seats, revenue/lead metrics, search) `kind <> 'trial'` ya trial-aware views.
- Trial ke mail/chat/calendar tables wohi (alag tables nahi — code duplicate nahi), lekin `org_id` trial org ka; RLS/Rust guard: trial user kabhi non-trial org nahi dekh sakta, non-trial kabhi trial org nahi.
- Founder dashboards (revenue, leads, signups) trial ko alag line dikhate hain ("Trials: n"), paid revenue mein nahi.
- Convert (paisa de diya): user choice **Keep my trial data** -> ek transaction mein org kind trial -> paid, plan entitlement lagti hai, caps badalte hain; ya **Start fresh** -> naya paid workspace, trial org frozen.
- Na khareeda: mailbox frozen, address 30 din reserved, incoming mail hold (kabhi silently discard nahi), data export khula. 30 din baad address free.
- Test: probe jo trial user aur paid user banata hai aur check karta hai ke kisi ek ke counters mein doosre ka data nahi.
