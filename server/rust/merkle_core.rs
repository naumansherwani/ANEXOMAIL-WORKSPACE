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
}
