# Changelog

All notable changes to this project are documented in this file.

## v2.4.0 — 2026-10-02

New affordances for the UIA family, shipped simultaneously in the private upstream
and here. Both changes are **append-only**: no existing output field moved or
changed, and the `@` prefix is the only routing mark — without it, every existing
command behaves exactly as before.

- **`uia-tree` action lists.** Each line gains `actions=[invoke,...]` — the verb
  set is invoke / toggle / select / expand / value / scroll / range; the read-side
  patterns (Text, Window, ...) are deliberately not listed, since what a node can
  be *read* with belongs to `read-text`. Every pattern probe is a cross-process
  call, so probing is **allowlisted by default** (Button, MenuItem, Edit,
  CheckBox, RadioButton, ComboBox, ListItem, TabItem, TreeItem, Hyperlink,
  Slider, SplitButton). `--actions-all` probes every node; `--no-actions` disables
  probing and keeps stdout byte-identical to the previous release. The cost
  self-reports on stderr: `actions-probed=K of M nodes (allowlist) elapsed=Xms`
  (or `actions-probed=0 (disabled)`). An `actions=` field appears only on nodes
  that were actually probed, so "not probed" and "probed but none" (`actions=[]`)
  stay distinguishable.
- **Structural path handles.** `uia-tree` lines gain `path=/0/2/1/4` — the
  child-index route from the root, counted by the same enumeration the dump
  prints, so it costs no extra cross-process call (`--no-paths` turns it off;
  with the rare multi-root fallback it is suppressed rather than labeled
  ambiguously). The new read-only `uia-path <sel> @/0/2/1 [maxDepth]` resolves a
  path and prints that node's line — the handle for controls that have no Name.
  `uia-click` / `uia-focus` / `uia-settext` accept `@path` with an expected
  identity token `Type|nameSub|X,Y,WxH` copied from the `uia-tree` line: the
  walked node is re-verified field by field, and ANY mismatch prints
  `REFUSED: path=... stale` with expected/actual plus the locate/OCR fallback
  hint, and exits 1 without acting. A path deeper than the walked bound
  self-reports `path depth N > walked M` instead of failing silently. **A stale
  path must never become a click** — a wrong click costs more than a failed one.

What was deliberately NOT done: opaque element handles (they silently die across
calls and the death is undetectable — the verified path is the checkable form of
the same need), semantic tree diffs ("did it change" is already covered by the
pixel-level `assert-changed` / `hash` route), silent fallbacks of any kind, and
new third-party dependencies (still one file, zero dependencies).

## v2.3.0 — 2026-10-02

A **code sync, not an incremental release**: this edition's `desktop.ps1` is brought to
feature parity with the private upstream tool at its v2.3.0, applied as a file-level
squash (upstream commit history is deliberately not merged — see "What did NOT change").
The Per-Monitor V2 DPI work from v1.1.0 and the `dpi` command were **re-applied on top**
of the synced file rather than overwritten, and they are verified as still present by
`selftest` and by the README command sweep.

### Self-testing gate (new in this edition)
- `selftest` runs ~590 offline checks — source lints for the PowerShell 5.1 `@(Fn)`
  list-return trap, BOM/ASCII invariants, unit checks of every pure helper, and contract
  checks that pin the version string across all five carriers, pin the READMEs' stated
  tracked-file count against `git ls-files`, and pin that **both language READMEs
  document the same command set**. `selftest --live` adds real round-trips against
  synthetic `DTX-*` fixture windows the tool creates and closes itself.
- Rule set retargeted for this repository: the upstream gate bound the version-sync and
  documentation-consistency checks to two internal Chinese-named working documents that
  do not belong in a public repo. Here they bind to `README.md` + `README.zh-CN.md` +
  `CHANGELOG.md`, enumerated from `git ls-files` so a fourth tracked `.md` cannot join
  the version-carrying set silently.

### Locate and verify, instead of guessing
- `find` — composite locator (UIA first, OCR over the same rect as fallback) that reports
  `source=uia|ocr`; a miss names what both roads measured.
- `find-text` / `read-text` / `assert-text` / `find-click` — OCR road with line rects and
  ready-to-use centres; tiled capture for regions above the OCR engine's dimension cap.
- `imgclick` / `unmap` + `.map.txt` sidecars — the only supported path from a pixel read
  off a saved (possibly fitted) image back to a screen click; a stale sidecar fails.
- `zoom`, `--fit`, `--grid`, `--mark` — fitted captures with the scale printed, an
  optional screen-pixel grid on the saved PNG only, and a crosshair to confirm a target
  before clicking it.
- `uia-find` re-contacts once before letting 0 hits become a verdict (UIA cold start), and
  an empty needle is refused because it would match everything.

### Occlusion self-reporting
- Every pixel-reading command samples a 5×5 `WindowFromPoint` grid and prints
  `scan=<role> occluded=N% coveredBy=pid 'title'`, naming every coverer; guards and
  `assert-*` refuse while occluded, plain reads never fail on it.
- A weak delivery receipt (window grew / new UIA node / line count changed) is refused
  outright when the target is covered — previously such a receipt could be produced by the
  covering window's own animation.

### Act with proof
- Landing self-report: every pointing command echoes `hit-window:` with the pid/proc/title
  actually under the point; `--to` with a point outside the visible rect is refused.
- `--expect-change`, `--expect`, `--expect-gone`, `assert-changed`, `assert-stable`,
  `wait-stable`, `assert-color`, `assert-hash` — proof of effect rather than a delivery
  receipt, each verdict naming the patience and interval actually used.
- Mid-state input: `press-down` / `drag-to` / `press-up` (a held button is machine-wide
  state, so it carries an in-process deadline, a release-on-next-invocation watchdog, and a
  refusal when the press/release pair would go 1:2).
- `menu-pick` and `open-and-pick` for popup menus and self-drawn dropdowns; a menu is
  identified by class and shape, never by the `WS_POPUP` bit.
- Window management: `win-move` / `win-resize` / `win-max` / `win-min` / `win-restore` /
  `win-close`; selector ambiguity now refuses with all candidates instead of silently
  picking the largest window.

### Text, clipboard and receipts
- `type` / `type-in` moved to SendInput Unicode: characters bypass the IME entirely and CJK
  works without a clipboard round-trip; `--verify` OCR-reads the target afterwards.
- `paste` / `paste-file` read back by default (`--no-expect` is the send-only escape). A
  payload long enough to fold into an attachment chip cannot show its tail, so it is then
  accepted on a **named** receipt — the echo always says which.
- `--guard-text` / `--guard-region`: the tool enforces "only talk to this conversation";
  an occluded guard region fails before the OCR runs.
- `ime` / `ime-state` / `ime-en` / `ime-cn` read the conversion mode and switch it with
  read-back, printing the exact command that restores the previous mode.

### Page content
- `chrome-a11y` (relaunch with `--force-renderer-accessibility`, measured before/after),
  `chrome-menu-read` (list Chrome's own menu items, dismiss without clicking), and a
  loopback-only CDP route: `chrome-tabs` / `chrome-read` / `chrome-find` / `chrome-click` /
  `chrome-debug-off`. Tab logging prints host+port only — path and query are dropped,
  because a token is as likely to sit in one as the other.
- `a11y-probe` answers the prior question: can `uia-*` drive this app's content at all?

### Batch, audit and hygiene
- `script` runs a step array in one process with per-step foreground guards, content
  guards, retry and a popup-survival guard (`require-popup` / `release-popup`) that aborts
  the rest of the run when the popup it was working on dies.
- `replay` re-runs recorded commands, dry run by default; it refuses redacted payloads and
  any slice carrying an abort marker.
- Payloads and guard needles are stored as `<redacted:Nchars>` unless `--log-payload` is
  passed; the audit log rotates at 512 KB and `shots-cleanup` bounds the screenshot folder
  by **moving** files to a quarantine folder with a manifest — it never deletes.
- `challenge-probe` reads verification challenges and hands them to a human; **there is no
  solver in this tool by design**, and one surviving attempt trips a fuse for that image.
- Unknown `--flags` in needle commands are a hard error rather than being searched as text.

### What did NOT change
- License (MIT), author identity, the file layout, and the three pre-existing public
  commits. Upstream commit history was not merged or cherry-picked: the upstream tool's
  commit messages are an internal log, so this edition arrives as file-level squashes with
  rewritten, public-facing commit messages. Nothing here should be read as "the public
  history of that work".

## v1.2.0 — 2026-09-27

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
