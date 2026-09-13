use serde::Serialize;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateStatus {
    pub source: &'static str,
    pub available: bool,
    pub message: String,
}

#[cfg(windows)]
mod platform {
    use super::UpdateStatus;
    use tauri::Manager;
    use tokio::sync::oneshot;
    use windows::{
        core::Interface,
        Services::Store::{StoreContext, StorePackageUpdateState},
        Win32::UI::Shell::IInitializeWithWindow,
    };

    async fn context(app: &tauri::AppHandle) -> Result<StoreContext, String> {
        let window = app
            .get_webview_window("main")
            .ok_or_else(|| "The Dictate window is unavailable.".to_string())?;
        let hwnd = window.hwnd().map_err(|error| error.to_string())?;
        let (send, receive) = oneshot::channel();
        app.run_on_main_thread(move || {
            let result = (|| {
                let context = StoreContext::GetDefault().map_err(|error| error.to_string())?;
                let owner: IInitializeWithWindow =
                    context.cast().map_err(|error| error.to_string())?;
                unsafe { owner.Initialize(hwnd) }.map_err(|error| error.to_string())?;
                Ok(context)
            })();
            let _ = send.send(result);
        })
        .map_err(|error| error.to_string())?;
        receive
            .await
            .map_err(|_| "Windows closed the update request unexpectedly.".to_string())?
    }

    pub async fn check(app: tauri::AppHandle) -> UpdateStatus {
        let result = async {
            let context = context(&app).await?;
            let updates = context
                .GetAppAndOptionalStorePackageUpdatesAsync()
                .map_err(|error| error.to_string())?
                .await
                .map_err(|error| error.to_string())?;
            updates.Size().map_err(|error| error.to_string())
        }
        .await;

        match result {
            Ok(count) if count > 0 => UpdateStatus {
                source: "store",
                available: true,
                message: "A Microsoft Store update is ready to download.".into(),
            },
            Ok(_) => UpdateStatus {
                source: "store",
                available: false,
                message: "You're using the latest Windows release.".into(),
            },
            Err(_) => UpdateStatus {
                source: "download",
                available: false,
                message: "This build updates from the Dictate download page.".into(),
            },
        }
    }

    pub async fn install(app: tauri::AppHandle) -> Result<(), String> {
        let context = context(&app).await?;
        let updates = context
            .GetAppAndOptionalStorePackageUpdatesAsync()
            .map_err(|error| error.to_string())?
            .await
            .map_err(|error| error.to_string())?;
        if updates.Size().map_err(|error| error.to_string())? == 0 {
            return Err("No Microsoft Store update is available.".into());
        }

        let request_context = context.clone();
        let (send, receive) = oneshot::channel();
        app.run_on_main_thread(move || {
            let request = request_context
                .RequestDownloadAndInstallStorePackageUpdatesAsync(&updates)
                .map_err(|error| error.to_string());
            let _ = send.send(request);
        })
        .map_err(|error| error.to_string())?;
        let result = receive
            .await
            .map_err(|_| "Windows closed the update request unexpectedly.".to_string())??
            .await
            .map_err(|error| error.to_string())?;

        match result.OverallState().map_err(|error| error.to_string())? {
            StorePackageUpdateState::Completed => app.restart(),
            StorePackageUpdateState::Canceled => Err("The Windows update was cancelled.".into()),
            state => Err(format!("Windows could not install the update ({state:?}).")),
        }
    }
}

#[cfg(windows)]
pub use platform::{check, install};

#[cfg(not(windows))]
pub async fn check(_app: tauri::AppHandle) -> UpdateStatus {
    UpdateStatus {
        source: "unavailable",
        available: false,
        message: "Updates are managed separately on this platform.".into(),
    }
}

#[cfg(not(windows))]
pub async fn install(_app: tauri::AppHandle) -> Result<(), String> {
    Err("Microsoft Store updates are available only on Windows.".into())
}
