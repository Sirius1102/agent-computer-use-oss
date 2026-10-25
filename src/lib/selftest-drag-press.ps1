# lib/selftest-drag-press.ps1 - one family of the selftest section, lifted out of lib/selftest.ps1
# by A-14o (A-beta). Bodies are byte-identical to what the section carried; the only channel to the
# orchestrator is the context object, and this family hands nothing back (measured: every name it
# computes is consumed inside these gates).
#
# The drag/press family: the drag mid-state gate (a drag that lands on its own origin must not read
# as a move), the pairing id that is HANDED OVER rather than re-read, and the landing guard that
# judges both endpoints before the press.
function Invoke-SelftestFamily-DragPress($Ctx) {
  # context handover (the one thing in this file above the lifted text that is not lifted text)
  $codeLines = $Ctx['codeLines']
  $gaCaseIdx = $Ctx['gaCaseIdx']
  $gaCases = $Ctx['gaCases']
  $j5ProdEnd = $Ctx['j5ProdEnd']
  $j5ProdStart = $Ctx['j5ProdStart']

  # ---------- v2.0.1 (P-3): the drag mid-state gate ----------
  # The whole risk of this feature is machine-wide state leaking out of a process, so
  # the DECISION is a pure truth table (measured button state in, action out) and is
  # pinned in BOTH directions: every cell has a "held" case and an "idle" case, because
  # a rule that only ever fires one way is not a rule.
  $p3WatchStray = Get-PressGate 'watchdog' 'wins' $true
  ST-Check 'unit: press gate - the entry watchdog releases a stray press for an ordinary command and names what it did' (
    $p3WatchStray.Release -and ($p3WatchStray.Warn -ceq 'released a button left down by a previous run'))
  $p3WatchUp = Get-PressGate 'watchdog' 'press-up' $true
  $p3WatchDrag = Get-PressGate 'watchdog' 'drag-to' $true
  ST-Check 'unit: press gate - press-up and drag-to are exempt from the entry watchdog (releasing first would destroy the state they act on and report about)' (
    (-not $p3WatchUp.Release) -and (-not $p3WatchDrag.Release) -and (-not $p3WatchUp.Refuse) -and (-not $p3WatchDrag.Refuse))
  $p3WatchIdle = Get-PressGate 'watchdog' 'wins' $false
  ST-Check 'unit: press gate - nothing pressed means the watchdog stays silent (no WARNING line on every ordinary call)' (
    (-not $p3WatchIdle.Release) -and ($p3WatchIdle.Warn -ceq ''))
  $p3DownHeld = Get-PressGate 'press-down' 'press-down' $true
  ST-Check 'unit: press gate - a second press-down while held is refused so DOWN/UP stay a 1:1 pair' (
    $p3DownHeld.Refuse -and $p3DownHeld.Reason.Contains('1:1 pair'))
  $p3DownIdle = Get-PressGate 'press-down' 'press-down' $false
  ST-Check 'unit: press gate - press-down on an idle button proceeds (and does not "release")' (
    (-not $p3DownIdle.Refuse) -and (-not $p3DownIdle.Release))
  $p3UpHeld = Get-PressGate 'press-up' 'press-up' $true
  $p3UpIdle = Get-PressGate 'press-up' 'press-up' $false
  ST-Check 'unit: press gate - press-up releases while held and REFUSES when nothing is down (a release that did not happen must never be reported as success)' (
    $p3UpHeld.Release -and $p3UpIdle.Refuse -and $p3UpIdle.Reason.Contains('not down'))
  $p3DragIdle = Get-PressGate 'drag-to' 'drag-to' $false
  $p3DragHeld = Get-PressGate 'drag-to' 'drag-to' $true
  ST-Check 'unit: press gate - drag-to refuses without a press and travels with one (offline half of "not a silent success")' (
    $p3DragIdle.Refuse -and $p3DragIdle.Reason.Contains('press-down') -and (-not $p3DragHeld.Refuse))
  $p3Bogus = Get-PressGate 'press-sideways' 'press-sideways' $false
  ST-Check 'unit: press gate - an unknown op refuses instead of returning a do-nothing verdict' ($p3Bogus.Refuse)

  # Wiring: one gate call per press op (no hand-inlined state tests in the handlers),
  # the entry watchdog called exactly once (process entry), the DOWN echo from one
  # producer, the trio in $known and OUT of $replayable (replay must never resurrect a
  # press state), and every --max-hold bound living in the flag table, not the handler.
  $p3Gate = 0; $p3Watch = 0; $p3Echo = 0; $p3Timer = 0
  $p3KnownLine = ''; $p3ReplLine = ''
  for ($p3i = 0; $p3i -lt $codeLines.Count; $p3i++) {
    if ($p3i -ge $j5ProdStart -and $p3i -lt $j5ProdEnd) { continue }
    if ($codeLines[$p3i] -match '^\s*#') { continue }
    if ($codeLines[$p3i].Contains('= Get-PressGate ')) { $p3Gate++ }
    if ($codeLines[$p3i].Contains('$pressWarn = Invoke-PressWatchdog ')) { $p3Watch++ }
    if ($codeLines[$p3i].Contains('"button is DOWN at ')) { $p3Echo++ }
    if ($codeLines[$p3i].Contains('= Wait-PressRelease ')) { $p3Timer++ }
    if ($codeLines[$p3i].Contains("`$known = @('click'")) { $p3KnownLine = $codeLines[$p3i] }
    if ($codeLines[$p3i].Contains("`$replayable = @('move'")) { $p3ReplLine = $codeLines[$p3i] }
  }
  ST-Check 'lint: the press trio routes every decision through one gate, one entry watchdog and one DOWN echo (no second copy of the mid-state rule)' (
    ($p3Gate -eq 4) -and ($p3Watch -eq 1) -and ($p3Echo -eq 1) -and ($p3Timer -eq 1))
  ST-Check 'lint: press-down/drag-to/press-up are script steps but never replayable commands' (
    ($p3KnownLine.Contains("'press-down'")) -and ($p3KnownLine.Contains("'drag-to'")) -and ($p3KnownLine.Contains("'press-up'")) -and
    (-not $p3ReplLine.Contains('press-down')) -and (-not $p3ReplLine.Contains('drag-to')) -and (-not $p3ReplLine.Contains('press-up')))
  # The measurement itself is a gate: [Windows.Forms.MouseButtons]::Buttons is an ENUM
  # type and the member does not exist, so the naive form returns NOTHING - every press
  # then reads "not down" and the trio degrades into permanent refusals plus a watchdog
  # that never fires (measured 2026-10-01 with the button physically held down).
  $p3Reader = 0; $p3ReaderBad = 0
  for ($p3j = 0; $p3j -lt $codeLines.Count; $p3j++) {
    if ($p3j -ge $j5ProdStart -and $p3j -lt $j5ProdEnd) { continue }
    if ($codeLines[$p3j] -match '^\s*#') { continue }
    if ($codeLines[$p3j].Contains('Control]::MouseButtons')) { $p3Reader++ }
    if ($codeLines[$p3j].Contains('MouseButtons]::Buttons')) { $p3ReaderBad++ }
  }
  ST-Check 'lint: the press-state reader is the one form that actually measures (no silently-empty MouseButtons::Buttons)' (
    ($p3Reader -eq 1) -and ($p3ReaderBad -eq 0))
  # Watchdog 1 must be armed NATIVELY. A PowerShell scriptblock marshalled as a
  # System.Threading.Timer callback kills the process (first live round, 2026-10-01:
  # press-down died with exit code 2 having printed only its DOWN echo, so the button
  # stayed down and the next check in the same round - drag-to's refusal - saw a press
  # that nobody had asked for). A dead process is the one thing a deadline watchdog
  # cannot be, so the deadline lives in DT.ArmLeftUpHold and PS only reads the flag.
  $p3Native = 0; $p3PsTimer = 0
  for ($p3k = 0; $p3k -lt $codeLines.Count; $p3k++) {
    if ($p3k -ge $j5ProdStart -and $p3k -lt $j5ProdEnd) { continue }
    if ($codeLines[$p3k] -match '^\s*#') { continue }
    if ($codeLines[$p3k].Contains('::ArmLeftUpHold(')) { $p3Native++ }
    if ($codeLines[$p3k].Contains('New-Object System.Threading.Timer')) { $p3PsTimer++ }
  }
  ST-Check 'lint: the hold deadline is armed natively, never by a marshalled PowerShell timer callback (that kills the process and leaves the button down)' (
    ($p3Native -eq 1) -and ($p3PsTimer -eq 0))
  Write-Output ("      press hold arming: native=$p3Native ps-timer=$p3PsTimer reader=$p3Reader/$p3ReaderBad")
  Write-Output ("      press trio: gate=$p3Gate watchdog=$p3Watch echo=$p3Echo hold-wait=$p3Timer")
  # ---------- v2.2.0 (P3-6 hardening): the pairing id is HANDED OVER, never rebuilt -------
  # The whole point of the change is that a release noticed by a process that did not press
  # cannot invent the id. These four cases are the shape of that rule; the live pairing
  # contract cannot see the difference (it passes either way today), so the teeth live here.
  $p6A = Format-PressReleaseLine 'p777-1' 'p888-1' 'max-hold'
  ST-Check 'unit: press release line - an id the CALLER hands over beats whatever this process remembers, and says it came from the caller (the party that notices a release is usually not the party that pressed)' (
    $p6A.Contains('id=p777-1 ') -and $p6A.Contains('cause=max-hold') -and $p6A.Contains('id-source=caller'))
  $p6B = Format-PressReleaseLine '' 'p888-1' 'max-hold'
  ST-Check 'unit: press release line - with nothing handed over it falls back to this process id and LABELS that honestly (id-source=process)' (
    $p6B.Contains('id=p888-1 ') -and $p6B.Contains('id-source=process'))
  $p6C = Format-PressReleaseLine '' '' 'external'
  ST-Check 'unit: press release line - an unattributable release STILL writes a line and calls itself out, instead of the old silent skip that left a DOWN dangling with no trace at all' (
    $p6C.Contains('id-source=none') -and $p6C.Contains('ON PURPOSE') -and $p6C.Contains('cause=external'))
  $p6D = Format-PressReleaseLine 'p1-1' '' 'press-up'
  ST-Check 'unit: press release line - the cause is carried verbatim through the single producer (a hardcoded cause would make every release look like a deadline)' (
    $p6D.Contains('cause=press-up') -and (-not $p6D.Contains('cause=max-hold')))
  $p6Def = 0; $p6InProducer = $false; $p6Outside = 0; $p6Sites = 0; $p6Explicit = 0
  for ($p6j = 0; $p6j -lt $codeLines.Count; $p6j++) {
    if ($p6j -ge $j5ProdStart -and $p6j -lt $j5ProdEnd) { continue }
    if ($codeLines[$p6j].StartsWith('function Format-PressReleaseLine')) { $p6Def++; $p6InProducer = $true; continue }
    if ($p6InProducer -and ($codeLines[$p6j] -match '^(function |ST-Check )')) { $p6InProducer = $false }
    if ($codeLines[$p6j] -match '^\s*#') { continue }
    if ((-not $p6InProducer) -and $codeLines[$p6j].Contains(('button=' + 'UP'))) { $p6Outside++ }
    if ($codeLines[$p6j].Contains('Close-PressHold @(') -or $codeLines[$p6j].Contains('Close-PressHold $prLog')) { $p6Sites++ }
    if ($codeLines[$p6j].Contains(('Close-PressHold $prLog ' + '$prId'))) { $p6Explicit++ }
  }
  ST-Check 'lint: the UP pairing line is spelled by exactly one producer function and nowhere else in the tool (three copies used to write it, and only one could be right about the id)' (
    ($p6Def -eq 1) -and ($p6Outside -eq 0))
  if ($p6Outside -ne 0) { Write-Output "      button=UP text sites outside the producer: $p6Outside (expected 0)" }
  ST-Check 'lint: all four Close-PressHold call sites pass an id argument, and exactly one of them passes the id it issued (the three cross-process ones pass empty on purpose and get labelled, never skipped)' (
    ($p6Sites -eq 4) -and ($p6Explicit -eq 1))

  # ---------- v3.1.0 (P-01): drag's landing guard - both endpoints, judged before the press ----------
  # drag was the only command whose comment promised the family guard wiring while its body
  # ran none of the landing check (the F-00-A lint above is the promise-side tooth; this
  # block pins the fix side). drag is the only two-point command, so the check must run
  # TWICE - start then end - and both verdicts must exist BEFORE mouse-down: refusing after
  # the press would drop the drag somewhere along a path nobody approved. The mouse layer is
  # static ([DT]::) and cannot be mocked, so every offline path here aborts before
  # SetCursorPos by construction: the reject paths throw inside the check itself, and the
  # accept-side mock throws a sentinel at Get-ExpectChangeBaseline, the step that would
  # otherwise lead into the press - which is also what keeps every MUTANT of this block safe
  # to run on a real desktop.
  $dgIdx = & $gaCaseIdx 'drag'
  # v4.4.0 (A-15 pen 2): drag's body is a handler now. What is judged is still FILE order, so every range
  #    of the command is walked in order and the first mouse-down line seen anywhere is the boundary.
  $dgHits = @(); $dgLdown = -1
  foreach ($dgRg in @(Get-CommandCodeRanges $codeLines 'drag')) {
    for ($dgi = [int]$dgRg[0]; $dgi -lt [int]$dgRg[1]; $dgi++) {
      if ($codeLines[$dgi] -match '^\s*#') { continue }
      if (($codeLines[$dgi].Contains('MOUSE_LDOWN')) -and ($dgLdown -lt 0)) { $dgLdown = $dgi }
      if ($codeLines[$dgi].Contains('Invoke-HitWindowCheck')) { $dgHits += $dgi }
    }
  }
  ST-Check 'lint (P-01): drag passes BOTH endpoints through the landing check before the mouse-down line (exactly 2 calls, start coords then end coords; a drag variant that skips one is this family again)' (
    ((@($dgHits).Count -eq 2) -and ($dgLdown -gt $dgHits[1]) -and
    ($codeLines[$dgHits[0]].Contains('$x1 $y1')) -and ($codeLines[$dgHits[1]].Contains('$x2 $y2'))))
  $dgHwcReal = ${function:Invoke-HitWindowCheck}
  $dgRtReal = ${function:Resolve-Target}
  $dgLaReal = ${function:Log-Action}
  $dgEcbReal = ${function:Get-ExpectChangeBaseline}
  $script:dgGuardCalls = New-Object System.Collections.ArrayList
  $script:dgLogCalls = New-Object System.Collections.ArrayList
  $dgFakeTarget = [pscustomobject]@{ Pid = 41999; Title = 'dg-fake-target'; Handle = [IntPtr]::Zero; Left = 0; Top = 0; W = 100; H = 100 }
  try {
    ${function:Resolve-Target} = { param($sel, $force, $always, $eh) return $dgFakeTarget }
    ${function:Log-Action} = { param($la, $detail, $cn) [void]$script:dgLogCalls.Add("$detail") }
    ${function:Get-ExpectChangeBaseline} = { param($pp, $tt) throw 'dg-sentinel: the accept path was reached without the landing checks (guards did not run first)' }
    ${function:Invoke-HitWindowCheck} = { param($x, $y, $tgt, $enforce, $allow)
      [void]$script:dgGuardCalls.Add(@($x, $y))
      if ($x -ge 4000) { throw "landing guard: point ($x,$y) is OUTSIDE target window (unit mock) visible rect - action NOT sent." } }
    $dgErrA = ''
    try { Invoke-DesktopCommand 'drag' @('10', '10', '4000', '4000', '--to', 'dg-fake') | Out-Null }
    catch { $dgErrA = "$($_.Exception.Message)" }
    ST-Check 'unit (P-01): drag judges the start point, then the end point, and refuses on the END point before any audit line exists (a refused drag logs nothing - the same contract the one-point commands run)' (
      (($dgErrA -like '*landing guard*') -and ($dgErrA -like '*action NOT sent*')) -and
      ((@($script:dgGuardCalls).Count -eq 2)) -and
      (($script:dgGuardCalls[0][0] -eq 10) -and ($script:dgGuardCalls[0][1] -eq 10)) -and
      (($script:dgGuardCalls[1][0] -eq 4000) -and ($script:dgGuardCalls[1][1] -eq 4000)) -and
      ((@($script:dgLogCalls).Count -eq 0)))
    [void]$script:dgGuardCalls.Clear(); [void]$script:dgLogCalls.Clear()
    ${function:Invoke-HitWindowCheck} = { param($x, $y, $tgt, $enforce, $allow)
      [void]$script:dgGuardCalls.Add(@($x, $y))
      if ($x -ge 4000) { throw "landing guard: point ($x,$y) is OUTSIDE target window (unit mock) visible rect - action NOT sent." } }
    $dgErrB = ''
    try { Invoke-DesktopCommand 'drag' @('5000', '5000', '60', '60', '--to', 'dg-fake') | Out-Null }
    catch { $dgErrB = "$($_.Exception.Message)" }
    ST-Check 'unit (P-01): drag refuses at the START point with the end point never judged and the audit log untouched (the refusal comes before the drag exists, not after it)' (
      (($dgErrB -like '*landing guard*') -and ($dgErrB -like '*action NOT sent*')) -and
      ((@($script:dgGuardCalls).Count -eq 1)) -and (($script:dgGuardCalls[0][0] -eq 5000)) -and
      ((@($script:dgLogCalls).Count -eq 0)))
    [void]$script:dgGuardCalls.Clear(); [void]$script:dgLogCalls.Clear()
    ${function:Invoke-HitWindowCheck} = $dgHwcReal
    $dgErrC = ''
    $dgOut = New-Object System.Collections.ArrayList
    try { Invoke-DesktopCommand 'drag' @('10', '10', '4000', '4000', '--to', 'dg-fake') | ForEach-Object { [void]$dgOut.Add("$_") } }
    catch { $dgErrC = "$($_.Exception.Message)" }
    $dgE2eOk = ((($dgErrC -like '*landing guard*') -and ($dgErrC -like '*action NOT sent*') -and ($dgErrC -like '*allow-outside*')) -and
      ((@($script:dgLogCalls).Count -eq 0)) -and
      ((@($dgOut | Where-Object { $_ -like 'hit-window:*' }).Count -ge 1)) -and
      ((@($dgOut | Where-Object { $_ -like '*inside-target=no*' }).Count -ge 1)))
    ST-Check 'e2e (P-01): drag 10 10 4000 4000 --to <target at 0,0 100x100> refuses through the REAL landing-check machinery with the production refusal text, one hit-window echo per point, no audit line, and the post-guard steps unreached' (
      $dgE2eOk)
    if (-not $dgE2eOk) { Write-Output ("      P-01 e2e: err=[" + $dgErrC + "] log-calls=" + @($script:dgLogCalls).Count + " echo-lines=" + @($dgOut).Count) }
  } finally {
    ${function:Invoke-HitWindowCheck} = $dgHwcReal
    ${function:Resolve-Target} = $dgRtReal
    ${function:Log-Action} = $dgLaReal
    ${function:Get-ExpectChangeBaseline} = $dgEcbReal
  }

}
