# desktop.ps1 - Agent Computer Use: a stateless Windows desktop automation CLI
# version: 1.1.0
#
# Single file, no dependencies beyond .NET Framework / Windows built-ins.
# Designed to be driven by an AI agent (or a human) from a shell: every call is
# one short-lived "powershell -File" process, so there is no daemon to debug.
# See README.md / README.zh-CN.md for the full command reference.
#
# NOTE: this file is intentionally pure ASCII. PowerShell 5.1 reads BOM-less
# UTF-8 as ANSI/GBK, so any non-ASCII literal here would break parsing.
# Non-ASCII text must go through the `paste` command (clipboard + Ctrl+V).
#
# Usage: powershell -ExecutionPolicy Bypass -File desktop.ps1 <cmd> [args...]

param(
  [Parameter(Position = 0)][string]$Cmd = 'help',
  [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest = @()
)

$ErrorActionPreference = 'Stop'

# Emit stdout as UTF-8 (no BOM) so CJK window titles survive being piped to
# other processes when invoked via powershell -File. Wrapped in try/catch
# because hosts without a real console reject the setter.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DT {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr ctx);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  public struct RECT { public int Left, Top, Right, Bottom; }
  public struct POINT { public int X, Y; }
  public static string Text(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
}
"@

# Must run before any coordinate is read, otherwise Windows virtualizes every
# value by the monitor scale factor (any non-100% display scaling) and clicks
# land in the wrong place.
# Preferred mode is Per-Monitor V2 (Windows 10 1703+, user32 context value -4):
# with several monitors at DIFFERENT scale factors, the legacy System-aware
# mode below is still virtualized on secondary monitors, so screenshots and
# clicks there can be offset. Older builds throw EntryPointNotFoundException
# and we fall back to SetProcessDPIAware() (System aware).
# $DpiMode is reported by the `dpi` command for troubleshooting.
$script:DpiMode = 'unaware'
try {
  if ([DT]::SetProcessDpiAwarenessContext([IntPtr](-4))) { $script:DpiMode = 'per-monitor-v2' }
} catch { }
if ($script:DpiMode -eq 'unaware') {
  try {
    if ([DT]::SetProcessDPIAware()) { $script:DpiMode = 'system' }
  } catch { }
}

$MOUSE_LDOWN = 0x0002
$MOUSE_LUP = 0x0004
$MOUSE_RDOWN = 0x0008
$MOUSE_RUP = 0x0010
$MOUSE_WHEEL = 0x0800

$OutDir = Join-Path $PSScriptRoot 'shots'
$ActionLog = Join-Path $OutDir 'actions.log'

function Ensure-OutDir {
  if (-not (Test-Path $OutDir)) { [void](New-Item -ItemType Directory -Force -Path $OutDir) }
}

# Audit trail for act/text commands: one line per executed action, appended
# right before the action runs. Format:
#   <UTC timestamp> UTC | <command> | <raw args> | <target>
# Never logs clipboard contents or the body of pasted files - only file paths.
function Log-Action([string]$argsLine, [string]$target) {
  Ensure-OutDir
  $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
  $line = "$ts UTC | $Cmd | $argsLine | $target"
  [System.IO.File]::AppendAllText($ActionLog, "$line`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Get-WinList {
  $script:WL = New-Object System.Collections.ArrayList
  $cb = [DT+EnumProc] {
    param($h, $l)
    if ([DT]::IsWindowVisible($h)) {
      $t = [DT]::Text($h)
      if ($t) {
        $r = New-Object DT+RECT
        [void][DT]::GetWindowRect($h, [ref]$r)
        $procId = 0
        [void][DT]::GetWindowThreadProcessId($h, [ref]$procId)
        $w = $r.Right - $r.Left
        $hh = $r.Bottom - $r.Top
        if ($w -gt 0 -and $hh -gt 0) {
          [void]$script:WL.Add([pscustomobject]@{
            Handle = $h; Pid = $procId; Left = $r.Left; Top = $r.Top
            Right = $r.Right; Bottom = $r.Bottom; W = $w; H = $hh
            Area = $w * $hh; Title = $t
          })
        }
      }
    }
    return $true
  }
  [void][DT]::EnumWindows($cb, [IntPtr]::Zero)
  return $script:WL
}

# selector: a numeric pid, a case-insensitive title substring, or "t:<substr>"
# / "title:<substr>" to force title matching (needed when the substring itself
# is all digits). Among matches the largest non-minimized window wins (usually
# the app's main window). Minimized windows stay "visible" to EnumWindows but
# sit at (-32000,-32000), so they are only used when nothing else matches.
# A selector that parses as a pid is matched by pid ONLY - no fallback to title
# matching, so a stale pid can never hit an unrelated window whose title
# happens to contain those digits.
# Foreground-first rule for numeric pid selectors: a process can own several
# top level windows (app main window + modal file dialog, both same pid); while
# one of them owns the foreground THAT one is the intended target, not the
# largest. The chosen basis is reported back as Pick = 'fg' or 'largest'.
function Resolve-Window([string]$sel) {
  $all = Get-WinList
  $matches = @()
  $asPid = 0
  $byPid = $false
  if ($sel -match '^(?:t|title):(.*)$') {
    $sub = $Matches[1]
    $matches = @($all | Where-Object { $_.Title -like "*$sub*" })
  } elseif ([int]::TryParse($sel, [ref]$asPid)) {
    $byPid = $true
    $matches = @($all | Where-Object { $_.Pid -eq $asPid })
  } else {
    $matches = @($all | Where-Object { $_.Title -like "*$sel*" })
  }
  if (-not $matches) { return $null }
  if ($byPid) {
    $fgH = [DT]::GetForegroundWindow()
    $fgWin = @($matches | Where-Object { $_.Handle -eq $fgH })
    if ($fgWin) {
      $pick = $fgWin[0]
      $pick | Add-Member -NotePropertyName Pick -NotePropertyValue 'fg' -Force
      return $pick
    }
  }
  $live = @($matches | Where-Object { -not [DT]::IsIconic($_.Handle) })
  if ($live) { $matches = $live }
  $pick = @($matches | Sort-Object -Property Area -Descending)[0]
  $pick | Add-Member -NotePropertyName Pick -NotePropertyValue 'largest' -Force
  return $pick
}

function Save-Rect([int]$x, [int]$y, [int]$w, [int]$h, [string]$path) {
  Ensure-OutDir
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size($w, $h)))
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  $size = (Get-Item $path).Length
  return "saved $path  rect=($x,$y) size=${w}x${h}  bytes=$size"
}

# Polls GetForegroundWindow until the target actually owns the foreground.
# Some windows take a moment to come forward, so: up to 3 tries, 400ms apart.
function Wait-Foreground($win) {
  for ($i = 0; $i -lt 3; $i++) {
    Start-Sleep -Milliseconds 400
    if ([DT]::GetForegroundWindow() -eq $win.Handle) { return $true }
  }
  return $false
}

# Returns $true only if the window REALLY ended up in the foreground.
# SetForegroundWindow can silently fail (foreground lock) and merely flash the
# taskbar, so its return value is never trusted - only GetForegroundWindow is.
# On failure, retries once via minimize + restore.
function Activate-Win($win) {
  if ([DT]::IsIconic($win.Handle)) { [void][DT]::ShowWindow($win.Handle, 9) }
  [void][DT]::BringWindowToTop($win.Handle)
  [void][DT]::SetForegroundWindow($win.Handle)
  if (Wait-Foreground $win) { return $true }
  # fallback: minimize (6) then restore (9) and retry once
  [void][DT]::ShowWindow($win.Handle, 6)
  Start-Sleep -Milliseconds 200
  [void][DT]::ShowWindow($win.Handle, 9)
  [void][DT]::BringWindowToTop($win.Handle)
  [void][DT]::SetForegroundWindow($win.Handle)
  return (Wait-Foreground $win)
}

# Keystrokes go to whatever is focused, so every text-sending command reports the
# target it actually used. Never send text blind: pass <sel> or run `focus` first.
function Get-ForegroundInfo {
  $h = [DT]::GetForegroundWindow()
  $procId = 0
  [void][DT]::GetWindowThreadProcessId($h, [ref]$procId)
  return "pid=$procId title='$([DT]::Text($h))'"
}

# Snapshot of the current clipboard so commands that overwrite it can put the
# old content back afterwards. Supported kinds: text and FileDrop (file list).
# Anything else (images, custom formats) is reported as unsupported and left
# alone; an empty clipboard is reported as empty.
function Save-ClipboardState {
  $st = @{ Kind = 'none' }
  try {
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
      $st = @{ Kind = 'text'; Text = (Get-Clipboard -TextFormatType Text) }
    } elseif ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) {
      $st = @{ Kind = 'files'; Files = @([System.Windows.Forms.Clipboard]::GetFileDropList()) }
    } else {
      $st = @{ Kind = 'other' }
    }
  } catch { $st = @{ Kind = 'other' } }
  return $st
}

# Returns a human readable note for the command echo. Never throws: a failed
# restore must not flip the command exit code.
function Restore-ClipboardState($st) {
  if ($null -eq $st) { return 'skipped clipboard restore (nothing saved)' }
  switch ($st.Kind) {
    'text' {
      try { Set-Clipboard -Value $st.Text; return 'clipboard restored' }
      catch { return 'clipboard restore failed' }
    }
    'files' {
      try {
        $sc = New-Object System.Collections.Specialized.StringCollection
        foreach ($f in $st.Files) { [void]$sc.Add($f) }
        [System.Windows.Forms.Clipboard]::SetFileDropList($sc)
        return "clipboard restored (FileDrop $($st.Files.Count) file(s))"
      } catch { return 'clipboard restore failed' }
    }
    'none' { return 'skipped clipboard restore (empty)' }
    default { return 'skipped clipboard restore (non-text)' }
  }
}

# Puts one file on the clipboard as FileDrop and self-verifies the drop list
# really contains it. Returns $true/$false, never throws.
function Set-ClipboardFileDrop([string]$path) {
  try {
    $sc = New-Object System.Collections.Specialized.StringCollection
    [void]$sc.Add($path)
    [System.Windows.Forms.Clipboard]::SetFileDropList($sc)
    Start-Sleep -Milliseconds 300
    if (-not [System.Windows.Forms.Clipboard]::ContainsFileDropList()) { return $false }
    $lst = [System.Windows.Forms.Clipboard]::GetFileDropList()
    return (@($lst | Where-Object { $_ -eq $path }).Count -gt 0)
  } catch { return $false }
}

# Resolves the target and, unless $force, hard-guards that it really is the
# foreground window before the caller sends any keystrokes. If the guard fails
# it throws (ERROR + exit 1) and nothing is sent. With -Force the old behaviour
# is kept: send anyway and print the reconciliation info for manual checking.
function Resolve-Target([string]$sel, [bool]$force = $false) {
  if (-not $sel) {
    $h = [DT]::GetForegroundWindow()
    $procId = 0
    [void][DT]::GetWindowThreadProcessId($h, [ref]$procId)
    return [pscustomobject]@{ Pid = $procId; Handle = $h; Title = [DT]::Text($h) }
  }
  $w = Resolve-Window $sel
  if (-not $w) { throw "no window matching: $sel" }
  $ok = Activate-Win $w
  if (-not $ok -and -not $force) {
    throw ("foreground guard: intended target pid=$($w.Pid) title='$($w.Title)' did not become foreground (actual foreground: $(Get-ForegroundInfo)); no keys sent. Re-run with --force to send anyway.")
  }
  return $w
}

# Splits an optional leading "--to <sel>" and an optional "--force" flag off
# the argument list so text payloads containing spaces stay unambiguous.
# Note: "--force" is a reserved token for these commands and is stripped
# wherever it appears in the argument list.
function Split-Target([string[]]$words) {
  $sel = ''
  $force = $false
  if (@($words) -contains '--force') {
    $force = $true
    $words = @($words | Where-Object { $_ -ne '--force' })
  }
  if ($words.Count -ge 2 -and $words[0] -eq '--to') {
    $sel = $words[1]
    if ($words.Count -gt 2) { $words = @($words[2..($words.Count - 1)]) } else { $words = @() }
  }
  return @{ Sel = $sel; Words = $words; Force = $force }
}

function Move-Click([int]$x, [int]$y, [string]$button) {
  [void][DT]::SetCursorPos($x, $y)
  Start-Sleep -Milliseconds 150
  if ($button -eq 'right') {
    [DT]::mouse_event($MOUSE_RDOWN, 0, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [DT]::mouse_event($MOUSE_RUP, 0, 0, 0, [IntPtr]::Zero)
  } else {
    [DT]::mouse_event($MOUSE_LDOWN, 0, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [DT]::mouse_event($MOUSE_LUP, 0, 0, 0, [IntPtr]::Zero)
  }
  Start-Sleep -Milliseconds 200
}

function Escape-SendKeys([string]$s) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $s.ToCharArray()) {
    switch ($ch) {
      '+' { [void]$sb.Append('{+}') }
      '^' { [void]$sb.Append('{^}') }
      '%' { [void]$sb.Append('{%}') }
      '~' { [void]$sb.Append('{~}') }
      '(' { [void]$sb.Append('{(}') }
      ')' { [void]$sb.Append('{)}') }
      '[' { [void]$sb.Append('{[}') }
      ']' { [void]$sb.Append('{]}') }
      '{' { [void]$sb.Append('{{}') }
      '}' { [void]$sb.Append('{}}') }
      default { [void]$sb.Append($ch) }
    }
  }
  return $sb.ToString()
}

# UIA roots for the SELECTED window. Primary path: AutomationElement.FromHandle
# on the resolved hwnd, so uia-* acts on exactly the window <sel> picked (a
# process can own several top level windows, e.g. main window + modal dialog,
# and the old pid-based FindFirst grabbed whichever came first). Fallback when
# FromHandle fails: every top level desktop child belonging to the pid, all of
# them included in the search.
function Uia-Roots($win) {
  Add-Type -AssemblyName UIAutomationClient
  Add-Type -AssemblyName UIAutomationTypes
  $roots = New-Object System.Collections.ArrayList
  $via = 'handle'
  $el = $null
  try { $el = [System.Windows.Automation.AutomationElement]::FromHandle($win.Handle) } catch { }
  if ($null -ne $el) {
    [void]$roots.Add($el)
  } else {
    $via = 'pid-enum'
    $cond = New-Object System.Windows.Automation.PropertyCondition(
      [System.Windows.Automation.AutomationElement]::ProcessIdProperty, $win.Pid)
    $tops = [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
      [System.Windows.Automation.TreeScope]::Children, $cond)
    foreach ($t in $tops) { [void]$roots.Add($t) }
  }
  return @{ Roots = $roots; Via = $via }
}

# Breadth-first walk over one or more roots.
function Uia-WalkAll($roots) {
  $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
  $out = New-Object System.Collections.ArrayList
  $queue = New-Object System.Collections.Queue
  foreach ($r in @($roots)) { $queue.Enqueue($r) }
  $n = 0
  while ($queue.Count -gt 0 -and $n -lt 6000) {
    $n++
    $el = $queue.Dequeue()
    [void]$out.Add($el)
    try {
      $child = $walker.GetFirstChild($el)
      while ($null -ne $child) { $queue.Enqueue($child); $child = $walker.GetNextSibling($child) }
    } catch { }
  }
  return $out
}

function Uia-Line($el, [int]$depth) {
  $ct = ''; $nm = ''; $aid = ''; $rect = '-'; $en = $false; $off = $true
  try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { }
  try { $nm = $el.Current.Name } catch { }
  try { $aid = $el.Current.AutomationId } catch { }
  try { $en = $el.Current.IsEnabled } catch { }
  try { $off = $el.Current.IsOffscreen } catch { }
  try {
    $r = $el.Current.BoundingRectangle
    if (-not $r.IsEmpty) { $rect = "$([int]$r.X),$([int]$r.Y),$([int]$r.Width)x$([int]$r.Height)" }
  } catch { }
  return (' ' * ($depth * 2)) + "$ct | name='$nm' | id='$aid' | $rect | enabled=$en offscreen=$off"
}

function Uia-Dump($el, [int]$depth, [int]$maxDepth) {
  if ($depth -gt $maxDepth) { return }
  $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
  $child = $walker.GetFirstChild($el)
  while ($null -ne $child) {
    Uia-Line $child $depth
    Uia-Dump $child ($depth + 1) $maxDepth
    $child = $walker.GetNextSibling($child)
  }
}

function Uia-Find($root, [string]$nameSub, [string]$typeRe) {
  foreach ($el in (Uia-WalkAll $root)) {
    $nm = ''; $ct = ''
    try { $nm = $el.Current.Name } catch { }
    try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { }
    if ($nm -like "*$nameSub*" -and (-not $typeRe -or $ct -match $typeRe)) { return $el }
  }
  return $null
}

# Returns the ValuePattern of $el when it is present AND not read-only,
# otherwise $null. Used by uia-settext to pick a genuinely settable element.
function Uia-SettableValue($el) {
  try {
    $vp = $el.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
    if (-not $vp.Current.IsReadOnly) { return $vp }
  } catch { }
  return $null
}

function Usage {
  @'
desktop.ps1 v1.1.0 - Agent Computer Use (Windows, DPI-aware, absolute screen pixels)

  read
    shot [outPath]                  capture whole virtual screen
    win <sel> [outPath]             capture largest visible window of <sel>
    rect <x> <y> <w> <h> [outPath]  capture a region
    wins                            list visible windows (pid | rect | title)
    info <sel>                      pid / handle / window rect / client rect / title
    rect-of <sel>                   print "x y w h" of <sel> only
    cursor                          print current cursor position
    dpi                             print DPI awareness mode + per-monitor bounds
                                    (physical pixels; use when coords look scaled)
    wait-win <sel> <timeoutSec>     poll (500ms) until a matching window appears
    wait-gone <sel> <timeoutSec>    poll until it disappears (dialog closed etc.)

  act (absolute coords)
    move <x> <y>                    move cursor
    click <x> <y>                   left click
    rclick <x> <y>                  right click
    dblclick <x> <y>                double left click
    wheel <amount> [x y]            scroll (negative = down); optional position:
    wheel <amount> --at <sel>         [x y] moves cursor there first, --at <sel>
                                      scrolls at that window's centre, no args
                                      scrolls wherever the cursor already is
    relclick <sel> <dx> <dy>        click inside window, coords relative to its top-left

  text   (keystrokes go to the focused window. With --to <sel> the target is
          activated and then VERIFIED via GetForegroundWindow before anything is
          sent; if it did not really come to the foreground the command fails
          with ERROR + exit 1 and no keys are sent. Pass --force to skip the
          guard and send anyway, old behaviour with reconciliation output.)
    focus <sel>                     restore + bring to front, prints fg_ok=True/False
    type [--to <sel>] <text...> [--force]
                                    type ASCII text (SendKeys, escapes specials)
    keys [--to <sel>] <spec> [--force]
                                    raw SendKeys spec, e.g. ^s  %{F4}  {ENTER}
    paste [--to <sel>] <file> [--force]
                                    read UTF-8 file, put on clipboard, Ctrl+V (use
                                    for CJK); previous clipboard (text or FileDrop)
                                    is saved and restored afterwards

  clipboard
    copy-file <path>                put a local file on the clipboard as FileDrop,
                                    self-verified; deliberately keeps it there
    paste-file [--to <sel>] <path> [--force]
                                    copy-file + foreground guard + Ctrl+V, then
                                    restore the previous clipboard

  ui automation (works only if the app exposes its a11y tree; roots are resolved
                 from the SELECTED window handle, not just the first pid window)
    uia-tree <sel> [maxDepth]       dump control tree (header shows scanned hwnd)
    uia-find <sel> <nameSub> [typeRe]
    uia-click <sel> <nameSub>       InvokePattern, falls back to clicking its centre
    uia-focus <sel> <nameSub>       SetFocus
    uia-settext <sel> <nameSub> <file>
                                    ValuePattern.SetValue from a UTF-8 file,
                                    readback-verified (no keyboard, no clipboard)

  <sel> = numeric pid or case-insensitive title substring.
          A numeric <sel> is matched by pid only (no title fallback) and prefers
          the window of that pid currently in the foreground (pick=fg), else the
          largest one (pick=largest);
          use t:<digits> or title:<digits> to match a title substring
          that consists of digits.
  every executed act/text/clipboard/uia-settext command appends one audit line
  to shots\actions.log (paths only, never file or clipboard contents)
  exit code 0 = ok, 1 = error
'@
}

try {
  switch ($Cmd) {

    'help' { Usage }

    'shot' {
      $o = [System.Windows.Forms.SystemInformation]::VirtualScreen
      $path = if ($Rest.Count -ge 1 -and $Rest[0]) { $Rest[0] } else { Join-Path $OutDir 'shot.png' }
      Save-Rect $o.X $o.Y $o.Width $o.Height $path
    }

    'win' {
      if ($Rest.Count -lt 1) { throw 'usage: win <sel> [outPath]' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      $path = if ($Rest.Count -ge 2 -and $Rest[1]) { $Rest[1] } else { Join-Path $OutDir 'win.png' }
      Save-Rect $w.Left $w.Top $w.W $w.H $path
    }

    'rect' {
      if ($Rest.Count -lt 4) { throw 'usage: rect <x> <y> <w> <h> [outPath]' }
      $path = if ($Rest.Count -ge 5 -and $Rest[4]) { $Rest[4] } else { Join-Path $OutDir 'rect.png' }
      Save-Rect ([int]$Rest[0]) ([int]$Rest[1]) ([int]$Rest[2]) ([int]$Rest[3]) $path
    }

    'wins' {
      Get-WinList | Sort-Object -Property Area -Descending |
        ForEach-Object { "pid=$($_.Pid)  rect=($($_.Left),$($_.Top))-($($_.Right),$($_.Bottom))  size=$($_.W)x$($_.H)  title=$($_.Title)" }
    }

    'info' {
      if ($Rest.Count -lt 1) { throw 'usage: info <sel>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      $cr = New-Object DT+RECT
      [void][DT]::GetClientRect($w.Handle, [ref]$cr)
      $pt = New-Object DT+POINT
      $pt.X = 0; $pt.Y = 0
      [void][DT]::ClientToScreen($w.Handle, [ref]$pt)
      $fg = [DT]::GetForegroundWindow()
      "pid=$($w.Pid)  handle=$($w.Handle)  title=$($w.Title)  pick=$($w.Pick)"
      "window rect = ($($w.Left),$($w.Top))-($($w.Right),$($w.Bottom))  size=$($w.W) x $($w.H)"
      "client rect = ($($pt.X),$($pt.Y))  size=$($cr.Right) x $($cr.Bottom)"
      "iconic=$([DT]::IsIconic($w.Handle))  foreground=$($fg -eq $w.Handle)"
    }

    'rect-of' {
      if ($Rest.Count -lt 1) { throw 'usage: rect-of <sel>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      "$($w.Left) $($w.Top) $($w.W) $($w.H)"
    }

    'cursor' {
      $p = New-Object DT+POINT
      [void][DT]::GetCursorPos([ref]$p)
      "cursor=($($p.X),$($p.Y))"
    }

    'dpi' {
      # Reports the awareness mode actually obtained at startup plus every
      # monitor's bounds in real physical pixels, so a mismatch between
      # screenshot size and click coordinates can be diagnosed in one call.
      $o = [System.Windows.Forms.SystemInformation]::VirtualScreen
      "dpi-mode=$script:DpiMode  virtual-screen=($($o.X),$($o.Y)) $($o.Width)x$($o.Height)"
      foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
        $b = $s.Bounds
        "$($s.DeviceName) primary=$($s.Primary) bounds=($($b.X),$($b.Y)) $($b.Width)x$($b.Height)"
      }
    }

    'wait-win' {
      # wait-win <sel> <timeoutSec> - poll every 500ms until <sel> resolves.
      if ($Rest.Count -lt 2) { throw 'usage: wait-win <sel> <timeoutSec>' }
      $timeout = [int]$Rest[1]
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      $w = $null
      while ($sw.Elapsed.TotalSeconds -lt $timeout) {
        $w = Resolve-Window $Rest[0]
        if ($w) { break }
        Start-Sleep -Milliseconds 500
      }
      if (-not $w) { throw "timeout after ${timeout}s waiting for window: $($Rest[0])" }
      "appeared after $([math]::Round($sw.Elapsed.TotalSeconds,1))s: pid=$($w.Pid)  rect=($($w.Left),$($w.Top))-($($w.Right),$($w.Bottom))  size=$($w.W)x$($w.H)  title=$($w.Title)  pick=$($w.Pick)"
    }

    'wait-gone' {
      # wait-gone <sel> <timeoutSec> - poll every 500ms until <sel> no longer
      # resolves (dialog closed, operation took effect).
      if ($Rest.Count -lt 2) { throw 'usage: wait-gone <sel> <timeoutSec>' }
      $timeout = [int]$Rest[1]
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      $w = Resolve-Window $Rest[0]
      while ($null -ne $w -and $sw.Elapsed.TotalSeconds -lt $timeout) {
        Start-Sleep -Milliseconds 500
        $w = Resolve-Window $Rest[0]
      }
      if ($null -ne $w) { throw "timeout after ${timeout}s, window still present: $($Rest[0])" }
      "gone after $([math]::Round($sw.Elapsed.TotalSeconds,1))s: $($Rest[0])"
    }

    'move' {
      if ($Rest.Count -lt 2) { throw 'usage: move <x> <y>' }
      Log-Action ($Rest -join ' ') "coords=$($Rest[0]),$($Rest[1])"
      [void][DT]::SetCursorPos([int]$Rest[0], [int]$Rest[1])
      Start-Sleep -Milliseconds 120
      "moved to $($Rest[0]),$($Rest[1])"
    }

    'click' {
      if ($Rest.Count -lt 2) { throw 'usage: click <x> <y>' }
      Log-Action ($Rest -join ' ') "coords=$($Rest[0]),$($Rest[1])"
      Move-Click ([int]$Rest[0]) ([int]$Rest[1]) 'left'
      "clicked $($Rest[0]),$($Rest[1])"
    }

    'rclick' {
      if ($Rest.Count -lt 2) { throw 'usage: rclick <x> <y>' }
      Log-Action ($Rest -join ' ') "coords=$($Rest[0]),$($Rest[1])"
      Move-Click ([int]$Rest[0]) ([int]$Rest[1]) 'right'
      "right-clicked $($Rest[0]),$($Rest[1])"
    }

    'dblclick' {
      if ($Rest.Count -lt 2) { throw 'usage: dblclick <x> <y>' }
      Log-Action ($Rest -join ' ') "coords=$($Rest[0]),$($Rest[1])"
      [void][DT]::SetCursorPos([int]$Rest[0], [int]$Rest[1])
      Start-Sleep -Milliseconds 150
      1..2 | ForEach-Object {
        [DT]::mouse_event($MOUSE_LDOWN, 0, 0, 0, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 40
        [DT]::mouse_event($MOUSE_LUP, 0, 0, 0, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 60
      }
      "double-clicked $($Rest[0]),$($Rest[1])"
    }

    'wheel' {
      # wheel <amount> [x y] | wheel <amount> --at <sel>
      # No position: scroll wherever the cursor currently is (legacy behaviour).
      $amount = if ($Rest.Count -ge 1 -and $Rest[0]) { [int]$Rest[0] } else { -120 }
      $posInfo = 'at current cursor position'
      if ($Rest.Count -ge 3 -and $Rest[1] -eq '--at') {
        $w = Resolve-Window $Rest[2]
        if (-not $w) { throw "no window matching: $($Rest[2])" }
        $wx = [int]($w.Left + $w.W / 2)
        $wy = [int]($w.Top + $w.H / 2)
        Log-Action ($Rest -join ' ') "pid=$($w.Pid) title='$($w.Title)' centre=$wx,$wy"
        [void][DT]::SetCursorPos($wx, $wy)
        Start-Sleep -Milliseconds 150
        $posInfo = "at window centre ($wx,$wy) pid=$($w.Pid) title='$($w.Title)'"
      } elseif ($Rest.Count -ge 3) {
        $wx = [int]$Rest[1]
        $wy = [int]$Rest[2]
        Log-Action ($Rest -join ' ') "coords=$wx,$wy"
        [void][DT]::SetCursorPos($wx, $wy)
        Start-Sleep -Milliseconds 150
        $posInfo = "at ($wx,$wy)"
      } else {
        Log-Action ($Rest -join ' ') 'cursor-current'
      }
      # mouse_event takes a DWORD; negative amounts must go through as their
      # two's-complement bit pattern (a plain [uint32] cast of -120 throws).
      $dwData = [uint32](([int64]$amount) -band 0xFFFFFFFFL)
      [DT]::mouse_event($MOUSE_WHEEL, 0, 0, $dwData, [IntPtr]::Zero)
      Start-Sleep -Milliseconds 300
      "wheel $amount  $posInfo"
    }

    'relclick' {
      if ($Rest.Count -lt 3) { throw 'usage: relclick <sel> <dx> <dy>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      $x = $w.Left + [int]$Rest[1]
      $y = $w.Top + [int]$Rest[2]
      Log-Action ($Rest -join ' ') "pid=$($w.Pid) title='$($w.Title)' screen=$x,$y"
      Move-Click $x $y 'left'
      "clicked window-relative ($($Rest[1]),$($Rest[2])) -> screen ($x,$y)"
    }

    'focus' {
      if ($Rest.Count -lt 1) { throw 'usage: focus <sel>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      Log-Action ($Rest -join ' ') "pid=$($w.Pid) title='$($w.Title)'"
      $ok = Activate-Win $w
      "focused pid=$($w.Pid) title=$($w.Title) fg_ok=$ok pick=$($w.Pick)"
    }

    'type' {
      # type [--to <sel>] <text...> [--force]   (ASCII only; use `paste` for CJK)
      $p = Split-Target $Rest
      if ($p.Words.Count -lt 1) { throw 'usage: type [--to <sel>] <text...> [--force]' }
      $text = ($p.Words -join ' ')
      $target = Resolve-Target $p.Sel $p.Force
      Log-Action ($Rest -join ' ') "pid=$($target.Pid) title='$($target.Title)'"
      [System.Windows.Forms.SendKeys]::SendWait((Escape-SendKeys $text))
      Start-Sleep -Milliseconds 300
      "typed $($text.Length) chars, target pid=$($target.Pid) title='$($target.Title)'  (foreground after send: $(Get-ForegroundInfo))"
    }

    'keys' {
      # keys [--to <sel>] <spec> [--force]
      $p = Split-Target $Rest
      if ($p.Words.Count -lt 1) { throw 'usage: keys [--to <sel>] <spec> [--force]' }
      $spec = $p.Words[0]
      $target = Resolve-Target $p.Sel $p.Force
      Log-Action ($Rest -join ' ') "pid=$($target.Pid) title='$($target.Title)'"
      [System.Windows.Forms.SendKeys]::SendWait($spec)
      Start-Sleep -Milliseconds 300
      "sent keys '$spec', target pid=$($target.Pid) title='$($target.Title)'  (foreground after send: $(Get-ForegroundInfo))"
    }

    'paste' {
      # paste [--to <sel>] <file> [--force] - reads UTF-8, clipboard + Ctrl+V (use for CJK)
      $p = Split-Target $Rest
      if ($p.Words.Count -lt 1) { throw 'usage: paste [--to <sel>] <file> [--force]' }
      $file = $p.Words[0]
      if (-not (Test-Path $file)) { throw "file not found: $file" }
      # Snapshot the previous clipboard (text or FileDrop) for restore afterwards.
      $clip = Save-ClipboardState
      $target = Resolve-Target $p.Sel $p.Force
      Log-Action ($Rest -join ' ') "pid=$($target.Pid) title='$($target.Title)' file=$file"
      $text = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
      Set-Clipboard -Value $text
      Start-Sleep -Milliseconds 400
      [System.Windows.Forms.SendKeys]::SendWait('^v')
      Start-Sleep -Milliseconds 500
      $restoreNote = Restore-ClipboardState $clip
      "pasted $($text.Length) chars from $file, target pid=$($target.Pid) title='$($target.Title)'  (foreground after send: $(Get-ForegroundInfo))  [$restoreNote]"
    }

    'copy-file' {
      # copy-file <path> - put a local file on the clipboard as FileDrop and
      # verify the drop list really contains it. Deliberately does NOT restore
      # the previous clipboard: leaving the file there is the point of this
      # command (paste / paste-file do restore).
      if ($Rest.Count -lt 1) { throw 'usage: copy-file <path>' }
      if (-not (Test-Path -LiteralPath $Rest[0] -PathType Leaf)) { throw "file not found: $($Rest[0])" }
      $fi = Get-Item -LiteralPath $Rest[0]
      Log-Action ($Rest -join ' ') "file=$($fi.FullName) bytes=$($fi.Length)"
      $ok = Set-ClipboardFileDrop $fi.FullName
      if (-not $ok) { throw "clipboard verification failed for: $($fi.FullName)" }
      "copied $($fi.Name)  bytes=$($fi.Length)  clipboard verified: $($fi.FullName)"
    }

    'paste-file' {
      # paste-file [--to <sel>] <path> [--force]
      # = copy-file + foreground guard + Ctrl+V, previous clipboard restored.
      $p = Split-Target $Rest
      if ($p.Words.Count -lt 1) { throw 'usage: paste-file [--to <sel>] <path> [--force]' }
      if (-not (Test-Path -LiteralPath $p.Words[0] -PathType Leaf)) { throw "file not found: $($p.Words[0])" }
      $fi = Get-Item -LiteralPath $p.Words[0]
      $clip = Save-ClipboardState
      $target = Resolve-Target $p.Sel $p.Force
      Log-Action ($Rest -join ' ') "pid=$($target.Pid) title='$($target.Title)' file=$($fi.FullName)"
      $ok = Set-ClipboardFileDrop $fi.FullName
      if (-not $ok) { throw "clipboard verification failed for: $($fi.FullName)" }
      [System.Windows.Forms.SendKeys]::SendWait('^v')
      Start-Sleep -Milliseconds 500
      $restoreNote = Restore-ClipboardState $clip
      "pasted file $($fi.Name) bytes=$($fi.Length), target pid=$($target.Pid) title='$($target.Title)'  (foreground after send: $(Get-ForegroundInfo))  [$restoreNote]"
    }

    'uia-tree' {
      if ($Rest.Count -lt 1) { throw 'usage: uia-tree <sel> [maxDepth]' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      $depth = if ($Rest.Count -ge 2 -and $Rest[1]) { [int]$Rest[1] } else { 6 }
      $rr = Uia-Roots $w
      if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
      "scan: handle=$($w.Handle) title='$($w.Title)' pick=$($w.Pick) roots=$($rr.Roots.Count) via=$($rr.Via)"
      foreach ($r in $rr.Roots) {
        $rn = ''
        try { $rn = $r.Current.Name } catch { }
        "root: $rn"
        Uia-Dump $r 0 $depth
      }
    }

    'uia-find' {
      if ($Rest.Count -lt 2) { throw 'usage: uia-find <sel> <nameSub> [typeRe]' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      $rr = Uia-Roots $w
      if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
      $typeRe = if ($Rest.Count -ge 3) { $Rest[2] } else { '' }
      $all = Uia-WalkAll $rr.Roots
      $c = 0
      foreach ($el in $all) {
        $nm = ''; $ct = ''
        try { $nm = $el.Current.Name } catch { }
        try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { }
        if ($nm -like "*$($Rest[1])*" -and (-not $typeRe -or $ct -match $typeRe)) { Uia-Line $el 0; $c++ }
      }
      "scanned $($all.Count) elements in $($rr.Roots.Count) root(s) via=$($rr.Via), hits=$c"
    }

    'uia-click' {
      if ($Rest.Count -lt 2) { throw 'usage: uia-click <sel> <nameSub>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      $rr = Uia-Roots $w
      if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
      $el = Uia-Find $rr.Roots $Rest[1] 'Button|MenuItem|ListItem|TabItem|Hyperlink|Text|Edit|ComboBox|CheckBox|RadioButton'
      if (-not $el) { throw "no clickable element matching: $($Rest[1])" }
      $nm = ''
      try { $nm = $el.Current.Name } catch { }
      try {
        $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
        "InvokePattern ok: $nm"
      } catch {
        $r = $el.Current.BoundingRectangle
        $x = [int]($r.X + $r.Width / 2)
        $y = [int]($r.Y + $r.Height / 2)
        Move-Click $x $y 'left'
        "no InvokePattern, clicked centre ($x,$y) of: $nm"
      }
    }

    'uia-focus' {
      if ($Rest.Count -lt 2) { throw 'usage: uia-focus <sel> <nameSub>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      $rr = Uia-Roots $w
      if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
      $el = Uia-Find $rr.Roots $Rest[1] ''
      if (-not $el) { throw "no element matching: $($Rest[1])" }
      $el.SetFocus()
      "focused element: $($Rest[1])"
    }

    'uia-settext' {
      # uia-settext <sel> <nameSub> <file> - ValuePattern.SetValue with the UTF-8
      # content of <file>; no keyboard, no clipboard. Readback-verified.
      if ($Rest.Count -lt 3) { throw 'usage: uia-settext <sel> <nameSub> <file>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      if (-not (Test-Path -LiteralPath $Rest[2] -PathType Leaf)) { throw "file not found: $($Rest[2])" }
      $text = [System.IO.File]::ReadAllText($Rest[2], [System.Text.Encoding]::UTF8)
      $rr = Uia-Roots $w
      if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
      # Element pick: pass 1 = name match with a settable ValuePattern (edit
      # boxes often carry their current value as Name, so pass 2 also looks
      # for a settable descendant inside any name-matched container, e.g. the
      # "filename:" label/host pane of a save dialog).
      $all = Uia-WalkAll $rr.Roots
      $el = $null
      $named = $null   # first element whose Name matches, even if not settable
      foreach ($cand in $all) {
        $cn = ''
        try { $cn = $cand.Current.Name } catch { }
        if ($cn -like "*$($Rest[1])*") {
          if ($null -eq $named) { $named = $cand }
          if ($null -ne (Uia-SettableValue $cand)) { $el = $cand; break }
        }
      }
      if (-not $el) {
        foreach ($cand in $all) {
          $cn = ''
          try { $cn = $cand.Current.Name } catch { }
          if ($cn -like "*$($Rest[1])*") {
            foreach ($d in (Uia-WalkAll @($cand))) {
              if ($null -ne (Uia-SettableValue $d)) { $el = $d; break }
            }
            if ($el) { break }
          }
        }
      }
      if (-not $el) {
        if ($null -ne $named) {
          $nn = ''
          try { $nn = $named.Current.Name } catch { }
          throw "element '$nn' matched but exposes no settable ValuePattern; fall back to: click the field then paste <file>"
        }
        throw "no element matching: $($Rest[1])"
      }
      $nm = ''
      try { $nm = $el.Current.Name } catch { }
      Log-Action ($Rest -join ' ') "pid=$($w.Pid) title='$($w.Title)' element='$nm' file=$($Rest[2])"
      $via = ''
      $vp = Uia-SettableValue $el
      if ($null -ne $vp) {
        $vp.SetValue($text)
        $via = 'ValuePattern'
      } else {
        # TextPattern is checked for diagnostics only - it exposes no setter.
        $tp = $null
        try { $tp = $el.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern) } catch { }
        if ($null -ne $tp) {
          throw "element '$nm' exposes TextPattern but no settable ValuePattern; fall back to: click the field then paste <file>"
        }
        throw "element '$nm' exposes no settable text pattern; fall back to: click the field then paste <file>"
      }
      $back = $null
      try { $back = $el.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value } catch { }
      if ($null -eq $back) { try { $back = $el.Current.Name } catch { } }
      if ($back -ne $text) { throw "uia-settext readback mismatch on element '$nm' (wrote $($text.Length) chars)" }
      "set text via $via on element '$nm': wrote $($text.Length) chars, readback match=True"
    }

    default { throw "unknown command: $Cmd (run 'desktop.ps1 help')" }
  }
  exit 0
} catch {
  Write-Output "ERROR: $($_.Exception.Message)"
  exit 1
}