# GAP 2: ML-DSA (FIPS 204) + Ed25519 HYBRID SIGNATURES, PLAN AT REPO TOP (23 Nov 2026 03:1x PKT, his word 02:53)
Status: OPEN GAP, separate from the order lock 1j..1o. It does NOT start until the Dashboard folder is 100% or he says "ab ML-DSA".
Research (IETF LAMPS draft-ietf-lamps-pq-composite-sigs, many revisions through 2026): composite = ML-DSA + a classical signature, BOTH must verify; this is the accepted hybrid shape.
Where it applies on the Desk: (1) the Control Plane answer envelope (today Ed25519 only), (2) AD4b audit checkpoints (outside signed copy), (3) kernel verify in the Rust WASM kernel.
Steps, each proven before the next: S1 pick crate (RustCrypto ml-dsa, WASM build size check) and write CURRENT.md contract; S2 kernel verify of a hybrid envelope (both must pass, either failing = refuse); S3 Rust signer on the Control Plane side; S4 checkpoint signing; S5 live proof. SLH-DSA (FIPS 205) stays the conservative fallback. SHA-256 chains stay unchanged.
Rule 52 note: it is listed as an open gap in RULE-52-LIVE-TECHNOLOGY-23NOV.md until code exists.
