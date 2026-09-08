fn main() {
    let target = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    assert!(target == "windows" || target == "macos",
        "Dictate currently supports Mac and Windows only. Linux support is paused.");
    tauri_build::build()
}
