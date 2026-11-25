# B13 T4i: company registration numbers for EVERY country (Pakistan included) - PLAN, NOT BUILT (25 Nov 2026 04:35 PKT)
His order (04:21): "duniya ke har country ki company registration number alag hota hai, sab countries ki, Pakistani bhi, websearch kero". RULE 52 COMBO S=yes M=N/A L=yes.
## Research (web, 25 Nov 2026) - what is proven and what is not
- GLEIF Registration Authorities List (https://www.gleif.org/en/about-lei/gleif-registration-authorities-list): almost 1,200 business registers and related authorities, 230+ jurisdictions, version v1.9 (Sept 2026), downloads as .xlsx and CSV. Each register has its own code. License text NOT confirmed (must read the LEI Data Terms of Use before loading).
- OpenCorporates + GLEIF mapping (https://knowledge.opencorporates.com/knowledge-base/data-dictionary-companies/): company_number is per jurisdiction; the register id is the key, the number alone is NOT unique worldwide.
- Pakistan: SECP issues the CUIN, a seven-digit number at incorporation (one source only: https://businessdataguide.com/blog/jurisdictions/pakistan-company-search-guide, not checked against a live SECP page; SECP search was down for that source). NTN (tax, FBR) is a separate number: digit format NOT confirmed (https://lookuptax.com/validate/pakistan/ntn lists it). STRN: not confirmed. These stay OPEN until read from SECP/FBR pages.
## Design (advance, built once)
1. Key = (country, register code) never the bare number. A company may hold several ids (registry no., tax no., LEI).
2. Table desk.fadm_registry_kind (AD34 extended, no new SQL file): country ISO 3166, GLEIF RA code, register name, id label, regex, check-digit rule if public, source URL, checked_on. Rows come ONLY from the GLEIF list file plus a hand-checked layer for Pakistan; a format with no public rule gets "shape unknown, accept as typed after normalising", never an invented regex.
3. Normalise (trim, remove spaces and dashes) before checking; a wrong shape is a warning with the expected shape, not a silent accept; nothing is ever guessed.
4. Company confirmation screen: country + register chosen first, then the number; the name returned by the Control Plane stays the proof.
## Needs from him
- The GLEIF RA list file (CSV) from the GLEIF page (this sandbox cannot download it; its network allow-list refuses that host) and a yes after the License terms are read.
## Not built yet: everything above.

## 25 Nov 2026 04:45 PKT: HIS CSV READ (docs/claude/admin-desk/data/gleif-ra-list-v1.9-2026-09-30.csv, GLEIF RA list v1.9, 1,181 lines)
- PROVEN from the file: 1,178 real register rows in 234 countries/jurisdictions + 3 special codes (RA777777 public legal documents, RA888888 temporary, RA999999 none available). Columns: RA code, country, country code, jurisdiction, register name, local name, responsible organisation, website, comments (445 rows have a comment).
- The file has NO number format column: it names WHICH register exists, not how its numbers look. So a per-country number shape is NOT in GLEIF's list and must never be invented; formats are added one by one only from the register's own page (Pakistan first: CUIN 7 digits needs SECP's page).
- RA codes are NOT unique across rows (some codes repeat): the table key must be a row id, with the RA code as a plain column, checked at load.
- Pakistan in the file: RA000475 Corporate Registry (Securities and Exchange Commission, www.secp.gov.pk); RA001111 Online Verification Services (FBR, https://e.fbr.gov.pk/esbn/Verification) = the tax side (NTN/STRN verification).
- NEXT (not built): AD34 extension desk.fadm_registry_kind loaded from this file (country + register picker), format column empty = "shape unknown" until verified per register.

## 25 Nov 2026 05:00 PKT: SQL WRITTEN + TESTED, NOT INSTALLED (his 04:31 order: build it future-proof ourselves, never ask the customer)
- AD34 extended (no new SQL file): desk.fadm_registry_kind loaded from his GLEIF file (1,181 rows, 234 jurisdictions), row id key + generated row_hash (idempotent load), forced RLS, SELECT only for desk_app, never deleted (trigger P0AW5), number_shape always together with shape_source + shape_checked_on (CHECK), desk.registry_check(kind, number) answers closed words ok / wrong_shape / shape_unknown / bad_number / no_register. Selftest + 3 CHECK rows (AD34 CHECK now 19 of 19 true on scratch PostgreSQL 16; second run keeps 1181 rows).
- Nothing in the customer flow asks for it: it is a reference the Desk uses only when a staff person needs it. Every shape stays NULL until a register's own page proves it (Pakistan SECP CUIN 7 digits needs SECP's page).
- NEXT: his SQL command (desk-sql-install.sh), then the Desk read door + country/register picker on Company confirmation (Rust + React, web install), then the Pakistan shape from SECP's page.
- Gate DESK NO-MONEY refused the first load (one GLEIF comment contains the word 'amount'); fixed honestly, gate untouched: comment column keeps the first 100 characters, full text stays in the CSV.
