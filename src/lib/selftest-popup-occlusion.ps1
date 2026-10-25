# lib/selftest-popup-occlusion.ps1 - one family of the selftest section, lifted out of
# lib/selftest.ps1 by A-14l (A-beta). Bodies are byte-identical to what the section carried; the only
# channel to the orchestrator is the explicit context object, and since this card that channel runs
# both ways - shared state arrives through $Ctx and what a lifted body still produces leaves through
# the declared export list, because a value that stays in a function scope reaches the next body as
# whatever the orchestration happened to hold under that name.
#
# The popup/occlusion family: the same-process popup delta, the no---to baseline that has to match
# --to, the occlusion self-proof, dialog-cancel made mechanical, the red-1/red-2 front gate over the
# weak receipt chain, the script popup survival guard, and the popup delta merge.
function Invoke-SelftestFamily-PopupOcclusion($Ctx) {
  # context handover (the one thing in this file above the lifted text that is not lifted text)
  $codeLines = $Ctx['codeLines']
  $j5ProdStart = $Ctx['j5ProdStart']
  $j5ProdEnd = $Ctx['j5ProdEnd']

  # ---------- unit: v1.5.3 R-06 same-process popup delta ----------
  # The RULE is pure (which handles count as newly on top), the enumeration is
  # not - so the two are tested apart. Synthetic windows only here.
  $wA = [pscustomobject]@{ Handle = [IntPtr]100; Class = 'Win'; Title = 'A'; Transparent = $false }
  $wB = [pscustomobject]@{ Handle = [IntPtr]200; Class = '#32768'; Title = ''; Transparent = $false }
  $wT = [pscustomobject]@{ Handle = [IntPtr]300; Class = 'tooltips_class32'; Title = ''; Transparent = $true }
  $dSame = Compare-PopupDelta @($wA) @($wA)
  ST-Check 'unit: popup delta - nothing new on top means no warning' ($dSame.HasNew -eq $false -and @($dSame.New).Count -eq 0)
  $dNew = Compare-PopupDelta @($wA) @($wA, $wB)
  ST-Check 'unit: popup delta - a menu-shaped window that appeared on top is reported' (
    $dNew.HasNew -eq $true -and @($dNew.New)[0].Class -eq '#32768')
  $dTip = Compare-PopupDelta @($wA) @($wA, $wT)
  ST-Check 'unit: popup delta - a click-through tooltip never triggers (no noise on every type)' (
    $dTip.HasNew -eq $false -and @($dTip.New).Count -eq 0)
  $dPre = Compare-PopupDelta @($wA, $wB) @($wA, $wB)
  ST-Check 'unit: popup delta - a tool window that was already there is not a new event' ($dPre.HasNew -eq $false)
  # ---------- v3.1.0 (P-02): the no---to send path must take the SAME popup baseline as --to ----------
  # Second review batch, item 5. The contract comment above promises "a tool window or palette
  # that was already floating there does not fire on every single send", but the baseline had
  # exactly ONE producer - the --to path. Resolve-Target returned early for no --to without the
  # property, Test-PostSendForeground fell back to an EMPTY baseline, and every pre-existing
  # same-process window on top read as "appeared ON TOP after the guard passed": WARN + exit 1
  # on a send that worked, while the identical scene with --to stayed green. One reality, two
  # exit codes, and the message was factually false about when the window appeared.
  $p02RealAbove = ${function:Get-SamePidWindowsAbove}
  try {
    $script:p02Calls = 0
    ${function:Get-SamePidWindowsAbove} = { param($t) $script:p02Calls++; return @([pscustomobject]@{ Handle = [IntPtr]7; Class = 'p02-palette'; Title = 'p02' }) }
    $p02Tgt = Resolve-Target ''
    ST-Check 'unit (P-02): the no---to path carries the same PreSendAbove baseline as --to, so a palette that was already there cannot read as a new event' (
      ($script:p02Calls -eq 1) -and ($null -ne $p02Tgt) -and (@($p02Tgt.PSObject.Properties['PreSendAbove']).Count -eq 1) -and (@($p02Tgt.PreSendAbove).Count -eq 1) -and (@($p02Tgt.PreSendAbove)[0].Class -eq 'p02-palette'))
    Write-Output ("      P-02 baseline: producer-calls=$($script:p02Calls) items=" + @($p02Tgt.PreSendAbove).Count)
  } finally {
    ${function:Get-SamePidWindowsAbove} = $p02RealAbove
  }
  # v3.1.0 (P-05 sub-item): the guard's OWN failure used to be an empty catch - "did not run"
  # and "passed" were the same observable. Fail-open stays the right call, silence does not:
  # NOTICE* is the prefix the four send consumers print WITHOUT exiting 1.
  $p05RealAbove = ${function:Get-SamePidWindowsAbove}
  try {
    ${function:Get-SamePidWindowsAbove} = { param($t) throw 'p05-sampler-broke' }
    $p05Tgt = [pscustomobject]@{ Pid = 1; Handle = [IntPtr]0; Title = 'p05' }
    $p05Msg = Test-PostSendForeground $p05Tgt $false
    ST-Check 'unit (P-05): a broken post-send guard returns a NOTICE naming the failure and keeps the exit code, never the empty string' (
      ("$p05Msg" -like 'NOTICE*') -and ("$p05Msg" -like '*p05-sampler-broke*') -and ("$p05Msg" -like '*was NOT re-verified*'))
    Write-Output ('      P-05 self-report: [' + $p05Msg + ']')
  } finally {
    ${function:Get-SamePidWindowsAbove} = $p05RealAbove
  }
  # ---------- unit: v1.5.1 occlusion self-proof ----------
  $og = Get-OcclusionPoints 100 100 100 100 5
  $ogInset = $true
  foreach ($p in @($og.Points)) {
    if ($p.X -lt 102 -or $p.X -gt 198 -or $p.Y -lt 102 -or $p.Y -gt 198) { $ogInset = $false }
  }
  $ogDistinct = @($og.Points | ForEach-Object { "$($_.X),$($_.Y)" } | Sort-Object -Unique).Count
  ST-Check 'unit: occlusion grid - 5x5 = 25 points, all 2px inside the edges, distinct' (
    $og.N -eq 25 -and @($og.Points).Count -eq 25 -and $ogInset -and $ogDistinct -eq 25)
  $ogTiny = Get-OcclusionPoints 0 0 3 3 5
  ST-Check 'unit: occlusion grid - tiny region degrades to one centre point' (
    $ogTiny.N -eq 1 -and $ogTiny.Points[0].X -eq 1 -and $ogTiny.Points[0].Y -eq 1)
  $ogZero = Get-OcclusionPoints 0 0 0 5 5
  ST-Check 'unit: occlusion grid - zero size yields no points (no crash)' ($ogZero.N -eq 0)

  $vsO = [System.Windows.Forms.SystemInformation]::VirtualScreen
  $pgO = Get-OcclusionPoints ($vsO.X - 6) ($vsO.Y + 10) 30 30 5
  $expSkipO = 0
  foreach ($p in @($pgO.Points)) {
    if ($p.X -lt $vsO.X -or $p.X -ge ($vsO.X + $vsO.Width) -or $p.Y -lt $vsO.Y -or $p.Y -ge ($vsO.Y + $vsO.Height)) { $expSkipO++ }
  }
  $vO = Get-OcclusionVerdict ($vsO.X - 6) ($vsO.Y + 10) 30 30 ([IntPtr]0x0BADC0DE) 5
  ST-Check 'unit: occlusion - offscreen points go to Skipped, never Mismatch' (
    $expSkipO -gt 0 -and $vO.Skipped -eq $expSkipO -and $vO.Checked -eq (25 - $expSkipO) -and $vO.Mismatch -eq $vO.Checked)
  $vOff = Get-OcclusionVerdict ($vsO.X - 2000) ($vsO.Y + 10) 100 100 ([IntPtr]0x0BADC0DE) 5
  ST-Check 'unit: occlusion - all-offscreen is its own state (not a 0% pass)' (
    $vOff.Checked -eq 0 -and $vOff.Err -eq 'all-offscreen')
  $mO = Merge-OcclusionHits @(
    @{ Hwnd = [IntPtr]111; Pid = 42; Proc = 'aaa'; Title = 't1' },
    @{ Hwnd = [IntPtr]111; Pid = 42; Proc = 'aaa'; Title = 't1' },
    @{ Hwnd = [IntPtr]111; Pid = 42; Proc = 'aaa'; Title = 't1' },
    @{ Hwnd = [IntPtr]222; Pid = 43; Proc = 'bbb'; Title = 't2' })
  ST-Check 'unit: occlusion - Covering dedupes by root handle (count aggregated)' (
    @($mO.Covering).Count -eq 2 -and $mO.Covering[0].Count -eq 3 -and $mO.Covering[0].Pid -eq 42 -and $mO.Covering[1].Count -eq 1)
  $rmA = Resolve-OcclusionMode '' $false $false
  $rmB = Resolve-OcclusionMode '' $false $true
  $rmC = Resolve-OcclusionMode '' $true $true
  $rmD = Resolve-OcclusionMode 'off' $true $true
  $rmE = Resolve-OcclusionMode 'strict' $false $false
  ST-Check 'unit: occlusion mode - read=warn / strict default / allow downgrades / off bypasses / strict upgrades' (
    $rmA.Action -eq 'warn' -and $rmB.Action -eq 'strict' -and $rmC.Action -eq 'warn' -and $rmD.Action -eq 'off' -and $rmE.Action -eq 'strict')
  $rmBad = $true
  try { $null = Resolve-OcclusionMode 'nope' $false $false } catch { $rmBad = $false }
  ST-Check 'unit: occlusion mode rejects a bogus value' (-not $rmBad)
  $sfO = Split-OcclusionFlags @('a', '--occlude', 'warn', 'b', '--allow-occluded', '--occlude-grid', '7')
  ST-Check 'unit: Split-OcclusionFlags strips+parses' (
    @($sfO.Words).Count -eq 2 -and $sfO.Words[0] -eq 'a' -and $sfO.Words[1] -eq 'b' -and $sfO.Occlude -eq 'warn' -and $sfO.OcclGrid -eq 7 -and $sfO.AllowOccluded)

  $toks = Split-LogArgs "click 100 200 --to 'Some Window'"
  # v3.0.1 (audit #14): this used to read `$toks.Count -eq 4 -and $toks[3] -eq '--to' -or
  # ($toks -contains 'Some Window')`. Two faults in one line: -and binds tighter than -or,
  # so the whole front half could be discarded by the tail; and the input actually yields
  # FIVE tokens (click / 100 / 200 / --to / 'Some Window'), making `Count -eq 4 -and
  # $toks[3] -eq '--to'` structurally false - the assertion passed only on its weak tail,
  # i.e. it never checked the flag position at all. Positions are now pinned, because the
  # replay path reads exactly those indices back out.
  ST-Check 'unit: Split-LogArgs keeps the quoted arg whole AND the flag in its own slot (five tokens, --to at index 3)' (
    (@($toks).Count -eq 5) -and ($toks[3] -ceq '--to') -and ($toks[4] -ceq 'Some Window') -and
    ($toks[0] -ceq 'click') -and ($toks[1] -ceq '100') -and ($toks[2] -ceq '200'))
  # and the precedence trap itself, pinned: an -or tail must not be able to rescue a false
  # front half, so the same expression is asserted with a deliberately wrong index.
  $toksPrecedenceTrap = (@($toks).Count -eq 4 -and $toks[3] -ceq 'nope' -or ($toks -contains 'Some Window'))
  ST-Check 'unit: the old -and/-or shape is recorded as unsound (a wrong front half still ORs to true, which is why the assertion above lists every slot)' (
    $toksPrecedenceTrap -eq $true)

  $px = Get-PixelHex 5 5
  ST-Check 'unit: Get-PixelHex returns #RRGGBB' ($px -match '^#[0-9A-F]{6}$')
  $hh = Get-RegionHash 0 0 8 8
  ST-Check 'unit: Get-RegionHash returns md5 hex' ($hh -match '^[0-9a-f]{32}$')
  $sn = Default-ShotName 'rect'
  ST-Check 'unit: Default-ShotName is timestamped .png' ($sn -match 'rect_\d{8}T\d{9}\.png$')

  # ---------- v3.0.0 B-5: dialog-cancel (the operating rule, made mechanical) ----------
  # Name matching is pure, so the dangerous shapes are pinned here rather than in a live run:
  # a stem hit must not fire on a WORD THATmerely starts with the stem, and the two words that
  # would confirm something must never match.
  $cnQu = [string][char]0x53D6 + [string][char]0x6D88
  $cnTrue = @(
    (Test-DialogCancelName 'Cancel'), (Test-DialogCancelName '  CANCEL  '),
    (Test-DialogCancelName 'Cancel(C)'), (Test-DialogCancelName 'cancel(&C)'),
    (Test-DialogCancelName ($cnQu + '(&C)')), (Test-DialogCancelName $cnQu))
  $cnFalse = @(
    (Test-DialogCancelName 'OK'), (Test-DialogCancelName 'Yes'), (Test-DialogCancelName 'Close'),
    (Test-DialogCancelName 'Retry'), (Test-DialogCancelName 'Cancel Order'),
    (Test-DialogCancelName 'CancelButtonStyle'), (Test-DialogCancelName ''),
    (Test-DialogCancelName ([string][char]0x786E + [string][char]0x5B9A)))
  ST-Check 'unit: dialog-cancel matches the cancel stem in case, spacing and accelerator forms' (
    (@($cnTrue | Where-Object { $_ -ne $true }).Count -eq 0))
  ST-Check 'unit: dialog-cancel refuses the confirming words and any name that only starts with the stem' (
    (@($cnFalse | Where-Object { $_ -ne $false }).Count -eq 0))
  Write-Output ("      dialog-cancel name matrix true=[" + (@($cnTrue | ForEach-Object { if ($_) { '1' } else { '0' } }) -join '') +
    "] false=[" + (@($cnFalse | ForEach-Object { if ($_) { '1' } else { '0' } }) -join '') + "]")
  # the closed set IS the safety property, so assert its exact content by CODE POINTS (an
  # early version used `-contains $cnQu`, which stayed red for a reason that turned out to be
  # the comparison, not the set - code points are the only form that says what is in there).
  $cnStems = @(Get-DialogCancelStems)
  $cnOther = @($cnStems | Where-Object { "$_" -ne 'cancel' })
  $cnOtherS = ''
  if (@($cnOther).Count -eq 1) { $cnOtherS = "$($cnOther[0])" }
  $cnChars = @($cnOtherS.ToCharArray())
  ST-Check 'unit: the cancel candidate set is exactly two stems - the EN word and the CN word for cancel, and nothing else' (
    @($cnStems).Count -eq 2 -and (@($cnStems) -contains 'cancel') -and
    @($cnOther).Count -eq 1 -and @($cnChars).Count -eq 2 -and
    [int][char]$cnChars[0] -eq 0x53D6 -and [int][char]$cnChars[1] -eq 0x6D88)
  Write-Output ("      cancel stems: count=" + @($cnStems).Count + ' nonAsciiLen=' + @($cnChars).Count)
  ST-Check 'unit: dialog shape test - #32* class or an owner window yes, an ordinary top-level no' (
    (Test-DialogWindow ([pscustomobject]@{ Class = '#32770'; Owner = [IntPtr]0 })) -and
    (Test-DialogWindow ([pscustomobject]@{ Class = 'Chrome_WidgetWin_1'; Owner = [IntPtr]42 })) -and
    -not (Test-DialogWindow ([pscustomobject]@{ Class = 'Chrome_WidgetWin_1'; Owner = [IntPtr]0 })) -and
    -not (Test-DialogWindow $null))
  # both wiring sites, counted OUTSIDE the selftest body (the marker strings are assembled
  # because a scan that contains its own pattern counts itself - this repo's oldest family).
  $dcCaseMark = "'dialog-cance" + "l' {"
  $dcKnownMark = '$' + "known = @('click'"
  $dcCase = @(); $dcKnown = @()
  for ($ci = 0; $ci -lt $codeLines.Count; $ci++) {
    if ($ci -ge $j5ProdStart -and $ci -lt $j5ProdEnd) { continue }
    if ($codeLines[$ci] -match '^\s*#') { continue }
    if ($codeLines[$ci].Contains($dcCaseMark)) { $dcCase += ($ci + 1) }
    if ($codeLines[$ci].Contains($dcKnownMark)) { $dcKnown += ($ci + 1) }
  }
  $dcStepMember = @($codeLines | Where-Object { $_.Contains("'dialog-cancel'") -and $_.Contains('win-close') })
  ST-Check 'lint: dialog-cancel is a real dispatch case AND a known script step (both wiring sites exist)' (
    @($dcCase).Count -eq 1 -and @($dcKnown).Count -ge 1 -and @($dcStepMember).Count -ge 1)

  # ---------- v2.3.0 red-1/red-2: the occlusion front gate over the weak receipt chain ----------
  # Real machine, 2026-10-02: two negative controls (paste into Program Manager, a target that
  # receives nothing) were both ACCEPTED on receipt=lines-changed because the legs sampled the
  # screen rect and the coverer supplied the motion (a playing video; then the foreground
  # switch itself). The gate closes the whole weak chain while the target rect is covered and
  # names the percentage it measured.
  $pvGateThr = [double](Get-PasteReceiptOcclusionMax)
  ST-Check 'unit: the shipped receipt occlusion gate is one specific spoken number (0) - any covered sample point closes the weak chain, and a default nobody reads could be set to never-gate' (
    $pvGateThr -eq 0)
  $pvGateAll = Get-PasteReceiptVerdict @{ VerbatimOk = $false; Threshold = 200; HeightMin = 8; PayloadChars = 12774; UiaBefore = 14; UiaAfter = 99; HeightBefore = 240; HeightAfter = 900; LinesBefore = 5; LinesAfter = 3; HashBefore = 'aaaa1111'; HashAfter = 'bbbb2222'; OccludedAfter = 100.0; OcclusionMax = 0; CoveredBy = "pid=999 'X' (25 of 25 sample points)" }
  ST-Check 'unit: paste receipt - an occluded target refuses the WHOLE weak chain even when uia-nodes AND grow-height AND lines-changed all moved, and names the pct, the coverer and why (front gate; covered pixels cannot tell target from coverer)' (
    (-not $pvGateAll.Ok) -and ($pvGateAll.Criterion -ceq 'occluded-refused') -and
    $pvGateAll.Detail.Contains('occluded-refused=100%') -and $pvGateAll.Detail.Contains('coveredBy=pid=999') -and
    $pvGateAll.Detail.Contains('nodes 14->99') -and $pvGateAll.Detail.Contains('h 240->900') -and
    $pvGateAll.Detail.Contains('lines 5->3') -and $pvGateAll.Detail.Contains('cannot tell the target from its coverer'))
  $pvGateOne = Get-PasteReceiptVerdict @{ VerbatimOk = $false; Threshold = 200; HeightMin = 8; PayloadChars = 12774; UiaBefore = 14; UiaAfter = 14; HeightBefore = 240; HeightAfter = 240; LinesBefore = 5; LinesAfter = 3; HashBefore = 'aaaa1111'; HashAfter = 'bbbb2222'; OccludedAfter = 4.0; OcclusionMax = 0; CoveredBy = "pid=998 'Y' (1 of 25 sample points)" }
  ST-Check 'unit: paste receipt - ONE covered sample point out of 25 (4%) already closes the gate (the read is 25-point sampled; a single covered point is already not the target own pixels)' (
    (-not $pvGateOne.Ok) -and ($pvGateOne.Criterion -ceq 'occluded-refused') -and $pvGateOne.Detail.Contains('occluded-refused=4%'))
  $pvOpen = Get-PasteReceiptVerdict @{ VerbatimOk = $false; Threshold = 200; HeightMin = 8; PayloadChars = 8556; UiaBefore = 14; UiaAfter = 15; HeightBefore = 240; HeightAfter = 240; LinesBefore = 5; LinesAfter = 5; HashBefore = 'aaaa1111'; HashAfter = 'aaaa1111'; OccludedAfter = 0.0; OcclusionMax = 0; CoveredBy = '' }
  ST-Check 'unit: paste receipt - a clean target (occluded=0) keeps the shipped legs exactly, uia-nodes first (the gate must not silently weaken the clean path)' (
    $pvOpen.Ok -and $pvOpen.Degraded -and ($pvOpen.Criterion -ceq 'uia-nodes'))
  # The wiring, in production code only (the scan skips the selftest body the same way the
  # autoexpect lints above do).
  $prDef = 0; $prBaseCall = 0; $prAnnounce = 0; $prFloorDef = 0; $prFreshRect = 0; $prBodyIn = $false; $prOccKnob = 0; $prOccRefuse = 0
  for ($awi = 0; $awi -lt $codeLines.Count; $awi++) {
    if ($awi -ge $j5ProdStart -and $awi -lt $j5ProdEnd) { continue }
    if ($codeLines[$awi] -match '^\s*#') { continue }
    if ($codeLines[$awi].StartsWith('function Get-PasteReceiptVerdict')) { $prDef++ }
    if ($codeLines[$awi].StartsWith('function Get-PasteFoldThreshold')) { $prFloorDef++ }
    if ($codeLines[$awi].StartsWith('function Get-PasteReceiptOcclusionMax')) { $prOccKnob++ }
    if ($codeLines[$awi].Contains(('occluded-' + 'refused='))) { $prOccRefuse++ }
    if ($codeLines[$awi].Contains(('Get-PasteReceipt' + 'Baseline $p $target'))) { $prBaseCall++ }
    if ($codeLines[$awi].Contains(('accepted on ' + 'receipt='))) { $prAnnounce++ }
    if ($codeLines[$awi].StartsWith('function Get-PasteReceipt(')) { $prBodyIn = $true; continue }
    if ($prBodyIn -and ($codeLines[$awi] -match '^function ')) { $prBodyIn = $false }
    if ($prBodyIn -and $codeLines[$awi].Contains(('$_.Handle -eq $' + 'target.Handle'))) { $prFreshRect++ }
  }
  ST-Check 'lint: the paste receipt verdict has exactly one pure producer and one fold-threshold producer (a second copy of the rule would drift silently)' (
    ($prDef -eq 1) -and ($prFloorDef -eq 1))
  # Deliberately ONE call site: paste-file's needle is the attached FILE NAME, which targets do
  # render, so the fold problem does not apply there and its semantics stay exactly as shipped.
  ST-Check 'lint: only the text-payload paste captures a receipt baseline (exactly 1 site; paste-file keeps its verbatim-only judgement because its needle is a file name it does render)' (
    $prBaseCall -eq 1)
  if ($prBaseCall -ne 1) { Write-Output "      receipt baseline call sites: $prBaseCall (expected 1)" }
  ST-Check 'lint: a degraded paste receipt is announced in words on the message that grants it (no silent second criterion)' (
    $prAnnounce -eq 1)
  # The first live round proved this one the hard way: with the cached rect the grow-height leg
  # reads the size the window had when the command started, so it is permanently flat.
  ST-Check 'lint: the receipt re-queries the window rect by handle instead of trusting the target snapshot (grow-height on a cached rect can never fire - live-v220-1 caught it at h 287->287 while wins saw 287->335)' (
    $prFreshRect -eq 1)
  ST-Check 'lint: the receipt occlusion gate has exactly one knob producer (a second copy of the rule would drift silently)' (
    $prOccKnob -eq 1)
  ST-Check 'lint: the occlusion refusal wording is spoken by exactly one production line - the front gate verdict itself (the echo contract and the log field both read it from there)' (
    $prOccRefuse -eq 1)


  # ---------- v1.9.0: script popup survival guard (J-02 C) ----------
  # Pure-rule units first: Test-PopupGuardAlive carries the survival VERDICT (Compare-
  # PopupDelta answers "what appeared"; the guard needs the complementary "is THIS
  # baseline popup still there", the granularity gap the task order told us to expect).
  $c36Base = @{ Hwnd = [IntPtr]4321; Pid = 777; Class = '#32768'; X = 620; Y = 300; W = 480; H = 320; OwnerHwnd = [IntPtr]4000; Above0 = @(); Tolerance = 3; MustBeFg = $false }
  $c36Above = @([pscustomobject]@{ Handle = [IntPtr]4321; Class = '#32768'; Title = 'x'; Transparent = $false })
  $c36Ok = Test-PopupGuardAlive $c36Base $true $c36Above @{ X = 620; Y = 300; W = 480; H = 320 } ([IntPtr]0)
  ST-Check 'unit: popup guard verdict - alive popup still above its owner with zero drift survives' (
    $c36Ok.Alive -and ($c36Ok.Present -eq 'yes') -and ($c36Ok.Above -eq 'yes') -and ($c36Ok.Drift -eq 'dx=0 dy=0 dw=0 dh=0'))
  $c36Gone = Test-PopupGuardAlive $c36Base $false $c36Above $null ([IntPtr]0)
  ST-Check 'unit: popup guard verdict - destroyed window reads popup GONE with present=no' (
    (-not $c36Gone.Alive) -and ($c36Gone.Present -eq 'no') -and $c36Gone.Reason.Contains('popup GONE'))
  $c36Buried = Test-PopupGuardAlive $c36Base $true @() @{ X = 620; Y = 300; W = 480; H = 320 } ([IntPtr]0)
  ST-Check 'unit: popup guard verdict - an owned popup no longer above its owner fails the z-order leg' (
    (-not $c36Buried.Alive) -and ($c36Buried.Above -eq 'no') -and $c36Buried.Reason.Contains('no longer above its owner'))
  $c36Moved = Test-PopupGuardAlive $c36Base $true $c36Above @{ X = 620; Y = 290; W = 480; H = 320 } ([IntPtr]0)
  ST-Check 'unit: popup guard verdict - rect drift beyond tolerance fails with measured deltas' (
    (-not $c36Moved.Alive) -and $c36Moved.Reason.Contains('rect drift dx=0 dy=10') -and $c36Moved.Reason.Contains('exceeds tolerance=3'))
  $c36Jitter = Test-PopupGuardAlive $c36Base $true $c36Above @{ X = 622; Y = 299; W = 481; H = 320 } ([IntPtr]0)
  ST-Check 'unit: popup guard verdict - drift within tolerance survives' ($c36Jitter.Alive -and ($c36Jitter.Drift -eq 'dx=2 dy=1 dw=1 dh=0'))
  $c36FgBase = @{ Hwnd = [IntPtr]4321; Pid = 777; Class = 'x'; X = 0; Y = 0; W = 10; H = 10; OwnerHwnd = [IntPtr]4000; Above0 = @(); Tolerance = 3; MustBeFg = $true }
  $c36FgLost = Test-PopupGuardAlive $c36FgBase $true $c36Above @{ X = 0; Y = 0; W = 10; H = 10 } ([IntPtr]9999)
  $c36FgKept = Test-PopupGuardAlive $c36FgBase $true $c36Above @{ X = 0; Y = 0; W = 10; H = 10 } ([IntPtr]4321)
  ST-Check 'unit: popup guard verdict - must-be-foreground leg fires only when the foreground moved away' (
    (-not $c36FgLost.Alive) -and $c36FgLost.Reason.Contains('foreground is no longer the guarded popup') -and $c36FgKept.Alive)
  $c36Free = Test-PopupGuardAlive (@{ Hwnd = [IntPtr]4321; Pid = 777; Class = 'x'; X = 0; Y = 0; W = 10; H = 10; OwnerHwnd = [IntPtr]::Zero; Above0 = @(); Tolerance = 3; MustBeFg = $false }) $true @() @{ X = 0; Y = 0; W = 10; H = 10 } ([IntPtr]0)
  ST-Check 'unit: popup guard verdict - an ownerless popup skips the z-order leg as n/a and survives on IsWindow+rect' (
    $c36Free.Alive -and ($c36Free.Above -eq 'n/a (no owner)'))
  # v2.0.1 merge, two ways the guard can be wired WRONG while still looking alive:
  # (a) the arm-time z-order snapshot is fed to the differ as the AFTER set (then a
  #     popup that closed would still read present), (b) presence taken from the
  #     transparent-filtered New list (then a click-through popup aborts every script
  #     that guards it). Both are pinned against the merged differ's own answer.
  $c36SnapBase = @{ Hwnd = [IntPtr]4321; Pid = 777; Class = '#32768'; X = 620; Y = 300; W = 480; H = 320; OwnerHwnd = [IntPtr]4000; Above0 = $c36Above; Tolerance = 3; MustBeFg = $false }
  $c36SnapOk = Test-PopupGuardAlive $c36SnapBase $true @() @{ X = 620; Y = 300; W = 480; H = 320 } ([IntPtr]0)
  ST-Check 'unit: popup guard verdict - the z-order leg reads the CURRENT enumeration, not the arm-time snapshot (buried popup fails even when it was in the baseline)' (
    (-not $c36SnapOk.Alive) -and ($c36SnapOk.Above -eq 'no'))
  $c36TipPopup = @([pscustomobject]@{ Handle = [IntPtr]4321; Class = 'tooltips_class32'; Title = 'x'; Transparent = $true })
  $c36TipAlive = Test-PopupGuardAlive $c36Base $true $c36TipPopup @{ X = 620; Y = 300; W = 480; H = 320 } ([IntPtr]0)
  ST-Check 'unit: popup guard verdict - a click-through guarded popup is still above its owner (the alarm filter must not decide existence)' (
    $c36TipAlive.Alive -and ($c36TipAlive.Above -eq 'yes'))
  $c36Log = '2026-10-01 00:00:00 UTC | script | C:\temp\steps.json | POPUP-GUARD-ABORTED at step 4 of 7: popup GONE (window destroyed)'
  $c36Clean = '2026-10-01 00:00:00 UTC | click | 10 20 | pid=1 title=x'
  ST-Check 'unit: replay abort scanner - the popup-guard marker is found and ordinary lines are not' (
    (@(Test-ReplayPopupAbort @($c36Log, $c36Clean)).Count -eq 1) -and (@(Test-ReplayPopupAbort @($c36Clean)).Count -eq 0))
  # Wiring: the two script steps exist, the guard aborts instead of skipping, the
  # win-close auto-release and the replay refusal are each wired exactly once, and
  # require-popup/release-popup stay OUT of the replayable list (they are script steps,
  # not CLI commands - replay must never see them).
  $c37Known = 0
  $c37ReplLine = New-Object System.Collections.ArrayList
  for ($c37i = 0; $c37i -lt $codeLines.Count; $c37i++) {
    if ($c37i -ge $j5ProdStart -and $c37i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c37i].Contains("`$known = @('click'")) { $c37Known++ }
    if ($codeLines[$c37i].Contains("`$replayable = @('move'")) { [void]$c37ReplLine.Add($codeLines[$c37i]) }
  }
  $c37ThrowN = 0; $c37AbortN = 0; $c37MarkN = 0; $c37AutoN = 0; $c37RefuseN = 0; $c37AliveCall = 0
  for ($c37i = 0; $c37i -lt $codeLines.Count; $c37i++) {
    if ($c37i -ge $j5ProdStart -and $c37i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c37i] -match '^\s*#') { continue }
    if ($codeLines[$c37i].Contains(('POPUP-GUARD-' + 'ABORT: popup guard: '))) { $c37ThrowN++ }
    if ($codeLines[$c37i].Contains(('script aborted: popup guard ' + 'failed'))) { $c37AbortN++ }
    if ($codeLines[$c37i].Contains(('POPUP-GUARD-AB' + 'ORTED at step'))) { $c37MarkN++ }
    if ($codeLines[$c37i].Contains(('win-close closed the guarded ' + 'popup'))) { $c37AutoN++ }
    if ($codeLines[$c37i].Contains(('refusing to replay a script that was aborted by the popup guard '))) { $c37RefuseN++ }
    if ($codeLines[$c37i].Contains('= Test-PopupGuardAlive ')) { $c37AliveCall++ }
  }
  ST-Check 'lint: require-popup/release-popup are known script steps, the survival verdict is called from exactly one place, and the abort/refusal contracts each have one producer' (
    ($c37Known -eq 1) -and ($c37AliveCall -eq 1) -and ($c37ThrowN -eq 1) -and ($c37AbortN -eq 1) -and ($c37MarkN -eq 1) -and ($c37AutoN -eq 2) -and ($c37RefuseN -eq 1))
  ST-Check 'lint: require-popup and release-popup never enter the replayable list (script steps, not CLI commands - replay must not see them)' (
    (@($c37ReplLine).Count -eq 1) -and (-not ($c37ReplLine[0].Contains('require-popup'))) -and (-not ($c37ReplLine[0].Contains('release-popup'))))
  Write-Output ("      popup guard wiring: known=$c37Known alive-call=$c37AliveCall throw=$c37ThrowN abort-line=$c37AbortN marker=$c37MarkN auto-release=$c37AutoN refuse=$c37RefuseN")

  # ---------- lint: v2.0.1 popup delta merge (owner ruling 2026-10-01) ----------
  # The failure mode of a MERGE is not a missing check, it is a second copy that
  # quietly disagrees - which is exactly why v1.9.0 shipped Test-PopupGuardAlive
  # beside the differ. So this pins: every handle-membership operator lives inside
  # Compare-PopupDelta, the guard asks the differ instead of computing it, and each
  # direction still has exactly one production consumer (the selftest body is skipped
  # so the units' own calls cannot satisfy or break the count).
  $c38Diff = @(-1, -1); $c38Grd = @(-1, -1); $c38Open = ''
  for ($c38i = 0; $c38i -lt $codeLines.Count; $c38i++) {
    if ($codeLines[$c38i] -match '^function ') {
      if ($c38Open -eq 'diff' -and $c38Diff[1] -lt 0) { $c38Diff[1] = $c38i }
      if ($c38Open -eq 'grd' -and $c38Grd[1] -lt 0) { $c38Grd[1] = $c38i }
      $c38Open = ''
      if ($codeLines[$c38i] -match '^function Compare-PopupDelta') { $c38Diff = @($c38i, -1); $c38Open = 'diff' }
      if ($codeLines[$c38i] -match '^function Test-PopupGuardAlive') { $c38Grd = @($c38i, -1); $c38Open = 'grd' }
    }
  }
  $c38Member = 0; $c38MemberInDiffer = 0; $c38Call = 0; $c38CallInGuard = 0
  for ($c38i = 0; $c38i -lt $codeLines.Count; $c38i++) {
    if ($c38i -ge $j5ProdStart -and $c38i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c38i] -match '^\s*#') { continue }
    if ($codeLines[$c38i] -match '(-not)?contains \[int64\]') {
      $c38Member++
      if ($c38i -ge $c38Diff[0] -and $c38i -lt $c38Diff[1]) { $c38MemberInDiffer++ }
    }
    if ($codeLines[$c38i].Contains('= Compare-PopupDelta ')) {
      $c38Call++
      if ($c38i -ge $c38Grd[0] -and $c38i -lt $c38Grd[1]) { $c38CallInGuard++ }
    }
  }
  ST-Check 'lint: popup handle-set membership has one producer and the guard reads the differ (v2.0.1 merge, no second copy)' (
    ($c38Member -eq 2) -and ($c38MemberInDiffer -eq 2) -and ($c38Call -eq 2) -and ($c38CallInGuard -eq 1) -and ($c38Diff[1] -gt $c38Diff[0]) -and ($c38Grd[1] -gt $c38Grd[0]))
  Write-Output ("      popup delta merge: membership=$c38Member/$c38MemberInDiffer differ-range=$($c38Diff[0])..$($c38Diff[1]) guard-range=$($c38Grd[0])..$($c38Grd[1]) calls=$c38Call/$c38CallInGuard")


  # context hand-back (A-14l): these names were produced here while the section was inline and are
  # still read by bodies that stayed in lib/selftest.ps1 - the three sample window objects feed the
  # popup-delta units that sit under a later banner, and the dialog-cancel line numbers feed the audit
  # detail line further down. They leave through the declared channel, never through scope luck.
  $Ctx['dcCase'] = $dcCase
  $Ctx['dcKnown'] = $dcKnown
  $Ctx['wA'] = $wA
  $Ctx['wB'] = $wB
  $Ctx['wT'] = $wT
}
