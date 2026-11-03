# lovable-gold: frozen copy of the Lovable-era code (Rule 73)

Founder 3 Nov 2026 08:33 PKT: the Lovable code is gold and must be PRESERVED. This folder holds an exact COPY (52 files) of every Lovable-lane file,
with the same relative paths and a sha256 MANIFEST. The live files stay where the awam site and server build from them (nothing was moved or deleted).

* READ-ONLY: never edit anything here by hand. The rules-gate fails if this folder differs from the live Lovable files.
* Refresh only through `python3 lanes/lane-sync.py` (after the live file was changed on purpose).
* Cutover T (removing the old Lovable founder routes) may delete the LIVE copy only after the founder says so; this copy stays.
* Lane lists: `lanes/founder.txt`, `lanes/awam.txt`, `lanes/shared.txt`, `lanes/lovable.txt`, `lanes/docs.txt` (every tracked file is in exactly one).
Counts at generation: {'founder': 189, 'awam': 1315, 'shared': 65, 'lovable': 52, 'docs': 278}.
