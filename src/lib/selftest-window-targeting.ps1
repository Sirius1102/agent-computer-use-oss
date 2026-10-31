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
  # CU-EXTERNAL-EXPERIENCE-20261028 B5: imgclick really runs --expect-change.
  # The shared flag table has admitted --expect-change on imgclick for as long as the table
  # has existed, but the handler only ran the TEXT expectation - the external review measured
  # a delivered click with zero pixel sampling. The handler is exercised here with dynamically
  # installed stubs (a Set-Item seam, not the ${function:...} table A-07 registers), and the
  # capture count is what proves the shapes: requested+changed, requested+same, not requested,
  # and --dry (which must sample nothing at all).
  $script:b5Captures = 0
  $script:b5Moves = 0
  $script:b5Seq = @()
  $script:a1StaleVerdict = 'ok'
  $script:a1MapHwnd = [IntPtr]::Zero
  $script:a1TgtHwnd = [IntPtr]::Zero
  $b5Names = @('Resolve-Target', 'Emit-ResolveNote', 'Invoke-HitWindowCheck', ('Log-' + 'Action'), 'Move-Click', 'Invoke-ActionExpectation', 'Read-MapSidecar', 'Test-MapSidecarStale', 'Convert-ImageToScreen', 'Get-RegionHash')
  $b5Orig = @{}
  foreach ($b5n in $b5Names) { $b5Orig[$b5n] = (Get-Item ("function:" + $b5n)).ScriptBlock }
  try {
    Set-Item -Path 'function:Resolve-Target' -Value { param($sel, $force, $always, $eh, $created) return [pscustomobject]@{ Pid = 41998; Title = 'b5-fake'; Handle = $script:a1TgtHwnd; Left = 0; Top = 0; W = 100; H = 100 } }
    Set-Item -Path 'function:Emit-ResolveNote' -Value { }
    Set-Item -Path 'function:Invoke-HitWindowCheck' -Value { param($x, $y, $tgt, $enforce, $allow) }
    Set-Item -Path ('function:' + $b5Names[3]) -Value { param($la, $detail, $cn) }
    Set-Item -Path 'function:Move-Click' -Value { param($x, $y, $b) $script:b5Moves++ }
    Set-Item -Path 'function:Invoke-ActionExpectation' -Value { param($pp, $tt, $what) }
    # GridStyle rides along since B-3: the handler reads it off every map it holds, and a mock
    # that omits a field the real reader always returns dies under StrictMode before the
    # assertion itself can speak. Grid=0 keeps the proximity math short-circuited.
    Set-Item -Path 'function:Read-MapSidecar' -Value { param($img) return [pscustomobject]@{ OutW = 100; OutH = 100; Kind = 'win'; Scale = 1; OriginX = 10; OriginY = 20; Grid = 0; GridStyle = 'unknown'; HostHwnd = $script:a1MapHwnd; HostTitle = 'b5-fake' } }
    Set-Item -Path 'function:Test-MapSidecarStale' -Value { param($map) return @{ Verdict = $script:a1StaleVerdict; Msg = ('stub verdict: ' + $script:a1StaleVerdict) } }
    Set-Item -Path 'function:Convert-ImageToScreen' -Value { param($map, $ix, $iy) return [pscustomobject]@{ X = 15; Y = 26 } }
    Set-Item -Path 'function:Get-RegionHash' -Value { param($x, $y, $w, $h) $script:b5Captures++; $v = [string]$script:b5Seq[0]; if (@($script:b5Seq).Count -gt 1) { $script:b5Seq = @($script:b5Seq | Select-Object -Skip 1) }; return $v }
    $script:b5Seq = @('b5hash-a', 'b5hash-b'); $script:b5Captures = 0; $script:b5Moves = 0
    $b5Changed = @(Invoke-DesktopCommand 'imgclick' @('b5.png', '10', '20', '--to', 'b5-fake', '--expect-change', '1,2,3,4')) -join "`n"
    ST-Check 'unit (B5): imgclick --expect-change samples before and after a real click and reports the change' (
      ($script:b5Captures -eq 2) -and ($script:b5Moves -eq 1) -and ($b5Changed.Contains('clicked 15,26')) -and ($b5Changed -match 'expect-change:.*changed'))
    $script:b5Seq = @('b5hash-c', 'b5hash-c'); $script:b5Captures = 0; $script:b5Moves = 0
    $b5Same = @(Invoke-DesktopCommand 'imgclick' @('b5.png', '10', '20', '--to', 'b5-fake', '--expect-change', '1,2,3,4')) -join "`n"
    ST-Check 'unit (B5): a pixel-identical region warns and names the rect it measured (no silent success)' (
      ($script:b5Captures -eq 2) -and ($script:b5Moves -eq 1) -and ($b5Same -match 'WARN: --expect-change:.*PIXEL-IDENTICAL'))
    $script:b5Captures = 0; $script:b5Moves = 0
    [void](Invoke-DesktopCommand 'imgclick' @('b5.png', '10', '20', '--to', 'b5-fake'))
    ST-Check 'unit (B5): without --expect-change imgclick reads no pixels and still clicks once' (
      ($script:b5Captures -eq 0) -and ($script:b5Moves -eq 1))
    $script:b5Captures = 0; $script:b5Moves = 0
    [void](Invoke-DesktopCommand 'imgclick' @('b5.png', '10', '20', '--to', 'b5-fake', '--expect-change', '1,2,3,4', '--dry'))
    ST-Check 'unit (B5): --dry with --expect-change neither clicks nor samples pixels' (
      ($script:b5Captures -eq 0) -and ($script:b5Moves -eq 0))
    # CU-EXTERNAL-EXPERIENCE-20261028 A1: the strict verification contract. The external
    # review measured an unbound crop being clicked anyway; --require-verified is the flag
    # that turns every non-ok verdict into a refusal BEFORE any input, while callers that
    # do not ask for it keep the OLD note-and-click behaviour (an explicit legacy contract,
    # not a silent change). The target-identity case is the second lie: a point mapped from
    # window A must not be clicked on window B.
    $script:a1StaleVerdict = 'unverifiable'; $script:b5Captures = 0; $script:b5Moves = 0
    $a1UnvErr = ''
    try { [void](Invoke-DesktopCommand 'imgclick' @('b5.png', '10', '20', '--to', 'b5-fake', '--require-verified')) } catch { $a1UnvErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1): imgclick --require-verified refuses an unverifiable (unbound) crop before any input' (
      $a1UnvErr.Contains('--require-verified') -and $a1UnvErr.Contains('unverifiable') -and ($script:b5Moves -eq 0) -and ($script:b5Captures -eq 0))
    $script:b5Moves = 0
    [void](Invoke-DesktopCommand 'imgclick' @('b5.png', '10', '20', '--to', 'b5-fake'))
    ST-Check 'unit (A1): without the strict flag the OLD unverified contract still clicks (compatibility kept)' (
      $script:b5Moves -eq 1)
    $a1MixErr = ''
    try { [void](Invoke-DesktopCommand 'imgclick' @('b5.png', '10', '20', '--to', 'b5-fake', '--require-verified', '--stale-ok')) } catch { $a1MixErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1): --require-verified together with --stale-ok is refused as contradictory' (
      $a1MixErr.Contains('contradict') -and ($script:b5Moves -eq 1))
    $script:a1StaleVerdict = 'ok'; $script:b5Moves = 0
    [void](Invoke-DesktopCommand 'imgclick' @('b5.png', '10', '20', '--to', 'b5-fake', '--require-verified'))
    ST-Check 'unit (A1): --require-verified with a verified (ok) mapping clicks exactly once' (
      $script:b5Moves -eq 1)
    $script:a1MapHwnd = [IntPtr]::new(55); $script:a1TgtHwnd = [IntPtr]::new(66); $script:b5Moves = 0
    $a1IdErr = ''
    try { [void](Invoke-DesktopCommand 'imgclick' @('b5.png', '10', '20', '--to', 'b5-fake', '--require-verified')) } catch { $a1IdErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1): --require-verified refuses a --to that resolves to a DIFFERENT window than the captured host' (
      $a1IdErr.Contains('another window') -and ($script:b5Moves -eq 0))
    $script:a1MapHwnd = [IntPtr]::Zero; $script:a1TgtHwnd = [IntPtr]::Zero
  } finally {
    foreach ($b5n in $b5Names) { Set-Item -Path ("function:" + $b5n) -Value $b5Orig[$b5n] }
  }
  # CU-EXTERNAL-EXPERIENCE-20261028 A1: the geometry verdict is pure, so the shape that
  # used to lie - a MINIMIZED window whose rect did not change, which rectangular equality
  # alone read as 'ok' - is pinned without a live window. A bound crop must also persist
  # its host rect: half a binding (identity without geometry) is refused at read time.
  $a1Cur = @{ X = 100; Y = 200; W = 300; H = 400 }
  $a1Min = Get-SidecarRectVerdict 'a1' 100 200 300 400 $a1Cur $true
  $a1Same = Get-SidecarRectVerdict 'a1' 100 200 300 400 $a1Cur $false
  $a1Move = Get-SidecarRectVerdict 'a1' 100 200 300 400 @{ X = 103; Y = 200; W = 300; H = 400 } $false
  ST-Check 'unit (A1): a minimized host is STALE even when its rect is unchanged; a 3px move is stale; equality is ok' (
    $a1Min.Verdict -eq 'stale' -and $a1Min.Msg.Contains('minimized') -and $a1Same.Verdict -eq 'ok' -and $a1Move.Verdict -eq 'stale')
  $a1Unbound = @{ Kind = 'rect'; OriginX = 10; OriginY = 20; Scale = 1; OutW = 100; OutH = 100; HostPid = 0; HostHwnd = [IntPtr]::Zero; HostTitle = ''; HostX = $null; HostY = $null; HostW = $null; HostH = $null }
  ST-Check 'unit (A1): an unbound rect sidecar stays unverifiable, never a false ok' (
    (Test-MapSidecarStale $a1Unbound).Verdict -eq 'unverifiable')
  $a1Names = @('Resolve-Window', 'Emit-ResolveNote', 'Get-WindowVisibleRect', 'Save-RectEx', 'Invoke-OcclusionOwners')
  $a1Orig = @{}
  foreach ($a1n in $a1Names) { $a1Orig[$a1n] = (Get-Item ("function:" + $a1n)).ScriptBlock }
  # v4.6.8: a sidecar now binds to the PNG bytes it describes, so every synthetic sidecar in
  # this family needs a real image beside it - the reader checks the hash, not our intention.
  $a1Png = { param($p) $pb = New-Object System.Drawing.Bitmap(2, 2); $pg = [System.Drawing.Graphics]::FromImage($pb); $pg.Clear([System.Drawing.Color]::FromArgb(255, 7, 8, 9)); $pg.Dispose(); $pb.Save($p, [System.Drawing.Imaging.ImageFormat]::Png); $pb.Dispose() }
  $script:a1RectArgs = $null
  $a1Side = Join-Path $env:TEMP ('dtx-a1-sidecar-' + [guid]::NewGuid().ToString('N') + '.png')
  $a1Bad = Join-Path $env:TEMP ('dtx-a1-sidecar-' + [guid]::NewGuid().ToString('N') + '.png')
  try {
    Set-Item -Path 'function:Resolve-Window' -Value { param($sel) return [pscustomobject]@{ Pid = 7; Handle = [IntPtr]::new(1234); Title = 'a1-host'; Left = 100; Top = 200; W = 300; H = 400 } }
    Set-Item -Path 'function:Emit-ResolveNote' -Value { }
    Set-Item -Path 'function:Get-WindowVisibleRect' -Value { param($h) return @{ X = 100; Y = 200; W = 300; H = 400 } }
    Set-Item -Path 'function:Save-RectEx' -Value { param($x, $y, $w, $h, $path, $fit, $grid, $marks, $kind, $mapWin, $mapRect, $cf) $script:a1RectArgs = @{ Path = $path; Kind = $kind; Host = $mapWin; Rect = $mapRect; X = [int]$x; Y = [int]$y }; return @('stub-saved') }
    Set-Item -Path 'function:Invoke-OcclusionOwners' -Value { param($rect, $action, $grid) return @{ Ran = $false; Echo = '' } }
    # --to must be stripped BEFORE the capture parser: left in place it becomes the
    # OUTPUT PATH (the first positional after the four numbers) and the binding vanishes.
    [void](Invoke-DesktopCommand 'rect' @('110', '210', '50', '40', '--to', 'a1-host'))
    ST-Check 'unit (A1): rect --to is stripped before the capture parser, reaches Save-RectEx as the host, AND carries the pre-capture rect snapshot (never as the outPath)' (
      $null -ne $script:a1RectArgs -and $script:a1RectArgs.Path -ne '--to' -and $script:a1RectArgs.Path -like '*rect_*' -and $null -ne $script:a1RectArgs.Host -and $null -ne $script:a1RectArgs.Rect -and $script:a1RectArgs.Rect.X -eq 100 -and $script:a1RectArgs.Rect.Y -eq 200 -and $script:a1RectArgs.X -eq 110 -and $script:a1RectArgs.Kind -eq 'rect')
    $script:a1RectArgs = $null
    $a1OutErr = ''
    try { [void](Invoke-DesktopCommand 'rect' @('10', '10', '50', '40', '--to', 'a1-host')) } catch { $a1OutErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1): rect --to refuses a region outside the bound window BEFORE any capture is written' (
      $a1OutErr.Contains('outside the visible rect') -and $null -eq $script:a1RectArgs)
    $a1ZoomErr = ''
    try { [void](Invoke-DesktopCommand 'zoom' @('10', '10', '50', '40', '--to', 'a1-host')) } catch { $a1ZoomErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1): zoom --to is parsed out (not taken as the outPath) and refuses an outside region before capture' (
      $a1ZoomErr.Contains('outside the visible rect'))
    & $a1Png $a1Side
    Write-MapSidecar $a1Side 110 210 1.0 50 40 'rect' ([pscustomobject]@{ Pid = 7; Handle = [IntPtr]::new(1234); Title = 'a1-host' }) 0 ([pscustomobject]@{ X = 100; Y = 200; W = 300; H = 400 })
    $a1Back = Read-MapSidecar $a1Side
    ST-Check 'unit (A1): a bound rect sidecar round-trips its host identity AND host rect (what the strict check compares)' (
      $a1Back.Kind -eq 'rect' -and $a1Back.HostPid -eq 7 -and ([Int64]$a1Back.HostHwnd -eq 1234) -and $a1Back.HostX -eq 100 -and $a1Back.HostY -eq 200 -and $a1Back.HostW -eq 300 -and $a1Back.HostH -eq 400)
    [System.IO.File]::WriteAllText(($a1Bad + '.map.txt'), "origin_x=1`r`norigin_y=2`r`nscale=1`r`nout_w=3`r`nout_h=4`r`nkind=rect`r`npid=7`r`nhandle=1234`r`n", (New-Object System.Text.UTF8Encoding($false)))
    $a1BadErr = ''
    try { [void](Read-MapSidecar $a1Bad) } catch { $a1BadErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1): a host identity WITHOUT its rect is refused at read time (half a binding never becomes unverifiable)' (
      $a1BadErr.Contains('host_x/host_y/host_w/host_h'))
  } finally {
    foreach ($a1n in $a1Names) { Set-Item -Path ("function:" + $a1n) -Value $a1Orig[$a1n] }
    Remove-Item -LiteralPath @(($a1Side + '.map.txt'), ($a1Bad + '.map.txt')) -Force -ErrorAction SilentlyContinue
  }
  # v4.6.7 (CU-466-REVIEW-20261028-01 A1): the review's two counterexamples stay load-bearing.
  # Only window observation, target activation and the input recorder are replaced; the sidecar
  # writer/reader, the real stale verdict, the real capture functions and the real imgclick
  # handler run unchanged. A stale check stubbed to a constant 'ok' would prove nothing.
  $a1bSnap = @{ Pid = 7; Handle = [IntPtr]::new(1234); Title = 'a1-host'; X = 100; Y = 200; W = 300; H = 400; Sel = 'a1-host' }
  $a1bMoved = Compare-CaptureHostSnapshot $a1bSnap @{ Alive = $true; Pid = 7; Iconic = $false; Rect = @{ X = 200; Y = 200; W = 300; H = 400 } }
  $a1bSame = Compare-CaptureHostSnapshot $a1bSnap @{ Alive = $true; Pid = 7; Iconic = $false; Rect = @{ X = 100; Y = 200; W = 300; H = 400 } }
  $a1bGone = Compare-CaptureHostSnapshot $a1bSnap @{ Alive = $false; Pid = 0; Iconic = $false; Rect = $null }
  $a1bMin = Compare-CaptureHostSnapshot $a1bSnap @{ Alive = $true; Pid = 7; Iconic = $true; Rect = @{ X = 100; Y = 200; W = 300; H = 400 } }
  ST-Check 'unit (A1-b): a rect that changed between capture and sidecar write is refused and both rects are named' (
    (-not $a1bMoved.Ok) -and $a1bMoved.Msg.Contains('DURING capture') -and $a1bMoved.Msg.Contains('(100,200) 300x400') -and $a1bMoved.Msg.Contains('(200,200) 300x400') -and $a1bSame.Ok)
  ST-Check 'unit (A1-b): vanished and minimized hosts during capture are refused, never re-recorded as valid' (
    (-not $a1bGone.Ok) -and $a1bGone.Msg.Contains('vanished DURING capture') -and (-not $a1bMin.Ok) -and $a1bMin.Msg.Contains('minimized DURING capture'))
  $a1bNames = @('Get-WindowObservation', 'Get-WindowVisibleRect')
  $a1bOrig = @{}
  foreach ($a1bn in $a1bNames) { $a1bOrig[$a1bn] = (Get-Item ("function:" + $a1bn)).ScriptBlock }
  $a1bBase = Join-Path $env:TEMP ('dtx-a1-' + [guid]::NewGuid().ToString('N'))
  $a1bFakeWin = [pscustomobject]@{ Pid = 7; Handle = [IntPtr]::new(1234); Title = 'a1-host' }
  # v4.6.9: these controls hash files with .NET, not Get-FileHash. On this engine that
  # command is a module function, and a PS 5.1 child launched with Start-Process from a PS 7 host
  # cannot autoload it (the PS 7 module directory wins PSModulePath) - the same environment the
  # installed-layout smoke test runs in. The subject code uses the identical .NET call.
  $a1Sha = { param([string]$p) $h = [System.Security.Cryptography.SHA256]::Create(); try { $s = [System.IO.File]::OpenRead($p); try { ([BitConverter]::ToString($h.ComputeHash($s)) -replace '-','').ToLower() } finally { $s.Dispose() } } finally { $h.Dispose() } }
  try {
    $script:a1bObs = @{ Alive = $true; Pid = 7; Iconic = $false; Rect = @{ X = 200; Y = 200; W = 300; H = 400 } }
    Set-Item -Path 'function:Get-WindowObservation' -Value { param($h) return $script:a1bObs }
    $a1bAssertErr = ''
    try { [void](Assert-CaptureHostStable $a1bSnap 'rect') } catch { $a1bAssertErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1-b): Assert-CaptureHostStable re-reads the host AFTER the grab and refuses a moved one' (
      $a1bAssertErr.Contains('rect :') -and $a1bAssertErr.Contains('DURING capture') -and $a1bAssertErr.Contains('re-capture'))
    $script:a1bObs = @{ Alive = $true; Pid = 7; Iconic = $false; Rect = @{ X = 100; Y = 200; W = 300; H = 400 } }
    $a1bStillOk = $true
    try { [void](Assert-CaptureHostStable $a1bSnap 'rect') } catch { $a1bStillOk = $false }
    ST-Check 'unit (A1-b): the stationary control passes the same post-capture re-check' ($a1bStillOk)

    $script:a1bReads = 0
    Set-Item -Path 'function:Get-WindowVisibleRect' -Value { param($h) $script:a1bReads++; return @{ X = 200; Y = 200; W = 300; H = 400 } }
    $a1bSide = $a1bBase + '-snap.png'
    & $a1Png $a1bSide
    Write-MapSidecar $a1bSide 10 20 1.0 30 40 'rect' $a1bFakeWin 0 $a1bSnap
    $a1bBack = Read-MapSidecar $a1bSide
    ST-Check 'unit (A1-b): Write-MapSidecar records the PRE-capture rect and makes zero live rect reads' (
      $a1bBack.HostX -eq 100 -and $a1bBack.HostY -eq 200 -and $a1bBack.HostW -eq 300 -and $a1bBack.HostH -eq 400 -and $script:a1bReads -eq 0)

    $script:a1bObs = @{ Alive = $true; Pid = 7; Iconic = $false; Rect = @{ X = 200; Y = 200; W = 300; H = 400 } }
    $a1bImgMove = $a1bBase + '-moved.png'
    $a1bSaveErr = ''
    try { [void](Save-RectEx 0 0 1 1 $a1bImgMove 1.0 -1 @() 'rect' $a1bFakeWin $a1bSnap $null) } catch { $a1bSaveErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1-b): Save-RectEx refuses to publish a sidecar when the host moved during the capture' (
      $a1bSaveErr.Contains('DURING capture') -and (-not (Test-Path -LiteralPath ($a1bImgMove + '.map.txt'))))
    $script:a1bObs = @{ Alive = $true; Pid = 7; Iconic = $false; Rect = @{ X = 100; Y = 200; W = 300; H = 400 } }
    $a1bImgStill = $a1bBase + '-still.png'
    [void](Save-RectEx 0 0 1 1 $a1bImgStill 1.0 -1 @() 'rect' $a1bFakeWin $a1bSnap $null)
    $a1bStillMap = Read-MapSidecar $a1bImgStill
    $script:a1bObs = @{ Alive = $true; Pid = 7; Iconic = $false; Rect = @{ X = 200; Y = 200; W = 300; H = 400 } }
    $a1bLate = Test-MapSidecarStale $a1bStillMap
    ST-Check 'unit (A1-b): the stationary frame keeps the capture-time rect, so a LATER move reads stale instead of ok' (
      $a1bStillMap.HostX -eq 100 -and $a1bLate.Verdict -eq 'stale')
    $a1bImgScript = $a1bBase + '-script.png'
    [void](Save-RectEx 0 0 1 1 $a1bImgScript 1.0 -1 @() '' $null $null)
    ST-Check 'unit (A1-b): a script-style capture publishes no bound sidecar at all' (
      -not (Test-Path -LiteralPath ($a1bImgScript + '.map.txt')))
    # CU-467-REVIEW-20261028-01 A1-b: the reviewer's reused-output counterexample, end to end on
    # the REAL Save-RectEx. First capture succeeds at a fixed name; the second, into the SAME
    # name, is refused after the host moved. The old order had already overwritten the PNG at
    # that point. Whatever remains must still be the OLD, self-consistent pair - the image bytes
    # are unchanged, so no reader can map the old sidecar through new pixels.
    $a1bStillRect = @{ Alive = $true; Pid = 7; Iconic = $false; Rect = @{ X = 100; Y = 200; W = 300; H = 400 } }
    $a1bMovedRect = @{ Alive = $true; Pid = 7; Iconic = $false; Rect = @{ X = 200; Y = 200; W = 300; H = 400 } }
    $script:a1bObs = $a1bStillRect
    $a1rB = $a1bBase + '-reuse.png'
    [void](Save-RectEx 10 20 2 2 $a1rB 1.0 -1 @() 'rect' $a1bFakeWin $a1bSnap $null)
    $a1rPng0 = & $a1Sha $a1rB
    $a1rMap0 = & $a1Sha ($a1rB + '.map.txt')
    $script:a1bObs = $a1bMovedRect
    $a1rErr = ''
    try { [void](Save-RectEx 210 220 4 4 $a1rB 1.0 -1 @() 'rect' $a1bFakeWin $a1bSnap $null) } catch { $a1rErr = "$($_.Exception.Message)" }
    $script:a1bObs = $a1bStillRect
    $a1rPng1 = & $a1Sha $a1rB
    $a1rMap1 = & $a1Sha ($a1rB + '.map.txt')
    $a1rBack = Read-MapSidecar $a1rB
    $a1rVerdict = Test-MapSidecarStale $a1rBack
    ST-Check 'unit (A1-b): a refused re-capture into an EXISTING name keeps the old PNG and map byte-identical (an old map never rides new pixels)' (
      $a1rErr.Contains('DURING capture') -and $a1rPng1 -eq $a1rPng0 -and $a1rMap1 -eq $a1rMap0 -and $a1rBack.OriginX -eq 10 -and $a1rBack.OriginY -eq 20 -and $a1rVerdict.Verdict -eq 'ok')
    $script:a1bObs = $a1bMovedRect
    $a1rNew = $a1bBase + '-reuse-newfail.png'
    $a1rNewErr = ''
    try { [void](Save-RectEx 10 20 4 4 $a1rNew 1.0 -1 @() 'rect' $a1bFakeWin $a1bSnap $null) } catch { $a1rNewErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1-b): a refused capture to a NEW name publishes neither the PNG nor a sidecar (no half frame on disk)' (
      $a1rNewErr.Contains('DURING capture') -and (-not (Test-Path -LiteralPath $a1rNew)) -and (-not (Test-Path -LiteralPath ($a1rNew + '.map.txt'))))
    $script:a1bObs = $a1bStillRect
    [void](Save-RectEx 30 40 2 2 $a1rB 1.0 -1 @() 'rect' $a1bFakeWin $a1bSnap $null)
    $a1rBack2 = Read-MapSidecar $a1rB
    $a1rPng2 = & $a1Sha $a1rB
    ST-Check 'unit (A1-b): a successful re-capture to the same name refreshes the sidecar origin AND records the new PNG hash' (
      $a1rBack2.OriginX -eq 30 -and $a1rBack2.OriginY -eq 40 -and $a1rBack2.PngSha.Length -eq 64 -and $a1rBack2.PngSha -eq $a1rPng2)
    $a1hPng = $a1bBase + '-hashmismatch.png'
    [void](Save-RectEx 10 20 2 2 $a1hPng 1.0 -1 @() 'rect' $a1bFakeWin $a1bSnap $null)
    $a1hBmp = New-Object System.Drawing.Bitmap(3, 3)
    $a1hBmp.Save($a1hPng, [System.Drawing.Imaging.ImageFormat]::Png)
    $a1hBmp.Dispose()
    $a1hErr = ''
    try { [void](Read-MapSidecar $a1hPng) } catch { $a1hErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1-b): a sidecar whose png_sha256 no longer matches the file is refused at read time (the old map never blesses a replaced PNG)' (
      $a1hErr.Contains('DIFFERENT image') -and $a1hErr.Contains('png_sha256'))
    # CU-CLOSEOUT-REVIEW-20261029-01 P2: the review's remaining branch - a PRE-v4.6.8 map (no
    # png_sha256) beside a REUSED name whose MAP WRITE fails. The map is made read-only so the REAL
    # writer throws; the publication order now puts the map in front of the image, so the PNG must
    # not be touched and the old origin must stay the only one any reader can obtain.
    $a1lg = $a1bBase + '-legacy.png'
    & $a1Png $a1lg
    $a1lgLegacy = "origin_x=11`r`norigin_y=22`r`nscale=1`r`nout_w=2`r`nout_h=2`r`nkind=rect`r`npid=7`r`nhandle=1234`r`nhost_x=100`r`nhost_y=200`r`nhost_w=300`r`nhost_h=400`r`n"
    [System.IO.File]::WriteAllText(($a1lg + '.map.txt'), $a1lgLegacy, (New-Object System.Text.UTF8Encoding($false)))
    $a1lgPng0 = & $a1Sha $a1lg
    $a1lgMap0 = & $a1Sha ($a1lg + '.map.txt')
    $script:a1bObs = $a1bStillRect
    Set-ItemProperty -LiteralPath ($a1lg + '.map.txt') -Name IsReadOnly -Value $true
    $a1lgErr = ''
    try { [void](Save-RectEx 700 450 2 2 $a1lg 1.0 -1 @() 'rect' $a1bFakeWin $a1bSnap $null) } catch { $a1lgErr = "$($_.Exception.Message)" }
    Set-ItemProperty -LiteralPath ($a1lg + '.map.txt') -Name IsReadOnly -Value $false
    $a1lgPng1 = & $a1Sha $a1lg
    $a1lgMap1 = & $a1Sha ($a1lg + '.map.txt')
    $a1lgBack = Read-MapSidecar $a1lg
    ST-Check 'unit (P2): a FAILED map write on a reused name leaves the OLD PNG and its legacy map byte-identical (new pixels never ride an old origin)' (
      $a1lgErr.Contains('map sidecar NOT written') -and $a1lgPng1 -eq $a1lgPng0 -and $a1lgMap1 -eq $a1lgMap0 -and $a1lgBack.OriginX -eq 11 -and $a1lgBack.OriginY -eq 22 -and $a1lgBack.PngSha -eq '' -and (Test-MapSidecarStale $a1lgBack).Verdict -eq 'ok')
    [void](Save-RectEx 33 44 2 2 $a1lg 1.0 -1 @() 'rect' $a1bFakeWin $a1bSnap $null)
    $a1lgBack2 = Read-MapSidecar $a1lg
    $a1lgPng2 = & $a1Sha $a1lg
    ST-Check 'unit (P2): a successful re-capture over a legacy map rewrites it WITH the new hash and origin (compatibility, not a licence to mismatch)' (
      $a1lgBack2.OriginX -eq 33 -and $a1lgBack2.OriginY -eq 44 -and $a1lgBack2.PngSha.Length -eq 64 -and $a1lgBack2.PngSha -eq $a1lgPng2)
    # v4.6.11 (CU-4610-REVIEW-20261029-01 P2): the writer must publish the sidecar as a WHOLE
    # file. The behavioural controls below can only observe the failures the OS hands us (a
    # read-only map, a read-only image); a failure halfway through the write is not one of them,
    # so the shape that makes it harmless is pinned here: the final map path is never the target
    # of a file write, and the publish goes through a sibling temp file with one Replace/Move.
    $a1pbBody = @()
    $a1pbStart = -1
    for ($a1pbi = 0; $a1pbi -lt $codeLines.Count; $a1pbi++) {
      if ($a1pbStart -lt 0) {
        if ($codeLines[$a1pbi] -match '^function Write-MapSidecar\(') { $a1pbStart = $a1pbi }
        continue
      }
      if ($codeLines[$a1pbi] -match '^function ') { break }
      $a1pbBody += [string]$codeLines[$a1pbi]
    }
    $a1pbDirect = @($a1pbBody | Where-Object { $_ -notmatch '^\s*#' -and $_ -match 'WriteAllText\(' -and $_ -match '\.map\.txt' })
    $a1pbTemp = @($a1pbBody | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains('WriteAllText($tmpPath') })
    $a1pbPublish = @($a1pbBody | Where-Object { $_ -notmatch '^\s*#' -and ($_.Contains('Replace($tmpPath, $mapPath') -or $_.Contains('Move($tmpPath, $mapPath')) })
    ST-Check 'lint (P2-b): the sidecar writer never writes the final map path directly - it publishes a whole temp file, so a mid-write failure cannot truncate a live map' (
      ($a1pbStart -ge 0) -and (@($a1pbDirect).Count -eq 0) -and (@($a1pbTemp).Count -eq 1) -and (@($a1pbPublish).Count -ge 1))
    if (-not (($a1pbStart -ge 0) -and (@($a1pbDirect).Count -eq 0) -and (@($a1pbTemp).Count -eq 1) -and (@($a1pbPublish).Count -ge 1))) {
      Write-Output ('      P2-b shape: start=' + $a1pbStart + ' body=' + @($a1pbBody).Count + ' direct=' + @($a1pbDirect).Count + ' temp=' + @($a1pbTemp).Count + ' publish=' + @($a1pbPublish).Count)
    }
    # The temp file must not survive any branch: on success the publish consumes it, on failure
    # the catch deletes it. Left behind, it would be a partial sidecar under a name no reader
    # picks up - harmless to reads, but a liar to the next person looking at the directory.
    $a1pbFailLeft = @(Get-ChildItem -LiteralPath (Split-Path -Parent $a1lg) -Filter '*.map.txt.new-*' -Force -ErrorAction SilentlyContinue)
    ST-Check 'unit (P2-b): a refused map publish deletes its own temp file (no partial sidecar is left behind)' (
      ($a1lgErr.Contains('map sidecar NOT written')) -and (@($a1pbFailLeft).Count -eq 0))
    # Both publish branches, measured: a first capture at a new name must take the Move branch,
    # a same-name re-capture the Replace branch, and neither may leave a temp file.
    $a1pbDir = $a1bBase + '-pub'
    New-Item -ItemType Directory -Force -Path $a1pbDir | Out-Null
    $a1pbNew = Join-Path $a1pbDir 'fresh.png'
    $script:a1bObs = $a1bStillRect
    [void](Save-RectEx 60 70 2 2 $a1pbNew 1.0 -1 @() 'rect' $a1bFakeWin $a1bSnap $null)
    $a1pbLeft = @(Get-ChildItem -LiteralPath $a1pbDir -Filter '*.new-*' -Force -ErrorAction SilentlyContinue)
    $a1pbBack = Read-MapSidecar $a1pbNew
    [void](Save-RectEx 80 90 2 2 $a1pbNew 1.0 -1 @() 'rect' $a1bFakeWin $a1bSnap $null)
    $a1pbLeft2 = @(Get-ChildItem -LiteralPath $a1pbDir -Filter '*.new-*' -Force -ErrorAction SilentlyContinue)
    $a1pbBack2 = Read-MapSidecar $a1pbNew
    ST-Check 'unit (P2-b): the first capture (move branch) and a same-name re-capture (replace branch) publish a readable map and leave no temp sidecar behind' (
      (@($a1pbLeft).Count -eq 0) -and (@($a1pbLeft2).Count -eq 0) -and
      $a1pbBack.OriginX -eq 60 -and $a1pbBack.OriginY -eq 70 -and
      $a1pbBack2.OriginX -eq 80 -and $a1pbBack2.OriginY -eq 90 -and
      $a1pbBack2.PngSha.Length -eq 64 -and $a1pbBack2.PngSha -eq (& $a1Sha $a1pbNew))
    Remove-Item -LiteralPath $a1pbDir -Recurse -Force -ErrorAction SilentlyContinue
    # CU-REMAINDER-FINAL-20261029-01 A2: shot / script steps publish no sidecar. Overwriting a name
    # that still carries a binding must withdraw it, or the next reader maps new pixels through an
    # old origin with nothing to compare.
    $a1ns = $a1bBase + '-nosidecar.png'
    & $a1Png $a1ns
    [System.IO.File]::WriteAllText(($a1ns + '.map.txt'), $a1lgLegacy, (New-Object System.Text.UTF8Encoding($false)))
    [void](Save-RectEx 20 30 2 2 $a1ns 1.0 -1 @() '' $null $null $null)
    ST-Check 'unit (A2): a capture that publishes NO sidecar withdraws a previous binding at the same name (shot/script cannot inherit an old origin)' (
      (-not (Test-Path -LiteralPath ($a1ns + '.map.txt'))) -and (Test-Path -LiteralPath $a1ns))
    # CU-REMAINDER-FINAL-20261029-01 A3: a png_sha256 line that exists but does not parse as 64 hex
    # is a damaged hash - it must not be read as the legacy no-hash format.
    $a1mf = $a1bBase + '-malformed.png'
    & $a1Png $a1mf
    $a1mfHead = "origin_x=5`r`norigin_y=6`r`nscale=1`r`nout_w=2`r`nout_h=2`r`nkind=rect`r`n"
    $a1mfBad = @("png_sha256=`r`n", "png_sha256=abc`r`n", ("png_sha256=" + ('a' * 63) + "`r`n"))
    $a1mfAllRefused = $true
    $a1mfMsgs = @()
    foreach ($a1mfOne in $a1mfBad) {
      [System.IO.File]::WriteAllText(($a1mf + '.map.txt'), ($a1mfHead + $a1mfOne), (New-Object System.Text.UTF8Encoding($false)))
      try { [void](Read-MapSidecar $a1mf); $a1mfAllRefused = $false; $a1mfMsgs += 'ACCEPTED:' + $a1mfOne.Trim() }
      catch { if (-not "$($_.Exception.Message)".Contains('malformed')) { $a1mfAllRefused = $false; $a1mfMsgs += 'OTHER:' + "$($_.Exception.Message)" } }
    }
    ST-Check 'unit (A3): png_sha256 present but empty, non-hex or truncated is refused as MALFORMED, never folded into the legacy branch' (
      $a1mfAllRefused -and (@($a1mfMsgs).Count -eq 0))
    # CU-REMAINDER-FINAL-20261029-01 A3: a sidecar without its image is not a pair - legacy included.
    $a1nm = $a1bBase + '-noimage.png'
    [System.IO.File]::WriteAllText(($a1nm + '.map.txt'), $a1lgLegacy, (New-Object System.Text.UTF8Encoding($false)))
    $a1nmErr = ''
    try { [void](Read-MapSidecar $a1nm) } catch { $a1nmErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A3): a sidecar whose image is missing is refused at read time for the LEGACY format too (no dangling pair)' (
      $a1nmErr.Contains('describes an image that is not there'))
    # CU-REMAINDER-FINAL-20261029-01 A3: the image-write half of a failed publication. The map lands
    # first (that is the fix), the read-only PNG refuses the replace, and the pair must then REFUSE
    # instead of letting the new map explain the old pixels.
    $a1pw = $a1bBase + '-pngreadonly.png'
    & $a1Png $a1pw
    [System.IO.File]::WriteAllText(($a1pw + '.map.txt'), $a1lgLegacy, (New-Object System.Text.UTF8Encoding($false)))
    $a1pwPng0 = & $a1Sha $a1pw
    $a1pwMap0 = & $a1Sha ($a1pw + '.map.txt')
    $script:a1bObs = $a1bStillRect
    Set-ItemProperty -LiteralPath $a1pw -Name IsReadOnly -Value $true
    $a1pwErr = ''
    try { [void](Save-RectEx 40 50 2 2 $a1pw 1.0 -1 @() 'rect' $a1bFakeWin $a1bSnap $null) } catch { $a1pwErr = "$($_.Exception.Message)" }
    Set-ItemProperty -LiteralPath $a1pw -Name IsReadOnly -Value $false
    $a1pwPng1 = & $a1Sha $a1pw
    $a1pwMap1 = & $a1Sha ($a1pw + '.map.txt')
    $a1pwRead = ''
    try { [void](Read-MapSidecar $a1pw) } catch { $a1pwRead = "$($_.Exception.Message)" }
    ST-Check 'unit (A3): when the image cannot be replaced after the map landed, the result is a REFUSED pair (old pixels never ride the new map)' (
      $a1pwPng1 -eq $a1pwPng0 -and $a1pwMap1 -ne $a1pwMap0 -and $a1pwRead.Contains('DIFFERENT image'))
  } finally {
    foreach ($a1bn in $a1bNames) { Set-Item -Path ("function:" + $a1bn) -Value $a1bOrig[$a1bn] }
    Remove-Item -LiteralPath @(($a1bBase + '-snap.png.map.txt'), ($a1bImgMove + '.map.txt'), ($a1bImgStill + '.map.txt'), ($a1rB + '.map.txt'), ($a1hPng + '.map.txt')) -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath @(($a1bBase + '-snap.png'), $a1bImgMove, $a1bImgStill, $a1bImgScript, $a1rB, $a1hPng) -Force -ErrorAction SilentlyContinue
    foreach ($a1extra in @($a1ns, $a1mf, $a1nm, $a1pw)) {
      if ($a1extra) {
        Set-ItemProperty -LiteralPath $a1extra -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath @($a1extra, ($a1extra + '.map.txt')) -Force -ErrorAction SilentlyContinue
      }
    }
    if ($a1lg) {
      Set-ItemProperty -LiteralPath ($a1lg + '.map.txt') -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath @($a1lg, ($a1lg + '.map.txt')) -Force -ErrorAction SilentlyContinue
    }
  }
  # A1-b end-to-end on zoom: Resolve-CropHost reads the rect BEFORE the grab; the post-save
  # re-check uses the same observation seam. Only the window lookup/observation is replaced.
  $a1zNames = @('Resolve-Window', 'Emit-ResolveNote', 'Get-WindowVisibleRect', 'Get-WindowObservation')
  $a1zOrig = @{}
  foreach ($a1zn in $a1zNames) { $a1zOrig[$a1zn] = (Get-Item ("function:" + $a1zn)).ScriptBlock }
  try {
    Set-Item -Path 'function:Resolve-Window' -Value { param($sel) return [pscustomobject]@{ Pid = 7; Handle = [IntPtr]::new(1234); Title = 'a1-host'; Left = 100; Top = 200; W = 300; H = 400 } }
    Set-Item -Path 'function:Emit-ResolveNote' -Value { }
    Set-Item -Path 'function:Get-WindowVisibleRect' -Value { param($h) return @{ X = 100; Y = 200; W = 300; H = 400 } }
    $script:a1zObs = @{ Alive = $true; Pid = 7; Iconic = $false; Rect = @{ X = 200; Y = 200; W = 300; H = 400 } }
    Set-Item -Path 'function:Get-WindowObservation' -Value { param($h) return $script:a1zObs }
    $a1zMove = $a1bBase + '-zoom-moved.png'
    $a1zErr = ''
    try { [void](Invoke-DesktopCommand 'zoom' @('100', '200', '10', '10', '2', $a1zMove, '--to', 'a1-host')) } catch { $a1zErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1-b): zoom refuses the frame when the host moved between the grab and the sidecar write' (
      $a1zErr.Contains('zoom :') -and $a1zErr.Contains('DURING capture') -and (-not (Test-Path -LiteralPath ($a1zMove + '.map.txt'))) -and (-not (Test-Path -LiteralPath $a1zMove)))
    $script:a1zObs = @{ Alive = $true; Pid = 7; Iconic = $false; Rect = @{ X = 100; Y = 200; W = 300; H = 400 } }
    $a1zStill = $a1bBase + '-zoom-still.png'
    [void](Invoke-DesktopCommand 'zoom' @('100', '200', '10', '10', '2', $a1zStill, '--to', 'a1-host'))
    $a1zMap = Read-MapSidecar $a1zStill
    ST-Check 'unit (A1-b): a stationary zoom records the pre-capture host rect in its sidecar' (
      $a1zMap.HostPid -eq 7 -and $a1zMap.HostX -eq 100 -and $a1zMap.HostY -eq 200 -and $a1zMap.HostW -eq 300 -and $a1zMap.HostH -eq 400)
    # CU-467-REVIEW-20261028-01 A1-b: the same reused-output counterexample on the ZOOM path.
    $a1zStillObs = @{ Alive = $true; Pid = 7; Iconic = $false; Rect = @{ X = 100; Y = 200; W = 300; H = 400 } }
    $a1zMovedObs = @{ Alive = $true; Pid = 7; Iconic = $false; Rect = @{ X = 200; Y = 200; W = 300; H = 400 } }
    $script:a1zObs = $a1zStillObs
    $a1zReuse = $a1bBase + '-zoom-reuse.png'
    [void](Invoke-DesktopCommand 'zoom' @('100', '200', '4', '4', '2', $a1zReuse, '--to', 'a1-host'))
    $a1zPng0 = & $a1Sha $a1zReuse
    $a1zMap0 = & $a1Sha ($a1zReuse + '.map.txt')
    $script:a1zObs = $a1zMovedObs
    $a1zReuseErr = ''
    try { [void](Invoke-DesktopCommand 'zoom' @('100', '200', '6', '6', '2', $a1zReuse, '--to', 'a1-host')) } catch { $a1zReuseErr = "$($_.Exception.Message)" }
    $script:a1zObs = $a1zStillObs
    $a1zPng1 = & $a1Sha $a1zReuse
    $a1zMap1 = & $a1Sha ($a1zReuse + '.map.txt')
    $a1zBack = Read-MapSidecar $a1zReuse
    ST-Check 'unit (A1-b): a refused re-capture into an EXISTING zoom name keeps the old PNG and map byte-identical' (
      $a1zReuseErr.Contains('DURING capture') -and $a1zPng1 -eq $a1zPng0 -and $a1zMap1 -eq $a1zMap0 -and $a1zBack.OriginX -eq 100 -and $a1zBack.OriginY -eq 200 -and (Test-MapSidecarStale $a1zBack).Verdict -eq 'ok')
    $script:a1zObs = $a1zMovedObs
    $a1zNew = $a1bBase + '-zoom-newfail.png'
    $a1zNewErr = ''
    try { [void](Invoke-DesktopCommand 'zoom' @('100', '200', '4', '4', '2', $a1zNew, '--to', 'a1-host')) } catch { $a1zNewErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1-b): a refused zoom to a NEW name publishes neither the PNG nor a sidecar' (
      $a1zNewErr.Contains('DURING capture') -and (-not (Test-Path -LiteralPath $a1zNew)) -and (-not (Test-Path -LiteralPath ($a1zNew + '.map.txt'))))
    # CU-CLOSEOUT-REVIEW-20261029-01 P2: the same legacy-map / map-write-failure branch on ZOOM.
    $a1zLeg = $a1bBase + '-zoom-legacy.png'
    & $a1Png $a1zLeg
    $a1zLegacy = "origin_x=600`r`norigin_y=400`r`nscale=2`r`nout_w=4`r`nout_h=4`r`nkind=zoom`r`npid=7`r`nhandle=1234`r`ntitle_b64=YTEtaG9zdA==`r`nhost_x=100`r`nhost_y=200`r`nhost_w=300`r`nhost_h=400`r`n"
    [System.IO.File]::WriteAllText(($a1zLeg + '.map.txt'), $a1zLegacy, (New-Object System.Text.UTF8Encoding($false)))
    $a1zLegPng0 = & $a1Sha $a1zLeg
    $a1zLegMap0 = & $a1Sha ($a1zLeg + '.map.txt')
    $script:a1zObs = $a1zStillObs
    Set-ItemProperty -LiteralPath ($a1zLeg + '.map.txt') -Name IsReadOnly -Value $true
    $a1zLegErr = ''
    try { [void](Invoke-DesktopCommand 'zoom' @('350', '550', '4', '4', '2', $a1zLeg, '--to', 'a1-host')) } catch { $a1zLegErr = "$($_.Exception.Message)" }
    Set-ItemProperty -LiteralPath ($a1zLeg + '.map.txt') -Name IsReadOnly -Value $false
    $a1zLegPng1 = & $a1Sha $a1zLeg
    $a1zLegMap1 = & $a1Sha ($a1zLeg + '.map.txt')
    $a1zLegBack = Read-MapSidecar $a1zLeg
    ST-Check 'unit (P2): a FAILED map write on a reused zoom name leaves the OLD PNG and its legacy map byte-identical' (
      $a1zLegErr.Contains('map sidecar NOT written') -and $a1zLegPng1 -eq $a1zLegPng0 -and $a1zLegMap1 -eq $a1zLegMap0 -and $a1zLegBack.OriginX -eq 600 -and $a1zLegBack.OriginY -eq 400 -and $a1zLegBack.PngSha -eq '')
    [void](Invoke-DesktopCommand 'zoom' @('150', '250', '4', '4', '2', $a1zLeg, '--to', 'a1-host'))
    $a1zLegBack2 = Read-MapSidecar $a1zLeg
    $a1zLegPng2 = & $a1Sha $a1zLeg
    ST-Check 'unit (P2): a successful zoom re-capture over a legacy map rewrites it WITH the new hash and origin' (
      $a1zLegBack2.OriginX -eq 150 -and $a1zLegBack2.OriginY -eq 250 -and $a1zLegBack2.PngSha.Length -eq 64 -and $a1zLegBack2.PngSha -eq $a1zLegPng2)
  } finally {
    foreach ($a1zn in $a1zNames) { Set-Item -Path ("function:" + $a1zn) -Value $a1zOrig[$a1zn] }
    Remove-Item -LiteralPath @(($a1zMove + '.map.txt'), ($a1zStill + '.map.txt'), ($a1zReuse + '.map.txt')) -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath @($a1zMove, $a1zStill, $a1zReuse) -Force -ErrorAction SilentlyContinue
    if ($a1zLeg) {
      Set-ItemProperty -LiteralPath ($a1zLeg + '.map.txt') -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath @($a1zLeg, ($a1zLeg + '.map.txt')) -Force -ErrorAction SilentlyContinue
    }
  }
  # A1-a: the real handler, real sidecar read, real stale verdict. Resolve-Target only flips a
  # flag and the observation seam returns the moved rect afterwards - the exact review shape:
  # the OLD mapped point is still inside the window, so the landing guard alone would pass.
  $a1aNames = @('Resolve-Target', 'Emit-ResolveNote', 'Invoke-TargetBlockGuard', 'Invoke-HitWindowCheck', 'Move-Click', 'Invoke-ActionExpectation', 'Invoke-ExpectChangeCheck', 'Get-ExpectChangeBaseline', 'Get-WindowObservation')
  $a1aLog = 'Log-' + 'Action'
  $a1aNames += $a1aLog
  $a1aOrig = @{}
  foreach ($a1an in $a1aNames) { $a1aOrig[$a1an] = (Get-Item ("function:" + $a1an)).ScriptBlock }
  try {
    $a1aSide = $a1bBase + '-click.png'
    & $a1Png $a1aSide
    # CU-467: the click point is now (150,300) -> screen (260,510), which stays inside the window
    # after activation moves X 100 -> 200 (200..500 by 200..600). The old (10,10) -> (120,220)
    # left the frame and did not exercise the shape the review describes.
    Write-MapSidecar $a1aSide 110 210 1.0 300 400 'rect' $a1bFakeWin 0 $a1bSnap
    Set-Item -Path 'function:Get-WindowObservation' -Value { param($h) $r = @{ X = 100; Y = 200; W = 300; H = 400 }; if ($script:a1aMove -and $script:a1aActivated) { $r = @{ X = 200; Y = 200; W = 300; H = 400 } }; return @{ Alive = $true; Pid = 7; Iconic = $false; Rect = $r } }
    Set-Item -Path 'function:Resolve-Target' -Value { param($sel, $force, $always, $eh, $created) $script:a1aActivated = $true; return [pscustomobject]@{ Pid = 7; Handle = [IntPtr]::new(1234); Title = 'a1-host'; Left = 100; Top = 200; W = 300; H = 400 } }
    Set-Item -Path 'function:Emit-ResolveNote' -Value { }
    Set-Item -Path 'function:Invoke-TargetBlockGuard' -Value { }
    Set-Item -Path 'function:Invoke-HitWindowCheck' -Value { param($x, $y, $tgt, $hasSel, $allow) }
    Set-Item -Path ("function:" + $a1aLog) -Value { param($r, $m, $c) }
    Set-Item -Path 'function:Move-Click' -Value { param($x, $y, $b) $script:a1aClicked++ }
    Set-Item -Path 'function:Invoke-ActionExpectation' -Value { param($p, $tgt, $what) }
    Set-Item -Path 'function:Invoke-ExpectChangeCheck' -Value { param($p, $ecb, $what) }
    Set-Item -Path 'function:Get-ExpectChangeBaseline' -Value { param($p, $tgt) return $null }
    $script:a1aMove = $true
    $script:a1aActivated = $false
    $script:a1aClicked = 0
    $a1aErr = ''
    try { [void](Invoke-DesktopCommand 'imgclick' @($a1aSide, '150', '300', '--to', 'a1-host', '--require-verified')) } catch { $a1aErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1-a): strict imgclick refuses when activation moved the host, even though the old point is still inside it' (
      $script:a1aClicked -eq 0 -and $a1aErr.Contains('immediately before input') -and $a1aErr.Contains('STALE'))
    $script:a1aMove = $false
    $script:a1aActivated = $false
    $script:a1aClicked = 0
    $a1aOk = $true
    try { [void](Invoke-DesktopCommand 'imgclick' @($a1aSide, '150', '300', '--to', 'a1-host', '--require-verified')) } catch { $a1aOk = $false }
    ST-Check 'unit (A1-a): the stationary control still clicks once' ($a1aOk -and $script:a1aClicked -eq 1)
    $script:a1aMove = $true
    $script:a1aActivated = $false
    $script:a1aClicked = 0
    $a1aDefErr = ''
    try { [void](Invoke-DesktopCommand 'imgclick' @($a1aSide, '150', '300', '--to', 'a1-host')) } catch { $a1aDefErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1-a): the default path (no --stale-ok) also refuses a late move before input' (
      $script:a1aClicked -eq 0 -and $a1aDefErr.Contains('immediately before input'))
    $script:a1aMove = $true
    $script:a1aActivated = $false
    $script:a1aClicked = 0
    $a1aStaleOk = $true
    try { [void](Invoke-DesktopCommand 'imgclick' @($a1aSide, '150', '300', '--to', 'a1-host', '--stale-ok')) } catch { $a1aStaleOk = $false }
    ST-Check 'unit (A1-a): --stale-ok remains the explicit permission to map against the old origin' (
      $a1aStaleOk -and $script:a1aClicked -eq 1)
    # CU-467-REVIEW-20261028-01 A1-b: the reader-side guard for an injected publication failure -
    # a PNG replaced out of band while the old sidecar stays. Strict imgclick must stop at the
    # read, with no target work and no input.
    $a1aBadPair = $a1bBase + '-click-badpair.png'
    $script:a1aMove = $false
    $script:a1aActivated = $false
    [void](Save-RectEx 110 210 2 2 $a1aBadPair 1.0 -1 @() 'rect' $a1bFakeWin $a1bSnap $null)
    $a1aBadBmp = New-Object System.Drawing.Bitmap(5, 5)
    $a1aBadBmp.Save($a1aBadPair, [System.Drawing.Imaging.ImageFormat]::Png)
    $a1aBadBmp.Dispose()
    $script:a1aClicked = 0
    $a1aBadErr = ''
    try { [void](Invoke-DesktopCommand 'imgclick' @($a1aBadPair, '150', '300', '--to', 'a1-host', '--require-verified')) } catch { $a1aBadErr = "$($_.Exception.Message)" }
    ST-Check 'unit (A1-b): strict imgclick refuses a sidecar/PNG pair whose hash no longer matches (0 clicks)' (
      $script:a1aClicked -eq 0 -and $a1aBadErr.Contains('DIFFERENT image'))
  } finally {
    foreach ($a1an in $a1aNames) { Set-Item -Path ("function:" + $a1an) -Value $a1aOrig[$a1an] }
    Remove-Item -LiteralPath @(($a1aSide + '.map.txt'), $a1aSide, ($a1aBadPair + '.map.txt'), $a1aBadPair) -Force -ErrorAction SilentlyContinue
  }
  # CU-EXTERNAL-EXPERIENCE-20261028 B2: the pre-input block verdict. owner is a WINDOW
  # RELATION, not a modality: an owned visible window that UIA reads as modeless must stay
  # 'clear' while the target is enabled, and a disabled target whose only candidates read
  # modeless/unsupported must read 'unknown' - never promoted to 'modal'. Facts in, verdict
  # out, so both fixtures (a modal dialog and a modeless palette) are pinned without a live
  # window and the negative control is the enabled case.
  $b2Cand = {
    param([int]$h, [string]$cls, [string]$title, [string]$uia)
    return [pscustomobject]@{ Handle = [IntPtr]::new($h); Pid = 9; Class = $cls; Title = $title
      Identity = ("pid=9 hwnd=$h " + (Format-WindowLabel $title $cls)); UiaModal = $uia }
  }
  $b2ModelessCand = & $b2Cand 11 'Qt63' 'Find' 'no'
  $b2UnsupportedCand = & $b2Cand 13 'Qt63' 'Palette' 'unsupported'
  $b2ModalCand = & $b2Cand 12 '#32770' 'Save changes' 'yes'
  $b2Clear = Get-TargetBlockVerdict $true $true @($b2ModelessCand) 't'
  $b2Blocked = Get-TargetBlockVerdict $true $false @($b2ModalCand) 't'
  $b2UnknownModeless = Get-TargetBlockVerdict $true $false @($b2ModelessCand, $b2UnsupportedCand) 't'
  $b2UnknownNone = Get-TargetBlockVerdict $true $false @() 't'
  $b2Gone = Get-TargetBlockVerdict $false $false @() 't'
  ST-Check 'unit (B2): an ENABLED target stays clear even with an owned visible window (owned is not modal - the modeless negative control)' (
    $b2Clear.Verdict -eq 'clear' -and $b2Clear.Msg -eq '')
  ST-Check 'unit (B2): a DISABLED target with a UIA IsModal=true candidate reads blocked and names that candidate' (
    $b2Blocked.Verdict -eq 'blocked' -and $b2Blocked.Blocking.Title -eq 'Save changes' -and
    $b2Blocked.Msg.Contains('hwnd=12') -and $b2Blocked.Msg.Contains('IsModal=true') -and $b2Blocked.Msg.Contains('NOTHING was sent'))
  ST-Check 'unit (B2): a DISABLED target whose owned windows read modeless/unsupported reads UNKNOWN - the message never claims IsModal=true' (
    $b2UnknownModeless.Verdict -eq 'unknown' -and (-not $b2UnknownModeless.Msg.Contains('IsModal=true')) -and
    $b2UnknownModeless.Msg.Contains('unconfirmed') -and $b2UnknownModeless.Msg.Contains('hwnd=11') -and $b2UnknownModeless.Msg.Contains('hwnd=13'))
  ST-Check 'unit (B2): a DISABLED target with NO owned window reads UNKNOWN (the cause is not invented)' (
    $b2UnknownNone.Verdict -eq 'unknown' -and $b2UnknownNone.Msg.Contains('no visible top-level window is owned') -and $null -eq $b2UnknownNone.Blocking)
  ST-Check 'unit (B2): a vanished target reads gone - the block guard does not manufacture a refusal the other guards own' (
    $b2Gone.Verdict -eq 'gone' -and $b2Gone.Msg -eq '')
  $b2Names = @('Resolve-Target', 'Emit-ResolveNote', 'Invoke-HitWindowCheck', ('Log-' + 'Action'), 'Move-Click',
    'Get-PointSpaceOrigin', 'Convert-PointSpace', 'Get-TargetBlockFacts')
  $b2Orig = @{}
  foreach ($b2n in $b2Names) { $b2Orig[$b2n] = (Get-Item ("function:" + $b2n)).ScriptBlock }
  $script:b2Moves = 0
  $script:b2Facts = @{ Alive = $true; Enabled = $true; Candidates = @() }
  try {
    Set-Item -Path 'function:Resolve-Target' -Value { param($sel, $force, $always, $eh, $created) return [pscustomobject]@{ Pid = 41998; Title = 'b2-fake'; Handle = [IntPtr]::new(77); Left = 0; Top = 0; W = 100; H = 100 } }
    Set-Item -Path 'function:Emit-ResolveNote' -Value { }
    Set-Item -Path 'function:Invoke-HitWindowCheck' -Value { param($x, $y, $tgt, $enforce, $allow) }
    Set-Item -Path ('function:' + $b2Names[3]) -Value { param($la, $detail, $cn) }
    Set-Item -Path 'function:Move-Click' -Value { param($x, $y, $b, $m) $script:b2Moves++ }
    Set-Item -Path 'function:Get-PointSpaceOrigin' -Value { param($space, $tgt) return @{ Space = 'screen'; X = 0; Y = 0; W = 1920; H = 1080 } }
    Set-Item -Path 'function:Convert-PointSpace' -Value { param($x, $y, $origin) return [pscustomobject]@{ X = [int]$x; Y = [int]$y } }
    Set-Item -Path 'function:Get-TargetBlockFacts' -Value { param($tgt) return $script:b2Facts }
    $b2NullOut = @(Invoke-TargetBlockGuard $null)
    ST-Check 'unit (B2): a bare-coordinate caller (null target) gets no guess and no output from the block guard' (
      @($b2NullOut).Count -eq 0)
    $script:b2Facts = @{ Alive = $true; Enabled = $false; Candidates = @($b2ModalCand) }
    $script:b2Moves = 0
    $b2RefErr = ''
    try { [void](Invoke-DesktopCommand 'click' @('10', '20', '--to', 'b2-fake')) } catch { $b2RefErr = "$($_.Exception.Message)" }
    ST-Check 'unit (B2): click with a blocked target refuses BEFORE any input and quotes the blocking window' (
      $b2RefErr.Contains('block guard') -and $b2RefErr.Contains('Save changes') -and ($script:b2Moves -eq 0))
    $script:b2Facts = @{ Alive = $true; Enabled = $true; Candidates = @() }
    $script:b2Moves = 0
    [void](Invoke-DesktopCommand 'click' @('10', '20', '--to', 'b2-fake'))
    ST-Check 'unit (B2): a clear target still reaches the click exactly once (the guard is not a blanket refusal)' (
      $script:b2Moves -eq 1)
  } finally {
    foreach ($b2n in $b2Names) { Set-Item -Path ("function:" + $b2n) -Value $b2Orig[$b2n] }
  }
  # The guard is only a contract if every command that CAN carry an explicit window identity
  # actually calls it. Bodies are read through the same command-ranges helper the rest of this
  # family uses, and the census counts LIVE lines only - a guard that somebody commented out
  # must read as missing (the planted pair proves the difference).
  $b2ClickCmds = @('click', 'rclick', 'dblclick', 'wheel', 'relclick', 'drag', 'drag-to', 'press-down', 'press-up', 'find-click', 'menu-pick', 'open-and-pick', 'imgclick')
  $b2Missing = @()
  $b2Sites = 0
  foreach ($b2c in $b2ClickCmds) {
    $b2t = Get-CommandCodeText $codeLines $b2c
    $b2live = @(@($b2t -split "`n") | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains('Invoke-TargetBlockGuard') })
    $b2Sites += $b2live.Count
    if ($b2live.Count -eq 0) { $b2Missing += $b2c }
  }
  ST-Check 'lint (B2): every click-family command that can carry an explicit window identity calls the shared block guard' (
    (@($b2Missing).Count -eq 0) -and ($b2Sites -ge 13))
  if (@($b2Missing).Count -gt 0) { Write-Output ('      B2: block guard missing from ' + (@($b2Missing) -join ', ')) }
  Write-Output ('      B2 block-guard live call sites: ' + $b2Sites + ' across ' + @($b2ClickCmds).Count + ' commands')
  $b2Plant = ('  # Invoke-TargetBlockGuard 1' + "`n" + '  Invoke-TargetBlockGuard 2')
  $b2PlantLive = @(@($b2Plant -split "`n") | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains('Invoke-TargetBlockGuard') })
  ST-Check 'unit (B2): the census refuses a commented-out call and still sees the live one (the scan has teeth)' (
    (@($b2PlantLive).Count -eq 1))

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
  # R-06: after CU-REL-03 a wheel call cannot take '--at' without an explicit x/y scroll point, so
  # the live proof carries two numeric words between the amount and the selector. The bare-'--at'
  # line left above it is the deliberate refusal control (no input sent) and must not be counted
  # as the proof; both are pinned so neither halves can silently drift.
  $c44WheelLiveCall = @($codeLines | Where-Object { $_ -match '\$outWheel = & powershell .* wheel -3 \$cpx \$cpy --at ''DTX-ExpectProbe''' }).Count
  $c44WheelLiveRefusal = @($codeLines | Where-Object { $_ -match '\$outWheelNoXY = & powershell .* wheel -3 --at ''DTX-ExpectProbe''' }).Count
  ST-Check 'lint: live wheel proof executes exactly one coordinate-bearing DTX-ExpectProbe call plus one no-coordinate refusal control' ($c44WheelLiveCall -eq 1 -and $c44WheelLiveRefusal -eq 1)
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

  # ---------- D-2 (v4.6.13): the tile grid and the stitch that rebuilds it ----------
  # A region too wide for one capture is written as a set of 1:1 PNGs, one map per cell;
  # 'stitch' rebuilds the region from that set alone. Everything below is offline: a
  # synthetic 301x197 bitmap at a NEGATIVE screen origin stands in for the screen, and the
  # real Export-TileSet / sidecar / Get-StitchPlan / Convert-TileSetToBitmap path is driven
  # end to end - so "the stitch equals the whole capture" is measured on PNG bytes, not on
  # the plan that produced them. Every refusal below is run against a byte-copy of the
  # pristine set, so the only difference between green and red is the planted defect.
  $d2RX = 1000; $d2RY = -40; $d2W = 301; $d2H = 197
  $d2Root = Join-Path ([System.IO.Path]::GetTempPath()) ('dtx-d2-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  $d2DirA = Join-Path $d2Root 'a'
  $d2DirB = Join-Path $d2Root 'b'
  [void][System.IO.Directory]::CreateDirectory($d2DirA)
  [void][System.IO.Directory]::CreateDirectory($d2DirB)
  $d2Src = $null
  try {
    $d2Src = New-Object System.Drawing.Bitmap($d2W, $d2H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $d2Fd = $d2Src.LockBits((New-Object System.Drawing.Rectangle 0, 0, $d2W, $d2H), [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $d2Row = New-Object byte[] ($d2W * 4)
      for ($d2yy = 0; $d2yy -lt $d2H; $d2yy++) {
        for ($d2xx = 0; $d2xx -lt $d2W; $d2xx++) {
          $d2o = $d2xx * 4
          $d2Row[$d2o] = [byte](($d2xx * 7 + $d2yy * 3) % 251)
          $d2Row[$d2o + 1] = [byte](($d2xx * 5 + $d2yy * 11) % 241)
          $d2Row[$d2o + 2] = [byte](($d2xx * 13 + $d2yy * 17) % 239)
          $d2Row[$d2o + 3] = 255
        }
        [System.Runtime.InteropServices.Marshal]::Copy($d2Row, 0, [IntPtr]::Add($d2Fd.Scan0, $d2yy * $d2Fd.Stride), $d2W * 4)
      }
    } finally { $d2Src.UnlockBits($d2Fd) }
    $d2Grab = { param($d2gx, $d2gy, $d2gw, $d2gh)
      $d2lx = [int]$d2gx - $d2RX; $d2ly = [int]$d2gy - $d2RY
      return $d2Src.Clone((New-Object System.Drawing.Rectangle $d2lx, $d2ly, ([int]$d2gw), ([int]$d2gh)), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    }
    $d2PngBytes = { param($d2bmp)
      $d2ms = New-Object System.IO.MemoryStream
      try { $d2bmp.Save($d2ms, [System.Drawing.Imaging.ImageFormat]::Png); return ,$d2ms.ToArray() } finally { $d2ms.Dispose() }
    }
    $d2ShaOf = { param([byte[]]$d2b)
      $d2hh = [System.Security.Cryptography.SHA256]::Create()
      try { return ([BitConverter]::ToString($d2hh.ComputeHash($d2b)) -replace '-', '').ToLower() } finally { $d2hh.Dispose() }
    }

    # --- the plan is ONE geometry, so both modes are pinned on numbers a reader can redo ---
    $d2PlanA = Get-TilePlan $d2RX $d2RY $d2W $d2H 'grid' 0 0 3 2 0
    $d2ATiles = @($d2PlanA.Tiles)
    $d2OutsideA = @($d2ATiles | Where-Object { $_.X -lt $d2RX -or $_.Y -lt $d2RY -or ($_.X + $_.W) -gt ($d2RX + $d2W) -or ($_.Y + $_.H) -gt ($d2RY + $d2H) })
    ST-Check 'unit (D-2): a --grid 3x2 plan over 301x197 strides 100x98, its last column/row absorb 101x99, and every cell stays inside the region' (
      $d2PlanA.Cols -eq 3 -and $d2PlanA.Rows -eq 2 -and $d2PlanA.StepX -eq 100 -and $d2PlanA.StepY -eq 98 -and
      $d2ATiles.Count -eq 6 -and (($d2PlanA.StepX * 2) + 101) -eq $d2W -and ($d2PlanA.StepY + 99) -eq $d2H -and
      @($d2ATiles | Where-Object { $_.C -eq 2 -and $_.W -eq 101 }).Count -eq 2 -and
      @($d2ATiles | Where-Object { $_.R -eq 1 -and $_.H -eq 99 }).Count -eq 3 -and
      @($d2ATiles | Where-Object { $_.C -eq 1 -and $_.X -eq ($d2RX + 100) }).Count -eq 2 -and
      @($d2ATiles | Where-Object { $_.R -eq 1 -and $_.Y -eq ($d2RY + 98) }).Count -eq 3 -and
      $d2OutsideA.Count -eq 0)
    $d2PlanB = Get-TilePlan $d2RX $d2RY $d2W $d2H 'tile' 120 80 0 0 20
    $d2BTiles = @($d2PlanB.Tiles)
    ST-Check 'unit (D-2): a --tile 120x80 plan with --overlap 20 strides 100x60 into 3x3 cells whose last column/row absorb 101x77 and whose shared strips really exist' (
      $d2PlanB.Cols -eq 3 -and $d2PlanB.Rows -eq 3 -and $d2PlanB.StepX -eq 100 -and $d2PlanB.StepY -eq 60 -and
      $d2BTiles.Count -eq 9 -and $d2PlanB.StepX -lt 120 -and $d2PlanB.StepY -lt 80 -and
      @($d2BTiles | Where-Object { $_.C -eq 2 -and $_.W -eq 101 }).Count -eq 3 -and
      @($d2BTiles | Where-Object { $_.R -eq 2 -and $_.H -eq 77 }).Count -eq 3 -and
      @($d2BTiles | Where-Object { $_.C -le 1 -and $_.W -eq 120 }).Count -eq 6)

    # --- the handler's own refusals happen BEFORE the first screen read ---
    $d2H1 = ''
    try { [void](Invoke-Handler-tile 'tile' @('0', '0', '10', '10', '--tile', '5x5', '--grid', '2x2', '--out-dir', $d2DirA)) } catch { $d2H1 = $_.Exception.Message }
    $d2H2 = ''
    try { [void](Invoke-Handler-tile 'tile' @('0', '0', '10', '10', '--out-dir', $d2DirA)) } catch { $d2H2 = $_.Exception.Message }
    $d2H3 = ''
    try { [void](Invoke-Handler-tile 'tile' @('0', '0', '10', '10', '--tile', '5x5')) } catch { $d2H3 = $_.Exception.Message }
    ST-Check 'unit (D-2): tile refuses two plans, no plan, and a missing destination BEFORE it touches the screen' (
      $d2H1.Contains('describe two different plans') -and $d2H2.Contains('exactly one plan is required') -and $d2H3.Contains('--out-dir is required'))
    $d2H4 = ''
    try { [void](Invoke-Handler-tile 'tile' @('0', '0', '10', '10', '--tile', '5by5', '--out-dir', $d2DirA)) } catch { $d2H4 = $_.Exception.Message }
    ST-Check 'unit (D-2): a plan spelled without the separator is refused by name, never read as five zero-size tiles' (
      $d2H4.Contains('--tile expects <number>x<number>') -and $d2H4.Contains('5by5'))
    $d2P1 = ''
    try { [void](Get-TilePlan 0 0 0 10 'grid' 0 0 2 2 0) } catch { $d2P1 = $_.Exception.Message }
    $d2P2 = ''
    try { [void](Get-TilePlan 0 0 10 10 'grid' 0 0 2 2 10) } catch { $d2P2 = $_.Exception.Message }
    $d2P3 = ''
    try { [void](Get-TilePlan 0 0 300 200 'tile' 50 50 0 0 50) } catch { $d2P3 = $_.Exception.Message }
    ST-Check 'unit (D-2): the planner refuses an empty region and an overlap that leaves no room - against the region and against the tile size' (
      $d2P1.Contains('at least 1x1') -and $d2P2.Contains('stay below both region dimensions') -and $d2P3.Contains('below the --tile size'))
    $d2P4 = ''
    try { [void](Get-TilePlan 0 0 100 100 'grid' 0 0 400 1 0) } catch { $d2P4 = $_.Exception.Message }
    $d2P5 = ''
    try { [void](Get-TilePlan 0 0 300 200 'grid' 0 0 40 20 0) } catch { $d2P5 = $_.Exception.Message }
    ST-Check 'unit (D-2): a grid denser than the region allows and a plan above the 400-image cap are refused with the numbers printed' (
      $d2P4.Contains('denser than the 100x100 region allows') -and $d2P5.Contains('800') -and $d2P5.Contains('cap is 400 images per set'))

    # --- round trip: the stitched bytes must equal the direct whole capture ---
    $d2TilesA = @(Export-TileSet $d2PlanA $d2DirA 'd2a' $d2Grab)
    $d2StitchA = Get-StitchPlan $d2DirA
    $d2BmpA = Convert-TileSetToBitmap $d2StitchA
    try { $d2BytesA = & $d2PngBytes $d2BmpA } finally { $d2BmpA.Dispose() }
    $d2WholeBmp = $d2Src.Clone((New-Object System.Drawing.Rectangle 0, 0, $d2W, $d2H), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try { $d2BytesWhole = & $d2PngBytes $d2WholeBmp } finally { $d2WholeBmp.Dispose() }
    $d2ShaA = & $d2ShaOf ([byte[]]$d2BytesA)
    $d2ShaWhole = & $d2ShaOf ([byte[]]$d2BytesWhole)
    $d2OrderA = (@($d2StitchA.Tiles | ForEach-Object { [string]$_.C + ',' + [string]$_.R }) -join ';')
    ST-Check 'unit (D-2): a 3x2 no-overlap set stitches back to BYTES identical to the direct whole capture (PNG SHA-256 equality, row-major order)' (
      $d2TilesA.Count -eq 6 -and @($d2StitchA.Tiles).Count -eq 6 -and
      $d2ShaA -match '^[0-9a-f]{64}$' -and $d2ShaA -ceq $d2ShaWhole -and
      $d2ShaWhole -cne ([string]$d2TilesA[0].Sha) -and
      $d2OrderA -ceq '0,0;1,0;2,0;0,1;1,1;2,1')
    $d2TilesB = @(Export-TileSet $d2PlanB $d2DirB 'd2b' $d2Grab)
    $d2StitchB = Get-StitchPlan $d2DirB
    $d2BmpB = Convert-TileSetToBitmap $d2StitchB
    try { $d2BytesB = & $d2PngBytes $d2BmpB } finally { $d2BmpB.Dispose() }
    $d2ShaB = & $d2ShaOf ([byte[]]$d2BytesB)
    ST-Check 'unit (D-2): a --overlap 20 set also rebuilds the region byte-exactly - shared strips are cropped by ownership, never averaged' (
      $d2TilesB.Count -eq 9 -and $d2ShaB -ceq $d2ShaWhole -and $d2ShaB -cne ([string]$d2TilesB[0].Sha) -and
      @($d2StitchB.Tiles | Where-Object { $_.W -gt $d2PlanB.StepX }).Count -eq 9)

    # --- unmap on a tile is a GLOBAL answer: 12 corners, tile output vs whole-image output ---
    $d2WholePath = Join-Path $d2Root 'whole.png'
    Write-MapSidecar $d2WholePath $d2RX $d2RY 1.0 $d2W $d2H 'rect' $null 0 $null $d2ShaWhole
    [System.IO.File]::WriteAllBytes($d2WholePath, [byte[]]$d2BytesWhole)
    $d2UmBad = New-Object System.Collections.ArrayList
    $d2UmPairs = 0
    foreach ($d2t in @($d2StitchA.Tiles)) {
      foreach ($d2lp in @(@(0, 0), @(([int]$d2t.W - 1), ([int]$d2t.H - 1)))) {
        $d2lx = [int]$d2lp[0]; $d2ly = [int]$d2lp[1]
        $d2gx = [int]$d2t.X + $d2lx; $d2gy = [int]$d2t.Y + $d2ly
        $d2tl = @(Invoke-Handler-unmap 'unmap' @([string]$d2t.Path, [string]$d2lx, [string]$d2ly))
        $d2wl = @(Invoke-Handler-unmap 'unmap' @($d2WholePath, [string]($d2gx - $d2RX), [string]($d2gy - $d2RY)))
        $d2UmPairs = $d2UmPairs + 1
        $d2tm = [regex]::Match([string]$d2tl[0], '-> screen \((-?\d+),(-?\d+)\)')
        $d2wm = [regex]::Match([string]$d2wl[0], '-> screen \((-?\d+),(-?\d+)\)')
        if (-not $d2tm.Success -or -not $d2wm.Success) { [void]$d2UmBad.Add('no screen clause for c' + $d2t.C + ' r' + $d2t.R); continue }
        if ([int]$d2tm.Groups[1].Value -ne $d2gx -or [int]$d2tm.Groups[2].Value -ne $d2gy) {
          [void]$d2UmBad.Add('tile c' + $d2t.C + ' r' + $d2t.R + ' -> ' + $d2tm.Value + ' want ' + $d2gx + ',' + $d2gy)
        }
        if ([string]$d2tm.Value -cne [string]$d2wm.Value) {
          [void]$d2UmBad.Add('tile c' + $d2t.C + ' r' + $d2t.R + ' disagrees with the whole image at ' + $d2gx + ',' + $d2gy)
        }
      }
    }
    ST-Check 'unit (D-2): unmap on EVERY tile prints the GLOBAL screen point and agrees with the whole image at the same pixel (12 corner pairs)' (
      $d2UmPairs -eq 12 -and @($d2UmBad).Count -eq 0)

    # --- planted defects: each case dir is a byte-copy of the set that just stitched ---
    $d2DirC = Join-Path $d2Root 'c1'
    [void][System.IO.Directory]::CreateDirectory($d2DirC)
    Get-ChildItem -LiteralPath $d2DirA -File | Copy-Item -Destination $d2DirC
    Remove-Item -LiteralPath (Join-Path $d2DirC 'tile_d2a_r1_c1.png') -Force
    Remove-Item -LiteralPath (Join-Path $d2DirC 'tile_d2a_r1_c1.png.map.txt') -Force
    $d2Miss = ''
    try { [void](Get-StitchPlan $d2DirC) } catch { $d2Miss = $_.Exception.Message }
    ST-Check 'unit (D-2): a set missing one cell is refused BY NAME (a partial set cannot be rebuilt honestly)' (
      $d2Miss.Contains('INCOMPLETE') -and $d2Miss.Contains('1 of 6') -and $d2Miss.Contains('c=1 r=1'))
    $d2DirC = Join-Path $d2Root 'c2'
    [void][System.IO.Directory]::CreateDirectory($d2DirC)
    Get-ChildItem -LiteralPath $d2DirA -File | Copy-Item -Destination $d2DirC
    Copy-Item -LiteralPath (Join-Path $d2DirC 'tile_d2a_r0_c0.png') -Destination (Join-Path $d2DirC 'dupe_r0_c0.png')
    Copy-Item -LiteralPath (Join-Path $d2DirC 'tile_d2a_r0_c0.png.map.txt') -Destination (Join-Path $d2DirC 'dupe_r0_c0.png.map.txt')
    $d2Dup = ''
    try { [void](Get-StitchPlan $d2DirC) } catch { $d2Dup = $_.Exception.Message }
    ST-Check 'unit (D-2): two files claiming the same cell are refused (one directory, one set)' (
      $d2Dup.Contains('two tiles claim c=0 r=0'))
    $d2DirC = Join-Path $d2Root 'c3'
    [void][System.IO.Directory]::CreateDirectory($d2DirC)
    Get-ChildItem -LiteralPath $d2DirA -File | Copy-Item -Destination $d2DirC
    $d2NoisePath = Join-Path $d2DirC 'noise.png'
    [System.IO.File]::WriteAllBytes($d2NoisePath, [byte[]]$d2BytesWhole)
    Write-MapSidecar $d2NoisePath $d2RX $d2RY 1.0 $d2W $d2H 'rect' $null 0 $null $d2ShaWhole
    $d2St3 = Get-StitchPlan $d2DirC
    $d2Ign = @($d2St3.Ignored)
    ST-Check 'unit (D-2): a foreign map in the folder is ignored AND named, and the tile set still stitches (a shared folder stays usable)' (
      @($d2St3.Tiles).Count -eq 6 -and $d2Ign.Count -eq 1 -and ([string]$d2Ign[0]).Contains('noise.png') -and
      ([string]$d2Ign[0]).Contains('kind=rect') -and @($d2StitchA.Ignored).Count -eq 0)
    $d2DirC = Join-Path $d2Root 'c4'
    [void][System.IO.Directory]::CreateDirectory($d2DirC)
    Get-ChildItem -LiteralPath $d2DirA -File | Copy-Item -Destination $d2DirC
    $d2MisPath = Join-Path $d2DirC 'tile_d2a_r0_c1.png.map.txt'
    $d2MisTxt = [System.IO.File]::ReadAllText($d2MisPath, [System.Text.Encoding]::UTF8)
    $d2MisTxt = $d2MisTxt -replace '(?m)^origin_x=1100\r?$', ("origin_x=1101" + "`r")
    [System.IO.File]::WriteAllText($d2MisPath, $d2MisTxt, (New-Object System.Text.UTF8Encoding($false)))
    $d2Mis = ''
    try { [void](Get-StitchPlan $d2DirC) } catch { $d2Mis = $_.Exception.Message }
    ST-Check 'unit (D-2): a tile whose origin is not where its own grid says is refused - the sidecar and the grid must agree' (
      $d2Mis.Contains('does not sit where its own grid says') -and $d2Mis.Contains('r0_c1'))
    $d2DirC = Join-Path $d2Root 'c5'
    [void][System.IO.Directory]::CreateDirectory($d2DirC)
    Get-ChildItem -LiteralPath $d2DirA -File | Copy-Item -Destination $d2DirC
    $d2NgPath = Join-Path $d2DirC 'tile_d2a_r0_c0.png.map.txt'
    $d2NgTxt = [System.IO.File]::ReadAllText($d2NgPath, [System.Text.Encoding]::UTF8)
    $d2NgTxt = ((@($d2NgTxt -split "`r?`n") | Where-Object { $_ -notmatch '^(tile_|region_)' }) -join "`r`n")
    [System.IO.File]::WriteAllText($d2NgPath, $d2NgTxt, (New-Object System.Text.UTF8Encoding($false)))
    $d2Ng = ''
    try { [void](Read-MapSidecar (Join-Path $d2DirC 'tile_d2a_r0_c0.png')) } catch { $d2Ng = $_.Exception.Message }
    ST-Check 'unit (D-2): a kind=tile map stripped of its grid is refused at the one chokepoint every reader passes' (
      $d2Ng.Contains('kind=tile without its grid'))
  } finally {
    if ($null -ne $d2Src) { $d2Src.Dispose() }
    try { if (Test-Path -LiteralPath $d2Root) { Remove-Item -LiteralPath $d2Root -Recurse -Force } } catch { }
  }

  # ---------- D-4 (v4.6.13): grid denoise - planned geometry, three styles, text boxes kept clear ----------
  # The grid used to be drawn by a loop with its arithmetic inline. It is now PLANNED by one pure
  # function, RENDERED by one function, and the text it must not swallow is read off the same 1:1
  # frame by the OCR road the tool already ships. Everything below is offline: planner and
  # renderer run on synthetic bitmaps, and the single OCR leg runs on a rendered fixture through
  # Invoke-OcrFile - no window, no desktop, no screen. Every "the feature is on" claim below has
  # the matching "feature off" measurement beside it, so a renderer that ignored the plan fails.
  $d4Styles = @('thin', 'bold', 'contrast')
  $d4Specs = @($d4Styles | ForEach-Object { Get-GridStyleSpec $_ })
  $d4Widths = @($d4Specs | ForEach-Object { [int]$_.Width })
  $d4Alphas = @($d4Specs | ForEach-Object { [int]$_.Alpha })
  $d4BadStyle = ''
  try { [void](Get-GridStyleSpec 'wobbly') } catch { $d4BadStyle = $_.Exception.Message }
  ST-Check 'unit (D-4): the three grid styles resolve to three DIFFERENT line widths with rising opacity, and a fourth name is refused by name (never silently rendered as thin)' (
    ($d4Widths.Count -eq 3) -and (@($d4Widths | Sort-Object -Unique).Count -eq 3) -and
    ($d4Alphas[0] -lt $d4Alphas[1]) -and ($d4Alphas[1] -lt $d4Alphas[2]) -and
    ($d4BadStyle.Contains('thin|bold|contrast')) -and ($d4BadStyle.Contains('wobbly')))
  if (-not (($d4Widths.Count -eq 3) -and (@($d4Widths | Sort-Object -Unique).Count -eq 3))) {
    Write-Output ('      D-4 styles: widths=[' + ($d4Widths -join ',') + '] alphas=[' + ($d4Alphas -join ',') + '] refusal=[' + $d4BadStyle + ']')
  }
  # The planner is a refactor of a loop whose behaviour is the contract: with nothing to avoid it
  # must reproduce that loop EXACTLY - the same round-screen labels, the same image index for each,
  # and one full run per line. The expected lists are recomputed here from the OLD formula (not
  # read back out of the planner), so dropping the screen->image arithmetic turns this red.
  $d4LegRect = @{ X = 1000; Y = -40; W = 301; H = 197 }
  $d4Plan0 = New-GridOverlayPlan 301 197 $d4LegRect 1.0 50 'thin' @()
  $d4LegV = @(); $d4LegH = @()
  $d4sx = [int]([math]::Ceiling($d4LegRect.X / 50) * 50)
  while ($d4sx -le ($d4LegRect.X + $d4LegRect.W)) {
    $d4ix = [int][math]::Round(($d4sx - $d4LegRect.X) * 1.0)
    if ($d4ix -ge 0 -and $d4ix -lt 301) { $d4LegV += ("$d4sx@$d4ix") }
    $d4sx += 50
  }
  $d4sy = [int]([math]::Ceiling($d4LegRect.Y / 50) * 50)
  while ($d4sy -le ($d4LegRect.Y + $d4LegRect.H)) {
    $d4iy = [int][math]::Round(($d4sy - $d4LegRect.Y) * 1.0)
    if ($d4iy -ge 0 -and $d4iy -lt 197) { $d4LegH += ("$d4sy@$d4iy") }
    $d4sy += 50
  }
  $d4GotV = @(@($d4Plan0.Lines) | Where-Object { $_.Vertical } | ForEach-Object { "$($_.Sx)@$($_.Ix)" })
  $d4GotH = @(@($d4Plan0.Lines) | Where-Object { -not $_.Vertical } | ForEach-Object { "$($_.Sy)@$($_.Iy)" })
  # the same screen values through a 0.7 --fit: the LAST column must fall off the same way the
  # old loop's ($ix -lt $iw) test dropped it (ix=210 on a 210px image), which is the seam most
  # likely to be lost when the loop is re-expressed.
  $d4FitRect = @{ X = 1000; Y = -40; W = 300; H = 200 }
  $d4Plan1 = New-GridOverlayPlan 210 140 $d4FitRect 0.7 50 'thin' @()
  $d4FitV = @()
  $d4sx = [int]([math]::Ceiling($d4FitRect.X / 50) * 50)
  while ($d4sx -le ($d4FitRect.X + $d4FitRect.W)) {
    $d4ix = [int][math]::Round(($d4sx - $d4FitRect.X) * 0.7)
    if ($d4ix -ge 0 -and $d4ix -lt 210) { $d4FitV += ("$d4sx@$d4ix") }
    $d4sx += 50
  }
  $d4GotFit = @(@($d4Plan1.Lines) | Where-Object { $_.Vertical } | ForEach-Object { "$($_.Sx)@$($_.Ix)" })
  $d4BadRuns = @(@($d4Plan0.Lines) | Where-Object {
      $sg = @($_.Segs)
      if ($_.Vertical) { return ($sg.Count -ne 1) -or ($sg[0].A -ne 0) -or ($sg[0].B -ne 197) }
      return ($sg.Count -ne 1) -or ($sg[0].A -ne 0) -or ($sg[0].B -ne 301)
    })
  $d4BadLabels = @(@($d4Plan0.Lines) | Where-Object { $_.Vertical -and ([string]$_.Label -ne "$($_.Sx)") })
  ST-Check 'unit (D-4): with nothing to avoid, the planner reproduces the pre-D-4 loop exactly - same screen labels, same image index per line (1:1 AND --fit, including the last column it drops), one full run each' (
    (($d4LegV -join ',') -ceq ($d4GotV -join ',')) -and (($d4LegH -join ',') -ceq ($d4GotH -join ',')) -and
    (($d4FitV -join ',') -ceq ($d4GotFit -join ',')) -and (@($d4BadRuns).Count -eq 0) -and
    (@($d4BadLabels).Count -eq 0) -and ($d4LegV.Count -eq 7) -and ($d4LegH.Count -eq 4) -and ($d4FitV.Count -eq 6))
  if ((($d4LegV -join ',') -cne ($d4GotV -join ',')) -or (($d4FitV -join ',') -cne ($d4GotFit -join ','))) {
    Write-Output ('      D-4 legacy geometry: want-v=[' + ($d4LegV -join ',') + '] got-v=[' + ($d4GotV -join ',') + '] want-fit=[' + ($d4FitV -join ',') + '] got-fit=[' + ($d4GotFit -join ',') + ']')
  }
  # The avoidance rule is containment, not proximity: a box that does not span the line leaves it
  # whole, two boxes that overlap cost ONE seam, full coverage removes the line, and a label that
  # would sit on text is dropped (a moved label would name a coordinate the line is not at).
  # A text box is 2-D, so the one below cuts a vertical AND a horizontal line and Avoided counts
  # the LINES cut (2), not the boxes - both cuts are named here so the count stays explainable.
  $d4AvRect = @{ X = 0; Y = 0; W = 400; H = 200 }
  $d4BoxA = @{ X = 95; Y = 40; W = 11; H = 21 }
  $d4BoxB = @{ X = 95; Y = 55; W = 11; H = 31 }
  $d4BoxC = @{ X = 195; Y = -10; W = 11; H = 300 }
  $d4PlanA = New-GridOverlayPlan 400 200 $d4AvRect 1.0 50 'thin' @($d4BoxA)
  $d4PlanM = New-GridOverlayPlan 400 200 $d4AvRect 1.0 50 'thin' @($d4BoxA, $d4BoxB)
  $d4PlanC = New-GridOverlayPlan 400 200 $d4AvRect 1.0 50 'thin' @($d4BoxC)
  $d4LineA = @(@($d4PlanA.Lines) | Where-Object { $_.Vertical -and [int]$_.Ix -eq 100 })[0]
  $d4LineH = @(@($d4PlanA.Lines) | Where-Object { -not $_.Vertical -and [int]$_.Iy -eq 50 })[0]
  $d4LineX = @(@($d4PlanA.Lines) | Where-Object { $_.Vertical -and [int]$_.Ix -eq 150 })[0]
  $d4LineM = @(@($d4PlanM.Lines) | Where-Object { $_.Vertical -and [int]$_.Ix -eq 100 })[0]
  $d4LineC = @(@($d4PlanC.Lines) | Where-Object { $_.Vertical -and [int]$_.Ix -eq 200 })[0]
  $d4SegA = (@(@($d4LineA.Segs) | ForEach-Object { "$($_.A)-$($_.B)" }) -join ',')
  $d4SegH = (@(@($d4LineH.Segs) | ForEach-Object { "$($_.A)-$($_.B)" }) -join ',')
  $d4SegX = (@(@($d4LineX.Segs) | ForEach-Object { "$($_.A)-$($_.B)" }) -join ',')
  $d4SegM = (@(@($d4LineM.Segs) | ForEach-Object { "$($_.A)-$($_.B)" }) -join ',')
  $d4SegC = (@(@($d4LineC.Segs) | ForEach-Object { "$($_.A)-$($_.B)" }) -join ',')
  $d4LblPlan = New-GridOverlayPlan 400 200 $d4AvRect 1.0 50 'thin' @(@{ X = 145; Y = 0; W = 40; H = 20 })
  $d4LblDropped = @(@($d4LblPlan.Lines) | Where-Object { $_.Vertical -and [int]$_.Ix -eq 150 })[0]
  $d4LblKept = @(@($d4LblPlan.Lines) | Where-Object { $_.Vertical -and [int]$_.Ix -eq 100 })[0]
  $d4Ok3 = ($d4SegA -ceq '0-37,63-200') -and ($d4SegH -ceq '0-92,108-400') -and ($d4SegX -ceq '0-200') -and
    ($d4SegM -ceq '0-37,88-200') -and ($d4SegC -ceq '') -and ([int]$d4PlanC.Avoided -eq 5) -and
    ([int]$d4PlanA.Avoided -eq 2) -and ([int]$d4LblPlan.LabelsDropped -eq 1) -and
    ([string]$d4LblDropped.Label -eq '') -and ([string]$d4LblKept.Label -ceq '100')
  ST-Check 'unit (D-4): a text box splits the one line it covers into two runs (and the horizontal line it also crosses), a second overlapping box merges into ONE seam, a box that misses the line changes nothing, full coverage leaves no run, and a label that would sit on text is dropped' $d4Ok3
  if (-not $d4Ok3) {
    Write-Output ('      D-4 segments: v=[' + $d4SegA + '] h=[' + $d4SegH + '] miss=[' + $d4SegX + '] merged=[' + $d4SegM + '] full=[' + $d4SegC + '] avoidedA=' + [int]$d4PlanA.Avoided + ' avoidedC=' + [int]$d4PlanC.Avoided + ' dropped=' + [int]$d4LblPlan.LabelsDropped + ' droppedLabel=[' + [string]$d4LblDropped.Label + '] keptLabel=[' + [string]$d4LblKept.Label + ']')
  }
  # The promise is pixel-level: a box the planner was told to keep clear is BYTE-identical to the
  # same image with no grid at all, while the line still exists immediately above and below that
  # gap. The empty-avoid draw is the planted "avoidance disabled" control - same renderer, same
  # geometry, and the box gets painted over.
  $d4PxW = 200; $d4PxH = 120
  $d4PxRect = @{ X = 0; Y = 0; W = 200; H = 120 }
  $d4PxBox = @{ X = 40; Y = 50; W = 41; H = 11 }
  $d4Base = New-Object System.Drawing.Bitmap($d4PxW, $d4PxH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $d4Keep = $null; $d4NoAv = $null
  try {
    $d4gb = [System.Drawing.Graphics]::FromImage($d4Base)
    $d4gb.Clear([System.Drawing.Color]::White); $d4gb.Dispose()
    $d4Keep = $d4Base.Clone()
    $d4gk = [System.Drawing.Graphics]::FromImage($d4Keep)
    $d4Pk = New-GridOverlayPlan $d4PxW $d4PxH $d4PxRect 1.0 50 'thin' @($d4PxBox)
    Draw-GridOverlay $d4gk $d4Pk
    $d4gk.Dispose()
    $d4NoAv = $d4Base.Clone()
    $d4gn = [System.Drawing.Graphics]::FromImage($d4NoAv)
    Draw-GridOverlay $d4gn (New-GridOverlayPlan $d4PxW $d4PxH $d4PxRect 1.0 50 'thin' @())
    $d4gn.Dispose()
    $d4InsideSame = 0; $d4InsideDiff = 0; $d4NoAvDiff = 0
    for ($d4yy = 50; $d4yy -lt 61; $d4yy++) {
      for ($d4xx = 40; $d4xx -lt 81; $d4xx++) {
        $d4c0 = $d4Base.GetPixel($d4xx, $d4yy).ToArgb()
        if ($d4Keep.GetPixel($d4xx, $d4yy).ToArgb() -eq $d4c0) { $d4InsideSame++ } else { $d4InsideDiff++ }
        if ($d4NoAv.GetPixel($d4xx, $d4yy).ToArgb() -ne $d4c0) { $d4NoAvDiff++ }
      }
    }
    $d4LineAbove = 0; $d4LineBelow = 0; $d4GapClean = 0
    for ($d4yy = 30; $d4yy -le 47; $d4yy++) { if ($d4Keep.GetPixel(50, $d4yy).ToArgb() -ne $d4Base.GetPixel(50, $d4yy).ToArgb()) { $d4LineAbove++ } }
    for ($d4yy = 63; $d4yy -le 80; $d4yy++) { if ($d4Keep.GetPixel(50, $d4yy).ToArgb() -ne $d4Base.GetPixel(50, $d4yy).ToArgb()) { $d4LineBelow++ } }
    for ($d4yy = 48; $d4yy -le 62; $d4yy++) { if ($d4Keep.GetPixel(50, $d4yy).ToArgb() -eq $d4Base.GetPixel(50, $d4yy).ToArgb()) { $d4GapClean++ } }
    $d4RowGapClean = 0
    for ($d4xx = 38; $d4xx -le 82; $d4xx++) { if ($d4Keep.GetPixel($d4xx, 50).ToArgb() -eq $d4Base.GetPixel($d4xx, 50).ToArgb()) { $d4RowGapClean++ } }
    $d4Ok4 = ($d4InsideSame -eq 451) -and ($d4InsideDiff -eq 0) -and ($d4NoAvDiff -gt 0) -and
      ($d4LineAbove -eq 18) -and ($d4LineBelow -eq 18) -and ($d4GapClean -eq 15) -and ($d4RowGapClean -eq 45)
    ST-Check 'unit (D-4): a planned gap leaves every pixel of the text box untouched while the line survives above and below it, and the same plan with an EMPTY avoid list paints over that box (planted control)' $d4Ok4
    if (-not $d4Ok4) {
      Write-Output ('      D-4 pixels: inside-same=' + $d4InsideSame + ' inside-diff=' + $d4InsideDiff + ' noavoid-diff=' + $d4NoAvDiff + ' above=' + $d4LineAbove + ' below=' + $d4LineBelow + ' gap=' + $d4GapClean + ' rowgap=' + $d4RowGapClean)
    }
  } finally {
    if ($null -ne $d4Keep) { $d4Keep.Dispose() }
    if ($null -ne $d4NoAv) { $d4NoAv.Dispose() }
    $d4Base.Dispose()
  }
  # "Three styles" has to mean three MEASURED widths, not three names. Each style paints ONE
  # vertical line on an identical white bitmap and the changed columns plus the centre pixel are
  # read back. A renderer that ignored the style table would report 1px and alpha-140 three times.
  $d4MsRect = @{ X = 30; Y = 30; W = 100; H = 100 }
  $d4Meas = @()
  foreach ($d4st in $d4Styles) {
    $d4bm = New-Object System.Drawing.Bitmap(200, 200, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $d4gm = [System.Drawing.Graphics]::FromImage($d4bm)
      $d4gm.Clear([System.Drawing.Color]::White)
      Draw-GridOverlay $d4gm (New-GridOverlayPlan 200 200 $d4MsRect 1.0 100 $d4st @())
      $d4gm.Dispose()
      $d4cols = @()
      for ($d4xx = 0; $d4xx -lt 200; $d4xx++) {
        if ($d4bm.GetPixel($d4xx, 30).ToArgb() -ne [System.Drawing.Color]::White.ToArgb()) { $d4cols += $d4xx }
      }
      $d4mid = $d4bm.GetPixel(70, 30)
      $d4Meas += [pscustomobject]@{ Style = $d4st; Cols = @($d4cols).Count; First = [int]$d4cols[0]; G = [int]$d4mid.G; B = [int]$d4mid.B }
    } finally { $d4bm.Dispose() }
  }
  $d4MeasTxt = (@($d4Meas | ForEach-Object { "$($_.Style)=$($_.Cols)px@$($_.First)/g$($_.G)" }) -join ' ')
  ST-Check 'unit (D-4): the three styles MEASURE 1/3/2 px on an identical synthetic capture and the centre pixel darkens from alpha 140 to 200 to fully opaque - the style table cannot be bypassed silently' (
    ($d4Meas[0].Cols -eq 1) -and ($d4Meas[1].Cols -eq 3) -and ($d4Meas[2].Cols -eq 2) -and
    ($d4Meas[0].First -eq 70) -and ($d4Meas[1].First -eq 69) -and ($d4Meas[2].First -eq 69) -and
    ($d4Meas[0].G -eq 115) -and ($d4Meas[1].G -eq 55) -and ($d4Meas[2].G -eq 0) -and ($d4Meas[2].B -eq 0))
  Write-Output ('      D-4 measured styles: ' + $d4MeasTxt)
  # The OCR leg is the blueprint's own criterion: a thin grid drawn with avoidance must not eat the
  # fixture's text. The fixture is real text, the avoid boxes come from the shipped reader
  # (Get-GridAvoidRects), and the check first proves the fixture forces a collision (2 fixture
  # lines, boxes >= 2 AND at least one planned line was cut) - otherwise equality would be
  # vacuous. No language pack: a named skip, never a green tick.
  $d4OcrPack = ''
  try { $d4Eng = Get-OcrEngine; if ($null -ne $d4Eng) { $d4OcrPack = "$($d4Eng.RecognizerLanguage.LanguageTag)" } } catch { $d4OcrPack = '' }
  $script:StRecord = New-Object System.Collections.ArrayList
  if ($d4OcrPack -eq '') {
    ST-SkipRegion 'grid-avoid' 'no OCR language pack / recognizer unreachable from this engine - the thin-vs-no-grid read cannot be measured, so this is not a regression'
  } else {
  # REGION-BEGIN grid-avoid  (one check; the skip branch emits the same name, so a machine
  # without a language pack moves the outcome but not the family total)
    $d4Fdir = Join-Path ([System.IO.Path]::GetTempPath()) ('dtx-d4-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    [void][System.IO.Directory]::CreateDirectory($d4Fdir)
    $d4Fbmp = $null; $d4Fgrid = $null
    $d4ReadPlain = @(); $d4ReadGrid = @(); $d4Fboxes = @(); $d4FCut = 0; $d4OcrErr = ''
    try {
      $d4Fbmp = New-Object System.Drawing.Bitmap(760, 170, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
      $d4Fg = [System.Drawing.Graphics]::FromImage($d4Fbmp)
      $d4Fg.Clear([System.Drawing.Color]::White)
      $d4Fg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
      $d4Ffnt = New-Object System.Drawing.Font('Consolas', 24, [System.Drawing.FontStyle]::Bold)
      $d4Fg.DrawString('DTXGRIDONE42', $d4Ffnt, [System.Drawing.Brushes]::Black, 12, 18)
      $d4Fg.DrawString('DTXGRIDTWO77', $d4Ffnt, [System.Drawing.Brushes]::Black, 12, 92)
      $d4Ffnt.Dispose(); $d4Fg.Dispose()
      $d4PngPlain = Join-Path $d4Fdir 'plain.png'
      $d4Fbmp.Save($d4PngPlain, [System.Drawing.Imaging.ImageFormat]::Png)
      $d4Fboxes = @((Get-GridAvoidRects $d4Fbmp 0 0).Rects)
      $d4Fgrid = $d4Fbmp.Clone()
      $d4Fg2 = [System.Drawing.Graphics]::FromImage($d4Fgrid)
      $d4Fplan = New-GridOverlayPlan 760 170 @{ X = 0; Y = 0; W = 760; H = 170 } 1.0 40 'thin' $d4Fboxes
      $d4FCut = [int]$d4Fplan.Avoided
      Draw-GridOverlay $d4Fg2 $d4Fplan
      $d4Fg2.Dispose()
      $d4PngGrid = Join-Path $d4Fdir 'grid.png'
      $d4Fgrid.Save($d4PngGrid, [System.Drawing.Imaging.ImageFormat]::Png)
      $d4ReadPlain = @(@((Invoke-OcrFile $d4PngPlain 1.0).Lines) | ForEach-Object { ([string]$_.Text).Trim() } | Where-Object { $_ })
      $d4ReadGrid = @(@((Invoke-OcrFile $d4PngGrid 1.0).Lines) | ForEach-Object { ([string]$_.Text).Trim() } | Where-Object { $_ })
    } catch { $d4OcrErr = "$($_.Exception.Message)" } finally {
      if ($null -ne $d4Fgrid) { $d4Fgrid.Dispose() }
      if ($null -ne $d4Fbmp) { $d4Fbmp.Dispose() }
      try { if (Test-Path -LiteralPath $d4Fdir) { Remove-Item -LiteralPath $d4Fdir -Recurse -Force } } catch { }
    }
    if ($d4OcrErr) {
      ST-SkipRegion 'grid-avoid' ("the grid-avoid OCR leg could not run on this machine: " + $d4OcrErr)
    } else {
      $d4PlainTxt = (@($d4ReadPlain) -join '|')
      $d4GridTxt = (@($d4ReadGrid) -join '|')
      # Every line the plain image read must come back from the gridded image VERBATIM and IN ORDER.
      # Exact list equality is not the criterion and cannot be: the grid's own coordinate labels are
      # text too, and the reader legitimately joins the label row into ONE extra line (measured and
      # printed below). Equality would go red on a correct grid; discarding the label row to make it
      # green would hide what the reader really returns. So the fixture's text is what is pinned, the
      # extra line is BOUNDED at one label row, and the fixture's own read is asserted first (two
      # lines, both DTXGRID...) so a fixture that failed to render cannot make this green.
      $d4SeqOk = $true; $d4SeqAt = 0; $d4GridN = @($d4ReadGrid).Count
      foreach ($d4Pl in @($d4ReadPlain)) {
        $d4Hit = -1
        for ($d4k = $d4SeqAt; $d4k -lt $d4GridN; $d4k++) { if ([string]$d4ReadGrid[$d4k] -ceq [string]$d4Pl) { $d4Hit = $d4k; break } }
        if ($d4Hit -lt 0) { $d4SeqOk = $false; break }
        $d4SeqAt = $d4Hit + 1
      }
      $d4PlainOk = (@($d4ReadPlain).Count -eq 2) -and (@(@($d4ReadPlain) | Where-Object { -not ([string]$_).StartsWith('DTXGRID') }).Count -eq 0)
      $d4Ok6 = (@($d4Fboxes).Count -ge 2) -and ($d4FCut -gt 0) -and $d4PlainOk -and $d4SeqOk -and
        (@($d4ReadGrid).Count -le (@($d4ReadPlain).Count + 1))
      ST-Check 'unit (D-4): OCR of a thin grid drawn with text avoidance still reads every line of the plain fixture verbatim and in order, the label row costs at most one extra line, and the fixture really forces collisions (2 fixture lines, >=2 text boxes, lines cut)' $d4Ok6
      Write-Output ('      D-4 ocr: pack=' + $d4OcrPack + ' boxes=' + @($d4Fboxes).Count + ' cut=' + $d4FCut + ' plain=[' + $d4PlainTxt + '] grid=[' + $d4GridTxt + ']')
    }
  # REGION-END grid-avoid
  }
  $d4OcrEmitted = @($script:StRecord)
  $script:StRecord = $null
  ST-ReconcileRegion 'grid-avoid' $d4OcrEmitted
  # The flag has to be REACHABLE and the two refusals have to happen through the real command
  # line: a bad style name is refused by the parser, and a style with no grid is refused before
  # a single pixel is grabbed. Neither may leave an image behind.
  $d4CliDir = Join-Path ([System.IO.Path]::GetTempPath()) ('dtx-d4cli-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  [void][System.IO.Directory]::CreateDirectory($d4CliDir)
  try {
    $d4Run = {
      param([string]$ArgLine, [string]$OutName)
      $o = Join-Path $d4CliDir $OutName
      $pr = Start-Process -FilePath 'powershell.exe' -ArgumentList $ArgLine -RedirectStandardOutput $o -RedirectStandardError "$o.err" -Wait -PassThru -NoNewWindow
      $txt = ''
      if (Test-Path -LiteralPath $o) { $txt += [IO.File]::ReadAllText($o) }
      if (Test-Path -LiteralPath "$o.err") { $txt += [IO.File]::ReadAllText("$o.err") }
      return @{ Exit = $pr.ExitCode; Txt = $txt }
    }
    $d4BadPng = Join-Path $d4CliDir 'bad-style.png'
    $d4Bad = & $d4Run ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" rect 0 0 40 40 "' + $d4BadPng + '" --grid 20 --fit 0 --grid-style wobbly') 'bad.txt'
    $d4NonePng = Join-Path $d4CliDir 'no-grid.png'
    $d4None = & $d4Run ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" rect 0 0 40 40 "' + $d4NonePng + '" --fit 0 --no-grid --grid-style thin') 'none.txt'
    ST-Check 'e2e (D-4): --grid-style is reachable through the real entry, a bad style name is refused by name and a style with no grid is refused BEFORE capture - neither leaves an image behind' (
      ($d4Bad.Exit -ne 0) -and ($d4Bad.Txt -match '--grid-style must be thin\|bold\|contrast') -and (-not (Test-Path -LiteralPath $d4BadPng)) -and
      ($d4None.Exit -ne 0) -and ($d4None.Txt -match '--grid-style only applies when a grid is actually drawn') -and (-not (Test-Path -LiteralPath $d4NonePng)))
    if (($d4Bad.Exit -eq 0) -or ($d4None.Exit -eq 0)) {
      Write-Output ('      D-4 e2e refusals: bad exit=' + $d4Bad.Exit + ' out=[' + $d4Bad.Txt + '] nogrid exit=' + $d4None.Exit + ' out=[' + $d4None.Txt + ']')
    }
    # and the positive leg: a real tiny capture with an explicit style carries style= AND the
    # avoid shape into the echo, and the sidecar keeps naming the step (imgclick's warning).
    # Nothing here asserts WHAT the screen showed - only that the flag travelled end to end.
    $d4OkPng = Join-Path $d4CliDir 'style-ok.png'
    $d4Ok = & $d4Run ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" rect 0 0 200 120 "' + $d4OkPng + '" --grid 50 --fit 0 --grid-style contrast') 'ok.txt'
    $d4OkMap = ''
    if (Test-Path -LiteralPath ($d4OkPng + '.map.txt')) { $d4OkMap = [IO.File]::ReadAllText($d4OkPng + '.map.txt') }
    ST-Check 'e2e (D-4): a real gridded capture carries style=contrast and the avoid= line into its echo, and the sidecar still names the grid step' (
      ($d4Ok.Exit -eq 0) -and ($d4Ok.Txt -match 'grid=50 style=contrast') -and ($d4Ok.Txt -match 'avoid=') -and
      (Test-Path -LiteralPath $d4OkPng) -and ($d4OkMap -match '(?m)^grid=50\r?$'))
    if (($d4Ok.Exit -ne 0) -or -not ($d4Ok.Txt -match 'grid=50 style=contrast')) {
      Write-Output ('      D-4 e2e positive: exit=' + $d4Ok.Exit + ' map=[grid]=' + ($d4OkMap -match '(?m)^grid=50\r?$') + ' out=[' + $d4Ok.Txt + ']')
    }
  } finally {
    try { if (Test-Path -LiteralPath $d4CliDir) { Remove-Item -LiteralPath $d4CliDir -Recurse -Force } } catch { }
  }
  # ---------- v4.8.0 (B-3): the grid note MEASURES this point's distance to the grid ----------
  # D-6 made every point on a gridded image carry the same "may sit on a line" sentence - the noise
  # shape this repo keeps retiring: a point 20px clear of every line read exactly like a point on
  # one. The note now measures per point (Resolve-GridProximity off the SAME overlay plan the
  # renderer drew), names BOTH units (image px and screen px, which differ whenever the capture was
  # downscaled), and only a caller-named margin can raise "near" when the map predates grid-style -
  # an unknown stroke width is reported as unknown, never guessed into a false "clear".
  $b3Dir = Join-Path ([System.IO.Path]::GetTempPath()) ('dtx-b3-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  [void][System.IO.Directory]::CreateDirectory($b3Dir)
  try {
    # (1) the near verdict flips at the STROKE WIDTH, and both sides of the flip are measured: a
    # thin line (1px, radius 0.5) claims only the pixel it covers, a bold line (3px, radius 1.5)
    # still claims a point 1px off, and one pixel further is CLEAR on both - so a radius that
    # silently became 0 or +inf cannot pass either branch. The points are chosen 25px clear of the
    # OTHER axis's lines, so the verdict is the tested axis's and not a coincidence of the min().
    $b3ThinOn = Resolve-GridProximity 50 75 50 1.0 0 0 'thin' -1.0 200 200
    $b3ThinOff = Resolve-GridProximity 51 75 50 1.0 0 0 'thin' -1.0 200 200
    $b3BoldOn = Resolve-GridProximity 51 75 50 1.0 0 0 'bold' -1.0 200 200
    $b3BoldOff = Resolve-GridProximity 52 75 50 1.0 0 0 'bold' -1.0 200 200
    ST-Check 'unit (B-3): the near verdict flips at the stroke width - a thin line claims only its own pixel (radius 0.5), a bold line still claims 1px off (radius 1.5), and one pixel further is CLEAR on both' (
      ([bool]$b3ThinOn.Near) -and (-not [bool]$b3ThinOff.Near) -and
      ([bool]$b3BoldOn.Near) -and (-not [bool]$b3BoldOff.Near) -and
      ([double]$b3ThinOn.Radius -eq 0.5) -and ([double]$b3BoldOn.Radius -eq 1.5) -and
      ([int]$b3ThinOn.LineWidth -eq 1) -and ([int]$b3BoldOn.LineWidth -eq 3))
    # (2) the two units are both real: at scale 0.5 the nearest line sits 1 IMAGE px away and 2
    # SCREEN px away, the resolver returns both, and the formatter names both in one sentence - a
    # note that printed only one number would be wrong in one of the two spaces a caller thinks in.
    $b3Half = Resolve-GridProximity 26 12 50 0.5 0 0 'thin' -1.0 200 100
    $b3HalfTxt = Format-GridProximity $b3Half 50 'thin'
    ST-Check 'unit (B-3): at scale 0.5 the same line is 1 image-px AND 2 screen-px away - both numbers are returned and the sentence names both, so neither unit is implied' (
      ([double]$b3Half.VDistPx -eq 1) -and ([double]$b3Half.VScreenPx -eq 2) -and
      ($b3HalfTxt.Contains('is 1 image-px = 2 screen-px away')))
    # (3) no grid drawn - no note at all: the proximity machinery is gridded-capture behaviour, and
    # a map without a grid has nothing to be near (the empty string keeps the echo unchanged).
    $b3NoGrid = Resolve-GridProximity 5 5 0 1.0 0 0 'thin' -1.0 100 100
    ST-Check 'unit (B-3): a sidecar with no grid short-circuits - Enabled=false and the formatter renders nothing, so a plain capture gains no sentence it never earned' (
      (-not [bool]$b3NoGrid.Enabled) -and ((Format-GridProximity $b3NoGrid 0 'thin') -ceq ''))
    # (4) an unknown stroke width is reported, not guessed: no style named means no radius and no
    # verdict unless the CALLER names a margin (--on-grid-alert), and the sentence says whose
    # number the alert-radius then is.
    $b3Unk = Resolve-GridProximity 50 75 50 1.0 0 0 'unknown' -1.0 200 200
    $b3UnkTxt = Format-GridProximity $b3Unk 50 'unknown'
    $b3UnkMargin = Resolve-GridProximity 52 75 50 1.0 0 0 'unknown' 3.0 200 200
    $b3UnkMarginTxt = Format-GridProximity $b3UnkMargin 50 'unknown'
    ST-Check 'unit (B-3): a map that predates grid-style yields distances with NO verdict (line width unknown, not guessed), and only a caller-named margin raises the alert - the sentence names that margin as the source' (
      (-not [bool]$b3Unk.StyleKnown) -and ([int]$b3Unk.LineWidth -eq -1) -and ([double]$b3Unk.Radius -eq -1) -and
      (-not [bool]$b3Unk.Near) -and
      ($b3UnkTxt.Contains('line-width=unknown (map predates grid-style; not guessed)')) -and
      ($b3UnkTxt.Contains('alert=not evaluated')) -and
      ([bool]$b3UnkMargin.Near) -and ([double]$b3UnkMargin.Radius -eq 3.0) -and
      ($b3UnkMarginTxt.Contains('--on-grid-alert only (line width unknown, not guessed)')))
    # (5) a gridded frame whose lines all fall outside the image says so instead of inventing a
    # nearest line (the formatter's no-lines branch is its own sentence, not the measured one).
    ST-Check 'unit (B-3): a grid whose lines never enter the image gets its own sentence - no distance is invented for a frame with no line in it' (
      ((Format-GridProximity @{ Enabled = $true; Reason = 'no-lines-in-image' } 50 'thin').Contains("carries no line inside this image's own bounds")))
    # (6) the style travels with the file and the OLD maps stay honest: a written sidecar carries
    # grid-style=bold back through the reader; a legacy sidecar WITHOUT the line reads as unknown
    # (never as thin); a style the renderer cannot produce is refused as damage; and the new field
    # coexists with the png_sha256 binding - a mismatched image is still refused with the style present.
    Add-Type -AssemblyName System.Drawing
    $b3Png = Join-Path $b3Dir 'b3.png'
    $b3Bm = New-Object System.Drawing.Bitmap(16, 16, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $b3G = [System.Drawing.Graphics]::FromImage($b3Bm)
    $b3G.Clear([System.Drawing.Color]::Gray)
    $b3G.Dispose()
    $b3Bm.Save($b3Png, [System.Drawing.Imaging.ImageFormat]::Png)
    $b3Bm.Dispose()
    $b3Sha = ''
    $b3ShaH = [System.Security.Cryptography.SHA256]::Create()
    try { $b3Fs = [System.IO.File]::OpenRead($b3Png); try { $b3Sha = ([System.BitConverter]::ToString($b3ShaH.ComputeHash($b3Fs))).Replace('-', '').ToLowerInvariant() } finally { $b3Fs.Dispose() } } finally { $b3ShaH.Dispose() }
    [void](Write-MapSidecar $b3Png 0 0 1.0 16 16 'rect' $null 50 $null $b3Sha $null 'bold')
    $b3Map = Read-MapSidecar $b3Png
    $b3LegacyPath = Join-Path $b3Dir 'b3-legacy.png'
    Copy-Item -LiteralPath $b3Png -Destination $b3LegacyPath
    $b3LegacyText = ("origin_x=0`r`norigin_y=0`r`nscale=1`r`nout_w=16`r`nout_h=16`r`nkind=rect`r`ngrid=50`r`n")
    [System.IO.File]::WriteAllText(($b3LegacyPath + '.map.txt'), $b3LegacyText, (New-Object System.Text.UTF8Encoding($false)))
    $b3LegacyMap = Read-MapSidecar $b3LegacyPath
    $b3BadPath = Join-Path $b3Dir 'b3-bad.png'
    Copy-Item -LiteralPath $b3Png -Destination $b3BadPath
    [System.IO.File]::WriteAllText(($b3BadPath + '.map.txt'), ($b3LegacyText + "grid-style=swirly`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    $b3BadErr = ''
    try { [void](Read-MapSidecar $b3BadPath) } catch { $b3BadErr = "$($_.Exception.Message)" }
    $b3SwapPath = Join-Path $b3Dir 'b3-swap.png'
    $b3Bm2 = New-Object System.Drawing.Bitmap(16, 16, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $b3G2 = [System.Drawing.Graphics]::FromImage($b3Bm2)
    $b3G2.Clear([System.Drawing.Color]::Black)
    $b3G2.Dispose()
    $b3Bm2.Save($b3SwapPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $b3Bm2.Dispose()
    Copy-Item -LiteralPath ($b3Png + '.map.txt') -Destination ($b3SwapPath + '.map.txt') -Force
    $b3SwapErr = ''
    try { [void](Read-MapSidecar $b3SwapPath) } catch { $b3SwapErr = "$($_.Exception.Message)" }
    ST-Check 'unit (B-3): grid-style round-trips through the sidecar writer and reader, a legacy map without the field reads unknown (never thin), a style the renderer cannot draw is refused as damage, and the field coexists with the png_sha256 binding (a swapped image is still refused)' (
      ([int]$b3Map.Grid -eq 50) -and ([string]$b3Map.GridStyle -ceq 'bold') -and
      (([System.IO.File]::ReadAllText($b3Png + '.map.txt')).Contains('grid-style=bold')) -and
      ([string]$b3LegacyMap.GridStyle -ceq 'unknown') -and
      ($b3BadErr.Contains("grid-style='swirly' is not unknown|thin|bold|contrast")) -and
      ($b3SwapErr.Contains('map sidecar describes a DIFFERENT image')) -and
      ([string]$b3Map.PngSha -ceq $b3Sha))
    # (7) end to end through the real handlers, no desktop: the legacy gridded pair prints both
    # distances and no verdict; the thin pair flips between CLEAR and ON as the point moves one
    # pixel across the line (both directions of the same move); and imgclick --dry with a caller
    # margin turns that legacy pair into a warning without any stroke width being guessed.
    $b3Big = Join-Path $b3Dir 'b3-big.png'
    $b3Bm3 = New-Object System.Drawing.Bitmap(200, 100, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $b3G3 = [System.Drawing.Graphics]::FromImage($b3Bm3)
    $b3G3.Clear([System.Drawing.Color]::White)
    $b3G3.Dispose()
    $b3Bm3.Save($b3Big, [System.Drawing.Imaging.ImageFormat]::Png)
    $b3Bm3.Dispose()
    $b3LegacyBigText = ("origin_x=0`r`norigin_y=0`r`nscale=1`r`nout_w=200`r`nout_h=100`r`nkind=rect`r`ngrid=50`r`n")
    [System.IO.File]::WriteAllText(($b3Big + '.map.txt'), $b3LegacyBigText, (New-Object System.Text.UTF8Encoding($false)))
    $b3UnmapEcho = @(Invoke-DesktopCommand 'unmap' @($b3Big, '52', '75')) -join "`n"
    [void](Write-MapSidecar $b3Big 0 0 1.0 200 100 'rect' $null 50 $null '' $null 'thin')
    $b3ClearEcho = @(Invoke-DesktopCommand 'unmap' @($b3Big, '52', '75')) -join "`n"
    $b3OnEcho = @(Invoke-DesktopCommand 'unmap' @($b3Big, '50', '75')) -join "`n"
    $b3DryEcho = @(Invoke-DesktopCommand 'imgclick' @($b3Big, '52', '75', '--dry', '--on-grid-alert', '3')) -join "`n"
    ST-Check 'e2e (B-3): the real unmap prints both units for a legacy map with NO verdict, the thin map flips CLEAR -> ON as the point crosses the line and back, and imgclick --dry with a caller margin alerts without guessing a stroke width' (
      ($b3UnmapEcho.Contains('line-width=unknown (map predates grid-style; not guessed)')) -and
      ($b3UnmapEcho.Contains('is 2 image-px = 2 screen-px away')) -and
      (-not $b3UnmapEcho.Contains('ON or beside a grid line')) -and
      ($b3ClearEcho.Contains('CLEAR of every grid line')) -and
      ($b3OnEcho.Contains('ON or beside a grid line')) -and
      ($b3DryEcho.Contains('ON or beside a grid line')) -and
      ($b3DryEcho.Contains('dry run') -or $b3DryEcho.Contains('[dry run]')))
  } finally {
    try { if (Test-Path -LiteralPath $b3Dir) { Remove-Item -LiteralPath $b3Dir -Recurse -Force } } catch { }
  }
  # ---------- v4.8.0 (C): the capture quality gate judges the 1:1 frame, and the re-capture loop is bounded ----------
  # The owner's two decisions live here: the gate NEVER runs unless --min-ink names a threshold
  # (a legal white canvas is a legal frame), and a refused frame publishes NOTHING - the loop
  # captures and measures only; the write path sits entirely outside it, so a same-name previous
  # pair stays byte-identical. The measurement runs on the 1:1 captured pixels (pre-fit, pre-grid,
  # pre-overlay). Every leg below is OFFLINE: the frames are synthetic bitmaps and the capture
  # step is an injected scriptblock (the seam Save-RectEx carries for exactly this), so nothing
  # here owns the desktop or guesses at a real screen.
  $cqDir = Join-Path ([System.IO.Path]::GetTempPath()) ('dtx-cq-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  [void][System.IO.Directory]::CreateDirectory($cqDir)
  try {
    Add-Type -AssemblyName System.Drawing
    # (1) the defaults and the grammar: the six flags parse into the capture table with the
    # documented defaults (gate OFF, mode reference, tolerance 24, whole frame, stride 1, no
    # retries), and every bound refuses BY NAME before any screen is read - the parse runs
    # pre-capture by construction, so a bad value can never cost a frame.
    $cqD = Parse-CaptureFlags @() $false
    $cqDefaultsOk = (([double]$cqD['MinInk'] -eq -1.0) -and ([string]$cqD['InkVs'] -ceq 'auto') -and ([int]$cqD['InkTol'] -eq 24) -and
      ($null -eq $cqD['InkArea']) -and ([int]$cqD['InkStride'] -eq 1) -and ([int]$cqD['Retry'] -eq 0) -and ([int]$cqD['RetryBudget'] -eq 0))
    $cqP = Parse-CaptureFlags @('--min-ink', '5.5', '--ink-vs', '#00FF7F', '--ink-tol', '9', '--ink-area', '3,4,50,60', '--ink-stride', '2', '--retry', '2', '--retry-budget', '500') $false
    $cqParsOk = (([double]$cqP['MinInk'] -eq 5.5) -and ([string]$cqP['InkVs'] -ceq '#00FF7F') -and ([int]$cqP['InkTol'] -eq 9) -and
      ((@($cqP['InkArea']) -join ',') -eq '3,4,50,60') -and ([int]$cqP['InkStride'] -eq 2) -and ([int]$cqP['Retry'] -eq 2) -and ([int]$cqP['RetryBudget'] -eq 500))
    $cqBad = @()
    foreach ($cqArg in @(@('--min-ink', '101'), @('--min-ink', 'abc'), @('--ink-tol', '256'), @('--ink-stride', '0'), @('--retry', '6'), @('--retry-budget', '600001'), @('--ink-vs', 'red'), @('--ink-area', '1,2,0,5'))) {
      $cqE = ''
      try { [void](Parse-CaptureFlags $cqArg $false) } catch { $cqE = "$($_.Exception.Message)" }
      if ($cqE -eq '') { $cqBad += ('accepted:' + ($cqArg -join ' ')) }
    }
    ST-Check 'unit (C): the quality flags default to gate-off with the documented values, parse into the capture table, and every out-of-range or malformed value is refused by name in the pre-capture parse (nothing costs a frame)' (
      $cqDefaultsOk -and $cqParsOk -and (@($cqBad).Count -eq 0))
    if (@($cqBad).Count -gt 0) { Write-Output ('      C parse gaps: ' + ($cqBad -join '; ')) }
    # synthetic frames: an all-white 200x100, and the same canvas with the RIGHT HALF inked
    # (red on white) - deterministic content the metric can be asserted against exactly.
    $cqWhite = New-Object System.Drawing.Bitmap(200, 100, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $cqGw = [System.Drawing.Graphics]::FromImage($cqWhite)
    $cqGw.Clear([System.Drawing.Color]::White)
    $cqGw.Dispose()
    $cqHalf = New-Object System.Drawing.Bitmap(200, 100, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $cqGh = [System.Drawing.Graphics]::FromImage($cqHalf)
    $cqGh.Clear([System.Drawing.Color]::White)
    $cqGh.FillRectangle([System.Drawing.Brushes]::Red, 100, 0, 100, 100)
    $cqGh.Dispose()
    # (2) the measurement on a legal white frame: auto resolves the reference to the frame's own
    # mode colour (echoed back), the measured ink is 0%, and the verdict belongs to the CALLER's
    # threshold - with no --min-ink the gate is off and a white frame is a legal frame.
    $cqSpecOff = New-CaptureQualityDefaults
    $cqW = Get-FrameInkQuality $cqWhite $cqSpecOff 10000
    ST-Check 'unit (C): a legal white frame measures ink 0% with the mode colour as the auto reference, and with the gate off (no --min-ink) it is a legal capture - nothing judges a blank canvas by default (the floor of -1 is met by every frame; the gate-off decision lives in Save-RectEx)' (
      ([double]$cqW.InkPct -eq 0) -and ($cqW.ModeColor -ceq '#FFFFFF') -and ([long]$cqW.ModeCount -eq 20000) -and
      ([long]$cqW.Sampled -eq 20000) -and ([bool]$cqW.Pass) -and ([string]$cqW.RefText).StartsWith('auto (mode #FFFFFF)'))
    Write-Output ('      C white measure: ink=' + $cqW.InkPct + '% mode=' + $cqW.ModeColor + ' count=' + $cqW.ModeCount + ' sampled=' + $cqW.Sampled + ' ref=' + $cqW.RefText + ' pass=' + $cqW.Pass)
    # (3) the reference decides what counts as ink: the SAME white frame measured against an
    # explicit #000000 reference is 100% ink - and the echo carries which reference was used.
    $cqSpecBlack = New-CaptureQualityDefaults
    $cqSpecBlack['MinInk'] = 5.0
    $cqSpecBlack['InkVs'] = '#000000'
    $cqWB = Get-FrameInkQuality $cqWhite $cqSpecBlack 10000
    ST-Check 'unit (C): the reference is what the caller named - a white frame against #000000 is 100% ink and passes a 5% threshold, with the echo naming the given colour' (
      ([double]$cqWB.InkPct -eq 100) -and ([bool]$cqWB.Pass) -and ([string]$cqWB.RefText -ceq '#000000'))
    # (4) the area and the stride are the caller's: the right half inked measures ~25% over the
    # whole frame, exactly 100% inside the inked --ink-area, and stride 2 quarters the sample
    # count without changing the verdict - the loop's echo prints sampled-of-total so the
    # denominator is never implied.
    $cqSpecHalf = New-CaptureQualityDefaults
    $cqSpecHalf['MinInk'] = 5.0
    $cqH = Get-FrameInkQuality $cqHalf $cqSpecHalf 10000
    $cqSpecArea = New-CaptureQualityDefaults
    $cqSpecArea['MinInk'] = 5.0
    $cqSpecArea['InkArea'] = @(100, 0, 100, 100)
    $cqHA = Get-FrameInkQuality $cqHalf $cqSpecArea 10000
    $cqSpecStride = New-CaptureQualityDefaults
    $cqSpecStride['MinInk'] = 5.0
    $cqSpecStride['InkStride'] = 2
    $cqHS = Get-FrameInkQuality $cqHalf $cqSpecStride 10000
    ST-Check 'unit (C): a half-inked frame measures 50% whole-frame and 100% inside the named --ink-area (the auto reference is the WHOLE frame mode, so a uniform area never measures against itself), stride 2 quarters the sampled count while the verdict holds, and the numbers carry their own denominator' (
      ([double]$cqH.InkPct -eq 50) -and ([double]$cqHA.InkPct -eq 100) -and ([string]$cqHA.AreaText -ceq '100,0,100x100') -and
      ([long]$cqHS.Sampled -eq 5000) -and ([double]$cqHS.InkPct -eq 50) -and ([bool]$cqH.Pass))
    Write-Output ('      C half measures: whole=' + $cqH.InkPct + '% area=' + $cqHA.InkPct + '% (' + $cqHA.AreaText + ') stride2=' + $cqHS.InkPct + '% sampled=' + $cqHS.Sampled + ' pass=' + $cqH.Pass)
    # (5) the measurement budget refuses to report a fraction it did not finish: a 1ms cap on a
    # frame big enough to exceed it comes back OverBudget with NO pass - budget-hit is a refusal,
    # never a number of unknown completeness.
    $cqBig = New-Object System.Drawing.Bitmap(4000, 3000, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $cqGb = [System.Drawing.Graphics]::FromImage($cqBig)
    $cqGb.Clear([System.Drawing.Color]::White)
    $cqGb.Dispose()
    $cqSpecBud = New-CaptureQualityDefaults
    $cqSpecBud['MinInk'] = 0.0
    $cqBud = Get-FrameInkQuality $cqBig $cqSpecBud 1
    $cqBig.Dispose()
    ST-Check 'unit (C): a measurement that hits its own budget reports OverBudget and no pass - a fraction of unknown completeness is never printed' (
      ([bool]$cqBud.OverBudget) -and (-not [bool]$cqBud.Pass))
    # (6) the bounded loop: a capture step that returns a white frame then the inked one passes on
    # attempt 2 and the lines name both attempts; a white-only step with retry 0 refuses naming
    # the knob; a slow step under a tiny budget refuses naming the budget - each refusal is a
    # throw, never a published file.
    $cqSeq = @($cqWhite, $cqHalf)
    $script:cqSeqIx = 0
    $cqStep = { param([int]$n) $f = $cqSeq[$script:cqSeqIx]; $script:cqSeqIx++; return $f.Clone() }
    $cqSpecLoop = New-CaptureQualityDefaults
    $cqSpecLoop['MinInk'] = 5.0
    $cqSpecLoop['Retry'] = 2
    $cqLoop = Invoke-BoundedCapture $cqStep $cqSpecLoop $null
    $cqWhiteOnly = { param([int]$n) return $cqWhite }
    $cqSpecRefuse = New-CaptureQualityDefaults
    $cqSpecRefuse['MinInk'] = 5.0
    $cqRefuseErr = ''
    try { [void](Invoke-BoundedCapture $cqWhiteOnly $cqSpecRefuse $null) } catch { $cqRefuseErr = "$($_.Exception.Message)" }
    $cqSlow = { param([int]$n) [void]([System.Threading.Thread]::Sleep(120)); return $cqWhite }
    $cqSpecBudget = New-CaptureQualityDefaults
    $cqSpecBudget['MinInk'] = 5.0
    $cqSpecBudget['Retry'] = 5
    $cqSpecBudget['RetryBudget'] = 40
    $cqBudgetErr = ''
    try { [void](Invoke-BoundedCapture $cqSlow $cqSpecBudget $null) } catch { $cqBudgetErr = "$($_.Exception.Message)" }
    ST-Check 'unit (C): the loop re-captures until the frame passes (attempt=1 below-threshold, attempt=2 pass), exhaustion refuses naming --retry and the last ink, and the time budget refuses naming --retry-budget - every refusal is a throw, never a file' (
      ([int]$cqLoop.Attempts -eq 2) -and ($cqLoop.Lines[0].Contains('attempt=1 ink=0%')) -and ($cqLoop.Lines[0].Contains('below-threshold')) -and
      ($cqLoop.Lines[1].Contains('attempt=2 ink=50%')) -and ($cqLoop.Lines[1].Contains('verdict=pass')) -and
      ($cqRefuseErr.Contains('refused after 1 attempt(s) (--retry 0)')) -and ($cqRefuseErr.Contains('last ink=0%')) -and
      ($cqRefuseErr.Contains('no PNG or map was written')) -and
      ($cqBudgetErr.Contains('refused on the time budget')) -and ($cqBudgetErr.Contains('--retry-budget 40 ms')))
    # (7) end to end through the REAL Save-RectEx with the capture step injected: the gate runs on
    # the 1:1 frame, the published PNG is the frame that PASSED (byte-compared against the second
    # frame's own encoding), and the echo carries the per-attempt lines plus the quality tail.
    $cqPath = Join-Path $cqDir 'cq-pass.png'
    $cqSpecSave = New-CaptureQualityDefaults
    $cqSpecSave['MinInk'] = 5.0
    $cqSpecSave['Retry'] = 2
    $script:cqSeqIx2 = 0
    $cqStep2 = { param([int]$n) $f = $cqSeq[$script:cqSeqIx2]; $script:cqSeqIx2++; return $f.Clone() }
    $cqSaveLines = Save-RectEx 0 0 200 100 $cqPath 0 -1 @() '' $null $null $cqSpecSave $null $cqStep2
    $cqSaveOut = (@($cqSaveLines) -join "`
")
    $cqSavedOk = $false
    if (Test-Path -LiteralPath $cqPath) {
      $cqSavedBytes = [System.IO.File]::ReadAllBytes($cqPath)
      $cqWant = New-Object System.IO.MemoryStream
      try { $cqHalf.Save($cqWant, [System.Drawing.Imaging.ImageFormat]::Png); $cqSavedOk = (($cqWant.ToArray() -join ',') -eq ($cqSavedBytes -join ',')) } finally { $cqWant.Dispose() }
    }
    ST-Check 'e2e (C): the real Save-RectEx with the capture step injected passes on the second frame, publishes THAT frame byte-exactly, and the echo carries attempt=1/attempt=2 plus the quality tail with attempts and spent' (
      ($cqSaveOut.Contains('attempt=1 ink=0%')) -and ($cqSaveOut.Contains('attempt=2 ink=50%')) -and
      ($cqSaveOut.Contains('quality: verdict=pass attempts=2')) -and ($cqSaveOut.Contains('occlusion=not re-checked (no gate on this path)')) -and
      $cqSavedOk)
    # (8) a refused capture publishes NOTHING and leaves a same-name previous pair byte-identical:
    # an old PNG + old map written first survive a gate refusal exactly as they survive a failed
    # re-capture (the v4.6.8/v4.6.10 order conclusions, now covering the quality gate too).
    $cqOldPath = Join-Path $cqDir 'cq-old.png'
    $cqWhite.Save($cqOldPath, [System.Drawing.Imaging.ImageFormat]::Png)
    [System.IO.File]::WriteAllText(($cqOldPath + '.map.txt'), "origin_x=0`r`norigin_y=0`r`nscale=1`r`nout_w=200`r`nout_h=100`r`nkind=rect`r`n", (New-Object System.Text.UTF8Encoding($false)))
    $cqOldPng = [System.IO.File]::ReadAllBytes($cqOldPath)
    $cqOldMap = [System.IO.File]::ReadAllBytes($cqOldPath + '.map.txt')
    $cqSpecRefuseSave = New-CaptureQualityDefaults
    $cqSpecRefuseSave['MinInk'] = 5.0
    # every Save-RectEx leg hands in its capture step: the offline gate never grabs the real
    # desktop (a CopyFromScreen here would read the room and make the verdict environment-dependent).
    $cqWhiteOnly2 = { param([int]$n) return $cqWhite.Clone() }
    $cqRefuseSaveErr = ''
    try { [void](Save-RectEx 0 0 200 100 $cqOldPath 0 -1 @() '' $null $null $cqSpecRefuseSave $null $cqWhiteOnly2) } catch { $cqRefuseSaveErr = "$($_.Exception.Message)" }
    $cqOldUntouched = (([System.IO.File]::ReadAllBytes($cqOldPath) -join ',') -eq ($cqOldPng -join ',')) -and
      (([System.IO.File]::ReadAllBytes($cqOldPath + '.map.txt') -join ',') -eq ($cqOldMap -join ','))
    ST-Check 'e2e (C): a frame that never passes the gate is refused with nothing published - a same-name previous PNG and its map stay byte-identical, and a first-time path gets no files at all' (
      ($cqRefuseSaveErr.Contains('refused after 1 attempt(s) (--retry 0)')) -and $cqOldUntouched)
    $cqNewPath = Join-Path $cqDir 'cq-new.png'
    $cqNewErr = ''
    try { [void](Save-RectEx 0 0 200 100 $cqNewPath 0 -1 @() '' $null $null $cqSpecRefuseSave $null $cqWhiteOnly2) } catch { $cqNewErr = "$($_.Exception.Message)" }
    Write-Output ('      C leg8: err=[' + $cqNewErr + '] png=' + (Test-Path -LiteralPath $cqNewPath) + ' map=' + (Test-Path -LiteralPath ($cqNewPath + '.map.txt')))
    ST-Check 'e2e (C): a first-time path whose frames never pass gets neither a PNG nor a map - the pair cannot exist to be misread' (
      ($cqNewErr.Contains('refused after')) -and (-not (Test-Path -LiteralPath $cqNewPath)) -and (-not (Test-Path -LiteralPath ($cqNewPath + '.map.txt'))))
    # (9) the per-attempt checks belong to the caller's path: a bound crop whose host assert fails
    # on the second attempt is refused mid-loop and publishes nothing (the mock throws the same
    # message the real assert throws on a moved host).
    $script:cqHostCalls = 0
    $cqHostOrig = (Get-Item 'function:Assert-CaptureHostStable').ScriptBlock
    try {
      Set-Item -Path 'function:Assert-CaptureHostStable' -Value { param($snap, $kind) $script:cqHostCalls++; if ($script:cqHostCalls -ge 2) { throw 'rect : the host window moved after the capture was resolved (was 0,0 200x100, now 40,40 200x100) - refusing to publish a binding that no longer describes the window' } }
      $script:cqSeqIx3 = 0
      $cqStep3 = { param([int]$n) $f = $cqSeq[$script:cqSeqIx3]; $script:cqSeqIx3++; return $f.Clone() }
      $cqHostPath = Join-Path $cqDir 'cq-host.png'
      $cqHostWinMock = [pscustomobject]@{ Pid = 4242; Handle = [IntPtr]::new(99); Title = 'cq-host-fake' }
      $cqHostSnapMock = @{ Pid = 4242; Handle = [IntPtr]::new(99); Title = 'cq-host-fake'; X = 0; Y = 0; W = 200; H = 100; Sel = '' }
      $cqHostErr = ''
      try { [void](Save-RectEx 0 0 200 100 $cqHostPath 0 -1 @() 'rect' $cqHostWinMock $cqHostSnapMock $cqSpecSave $null $cqStep3) } catch { $cqHostErr = "$($_.Exception.Message)" }
      Write-Output ('      C leg9: err=[' + $cqHostErr + '] calls=' + $script:cqHostCalls + ' png=' + (Test-Path -LiteralPath $cqHostPath))
    ST-Check 'e2e (C): a bound crop whose host check fails on a LATER attempt is refused mid-loop with the assert message and publishes nothing - the per-attempt re-check is wired, not decorative' (
        ($cqHostErr.Contains('the host window moved after the capture was resolved')) -and
        (-not (Test-Path -LiteralPath $cqHostPath)) -and ($script:cqHostCalls -eq 2))
    } finally {
      Set-Item -Path 'function:Assert-CaptureHostStable' -Value $cqHostOrig
    }
    # (10) the loop is read-only by construction: a re-capture re-READS the screen and never
    # touches it - the compiled metric, the measure wrapper and the loop body contain no input API.
    # A-22 shape: the face enumeration needs lib/, so in single-file mode this half skips named.
    if ($script:StSourceMode -cne 'aggregate') {
      ST-Skip 'lint (C): the quality loop contains no input API and the six-flag grammar has ONE consumer over entry+lib files' 'single-file source mode (no lib/ beside the entry) - the product-face file set this lint enumerates does not exist'
    } else {
    $cqProdFace = @(@('desktop.ps1') + @((Get-ChildItem -LiteralPath (Join-Path $script:ToolRootPath 'lib') -Filter '*.ps1' -File | Where-Object { ([string]$_.Name) -notlike 'selftest*' } | Sort-Object Name | ForEach-Object { 'lib/' + $_.Name })))
    $cqInputTokens = @((('Send' + 'Input')), ('mouse_' + 'event'), ('Set-Cursor' + 'Position'), ('Move-' + 'Click'), ('Set-Foreground' + 'Window'), ('keybd_' + 'event'))
    $cqLoopBody = @()
    $cqAllLines = @([System.IO.File]::ReadAllLines((Join-Path $script:ToolRootPath 'desktop.ps1')))
    foreach ($cqFn in @('function Invoke-BoundedCapture', 'function Get-FrameInkQuality')) {
      $cqFs = -1
      for ($cqi = 0; $cqi -lt $cqAllLines.Count; $cqi++) { if (([string]$cqAllLines[$cqi]).StartsWith($cqFn)) { $cqFs = $cqi; break } }
      if ($cqFs -ge 0) {
        $cqFe = $cqAllLines.Count
        for ($cqj = $cqFs + 1; $cqj -lt $cqAllLines.Count; $cqj++) { if (([string]$cqAllLines[$cqj]).StartsWith('function ')) { $cqFe = $cqj; break } }
        for ($cqk = $cqFs; $cqk -lt $cqFe; $cqk++) { $cqLoopBody += [string]$cqAllLines[$cqk] }
      }
    }
    $cqInputHits = @($cqInputTokens | Where-Object { (@($cqLoopBody) -join "`n").Contains($_) })
    $cqQFlagSites = 0
    foreach ($cqp in @($cqProdFace)) {
      $cqPl = @([System.IO.File]::ReadAllLines((Join-Path $script:ToolRootPath $cqp)))
      foreach ($cql in @($cqPl)) {
        if (([string]$cql).TrimStart().StartsWith('#')) { continue }
        if (([string]$cql).TrimStart().StartsWith('function ')) { continue }
        if (([string]$cql).Contains('Test-CaptureQualityFlag')) { $cqQFlagSites++ }
      }
    }
    ST-Check 'lint (C): the quality loop and the measure wrapper contain no input API (a re-capture re-reads, never touches), and the six-flag grammar has ONE consumer called from exactly the two capture parsers (planted third site would be counted)' (
      (@($cqInputHits).Count -eq 0) -and ($cqQFlagSites -eq 2) -and ($cqLoopBody.Count -ge 20))
    if (@($cqInputHits).Count -gt 0) { Write-Output ('      C input tokens in the loop: ' + ($cqInputHits -join ', ')) }
    if ($cqQFlagSites -ne 2) { Write-Output ('      C quality-flag consumer sites: ' + $cqQFlagSites + ' (want 2)') }
    }
  } finally {
    try { if (Test-Path -LiteralPath $cqDir) { Remove-Item -LiteralPath $cqDir -Recurse -Force } } catch { }
  }
  # ---------- D-5 (v4.6.13): cluster-color - the palette an image file really holds ----------
  # The blueprint's two criteria are the FIRST check below (a three-block fixture: cluster
  # COUNT and SHARES correct, BBOXES equal to the rectangles that were painted). Everything
  # after them is what the rule adds that one fixture cannot show: the tolerance is PER
  # CHANNEL and inclusive at the boundary (a Euclidean reader would split where this merges),
  # the report order is a contract, the mean is the pixel-weighted FLOOR, invisible pixels are
  # counted rather than averaged, both trims self-report, and the two ceilings REFUSE instead
  # of returning a shorter list. Check 1 compares the compiled pass against a separate
  # PowerShell histogram over the SAME decoded bytes - if [CLC] read the stride wrong or
  # swapped red for blue, the two disagree, and a fixture of three flat blocks cannot tell
  # that apart on its own.
  $d5Dir = Join-Path ([System.IO.Path]::GetTempPath()) ('dtx-d5-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  [void][System.IO.Directory]::CreateDirectory($d5Dir)
  $d5Fill = {
    param([string]$Name, [int]$W, [int]$H, [object[]]$Blocks)
    $d5p = Join-Path $d5Dir $Name
    $d5bm = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $d5gm = [System.Drawing.Graphics]::FromImage($d5bm)
      try {
        foreach ($d5bk in @($Blocks)) {
          $d5br = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, [int]$d5bk[0], [int]$d5bk[1], [int]$d5bk[2]))
          try { $d5gm.FillRectangle($d5br, [int]$d5bk[3], [int]$d5bk[4], [int]$d5bk[5], [int]$d5bk[6]) } finally { $d5br.Dispose() }
        }
      } finally { $d5gm.Dispose() }
      $d5ms = New-Object System.IO.MemoryStream
      try { $d5bm.Save($d5ms, [System.Drawing.Imaging.ImageFormat]::Png); [System.IO.File]::WriteAllBytes($d5p, $d5ms.ToArray()) } finally { $d5ms.Dispose() }
    } finally { $d5bm.Dispose() }
    return $d5p
  }
  try {
    # (1) the fixture is the region the caller paints: three blocks, full coverage, no gaps.
    $d5Three = & $d5Fill 'three.png' 100 50 @(
      @(255, 0, 0, 0, 0, 60, 25),
      @(0, 0, 255, 0, 25, 60, 25),
      @(0, 255, 0, 60, 0, 40, 50))
    $d5Img = Read-ClusterImage $d5Three
    $d5Zero = Get-ColorClusters $d5Img.Bytes $d5Img.Stride $d5Img.W $d5Img.H 0 (Get-ClusterCeiling 'MaxSeeds') (Get-ClusterCeiling 'MaxMs')
    $d5Ind = @{}
    for ($d5y = 0; $d5y -lt $d5Img.H; $d5y++) {
      $d5Row = $d5y * $d5Img.Stride
      for ($d5x = 0; $d5x -lt $d5Img.W; $d5x++) {
        $d5o = $d5Row + $d5x * 4
        $d5k = ([int] $d5Img.Bytes[$d5o + 2] * 65536) + ([int] $d5Img.Bytes[$d5o + 1] * 256) + [int] $d5Img.Bytes[$d5o]
        if (-not $d5Ind.ContainsKey($d5k)) { $d5Ind[$d5k] = @{ N = 0; X0 = $d5x; Y0 = $d5y; X1 = $d5x; Y1 = $d5y } }
        $d5e = $d5Ind[$d5k]
        $d5e.N = $d5e.N + 1
        if ($d5x -lt $d5e.X0) { $d5e.X0 = $d5x }
        if ($d5x -gt $d5e.X1) { $d5e.X1 = $d5x }
        if ($d5y -lt $d5e.Y0) { $d5e.Y0 = $d5y }
        if ($d5y -gt $d5e.Y1) { $d5e.Y1 = $d5y }
      }
    }
    $d5IndPx = 0
    foreach ($d5k in @($d5Ind.Keys)) { $d5IndPx = $d5IndPx + [long] $d5Ind[$d5k].N }
    $d5Bad = @()
    foreach ($d5c in @($d5Zero.Rows)) {
      $d5ck = [int] $d5c.R * 65536 + [int] $d5c.G * 256 + [int] $d5c.B
      if (-not $d5Ind.ContainsKey($d5ck)) { $d5Bad += ('colour-not-in-histogram=' + $d5c.Hex); continue }
      $d5ie = $d5Ind[$d5ck]
      if ([long] $d5c.Count -ne [long] $d5ie.N) { $d5Bad += ($d5c.Hex + '=count' + $d5c.Count + '-want' + $d5ie.N) }
      if ($d5c.X -ne $d5ie.X0 -or $d5c.Y -ne $d5ie.Y0) { $d5Bad += ($d5c.Hex + '=origin' + $d5c.X + ',' + $d5c.Y + '-want' + $d5ie.X0 + ',' + $d5ie.Y0) }
      if (($d5c.X + $d5c.BoxW - 1) -ne $d5ie.X1 -or ($d5c.Y + $d5c.BoxH - 1) -ne $d5ie.Y1) { $d5Bad += ($d5c.Hex + '=far' + ($d5c.X + $d5c.BoxW - 1) + ',' + ($d5c.Y + $d5c.BoxH - 1) + '-want' + $d5ie.X1 + ',' + $d5ie.Y1) }
    }
    $d5BySize = @($d5Zero.Rows | Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, 'R', 'G', 'B', 'Y', 'X')
    $d5Ok1 = (@($d5Zero.Rows).Count -eq 3) -and ($d5Zero.Seeds -eq 3) -and ($d5IndPx -eq 5000) -and
      ($d5Zero.Opaque -eq 5000L) -and ($d5Zero.Transparent -eq 0L) -and (@($d5Zero.Pixels) -eq 5000) -and
      (@($d5Bad).Count -eq 0) -and (@($d5Ind.Keys).Count -eq 3) -and
      ($d5BySize[0].Hex -ceq '#00FF00') -and ($d5BySize[0].Count -eq 2000) -and
      ($d5BySize[0].X -eq 60) -and ($d5BySize[0].Y -eq 0) -and ($d5BySize[0].BoxW -eq 40) -and ($d5BySize[0].BoxH -eq 50) -and
      ($d5BySize[1].Hex -ceq '#0000FF') -and ($d5BySize[1].Count -eq 1500) -and
      ($d5BySize[1].X -eq 0) -and ($d5BySize[1].Y -eq 25) -and ($d5BySize[1].BoxW -eq 60) -and ($d5BySize[1].BoxH -eq 25) -and
      ($d5BySize[2].Hex -ceq '#FF0000') -and ($d5BySize[2].Count -eq 1500) -and
      ($d5BySize[2].X -eq 0) -and ($d5BySize[2].Y -eq 0) -and ($d5BySize[2].BoxW -eq 60) -and ($d5BySize[2].BoxH -eq 25)
    ST-Check 'unit (D-5): a three-block fixture yields exactly three clusters whose counts, pixel-weighted colours and bboxes equal the rectangles painted AND an independent PowerShell histogram over the same decoded bytes (planted control for a stride or channel-order bug)' $d5Ok1
    if (-not $d5Ok1) {
      Write-Output ('      D-5 fixture: rows=' + @($d5Zero.Rows).Count + ' seeds=' + $d5Zero.Seeds + ' opaque=' + $d5Zero.Opaque +
        ' transparent=' + $d5Zero.Transparent + ' pixels=' + $d5Zero.Pixels + ' hist-colours=' + @($d5Ind.Keys).Count +
        ' hist-pixels=' + $d5IndPx + ' bad=[' + (@($d5Bad) -join '; ') + '] order=[' +
        ((@($d5BySize | ForEach-Object { "$($_.Hex):$($_.Count)@($($_.X),$($_.Y),$($_.BoxW),$($_.BoxH))" })) -join ' ') + ']')
    }
    # (2) the tolerance is a PER-CHANNEL bound, INCLUSIVE at the boundary. Two blocks whose
    # colours differ by 5 on RED and 5 on GREEN are 7.07 apart in Euclidean terms: a reader
    # that measured distance would keep them apart at --tolerance 5, this rule merges them and
    # the dev columns print 5,5,0 as the evidence. A second pair differs on BLUE only.
    $d5Cheb = & $d5Fill 'cheb.png' 20 10 @(
      @(255, 0, 0, 0, 0, 10, 10),
      @(250, 5, 0, 10, 0, 10, 10))
    $d5Cimg = Read-ClusterImage $d5Cheb
    $d5C4 = Get-ColorClusters $d5Cimg.Bytes $d5Cimg.Stride $d5Cimg.W $d5Cimg.H 4 (Get-ClusterCeiling 'MaxSeeds') (Get-ClusterCeiling 'MaxMs')
    $d5C5 = Get-ColorClusters $d5Cimg.Bytes $d5Cimg.Stride $d5Cimg.W $d5Cimg.H 5 (Get-ClusterCeiling 'MaxSeeds') (Get-ClusterCeiling 'MaxMs')
    $d5Blue = & $d5Fill 'blue.png' 20 10 @(
      @(10, 10, 10, 0, 0, 10, 10),
      @(10, 10, 16, 10, 0, 10, 10))
    $d5Bimg = Read-ClusterImage $d5Blue
    $d5B5 = Get-ColorClusters $d5Bimg.Bytes $d5Bimg.Stride $d5Bimg.W $d5Bimg.H 5 (Get-ClusterCeiling 'MaxSeeds') (Get-ClusterCeiling 'MaxMs')
    $d5B6 = Get-ColorClusters $d5Bimg.Bytes $d5Bimg.Stride $d5Bimg.W $d5Bimg.H 6 (Get-ClusterCeiling 'MaxSeeds') (Get-ClusterCeiling 'MaxMs')
    $d5C5row = @($d5C5.Rows)[0]
    $d5Ok2 = (@($d5C4.Rows).Count -eq 2) -and (@($d5C5.Rows).Count -eq 1) -and
      ($d5C5row.Count -eq 200) -and ($d5C5row.R -eq 252) -and ($d5C5row.G -eq 2) -and ($d5C5row.B -eq 0) -and
      ($d5C5row.SeedR -eq 255) -and ($d5C5row.DevR -eq 5) -and ($d5C5row.DevG -eq 5) -and ($d5C5row.DevB -eq 0) -and
      (@($d5B5.Rows).Count -eq 2) -and (@($d5B6.Rows).Count -eq 1) -and
      (@($d5B6.Rows)[0].DevB -eq 6) -and (@($d5B6.Rows)[0].DevR -eq 0)
    ST-Check 'unit (D-5): --tolerance is a PER-CHANNEL bound and inclusive at the boundary - a pair 5 apart on red and 5 apart on green (7.07 apart as the crow flies) merges at 5 and splits at 4, and a pair differing on blue alone does the same at 6' (
      $d5Ok2)
    if (-not $d5Ok2) {
      Write-Output ('      D-5 cheb: at4=' + @($d5C4.Rows).Count + ' at5=' + @($d5C5.Rows).Count +
        ' merged=[' + ($d5C5row.R.ToString() + ',' + $d5C5row.G + ',' + $d5C5row.B + ') seed=' + $d5C5row.SeedR + ',' + $d5C5row.SeedG + ',' + $d5C5row.SeedB + ' dev=' + $d5C5row.DevR + ',' + $d5C5row.DevG + ',' + $d5C5row.DevB + ' n=' + $d5C5row.Count) +
        '] blue: at5=' + @($d5B5.Rows).Count + ' at6=' + @($d5B6.Rows).Count)
    }
    # (3) the ORDER is part of the answer. Biggest first; an equal-size tie falls back to the
    # cluster's own numbers (blue 0,0,255 before red 255,0,0), and every dev printed is inside
    # the tolerance that produced it - the bound the report claims is the bound it holds.
    $d5RankTxt = (@($d5BySize | ForEach-Object { $_.Hex }) -join ' ')
    # Each set is judged against the tolerance that PRODUCED it: 5 for the pair that merged at
    # 5, 6 for the pair that merged at 6, 0 for the three flat blocks. One hard-coded bound
    # across mixed sources is not "inside the tolerance that produced it" - it is a guess, and
    # it reddens on correct data (measured r1: the blue pair at tolerance 6 dev=0,0,6).
    $d5OverDev = @()
    foreach ($d5Set in @(@{ Rows = @($d5C5.Rows); Tol = 5 }, @{ Rows = @($d5B5.Rows); Tol = 5 },
                         @{ Rows = @($d5B6.Rows); Tol = 6 }, @{ Rows = @($d5BySize); Tol = 0 })) {
      foreach ($d5rr in @($d5Set.Rows)) {
        if ($d5rr.DevR -gt $d5Set.Tol -or $d5rr.DevG -gt $d5Set.Tol -or $d5rr.DevB -gt $d5Set.Tol) {
          $d5OverDev += ($d5rr.Hex + '=' + $d5rr.DevR + ',' + $d5rr.DevG + ',' + $d5rr.DevB + '-over-tol' + $d5Set.Tol)
        }
      }
    }
    $d5Ok3 = ($d5RankTxt -ceq '#00FF00 #0000FF #FF0000') -and (@($d5OverDev).Count -eq 0) -and
      (@($d5BySize | Where-Object { $_.DevR -ne 0 -or $_.DevG -ne 0 -or $_.DevB -ne 0 }).Count -eq 0)
    ST-Check 'unit (D-5): clusters come back biggest first with the stated tie-break (equal 1500-pixel clusters fall back to their own colour numbers), and at tolerance 0 every cluster is one exact colour with zero deviation' (
      $d5Ok3)
    if (-not $d5Ok3) { Write-Output ('      D-5 order: [' + $d5RankTxt + '] over-dev=[' + (@($d5OverDev) -join '; ') + ']') }
    # (4) the mean is the pixel-weighted FLOOR and alpha-0 pixels are invisible, not black.
    $d5Floor = & $d5Fill 'floor.png' 4 1 @(
      @(10, 0, 0, 0, 0, 1, 1),
      @(11, 0, 0, 1, 0, 1, 1),
      @(10, 0, 0, 2, 0, 1, 1),
      @(11, 0, 0, 3, 0, 1, 1))
    $d5Fimg = Read-ClusterImage $d5Floor
    $d5F1 = Get-ColorClusters $d5Fimg.Bytes $d5Fimg.Stride $d5Fimg.W $d5Fimg.H 1 (Get-ClusterCeiling 'MaxSeeds') (Get-ClusterCeiling 'MaxMs')
    $d5Frow = @($d5F1.Rows)[0]
    $d5AlphaP = Join-Path $d5Dir 'alpha.png'
    $d5Abm = New-Object System.Drawing.Bitmap(10, 10, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      for ($d5ax = 0; $d5ax -lt 10; $d5ax++) {
        for ($d5ay = 0; $d5ay -lt 10; $d5ay++) {
          if ($d5ax -lt 5) { $d5Abm.SetPixel($d5ax, $d5ay, [System.Drawing.Color]::FromArgb(255, 200, 30, 30)) }
          else { $d5Abm.SetPixel($d5ax, $d5ay, [System.Drawing.Color]::FromArgb(0, 9, 9, 9)) }
        }
      }
      $d5Ams = New-Object System.IO.MemoryStream
      try { $d5Abm.Save($d5Ams, [System.Drawing.Imaging.ImageFormat]::Png); [System.IO.File]::WriteAllBytes($d5AlphaP, $d5Ams.ToArray()) } finally { $d5Ams.Dispose() }
    } finally { $d5Abm.Dispose() }
    $d5Avimg = Read-ClusterImage $d5AlphaP
    $d5Av = Get-ColorClusters $d5Avimg.Bytes $d5Avimg.Stride $d5Avimg.W $d5Avimg.H 20 (Get-ClusterCeiling 'MaxSeeds') (Get-ClusterCeiling 'MaxMs')
    $d5Avrow = @($d5Av.Rows)[0]
    $d5Ok4 = (@($d5F1.Rows).Count -eq 1) -and ($d5Frow.Count -eq 4) -and ($d5Frow.R -eq 10) -and
      ($d5Frow.Hex -ceq '#0A0000') -and ($d5Frow.SeedR -eq 10) -and ($d5Frow.DevR -eq 1) -and
      (@($d5Av.Rows).Count -eq 1) -and ($d5Av.Opaque -eq 50L) -and ($d5Av.Transparent -eq 50L) -and
      ($d5Av.Pixels -eq 100L) -and ($d5Avrow.Count -eq 50) -and ($d5Avrow.R -eq 200) -and
      (Format-ClusterShare $d5Avrow.Count $d5Av.Opaque -ceq '100.00') -and
      (Format-ClusterShare 2000L 5000L -ceq '40.00') -and (Format-ClusterShare 1L 3L -ceq '33.33')
    ST-Check 'unit (D-5): the printed colour is the pixel-weighted mean FLOORED (two 10s and two 11s print 10, never 11), and alpha-0 pixels are counted and skipped so a share is taken over the opaque pixels only' (
      $d5Ok4)
    if (-not $d5Ok4) {
      Write-Output ('      D-5 floor/alpha: mean=' + $d5Frow.R + ' hex=' + $d5Frow.Hex + ' seed=' + $d5Frow.SeedR + ' dev=' + $d5Frow.DevR +
        ' | opaque=' + $d5Av.Opaque + ' transparent=' + $d5Av.Transparent + ' pixels=' + $d5Av.Pixels + ' rows=' + @($d5Av.Rows).Count + ' r=' + $d5Avrow.R)
    }
    # (5) both cuts self-report. Twelve blocks of two sizes: --min-cluster 100 keeps the six
    # big ones and says how many pixels it dropped; with no trim the TEXT page stops at the top
    # ten and says so, while --json carries all twelve (the page is a reading limit, the data
    # is not). A drop that is not announced is the same lie as a truncation that is not.
    $d5Twelve = & $d5Fill 'twelve.png' 144 10 @(
      @(10, 40, 60, 0, 0, 20, 10), @(30, 40, 60, 20, 0, 20, 10), @(50, 40, 60, 40, 0, 20, 10),
      @(70, 40, 60, 60, 0, 20, 10), @(90, 40, 60, 80, 0, 20, 10), @(110, 40, 60, 100, 0, 20, 10),
      @(130, 40, 60, 120, 0, 4, 10), @(150, 40, 60, 124, 0, 4, 10), @(170, 40, 60, 128, 0, 4, 10),
      @(190, 40, 60, 132, 0, 4, 10), @(210, 40, 60, 136, 0, 4, 10), @(230, 40, 60, 140, 0, 4, 10))
    $d5JsonSave = $script:Json
    $script:Json = $false
    $d5T1 = @(Invoke-Handler-cluster-color 'cluster-color' @($d5Twelve, '--tolerance', '0'))
    $d5T2 = @(Invoke-Handler-cluster-color 'cluster-color' @($d5Twelve, '--tolerance', '0', '--min-cluster', '100'))
    $script:Json = $true
    $d5J1 = (Invoke-Handler-cluster-color 'cluster-color' @($d5Twelve, '--tolerance', '0')) | ConvertFrom-Json
    $d5J2 = (Invoke-Handler-cluster-color 'cluster-color' @($d5Twelve, '--tolerance', '0', '--min-cluster', '100')) | ConvertFrom-Json
    $script:Json = $d5JsonSave
    $d5T1txt = ($d5T1 -join "`n")
    $d5T2txt = ($d5T2 -join "`n")
    $d5Ok5 = (@($d5T1 | Where-Object { $_ -like '  #*' }).Count -eq 10) -and
      ($d5T1txt.Contains('10 of 12 cluster(s) over 1440 opaque pixel(s)')) -and
      ($d5T1txt.Contains('showing the top 10 of 12 cluster(s) that passed --min-cluster')) -and
      (@($d5T2 | Where-Object { $_ -like '  #*' }).Count -eq 6) -and
      ($d5T2txt.Contains('6 of 12 cluster(s)')) -and ($d5T2txt.Contains('6 cluster(s) fell below --min-cluster 100 (240 pixel(s))')) -and
      (-not $d5T2txt.Contains('#82283C')) -and
      (@($d5J1.palette).Count -eq 12) -and ($d5J1.clusters -eq 12) -and ($d5J1.kept -eq 12) -and ($d5J1.below_min -eq 0) -and
      (@($d5J2.palette).Count -eq 6) -and ($d5J2.kept -eq 6) -and ($d5J2.below_min -eq 6) -and ($d5J2.below_min_pixels -eq 240) -and
      ((@($d5J1.palette) | Measure-Object -Property count -Minimum).Minimum -eq 40) -and
      ((@($d5J2.palette) | Measure-Object -Property count -Minimum).Minimum -eq 200)
    ST-Check 'unit (D-5): --min-cluster trims small clusters and reports how many it trimmed with their pixel total, the text page stops at the top ten and says so, and --json carries every cluster that passed the trim' (
      $d5Ok5)
    if (-not $d5Ok5) {
      Write-Output ('      D-5 trim: text-lines=' + @($d5T1 | Where-Object { $_ -like '  #*' }).Count +
        ' kept-lines=' + @($d5T2 | Where-Object { $_ -like '  #*' }).Count + ' json-all=' + @($d5J1.palette).Count +
        ' json-kept=' + @($d5J2.palette).Count + ' dropped=' + $d5J2.below_min + '/' + $d5J2.below_min_pixels +
        ' | t1=[' + $d5T1txt.Replace("`n", ' | ') + '] t2=[' + $d5T2txt.Replace("`n", ' | ') + ']')
    }
    # (6) every refusal names what it found. Five different defects must not collapse into one
    # sentence, and no two messages may be identical (that is how a reader learns WHICH thing
    # to fix); the handler rejects a missing or doubled positional before the file is touched.
    $d5EmptyP = Join-Path $d5Dir 'empty.png'
    [System.IO.File]::WriteAllBytes($d5EmptyP, @())
    $d5TextP = Join-Path $d5Dir 'notanimage.png'
    [System.IO.File]::WriteAllText($d5TextP, 'this is not a PNG at all, it is a sentence', (New-Object System.Text.UTF8Encoding($false)))
    $d5Why = @()
    try { [void](Read-ClusterImage (Join-Path $d5Dir 'nope.png')) } catch { $d5Why += [string] $_.Exception.Message }
    try { [void](Read-ClusterImage $d5Dir) } catch { $d5Why += [string] $_.Exception.Message }
    try { [void](Read-ClusterImage $d5EmptyP) } catch { $d5Why += [string] $_.Exception.Message }
    try { [void](Read-ClusterImage $d5TextP) } catch { $d5Why += [string] $_.Exception.Message }
    $d5WhyArgs = @()
    try { [void](Invoke-Handler-cluster-color 'cluster-color' @()) } catch { $d5WhyArgs += [string] $_.Exception.Message }
    try { [void](Invoke-Handler-cluster-color 'cluster-color' @($d5Three, 'extra.png')) } catch { $d5WhyArgs += [string] $_.Exception.Message }
    $d5Distinct = @($d5Why | Sort-Object -Unique).Count
    $d5Ok6 = (@($d5Why).Count -eq 4) -and ($d5Distinct -eq 4) -and
      ($d5Why[0].Contains('no image at')) -and ($d5Why[1].Contains('is a directory')) -and
      ($d5Why[2].Contains('empty file')) -and ($d5Why[3].Contains('could not be decoded')) -and
      (@($d5WhyArgs).Count -eq 2) -and ($d5WhyArgs[0].Contains('usage: cluster-color')) -and
      ($d5WhyArgs[1].Contains('one positional argument')) -and ($d5WhyArgs[1].Contains('extra.png'))
    ST-Check 'unit (D-5): a missing path, a directory, an empty file and undecodable bytes are each refused by their own reason (four distinct sentences, never one shared ''not an image''), and a missing or doubled positional is refused before the file is opened' (
      $d5Ok6)
    if (-not $d5Ok6) { Write-Output ('      D-5 refusals: n=' + @($d5Why).Count + ' distinct=' + $d5Distinct + ' [' + (@($d5Why) -join ' || ') + '] args=[' + (@($d5WhyArgs) -join ' || ') + ']') }
    # (7) the two ceilings. Both are driven through the helper's OWN parameters so a fixture
    # does not have to be eight megapixels: a cap of two clusters on a three-colour file, and a
    # budget of -1 ms on a 512x512 one (the sentinel is what makes the time leg deterministic -
    # a real stopwatch reading at 0 ms would depend on the machine). Neither may return a
    # partial list, because a shorter palette reads as a complete one.
    $d5Big = & $d5Fill 'big.png' 512 512 @(
      @(0, 128, 0, 0, 0, 512, 512), @(0, 129, 0, 0, 0, 1, 1))
    $d5Gimg = Read-ClusterImage $d5Big
    $d5Ceil = @()
    try { [void](Get-ColorClusters $d5Img.Bytes $d5Img.Stride $d5Img.W $d5Img.H 0 2 (Get-ClusterCeiling 'MaxMs')) } catch { $d5Ceil += [string] $_.Exception.Message }
    try { [void](Get-ColorClusters $d5Gimg.Bytes $d5Gimg.Stride $d5Gimg.W $d5Gimg.H 0 (Get-ClusterCeiling 'MaxSeeds') (-1)) } catch { $d5Ceil += [string] $_.Exception.Message }
    $d5CeilUnknown = ''
    try { [void](Get-ClusterCeiling 'MaxEverything') } catch { $d5CeilUnknown = [string] $_.Exception.Message }
    # Neither number is guessed. The cap trips on the FIRST pixel that needs a third seed, so
    # the pixels already counted are exactly the opaque ones before it in raster order - here
    # the 25 full rows of red+green. The budget is tested on the first counted total divisible
    # by 0x10000, which is why a -1 ms budget still reports a fixed pixel count on any machine.
    $d5CapWant = 'stopped at ' + (25 * $d5Img.W) + ' opaque pixel(s) of ' + ($d5Img.W * $d5Img.H)
    $d5OverWant = 'after ' + [string] 0x10000 + ' opaque pixel(s) of ' + ($d5Gimg.W * $d5Gimg.H)
    $d5Ok7 = (@($d5Ceil).Count -eq 2) -and ($d5Ceil[0].Contains('more than 2 clusters')) -and
      ($d5Ceil[0].Contains('NO palette is reported')) -and ($d5Ceil[1].Contains('-1 ms budget')) -and
      ($d5Ceil[0].Contains('--tolerance 0 merges too little')) -and
      ($d5Ceil[0].Contains($d5CapWant)) -and ($d5Ceil[1].Contains($d5OverWant)) -and
      (@($d5Ceil | Where-Object { $_ -like '*partial list*' }).Count -eq 2) -and
      ((Get-ClusterCeiling 'MaxSeeds') -eq 4096) -and ((Get-ClusterCeiling 'MaxMs') -eq 5000) -and
      ((Get-ClusterCeiling 'TopK') -eq 10) -and ($d5CeilUnknown.Contains('the ceilings are MaxSeeds, MaxMs and TopK'))
    ST-Check 'unit (D-5): both ceilings refuse with the number that fired and return NO partial list - the cluster cap names the tolerance and the pixels counted before it stopped, the time budget names the same against the whole image, and the shipped ceilings are 4096/5000/10' (
      $d5Ok7)
    if (-not $d5Ok7) { Write-Output ('      D-5 ceilings: cap-want=[' + $d5CapWant + '] over-want=[' + $d5OverWant + '] n=' + @($d5Ceil).Count + ' [' + (@($d5Ceil) -join ' || ') + '] unknown-ceiling=[' + $d5CeilUnknown + ']') }
    # (8) the registration sweep, with a planted ghost. cluster-color must be a real dispatch
    # case, have exactly one handler in the file the read group declares, own a help entry, be
    # tabled for both of its flags, route NO shared flag, and be JSON-capable - while a name
    # that does not exist must fail the same tests (a scan that cannot say no is not evidence).
    $d5Case = @($codeLines | Where-Object { $_ -match ("^    '" + 'cluster-color' + "' \{") }).Count
    $d5GhostCase = @($codeLines | Where-Object { $_ -match ("^    '" + 'cluster-colorzzz' + "' \{") }).Count
    $d5Fn = @($codeLines | Where-Object { $_ -match '^function Invoke-Handler-cluster-color\(' }).Count
    # The help page lives inside a single-quoted here-string, and $codeLines blanks every
    # here-string body on purpose, so the entry is read from the function that RENDERS it -
    # scanning the source here would measure a blank line and report the help page as missing.
    $d5Help = @(((Get-UsageText) -split "`r?`n") | Where-Object { $_ -ceq '    cluster-color <image> [--min-cluster N] [--tolerance d]' }).Count
    $d5FlagRow = @($codeLines | Where-Object { $_ -match ("^    '" + 'cluster-color' + "' = @\{ '--tolerance' = @\{ Min = 0; Max = 255; Default = 20 \}") }).Count
    $d5Spec = Get-OwnFlagSpec 'cluster-color'
    $d5Ok8 = ($d5Case -eq 1) -and ($d5GhostCase -eq 0) -and ($d5Fn -eq 1) -and ($d5Help -eq 1) -and ($d5FlagRow -eq 1) -and
      (Test-JsonCapableCommand 'cluster-color') -and (-not (Test-JsonCapableCommand 'cluster-colorzzz')) -and
      (@(Get-CommandSharedSet 'cluster-color').Count -eq 0) -and
      (@(Get-CommandSharedSet 'cluster-colorzzz').Count -gt 0) -and
      ($d5Spec.ContainsKey('--tolerance')) -and ($d5Spec.ContainsKey('--min-cluster')) -and
      ($d5Spec['--tolerance']['Min'] -eq 0) -and ($d5Spec['--tolerance']['Max'] -eq 255) -and ($d5Spec['--tolerance']['Default'] -eq 20) -and
      ($d5Spec['--min-cluster']['Min'] -eq 1) -and ($d5Spec['--min-cluster']['Max'] -eq 100000000) -and ($d5Spec['--min-cluster']['Default'] -eq 1) -and
      (-not (Get-OwnFlagSpec 'cluster-colorzzz').ContainsKey('--tolerance'))
    ST-Check 'lint (D-5): cluster-color is one dispatch case with one handler, one help entry and both flags tabled, routes no shared flag, renders --json, and a ghost name fails every one of those tests (the sweep is not vacuous)' (
      $d5Ok8)
    if (-not $d5Ok8) {
      Write-Output ('      D-5 registration: case=' + $d5Case + ' ghost=' + $d5GhostCase + ' handler=' + $d5Fn +
        ' help=' + $d5Help + ' flagrow=' + $d5FlagRow + ' json=' + (Test-JsonCapableCommand 'cluster-color') +
        ' shared=' + (@(Get-CommandSharedSet 'cluster-color').Count) + ' spec=' + (@(Get-HashKeys (Get-OwnFlagSpec 'cluster-color')).Count))
    }
    # (9) end to end through the real entry: the numbers a child prints are the numbers the
    # library computed (two outlets, one measurement), a bad --tolerance is refused by the
    # table BEFORE the image is decoded, and an unknown flag names itself. A box that cannot
    # spawn a child gets a named skip, never a silent pass.
    $d5Run = {
      param([string]$ArgLine, [string]$OutName)
      $d5o = Join-Path $d5Dir $OutName
      try {
        $d5pr = Start-Process -FilePath 'powershell.exe' -ArgumentList $ArgLine -RedirectStandardOutput $d5o -RedirectStandardError "$d5o.err" -Wait -PassThru -NoNewWindow
        $d5txt = ''
        if (Test-Path -LiteralPath $d5o) { $d5txt += [IO.File]::ReadAllText($d5o) }
        $d5errt = ''
        if (Test-Path -LiteralPath "$d5o.err") { $d5errt += [IO.File]::ReadAllText("$d5o.err") }
        return @{ Ok = $true; Exit = [int] $d5pr.ExitCode; Out = $d5txt; Err = $d5errt }
      } catch { return @{ Ok = $false; Why = [string] $_.Exception.Message; Exit = -1; Out = ''; Err = '' } }
    }
    $d5Q = '-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" cluster-color '
    $d5E1 = & $d5Run ($d5Q + '"' + $d5Three + '" --tolerance 0') 'e1.txt'
    $d5E2 = & $d5Run ($d5Q + '"' + $d5Three + '" --tolerance 0 --json') 'e2.txt'
    $d5E3 = & $d5Run ($d5Q + '"' + $d5Three + '" --tolerance 256') 'e3.txt'
    $d5E4 = & $d5Run ($d5Q + '"' + (Join-Path $d5Dir 'gone.png') + '"') 'e4.txt'
    $d5E5 = & $d5Run ($d5Q + '"' + $d5Three + '" --nope') 'e5.txt'
    if (-not $d5E1.Ok) {
      ST-Skip 'e2e (D-5): a real child reports the same palette the library computed, in text and in --json, and refuses a bad tolerance before decoding' ($d5E1.Why + ' - the check spawns a child process')
    } else {
      $d5E1txt = $d5E1.Out + $d5E1.Err
      $d5Ej = $null
      try { $d5Ej = $d5E2.Out | ConvertFrom-Json } catch { $d5Ej = $null }
      $d5Ok9 = ($d5E1.Exit -eq 0) -and ($d5E1txt.Contains('3 of 3 cluster(s) over 5000 opaque pixel(s)')) -and
        ($d5E1txt.Contains('#00FF00 share=40.00% count=2000 bbox=(60,0,40,50)')) -and
        ($d5E2.Exit -eq 0) -and ($null -ne $d5Ej) -and ($d5Ej.clusters -eq 3) -and (@($d5Ej.palette).Count -eq 3) -and
        ($d5Ej.width -eq 100) -and ($d5Ej.height -eq 50) -and ($d5Ej.opaque -eq 5000) -and
        (@($d5Ej.palette | Where-Object { $_.count -eq 2000 }).Count -eq 1) -and
        ((@($d5Ej.palette | Where-Object { $_.hex -ceq '#0000FF' })[0].bbox -join ',') -ceq '0,25,60,25') -and
        ($d5E3.Exit -ne 0) -and (($d5E3.Out + $d5E3.Err).Contains('--tolerance')) -and (($d5E3.Out + $d5E3.Err).Contains('0..255')) -and
        ($d5E4.Exit -ne 0) -and (($d5E4.Out + $d5E4.Err).Contains('no image at')) -and
        ($d5E5.Exit -ne 0) -and (($d5E5.Out + $d5E5.Err).Contains('unknown flag ''--nope'''))
      ST-Check 'e2e (D-5): a real child prints the same palette the library computed for the same file, text and --json agree cluster-for-cluster, and a tolerance of 256, a missing file and an unknown flag are each refused by name' (
        $d5Ok9)
      if (-not $d5Ok9) {
        Write-Output ('      D-5 e2e: text exit=' + $d5E1.Exit + ' out=[' + $d5E1txt.Replace("`n", ' | ') + ']' +
          ' json exit=' + $d5E2.Exit + ' clusters=' + $(if ($null -ne $d5Ej) { $d5Ej.clusters } else { 'UNPARSED' }) + ' out=[' + $d5E2.Out.Trim().Replace("`n", ' | ') + ']' +
          ' bad-tol exit=' + $d5E3.Exit + ' out=[' + ($d5E3.Out + $d5E3.Err).Replace("`n", ' | ') + ']' +
          ' missing exit=' + $d5E4.Exit + ' unknown-flag exit=' + $d5E5.Exit + ' out=[' + ($d5E5.Out + $d5E5.Err).Replace("`n", ' | ') + ']')
      }
    }
  } finally {
    try { if (Test-Path -LiteralPath $d5Dir) { Remove-Item -LiteralPath $d5Dir -Recurse -Force } } catch { }
    $d5Residual = @(Get-ChildItem -LiteralPath ([System.IO.Path]::GetTempPath()) -Filter 'dtx-d5-*' -Force -ErrorAction SilentlyContinue).Count
    if ($d5Residual -gt 0) { Write-Output ('      D-5 cleanup: ' + $d5Residual + ' temp dir(s) left behind') }
  }
}
