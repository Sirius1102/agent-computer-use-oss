---
name: agent-computer-use
description: Operates a real Windows desktop for an agent — screenshots, window selection, clicks, typing, clipboard read/write, and element location via the UIA accessibility tree or OCR（操控桌面 / 截图 / 点击 / 键入 / OCR 定位 / UIA 无障碍树 / 窗口 / 剪贴板 / 计算机操作）. Use when a task requires performing computer operations on a real desktop application rather than manipulating files.
---

# Agent Computer Use

Tool version: v4.11.0.

首次使用先阅读[电脑操控快速上手](快速上手指南.md)。这份文档随技能包一起交付（仓库根目录与本目录各一份，两份逐字节相同由离线判据钉死，改一处必改两处），它把截图、定位、动作和回读串成一条标准流程，并说明中文输入法下 `type`、`uia-settext`、`paste` 的选择。

A **single-file, stateless Windows desktop automation CLI**. One short-lived `powershell` process per invocation: no daemon, no HTTP server, no third-party dependencies. The repository ships an `install.ps1` that stitches that single file and copies this skill into an agent skill directory; the installed artifact itself installs nothing at run time.

## When to Use This Skill

Use it when a task requires acting on **a real desktop** — a real application window, not a file:

- Taking screenshots of the screen / a window / a region (possibly followed by OCR).
- Clicking, typing, scrolling, dragging in a real GUI application.
- Reading or writing the clipboard (including sending a file as a paste payload).
- Finding an element by name through the UI Automation (UIA) accessibility tree, or by text through OCR when the app exposes no tree.
- Driving windows (focus / move / resize / list / wait for appear-or-disappear).

Do **not** use it for pure file operations, HTTP fetching, or anything that does not require a visible desktop — for those, plain shell/file tools are cheaper and safer.

## How It Works And How To Call It

When you read this `SKILL.md`, you also receive its absolute path. The tool lives at:

```
<skill-dir>/scripts/desktop.ps1      (replace <skill-dir> with this file's directory)
```

Every command is one invocation:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>/scripts/desktop.ps1" <command> [arguments...]
```

The tool is **stateless**: each call is a fresh process; nothing persists between calls except the audit log and saved screenshots. Long chains can be batched in one process via the `script` command (see **Batch Chains: One Process, Not Five** below).

## Command Quick Reference

Each entry: command — what it does — minimal example.

### Screenshots (read)

- `shot [outPath]` — capture the whole virtual screen; it accepts at most one output path and rejects unknown flags or extra positions before capture. For a local full-resolution crop use `rect 0 2010 400 80 <outPath> --fit 0`; use that image's `.map.txt` with `imgclick` or `unmap`, and capture again after the window or layout changes.
- `win <sel>` — capture one window + its image-to-screen mapping; `win` / `rect` / `zoom` also bind a SHA-256 content baseline from the raw 1:1 frame before fit/grid/marks; `--content-roi x,y,w,h` narrows that check; e.g. `win "Notepad" win.png --fit 900`
- `rect <x> <y> <w> <h>` — capture a region; e.g. `rect 100 100 800 600 r.png --grid`
- `zoom <x> <y> <w> <h> [scale]` — enlarge a small region with a mapping echo; e.g. `zoom 500 400 200 80 2 z.png`
- `wins` — list visible windows (pid / class / rect / title ...); `wins -z` opts into the verified GetWindow Z-order chain and the extended **16-key** JSON (`z hwnd enabled modal modal_source` on top of the original 11); a `z` rank is assigned only from the `GetTopWindow` document-chain head, and rows unreachable from that head stay `unknown` (JSON null); the default JSON remains the original 11 keys; e.g. `wins -z`
- `info <sel>` / `rect-of <sel>` — window details / just its rect; e.g. `rect-of 12345`
- `cursor` / `color-at <x> <y>` — cursor position / pixel color; e.g. `color-at 800 600`
- `find-color <x> <y> <w> <h> <#RRGGBB>` — first matching pixel in a region (LEDs, spinners); e.g. `find-color 0 0 400 200 #00FF00`
- `hash <sel|x y w h>` — region MD5 (for assert-hash); e.g. `hash "Notepad"`

### Windows

- Numeric-PID selection is **foreground-first** by default (`pick=fg`), else largest (`pick=largest`). ONE exception (v4.9.0, X-04): a same-pid main window that is DISABLED and owns the foreground dialog via its Owner chain is picked instead (`pick=main`, or `pick=parked` when minimized), with a `note:` stating why — input to the dialog would bypass the disabled main. Every other shape keeps foreground-first. To act on a dialog itself, select it explicitly by title or `hwnd:`; that path is never re-routed.
- `focus <sel>` — bring a window to the front, then RE-READ the same handle (foreground / minimized / visible / rect on screen); echoes both readings with `fg_ok=` and exits 1 when the window is not actually usable; e.g. `focus "Notepad"`
- `win-move <sel> <x> <y>` / `win-resize <sel> <w> <h>` — place / size a window; e.g. `win-move "Notepad" 0 0`
- `win-max` / `win-min` / `win-restore` / `win-close <sel>` — window state changes; e.g. `win-restore "Notepad"`
- `wait-win <sel> <sec>` / `wait-gone <sel> <sec>` — poll for appearance / disappearance; e.g. `wait-win "Save As" 10`
- `wait-stable <sel|x y w h> <sec>` — wait until two consecutive frames are pixel-identical; a `lib/quirks.json` rule matching the window may set the DEFAULT poll interval and its note is appended when the wait fails; e.g. `wait-stable "Notepad" 5`
- `doctor` — one read-only snapshot of machine readiness: psVersion / os / screen+monitors+dpi / OCR / foreground / clipboard kind / quirks policy state / the most recent failure receipt in the current audit log (`--json` publishes the same fields as one object); e.g. `doctor`
- `quirks [--match <sel>]` — the `lib/quirks.json` policy reader: list the rules in force (or why a file was rejected), or test which rule one window hits; e.g. `quirks --match "Notepad"`

### Locate (UIA accessibility tree — preferred when available)

- `find <text...>` — composite locator: UIA first, OCR second, and it SAYS which answered (`source=uia|ocr`); e.g. `find "Save"`
- `uia-tree <sel> [maxDepth]` — dump the control tree (each line carries `path=/0/2/1` and interactive nodes carry `actions=[...]`); e.g. `uia-tree "Notepad" 6`
- `uia-find <sel> <nameSub> [typeRe]` — find elements by Name substring; never empty; auto re-contacts once on a cold zero; e.g. `uia-find "Notepad" "Save"`
- `uia-path <sel> @/0/2/1` — resolve a path from a `uia-tree` line, read-only; e.g. `uia-path "Notepad" @/0/2/1`
- `uia-click <sel> <nameSub>` — InvokePattern (or centre fallback); `@path` form verifies before acting; e.g. `uia-click "Notepad" "Save"`
- `uia-focus <sel> <nameSub>` / `uia-settext <sel> <nameSub> <file>` — focus / set text via ValuePattern (no keyboard, no clipboard); e.g. `uia-settext "Notepad" "Edit" text.txt`
- `a11y-probe <sel>` — read-only: can this app be driven through UIA at all? e.g. `a11y-probe "Some App"`

### Locate (OCR road — for apps with no UIA tree)

- `find-text <sel|x y w h> <needle...>` — OCR a region, back comes line rect + ready centre; e.g. `find-text 0 0 1920 1080 "Log in"`
- `find-click <sel|x y w h> <needle...>` — locate by OCR and click the needle's own sub-span; e.g. `find-click "Some App" "OK"`
- `read-text <sel|x y w h>` — OCR the region, print lines + screen rects; text mode adds a separate raw line-count/area-density and bounded UIA hint (1000ms/256 nodes); timeout is unknown, and file/unbound regions say not-probed; the hint does not change OCR, JSON or exit code; e.g. `read-text "Some App" --max-lines 30`
- `tpl-find <template.png> [--to <sel>] [--region x,y,w,h] [--space screen|window|client] [--scales ...] [--tolerance n] [--index n]` — read-only deterministic icon matching; does not activate or click, reports top-left and size, and refuses ambiguous results unless indexed; `--force` and `--always-activate` are refused by name before resolve/capture/activation (`reason=read-only-override`); the centre is `x+floor(w/2), y+floor(h/2)`; e.g. `tpl-find search.png --to "Some App" --region 0,0,900,700 --space window`
- `assert-text <sel|x y w h> <needle...>` — OCR + exit-code check; e.g. `assert-text "Some App" "Ready"`

### Act (mouse — absolute screen pixels)

- `click` / `rclick` / `dblclick <x> <y>` — click at a point (optionally `--to <sel>` to activate + verify a window first); the click family (`click`/`rclick`/`dblclick`/`imgclick`/`relclick`) shares one `WindowFromPoint → GA_ROOT` landing observation with three states (hit/none/unknown); with `--to`, only `hit` on the target's root hwnd is allowed and none/unknown/another window are refused before input; bare coordinates remain available with `binding=unbound` in the audit; e.g. `click 800 600 --to "Notepad"`
- `move <x> <y>` / `hover <x> <y> [--dwell ms]` — move / stay (tooltips need a dwell); e.g. `hover 800 600 --dwell 1000`
- `drag <x1> <y1> <x2> <y2>` — press, interpolate, release; e.g. `drag 400 400 900 400`
- `press-down` / `drag-to` / `press-up` — the mid-state trio for surfaces that decide on release; e.g. `press-down 400 400` then `press-up 900 400`
- `wheel [amount] [x y] [--unit raw|notches] [--axis vertical|horizontal] [--to <sel>|--at <sel>] [--focus-first] [--verify-scroll [--expect-change x,y,w,h]|--expect-visible-text <needle>]` — scroll. Omitted amount still means -120 raw delta; defaults stay raw delta and vertical. Notches multiply an explicit amount by 120. Positive/negative means up/down vertically and right/left horizontally. `--to` checks that the explicit point, or current cursor when no x/y is given, hits the selected window; `--at` requires explicit x/y and never substitutes the window centre. Verification is opt-in and requires a selected window plus explicit amount/x/y. `--verify-scroll` reads the point's UIA ScrollPattern, with an explicit local pixel rectangle as a labeled pixel-only fallback; `--expect-visible-text` checks for a newly visible UIA name. Boundary, no-effect, target-change and unavailable states stay distinct, polling is capped at 13 samples and no input is retried. Example: `wheel -3 800 600 --unit notches --axis vertical --to "Some App"`.
- `relclick <sel> <dx> <dy>` — click relative to a window's top-left; the origin is the rect re-read after activation, and the click is refused when the point misses the target or another window (even a same-pid top-level) sits under it; e.g. `relclick "Notepad" 100 60`
- `imgclick <img> <ix> <iy> [--stale-ok] [--stale-content-ok] [--require-verified]` — map an image pixel through its sidecar and strictly re-check captured content before clicking; `--stale-content-ok` bypasses content freshness only, `--stale-ok` is the separate host-geometry override; e.g. `imgclick shots/win.png 120 40`

### Type And Clipboard

- `type [--to <sel>] <text...>` — type text (bypasses the IME; CJK works); e.g. `type --to "Notepad" "hello"`
- `type-in <x> <y> [--tab <n>] <text...>` — click a spot then type (webview forms need it); e.g. `type-in 500 300 "hi"`
- `keys [--to <sel>] <spec>` — raw SendKeys spec; e.g. `keys --to "Notepad" "^s"`
- `paste [--to <sel>] <file>` — read a UTF-8 file, set clipboard, Ctrl+V, restore the old clipboard afterwards; e.g. `paste --to "Notepad" text.txt`
- `paste-file [--to <sel>] <path>` — copy a real file as FileDrop + Ctrl+V, then restore the old clipboard; the receipt needle is the file NAME, so the file has to be one this run owns. Fixture form only: `paste-file --to "Notepad" dtx-fixture.txt` — a generated file into a local editor window this run opened. **Red line below applies before you point this at any messaging surface.**
- `copy-file <path>` — put a file on the clipboard as FileDrop (stays there); e.g. `copy-file dtx-fixture.txt`

`type` treats `^a` as literal text; `keys` treats it as Ctrl+A. A numeric PID is a window selector after `--to`, not part of the text. `activated=no (was fg)` means the top-level window was already foreground; it says nothing about the edit control's focus or whether its value changed. `uia-focus` reports a SetFocus call, not a readback of keyboard focus. Read the actual field value after input when it is exposed; use `uia-settext` only as its separate ValuePattern write-and-readback route. Use Ctrl+A plus `paste` only for an explicitly confirmed whole-field replacement.

Use `--guard-text` or `--guard-region` when the expected pre-action content is readable. If a `type` call cannot be read back, record that call's limit and re-check its control/focus/read path; do not infer that every Qt or Electron app rejects `type`.

### Assertions (exit-code checkpoints)

- `assert-window <sel>` / `assert-color <x> <y> <#RRGGBB>` — window exists / pixel equals; e.g. `assert-window "Notepad"`
- `assert-hash <sel|x y w h> ==|!= <hash>` — region hash verdict; e.g. `assert-hash "Notepad" != abc123...`
- `assert-stable <sel|x y w h> <sec>` / `assert-changed ...` — settled / changed within patience; e.g. `assert-changed "Notepad" 5 --interval 300`

### Batch And Replay

- `script <steps.json> [--dry-run] [--stop-on-error] [--reset-on-exit] [--warmup]` — run a JSON list of steps in one process (guards as checkpoints); add `desc` to name receipts; default continues after an ordinary failure and exits 1, while `--stop-on-error` stops there; `ok` means the step ran, not that the business result succeeded; use an assertion such as `assert-text`; `--reset-on-exit` snapshots the clipboard before step 1 and restores it on every exit road with a receipt; `--warmup` (or a handwritten `{"warmup": ""}` first step) runs a read-only pre-flight first — foreground identity, DPI mode, OCR engine — and a probe that cannot produce its value aborts the whole script before any real step runs (a file that already starts with warmup is never double-prepended); `script --json` is refused because this command has no JSON envelope; e.g. `script plan.json --warmup`
- `replay [<actions.log>] [--go]` — re-run recorded commands (dry by default); e.g. `replay --last 10`

### Self-Check

- `selftest` — the offline gate: environment + behaviour checks (part of the smoke test after installation); e.g. `selftest`
- `help [<cmd>]` — the full command page, or one command's entry; e.g. `help uia-click`
- `status-summary [--json]` — read-only checkpoint: HEAD / clean state / selftest counts; e.g. `status-summary`

## Default Behavior You Must Respect

1. **Dry-run first.** For a new or unfamiliar target, test the chain with `--dry-run` (or the dry modes of `replay` / `imgclick --dry` / `script --dry-run`) before any real action.
2. **Guards are strict by default.** A failed guard **refuses and sends nothing** — no key, no click. Foreground guards verify the target really came to the front before acting; occlusion guards refuse to read a covered region.
3. **On `REFUSED`, read the reason — do not improvise.** The refusal names the expected/actual values and the supported fallback roads (`find` / `find-text` / `uia-find` / `imgclick`). Never "solve" a refusal by eyeballing a screenshot and clicking guessed coordinates — that is exactly what the guards exist to prevent.
4. **A zero is not absence.** When a locator reports 0 hits, read its echo: it names what both roads measured and whether a re-contact happened. Use the suggested alternative road instead of falling back to blind coordinates.
5. **Prefer the order: `find` → `uia-find` → `find-text` / `find-click` → `imgclick`.** This ladder is printed by `help`; guessing coordinates off a fitted/downscaled screenshot is not a step in it.

## Batch Chains: One Process, Not Five

Every separate call pays a fresh PowerShell process. The rule of thumb, measured on the authoring machine (see the table): a chain of desktop actions belongs in ONE `script` call, not N separate calls.

- **When**: 2+ desktop actions in one task → write a steps file, dry-run it, run it once. Five separate calls also re-pay process start, screen re-attach and OCR engine init each time; `script` pays them once.
- **Warmup pre-flight**: the first run in a fresh environment (new boot, new session, first OCR use) should pay engine init BEFORE the real steps. Either write `{"warmup": ""}` as the first step, or pass `--warmup` and let the tool prepend one (a steps file that already starts with warmup is never double-prepended). The step is read-only — it reports foreground identity, DPI mode and OCR engine availability — and a probe that cannot produce its value aborts the whole script before any real step runs, so a broken environment fails loudly instead of failing every later step quietly.
- **Dry-run still applies**: `script plan.json --warmup --dry-run` prints the plan (the warmup step shows `probes=foreground,dpi,ocr`) and executes nothing.

Measured chain (5 steps: two shots, one full-screen OCR `assert-text`, one pixel read, one sleep), 10 runs, median, 3840x2160, PowerShell 5.1:

| invocation form | median per chain |
|---|---|
| five separate desktop.ps1 calls | 10036 ms |
| `script`, one process, no warmup | 3455 ms |
| `script --warmup`, one process, pre-flight | 3488 ms |

The per-call saving is the A−B delta; the one-time warmup cost is the C−B delta. Re-measure on your own machine before quoting these numbers elsewhere — they are an authoring-machine figure, not a contract.

## Permissions And Risk

This skill **clicks, types, reads/writes the clipboard and sends real file payloads into applications** — installing it is equivalent to handing the desktop's input devices to the agent that calls it. Run it only when the user asked for a desktop action, keep actions within the requested scope, and prefer read-only commands (`wins` / `uia-tree` / `read-text` / `screenshot` family) to explore first. The tool's audit log records act/text/clipboard commands **with payloads redacted** (`<redacted:Nchars>`), so logs are safe to read back.

**Messaging surfaces — whose call it is (the old hard red line, restated).** The tool proves the landing point and the hit (hit-window / foreground / occlusion guards, `--to` resolution); it does not decide the send. `paste` / `paste-file` / `copy-file` / `keys` / `type` reach whatever window is in the foreground, so a guard passing is *not* permission to send. Whether to send into a real chat, mail or any other person-facing window (WeChat / QQ / DingTalk / Slack / Outlook / a browser webmail, anything that stands for a human on the other side) is the caller's decision, and it requires an explicit instruction from the owner in this same turn naming **that recipient and that file**; system dialogs are always cancelled. 落点与命中可证明（hit-window / 落点守卫），发送与否由调用方决定；发送必须有明确机主指令（本轮点名收件人与文件），不得自作主张。活体验收只用本项目自己创建、自己销毁的夹具（一个本地编辑器窗口 + 一个生成的测试文件）。已经开在屏幕上的聊天窗口不是夹具，"守卫绿了"不是发送许可。

## Self-Check After Installation

Run the offline gate once after installing (or after any environment change):

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>/scripts/desktop.ps1" selftest
```

It verifies the environment (PowerShell version, DPI awareness, OCR language packs) plus the tool's own behaviour contract. Read its three outcomes apart, because they mean three different things: a **FAIL** line is the tool being wrong — fix that, and it is the only outcome that blocks delivery; a **SKIP** line names a capability this machine or this engine cannot measure (no OCR language pack, a PATH without `powershell.exe`, no `git`), and it is neither a pass nor a defect — do not install packages to make a SKIP disappear, and do not read one as proof the road works; `--live` adds checks the offline declaration does not cover, so a live run legitimately reports more. The offline total is the same number on every engine and every PATH shape (that is what the SKIP accounting buys), so a total that disagrees with the version's declaration means a check was added or lost — not that your machine is odd.

## Command Index (one anchor per command)

Every `capabilities` name has its own anchor below. The quoted line is the usage line from `desktop.ps1 help <name>` - full flags, guards and descriptions live in that entry.

### assert-changed
`assert-changed <sel|x y w h> <sec> [--interval ms]`
Example: desktop.ps1 assert-changed "Untitled - Notepad" 1

### assert-color
`assert-color <x> <y> <#RRGGBB> [tol]`
Example: desktop.ps1 assert-color 100 200 sample

### assert-hash
`assert-hash <sel|x y w h> ==|!= <hash>`
Example: desktop.ps1 assert-hash "Untitled - Notepad" ==|!= 00

### assert-stable
`assert-stable <sel|x y w h> <sec> [--interval ms]`
Example: desktop.ps1 assert-stable "Untitled - Notepad" 1

### assert-text
`assert-text <sel|x y w h> <needle...> [--scale a|1|2|tiled] [--max-tiles n]`
Example: desktop.ps1 assert-text "Untitled - Notepad" sample

### assert-window
`assert-window <sel>`
Example: desktop.ps1 assert-window "Untitled - Notepad"

### capabilities
`capabilities [--json]`
Example: desktop.ps1 capabilities

### clip-info
`clip-info`
Example: desktop.ps1 clip-info

### cluster-color
`cluster-color <image> [--min-cluster N] [--tolerance d]`
Example: desktop.ps1 cluster-color sample

### color-at
`color-at <x> <y>`
Example: desktop.ps1 color-at 100 200

### cursor
`cursor`
Example: desktop.ps1 cursor

### dpi
`dpi`
Example: desktop.ps1 dpi

### find
`find <text...> [--target <sel>] [--region x,y,w,h] [--depth n] [--needle <text>]`
Example: desktop.ps1 find sample

### find-color
`find-color <x> <y> <w> <h> <#RRGGBB> [--tolerance n] [--all]`
Example: desktop.ps1 find-color 100 200 800 600 sample

### find-text
`find-text <sel|x y w h> <needle...> [--all] [--scale auto|1|2|tiled]`
Example: desktop.ps1 find-text "Untitled - Notepad" sample

### focus
`focus <sel>`
Example: desktop.ps1 focus "Untitled - Notepad"

### hash
`hash <sel|x y w h>`
Example: desktop.ps1 hash "Untitled - Notepad"

### help
`help [<cmd>|--<flag>]`
Example: desktop.ps1 help

### info
`info <sel>`
Example: desktop.ps1 info "Untitled - Notepad"

### log-index
`log-index [--date <YYYY-MM-DD>] [--origin <tag>] [--log <path>] [--scope current|day|all] [--result error]`
Example: desktop.ps1 log-index --result error

### doctor
`doctor`
Example: desktop.ps1 doctor

### quirks
`quirks [--match <sel>]`
Example: desktop.ps1 quirks --match "Notepad"

### ocr-cap
`ocr-cap`
Example: desktop.ps1 ocr-cap

### proc-info
`proc-info <pid>`
Example: desktop.ps1 proc-info 1234

### proc-list
`proc-list [name-filter]`
Example: desktop.ps1 proc-list

### proc-wait
`proc-wait <pid> [--exit] [--window] [--created <iso>] [--timeout s] [--interval ms]`
Example: desktop.ps1 proc-wait 1234

### pt-anchor
`pt-anchor <profile> --needle <text> [--strict] [--max-drift px]`
Example: desktop.ps1 pt-anchor sample --needle X07-SAMPLE

### pt-calibrate
`pt-calibrate <profile> --estimate <i,j> --verify <k[,...]> [--file <png>]`
Example: desktop.ps1 pt-calibrate sample --estimate sample --verify 1

### pt-profile
`pt-profile <sel> [--samples 1..16] [--save <path>] [--file <png>]`
Example: desktop.ps1 pt-profile "Untitled - Notepad"

### read-text
`read-text <sel|x y w h> [--file <png>] [--max-lines n | --all-lines] [--filter needle]`
Example: desktop.ps1 read-text "Untitled - Notepad"

### rect
`rect <x> <y> <w> <h> [outPath] [--fit px|0] [--grid [step] | --no-grid] [--mark x,y] [--content-roi x,y,w,h]`
Example: desktop.ps1 rect 100 200 800 600

### rect-of
`rect-of <sel>`
Example: desktop.ps1 rect-of "Untitled - Notepad"

### shot
`shot [outPath] [--fit px] [--grid [step] | --no-grid] [--occlude off|warn|strict]`
Example: desktop.ps1 shot

### status-summary
`status-summary [--json]`
Example: desktop.ps1 status-summary

### tpl-find
`tpl-find <templatePng> [--to <sel>] [--region x,y,w,h] [--space screen|window|client]`
Example: desktop.ps1 tpl-find sample

### wait-cond
`wait-cond <sel> [--win] [--gone] [--foreground] [--text <needle>]`
Example: desktop.ps1 wait-cond "Untitled - Notepad"

### wait-gone
`wait-gone <sel> <timeoutSec>`
Example: desktop.ps1 wait-gone "Untitled - Notepad" sample

### wait-stable
`wait-stable <sel|x y w h> <timeoutSec> [--interval ms]`
Example: desktop.ps1 wait-stable "Untitled - Notepad" sample

### wait-win
`wait-win <sel> <timeoutSec>`
Example: desktop.ps1 wait-win "Untitled - Notepad" sample

### win
`win <sel> [outPath] [--fit px|0] [--grid [step] | --no-grid] [--mark x,y] [--content-roi x,y,w,h]`
Example: desktop.ps1 win "Untitled - Notepad"

### wins
`wins [-z]`
Example: desktop.ps1 wins

### click
`click <x> <y> [--button left|right|middle|back|forward] [--mods ctrl+shift|ctrl,shift]`
Example: desktop.ps1 click 100 200

### dblclick
`dblclick <x> <y> [--mods ...] [--space screen|window|client] [--created <iso>]  --guard-region x,y,w,h=s asserts context`
Example: desktop.ps1 dblclick 100 200 --guard-region x,y,w,h=s asserts context

### dialog-cancel
`dialog-cancel <sel> [--allow-window]`
Example: desktop.ps1 dialog-cancel "Untitled - Notepad"

### drag
`drag <x1> <y1> <x2> <y2> [--steps n] [--hold ms] [--button left|middle|right|back|forward] [--mods ctrl+shift] [--space screen|window|client] [--created <iso>] [--to <sel>] [--guard-text <s>]`
Example: desktop.ps1 drag sample sample sample sample

### drag-to
`drag-to <x> <y> [--steps n] [--to <sel>] [--expect-change [x,y,w,h]]`
Example: desktop.ps1 drag-to 100 200

### find-click
`find-click <sel|x y w h> <needle...> [--index n] [--aim-line] [--scale a|1|2|tiled]`
Example: desktop.ps1 find-click "Untitled - Notepad" sample

### hover
`hover <x> <y> [--dwell ms]`
Example: desktop.ps1 hover 100 200

### menu-pick
`menu-pick <sel> <needle...>`
Example: desktop.ps1 menu-pick "Untitled - Notepad" sample

### move
`move <x> <y>`
Example: desktop.ps1 move 100 200

### open-and-pick
`open-and-pick <sel> <opener-x> <opener-y> <needle...> [--region x,y,w,h]`
Example: desktop.ps1 open-and-pick "Untitled - Notepad" sample sample sample

### press-down
`press-down <x> <y> [--max-hold ms] [--to <sel>] [--guard-text <s>] [--force]`
Example: desktop.ps1 press-down 100 200

### press-up
`press-up <x> <y> [--to <sel>] [--expect-change [x,y,w,h]]`
Example: desktop.ps1 press-up 100 200

### proc-kill
`proc-kill <pid> [--created <iso>] [--timeout s] [--go]`
Example: desktop.ps1 proc-kill 1234

### proc-start
`proc-start [--cwd <dir>] [--wait-window s] <exe> [argv...]`
Example: desktop.ps1 proc-start sample

### rclick
`rclick <x> <y> [--mods shift] [--space screen|window|client] [--created <iso>]  + verifies a window first, --guard-text /`
Example: desktop.ps1 rclick 100 200 + verifies a window first, --guard-text /

### relclick
`relclick <sel> <dx> <dy>`
Example: desktop.ps1 relclick "Untitled - Notepad" 10 10

### wheel
`wheel [amount] [x y] [--unit raw|notches] [--axis vertical|horizontal] [--to <sel>] [--at <sel>]`
Example: desktop.ps1 wheel

### win-close
`win-close <sel>`
Example: desktop.ps1 win-close "Untitled - Notepad"

### win-max
`win-max <sel>`
Example: desktop.ps1 win-max "Untitled - Notepad"

### win-min
`win-min <sel>`
Example: desktop.ps1 win-min "Untitled - Notepad"

### win-move
`win-move <sel> <x> <y>`
Example: desktop.ps1 win-move "Untitled - Notepad" 100 200

### win-resize
`win-resize <sel> <w> <h>`
Example: desktop.ps1 win-resize "Untitled - Notepad" 800 600

### win-restore
`win-restore <sel>`
Example: desktop.ps1 win-restore "Untitled - Notepad"

### a11y-probe
`a11y-probe <sel> [bigDepth]`
Example: desktop.ps1 a11y-probe "Untitled - Notepad"

### chrome-a11y
`chrome-a11y <on|off>`
Example: desktop.ps1 chrome-a11y sample

### chrome-click
`chrome-click <sel> <text...> [-dry]`
Example: desktop.ps1 chrome-click "Untitled - Notepad" sample

### chrome-debug-off
`chrome-debug-off`
Example: desktop.ps1 chrome-debug-off

### chrome-find
`chrome-find <sel> <text...>`
Example: desktop.ps1 chrome-find "Untitled - Notepad" sample

### chrome-menu-read
`chrome-menu-read`
Example: desktop.ps1 chrome-menu-read

### chrome-read
`chrome-read <sel>`
Example: desktop.ps1 chrome-read "Untitled - Notepad"

### chrome-tabs
`chrome-tabs [--json]`
Example: desktop.ps1 chrome-tabs

### copy-file
`copy-file [--image] [--replace-clipboard] <path>`
Example: desktop.ps1 copy-file C:\Temp\sample.txt

### ime
`ime`
Example: desktop.ps1 ime

### key
`key [--to <sel>] <combo> [--repeat n] [--interval ms] [--hold ms] [--guard-text <s>] [--expect <needle>] [--force]`
Example: desktop.ps1 key ctrl+s

### key-release
`key-release [--go]`
Example: desktop.ps1 key-release

### keys
`keys [--to <sel>] <spec> [--log-payload] [--force]`
Example: desktop.ps1 keys sample

### key-state
`key-state`
Example: desktop.ps1 key-state

### paste
`paste [--to <sel>] <file> [--expect <s>|--no-expect] [--replace-clipboard] [--force]`
Example: desktop.ps1 paste C:\Temp\sample.txt

### paste-file
`paste-file [--to <sel>] [--image] <path> [--guard-text <s>] [--expect <s>|--no-expect] [--replace-clipboard] [--force]`
Example: desktop.ps1 paste-file C:\Temp\sample.txt

### type
`type [--to <sel>] <text...> [--verify] [--verify-timeout <sec>] [--log-payload] [--force]`
Example: desktop.ps1 type sample

### type-in
`type-in <x> <y> [--tab <n>] <text...> [--verify] [--verify-timeout <sec>] [--log-payload]`
Example: desktop.ps1 type-in 100 200 sample

### uia-click
`uia-click <sel> <nameSub>`
Example: desktop.ps1 uia-click "Untitled - Notepad" sample

### uia-do
`uia-do <action> <sel> <nameSub> [value]`
Example: desktop.ps1 uia-do sample "Untitled - Notepad" sample

### uia-find
`uia-find <sel> <nameSub> [typeRe]`
Example: desktop.ps1 uia-find "Untitled - Notepad" sample

### uia-focus
`uia-focus <sel> <nameSub>`
Example: desktop.ps1 uia-focus "Untitled - Notepad" sample

### uia-path
`uia-path <sel> @/0/2/1 [maxDepth]`
Example: desktop.ps1 uia-path "Untitled - Notepad" @/0/2/1

### uia-settext
`uia-settext <sel> <nameSub> <file>`
Example: desktop.ps1 uia-settext "Untitled - Notepad" sample C:\Temp\sample.txt

### uia-state
`uia-state <sel> <nameSub> [--text]`
Example: desktop.ps1 uia-state "Untitled - Notepad" sample

### uia-tree
`uia-tree <sel> [maxDepth] [--path </0/1/...>] [--dump <file>]`
Example: desktop.ps1 uia-tree "Untitled - Notepad"

### challenge-probe
`challenge-probe <sel> [--allow-attempt --attempt-click x,y]`
Example: desktop.ps1 challenge-probe "Untitled - Notepad"

### ime-cn
`ime-cn [mode]`
Example: desktop.ps1 ime-cn

### ime-en
`ime-en [hkl]`
Example: desktop.ps1 ime-en

### ime-state
`ime-state`
Example: desktop.ps1 ime-state

### imgclick
`imgclick <outPath> <ix> <iy> [--to <sel>] [--expect ...] [--dry] [--stale-ok] [--require-verified] [--stale-content-ok] [--on-grid-alert <px>]`
Example: desktop.ps1 imgclick C:\Temp\out.png 10 20

### shots-cleanup
`shots-cleanup [--keep n] [--go] [--quarantine <dir>]`
Example: desktop.ps1 shots-cleanup

### stitch
`stitch <dir> <out.png>`
Example: desktop.ps1 stitch sample sample

### tile
`tile <x> <y> <w> <h> [--tile WxH] [--grid CxR] [--out-dir <dir>] [--overlap px]`
Example: desktop.ps1 tile 100 200 800 600

### unmap
`unmap <outPath> <ix> <iy> [--stale-ok]`
Example: desktop.ps1 unmap C:\Temp\out.png 10 20

### zoom
`zoom <x> <y> <w> <h> [scale] [outPath] [--to <sel>] [--min-ink pc] [--retry 0..5] [--content-roi x,y,w,h]`
Example: desktop.ps1 zoom 100 200 800 600

### script
`script <steps.json> [--dry-run] [--stop-on-error] [--shot-at n] [--reset-on-exit] [--warmup]`
Example: desktop.ps1 script plan.json --dry-run

### replay
`replay [<actions.log>] [--last n] [--grep s] [--go]`
Example: desktop.ps1 replay --last 10

### selftest
`selftest [--live] [--timing] [--index] [--only <pat>]`
Example: desktop.ps1 selftest

## Detailed Reference

Flags, exit codes, output shapes and worked recipes live in **`reference.md`** (one level deep, in this same folder).
