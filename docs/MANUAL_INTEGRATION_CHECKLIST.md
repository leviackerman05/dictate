# Dictate manual integration checklist

Run these checks with the exact packaged app built by `make preflight`. Record
the provider, trigger source, recording mode, target app, and the resulting
History insertion status for each run.

## Automatic insertion

- [ ] Hold-to-talk, Right Command, Apple SpeechTranscriber, TextEdit text view:
  place the caret, hold, speak a multi-sentence paragraph, release, and verify
  the complete text is inserted once with the caret after it.
- [ ] Hold-to-talk, Right Command, Apple SpeechTranscriber, Notes text area:
  verify selection replacement and insertion at the original caret.
- [ ] Hold-to-talk, Right Command, Apple SpeechTranscriber, browser text field:
  verify a normal input and a contenteditable editor both accept the text.
- [ ] Start from Dictate’s main window or menu bar after focusing TextEdit:
  verify the immediately preceding external target is used.
- [ ] With no editable field focused, record and verify no insertion is claimed;
  the persistent Text ready overlay offers Copy and Discard.
- [ ] With Accessibility denied, record and verify transcription still reaches
  History, recovery remains available, and the clipboard is unchanged until
  Copy is pressed.
- [ ] Start in one field, move focus to another field before release, and verify
  Dictate never writes to the original field. Record whether it safely targets
  the new current field or offers Copy according to the current-focus policy.
- [ ] Start in a field, close the field or its window before release, and verify
  the transcript remains recoverable without insertion into another control.
- [ ] Start with no editable field focused and verify a previously focused field
  is not reused.
- [ ] Revoke Accessibility while Dictate is running, complete a recording, and
  verify no repeated system prompt appears and Copy/History remain available.
- [ ] Change the system clipboard during paste fallback and verify Dictate does
  not overwrite that newer clipboard value during restoration.
- [ ] In Codex, Zed, Raycast, and a browser contenteditable, dictate Unicode,
  punctuation, numbers, multiline text, and a long paragraph. Verify insertion
  happens once, at the current caret, with no lost final word.
- [ ] In an Electron editor, dictate two sentences separated by a five-second
  pause and verify the first sentence is not replaced by the second.

## Recording and cancellation

- [ ] Hold-to-talk release during model preparation stops as soon as capture
  starts and does not leave a session running.
- [ ] Click-to-toggle starts on the first press and stops on the second;
  autorepeat and duplicate modifier events do not create extra sessions.
- [ ] Escape cancels from Dictate and while another application is frontmost;
  canceled text is not delivered.
- [ ] A five-minute safety timeout produces a visible recoverable failure.

## Providers and recovery

- [ ] Apple SpeechTranscriber keeps finalized phrases and replaces only the
  current volatile phrase while recording.
- [ ] NVIDIA Parakeet TDT 0.6B v3 downloads, reaches Ready, transcribes one
  complete result, and does not duplicate it.
- [ ] Copy writes the full pending transcript and then hides the overlay.
- [ ] Discard hides the overlay without changing the existing clipboard.
- [ ] A second recording cannot silently overwrite unresolved pending recovery.
- [ ] Verified paste fallback restores the original clipboard unless the user
  changed it during insertion.
