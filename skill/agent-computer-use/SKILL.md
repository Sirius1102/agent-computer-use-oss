---
name: agent-computer-use
description: Operates a real Windows desktop for an agent — screenshots, window selection, clicks, typing, clipboard read/write, and element location via the UIA accessibility tree or OCR（操控桌面 / 截图 / 点击 / 键入 / OCR 定位 / UIA 无障碍树 / 窗口 / 剪贴板 / 计算机操作）. Use when a task requires performing computer operations on a real desktop application rather than manipulating files.
---

# Agent Computer Use

首次使用先阅读[电脑操控快速上手](快速上手指南.md)。这份文档随技能包一起交付（仓库根目录与本目录各一份，两份逐字节相同由离线判据钉死，改一处必改两处），它把截图、定位、动作和回读串成一条标准流程，并说明中文输入法下 `type`、`uia-settext`、`paste` 的选择。

A **single-file, stateless Windows desktop automation CLI**. One short-lived `powershell` process per invocation: no daemon, no HTTP server, no installer, no third-party dependencies.

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

The tool is **stateless**: each call is a fresh process; nothing persists between calls except the audit log and saved screenshots. Long chains can be batched in one process via the `script` command.

## Command Quick Reference

Each entry: command — what it does — minimal example.

### Screenshots (read)

- `shot [outPath]` — capture the whole virtual screen; it accepts at most one output path and rejects unknown flags or extra positions before capture. For a local full-resolution crop use `rect 0 2010 400 80 <outPath> --fit 0`; use that image's `.map.txt` with `imgclick` or `unmap`, and capture again after the window or layout changes.
- `win <sel>` — capture one window + its image-to-screen mapping; e.g. `win "Notepad" win.png --fit 900`
- `rect <x> <y> <w> <h>` — capture a region; e.g. `rect 100 100 800 600 r.png --grid`
- `zoom <x> <y> <w> <h> [scale]` — enlarge a small region with a mapping echo; e.g. `zoom 500 400 200 80 2 z.png`
- `wins` — list visible windows (pid / class / rect / title ...); e.g. `wins`
- `info <sel>` / `rect-of <sel>` — window details / just its rect; e.g. `rect-of 12345`
- `cursor` / `color-at <x> <y>` — cursor position / pixel color; e.g. `color-at 800 600`
- `find-color <x> <y> <w> <h> <#RRGGBB>` — first matching pixel in a region (LEDs, spinners); e.g. `find-color 0 0 400 200 #00FF00`
- `hash <sel|x y w h>` — region MD5 (for assert-hash); e.g. `hash "Notepad"`

### Windows

- `focus <sel>` — bring a window to the front, then RE-READ the same handle (foreground / minimized / visible / rect on screen); echoes both readings with `fg_ok=` and exits 1 when the window is not actually usable; e.g. `focus "Notepad"`
- `win-move <sel> <x> <y>` / `win-resize <sel> <w> <h>` — place / size a window; e.g. `win-move "Notepad" 0 0`
- `win-max` / `win-min` / `win-restore` / `win-close <sel>` — window state changes; e.g. `win-restore "Notepad"`
- `wait-win <sel> <sec>` / `wait-gone <sel> <sec>` — poll for appearance / disappearance; e.g. `wait-win "Save As" 10`
- `wait-stable <sel|x y w h> <sec>` — wait until two consecutive frames are pixel-identical; e.g. `wait-stable "Notepad" 5`

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
- `read-text <sel|x y w h>` — OCR the region, print lines + screen rects; e.g. `read-text "Some App" --max-lines 30`
- `assert-text <sel|x y w h> <needle...>` — OCR + exit-code check; e.g. `assert-text "Some App" "Ready"`

### Act (mouse — absolute screen pixels)

- `click` / `rclick` / `dblclick <x> <y>` — click at a point (optionally `--to <sel>` to activate + verify a window first); e.g. `click 800 600 --to "Notepad"`
- `move <x> <y>` / `hover <x> <y> [--dwell ms]` — move / stay (tooltips need a dwell); e.g. `hover 800 600 --dwell 1000`
- `drag <x1> <y1> <x2> <y2>` — press, interpolate, release; e.g. `drag 400 400 900 400`
- `press-down` / `drag-to` / `press-up` — the mid-state trio for surfaces that decide on release; e.g. `press-down 400 400` then `press-up 900 400`
- `wheel [amount] [x y] [--unit raw|notches] [--axis vertical|horizontal] [--to <sel>|--at <sel>] [--focus-first] [--verify-scroll [--expect-change x,y,w,h]|--expect-visible-text <needle>]` — scroll. Omitted amount still means -120 raw delta; defaults stay raw delta and vertical. Notches multiply an explicit amount by 120. Positive/negative means up/down vertically and right/left horizontally. `--to` checks that the explicit point, or current cursor when no x/y is given, hits the selected window; `--at` requires explicit x/y and never substitutes the window centre. Verification is opt-in and requires a selected window plus explicit amount/x/y. `--verify-scroll` reads the point's UIA ScrollPattern, with an explicit local pixel rectangle as a labeled pixel-only fallback; `--expect-visible-text` checks for a newly visible UIA name. Boundary, no-effect, target-change and unavailable states stay distinct, polling is capped at 13 samples and no input is retried. Example: `wheel -3 800 600 --unit notches --axis vertical --to "Some App"`.
- `relclick <sel> <dx> <dy>` — click relative to a window's top-left; the origin is the rect re-read after activation, and the click is refused when the point misses the target or another window (even a same-pid top-level) sits under it; e.g. `relclick "Notepad" 100 60`
- `imgclick <img> <ix> <iy>` — the ONLY supported way from a pixel you SAW in a saved image to a screen click (uses the image's `.map.txt` sidecar); e.g. `imgclick shots/win.png 120 40`

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

- `script <steps.json> [--dry-run]` — run a JSON list of steps in one process (guards as checkpoints); e.g. `script plan.json --dry-run`
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

## Permissions And Risk

This skill **clicks, types, reads/writes the clipboard and sends real file payloads into applications** — installing it is equivalent to handing the desktop's input devices to the agent that calls it. Run it only when the user asked for a desktop action, keep actions within the requested scope, and prefer read-only commands (`wins` / `uia-tree` / `read-text` / `screenshot` family) to explore first. The tool's audit log records act/text/clipboard commands **with payloads redacted** (`<redacted:Nchars>`), so logs are safe to read back.

**项目红线 / hard red line — messaging surfaces.** Never send a message or a file into a **real** chat, mail or any other person-facing conversation window (WeChat / QQ / DingTalk / Slack / Outlook / a browser webmail, and any window that stands for a human on the other side) unless the user, in this same turn, named **that recipient and that file** and confirmed it. `paste` / `paste-file` / `copy-file` / `keys` / `type` all reach whatever window is in the foreground, so a guard passing is *not* permission to send. 不得向任何真实聊天会话发送消息或文件；活体验收只用本项目自己创建、自己销毁的夹具（一个本地编辑器窗口 + 一个生成的测试文件）。已经开在屏幕上的聊天窗口不是夹具，"守卫绿了"不是发送许可。

## Self-Check After Installation

Run the offline gate once after installing (or after any environment change):

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>/scripts/desktop.ps1" selftest
```

It verifies the environment (PowerShell version, DPI awareness, OCR language packs) plus the tool's own behaviour contract. Read its three outcomes apart, because they mean three different things: a **FAIL** line is the tool being wrong — fix that, and it is the only outcome that blocks delivery; a **SKIP** line names a capability this machine or this engine cannot measure (no OCR language pack, a PATH without `powershell.exe`, no `git`), and it is neither a pass nor a defect — do not install packages to make a SKIP disappear, and do not read one as proof the road works; `--live` adds checks the offline declaration does not cover, so a live run legitimately reports more. The offline total is the same number on every engine and every PATH shape (that is what the SKIP accounting buys), so a total that disagrees with the version's declaration means a check was added or lost — not that your machine is odd.

## Detailed Reference

Flags, exit codes, output shapes and worked recipes live in **`reference.md`** (one level deep, in this same folder).
