# Windows workspace
Mode: Operate. Scope: Desktop/src; Windows desktop, 1120×750 content area and minimum 760×560. Native macOS is outside this redesign. User supplied beta4 screenshots are the anti-reference. Code-led implementation uses existing Dictate identity and no new raster artwork. Windows-native direction is a stated working assumption after the optional preference question went unanswered; user authorized autonomous redesign and publication.

## Direction contract
THESIS: A Windows dictation utility with familiar controls and one obvious recording action; replace oversized serif layouts.
OWN-WORLD: Segoe UI, slate-white surfaces, blue focus and actions, compact grouped settings, continuous model rows.
STORY: Choose a local model, assign one comfortable trigger, speak, and recover words when insertion fails.
FIRST VIEWPORT: A 204px navigation rail; 28px page heading; central recording control or task-specific compact workspace. Settings put shortcut capture first.
FORM: Windows control workspace, assigned position 5, seed 95e23d64. Density and explicit state take precedence over decorative expression.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Verification boundary
Browser captures use synthetic Tauri IPC on macOS, so they prove layout and frontend behavior, not Windows microphone, global hooks, insertion, or Segoe rasterization. Native Windows compilation and real offline model inference run in public GitHub Actions. User tests installation and physical input in Windows Sandbox.
