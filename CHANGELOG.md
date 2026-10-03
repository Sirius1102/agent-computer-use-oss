# Changelog

All notable changes to this project are documented in this file.

## v2.7.0 — 2026-10-03

`read-text --file <png>`: OCR a **saved capture** instead of a live screen region.

Until now every claim about the OCR road rested on live checks that need the desktop, so
"our OCR reads this well" was not testable at all - and certainly not comparable between
recognizers. Reading a stored image makes OCR quality something you can measure offline,
replay, and A/B, with no window raised, nothing clicked, and no other automation able to
collide with the measurement.

- Lines come back in **image pixels from the image's own top-left**, and the label is
  deliberately a different shape - `img-rect=` rather than `rect=` - so a file read cannot
  be pasted into a click by a caller who skimmed. The header says in as many words that
  these are not screen coordinates.
- **`--json` is refused in file mode** rather than answered. The `read-text` envelope keys
  are a pinned contract (`schemaVersion+occluded+coveredBy+lines`) with no field that could
  name the coordinate space; emitting it anyway would hand a machine consumer image pixels
  dressed as screen pixels. The refusal message explains why and points at text mode.
- `--scale 2` upscales the image before reading, for small text in a saved capture.
- Four new checks (644 total, up from 640): an end-to-end round trip that renders a known
  string with GDI+ and reads it back through the real recognizer - **not** gated behind
  `--live`, since running anywhere is the point; a bounds check that every returned rect
  sits inside the reported image size; an end-to-end test of the `--json` refusal through a
  child process; and a lint that the help actually names `img-rect=` and states the
  coordinates are not a screen rect. On a machine with no OCR language pack the round trip
  **skips with a reason** and the badge total does not move - the first use of the v2.5.4
  counting fix.
- Measured while building this, on a box with only the `zh-Hans-CN` recognizer installed: a
  28px rendered English menu bar (`File Edit View Run Terminal Help`) round-trips
  **exactly**. So the Chinese-only-pack worry is not a blanket English-reading failure; it
  is an open question about smaller and mixed text, and `--file` is now the way to answer
  it with numbers instead of opinion.

## v2.6.0 — 2026-10-03

The screenshot folder grew without limit because the command that bounds it was never
run. `shots-cleanup` has existed since v1.5.2 and nobody remembered it: 690 files /
132 MB measured on 2026-10-03. The audit log has self-archived on size since v1.4.1;
captures now follow the same pattern instead of waiting to be asked.

- **Every capture trims the folder afterwards.** `shot`, `zoom`, `imgclick`, the
  `chrome-*` family and `challenge-probe` bound it to the newest 100 images right after
  writing their own file - so the capture you just asked for is always inside the bound
  and can never be swept by its own trim.
- **Move, never delete.** The automatic pass calls the SAME code as `shots-cleanup --go`:
  one `Move-Item` per file into the quarantine folder, one `MANIFEST.md` line per file
  with its SHA256 and timestamps, `.map.txt` sidecars travelling with their image. There
  is exactly one copy of that loop in the file, and a lint keeps it that way.
- **Quiet when there is nothing to do, explicit when it acts** (`auto-trim: moved N ...`),
  and it **skips with a stated reason** when no quarantine is configured - a capture never
  fails because the cleanup could not run. It also switches itself off during `selftest`,
  because a `--live` run writes fixtures early and reads them back later.
- **Knobs**: `DTX_SHOT_KEEP=<n>` for the bound, `DTX_SHOT_AUTOTRIM=0|off|false|no` to stop
  the automatic pass (the command still works by hand). Unlike the quarantine target these
  are read from the process environment only - the default is ON and the variables only
  ever lower it, so a setting that has not reached a long-lived host fails safe towards
  trimming rather than towards stopping.
- 640 checks in this release, up from 626: four unit checks pin the policy knobs (including
  "a typo in the switch must not silently stop the trim"), four end-to-end checks move real
  files in a temp folder against a temp quarantine and assert on the disk afterwards, and
  three lints pin the shape - the move loop existing exactly once, the trim having exactly
  one call site and that site being the tail of the command dispatcher, and the mover
  containing no deletion primitive at all.
- The trim hook lives at the **one place every command must pass**, not next to the
  function that writes most images. The first draft hooked the common capture helper and a
  lint said "the capture path calls the trim" - green, and wrong: `zoom` builds its own
  bitmap and never enters that helper, so a real `zoom` left its file behind. Two lessons,
  both recorded because they were not obvious from reading the code: a wiring check only
  proves the wiring it looks at, and the way to find the rest is to run the command that
  least looks like the main path.

## v2.5.4 — 2026-10-03

The selftest badge check was a machine probe. It compared the README badge against the
**passed** tally only, so any check that legitimately skips on a different box lowered
the expectation by one and turned the gate red: on a fresh clone (no `DTX_QUARANTINE`
anywhere) and on the very machine that configured it, once a shell inherits it into its
process environment. Measured before this release: `622 passed, 1 failed, 1 skipped`
with the badge demanding `623` while stating `624`.

- The badge now compares against the **count of checks this run defines** —
  `passed + failed + skipped + 1`, the `+1` being the badge check itself — through a new
  `Get-BadgeCheckTotal` helper. A check counts once no matter which way it went.
- Two guards keep it that way: a unit check asserting the total is invariant when one
  check moves from skipped to passed, and a lint that fails if the badge comparison ever
  reads the passed tally alone again. The lint assembles its own search tokens at runtime
  so its source lines cannot satisfy the pattern it forbids.
- `626` is this release's check count; the badge check pins it, so adding or removing any
  check turns the gate red until the badge moves with it.
- Out of band (no file in this repo changes): the release gate's outbound-leak scan gained
  two rule families — bare personal directory names, and paths assembled from character
  codes — after both were shown to slip through undetected. Proven by injecting synthetic
  samples into a throwaway clone and requiring each to turn the scan red, with benign
  look-alikes required to stay clean.

## v2.5.3 — 2026-10-03

Fix to the v2.5.2 value chain, measured on the machine that set the variable: a
process environment block is a **startup snapshot**, so a long-lived host (and
everything it spawns) never sees a User-level environment variable written after it
started — with v2.5.2's env-only chain, `shots-cleanup --go` refused on exactly the
machine that had configured `DTX_QUARANTINE`.

- The resolution order is now: explicit `--quarantine <dir>` → `DTX_QUARANTINE` from
  the **process environment** → `DTX_QUARANTINE` from the **User-scope registry** →
  **Machine-scope registry** → refuse (exit 2, both remedies named, no path echoed).
- The resolver returns the target together with the tier that answered (the command
  echoes `resolved by: flag / env / user / machine`), and every precedence tier is
  unit-pinned with injected probe values — the real registry is never touched by a
  test. One additional check pins the live wiring on a process whose env block
  predates the User value (the exact defect this release fixes); it skips with a
  reason where that fixture does not exist.
- The all-empty live refusal (every source empty for real) is verified once, manually
  — making it testable in place would require deleting the User-scope value, which a
  selftest must never do.

Version bit 2.5.2 → 2.5.3 (a published command's default-behaviour fix).

## v2.5.2 — 2026-10-03

Two behaviour-facing changes, both about not lying to the user or the maintainer.

- **`shots-cleanup --go` no longer carries a machine-specific default target.** The
  previous default was a personal folder baked into the script (spelled in character
  codes, which is exactly how it slipped past the outbound content scanner's
  drive-letter-path rules — see the project iteration log for that blind spot). The
  target is now resolved per call: an explicit `--quarantine <dir>` wins, then the
  `DTX_QUARANTINE` environment variable, else the command **refuses** (exit 2) naming
  both remedies and echoing no path. The refusal ("no target configured") and the
  pre-existing "quarantine folder does not exist" failure are separate branches. Dry
  run — the default — never needed the target and works unchanged. The resolver is a
  pure function pinned by unit checks, and the refusal is pinned end-to-end by a
  subprocess check that strips the variable and demands exit 2 with no path echoed.
- **The README selftest badge is now pinned by a lint.** The badge is a count, not a
  status (`617 checks` was an honest snapshot with no teeth); the selftest's final
  check asserts both README badges state the same number AND that it equals the run's
  own passed total, so the badge can no longer drift from reality when checks are
  added. With this release's six new checks the badge reads **623 checks**.

Version bit 2.5.1 → 2.5.2 (a published command's default behaviour changed); no other
command's behaviour moved.

## v2.5.1 — 2026-10-03

Project page and engineering shell: documentation and repo scaffolding only —
**zero changes to any command's behaviour**.

- **README overhaul (both editions, same structure).** A badge row (license, platform,
  shell, single-file, and the CI status of the offline self-test), the one-line
  positioning directly under the H1, a table of contents, a scannable highlights grid
  distilled from "Why this design" (the full paragraphs stay, nothing removed), a
  Mermaid flow diagram of one call (locate → guard chain → act → assert/receipt), and a
  differences table against cloud-VLM agents, AI-IDE built-in desktop automation and
  terminal coding agents — phrased as differences with their costs, no unfalsifiable
  claims, and no assertions about other products' non-public internals.
- **Engineering shell.** `CONTRIBUTING.md` (selftest before every PR, the outbound
  gate, version-bit rules, the tracked-inventory rule, the two-edition README rule),
  `SECURITY.md` (what the tool can do, the audit log and its default redaction, how to
  report), and two issue templates plus a pull-request template that require the
  selftest line and the gate result up front. A CI workflow running the **offline**
  selftest on `windows-latest` (never `selftest --live`, which needs a real desktop and
  creates `DTX-*` fixture windows) is prepared but not landed in this release — pushing
  workflow files requires repository credentials with the `workflow` scope, which the
  current credentials lack; the selftest badge is therefore the static form, and no CI
  is claimed.
- **Tracked inventory 11 → 16.** The five new files above; the inventory line and the
  repository layout in both README editions updated in the same commit, as pinned by
  the self-test. The self-test's pinned tracked-`.md` set grew by the same five
  markdown files.
- Version bit 2.5.0 → 2.5.1 across the five carriers (header comment, usage banner,
  both README H1s, this changelog's top entry); historical version numbers unchanged.
- Same-day addendum (badge honesty): the static selftest badge now states a **count**,
  not a state — "selftest | 617 checks" in a neutral colour, replacing the ever-green
  "offline gate" image, so nothing on the page reads as continuous verification. The
  count is the offline gate's check total at this release; update the badge in the same
  commit as any future change to that total.

## v2.5.0 — 2026-10-02

Skill packaging: the repository now ships a **loadable agent-skill wrapper** under
`skill/agent-computer-use/` — `SKILL.md` (what it is / when to use it / quick command
reference), `reference.md` (flags, exit codes, recipes), plus `install.ps1` /
`uninstall.ps1` which copy the skill into an agent skill directory resolved at
runtime (first existing of the known host roots; never a hard-coded user path).
No command behaviour changed — v2.5.0 is an additive packaging layer.

The offline self-test now reports its repository-level checks (version carriers,
tracked-file inventory, README sweep) as SKIP-with-a-reason when the tool runs
outside a checkout (an installed copy), so an installation can self-verify
standalone; inside the repository nothing changed.

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
