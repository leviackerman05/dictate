// Opt-in integration check: synthetic mono 16 kHz little-endian f32 samples.
// The test never downloads a model or opens a microphone.
#[path = "../src/models.rs"]
#[allow(dead_code)]
mod models;

#[test]
#[ignore = "requires DICTATE_SMOKE_DIR with a verified tiny model and synthetic.f32"]
fn recognizes_synthetic_audio_offline() {
    use whisper_rs::{FullParams, SamplingStrategy};
    let dir = std::path::PathBuf::from(std::env::var("DICTATE_SMOKE_DIR").unwrap());
    let bytes = std::fs::read(dir.join("synthetic.f32")).unwrap();
    assert_eq!(bytes.len() % 4, 0);
    let samples = bytes
        .chunks_exact(4)
        .map(|v| f32::from_le_bytes(v.try_into().unwrap()))
        .collect::<Vec<_>>();
    let context = models::load(&dir, "tiny").unwrap();
    let mut state = context.create_state().unwrap();
    let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
    params.set_language(None);
    params.set_n_threads(4);
    params.set_no_context(true);
    params.set_print_progress(false);
    params.set_print_realtime(false);
    params.set_print_timestamps(false);
    state.full(params, &samples).unwrap();
    let text = state
        .as_iter()
        .map(|s| s.to_str().unwrap().to_owned())
        .collect::<Vec<_>>()
        .join(" ")
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
