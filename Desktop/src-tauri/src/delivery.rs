#[cfg(windows)]
use enigo::{Enigo, Keyboard, Settings};
use std::sync::Mutex;

pub struct Clipboard(pub Mutex<Option<arboard::Clipboard>>);
impl Clipboard {
    pub fn new() -> Self {
        Self(Mutex::new(arboard::Clipboard::new().ok()))
    }
    pub fn copy(&self, text: &str) -> Result<(), String> {
        let mut c = self.0.lock().unwrap();
        if c.is_none() {
            *c = arboard::Clipboard::new().ok();
        }
        c.as_mut()
            .ok_or("Clipboard unavailable. Select the transcript and copy it manually.")?
            .set_text(text)
            .map_err(|e| e.to_string())
    }
}

pub fn capability() -> &'static str {
    if cfg!(windows) {
        "Automatic insertion uses the current editable field. Elevated or inaccessible apps keep text ready to copy."
    } else {
        "Portable preview: copy completed text. Use the native Dictate app for Mac insertion."
    }
}

#[cfg(windows)]
pub fn insert(text: &str, _clipboard: &Clipboard) -> Result<(), String> {
    use windows::Win32::{
        Foundation::HWND, System::Com::*, UI::Accessibility::*, UI::WindowsAndMessaging::*,
    };
    unsafe {
        let initialized = CoInitializeEx(None, COINIT_MULTITHREADED).is_ok();
        struct ComGuard(bool);
        impl Drop for ComGuard {
            fn drop(&mut self) {
                if self.0 {
                    unsafe { CoUninitialize() }
                }
            }
        }
        let _guard = ComGuard(initialized);
        let automation: IUIAutomation =
            CoCreateInstance(&CUIAutomation, None, CLSCTX_INPROC_SERVER)
                .map_err(|_| "Accessibility is unavailable.".to_string())?;
        let target = automation
            .GetFocusedElement()
            .map_err(|_| "No focused editor. Copy the transcript instead.".to_string())?;
        let pid = target.CurrentProcessId().map_err(|e| e.to_string())?;
        let kind = target.CurrentControlType().map_err(|e| e.to_string())?;
        if target
            .CurrentIsPassword()
            .map_err(|e| e.to_string())?
            .as_bool()
        {
            return Err(
                "Dictate will not insert into a password field. Your transcript is ready to copy."
                    .into(),
            );
        }
        if kind != UIA_EditControlTypeId
            && kind != UIA_DocumentControlTypeId
            && kind != UIA_CustomControlTypeId
        {
            return Err(
                "Focus an editable field, then use your recording shortcut. Your transcript is ready to copy."
                    .into(),
            );
        }
        let window = GetForegroundWindow();
        if window == HWND::default() {
            return Err("No destination app is active. Your transcript is ready to copy.".into());
        }
        let mut foreground_pid = 0;
        GetWindowThreadProcessId(window, Some(&mut foreground_pid));
        let own_pid = std::process::id();
        // WebView2 exposes its focused editor through a child process, so the
        // focused UIA element alone cannot identify Dictate's own window. The
        // foreground HWND belongs to the Tauri process and closes that gap.
        if pid == own_pid as i32 || foreground_pid == own_pid {
            return Err("Focus a field in another app, then use your recording shortcut. Your transcript is ready to copy.".into());
        }
        if text.chars().any(char::is_control) {
            return Err("This transcript includes control characters. Use Copy when ready.".into());
        }
        let mut input = Enigo::new(&Settings::default()).map_err(|e| e.to_string())?;
        // Many valid Windows editors expose Custom controls or omit readable
        // Value/Text patterns. Accept editable control families without requiring
        // a readable document snapshot, while still rejecting buttons and other
        // unrelated focused controls. The foreground and password checks remain.
        if GetForegroundWindow() != window {
            return Err("Focus changed. Your transcript is ready to copy.".into());
        }
        // Unicode input preserves every clipboard format. It also avoids a
        // Ctrl+V shortcut that elevated apps or custom editors may intercept.
        input.text(text).map_err(|e| e.to_string())?;
        Ok(())
    }
}

#[cfg(not(windows))]
pub fn insert(_text: &str, _clipboard: &Clipboard) -> Result<(), String> {
    Err(
        "Use the native Dictate app for Mac insertion. Your preview transcript is ready to copy."
            .into(),
    )
}
