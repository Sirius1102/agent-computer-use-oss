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

- `shot [out] [--fit px] [--grid [step] | --no-grid] [--mark x,y] [--occlude off|warn|strict]` — whole virtual screen; accepts at most one output path and rejects unknown flags or extra positions before capture. For a local full-resolution crop use `rect 0 2010 400 80 <outPath> --fit 0`; use its `.map.txt` with `imgclick` or `unmap`, and recapture after the window or layout changes. `--fit` downscales wider crops and the echo carries the explicit scale; the grid is labelled in SCREEN pixels; `--mark` draws a candidate click point.
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
- `read-text <sel|x y w h> [--file <png>] [--max-lines n | --all-lines] [--filter needle]` — OCR dump with rects; a large region always self-reports its read quality as `readability=<n> lines per 100k px2 (area=..., warn-below=..., band=...)` (v2.9.0), and a shouted modal/scrim WARN is reserved for reads under 0.1 lines per 100k px2 - the zone where the result cannot support "it is not there". find-text / assert-text / expect keep the 1.0/1.5 area bands untouched because there the read IS the claim of absence. Hint only either way: never changes the exit code; --min-line-density moves the line, 0 silences label and WARN together. `--file` reads a saved capture instead of a live region: coords are then IMAGE px from the image's own top-left and every line is prefixed `img-rect=` (deliberately not `rect=`, so a file read cannot be pasted into a click), and `--json` is refused there because the pinned envelope has no field naming the coordinate space. v2.8.0, file mode only: --scale tiled really subdivides the image (it halves the LONG side to choose the subdivision - the engine limit alone never splits a screenshot), and a 0-line read of any capture of >= 30000 px2 goes through a retry LADDER (v2.8.1: whole image at 2x, then four un-upscaled overlapping crops) whose every pass is named in the header with its own count, including a pass skipped because --max-tiles was too small (--no-tile opts out); the sparse WARN in file mode reads "image is WxH", not "region".
- `assert-text <sel|x y w h> <needle...>` — OCR + exit-code check.

### Profile And Calibration (PT family)

These three read a surface and compare readings. None of them clicks, types, activates or writes a profile.

- `pt-profile <sel|--file <png>> [--samples 1..16] [--save <path>]` — write ONE surface down as a profile JSON: window identity (pid/proc/class/title/rect), a UIA tree summary and the OCR lines in WINDOW-RELATIVE coordinates (image px with `--file`). `--samples N` reads the same surface N times and keeps only lines every pass saw (median position, lower middle on an even count). `ocrConf` is `null` by contract — the engine exposes no per-line confidence, so printing 0.9 would be invented.
- `pt-anchor <profile> --needle <text> [--strict] [--max-drift px] [--file <png>]` — re-read the surface the profile names and report how far the named line really moved: `match=exact|fold|substring`, `drift=(dx,dy)`, `distance=`, `verdict=within|exceeded`. The drift is the difference of two real readings, never arithmetic on a remembered coordinate. A miss or an ambiguous needle is a refusal; `--strict` turns drift over `--max-drift` (default 4px) into exit 1.
- `pt-calibrate <profile> --estimate <i,j> --verify <k[,...]> [--file <png>] [--canvas x,y,w,h] [--relocate x,y] [--max-residual px] [--min-spacing px] [--list] [--json]` — answer "what was this canvas zoomed to", which one anchor structurally cannot. Two anchors fix a `uniform-scale+translation` model (the separation ratio is ONE scalar and the same pair fixes the translation); a THIRD anchor the fit never saw is what makes it a measurement, because a rotation or a non-uniform stretch hides comfortably inside a two-point fit. Per-axis ratios `sx`/`sy` are computed and their disagreement (>0.02) is a REFUSAL, never an average — there is no rotation or shear term in this model. Anchors are named by the 1-based index `--list` prints, not by text: an OCR line may contain a comma, and a separator that can also appear inside a value is how a list silently loses an item. Every refusal names itself and carries the number it measured (duplicate label in the profile, baseline under `--min-spacing` (default 20px), no extent on one axis, index out of range or in both sets, anchor absent from the re-read, residual over `--max-residual` (default 3px) — in which case NO conversion is reported). The answer states units (px), basis, both timestamps, the rect read, the occlusion rate and the region it applies to: by default only the whole read rect, saying out loud that the tool cannot tell a canvas from its chrome — pass `--canvas` to scope it. Menus, toolbars and child windows are never covered by the model and nothing is moved by it. `--relocate x,y` converts ONE point the caller names (float plus half-to-even int); a profile is never rewritten in bulk.

## Acting (Mouse)

- `move` · `hover [--dwell ms]` (tooltips need the dwell) · `click` · `rclick` · `dblclick` — absolute screen pixels; `--to <sel>` activates + verifies a window first; `--guard-text <s>` / `--guard-region x,y,w,h=<s>` assert context BEFORE the click.
- `drag <x1> <y1> <x2> <y2> [--steps n] [--hold ms]` — press, interpolate, release.
- Mid-state trio (surfaces that decide on release): `press-down [--max-hold ms]` → `drag-to <x> <y>` → `press-up <x> <y>`. Watchdogs: a held button self-releases at the deadline, and any later invocation releases a button left down by a previous run.
- `wheel [amount] [x y] [--unit raw|notches] [--axis vertical|horizontal] [--to <sel>|--at <sel>] [--focus-first] [--expect-change [x,y,w,h]] [--verify-scroll [--expect-change x,y,w,h]|--expect-visible-text <needle>]` — scroll. Omitted amount remains -120 raw delta. Defaults are raw delta and vertical; `notches` requires an explicit amount and multiplies it by 120. Vertical positive/negative is up/down; horizontal positive/negative is right/left. `--to` verifies the actual point against the selected top-level window; when x/y is omitted it checks the current cursor. `--at` requires explicit x/y; a window centre does not identify the target panel. `--focus-first` stays opt-in and rechecks target, foreground and landing after its real click. Verification is opt-in and requires a selector plus amount/x/y. `--verify-scroll` reads UIA ScrollPattern position; only an explicit in-window region enables the pixel-only fallback. `--expect-visible-text` verifies that a caller-specified UIA name becomes visible in the target window. Receipts separate input insertion from observed effect, report actual wait/sample count and label pixel-only evidence. Boundary avoids injection; no-effect, target-change and unavailable states fail distinctly; no automatic retry.
- `relclick <sel> <dx> <dy>` — click relative to a window's top-left, from the rect re-read after activation; refused when the point misses the target or a window other than the target answers the hit test (`--allow-outside` relaxes both and says so).
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

- `focus <sel>` — restore + front, then re-read the SAME handle: prints the at-select and after-activate readings (`fg=` faces) plus the `fg_ok=` contract token, and exits 1 unless the window really is foreground, not minimized, visible and on-screen.
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

`type` sends literal characters (`"^a"` is two characters); `keys --to "MyApp" "^a"` sends Ctrl+A. Numeric PIDs go in the `--to` selector. `activated=no (was fg)` only means the window was already foreground; it does not prove the edit control has focus. `uia-focus` reports SetFocus without reading the keyboard-focus property back. Read the actual field value after typing when available. Use `keys "^a"` followed by `paste` only when replacing the entire, confirmed field, then compare its full readback.

If the expected pre-action text is readable, guard it with `--guard-text` or `--guard-region`. One `type` call that cannot be read back only describes that call and read path; do not generalize it into a blanket Qt/Electron compatibility claim.

**Hand a file to a window (fixture form only):**
```
paste-file --to "Notepad" dtx-fixture.txt
```
The example file and the target window are ones this run creates and destroys (a generated text file, a local editor). Its receipt is the file name, so `+ verified` on that line means only "the name showed up in that window".

**项目红线 / hard red line:** do not aim `paste` / `paste-file` / `copy-file` at a real chat, mail or any other person-facing conversation window (WeChat / QQ / DingTalk / Slack / Outlook / webmail in a browser — anything with a human on the other side) unless the user, in this same turn, named that recipient and that file and confirmed it. Foreground and occlusion guards check *which window the keys land in*; they never authorize the send. 不得向任何真实聊天会话发送消息或文件；活体验收只用本项目自建自销的夹具；已经开在屏幕上的聊天窗口不是夹具。

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
