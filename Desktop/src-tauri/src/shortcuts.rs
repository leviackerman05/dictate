//! Dedicated Windows keyboard/mouse bindings. Hooks inspect only the configured
//! trigger, ignore synthetic input, and never store or log typed keys.
#[cfg(windows)]
mod native {
    use dictate_core::shortcut::{Binding, Key, Trigger, ALT, CTRL, SHIFT, WIN};
    use std::sync::{
        atomic::{AtomicBool, Ordering},
        mpsc, Mutex, OnceLock,
    };
    use windows::Win32::{
        Foundation::{LPARAM, LRESULT, WPARAM},
        System::LibraryLoader::GetModuleHandleW,
        UI::{Input::KeyboardAndMouse::GetAsyncKeyState, WindowsAndMessaging::*},
    };
    struct Input {
        trigger: Mutex<Trigger>,
        paused: AtomicBool,
        sender: tokio::sync::mpsc::UnboundedSender<bool>,
    }
    static INPUT: OnceLock<Input> = OnceLock::new();
    unsafe fn modifiers() -> u8 {
        [
            (0x11, CTRL),
            (0x12, ALT),
            (0x10, SHIFT),
            (0x5B, WIN),
            (0x5C, WIN),
        ]
        .into_iter()
        .fold(0, |mask, (key, bit)| {
            mask | if GetAsyncKeyState(key) < 0 { bit } else { 0 }
        })
    }
    fn edge(key: Key, down: bool, mask: u8, injected: bool) -> bool {
        let Some(input) = INPUT.get() else {
            return false;
        };
        if input.paused.load(Ordering::Relaxed) {
            return false;
        }
        let (consume, event) = input
            .trigger
            .lock()
            .unwrap()
            .event(key, down, mask, injected);
        if let Some(pressed) = event {
            let _ = input.sender.send(pressed);
        }
        consume
    }
    unsafe extern "system" fn keyboard(code: i32, w: WPARAM, l: LPARAM) -> LRESULT {
        if code >= 0 {
            let event = &*(l.0 as *const KBDLLHOOKSTRUCT);
            let message = w.0 as u32;
            if matches!(message, WM_KEYDOWN | WM_SYSKEYDOWN | WM_KEYUP | WM_SYSKEYUP) {
                let mut vk = event.vkCode as u16;
                // Some layouts report generic Ctrl/Alt; extended identifies the right key.
                if vk == 0x11 {
                    vk = if event.flags.0 & LLKHF_EXTENDED.0 != 0 {
                        0xA3
                    } else {
                        0xA2
                    };
                }
                if vk == 0x12 {
                    vk = if event.flags.0 & LLKHF_EXTENDED.0 != 0 {
                        0xA5
                    } else {
                        0xA4
                    };
                }
                if vk == 0x10 {
                    vk = if event.scanCode == 0x36 { 0xA1 } else { 0xA0 };
                }
                if edge(
                    Key::Keyboard(vk),
                    matches!(message, WM_KEYDOWN | WM_SYSKEYDOWN),
                    modifiers(),
                    event.flags.0 & LLKHF_INJECTED.0 != 0,
                ) {
                    return LRESULT(1);
                }
            }
        }
        CallNextHookEx(None, code, w, l)
    }
    unsafe extern "system" fn mouse(code: i32, w: WPARAM, l: LPARAM) -> LRESULT {
        if code >= 0 {
            let event = &*(l.0 as *const MSLLHOOKSTRUCT);
            let message = w.0 as u32;
            let button = match message {
                WM_MBUTTONDOWN | WM_MBUTTONUP => Some(1),
                WM_XBUTTONDOWN | WM_XBUTTONUP => match event.mouseData >> 16 {
                    1 => Some(3),
                    2 => Some(4),
                    _ => None,
                },
                _ => None,
            };
            if let Some(button) = button {
                if edge(
                    Key::Mouse(button),
                    matches!(message, WM_MBUTTONDOWN | WM_XBUTTONDOWN),
                    modifiers(),
                    event.flags & 1 != 0,
                ) {
                    return LRESULT(1);
                }
            }
        }
        CallNextHookEx(None, code, w, l)
    }
    pub fn start(app: tauri::AppHandle, binding: &str) -> Result<(), String> {
        let trigger = Trigger::new(Binding::parse(binding)?);
        let (sender, mut receiver) = tokio::sync::mpsc::unbounded_channel();
        INPUT
            .set(Input {
                trigger: Mutex::new(trigger),
                paused: AtomicBool::new(false),
                sender,
            })
            .map_err(|_| "Shortcut handler already started.")?;
        let (ready_tx, ready_rx) = mpsc::sync_channel(1);
        std::thread::Builder::new()
            .name("dictate-shortcuts".into())
            .spawn(move || unsafe {
                let module = GetModuleHandleW(None).ok().map(|m| m.into());
                let keyboard_hook =
                    match SetWindowsHookExW(WH_KEYBOARD_LL, Some(keyboard), module, 0) {
                        Ok(h) => h,
                        Err(e) => {
                            let _ = ready_tx.send(Err(e.to_string()));
                            return;
                        }
                    };
                let mouse_hook = match SetWindowsHookExW(WH_MOUSE_LL, Some(mouse), module, 0) {
                    Ok(h) => h,
                    Err(e) => {
                        let _ = UnhookWindowsHookEx(keyboard_hook);
                        let _ = ready_tx.send(Err(e.to_string()));
                        return;
                    }
                };
                let _ = ready_tx.send(Ok(()));
                let mut message = MSG::default();
                while GetMessageW(&mut message, None, 0, 0).0 > 0 {
                    let _ = TranslateMessage(&message);
                    DispatchMessageW(&message);
                }
                let _ = UnhookWindowsHookEx(keyboard_hook);
                let _ = UnhookWindowsHookEx(mouse_hook);
            })
            .map_err(|e| e.to_string())?;
        ready_rx
            .recv_timeout(std::time::Duration::from_secs(5))
            .map_err(|e| e.to_string())??;
        // Process physical edges through one async consumer. A quick release
        // or second toggle press can no longer race microphone startup and
        // observe an older recording phase.
        tauri::async_runtime::spawn(async move {
            while let Some(pressed) = receiver.recv().await {
                super::super::handle_shortcut_event(app.clone(), pressed).await;
            }
        });
        Ok(())
    }
    pub fn configure(value: &str) -> Result<(), String> {
        let binding = Binding::parse(value)?;
        let input = INPUT
            .get()
            .ok_or("Shortcut handler is unavailable. Restart Dictate or use Record.")?;
        *input.trigger.lock().unwrap() = Trigger::new(binding);
        Ok(())
    }
    pub fn pause(value: bool) {
        if let Some(input) = INPUT.get() {
            input.paused.store(value, Ordering::SeqCst);
            input.trigger.lock().unwrap().reset();
        }
    }
}
#[cfg(windows)]
pub use native::*;
#[cfg(not(windows))]
pub fn start(app: tauri::AppHandle, binding: &str) -> Result<(), String> {
    use tauri_plugin_global_shortcut::GlobalShortcutExt;
    app.global_shortcut()
        .register(binding)
        .map_err(|e| e.to_string())
}
#[cfg(not(windows))]
pub fn configure(_value: &str) -> Result<(), String> {
    Err("Custom Windows bindings can only be tested on Windows.".into())
}
#[cfg(not(windows))]
pub fn pause(_value: bool) {}
