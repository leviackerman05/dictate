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
    use std::sync::{Arc, Mutex};
    use tauri::Manager;
    use tokio::sync::oneshot;
    use windows::{
        core::Interface,
        Services::Store::{
            StoreContext, StorePackageUpdateResult, StorePackageUpdateState,
            StorePackageUpdateStatus,
        },
        Win32::Foundation::HWND,
        Win32::UI::Shell::IInitializeWithWindow,
    };
    use windows_collections::IVectorView;
    use windows_future::AsyncOperationWithProgressCompletedHandler;

    async fn context(app: &tauri::AppHandle) -> Result<StoreContext, String> {
        let window = app
            .get_webview_window("main")
            .ok_or_else(|| "The Dictate window is unavailable.".to_string())?;
        let hwnd_value = window.hwnd().map_err(|error| error.to_string())?.0 as isize;
        let (send, receive) = oneshot::channel();
        app.run_on_main_thread(move || {
            let result = (|| {
                let context = StoreContext::GetDefault().map_err(|error| error.to_string())?;
                let owner: IInitializeWithWindow =
                    context.cast().map_err(|error| error.to_string())?;
                unsafe { owner.Initialize(HWND(hwnd_value as *mut _)) }
                    .map_err(|error| error.to_string())?;
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
        let items = {
            let context = context(&app).await?;
            let updates = context
                .GetAppAndOptionalStorePackageUpdatesAsync()
                .map_err(|error| error.to_string())?
                .await
                .map_err(|error| error.to_string())?;
            let count = updates.Size().map_err(|error| error.to_string())?;
            if count == 0 {
                return Err("No Microsoft Store update is available.".into());
            }
            (0..count)
                .map(|index| updates.GetAt(index).map_err(|error| error.to_string()))
                .collect::<Result<Vec<_>, _>>()?
        };
        let window = app
            .get_webview_window("main")
            .ok_or_else(|| "The Dictate window is unavailable.".to_string())?;
        let hwnd_value = window.hwnd().map_err(|error| error.to_string())?.0 as isize;
        let (send, receive) = oneshot::channel();
        let completion = Arc::new(Mutex::new(Some(send)));
        let completion_for_main = completion.clone();
        app.run_on_main_thread(move || {
            let start = (|| {
                let context = StoreContext::GetDefault().map_err(|error| error.to_string())?;
                let owner: IInitializeWithWindow =
                    context.cast().map_err(|error| error.to_string())?;
                unsafe { owner.Initialize(HWND(hwnd_value as *mut _)) }
                    .map_err(|error| error.to_string())?;
                let updates = IVectorView::from(items.into_iter().map(Some).collect::<Vec<_>>());
                let request = context
                    .RequestDownloadAndInstallStorePackageUpdatesAsync(&updates)
                    .map_err(|error| error.to_string())?;
                let completion_for_callback = completion_for_main.clone();
                let handler = AsyncOperationWithProgressCompletedHandler::<
                    StorePackageUpdateResult,
                    StorePackageUpdateStatus,
                >::new(move |operation, _| {
                    let result = operation
                        .ok()?
                        .GetResults()
                        .and_then(|result| result.OverallState())
                        .map_err(|error| error.to_string());
                    if let Some(send) = completion_for_callback.lock().unwrap().take() {
                        let _ = send.send(result);
                    }
                    Ok(())
                });
                request
                    .SetCompleted(&handler)
                    .map_err(|error| error.to_string())
            })();
            if let Err(error) = start {
                if let Some(send) = completion_for_main.lock().unwrap().take() {
                    let _ = send.send(Err(error));
                }
            }
        })
        .map_err(|error| error.to_string())?;
        let state = receive
            .await
            .map_err(|_| "Windows closed the update request unexpectedly.".to_string())??;

        match state {
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
