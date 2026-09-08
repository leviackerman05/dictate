use chrono::{DateTime, Utc};
use regex::RegexBuilder;
use serde::{Deserialize, Serialize};
use std::{io::Write, path::Path};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct DictionaryEntry {
    pub id: Uuid,
    pub kind: String,
    pub source_phrase: String,
    pub target_phrase: Option<String>,
    pub notes: Option<String>,
    pub is_enabled: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DictionaryDocument {
    pub schema_version: u32,
    pub exported_at: DateTime<Utc>,
    pub entries: Vec<DictionaryEntry>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorrectionAudit {
    pub id: Uuid,
    pub heard: String,
    pub written: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HistoryItem {
    pub id: Uuid,
    pub timestamp: DateTime<Utc>,
    pub original_transcript: String,
    pub corrected_text: String,
    pub duration: f64,
    pub insertion_result: String,
    pub correction_audit: Vec<CorrectionAudit>,
    pub is_pinned: bool,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HistoryDocument {
    pub schema_version: u32,
    pub items: Vec<HistoryItem>,
}

pub fn normalize(s: &str) -> String {
    s.split_whitespace().collect::<Vec<_>>().join(" ")
}
fn phrase_key(s: &str) -> String {
    s.split(|c: char| c.is_whitespace() || c == '-')
        .collect::<String>()
        .to_lowercase()
}
pub fn validate_dictionary(entries: &[DictionaryEntry]) -> Result<(), String> {
    let mut seen = std::collections::HashSet::new();
    let mut ids = std::collections::HashSet::new();
    for e in entries {
        if !ids.insert(e.id) {
            return Err("Dictionary contains duplicate IDs.".into());
        }
        if e.source_phrase.trim().is_empty() || e.source_phrase.len() > 2048 {
            return Err("Use a phrase between 1 and 2048 bytes.".into());
        }
        match e.kind.as_str() {
            "correction" if e.target_phrase.as_deref().unwrap_or("").trim().is_empty() => {
                return Err("A correction needs a written phrase.".into())
            }
            "vocabulary"
                if e.target_phrase
                    .as_deref()
                    .is_some_and(|v| !v.trim().is_empty()) =>
            {
                return Err("Vocabulary cannot have a replacement.".into())
            }
            "correction" | "vocabulary" => {}
            _ => return Err("Unknown dictionary entry kind.".into()),
        }
        if !seen.insert((
            e.kind.clone(),
            phrase_key(&e.source_phrase),
            e.target_phrase.as_deref().map(phrase_key),
        )) {
            return Err("An identical dictionary entry already exists.".into());
        }
    }
    Ok(())
}

/// One pass over original input; replacement output is never matched again.
/// Offsets are UTF-8 byte boundaries from regex, never character indices.
pub fn correct(text: &str, entries: &[DictionaryEntry]) -> (String, Vec<CorrectionAudit>) {
    struct Candidate {
        start: usize,
        end: usize,
        replacement: String,
        key: String,
    }
    let mut matches = Vec::new();
    let word = |c: char| c.is_alphanumeric() || c == '_';
    for e in entries
        .iter()
        .filter(|e| e.is_enabled && e.kind == "correction")
    {
        let Some(target) = e
            .target_phrase
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
        else {
            continue;
        };
        let parts = e
            .source_phrase
            .split(|c: char| c.is_whitespace() || c == '-')
            .filter(|p| !p.is_empty())
            .map(regex::escape)
            .collect::<Vec<_>>();
        if parts.is_empty() {
            continue;
        }
        let Ok(pattern) = RegexBuilder::new(&parts.join("[\\s-]*"))
            .case_insensitive(true)
            .build()
        else {
            continue;
        };
        let key = format!(
            "{}\0{}\0{}",
            e.source_phrase.trim().to_lowercase(),
            target.to_lowercase(),
            e.id.to_string().to_uppercase()
        );
        for m in pattern.find_iter(text) {
            if text[..m.start()].chars().next_back().is_some_and(word)
                || text[m.end()..].chars().next().is_some_and(word)
            {
                continue;
            }
            matches.push(Candidate {
                start: m.start(),
                end: m.end(),
                replacement: target.into(),
                key: key.clone(),
            });
        }
    }
    matches.sort_by(|a, b| {
        a.start
            .cmp(&b.start)
            .then_with(|| (b.end - b.start).cmp(&(a.end - a.start)))
            .then_with(|| a.key.cmp(&b.key))
    });
    let mut end = 0;
    let mut output = String::new();
    let mut audits = Vec::new();
    for m in matches {
        if m.start < end {
            continue;
        }
        output.push_str(&text[end..m.start]);
        output.push_str(&m.replacement);
        audits.push(CorrectionAudit {
            id: Uuid::new_v4(),
            heard: text[m.start..m.end].into(),
            written: m.replacement,
        });
        end = m.end;
    }
    output.push_str(&text[end..]);
    (output, audits)
}

pub fn atomic_save(path: &Path, value: &impl Serialize) -> Result<(), String> {
    let parent = path.parent().ok_or("Invalid data location")?;
    std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    let mut file = tempfile::NamedTempFile::new_in(parent).map_err(|e| e.to_string())?;
    serde_json::to_writer(&mut file, value).map_err(|e| e.to_string())?;
    file.flush().map_err(|e| e.to_string())?;
    file.as_file().sync_all().map_err(|e| e.to_string())?;
    file.persist(path).map_err(|e| e.to_string())?;
    Ok(())
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Phase {
    Idle,
    Preparing,
    Listening,
    Finalizing,
    Delivering,
}
#[derive(Default)]
pub struct ShortcutGesture {
    pressed: bool,
}
#[derive(Debug, PartialEq)]
pub enum Action {
    None,
    Start,
    Stop,
}
impl ShortcutGesture {
    pub fn event(&mut self, down: bool, toggle: bool, phase: Phase) -> Action {
        if !down {
            self.pressed = false;
            return if !toggle && matches!(phase, Phase::Preparing | Phase::Listening) {
                Action::Stop
            } else {
                Action::None
            };
        }
        if self.pressed {
            return Action::None;
        }
        self.pressed = true;
        match phase {
            Phase::Idle => Action::Start,
            Phase::Preparing | Phase::Listening if toggle => Action::Stop,
            _ => Action::None,
        }
    }
}

pub fn retain_history(items: &mut Vec<HistoryItem>, retention: &str, now: DateTime<Utc>) {
    let days = match retention {
        "oneDay" => 1,
        "oneWeek" => 7,
        "oneMonth" => 30,
        _ => return,
    };
    let cutoff = now - chrono::Duration::days(days);
    items.retain(|i| i.is_pinned || i.timestamp >= cutoff);
}

/// Linear interpolation is used for the portable CPU input path. The audio
/// callback first downmixes channels; this function runs off the realtime thread.
pub fn resample(samples: &[f32], rate: u32) -> Vec<f32> {
    if rate == 0 || samples.is_empty() {
        return vec![];
    }
    if rate == 16000 {
        return samples.to_vec();
    }
    let count = (samples.len() as u64 * 16000 / rate as u64) as usize;
    (0..count)
        .map(|i| {
            let p = i as f64 * rate as f64 / 16000.;
            let j = p as usize;
            let t = (p - j as f64) as f32;
            samples[j] * (1. - t) + samples[(j + 1).min(samples.len() - 1)] * t
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    fn entry(from: &str, to: &str) -> DictionaryEntry {
        DictionaryEntry {
            id: Uuid::new_v4(),
            kind: "correction".into(),
            source_phrase: from.into(),
            target_phrase: Some(to.into()),
            notes: None,
            is_enabled: true,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }
    }
    #[test]
    fn corrections_are_nonrecursive_boundary_aware_and_unicode_safe() {
        let e = vec![
            entry("cloud code", "Claude Code"),
            entry("Claude Code", "wrong"),
            entry("café", "coffee"),
        ];
        assert_eq!(
            correct("cloud-code, café! cloudcodec", &e).0,
            "Claude Code, coffee! cloudcodec"
        );
    }
    #[test]
    fn stable_order_longest_and_separator_equivalence() {
        let mut e = vec![
            entry("new", "old"),
            entry("new york", "NY"),
            entry("cloud code", "Claude"),
        ];
        let a = correct("new york cloudcode", &e).0;
        e.reverse();
        assert_eq!(a, correct("new york cloudcode", &e).0);
        assert_eq!(a, "NY Claude");
        assert!(
            validate_dictionary(&[entry("cloud-code", "x"), entry("cloud code", "x")]).is_err()
        );
    }
    #[test]
    fn toggle_releases_latch_and_ignores_repeats() {
        let mut s = ShortcutGesture::default();
        assert_eq!(s.event(true, true, Phase::Idle), Action::Start);
        assert_eq!(s.event(true, true, Phase::Listening), Action::None);
        s.event(false, true, Phase::Listening);
        assert_eq!(s.event(true, true, Phase::Listening), Action::Stop);
    }
    #[test]
    fn hold_release_during_preparation_stops() {
        let mut s = ShortcutGesture::default();
        s.event(true, false, Phase::Idle);
        assert_eq!(s.event(false, false, Phase::Preparing), Action::Stop);
    }
    #[test]
    fn resampling_preserves_duration_and_silence() {
        assert_eq!(resample(&vec![0.; 48000], 48000), vec![0.; 16000]);
        assert!(resample(&[], 0).is_empty());
    }
    #[test]
    fn atomic_json_roundtrip_and_invalid_dictionary() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("dictionary.json");
        let entries = vec![entry("a", "b")];
        let doc = DictionaryDocument {
            schema_version: 1,
            exported_at: Utc::now(),
            entries,
        };
        atomic_save(&file, &doc).unwrap();
        let loaded: DictionaryDocument =
            serde_json::from_slice(&std::fs::read(file).unwrap()).unwrap();
        assert_eq!(doc.entries, loaded.entries);
        assert!(validate_dictionary(&[entry("", "x")]).is_err());
    }
}
