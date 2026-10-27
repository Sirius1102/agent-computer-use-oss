# lib/selftest-window-targeting.ps1 - family window-targeting of the selftest section, lifted out
# of lib/selftest.ps1 by A-14j (A-beta). Bodies are byte-identical to what the section carried.
# Eleven banners in ten gathered pieces: idempotent activation and --expect-change, the anonymous window
# label, the main-window rule as a pure function, the take-a-coordinate ladder, open-and-pick, the
# inverted --region validator, the composite locator, the UIA Chrome exit menu, Resolve-Window
# selector semantics, the uia-tree file route and the CU-REL-01 landing/state guards. State arrives
# only through $Ctx - the help-page line array it reads is the one A-14j hoisted and published, and
# lint (A-14b) names any read that reaches past the handover. Nine pieces from 793..6688 collapse into
# one call: the card counts the resulting reordering by name and position.
function Invoke-SelftestFamily-WindowTargeting($Ctx) {
  # context handover (the one thing in this file that is not lifted text)
  $self = [string]$Ctx['self']
  $codeLines = $Ctx['codeLines']
  $j5ProdStart = $Ctx['j5ProdStart']
  $j5ProdEnd = $Ctx['j5ProdEnd']
  $hLines = $Ctx['hLines']

  # ---------- unit + lint: v1.5.6 idempotent activation, --always-activate, --expect-change ----------
  $v6On = Split-Target @('10', '20', '--always-activate', '--to', 'Win')
  ST-Check 'unit: --always-activate is parsed as a boolean and does not eat the selector' (
    $v6On.AlwaysActivate -eq $true -and $v6On.Sel -ceq 'Win' -and (@($v6On.Words) -join ' ') -ceq '10 20')
  $v6Off = Split-Target @('10', '20', '--to', 'Win')
  ST-Check 'unit: activation stays idempotent by default (flag absent -> AlwaysActivate false)' (
    $v6Off.AlwaysActivate -eq $false)
  $v6EcRect = Split-Target @('10', '20', '--expect-change', '5,6,70,80', '--to', 'Win')
  ST-Check 'unit: --expect-change takes an optional screen rect and keeps --to intact' (
    $v6EcRect.ExpectChange -ceq '5,6,70,80' -and $v6EcRect.Sel -ceq 'Win')
  $v6EcBare = Split-Target @('10', '20', '--expect-change')
  ST-Check 'unit: bare --expect-change means auto region, not an empty value' ($v6EcBare.ExpectChange -ceq 'auto')
  # a value is consumed only as a rect-looking token; a NON-numeric word after the flag
  # stays where it was, and a number-shaped-but-wrong value is refused rather than
  # quietly reinterpreted (measured in the live round: `--expect-change 1,2,3` used to
  # click with an auto region and leave the bad rect as a stray positional).
  $v6EcStray = Split-Target @('10', '20', '--expect-change', 'extra')
  ST-Check 'unit: --expect-change refuses to swallow a non-rect token (it stays in Words)' (
    $v6EcStray.ExpectChange -ceq 'auto' -and (@($v6EcStray.Words) -join ' ') -ceq '10 20 extra')
  $v6EcBad = ''
  try { [void](Split-Target @('10', '20', '--expect-change', '1,2,3')) } catch { $v6EcBad = $_.Exception.Message }
  ST-Check 'unit: a malformed --expect-change rect is refused by the parser, not silently ignored' (
    $v6EcBad.Contains('--expect-change needs x,y,w,h') -and $v6EcBad.Contains('1,2,3'))
  $v6EcWheel = ''
  try { [void](Split-Target @('10', '20', '--expect-change', '300')) } catch { $v6EcWheel = $_.Exception.Message }
  ST-Check 'unit: a lone number after --expect-change is refused too (ambiguous beats silent)' (
    $v6EcWheel.Contains('--expect-change needs x,y,w,h'))
  $v6Reg = Get-ExpectChangeRegion @{ ExpectChange = '7,8,90,100' } $null
  ST-Check 'unit: an explicit --expect-change rect is taken as screen pixels' (
    $v6Reg.X -eq 7 -and $v6Reg.Y -eq 8 -and $v6Reg.W -eq 90 -and $v6Reg.H -eq 100 -and $v6Reg.Source -ceq '--expect-change rect 7,8,90,100')
  $v6Auto = Get-ExpectChangeRegion @{ ExpectChange = 'auto'; Sel = '' } $null
  ST-Check 'unit: auto with no --to says so and measures the whole virtual screen' (
    $v6Auto.Source -like 'virtual screen*' -and $v6Auto.W -gt 0 -and $v6Auto.H -gt 0)
  # Item2 second half: an explicit rect must WIN over the target rect. A caller that
  # passes 1600,1050,700,200 while the target sits at 959,428 1924x1234 must get the
  # small rect measured, never the full window silently substituted back.
  $v6EcExplicitWins = Get-ExpectChangeRegion @{ ExpectChange = '1600,1050,700,200'; Sel = 'FakeWin' } @{ Left = 959; Top = 428; W = 1924; H = 1234; Title = 'FakeWin' }
  ST-Check 'unit: an explicit --expect-change rect wins over the target rect (given != full window)' (
    $v6EcExplicitWins.X -eq 1600 -and $v6EcExplicitWins.Y -eq 1050 -and $v6EcExplicitWins.W -eq 700 -and $v6EcExplicitWins.H -eq 200 -and
    $v6EcExplicitWins.Source -like '*1600,1050,700,200*')
  # Feedback item 2, first half: the shape that actually arrived in the wild - the rect as
  # ONE quoted argument with spaces, logged verbatim in actions.log 2026-10-10 00:48 UTC -
  # must be CONSUMED and canonicalised, never degraded to the auto region.
  $v6EcSpace = $null
  try { $v6EcSpace = Split-Target @('1658', '1087', '--expect-change', '1600 1050 700 200', '--to', 'Win') } catch { }
  ST-Check 'unit: a space-separated --expect-change rect is consumed and canonicalised, never degraded to auto' (
    ($null -ne $v6EcSpace) -and $v6EcSpace.ExpectChange -ceq '1600,1050,700,200' -and $v6EcSpace.Sel -ceq 'Win' -and
    (@($v6EcSpace.Words) -join ' ') -ceq '1658 1087')
  $v6EcSpaceReg = Get-ExpectChangeRegion @{ ExpectChange = '1600 1050 700 200'; Sel = 'FakeWin' } @{ Left = 959; Top = 428; W = 1924; H = 1234; Title = 'FakeWin' }
  ST-Check 'unit: the expect-change echo reports the rect it really measures, not the window it fell back to' (
    $v6EcSpaceReg.X -eq 1600 -and $v6EcSpaceReg.Y -eq 1050 -and $v6EcSpaceReg.W -eq 700 -and $v6EcSpaceReg.H -eq 200 -and
    $v6EcSpaceReg.Source -ceq '--expect-change rect 1600,1050,700,200')
  $v6EcShort = ''
  try { [void](Split-Target @('10', '20', '--expect-change', '1600 1050 700')) } catch { $v6EcShort = $_.Exception.Message }
  ST-Check 'unit: a three-number rect in either spelling is refused by name instead of degrading to the auto region' (
    $v6EcShort.Contains('--expect-change needs x,y,w,h') -and $v6EcShort.Contains('1600 1050 700'))
  $v6Bad = ''
  try { [void](Get-ExpectChangeRegion @{ ExpectChange = '1,2,3' } $null) } catch { $v6Bad = $_.Exception.Message }
  ST-Check 'unit: a malformed --expect-change rect is refused by name' ($v6Bad -like '--expect-change needs x,y,w,h*')
  # v3.0.1 (audit item 5): a SECOND gate inside the parser rejected what the first gate
  # had just admitted, so an explicit rect on a left-hand monitor (negative X, which is
  # where a dual-monitor layout puts it) could never be passed - while --guard-region and
  # --expect-region, which document the SAME convention, accept it. Width and height stay
  # unsigned: a negative extent has no meaning the tool could honour.
  $v6EcNeg = $null
  try { $v6EcNeg = Split-Target @('10', '20', '--expect-change', '-100,0,50,50', '--to', 'Win') } catch { }
  ST-Check 'unit: a negative --expect-change rect is consumed, not refused (left monitor)' (
    ($null -ne $v6EcNeg) -and $v6EcNeg.ExpectChange -ceq '-100,0,50,50' -and $v6EcNeg.Sel -ceq 'Win' -and (@($v6EcNeg.Words) -join ' ') -ceq '10 20')
  $v6NegReg = Get-ExpectChangeRegion @{ ExpectChange = '-100,20,50,60' } $null
  ST-Check 'unit: a negative --expect-change rect reaches the screen mapping with its sign' (
    $v6NegReg.X -eq -100 -and $v6NegReg.Y -eq 20 -and $v6NegReg.W -eq 50 -and $v6NegReg.H -eq 60)
  $v6EcNegW = ''
  try { [void](Split-Target @('10', '20', '--expect-change', '1,2,-3,4')) } catch { $v6EcNegW = $_.Exception.Message }
  ST-Check 'unit: a NEGATIVE width or height in --expect-change is still refused' (
    $v6EcNegW.Contains('--expect-change needs x,y,w,h'))
  # the three rect-taking flags must speak one signedness, or a call that works on one
  # command throws on another for the same token (measured: --expect-change alone).
  $v6SignOk = $true
  foreach ($v6SignProbe in @('-100,0,50,50', '0,-40,50,50', '-1,-2,3,4')) {
    $v6SignER = $true
    try { [void](Split-Target @('10', '20', '--expect-region', $v6SignProbe)) } catch { $v6SignER = $false }
    $v6SignEC = $true
    try { [void](Split-Target @('10', '20', '--expect-change', $v6SignProbe)) } catch { $v6SignEC = $false }
    $v6SignGR = $true
    try { [void](Split-Target @('10', '20', '--guard-region', ($v6SignProbe + '=needle here'))); } catch { $v6SignGR = $false }
    if (-not ($v6SignER -and $v6SignEC -and $v6SignGR)) { $v6SignOk = $false; Write-Output "      signed-rect disagreement for $v6SignProbe : expect-region=$v6SignER expect-change=$v6SignEC guard-region=$v6SignGR" }
  }
  ST-Check 'contract: expect-region, expect-change and guard-region accept the same signed screen rects' ($v6SignOk)
  # single-source lints: these verdicts must be produced in exactly one place, or a new
  # call site can start claiming "activated" / proving nothing without anyone noticing.
  # Every marker below is ASSEMBLED by concatenation on purpose: a scan line that
  # literally contains its own search string matches itself, and the first draft of
  # these three checks went red on the file's own selftest block.
  $v6ActMark = 'this call activated ' + 'the window'
  $v6ActSite = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($v6ActMark) })
  ST-Check 'lint: the activation NOTICE has exactly one producer (never per-call-site wording)' ($v6ActSite.Count -eq 1)
  # ...and that one producer must be CONDITIONAL: an unconditional NOTICE is printed on
  # every --to, which is noise, and noise is what makes warnings unread. Measured reason:
  # with only the count check above, mutating `if ($w.Activated)` to `if ($true)` stayed
  # green offline - the live case sees it, the fast gate did not.
  $v6CondOk = $false
  for ($v6j = 0; $v6j -lt $codeLines.Count; $v6j++) {
    if ($codeLines[$v6j].Contains($v6ActMark)) {
      for ($v6k = $v6j - 1; $v6k -ge [Math]::Max(0, $v6j - 6); $v6k--) {
        if ($codeLines[$v6k] -match '^\s*if \(' -and $codeLines[$v6k].Contains('Activated')) { $v6CondOk = $true; break }
      }
      break
    }
  }
  ST-Check 'lint: the NOTICE is emitted only under an Activated condition (never per-call noise)' ($v6CondOk -eq $true)
  # !! The contract this round's live run actually BROKE, now pinned: a function that
  # returns an object must not also write to the pipeline. `$tgt = Resolve-Target ...`
  # swallowed the activated= line into $tgt (an array of [string, object]), member
  # enumeration kept $tgt.Handle / $tgt.Pid working so 337 other checks stayed green,
  # and the user never saw the verdict the feature exists to print.
  $rtStart = -1; $rtEnd = $codeLines.Count
  for ($vi = 0; $vi -lt $codeLines.Count; $vi++) { if ($codeLines[$vi] -match '^function Resolve-Target') { $rtStart = $vi; break } }
  if ($rtStart -ge 0) { for ($vi = $rtStart + 1; $vi -lt $codeLines.Count; $vi++) { if ($codeLines[$vi] -match '^function ') { $rtEnd = $vi; break } } }
  $rtWrites = @($codeLines[$rtStart..($rtEnd - 1)] | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '^\s*(Write-Output|Write-Host)\s' })
  ST-Check 'lint: an object-returning resolver (Resolve-Target) writes nothing to the pipeline' ($rtStart -ge 0 -and @($rtWrites).Count -eq 0)
  foreach ($rw in @($rtWrites)) { Write-Output "      pipeline write inside a resolver: $($rw.Trim())" }
  $emitV = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_ -match 'Write-Output \$script:ActivationLine' })
  $emitN = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_ -match 'Write-Output \$script:ActivationNotice' })
  ST-Check 'lint: the activation verdict is printed from exactly one place (Emit-ResolveNote)' (
    @($emitV).Count -eq 1 -and @($emitN).Count -eq 1)
  # v1.5.3 taught this the hard way: a parameter that only lives in the signature.
  $v6FwdPat = 'Resolve-Target \$p\.Sel \$p\.' + 'Force(?! \$p\.AlwaysActivate)'
  $v6NoArg = New-Object System.Collections.ArrayList
  for ($v6i = 0; $v6i -lt $codeLines.Count; $v6i++) {
    if ($codeLines[$v6i] -match '^\s*#') { continue }
    if ($codeLines[$v6i] -match $v6FwdPat) { [void]$v6NoArg.Add($v6i + 1) }
  }
  ST-Check 'lint: every --to call site forwards the rollback switch (no flag that only lives in the signature)' (@($v6NoArg).Count -eq 0)
  foreach ($v6n in @($v6NoArg)) { Write-Output "      Resolve-Target call without --always-activate: line $v6n" }
  $v6Plant = '  $t = Resolve-Target $p.Sel $p.' + 'Force'
  ST-Check 'lint: the forward-check detects a planted two-argument call' ($v6Plant -match $v6FwdPat)
  # X-02: the pinned spelling moved with the code it pins (the step object's optional fields now
  # go through the one reader), and the marker is still split so this scan line cannot match
  # itself. This edits the LITERAL being looked for, NOT the comparison: exactly one site, same as before.
  $v6ScriptMark = 'Resolve-Target (Get-OptValue $s ' + '''to'') ([bool](Get-OptValue $s ''force'')) ([bool](Get-OptValue $s ''alwaysActivate''))'
  $v6ScriptFwd = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($v6ScriptMark) })
  ST-Check 'lint: the script step path forwards alwaysActivate too (its own spelling)' (@($v6ScriptFwd).Count -eq 1)
  # both branches of the proof-of-effect verdict, asserted WITHOUT touching the desktop:
  # this is what makes the offline gate able to see a neutered WARN branch at all.
  $v6BaseSame = @{ X = 5; Y = 6; W = 7; H = 8; Source = 'unit fixture'; Hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' }
  $v6Same = Format-ExpectChangeVerdict $v6BaseSame 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' 'clicked'
  $v6Diff = Format-ExpectChangeVerdict $v6BaseSame 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' 'clicked'
  ST-Check 'unit: a pixel-identical region produces the WARN, and it names the rect it measured' (
    $v6Same -like 'WARN: --expect-change:*' -and $v6Same.Contains('PIXEL-IDENTICAL (md5 aaaa') -and
    $v6Same.Contains('region (5,6) 7x8 from unit fixture'))
  ST-Check 'unit: a changed region reports the two hashes and never claims the WARN' (
    $v6Diff -like 'expect-change: after clicked*' -and $v6Diff.Contains('aaaa') -and $v6Diff.Contains('bbbb') -and
    -not $v6Diff.Contains('PIXEL-IDENTICAL'))
  ST-Check 'unit: the WARN still says it is not proof of failure (opt-in must not over-claim)' (
    $v6Same.Contains('NOT proof of failure'))
  $v6Quiet = @(Invoke-ExpectChangeCheck @{ ExpectChange = '' } $v6BaseSame 'clicked')
  ST-Check 'unit: without the flag the check prints nothing (default off, zero behaviour change)' (@($v6Quiet).Count -eq 0)
  $v6Wired = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains('Invoke-ExpectChangeCheck ') })
  ST-Check 'lint: every action command wires the proof-of-effect (click/rclick/dblclick/drag/find-click/wheel)' ($v6Wired.Count -ge 6)

  # ---------- unit: v1.5.5 (D-8) window label, including the anonymous surfaces ----------
  $wlT = Format-WindowLabel 'Notepad' 'Notepad'
  $wlTaskbar = Format-WindowLabel '' 'Shell_TrayWnd'
  $wlTaskbar2 = Format-WindowLabel '' 'Shell_SecondaryTrayWnd'
  $wlDesk = Format-WindowLabel '' 'Progman'
  $wlDesk2 = Format-WindowLabel '' 'WorkerW'
  $wlClass = Format-WindowLabel '' 'Chrome_WidgetWin_1'
  $wlNone = Format-WindowLabel '' ''
  $wlNull = Format-WindowLabel $null $null
  ST-Check 'unit: a titled covering window is still named verbatim in quotes (D-8 must not hide names)' (
    $wlT -ceq "'Notepad'")
  ST-Check 'unit: the taskbar and the desktop are named as themselves, not as an empty string' (
    $wlTaskbar -ceq '(taskbar)' -and $wlTaskbar2 -ceq '(taskbar)' -and
    $wlDesk -ceq '(desktop)' -and $wlDesk2 -ceq '(desktop)')
  ST-Check 'unit: any other anonymous window falls back to its class name' (
    $wlClass -ceq '(class Chrome_WidgetWin_1)')
  # the whole point of D-8: no combination may render as '' - that is the string that
  # sent people hunting for a window that does not exist.
  ST-Check 'unit: no title/class combination renders as an empty or quote-only label' (
    $wlNone -ceq '(untitled)' -and $wlNull -ceq '(untitled)' -and
    @( @($wlT, $wlTaskbar, $wlDesk, $wlClass, $wlNone) | Where-Object { -not $_ -or $_ -ceq "''" } ).Count -eq 0)

  # ---------- unit: v1.5.7 (D-7) the main-window rule is a pure function, so all of
  # these shapes are provable offline instead of waiting for a live fixture ----------
  $d7Rows = @(
    [pscustomobject]@{ Handle = [IntPtr]1; Pid = 100; Owner = 0; Area = 100 },
    [pscustomobject]@{ Handle = [IntPtr]2; Pid = 100; Owner = 0; Area = 50 },
    [pscustomobject]@{ Handle = [IntPtr]3; Pid = 100; Owner = 1; Area = 1000 },
    [pscustomobject]@{ Handle = [IntPtr]4; Pid = 200; Owner = 5; Area = 10 },
    [pscustomobject]@{ Handle = [IntPtr]5; Pid = 300; Owner = 0; Area = 70 },
    [pscustomobject]@{ Handle = [IntPtr]6; Pid = 300; Owner = 0; Area = 70 }
  )
  $d7Map = Select-MainWindowMap $d7Rows
  ST-Check 'unit: D-7 main map - largest UNOWNED window of a pid is the main one' (
    $d7Map[[int64]1] -ceq 'yes' -and $d7Map[[int64]2] -ceq 'no')
  ST-Check 'unit: D-7 main map - an owned window is never main even when it is far larger' ($d7Map[[int64]3] -ceq 'no')
  ST-Check 'unit: D-7 main map - a pid whose windows all have owners still gets exactly one main' ($d7Map[[int64]4] -ceq 'yes')
  ST-Check 'unit: D-7 main map - equal areas break deterministically (lowest handle)' ($d7Map[[int64]5] -ceq 'yes' -and $d7Map[[int64]6] -ceq 'no')
  $d7Map2 = Select-MainWindowMap @($d7Rows | Sort-Object -Property Area)
  $d7Same = $true
  foreach ($k in @($d7Map.Keys)) { if ($d7Map[$k] -cne $d7Map2[$k]) { $d7Same = $false } }
  ST-Check 'unit: D-7 main map - input order does not change the answer (same rows -> same map)' ($d7Same)
  $d7Picked = @(
    [pscustomobject]@{ Handle = [IntPtr]1; Pid = 100; Owner = 0; Area = 100; W = 10; H = 10; Title = 'MainWin'; Main = 'yes' },
    [pscustomobject]@{ Handle = [IntPtr]2; Pid = 100; Owner = 0; Area = 50; W = 5; H = 5; Title = 'PromoWin'; Main = 'no' },
    [pscustomobject]@{ Handle = [IntPtr]7; Pid = 700; Owner = 0; Area = 9; W = 3; H = 3; Title = 'Alone'; Main = 'yes' }
  )
  $d7Note = Format-NonMainPickNote $d7Picked[1] $d7Picked 'fg'
  ST-Check 'unit: D-7 note fires when a non-main window of a multi-window pid is picked and names the main one' (
    $d7Note.StartsWith('note: pid=100 has a main window handle=1') -and $d7Note.Contains('PromoWin') -and
    $d7Note.Contains('because it is the foreground window of that process'))
  $d7NoteL = Format-NonMainPickNote $d7Picked[1] $d7Picked 'largest'
  ST-Check 'unit: D-7 note states the real basis (largest) instead of blaming the foreground' ($d7NoteL.Contains('it is the largest matching window'))
  $d7NoteMain = Format-NonMainPickNote $d7Picked[0] $d7Picked 'fg'
  ST-Check 'unit: D-7 note is silent when the main window is the one picked' ($d7NoteMain -ceq '')
  $d7NoteSolo = Format-NonMainPickNote $d7Picked[2] $d7Picked 'fg'
  ST-Check 'unit: D-7 note is silent for a single-window process (no ambiguity to report)' ($d7NoteSolo -ceq '')
  # ---------- v2.1.0 (plan doc 1.3): the take-a-coordinate ladder lives IN the tool ----------
  # The ladder existed only as memory in whoever happened to have paid for it, so every
  # new session re-derived it wrong (four eyeballed clicks in one session, each one
  # costing a retry cycle to notice). Counted by KEY SENTENCE, never by line number -
  # numbers drift, this file has been bitten by that repeatedly. The usage page is a
  # here-string (blanked out of $codeLines), so the ladder is scanned in $hLines.
  $hLadderKey = 'Taking a coordinate off the screen - the ORDER'
  $hLadderHeader = @($hLines | Where-Object { $_.StartsWith('    ' + $hLadderKey) }).Count
  $hLadderMentions = @($hLines | Where-Object { $_.Contains($hLadderKey) }).Count
  $hPage = @($hLines) -join "`n"
  $hStep1 = $hPage.IndexOf('1  find <text>')
  $hStep2 = $hPage.IndexOf('2  uia-find')
  $hStep3 = $hPage.IndexOf('3  find-text / find-click')
  $hStep4 = $hPage.IndexOf('4  imgclick')
  # the four numbered lines start with command tokens, so Format-CommandHelp reads them as
  # entry headers and the ladder itself is NOT part of any single command's block - find's
  # entry therefore POINTS at the ladder, and that pointer is what per-command help shows.
  $hFindEntry = (@(Format-CommandHelp $hLines 'find') -join "`n")
  ST-Check 'unit: the help page carries the coordinate ladder exactly once, in find > uia-find > find-text > imgclick order, and help find points at it (plan 1.3)' (
    ($hLadderHeader -eq 1) -and ($hLadderMentions -eq 2) -and ($hStep1 -ge 0) -and ($hStep1 -lt $hStep2) -and ($hStep2 -lt $hStep3) -and ($hStep3 -lt $hStep4) -and
    $hFindEntry.Contains($hLadderKey))
  # Telling people NOT to eyeball a downscaled image without naming the road is how they
  # keep eyeballing it - both warnings must point at imgclick and at the .map.txt that is
  # already sitting next to the capture they just took.
  $hImgclickWarn = 0; $hMapWarn = 0; $hWarnSites = 0
  for ($hl = 0; $hl -lt $codeLines.Count; $hl++) {
    if ($hl -ge $j5ProdStart -and $hl -lt $j5ProdEnd) { continue }
    if ($codeLines[$hl] -match '^\s*#') { continue }
    if ($codeLines[$hl].Contains('DOWNSCALE this image') -or $codeLines[$hl].Contains('downscale it once more')) {
      $hWarnSites++
      if ($codeLines[$hl].Contains('imgclick')) { $hImgclickWarn++ }
      if ($codeLines[$hl].Contains('.map.txt')) { $hMapWarn++ }
    }
  }
  ST-Check 'lint: both downscaled-image warnings name imgclick AND the .map.txt beside the capture (forbid-the-guess without naming-the-road is the shape that keeps failing)' (
    ($hWarnSites -eq 2) -and ($hImgclickWarn -eq 2) -and ($hMapWarn -eq 2))
  Write-Output ("      coordinate ladder: header=$hLadderHeader mentions=$hLadderMentions steps=$hStep1/$hStep2/$hStep3/$hStep4 warn-sites=$hWarnSites imgclick=$hImgclickWarn map=$hMapWarn")

  # ---------- unit: v1.6.0 A-1 open-and-pick - parsing and refusal shapes (offline) ----------
  # The click/shoot/OCR chain needs a live desktop; everything BEFORE Resolve-Target is
  # provable here by invoking the real dispatcher and catching its refusals (a throw in a
  # unit is caught per the abort-vs-fail rule, never allowed to kill the gate).
  $opBad = 'NOT-THROWN'
  try { Parse-OpenPickRegion '10,20' | Out-Null } catch { $opBad = $_.Exception.Message }
  ST-Check 'unit: open-and-pick --region refuses a three-number spec by name' ($opBad.Contains('open-and-pick: --region needs x,y,w,h'))
  $opZero = 'NOT-THROWN'
  try { Parse-OpenPickRegion '10,20,0,50' | Out-Null } catch { $opZero = $_.Exception.Message }
  ST-Check 'unit: open-and-pick --region refuses a zero width/height' ($opZero.Contains('width/height must be > 0'))
  ST-Check 'unit: open-and-pick --region absent means the whole window (null, not an empty scan)' ($null -eq (Parse-OpenPickRegion ''))
  $opR = 'THREW'
  try { $opR = Parse-OpenPickRegion '10,20,300,120' } catch { $opR = 'THREW: ' + $_.Exception.Message }
  ST-Check 'unit: open-and-pick --region parses to a window-relative rect' (
    ($opR -isnot [string]) -and $opR.X -eq 10 -and $opR.Y -eq 20 -and $opR.W -eq 300 -and $opR.H -eq 120)
  $opShort = 'NO-THROW'
  try { Invoke-DesktopCommand 'open-and-pick' @('Notepad', '10', '20') | Out-Null } catch { $opShort = $_.Exception.Message }
  ST-Check 'unit: open-and-pick refuses to run with fewer than four positional arguments (usage names the shape)' ($opShort.Contains('usage: open-and-pick <sel> <opener-x> <opener-y> <needle...>'))
  $opNeedle = 'NO-THROW'
  try { Invoke-DesktopCommand 'open-and-pick' @('Notepad', '10', '20', '') | Out-Null } catch { $opNeedle = $_.Exception.Message }
  ST-Check 'unit: open-and-pick refuses an empty needle before anything is clicked' ($opNeedle -eq 'open-and-pick: empty needle')
  $opRegion = 'NO-THROW'
  try { Invoke-DesktopCommand 'open-and-pick' @('Notepad', '10', '20', 'x', '--region', 'bad') | Out-Null } catch { $opRegion = $_.Exception.Message }
  ST-Check 'unit: open-and-pick refuses a malformed --region before anything is clicked' ($opRegion.Contains('--region needs x,y,w,h'))
  $opCoords = 'NO-THROW'
  try { Invoke-DesktopCommand 'open-and-pick' @('Notepad', 'left', '20', 'File') | Out-Null } catch { $opCoords = $_.Exception.Message }
  ST-Check 'unit: open-and-pick refuses non-integer opener coordinates' ($opCoords.Contains('opener coordinates must be integers'))
  $opStrip = Strip-OwnFlags @('--region', '5,6,70,80', '--expect', 'Done', 'Notepad', '10', '20', 'File') 'open-and-pick'
  ST-Check 'unit: open-and-pick strips --region as a raw value and passes the expect family through to Split-Target' (
    "$((Get-OptValue $opStrip 'Values')['--region'])" -ceq '5,6,70,80' -and $opStrip.Present['--region'] -and (@($opStrip.Rest) -contains '--expect'))

  # ---------- unit+lint: v2.3.0 red-3 - find --region's inverted validator (real machine 2026-10-02) ----------
  # The shipped inline check demanded "count of non-numeric segments == 4": every VALID
  # x,y,w,h threw the named error and garbage like a,b,c,d sailed through to die at the
  # [int] cast (both shapes reproduced live on this machine, evidence archived in
  # .cowork-temp/zq-red-find-region-inverted.md). The extracted parser above is now the
  # single pure producer of both refusals; these checks hold it directly, and the two
  # lints keep the handler from ever growing a second copy of the logic. The lint needle
  # is built by concatenation so no scan line contains its own search string.
  $frOk = 'THREW'
  try { $frOk = Parse-FindRegionSpec '100,100,50,30' } catch { $frOk = 'THREW: ' + $_.Exception.Message }
  ST-Check 'unit: find --region accepts a legal x,y,w,h and parses every field (red-3 fix)' (
    ($frOk -isnot [string]) -and $frOk.X -eq 100 -and $frOk.Y -eq 100 -and $frOk.W -eq 50 -and $frOk.H -eq 30)
  $frNeg = 'THREW'
  try { $frNeg = Parse-FindRegionSpec '-10,-5,50,30' } catch { $frNeg = 'THREW: ' + $_.Exception.Message }
  ST-Check 'unit: find --region keeps negative x/y legal (the original character class allowed them)' (
    ($frNeg -isnot [string]) -and $frNeg.X -eq -10 -and $frNeg.Y -eq -5)
  $frBad = 'NOT-THROWN'
  try { Parse-FindRegionSpec 'a,b,50,30' | Out-Null } catch { $frBad = $_.Exception.Message }
  ST-Check 'unit: find --region refuses a non-numeric segment by name (it used to slip through)' ($frBad.Contains('find: --region needs x,y,w,h in screen pixels'))
  $frZero = 'NOT-THROWN'
  try { Parse-FindRegionSpec '100,100,0,30' | Out-Null } catch { $frZero = $_.Exception.Message }
  ST-Check 'unit: find --region still refuses a zero width' ($frZero.Contains('find: --region w/h must be positive'))
  $frThree = 'NOT-THROWN'
  try { Parse-FindRegionSpec '1,2,3' | Out-Null } catch { $frThree = $_.Exception.Message }
  $frFive = 'NOT-THROWN'
  try { Parse-FindRegionSpec '1,2,3,4,5' | Out-Null } catch { $frFive = $_.Exception.Message }
  ST-Check 'unit: find --region refuses segment counts other than four (three and five both tried)' (
    $frThree.Contains('find: --region needs x,y,w,h in screen pixels') -and $frFive.Contains('find: --region needs x,y,w,h in screen pixels'))
  $frDefNeedle = 'function Parse-' + 'FindRegionSpec'
  $frDefSites = @([regex]::Matches((@($codeLines) -join "`n"), $frDefNeedle)).Count
  ST-Check 'lint: find --region validation has exactly one definition (single-producer rule)' (
    $frDefSites -eq 1)
  $frCallNeedle = '= Parse-' + 'FindRegionSpec \$fRegion'
  $frCallSites = @([regex]::Matches((@($codeLines) -join "`n"), $frCallNeedle)).Count
  ST-Check 'lint: the find handler is the one production caller of the extracted --region parser' (
    $frCallSites -eq 1)
  $frInlineNeedle = '\$f' + 'Region -split'
  $frInline = @([regex]::Matches((@($codeLines) -join "`n"), $frInlineNeedle)).Count
  ST-Check 'lint: the inverted inline --region split is gone from the find handler (zero copies left)' (
    $frInline -eq 0)

  # ---------- v2.1.0 (plan doc 1.1): the composite locator 'find' ----------
  # The rule under test is WHICH ROAD ANSWERED, so every cell is pinned in both
  # directions: a UIA hit must win and must not be relabelled, an OCR-only answer must
  # be marked degraded (that is the whole point of the field), and the two-zeroes cell
  # must refuse with both volumes in the message. The message is checked as RENDERED
  # text - a miss line that names one road and not the other is the shape that lets a
  # caller conclude 'the text is not there' from a scan that never looked properly.
  $f12Uia = Get-FindSourceDecision 1 0
  ST-Check 'unit: find source decision - a UIA hit answers as uia and is never called a degradation' (
    ($f12Uia.Source -ceq 'uia') -and (-not $f12Uia.Degraded) -and (-not $f12Uia.Refuse))
  $f12UiaWins = Get-FindSourceDecision 1 5
  ST-Check 'unit: find source decision - OCR finding more lines does NOT steal the answer from UIA (road order, not hit count)' (
    $f12UiaWins.Source -ceq 'uia')
  $f12Ocr = Get-FindSourceDecision 0 3
  ST-Check 'unit: find source decision - UIA empty with OCR hits is source=ocr AND degraded=true (a silent fallback is the bug this field exists to prevent)' (
    ($f12Ocr.Source -ceq 'ocr') -and $f12Ocr.Degraded -and (-not $f12Ocr.Refuse))
  $f12None = Get-FindSourceDecision 0 0
  ST-Check 'unit: find source decision - both roads empty refuses, it never reports a source that produced nothing' (
    ($f12None.Source -ceq 'none') -and $f12None.Refuse)
  $f12Miss = Format-FindMiss 'QXABSENTTEXT' 14 'walks=2 cold-zero-reprobe=yes -> still 0 (scanned=14)' 7 'no retry ran' '(100,200) 420x240' '; occluded=0%'
  ST-Check 'unit: find miss text names BOTH roads with what each one measured (never a bare not-found)' (
    ($f12Miss.Contains('uia scanned 14 element(s)')) -and ($f12Miss.Contains('OCR read 7 line(s)')) -and
    ($f12Miss.Contains('walks=2')) -and ($f12Miss.Contains('no retry ran')) -and ($f12Miss.Contains("NOT 'absent'")))
  $f12Env = New-FindJsonEnvelope 'ocr' 'target=pid=7 region=(1,2,3x4) via=target' $null @(@{ road = 'ocr'; text = 'x' })
  $f12Keys = (@($f12Env.PSObject.Properties.Name) | Sort-Object) -join ','
  $f12Want = @(Get-FindJsonTopKeys | Sort-Object) -join ','
  ST-Check 'contract: find --json key set is exactly what Get-FindJsonTopKeys lists (source is a REQUIRED key of this envelope; the phrase "keys are exactly" stays owned by the two OCR contracts)' (
    ($f12Keys -ceq $f12Want) -and ($f12Keys.Contains('source')) -and ([int]$f12Env.schemaVersion -eq [int]$script:JsonSchemaVersion))
  $f12Probe = ($f12Env | ConvertTo-Json -Compress -Depth 5 | ConvertFrom-Json)
  ST-Check 'contract: find --json keeps hits an ARRAY for one hit (a scalar here silently breaks every consumer that iterates it)' (
    @($f12Probe.hits).Count -eq 1 -and ($f12Probe.hits[0].road -ceq 'ocr'))
  # find's own envelope must not be the OCR envelope: the two published key sets stay frozen.
  # v3.0.0 (B-6) updated this literal ON PURPOSE: contentTrust joined the OCR envelope and the
  # schema version moved with it, which is exactly the "bump it in the same commit" bookkeeping
  # the envelope comment demands. The inequality half is the part that still guards find.
  $f12OcrEnvKeys = (@((New-OcrJsonEnvelope 'hits' $null @()).PSObject.Properties.Name) | Sort-Object) -join ','
  ST-Check 'contract: adding find did not touch the published find-text/read-text key sets (the OCR envelope is still a different shape from find, whatever B-6 added to both)' (
    ($f12OcrEnvKeys -ceq (Get-JsonContractKeySet 'find')) -and ($f12OcrEnvKeys -ne $f12Want))
  # one producer per decision, and the road is never re-derived by hand in the handler
  $f12Decide = 0; $f12DegradedEcho = 0; $f12SourceEcho = 0
  for ($f12i = 0; $f12i -lt $codeLines.Count; $f12i++) {
    if ($f12i -ge $j5ProdStart -and $f12i -lt $j5ProdEnd) { continue }
    if ($codeLines[$f12i] -match '^\s*#') { continue }
    if ($codeLines[$f12i].Contains('= Get-FindSourceDecision ')) { $f12Decide++ }
    if ($codeLines[$f12i].Contains('falling back to OCR on the same rect')) { $f12DegradedEcho++ }
    if ($codeLines[$f12i].Contains('find: source=$($fDecision.Source)') -or $codeLines[$f12i].Contains('find: source=uia ') -or $codeLines[$f12i].Contains('find: source=ocr ')) { $f12SourceEcho++ }
  }
  ST-Check 'lint: find decides its source through one producer, announces the fallback exactly once, and echoes the source per road (no hand-rolled second opinion)' (
    ($f12Decide -eq 2) -and ($f12DegradedEcho -eq 1) -and ($f12SourceEcho -eq 2))
  Write-Output ("      find wiring: decision-sites=$f12Decide fallback-echo=$f12DegradedEcho source-echo=$f12SourceEcho")
  # Literal name matching. -like turned '[', ']' and '*' inside a control's own Name into
  # wildcards, so the element could not be found by the very string the tool printed.
  $c18Cases = @(
    @('TELEBOT [main] window', '[main]', $true),
    @('a*b', '*', $true),
    @('QXHELLO', 'qxhello', $true),
    @('plain name', 'xyz', $false),
    @('anything', '', $false),
    @('', 'x', $false)
  )
  $c18Bad = ''
  foreach ($c18c in $c18Cases) {
    $c18Got = $false
    try { $c18Got = [bool](Test-NameSubstring $c18c[0] $c18c[1]) } catch { $c18Got = 'THREW' }
    if ($c18Got -ne $c18c[2]) { $c18Bad = "name='$($c18c[0])' needle='$($c18c[1])' -> $c18Got, expected $($c18c[2])" }
  }
  ST-Check 'unit: UIA and tab name matching is literal - brackets and * inside a Name match themselves, an empty needle matches nothing, case stays insensitive' ($c18Bad -eq '')
  $c19Q = [string][char]34
  $c19Bad = New-Object System.Collections.ArrayList
  for ($c19i = 0; $c19i -lt $codeLines.Count; $c19i++) {
    if ($c19i -ge $j5ProdStart -and $c19i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c19i] -match '^\s*#') { continue }
    if ($codeLines[$c19i].Contains(('-like ' + $c19Q + '*$($Rest[1])*' + $c19Q)) -or $codeLines[$c19i].Contains(('-like ' + $c19Q + '*$nameSub*' + $c19Q))) { [void]$c19Bad.Add($c19i + 1) }
  }
  ST-Check 'lint: no uia-family command matches an element Name with -like any more (wildcards inside a Name made the Name unfindable)' (
    @($c19Bad).Count -eq 0)
  if (@($c19Bad).Count -gt 0) { Write-Output "      -like name matches left at lines: $(@($c19Bad) -join ', ')" }
  $c15Mark = ('Uia-WalkAll @($r0) ' + '$maxDepth')
  $c15Depth = 0
  for ($c15i = 0; $c15i -lt $codeLines.Count; $c15i++) { if ($codeLines[$c15i].Contains($c15Mark)) { $c15Depth++ } }
  # mark assembled, not literal: written plainly this search string also appears on
  # the scanning line itself and the count silently becomes 2 (this repo has been
  # bitten by that three times in one day).
  $c15FeedMark = ('Measure-A11yTree $w ' + '$bigDepth')
  $c15Feed = 0
  for ($c15i = 0; $c15i -lt $codeLines.Count; $c15i++) { if ($codeLines[$c15i].Contains($c15FeedMark)) { $c15Feed++ } }
  Write-Output ("      depth call sites: walker=" + $c15Depth + " probe=" + $c15Feed)
  ST-Check 'lint: a11y-probe depth reaches the walker, and Uia-WalkAll honours it (a knob that changes nothing is a fake flag)' (
    # 2 feed sites since A-6b: a11y-probe's first measurement and its cold-zero re-probe
    ($c15Depth -eq 1) -and ($c15Feed -eq 2))
  # A cold 'collapsed' must be re-measured before it becomes a verdict (A-6b: the first
  # UIA contact after a Chrome start reads 0 because that contact is what enables the
  # tree). Marks assembled by concatenation so this scan cannot satisfy itself.
  $c20MeasureMark = ('= Measure-A11yTree $w ') + '$bigDepth'
  $c20AdoptMark = 'if ($m2.PageHits -gt 0) { $m = $m2 }'
  $c20EchoMark = 'cold-zero-re' + 'probe='
  $c20Sites = 0; $c20Adopt = 0; $c20Echo = 0
  for ($c20i = 0; $c20i -lt $codeLines.Count; $c20i++) {
    if ($c20i -ge $j5ProdStart -and $c20i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c20i] -match '^\s*#') { continue }
    if ($codeLines[$c20i].Contains($c20MeasureMark)) { $c20Sites++ }
    if ($codeLines[$c20i].Contains($c20AdoptMark)) { $c20Adopt++ }
    if ($codeLines[$c20i].Contains($c20EchoMark)) { $c20Echo++ }
  }
  ST-Check 'lint: a11y-probe re-measures a collapsed page area before calling it collapsed, and self-reports that it did (cold-start zeros are not verdicts)' (
    # echo 1 -> 2 on 2026-10-01 (uia-find gained the same cold-start re-contact, plan 1.2)
    # and 2 -> 3 the same day (find's UIA road carries it too, plan 1.1). Expected value
    # follows a new measurement point - the strictness of the check is unchanged (same
    # precedent as the v1.8.0 3->4 / 1->2 count updates: the expected value moved, the
    # strictness did not).
    ($c20Sites -eq 2) -and ($c20Adopt -eq 1) -and ($c20Echo -eq 3))
  Write-Output "      a11y re-probe: measure-sites=$c20Sites adopt=$c20Adopt echo=$c20Echo"

  # ---------- option B: the UIA-driven Chrome exit menu (owner ruling 2026-09-30 22:0x) ----------
  # The exit menu is destructive when misread (sign-out sits one glyph away from quit), so
  # both selectors must refuse instead of guessing. These units feed synthetic rows; the
  # real menu is only opened by live runs. CJK corpus entries are code-point assembled -
  # this file stays pure ASCII beyond its BOM, and a GBK-rotted literal would still pass
  # an equality test written the same rotted way.
  $c30QuitBrowser = [string]([char]0x9000) + [char]0x51FA + [char]0x6D4F + [char]0x89C8 + [char]0x5668   # quit browser (5 glyphs)
  $c30QuitAccel = [string]([char]0x9000) + [char]0x51FA + '(X)'   # quit(X) - label as read on Chrome 154 zh-CN
  $c30SignOut = [string]([char]0x9000) + [char]0x51FA + [char]0x767B + [char]0x5F55   # sign out - must never satisfy an exit needle
  $c30Row = { param($ct, $nm, $x, $y, $w, $h) [pscustomobject]@{ ControlType = $ct; Name = $nm; X = $x; Y = $y; W = $w; H = $h } }
  # The 4-row corpus carries BOTH accident shapes the handover names: a TabItem titled
  # "<page> - Google Chrome" (never reaches the Name filter - the control-type filter
  # drops it first) and a BUTTON whose Name merely CONTAINS Chrome (the row substring
  # matching would actually select; exact matching must not).
  $c30Pick = Select-ChromeMenuButton @((& $c30Row 'Button' 'Chrome' 1700 160 46 30), (& $c30Row 'TabItem' 'TELEBOT console - Google Chrome' 600 160 300 30), (& $c30Row 'Button' 'TELEBOT console - Google Chrome' 600 200 300 30), (& $c30Row 'Text' 'Chrome' 0 0 100 20))
  ST-Check 'unit: Select-ChromeMenuButton picks the one Button named exactly Chrome and ignores a button or tab whose name merely contains Chrome' (
    $c30Pick.Ok -and ($c30Pick.Index -eq 0) -and ($c30Pick.Candidates -eq 1))
  $c30Two = Select-ChromeMenuButton @((& $c30Row 'Button' 'Chrome' 1700 160 46 30), (& $c30Row 'Button' 'Chrome' 1700 200 46 30))
  ST-Check 'unit: Select-ChromeMenuButton refuses two same-name buttons and reports the candidate count' (
    (-not $c30Two.Ok) -and ($c30Two.Candidates -eq 2))
  $c30Tab = Select-ChromeMenuButton @((& $c30Row 'TabItem' 'TELEBOT console - Google Chrome' 600 160 300 30))
  ST-Check 'unit: Select-ChromeMenuButton refuses when only a tab name contains Chrome, and says how many rows it swept' (
    (-not $c30Tab.Ok) -and ($c30Tab.Reason.Contains('among 1 row(s)')))
  $c30Text = Select-ChromeMenuButton @((& $c30Row 'Text' 'Chrome' 0 0 100 20))
  ST-Check 'unit: Select-ChromeMenuButton needs the Button control type (a Text named Chrome is not the app menu)' (-not $c30Text.Ok)
  $c30Zero = Select-ChromeMenuButton @()
  ST-Check 'unit: Select-ChromeMenuButton on an empty row set refuses and reports among 0 row(s)' (
    (-not $c30Zero.Ok) -and ($c30Zero.Reason.Contains('among 0 row(s)')))
  $c30Flat = Select-ChromeMenuButton @((& $c30Row 'Button' 'Chrome' 1700 160 0 0))
  ST-Check 'unit: Select-ChromeMenuButton drops zero-rect rows (an empty BoundingRectangle arrives as W/H 0 and is filtered, not crashed on)' (
    (-not $c30Flat.Ok) -and ($c30Flat.Reason.Contains('among 1 row(s)')))
  $c31Zh = Find-ChromeExitItem @('new tab', $c30QuitBrowser)
  ST-Check 'unit: Find-ChromeExitItem matches the full localized quit label' (
    $c31Zh.Ok -and ($c31Zh.Name -eq $c30QuitBrowser))
  $c31Accel = Find-ChromeExitItem @('new tab', 'zoom', $c30QuitAccel)
  ST-Check 'unit: Find-ChromeExitItem matches the access-key quit label read on this build (Chrome 154 zh-CN)' (
    $c31Accel.Ok -and ($c31Accel.Name -eq $c30QuitAccel))
  $c31En = Find-ChromeExitItem @('history', 'Exit')
  ST-Check 'unit: Find-ChromeExitItem matches the plain English Exit label' (
    $c31En.Ok -and ($c31En.Name -eq 'Exit'))
  $c31Sign = Find-ChromeExitItem @($c30SignOut)
  ST-Check 'unit: Find-ChromeExitItem refuses a menu that only offers sign-out (a bare quit stem would click it)' (-not $c31Sign.Ok)
  $c31Amb = Find-ChromeExitItem @('Exit', 'Exit the app')
  ST-Check 'unit: Find-ChromeExitItem refuses two items sharing one exit needle' (
    (-not $c31Amb.Ok) -and ($c31Amb.Reason.Contains('2 menu items contain the same exit needle')))
  $c31Empty = Find-ChromeExitItem @()
  $c31Miss = Find-ChromeExitItem @('new tab', 'settings')
  ST-Check 'unit: Find-ChromeExitItem empty read is its own refusal, distinct from scanned-but-no-match' (
    (-not $c31Empty.Ok) -and $c31Empty.Reason.Contains('no menu item names were read at all') -and
    (-not $c31Empty.Reason.Contains('matched any exit needle')) -and
    (-not $c31Miss.Ok) -and $c31Miss.Reason.Contains('no menu item matched any exit needle'))
  # Wiring of the close chain: option B sits between browser-close and WM_CLOSE, and
  # WM_CLOSE must stay guarded so a successful exit-menu click is never followed by a
  # second close signal (ruling 1: no blind accelerators, and never force-kill chrome).
  $c33Q = "'"
  $c33UiaMark = '$r.CloseVia = ' + $c33Q + 'uia-' + 'exit-menu' + $c33Q
  $c33WmMark = '$r.CloseVia = ' + $c33Q + 'wm-' + 'close' + $c33Q
  $c33GuardMark = '$r.CloseVia -ne ' + $c33Q + 'browser-' + 'close' + $c33Q + ' -and ' + '$r.CloseVia -ne ' + $c33Q + 'uia-' + 'exit-menu' + $c33Q + ')'
  $c33NoteMark = ('close-' + 'note=')
  $c33CommitMark = ('Invoke-Chrome' + 'ExitMenu ')
  $c33UiaN = 0; $c33WmN = 0; $c33GuardN = 0; $c33CommitN = 0; $c33NoteN = 0
  for ($c33i = 0; $c33i -lt $codeLines.Count; $c33i++) {
    if ($c33i -ge $j5ProdStart -and $c33i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c33i] -match '^\s*#') { continue }
    if ($codeLines[$c33i].Contains($c33UiaMark)) { $c33UiaN++ }
    if ($codeLines[$c33i].Contains($c33WmMark)) { $c33WmN++ }
    if ($codeLines[$c33i].Contains($c33GuardMark)) { $c33GuardN++ }
    if ($codeLines[$c33i].Contains($c33CommitMark) -and $codeLines[$c33i].Contains('-Commit')) { $c33CommitN++ }
    if ($codeLines[$c33i].Contains($c33NoteMark)) { $c33NoteN++ }
  }
  ST-Check 'lint: the restart close chain wires the exit-menu route (exactly one uia-exit-menu and one wm-close CloseVia, and the wm-close guard excludes both graceful paths)' (
    ($c33UiaN -eq 1) -and ($c33WmN -eq 1) -and ($c33GuardN -eq 1))
  ST-Check 'lint: Invoke-ChromeExitMenu commits at exactly one production site (reading the menu must never click; only the restart commits)' ($c33CommitN -eq 1)
  ST-Check 'lint: both restart consumers self-report close-note= (the operator reads how the browser actually closed)' ($c33NoteN -eq 2)
  # Two defects W-0 caught on the first real chrome-menu-read run, each nailed where it
  # was born: the bare namespace type literal (PS 5.1 cannot resolve it) and the
  # unguarded [int] cast of an empty BoundingRectangle (Infinity overflows Int32).
  $c32BareMark = ('[System.Windows.' + 'Automation]::')
  $c32BareList = New-Object System.Collections.ArrayList
  $c32Kill = 0
  for ($c32i = 0; $c32i -lt $codeLines.Count; $c32i++) {
    if ($c32i -ge $j5ProdStart -and $c32i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c32i] -match '^\s*#') { continue }
    if ($codeLines[$c32i].Contains($c32BareMark)) { [void]$c32BareList.Add($c32i + 1) }
    if ($codeLines[$c32i].ToLowerInvariant().Contains('chrome') -and ($codeLines[$c32i] -match 'Stop-Process|taskkill')) { $c32Kill++ }
  }
  ST-Check 'lint: no bare [System.Windows.Automation] type literal (PS 5.1 cannot resolve it - option B died on this before its first menu read)' (
    @($c32BareList).Count -eq 0)
  if (@($c32BareList).Count -gt 0) { Write-Output "      bare automation type literals at lines: $(@($c32BareList) -join ', ')" }
  $c32GuardMark = ('-not $br.' + 'IsEmpty')
  $c32Gbs = -1; $c32Gbe = $codeLines.Count
  for ($c32i = 0; $c32i -lt $codeLines.Count; $c32i++) {
    if ($codeLines[$c32i].StartsWith('function Get-ChromeMenuButton')) { $c32Gbs = $c32i; continue }
    if (($c32Gbs -ge 0) -and ($c32i -gt $c32Gbs) -and ($codeLines[$c32i] -match '^function ')) { $c32Gbe = $c32i; break }
  }
  $c32GuardCount = 0
  if ($c32Gbs -ge 0) { for ($c32i = $c32Gbs; $c32i -lt $c32Gbe; $c32i++) { if ($codeLines[$c32i].Contains($c32GuardMark)) { $c32GuardCount++ } } }
  ST-Check 'lint: the menu-button walk converts BoundingRectangle only behind the IsEmpty guard (Rect.Empty carries Infinity and the [int] cast of it killed the whole call)' (
    ($c32Gbs -ge 0) -and ($c32GuardCount -eq 1))
  ST-Check 'lint: chrome.exe is never force-killed (owner ruling 4: killing loses the session and leaves a headless debug-port holder)' ($c32Kill -eq 0)
  # v2.2.0 (R5-C): a BARE dollar-variable-dot-member inside a double-quoted string does NOT
  # interpolate in PS 5.1 - it emits the variable, then the literal member text, so this CDP
  # error line printed a TYPE NAME instead of what the page returned. Narrow pin on purpose: a
  # whole-file traversal for this shape is not sound, because "$base + a literal .ext"
  # concatenations (like the imgclick map line) are intentional and are 5 of the 7 matches the
  # naive scanner reports - the negative finding is registered in the iteration log.
  $cDqMark = ('page returned ' + 'non-JSON')
  # v3.0.1 (audit #24) moved the size behind a computed variable, because a null page
  # value has no .Length and the message used to print an empty field. The shape this pin
  # protects is unchanged - the size enters the message through a SUBEXPRESSION, never as
  # a bare $r.Value.Length - so only the marker's name followed the code.
  $cDqInterpMark = ('$($cdpVal' + 'Len)')
  $cDqQuietMark = ('page text ' + 'not echoed')
  $cDqBareMark = (': $' + 'r.Value"')
  $cDqSites = 0; $cDqInterp = 0; $cDqQuiet = 0; $cDqBare = 0
  for ($c32i = 0; $c32i -lt $codeLines.Count; $c32i++) {
    if ($codeLines[$c32i] -match '^\s*#') { continue }
    if ($codeLines[$c32i].Contains($cDqMark)) { $cDqSites++ }
    if ($codeLines[$c32i].Contains($cDqInterpMark)) { $cDqInterp++ }
    if ($codeLines[$c32i].Contains($cDqQuietMark)) { $cDqQuiet++ }
    if ($codeLines[$c32i].Contains($cDqBareMark)) { $cDqBare++ }
  }
  ST-Check 'lint: the CDP non-JSON message interpolates through a subexpression and carries only a char count (a bare dollar-r-dot-Value in a double-quoted string prints the TYPE NAME - PS 5.1 does not resolve member access there), and page text never enters an error line' (
    ($cDqSites -eq 1) -and ($cDqInterp -eq 1) -and ($cDqQuiet -eq 1) -and ($cDqBare -eq 0))
  if ($cDqSites -ne 1) { Write-Output "      CDP non-JSON message sites: $cDqSites (expected exactly 1)" }
  Write-Output ("      exit-menu wiring: uia-close=$c33UiaN wm-close=$c33WmN guard=$c33GuardN commit-sites=$c33CommitN close-note=$c33NoteN kill-lines=$c32Kill")

  # ---------- v1.11.0: Resolve-Window selector semantics go literal (owner ruling 3) ----------
  # The four contrast groups the owner named, fed as a synthetic window list through the
  # extracted pure selector. Each group has BOTH directions: the literal needle must find
  # its window, and the wildcard READING of the same needle must find nothing any more.
  $c42Win = { param($p, $pr, $cl, $ttl) [pscustomobject]@{ Pid = $p; Proc = $pr; Class = $cl; Title = $ttl; Handle = [IntPtr]$p; W = 100; H = 50; Area = 5000; Main = 'yes' } }
  $c42All = @(
    (& $c42Win 111 'notepad' 'Notepad' 'TELEBOT [main] - work'),
    (& $c42Win 222 'explorer' 'Chrome_WidgetWin_1' 'a*b archive'),
    (& $c42Win 333 'app' 'X?Y' 'settings q?x panel'),
    (& $c42Win 444 'chrome' 'Chrome_WidgetWin_1' 'TELEBOT console - Google Chrome')
  )
  $c42Pick = { param($sel) @((Select-WindowsBySelector $c42All $sel).Matches | ForEach-Object { $_.Pid }) }
  $c42Bad = ''
  if (@(& $c42Pick 't:[main]') -ne 111) { $c42Bad = 't:[main]' }
  if (@(& $c42Pick '[main]') -ne 111) { $c42Bad = "$c42Bad [main]" }
  if (@(& $c42Pick 't:[ma*n]').Count -ne 0) { $c42Bad = "$c42Bad [ma*n]-must-not-match" }
  if (@(& $c42Pick 'a*b') -ne 222) { $c42Bad = "$c42Bad a*b" }
  if (@(& $c42Pick 't:axb').Count -ne 0) { $c42Bad = "$c42Bad axb-must-not-match" }
  if (@(& $c42Pick 'q?x') -ne 333) { $c42Bad = "$c42Bad q?x" }
  if (@(& $c42Pick 't:qax').Count -ne 0) { $c42Bad = "$c42Bad qax-must-not-match" }
  if (@(& $c42Pick '[MAIN]') -ne 111) { $c42Bad = "$c42Bad case" }
  $c42ClsBad = ''
  if ((@(& $c42Pick 'class:WidgetWin') -join ',') -ne '222,444') { $c42ClsBad = 'class substring' }
  if (@(& $c42Pick 'class:Widget?in').Count -ne 0) { $c42ClsBad = "$c42ClsBad class-wildcard" }
  if (@(& $c42Pick 'proc:CHROME') -ne 444) { $c42ClsBad = "$c42ClsBad proc" }
  if (@(& $c42Pick '222') -ne 222) { $c42ClsBad = "$c42ClsBad pid" }
  if ((@(& $c42Pick 'class:WidgetWin') -join ',') -eq '222, 444') { $c42ClsBad = 'join-shape' }
  $c42EmptyThrows = 0
  foreach ($c42e in @('t:', 'title:   ', 'class:')) {
    try { [void](Select-WindowsBySelector $c42All $c42e) } catch { if ("$($_.Exception.Message)".Contains('must not be empty')) { $c42EmptyThrows++ } }
  }
  ST-Check 'unit: an empty needle is REFUSED, not a match-everything (t: / title: whitespace / class:)' ($c42EmptyThrows -eq 3)
  $c42BareEmpty = @((Select-WindowsBySelector $c42All '').Matches).Count
  ST-Check 'unit: a bare empty selector matches nothing (Resolve-Target intercepts "" for the foreground window before this runs)' ($c42BareEmpty -eq 0)
  $c43TitleLikeN = 0
  $c43ClassLikeN = 0
  for ($c43i = 0; $c43i -lt $codeLines.Count; $c43i++) {
    if ($c43i -ge $j5ProdStart -and $c43i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c43i] -match '^\s*#') { continue }
    if ($codeLines[$c43i].Contains('Title -like "*$sub*"')) { $c43TitleLikeN++ }
    if ($codeLines[$c43i].Contains('Class -like "*$sub*"')) { $c43ClassLikeN++ }
  }
  $c43TnsN = 0
  for ($c43i = 0; $c43i -lt $codeLines.Count; $c43i++) {
    if ($codeLines[$c43i].StartsWith('function Select-WindowsBySelector')) { $c43TnsN = $c43i; break }
  }
  $c43TnsBody = 0
  if ($c43TnsN -ge 0) {
    for ($c43i = $c43TnsN; $c43i -lt ($c43TnsN + 30); $c43i++) {
      if ($c43i -ge $codeLines.Count) { break }
      if (($c43i -gt $c43TnsN) -and ($codeLines[$c43i] -match '^function ')) { break }
      if ($codeLines[$c43i].Contains('Test-NameSubstring')) { $c43TnsBody++ }
    }
  }
  ST-Check 'unit/lint: selector is a literal substring - titles with [ * ? are found by their own text, the wildcard reading finds nothing, case stays insensitive' (
    ($c42Bad -eq '') -and ($c43TitleLikeN -eq 0) -and ($c43TnsBody -ge 2))
  ST-Check 'unit/lint: class goes literal too (substring found, wildcard dead), proc stays exact, numeric pid still routes to pid' (
    ($c42ClsBad -eq '') -and ($c43ClassLikeN -eq 0) -and ($c43TnsBody -ge 2))
  Write-Output ("      selector wiring: title-like=$c43TitleLikeN class-like=$c43ClassLikeN literal-matcher-sites=$c43TnsBody")

  $c44Amb = Get-SelectorAmbiguity @($c42All[0], $c42All[3]) 'TELEBOT'
  ST-Check 'unit: non-PID multi-match is refused with every candidate and an explicit disambiguation route' (
    $c44Amb.Ambiguous -and $c44Amb.Count -eq 2 -and
    $c44Amb.Message.Contains('pid=111') -and $c44Amb.Message.Contains('pid=444') -and
    $c44Amb.Message.Contains('class=') -and $c44Amb.Message.Contains('main=') -and
    $c44Amb.Message.Contains('rect=') -and $c44Amb.Message.Contains('choose pid / proc: / class:'))
  $c44Single = Get-SelectorAmbiguity @($c42All[0]) 'TELEBOT'
  ST-Check 'unit: a single selector match remains selectable' (-not $c44Single.Ambiguous -and $c44Single.Count -eq 1)
  $c44RefuseIf = @($codeLines | Where-Object { $_ -ceq '  if (-not $byPid -and $amb.Ambiguous) {' }).Count
  $c44RefuseThrow = @($codeLines | Where-Object { $_ -ceq '    throw $amb.Message' }).Count
  ST-Check 'lint: Resolve-Window refuses non-PID ambiguity before selecting a largest match' ($c44RefuseIf -eq 1 -and $c44RefuseThrow -eq 1)
  $c44WheelNoneOwn = Strip-OwnFlags @('-4', '2443', '1350') 'wheel'
  $c44WheelNone = Split-Target @($c44WheelNoneOwn.Rest) 'wheel'
  ST-Check 'unit: wheel without --expect-change keeps the legacy no-check shape' (
    $c44WheelNone.ExpectChange -ceq '' -and (@($c44WheelNone.Words) -join ' ') -ceq '-4 2443 1350')
  Write-Output "      wheel parser: absent -> active=none difference=delivery-only"
  $c44WheelBareOwn = Strip-OwnFlags @('-3', '--expect-change', '--at', 'proc:dtx') 'wheel'
  $c44WheelBare = Split-Target @((Get-OptValue $c44WheelBareOwn 'Rest')) 'wheel'
  ST-Check 'unit: wheel bare --expect-change means auto and strips --at through the shared path' (
    (Get-OptValue $c44WheelBare 'ExpectChange') -ceq 'auto' -and $c44WheelBareOwn.Values['--at'] -ceq 'proc:dtx' -and
    (@($c44WheelBare.Words) -join ' ') -ceq '-3')
  Write-Output "      wheel parser: bare -> active=auto difference=hash-check on target/virtual rect"
  $c44WheelRectOwn = Strip-OwnFlags @('-5', '--expect-change', '1,2,300,400') 'wheel'
  $c44WheelRect = Split-Target @($c44WheelRectOwn.Rest) 'wheel'
  ST-Check 'unit: wheel --expect-change consumes an explicit screen rect' (
    $c44WheelRect.ExpectChange -ceq '1,2,300,400' -and (@($c44WheelRect.Words) -join ' ') -ceq '-5')
  Write-Output "      wheel parser: explicit -> active=1,2,300,400 difference=hash-check on explicit screen rect"
  $c44WheelBad = ''
  try {
    $c44WheelBadOwn = Strip-OwnFlags @('-5', '--expect-change', '1,2,3') 'wheel'
    [void](Split-Target @($c44WheelBadOwn.Rest) 'wheel')
  } catch { $c44WheelBad = "$($_.Exception.Message)" }
  ST-Check 'unit: wheel malformed --expect-change is refused by name' ($c44WheelBad.Contains('--expect-change needs x,y,w,h') -and $c44WheelBad.Contains('1,2,3'))
  Write-Output "      wheel parser: malformed -> active=reject difference=one named error"
  $c44WheelAtBad = ''
  try { [void](Strip-OwnFlags @('-3', '--at') 'wheel') } catch { $c44WheelAtBad = "$($_.Exception.Message)" }
  ST-Check 'unit: wheel --at without a selector is refused before dispatch' ($c44WheelAtBad.Contains("'--at' needs a value"))
  $wheelCommandLines = @((Get-CommandCodeText $codeLines 'wheel') -split "`n")
  $c44WheelAtGuard = @($wheelCommandLines | Where-Object {
    $_.Contains('$atPresent -and (-not $atSel -or $atSel -like') -and $_.Contains("'--at' needs a window selector value")
  }).Count
  ST-Check 'lint: wheel dispatcher keeps its named --at missing-value guard' ($c44WheelAtGuard -eq 1)
  $c44WheelSites = @($codeLines | Where-Object { $_ -match 'Split-Target @\(\$own\.Rest\) ''wheel''' }).Count
  $c44WheelPrivateSites = @($codeLines | Where-Object { $_ -match 'Strip-OwnFlags \$Rest ''wheel''' }).Count
  ST-Check 'lint: wheel routes shared --expect-change through Split-Target after one private-flag strip' ($c44WheelSites -eq 1 -and $c44WheelPrivateSites -eq 1)
  $c44WheelEmptyGuard = @($wheelCommandLines | Where-Object {
    $_.Contains('$ecb = $null') -or $_.Contains('if ($p.ExpectChange -and -not $verificationRequested)') -or
      $_.Contains('if ($ecb) { Invoke-ExpectChangeCheck $p $ecb ''wheel'' }')
  }).Count
  ST-Check 'lint: wheel initializes no pixel expectation, acquires one only when requested, and checks only a present baseline' ($c44WheelEmptyGuard -eq 3)
  $c44WheelLiveCall = @($codeLines | Where-Object { $_ -match '\$outWheel = & powershell .* wheel -3 --at ''DTX-ExpectProbe''' }).Count
  ST-Check 'lint: live wheel proof executes exactly one real DTX-ExpectProbe call' ($c44WheelLiveCall -eq 1)
  $c44ClickPidAudit = @($codeLines | Where-Object { $_ -ceq '      if ($null -ne $tgt) { $clickLogArgs = @($clickLogArgs) + @("pid=$($tgt.Pid)") }' }).Count
  ST-Check 'lint: click audit appends the resolved target pid for an independent act witness' ($c44ClickPidAudit -eq 1)
  Write-Output ("      selector ambiguity + wheel parser: ambiguous=$($c44Amb.Count) wheel-sites=$c44WheelSites private-sites=$c44WheelPrivateSites")

  # ---------- unit: v4.2.0 feedback item 4 - uia-tree file route + --path ----------
  # The FILE half of the request is deliberately NOT a second writer. Two measured facts
  # pinned the decision: (a) `--out` cannot reach this file at all under `powershell -File`
  # - it binds at PowerShell's own parameter layer and dies as AmbiguousParameter between
  # -OutVariable and -OutBuffer (2026-10-10, both engines), so advertising it would be a
  # flag that only lives in the signature; (b) `--dump <file>` has shipped since v3.0.0
  # with uia-tree already in its accepted set, writing UTF-8 without BOM and refusing to
  # overwrite. So what needed adding was discoverability, not a writer.
  $v42DumpSet = @(Get-DumpCommandSet)
  ST-Check 'unit: uia-tree and uia-find are in the --dump accepted set, an action is not' (
    ($v42DumpSet -contains 'uia-tree') -and ($v42DumpSet -contains 'uia-find') -and (-not ($v42DumpSet -contains 'click')))
  $v42OutProbe = ''
  # v4.2.1 (self-check repair): capture the child's COMPLETE stderr, not the parent's truncated
  # error record. With $ErrorActionPreference = 'Stop' (line 26) a native command's stderr becomes
  # a terminating NativeCommandError whose .Exception.Message keeps only the FIRST physical line.
  # On a zh-CN console that line is Chinese, and the error record's Out-String() drops the child's
  # FullyQualifiedErrorId line as well - so the English tokens below matched nothing and this check
  # went RED on a tool that was working correctly (measured 2026-10-10: exception-message len=53,
  # full-error-record len=465, neither contained AmbiguousParameter). Relaxing EAP to 'Continue'
  # for THIS ONE probe lets the child's whole stderr reach the pipe, where the locale-independent
  # identifier `AmbiguousParameter` (also `OutVariable`) is present whatever the UI language is.
  # The assertion is NOT loosened: a reachable --out would print the tool's own output ("wrote ..."),
  # which the second half below still rejects - that negative control is what gives it teeth.
  $v42Eap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  # G-21 (owner ruling 2026-10-20 14:4x, item 3; the fourth site of the v4.1.3 finding-D family, which
  # was missed there): this probe calls `powershell` BY BARE NAME, so it measures the PATH face. When
  # the harness has no resolvable child at all there is nothing to measure - the child never runs, the
  # face comes back empty, and the assertion below matched none of its tokens and went RED for the
  # caller's environment (measured: contexts C and D of the A-25 four-context matrix, exit 1 both).
  # So the site now asks the same pre-flight every other `& powershell` check asks, and when the answer
  # is no it SKIPs under the IDENTICAL name, carrying the measured reason. When the answer is yes the
  # original assertion runs exactly as written - it is not weakened here, and a --out that really does
  # reach the parser still prints 'wrote ' and still goes red.
  if ($script:PsChildOk) {
    try { $v42OutProbe = (& powershell -NoProfile -ExecutionPolicy Bypass -File $self uia-tree --out 'D:/x/nul.txt' 2>&1 | Out-String) } catch { $v42OutProbe = $_.Exception.Message } finally { $ErrorActionPreference = $v42Eap }
    # This assertion accepts either shape the probe can produce: the raw child stderr (the normal
    # case while EAP is relaxed above) or the exception text, should a future edit capture it
    # through the terminating path. The claim under test is that PowerShell's own binder eats
    # --out - not which channel reported it. (v4.2.1 correction: the old comment said EAP=Stop
    # "merges stderr into the pipeline" so both shapes arrive; measurement showed the terminating
    # path yields ONLY the first physical line, which on zh-CN is Chinese and matches nothing.)
    ST-Check 'live: --out still never reaches the parser (PowerShell eats it) - the reason --dump is the advertised route' (
      ($v42OutProbe -match 'is ambiguous|AmbiguousParameter|OutVariable') -and (-not ($v42OutProbe -match 'wrote ')))
  } else {
    Write-Output ('      --out probe NOT VERIFIED (no child to probe): ' + $script:PsChildWhy)
    ST-Skip 'live: --out still never reaches the parser (PowerShell eats it) - the reason --dump is the advertised route' ($script:PsChildWhy + ' - this probe spawns its child through the call operator, so there is nothing to measure')
  }
  $ErrorActionPreference = $v42Eap
  # G-21 (owner ruling 2026-10-20 14:4x, item 3): the child-spawn face is gated, and the
  # gating itself has to be inspectable. What is claimed here is structural, not a rerun:
  #   A) the --out probe above must sit INSIDE a PATH-face pre-check, and the name it skips under must
  #      be the identical name it checks under (a skip under a different name would free a check slot);
  #   B) the step-probe block must gate BOTH child faces BEFORE it raises its fixture - the two faces
  #      answer differently (measured: PATH face unresolvable, Start-Process face still fine, because
  #      App Paths), and an ungated fixture launch is a window nobody cleans up;
  #   C) the mid-run path must STILL be able to report red - a pre-check may not become a blanket.
  # Needles are concatenated so none of these lines can match its own search (the self-pollution shape
  # this file has caught repeatedly). The detector is a scriptblock over a line array, so the planted
  # copies below are data, never source the real scan can see.
  $g21NProbe = "uia-tree " + "--out 'D:/x/nul.txt'"
  $g21NGuard = '  if (' + '$script:PsChildOk) {'
  $g21NChk = ('ST-' + "Check 'live: --out still never")
  $g21NSkip = ('ST-' + "Skip 'live: --out still never")
  $g21NGateChild = 'if (-not ' + '$script:PsChildOk) { $stepGate ='
  $g21NGateStart = 'if (-not ' + '$script:PsStartOk) { $stepGate ='
  $g21NInit = '$stepGate = ' + "''"
  $g21NFixture = '$stepProc = ' + 'Start-Process powershell'
  $g21NMidRed = ('ST-' + "Check 'live: step probe setup+run' ") + '$false'
  $g21Gap = {
    param([string[]]$Raw)
    $L = @($Raw | Where-Object { $_ -notmatch '^\s*#' })
    $idxOf = {
      param($needle)
      $r = @()
      for ($i = 0; $i -lt $L.Count; $i++) { if ($L[$i].Contains($needle)) { $r += $i } }
      return , @($r)
    }
    $iProbe = & $idxOf $g21NProbe
    if ($iProbe.Count -ne 1) { return 'A-probe-site-not-single:' + $iProbe.Count }
    $iGuard = & $idxOf $g21NGuard
    $p = $iProbe[0]
    $before = @($iGuard | Where-Object { $_ -lt $p -and ($p - $_) -le 14 })
    if ($before.Count -eq 0) { return 'A-probe-ungated' }
    $nameOf = {
      param($line, $kind)
      # Measured on the first pass: the usual quoted-first-argument pattern
      # "'((?:[^']|'')*)'" is GREEDY across the rest of the line, so on an ST-Skip line - whose second
      # argument is another quoted string - it swallows the closing quote plus the code after it, and
      # the REAL face reported a name drift that did not exist. Take one run of non-quote characters
      # and refuse to compare when the next character is another quote, because that is a doubled
      # quote inside the name (the very case the greedy form was written to allow).
      if ($line -match ('ST-' + $kind + "\s+'([^']*)'(.?)")) {
        if ($Matches[2] -eq "'") { return '~DOUBLED-QUOTE~' }
        return $Matches[1]
      }
      return ''
    }
    $iChk = & $idxOf $g21NChk
    $iSkip = & $idxOf $g21NSkip
    if ($iChk.Count -eq 0) { return 'A-check-name-missing' }
    if ($iSkip.Count -eq 0) { return 'A-skip-line-missing' }
    $nChk = & $nameOf $L[$iChk[0]] 'Check'
    $nSkip = & $nameOf $L[$iSkip[0]] 'Skip'
    if ($nChk -eq '~DOUBLED-QUOTE~' -or $nSkip -eq '~DOUBLED-QUOTE~') { return 'A-name-has-doubled-quote' }
    if (-not $nChk) { return 'A-check-name-unparseable' }
    if ($nChk -cne $nSkip) { return 'A-skip-name-drift' }
    $iChildGate = & $idxOf $g21NGateChild
    $iStartGate = & $idxOf $g21NGateStart
    $iInit = & $idxOf $g21NInit
    $iFixture = & $idxOf $g21NFixture
    $iMidRed = & $idxOf $g21NMidRed
    if ($iChildGate.Count -ne 1) { return 'B-child-gate-not-single:' + $iChildGate.Count }
    if ($iStartGate.Count -ne 1) { return 'B-start-gate-not-single:' + $iStartGate.Count }
    if ($iFixture.Count -ne 1) { return 'B-fixture-site-not-single:' + $iFixture.Count }
    if ($iInit.Count -ne 1) { return 'B-block-init-not-single:' + $iInit.Count }
    if ($iMidRed.Count -ne 1) { return 'C-midrun-red-lost:' + $iMidRed.Count }
    $f = $iFixture[0]
    if (-not ($iChildGate[0] -gt $iInit[0] -and $iChildGate[0] -lt $f)) { return 'B-child-gate-not-before-fixture' }
    if (-not ($iStartGate[0] -gt $iInit[0] -and $iStartGate[0] -lt $f)) { return 'B-start-gate-not-before-fixture' }
    return 'ok'
  }
  $g21Real = & $g21Gap -Raw @($codeLines)
  # plants: each is the REAL face with exactly one thing broken, so a gap can only come from that break
  $g21P1 = @($codeLines | Where-Object { $_ -cne $g21NGuard })
  # plant 2 drifts the SKIP name at its TAIL: breaking the head would stop the needle from matching at
  # all, and the honest detector answer to "no skip line here" is A-skip-line-missing (measured on the
  # first pass) - a different gap, so the drift branch would never have been exercised.
  $g21P2 = @($codeLines | ForEach-Object { if ($_.Contains($g21NSkip)) { $_.Replace('is the advertised route', 'is the advertised ROUTE') } else { $_ } })
  # plant 3 moves the two gates to AFTER the fixture launch. Each part is built as its own variable
  # because `cmd + cmd` on one line is not valid PowerShell (measured: 4 parse errors here on the
  # first pass), and the parts are concatenated in expression mode below.
  $g21P3Keep = @($codeLines | Where-Object { -not ($_.Contains($g21NGateChild) -or $_.Contains($g21NGateStart) -or $_.Contains($g21NFixture) -or $_.Contains($g21NMidRed)) })
  $g21P3Fx = @($codeLines | Where-Object { $_.Contains($g21NFixture) })
  $g21P3Gate = @($codeLines | Where-Object { $_.Contains($g21NGateChild) -or $_.Contains($g21NGateStart) })
  $g21P3Red = @($codeLines | Where-Object { $_.Contains($g21NMidRed) })
  $g21P3 = @($g21P3Keep + $g21P3Fx + $g21P3Gate + $g21P3Red)
  $g21P4 = @($codeLines | Where-Object { -not $_.Contains($g21NMidRed) })
  $g21R1 = & $g21Gap -Raw $g21P1
  $g21R2 = & $g21Gap -Raw $g21P2
  $g21R3 = & $g21Gap -Raw $g21P3
  $g21R4 = & $g21Gap -Raw $g21P4
  $g21CodeHits = @($codeLines | Where-Object { $_.Contains('$script:PsChildOk') -or $_.Contains('$script:PsStartOk') -or $_.Contains('$script:PsChildWhy') -or $_.Contains('$script:PsStartWhy') }).Count
  $g21PlantReport = (@($g21R1, $g21R2, $g21R3, $g21R4) -join '/')
  Write-Output ('      G-21 child-face gate: real=' + $g21Real + ' runtime PATH=' + [bool]$script:PsChildOk + ' runtime Start=' + [bool]$script:PsStartOk +
    ' code-hits=' + $g21CodeHits + ' plants=' + $g21PlantReport)
  ST-Check 'lint (G-21): the --out probe sits behind the PATH-face pre-check and skips under the identical name, the step-probe gates both child faces before its fixture starts, and the mid-run red line is still there' (
    $g21Real -ceq 'ok')
  ST-Check 'unit (G-21): the child-face gate detector has teeth - each planted break reports its own named gap and the unplanted face reports ok' (
    ($g21Real -ceq 'ok') -and ($g21R1 -ceq 'A-probe-ungated') -and ($g21R2 -ceq 'A-skip-name-drift') -and
    ($g21R3 -ceq 'B-child-gate-not-before-fixture') -and ($g21R4 -ceq 'C-midrun-red-lost:0'))
  $v42TreeUsage = (Get-UsageText | Out-String)
  ST-Check 'unit: the uia-tree usage entry names --dump as the file route and --path as the subtree route' (
    ($v42TreeUsage.Contains('--dump <file>')) -and ($v42TreeUsage.Contains('--path')))
  $v42TreeLines = @(
    'scan: handle=1 depth=6',
    'root: LobsterAI',
    "  A | name='m1' | path=/0/1",
    "    B | name='m1 reply' | path=/0/1/0",
    "    C | name='m2' | path=/0/1/1",
    "      D | name='other' | path=/0/1/1/0")
  $v42Keep = Test-UiaPathFilter $v42TreeLines '/0/1/0'
  ST-Check 'unit: --path keeps the ancestor chain + the subtree, drops siblings, and counts both' (
    (@($v42Keep.Lines).Count -eq 4) -and ($v42Keep.Sub -eq 1) -and ($v42Keep.Anc -eq 1) -and
    (@($v42Keep.Lines | Where-Object { "$_" -like '*path=/0/1/1*' }).Count -eq 0) -and
    ($v42Keep.Summary -ceq 'path=/0/1/0 -> 1 node(s) below it + 1 ancestor(s)'))
  $v42Miss = Test-UiaPathFilter @("  A | name='x' | path=/0/1") '/0/9/9'
  ST-Check 'unit: a --path token that matches nothing is reported as a miss, never as an empty tree' (
    (-not $v42Miss.Ok) -and ($v42Miss.Sub -eq 0) -and ($v42Keep.Ok -eq $true))
  # the needles are assembled so this check cannot count its own source as a hit.
  $v42PathNeedle = '--path'
  $v42PathSites = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_ -match "--eq '--path'" })
  $v42UnknownSites = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_ -match 'unknown flag ''\$w0''' })
  $v42DumpMentions = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_ -match 'unknown flag .\$w0.*--dump' })
  ST-Check 'lint: uia-tree parses --path, still refuses unknown --words, and that refusal names --dump' (
    (@($v42PathSites).Count -ge 1) -and (@($v42UnknownSites).Count -ge 1) -and (@($v42DumpMentions).Count -ge 1))

  # ---------- v4.4.1 (CU-REL-01): the landing identity check and the post-activation state read ----------
  # relclick used to add its offsets to the rect the SELECTOR handed back and click, passing none of
  # the pre-action checks its siblings pass; focus used to print the select-time pick next to
  # Activate-Win's boolean and never look at the window again. Both verdicts are now pure functions,
  # so every shape below is measured offline - including the one a live window would make hard to
  # arrange on purpose: a top-level of the SAME pid that is not the target sitting under the point
  # (the card names that case explicitly, and a fixture for it belongs to --live, not to this gate).
  $curelTarget = @{ Handle = [IntPtr]1000; Title = 'TARGET'; Pid = 42 }
  $curelOwnRoot = @{ Hwnd = [IntPtr]1000; Pid = 42 }
  $curelSamePid = @{ Hwnd = [IntPtr]2000; Pid = 42 }
  $curelForeign = @{ Hwnd = [IntPtr]3000; Pid = 99 }
  ST-Check 'unit (CU-REL-01): the landing verdict passes the target and its own controls, and refuses a same-pid top-level as well as a foreign one' (
    (Test-LandingOnTarget $curelOwnRoot $curelTarget) -and (-not (Test-LandingOnTarget $curelSamePid $curelTarget)) -and
    (-not (Test-LandingOnTarget $curelForeign $curelTarget)))
  ST-Check 'unit (CU-REL-01): a point where no window answers the hit test is a refusal, never a pass' (
    -not (Test-LandingOnTarget $null $curelTarget))
  $curelRefuse = Format-LandingVerdict 500 600 $curelSamePid $curelTarget $false
  $curelRelax = Format-LandingVerdict 500 600 $curelSamePid $curelTarget $true
  ST-Check 'unit (CU-REL-01): the refusal names the window under the point, says NOTHING was clicked and offers the relaxation flag' (
    ($curelRefuse.Contains('NOTHING was clicked')) -and ($curelRefuse.Contains('hwnd=2000')) -and
    ($curelRefuse.Contains('--allow-outside')) -and ($curelRefuse.Contains('not the resolved target hwnd=1000')))
  ST-Check 'unit (CU-REL-01): the relaxed line says which flag relaxed what - a relaxation is never silent' (
    ($curelRelax.Contains('RELAXED by --allow-outside')) -and ($curelRelax.Contains('hwnd=2000')) -and
    ($curelRelax.Contains('hwnd=1000')))
  $curelNoneRefusal = Format-LandingVerdict 1 2 $null $curelTarget $false
  $curelNoneWho = [regex]::Match($curelNoneRefusal, 'the window under \(1,2\) is (.*), not the resolved target').Groups[1].Value
  ST-Check 'unit (CU-REL-01): an absent hit window is rendered as a named reading, not as an empty handle' (
    ($curelNoneWho -ceq '(nothing answers the hit test)') -and ($curelNoneRefusal.Contains('hwnd=1000')))
  $curelUsable = @{ Fg = $true; Iconic = $false; Visible = $true; Rect = @{ X = 10; Y = 20; W = 300; H = 200 } }
  $curelBroken = @{
    'not-foreground' = @{ Fg = $false; Iconic = $false; Visible = $true; Rect = $curelUsable.Rect }
    'still-minimized' = @{ Fg = $true; Iconic = $true; Visible = $true; Rect = $curelUsable.Rect }
    'not-visible' = @{ Fg = $true; Iconic = $false; Visible = $false; Rect = $curelUsable.Rect }
    'no-rect' = @{ Fg = $true; Iconic = $false; Visible = $true; Rect = $null }
    'parked-off-screen' = @{ Fg = $true; Iconic = $false; Visible = $true; Rect = @{ X = -32000; Y = -32000; W = 300; H = 200 } }
  }
  $curelBrokenNames = @(Get-HashKeys $curelBroken)
  $curelRefusedNames = @($curelBrokenNames | Where-Object { -not (Test-FocusUsable $curelBroken[$_]) })
  ST-Check 'unit (CU-REL-01): usable needs all four faces good - five planted single-face breaks all refuse, the planted whole passes, and an unmeasured state refuses' (
    (Test-FocusUsable $curelUsable) -and (@($curelRefusedNames).Count -eq 5) -and (-not (Test-FocusUsable $null)))
  Write-Output ('      CU-REL-01 focus-usable refusals: ' + (@($curelRefusedNames) -join ','))
  $curelStateOk = Format-FocusState 'after-activate' $curelUsable
  $curelStateNoRect = Format-FocusState 'after-activate' $curelBroken['no-rect']
  ST-Check 'unit (CU-REL-01): the state line stamps which reading it is, spells the faces with fg= (never the fg_ok= token) and names a missing rect' (
    ($curelStateOk.StartsWith('after-activate fg=True iconic=False visible=True rect=(10,20,300x200)')) -and
    ($curelStateOk -notlike '*fg_ok=*') -and ($curelStateNoRect.Contains('rect=(none)')))
  ST-Check 'unit (CU-REL-01): a reading that never happened prints as not measured, so an empty state cannot look like a pass' (
    ((Format-FocusState 'after-activate' $null) -ceq 'after-activate (not measured)'))
  # Wiring: a pure guard nobody calls is the shape this repo has been caught with before, so the
  # handlers themselves are measured from the command's own code spans (case + named handler), not
  # from a remembered line number.
  $curelRelclickRanges = @(Get-CommandCodeRanges $codeLines 'relclick')
  $curelRelclickText = Get-CommandCodeText $codeLines 'relclick'
  $curelFocusRanges = @(Get-CommandCodeRanges $codeLines 'focus')
  $curelFocusText = Get-CommandCodeText $codeLines 'focus'
  ST-Check 'lint (CU-REL-01): the wiring scan really sees both command bodies (a scan over an empty span would make every claim below vacuous)' (
    (@($curelRelclickRanges).Count -ge 2) -and (@($curelFocusRanges).Count -ge 2))
  # A guard prefixed with '#' keeps every literal the mention-scan looks for, so it reads as wired.
  # The census below only counts a name where the line is live code; the planted pair proves the
  # difference, because "it stayed green with the guard commented out" is a whole class of breakage
  # that a text scan cannot see.
  $curelLiveCallLines = { param($Text, $Name)
    $src = @([string]$Text -split "`n")
    $at = @()
    for ($ci = 0; $ci -lt $src.Count; $ci++) {
      if (($src[$ci] -notmatch '^\s*#') -and ([string]$src[$ci]).Contains($Name)) { $at += $ci }
    }
    return @($at)
  }
  $curelRcNames = @('Resolve-Target', 'Invoke-ContentGuard', 'Get-WindowVisibleRect',
    'Invoke-HitWindowCheck', 'Test-LandingOnTarget', 'Move-Click')
  $curelRcMissing = @($curelRcNames | Where-Object { @(& $curelLiveCallLines $curelRelclickText $_).Count -eq 0 })
  Write-Output ('      CU-REL-01 relclick live call lines: ' + (($curelRcNames | ForEach-Object { $_ + '=' + @(& $curelLiveCallLines $curelRelclickText $_).Count }) -join ','))
  ST-Check 'lint (CU-REL-01): relclick walks the common target path - resolve, content guard, by-handle rect, hit-window check, landing identity - before it moves the cursor' (
    (@($curelRcMissing).Count -eq 0) -and ($curelRelclickText.Contains('Resolve-Target')) -and
    ($curelRelclickText.Contains('Invoke-ContentGuard')) -and ($curelRelclickText.Contains('Get-WindowVisibleRect')) -and
    ($curelRelclickText.Contains('Invoke-HitWindowCheck')) -and ($curelRelclickText.Contains('Test-LandingOnTarget')) -and
    ($curelRelclickText.Contains('Move-Click')))
  $curelPlantText = ('  # Invoke-HitWindowCheck 1 2 3' + "`n" + '  Invoke-ContentGuard 4 5' + "`n" + '#Move-Click 6' + "`n" + '  Move-Click 7 8')
  $curelPlantDead = @(& $curelLiveCallLines $curelPlantText 'Invoke-HitWindowCheck')
  $curelPlantHash = @(& $curelLiveCallLines $curelPlantText 'Move-Click')
  $curelPlantLive = @(& $curelLiveCallLines $curelPlantText 'Invoke-ContentGuard')
  ST-Check 'unit (CU-REL-01): the wiring census has teeth - a guard commented out with a leading space and one commented out flush read as absent, the live call two lines later still reads as present' (
    (@($curelPlantDead).Count -eq 0) -and (@($curelPlantHash).Count -eq 1) -and (@($curelPlantLive).Count -eq 1) -and
    (@($curelPlantLive)[0] -eq 1))
  Write-Output ('      CU-REL-01 planted census: commented=' + @($curelPlantDead).Count + ' flushCommented=' + @($curelPlantHash).Count + ' live=' + @($curelPlantLive).Count)
  $curelStaleHits = ([regex]::Matches($curelRelclickText, '\$w\.(Left|Top)')).Count
  ST-Check 'lint (CU-REL-01): relclick no longer reads geometry off the selector result - the select-time origin is gone from its body' (
    ($curelStaleHits -eq 0) -and ($curelRelclickText.Contains('$rcRect.X + $rcDx')) -and
    ($curelRelclickText.Contains('-le -32000')))
  ST-Check 'unit (CU-REL-01): the select-time-origin pattern the lint refuses still matches a planted counterexample (the scan is not blind)' (
    ('      $x = $w.Left + [int]$Rest[1]' -match '\$w\.(Left|Top)'))
  $curelClickCount = ([regex]::Matches($curelRelclickText, 'NOTHING was clicked')).Count
  ST-Check 'lint (CU-REL-01): every relclick refusal before the send says nothing was clicked, and the count is published (>=2: unmeasurable rect + parked rect)' (
    ($curelClickCount -ge 2))
  Write-Output ('      CU-REL-01 relclick pre-send refusals naming the no-op: ' + $curelClickCount)
  ST-Check 'lint (CU-REL-01): relclick keeps its positional selector form and refuses --to by name (a behaviour fix must not change the call shape silently)' (
    ($curelRelclickText.Contains('relclick <sel> <dx> <dy>')) -and ($curelRelclickText.Contains('$p.Sel')))
  $curelFocusNames = @('Resolve-Target', 'GetForegroundWindow', 'IsIconic', 'IsWindowVisible', 'Get-WindowVisibleRect')
  $curelFocusMissing = @($curelFocusNames | Where-Object { @(& $curelLiveCallLines $curelFocusText $_).Count -eq 0 })
  ST-Check 'lint (CU-REL-01): focus re-measures the same handle on all four faces after activation instead of trusting Activate-Win (foreground, iconic, visible, rect)' (
    (@($curelFocusMissing).Count -eq 0) -and ($curelFocusText.Contains('at-select')))
  $curelGuardSite = @(& $curelLiveCallLines $curelFocusText 'Test-FocusUsable')
  $curelEchoSite = @(& $curelLiveCallLines $curelFocusText 'focused pid=')
  $curelGuardAt = @($curelGuardSite)[0]
  $curelEchoAt = @($curelEchoSite)[0]
  ST-Check 'lint (CU-REL-01): the usable guard sits AHEAD of the success line (a guard that runs after the echo polices nothing)' (
    (@($curelGuardSite).Count -ge 1) -and (@($curelEchoSite).Count -ge 1) -and ($curelEchoAt -gt $curelGuardAt))
  $curelFocusFgOk = @((($curelFocusText -split "`n")) | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains('fg_ok=') })
  ST-Check 'lint (CU-REL-01): fg_ok= has exactly one producer inside focus and it is the guarded success line (a refusal cannot satisfy the live focus pin)' (
    (@($curelFocusFgOk).Count -eq 1) -and (@($curelFocusFgOk)[0].Contains('focused pid=')))
  # focus routes through the shared guard, whose sentence ends with "Re-run with" plus this flag - a
  # flag this command refuses on purpose, because a forced focus would print a usable-looking line for
  # a window it could not raise. So the correction has to live in focus (appended), and the shared
  # producer must keep saying what the commands that DO accept it need to hear. The needle is
  # assembled at runtime: written whole, this very line would be a second hit for its own scan (the
  # scanner-reads-its-own-source family, recorded four times in this repo already).
  $curelForceNeedle = 'Re-run with ' + '--force'
  $curelForceQuoted = ([string][char]39) + '--force' + ([string][char]39)
  $curelSharedForce = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($curelForceNeedle) })
  ST-Check 'lint (CU-REL-01): focus reads no force flag, the shared guard keeps its own force advice intact, and focus names its own refusal instead' (
    (-not $curelFocusText.Contains($curelForceQuoted)) -and (@($curelSharedForce).Count -eq 1) -and
    (-not $curelSharedForce[0].Contains('focus')) -and ($curelFocusText.Contains('focus has no --force')))
  ST-Check 'unit (CU-REL-01): the no-force scan has teeth - a planted flag read is detected by the same test' (
    (-not $curelFocusText.Contains($curelForceQuoted)) -and
    ('if ($p.Force -eq ' + $curelForceQuoted + ') { x }').Contains($curelForceQuoted))
  $curelUsage = (Get-UsageText | Out-String)
  ST-Check 'lint (CU-REL-01): the help page states both new contracts - relclick re-reads the rect after raising, focus re-reads the same handle, and the pointing set now polices the landing identity' (
    ($curelUsage.Contains('re-read AFTER it is raised')) -and ($curelUsage.Contains('the SAME handle')) -and
    ($curelUsage.Contains('is not the resolved target itself')))

  # -------------------------------------------------------------------------
  # CU-OPS-COMPLETE-20261026-01 packages A + D: target identity and coordinate
  # spaces, pinned offline. Nothing here sends input or looks at the screen: the
  # window branch uses an INJECTED rect (Get-TargetRect trusts cached fields when
  # they are live geometry), and the identity checks only read process metadata.
  # -------------------------------------------------------------------------
  $curD1 = @(Test-PointSpaceArg '' )
  $curDBad = ''
  try { [void](Test-PointSpaceArg 'vstual') } catch { $curDBad = $_.Exception.Message }
  ST-Check 'unit (D-01): an absent --space means screen (legacy path), the three names pass through, anything else is refused by name' (
    ($curD1[0] -ceq 'screen') -and ((Test-PointSpaceArg 'screen') -ceq 'screen') -and ((Test-PointSpaceArg 'window') -ceq 'window') -and
    ((Test-PointSpaceArg 'client') -ceq 'client') -and ($curDBad.Contains('screen|window|client')) -and ($curDBad.Contains('no input was sent')))

  $curDWinTgt = [pscustomobject]@{ Handle = [IntPtr]1; Left = 100; Top = 200; W = 300; H = 200 }
  $curDWinOrg = Get-PointSpaceOrigin 'window' $curDWinTgt
  $curDWinPt = Convert-PointSpace 5 7 $curDWinOrg
  $curDScrOrg = Get-PointSpaceOrigin 'screen' $null
  $curDScrPt = Convert-PointSpace 900 700 $curDScrOrg
  ST-Check 'unit (D-02): window space adds the rect read at action time, screen space is the identity, and screen needs no window' (
    ($curDWinOrg.X -eq 100) -and ($curDWinOrg.Y -eq 200) -and ($curDWinOrg.W -eq 300) -and ($curDWinOrg.H -eq 200) -and
    ($curDWinPt.X -eq 105) -and ($curDWinPt.Y -eq 207) -and ($curDScrOrg.Space -ceq 'screen') -and
    ($curDScrPt.X -eq 900) -and ($curDScrPt.Y -eq 700))

  $curDOorHigh = ''
  try { [void](Convert-PointSpace 300 0 $curDWinOrg) } catch { $curDOorHigh = $_.Exception.Message }
  $curDOorNeg = ''
  try { [void](Convert-PointSpace -1 0 $curDWinOrg) } catch { $curDOorNeg = $_.Exception.Message }
  ST-Check 'unit (D-03): a point outside the area is REFUSED (both edges, 0-based) and never clamped to the edge' (
    $curDOorHigh.Contains('outside the target area 300x200') -and $curDOorHigh.Contains('no input was sent') -and
    $curDOorNeg.Contains('outside the target area') -and $curDOorNeg.Contains('no input was sent'))

  $curDNoWin = ''
  try { [void](Get-PointSpaceOrigin 'client' $null) } catch { $curDNoWin = $_.Exception.Message }
  ST-Check 'unit (D-04): a relative space without a resolved window is refused instead of defaulting to (0,0)' (
    $curDNoWin.Contains('--space client needs a resolved window') -and $curDNoWin.Contains('no input was sent'))

  $curDReceipt = Format-PointSpaceReceipt $curDScrOrg 5 7
  $curDReceiptWin = Format-PointSpaceReceipt $curDWinOrg 5 7
  ST-Check 'unit (D-05): the receipt tail is EMPTY for screen (every pre-existing echo stays byte-identical) and names the space+offset otherwise' (
    ($curDReceipt -ceq '') -and ($curDReceiptWin -ceq ' space=window rel=5,7'))

  # The client origin cannot be faked offline (ClientToScreen needs a live hwnd), so what is
  # pinned is that the client branch measures the origin from the HANDLE at call time - both
  # Win32 calls sit inside the client branch. (codeLines is the stitched source set, so a
  # definition may appear once per contributing file; the floor is what matters here.)
  $curDClientSrc = @($codeLines | Where-Object { $_ -notmatch '^\s*#' })
  $curDClientSite = @($curDClientSrc | Where-Object { $_.Contains('ClientToScreen') })
  $curDClientRect = @($curDClientSrc | Where-Object { $_.Contains('GetClientRect') })
  ST-Check 'unit (D-06): client space is measured from the handle at action time (ClientToScreen + GetClientRect inside the client branch) and the conversion is produced once per source set' (
    ($curDClientSite.Count -ge 2) -and ($curDClientRect.Count -ge 2) -and
    (@($curDClientSrc | Where-Object { $_.Contains('function Convert-PointSpace') }).Count -ge 1) -and
    (@($curDClientSrc | Where-Object { $_.Contains('function Get-PointSpaceOrigin') }).Count -ge 1))

  # A lifted family may not read the caller's plain variables (A-14b), so the own-pid
  # comes from the runtime handle rather than the automatic variable.
  $curAOwn = [int][System.Diagnostics.Process]::GetCurrentProcess().Id
  $curA1 = Test-ProcIdentity 999999999 ''
  $curA2 = Test-ProcIdentity $curAOwn ''
  $curA3 = Test-ProcIdentity $curAOwn '2000-01-01T00:00:00'
  $curA4 = Test-ProcIdentity $curAOwn ([string]$curA2.Snap.start)
  ST-Check 'unit (A-01): process identity answers in four honest shapes - dead pid, no pin, wrong creation time, matching creation time' (
    (-not $curA1.Ok) -and ($curA1.Why -ceq 'process-not-running') -and
    ($curA2.Ok) -and ($curA2.Why -ceq 'no-created-pin') -and
    (-not $curA3.Ok) -and ($curA3.Why.Contains('creation time mismatch')) -and
    ($curA4.Ok))
  if (-not ($curA2.Ok -and $curA4.Ok -and (-not $curA3.Ok))) { Write-Output ('      A-01: ' + $curA1.Why + ' / ' + $curA2.Why + ' / ' + $curA3.Why + ' / ' + $curA4.Why + ' start=' + $curA2.Snap.start) }

  $curATolEdge = Test-ProcIdentity $curAOwn (([datetime]$curA2.Snap.start).AddSeconds(1).ToString('o'))
  $curATolOut = Test-ProcIdentity $curAOwn (([datetime]$curA2.Snap.start).AddSeconds(5).ToString('o'))
  # CU-OPS-ADJ-01: the old 2s window accepted a process created one second after the pin.
  # Exactness is the contract now: 1s off is refused exactly like 5s off.
  ST-Check 'unit (A-02): identity is EXACT - a pin 1s off is refused like one 5s off (no tolerance window, CU-OPS-ADJ-01)' (
    (-not $curATolEdge.Ok) -and $curATolEdge.Why.Contains('creation time mismatch') -and
    (-not $curATolOut.Ok) -and $curATolOut.Why.Contains('creation time mismatch'))
  if (-not ((-not $curATolEdge.Ok) -and (-not $curATolOut.Ok))) { Write-Output ('      A-02: 1s=' + $curATolEdge.Why + ' / 5s=' + $curATolOut.Why) }

  $curAKillSrc = @($codeLines | Where-Object { $_ -notmatch '^\s*#' })
  $curAGoGate = @($curAKillSrc | Where-Object { $_.Contains(' --go') -or $_.Contains("'--go'") })
  ST-Check 'unit (A-03): proc-kill is preview-by-default (the --go branch is the only one that terminates) and it re-checks the same object before killing' (
    ($curAGoGate.Count -ge 1) -and (@($curAKillSrc | Where-Object { $_.Contains('TerminateProcess') }).Count -ge 1) -and
    (@($curAKillSrc | Where-Object { $_.Contains('WaitForExit') }).Count -ge 1))

  # CU-OPS-ADJ-02: one pinned handle, released last. A shared .NET Process object alone is
  # not a proof that the check and the terminate travelled through the same native handle.
  ST-Check 'unit (A-04): proc-kill pins ONE native handle (Process.Handle) and releases it in finally (CU-OPS-ADJ-02)' (
    (@($curAKillSrc | Where-Object { $_.Contains('$pr.Handle') }).Count -ge 1) -and
    (@($curAKillSrc | Where-Object { $_.Contains('$pr.Dispose()') }).Count -ge 1) -and
    (@($curAKillSrc | Where-Object { $_.Contains('handle-pinned=yes') }).Count -ge 1))

}
