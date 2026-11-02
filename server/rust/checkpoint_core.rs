//! `checkpoint_core` (module `checkpoint@1` of the kernel) — G5b: C2SP signed-note + tlog-checkpoint, the audit log's own signed checkpoints.
//! Spec: c2sp.org/signed-note, c2sp.org/tlog-checkpoint. Body = `origin \n size \n base64(root32) \n` (size canonical decimal). Note = body + `\n` + `— name base64(keyid4 || sig64)\n`.
//! Ed25519 key id = first 4 bytes of sha256(name || 0x0A || 0x01 || pub32). The signature covers the body INCLUDING its final newline.
//! One source for two users (Rule 52): the founder server (signs, and self-verifies before it stores) and the browser kernel (verifies). Pure: no I/O, no clock, no Ed25519 inside —
//! the caller hands in `verify_sig`, so this file needs only sha2 and the Ed25519 crate stays where it already is (ring on the server, ed25519-dalek in the kernel).
//! Independent oracle: Go's own `note` package (see docs/cursor-work/server/g5b-oracle/) produced the vectors this file is tested against, plus the published PeterNeumann note.
//! STRICTER than Go on purpose: canonical base64, <=16 signature lines, body is exactly the three checkpoint lines (no extension lines), origin must equal the key name.
//! Same as Go: unknown keys are ignored; a KNOWN key with a bad signature rejects the whole note; identical repeated signature lines are dropped; no matching signature rejects.
use sha2::{Digest, Sha256};

pub const MAX_NOTE: usize = 4096;
pub const MAX_SIGS: usize = 16;
const EM_DASH: &str = "\u{2014} ";
const B64: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

pub fn b64_enc(d: &[u8]) -> String {
    let mut s = String::with_capacity(d.len().div_ceil(3) * 4);
    for c in d.chunks(3) {
        let n = (c[0] as u32) << 16 | (*c.get(1).unwrap_or(&0) as u32) << 8 | *c.get(2).unwrap_or(&0) as u32;
        s.push(B64[(n >> 18) as usize & 63] as char);
        s.push(B64[(n >> 12) as usize & 63] as char);
        s.push(if c.len() > 1 { B64[(n >> 6) as usize & 63] as char } else { '=' });
        s.push(if c.len() > 2 { B64[n as usize & 63] as char } else { '=' });
    }
    s
}

/// Canonical standard base64 only: length % 4 == 0, alphabet, `=` only at the end, and unused trailing bits are zero (so one byte string has exactly one text form).
pub fn b64_dec(s: &str) -> Option<Vec<u8>> {
    let b = s.as_bytes();
    if b.is_empty() || b.len() % 4 != 0 { return None; }
    let val = |c: u8| B64.iter().position(|&x| x == c).map(|p| p as u32);
    let mut out = Vec::with_capacity(b.len() / 4 * 3);
    for (i, q) in b.chunks(4).enumerate() {
        let last = i == b.len() / 4 - 1;
        let pad = if q[3] == b'=' { if q[2] == b'=' { 2 } else { 1 } } else { 0 };
        if pad > 0 && !last { return None; }
        if q[..4 - pad].contains(&b'=') { return None; }
        let (a, b2) = (val(q[0])?, val(q[1])?);
        let c = if pad == 2 { 0 } else { val(q[2])? };
        let d = if pad >= 1 { 0 } else { val(q[3])? };
        let n = a << 18 | b2 << 12 | c << 6 | d;
        out.push((n >> 16) as u8);
        if pad < 2 { out.push((n >> 8) as u8); }
        if pad < 1 { out.push(n as u8); }
        if pad == 2 && (b2 & 0x0f) != 0 { return None; }
        if pad == 1 && (c & 0x03) != 0 { return None; }
    }
    Some(out)
}

pub fn valid_name(n: &str) -> bool { !n.is_empty() && !n.chars().any(|c| c.is_whitespace() || c == '+' || c.is_control()) }

pub fn key_id(name: &str, pubkey: &[u8; 32]) -> [u8; 4] {
    let mut h = Sha256::new();
    h.update(name.as_bytes());
    h.update([0x0a, 0x01]);
    h.update(pubkey);
    let d = h.finalize();
    [d[0], d[1], d[2], d[3]]
}

/// `origin\nsize\nb64(root)\n`
pub fn body(origin: &str, size: u64, root: &[u8; 32]) -> String { format!("{origin}\n{size}\n{}\n", b64_enc(root)) }

/// One signature line (with trailing newline) for `sig64` over `body`.
pub fn sig_line(name: &str, pubkey: &[u8; 32], sig: &[u8; 64]) -> String {
    let mut raw = key_id(name, pubkey).to_vec();
    raw.extend_from_slice(sig);
    format!("{EM_DASH}{name} {}\n", b64_enc(&raw))
}

pub fn assemble(body: &str, sig_lines: &[String]) -> String { format!("{body}\n{}", sig_lines.concat()) }

/// Parse the three checkpoint lines exactly: no extension lines, size without leading zeros/sign/space, root = canonical base64 of exactly 32 bytes.
pub fn parse_body(b: &str) -> Option<(String, u64, [u8; 32])> {
    let body = b.strip_suffix('\n')?;
    let mut it = body.split('\n');
    let (origin, size, root) = (it.next()?, it.next()?, it.next()?);
    if it.next().is_some() || origin.is_empty() { return None; }
    if size.is_empty() || !size.bytes().all(|c| c.is_ascii_digit()) || (size.len() > 1 && size.starts_with('0')) { return None; }
    let size: u64 = size.parse().ok()?;
    let r = b64_dec(root)?;
    let root: [u8; 32] = r.try_into().ok()?;
    Some((origin.to_string(), size, root))
}

#[derive(Debug, PartialEq, Eq)]
pub enum Verdict { Ok, Bad(&'static str) }

/// Strict verify. `verify_sig(msg, sig64)` is the caller's Ed25519 check against `pubkey`. Returns Ok only when: well-formed, a signature line from exactly (name, key id of pubkey) verifies,
/// the origin equals `name`, and the signed size/root equal what the caller expects (what the database says the seal is).
pub fn verify(note: &str, name: &str, pubkey: &[u8; 32], want_size: u64, want_root: &[u8; 32], verify_sig: &dyn Fn(&[u8], &[u8; 64]) -> bool) -> Verdict {
    if note.len() > MAX_NOTE { return Verdict::Bad("note too long"); }
    if !valid_name(name) { return Verdict::Bad("bad key name"); }
    if note.chars().any(|c| (c as u32) < 0x20 && c != '\n') { return Verdict::Bad("control character"); }
    let Some(split) = note.rfind("\n\n") else { return Verdict::Bad("no blank line before signatures") };
    let (text, sigs) = (&note[..split + 1], &note[split + 2..]);
    if sigs.is_empty() || !sigs.ends_with('\n') { return Verdict::Bad("signature block must end with a newline"); }
    let Some((origin, size, root)) = parse_body(text) else { return Verdict::Bad("not a canonical checkpoint body") };
    if origin != name { return Verdict::Bad("origin is not the key name"); }
    if size != want_size || &root != want_root { return Verdict::Bad("size or root differs from the seal"); }
    let kid = key_id(name, pubkey);
    let (mut n_sigs, mut good) = (0usize, false);
    let mut seen: Vec<&str> = Vec::new();
    for line in sigs.strip_suffix('\n').unwrap().split('\n') {
        n_sigs += 1;
        if n_sigs > MAX_SIGS { return Verdict::Bad("too many signature lines"); }
        let Some(rest) = line.strip_prefix(EM_DASH) else { return Verdict::Bad("signature line must start with an em dash and a space") };
        let Some((sname, b64)) = rest.split_once(' ') else { return Verdict::Bad("signature line needs name and signature") };
        if !valid_name(sname) { return Verdict::Bad("bad signer name"); }
        let Some(raw) = b64_dec(b64) else { return Verdict::Bad("signature is not canonical base64") };
        if raw.len() < 5 { return Verdict::Bad("signature too short"); }
        if sname != name || raw[..4] != kid { continue; } // someone else's key: ignored, as the spec says
        if seen.contains(&line) { continue; }
        seen.push(line);
        let Ok(sig) = <[u8; 64]>::try_from(&raw[4..]) else { return Verdict::Bad("Ed25519 signature must be 64 bytes") };
        if !verify_sig(text.as_bytes(), &sig) { return Verdict::Bad("signature does not verify"); }
        good = true;
    }
    if good { Verdict::Ok } else { Verdict::Bad("no signature from the audit-log key") }
}

/// Text form for the kernel ABI (plain strings in, one bit out). Public key and root: 64 lowercase hex. Size: canonical decimal. Anything else = false.
pub fn verify_text(note: &str, name: &str, pub_hex: &str, size: &str, root_hex: &str, verify_sig: &dyn Fn(&[u8], &[u8; 64]) -> bool) -> bool {
    fn h32(s: &str) -> Option<[u8; 32]> {
        let b = s.as_bytes();
        if b.len() != 64 { return None; }
        let n = |c: u8| match c { b'0'..=b'9' => Some(c - b'0'), b'a'..=b'f' => Some(c - b'a' + 10), _ => None };
        let mut o = [0u8; 32];
        for i in 0..32 { o[i] = n(b[2 * i])? << 4 | n(b[2 * i + 1])?; }
        Some(o)
    }
    let (Some(p), Some(r)) = (h32(pub_hex), h32(root_hex)) else { return false };
    if size.is_empty() || !size.bytes().all(|c| c.is_ascii_digit()) || (size.len() > 1 && size.starts_with('0')) { return false; }
    let Ok(size) = size.parse::<u64>() else { return false };
    verify(note, name, &p, size, &r, verify_sig) == Verdict::Ok
}

#[cfg(test)]
mod tests {
    use super::*;
    use ring::signature::{Ed25519KeyPair, UnparsedPublicKey, ED25519};
    use serde_json::Value;

    fn hex(s: &str) -> Vec<u8> { (0..s.len() / 2).map(|i| u8::from_str_radix(&s[2 * i..2 * i + 2], 16).unwrap()).collect() }
    fn arr32(s: &str) -> [u8; 32] { hex(s).try_into().unwrap() }
    fn vecs() -> Value { serde_json::from_str(include_str!("g5b_vectors.json")).unwrap() }
    fn dverify(pubkey: [u8; 32]) -> impl Fn(&[u8], &[u8; 64]) -> bool {
        move |m, s| UnparsedPublicKey::new(&ED25519, pubkey).verify(m, s).is_ok()
    }
    struct SigningKey(Ed25519KeyPair);
    struct Sig([u8; 64]);
    impl Sig { fn to_bytes(&self) -> [u8; 64] { self.0 } }
    impl SigningKey {
        fn from_bytes(seed: &[u8; 32]) -> Self { SigningKey(Ed25519KeyPair::from_seed_unchecked(seed).unwrap()) }
        fn sign(&self, m: &[u8]) -> Sig { Sig(self.0.sign(m).as_ref().try_into().unwrap()) }
    }
    fn judge(note: &str, key: &Value) -> bool {
        let (name, pubk) = (key["name"].as_str().unwrap(), arr32(key["pub_hex"].as_str().unwrap()));
        // size/root are taken from the note itself so that only the signature/format part is judged here
        let Some(split) = note.rfind("\n\n") else { return false };
        let Some((_, size, root)) = parse_body(&note[..split + 1]) else { return false };
        verify(note, name, &pubk, size, &root, &dverify(pubk)) == Verdict::Ok
    }

    #[test]
    fn key_ids_match_go() {
        let v = vecs();
        for k in v["keys"].as_array().unwrap() {
            let id = key_id(k["name"].as_str().unwrap(), &arr32(k["pub_hex"].as_str().unwrap()));
            assert_eq!(id.iter().map(|b| format!("{b:02x}")).collect::<String>(), k["key_id_hex"].as_str().unwrap());
        }
    }
    #[test]
    fn go_signed_notes_verify_and_our_signing_is_byte_identical() {
        let v = vecs();
        let keys = v["keys"].as_array().unwrap();
        for x in v["vectors"].as_array().unwrap() {
            let k = &keys[x["key"].as_u64().unwrap() as usize];
            let (name, pubk) = (k["name"].as_str().unwrap(), arr32(k["pub_hex"].as_str().unwrap()));
            let (size, root) = (x["size"].as_u64().unwrap(), arr32(x["root_hex"].as_str().unwrap()));
            let note = x["note"].as_str().unwrap();
            assert_eq!(verify(note, name, &pubk, size, &root, &dverify(pubk)), Verdict::Ok, "Go note must verify: {note:?}");
            // our own signing: same seed, same body, must give Go's exact bytes (Ed25519 is deterministic)
            let sk = SigningKey::from_bytes(&arr32(k["seed_hex"].as_str().unwrap()));
            let b = body(name, size, &root);
            let line = sig_line(name, &pubk, &sk.sign(b.as_bytes()).to_bytes());
            assert_eq!(assemble(&b, &[line]), note, "byte-identical with Go");
            // wrong expectation is refused
            assert!(matches!(verify(note, name, &pubk, size.wrapping_add(1), &root, &dverify(pubk)), Verdict::Bad(_)));
            let mut r2 = root; r2[0] ^= 1;
            assert!(matches!(verify(note, name, &pubk, size, &r2, &dverify(pubk)), Verdict::Bad(_)));
        }
    }
    #[test]
    fn every_mutation_agrees_with_go_or_is_stricter() {
        let v = vecs();
        let k = &v["keys"][0];
        let (mut agree, mut stricter) = (0, 0);
        for m in v["mutations"].as_array().unwrap() {
            let go = m["go_verifies"].as_bool().unwrap();
            let ours = judge(m["note"].as_str().unwrap(), k);
            assert!(!(ours && !go), "we accepted what Go refused: {}", m["why"]);
            if go == ours { agree += 1 } else { stricter += 1; eprintln!("stricter than Go: {}", m["why"]) }
        }
        assert!(agree > 200, "agree={agree} stricter={stricter}");
        assert!(stricter <= 1, "only the intended differences allowed, got {stricter}");
    }
    #[test]
    fn published_go_example_parses_but_is_not_ours() {
        // the PeterNeumann note is Go's published vector: our verifier must refuse it for our key (different name/origin) without panicking
        let p = &vecs()["published"];
        assert!(p["go_verifies"].as_bool().unwrap());
        let k = &vecs()["keys"][0];
        assert!(!judge(p["note"].as_str().unwrap(), k));
    }
    #[test]
    fn unknown_key_ignored_known_bad_rejected_dupes_dropped() {
        let v = vecs();
        let (k0, k1) = (&v["keys"][0], &v["keys"][1]);
        let (n0, p0) = (k0["name"].as_str().unwrap(), arr32(k0["pub_hex"].as_str().unwrap()));
        let (n1, p1) = (k1["name"].as_str().unwrap(), arr32(k1["pub_hex"].as_str().unwrap()));
        let (s0, s1) = (SigningKey::from_bytes(&arr32(k0["seed_hex"].as_str().unwrap())), SigningKey::from_bytes(&arr32(k1["seed_hex"].as_str().unwrap())));
        let root = [7u8; 32];
        let b = body(n0, 9, &root);
        let l0 = sig_line(n0, &p0, &s0.sign(b.as_bytes()).to_bytes());
        let l1 = sig_line(n1, &p1, &s1.sign(b.as_bytes()).to_bytes());
        let ver = |note: &str| verify(note, n0, &p0, 9, &root, &dverify(p0));
        assert_eq!(ver(&assemble(&b, &[l1.clone(), l0.clone()])), Verdict::Ok, "a stranger's signature next to ours is ignored");
        assert_eq!(ver(&assemble(&b, &[l0.clone(), l0.clone()])), Verdict::Ok, "identical repeat dropped");
        assert!(matches!(ver(&assemble(&b, &[l1.clone()])), Verdict::Bad(_)), "only a stranger signed");
        let bad = sig_line(n0, &p0, &s1.sign(b.as_bytes()).to_bytes()); // right key id, wrong key's signature
        assert!(matches!(ver(&assemble(&b, &[bad, l0.clone()])), Verdict::Bad("signature does not verify")), "known key bad sig kills the note even when a good one follows");
        let many: Vec<String> = (0..17).map(|_| l1.clone()).collect();
        assert!(matches!(ver(&assemble(&b, &many)), Verdict::Bad("too many signature lines")));
    }
    #[test]
    fn strict_format_negatives() {
        let v = vecs();
        let k = &v["keys"][0];
        let (n, p) = (k["name"].as_str().unwrap(), arr32(k["pub_hex"].as_str().unwrap()));
        let s = SigningKey::from_bytes(&arr32(k["seed_hex"].as_str().unwrap()));
        let root = [1u8; 32];
        let ok = |b: &str| { let l = sig_line(n, &p, &s.sign(b.as_bytes()).to_bytes()); verify(&assemble(b, &[l]), n, &p, 5, &root, &dverify(p)) };
        let rb = b64_enc(&root);
        assert_eq!(ok(&format!("{n}\n5\n{rb}\n")), Verdict::Ok);
        assert!(matches!(ok(&format!("{n}\n05\n{rb}\n")), Verdict::Bad(_)), "leading zero");
        assert!(matches!(ok(&format!("{n}\n+5\n{rb}\n")), Verdict::Bad(_)));
        assert!(matches!(ok(&format!("{n}\n5\n{rb}\nextension\n")), Verdict::Bad(_)), "extension line");
        assert!(matches!(ok(&format!("other\n5\n{rb}\n")), Verdict::Bad(_)), "origin != key name");
        assert!(matches!(ok(&format!("{n}\n5\n{}\n", b64_enc(&root[..31]))), Verdict::Bad(_)), "31-byte root");
        assert!(matches!(ok(&format!("{n}\n18446744073709551616\n{rb}\n")), Verdict::Bad(_)), "u64 overflow");
        assert!(matches!(verify("", n, &p, 5, &root, &dverify(p)), Verdict::Bad(_)));
        assert!(matches!(verify(&"a".repeat(MAX_NOTE + 1), n, &p, 5, &root, &dverify(p)), Verdict::Bad(_)));
    }
    #[test]
    fn base64_is_canonical_only() {
        for len in 0..40usize {
            let d: Vec<u8> = (0..len as u8).map(|x| x.wrapping_mul(37).wrapping_add(11)).collect();
            if len > 0 { assert_eq!(b64_dec(&b64_enc(&d)).unwrap(), d); }
        }
        assert!(b64_dec("QQ==").is_some() && b64_dec("QR==").is_none(), "non-zero trailing bits");
        assert!(b64_dec("QUI=").is_some() && b64_dec("QUJ=").is_none());
        assert!(b64_dec("QQ=").is_none() && b64_dec("Q===").is_none() && b64_dec("=QQQ").is_none() && b64_dec("QQ==QQ==").is_none());
        assert!(b64_dec("QQ.=").is_none() && b64_dec("").is_none() && b64_dec("QUJD ").is_none());
    }
}
