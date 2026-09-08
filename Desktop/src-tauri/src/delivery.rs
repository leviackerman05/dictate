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
    } else if cfg!(target_os = "linux") && std::env::var_os("WAYLAND_DISPLAY").is_some() {
        "Wayland: use Record here, then copy your transcript. System-wide shortcut and insertion support vary by desktop."
    } else if cfg!(target_os = "linux") {
        "X11: automatic insertion requires an accessible focused editor. Otherwise, copy your completed transcript."
    } else {
        "Portable preview: copy completed text. Use the native Dictate app for Mac insertion."
    }
}

#[cfg(windows)]
pub fn insert(text: &str, _clipboard: &Clipboard) -> Result<(), String> {
    use windows::Win32::{System::Com::*, UI::Accessibility::*, UI::WindowsAndMessaging::*};
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
        if pid == std::process::id() as i32
            || target
                .CurrentIsPassword()
                .map_err(|e| e.to_string())?
                .as_bool()
            || !target
                .CurrentHasKeyboardFocus()
                .map_err(|e| e.to_string())?
                .as_bool()
            || (kind != UIA_EditControlTypeId && kind != UIA_DocumentControlTypeId)
        {
            return Err(
                "No accessible external editor is focused. Copy the transcript instead.".into(),
            );
        }
        let read_text = || {
            target
                .GetCurrentPatternAs::<IUIAutomationValuePattern>(UIA_ValuePatternId)
                .ok()
                .and_then(|v| v.CurrentValue().ok())
                .map(|v| v.to_string())
                .or_else(|| {
                    target
                        .GetCurrentPatternAs::<IUIAutomationTextPattern>(UIA_TextPatternId)
                        .ok()
                        .and_then(|p| p.DocumentRange().ok())
                        .and_then(|r| r.GetText(100000).ok())
                        .map(|s| s.to_string())
                })
        };
        let before =
            read_text().ok_or("The editor cannot confirm insertion. Copy the text instead.")?;
        let window = GetForegroundWindow();
        let still = || {
            GetForegroundWindow() == window
                && automation
                    .GetFocusedElement()
                    .ok()
                    .and_then(|current| automation.CompareElements(&target, &current).ok())
                    .is_some_and(|v| v.as_bool())
        };
        if text.chars().any(char::is_control) {
            return Err("This transcript includes control characters. Use Copy when ready.".into());
        }
        let mut input = Enigo::new(&Settings::default()).map_err(|e| e.to_string())?;
        if !still() {
            return Err("Focus changed. Your transcript is ready to copy.".into());
        }
        // Windows Unicode input preserves every clipboard format. Never send
        // Return or Tab: these can submit forms or change the focused field.
        input.text(text).map_err(|e| e.to_string())?;
        std::thread::sleep(std::time::Duration::from_millis(250));
        // Sending a key is not proof of insertion. Require the expected text to be
        // observable through the editor's Text or Value pattern before clearing recovery.
        let value = target
            .GetCurrentPatternAs::<IUIAutomationValuePattern>(UIA_ValuePatternId)
            .ok()
            .and_then(|v| v.CurrentValue().ok())
            .map(|v| v.to_string());
        let content = value.or_else(|| {
            target
                .GetCurrentPatternAs::<IUIAutomationTextPattern>(UIA_TextPatternId)
                .ok()
                .and_then(|p| p.DocumentRange().ok())
                .and_then(|r| r.GetText(100000).ok())
                .map(|s| s.to_string())
        });
        if content.is_some_and(|v| v != before && v.contains(text)) {
            Ok(())
        } else {
            Err("Text sent, but the editor could not confirm it. Check the field before copying again.".into())
        }
    }
}

#[cfg(not(any(windows, target_os = "linux")))]
pub fn insert(_text: &str, _clipboard: &Clipboard) -> Result<(), String> {
    Err(if std::env::var_os("WAYLAND_DISPLAY").is_some(){"Your desktop does not expose verified insertion. Your transcript is ready to copy."}else{"Automatic insertion is not yet verified for this desktop. Your transcript is ready to copy."}.into())
}

#[cfg(target_os = "linux")]
pub fn insert(text: &str, clipboard: &Clipboard) -> Result<(), String> {
    super::linux_delivery::insert(text, clipboard)
}
