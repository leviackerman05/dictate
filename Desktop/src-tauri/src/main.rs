#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
mod audio;
mod delivery;
#[cfg(target_os = "linux")]
mod linux_delivery;
mod models;

use chrono::Utc;
use dictate_core::*;
use serde::{Deserialize, Serialize};
use std::{
    path::PathBuf,
    sync::{
        atomic::{AtomicBool, AtomicU64, Ordering},
        Arc, Mutex,
    },
};
use tauri::{Emitter, Manager};
use tauri_plugin_global_shortcut::{GlobalShortcutExt, ShortcutState};
use uuid::Uuid;
use whisper_rs::{FullParams, SamplingStrategy, WhisperContext};

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
struct Preferences {
    model: String,
    keep_history: bool,
    retention: String,
    recording_mode: String,
    shortcut: String,
    appearance: String,
    onboarding_done: bool,
    auto_insert: bool,
}
impl Default for Preferences {
    fn default() -> Self {
        Self {
            model: "tiny".into(),
            keep_history: true,
            retention: "forever".into(),
            recording_mode: "holdToTalk".into(),
            shortcut: "CommandOrControl+Shift+Space".into(),
            appearance: "system".into(),
            onboarding_done: false,
            auto_insert: true,
        }
    }
}
#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Data {
    schema_version: u32,
    preferences: Preferences,
    history: Vec<HistoryItem>,
    dictionary: Vec<DictionaryEntry>,
    recovery: Option<String>,
}
impl Default for Data {
    fn default() -> Self {
        Self {
            schema_version: 1,
            preferences: Preferences::default(),
            history: vec![],
            dictionary: vec![],
            recovery: None,
        }
    }
}
struct Runtime {
    data: Mutex<Data>,
    dir: PathBuf,
    audio: audio::Audio,
    clipboard: delivery::Clipboard,
    engine: Mutex<Option<(String, WhisperContext)>>,
    phase: Mutex<Phase>,
    gesture: Mutex<ShortcutGesture>,
    cancel: Arc<AtomicBool>,
    setup_cancel: Arc<AtomicBool>,
    setting_up: AtomicBool,
    generation: AtomicU64,
    notice: Mutex<Option<String>>,
    shortcut_error: Mutex<Option<String>>,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ViewState {
    data: Data,
    phase: Phase,
    models: Vec<models::Model>,
    installed: Vec<String>,
    ready: bool,
    setting_up: bool,
    notice: Option<String>,
    shortcut_error: Option<String>,
    capability: String,
    platform: String,
    version: String,
}
impl Runtime {
    fn persist(&self, data: &Data) -> Result<(), String> {
        atomic_save(&self.dir.join("data.json"), data)
    }
    fn notice(&self, text: impl Into<String>) {
        *self.notice.lock().unwrap() = Some(text.into());
    }
}
fn changed(app: &tauri::AppHandle) {
    let _ = app.emit("state-changed", ());
}
#[tauri::command]
fn get_state(state: tauri::State<Runtime>) -> ViewState {
    let data = state.data.lock().unwrap().clone();
    let ready = state.engine.try_lock().ok().is_some_and(|e| {
        e.as_ref()
            .is_some_and(|(id, _)| id == &data.preferences.model)
    });
    let installed = models::MODELS
        .iter()
        .filter(|m| {
            models::path(&state.dir, m.id)
                .ok()
                .and_then(|p| std::fs::metadata(p).ok())
                .is_some_and(|f| f.len() == m.bytes)
        })
        .map(|m| m.id.to_string())
        .collect();
    ViewState {
        data,
        phase: *state.phase.lock().unwrap(),
        models: models::MODELS.to_vec(),
        installed,
        ready,
        setting_up: state.setting_up.load(Ordering::SeqCst),
        notice: state.notice.lock().unwrap().clone(),
        shortcut_error: state.shortcut_error.lock().unwrap().clone(),
        capability: delivery::capability().into(),
        platform: std::env::consts::OS.into(),
        version: env!("CARGO_PKG_VERSION").into(),
    }
}

#[tauri::command]
async fn setup_model(app: tauri::AppHandle, id: String, download: bool) -> Result<(), String> {
    let state = app.state::<Runtime>();
    models::model(&id)?;
    if *state.phase.lock().unwrap() != Phase::Idle {
        return Err("Finish recording before changing models.".into());
    }
    if state.setting_up.swap(true, Ordering::SeqCst) {
        return Err("Model setup is already running.".into());
    }
    state.setup_cancel.store(false, Ordering::SeqCst);
    *state.notice.lock().unwrap() = None;
    changed(&app);
    let dir = state.dir.clone();
    let cancel = state.setup_cancel.clone();
    let result = async {
        if download {
            models::download(&app, &dir, &id, cancel.clone()).await?;
        }
        if cancel.load(Ordering::SeqCst) {
            return Err("Model setup cancelled.".into());
        }
        let _ = app.emit(
            "model-progress",
            serde_json::json!({"id":id,"stage":"loading","progress":1}),
        );
        let load_id = id.clone();
        let engine = tauri::async_runtime::spawn_blocking(move || models::load(&dir, &load_id))
            .await
            .map_err(|e| e.to_string())??;
        if cancel.load(Ordering::SeqCst) {
            return Err("Model setup cancelled.".into());
        }
        let mut data = state.data.lock().unwrap();
        let mut next = data.clone();
        next.preferences.model = id.clone();
        state.persist(&next)?;
        *data = next;
        *state.engine.lock().unwrap() = Some((id, engine));
        Ok(())
    }
    .await;
    if let Err(ref error) = result {
        state.notice(error);
    }
    state.setting_up.store(false, Ordering::SeqCst);
    changed(&app);
    result
}
#[tauri::command]
fn cancel_setup(app: tauri::AppHandle) {
    app.state::<Runtime>()
        .setup_cancel
        .store(true, Ordering::SeqCst);
    changed(&app);
}
#[tauri::command]
fn remove_model(app: tauri::AppHandle, id: String) -> Result<(), String> {
    let state = app.state::<Runtime>();
    if state.setting_up.load(Ordering::SeqCst) || *state.phase.lock().unwrap() != Phase::Idle {
        return Err("Finish the current operation first.".into());
    }
    let path = models::path(&state.dir, &id)?;
    let mut engine = state.engine.lock().unwrap();
    if engine.as_ref().is_some_and(|(m, _)| m == &id) {
        *engine = None;
    }
    if path.exists() {
        std::fs::remove_file(path).map_err(|e| e.to_string())?;
    }
    changed(&app);
    Ok(())
}

#[tauri::command]
async fn start_recording(app: tauri::AppHandle) -> Result<(), String> {
    let state = app.state::<Runtime>();
    let id = {
        let mut phase = state.phase.lock().unwrap();
        if *phase != Phase::Idle {
            return Err("A recording is already in progress.".into());
        }
        if state.setting_up.load(Ordering::SeqCst) {
            return Err("Wait for model setup to finish.".into());
        }
        let data = state.data.lock().unwrap();
        if data.recovery.is_some() {
            return Err(
                "Copy or dismiss your recovered transcript before starting another.".into(),
            );
        }
        if !state
            .engine
            .lock()
            .unwrap()
            .as_ref()
            .is_some_and(|(m, _)| m == &data.preferences.model)
        {
            return Err("Set up a local model first.".into());
        }
        state.cancel.store(false, Ordering::SeqCst);
        *phase = Phase::Preparing;
        state.generation.fetch_add(1, Ordering::SeqCst) + 1
    };
    *state.notice.lock().unwrap() = None;
    changed(&app);
    let handle = app.clone();
    let result =
        tauri::async_runtime::spawn_blocking(move || handle.state::<Runtime>().audio.start())
            .await
            .map_err(|e| e.to_string())
            .and_then(|result| result);
    if let Err(error) = result {
        state.audio.cancel();
        *state.phase.lock().unwrap() = Phase::Idle;
        state.notice(&error);
        changed(&app);
        return Err(error);
    }
    if state.generation.load(Ordering::SeqCst) != id {
        state.audio.cancel();
        return Ok(());
    }
    *state.phase.lock().unwrap() = Phase::Listening;
    if let Some(overlay) = app.get_webview_window("overlay") {
        let _ = overlay.show();
    }
    changed(&app);
    let handle = app.clone();
    tauri::async_runtime::spawn(async move {
        tokio::time::sleep(std::time::Duration::from_secs(600)).await;
        let state = handle.state::<Runtime>();
        if state.generation.load(Ordering::SeqCst) == id
            && *state.phase.lock().unwrap() == Phase::Listening
        {
            let _ = finish_recording(handle.clone()).await;
        }
    });
    Ok(())
}
#[tauri::command]
async fn finish_recording(app: tauri::AppHandle) -> Result<(), String> {
    let state = app.state::<Runtime>();
    {
        let mut phase = state.phase.lock().unwrap();
        if *phase == Phase::Preparing {
            drop(phase);
            cancel_recording(app.clone())?;
            return Ok(());
        }
        if *phase != Phase::Listening {
            return Ok(());
        }
        *phase = Phase::Finalizing;
    }
    let id = state.generation.load(Ordering::SeqCst);
    changed(&app);
    let handle = app.clone();
    let result = tauri::async_runtime::spawn_blocking(move || -> Result<(), String> {
        let state = handle.state::<Runtime>();
        let recording = state.audio.stop()?;
        if recording.samples.len() < recording.rate as usize / 5 {
            return Ok(());
        }
        let energy =
            recording.samples.iter().map(|v| v * v).sum::<f32>() / recording.samples.len() as f32;
        if energy.sqrt() < 0.002 {
            return Ok(());
        }
        let seconds = recording.samples.len() as f64 / recording.rate as f64;
        let samples = resample(&recording.samples, recording.rate);
        let entries = state.data.lock().unwrap().dictionary.clone();
        let original = {
            let engine = state.engine.lock().unwrap();
            let context = &engine.as_ref().ok_or("Load the model before recording.")?.1;
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
            let vocabulary = entries
                .iter()
                .filter(|e| e.is_enabled && e.kind == "vocabulary")
                .take(24)
                .map(|e| e.source_phrase.clone())
                .collect::<Vec<_>>()
                .join(", ");
            if !vocabulary.is_empty() {
                params.set_initial_prompt(&vocabulary);
            }
            let cancel = state.cancel.clone();
            params.set_abort_callback_safe(move || cancel.load(Ordering::SeqCst));
            inference
                .full(params, &samples)
                .map_err(|e| e.to_string())?;
            let mut parts = vec![];
            for segment in inference.as_iter() {
                parts.push(segment.to_str().map_err(|e| e.to_string())?.to_string());
            }
            normalize(&parts.join(" "))
        };
        if state.cancel.load(Ordering::SeqCst)
            || state.generation.load(Ordering::SeqCst) != id
            || original.is_empty()
        {
            return Ok(());
        }
        let (corrected, audits) = correct(&original, &entries);
        let mut phase = state.phase.lock().unwrap();
        if state.cancel.load(Ordering::SeqCst) || state.generation.load(Ordering::SeqCst) != id {
            return Ok(());
        }
        let auto_insert = {
            let mut data = state.data.lock().unwrap();
            data.recovery = Some(corrected.clone());
            state.persist(&data)?;
            data.preferences.auto_insert
        };
        // Recovery is durably committed before any external input is attempted.
        *phase = Phase::Delivering;
        drop(phase);
        changed(&handle);
        let delivery = if auto_insert {
            delivery::insert(&corrected, &state.clipboard)
        } else {
            Err("Your transcript is ready to copy.".into())
        };
        let mut data = state.data.lock().unwrap();
        let outcome = match delivery {
            Ok(()) => {
                data.recovery = None;
                "insertedViaPaste"
            }
            Err(error) => {
                state.notice(error);
                "copiedForRecovery"
            }
        };
        if data.preferences.keep_history {
            data.history.insert(
                0,
                HistoryItem {
                    id: Uuid::new_v4(),
                    timestamp: Utc::now(),
                    original_transcript: original,
                    corrected_text: corrected,
                    duration: seconds,
                    insertion_result: outcome.into(),
                    correction_audit: audits,
                    is_pinned: false,
                },
            );
            let retention = data.preferences.retention.clone();
            retain_history(&mut data.history, &retention, Utc::now());
        }
        state.persist(&data)?;
        Ok(())
    })
    .await
    .map_err(|e| e.to_string())
    .and_then(|result| result);
    if state.generation.load(Ordering::SeqCst) == id {
        *state.phase.lock().unwrap() = Phase::Idle;
    }
    if let Err(ref error) = result {
        if !state.cancel.load(Ordering::SeqCst) {
            state.notice(format!("Recording could not finish: {error}"));
        }
    }
    if let Some(overlay) = app.get_webview_window("overlay") {
        let _ = overlay.hide();
    }
    changed(&app);
    result
}
#[tauri::command]
fn cancel_recording(app: tauri::AppHandle) -> Result<(), String> {
    let state = app.state::<Runtime>();
    let mut phase = state.phase.lock().unwrap();
    if *phase == Phase::Delivering {
        return Err("Delivery is finishing. Check the focused field.".into());
    }
    state.cancel.store(true, Ordering::SeqCst);
    if *phase != Phase::Finalizing {
        state.generation.fetch_add(1, Ordering::SeqCst);
        state.audio.cancel();
        *phase = Phase::Idle;
    }
    drop(phase);
    if let Some(overlay) = app.get_webview_window("overlay") {
        let _ = overlay.hide();
    }
    changed(&app);
    Ok(())
}
#[tauri::command]
fn copy_text(app: tauri::AppHandle, text: String) -> Result<(), String> {
    let state = app.state::<Runtime>();
    state.clipboard.copy(&text)?;
    let mut data = state.data.lock().unwrap();
    if data.recovery.as_ref() == Some(&text) {
        data.recovery = None;
        state.persist(&data)?;
    }
    state.notice("Copied to clipboard.");
    drop(data);
    changed(&app);
    Ok(())
}
#[tauri::command]
fn discard_recovery(app: tauri::AppHandle) -> Result<(), String> {
    let state = app.state::<Runtime>();
    let mut data = state.data.lock().unwrap();
    data.recovery = None;
    state.persist(&data)?;
    *state.notice.lock().unwrap() = None;
    drop(data);
    changed(&app);
    Ok(())
}
#[tauri::command]
async fn retry_delivery(app: tauri::AppHandle) -> Result<(), String> {
    app.state::<Runtime>()
        .notice("Focus your destination now. Retrying in 3 seconds…");
    changed(&app);
    tokio::time::sleep(std::time::Duration::from_secs(3)).await;
    let handle = app.clone();
    let result = tauri::async_runtime::spawn_blocking(move || -> Result<(), String> {
        let state = handle.state::<Runtime>();
        let text = state
            .data
            .lock()
            .unwrap()
            .recovery
            .clone()
            .ok_or("No pending transcript.")?;
        delivery::insert(&text, &state.clipboard)?;
        let mut data = state.data.lock().unwrap();
        if data.recovery.as_ref() == Some(&text) {
            data.recovery = None;
            state.persist(&data)?;
        }
        Ok(())
    })
    .await
    .map_err(|e| e.to_string())?;
    if let Err(ref e) = result {
        app.state::<Runtime>().notice(e);
    }
    changed(&app);
    result
}
#[tauri::command]
fn save_preferences(app: tauri::AppHandle, preferences: Preferences) -> Result<(), String> {
    if !["holdToTalk", "clickToToggle"].contains(&preferences.recording_mode.as_str())
        || !["system", "light", "dark"].contains(&preferences.appearance.as_str())
        || !["forever", "oneDay", "oneWeek", "oneMonth"].contains(&preferences.retention.as_str())
    {
        return Err("Unsupported setting.".into());
    }
    let state = app.state::<Runtime>();
    if *state.phase.lock().unwrap() != Phase::Idle {
        return Err("Finish recording before changing settings.".into());
    }
    let mut data = state.data.lock().unwrap();
    let old = data.preferences.shortcut.clone();
    if preferences.model != data.preferences.model {
        return Err("Use model setup to change recognition models.".into());
    }
    if old != preferences.shortcut {
        let key = preferences
            .shortcut
            .parse::<tauri_plugin_global_shortcut::Shortcut>()
            .map_err(|e| e.to_string())?;
        app.global_shortcut()
            .register(key)
            .map_err(|e| e.to_string())?;
    }
    let mut next = data.clone();
    next.preferences = preferences;
    let retention = next.preferences.retention.clone();
    retain_history(&mut next.history, &retention, Utc::now());
    if let Err(error) = state.persist(&next) {
        if old != next.preferences.shortcut {
            let _ = app
                .global_shortcut()
                .unregister(next.preferences.shortcut.as_str());
        }
        return Err(error);
    }
    if old != next.preferences.shortcut {
        let _ = app.global_shortcut().unregister(old.as_str());
        *state.shortcut_error.lock().unwrap() = None;
    }
    *data = next;
    drop(data);
    changed(&app);
    Ok(())
}
#[tauri::command]
fn save_dictionary(app: tauri::AppHandle, entries: Vec<DictionaryEntry>) -> Result<(), String> {
    if entries.len() > 10000 {
        return Err("Dictionary is too large (maximum 10,000 entries).".into());
    }
    validate_dictionary(&entries)?;
    let state = app.state::<Runtime>();
    let mut data = state.data.lock().unwrap();
    let mut next = data.clone();
    next.dictionary = entries;
    state.persist(&next)?;
    *data = next;
    drop(data);
    changed(&app);
    Ok(())
}
#[tauri::command]
fn update_history(app: tauri::AppHandle, id: Option<Uuid>, action: String) -> Result<(), String> {
    let state = app.state::<Runtime>();
    let mut data = state.data.lock().unwrap();
    let mut next = data.clone();
    match action.as_str() {
        "clear" => next.history.clear(),
        "delete" => next.history.retain(|h| Some(h.id) != id),
        "pin" => {
            if let Some(h) = next.history.iter_mut().find(|h| Some(h.id) == id) {
                h.is_pinned = !h.is_pinned;
            }
        }
        _ => return Err("Unknown history action.".into()),
    };
    state.persist(&next)?;
    *data = next;
    drop(data);
    changed(&app);
    Ok(())
}
#[tauri::command]
fn export_data(state: tauri::State<Runtime>, path: PathBuf, kind: String) -> Result<(), String> {
    let data = state.data.lock().unwrap();
    if kind == "dictionary" {
        atomic_save(
            &path,
            &DictionaryDocument {
                schema_version: 1,
                exported_at: Utc::now(),
                entries: data.dictionary.clone(),
            },
        )
    } else if kind == "history" {
        atomic_save(
            &path,
            &HistoryDocument {
                schema_version: 1,
                items: data.history.clone(),
            },
        )
    } else {
        Err("Unknown export type.".into())
    }
}
#[tauri::command]
fn import_dictionary(app: tauri::AppHandle, path: PathBuf) -> Result<(), String> {
    let meta = std::fs::metadata(&path).map_err(|e| e.to_string())?;
    if meta.len() > 10_000_000 {
        return Err("Import must be smaller than 10 MB.".into());
    }
    let doc: DictionaryDocument =
        serde_json::from_slice(&std::fs::read(&path).map_err(|e| e.to_string())?)
            .map_err(|e| e.to_string())?;
    if doc.schema_version != 1 {
        return Err("Unsupported dictionary schema.".into());
    }
    validate_dictionary(&doc.entries)?;
    let state = app.state::<Runtime>();
    let mut entries = state.data.lock().unwrap().dictionary.clone();
    for entry in doc.entries {
        if entries.iter().any(|e| e.id == entry.id) {
            continue;
        }
        let mut proposed = entries.clone();
        proposed.push(entry);
        if validate_dictionary(&proposed).is_ok() {
            entries = proposed;
        }
    }
    drop(state);
    save_dictionary(app, entries)
}

fn main() {
    tauri::Builder::default()
 .plugin(tauri_plugin_single_instance::init(|app,_,_|{if let Some(w)=app.get_webview_window("main"){let _=w.show();let _=w.set_focus();}}))
 .plugin(tauri_plugin_dialog::init())
 .plugin(tauri_plugin_global_shortcut::Builder::new().with_handler(|app,_,event|{
  let state=app.state::<Runtime>();let phase=*state.phase.lock().unwrap();let toggle=state.data.lock().unwrap().preferences.recording_mode=="clickToToggle";
  let action=state.gesture.lock().unwrap().event(event.state==ShortcutState::Pressed,toggle,phase);let app=app.clone();
  tauri::async_runtime::spawn(async move{let result=match action{Action::Start=>start_recording(app.clone()).await,Action::Stop=>finish_recording(app.clone()).await,Action::None=>Ok(())};if let Err(e)=result{app.state::<Runtime>().notice(e);changed(&app);}});
 }).build())
 .invoke_handler(tauri::generate_handler![get_state,setup_model,cancel_setup,remove_model,start_recording,finish_recording,cancel_recording,copy_text,discard_recovery,retry_delivery,save_preferences,save_dictionary,update_history,export_data,import_dictionary])
 .setup(|app|{
  let dir=app.path().app_data_dir()?;std::fs::create_dir_all(&dir)?;let file=dir.join("data.json");
  // A corrupt archive is a visible startup error, never silently overwritten.
  let mut data=if file.exists(){serde_json::from_slice::<Data>(&std::fs::read(&file)?)?}else{Data::default()};
  if data.schema_version!=1{return Err("Unsupported data schema. Keep your archive and use a compatible version.".into());}
  validate_dictionary(&data.dictionary)?;let retention=data.preferences.retention.clone();retain_history(&mut data.history,&retention,Utc::now());
  let model=data.preferences.model.clone();let shortcut=data.preferences.shortcut.clone();
  app.manage(Runtime{data:Mutex::new(data),dir,audio:audio::Audio::new(app.handle().clone()),clipboard:delivery::Clipboard::new(),engine:Mutex::new(None),phase:Mutex::new(Phase::Idle),gesture:Mutex::new(ShortcutGesture::default()),cancel:Arc::new(AtomicBool::new(false)),setup_cancel:Arc::new(AtomicBool::new(false)),setting_up:AtomicBool::new(false),generation:AtomicU64::new(0),notice:Mutex::new(None),shortcut_error:Mutex::new(None)});
  if !(cfg!(target_os="linux")&&std::env::var_os("WAYLAND_DISPLAY").is_some()) {
   if let Err(e)=app.global_shortcut().register(shortcut.as_str()){*app.state::<Runtime>().shortcut_error.lock().unwrap()=Some(format!("Global shortcut unavailable: {e}. Use the Record button or choose another shortcut."));}
  }else{*app.state::<Runtime>().shortcut_error.lock().unwrap()=Some("Wayland global shortcut is not enabled in this beta. Use the Record button.".into());}
  let overlay=tauri::WebviewWindowBuilder::new(app,"overlay",tauri::WebviewUrl::App("index.html?overlay=1".into())).title("Dictate recording").inner_size(280.,64.).decorations(false).always_on_top(true).skip_taskbar(true).focused(false).focusable(false).visible(false).resizable(false).build()?;
  if let Ok(Some(monitor))=overlay.primary_monitor(){let scale=monitor.scale_factor();let size=monitor.size();let origin=monitor.position();let _=overlay.set_position(tauri::LogicalPosition::new(origin.x as f64/scale+(size.width as f64/scale-280.)/2.,origin.y as f64/scale+size.height as f64/scale-120.));}
  let show=tauri::menu::MenuItem::with_id(app,"show","Open Dictate",true,None::<&str>)?;
  let quit=tauri::menu::MenuItem::with_id(app,"quit","Quit Dictate",true,None::<&str>)?;
  let menu=tauri::menu::Menu::with_items(app,&[&show,&quit])?;
  let mut tray=tauri::tray::TrayIconBuilder::new().menu(&menu).tooltip("Dictate").on_menu_event(|app,event|{match event.id.as_ref(){"show"=>{if let Some(w)=app.get_webview_window("main"){let _=w.show();let _=w.set_focus();}},"quit"=>app.exit(0),_=>{}}});
  if let Some(icon)=app.default_window_icon(){tray=tray.icon(icon.clone());}let _=tray.build(app)?;
  let handle=app.handle().clone();let path=models::path(&handle.state::<Runtime>().dir,&model)?;
  if path.exists(){tauri::async_runtime::spawn(async move{let _=setup_model(handle,model,false).await;});}
  Ok(())
 })
 .on_window_event(|window,event|{if window.label()=="main"{if let tauri::WindowEvent::CloseRequested{api,..}=event{api.prevent_close();let _=window.hide();}}})
 .run(tauri::generate_context!()).expect("Dictate could not start. Your local data has been preserved.");
}
