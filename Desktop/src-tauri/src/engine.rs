//! Offline recognition adapters. No transcript or audio is sent to a service.
use parakeet_rs::{ParakeetTDT, Transcriber};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};
use whisper_rs::{FullParams, SamplingStrategy, WhisperContext};
pub enum SpeechEngine {
    Whisper(WhisperContext),
    Parakeet(Box<ParakeetTDT>),
}
impl SpeechEngine {
    pub fn transcribe(
        &mut self,
        samples: &[f32],
        vocabulary: &str,
        cancel: Arc<AtomicBool>,
    ) -> Result<String, String> {
        if cancel.load(Ordering::SeqCst) {
            return Ok(String::new());
        }
        let mut parts = Vec::new();
        match self {
            Self::Whisper(context) => {
                let mut inference = context.create_state().map_err(|e| e.to_string())?;
                let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
                params.set_n_threads(
                    std::thread::available_parallelism()
                        .map(|v| v.get().min(8) as i32)
                        .unwrap_or(2),
                );
                params.set_language(None);
                params.set_translate(false);
                params.set_no_context(true);
                params.set_print_progress(false);
                params.set_print_realtime(false);
                params.set_print_timestamps(false);
                params.set_print_special(false);
                if !vocabulary.is_empty() {
                    params.set_initial_prompt(vocabulary);
                }
                params.set_abort_callback_safe(move || cancel.load(Ordering::SeqCst));
                inference.full(params, samples).map_err(|e| e.to_string())?;
                for segment in inference.as_iter() {
                    parts.push(segment.to_str().map_err(|e| e.to_string())?.to_string());
                }
            }
            Self::Parakeet(engine) => {
                // Bound attention memory on ordinary PCs. Cancellation is checked
                // between chunks; an in-flight ONNX inference must finish first.
                for chunk in samples.chunks(30 * 16000) {
                    if cancel.load(Ordering::SeqCst) {
                        return Ok(String::new());
                    }
                    parts.push(
                        engine
                            .transcribe_samples(chunk.to_vec(), 16000, 1, None)
                            .map_err(|e| e.to_string())?
                            .text,
                    );
                }
            }
        }
        Ok(dictate_core::normalize(&parts.join(" ")))
    }
}
