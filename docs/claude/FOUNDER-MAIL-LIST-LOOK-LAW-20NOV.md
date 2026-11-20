# FOUNDER MAIL LIST LOOK = SAME TO SAME (his 20 Nov 2026 09:39 PKT, in anger)
His words: "mujhe yeh same to same wapis chaye hain yaad rakhna" (his phone photo of the list is in the chat only, not in the repo).
The look: each mail row = round avatar (AM / MN / NO), sender + time on one line, subject line, preview line, "6 in thread". NO bordered boxes around rows.
Cause of the break (20 Nov 09:30): my new reply button class `mbx-rb` was the SAME name as the list row class, so rows became 44 px boxes. Fixed by the rename to `mbx-rpl` (9ac3a9c6).
RULES: (1) a new class name is grepped against ALL css + tsx before use; (2) the UI LAW stays: nothing existing is restyled without his word; (3) guard test founder-web/src/ui_class_guard.test.ts fails if `.mbx-rb` is defined twice or the reply bar reuses it.
