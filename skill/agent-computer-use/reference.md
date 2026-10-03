# Agent Computer Use — Detailed Reference

One level below `SKILL.md`. Everything here is optional depth: the quick reference in `SKILL.md` is enough to start; come here for flags, exit codes and recipes.

## Invocation

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>/scripts/desktop.ps1" <command> [arguments...]
```

- Stateless: one fresh process per invocation, no daemon, no config file. The working directory does not matter; screenshot defaults go to `<repo>/shots/` unless you pass an output path.
- Every command prints an echo that states what it measured (rect, mapping, source road, counts). Read the echo — most "why did nothing happen" cases are answered there.
- Exit code: `0` = ok, `1` = error / refusal / failed verdict.

## Window Selectors (`<sel>`)

Anywhere a `<sel>` appears:

| form | meaning |
|---|---|
| `<number>` | pid (prefers the pid's foreground window, else its largest) |
| `<text>` | title substring (case-insensitive) |
| `proc:<name>` | process name |
| `class:<substr>` | window class substring |
| `t:<digits>` | force title matching for digit-only strings |

If a title/proc/class selector matches several windows, resolution **refuses and lists every candidate** — disambiguate with pid / proc: / class: / a longer title.

## Screenshots And Reading

- `shot [out] [--fit px] [--grid [step] | --no-grid] [--mark x,y] [--occlude off|warn|strict]` — whole virtual screen. `--fit` downscales wider crops and the echo carries the explicit scale; the grid is labelled in SCREEN pixels; `--mark` draws a candidate click point.
- `win <sel> [out] [--fit px|0] [--grid...] [--mark x,y]` — a window; echoes the image→screen mapping (`screen = image + (L,T)` or `(L + ix/scale, T + iy/scale)`).
- `rect <x> <y> <w> <h> [out] [--fit...] [--grid...] [--mark x,y]` — a region.
- `zoom <x> <y> <w> <h> [scale] [out]` — small region enlarged (default 2x) with mapping echo.
- `wins` — table of visible windows: pid / proc / class / popup / owner / main / rect / size / title.
- `info <sel>` · `rect-of <sel>` · `cursor` · `color-at <x> <y>` · `find-color <x> <y> <w> <h> <#RRGGBB> [--tolerance n] [--all]`.
- `hash <sel|x y w h>` — region MD5; input for `assert-hash`.
- `ocr-cap` — OCR engine limits + installed language packs.
- `status-summary [--json]` — read-only checkpoint: HEAD, cleanliness, latest offline selftest counts, latest live log, red count.

Screenshot files: `win` / `rect` / `zoom` write a `<image>.map.txt` sidecar next to the image — that sidecar is what `imgclick` / `unmap` use to map pixels back to the screen.

## Locating Elements

### The order (not a menu)

1. `find <text...>` — UIA first, OCR second; reports which road answered (`source=uia|ocr`).
2. `uia-find <sel> <nameSub> [typeRe]` — exact tree lookup; one automatic re-contact on the cold-start shape before a 0 is final.
3. `find-text` / `find-click` — the OCR road: line rect + ready centre, no control needed.
4. `imgclick <img> <ix> <iy>` — the only supported way from a pixel in a saved image to a screen click.

Never guess a click point from a fitted or downscaled screenshot.

### `find`

```
find <text...> [--target <sel>] [--region x,y,w,h] [--needle <text>] [--json]
```

- Read-only: never activates or raises a window.
- No `--target` / `--region` = the ACTUAL foreground window (echoed `via=foreground`).
- On a miss it names what BOTH roads measured (elements scanned / lines read) — a bare "not found" never appears.

### UIA family

- `uia-tree <sel> [maxDepth] [--paths|--no-paths] [--actions|--no-actions|--actions-all] [--json]`
  - Each line carries `path=/0/2/1` (child-index route from the root) and, on interactive nodes, `actions=[invoke,...]`.
  - Pattern probing is allowlisted by default (cross-process calls); `--actions-all` probes everything; `--no-actions` keeps stdout byte-identical to older releases. Cost self-reports on stderr: `actions-probed=K of M nodes (allowlist|all) elapsed=Xms`.
  - `actions=[]` = probed, no actions; no `actions=` field = not probed. The two are distinguishable on purpose.
- `uia-path <sel> @/0/2/1 [maxDepth]` — read-only path resolution; prints the node's line.
- `uia-find <sel> <nameSub> [typeRe]` — `<nameSub>` must not be empty (an empty substring would match everything and prove nothing).
- `uia-click <sel> <nameSub>` — InvokePattern, then centre fallback.
- `uia-click <sel> @/0/2/1 "Button|OK|123,45,80x24"` — **`@path` form**: the tool walks the route, re-verifies ControlType / Name / rect against the expected token copied from the `uia-tree` line, and on any mismatch prints `REFUSED: path=... stale` (expected/actual + fallback roads) and exits 1 **without clicking**. A path deeper than `maxDepth` self-reports `path depth N > walked M`.
- `uia-focus <sel> <nameSub>` · `uia-settext <sel> <nameSub> <file>` (ValuePattern write + readback; no keyboard, no clipboard). Both accept the `@path` form with the same verify-then-act contract.
- `a11y-probe <sel> [bigDepth]` — read-only: is this app's content exposed to UIA (`page-tree=exposed|collapsed`), i.e. can `uia-*` drive it or is CDP / OCR needed.

### OCR family

- `find-text <sel|x y w h> <needle...> [--all] [--scale auto|1|2|tiled]` — returns line rects of matching OCR lines. A hit is a LINE, not an occurrence (text twice on one line = one hit; `--index` selects lines).
- `find-click <sel|x y w h> <needle...> [--index n] [--aim-line]` — locate + click the needle's sub-span in one call.
- `read-text <sel|x y w h> [--file <png>] [--max-lines n | --all-lines] [--filter needle]` — OCR dump with rects; a very sparse large region gets a modal/scrim WARN (hint only, never changes the exit code). `--file` reads a saved capture instead of a live region: coords are then IMAGE px from the image's own top-left and every line is prefixed `img-rect=` (deliberately not `rect=`, so a file read cannot be pasted into a click), and `--json` is refused there because the pinned envelope has no field naming the coordinate space.
- `assert-text <sel|x y w h> <needle...>` — OCR + exit-code check.

## Acting (Mouse)

- `move` · `hover [--dwell ms]` (tooltips need the dwell) · `click` · `rclick` · `dblclick` — absolute screen pixels; `--to <sel>` activates + verifies a window first; `--guard-text <s>` / `--guard-region x,y,w,h=<s>` assert context BEFORE the click.
- `drag <x1> <y1> <x2> <y2> [--steps n] [--hold ms]` — press, interpolate, release.
- Mid-state trio (surfaces that decide on release): `press-down [--max-hold ms]` → `drag-to <x> <y>` → `press-up <x> <y>`. Watchdogs: a held button self-releases at the deadline, and any later invocation releases a button left down by a previous run.
- `wheel <amount> [x y | --at <sel>] [--focus-first]` — scroll (negative = down).
- `relclick <sel> <dx> <dy>` — click relative to a window's top-left.
- `imgclick <img> <ix> <iy> [--dry] [--stale-ok]` — reverse-map through the image's `.map.txt`; `--dry` prints the mapping without clicking; a moved/resized window fails the sidecar check unless `--stale-ok`.
- `unmap <img> <ix> <iy>` — mapping echo only, no click.

**Proof of effect (opt-in):** `--expect-change [x,y,w,h]` on the click family / drag / wheel hashes the region before and after and WARNs if pixel-identical — a WARN is not proof of failure (the effect may sit outside the rect). Default OFF; never changes the exit code.

**Expectations (verdicts):** `--expect <needle>` / `--expect-gone <needle> [--expect-region x,y,w,h] [--timeout s] [--interval ms] [--no-expect]` poll OCR after the action; an unmet expectation exits 1 ("clicked OK but expectation NOT met"). The verdict names the patience and polling interval actually used.

## Typing And Clipboard

- `type [--to <sel>] <text...> [--verify] [--verify-timeout <sec>]` — SendInput unicode: IME bypassed, CJK works. With `--to`, the target is verified foreground BEFORE keys are sent (no keys are sent if it did not come to the front); the foreground is re-checked after sending too.
- `type-in <x> <y> [--tab <n>] <text...>` — click a spot (webview forms: click alone gives no keyboard focus), optional TABs, then type.
- `keys [--to <sel>] <spec>` — raw SendKeys (`^s`, `%{F4}`, `{ENTER}`). SendKeys still honours the IME.
- `paste [--to <sel>] <file>` — UTF-8 file → clipboard → Ctrl+V; the previous clipboard is saved and restored; the payload tail is OCR-read back by default (a folded attachment chip is accepted on a named receipt instead — the receipt used is always named). `--no-expect` = send-only.
- `paste-file [--to <sel>] <path>` — a real file as FileDrop + Ctrl+V, with the same guard/readback family.
- `copy-file <path>` — put a file on the clipboard (stays there).

Clipboard write-back is verified; a clipboard that cannot be confirmed is reported, never silently assumed.

## Windows

- `focus <sel>` — restore + front; prints `fg_ok=True/False`.
- `win-move <sel> <x> <y>` · `win-resize <sel> <w> <h>` (visible size, DWM-corrected) · `win-max` / `win-min` / `win-restore` / `win-close`.
- `wait-win <sel> <sec>` / `wait-gone <sel> <sec>` — 500 ms polling with clear timeout messages.
- `wait-stable <sel|x y w h> <sec> [--interval ms]` — two consecutive identical frames; replaces fixed sleeps.
- `menu-pick <sel> <needle...> [--index n]` — resolve a popup MENU window, OCR its rows, click the matching row. Refuses anything that is not a menu-shaped window.
- `open-and-pick <sel> <opener-x> <opener-y> <needle...>` — click an opener, beat, shoot, click the first matching line (self-drawn dropdowns).
- `assert-window` / `assert-color` / `assert-hash` / `assert-stable` / `assert-changed` — verdicts as exit codes.

## Batch · Replay · Housekeeping

- `script <steps.json> [--dry-run] [--stop-on-error] [--shot-at n]` — a JSON array of steps in ONE process; `"to"` per step = foreground guard; asserts as checkpoints; `require-popup` arms a popup survival guard for later steps; `press-down`/`drag-to`/`press-up` are valid steps.
- `replay [<actions.log>] [--last n] [--grep s] [--go]` — re-run recorded act/text/clipboard commands; DRY by default. Redacted payloads (`<redacted:Nchars>`) are refused, never typed as placeholders.
- `shots-cleanup [--keep n] [--go] [--quarantine <dir>]` — bound the screenshot folder; dry by default; `--go` moves files into a quarantine dir with a MANIFEST (nothing is deleted). Since v2.6.0 the same bound is applied automatically after every capture (newest 100 by default; `DTX_SHOT_KEEP=<n>` changes it, `DTX_SHOT_AUTOTRIM=0` stops the automatic pass); it skips with a stated reason when no quarantine is configured, and never runs during selftest. The `--go` target, in order: `--quarantine <dir>`, then `DTX_QUARANTINE` from the process environment, then `DTX_QUARANTINE` from the User-scope registry, then Machine-scope, else the command refuses (exit 2) naming both remedies — no baked-in machine path.

## Occlusion (reads and guards)

Every pixel-reading command samples a 5x5 hit-test grid (WindowFromPoint, click-through overlays excluded). A covered target prints `scan=<read|guard|assert|hit> rect=(x,y,WxH) occluded=N% coveredBy=pid 'title' ...`. Guards (`--guard-text` / `--guard-region` / `assert-*`) REFUSE when occluded — a guard must never read a coverer's text and pass. Overrides: `--occlude off|warn|strict`, `--allow-occluded` downgrades a strict fail to a warning.

## Audit Log And Redaction

Every executed act / text / clipboard / uia-settext command appends one line to `shots/actions.log` (paths, coordinates, targets verbatim). Typed payloads and guard needles are stored as `<redacted:Nchars>`; `--log-payload` opts into verbatim recording. The log rotates at 512 KB (5 archives kept).

## Exit Codes

| code | meaning |
|---|---|
| 0 | ok / verdict passed |
| 1 | error, guard refusal, unmet expectation, failed assert, or a smoke-test failure |

## Worked Recipes

**Click a button by name (tree available):**
```
find "Save"                    # learn the road + centre
uia-click "MyApp" "Save"       # act; a refusal names why + fallbacks
```

**Click a control that has no Name (path handle):**
```
uia-tree "MyApp" 6             # copy the line for the target node
uia-path "MyApp" @/0/2/1/4     # read-only re-resolve
uia-click "MyApp" @/0/2/1/4 "Button||123,45,80x24"   # verify-then-act
```

**Type into a specific window (guarded):**
```
type --to "MyApp" "hello" --verify
```

**Send a file into a chat window:**
```
paste-file --to "MyChat" report.pdf
```

**Region screenshot → pixel click:**
```
win "MyApp" out/win.png --grid
imgclick out/win.png 120 40 --dry      # check the mapping first
imgclick out/win.png 120 40
```

**Prove a change happened:**
```
click 800 600 --to "MyApp" --expect-change
assert-changed "MyApp" 5 --interval 300
```

**Regression-check the environment:**
```
selftest
```
