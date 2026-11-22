# RUNBOOK LIBRARY, FIRST DRAFT BY CLAUDE (his word 22 Nov 2026 10:42 PKT: "promises miscommitment hai, woh nahi hoga" and "suspension reason classes tum khud banao, advance level pe")
Written 22 Nov 2026 10:43 PKT. Status: DRAFT for his approval (approval owner = the Chairman). Employee-facing words only: no phase names, no money, no webhook names. Rule 52 applies to every screen that shows these.

## A. THE NO-PROMISE LAW (his word, written as a rule the gate enforces)
The employee NEVER promises. Not a date, not a restore time, not a refund, credit, discount or free month, not an upgrade, not the outcome of an owner decision, not "it will be fixed". The employee states FACTS FROM THE SCREEN, what was done, the case number, and which clock applies (the SLA target is a target to answer, not a promise to fix).
Allowed sentence shapes: "I can see ...", "I have passed this to ... , your reference is ...", "The next update is due by ... (the target for this plan)", "I cannot give a restore time."
Banned in any runbook "say this" text (gate, D5b-3): promise, guarantee, definitely, for sure, 100 percent, will be fixed, will be restored, refund, credit, compensation, discount, free, within N hours / minutes (unless the number is read from the plan's SLA target and the sentence says "target"), "I will make sure". The commit gate fails a runbook that contains one. A runbook also shows a fixed line in part 3: "Never promise a date, a refund, a credit, an upgrade or an owner decision."

## B. SUSPENSION REASON CLASSES (my design, advance level; the employee only SEES the class, never sets it)
Who sets a class: the Control Plane or the owner, never the employee. The Desk shows class code + label + since when + case reference. The employee can never suspend, restore, or change a class.
| Code | Class | What the employee may say (facts only) | Escalate to |
|---|---|---|---|
| SR1 | Payment matter | "The account is on hold for a billing matter. I cannot see amounts. I have passed it to the team that handles billing, reference N." | owner case (billing side) |
| SR2 | Abuse or policy breach | "The account is on hold under our usage policy. The details are handled by the abuse team. Reference N." | abuse team case |
| SR3 | Security hold | "The account is on hold to protect it after unusual activity. Reference N. I cannot give details or a restore time." Never reveal what triggered it | security case, priority raised |
| SR4 | Legal or compliance hold | "The account is on hold. I am not able to discuss the reason. Reference N." No details, no guessing | owner case only |
| SR5 | Customer's own request | "The account is paused at the request of your company administrator." Restore only by the customer's own administrator through the owner route | owner case if the admin cannot be reached |
| SR6 | Verification pending | "We are waiting for the domain or identity check to be completed." Employee may show which check is pending | support lead |
| SR7 | Fair-use limit | "The account reached a usage limit for its package." Employee explains usage from the screen; no promise of a raise | owner case |
| SR8 | Under review | "The account is under review. Reference N." No reason given | owner case |
Every class has: allowed statement, forbidden statement ("never say why in detail unless the class sheet says so"), escalation target, who may lift it (always not the employee), and an audit line when someone views it. A new class needs the Chairman's approval and a new registry version.

## C. THE NINE RUNBOOKS (each has exactly six parts; part 3 always carries the no-promise line)
Format per runbook: 1 sees / 2 may / 3 never / 4 escalate / 5 say / 6 clock. SLA target numbers come from the plan registry, never typed here.

R1 Payment received, service not active
1 sees: service state, the ONE flag "payment received, service not active" + since when, package and version, freshness time
2 may: confirm the flag, open an owner case with the audit reference, tell the customer a case exists
3 never: ask for or look at amounts, card, invoice; touch the money side; promise a time; (no-promise line)
4 escalate: owner case, priority high if the flag is older than the plan's target
5 say: "I can see your payment has been received and your service is not active yet. I have opened case N with the team that can fix this. I cannot give a restore time."
6 clock: the plan's first-answer target (a target to reply, not a promise to fix)

R2 Features missing
1 sees: package and version, features included, features actually enabled, the difference
2 may: explain the difference, check the version date, open a case if included features are off
3 never: enable or disable anything, say a feature will be added, (no-promise line)
4 escalate: support lead if the package says included but it is off
5 say: "Your package includes X. I can see it is currently off for your account. I have opened case N."
6 clock: plan target

R3 Storage or seats limit reached
1 sees: usage against the limit, the 90 and 95 percent marks, package limit
2 may: explain what is using space or seats from the usage metadata, point to the owner's upgrade route
3 never: sell, quote, promise an upgrade or a raise, (no-promise line)
4 escalate: owner case if the customer asks for a change
5 say: "You are at N percent of your limit. Changes to limits are handled by the owner. I have passed your request, reference N."
6 clock: plan target

R4 Grace period
1 sees: service state "Grace period", days left (from the registry), package
2 may: explain the state in plain words, open a case if the customer disagrees
3 never: extend, shorten, or promise an extension, (no-promise line)
4 escalate: owner case for any extension request
5 say: "Your account is in a grace period. The date it ends is on your account page. Any change to that is decided by the owner. Reference N."
6 clock: plan target

R5 Account suspended
1 sees: state "Suspended", reason class code (section B), since when
2 may: read the class sheet statement, open the escalation named in the class
3 never: say more than the class sheet allows, guess a reason, restore, promise, (no-promise line)
4 escalate: as per the class table
5 say: the class sentence from section B
6 clock: plan target; SR3 and SR4 run at raised priority

R6 Cannot sign in
1 sees: account state, whether recovery is pending or done (never a code or secret), last sign-in time, device count
2 may: tell the customer the recovery steps from their own page, confirm that recovery is pending
3 never: ask for a password or code, reset a secret, bypass a check, (no-promise line)
4 escalate: security case if signs of takeover
5 say: "I can see the account is active. Please use the recovery option on the sign-in page. I will not ask for your password or any code."
6 clock: plan target, raised if suspected takeover

R7 Email not delivered
1 sees: domain checks (MX, SPF, DKIM, DMARC state), queue state, last delivery results, never message content
2 may: explain which check fails and what the customer's administrator must change
3 never: read message content, send on the customer's behalf, promise delivery, (no-promise line)
4 escalate: support lead if our side is the cause; incident if many customers show it
5 say: "Your domain check for X shows Y. Your administrator needs to change Z."
6 clock: plan target

R8 Attachment blocked
1 sees: scan state (clean, infected, scan pending, too large), size against the package limit
2 may: explain the reason in plain words
3 never: release or open the file, promise it will be released, (no-promise line)
4 escalate: security case if the scan result is disputed
5 say: "The file was held because the scan says X. I cannot open or release it."
6 clock: plan target

R9 Multiple customers affected (first cut)
1 sees: several cases from different companies about the same symptom, service health card
2 may: link the cases to one incident, post the status note the incident lead approved
3 never: tell customers a cause or an end time that is not in the approved note, (no-promise line)
4 escalate: incident manager immediately
5 say: the approved status note only
6 clock: incident clock; full handling in the incident section

## D. WHAT HAPPENS WITH THIS FILE
Part of D5b-1: each runbook becomes versioned data with the Chairman as approval owner; the no-promise words list becomes a commit gate in D5b-3; the suspension classes become registry rows in D5a-2. Until he approves, the Desk shows these as "Draft, not approved yet" to leads only.
