use crate::engine::SpeechEngine;
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
    #[serde(skip)]
    pub files: &'static [ModelFile],
}
#[derive(Clone)]
pub struct ModelFile {
    pub file: &'static str,
    pub bytes: u64,
    pub sha256: &'static str,
}
pub const PARAKEET_REVISION: &str = "8f23f0c03c8761650bdb5b40aaf3e40d2c15f1ce";
pub const MODELS: [Model; 4] = [
    Model {
        id: "tiny",
        name: "Whisper Tiny",
        bytes: 77691713,
        files: &[ModelFile {
            file: "ggml-tiny.bin",
            bytes: 77691713,
            sha256: "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21",
        }],
    },
    Model {
        id: "base",
        name: "Whisper Base",
        bytes: 147951465,
        files: &[ModelFile {
            file: "ggml-base.bin",
            bytes: 147951465,
            sha256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
        }],
    },
    Model {
        id: "small",
        name: "Whisper Small",
        bytes: 487601967,
        files: &[ModelFile {
            file: "ggml-small.bin",
            bytes: 487601967,
            sha256: "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b",
        }],
    },
    Model {
        id: "parakeet",
        name: "NVIDIA Parakeet v3",
        bytes: 670479942,
        files: &[
            ModelFile {
                file: "encoder-model.int8.onnx",
                bytes: 652183999,
                sha256: "6139d2fa7e1b086097b277c7149725edbab89cc7c7ae64b23c741be4055aff09",
            },
            ModelFile {
                file: "decoder_joint-model.int8.onnx",
                bytes: 18202004,
                sha256: "eea7483ee3d1a30375daedc8ed83e3960c91b098812127a0d99d1c8977667a70",
            },
            ModelFile {
                file: "vocab.txt",
                bytes: 93939,
                sha256: "d58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d",
            },
        ],
    },
];
pub fn model(id: &str) -> Result<&'static Model, String> {
    MODELS
        .iter()
        .find(|m| m.id == id)
        .ok_or("Unknown model.".into())
}
pub fn path(dir: &Path, id: &str) -> Result<PathBuf, String> {
    let m = model(id)?;
    Ok(dir.join("models").join(if id == "parakeet" {
        "parakeet"
    } else {
        m.files[0].file
    }))
}
fn component_path(dir: &Path, m: &Model, file: &ModelFile) -> PathBuf {
    if m.id == "parakeet" {
        dir.join("models/parakeet").join(file.file)
    } else {
        dir.join("models").join(file.file)
    }
}
pub fn is_installed(dir: &Path, id: &str) -> bool {
    model(id).is_ok_and(|m| {
        m.files
            .iter()
            .all(|f| std::fs::metadata(component_path(dir, m, f)).is_ok_and(|s| s.len() == f.bytes))
    })
}
pub fn verify(path: &Path, m: &ModelFile) -> Result<(), String> {
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
pub fn load(dir: &Path, id: &str) -> Result<SpeechEngine, String> {
    // Upstream debug logs can include decoded tokens. No log backend is enabled;
    // these hooks suppress whisper.cpp and GGML output even in developer builds.
    whisper_rs::install_logging_hooks();
    let m = model(id)?;
    let file = path(dir, id)?;
    for component in m.files {
        verify(&component_path(dir, m, component), component)?;
    }
    if id == "parakeet" {
        crate::engine::prepare_runtime()?;
        return parakeet_rs::ParakeetTDT::from_pretrained(&file, None)
            .map(|engine| SpeechEngine::Parakeet(Box::new(engine)))
            .map_err(|e| {
                format!("Parakeet could not load. Close memory-heavy apps and retry: {e}")
            });
    }
    let mut params = WhisperContextParameters::default();
    params.use_gpu(false);
    WhisperContext::new_with_params(file.to_string_lossy().as_ref(), params)
        .map(SpeechEngine::Whisper)
        .map_err(|e| format!("Model could not load on this computer: {e}"))
}
pub async fn download(
    app: &tauri::AppHandle,
    dir: &Path,
    id: &str,
    cancel: Arc<AtomicBool>,
) -> Result<(), String> {
    let m = model(id)?;
    let client = reqwest::Client::builder()
        .https_only(true)
        .connect_timeout(std::time::Duration::from_secs(20))
        .timeout(std::time::Duration::from_secs(1800))
        .build()
        .map_err(|e| e.to_string())?;
    let mut completed = 0u64;
    for file in m.files {
        if cancel.load(Ordering::SeqCst) {
            return Err("Model setup cancelled.".into());
        }
        let dest = component_path(dir, m, file);
        std::fs::create_dir_all(dest.parent().unwrap()).map_err(|e| e.to_string())?;
        if verify(&dest, file).is_ok() {
            completed += file.bytes;
            continue;
        }
        let mut partial =
            tempfile::NamedTempFile::new_in(dest.parent().unwrap()).map_err(|e| e.to_string())?;
        let url = if id == "parakeet" {
            format!("https://huggingface.co/istupakov/parakeet-tdt-0.6b-v3-onnx/resolve/{PARAKEET_REVISION}/{}",file.file)
        } else {
            format!(
                "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/{}",
                file.file
            )
        };
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
            let chunk = match tokio::time::timeout(std::time::Duration::from_secs(1), stream.next())
                .await
            {
                Ok(Some(chunk)) => chunk,
                Ok(None) => break,
                Err(_) if !cancel.load(Ordering::SeqCst) => continue,
                Err(_) => return Err("Model setup cancelled.".into()),
            };
            if cancel.load(Ordering::SeqCst) {
                return Err("Model setup cancelled.".into());
            }
            let chunk =
                chunk.map_err(|_| "Download interrupted. Reconnect and retry.".to_string())?;
            size += chunk.len() as u64;
            if size > file.bytes {
                return Err("Unexpected model size; download rejected.".into());
            }
            partial
                .write_all(&chunk)
                .map_err(|_| "Not enough writable storage for this model.".to_string())?;
            if last.elapsed().as_millis() > 150 {
                let _=app.emit("model-progress",serde_json::json!({"id":id,"progress":(completed+size) as f64/m.bytes as f64,"stage":"downloading"}));
                last = std::time::Instant::now();
            }
        }
        partial.flush().map_err(|e| e.to_string())?;
        verify(partial.path(), file)?;
        if cancel.load(Ordering::SeqCst) {
            return Err("Model setup cancelled.".into());
        }
        partial.as_file().sync_all().map_err(|e| e.to_string())?;
        partial.persist(&dest).map_err(|e| e.to_string())?;
        completed += file.bytes;
    }
    Ok(())
}
