# Founder Decisions — Founder OS ↔ Command Center OS Bridge

Teeno decisions meri taraf se yeh hain. Inhein architecture contract mein lock karo.

## 1. Founder ko Desk ke kaun se numbers dikhen?

Founder ko Command Center OS ki operational health ka consolidated dashboard chahiye.

Yeh numbers dikhao:

**Employee Operations**
- Total employees
- Active employees
- Frozen employees
- Pending invitations
- Employees currently online

**Company Operations**
- Total companies
- Active companies
- Suspended/frozen companies
- Companies onboarding
- Companies experiencing service problems

**Customer Support**
- Total open cases
- Urgent cases
- Unassigned cases
- SLA at-risk cases
- SLA-breached cases
- Average first response time
- Average resolution time

**System Operations**
- Active incidents
- Affected companies
- Mail, Chat, Files, Authentication and Storage health
- Critical service alerts

**Security Overview**
- Failed access attempts
- Privileged employee changes
- Employee freeze/unfreeze actions
- Founder command activity
- Break-glass access events

Yeh operational numbers honge. Founder OS par financial figures, revenue, invoices, transaction amounts ya payment records expose nahi honge. Woh exclusively Founder Desk ke paas rahenge.

Har metric ke saath last-updated timestamp, data freshness aur source status dikhana mandatory hai. Stale data ko live data represent nahi karna.

**Important architecture distinction:** Founder → Command Center command bridge one-way rahega. Founder dashboard ke aggregate operational numbers ke liye separate, read-only, signed telemetry feed ho sakti hai. Is feed se koi command execute nahi ho sakta aur Command Center ko Founder OS ka data access nahi milega.

## 2. Founder customer khol kar dekh sakta hai ya sirf counts?

Mera decision: **Counts by default, controlled case-level access when necessary.**

Founder ko har customer ki private information browse karne ki zaroorat nahi.

Lekin exceptional situations mein Founder ko specific customer support case dekhne ka authorised option hona chahiye.

Rules:

- Founder normal dashboard par aggregate counts dekhega.
- Specific customer access sirf relevant support case ya escalation ke through hoga.
- Access reason-bound, time-limited, read-only aur fully audited hoga.
- Customer record Command Center OS mein hi rahega.
- Customer records ki copy Founder OS mein nahi banegi.
- Mail content, private chat content, attachments aur private customer files default se accessible nahi honge.
- Exceptional sensitive-content access ke liye separate explicit approval aur audit required hoga.

Founder case ko Command Center OS ke apne secure case viewer mein open kar sake. Signed bridge sirf scoped access grant/command dega; customer database expose nahi karega.

## 3. Desk, Founder ka kya dekhta hai?

**Command Center OS ko Founder OS ke internal data ka zero visibility access hoga.**

Desk ko sirf command verify aur execute karne ke liye minimum metadata mile:

- Founder ka authorised public identity/reference.
- Command ID.
- Command type.
- Target employee/company/ticket.
- Command issue time and expiry.
- Authorised scope.
- Reason for command.
- Ed25519 signature verification result.
- Fresh passkey approval result, where required.
- Execution status and audit reference.

Desk ko yeh cheezein kabhi nahi milengi:

- Founder OS database records.
- Financial records or transactions.
- Founder personal data.
- Internal founder notes and documents.
- Private signing keys.
- Passkey private credentials or biometric information.
- Founder sessions, tokens or unrelated permissions.

Desk sirf yeh verify karega ke command authorised Founder se aayi hai aur allowed scope mein hai.

## Command Security Conditions

Existing Rule 52 aur Ed25519 + QUIC architecture preserve karo.

Fresh passkey touch mandatory ho for:
- Company freeze/unfreeze.
- Privileged employee freeze/unfreeze.
- Privileged employee creation.
- High-impact emergency interventions.
- Bulk or destructive operations.

Every command must have:
- Unique command ID and nonce.
- Strict expiry.
- Replay protection.
- Target and scope validation.
- Idempotent execution.
- Signed execution acknowledgement.
- Immutable audit record.

Normal urgent-ticket creation ko unnecessary passkey friction se block mat karo. Us par normal Founder signature and command authorization sufficient hai.

## Isolation Law — Non-negotiable

Founder OS and Command Center OS retain:

- Separate binaries.
- Separate databases and tables.
- Separate signing keys.
- Separate authorization systems.
- Separate audit records.

Command Center OS cannot read Founder OS data or issue commands into Founder OS.

Founder OS can send only explicitly permitted signed commands. Aggregate telemetry is a separate read-only channel and cannot execute commands.

No shared database, no shared private keys, no direct cross-database access.

## Implementation Order

Existing requested order preserve karo:

1. BL-46 B13
2. BL-49 B11
3. BL-48 B12
4. B6c
5. 1n
6. 1o
7. 1a
8. Security hardening
9. OS-11 Employee Lifecycle — absolutely last.

Har phase separately implement, test and verify karo. Existing functionality, phase boundaries, tables, binaries aur governance rules ko bina approval modify mat karna.

**Final principle: Founder has operational visibility and ultimate authorised control. Command Center OS independently operates its employees, companies and customer support. Neither system gains access to the other's private data or authority.**