//! DK-a cross-proof: a vector made by the SERVER's real fmail_kem::wrap + fmail_seal::seal (server/founder/src/fmail_kem.rs test emit_kem_vector)
//! must open in the kernel module kemopen@1, byte for byte, and tampering must be refused.
use anexo_kernel::kemopen;

fn vector() -> serde_json::Value { serde_json::from_str(&std::fs::read_to_string("tests/kem_vector.json").unwrap()).unwrap() }

#[test]
fn the_kernel_opens_what_the_server_sealed() {
    let v = vector();
    let (ok, plain) = kemopen::open_json(&v.to_string());
    assert!(ok, "{}", String::from_utf8_lossy(&plain));
    assert_eq!(String::from_utf8(plain).unwrap(), v["plain"].as_str().unwrap());
}
#[test]
fn a_changed_vector_is_refused() {
    let v = vector();
    for (field, from, to) in [("sealed", 0usize, 1usize), ("wrap", 2, 3), ("nonce", 0, 1)] {
        let mut w = v.clone();
        let s = w[field].as_str().unwrap().to_string();
        let mut b = s.into_bytes(); b[from] = if b[from] == b'0' { b'1' } else { b'0' }; let _ = to;
        w[field] = serde_json::Value::String(String::from_utf8(b).unwrap());
        assert!(!kemopen::open_json(&w.to_string()).0, "tamper {field}");
    }
    let mut w = v.clone(); w["key_id"] = "other".into(); assert!(!kemopen::open_json(&w.to_string()).0);
    let mut w = v.clone(); w["aad"] = serde_json::json!(["body", "mbx-vector", "out"]); assert!(!kemopen::open_json(&w.to_string()).0);
}
