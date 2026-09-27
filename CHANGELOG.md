# Changelog

All notable changes to this project are documented in this file.

## v1.2.0 — 2026-09-27

### New commands
- `type-in <x> <y> [--tab <n>] <text...>` — click, send *n* TABs, type ASCII. Built for webview/Electron forms where a click gives selection state but never keyboard focus (silent `type`/`paste` failures).
- `zoom <x> <y> <w> <h> [scale] [outPath]` — capture a small region enlarged (nearest-neighbor, default 2x, scale 1..8); echo includes the `screen = origin + image/scale` mapping. Replaces manual crop-and-recheck loops.
- `ime` — read-only report of the foreground thread's keyboard layout / IME state.

### Window geometry fix
- Window rects now come from `DwmGetWindowAttribute(DWMWA_EXTENDED_FRAME_BOUNDS)` with fallback to `GetWindowRect`. The old value includes an invisible 7–11 px resize border on Win10/11, which offset every `win` capture and `relclick` origin relative to the *visible* window. `win` now also self-reports its coordinate mapping and occlusion caveat in the echo.

### IME handling
- `type` / `type-in` request a temporary switch to the English layout (via `WM_INPUTLANGCHANGEREQUEST`) when an IME is active on the target thread, restore the original afterwards, and report honestly in `[ime: ...]` — hosts that ignore the request (e.g. Windows Terminal) get an explicit warning; use `paste` there.

### Docs & clarity
- New README sections: screenshot coordinate system (physical pixels 1:1, display scaling ≠ image scaling), webview Tab-focus recovery, IME behavior; Chromium a11y boundary pinned: `SPI_SETSCREENREADER` does not expand the tree, `--force-renderer-accessibility` restart is the only reliable route.
- Clipboard restore echoes now state what was actually restored (`previous content was text/FileDrop ...`) and code comments clarify that save/restore is per-invocation — there is no cross-command queue.

## v1.1.0 — 2026-09-26

### DPI: Per-Monitor V2 awareness
- The process now opts into **Per-Monitor V2** DPI awareness at startup
  (`SetProcessDpiAwarenessContext`, Windows 10 1703+), falling back to the
  legacy `SetProcessDPIAware()` (System-aware) on older builds. System-aware
  mode is still virtualized on secondary monitors with a different scale
  factor, so screenshots and clicks were offset on mixed-DPI multi-monitor
  setups; Per-Monitor V2 makes every monitor pixel-exact.
- New read command `dpi`: prints the awareness mode actually obtained plus
  every monitor's bounds in physical pixels — a one-call diagnosis when
  coordinates look scaled.

## v1.0.0 — 2026-09-26

First public release. Open-source edition distilled from a personal,
production-used desktop automation tool; all machine-specific paths,
account names and private history removed and generalized.

### Command groups
- **read** — `shot` / `win` / `rect` / `wins` / `info` / `rect-of` / `cursor` / `wait-win` / `wait-gone`
- **act** — `move` / `click` / `rclick` / `dblclick` / `wheel` (with optional position or `--at <sel>`) / `relclick`
- **text** — `focus` / `type` / `keys` / `paste`, all with a hard foreground guard (`--to <sel>`, opt-out via `--force`)
- **clipboard** — `copy-file` (self-verified FileDrop) / `paste-file`
- **uia** — `uia-tree` / `uia-find` / `uia-click` / `uia-focus` / `uia-settext`, rooted at the selected window handle (dialogs sharing a PID are addressable precisely)

### Safety & hygiene
- `SetProcessDPIAware()` before any coordinate use
- UTF-8 (no BOM) stdout so CJK window titles survive piping to other processes
- Clipboard save/restore (text and file lists) around paste commands
- `shots/actions.log` audit trail for every executed act/text/clipboard/uia-settext command — paths only, never file or clipboard contents
- Pure-ASCII script source for PowerShell 5.1 compatibility; non-ASCII payloads enter only via UTF-8 files
