//! X11 delivery requires both a live AT-SPI editable target and unchanged X11
//! focus. Wayland deliberately returns copy recovery instead of bypassing the
//! compositor's input policy.
use super::delivery::Clipboard;
use atspi::{
    proxy::{accessible::ObjectRefExt, editable_text::EditableTextProxy, text::TextProxy},
    AccessibilityConnection, Role, State,
};
use x11rb::protocol::xproto::ConnectionExt;

pub fn insert(text: &str, _clipboard: &Clipboard) -> Result<(), String> {
    if std::env::var_os("WAYLAND_DISPLAY").is_some() {
        return Err(
            "Wayland insertion is not available in this beta. Your transcript is ready to copy."
                .into(),
        );
    }
    let (x11, _) = x11rb::connect(None).map_err(|_| "X11 is unavailable.".to_string())?;
    let focus = x11
        .get_input_focus()
        .map_err(|e| e.to_string())?
        .reply()
        .map_err(|e| e.to_string())?
        .focus;
    let conn = tauri::async_runtime::block_on(async {
        tokio::time::timeout(
            std::time::Duration::from_secs(2),
            AccessibilityConnection::new(),
        )
        .await
    })
    .map_err(|_| "Accessibility timed out.".to_string())?
    .map_err(|_| {
        "Enable desktop accessibility to use automatic insertion, or copy the text.".to_string()
    })?;
    let target = tauri::async_runtime::block_on(async {
        tokio::time::timeout(std::time::Duration::from_secs(2), async {
            let root = conn
                .root_accessible_on_registry()
                .await
                .map_err(|e| e.to_string())?;
            let mut queue = std::collections::VecDeque::from(
                root.get_children().await.map_err(|e| e.to_string())?,
            );
            let mut visited = 0;
            while let Some(obj) = queue.pop_front() {
                visited += 1;
                if visited > 350 {
                    break;
                }
                let Ok(proxy) = obj.as_accessible_proxy(conn.connection()).await else {
                    continue;
                };
                let Ok(role) = proxy.get_role().await else {
                    continue;
                };
                if role == Role::Application && proxy.name().await.unwrap_or_default() == "Dictate"
                {
                    continue;
                }
                let Ok(states) = proxy.get_state().await else {
                    continue;
                };
                if states.contains(State::Focused)
                    && states.contains(State::Editable)
                    && matches!(role, Role::Entry | Role::Text | Role::DocumentText)
                {
                    return Ok(obj);
                }
                if let Ok(children) = proxy.get_children().await {
                    queue.extend(children.into_iter().take(100));
                }
            }
            Err("No accessible focused editor. Copy your transcript instead.".to_string())
        })
        .await
    })
    .map_err(|_| "The editor did not respond. Your transcript is ready to copy.".to_string())??;
    let text_proxy = tauri::async_runtime::block_on(async {
        TextProxy::builder(conn.connection())
            .destination(target.name().ok_or("Missing application")?.clone())
            .map_err(|e| e.to_string())?
            .path(target.path())
            .map_err(|e| e.to_string())?
            .cache_properties(atspi::zbus::proxy::CacheProperties::No)
            .build()
            .await
            .map_err(|e| e.to_string())
    })?;
    let read = || {
        tauri::async_runtime::block_on(async {
            tokio::time::timeout(std::time::Duration::from_millis(500), async {
                let count = text_proxy.character_count().await?;
                text_proxy.get_text(0, count.min(100000)).await
            })
            .await
        })
        .ok()
        .and_then(Result::ok)
    };
    let before = read().ok_or("The editor cannot confirm insertion. Copy the text instead.")?;
    let still = || {
        if x11
            .get_input_focus()
            .ok()
            .and_then(|c| c.reply().ok())
            .map(|v| v.focus)
            != Some(focus)
        {
            return false;
        }
        tauri::async_runtime::block_on(async {
            tokio::time::timeout(std::time::Duration::from_millis(300), async {
                let p = target.as_accessible_proxy(conn.connection()).await.ok()?;
                p.get_state().await.ok()
            })
            .await
        })
        .ok()
        .flatten()
        .is_some_and(|s| s.contains(State::Focused) && s.contains(State::Editable))
    };
    if !still() {
        return Err("Focus changed. Copy your transcript instead.".into());
    }
    let inserted = tauri::async_runtime::block_on(async {
        tokio::time::timeout(std::time::Duration::from_secs(1), async {
            if text_proxy
                .get_n_selections()
                .await
                .map_err(|e| e.to_string())?
                != 0
            {
                return Err("An editor selection is active. Use Copy to replace it.".to_string());
            }
            let caret = text_proxy.caret_offset().await.map_err(|e| e.to_string())?;
            let editable = EditableTextProxy::builder(conn.connection())
                .destination(target.name().ok_or("Missing application")?.clone())
                .map_err(|e| e.to_string())?
                .path(target.path())
                .map_err(|e| e.to_string())?
                .build()
                .await
                .map_err(|e| e.to_string())?;
            editable
                .insert_text(caret, text, text.chars().count() as i32)
                .await
                .map_err(|e| e.to_string())
        })
        .await
    })
    .map_err(|_| "Insertion timed out; check the field before copying again.")??;
    if !inserted {
        return Err("The editor declined insertion. Copy your transcript instead.".into());
    }
    if read().is_some_and(|after| after != before && after.contains(text)) {
        Ok(())
    } else {
        Err("Text sent, but insertion could not be confirmed. Check the field before copying again.".into())
    }
}
