//! `merkle_core` (module `merkle@1` of the kernel) — audit-ledger Merkle tree (master order step 5, F2c). SAME rule as SQL E107 (`_fm_leaf`, `_fm_node`, `_fm_next_level`) and RFC 6962:
//!   leaf = sha256(0x00 || row_hash_bytes)   node = sha256(0x01 || left || right)   odd last node is promoted unchanged (never duplicated).
//! One source (server/rust/, next to jwt_core.rs) for two users: the browser kernel `web-wasm` (Rule 52) and the founder server, both by `#[path]` include. Pure functions, no I/O, no clock.
//! Proof path items are `(side, sibling)`: side `R` = sibling on the right (node = H(01||node||sib)), `L` = sibling on the left (node = H(01||sib||node)).
use sha2::{Digest, Sha256};

pub type H32 = [u8; 32];

/// 64 lowercase hex chars -> 32 bytes. Anything else (upper case, wrong length, non-hex) = None, so a sloppy hash can never verify.
pub fn from_hex(s: &str) -> Option<H32> {
    let b = s.as_bytes();
    if b.len() != 64 { return None; }
    let mut out = [0u8; 32];
    for i in 0..32 {
        let hi = nib(b[2 * i])?;
        let lo = nib(b[2 * i + 1])?;
        out[i] = (hi << 4) | lo;
    }
    Some(out)
}
fn nib(c: u8) -> Option<u8> { match c { b'0'..=b'9' => Some(c - b'0'), b'a'..=b'f' => Some(c - b'a' + 10), _ => None } }

pub fn to_hex(h: &H32) -> String {
    const D: &[u8; 16] = b"0123456789abcdef";
    let mut s = String::with_capacity(64);
    for b in h { s.push(D[(b >> 4) as usize] as char); s.push(D[(b & 15) as usize] as char); }
    s
}

pub fn leaf(row_hash: &H32) -> H32 {
    let mut h = Sha256::new();
    h.update([0x00]);
    h.update(row_hash);
    h.finalize().into()
}

pub fn node(left: &H32, right: &H32) -> H32 {
    let mut h = Sha256::new();
    h.update([0x01]);
    h.update(left);
    h.update(right);
    h.finalize().into()
}

/// One level up: pairs (1,2),(3,4)...; the last lone node moves up as it is.
pub fn next_level(cur: &[H32]) -> Vec<H32> {
    let mut out = Vec::with_capacity(cur.len().div_ceil(2));
    let mut i = 0;
    while i < cur.len() {
        if i + 1 < cur.len() { out.push(node(&cur[i], &cur[i + 1])); } else { out.push(cur[i]); }
        i += 2;
    }
    out
}

/// Root of the leaves (already leaf-hashed). Empty = None (a tree needs at least one leaf).
pub fn root_of(leaves: &[H32]) -> Option<H32> {
    if leaves.is_empty() { return None; }
    let mut cur = leaves.to_vec();
    while cur.len() > 1 { cur = next_level(&cur); }
    Some(cur[0])
}

/// Every level, bottom (the leaves) to top (the root).
pub fn levels(leaves: &[H32]) -> Vec<Vec<H32>> {
    if leaves.is_empty() { return vec![]; }
    let mut all = vec![leaves.to_vec()];
    while all.last().map(|l| l.len() > 1).unwrap_or(false) { let n = next_level(all.last().unwrap()); all.push(n); }
    all
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Side { L, R }

/// Inclusion path of leaf `index` from the levels: at each level the sibling (if any) and which side it sits on.
pub fn path(levels: &[Vec<H32>], index: usize) -> Option<Vec<(Side, H32)>> {
    if levels.is_empty() || index >= levels[0].len() { return None; }
    let (mut idx, mut out) = (index, Vec::new());
    for lv in &levels[..levels.len() - 1] {
        let sib = idx ^ 1;
        if sib < lv.len() { out.push((if idx % 2 == 0 { Side::R } else { Side::L }, lv[sib])); }
        idx /= 2;
    }
    Some(out)
}

/// Does `row_hash` + `path` lead to `root`? More than 64 hops is refused (a tree of 2^64 leaves does not exist).
pub fn verify(row_hash: &H32, path: &[(Side, H32)], root: &H32) -> bool {
    if path.len() > 64 { return false; }
    let mut cur = leaf(row_hash);
    for (side, sib) in path { cur = match side { Side::R => node(&cur, sib), Side::L => node(sib, &cur) }; }
    &cur == root
}

/// JSON path from the server (`[{"s":"L","h":"<64 hex>"}, ...]`) -> typed. Any malformed item = None.
pub fn path_from_json(v: &[(String, String)]) -> Option<Vec<(Side, H32)>> {
    v.iter().map(|(s, h)| Some((match s.as_str() { "L" => Side::L, "R" => Side::R, _ => return None }, from_hex(h)?))).collect()
}

/// Text form used by the kernel ABI (no JSON parser inside the wasm): `L:<64 hex>,R:<64 hex>,...` (empty text = zero hops).
/// Any malformed part (bad side, bad hex, empty item, stray space) = false, never a panic.
pub fn verify_text(row_hash_hex: &str, path_text: &str, root_hex: &str) -> bool {
    let (Some(row), Some(root)) = (from_hex(row_hash_hex), from_hex(root_hex)) else { return false };
    let mut p = Vec::new();
    if !path_text.is_empty() {
        for item in path_text.split(',') {
            let Some((s, h)) = item.split_once(':') else { return false };
            let side = match s { "L" => Side::L, "R" => Side::R, _ => return false };
            let Some(sib) = from_hex(h) else { return false };
            p.push((side, sib));
        }
    }
    verify(&row, &p, &root)
}

// ============================================================================================================================================
// G5a: CONSISTENCY proofs (RFC 9162 section 2.1.4). "The tree of `second` leaves extends the tree of `first` leaves without changing any of the
// first ones." The tree shape here (odd node promoted) is the same tree as the RFC 6962 recursive split at the largest power of two below n
// (proven for 1..150 leaves in the tests), so the RFC algorithm applies unchanged. Generator = SUBPROOF; verifier = the RFC verification algorithm.
// ============================================================================================================================================

/// RFC 6962 recursive tree hash of leaves that are already leaf-hashed (reference form; `root_of` is the fast iterative form).
pub fn mth(leaves: &[H32]) -> H32 {
    match leaves.len() {
        0 => panic!("mth of an empty list"),
        1 => leaves[0],
        n => { let k = largest_pow2_below(n); node(&mth(&leaves[..k]), &mth(&leaves[k..])) }
    }
}
fn largest_pow2_below(n: usize) -> usize { let mut k = 1; while k * 2 < n { k *= 2; } k }

fn subproof(m: usize, d: &[H32], b: bool) -> Vec<H32> {
    let n = d.len();
    if m == n { return if b { vec![] } else { vec![mth(d)] }; }
    let k = largest_pow2_below(n);
    if m <= k { let mut v = subproof(m, &d[..k], b); v.push(mth(&d[k..])); v }
    else { let mut v = subproof(m - k, &d[k..], false); v.push(mth(&d[..k])); v }
}

/// The proof that the first `first` leaves are a prefix of the first `second` leaves (1 <= first <= second <= leaves.len()). None for any other sizes.
pub fn consistency_proof(leaves: &[H32], first: usize, second: usize) -> Option<Vec<H32>> {
    if first < 1 || first > second || second > leaves.len() { return None; }
    Some(subproof(first, &leaves[..second], true))
}

/// RFC 9162 2.1.4.2. Accepts only if the proof rebuilds BOTH roots. Sizes must be 1 <= first <= second; equal sizes need an empty proof and equal roots.
/// A proof longer than 65 hashes cannot exist for any tree that fits in memory and is refused outright.
pub fn verify_consistency(first: u64, second: u64, first_root: &H32, second_root: &H32, proof: &[H32]) -> bool {
    if first < 1 || first > second || proof.len() > 65 { return false; }
    if first == second { return proof.is_empty() && first_root == second_root; }
    if proof.is_empty() { return false; }
    let mut p: Vec<H32> = Vec::with_capacity(proof.len() + 1);
    if first.is_power_of_two() { p.push(*first_root); }          // the old tree is a complete subtree the generator did not emit
    p.extend_from_slice(proof);
    let (mut fnn, mut sn) = (first - 1, second - 1);
    while fnn & 1 == 1 { fnn >>= 1; sn >>= 1; }
    let (mut fr, mut sr) = (p[0], p[0]);
    for c in &p[1..] {
        if sn == 0 { return false; }
        if fnn & 1 == 1 || fnn == sn {
            fr = node(c, &fr); sr = node(c, &sr);
            if fnn & 1 == 0 { while fnn & 1 == 0 && fnn != 0 { fnn >>= 1; sn >>= 1; } }
        } else {
            sr = node(&sr, c);
        }
        fnn >>= 1; sn >>= 1;
    }
    &fr == first_root && &sr == second_root && sn == 0
}

/// Text form for the kernel ABI (no JSON parser inside the wasm): sizes as numbers, roots as 64 lowercase hex, proof as `<64 hex>,<64 hex>,...`
/// (empty text = no hashes). Anything malformed (bad hex, empty item, stray space, too many hashes) = false, never a panic.
pub fn verify_consistency_text(first: u64, second: u64, first_root_hex: &str, second_root_hex: &str, proof_text: &str) -> bool {
    let (Some(fr), Some(sr)) = (from_hex(first_root_hex), from_hex(second_root_hex)) else { return false };
    let mut proof = Vec::new();
    if !proof_text.is_empty() {
        for item in proof_text.split(',') {
            let Some(h) = from_hex(item) else { return false };
            proof.push(h);
            if proof.len() > 65 { return false; }
        }
    }
    verify_consistency(first, second, &fr, &sr, &proof)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Same inputs as SQL `founder_audit_merkle_vectors()`: row hash g = sha256("founder-merkle-vector-" + g), g = 1..n.
    fn vec_rows(n: usize) -> Vec<H32> { (1..=n).map(|g| Sha256::digest(format!("founder-merkle-vector-{g}").as_bytes()).into()).collect() }
    fn leaves_of(n: usize) -> Vec<H32> { vec_rows(n).iter().map(leaf).collect() }
    fn h(s: &str) -> H32 { from_hex(s).unwrap() }

    // Roots below were produced by the SQL (E107, server CHECK 12/12): the two implementations must agree byte for byte.
    const ROOTS: [(usize, &str); 9] = [
        (1, "158cccace1cd000b720dc6533de2620ea3e70b907a6d7a7038687f1b28a7537c"),
        (2, "619933a6cda3bcd1faba11b3fb9ec2d8bd13d4ec4d9c8787d3c830cea5220476"),
        (3, "affb9317bdc52d5109a09da7a9e5ae9503f6b95b5476b5ea2de70b050e7b09b9"),
        (4, "b0c9b4dbdc617bb2c4a37c4d2658abf14b6b564a44565ae550544a4f53d58072"),
        (5, "c1dea11c258198e48445075d7c48267aacafaf7e68870e45d74b37b6023d5f44"),
        (6, "2fd96038f719600ebbac1068f6748310b47a0cadb7c87fa51e308f36856e8f90"),
        (7, "de5464e0406c1157d9b964a79975e75723285ba73ad8679366179f1aa607c1c4"),
        (8, "cf5be755f603be6bda48a7e27b6b942200eefcc584c18e30d3748b91d0bd99fd"),
        (9, "245862b3e1315bc2760fbb02ade04caf4331a06c2b1ba2f63db8714d1d64ee9f"),
    ];

    #[test]
    fn roots_match_the_sql_vectors_for_every_size() {
        for (n, want) in ROOTS { assert_eq!(to_hex(&root_of(&leaves_of(n)).unwrap()), want, "n={n}"); }
    }

    #[test]
    fn last_leaf_paths_match_the_sql_vectors() {
        // n=3 last leaf: one hop, sibling = root of the first two, on the LEFT (odd node promoted, not duplicated)
        let lv = levels(&leaves_of(3));
        assert_eq!(path(&lv, 2).unwrap(), vec![(Side::L, h("619933a6cda3bcd1faba11b3fb9ec2d8bd13d4ec4d9c8787d3c830cea5220476"))]);
        // n=9 last leaf: one hop, sibling = root of the first eight
        let lv = levels(&leaves_of(9));
        assert_eq!(path(&lv, 8).unwrap(), vec![(Side::L, h("cf5be755f603be6bda48a7e27b6b942200eefcc584c18e30d3748b91d0bd99fd"))]);
        // n=1: no hop at all
        assert_eq!(path(&levels(&leaves_of(1)), 0).unwrap(), vec![]);
    }

    #[test]
    fn every_leaf_of_every_size_proves_and_nothing_else_does() {
        for n in 1..=40usize {
            let (rows, lv) = (vec_rows(n), levels(&leaves_of(n)));
            let root = *lv.last().unwrap().first().unwrap();
            for i in 0..n {
                let p = path(&lv, i).unwrap();
                assert!(verify(&rows[i], &p, &root), "n={n} i={i}");
                if n > 1 { assert!(!verify(&rows[(i + 1) % n], &p, &root), "n={n} i={i} wrong row accepted"); }
                let mut bad = root; bad[0] ^= 1;
                assert!(!verify(&rows[i], &p, &bad), "n={n} i={i} wrong root accepted");
            }
        }
    }

    /// RFC 6962's recursive definition (split at the largest power of two < n) must equal the iterative one used everywhere.
    fn mth(l: &[H32]) -> H32 {
        if l.len() == 1 { return l[0]; }
        let mut k = 1; while k * 2 < l.len() { k *= 2; }
        node(&mth(&l[..k]), &mth(&l[k..]))
    }
    #[test]
    fn iterative_equals_rfc6962_recursive_for_1_to_150_leaves() {
        for n in 1..=150 { let l = leaves_of(n); assert_eq!(root_of(&l).unwrap(), mth(&l), "n={n}"); }
    }

    #[test]
    fn leaf_and_node_domains_are_separate() {
        let z = [0u8; 32];
        assert_ne!(leaf(&z), node(&z, &z));
        assert_ne!(leaf(&z), <H32>::from(Sha256::digest(z))); // the 0x00 prefix is really there
        assert_ne!(node(&h(&"01".repeat(32)), &h(&"02".repeat(32))), node(&h(&"02".repeat(32)), &h(&"01".repeat(32))));
    }

    #[test]
    fn tampering_with_the_path_fails_closed() {
        let (rows, lv) = (vec_rows(7), levels(&leaves_of(7)));
        let root = *lv.last().unwrap().first().unwrap();
        let mut p = path(&lv, 3).unwrap();
        assert!(verify(&rows[3], &p, &root));
        p[0].1[5] ^= 0x80; assert!(!verify(&rows[3], &p, &root), "sibling bit flipped");
        let mut p = path(&lv, 3).unwrap();
        p[1].0 = if p[1].0 == Side::L { Side::R } else { Side::L }; assert!(!verify(&rows[3], &p, &root), "side swapped");
        let mut p = path(&lv, 3).unwrap(); p.pop(); assert!(!verify(&rows[3], &p, &root), "hop removed");
        let long = vec![(Side::L, [0u8; 32]); 65];
        assert!(!verify(&rows[3], &long, &root), "65 hops refused");
    }

    #[test]
    fn hex_is_strict() {
        assert!(from_hex(&"ab".repeat(32)).is_some());
        assert!(from_hex(&"AB".repeat(32)).is_none(), "upper case refused");
        assert!(from_hex(&"ab".repeat(31)).is_none());
        assert!(from_hex(&format!("{}zz", "ab".repeat(31))).is_none());
        assert_eq!(to_hex(&from_hex(&"0f".repeat(32)).unwrap()), "0f".repeat(32));
    }

    #[test]
    fn json_path_parser_refuses_garbage() {
        let ok = vec![("L".to_string(), "ab".repeat(32)), ("R".to_string(), "cd".repeat(32))];
        assert_eq!(path_from_json(&ok).unwrap().len(), 2);
        assert!(path_from_json(&[("X".to_string(), "ab".repeat(32))]).is_none());
        assert!(path_from_json(&[("L".to_string(), "zz".to_string())]).is_none());
    }

    #[test]
    fn empty_tree_has_no_root_and_bad_index_has_no_path() {
        assert!(root_of(&[]).is_none());
        assert!(levels(&[]).is_empty());
        assert!(path(&levels(&leaves_of(3)), 3).is_none());
        assert!(path(&[], 0).is_none());
    }

    #[test]
    fn text_form_verifies_the_sql_vectors_and_refuses_garbage() {
        // n=3 last leaf, path and root straight from SQL E107 vectors
        let rows = vec_rows(3);
        let root = to_hex(&root_of(&leaves_of(3)).unwrap());
        let row = to_hex(&rows[2]);
        let path = "L:619933a6cda3bcd1faba11b3fb9ec2d8bd13d4ec4d9c8787d3c830cea5220476";
        assert!(verify_text(&row, path, &root));
        assert!(verify_text(&to_hex(&rows[0]), "", "158cccace1cd000b720dc6533de2620ea3e70b907a6d7a7038687f1b28a7537c"), "1 leaf = zero hops");
        for bad in ["R:619933a6cda3bcd1faba11b3fb9ec2d8bd13d4ec4d9c8787d3c830cea5220476", "X:61", "L:zz", "L", ",", "L:619933a6cda3bcd1faba11b3fb9ec2d8bd13d4ec4d9c8787d3c830cea5220476,", " L:619933a6cda3bcd1faba11b3fb9ec2d8bd13d4ec4d9c8787d3c830cea5220476"] {
            assert!(!verify_text(&row, bad, &root), "{bad}");
        }
        assert!(!verify_text("nothex", path, &root));
        assert!(!verify_text(&row, path, &"0".repeat(64)));
        assert!(!verify_text(&row, &vec!["L:".to_string() + &"00".repeat(32); 65].join(","), &root), "65 hops refused");
    }

    // ---------------------------------------------------------------- G5a: consistency proofs
    #[test]
    fn iterative_root_equals_the_rfc_recursive_tree_for_1_to_150_leaves() {
        for n in 1..=150 { let l = leaves_of(n); assert_eq!(root_of(&l).unwrap(), mth(&l), "n={n}"); }
    }
    #[test]
    fn every_consistency_proof_for_1_to_150_leaves_verifies_and_has_the_rfc_length_bound() {
        let l = leaves_of(150);
        for n in 1..=150usize {
            let rn = mth(&l[..n]);
            for m in 1..=n {
                let rm = mth(&l[..m]);
                let pr = consistency_proof(&l, m, n).unwrap();
                assert!(verify_consistency(m as u64, n as u64, &rm, &rn, &pr), "m={m} n={n}");
                assert!(pr.len() <= (usize::BITS - (n - 1).leading_zeros()) as usize + 1, "proof too long m={m} n={n}");
                if m == n { assert!(pr.is_empty(), "equal sizes need an empty proof"); }
            }
        }
    }
    #[test]
    fn consistency_generator_refuses_impossible_sizes() {
        let l = leaves_of(10);
        for (m, n) in [(0, 5), (6, 5), (1, 11), (0, 0), (11, 11)] { assert!(consistency_proof(&l, m, n).is_none(), "{m} {n}"); }
    }
    #[test]
    fn every_single_bit_flip_in_any_proof_hash_is_rejected() {
        let l = leaves_of(40);
        for n in 2..=40usize {
            let rn = mth(&l[..n]);
            for m in 1..n {
                let rm = mth(&l[..m]);
                let pr = consistency_proof(&l, m, n).unwrap();
                for i in 0..pr.len() { for bit in 0..256usize {
                    let mut bad = pr.clone(); bad[i][bit / 8] ^= 1 << (bit % 8);
                    assert!(!verify_consistency(m as u64, n as u64, &rm, &rn, &bad), "bit flip accepted m={m} n={n} i={i} bit={bit}");
                } }
            }
        }
    }
    #[test]
    fn wrong_sizes_wrong_roots_and_reshaped_proofs_are_rejected() {
        let l = leaves_of(64);
        for n in 2..=64usize {
            let rn = mth(&l[..n]);
            for m in 1..n {
                let rm = mth(&l[..m]);
                let pr = consistency_proof(&l, m, n).unwrap();
                let ok = |a: u64, b: u64, x: &H32, y: &H32, p: &[H32]| verify_consistency(a, b, x, y, p);
                assert!(ok(m as u64, n as u64, &rm, &rn, &pr));
                assert!(!ok(m as u64, n as u64, &rn, &rm, &pr), "swapped roots m={m} n={n}");
                let mut rn_bad = rn; rn_bad[31] ^= 0x80; assert!(!ok(m as u64, n as u64, &rm, &rn_bad, &pr), "wrong new root m={m} n={n}");
                let mut rm_bad = rm; rm_bad[0] ^= 1; assert!(!ok(m as u64, n as u64, &rm_bad, &rn, &pr), "wrong old root m={m} n={n}");
                assert!(!ok(0, n as u64, &rm, &rn, &pr), "first=0");
                assert!(!ok(n as u64 + 1, n as u64, &rm, &rn, &pr), "first>second");
                if m + 1 < n { assert!(!ok(m as u64 + 1, n as u64, &rm, &rn, &pr), "lied about the old size m={m} n={n}"); }
                // NOTE (design fact, not a bug): a Merkle root does not commit to its own tree size, so the SIZES are bound by the signed checkpoint (G5b), never by this check alone.
                assert!(!ok(m as u64, n as u64, &rm, &rn, &[]), "empty proof");
                let mut ext = pr.clone(); ext.push([7u8; 32]); assert!(!ok(m as u64, n as u64, &rm, &rn, &ext), "extended proof m={m} n={n}");
                let mut cut = pr.clone(); cut.pop(); assert!(!ok(m as u64, n as u64, &rm, &rn, &cut), "truncated proof m={m} n={n}");
                if pr.len() > 1 { let mut rev = pr.clone(); rev.reverse(); if rev != pr { assert!(!ok(m as u64, n as u64, &rm, &rn, &rev), "reordered proof m={m} n={n}"); } }
            }
            // equal sizes: proof must be empty and the roots equal
            assert!(verify_consistency(n as u64, n as u64, &rn, &rn, &[]));
            assert!(!verify_consistency(n as u64, n as u64, &rn, &rn, &[[1u8; 32]]), "equal sizes with a proof");
            assert!(!verify_consistency(n as u64, n as u64, &rn, &mth(&l[..n - 1]), &[]), "equal sizes, different roots");
        }
    }
    #[test]
    fn random_garbage_never_verifies_and_never_panics() {
        let mut x: u64 = 0x9E3779B97F4A7C15;
        let mut next = move || { x ^= x << 13; x ^= x >> 7; x ^= x << 17; x };
        for _ in 0..20_000 {
            let (m, n) = (1 + next() % 300, 1 + next() % 300);
            let mut hash = || { let mut a = [0u8; 32]; for b in a.iter_mut() { *b = next() as u8; } a };
            let (fr, sr) = (hash(), hash());
            let plen = (hash()[0] % 70) as usize;
            let proof: Vec<H32> = (0..plen).map(|_| hash()).collect();
            if m <= n { assert!(!verify_consistency(m, n, &fr, &sr, &proof), "garbage accepted m={m} n={n}"); }
        }
        // sizes at the edge of u64 must not overflow or panic
        let z = [0u8; 32];
        for (m, n) in [(u64::MAX, u64::MAX), (1, u64::MAX), (u64::MAX - 1, u64::MAX), (0, 0)] { let _ = verify_consistency(m, n, &z, &z, &[z; 3]); }
    }
    #[test]
    fn power_of_two_old_size_with_a_forged_old_root_and_text_edge_forms_are_refused() {
        let l = leaves_of(7);
        let (rm, rn) = (mth(&l[..4]), mth(&l));
        let pr = consistency_proof(&l, 4, 7).unwrap();
        assert!(verify_consistency(4, 7, &rm, &rn, &pr));
        for forged in &pr { assert!(!verify_consistency(4, 7, forged, &rn, &pr), "a proof node passed off as the old root"); }
        let txt = pr.iter().map(to_hex).collect::<Vec<_>>().join(",");
        let (a, b) = (to_hex(&rm), to_hex(&rn));
        assert!(verify_consistency_text(4, 7, &a, &b, &txt));
        for bad in [format!("{txt}\n"), format!("0x{txt}"), format!(",{txt}"), format!("{txt},,"), txt.to_uppercase()] { assert!(!verify_consistency_text(4, 7, &a, &b, &bad), "{bad}"); }
        let h = to_hex(&[0x11u8; 32]);
        assert!(!verify_consistency_text(4, 7, &a, &b, &vec![h.as_str(); 65].join(",")), "65 hashes parse, then are refused");
        assert!(!verify_consistency_text(4, 7, &a, &b, &vec![h.as_str(); 66].join(",")), "66 hashes refused by the parser");
        let _ = verify_consistency(1 << 62, (1u64 << 63) - 1, &rm, &rn, &pr); // huge sizes: only 'no panic' is promised; sizes are bound by the signed seal, not by the roots
    }
    #[test]
    fn larger_trees_also_verify_with_real_proofs() {
        let l = leaves_of(700);
        for (m, n) in [(1usize, 700usize), (255, 256), (256, 257), (300, 700), (512, 700), (699, 700), (350, 351), (1, 2), (129, 700)] {
            let (rm, rn) = (mth(&l[..m]), mth(&l[..n]));
            let pr = consistency_proof(&l, m, n).unwrap();
            assert!(verify_consistency(m as u64, n as u64, &rm, &rn, &pr), "m={m} n={n}");
            let mut bad = pr.clone(); let i = pr.len() / 2; bad[i][5] ^= 0x10;
            assert!(!verify_consistency(m as u64, n as u64, &rm, &rn, &bad), "flip m={m} n={n}");
        }
    }
    #[test]
    fn text_form_is_strict() {
        let l = leaves_of(9);
        let (rm, rn) = (to_hex(&mth(&l[..5])), to_hex(&mth(&l[..9])));
        let pr = consistency_proof(&l, 5, 9).unwrap();
        let txt = pr.iter().map(to_hex).collect::<Vec<_>>().join(",");
        assert!(verify_consistency_text(5, 9, &rm, &rn, &txt));
        assert!(!verify_consistency_text(5, 9, &rm, &rn, &format!("{txt},")), "trailing comma");
        assert!(!verify_consistency_text(5, 9, &rm, &rn, &txt.replace(',', ", ")), "space");
        assert!(!verify_consistency_text(5, 9, &rm.to_uppercase(), &rn, &txt), "upper case hex");
        assert!(!verify_consistency_text(5, 9, &rm, &rn, ""), "no proof for different sizes");
        assert!(verify_consistency_text(9, 9, &rn, &rn, ""), "equal sizes, no proof");
        assert!(!verify_consistency_text(5, 9, &rm, &rn, &vec![txt.as_str(); 20].join(",")), "too many hashes");
    }
}
