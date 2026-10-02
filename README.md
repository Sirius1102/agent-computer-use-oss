# Agent Computer Use (Open Source Edition) v2.3.0

A **single-file, stateless Windows desktop automation CLI** built to be driven by an AI agent — or by you, from a shell.

`desktop.ps1` gives an agent the four primitives of "computer use": **see** (screenshots of screen/window/region, plus OCR), **point** (move/click/scroll/drag at real pixel coordinates), **type** (keyboard, clipboard, and direct UIA value-setting), and **read the UI tree** (UI Automation, plus a Chrome DevTools route). No daemon, no installer, no third-party dependencies — every command is one short-lived `powershell -File` invocation, so the whole tool is trivially auditable and hard to get into a stuck state.

> 🇨🇳 中文版文档见 [README.zh-CN.md](README.zh-CN.md)

## Why this design

- **Stateless by choice.** Each call spawns a fresh PowerShell process (~0.3–0.6 s). Slower than a resident host, but there is no background process to leak, crash, or debug. When something goes wrong, the failure is fully contained in one command's stdout and exit code.
- **Guarded by default.** Keystrokes physically go to whatever window is focused, so `type` / `keys` / `paste` / `paste-file` with `--to <sel>` **verify the target actually owns the foreground before sending a single key** — if it doesn't, the command fails with `ERROR` + exit 1 and nothing is sent. The foreground is re-checked *after* sending, so a mid-flight focus steal is a loud failure too. (`--force` opts out, legacy behavior.)
- **It says how it knows what it knows.** This is the design rule the whole feature set grew around: a number or a "not found" is worthless unless the command also prints the measurement it came from. So `find` reports `source=uia|ocr`; a miss names what *both* roads measured; `hit-window:` prints the window your click actually landed on; capture echoes print the image→screen mapping they used; `--expect` verdicts name the patience and polling interval that were really applied; `paste` names which receipt leg accepted a folded payload. **Zero is never evidence of absence**, and a check that can only pass is not a check.
- **Auditable.** Every executed act/text/clipboard/uia-settext command appends one line to `shots/actions.log`: UTC timestamp, command, arguments, resolved target. Typed payloads and guard needles are stored as `<redacted:Nchars>` (pass `--log-payload` to record them verbatim); file *paths* are recorded, never file or clipboard contents. The log rotates at 512 KB keeping the 5 newest archives, and `replay` refuses any step whose payload was redacted — replaying the placeholder would type the placeholder.
- **Self-testing.** `selftest` runs the offline gate (currently ~590 checks: source lints for the PowerShell 5.1 list-return trap, BOM/ASCII invariants, unit checks of every pure helper, and contract checks that pin documented key sets and README/dispatcher agreement). `selftest --live` adds real desktop round-trips against synthetic `DTX-*` fixture windows it owns, never against your apps.
- **DPI-safe.** The process opts into **Per-Monitor V2** DPI awareness at startup (Windows 10 1703+; falls back to System-aware on older builds), before any coordinate is read. Without awareness, Windows virtualizes every value by the display scale factor (a 2100×1350 window reads as 1400×900 at 150 %), screenshots come out cropped, and clicks land in the wrong place. Per-Monitor V2 additionally keeps secondary monitors at *different* scale factors (mixed-DPI multi-monitor) pixel-exact. Run `dpi` to see the mode actually obtained and every monitor's bounds in physical pixels.
- **Pure ASCII source.** PowerShell 5.1 misparses BOM-less UTF-8 scripts on non-ANSI systems, so the script contains zero non-ASCII literals (it does carry a UTF-8 BOM, which is what makes 5.1 decode it as UTF-8). Non-ASCII text (CJK and friends) enters through `paste <file>` or `uia-settext <sel> <name> <file>`, which read external UTF-8 files.

## Requirements

- Windows 10/11 with PowerShell 5.1 (ships with Windows) or later
- OCR uses the built-in Windows.Media.Ocr engine; the languages installed on your machine are the languages available (`ocr-cap` lists them)
- No modules, no packages, nothing to install

## Quick start

```powershell
# what's on screen?
powershell -ExecutionPolicy Bypass -File desktop.ps1 wins

# screenshot of one window (title substring, pid, proc:notepad or class:<substr>)
powershell -ExecutionPolicy Bypass -File desktop.ps1 win notepad shot.png

# where is this text, in screen pixels? (UIA first, OCR second, says which answered)
powershell -ExecutionPolicy Bypass -File desktop.ps1 find "File" --to notepad

# click at absolute screen coordinates
powershell -ExecutionPolicy Bypass -File desktop.ps1 click 800 500

# send Ctrl+S, but only if the target window really is in the foreground
powershell -ExecutionPolicy Bypass -File desktop.ps1 keys --to notepad "^s"

# type CJK text: write it to a UTF-8 file, paste it (clipboard restored, tail read back)
powershell -ExecutionPolicy Bypass -File desktop.ps1 paste --to notepad .\samples\selftest.txt

# send a file to a chat app: file on the clipboard as a file drop, then Ctrl+V
powershell -ExecutionPolicy Bypass -File desktop.ps1 paste-file --to "MyChatWindow" C:\path\to\file.zip
```

`help <command>` prints one command's entry (flags, semantics, version notes); `help --<flag>` prints every line that mentions a flag.

## Window selector `<sel>`

- A **numeric PID** matches windows by process id only. If several of that process's windows exist (main window + modal dialog), the one currently in the **foreground wins** (`pick=fg`); otherwise the largest non-minimized one (`pick=largest`).
- Any other string is a **case-insensitive title substring**; `proc:<name>` matches the process name exactly, `class:<substr>` matches the window class as a substring.
- Prefix with `t:` / `title:` to force title matching (needed when the substring itself is all digits).
- When a title/proc/class selector matches **several** windows the tool *refuses* and prints every candidate — it will not silently pick the largest one. Disambiguate with a pid, `proc:` or `class:`.
- Minimized windows (parked at −32000,−32000) are only used as a last resort.

## Commands

All coordinates are **physical screen pixels**. `|` marks the read-only/assertion commands that never move anything.

### read and measure

| command | what it does |
|---|---|
| `shot [outPath] [--fit px] [--grid [step]] [--mark x,y]` | capture the whole virtual screen |
| `win <sel> [outPath] [--fit px] [--grid] [--mark x,y]` | capture one window; echoes the image→screen mapping and a labelled `occluded=N%` verdict |
| `rect <x> <y> <w> <h> [outPath] [--fit px] [--grid] [--mark x,y]` | capture a region (default `--fit 900`, so eyeballed coordinates survive viewer downsampling) |
| `zoom <x> <y> <w> <h> [scale] [outPath]` | capture a small region **enlarged** (default 2x, nearest-neighbor) + echo the `screen = (x + ix/scale, y + iy/scale)` mapping |
| `wins` | list visible windows: `pid proc class popup owner main rect size title` |
| `info <sel>` | pid / handle / proc / class / owner / main / rects / `pick=` (why this window was chosen) |
| `rect-of <sel>` | print `x y w h` only — handy for relative math |
| `cursor` | current cursor position |
| `dpi` | DPI awareness mode obtained at startup + every monitor's bounds in physical pixels |
| `color-at <x> <y>` | pixel colour as `#RRGGBB` (status LEDs, spinners that have no text) |
| `find-color <x> <y> <w> <h> <#RRGGBB> [--tolerance n] [--all]` | first (or all, capped at 500) matching pixels in a region |
| `hash <sel|x y w h>` | MD5 of a region capture — the input for `assert-hash` |
| `find <text...> [--target <sel>] [--region x,y,w,h] [--needle <text>]` | **composite locator**: UIA first, OCR over the same rect as fallback, and it reports `source=uia|ocr`; a miss names what both roads measured |
| `find-text <sel|x y w h> <needle...> [--all] [--scale auto|1|2|tiled]` | OCR a region, return the screen rect(s) of matching lines + ready-to-use centres |
| `read-text <sel|x y w h> [--max-lines n | --all-lines] [--filter needle]` | OCR a region, print lines with their screen rects; `--filter` keeps matching lines |
| `ime` | the foreground thread's keyboard layout / IME state (`ime=yes` → `keys` may be eaten by a candidate window; `type` bypasses the IME) |
| `ime-state` | conversion mode (alphanumeric vs native), read through the default IME window |
| `ime-en [hkl]` | switch the foreground thread's conversion mode to alphanumeric and **read it back**; the echo prints the exact command that restores the old mode |
| `ime-cn [mode]` | switch to native (Chinese composition) and read back; same restore hint |
| `ocr-cap` | read-only: OCR engine `MaxImageDimension`, installed language packs, current language |
| `a11y-probe <sel> [bigDepth]` | read-only: control counts at two depths + interactive controls in the page area → `page-tree=exposed|collapsed`, i.e. whether `uia-*` can drive this app at all |
| `challenge-probe <sel>` | read-only: OCR a verification challenge and report match/confidence/staleness + a handoff block. **There is no solver, by design** (see limitation 12) |
| `status-summary [--json]` | read-only checkpoint of a working copy: HEAD, clean/ahead, offline selftest counts, newest live log and its red count, leftover fixture windows |
| `shots-cleanup [--keep n] [--go] [--quarantine <dir>]` | bound the runtime screenshot folder — **dry run by default**, and `--go` *moves* files to a quarantine folder with a manifest instead of deleting them |
| `help [<cmd>|--<flag>]` | this page, one command's entry, or every line mentioning one flag |

### assertions (exit-code checkpoints, nothing is clicked)

| command | what it does |
|---|---|
| `assert-window <sel>` | exit 0 when a window matches |
| `assert-text <sel|x y w h> <needle...>` | OCR + exit-code check; `--allow-occluded` / `--occlude` as elsewhere |
| `assert-color <x> <y> <#RRGGBB> [tol]` | pixel equality as a verdict (LEDs, spinners) |
| `assert-hash <sel|x y w h> ==|!= <hash>` | a region MD5 against one from `hash` |
| `assert-stable <sel|x y w h> <sec>` | two identical consecutive frames = settled (never true for a blinking cursor) |
| `assert-changed <sel|x y w h> <sec>` | the opposite: wait until the region *does* change; a timeout says the action probably did nothing |

### wait

| command | what it does |
|---|---|
| `wait-win <sel> <timeoutSec>` | poll (500 ms) until a matching window appears |
| `wait-gone <sel> <timeoutSec>` | poll until it disappears (dialog closed, action took effect) |
| `wait-stable <sel|x y w h> <timeoutSec> [--interval ms]` | poll until two consecutive captures hash identical — replaces fixed sleeps |

### act (absolute screen coordinates)

| command | what it does |
|---|---|
| `move <x> <y>` | move the cursor |
| `hover <x> <y> [--dwell ms]` | move and **stay** — tooltips need the dwell (default 800 ms) to render |
| `click <x> <y>` | left click; `--to <sel>` activates and verifies a window first, `--guard-text`/`--guard-region` assert context *before* the click |
| `rclick <x> <y>` | right click, same guards |
| `dblclick <x> <y>` | double left click, same guards |
| `drag <x1> <y1> <x2> <y2> [--steps n] [--hold ms]` | press, interpolate, release (windows, sliders, scrollbars); steps default 14, hold default 120 ms |
| `press-down <x> <y> [--max-hold ms]` | press and **leave it down** so you can look before letting go. Three watchdogs, because a held button is machine-wide state: an in-process deadline, a release-on-next-invocation, and an echo that names the deadline |
| `drag-to <x> <y> [--steps n]` | travel **while held** from wherever the cursor is; refuses when nothing is pressed |
| `press-up <x> <y>` | let go — the drop is where the verdict lands, so `--expect-change` is honoured here; refuses when nothing is down |
| `wheel <amount> [x y | --at <sel>] [--focus-first]` | scroll (negative = down); echoes the window the event actually lands on |
| `relclick <sel> <dx> <dy>` | click inside a window, relative to its top-left — survives window moves |
| `find-click <sel|x y w h> <needle...> [--index n] [--aim-line]` | OCR locates the text and clicks the needle's own sub-span of the matched line (one call instead of find-text → read echo → click) |
| `imgclick <outPath> <ix> <iy> [--dry] [--stale-ok]` | reverse-map a pixel you read off a saved image through its `.map.txt` sidecar and click it; a sidecar whose window moved >2 px since capture **fails** |
| `unmap <outPath> <ix> <iy>` | the same mapping, printed — no click, no log line |
| `win-move <sel> <x> <y>` | place the window (visible top-left at x,y) |
| `win-resize <sel> <w> <h>` | set the **visible** size (DWM-border corrected) |
| `win-max <sel>` | maximize |
| `win-min <sel>` | minimize |
| `win-restore <sel>` | restore from minimized/maximized |
| `win-close <sel>` | graceful `WM_CLOSE` (not a kill) |
| `menu-pick <sel> <needle...> [--index n] [--allow-window]` | resolve a **popup menu** window, OCR its rows, click the matching one; refuses anything that is not a menu shape (the `WS_POPUP` style bit is *not* the test — see limitation 9) |
| `open-and-pick <sel> <opener-x> <opener-y> <needle...> [--region x,y,w,h]` | one process: click the opener, wait a beat, shoot the target and click the first line containing the needle — for self-drawn dropdowns `menu-pick` refuses by design |

### text (always reconciles target vs. actual foreground)

| command | what it does |
|---|---|
| `focus <sel>` | restore + bring to front; prints `fg_ok=True/False` |
| `type [--to <sel>] <text...> [--verify] [--force]` | SendInput Unicode, so characters bypass the IME entirely and CJK works directly; `--verify` OCR-reads the target afterwards and fails loudly if the text is not visible (skip it for password fields) |
| `type-in <x> <y> [--tab <n>] <text...> [--verify]` | click a spot, send *n* TABs, type — built for webview/Electron forms where **a click alone never gives keyboard focus** |
| `keys [--to <sel>] <spec> [--force]` | raw SendKeys spec: `^s`, `%{F4}`, `{ENTER}` (SendKeys still honours the IME) |
| `paste [--to <sel>] <file> [--expect <s>|--no-expect] [--force]` | UTF-8 file → clipboard → Ctrl+V, previous clipboard restored. Readback is **on by default**: the payload tail is OCR-read back, and a payload too long to show its tail (it folded into an attachment chip) is accepted on a named *receipt* instead — never silently |
| `--guard-text <needle>` / `--guard-region x,y,w,h=<needle>` | with the text commands: send only if the needle is visible on the target — the tool enforces "only talk to this conversation". An occluded guard region fails *before* the OCR, so a guard can never read a coverer's text |

### clipboard

| command | what it does |
|---|---|
| `copy-file <path>` | put a file on the clipboard as `FileDrop`, self-verified; deliberately leaves it there |
| `paste-file [--to <sel>] <path> [--guard-text <s>] [--force]` | copy-file + foreground guard + content guard + Ctrl+V + clipboard restore; default-on readback looks for the **file name** |

### occlusion switches (every pixel-reading command)

`win`/`rect`/`shot`/`find-text`/OCR roads sample a 5×5 hit-test grid (`WindowFromPoint`, not rectangle overlap, so click-through full-screen overlays and `Program Manager` never count as coverers) and print `scan=<role> rect=(x,y,WxH) occluded=N% coveredBy=pid 'title'`, plus a stderr warning naming **every** coverer. Guard and `assert-*` commands **refuse** when occluded; plain reads never fail on occlusion (the needle may sit in the visible part). Switches: `--occlude off|warn|strict`, `--occlude-grid n`, `--allow-occluded`.

### ui automation (only if the app exposes its accessibility tree)

| command | what it does |
|---|---|
| `uia-tree <sel> [maxDepth]` | dump the control tree; the header shows which hwnd was scanned and the depth actually walked |
| `uia-find <sel> <nameSub> [typeRe]` | search elements by name/type. An empty needle is **refused** (it would match everything and prove nothing); a first 0-hit contact with a shallow tree is re-probed **once** before 0 becomes a verdict (UIA cold start) |
| `uia-click <sel> <nameSub>` | InvokePattern, falling back to clicking the element's centre |
| `uia-focus <sel> <nameSub>` | SetFocus |
| `uia-settext <sel> <nameSub> <file>` | write a UTF-8 file's content via ValuePattern, readback-verified — no keyboard, no clipboard |

UIA roots are resolved from the **selected window handle**, so dialogs that share a PID with their main window are addressed precisely.

### chrome / page content

Chrome ≥136 refuses a debug port on the **default profile** ("DevTools remote debugging requires a non-default data directory") — measured, not folklore. So there are two routes, and they are not interchangeable.

| command | what it does |
|---|---|
| `chrome-a11y <on|off>` | the route for a **default profile**: relaunch Chrome with `--force-renderer-accessibility` so the page DOM reaches the UIA tree, then `uia-find`/`uia-click`/`read-text` work on web content. Measures the page-area tree before and after and refuses to claim success |
| `chrome-menu-read` | UIA: open Chrome's own app menu, list every `MenuItem` name it exposes, then dismiss it with Escape **without clicking anything** — how you get evidence on a browser that is still in use |
| `chrome-tabs [--json]` | CDP: enumerate open tabs (id / title / **host+port only** — a token can sit in the path as happily as in the query, so neither is ever printed) |
| `chrome-read <sel>` | CDP: visible text of the matching tab's page |
| `chrome-find <sel> <text...>` | CDP: innermost element containing the text → physical screen rect + centre (scale measured per call) |
| `chrome-click <sel> <text...> [--dry]` | CDP: `chrome-find`, then a regular injected click on its centre; DOM synthetic clicks are deliberately not used |
| `chrome-debug-off` | CDP: graceful close + relaunch **without** the debug flag, and verify the endpoint stopped answering |

The CDP route only ever talks to `127.0.0.1`; `0.0.0.0`, LAN addresses, bare ports and hostnames are refused by name.

### batch

| command | what it does |
|---|---|
| `script <steps.json> [--dry-run] [--stop-on-error] [--shot-at n]` | run a JSON array of steps **in one process**: per-step `to` is a hard foreground guard (a guard failure aborts everything), asserts are checkpoints, `retry`/`intervalMs` per step, content guards. `require-popup <sel>` arms a popup-survival guard; `release-popup` disarms it |
| `replay [<actions.log>] [--last n] [--grep s] [--go]` | re-run recorded act/text/clipboard commands — **dry run by default**, `--go` executes. Redacted payloads are refused, and a log slice carrying a popup-guard abort marker is refused outright |
| `selftest [--live]` | the tool's own regression gate: source lints, unit checks of every pure helper, contract checks, and with `--live` real round-trips against synthetic `DTX-*` windows |

### script step schema

The step file is **a JSON array** — do not wrap it in `{"steps": [...]}`. Each step has exactly one action key (named like the command) plus optional fields: `to` (hard foreground guard), `guard-text`, `guard-region`, `expectText`, `expectGone`, `index`, `retry`, `intervalMs`, `timeoutSec`, `require-popup`, `release-popup`, `must-be-foreground`.

```json
[
  { "desc": "bring the window forward (hard foreground guard)", "focus": "Notepad" },
  { "desc": "type with a content guard", "type": ["QX EXAMPLE TEXT"], "to": "Notepad", "guard-text": "Edit" },
  { "desc": "OCR decides where to click", "find-click": ["Notepad", "File"], "expectText": "Open" },
  { "desc": "checkpoint", "assert-text": ["Notepad", "Open"] },
  { "desc": "settle", "sleep": 500 }
]
```

`--dry-run` parses and plans without touching anything; run it before every real `script`.

## Taking a coordinate off the screen — the order, not a menu

1. `find <text>` — UIA first, OCR second, and it **says** which road answered.
2. `uia-find <sel> <name>` — exact name/rect/enabled/offscreen, with the cold-start re-probe.
3. `find-text` / `find-click` — the OCR road: line rect plus a ready-to-use centre, no control needed.
4. `imgclick <img> <ix> <iy>` — the **only** supported way from a pixel you saw in a saved image to a screen click: it reads the `.map.txt` that `win`/`rect`/`zoom` wrote beside that image.

Guessing a point off a fitted or downscaled screenshot is not step 5 and is not a method. It has been measured in one session: four clicks placed that way, all four wrong, each one costing a retry cycle to notice.

## Known limitations (learned the hard way)

1. **Chromium-shell apps** (Electron/Tauri-style editors, chat clients) often expose an accessibility tree that stops at `Pane` — `uia-*` is useless there; fall back to screenshots + coordinates. Setting the `SPI_SETSCREENREADER` system flag does **not** make Chromium expand its tree (tested); the only reliable route is restarting the target app with `--force-renderer-accessibility` (`chrome-a11y` does exactly that, and verifies it).
2. **UIA's first contact can be shallow.** The a11y tree is lit up *by a client connecting*, and often only after the walk that triggered it has finished. `uia-find` therefore re-contacts once before letting 0 become a verdict — and a still-empty re-contact says "no such Name", never "nothing is there".
3. **"Window focused" ≠ "input box focused".** Pasting into a Chromium input requires clicking the input first (`relclick`), then `paste`. Verify with a screenshot, never trust the command echo alone.
4. **Windows common file dialogs**: the "File name" field is a `Pane` exposing no writable UIA pattern by design; `uia-settext` reports this and tells you to fall back to `click` + `paste`.
5. **`SetForegroundWindow` has a foreground lock** — a background process sometimes cannot steal focus (Windows flashes the taskbar instead). The guard turns that silent failure into a loud `ERROR` instead of keystrokes landing in the wrong app. Targeting the desktop (`Program Manager`) is especially affected; that is Windows, not a bug here.
6. **Single-instance apps** (e.g. Windows 11 Notepad opens tabs in the existing process): the PID returned by `Start-Process` may own no top-level window. Use `wins` to find the real one.
7. **Webview/Electron forms: a click gives selection, not keyboard focus.** Typing/pasting silently does nothing. Fix: send one `{TAB}` after clicking — `type-in <x> <y> --tab 1 <text>` packages exactly this.
8. **Active IMEs swallow plain keystrokes** (a space may pick a candidate instead of typing). `ime` shows the state; `type`/`type-in` go through SendInput Unicode and never touch the IME; `keys` still does. If a keystroke must land and an IME is active, prefer `paste` — the clipboard path never goes through it.
9. **The `WS_POPUP` style bit is not "is a menu".** The desktop, the Settings shell, chat clients and several app shells carry it. `menu-pick` identifies menus by class **and shape**, and refuses a whole surface on purpose — picking a row out of a full window would click whatever happens to contain the text.
10. **Popup windows can share everything.** A promo/dialog window and an app's real main window can share pid, class *and* `WS_POPUP`; `popup=` cannot separate them, which is why `wins` rows carry `owner=` (GW_OWNER) and `main=` (the one window a pid means).
11. **A screenshot is not a live view.** `win` shows whatever physically covers the window; read the `occluded=N%` echo before trusting a capture, and raise the window when it matters.
12. **Verification challenges are refused, not solved.** `challenge-probe` reads and reports; it never solves. These challenges exist to stop scripted claiming, and solving them escalates the account's own risk control. `--allow-attempt` permits exactly one caller-named click, and a surviving challenge trips a fuse that blocks further attempts on that image.
13. **Reading a whole chat window can surface secrets.** A `read-text` over a full messaging window has been observed to return a payment URL carrying a session key. Use `--max-lines`/`--filter`, and never log raw payloads you did not have to log.
14. **`selftest --live` touches the real desktop.** It creates and closes its own `DTX-*` fixture windows; run it only when nothing else needs the foreground, and note that the fixture processes keep System-aware DPI while the tool process opts into Per-Monitor V2 (harmless on one monitor; on mixed-DPI multi-monitor a fixture can land offset).
15. **Keystrokes are physical input** — the user should not touch mouse/keyboard while an agent drives, and an agent should confirm the target window from a screenshot before irreversible actions (sending messages, deleting things).

## Screenshot coordinate system (read once, saves misclicks)

All captures are raw screen grabs in **physical pixels, 1:1 with the screen** — `shot` covers the whole virtual screen, `win`/`rect`/`zoom` cover a region at a self-reported origin. So: `screen = image + (origin)`, and every capture echo prints the mapping it used. Chat/AI viewers often *display* a 4K screenshot at 50 %, but the file itself is unscaled — measure from the echo, never from how big the image looks. Window rects come from `DWMWA_EXTENDED_FRAME_BOUNDS` (the *visible* frame; `GetWindowRect`'s invisible 7–11 px resize border would offset every `win` capture and `relclick`), and `win` shows whatever physically covers the window — bring it to front first if occlusion matters.

`--fit` deliberately *downscales* wide crops and prints the scale it used; `--grid` overlays coordinates in **screen** pixels on the saved PNG only (hash/OCR judge the untouched pixels); `--mark x,y` draws a crosshair so you can confirm where a click would land before performing it.

## Testing

```powershell
powershell -ExecutionPolicy Bypass -File desktop.ps1 selftest          # offline gate, no desktop touched
powershell -ExecutionPolicy Bypass -File desktop.ps1 selftest --live    # adds real round-trips on its own fixture windows
```

The offline gate is a hard requirement before committing: it pins the version string across `desktop.ps1`, both READMEs and `CHANGELOG.md`, pins that the tracked-file inventory written in both READMEs equals `git ls-files`, pins that both language READMEs document the *same* command set, and pins that every dispatcher command has a help entry. Exit code is non-zero on any `FAIL`.

## Repository layout

```
desktop.ps1            # the entire tool (tracked=7 counts this file)
README.md              # this document
README.zh-CN.md        # the Chinese edition (same command set, enforced by a gate rule)
CHANGELOG.md           # release history
LICENSE                # MIT
samples/selftest.txt   # CJK sample for verifying the paste path
shots/                 # runtime dir (gitignored): default screenshots + actions.log
.cowork-temp/          # runtime dir (gitignored): --live logs
```

The tracked-file inventory of this repository is 7 files (`tracked=7`, asserted against `git ls-files`).

## License

MIT — see [LICENSE](LICENSE).
