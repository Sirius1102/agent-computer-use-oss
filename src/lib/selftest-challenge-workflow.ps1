# lib/selftest-challenge-workflow.ps1 - family challenge-workflow of the selftest section, lifted out
# of lib/selftest.ps1 by A-14g (A-beta). Bodies are byte-identical to what the section carried.
# Two banners, 204 lines: the verification-challenge workflow (J-02: detect, classify, staleness, one
# authorized attempt, fuse, handoff - and explicitly NO solver) and the process-entry environment
# normalizer (F2). A-14e attempted this same cut and reverted it: two production lints reddened
# because the window they exempt themselves by was an open interval that stopped at the first family
# file. A-14f replaced that window with the AST span of every selftest body, which is what makes
# this card possible without touching those lints. The second block moves forward to join the first;
# the reordering is counted in the card notes, not waved away.
function Invoke-SelftestFamily-ChallengeWorkflow($Ctx) {
  # context handover (the one thing in this file that is not lifted text)
  $codeLines = $Ctx['codeLines']
  $clCount = $Ctx['clCount']
  $j5ProdStart = $Ctx['j5ProdStart']
  $j5ProdEnd = $Ctx['j5ProdEnd']
  $srcLines = $Ctx['srcLines']

  # ---------- v1.10.0: verification-challenge workflow (J-02 boundary: detect/classify/staleness/one-authorized-attempt/fuse/handoff; NO solver) ----------
  # Synthetic OCR lines only - the real thing is a live concern. Corpus needles come
  # FROM Get-ChallengeCorpus (a second hand-built copy here would drift silently).
  $c40Corpus = @(Get-ChallengeCorpus)
  $c40Drag = @($c40Corpus | Where-Object { $_.Kind -eq 'slider' })[0].Needle
  $c40Puzzle = @($c40Corpus | Where-Object { $_.Kind -eq 'slider' })[1].Needle
  $c40Secure = @($c40Corpus | Where-Object { $_.Needle.Length -eq 4 })[0].Needle
  $c40Mk = { param($txt, $x, $y) [pscustomobject]@{ Text = $txt; X = $x; Y = $y; W = 300; H = 34 } }
  $c40Slider = Test-ChallengeLines @((& $c40Mk "$c40Drag$c40Puzzle" 40 30), (& $c40Mk 'some ordinary card text' 40 90))
  ST-Check 'unit: challenge matcher - a slider-affordance line classifies slider-captcha and its line is the handle' (
    $c40Slider.Challenge -and ($c40Slider.Type -eq 'slider-captcha') -and ($null -ne $c40Slider.Handle) -and ($c40Slider.Handle.Y -eq 30))
  $c40Plain = Test-ChallengeLines @((& $c40Mk 'order summary row one' 40 30), (& $c40Mk 'order summary row two' 40 90), (& $c40Mk 'order summary row three' 40 150))
  ST-Check 'unit: challenge matcher - dense ordinary text reads none (the two directions of V-1)' (-not $c40Plain.Challenge)
  $c40Single = Test-ChallengeLines @((& $c40Mk "$c40Secure page" 40 30))
  $c40High = Test-ChallengeLines @((& $c40Mk "$c40Drag$c40Puzzle" 40 30), (& $c40Mk "$c40Secure" 40 90))
  ST-Check 'unit: challenge matcher - one hit reads medium, several hits read high' (
    ($c40Single.Confidence -eq 'medium') -and ($c40High.Confidence -eq 'high') -and (@($c40High.Matched).Count -ge 3))
  $c40S1 = Test-ChallengeStale '' 'aabb'
  $c40S2 = Test-ChallengeStale 'aabb' 'aabb'
  $c40S3 = Test-ChallengeStale 'aabb' 'ccdd'
  ST-Check 'unit: challenge staleness - first-seen / unchanged reads stale=yes with the dismiss advice / changed reads stale=no' (
    ($c40S1.Stale -eq 'first-seen') -and ($c40S2.Stale -eq $true) -and $c40S2.Recommend.Contains('dismiss-not-solve') -and ($c40S3.Stale -eq $false))
  $c40Id = Get-ChallengeIdentityHash @{ Type = 'slider-captcha'; Confidence = 'high'; Matched = @('drag', 'secure'); Lines = 3; Handle = [pscustomobject]@{ X = 1; Y = 2; W = 3; H = 4 } }
  $c40Id2 = Get-ChallengeIdentityHash @{ Type = 'slider-captcha'; Confidence = 'high'; Matched = @('secure', 'drag'); Lines = 3; Handle = [pscustomobject]@{ X = 1; Y = 2; W = 3; H = 4 } }
  $c40Id3 = Get-ChallengeIdentityHash @{ Type = 'slider-captcha'; Confidence = 'high'; Matched = @('secure'); Lines = 3; Handle = [pscustomobject]@{ X = 1; Y = 2; W = 3; H = 4 } }
  ST-Check 'unit: challenge identity hash is stable across corpus order and changes when the recognized challenge changes' (
    $c40Id -eq $c40Id2 -and $c40Id -ne $c40Id3 -and $c40Id -match '^[0-9a-f]{32}$')
  $c40Log1 = '2026-10-01 00:00:00 UTC | challenge-probe | pid=111 | seen hash=0000000000000000000000000000aaaa'
  $c40Log2 = '2026-10-01 00:00:01 UTC | challenge-probe | pid=222 | seen hash=0000000000000000000000000000bbbb'
  $c40Log3 = '2026-10-01 00:00:02 UTC | challenge-probe | pid=111 | fuse hash=0000000000000000000000000000cccc'
  $c40Log4 = '2026-10-01 00:00:03 UTC | click | 10 20 | pid=111 title=x'
  $c40State = Test-ChallengeLogLines @($c40Log1, $c40Log2, $c40Log3, $c40Log4) 111
  $c40StateOther = Test-ChallengeLogLines @($c40Log1, $c40Log2, $c40Log3, $c40Log4) 222
  ST-Check 'unit: challenge log state - seen and fuse hashes extracted per pid, other pids and act lines ignored' (
    ($c40State.LastHash -eq '0000000000000000000000000000aaaa') -and ($c40State.FuseHash -eq '0000000000000000000000000000cccc') -and
    ($c40StateOther.LastHash -eq '0000000000000000000000000000bbbb') -and ($c40StateOther.FuseHash -eq ''))
  # v4.0.1 (audit finding 2): the three read outcomes must not collapse into one another. `absent`
  # is the only state allowed to become first-seen; `unreadable` has to stay a separate answer,
  # which is what the last clause pins - if both branches ever return the same token, this goes
  # red instead of quietly re-opening the fail-open fuse.
  $c40LbAbsent = Resolve-ChallengeLogState $false $false
  $c40LbUnread = Resolve-ChallengeLogState $true $false
  $c40LbUnwrit = Resolve-ChallengeLogState $true $true $false
  $c40LbOk = Resolve-ChallengeLogState $true $true
  $c40LbDflt = Resolve-ChallengeLogState $true $true $true
  # pairwise distinctness is the whole point: if any two branches ever return the same token the
  # unique-count drops and this goes red instead of quietly re-opening the fail-open fuse.
  $c40LbSet = @($c40LbAbsent, $c40LbUnread, $c40LbUnwrit, $c40LbOk) | Sort-Object -Unique
  ST-Check 'unit: challenge log read state - absent / unreadable / unwritable / ok are four pairwise distinct answers and the 2-arg form still means the write succeeded' (
    ($c40LbAbsent -ceq 'absent') -and ($c40LbUnread -ceq 'unreadable') -and ($c40LbUnwrit -ceq 'unwritable') -and ($c40LbOk -ceq 'ok') -and
    (@($c40LbSet).Count -eq 4) -and ($c40LbDflt -ceq $c40LbOk))
  # v4.1.1 (X-02 residual, surfaced by the second external review round): a bare LOCAL null-init
  # sitting next to a script-scoped read is NOT an initialiser for that read - it is dead code that
  # LOOKS like the guard, and under StrictMode the finally then raises a second error that masks
  # the real one. Two instances were live in the file (the challenge fixture and the popup-gate
  # fixture). The predicate is proven against a planted copy of the shape, because a lint that has
  # never fired on a known-bad input is not a lint. Plant strings are ASSEMBLED at runtime so this
  # very block cannot be flagged by the scan it defines.
  $scopeOffenders = {
    param($slArr)
    $bad2 = @()
    foreach ($sl in $slArr) {
      $mScope = [regex]::Match([string]$sl, '^\s*\$([A-Za-z][A-Za-z0-9_]*)\s*=\s*\$null\s*$')
      if (-not $mScope.Success) { continue }
      $sName = $mScope.Groups[1].Value
      $asScript = 0; $asBare = 0
      foreach ($sl2 in $slArr) {
        $s2 = [string]$sl2
        $asScript += ([regex]::Matches($s2, ('\$script:' + [regex]::Escape($sName) + '(?![A-Za-z0-9_])'))).Count
        $asBare += ([regex]::Matches($s2, ('\$' + [regex]::Escape($sName) + '(?![A-Za-z0-9_])'))).Count
      }
      if ($asScript -gt 0 -and $asBare -le 1) { $bad2 += $sName }
    }
    return ,@($bad2)
  }
  $scopeReal = & $scopeOffenders $codeLines
  $plStem = 'zz' + 'Proc'
  $scopePlant = @(
    ('      $' + $plStem + ' = ' + '$null'),
    '      try {',
    ('        $script:' + $plStem + ' = Start-Process x'),
    '      } finally {',
    ('        if ($script:' + $plStem + ') { Stop-Process }'),
    '      }'
  )
  $scopeCaught = & $scopeOffenders $scopePlant
  Write-Output ('      scope-shadow offenders=' + (@($scopeReal).Count) + ' [' + (@($scopeReal) -join ',') + '] plant-caught=' + (@($scopeCaught).Count))
  ST-Check 'lint: no bare local null-initialiser may stand in for the script-scoped variable a finally actually reads, and the predicate catches a planted copy of the shape' (
    (@($scopeReal).Count -eq 0) -and (@($scopeCaught).Count -eq 1) -and ($scopeCaught[0] -ceq $plStem))
  $c40HandWin = [pscustomobject]@{ Title = 'DTX-ChalProbe'; Pid = 4242; Left = 150; Top = 700; W = 700; H = 420 }
  $c40Hand = Build-ChallengeHandoff $c40Slider $c40HandWin 'deadbeef' 'shots\challenge-x.png'
  $c40HandAll = "$($c40Hand -join [char]10)"
  ST-Check 'unit: challenge handoff carries all four contract fields (type= / rect= / handle: / shot:) - V-4 named contract' (
    $c40HandAll.Contains('type=slider-captcha') -and $c40HandAll.Contains('rect=(150,700,700x420)') -and $c40HandAll.Contains('  handle: (') -and $c40HandAll.Contains('  shot: shots\challenge-x.png'))
  $c40HandNoHandle = Build-ChallengeHandoff $c40Plain $c40HandWin 'deadbeef' 'shots\challenge-x.png'
  ST-Check 'unit: challenge handoff without a slider line still carries the handle field as not-found (the field never disappears)' (
    (("$($c40HandNoHandle -join [char]10)")).Contains('  handle: not-found'))
  $c41DefN = 0; $c41CallN = 0; $c41FuseMsg = 0; $c41NotAuth = 0; $c41NoSolver = 0
  for ($c41i = 0; $c41i -lt $codeLines.Count; $c41i++) {
    if ($c41i -ge $j5ProdStart -and $c41i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c41i] -match '^\s*#') { continue }
    if ($codeLines[$c41i].StartsWith('function Get-ChallengeCorpus')) { $c41DefN++ }
    if ($codeLines[$c41i].Contains('(Get-ChallengeCorpus)') -and (-not $codeLines[$c41i].Contains('$c40'))) { $c41CallN++ }
    if ($codeLines[$c41i].Contains(('challenge attempt FAILED '))) { $c41FuseMsg++ }
    if ($codeLines[$c41i].Contains(('attempt: not authorized (pass --allow-' + 'attempt'))) { $c41NotAuth++ }
    if ($codeLines[$c41i].Contains(('There is NO solver ' + 'in this tool by design'))) { $c41NoSolver++ }
  }
  ST-Check 'lint: the challenge corpus has exactly one definition and one production consumer (a second copy would drift silently)' (
    ($c41DefN -eq 1) -and ($c41CallN -eq 1))
  ST-Check 'lint: the attempt gate speaks once (not-authorized hint, FAILED fuse message) and the no-solver boundary is stated in code, not just docs' (
    ($c41FuseMsg -eq 1) -and ($c41NotAuth -eq 1) -and ($c41NoSolver -ge 1))
  # v2.2.0 (R5-B): the act-count witness cannot tell "a guard refused the click" from "the
  # click landed and the challenge stayed up" - both read exit 1 + FAILED + delta 0. The
  # FAILED line already says which, so the live echo must carry it, and that carry must not
  # be removable without going red here. Both markers live in the SELFTEST body, so this
  # scans exactly the range the production-wiring loop above deliberately skips.
  $c41Reason = 0; $c41WhyCap = 0
  for ($c41j = $j5ProdStart; $c41j -lt $j5ProdEnd; $c41j++) {
    if ($codeLines[$c41j].Contains(('click-' + 'reason='))) { $c41Reason++ }
    if ($codeLines[$c41j].Contains(('$chFail' + 'Lines = @('))) { $c41WhyCap++ }
  }
  ST-Check 'lint: the V-3 live echo carries the tool own refusal reason (click-reason field spoken exactly once, fed by exactly one FAILED-line capture) - a flat act delta must be self-classifying' (
    ($c41Reason -eq 1) -and ($c41WhyCap -eq 1))
  Write-Output ("      challenge wiring: corpus-def=$c41DefN corpus-call=$c41CallN fuse-msg=$c41FuseMsg not-auth=$c41NotAuth")


  # ---------- v4.2.2 (F2): the process-entry environment normalizer ----------
  # A process environment block can carry one name twice in different casing. Windows resolves
  # every lookup case-insensitively, but PS 5.1's Start-Process copies the block into its own
  # case-insensitive dictionary and dies on the twin - measured 2026-10-10, and it took the whole
  # offline gate down before its summary line. Three checks in the house shape: the pure decision
  # fed SYNTHETIC input (including a planted twin), the raw reader being non-vacuous (a reader
  # that sees nothing would make any box look clean - the "0 hits" rule), and the wiring counted
  # over the production region (one raw read, one removal primitive, no second implementation).
  $f2NoDup = Get-DuplicateCaseEnvNames @('PATH', 'TEMP')
  $f2OneDup = Get-DuplicateCaseEnvNames @('PATH', 'Path')
  $f2Triple = Get-DuplicateCaseEnvNames @('HTTP_PROXY', 'http_proxy', 'Http_Proxy')
  $f2Exact = Get-DuplicateCaseEnvNames @('PATH', 'PATH')
  $f2Near = Get-DuplicateCaseEnvNames @('PATH', 'PATHX')
  ST-Check 'unit (F2): the duplicate-case finder keeps the FIRST spelling, names every later one, and never touches a name that merely looks similar' (
    (@($f2NoDup).Count -eq 0) -and (@($f2OneDup).Count -eq 1) -and ($f2OneDup[0] -ceq 'Path') -and
    (@($f2Triple).Count -eq 2) -and ($f2Triple[0] -ceq 'http_proxy') -and ($f2Triple[1] -ceq 'Http_Proxy') -and
    (@($f2Exact).Count -eq 1) -and ($f2Exact[0] -ceq 'PATH') -and (@($f2Near).Count -eq 0))
  $f2RawAll = @([DT]::RawEnvNames())
  $f2RawEquals = @($f2RawAll | Where-Object { ([string]$_).Contains('=') })
  ST-Check 'unit (F2): the raw environment reader sees this process own block and returns NAMES, never NAME=VALUE (an empty or unsplit read would make every box look clean)' (
    ($f2RawAll.Count -ge 10) -and (@($f2RawAll | Where-Object { ([string]$_).Length -gt 0 }).Count -eq $f2RawAll.Count) -and
    ($f2RawEquals.Count -eq 0) -and (@($f2RawAll | Where-Object { ([string]$_) -ieq 'PATH' }).Count -ge 1))
  $f2CallSites = @()
  $f2RemoveSites = @()
  for ($f2I = 0; $f2I -lt $clCount; $f2I++) {
    if ($f2I -ge $j5ProdStart -and $f2I -lt $j5ProdEnd) { continue }
    $f2L = [string]$codeLines[$f2I]
    if ($f2L -match '^\s*#') { continue }
    if ($f2L.Contains('Get-DuplicateCaseEnvNames $envRawNames')) { $f2CallSites += ($f2I + 1) }
    if ($f2L.Contains('SetEnvironmentVariable($envDn')) { $f2RemoveSites += ($f2I + 1) }
  }
  ST-Check 'lint (F2): the entry normalizer is wired exactly once - one raw read, one removal primitive, and no second implementation' (
    (@($f2CallSites).Count -eq 1) -and (@($f2RemoveSites).Count -eq 1))
  Write-Output ("      env normalizer: call-sites=[" + (Format-SourceLineList $f2CallSites) + "] remove-sites=[" + (Format-SourceLineList $f2RemoveSites) + "] raw-names=" + $f2RawAll.Count)

  # v3.1.0 (F-03): that block now carries a SECOND skip shape - a private-history anchor read from a
  # re-rooted public clone. It has to be pinned, not trusted: an unasserted skip is how this project
  # shipped two "silently always green" cases already. The counts below are EXACT on purpose - a floor
  # would survive deleting either half of the narrowing conjunction, and the private tree MUST still
  # go red when its own anchors disappear. 3 = the assignment, the branch, and this file's own
  # conjunction mark (which names the gate variable, not the full conjunction, so the conjunction
  # count stays 1 and only the real branch can satisfy it).
  $pubGateMark = '$anchPub' + 'lished'
  $pubSkipMark = 'are private-history anchors and this is the ' + 'published tree'
  $pubProbeMark = "'cat-file', '-e', (" + '$anchOid'
  $pubConjMark = '$anchPublished -and $anchMissing' + '.Count -gt 0'
  $pubNoBytesMark = 'NO bytes were ' + 'compared'
  $pubGateLines = 0; $pubSkipLines = 0; $pubProbeLines = 0; $pubConjLines = 0; $pubNoBytesLines = 0
  foreach ($ep in $srcLines) {
    $eps = [string]$ep
    if ($eps.Contains($pubGateMark)) { $pubGateLines++ }
    if ($eps.Contains($pubSkipMark)) { $pubSkipLines++ }
    if ($eps.Contains($pubProbeMark)) { $pubProbeLines++ }
    if ($eps.Contains($pubConjMark)) { $pubConjLines++ }
    if ($eps.Contains($pubNoBytesMark)) { $pubNoBytesLines++ }
  }
  # X-02: this helper shipped WITHOUT a test of its own, and that is exactly how the bug below hid.
  # A hashtable's Keys / Values / Count are INTRINSIC members, not keys, so an early
  # "if IDictionary -> return $null when the key is absent" made them read as missing. It surfaced
  # only when a later batch rewrote a $spec.Keys read and the run died on "cannot index a null array"
  # with 584 verdicts flipped. Intrinsic members must keep resolving through PSObject.
  $x02Hasht = @{ A = 1 }
  $x02Obj = [pscustomobject]@{ A = 2 }
  $x02ObjNoA = [pscustomobject]@{ B = 3 }
  ST-Check 'unit (X-02): Get-OptValue separates an absent KEY from an INTRINSIC member (hashtable Keys/Count are not keys - that early return once turned them into null, which is why the helper has a test now)' (
    ((Get-OptValue $x02Hasht 'A') -eq 1) -and
    ($null -eq (Get-OptValue $x02Hasht 'MissingKey')) -and
    ($null -ne (Get-OptValue $x02Hasht 'Keys')) -and (@(Get-OptValue $x02Hasht 'Keys').Count -eq 1) -and
    ((Get-OptValue $x02Hasht 'Count') -eq 1) -and
    ($null -ne (Get-OptValue $x02Hasht 'Values')) -and ($((Get-OptValue $x02Hasht 'Values')[0]) -eq 1) -and
    ((Get-OptValue $x02Obj 'A') -eq 2) -and
    ($null -eq (Get-OptValue $x02ObjNoA 'A')) -and
    ($null -eq (Get-OptValue $null 'A'))
  )
  ST-Check 'lint (F-03): the BOM anchor publishes a SECOND, narrowed skip (published tree AND missing private anchor), self-reports that no bytes were compared, and the private tree keeps its red' (
    ($pubGateLines -eq 3) -and ($pubSkipLines -eq 1) -and ($pubProbeLines -eq 1) -and ($pubConjLines -eq 1) -and ($pubNoBytesLines -eq 1))
  Write-Output ("      anchor skip shapes: gate=$pubGateLines pub-skip=$pubSkipLines presence-probe=$pubProbeLines conjunction=$pubConjLines no-bytes-disclosure=$pubNoBytesLines")


}
