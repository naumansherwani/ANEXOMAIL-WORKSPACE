// SYS-LIVE: the install script exports ANX_BUILD (repo commit) and ANX_BUILD_TIME so the running binary can tell the page exactly which commit it was built from. Without them the pulse says "unknown", never a guess.
fn main() {
    println!("cargo:rerun-if-env-changed=ANX_BUILD");
    println!("cargo:rerun-if-env-changed=ANX_BUILD_TIME");
}
