// Opt-in integration check: synthetic mono 16 kHz little-endian f32 samples.
// The test never downloads a model or opens a microphone.
#[path = "../src/models.rs"]
#[allow(dead_code)]
mod models;

#[path = "../src/engine.rs"]
mod engine;

#[test]
#[ignore = "requires DICTATE_SMOKE_DIR with a verified tiny model and synthetic.f32"]
fn recognizes_synthetic_audio_offline() {
    use std::sync::{atomic::AtomicBool, Arc};
    let dir = std::path::PathBuf::from(std::env::var("DICTATE_SMOKE_DIR").unwrap());
    let bytes = std::fs::read(dir.join("synthetic.f32")).unwrap();
    assert_eq!(bytes.len() % 4, 0);
    let samples = bytes
        .chunks_exact(4)
        .map(|v| f32::from_le_bytes(v.try_into().unwrap()))
        .collect::<Vec<_>>();
    for id in ["tiny", "parakeet"] {
        let mut engine = models::load(&dir, id).unwrap();
        let text = engine
            .transcribe(&samples, "", Arc::new(AtomicBool::new(false)))
            .unwrap()
            .to_lowercase();
        assert!(
            text.contains("local dictation"),
            "Synthetic speech was not recognized as expected"
        );
        assert!(
            text.contains("computer"),
            "Synthetic speech was not recognized as expected"
        );
    }
}
