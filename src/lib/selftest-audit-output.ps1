# lib/selftest-audit-output.ps1 - one family of the selftest section, lifted out of lib/selftest.ps1
# by A-14m (A-beta). Bodies are byte-identical to what the section carried, with ONE line deliberately
# left behind: the dialog-cancel wiring echo reads popup-occlusion hand-backs, which A-14l binds into
# the orchestration scope by name, and a lifted family may only be handed published context. Routing a
# value from one family to another would be a new channel, not a move - so the echo stays where its
# inputs are and this file carries the gates.
#
# The audit/outlet family: audit-log redaction and rotation, the two OCR --json key sets, the covering
# list rendered in one place, the action family --json envelope, --json never accepted-and-ignored,
# --dump pointers, a stamp that claims UTC, resource hygiene, and the line/occurrence gap spoken aloud.
function Invoke-SelftestFamily-AuditOutput($Ctx) {
  # context handover (the one thing in this file above the lifted text that is not lifted text)
  $clCount = $Ctx['clCount']
  $code = $Ctx['code']
  $codeLines = $Ctx['codeLines']
  $evMark = $Ctx['evMark']
  $evWire = $Ctx['evWire']
  $j5ProdEnd = $Ctx['j5ProdEnd']
  $j5ProdStart = $Ctx['j5ProdStart']

  # ---------- contract: v1.5.3 the two OCR --json top-level key sets are pinned ----------
  # This shape is a PUBLISHED CONTRACT, not an implementation detail: nothing inside
  # this repo parses it (ConvertFrom-Json appears only in script/replay paths), the
  # real consumers are AI sessions reading the output. v1.5.1 already broke it once
  # (array -> object) with nothing but a README line to mark the boundary, so the
  # set is now compared EXACTLY - add a key or drop a key and this goes red, which
  # is the moment $JsonSchemaVersion and the two README lines must change together.
  $cFind = New-OcrJsonEnvelope 'hits' $null @()
  $cRead = New-OcrJsonEnvelope 'lines' $null @()
  # v3.0.0 (B-6) CONTRACT CHANGE: both envelopes gained `contentTrust` and schemaVersion moved
  # 1 -> 2. This is the bookkeeping the envelope comment demands ("changing the key set is a
  # breaking change: bump schemaVersion AND the two README lines in the same commit"), and it
  # is why the comparison is an EXACT set: had the check been "contains the keys I care
  # about", the new key would have shipped without a single check noticing.
  $cWantFind = Get-JsonContractKeySet 'find'
  $cWantRead = Get-JsonContractKeySet 'read'
  # The contract must have ONE home. Tokens are assembled at runtime because this scanner's own
  # source contains the very literals it hunts (measured twice this round already).
  $jkTok = "'schemaVersion', 'contentTrust', 'oc" + "cluded', 'coveredBy'"
  $jkCall = 'Get-JsonContract' + "KeySet '"
  $jkProducer = 0; $jkReaders = 0; $jkLits = 0
  foreach ($jkL in $codeLines) {
    $jkT = "$jkL"
    if ($jkT.StartsWith('function Get-JsonContractKeySet')) { $jkProducer++ }
    if ($jkT.Contains($jkCall)) { $jkReaders++ }
    if ($jkT.Contains($jkTok)) { $jkLits++ }
  }
  ST-Check 'lint: the published --json key contract has exactly one home (one producer, five readers, no stray literal copy - a second copy is how v3.0.0 drifted and two live checks sat red unseen for two rounds)' (
    ($jkProducer -eq 1) -and ($jkReaders -eq 5) -and ($jkLits -eq 2))
  Write-Output ('      json-contract homes: producer=' + $jkProducer + ' readers=' + $jkReaders + ' literals=' + $jkLits)
  $cGotFind = (@($cFind.PSObject.Properties.Name | Sort-Object) -join ',')
  $cGotRead = (@($cRead.PSObject.Properties.Name | Sort-Object) -join ',')
  ST-Check 'contract: find-text --json top-level keys are exactly schemaVersion+occluded+coveredBy+hits (add or drop one = breaking)' (
    $cGotFind -ceq $cWantFind)
  ST-Check 'contract: read-text --json top-level keys are exactly schemaVersion+occluded+coveredBy+lines (add or drop one = breaking)' (
    $cGotRead -ceq $cWantRead)
  # v3.0.0 (B-6) BREAKING CHANGE, declared: 1 -> 2, because `contentTrust` joined the key set
  # of every envelope. v3.1.0 (X-01) BREAKING CHANGE, declared: 2 -> 3, because the action
  # family got an envelope (see Get-ActionJsonCommandSet). The literal expectation stays a
  # literal ON PURPOSE - bumping the variable without coming here is the mistake this check
  # exists to make impossible, and the second conjunct proves the builders read the same
  # variable rather than a copied constant.
  ST-Check 'contract: both envelopes report the declared schemaVersion, which is 3 since the action family joined the contract' (
    [int]$script:JsonSchemaVersion -eq 3 -and $cFind.schemaVersion -eq 3 -and $cRead.schemaVersion -eq 3)
  # the occlusion half of the contract, from a synthetic gate: a gate that ran must
  # produce an INTEGER percent (not 37.4, not ''), and coveredBy must be an array
  # even for a single coverer - a scalar here silently breaks JSON consumers that
  # iterate it.
  $cGate = @{ Err = $false; Pct = 37.4; Covering = @(@{ Pid = 4242; Proc = 'notepad'; Title = 'T'; Count = 3 }) }
  $cGateObj = New-OcrJsonEnvelope 'hits' $cGate @()
  $cCov1 = @($cGateObj.coveredBy)[0]
  $cGotCov = (@($cCov1.PSObject.Properties.Name | Sort-Object) -join ',')
  $cWantCov = (@('count', 'pid', 'proc', 'title') | Sort-Object) -join ','
  ST-Check 'contract: occluded is the rounded integer percent and coveredBy stays an array of {pid,proc,title,count}' (
    $cGateObj.occluded -is [int] -and $cGateObj.occluded -eq 37 -and
    @($cGateObj.coveredBy).Count -eq 1 -and $cGotCov -ceq $cWantCov)
  $cNoGate = New-OcrJsonEnvelope 'hits' $null @()
  ST-Check 'contract: no gate means occluded=null and coveredBy=[] (keys never disappear, only their values do)' (
    $null -eq $cNoGate.occluded -and @($cNoGate.coveredBy).Count -eq 0)
  # Wiring nail: the checks above prove what the BUILDER emits. They would still be
  # green if a command quietly went back to hand-building its object at the call
  # site, so pin the emission path itself - exactly one ConvertTo-Json per command,
  # both fed by the envelope variable.
  $cWirePat = '^\s*\$envelope \| ConvertTo-Json -Compress -Depth (4|5)\s*$'
  $cWire = 0
  for ($i = 0; $i -lt $codeLines.Count; $i++) {
    if ($codeLines[$i] -match $cWirePat) { $cWire++ }
  }
  ST-Check 'contract: find-text and read-text both emit --json through the envelope builder (no hand-built object at the call site)' (
    $cWire -eq 2)
  $cPlantWire = '$envelope | ConvertTo-Json -Compress -Depth 5'
  ST-Check 'contract: wiring pattern detects a planted emission (not vacuous)' ($cPlantWire -match $cWirePat)
  # control: the set comparison is not comparing a constant - one extra key really
  # does break it, which is the entire point of pinning a contract
  $cWithExtra = [pscustomobject]@{ schemaVersion = 1; occluded = $null; coveredBy = @(); hits = @(); extraKey = 1 }
  $cGotExtra = (@($cWithExtra.PSObject.Properties.Name | Sort-Object) -join ',')
  ST-Check 'contract: an added top-level key breaks the comparison (control)' ($cGotExtra -cne $cWantFind)

  # ---------- contract: v1.5.4 (R-25) the covering list is rendered in ONE place ----------
  # R-25 reached me as "two pids blamed in one command". Measured, that reading came
  # from the observer truncating the report; the real defects were that three call
  # sites rendered the same list in three shapes, the gate path dropped everything
  # past the THIRD coverer silently, and no line said which rectangle it measured.
  # These assertions are what stop any of the three from coming back.
  # Deliberately UNSORTED input: the renderer must sort, so a future change to the
  # upstream ordering can never make the summary and the list disagree.
  $oC1 = @{ Hwnd = [IntPtr]11; Pid = 111; Proc = 'pA'; Title = 'T-A'; Count = 2 }
  $oC2 = @{ Hwnd = [IntPtr]22; Pid = 222; Proc = 'pB'; Title = 'T-B'; Count = 9 }
  $oC3 = @{ Hwnd = [IntPtr]33; Pid = 333; Proc = 'pC'; Title = 'T-C'; Count = 5 }
  $oR = Format-OcclusionCovering @($oC1, $oC3, $oC2) 25
  # A) THE contract the owner asked for: the one-line summary IS the first detailed
  # line's subject - not "whatever [0] happens to be in some other order".
  $oSumPid = ''
  if ((Get-OptValue $oR 'Summary') -match '^pid=(\d+)') { $oSumPid = $Matches[1] }
  $oFirstPid = ''
  if (@((Get-OptValue $oR 'Lines'))[0] -match '^pid=(\d+)') { $oFirstPid = $Matches[1] }
  ST-Check 'contract: the occlusion summary is the first rendered covering line (same pid, by construction)' (
    $oSumPid -ceq $oFirstPid -and $oSumPid -ceq '222')
  ST-Check 'contract: the covering list is ordered by sample points descending (unsorted input in, sorted out)' (
    (@((Get-OptValue $oR 'Items') | ForEach-Object { $_.Count }) -join ',') -ceq '9,5,2')
  # B) every coverer is named with its own count, and the summary ADMITS the rest.
  ST-Check 'contract: every coverer is named with its x/N share - nothing past the third is dropped' (
    @((Get-OptValue $oR 'Lines')).Count -eq 3 -and
    ((Get-OptValue $oR 'Lines') -join '|') -match 'pid=111 .*\(2 of 25 sample points\)' -and
    ((Get-OptValue $oR 'Lines') -join '|') -match 'pid=222 .*\(9 of 25 sample points\)')
  ST-Check 'contract: the one-line summary admits it only names one of them (+K more)' (
    (Get-OptValue $oR 'Summary') -like 'pid=222 * (+2 more)')
  # the marker itself: same helper for both paths, and it never lies
  ST-Check 'unit: (+K more) is empty when nothing is hidden and counts exactly when something is' (
    (Add-OcclusionMore 3 3) -ceq '' -and (Add-OcclusionMore 5 3) -ceq ' (+2 more)' -and
    (Add-OcclusionMore 1 1) -ceq '')
  # four coverers, the shape R-25 was reported in: the 4th must not be invisible
  $oC4 = @{ Hwnd = [IntPtr]44; Pid = 444; Proc = 'pD'; Title = 'T-D'; Count = 1 }
  $oR4 = Format-OcclusionCovering @($oC1, $oC2, $oC3, $oC4) 25
  ST-Check 'contract: with four coverers the gate list still names all four (R-25 was the 4th vanishing)' (
    @((Get-OptValue $oR4 'Lines')).Count -eq 4 -and ((Get-OptValue $oR4 'Lines') -join '|') -match 'pid=444 ' -and
    $oR4.Summary -like '*(+3 more)')
  # summed with an explicit loop, NOT Measure-Object -Property Count: measured here,
  # on hashtables that carry their own 'Count' KEY, Measure-Object sums the INTRINSIC
  # key count (5+5=10) while foreach { $_.Count } reads the entry (2+9=11). Same
  # expression text, two meanings - so anything touching these coverer rows sums by hand.
  $oSum4 = 0
  foreach ($it in @((Get-OptValue $oR4 'Items'))) { $oSum4 += [int]$it.Count }
  ST-Check 'contract: the rendered items are exactly the input items (no drop, no duplicate) and their shares sum' (
    @((Get-OptValue $oR4 'Items')).Count -eq 4 -and @($oR4.Lines).Count -eq @((Get-OptValue $oR4 'Items')).Count -and $oSum4 -eq 17)
  # anti-drift nail: the gate path must never go back to a silent cap. The owners
  # path is ALLOWED to cap (it now says so), so the pattern must exist exactly once.
  $oCap = New-Object System.Collections.ArrayList
  $oCapBound = New-Object System.Collections.ArrayList
  for ($i = 0; $i -lt $codeLines.Count; $i++) {
    $l = $codeLines[$i]
    if ($l -match 'SELFTEST-EXEMPT') { continue }
    # v1.5.7: the owners cap moved behind a named local ($ownMax) so the "we hid K more"
    # statement can sit one line from it (the truncation contract). The old literal
    # "-First 3" pattern therefore no longer matches - asserting on the literal would have
    # made this lint fire on a refactor that strictly improved the thing it cares about.
    if ($l -match 'Select-Object\s+-First\s+(3\b|\$ownMax\b)') { [void]$oCap.Add($i + 1) }
    # ASSEMBLED, not written whole: this scan reads the whole file including its own
    # selftest block, so a literal pattern here would match the line that declares it
    # and the count would be 2 on a file that has exactly one real cap.
    $oCapBindPat = 'Add-OcclusionMore .*Owners.*\$own' + 'Max'
    if ($l -match $oCapBindPat) { [void]$oCapBound.Add($i + 1) }
  }
  ST-Check 'lint: exactly one three-item cap survives in the occlusion code and it is the owners path' (
    @($oCap).Count -eq 1)
  ST-Check 'lint: that cap is bound to its hidden-count helper (a cut that cannot stop admitting)' (
    @($oCapBound).Count -eq 1)
  if (@($oCap).Count -ne 1) { Write-Output "      -First 3 caps at line(s): $(Format-SourceLineList @($oCap))" }
  # the label that made two correct lines look contradictory must always be present
  $oV = Format-OcclusionVerdict 'guard' @{ X = 10; Y = 20; W = 30; H = 40 } 36 (Get-OptValue $oR 'Summary') ''
  $oV0 = Format-OcclusionVerdict 'read' @{ X = 1; Y = 2; W = 3; H = 4 } 0 'unknown' ''
  $oVErr = Format-OcclusionVerdict 'hit' $null 0 '' 'all-offscreen'
  ST-Check 'contract: every occlusion verdict names its scan AND the rect it measured' (
    $oV -like 'scan=guard rect=(10,20,30x40) occluded=36% coveredBy=pid=222*' -and
    $oV0 -ceq 'scan=read rect=(1,2,3x4) occluded=0%')
  ST-Check 'contract: a failed scan says n/a with its reason and never invents a coveredBy' (
    $oVErr -like 'scan=hit occluded=n/a (all-offscreen)*' -and $oVErr -notmatch 'coveredBy')

  # ---------- unit: v1.5.7 (J-05) the line/occurrence gap must be spoken out loud ----------
  # The owner ruled line granularity STAYS (word hits would turn one line containing the
  # text twice into two hits and break every --index script), so the deliverable is the
  # sentence - and a sentence nobody can prove fires is just decoration.
  $j5Two = Format-MultiOccurrenceHint 'AAA' @([pscustomobject]@{ Text = 'AAA BBB AAA' })
  ST-Check 'unit: J-05 hint fires when one hit line holds the needle twice' (
    $j5Two -ne '' -and $j5Two.Contains('2 time(s)') -and $j5Two.Contains('1 hit line(s)') -and $j5Two.Contains('a hit is ONE LINE'))
  $j5One = Format-MultiOccurrenceHint 'AAA' @([pscustomobject]@{ Text = 'AAA BBB' })
  ST-Check 'unit: J-05 hint is silent when hits and occurrences agree' ($j5One -ceq '')
  $j5TwoLines = Format-MultiOccurrenceHint 'AAA' @([pscustomobject]@{ Text = 'AAA x' }, [pscustomobject]@{ Text = 'y AAA' })
  ST-Check 'unit: J-05 hint is silent for two lines with one occurrence each (those ARE two hits)' ($j5TwoLines -ceq '')
  $j5Fold = Format-MultiOccurrenceHint 'ZZZ' @([pscustomobject]@{ Text = 'AAA x' })
  ST-Check 'unit: J-05 never claims occurrences it could not count (a fold-only match says nothing)' ($j5Fold -ceq '')
  $j5Empty = Format-MultiOccurrenceHint '' @([pscustomobject]@{ Text = 'AAA' })
  $j5NoHits = Format-MultiOccurrenceHint 'AAA' @()
  ST-Check 'unit: J-05 prints nothing for an empty needle or an empty hit list' ($j5Empty -ceq '' -and $j5NoHits -ceq '')
  $j5Mark = 'Format-MultiOccurrence' + 'Hint '
  $j5Wire = @()
  for ($j5i = 0; $j5i -lt $codeLines.Count; $j5i++) {
    if ($j5i -ge $j5ProdStart -and $j5i -lt $j5ProdEnd) { continue }
    if ($codeLines[$j5i] -match '^\s*#') { continue }
    if ($codeLines[$j5i].Contains($j5Mark)) { $j5Wire += ($j5i + 1) }
  }
  ST-Check 'lint: find-text, find-click and menu-pick all route the J-05 hint through one producer' (
    @($j5Wire).Count -eq 3 -and $j5ProdStart -gt 0)
  Write-Output "      J-05 production call sites: $(@($j5Wire).Count) (lines $(Format-SourceLineList $j5Wire))"

  # ---------- unit: audit-log redaction + rotation (v1.4.1, audit #4/#13) ----------
  $red = Get-RedactedLogArgs @('type', '--to', 'notepad', 'SECRET-TOKEN-123', '--verify') @('SECRET-TOKEN-123') $false
  ST-Check 'unit: log redaction hides payload, keeps flags and target' (
    (($red -join ' ') -notmatch 'SECRET-TOKEN-123') -and (($red -join ' ') -match '<redacted:16chars>') -and ($red -contains '--to'))
  $redKeep = Get-RedactedLogArgs @('type', 'SECRET-TOKEN-123') @('SECRET-TOKEN-123') $true
  ST-Check 'unit: --log-payload records the payload verbatim' (($redKeep -join ' ') -match 'SECRET-TOKEN-123')
  $redGuard = Get-RedactedLogArgs @('click', '10', '20', '--guard-region', '0,0,600,50=SEEKRET') @() $false
  ST-Check 'unit: guard-region needle redacted, coordinates kept' (
    (($redGuard -join ' ') -notmatch 'SEEKRET') -and (($redGuard -join ' ') -match '0,0,600,50=<redacted:7chars>'))
  $rotDir = Join-Path $env:TEMP ('dtrot_' + [guid]::NewGuid().ToString('N'))
  [void](New-Item -ItemType Directory -Force -Path $rotDir)
  try {
    $rotLog = Join-Path $rotDir 'actions.log'
    [System.IO.File]::WriteAllText($rotLog, ('x' * 300))
    $did = Invoke-LogRotation $rotLog 100 2
    $rotated = (-not (Test-Path $rotLog)) -and (@(Get-ChildItem $rotDir -Filter 'actions_*.log').Count -ge 1)
    for ($ai = 1; $ai -le 4; $ai++) { [System.IO.File]::WriteAllText((Join-Path $rotDir ('actions_000' + $ai + '.log')), ('y' * 10)) }
    [System.IO.File]::WriteAllText($rotLog, ('z' * 300))
    Invoke-LogRotation $rotLog 100 2 | Out-Null
    $archives = @(Get-ChildItem $rotDir -Filter 'actions_*.log').Count
    ST-Check 'unit: log rotation archives the over-threshold log' ($did -and $rotated)
    ST-Check 'unit: log rotation prunes archives beyond keep' ($archives -eq 2)
  } finally { Remove-Item -LiteralPath $rotDir -Recurse -Force -ErrorAction SilentlyContinue }

  # ---------- v3.0.0 B-4: --dump (write the bulk to a file, print a pointer) ----------
  # The closed set first, both directions: every declared name must be a REAL command (a
  # typo in the set would advertise a flag that reaches nothing), and a real command that is
  # not in the set must be refused (the silent no-op is what --json had been doing).
  $dumpSet = @(Get-DumpCommandSet)
  $dumpNotCommands = @($dumpSet | Where-Object { -not ($code -match ("'" + [regex]::Escape($_) + "' \{")) })
  ST-Check 'lint: every --dump command is a real dispatch case (no advertised typo can reach nothing)' (@($dumpNotCommands).Count -eq 0)
  ST-Check 'unit: --dump is accepted for the declared read commands and refused for an action and for a non-command' (
    (Test-DumpCommand 'read-text') -and (Test-DumpCommand 'uia-tree') -and (Test-DumpCommand 'wins') -and
    -not (Test-DumpCommand 'click') -and -not (Test-DumpCommand 'wins2') -and -not (Test-DumpCommand ''))
  # production sites only: the units below call the emitter themselves, and a scan that
  # counts its own test corpus is the self-match family again.
  $dumpMark = 'Emit-Dump' + 'Output '
  $dumpWire = @()
  for ($di = 0; $di -lt $codeLines.Count; $di++) {
    if ($di -ge $j5ProdStart -and $di -lt $j5ProdEnd) { continue }
    if ($codeLines[$di] -match '^\s*#') { continue }
    if ($codeLines[$di].Contains($dumpMark)) { $dumpWire += ($di + 1) }
  }
  ST-Check 'lint: exactly one production emitter renders a dump (one pointer, not per-command copies)' (@($dumpWire).Count -eq 1)
  # behaviour on the real filesystem, in TEMP - including the two refusals that protect the
  # user's files: never overwrite, never create a directory tree.
  $dumpDir = Join-Path $env:TEMP ('dtx-dump-' + (Get-Date -Format 'yyyyMMddHHmmss'))
  [void](New-Item -ItemType Directory -Path $dumpDir)
  try {
    $dumpFile = Join-Path $dumpDir 'out.txt'
    $dumpLines = @()
    for ($dl = 1; $dl -le 12; $dl++) { $dumpLines += "line$dl" }
    $dumpEcho = @(Emit-DumpOutput $dumpLines $dumpFile 'wins')
    $dumpEchoTxt = ($dumpEcho -join "`n")
    $dumpReadBack = @([System.IO.File]::ReadAllLines($dumpFile))
    ST-Check 'unit: a dump writes every line and the pointer reports the file OWN counts (completeness read off the artifact, not off the input array)' (
      @($dumpReadBack).Count -eq 12 -and $dumpEchoTxt.Contains('lines=12 bytes=') -and
      $dumpEchoTxt.Contains('dump-readback: lines=12'))
    # a 12-line dump shows 5: the truncation must say the hidden count out loud (J-06).
    ST-Check 'unit: a truncated dump sample says how many lines it hid' (
      $dumpEchoTxt.Contains('(+7 more line(s) NOT shown here') -and $dumpEchoTxt.Contains('| line5') -and
      -not ($dumpEchoTxt -match '\| line6'))
    $dumpOver = ''
    try { Emit-DumpOutput @('x') $dumpFile 'wins' | Out-Null } catch { $dumpOver = "$($_.Exception.Message)" }
    ST-Check 'unit: --dump refuses to overwrite an existing file and writes nothing' (
      $dumpOver -like '*refusing to overwrite*' -and (@([System.IO.File]::ReadAllLines($dumpFile)).Count -eq 12))
    $dumpNoDir = ''
    try { Emit-DumpOutput @('x') (Join-Path $dumpDir 'nope\deep.txt') 'wins' | Out-Null } catch { $dumpNoDir = "$($_.Exception.Message)" }
    ST-Check 'unit: --dump refuses a missing parent instead of creating directories' (
      $dumpNoDir -like '*parent directory does not exist*' -and -not (Test-Path (Join-Path $dumpDir 'nope')))
    # the file must be readable by the NEXT call: UTF-8 without BOM, and the empty-output case
    # says so rather than looking like a failed write.
    $dumpEmptyFile = Join-Path $dumpDir 'empty.txt'
    $dumpEmpty = @(Emit-DumpOutput @() $dumpEmptyFile 'read-text') -join "`n"
    $dumpBytes = [System.IO.File]::ReadAllBytes($dumpEmptyFile)
    $dumpBom = ($dumpBytes.Length -ge 3 -and [int]$dumpBytes[0] -eq 0xEF -and [int]$dumpBytes[1] -eq 0xBB -and [int]$dumpBytes[2] -eq 0xBF)
    ST-Check 'unit: an empty dump still writes a file, self-reports lines=0 and carries no BOM' (
      $dumpEmpty.Contains('lines=0') -and $dumpEmpty.Contains('produced no output') -and
      (Test-Path -LiteralPath $dumpEmptyFile) -and -not $dumpBom)
  } finally {
    try { Remove-Item -Recurse -Force $dumpDir } catch { }
  }

  # ---------- v3.0.0 S-2: --json must never be accepted and ignored ----------------------
  # The gate is proved at the boundary the caller actually uses (a real subprocess, a real
  # command line) rather than by scanning the dispatcher for $script:Json: two attempts at
  # that scan measured the wrong region on their own terms (one latched onto a 4-space
  # quoted-brace line at file line 270 and derived an empty set while reporting 84 cases seen;
  # the other hit the hashtable key-vs-property trap because a command is literally named
  # `keys`). A scan whose failure mode is "silently agrees" is not evidence, and this repo's
  # own rule is to test the road the caller drives. So: the positive case must PARSE as JSON
  # and the negative case must refuse with the flag's own name and exit 1.
  $jcDeclared = @(Get-JsonCapableCommandSet | Sort-Object)
  $jcFake = @()
  foreach ($jd in @($jcDeclared)) {
    if (-not ($code -match ("'" + [regex]::Escape($jd) + "' \{"))) { $jcFake += $jd }
  }
  ST-Check 'lint: every declared --json command is a real dispatch case (the refusal text cannot name a phantom)' (@($jcFake).Count -eq 0)
  ST-Check 'unit: --json is refused for a command that cannot render it, and accepted for one that can' (
    (Test-JsonCapableCommand 'wins') -and (Test-JsonCapableCommand 'read-text') -and
    (Test-JsonCapableCommand 'click') -and (Test-JsonCapableCommand 'paste') -and
    -not (Test-JsonCapableCommand 'cursor') -and -not (Test-JsonCapableCommand 'shot') -and
    -not (Test-JsonCapableCommand ''))
  # A-24 gauge repair: one child-spawn runner for the offline probes.
  # Owner ruling of 2026-10-19, three content criteria: keep both child streams, read the child's REAL
  # exit code, and report a collection failure apart from a contract failure. Measured on this machine,
  # both engines, in .cowork-temp/a24g-channel/{shape,ctrl}-ps51.txt and -pwsh7.txt: under the entry's
  # `$ErrorActionPreference = 'Stop'` a native child that writes to stderr is promoted to a terminating
  # RemoteException on Windows PowerShell 5.1 whenever the capture REDIRECTS it - `2>&1` and `2> <file>`
  # both throw there, while pwsh 7 leaves the identical call non-terminating. So on 5.1 the line after
  # the call never runs, and by the time the catch reads `$LASTEXITCODE` the runtime has already rewritten
  # it to -1 (a seeded 42 comes back -1): -1 is what a broken collection looks like, which is where the
  # historical `refusal-exit=-1` reading came from. Not redirecting at all does not throw but drops the
  # child's stderr from the reading (measured stderr=0), which loses the diagnostics G-08 routed there on
  # purpose. Relaxing EAP around the call and restoring it in `finally` is the only measured shape that
  # keeps both streams AND yields the real code on both engines. `2>&1` stays deliberately: the elements
  # are split by type below, so stderr can never re-enter the face ConvertFrom-Json parses - the v4.1.3
  # bug is replaced here, not reinstated.
  # G-23 pre-flight: where the whole-stream evidence lands, and what it says it came from. The directory
  # lives outside the repository (the harness writes nothing into the delivery tree); a healthy run never
  # creates a file in it. It is named PER PROCESS on purpose: the plant checks below COUNT the files in
  # this directory, so a directory shared by two gates running at once (two trees, or my gate and the
  # monitor's) would read the other run's litter as its own - the same shape the CU-REL-01 live round
  # hit with a click counter shared across fixture instances. The id comes from a .NET call, not from $PID:
  # the A-14b context lint forbids a lifted body from reading a variable it did not declare, and writing
  # $PID was caught by it first-hand (`A-14b state gap: pid=free-read-at-19777`).
  $g23EvidenceDir = Join-Path $env:TEMP ('json-probe-evidence-' + [System.Diagnostics.Process]::GetCurrentProcess().Id)
  $g23SourceTag = 'entry=' + $script:ToolEntryPath + ' entry-sha=' + $(try { ([System.BitConverter]::ToString(([System.Security.Cryptography.SHA256]::Create()).ComputeHash([System.IO.File]::ReadAllBytes($script:ToolEntryPath))) -replace '-','').Substring(0, 12) } catch { 'unreadable' }) + ' declared=' + [string]$script:DeclaredCheckTotal

  $cnpRun = {
    param([string[]]$ChildArgs)
    if (@($ChildArgs).Count -lt 1) { throw 'child runner: empty argument list - nothing would be measured' }
    $cnpRes = [pscustomobject]@{ ran = $false; code = $null; why = ''; out = ''; err = ''; outCount = 0; errCount = 0 }
    $cnpEap0 = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $cnpRaw = @()
    try {
      $cnpRaw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath @ChildArgs 2>&1)
      $cnpRes.code = $LASTEXITCODE
      $cnpRes.ran = $true
    } catch { $cnpRes.why = $_.Exception.GetType().Name + ' :: ' + $_.Exception.Message }
    finally { $ErrorActionPreference = $cnpEap0 }
    $cnpSo = @(); $cnpSe = @()
    foreach ($cnpE in @($cnpRaw)) {
      if ($cnpE -is [System.Management.Automation.ErrorRecord]) { $cnpSe += [string]$cnpE.Exception.Message }
      else { $cnpSo += [string]$cnpE }
    }
    $cnpRes.out = ($cnpSo -join "`n"); $cnpRes.err = ($cnpSe -join "`n")
    $cnpRes.outCount = @($cnpSo).Count; $cnpRes.errCount = @($cnpSe).Count
    $cnpRes
  }
  $jsonPos = & $cnpRun -ChildArgs @('wins', '--json')
  $jsonPosObj = $null
  $jsonPosWhy = ''
  try { $jsonPosObj = @($jsonPos.out | ConvertFrom-Json) } catch { $jsonPosObj = $null; $jsonPosWhy = $_.Exception.Message }
  # G-23: this leg's contract is "stdout parses", so a failed parse is the surprise worth the whole stream.
  # A healthy run writes nothing here.
  $g23Evidence = ''
  if ($jsonPos.ran -and $null -eq $jsonPosObj) {
    $g23Evidence = Write-JsonProbeEvidence -Label 'read-json-leg' -Stdout $jsonPos.out -Stderr $jsonPos.err -Code ([string]$jsonPos.code) -Parsed $false -ParseWhy $jsonPosWhy -Dir $g23EvidenceDir -Source $g23SourceTag
  }
  $jsonNeg = & $cnpRun -ChildArgs @('cursor', '--json')
  if (-not $script:PsChildOk) {
    ST-Skip 'contract: --json on a capable command yields parseable JSON end to end (wins, real command line)' ($script:PsChildWhy + ' - the check spawns a child through the call operator, so there is nothing to measure')
    ST-Skip 'contract: --json on an incapable command REFUSES with exit 1 instead of printing text it never promised' ($script:PsChildWhy + ' - the check spawns a child through the call operator, so there is nothing to measure')
  } else {
  ST-Check 'contract: --json on a capable command yields parseable JSON end to end (wins, real command line)' (
    $jsonPos.code -eq 0 -and $null -ne $jsonPosObj -and @($jsonPosObj).Count -ge 1)
  ST-Check 'contract: --json on an incapable command REFUSES with exit 1 instead of printing text it never promised' (
    $jsonNeg.code -eq 1 -and ($jsonNeg.out + "`n" + $jsonNeg.err).Contains("--json is not supported by 'cursor'") -and
    -not (($jsonNeg.out + "`n" + $jsonNeg.err) -match 'cursor='))
  }

  # ---------- v4.4.0 (G-14, owner ruling): the residual resolve sentences must not enter the envelope ----------
  # End to end in two legs, because the scene that PRODUCES a non-main pick is desktop state and this run is
  # the offline-safe subset: leg A drives the real emitter in-process with a forced note (deterministic, and
  # it fails the moment the sentence goes back to the success stream), leg B spawns the real entry with
  # --json on a read command and requires stdout to parse with no note text anywhere in it.
  $g14Marker = ('DTX' + '-G14-NOTE-PROBE')
  $g14JsonLines = $null; $g14PlainLines = $null
  $g14JsonSave = $script:Json
  try {
    $script:Json = $true
    $script:ActivationLine = $g14Marker + '-act'; $script:ActivationNotice = $g14Marker + '-notice'; $script:ResolveNote = $g14Marker + '-pick'
    $g14JsonLines = @(& { Emit-ResolveNote })
    $g14JsonCleared = (-not $script:ActivationLine) -and (-not $script:ActivationNotice) -and (-not $script:ResolveNote)
    $script:Json = $false
    $script:ActivationLine = $g14Marker + '-act'; $script:ResolveNote = $g14Marker + '-pick'
    $g14PlainLines = @(& { Emit-ResolveNote })
    $g14PlainCleared = (-not $script:ActivationLine) -and (-not $script:ResolveNote)
  } finally {
    $script:Json = $g14JsonSave
    $script:ActivationLine = ''; $script:ActivationNotice = ''; $script:ResolveNote = ''
  }
  $g14JsonJoined = (@($g14JsonLines) -join "`n")
  $g14PlainJoined = (@($g14PlainLines) -join "`n")
  ST-Check 'e2e (G-14): with --json the three resolve sentences leave the success stream entirely, and without it they print verbatim in the same order (the real emitter, both roads, state cleared on both)' (
    (-not $g14JsonJoined.Contains($g14Marker)) -and (@($g14JsonLines).Count -eq 0) -and $g14JsonCleared -and
    (@($g14PlainLines).Count -eq 2) -and ($g14PlainJoined.Contains($g14Marker + '-act')) -and
    ($g14PlainJoined.Contains($g14Marker + '-pick')) -and ($g14PlainJoined.IndexOf($g14Marker + '-act') -lt $g14PlainJoined.IndexOf($g14Marker + '-pick')) -and
    $g14PlainCleared -and ($script:Json -eq $g14JsonSave))
  Write-Output ('      G-14 emitter: json-lines=' + @($g14JsonLines).Count + ' plain-lines=' + @($g14PlainLines).Count +
    ' json-leak=' + $g14JsonJoined.Contains($g14Marker) + ' cleared=' + $g14JsonCleared + '/' + $g14PlainCleared)
  $g14Child = & $cnpRun -ChildArgs @('wins', '--json')
  if ($script:PsChildOk) {
    ST-Check 'e2e (G-14): a real --json child of the read family still gives parseable JSON with no resolve sentence anywhere in stdout' (
      $g14Child.code -eq 0 -and ($g14Child.out -ne '') -and (-not $g14Child.out.Contains('activated=')) -and
      (-not $g14Child.out.Contains('picked the')) -and ($g14Child.out.Contains('pid')))
    # stdout-bytes is the face the assertion reads; the stderr counts are what the old `2> <file>` shape
    # believed it was keeping and, on 5.1, was not (the call threw before the file was ever written).
    Write-Output ('      G-14 child: exit=' + [string]$g14Child.code + ' ran=' + $g14Child.ran +
      ' stdout-lines=' + $g14Child.outCount + ' stdout-bytes=' + $g14Child.out.Length +
      ' stderr-lines=' + $g14Child.errCount + ' stderr-bytes=' + $g14Child.err.Length)
  } else {
    ST-Skip 'e2e (G-14): a real --json child of the read family still gives parseable JSON with no resolve sentence anywhere in stdout' ($script:PsChildWhy + ' - the check spawns a child process')
  }
  $jsonProbeDump = Format-JsonProbeDump $jsonPos.out ($null -ne $jsonPosObj)
  Write-Output ("      --json gate: declared=" + @($jcDeclared).Count + ' pos-exit=' + [string]$jsonPos.code +
    ' pos-ran=' + $jsonPos.ran + ' pos-stdout=' + $jsonPos.outCount + ' pos-stderr=' + $jsonPos.errCount +
    ' neg-exit=' + [string]$jsonNeg.code + ' neg-ran=' + $jsonNeg.ran +
    ' neg-stdout=' + $jsonNeg.outCount + ' neg-stderr=' + $jsonNeg.errCount +
    ' neg-hits-refusal=' + (($jsonNeg.out + "`n" + $jsonNeg.err).Contains('is not supported by')) +
    ' child-stdout=' + $jsonProbeDump + $(if ($g23Evidence) { ' ' + $g23Evidence } else { '' }))
  # A-24 gauge repair: the channel shape pin. The old pin read "the JSON probe may not merge the error
  # stream, the refusal probe must" - and THAT rule is where the -1 readings came from, because keeping
  # stderr out was done by not redirecting, which drops the diagnostics, and keeping it in was done by
  # merging, which throws on 5.1. The invariant is now: ONE runner, ONE spawn site inside it, the elements
  # split by type, and the face ConvertFrom-Json parses built from stdout only.
  # Both sides counted, because a one-sided lint is satisfied by deleting the pattern, so every predicate
  # is planted against a copy of its own violation. Markers AND plants are built by concatenation: this
  # file scans itself, and a contiguous literal of a marker in its own scanner or plant line counts as a
  # real site (the old gate went red on its own source lines that way on first run).
  # The scan is scoped to THIS family's lines on purpose: $codeLines is the aggregate, and a general shape
  # like a direct child spawn has ~40 legitimate sites in the live suite - unscoped, the count would be
  # meaningless. The slice runs from this family's function definition to the next top-level `function`,
  # which is also how it reads in the stitched single file (every lib body is present there in declaration
  # order). The slice size is reported and asserted non-trivial, because a scope that resolved to nothing
  # would make every count below read as a clean zero - the empty-ruler shape criterion 5 already bans.
  $chScopeMark = 'function Invoke-SelftestFamily-' + 'AuditOutput('
  $chScopeStart = -1
  $chScopeEnd = -1
  for ($chi = 0; $chi -lt $codeLines.Count; $chi++) {
    if ($chScopeStart -lt 0) { if ($codeLines[$chi].Contains($chScopeMark)) { $chScopeStart = $chi } }
    elseif ($codeLines[$chi] -match '^function ') { $chScopeEnd = $chi; break }
  }
  $chScope = @()
  if ($chScopeStart -ge 0) {
    if ($chScopeEnd -lt 0) { $chScope = @($codeLines[$chScopeStart..($codeLines.Count - 1)]) }
    else { $chScope = @($codeLines[$chScopeStart..($chScopeEnd - 1)]) }
  }
  $chDefMark = ('$cnpRu' + 'n = {')
  $chCallMark = ('= & $cnp' + 'Run')
  $chSpawnMark = ('& ' + 'powershell -NoProfile')
  $chSplatMark = ('@Child' + 'Args 2>&1')
  $chSplitMark = ('-is [System.Management.Automation.' + 'ErrorRecord]')
  $chMergeMark = ('.out +' + ' "`n"')
  $chJsonMark = ('| ' + 'ConvertFrom-Json')
  $chDefSites = @($chScope | Where-Object { $_.Contains($chDefMark) })
  $chCallSites = @($chScope | Where-Object { $_.Contains($chCallMark) })
  $chSpawnSites = @($chScope | Where-Object { $_.Contains($chSpawnMark) })
  $chSpawnLoose = @($chSpawnSites | Where-Object { -not $_.Contains($chSplatMark) })
  $chSplitSites = @($chScope | Where-Object { $_.Contains($chSplitMark) })
  $chJsonMerged = @($chScope | Where-Object { $_.Contains($chJsonMark) -and $_.Contains($chMergeMark) })
  $chPlant = @(
    ('  ' + '$chPlantA = ' + '& powershell -NoProf' + 'ile -File x wins --json 2>&1'),
    ('  ' + '$chPlantB = ($r.ou' + 't + "`n" + $r.er' + 'r) ' + '| ConvertF' + 'rom-Json'),
    ('  ' + '$cnpRu' + 'n = {'),
    ('  ' + '= & $cnp' + 'Run -ChildArgs @()')
  )
  $chPlantSpawnCaught = @($chPlant | Where-Object { $_.Contains($chSpawnMark) -and -not $_.Contains($chSplatMark) }).Count
  $chPlantMergeCaught = @($chPlant | Where-Object { $_.Contains($chJsonMark) -and $_.Contains($chMergeMark) }).Count
  $chPlantDefCaught = @($chPlant | Where-Object { $_.Contains($chDefMark) }).Count
  $chPlantCallCaught = @($chPlant | Where-Object { $_.Contains($chCallMark) }).Count
  ST-Check 'lint: every offline child probe in this family goes through the one runner (slice sized, one definition, one splatting spawn site, streams split by type, no merged face parsed as JSON) and each shape predicate catches its planted copy' (
    (@($chScope).Count -gt 400) -and (@($chDefSites).Count -eq 1) -and (@($chCallSites).Count -eq 9) -and
    (@($chSpawnSites).Count -eq 1) -and (@($chSpawnLoose).Count -eq 0) -and (@($chSplitSites).Count -eq 1) -and
    (@($chJsonMerged).Count -eq 0) -and ($chPlantSpawnCaught -eq 1) -and ($chPlantMergeCaught -eq 1) -and
    ($chPlantDefCaught -eq 1) -and ($chPlantCallCaught -eq 1))
  # call-sites 7 -> 9 (B-2): the archive-walk e2e adds two child probes (the scope=day read and
  # the refused scope), both through the same runner - the pin moves WITH the measured count.
  Write-Output ('      child channel: scope-lines=' + @($chScope).Count + ' runner-def=' + @($chDefSites).Count +
    ' call-sites=' + @($chCallSites).Count + ' spawn-sites=' + @($chSpawnSites).Count +
    ' unsplit-spawn=' + @($chSpawnLoose).Count + ' type-split=' + @($chSplitSites).Count +
    ' json-from-merged=' + @($chJsonMerged).Count + ' plants=[' + $chPlantSpawnCaught + '/' + $chPlantMergeCaught +
    '/' + $chPlantDefCaught + '/' + $chPlantCallCaught + ']')
  if (@($chSpawnLoose).Count -gt 0) { Write-Output '      a child spawn bypassed the runner - its exit code is a sentinel again' }
  if (@($chJsonMerged).Count -gt 0) { Write-Output '      a JSON probe parses a merged face again - warnings will break every caller that parses it' }
  # ---------- v3.1.0 X-01: the action family's --json envelope --------------------------------
  # The requirement this block exists to enforce is not "there is JSON", it is "the JSON cannot
  # lie and cannot drift": ONE producer, a CLOSED command table, a PINNED key set, and a
  # projection that is a subset of the text it carries. Every one of those has a planted
  # positive control below, because a set comparison over two empty sets is how this repo has
  # been fooled three times already (@($hashtable).Count, the scanner reading its own source,
  # and the v3.0.0 key-set copy that lived in three places).
  $xHelpSet = @(Get-ActionFamilyCommandsFromHelp (Get-UsageLines))
  $xTableSet = @(Get-ActionJsonCommandSet | Sort-Object -Unique)
  $xMissing = @($xHelpSet | Where-Object { $xTableSet -notcontains $_ })
  $xPhantom = @($xTableSet | Where-Object { $xHelpSet -notcontains $_ })
  Write-Output ('      action-json table: help=' + @($xHelpSet).Count + ' table=' + @($xTableSet).Count +
    ' missing=[' + ($xMissing -join ',') + '] phantom=[' + ($xPhantom -join ',') + ']')
  # the >=25 conjunct is the positive control: if the group parser ever returns an empty list,
  # both diffs below are empty and the equality would be vacuously true.
  ST-Check 'lint (X-01): the action --json command table is CLOSED (equals the help page act/text/clipboard set in BOTH directions, and the parse itself yields >=25 names)' (
    @($xMissing).Count -eq 0 -and @($xPhantom).Count -eq 0 -and @($xTableSet).Count -ge 25 -and @($xHelpSet).Count -ge 25)
  # Teeth for the parser itself: a group header must never be read as a command, and the option
  # lists inside a synopsis must never be read as commands (Get-HelpEntryNames' documented trap).
  $xFakeHelp = @('  act (absolute coords)', '    click <x> <y> [--occlude off|warn|strict]', '  clipboard', '    selftest [--live] = x')
  $xFakeGot = @(Get-ActionFamilyCommandsFromHelp $xFakeHelp)
  ST-Check 'unit (X-01): the action-set parser takes names from the act/clipboard groups only, never a group header and never an option token (off/warn/strict)' (
    (@($xFakeGot | Where-Object { $_ -in @('off', 'warn', 'strict', 'act', 'clipboard') }).Count -eq 0) -and
    (@($xFakeGot | Where-Object { $_ -eq 'click' }).Count -eq 1))
  # ONE producer + ONE pair of emission sites, both at the process boundary. Tokens assembled at
  # runtime: this scanner's own source sits on the face it scans (pit recorded in v3.1.0 7B).
  $xProdMark = 'function Format-Action' + 'JsonEnvelope'
  $xEmitMark = 'Format-Action' + 'JsonEnvelope $Cmd'
  $xProd = 0; $xEmit = @()
  for ($xi = 0; $xi -lt $codeLines.Count; $xi++) {
    if ($xi -ge $j5ProdStart -and $xi -lt $j5ProdEnd) { continue }
    if ($codeLines[$xi] -match '^\s*#') { continue }
    $xl = [string]$codeLines[$xi]
    if ($xl.StartsWith($xProdMark)) { $xProd++ }
    if ($xl.Contains($xEmitMark)) { $xEmit += ($xi + 1) }
  }
  Write-Output ('      action-json outlets: producer=' + $xProd + ' emit=[' + (Format-SourceLineList $xEmit) + ']')
  ST-Check 'lint (X-01): the action envelope has exactly one producer and exactly two emission sites (stdout + --dump), never a per-case copy' (
    $xProd -eq 1 -and @($xEmit).Count -eq 2)
  # The key sets. `signals` is DERIVED from the pattern map, so the map and a hardcoded contract
  # list are compared against each other - that is the drift nail; comparing the object to its
  # own source would be vacuous.
  $xWantSigLit = (@('expect', 'foreground', 'guard', 'hitWindow', 'notice', 'occluded', 'receipt', 'warning') | Sort-Object) -join ','
  $xEnv1 = Format-ActionJsonEnvelope 'click' @('hit-window: pid=1 proc=p title=T', 'clicked 1,2')
  $xObj1 = $null
  try { $xObj1 = $xEnv1 | ConvertFrom-Json } catch { $xObj1 = $null }
  $xTop = ''
  if ($null -ne $xObj1) { $xTop = (@($xObj1.PSObject.Properties.Name) | Sort-Object) -join ',' }
  ST-Check 'contract (X-01): the action envelope top-level keys are exactly schemaVersion+command+lines+signals and schemaVersion is the declared one (add or drop a key = breaking)' (
    $xTop -ceq (Get-ActionJsonKeySet) -and $null -ne $xObj1 -and [int]$xObj1.schemaVersion -eq [int]$script:JsonSchemaVersion)
  $xSigGot = ''
  if ($null -ne $xObj1) { $xSigGot = (@($xObj1.signals.PSObject.Properties.Name) | Sort-Object) -join ',' }
  ST-Check 'contract (X-01): signals carries exactly the eight pinned classes, the pattern map agrees with the pinned list, and the schema is 3 (this class of change was MAJOR in v3.0.0 - the conflict is registered, not eaten)' (
    $xSigGot -ceq $xWantSigLit -and (Get-ActionJsonSignalKeySet) -ceq $xWantSigLit -and [int]$script:JsonSchemaVersion -eq 3)
  # The projection has to be a SUBSET (it invents nothing) and COMPLETE per class (it drops
  # nothing) and must keep an unclassed line - all three on one planted fixture.
  $xL1 = 'hit-window: pid=7 proc=notepad title=T  (inside-target=True occluded=0% coveredBy=-)'
  $xL2 = "target pid=7 (foreground after send: pid=7 notepad 'T')"
  $xL3 = 'content guard FAILED: needle not present'
  $xL4 = 'receipt-tried=occluded-refused (lines 3->4)'
  $xL5 = 'unmap: C:\tmp\x.png (400x300 kind=rect scale=1) image (10,20) -> screen (110,220)'
  $xL6 = 'WARNING: something the reader must not lose'
  $xL7 = 'NOTICE: post-send foreground check unavailable: boom'
  $xL8 = 'expect refused: target occluded=44% coveredBy=pid=9 p'
  $xEnv2 = Format-ActionJsonEnvelope 'paste' @($xL1, $xL2, $xL3, $xL4, $xL5, $xL6, $xL7, $xL8)
  $xObj2 = $null
  try { $xObj2 = $xEnv2 | ConvertFrom-Json } catch { $xObj2 = $null }
  $xInvent = 0
  $xBlind = @()
  if ($null -ne $xObj2) {
    foreach ($pk in @($xObj2.signals.PSObject.Properties.Name)) {
      $pv = @($xObj2.signals.$pk)
      if ($pv.Count -lt 1) { $xBlind += $pk }
      foreach ($v in $pv) { if (@($xObj2.lines) -notcontains [string]$v) { $xInvent++ } }
    }
  } else { $xInvent = -1 }
  Write-Output ('      action-json projection: invented=' + $xInvent + ' blind=[' + ($xBlind -join ',') + '] lines=' +
    $(if ($null -ne $xObj2) { @($xObj2.lines).Count } else { -1 }))
  ST-Check 'unit (X-01): signals is a subset projection (invents nothing), every class catches its own planted line, and an unclassed line still survives in lines' (
    $xInvent -eq 0 -and @($xBlind).Count -eq 0 -and $null -ne $xObj2 -and
    @($xObj2.lines).Count -eq 8 -and (@($xObj2.lines) -contains $xL5))
  # End to end on the road the caller actually drives: a real subprocess, a side-effect-free
  # action (unmap = imgclick minus the click), and the refusal path must NOT be swallowed.
  $xImg = Join-Path $env:TEMP ('x01unmap' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.png')
  # v4.6.10 (A3): a sidecar whose image is missing is refused at read time now, so this fixture has
  # to be a real pair. This leg stays the JSON-envelope probe, not the missing-image counterexample.
  Add-Type -AssemblyName System.Drawing
  $xImgBmp = New-Object System.Drawing.Bitmap 400, 300
  $xImgBmp.Save($xImg, [System.Drawing.Imaging.ImageFormat]::Png)
  $xImgBmp.Dispose()
  [System.IO.File]::WriteAllText($xImg + '.map.txt',
    (@('origin_x=100', 'origin_y=200', 'scale=1', 'out_w=400', 'out_h=300', 'kind=rect') -join "`r`n"),
    (New-Object System.Text.UTF8Encoding($false)))
  # A-24, on the monitor's one-off `refusal-exit=-1` reading: -1 was NEVER an exit code. Both probes used to
  # start their code at -1 and only overwrite it on the success path, so a spawn that THROWS (the call
  # operator cannot resolve `powershell`, an access denial, a killed child) left the sentinel in the reading
  # and the gate went red as if the tool had returned -1. The sentinel now says what it is, the exception
  # text is kept for the reading line, and a probe that could not run is reported as not run - which is a
  # different fact from "the tool exited N", and the reason belongs in the same place the reason already
  # goes when the pre-flight says no child can be spawned at all ($script:PsChildOk).
  # A-24 gauge repair, correcting that attribution (measured in .cowork-temp/a24g-channel/ctrl-ps51.txt):
  # the sentinel was only ONE of two ways to print -1. On Windows PowerShell 5.1, once a redirected native
  # child writes to stderr the call itself is terminating AND the runtime rewrites `$LASTEXITCODE` to -1
  # before the catch runs (a seeded 42 reads back -1), so even a probe that assigned the code inside its
  # catch would have printed -1. The child's real code is unrecoverable through that channel; it is
  # recoverable through the runner below, which is why the repair relaxes EAP instead of only labelling
  # the sentinel. Both legs now share the runner, so stdout is what the JSON face parses and stderr is
  # counted in its own field instead of being dropped (unmap) or merged (refusal) as they each did before.
  $xSubLeg = & $cnpRun -ChildArgs @('unmap', $xImg, '10', '20', '--json')
  $xSubOut = $xSubLeg.out
  $xSubCode = $xSubLeg.code
  $xSubRan = $xSubLeg.ran
  $xSubWhy = $xSubLeg.why
  $xSubObj = $null
  $xSubWhy2 = ''
  try { $xSubObj = $xSubOut | ConvertFrom-Json } catch { $xSubObj = $null; $xSubWhy2 = $_.Exception.Message }
  $xSubEvidence = ''
  if ($xSubRan -and $null -eq $xSubObj) {
    $xSubEvidence = Write-JsonProbeEvidence -Label 'action-json-leg' -Stdout $xSubOut -Stderr $xSubLeg.err -Code ([string]$xSubCode) -Parsed $false -ParseWhy $xSubWhy2 -Dir $g23EvidenceDir -Source $g23SourceTag
  }
  $xSubTop = ''
  if ($null -ne $xSubObj) { $xSubTop = (@($xSubObj.PSObject.Properties.Name) | Sort-Object) -join ',' }
  $xNegLeg = & $cnpRun -ChildArgs @('click', '10', '10', '--to', 'DTX-NoSuchWindow-ZZ', '--json')
  $xNegOut = ($xNegLeg.out + "`n" + $xNegLeg.err)
  $xNegCode = $xNegLeg.code
  $xNegRan = $xNegLeg.ran
  $xNegWhy = $xNegLeg.why
  $xSubDump = Format-JsonProbeDump $xSubOut ($null -ne $xSubObj)
  Write-Output ('      action-json e2e: unmap-exit=' + [string]$xSubCode + ' unmap-ran=' + $xSubRan + ' keys=[' + $xSubTop + ']' +
    ' refusal-exit=' + [string]$xNegCode + ' refusal-ran=' + $xNegRan +
    ' refusal-is-text=' + ($xNegOut.StartsWith('ERROR:')) + ' child-stdout=' + $xSubDump + $(if ($xSubEvidence) { ' ' + $xSubEvidence } else { '' }))
  if (($xSubWhy -ne '') -or ($xNegWhy -ne '')) {
    # the one thing that used to be invisible: which leg could not be started, and what the runtime said.
    Write-Output ('      action-json e2e spawn failure: unmap=[' + $xSubWhy + '] refusal=[' + $xNegWhy + ']')
  }
  # A-24 gauge repair: the collection layer, named apart from every contract it feeds.
  # Owner criterion 3. A leg that could not be collected has no business being read as "the tool refused",
  # and before this repair four of these five legs seeded their exit code at -1 while the fifth could not
  # tell a refusal from a lost child at all. The contract gates below STILL require their own leg to have
  # run, so a collection failure reddens both layers on purpose - a contract gate that passed on an unread
  # child is the false green this card exists to remove. What this gate adds is the NAME of the first red:
  # collect red = the gauge broke, contract red with collect green = the product broke.
  # The literal 5 is a registration, not a convenience: add or drop a child probe and this goes red until
  # the pair list and the count are argued about in the same commit.
  $xCollectPairs = @(
    @('wins', $jsonPos), @('cursor', $jsonNeg), @('g14', $g14Child), @('unmap', $xSubLeg), @('refusal', $xNegLeg)
  )
  $xCollectRan = @($xCollectPairs | Where-Object { $_[1].ran }).Count
  $xCollectCode = @($xCollectPairs | Where-Object { $null -ne $_[1].code }).Count
  $xCollectAny = @($xCollectPairs | Where-Object { ($_[1].outCount + $_[1].errCount) -ge 1 }).Count
  $xCollectStdout = @($xCollectPairs | Where-Object { $_[1].outCount -ge 1 }).Count
  $xCollectFace = @()
  foreach ($xcp in $xCollectPairs) { $xCollectFace += ('[' + $xcp[0] + ' ' + [string]$xcp[1].outCount + '/' + [string]$xcp[1].errCount + ']') }
  Write-Output ('      child collection: legs=' + @($xCollectPairs).Count + ' ran=' + $xCollectRan +
    ' code-read=' + $xCollectCode + ' any-stream=' + $xCollectAny + ' stdout-stream=' + $xCollectStdout +
    ' (stdout/stderr per leg)=' + ($xCollectFace -join ''))
  if (-not $script:PsChildOk) {
    ST-Skip 'e2e (A-24g): every offline child probe reports its own collection - five legs ran, each read a real exit code from the child, each caught at least one stream and each left a stdout face to parse' ($script:PsChildWhy + ' - the checks spawn children through the call operator, so there is nothing to measure')
  } else {
  ST-Check 'e2e (A-24g): every offline child probe reports its own collection - five legs ran, each read a real exit code from the child, each caught at least one stream and each left a stdout face to parse' (
    (@($xCollectPairs).Count -eq 5) -and ($xCollectRan -eq 5) -and ($xCollectCode -eq 5) -and
    ($xCollectAny -eq 5) -and ($xCollectStdout -eq 5))
  }
  if (-not $script:PsChildOk) {
    ST-Skip 'contract (X-01): a real action subprocess with --json yields parseable JSON with the pinned four keys (unmap, side-effect-free) - and a refused action still yields ERROR + exit 1, never an envelope that hides the refusal' ($script:PsChildWhy + ' - the check spawns a child through the call operator, so there is nothing to measure')
  } else {
  ST-Check 'contract (X-01): a real action subprocess with --json yields parseable JSON with the pinned four keys (unmap, side-effect-free) - and a refused action still yields ERROR + exit 1, never an envelope that hides the refusal' (
    $xSubRan -and $xNegRan -and
    $xSubCode -eq 0 -and $xSubTop -ceq (Get-ActionJsonKeySet) -and
    @($xSubObj.lines).Count -ge 1 -and [int]$xSubObj.schemaVersion -eq 3 -and "$($xSubObj.command)" -eq 'unmap' -and
    $xNegCode -eq 1 -and $xNegOut.Contains('ERROR:') -and -not $xNegOut.Contains('"schemaVersion"'))
  }
  try { if (Test-Path -LiteralPath $xImg) { Remove-Item -LiteralPath $xImg -Force } } catch { }
  try { if (Test-Path -LiteralPath ($xImg + '.map.txt')) { Remove-Item -LiteralPath ($xImg + '.map.txt') -Force } } catch { }
  # G-23: whole-stream evidence, taken BEFORE any head is cut. Deliberately not a banner rule line: the
  # family census enumerates every banner and would report this section as a banner claimed by nobody.
  # The two shapes are planted here so the gate owns the counterexample the monitor measured by hand: both
  # printed heads end with the same ' (cut)' marker, so a head cannot tell a clean envelope from one with a
  # polluter glued after it - only the evidence file can. G-25 puts these planted files in a unique owned
  # directory; the check counts and removes only those files, never the shared evidence root.
  $g23Tok = 'TAIL-POLLUTER-' + ([Guid]::NewGuid().ToString('N')).Substring(0, 8)
  $g23Pad = '{"schemaVersion":3,"command":"plant","lines":[' + ((1..40 | ForEach-Object { '"line-' + $_ + '"' }) -join ',') + ']}'
  $g23CleanObj = $null
  try { $g23CleanObj = $g23Pad | ConvertFrom-Json } catch { $g23CleanObj = $null }
  $g23Dirty = $g23Pad + "`n" + $g23Tok
  $g23DirtyObj = $null
  $g23DirtyWhy = ''
  try { $g23DirtyObj = $g23Dirty | ConvertFrom-Json } catch { $g23DirtyObj = $null; $g23DirtyWhy = $_.Exception.Message }
  $g23CleanDump = Format-JsonProbeDump $g23Pad ($null -ne $g23CleanObj)
  $g23DirtyDump = Format-JsonProbeDump $g23Dirty ($null -ne $g23DirtyObj)
  $g23EvidenceFull = [System.IO.Path]::GetFullPath($g23EvidenceDir).TrimEnd('\')
  $g23TempFull = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
  $g23EvidenceParent = [System.IO.Path]::GetDirectoryName($g23EvidenceFull).TrimEnd('\')
  $g23EvidenceLeaf = [System.IO.Path]::GetFileName($g23EvidenceFull)
  $g23EvidenceRootOk = ($g23EvidenceParent -ieq $g23TempFull) -and
    $g23EvidenceFull.StartsWith($g23TempFull + '\', [System.StringComparison]::OrdinalIgnoreCase) -and
    ($g23EvidenceLeaf -ceq ('json-probe-evidence-' + [System.Diagnostics.Process]::GetCurrentProcess().Id))
  $g23OwnedDir = Join-Path $g23EvidenceDir ('g23-owned-' + [Guid]::NewGuid().ToString('N'))
  $g23OwnedFull = [System.IO.Path]::GetFullPath($g23OwnedDir).TrimEnd('\')
  $g23OwnedParent = [System.IO.Path]::GetDirectoryName($g23OwnedFull).TrimEnd('\')
  $g23OwnedLeaf = [System.IO.Path]::GetFileName($g23OwnedFull)
  $g23OwnedPathOk = $g23EvidenceRootOk -and ($g23OwnedParent -ieq $g23EvidenceFull) -and
    $g23OwnedLeaf.StartsWith('g23-owned-', [System.StringComparison]::Ordinal) -and
    $g23OwnedFull.StartsWith($g23EvidenceFull + '\', [System.StringComparison]::OrdinalIgnoreCase) -and
    -not (Test-Path -LiteralPath $g23OwnedFull)
  $g23OwnedCreated = $false
  if ($g23OwnedPathOk) {
    New-Item -ItemType Directory -Path $g23OwnedFull | Out-Null
    $g23OwnedCreated = Test-Path -LiteralPath $g23OwnedFull -PathType Container
  }
  # The synthetic evidence-shaped sentinel is outside the owned plant path. Check its hash after owned cleanup,
  # then remove only this exact fixture file so the test itself leaves no litter.
  $g23ForeignPath = Join-Path $g23EvidenceFull ('json-probe-plant-foreign-' + [Guid]::NewGuid().ToString('N') + '.txt')
  $g23ForeignFull = [System.IO.Path]::GetFullPath($g23ForeignPath)
  $g23ForeignParent = [System.IO.Path]::GetDirectoryName($g23ForeignFull).TrimEnd('\')
  $g23ForeignOutside = $g23EvidenceRootOk -and ($g23ForeignParent -ieq $g23EvidenceFull) -and
    -not $g23ForeignFull.StartsWith($g23OwnedFull + '\', [System.StringComparison]::OrdinalIgnoreCase) -and
    -not (Test-Path -LiteralPath $g23ForeignFull)
  $g23ForeignCreated = $false
  $g23ForeignHashBefore = ''
  $g23ForeignHashAfter = ''
  $g23HashFile = {
    param([string]$Path)
    $g23HashAlg = [System.Security.Cryptography.SHA256]::Create()
    try {
      return ([System.BitConverter]::ToString($g23HashAlg.ComputeHash([System.IO.File]::ReadAllBytes($Path)))).Replace('-', '')
    } finally { $g23HashAlg.Dispose() }
  }
  if ($g23ForeignOutside) {
    New-Item -ItemType Directory -Force -Path $g23EvidenceFull | Out-Null
    [System.IO.File]::WriteAllText($g23ForeignFull, ('JSON-PROBE-EVIDENCE label=plant-foreign parsed=false exit=1' + [Environment]::NewLine + 'synthetic G-25 sentinel' + [Environment]::NewLine), (New-Object System.Text.UTF8Encoding($false)))
    $g23ForeignCreated = Test-Path -LiteralPath $g23ForeignFull -PathType Leaf
    if ($g23ForeignCreated) { $g23ForeignHashBefore = & $g23HashFile $g23ForeignFull }
  }
  $g23Before = if ($g23OwnedCreated) { @(Get-ChildItem -LiteralPath $g23OwnedFull -Filter 'json-probe-plant-*' -File -ErrorAction SilentlyContinue).Count } else { -1 }
  $g23EvDesc = ''
  if ($g23OwnedCreated) {
    $g23EvDesc = Write-JsonProbeEvidence -Label 'plant-tail' -Stdout $g23Dirty -Stderr ('planted stderr noise ' + $g23Tok) -Code '0' -Parsed $false -ParseWhy $g23DirtyWhy -Dir $g23OwnedFull -Source $g23SourceTag
  }
  $g23EvPath = ($g23EvDesc -replace '^evidence=([^ ]+).*$', '$1')
  $g23EvText = ''
  if (Test-Path -LiteralPath $g23EvPath) { $g23EvText = [System.IO.File]::ReadAllText($g23EvPath) }
  $g23After = if ($g23OwnedCreated) { @(Get-ChildItem -LiteralPath $g23OwnedFull -Filter 'json-probe-plant-*' -File -ErrorAction SilentlyContinue).Count } else { -1 }
  Write-Output ('      G-23 plant: head-shapes=' + $g23CleanDump.EndsWith('(cut)') + '/' + $g23DirtyDump.EndsWith('(cut)') +
    ' token-in-head=' + $g23DirtyDump.Contains($g23Tok) + ' token-in-file=' + $g23EvText.Contains($g23Tok) +
    ' owned-files=' + $g23Before + '->' + $g23After + ' ' + $g23EvDesc)
  ST-Check 'unit (G-23): a tail polluter the printed head cannot tell apart still lands whole on disk - both heads end with the same cut marker, the tail token is absent from every head and present in the evidence file' (
    ($g23Pad.Length -gt 260) -and ($null -ne $g23CleanObj) -and ($null -eq $g23DirtyObj) -and
    ($g23CleanDump.EndsWith('(cut)')) -and ($g23DirtyDump.EndsWith('(cut)')) -and
    (-not $g23CleanDump.Contains($g23Tok)) -and (-not $g23DirtyDump.Contains($g23Tok)) -and
    ($g23EvText.Contains($g23Tok)) -and ($g23After -eq ($g23Before + 1)) -and
    ($g23EvText.Contains('stdout-sha256=')) -and ($g23EvText.Contains('stderr-sha256=')) -and
    ($g23EvText.Contains('exit=0')) -and ($g23EvText.Contains('entry=')) -and ($g23EvText.Contains('---- PARSE EXCEPTION ----')))
  # The second planted shape: diagnostics that only touch stderr must NOT move the trigger. The evidence
  # follows the parse verdict, so noise on the other stream cannot silently create or hide a file.
  $g23bWrote = 0
  if ($g23OwnedCreated -and $null -eq $g23CleanObj) {
    [void](Write-JsonProbeEvidence -Label 'plant-should-not-write' -Stdout $g23Pad -Stderr ('WARNING: noise only here ' + $g23Tok) -Code '0' -Parsed $false -ParseWhy '' -Dir $g23OwnedFull -Source $g23SourceTag)
    $g23bWrote = 1
  }
  $g23bFiles = if ($g23OwnedCreated) { @(Get-ChildItem -LiteralPath $g23OwnedFull -Filter 'json-probe-plant-should-not-write-*' -File -ErrorAction SilentlyContinue).Count } else { -1 }
  $g23dWrote = 0
  if ($g23OwnedCreated -and $null -eq $g23DirtyObj) {
    [void](Write-JsonProbeEvidence -Label 'plant-real-failure' -Stdout $g23Dirty -Stderr '' -Code '1' -Parsed $false -ParseWhy $g23DirtyWhy -Dir $g23OwnedFull -Source $g23SourceTag)
    $g23dWrote = 1
  }
  $g23dFiles = if ($g23OwnedCreated) { @(Get-ChildItem -LiteralPath $g23OwnedFull -Filter 'json-probe-plant-real-failure-*' -File -ErrorAction SilentlyContinue).Count } else { -1 }
  $g23Removed = 0
  if ($g23OwnedCreated -and $g23OwnedPathOk -and ([System.IO.Path]::GetDirectoryName($g23OwnedFull).TrimEnd('\') -ieq $g23EvidenceFull)) {
    foreach ($g23f in @(Get-ChildItem -LiteralPath $g23OwnedFull -Filter 'json-probe-plant-*' -File -ErrorAction SilentlyContinue)) {
      if ([System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($g23f.FullName)).TrimEnd('\') -ieq $g23OwnedFull) {
        try { Remove-Item -LiteralPath $g23f.FullName -Force; $g23Removed++ } catch { }
      }
    }
  }
  $g23Residue = if ($g23OwnedCreated) { @(Get-ChildItem -LiteralPath $g23OwnedFull -Filter 'json-probe-plant-*' -File -ErrorAction SilentlyContinue).Count } else { -1 }
  # Only the exact unique directory created above is eligible for removal, and only when empty. The shared
  # evidence root can contain genuine child-probe failures, so its existence and contents are not a verdict.
  $g23OwnedDirState = 'absent'
  if (Test-Path -LiteralPath $g23OwnedFull -PathType Container) {
    $g23OwnedLeft = @(Get-ChildItem -LiteralPath $g23OwnedFull -Force -ErrorAction SilentlyContinue).Count
    if ($g23OwnedLeft -eq 0) {
      try { Remove-Item -LiteralPath $g23OwnedFull -Force } catch { }
      $g23OwnedDirState = $(if (Test-Path -LiteralPath $g23OwnedFull) { 'still-there' } else { 'gone' })
    } else { $g23OwnedDirState = 'kept-with-' + $g23OwnedLeft + '-files' }
  }
  if ($g23ForeignCreated -and (Test-Path -LiteralPath $g23ForeignFull -PathType Leaf)) {
    $g23ForeignHashAfter = & $g23HashFile $g23ForeignFull
  }
  $g23ForeignPreserved = $g23ForeignCreated -and ($g23ForeignHashBefore.Length -eq 64) -and
    ($g23ForeignHashAfter -ceq $g23ForeignHashBefore) -and (Test-Path -LiteralPath $g23ForeignFull -PathType Leaf) -and $g23ForeignOutside
  $g23ForeignClean = $false
  if ($g23ForeignPreserved -and ($g23ForeignParent -ieq $g23EvidenceFull) -and
      ([System.IO.Path]::GetFileName($g23ForeignFull) -match '^json-probe-plant-foreign-[0-9a-f]{32}\.txt$')) {
    try { Remove-Item -LiteralPath $g23ForeignFull -Force; $g23ForeignClean = -not (Test-Path -LiteralPath $g23ForeignFull) } catch { }
  }
  Write-Output ('      G-23 trigger: parsed-clean=' + ($null -ne $g23CleanObj) + ' wrote-on-clean=' + $g23bWrote +
    ' files-on-clean=' + $g23bFiles + ' wrote-on-unparseable=' + $g23dWrote + ' files-on-unparseable=' + $g23dFiles +
    ' owned-planted-removed=' + $g23Removed + ' owned-residue=' + $g23Residue + ' owned-dir-state=' + $g23OwnedDirState +
    ' shared-root=' + (Test-Path -LiteralPath $g23EvidenceFull -PathType Container))
  ST-Check 'unit (G-23): stderr-only noise leaves stdout parseable and writes no evidence, an unparseable stdout does write it, and the planted files leave zero residue (the trigger is the parse verdict, not the presence of a second stream)' (
    ($null -ne $g23CleanObj) -and ($g23bWrote -eq 0) -and ($g23bFiles -eq 0) -and
    ($null -eq $g23DirtyObj) -and ($g23dWrote -eq 1) -and ($g23dFiles -eq 1) -and
    ($g23Removed -ge 2) -and ($g23Residue -eq 0) -and ($g23OwnedDirState -ceq 'gone'))
  Write-Output ('      G-25 cleanup: shared-root-contained=' + $g23EvidenceRootOk + ' owned-path=' + $g23OwnedPathOk + ' foreign-outside=' + $g23ForeignOutside +
    ' foreign-retained-same-sha=' + $g23ForeignPreserved + ' fixture-sentinel-removed=' + $g23ForeignClean +
    ' sha256=' + $g23ForeignHashBefore)
  ST-Check 'unit (G-25): planted evidence is contained in a unique owned path, cleanup leaves the foreign evidence-shaped sentinel byte-for-byte intact, then removes only that exact fixture sentinel' (
    $g23EvidenceRootOk -and $g23OwnedPathOk -and $g23OwnedCreated -and $g23ForeignOutside -and $g23ForeignCreated -and
    ($g23Residue -eq 0) -and ($g23OwnedDirState -ceq 'gone') -and $g23ForeignPreserved -and $g23ForeignClean)
  # The purity the monitor asked to keep: the formatter must stay two parameters in, one string out, with
  # no path built, no write call and no global read inside its own braces. Its name is assembled below:
  # the S-89 census counts every line that carries the literal token, so a scan that spells its own target
  # would inflate the consumer count it exists to pin (measured: spelling the name in the scan lines read
  # calls=8, spelling it once in the entry file's header comment read calls=5, both against 4 real sites).
  $g23pTok = 'Format-JsonProbe' + 'Dump'
  $g23pSigWant = 'function ' + $g23pTok + '([string]$Text, [bool]$Parsed) {'
  $g23SrcLines = @(Get-Content -LiteralPath $script:ToolEntryPath)
  $g23pStart = -1
  for ($g23i = 0; $g23i -lt $g23SrcLines.Count; $g23i++) {
    if (([string]$g23SrcLines[$g23i]).StartsWith('function ' + $g23pTok + '(')) { $g23pStart = $g23i; break }
  }
  $g23pEnd = -1
  if ($g23pStart -ge 0) {
    for ($g23j = $g23pStart + 1; $g23j -lt $g23SrcLines.Count; $g23j++) {
      if (([string]$g23SrcLines[$g23j]) -eq '}') { $g23pEnd = $g23j; break }
    }
  }
  $g23pBody = ''
  if ($g23pStart -ge 0 -and $g23pEnd -gt ($g23pStart + 1)) { $g23pBody = (@($g23SrcLines[($g23pStart + 1)..($g23pEnd - 1)]) -join "`n") }
  $g23pBad = @()
  foreach ($g23t in @('Write-Output', 'Write-Host', 'Write-Information', 'Set-Content', 'Add-Content', 'Out-File', 'New-Item', 'Join-Path', 'Get-Content', '[System.IO', '$script:')) {
    if ($g23pBody.Contains($g23t)) { $g23pBad += $g23t }
  }
  $g23pSig = if ($g23pStart -ge 0) { [string]$g23SrcLines[$g23pStart] } else { '' }
  Write-Output ('      G-23 purity: span=' + $g23pStart + '-' + $g23pEnd + ' bad-tokens=' + ($g23pBad -join ',') +
    ' returns=' + $g23pBody.Contains('return ') + ' sig=' + ($g23pSig -ceq $g23pSigWant))
  ST-Check 'lint (G-23): the json probe dump formatter stays a pure function - exactly two parameters, one returned string, and no write call, path build, file read or global reference inside its own braces' (
    ($g23pStart -ge 0) -and ($g23pEnd -gt ($g23pStart + 1)) -and (@($g23pBad).Count -eq 0) -and
    $g23pBody.Contains('return ') -and ($g23pSig -ceq $g23pSigWant))

  # B-6 on the text side: one producer, and it must reach the outlets that were chosen - a
  # label that exists only in the JSON would be invisible to the agents that read text.
  $utNoteMark = 'Get-UntrustedContent' + 'Note'
  $utWired = @()
  for ($ui = 0; $ui -lt $codeLines.Count; $ui++) {
    if ($ui -ge $j5ProdStart -and $ui -lt $j5ProdEnd) { continue }
    if ($codeLines[$ui] -match '^\s*#') { continue }
    if ($codeLines[$ui].Contains($utNoteMark)) { $utWired += ($ui + 1) }
  }
  $utTrustKey = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains('contentTrust = (Get-UntrustedContent' + 'Tag)') })
  ST-Check 'lint: the untrusted-content label has one producer, reaches BOTH outlets (text and every JSON envelope) and nothing else' (
    @($utWired).Count -eq 3 -and @($utTrustKey).Count -eq 2)
  ST-Check 'unit: the untrusted-text outlet set is a subset of real commands and excludes measurement-only reads' (
    (Test-UntrustedTextCommand 'wins') -and (Test-UntrustedTextCommand 'read-text') -and
    -not (Test-UntrustedTextCommand 'color-at') -and -not (Test-UntrustedTextCommand 'hash') -and
    -not (Test-UntrustedTextCommand 'cursor'))
  ST-Check 'unit: the content-trust tag is one fixed lowercase token (a consumer compares it, not reads it)' (
    (Get-UntrustedContentTag) -ceq 'untrusted-screen-text')
  # The ambiguity rule is the one safety property here that a live run would be badly placed
  # to test (it needs two cancel-shaped buttons in a real dialog), so the decision is a pure
  # function and the three shapes are pinned offline.
  $cnHitA = @{ Name = 'Cancel'; El = $null }
  # built from code points because a bare & inside the literal is the call operator to the
  # parser; and assembled char-by-char so the accelerator brackets are exactly one pair.
  $cnNameB = 'cancel' + [char]0x28 + [char]0x26 + 'C' + [char]0x29
  $cnHitB = @{ Name = $cnNameB; El = $null }
  $pick0 = Resolve-DialogCancelPick @()
  $pick1 = Resolve-DialogCancelPick @($cnHitA)
  $cnTwo = @($cnHitA, $cnHitB)
  $pick2 = Resolve-DialogCancelPick $cnTwo
  ST-Check 'unit: dialog-cancel - zero candidates fall back to Escape, one is pressed, two or more REFUSE' (
    $pick0.Action -eq 'escape' -and $pick1.Action -eq 'invoke' -and $pick1.Pick.Name -eq 'Cancel' -and
    $pick2.Action -eq 'refuse' -and $null -eq $pick2.Pick)
  ST-Check 'unit: a refusal names every candidate it could have guessed between' (
    $pick2.List.Contains("'Cancel'") -and $pick2.List.Contains("'$cnNameB'"))
  Write-Output ("      expect-verdict wiring sites: " + (Format-SourceLineList $evWire))
  $evPlant = "  throw `"`$verb OK but expectation NOT met: x`""
  ST-Check 'lint: the single-producer scan would catch a hand-written expectation tail' (
    -not $evPlant.Contains($evMark))
  # uia-tree takes [maxDepth] and hands it to Uia-Dump; the header must say which depth it
  # walked, or `uia-tree X 3` and `uia-tree X` print identical headers and a shallow read can
  # be mistaken for "this app exposes no controls" (the exact misread that cost a whole
  # investigation elsewhere). Teeth here are SOURCE-level (no live UIA case exists in the
  # suite - stated in the iteration log rather than pretended away).
  $uiDepthPat = 'via=$($rr.Via)' + ' depth=$depth'
  $uiDepthSite = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($uiDepthPat) })
  ST-Check 'lint: the uia-tree header reports the depth it actually walked' (@($uiDepthSite).Count -eq 1)

  # ---------- contract: a stamp that CLAIMS UTC must be UTC (v3.0.1, audit item 9) ----------
  # Two MANIFEST headings wrote (Get-Date) - local time - and then printed " UTC" after
  # it. A reader computing an age from that line is wrong by the whole UTC offset, and
  # the quarantine MANIFEST is exactly the document an agent trusts without re-checking.
  # Production lines only (the selftest body is skipped): this scan names both literals,
  # so scanning itself would flag its own declaration.
  $utcStamps = @()
  for ($uS = 0; $uS -lt $clCount; $uS++) {
    if ($uS -ge $j5ProdStart -and $uS -lt $j5ProdEnd) { continue }
    $uSL = [string]$codeLines[$uS]
    if ($uSL.Contains('ToString(' + [char]39 + 'yyyy-MM-dd HH:mm') -and $uSL.Contains('UTC') -and -not $uSL.Contains('ToUniversalTime')) { $utcStamps += ($uS + 1) }
  }
  ST-Check 'contract: no production line stamps local time under a UTC label' (@($utcStamps).Count -eq 0)
  if (@($utcStamps).Count -gt 0) { Write-Output ("      UTC-labelled local timestamps at line(s): $(Format-SourceLineList @($utcStamps))") }

  # ---------- v3.0.1 (audit #10/#11/#13/#24): resource hygiene, one check per claim ----------
  # These are the "a path with [ ] in it, a handle that does not fit, a stream nobody
  # closed" class. Each is asserted structurally where the fix is a code SHAPE (this call
  # inside that try) and behaviourally where a pure answer exists.
  $giRaw = @()
  for ($giI = 0; $giI -lt $clCount; $giI++) {
    if ($giI -ge $j5ProdStart -and $giI -lt $j5ProdEnd) { continue }
    $giL = [string]$codeLines[$giI]
    if ($giL -match '^\s*#') { continue }
    if ($giL -match 'Get-Item\s' -and -not $giL.Contains('Get-Item -LiteralPath')) { $giRaw += ($giI + 1) }
  }
  ST-Check 'lint: every production Get-Item is given a literal path (a user path with [ ] or * is a wildcard to the provider)' (
    @($giRaw).Count -eq 0)
  if (@($giRaw).Count -gt 0) { Write-Output "      bare Get-Item at line(s): $(Format-SourceLineList @($giRaw))" }
  $emptyNeedleErr = ''
  $emptyNeedleHits = -1
  $enLines = @([pscustomobject]@{ Text = 'ALPHA ONE'; X = 0; Y = 0; W = 10; H = 10 }, [pscustomobject]@{ Text = 'BETA TWO'; X = 0; Y = 1; W = 10; H = 1 })
  try { $emptyNeedleHits = Find-OcrHits $enLines '' } catch { $emptyNeedleErr = $_.Exception.Message }
  ST-Check 'unit: Find-OcrHits refuses an empty needle instead of matching every line (IndexOf("") is 0)' (
    ($emptyNeedleErr -like '*empty needle*') -and ($emptyNeedleHits -lt 0))
  $enOne = Find-OcrHits $enLines 'BETA'
  ST-Check 'unit: the same two lines still answer one hit for a real needle (the refusal did not eat the function)' (
    (@($enOne).Count) -eq 1)
  $ocrSlice = Get-FunctionSlice 'Invoke-OcrBitmap' $codeLines
  $ocrTryIdx = $ocrSlice.Text.IndexOf('try {')
  $ocrSaveIdx = $ocrSlice.Text.IndexOf('$src.Save(')
  $ocrFinIdx = $ocrSlice.Text.IndexOf('} finally')
  # Every marker below is ASSEMBLED by concatenation, the same way the older structural
  # lints do it: a check that quotes the exact text it hunts cannot be teeth-tested by a
  # global search-and-replace (the mutation edits the check too, and both stay green).
  $ocrDisposeMark = ('$ocrDisposables.Dispos' + 'e()')
  $ocrRemoveMark = ('Remove-Item -LiteralPath ' + '$tmp')
  ST-Check 'lint: the OCR temp file is written INSIDE the try and the WinRT stream and bitmap are disposed on the way out' (
    $ocrSlice.Found -and ($ocrTryIdx -ge 0) -and ($ocrSaveIdx -gt $ocrTryIdx) -and ($ocrFinIdx -gt $ocrSaveIdx) -and
    ($ocrSlice.Text.Contains($ocrDisposeMark)) -and ($ocrSlice.Text.Contains($ocrRemoveMark)))
  $cdpSlice = Get-FunctionSlice 'Invoke-CdpEval' $codeLines
  # The claim is not "the words $result and Ok=false appear somewhere in the function" -
  # they do four times on the normal paths. It is that the CATCH clause itself answers
  # through the contract, so the clause is sliced out and searched on its own.
  $cdpCatchTxt = ''
  $cdpCatchAt = $cdpSlice.Text.IndexOf('} catch {')
  if ($cdpCatchAt -ge 0) {
    $cdpFinAt = $cdpSlice.Text.IndexOf('} finally', $cdpCatchAt)
    if ($cdpFinAt -gt $cdpCatchAt) { $cdpCatchTxt = $cdpSlice.Text.Substring($cdpCatchAt, $cdpFinAt - $cdpCatchAt) }
  }
  $cdpCatchAssign = ('$result = @{ ' + 'Ok = $false')
  ST-Check 'lint: Invoke-CdpEval answers through the Ok/Error contract (the catch clause itself sets a refused verdict, the socket still always closes)' (
    $cdpSlice.Found -and ($cdpCatchTxt.Length -gt 20) -and ($cdpCatchTxt.Contains($cdpCatchAssign)) -and
    ($cdpSlice.Text.Contains('finally { $ws.Dispose() }')))
  $cdpNullMark = ('value=' + 'null')
  $cdpBlindMark = ('$($r.Value.' + 'Length) chars')
  $cdpJsonSlice = Get-FunctionSlice 'Invoke-CdpJson' $codeLines
  ST-Check 'lint: the non-JSON refusal states a size it can actually state (a null value says value=null, not an empty field)' (
    $cdpJsonSlice.Found -and ($cdpJsonSlice.Text.Contains($cdpNullMark)) -and (-not $cdpJsonSlice.Text.Contains($cdpBlindMark)))
  $tabSlice = Get-FunctionSlice 'Write-TabManifest' $codeLines
  $tabTryW = $tabSlice.Text.IndexOf('try {')
  $tabNewW = $tabSlice.Text.IndexOf('New-Object System.IO.StreamWriter')
  $tabFinW = $tabSlice.Text.IndexOf('} finally')
  $tabDisposeMark = ('$swMan.Dispos' + 'e()')
  ST-Check 'lint: the tab manifest writer is disposed in a finally (a half-written evidence file is worse than no file)' (
    $tabSlice.Found -and ($tabTryW -ge 0) -and ($tabNewW -gt $tabTryW) -and ($tabFinW -gt $tabNewW) -and
    ($tabSlice.Text.Contains($tabDisposeMark)))
  $hprSlice = Get-FunctionSlice 'Format-HandlePinReason' $codeLines
  $hprSites = 0
  for ($hprI = 0; $hprI -lt $clCount; $hprI++) {
    if ($hprI -ge $j5ProdStart -and $hprI -lt $j5ProdEnd) { continue }
    if (([string]$codeLines[$hprI]).Contains('Format-HandlePinReason $')) { $hprSites++ }
  }
  ST-Check 'lint: every handle-pin refusal line prints through the one formatter (three routes, one wording)' (
    $hprSlice.Found -and ($hprSites -eq 3))

  # ---------- v4.6.13 (D-3): the audit line carries its origin ----------
  # The audit log gained a fifth column in this commit and one reader grew a filter over
  # it. Three facts are asserted here, each on the REAL production function rather than a
  # copy: the shape reader accepts both line shapes and refuses anything else; the real
  # audit writer puts the tag in the fifth column of every line (default 'unknown'); log-index
  # filters by day/tag and counts unreadable lines instead of dropping them. The e2e leg drives the
  # REAL entry through a child process, but it deliberately uses the REFUSAL path for the
  # write side (an unusable tag is stopped before dispatch, so nothing touches the desk):
  # the offline gate must not send input just to prove a log column exists.
  $d3Stamp = [Guid]::NewGuid().ToString('N').Substring(0, 8)
  $d3Log = Join-Path ([System.IO.Path]::GetTempPath()) ('acu-d3-' + $d3Stamp + '.log')
  $d3Rows = @(
    '2026-10-30 01:02:03 UTC | move | coords=0,0 | id=1 | origin=d3tag',
    '2026-10-30 02:03:04 UTC | click | coords=10,20 | id=2 | origin=other',
    '2026-10-29 03:04:05 UTC | type | typed | id=3 | origin=d3tag',
    '2026-10-28 04:05:06 UTC | move | coords=5,5 | id=4',
    'this line is a note, not an audit line',
    'a | b | c | d | e | f'
  )
  [System.IO.File]::WriteAllText($d3Log, (($d3Rows -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
  $d3New = ConvertFrom-ActionLogLine ([string]$d3Rows[0])
  $d3Old = ConvertFrom-ActionLogLine ([string]$d3Rows[3])
  $d3Note = ConvertFrom-ActionLogLine ([string]$d3Rows[4])
  $d3Wide = ConvertFrom-ActionLogLine ([string]$d3Rows[5])
  $d3BadTag = ConvertFrom-ActionLogLine '2026-10-30 05:06:07 UTC | move | coords=0,0 | id=5 | origin=bad tag'
  ST-Check 'unit (D-3): one reader reads both audit-line shapes - five columns report their tag, four columns report origin=unknown with legacy=yes, and any other shape is $null (counted, never guessed)' (
    $null -ne $d3New -and [bool]$d3New.HasOrigin -and ([string]$d3New.Origin -ceq 'd3tag') -and
    ([string]$d3New.Date -ceq '2026-10-30') -and ([string]$d3New.Cmd -ceq 'move') -and
    $null -ne $d3Old -and (-not [bool]$d3Old.HasOrigin) -and ([string]$d3Old.Origin -ceq 'unknown') -and
    ([string]$d3Old.Target -ceq 'id=4') -and
    ($null -eq $d3Note) -and ($null -eq $d3Wide) -and ($null -eq $d3BadTag))
  Write-Output ('      D-3 shape reader: new=' + [string]$d3New.Origin + ' old=' + [string]$d3Old.Origin +
    ' note-null=' + ($null -eq $d3Note) + ' wide-null=' + ($null -eq $d3Wide) + ' bad-tag-null=' + ($null -eq $d3BadTag))
  $d3WLog = Join-Path ([System.IO.Path]::GetTempPath()) ('acu-d3w-' + $d3Stamp + '.log')
  $d3SavedLog = [string]$Ctx['actionLog']
  $d3SavedOrigin = [string](Get-Variable -Name 'LogOrigin' -Scope Script -ValueOnly -ErrorAction SilentlyContinue)
  if ($d3SavedOrigin -eq '') { $d3SavedOrigin = 'unknown' }
  $d3WriteErr = ''
  $d3WriteRows = @()
  try {
    $ActionLog = $d3WLog
    # The two planted writes go through a local alias whose value is the assembled token,
    # the same trick A-08 uses: the real writer runs, but the harness does not become two
    # more entries in the product inventory this card keeps.
    Set-Alias -Name 'd3-planted-audit-call' -Value "$script:StCommandToken"
    $script:LogOrigin = 'd3tag'
    & 'd3-planted-audit-call' @('coords=0,0') 'id=777' 'd3-probe'
    $script:LogOrigin = 'unknown'
    & 'd3-planted-audit-call' @('coords=1,1') 'id=778' 'd3-probe'
    $d3WriteRows = @(@([regex]::Split([System.IO.File]::ReadAllText($d3WLog), "\r?\n")) | Where-Object { $_ -ne '' })
  } catch { $d3WriteErr = $_.Exception.Message }
  finally {
    $ActionLog = $d3SavedLog
    $script:LogOrigin = $d3SavedOrigin
    if (Test-Path Alias:d3-planted-audit-call) { Remove-Item Alias:d3-planted-audit-call -Force }
  }
  $d3WP1 = @()
  if (@($d3WriteRows).Count -ge 1) { $d3WP1 = @([string]$d3WriteRows[0] -split ' \| ') }
  $d3WP2 = @()
  if (@($d3WriteRows).Count -ge 2) { $d3WP2 = @([string]$d3WriteRows[1] -split ' \| ') }
  ST-Check 'unit (D-3): the real audit writer puts origin in the fifth column of every line (a set tag verbatim, the default as unknown) while the four legacy columns keep their quoting' (
    ($d3WriteErr -eq '') -and (@($d3WriteRows).Count -eq 2) -and (@($d3WP1).Count -eq 5) -and (@($d3WP2).Count -eq 5) -and
    ([string]$d3WP1[1] -ceq 'd3-probe') -and ([string]$d3WP1[2] -ceq 'coords=0,0') -and ([string]$d3WP1[4] -ceq 'origin=d3tag') -and
    ([string]$d3WP2[4] -ceq 'origin=unknown') -and (([string]$d3WP1[0]).EndsWith(' UTC')))
  Write-Output ('      D-3 writer: lines=' + @($d3WriteRows).Count + ' tag=[' + (@($d3WP1) -join ' || ') + '] default=[' + (@($d3WP2) -join ' || ') + '] err=' + $d3WriteErr)
  $d3IndexAll = @(Invoke-Handler-log-index 'log-index' @('--log', $d3Log))
  $d3IndexTag = @(Invoke-Handler-log-index 'log-index' @('--log', $d3Log, '--origin', 'd3tag'))
  $d3IndexDay = @(Invoke-Handler-log-index 'log-index' @('--log', $d3Log, '--date', '2026-10-29'))
  $d3IndexOld = @(Invoke-Handler-log-index 'log-index' @('--log', $d3Log, '--origin', 'unknown'))
  $d3IndexBad = ''
  try { [void](Invoke-Handler-log-index 'log-index' @('--log', $d3Log, '--date', '2026-10-30T00')) } catch { $d3IndexBad = $_.Exception.Message }
  $d3AllTxt = ($d3IndexAll -join "`n"); $d3TagTxt = ($d3IndexTag -join "`n")
  $d3DayTxt = ($d3IndexDay -join "`n"); $d3OldTxt = ($d3IndexOld -join "`n")
  ST-Check 'unit (D-3): log-index indexes a planted log by origin tag and UTC day, keeps the legacy line as origin=unknown, and counts the two unreadable lines out loud instead of dropping them' (
    $d3AllTxt.Contains('4 of 6 non-empty line(s) matched') -and $d3AllTxt.Contains('2 unreadable line(s) skipped') -and
    $d3TagTxt.Contains('2 of 6') -and $d3TagTxt.Contains('origin=d3tag') -and (-not $d3TagTxt.Contains('origin=other')) -and
    $d3DayTxt.Contains('1 of 6') -and $d3DayTxt.Contains('2026-10-29') -and
    $d3OldTxt.Contains('1 of 6') -and $d3OldTxt.Contains('origin=unknown legacy=yes') -and
    $d3IndexBad.Contains('--date'))
  Write-Output ('      D-3 index: all=[' + $d3IndexAll.Count + ' lines] tag=[' + $d3IndexTag.Count + '] day=[' + $d3IndexDay.Count +
    '] legacy=[' + $d3IndexOld.Count + '] bad-date=[' + $d3IndexBad + ']')
  $d3RealLog = [string]$Ctx['actionLog']
  $d3CountLines = {
    param([string]$p)
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return 0 }
    try { return @(@([regex]::Split([System.IO.File]::ReadAllText($p), "\r?\n")) | Where-Object { $_ -ne '' }).Count } catch { return -1 }
  }
  $d3RealBefore = & $d3CountLines $d3RealLog
  $d3BadChild = & $cnpRun -ChildArgs @('move', '0', '0', '--origin', 'not a tag')
  $d3RealAfter = & $d3CountLines $d3RealLog
  $d3IdxChild = & $cnpRun -ChildArgs @('log-index', '--log', $d3Log, '--origin', 'd3tag')
  if (-not $script:PsChildOk) {
    ST-Skip 'e2e (D-3): a real child refuses an unusable origin tag BEFORE dispatch and log-index reads the log through the real entry with --origin as a FILTER' ($script:PsChildWhy + ' - the check spawns a child process')
  } else {
  ST-Check 'e2e (D-3): a real child refuses an unusable origin tag BEFORE dispatch (exit 1, names --origin, actions.log line count unchanged) and log-index reaches the planted log through the real entry with --origin as a FILTER (the entry does not eat it)' (
    $d3BadChild.code -eq 1 -and (($d3BadChild.out + "`n" + $d3BadChild.err).Contains('--origin')) -and
    ($d3RealBefore -eq $d3RealAfter) -and ($d3RealBefore -ge 0) -and
    $d3IdxChild.code -eq 0 -and $d3IdxChild.out.Contains('2 of 6') -and $d3IdxChild.out.Contains('origin=d3tag') -and
    (-not $d3IdxChild.out.Contains('origin=other')))
  Write-Output ('      D-3 children: bad-tag exit=' + [string]$d3BadChild.code + ' real-log=' + $d3RealBefore + '->' + $d3RealAfter +
    ' index exit=' + [string]$d3IdxChild.code + ' out-lines=' + $d3IdxChild.outCount)
  }
  if (Test-Path -LiteralPath $d3Log) { Remove-Item -LiteralPath $d3Log -Force }
  if (Test-Path -LiteralPath $d3WLog) { Remove-Item -LiteralPath $d3WLog -Force }

  # ---------- v4.8.0 (B-2): the origin is resolved per context, and the index walks the archives ----------
  # D-3 gave every audit line a fifth column and log-index a date/tag filter over ONE file. B-2
  # closes the two gaps a one-file index leaves open: where the tag COMES FROM when the caller did
  # not type one (a declared mode and the caller-env label, in that order, else unknown), and the
  # archives the rotator moved aside (a day that lives only in actions_<stamp>.log must be findable
  # by date, and its absence - the rotator DELETES old archives - must read as "the record is gone",
  # never as "nothing happened").
  $b2LogDir = Join-Path ([System.IO.Path]::GetTempPath()) ('dtx-b2log-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  [void][System.IO.Directory]::CreateDirectory($b2LogDir)
  try {
    # (1) the resolver's order is the contract: an explicit tag beats everything, the declared mode
    # beats the caller env, a caller-env label is earned only from the two sources that actually
    # expose one, anything else is unknown - and a label that fails the tag grammar degrades to
    # unknown instead of smuggling a pipe or a space into the '|'-delimited log.
    $b2R1 = Resolve-AuditOrigin 'explicit' 'selftest' 'Whatever' 'explicit-environment'
    $b2R2 = Resolve-AuditOrigin '' 'selftest' 'Whatever' 'explicit-environment'
    $b2R3 = Resolve-AuditOrigin '' '' 'MyLabel' 'explicit-environment'
    $b2R4 = Resolve-AuditOrigin '' '' 'My-Label.2' 'partial-explicit-environment'
    $b2R5 = Resolve-AuditOrigin '' '' 'MyLabel' 'none'
    $b2R6 = Resolve-AuditOrigin '' '' 'bad label!' 'explicit-environment'
    $b2R7 = Resolve-AuditOrigin '' '' '' ''
    ST-Check 'unit (B-2): the origin resolver keeps its order - explicit tag, then the declared mode, then a caller env label from the two sources that earn one, then unknown; a label with unsafe characters is SANITIZED to a legal token (measured: it never reaches the log as typed), and a label that sanitizes to nothing stays unknown' (
      ($b2R1 -ceq 'explicit') -and ($b2R2 -ceq 'selftest') -and ($b2R3 -ceq 'MyLabel') -and ($b2R4 -ceq 'My-Label.2') -and
      ($b2R5 -ceq 'unknown') -and ($b2R6 -ceq 'bad-label') -and ($b2R7 -ceq 'unknown'))
    # (2) the write path really resolves: the audit writer contains exactly one resolver call, and
    # the same counter counts a planted second call - a writer that stopped resolving (and started
    # printing a constant) would show up here instead of flattening every origin silently. The
    # writer's NAME is read from the registered token rather than typed: a literal of the audited
    # command inside a scanner is exactly the mention the A-07 exclusion sweep would have to excuse.
    $b2EntryLines = @([System.IO.File]::ReadAllLines((Join-Path $script:ToolRootPath 'desktop.ps1')))
    $b2LaMark = 'function ' + [string]$script:StCommandToken
    $b2LaStart = -1
    for ($b2i = 0; $b2i -lt $b2EntryLines.Count; $b2i++) { if (([string]$b2EntryLines[$b2i]).StartsWith($b2LaMark)) { $b2LaStart = $b2i; break } }
    $b2LaEnd = $b2EntryLines.Count
    if ($b2LaStart -ge 0) {
      for ($b2j = $b2LaStart + 1; $b2j -lt $b2EntryLines.Count; $b2j++) { if (([string]$b2EntryLines[$b2j]).StartsWith('function ')) { $b2LaEnd = $b2j; break } }
    }
    $b2LaBody = @()
    for ($b2k = $b2LaStart; $b2k -lt $b2LaEnd; $b2k++) { if ($b2k -ge 0) { $b2LaBody += [string]$b2EntryLines[$b2k] } }
    # the call mark is assembled (an equals sign + the resolver name split around its middle) so
    # this scanner cannot match its own source line the way P-05's first draft did.
    $b2LaCallMark = [string][char]0x3D + ' Resolve-' + 'AuditOrigin '
    $b2RealCalls = @(@($b2LaBody) | Where-Object { (-not ([string]$_).TrimStart().StartsWith([char]0x23)) -and (([string]$_).Contains($b2LaCallMark)) })
    $b2PlantBody = @(
      ('function Log-Plant { ' + $b2LaCallMark + "'' '' '' '' }"),
      ('  ' + $b2LaCallMark + "'' '' '' ''"))
    $b2PlantCalls = @(@($b2PlantBody) | Where-Object { (-not ([string]$_).TrimStart().StartsWith([char]0x23)) -and (([string]$_).Contains($b2LaCallMark)) })
    ST-Check 'lint (B-2): the audit writer resolves the origin exactly once (one resolver call in the writer body), and the same counter counts a planted second call - the ruler is not a needle that always reads one' (
      ($b2LaStart -ge 0) -and (@($b2RealCalls).Count -eq 1) -and (@($b2PlantCalls).Count -eq 2))
    # (3) --scope day walks the archives BY LINE DATE, not by file name: the seeded archive is
    # NAMED for one local day and carries lines of two UTC days, and the day filter hits the lines.
    $b2Cur = Join-Path $b2LogDir 'cur.log'
    $b2Arch = Join-Path $b2LogDir 'actions_20261030T080000.log'
    $b2Line5 = {
      param([string]$d, [string]$tag, [string]$cmd)
      return ($d + ' 05:00:00 UTC | ' + $cmd + ' | args | target-' + $tag + ' | origin=' + $tag)
    }
    $b2ArchText = (& $b2Line5 '2026-10-29' 'a1' 'win') + "`r`n" + (& $b2Line5 '2026-10-30' 'a2' 'win') + "`r`n" + 'garbage line shape' + "`r`n"
    [System.IO.File]::WriteAllText($b2Arch, $b2ArchText, (New-Object System.Text.UTF8Encoding($false)))
    $b2CurText = (& $b2Line5 '2026-10-30' 'c1' 'rect') + "`r`n" + ('2026-10-29 06:00:00 UTC | win | args | target-old') + "`r`n"
    [System.IO.File]::WriteAllText($b2Cur, $b2CurText, (New-Object System.Text.UTF8Encoding($false)))
    $b2AllOut = @(Invoke-DesktopCommand 'log-index' @('--log', $b2Cur, '--scope', 'all')) -join "`n"
    $b2DayOut = @(Invoke-DesktopCommand 'log-index' @('--log', $b2Cur, '--scope', 'day', '--date', '2026-10-29')) -join "`n"
    $b2DayNoDateErr = ''
    try { [void](Invoke-DesktopCommand 'log-index' @('--log', $b2Cur, '--scope', 'day')) } catch { $b2DayNoDateErr = "$($_.Exception.Message)" }
    ST-Check 'unit (B-2): --scope all indexes the live log AND the archive the rotator left (files-scanned=2, per-file rows reconcile, the skipped shape is counted out loud, retention is disclosed as a policy); --scope day filters by the LINE date so an archive named for another day still answers; --scope day with no --date is refused by name' (
      ($b2AllOut.Contains('scope=all 4 of 5 non-empty line(s) matched across files-scanned=2')) -and
      ($b2AllOut.Contains('role=archive')) -and ($b2AllOut.Contains('lines=3')) -and ($b2AllOut.Contains('unreadable=1')) -and
      ($b2AllOut.Contains('role=current')) -and ($b2AllOut.Contains('lines=2')) -and
      ($b2AllOut.Contains('archive NAME = the rotation')) -and ($b2AllOut.Contains('DELETED BY THE TOOL')) -and
      ($b2DayOut.Contains('scope=day 2 of 5')) -and
      ($b2DayOut.Contains('target-a1')) -and
      ($b2DayOut.Contains('origin=unknown legacy=yes') -and $b2DayOut.Contains('target-old')) -and
      ($b2DayNoDateErr.Contains('--scope day needs --date')))
    # (4) the multi-file rows name the file they came from, and --scope current stays the pre-B-2
    # shape byte for byte: same summary line, no per-file rows, no scope token, no retention note.
    $b2CurOnly = @(Invoke-DesktopCommand 'log-index' @('--log', $b2Cur, '--origin', 'c1')) -join "`n"
    ST-Check 'unit (B-2): scope=current keeps the pre-B-2 output verbatim (no scope token, no per-file rows, no retention note) while the multi-file rows carry their own [file] marker' (
      ($b2CurOnly.Contains('1 of 2 non-empty line(s) matched')) -and
      (-not $b2CurOnly.Contains('files-scanned=')) -and (-not $b2CurOnly.Contains('retention:')) -and
      ($b2AllOut.Contains('cur.log]')) -and ($b2AllOut.Contains('actions_20261030T080000.log]')))
    # (5) the real entry: --scope day reaches the archives through a child, and a scope the grammar
    # does not know is refused by name before any file is opened.
    if (-not $script:PsChildOk) {
      ST-Skip 'e2e (B-2): the real entry indexes the seeded archives by day and refuses an unknown scope by name' ($script:PsChildWhy + ' - the check spawns a child process')
    } else {
      $b2ChildDay = & $cnpRun -ChildArgs @('log-index', '--log', $b2Cur, '--scope', 'day', '--date', '2026-10-29')
      $b2ChildBad = & $cnpRun -ChildArgs @('log-index', '--log', $b2Cur, '--scope', 'everything')
      ST-Check 'e2e (B-2): through the real entry --scope day finds the archive line the live file does not hold (and the live line the archive does not), and --scope everything is refused by name with the three legal values' (
        ($b2ChildDay.code -eq 0) -and $b2ChildDay.out.Contains('scope=day 2 of 5') -and
        $b2ChildDay.out.Contains('files-scanned=2') -and $b2ChildDay.out.Contains('target-a1') -and
        ($b2ChildBad.code -eq 1) -and $b2ChildBad.out.Contains('--scope must be current|day|all'))
    }
  } finally {
    try { if (Test-Path -LiteralPath $b2LogDir) { Remove-Item -LiteralPath $b2LogDir -Recurse -Force } } catch { }
  }

}
