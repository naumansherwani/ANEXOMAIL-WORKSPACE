CRM THE LOOP - 9 steps, each with its OWN question, logic and data (LOCKED by owner)
Problem being fixed: Timeline, Promises, Risk, Graph and Next all link to the same Overview
page, and /crm/live is one handler that builds all of them. Each step must have its own
separate logic, and the steps must be connected to each other.
Do not change this table without the owner saying so.

Format: step | user's question | what must be shown | data source

1 Capture   | Naya kaun aaya?                    | Queue of people who emailed but are not on the book, with Accept / Not a lead | mail, crm_leads (already built)
2 Memory    | Ye banda kaun hai?                 | One person's full profile: notes, phone/title, other emails | contacts (already built)
3 Timeline  | Kya hua?                           | All activity of all people by time, filter by person or type | mail, meetings, tasks, deals
4 Promises  | Maine kya wada kiya, unhone kya?   | Promises with due date, kept / late / broken, plus "kept" or "change date" button | work_promises
5 Health    | Kis rishte ko dhyan chahiye?       | People ranked: Active, Cooling, Cold, and days since last contact | contact_stats
6 Risk      | Kya bigad sakta hai?               | Only dangers: overdue promise, thread waiting for a reply, big deal with a cold contact. Each with its reason | promises + health + deals
7 Evidence  | Kisne kya aur kyun kiya?           | Record of decisions | audit ledger (already built)
8 Graph     | Kaun kis se judha hai?             | Who is inside a company, which deals, which of my teammates talked to whom | contacts + deals + mail
9 Next      | Aaj kya karun?                     | One ranked list built from steps 4, 5, 6. Every item says which step it came from | only results of other steps, no data of its own

CONNECTION RULE: every item links to another step. Overdue promise in Risk opens Promises.
A Timeline entry opens that person's Memory profile (/app/crm/relationships?email=...).
Every Next item says where it came from.

HOW WE BUILD: one step at a time, order 3,4,5,6,8,9 (1,2,7 exist). Each step is verified
before the next starts. Applies to every plan except Basic (same gate as showCrm).
- Live /api routes: /opt/anexomail/src/routes/*.ts, then pm2 restart anexomail-leo
- New backend procedures: Rust (/opt/anexomail-rust), cargo build, pm2 restart anexomail-rust
- Frontend: /opt/anexomail-web, bun run build:bun, pm2 restart anexomail-web
- Never run write-tests on Humza or Masood accounts. The owner tests in the browser.
- Never write "verified" in docs until the result has been seen.
