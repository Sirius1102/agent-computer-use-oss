# Agent Computer Use (Open Source Edition)

A **single-file, stateless Windows desktop automation CLI** built to be driven by an AI agent — or by you, from a shell.

`desktop.ps1` gives an agent the four primitives of "computer use": **see** (screenshots of screen/window/region), **point** (move/click/scroll at real pixel coordinates), **type** (keyboard, clipboard, and direct UIA value-setting), and **read the UI tree** (UI Automation). No daemon, no installer, no third-party dependencies — every command is one short-lived `powershell -File` invocation, so the whole tool is trivially auditable and hard to get into a stuck state.

> 🇨🇳 中文版文档见 [README.zh-CN.md](README.zh-CN.md)

## Why this design

- **Stateless by choice.** Each call spawns a fresh PowerShell process (~0.3–0.6 s). Slower than a resident host, but there is no background process to leak, crash, or debug. When something goes wrong, the failure is fully contained in one command's stdout and exit code.
- **Guarded by default.** Keystrokes physically go to whatever window is focused, so `type` / `keys` / `paste` / `paste-file` with `--to <sel>` **verify the target actually owns the foreground before sending a single key** — if it doesn't, the command fails with `ERROR` + exit 1 and nothing is sent. (`--force` opts out, legacy behavior.)
- **Auditable.** Every executed act/text/clipboard/uia-settext command appends one line to `shots/actions.log`: UTC timestamp, command, arguments, resolved target. It records file *paths* only — never clipboard contents or file bodies.
- **DPI-safe.** `SetProcessDPIAware()` runs before any coordinate is read. Without it, Windows virtualizes every value by the display scale factor (a 2100×1350 window reads as 1400×900 at 150 %), screenshots come out cropped, and clicks land in the wrong place.
- **Pure ASCII source.** PowerShell 5.1 misparses BOM-less UTF-8 scripts on non-ANSI systems, so the script contains zero non-ASCII literals. Non-ASCII text (CJK and friends) enters through `paste <file>` or `uia-settext <sel> <name> <file>`, which read external UTF-8 files.

## Requirements

- Windows 10/11 with PowerShell 5.1 (ships with Windows) or later
- No modules, no packages, nothing to install

## Quick start

```powershell
# what's on screen?
powershell -ExecutionPolicy Bypass -File desktop.ps1 wins

# screenshot of the largest window matching a title substring (or a numeric PID)
powershell -ExecutionPolicy Bypass -File desktop.ps1 win notepad shot.png

# click at absolute screen coordinates
powershell -ExecutionPolicy Bypass -File desktop.ps1 click 800 500

# send Ctrl+S, but only if the target window really is in the foreground
powershell -ExecutionPolicy Bypass -File desktop.ps1 keys --to notepad "^s"

# type CJK text: write it to a UTF-8 file, paste it (clipboard is restored after)
powershell -ExecutionPolicy Bypass -File desktop.ps1 paste --to notepad .\samples\selftest.txt

# send a file to a chat app: put it on the clipboard as a file drop and Ctrl+V
powershell -ExecutionPolicy Bypass -File desktop.ps1 paste-file --to "MyChatWindow" C:\path\to\file.zip
```

## Window selector `<sel>`

- A **numeric PID** matches windows by process id only. If several of that process's windows exist (main window + modal dialog), the one currently in the **foreground wins** (`pick=fg`); otherwise the largest non-minimized one (`pick=largest`).
- Any other string is a **case-insensitive title substring**.
- Prefix with `t:` / `title:` to force title matching (needed when the substring itself is all digits).
- Minimized windows (parked at −32000,−32000) are only used as a last resort.

## Commands

### read
| command | what it does |
|---|---|
| `shot [outPath]` | capture the whole virtual screen |
| `win <sel> [outPath]` | capture one window |
| `rect <x> <y> <w> <h> [outPath]` | capture a region |
| `wins` | list visible windows (pid, rect, title) |
| `info <sel>` | pid / handle / window & client rects / iconic / foreground |
| `rect-of <sel>` | print `x y w h` only — handy for relative math |
| `cursor` | current cursor position |
| `wait-win <sel> <timeoutSec>` | poll until a matching window appears |
| `wait-gone <sel> <timeoutSec>` | poll until it disappears (dialog closed, etc.) |

### act (absolute screen coordinates)
| command | what it does |
|---|---|
| `move <x> <y>` / `click <x> <y>` / `rclick <x> <y>` / `dblclick <x> <y>` | cursor + buttons |
| `wheel <amount> [x y \| --at <sel>]` | scroll (negative = down); optionally move the cursor to a position or window centre first |
| `relclick <sel> <dx> <dy>` | click relative to the window's top-left — matches `win` screenshots 1:1, survives window moves |

### text (always reconciles target vs. actual foreground)
| command | what it does |
|---|---|
| `focus <sel>` | restore + foreground; prints `fg_ok=True/False` |
| `type [--to <sel>] <text...> [--force]` | ASCII text via SendKeys (specials escaped) |
| `keys [--to <sel>] <spec> [--force]` | raw SendKeys spec: `^s`, `%{F4}`, `{ENTER}` |
| `paste [--to <sel>] <file> [--force]` | UTF-8 file → clipboard → Ctrl+V; previous clipboard (text or file list) restored afterwards |

### clipboard
| command | what it does |
|---|---|
| `copy-file <path>` | put a file on the clipboard as FileDrop, self-verified; deliberately leaves it there |
| `paste-file [--to <sel>] <path> [--force]` | copy-file + foreground guard + Ctrl+V + clipboard restore |

### ui automation (only if the app exposes its accessibility tree)
| command | what it does |
|---|---|
| `uia-tree <sel> [maxDepth]` | dump the control tree (header shows which hwnd was scanned) |
| `uia-find <sel> <nameSub> [typeRe]` | search elements by name/type |
| `uia-click <sel> <nameSub>` | InvokePattern, falls back to clicking the element's centre |
| `uia-focus <sel> <nameSub>` | SetFocus |
| `uia-settext <sel> <nameSub> <file>` | write a UTF-8 file's content via ValuePattern with readback verification — no keyboard, no clipboard |

UIA roots are resolved from the **selected window handle**, so dialogs that share a PID with their main window are addressed precisely.

Exit codes: `0` success, `1` failure (`ERROR: <reason>` on stdout).

## Known limitations (learned the hard way)

1. **Chromium-shell apps** (Electron/Taurin-style editors, chat clients) often expose an accessibility tree that stops at `Pane` — `uia-*` is useless there; fall back to screenshots + coordinates.
2. **"Window focused" ≠ "input box focused".** Pasting into a Chromium input requires clicking the input first (`relclick`), then `paste`. Verify with a screenshot, never trust the command echo alone.
3. **Windows common file dialogs**: the "File name" field is a `Pane` that exposes no writable UIA pattern by design; `uia-settext` reports this and tells you to fall back to `click` + `paste`.
4. **`SetForegroundWindow` has a foreground lock** — a background process sometimes cannot steal focus (Windows flashes the taskbar instead). The guard turns this silent failure into a loud `ERROR` instead of keystrokes landing in the wrong app. Targeting the desktop (`Program Manager`) is especially affected; this is Windows, not a bug.
5. **Single-instance apps** (e.g., Windows 11 Notepad opens tabs in the existing process): the PID returned by `Start-Process` may own no top-level window. Use `wins` to find the real one.
6. Keystrokes are physical input — **the user should not touch mouse/keyboard while an agent drives**, and an agent should confirm the target window from a screenshot before irreversible actions (sending messages, deleting things).

## Repository layout

```
desktop.ps1            # the entire tool
samples/selftest.txt   # CJK sample for verifying the paste path
shots/                 # runtime dir (gitignored): default screenshots + actions.log
```

## License

MIT — see [LICENSE](LICENSE).
