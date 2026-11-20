//! DK-a parity: every golden case was made by the SERVER's real fmail_core::summarize() + render(); the kernel module mailparse@1 must give the SAME JSON, value for value.
use anexo_kernel::mailparse;

#[test]
fn the_kernel_reads_every_mail_exactly_like_the_server() {
    let cases: Vec<serde_json::Value> = serde_json::from_str(&std::fs::read_to_string("tests/mail_golden.json").unwrap()).unwrap();
    assert!(cases.len() >= 9);
    for c in &cases {
        let raw: Vec<u8> = { let h = c["raw"].as_str().unwrap(); (0..h.len() / 2).map(|i| u8::from_str_radix(&h[2 * i..2 * i + 2], 16).unwrap()).collect() };
        let got: serde_json::Value = serde_json::from_str(&mailparse::parse_json(&raw)).unwrap();
        assert_eq!(got["summary"], c["summary"], "summary of case {}", c["name"]);
        assert_eq!(got["view"], c["view"], "view of case {}", c["name"]);
    }
}
#[test]
fn the_reply_fields_the_screen_needs_come_out() {
    let cases: Vec<serde_json::Value> = serde_json::from_str(&std::fs::read_to_string("tests/mail_golden.json").unwrap()).unwrap();
    let find = |n: &str| cases.iter().find(|c| c["name"] == n).unwrap();
    assert_eq!(find("thread")["summary"]["references"], serde_json::json!(["m1@x.org", "m2@x.org"]));
    assert_eq!(find("thread")["summary"]["reply_to"], serde_json::json!(["desk@x.org", "other@y.org"]));
    assert_eq!(find("many_references")["summary"]["references"].as_array().unwrap().len(), 40);
    assert_eq!(find("html_only")["view"]["remote_content_blocked"], true);
    assert_eq!(find("multipart_attachment")["view"]["attachments"][0]["name"], "usd.pdf");
}
