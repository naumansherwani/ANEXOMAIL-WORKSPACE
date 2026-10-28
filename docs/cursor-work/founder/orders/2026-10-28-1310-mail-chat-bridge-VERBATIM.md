# Founder order 28 Oct 2026 13:10 PKT — Email <-> Chat Bridge (verbatim paste, tarteeb se blueprint mein add; "yeh bhi hoga")

Unified Ledger Threading (Deterministic Context Map)
* Feature: Jab ek email thread chal rahi ho, toh workspace ke andar ek single click se usi thread ke niche ek Dedicated Secure Chat Room khul jaye. Us chat mein jo bhi files, voice notes, ya faisle hon, woh wapas email thread ke sath cryptographically link ho jayein.
* Zoho vs Anexomail: Zoho Cliq aur Zoho Mail bilkul alag apps hain. Anexomail ka bridge ek hi window mein chalega, jahan email ka message aur chat ki timeline ek hi Outcome Timeline ka hissa banegi, taake pata chal sake ke email par kya baat hui aur chat par kya faisla hua.

2. Immutable "Promise & Decision" Extraction
* Feature: Chat ya email bridge ke andar jab koi employee likhe "I will deliver the sales report by Friday," toh bridge bina kisi AI ke, deterministic logic ke zariye us chat line ko utha kar ek Official Company Promise (Work Object) mein convert kar de.
* Advance Mechanic: Yeh promise seedha company ke append-only ledger mein register ho jayega. Agar employee deadline miss karega, toh pure dashboard par uske Downstream Impact ka warning sign chalne lagega, jise mityaya nahi ja sakega.

3. File Evidence Chain Integration
* Feature: Jab koi file chat mein share ho, toh woh bridge ke zariye automatic us email thread ke attachment pipeline ke sath sync ho jaye. Us file par "Selected -> Verified -> Available" ka status badge lag jaye.
* Advance Mechanic: Agar chat mein chalne wali file ka version purana ho chuka hai aur email thread par naya faisla ho gaya hai, toh bridge instant chat screen par "Stale-File Warning" display karega. Zoho mein purani files dhoondna azaab hota hai, jabke yahan deterministic diff (version farq) live dikhega.

4. Direct Broadcast to External Email from Chat Panel
* Feature: Agar koi client external network (jaise Gmail ya Outlook) se email bhejta hai, toh company ke teams ko unhe reply karne ke liye email inbox mein jaane ki zaroorat nahi. Woh apne ANEXOChat panel se hi direct reply type karenge, aur bridge use automatic DKIM-signed and DMARC-protected outbound email bana kar client ko bhej dega.
* Advance Mechanic: Chat screen par hi live delivery confirmation aur message provenance (origination verification) ka status show hoga.

5. Honest Edit & Revocation Sync
* Feature: Agar chat ya email bridge ke zariye koi sent message ya email modify kiya jata hai, toh bridge pure workspace par ek Honest Edit Marker laga dega. Agar bridge se chat ya email delete kiya jaye, toh "Delete for Everyone" ka feature 48 ghante baad bhi kaam karega, aur poore system se uske fragments ko clean kar dega.

Workspace Dashboard Par Bridge Ka Look & Feel: split-screen mode — Left Panel: Main Email communication. Right Panel: Live Chat execution stream. Center/Bottom Anchor: The Bridge Engine (hashes, work dependencies, file tracking ko linear tarike se link karta hai).

1. Functional Workflow Design Features
* Thread-to-Room Instant Spin-up: kisi bhi active email thread ko single click se real-time cryptographic chat room mein convert karna.
* Bi-Directional Message Relay: chat panel se bheje gaye messages automatically DKIM-signed outbound emails; incoming client emails live chat messages.
* Deterministic Action Extraction: chat streams aur email texts se commitments (deadlines, deliverables) bina AI ke, strict text patterns se official "Work Objects".
* Stale-File Alert Workflow: jab kisi transaction ka decision agay nikal jaye, chat aur email dono screens par purani shared files par automatic warning badge.
* The Global Outcome Timeline: pure communication flow ka single master graphical timeline, email exchanges aur chat messages side-by-side chronologically merge.

2. Database Relational Logic Features
* Unified Thread Identity Schema: unique `Thread_ID` mapping table, email protocols (Message-ID headers) aur real-time chat web-socket events ko ek master record se cryptographically link kare.
* Append-Only Ledger Relations: messages/status badalne par purana data delete nahi hota, `previous_hash` foreign key ke sath sirf naya append record (`insert-only`).
* Work Object Dependency Constraints: strong cascading constraints jo task ko "Complete" tak update hone se rokti hain jab tak completion evidence file ka foreign key hash verify na ho jaye.
* File Hash Integrity Tracking: `File_Master` table mein file content ka unique SHA-256 hash, chat aur email records dono se relational linkage, duplicate storage zero.
* Provenance Ledger Schema: har data row ke sath strict UTC timestamp, unique device token, aur session state hashes bind.

Founder: "yeh bhi tarteeb main blueprint main add kero. yeh bhi hoga"
