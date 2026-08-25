# Manual compatibility matrix

Run date: 2026-08-24

This is an evidence log, not a claim that live speech insertion passed. The local build was launched with the stable bundle identifier `app.dictate.desktop`. The test environment did not provide a usable live microphone/transcription path, so rows requiring real spoken audio remain unverified.

| Target | Hold-to-talk | Click-to-toggle | Focus precondition | Result |
| --- | --- | --- | --- | --- |
| TextEdit | Not run: no live speech input | Attempted shortcut path; no transcript was produced | A real editable TextEdit text view was located; synthetic marker remained unchanged | Not verified |
| Terminal | Not run | Not run | Not inspected | Not verified |
| Safari | Not run | Not run | Not inspected | Not verified |
| Chrome | Not run | Not run | Not inspected | Not verified |
| Codex | Not run | Not run | Not inspected | Not verified |
| Zed | Not run | Not run | Not inspected | Not verified |
| Raycast | Not run | Not run | Not inspected | Not verified |
| Secure/password field | Not run | Not run | Not inspected; no sensitive text entered | Not verified |

## What was verified without live speech

- Focus intent is generation- and target-bound in pure tests.
- A pointer-down outside the captured editable target invalidates the intent immediately.
- Retry does not fall back to a stale preserved target.
- Paste delivery waits for accessibility state change and only reports insertion success when the expected replacement can be observed; otherwise it preserves recovery.
- The TextEdit precondition used a real editable AX text view. No transcript, document content, title, URL, or password data was recorded in the evidence.

## Required follow-up

Run every row with a short synthetic phrase on a Mac with microphone access and the target app focused. Record only pass/fail, target role/subrole, bundle identifier, and resolver tier. Do not record transcript text or document contents.
