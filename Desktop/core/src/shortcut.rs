//! Windows shortcut policy. Stores a binding, never a stream of typed keys.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Key {
    Keyboard(u16),
    Mouse(u16),
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Binding {
    pub key: Key,
    pub modifiers: u8,
}
pub const CTRL: u8 = 1;
pub const ALT: u8 = 2;
pub const SHIFT: u8 = 4;
pub const WIN: u8 = 8;
impl Binding {
    pub fn parse(value: &str) -> Result<Self, String> {
        if value.len() > 100 {
            return Err("Shortcut is too long.".into());
        }
        let mut parts = value.split('+').collect::<Vec<_>>();
        let name = parts.pop().unwrap_or("");
        let mut modifiers = 0;
        for part in parts {
            let bit = match part {
                "Ctrl" | "Control" | "CommandOrControl" => CTRL,
                "Alt" => ALT,
                "Shift" => SHIFT,
                "Win" | "Meta" | "Super" => WIN,
                _ => return Err("Unsupported shortcut modifier.".into()),
            };
            if modifiers & bit != 0 {
                return Err("Repeated shortcut modifier.".into());
            }
            modifiers |= bit;
        }
        let key = match name {
            "ControlRight" => Key::Keyboard(0xA3), "ControlLeft" => Key::Keyboard(0xA2),
            "AltRight" => Key::Keyboard(0xA5), "AltLeft" => Key::Keyboard(0xA4),
            "ShiftRight" => Key::Keyboard(0xA1), "ShiftLeft" => Key::Keyboard(0xA0),
            "MetaLeft" => Key::Keyboard(0x5B), "MetaRight" => Key::Keyboard(0x5C),
            "MouseMiddle" => Key::Mouse(1), "MouseBack" => Key::Mouse(3), "MouseForward" => Key::Mouse(4),
            "NumpadAdd" => Key::Keyboard(0x6B), "NumpadSubtract" => Key::Keyboard(0x6D),
            "NumpadMultiply" => Key::Keyboard(0x6A), "NumpadDivide" => Key::Keyboard(0x6F),
            "NumpadDecimal" => Key::Keyboard(0x6E),
            _ if name.starts_with("Numpad") && name.len()==7 && name.as_bytes()[6].is_ascii_digit() => Key::Keyboard(0x60+(name.as_bytes()[6]-b'0') as u16),
            "Space" => Key::Keyboard(0x20), "Tab" => Key::Keyboard(9),
            "Enter" => Key::Keyboard(13), "Backspace" => Key::Keyboard(8),
            "CapsLock" => Key::Keyboard(0x14), "Insert" => Key::Keyboard(0x2D),
            "Delete" => Key::Keyboard(0x2E), "Home" => Key::Keyboard(0x24), "End" => Key::Keyboard(0x23),
            "PageUp" => Key::Keyboard(0x21), "PageDown" => Key::Keyboard(0x22),
            "ArrowLeft" => Key::Keyboard(0x25), "ArrowUp" => Key::Keyboard(0x26),
            "ArrowRight" => Key::Keyboard(0x27), "ArrowDown" => Key::Keyboard(0x28),
            "Backquote" => Key::Keyboard(0xC0), "Minus" => Key::Keyboard(0xBD),
            "Equal" => Key::Keyboard(0xBB), "BracketLeft" => Key::Keyboard(0xDB),
            "BracketRight" => Key::Keyboard(0xDD), "Backslash" => Key::Keyboard(0xDC),
            "Semicolon" => Key::Keyboard(0xBA), "Quote" => Key::Keyboard(0xDE),
            "Comma" => Key::Keyboard(0xBC), "Period" => Key::Keyboard(0xBE), "Slash" => Key::Keyboard(0xBF),
            _ if name.starts_with("Key") && name.len() == 4 && name.as_bytes()[3].is_ascii_uppercase() => Key::Keyboard(name.as_bytes()[3] as u16),
            _ if name.starts_with("Digit") && name.len() == 6 && name.as_bytes()[5].is_ascii_digit() => Key::Keyboard(name.as_bytes()[5] as u16),
            _ if name.starts_with('F') => {
                let n = name[1..].parse::<u16>().map_err(|_| "Unsupported function key.")?;
                if !(1..=24).contains(&n) { return Err("Choose F1 through F24.".into()); }
                Key::Keyboard(0x70 + n - 1)
            }
            _ => return Err("Choose a keyboard key, middle mouse button, or mouse side button. Escape is reserved for Cancel.".into()),
        };
        Ok(Self { key, modifiers })
    }
}
#[derive(Debug)]
pub struct Trigger {
    pub binding: Binding,
    held: bool,
}
impl Trigger {
    pub fn new(binding: Binding) -> Self {
        Self {
            binding,
            held: false,
        }
    }
    pub fn reset(&mut self) {
        self.held = false;
    }
    /// Returns whether to consume the event, and one edge per physical press/release.
    pub fn event(
        &mut self,
        key: Key,
        down: bool,
        modifiers: u8,
        injected: bool,
    ) -> (bool, Option<bool>) {
        if injected || key != self.binding.key {
            return (false, None);
        }
        if !down {
            let held = self.held;
            self.held = false;
            return (held, held.then_some(false));
        }
        if self.held {
            return (true, None);
        }
        let own = match key {
            Key::Keyboard(0xA2 | 0xA3) => CTRL,
            Key::Keyboard(0xA4 | 0xA5) => ALT,
            Key::Keyboard(0xA0 | 0xA1) => SHIFT,
            Key::Keyboard(0x5B | 0x5C) => WIN,
            _ => 0,
        };
        if modifiers & !own != self.binding.modifiers {
            return (false, None);
        }
        self.held = true;
        (true, Some(true))
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn dedicated_keys_and_mouse_buttons() {
        for (name, key) in [
            ("ControlRight", Key::Keyboard(0xA3)),
            ("F8", Key::Keyboard(0x77)),
            ("MouseBack", Key::Mouse(3)),
            ("KeyR", Key::Keyboard(0x52)),
        ] {
            assert_eq!(Binding::parse(name).unwrap().key, key);
        }
        assert_eq!(
            Binding::parse("CommandOrControl+Shift+Space")
                .unwrap()
                .modifiers,
            CTRL | SHIFT
        );
        for bad in [
            "",
            "Escape",
            "MouseLeft",
            "Ctrl+Ctrl+KeyA",
            "F25",
            "Keyé",
            "ctrl+Q",
        ] {
            assert!(Binding::parse(bad).is_err(), "{bad}");
        }
    }
    #[test]
    fn release_survives_changed_modifiers_and_repeats() {
        let mut t = Trigger::new(Binding::parse("Ctrl+KeyD").unwrap());
        assert_eq!(t.event(Key::Keyboard(0x44), true, 0, false), (false, None));
        assert_eq!(
            t.event(Key::Keyboard(0x44), true, CTRL, false),
            (true, Some(true))
        );
        assert_eq!(
            t.event(Key::Keyboard(0x44), true, CTRL, false),
            (true, None)
        );
        assert_eq!(
            t.event(Key::Keyboard(0x44), false, 0, false),
            (true, Some(false))
        );
    }
    #[test]
    fn ignores_injected_and_unrelated_input() {
        let mut t = Trigger::new(Binding::parse("ControlRight").unwrap());
        assert_eq!(
            t.event(Key::Keyboard(0xA3), true, CTRL, true),
            (false, None)
        );
        assert_eq!(t.event(Key::Keyboard(0x41), true, 0, false), (false, None));
        assert_eq!(
            t.event(Key::Keyboard(0xA3), true, CTRL, false),
            (true, Some(true))
        );
        t.reset();
        assert_eq!(t.event(Key::Keyboard(0xA3), false, 0, false), (false, None));
    }
}
