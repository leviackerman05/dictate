# Dictate privacy

Dictate is designed to keep short dictations on the Mac where they were made.

- Speech recognition is requested in on-device mode. Dictate does not send speech,
  transcripts, dictionary entries, or pasteboard contents to a server.
- Raw microphone audio is streamed through the active recognition session and is
  not written to disk.
- History and the personal dictionary are stored as local JSON files under the
  user Application Support directory. Preferences are stored in standard local
  application preferences.
- History is optional. When “Keep history” is off, future dictations can still be
  inserted or copied but are not added to the archive. Deleting existing history
  is a separate user action.
- Logs contain operational categories only. Transcript text, dictionary contents,
  and pasteboard data are not logged by default.
- Accessibility permission is used to read the focused text element and set its
  selected text. If that is unavailable, Dictate offers a pasteboard and synthetic
  Command-V path when the system permits it.

The app has no account, advertising, telemetry, analytics, tracking, or cloud
rewrite tier. A future rewrite tier would require a separate, explicit consent
boundary and is not part of v1.
