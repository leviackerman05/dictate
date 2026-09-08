use futures_util::StreamExt;
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::{
    io::{Read, Write},
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
};
use tauri::Emitter;
use whisper_rs::{WhisperContext, WhisperContextParameters};

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Model {
    pub id: &'static str,
    pub name: &'static str,
    pub bytes: u64,
    pub sha256: &'static str,
    pub file: &'static str,
}
pub const MODELS: [Model; 3] = [
    Model {
        id: "tiny",
        name: "Whisper Tiny · multilingual",
        bytes: 77691713,
        sha256: "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21",
        file: "ggml-tiny.bin",
    },
    Model {
        id: "base",
        name: "Whisper Base · multilingual",
        bytes: 147951465,
        sha256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
        file: "ggml-base.bin",
    },
    Model {
        id: "small",
        name: "Whisper Small · multilingual",
        bytes: 487601967,
        sha256: "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b",
        file: "ggml-small.bin",
    },
];
pub fn model(id: &str) -> Result<&'static Model, String> {
    MODELS
        .iter()
        .find(|m| m.id == id)
        .ok_or("Unknown model.".into())
}
pub fn path(dir: &Path, id: &str) -> Result<PathBuf, String> {
    Ok(dir.join("models").join(model(id)?.file))
}
pub fn verify(path: &Path, m: &Model) -> Result<(), String> {
    let mut file = std::fs::File::open(path).map_err(|e| e.to_string())?;
    if file.metadata().map_err(|e| e.to_string())?.len() != m.bytes {
        return Err("Model download is incomplete. Download it again.".into());
    }
    let mut digest = Sha256::new();
    let mut buffer = [0u8; 65536];
    loop {
        let n = file.read(&mut buffer).map_err(|e| e.to_string())?;
        if n == 0 {
            break;
        }
        digest.update(&buffer[..n]);
    }
    if format!("{:x}", digest.finalize()) != m.sha256 {
        return Err("Model checksum failed. Download it again.".into());
    }
    Ok(())
}
pub fn load(dir: &Path, id: &str) -> Result<WhisperContext, String> {
    // Upstream debug logs can include decoded tokens. No log backend is enabled;
    // these hooks suppress whisper.cpp and GGML output even in developer builds.
    whisper_rs::install_logging_hooks();
    let m = model(id)?;
    let file = path(dir, id)?;
    verify(&file, m)?;
    let mut params = WhisperContextParameters::default();
    params.use_gpu(false);
    WhisperContext::new_with_params(file.to_string_lossy().as_ref(), params)
        .map_err(|e| format!("Model could not load on this computer: {e}"))
}
pub async fn download(
    app: &tauri::AppHandle,
    dir: &Path,
    id: &str,
    cancel: Arc<AtomicBool>,
) -> Result<(), String> {
    let m = model(id)?;
    let dest = path(dir, id)?;
    std::fs::create_dir_all(dest.parent().unwrap()).map_err(|e| e.to_string())?;
    if verify(&dest, m).is_ok() {
        return Ok(());
    }
    let mut partial =
        tempfile::NamedTempFile::new_in(dest.parent().unwrap()).map_err(|e| e.to_string())?;
    let client = reqwest::Client::builder()
        .https_only(true)
        .connect_timeout(std::time::Duration::from_secs(20))
        .timeout(std::time::Duration::from_secs(1800))
        .build()
        .map_err(|e| e.to_string())?;
    let url = format!(
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/{}",
        m.file
    );
    let response = client
        .get(url)
        .send()
        .await
        .map_err(|_| {
            "Could not reach the model download. Check your connection or work network policy."
                .to_string()
        })?
        .error_for_status()
        .map_err(|e| e.to_string())?;
    let mut stream = response.bytes_stream();
    let mut size = 0u64;
    let mut last = std::time::Instant::now();
    loop {
        let chunk =
            match tokio::time::timeout(std::time::Duration::from_secs(1), stream.next()).await {
                Ok(Some(chunk)) => chunk,
                Ok(None) => break,
                Err(_) if !cancel.load(Ordering::SeqCst) => continue,
                Err(_) => return Err("Model setup cancelled.".into()),
            };
        if cancel.load(Ordering::SeqCst) {
            return Err("Model setup cancelled.".into());
        }
        let chunk = chunk.map_err(|_| "Download interrupted. Reconnect and retry.".to_string())?;
        size += chunk.len() as u64;
        if size > m.bytes {
            return Err("Unexpected model size; download rejected.".into());
        }
        partial
            .write_all(&chunk)
            .map_err(|_| "Not enough writable storage for this model.".to_string())?;
        if last.elapsed().as_millis() > 150 {
            let _=app.emit("model-progress",serde_json::json!({"id":id,"progress":size as f64/m.bytes as f64,"stage":"downloading"}));
            last = std::time::Instant::now();
        }
    }
    partial.flush().map_err(|e| e.to_string())?;
    verify(partial.path(), m)?;
    if cancel.load(Ordering::SeqCst) {
        return Err("Model setup cancelled.".into());
    }
    partial.as_file().sync_all().map_err(|e| e.to_string())?;
    partial.persist(&dest).map_err(|e| e.to_string())?;
    Ok(())
}
