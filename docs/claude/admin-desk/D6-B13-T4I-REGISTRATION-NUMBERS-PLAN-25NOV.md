# B13 T4i: company registration numbers for EVERY country (Pakistan included) - PLAN, NOT BUILT (25 Nov 2026 04:35 PKT)
His order (04:21): "duniya ke har country ki company registration number alag hota hai, sab countries ki, Pakistani bhi, websearch kero". RULE 52 COMBO S=yes M=N/A L=yes.
## Research (web, 25 Nov 2026) - what is proven and what is not
- GLEIF Registration Authorities List (https://www.gleif.org/en/about-lei/gleif-registration-authorities-list): almost 1,200 business registers and related authorities, 230+ jurisdictions, version v1.9 (Sept 2026), downloads as .xlsx and CSV. Each register has its own code. License text NOT confirmed (must read the LEI Data Terms of Use before loading).
- OpenCorporates + GLEIF mapping (https://knowledge.opencorporates.com/knowledge-base/data-dictionary-companies/): company_number is per jurisdiction; the register id is the key, the number alone is NOT unique worldwide.
- Pakistan: SECP issues the CUIN, a seven-digit number at incorporation (one source only: https://businessdataguide.com/blog/jurisdictions/pakistan-company-search-guide, not checked against a live SECP page; SECP search was down for that source). NTN (tax, FBR) is a separate number: digit format NOT confirmed (https://lookuptax.com/validate/pakistan/ntn lists it). STRN: not confirmed. These stay OPEN until read from SECP/FBR pages.
## Design (advance, built once)
1. Key = (country, register code) never the bare number. A company may hold several ids (registry no., tax no., LEI).
2. Table desk.registry_kind (AD34 extended, no new SQL file): country ISO 3166, GLEIF RA code, register name, id label, regex, check-digit rule if public, source URL, checked_on. Rows come ONLY from the GLEIF list file plus a hand-checked layer for Pakistan; a format with no public rule gets "shape unknown, accept as typed after normalising", never an invented regex.
3. Normalise (trim, remove spaces and dashes) before checking; a wrong shape is a warning with the expected shape, not a silent accept; nothing is ever guessed.
4. Company confirmation screen: country + register chosen first, then the number; the name returned by the Control Plane stays the proof.
## Needs from him
- The GLEIF RA list file (CSV) from the GLEIF page (this sandbox cannot download it; its network allow-list refuses that host) and a yes after the License terms are read.
## Not built yet: everything above.
