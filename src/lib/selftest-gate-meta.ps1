# lib/selftest-gate-meta.ps1 - one family of the selftest section, lifted out of lib/selftest.ps1 by
# A-14q (A-beta) and finished by A-14r: the last family, and the only one that could not leave
# entirely. The lifted text is byte-identical to what the section carried - the union of the lifted
# lines was hashed before each cut (.cowork-temp/a14q-lift-pre-cut.txt, a14r-lift-pre-cut.txt) and the
# region is re-hashed inside this file after it - and the only channel to the orchestrator is the
# context object. Nothing is handed back: zero $Ctx[...] writes in either span.
#
# gate-meta is what remains when no subject names a group: lints that judge the checker itself. At the
# A-14q/r lift it had 24 banner runs: 22 moved (18 by A-14q, 4 by A-14r), and 2 stayed as structure:
# * `unit: window model` runs Get-WinList - a LIVE enumeration - and carries the in-place publish site
#   and lint (A-14p); lifting it would move the snapshot to an earlier desktop.
# * `--index / --only contracts` grades THIS RUN'S TRANSCRIPT, so it stays where the run ends.
# The four stays A-14q left were not physical, they were ordering, and A-14r removed the ordering:
# * a run that READ a hand-back re-bind ($dcCase / $dcKnown / $wA) could not move while the call sat
#   ABOVE the publish - attempt 1 proved it by aborting on $wA.Handle, because a re-bind is
#   orchestration work and family to family is not an authorised channel. The call now sits below the
#   publish and the values arrive through $Ctx, which lint (A-14r) certifies name by name.
# * a run whose assigned name was still READ by inline text could not move either; the two producers
#   involved ($commaFns and the production slice $mvProd) are hoisted into the setup and published, so
#   one value serves both sides of the boundary - measured after the cut, $commaFns still has an inline
#   reader (the wrapper-lint loop in the orchestration) and $mvProd has none left except the chain gate
#   that checks its own slice (attempt 2 aborted on $commaFns before any of that was true).
# The runs that move are segments, because the family calls inside them stay where they are - a lifted
# family may not call a family - and the fenced A-14r chain block stays in the orchestration.
function Invoke-SelftestFamily-GateMeta($Ctx) {
  # context handover (the one thing in this file above the lifted text that is not lifted text)
  $ActionLog = $Ctx['actionLog']
  $clCount = $Ctx['clCount']
  $codeLines = $Ctx['codeLines']
  $commaFns = $Ctx['commaFns']
  $dcCase = $Ctx['dcCase']
  $dcKnown = $Ctx['dcKnown']
  $gaCaseIdx = $Ctx['gaCaseIdx']
  $gaCases = $Ctx['gaCases']
  $gaCasesCount = $Ctx['gaCasesCount']
  $gaDispStart = $Ctx['gaDispStart']
  $gaHelpEnd = $Ctx['gaHelpEnd']
  $gaHelpStart = $Ctx['gaHelpStart']
  $j5ProdEnd = $Ctx['j5ProdEnd']
  $j5ProdStart = $Ctx['j5ProdStart']
  $j5SelfParsed = $Ctx['j5SelfParsed']
  $mvProd = $Ctx['mvProd']
  $src = $Ctx['src']
  $srcLines = $Ctx['srcLines']
  $stDefIdx = $Ctx['stDefIdx']
  $stEndIdx = $Ctx['stEndIdx']
  $wA = $Ctx['wA']
  # ---------- unit: v1.5.2 WP-7 shot cleanup plan (audit R-14) ----------
  # Selection is pure geometry over (Name, LastWriteTime, Length) so it can be
  # pinned without moving anything. Synthetic file objects, deterministic times.
  function ST-MkShot([string]$name, [int]$minutesAgo, [long]$len) {
    return [pscustomobject]@{ Name = $name; LastWriteTime = (Get-Date '2026-01-01T12:00:00').AddMinutes(-$minutesAgo); LastWriteTimeUtc = (Get-Date '2026-01-01T12:00:00').AddMinutes(-$minutesAgo); Length = $len; FullName = "X:\shots\$name" }
  }
  $shotSet = @(
    (ST-MkShot 'new.png' 1 100), (ST-MkShot 'new.png.map.txt' 1 20),
    (ST-MkShot 'mid.png' 5 100), (ST-MkShot 'mid.png.map.txt' 5 20),
    (ST-MkShot 'old.png' 9 100), (ST-MkShot 'old.png.map.txt' 9 20),
    (ST-MkShot 'orphan.png.map.txt' 30 20)
  )
  $plan2 = Get-ShotCleanupPlan $shotSet 2
  $plan2Move = @($plan2.Move | ForEach-Object { $_.Name })
  ST-Check 'unit: shot plan keeps the newest N images' (
    @($plan2.Move | Where-Object { $_.Name -ceq 'new.png' -or $_.Name -ceq 'mid.png' }).Count -eq 0)
  ST-Check 'unit: shot plan moves the older image and its own sidecar together' (
    $plan2Move -contains 'old.png' -and $plan2Move -contains 'old.png.map.txt')
  ST-Check 'unit: shot plan moves an orphan sidecar whose image is gone' ($plan2Move -contains 'orphan.png.map.txt')
  ST-Check 'unit: shot plan leaves a sidecar whose image stayed' (
    -not ($plan2Move -contains 'new.png.map.txt') -and -not ($plan2Move -contains 'mid.png.map.txt'))
  # moved bytes = old.png (100) + its sidecar (20) + the orphan sidecar (20)
  ST-Check 'unit: shot plan byte total covers exactly the moved files' ($plan2.Bytes -eq 140)
  $plan0 = Get-ShotCleanupPlan $shotSet 0
  ST-Check 'unit: --keep 0 moves every image (and every sidecar)' (@($plan0.Move).Count -eq $shotSet.Count -and @($plan0.Keep).Count -eq 0)
  # an orphan sidecar goes even when everything else stays: its image is gone, so
  # leaving it behind only invites imgclick to point at a moved file
  $planAll = Get-ShotCleanupPlan $shotSet 99
  ST-Check 'unit: keep larger than the set still moves only the orphan sidecar' (
    @($planAll.Move).Count -eq 1 -and @($planAll.Move)[0].Name -ceq 'orphan.png.map.txt')
  # v4.4.0 (A-19): the dry-run sentence lives in the lifted handler now, so the text read is the command's
  #    own code wherever it sits - a case-span-only read would grade a three-line stub and call it a pass.
  $scBody = Get-CommandCodeText $codeLines 'shots-cleanup'
  ST-Check 'lint: shots-cleanup dry-run lists every moved file or states the hidden count explicitly' (
    $scBody.Contains('$shown -lt 12') -and $scBody.Contains('... and $($plan.Move.Count - $shown) more') -and
    $scBody.Contains('if ($plan.Move.Count -gt $shown)'))
  Write-Output "      shot plan: keep=$(@($plan2.Keep).Count) move=$(@($plan2.Move).Count) bytes=$($plan2.Bytes)"

  # ---------- unit: v2.5.3 shots-cleanup quarantine resolution (flag > env > User reg > Machine reg) ----------
  # Every precedence tier is pinned with INJECTED probe values, so the tests never
  # touch the real registry and the branch taken never depends on how this process was
  # launched or on what the machine has configured. Equality is all the assertions ever
  # see - no probe value is ever printed. The live all-empty refusal is NOT tested
  # here: making every source empty for real would mean deleting the User-scope
  # registry value, which a selftest must never do - it is verified once, manually,
  # outside this run (backup -> test -> try/finally restore -> readback).
  $rFlag = Resolve-ShotsCleanupQuarantine 'Q-flag' 'Q-env' 'Q-user' 'Q-machine'
  ST-Check 'unit: shots-cleanup quarantine resolver prefers an explicit --quarantine over every fallback' (
    ("$($rFlag.Dir)" -ceq 'Q-flag') -and ("$($rFlag.Source)" -ceq 'flag'))
  $rEnv = Resolve-ShotsCleanupQuarantine '' 'Q-env' 'Q-user' 'Q-machine'
  ST-Check 'unit: shots-cleanup quarantine resolver prefers the process environment over both registry scopes' (
    ("$($rEnv.Dir)" -ceq 'Q-env') -and ("$($rEnv.Source)" -ceq 'env'))
  $rUser = Resolve-ShotsCleanupQuarantine '' '' 'Q-user' 'Q-machine'
  ST-Check 'unit: shots-cleanup quarantine resolver prefers the User-scope registry over Machine' (
    ("$($rUser.Dir)" -ceq 'Q-user') -and ("$($rUser.Source)" -ceq 'user'))
  $rMachine = Resolve-ShotsCleanupQuarantine '' '' '' 'Q-machine'
  ST-Check 'unit: shots-cleanup quarantine resolver falls back to Machine scope when nothing above is set' (
    ("$($rMachine.Dir)" -ceq 'Q-machine') -and ("$($rMachine.Source)" -ceq 'machine'))
  $rNone = Resolve-ShotsCleanupQuarantine '' '' '' ''
  ST-Check 'unit: shots-cleanup quarantine resolver yields no target when every probe is empty (live all-empty refusal is verified manually, never here)' (
    ($null -eq $rNone.Dir) -and ($null -eq $rNone.Source))
  # Live wiring, fixture = this machine's real current state: the process env block
  # here predates the User-scope value (resident hosts keep the env they were born
  # with), so the resolver must reach DOWN to the registry fallback. Equality-only
  # assertion - the value itself is never printed. Skips with a reason on a machine
  # where the fixture does not hold (env carries the variable, or no User value).
  $rLive = Resolve-ShotsCleanupQuarantine ''
  $uLive = [Environment]::GetEnvironmentVariable('DTX_QUARANTINE', 'User')
  if (([string]::IsNullOrEmpty("$($env:DTX_QUARANTINE)")) -and (-not [string]::IsNullOrEmpty("$uLive"))) {
    ST-Check 'unit: shots-cleanup quarantine resolver live run reaches the registry fallback when the env block predates the User value (fixture = this machine)' (
      ("$($rLive.Dir)" -ceq "$uLive") -and ("$($rLive.Source)" -ceq 'user') -and (-not [string]::IsNullOrEmpty("$($rLive.Dir)")))
  } else {
    ST-Skip 'unit: shots-cleanup quarantine resolver live run reaches the registry fallback when the env block predates the User value (fixture = this machine)' 'fixture absent here (process env carries the variable, or no User-scope value) - precedence itself is pinned by the injected-probe checks above'
  }

  # ---------- lint+unit: v1.5.2 WP-1 step assembly purity (audit R-01, HIGH) ----------
  # A step whose value serializes to exactly ONE token used to come back from
  # ConvertTo-StepArgs as a String (PS 5.1 unwraps a 1-element array return). The
  # old assembly then did `$tokens + @('--expect', ...)`, which on a String is
  # STRING CONCATENATION: {"type":["ABC"],"expectText":"ABC"} typed
  # 'ABC--expect ABC--timeout 6' into the target window and echoed ok, exit 0.
  # Two nails: the serializer's return form, and the assembled token list itself.
  $stepFnStart = -1
  for ($i = 0; $i -lt $codeLines.Count; $i++) { if ($codeLines[$i] -match '^function ConvertTo-StepArgs') { $stepFnStart = $i; break } }
  $stepFnText = ''
  if ($stepFnStart -ge 0) {
    for ($i = $stepFnStart; $i -lt $codeLines.Count; $i++) {
      $stepFnText += $codeLines[$i] + "`n"
      if ($i -gt $stepFnStart -and $codeLines[$i] -eq '}') { break }
    }
  }
  # Unanchored on purpose: most of these returns sit inline (`if (...) { return ,@(...) }`),
  # so a ^\s*return pattern silently counts only the standalone ones - a first
  # attempt anchored that way saw 10 of 25 and would have gated nothing.
  $bareReturns = ([regex]::Matches($stepFnText, 'return\s+@\(')).Count
  $commaReturns = ([regex]::Matches($stepFnText, 'return\s+,')).Count
  ST-Check 'lint: step serializer located in source (scan itself works)' ($stepFnStart -ge 0 -and $commaReturns -ge 25)
  ST-Check 'lint: ConvertTo-StepArgs has no bare return @() (single-token steps must stay arrays)' ($bareReturns -eq 0)
  Write-Output "      step serializer returns: comma=$commaReturns bare=$bareReturns"
  # positive control: the bare-return probe must not be vacuous
  ST-Check 'lint: planted bare return @() IS detected by the bare-return probe' (
    ([regex]::Matches("    if (`$x) { return @('one') }", 'return\s+@\(')).Count -eq 1)
  # negative control: the fix form must not be flagged
  ST-Check 'lint: comma-wrapped return is NOT flagged by the bare-return probe' (
    ([regex]::Matches("    if (`$x) { return ,@('one') }", 'return\s+@\(')).Count -eq 0)

  # assembly-level unit tests: the exact shape that regressed, and the control
  # shape that always worked (multi-token). Payload token must stay byte-exact and
  # every flag must arrive as its own bare token.
  $stStep = [pscustomobject]@{ expectText = 'EXP1'; timeoutSec = 6 }
  $tType = Get-StepTokens 'type' @('ABC') $stStep
  ST-Check 'unit: single-token type step stays an array' ($tType -is [System.Array] -and @($tType).Count -eq 5)
  ST-Check 'unit: type payload token is exactly the payload' ($tType[0] -ceq 'ABC')
  ST-Check 'unit: expect flags are separate tokens in order' (
    $tType[1] -ceq '--expect' -and $tType[2] -ceq 'EXP1' -and $tType[3] -ceq '--timeout' -and $tType[4] -ceq '6')
  $tBareType = Get-StepTokens 'type' @('ABC') $null
  ST-Check 'unit: type step without expect is exactly one token' ($tBareType.Count -eq 1 -and $tBareType[0] -ceq 'ABC')
  $tClick = Get-StepTokens 'click' @(500, 600) $stStep
  ST-Check 'unit: multi-token click step unaffected by the fix (control)' (
    @($tClick).Count -eq 6 -and $tClick[0] -ceq '500' -and $tClick[1] -ceq '600' -and $tClick[2] -ceq '--expect')
  $stepFlagNames = @('--expect', '--expect-gone', '--expect-region', '--timeout', '--interval')
  foreach ($tc in @(
    [pscustomobject]@{ cmd = 'paste'; val = 'C:\tmp\qxa.txt' },
    [pscustomobject]@{ cmd = 'paste-file'; val = 'C:\tmp\qxa.txt' },
    [pscustomobject]@{ cmd = 'keys'; val = '{ENTER}' },
    [pscustomobject]@{ cmd = 'type'; val = 'QXSTRINGFORM' })) {
    $tk = Get-StepTokens $tc.cmd $tc.val $stStep
    $glued = @($tk | Where-Object { $_ -like '--*' -and $stepFlagNames -notcontains $_ })
    $hasFlags = (@($tk | Where-Object { $_ -ceq '--expect' }).Count -eq 1)
    ST-Check ("unit: " + $tc.cmd + " string-value step keeps payload clean and flags bare") (
      $tk -is [System.Array] -and $tk[0] -ceq $tc.val -and $glued.Count -eq 0 -and $hasFlags)
  }

  # ---------- unit: the exact return-shape semantics the lint defends ----------
  $lines = New-Object System.Collections.ArrayList
  foreach ($t in 'Switch#show mac-address-table', 'FastEthernet0/1', 'Vlan Mac Address Type Ports') {
    [void]$lines.Add([pscustomobject]@{ Text = $t; X = 10; Y = 20; W = 100; H = 14 })
  }

  $h0 = Find-OcrHits $lines 'zzz-not-present'
  ST-Check 'unit: 0 hits -> Count 0' ($h0.Count -eq 0)
  ST-Check 'unit: 0 hits is still an ArrayList (not $null)' ($h0 -is [System.Collections.ArrayList])

  $h1 = Find-OcrHits $lines 'FastEthernet0/1'
  ST-Check 'unit: 1 hit -> Count 1' ($h1.Count -eq 1)
  ST-Check 'unit: 1 hit -> [0].Text is the line, not a nested list' ($h1[0].Text -eq 'FastEthernet0/1')

  $h3 = Find-OcrHits $lines 'a'
  ST-Check 'unit: multi hit -> Count 3' ($h3.Count -eq 3)
  ST-Check 'unit: hits are case-insensitive' ((Find-OcrHits $lines 'MAC-ADDRESS').Count -eq 1)
  # The trap only bites when the true count is NOT 1, and the dangerous case is
  # 0: @() turns "nothing found" into Count 1, so `if ($hits.Count -eq 0)` never
  # fires and a failed lookup is silently read as a hit.
  $wrapped0 = @(Find-OcrHits $lines 'zzz-not-present')  # SELFTEST-EXEMPT deliberate
  ST-Check 'unit: @() breaks the 0-hit case (why the lint exists)' (
    $wrapped0.Count -ne $h0.Count -and $h0.Count -eq 0)

  # ---------- unit: v1.5.2 WP-2 replay flag parsing + redaction refusal ----------
  # audit R-02/R-03: unknown --flags were ignored (README documented a --from that
  # never existed, so `replay --from X --go` queued the WHOLE log), and a replayed
  # '<redacted:Nchars>' line typed its own placeholder into the target window.
  # These two are pure functions precisely because Invoke-ReplayLog exits by design.
  $rf3 = Split-ReplayFlags @('--last', '3', '--go')
  ST-Check 'unit: replay --last/--go parsed' ($rf3.Last -eq 3 -and $rf3.Go -eq $true -and $rf3.Grep -eq '')
  $rf1 = Split-ReplayFlags @('--go')
  ST-Check 'unit: replay single flag token (no default last) parses to a hashtable' ($rf1.Last -eq 0 -and $rf1.Go -eq $true)
  $rfPos = Split-ReplayFlags @('C:\tmp\other.log', '--grep', 'needle')
  ST-Check 'unit: replay positional log path + --grep' ($rfPos.LogPath -eq 'C:\tmp\other.log' -and $rfPos.Grep -eq 'needle' -and $rfPos.Go -eq $false)
  ST-Check 'unit: replay defaults to the built-in actions.log path' ((Split-ReplayFlags @()).LogPath -eq $ActionLog)
  $rfErr = ''
  try { [void](Split-ReplayFlags @('--from', '2026-01-01', '--go')) } catch { $rfErr = $_.Exception.Message }
  ST-Check 'unit: replay rejects an unknown flag instead of ignoring it' (
    $rfErr -like "unknown flag*" -or $rfErr -like "*unknown flag '--from'*")
  Write-Output "      replay unknown-flag message: $rfErr"
  $rfErr2 = ''
  try { [void](Split-ReplayFlags @('--last')) } catch { $rfErr2 = $_.Exception.Message }
  ST-Check 'unit: replay --last without a value throws' ($rfErr2 -like 'replay: --last needs a count*')
  $rd1 = Test-ReplayStepRedacted @('--to', 'X', '<redacted:9chars>')
  ST-Check 'unit: replay refuses a step carrying a redacted payload' ($rd1.Refused -eq $true -and $rd1.Placeholders.Count -eq 1)
  # the WP-1 family trap, tested again on this helper: a ONE-token args list must
  # behave exactly like a multi-token one (no array unwrap, no silent pass-through)
  $rdSingle = Test-ReplayStepRedacted @('<redacted:12chars>')
  ST-Check 'unit: single-token redacted args still refused (unwrap control)' (
    $rdSingle.Refused -eq $true -and @($rdSingle.Placeholders).Count -eq 1)
  $rdClean = Test-ReplayStepRedacted @('500', '600', '--to', 'Notepad')
  ST-Check 'unit: clean args are not refused' ($rdClean.Refused -eq $false -and $rdClean.Placeholders.Count -eq 0)

  # v4.4.0 (A-14d): this family's body now lives in lib/selftest-clipboard-input.ps1; the call sits at
  # the position its first block had, and the state it needs arrives only through $Ctx.
  # ---------- unit: JSON array unwrapping (same @() trap, pipeline form) ------
  $jarr = '[{"click":[1,2]},{"sleep":5}]'
  $badIdiom = @($jarr | ConvertFrom-Json)
  $goodRaw = $jarr | ConvertFrom-Json
  $goodIdiom = @($goodRaw)
  # v4.1.3 (external review C): this asserted "$badIdiom.Count -eq 1" unconditionally, but
  # that is not a language fact, it is a Windows PowerShell 5.1 fact - 5.1 folds a JSON
  # array into ONE object while PowerShell 7 unrolls it (measured on this box: 1 vs 2). The
  # check was therefore red on every machine that ran the other engine, and the repo does
  # run on both. Both halves are pinned now: the folding value per engine (an unknown
  # engine is a failure, not a free pass), and the loader shape that holds on either.
  $jEngine = 'other'
  if ($PSVersionTable.PSVersion.Major -eq 5) { $jEngine = '5.1' }
  elseif ($PSVersionTable.PSVersion.Major -ge 7) { $jEngine = 'pwsh7' }
  $jBadExpect = -1
  if ($jEngine -eq '5.1') { $jBadExpect = 1 }
  elseif ($jEngine -eq 'pwsh7') { $jBadExpect = 2 }
  ST-Check 'unit: JSON array needs assign-then-@() (script loader)' (
    $jBadExpect -gt 0 -and $badIdiom.Count -eq $jBadExpect)
  ST-Check 'unit: the assign-then-@() loader shape yields every element on either engine (the engine-independent half)' (
    $goodIdiom.Count -eq 2 -and @($goodIdiom[0].click).Count -eq 2)
  Write-Output ('      json unwrap: engine=' + $jEngine + ' @()-over-pipeline=' + $badIdiom.Count +
    ' assign-then-@()=' + $goodIdiom.Count + ' expected-fold=' + $jBadExpect)

  # ---------- unit: pure helpers ----------
  $rgb = Convert-HexToRgb '#00FF80'
  ST-Check 'unit: Convert-HexToRgb' ($rgb.R -eq 0 -and $rgb.G -eq 255 -and $rgb.B -eq 128)
  $badRgb = $true
  try { $null = Convert-HexToRgb 'nope' } catch { $badRgb = $false }
  ST-Check 'unit: Convert-HexToRgb rejects garbage' (-not $badRgb)

  $r4 = Resolve-Region @('12', '34', '56', '78') 0
  ST-Check 'unit: Resolve-Region integer quad' ($r4.X -eq 12 -and $r4.Y -eq 34 -and $r4.W -eq 56 -and $r4.H -eq 78)
  ST-Check 'unit: Region-WordCount quad = 4' ((Region-WordCount @('1', '2', '3', '4') 0) -eq 4)
  ST-Check 'unit: Region-WordCount selector = 1' ((Region-WordCount @('notepad') 0) -eq 1)

  $pf = Parse-CaptureFlags @('--fit', '1200', '--grid', '80', '--mark', '10,20', 'win') $false
  ST-Check 'unit: Parse-CaptureFlags fit/grid/mark' (
    $pf.Fit -eq 1200 -and $pf.Grid -eq 80 -and $pf.Marks.Count -eq 1 -and $pf.Rest.Count -eq 1 -and $pf.Rest[0] -eq 'win')
  ST-Check 'unit: rect default fit is 900' ((Parse-CaptureFlags @() $true).Fit -eq 900)
  ST-Check 'unit: win/shot default fit is 0 (full res)' ((Parse-CaptureFlags @() $false).Fit -eq 0)
  $badMark = $true
  try { $null = Parse-CaptureFlags @('--mark', '10') $false } catch { $badMark = $false }
  ST-Check 'unit: --mark without y throws' (-not $badMark)

  # ---------- call arity: a dead argument is a claim about behaviour that is not true ----------
  # Units first, because the scan below is only as honest as this counter.
  ST-Check 'unit: Get-CallArgCount counts three positional args and stops at the enclosing brace' (
    (Get-CallArgCount '([string]$bp) $false $false } else { $null })') -eq 3)
  ST-Check 'unit: Get-CallArgCount keeps a bracketed index inside one argument' (
    (Get-CallArgCount '$Rest[0]') -eq 1)
  ST-Check 'unit: Get-CallArgCount is not ended by a semicolon that lives inside a quoted literal' (
    (Get-CallArgCount "'a; b' $false") -eq 2)
  ST-Check 'unit: Get-CallArgCount returns a plain integer (a list return would re-open the single-element unwrapping trap)' (
    (Get-CallArgCount "'Chrome'").GetType().Name -eq 'Int32')
  ST-Check 'unit: Get-CallArgCount on an empty tail is 0' ((Get-CallArgCount '') -eq 0)
  ST-Check 'unit: Get-CallArgCount ignores a space that lives inside a parenthesised cast' (
    (Get-CallArgCount '([string] $bp)') -eq 1)
  $scMark = ('Resolve-' + 'Window ')
  $scTitle = "ST-Check 'unit: Resolve-Window by pid selects a window' (`$null -ne `$rw)"
  $scCall = "  `$w = Resolve-Window 'Chrome' `$false `$false"
  ST-Check 'unit: Get-CodeTailAfterMark skips a mark that only appears inside a quoted assertion title' (
    $null -eq (Get-CodeTailAfterMark $scTitle $scMark))
  ST-Check 'unit: Get-CodeTailAfterMark returns the code tail of a real call, quote-aware from the first character' (
    (Get-CodeTailAfterMark $scCall $scMark) -eq "'Chrome' `$false `$false")
  ST-Check 'unit: the tail of a real call counts 3 arguments while the assertion title counts none' (
    (Get-CallArgCount (Get-CodeTailAfterMark $scCall $scMark)) -eq 3)
  # Declared arity is READ from the definition, never hand-copied, so giving the
  # function a real second parameter later cannot silently make this check lie.
  $arDeclMark = ('function Resolve-' + 'Window(')
  $arCallMark = ('Resolve-' + 'Window ')
  $arArity = -1
  for ($ari = 0; $ari -lt $codeLines.Count; $ari++) {
    if ($codeLines[$ari].StartsWith($arDeclMark)) {
      $arRest = $codeLines[$ari].Substring($arDeclMark.Length)
      $arClose = $arRest.IndexOf(')')
      if ($arClose -lt 0) { break }
      $arParams = @($arRest.Substring(0, $arClose) -split ',' | Where-Object { $_ -match '\$\w' })
      $arArity = @($arParams).Count
      break
    }
  }
  $arSites = 0
  $arOverList = @()
  for ($ari = 0; $ari -lt $codeLines.Count; $ari++) {
    $arl = $codeLines[$ari]
    if ($arl -match '^\s*#') { continue }
    if ($arl.StartsWith($arDeclMark)) { continue }
    $arTail = Get-CodeTailAfterMark $arl $arCallMark
    if ($null -eq $arTail) { continue }
    $arSites++
    $arGot = Get-CallArgCount $arTail
    if ($arGot -gt $arArity) { $arOverList += ('line ' + (Format-SourceLineRef ($ari + 1)) + '(passes ' + $arGot + ')') }
  }
  $arOver = @($arOverList).Count
  ST-Check 'lint: no Resolve-Window call site passes arguments the function does not declare (PowerShell files extras in $args silently, so a dead flag reads as suppressed behaviour and no gate sees it)' (
    ($arArity -eq 1) -and ($arSites -ge 30) -and ($arOver -eq 0))
  Write-Output ("      arity scan: declared=" + $arArity + " call-sites=" + $arSites + " over-arity=" + $arOver + $(if ($arOver -gt 0) { ' [' + ($arOverList -join ', ') + ']' } else { '' }))

  # ---------- lint: every Test-* guard is called WITH the arguments it declares ----------
  # The scan above covers one function. Audit item #1 was the same shape somewhere else:
  # `if ((Test-NameSubstring  ))` - compiles fine, passes nothing, the guard answers for a
  # $null subject, and the uia-settext name route it guarded had been dead since v2.0.0
  # while looking like a tool that could not find elements. Missing parameters bind to
  # $null and surplus ones land in $args, so PowerShell never complains in either
  # direction. Arity is READ from each definition line, not hand-copied.
  $gvDefs = @{}
  for ($gvi = 0; $gvi -lt $codeLines.Count; $gvi++) {
    if ($gvi -ge $j5ProdStart -and $gvi -lt $j5ProdEnd) { continue }
    $gvm = [regex]::Match([string]$codeLines[$gvi], '^function (Test-[A-Za-z0-9]+)\(([^)]*)\)')
    if (-not $gvm.Success) { continue }
    $gvParams = @($gvm.Groups[2].Value -split ',' | Where-Object { $_ -match '\$\w' })
    if (@($gvParams).Count -lt 1) { continue }
    $gvDefs[[string]$gvm.Groups[1].Value] = @{ Min = @($gvParams | Where-Object { $_ -notmatch '=' }).Count; Max = @($gvParams).Count }
  }
  $gvBad = New-Object System.Collections.ArrayList
  $gvSeen = 0
  foreach ($gvPair in $gvDefs.GetEnumerator()) {
    $gvName = [string]$gvPair.Key
    $gvMark = $gvName + ' '
    for ($gvi = 0; $gvi -lt $codeLines.Count; $gvi++) {
      if ($gvi -ge $j5ProdStart -and $gvi -lt $j5ProdEnd) { continue }
      $gvL = [string]$codeLines[$gvi]
      if ($gvL -match '^\s*#') { continue }
      if ($gvL.StartsWith('function ' + $gvName + '(')) { continue }
      $gvTail = Get-CodeTailAfterMark $gvL $gvMark
      if ($null -eq $gvTail) { continue }
      $gvSeen++
      # Only a tail whose brackets are STILL OPEN belongs to a later line (a call that
      # passes a multi-line hashtable literal). A tail like '$a $b)) {' is complete -
      # Get-CallArgCount stops at the caller's own ')' - and must be counted, because the
      # shape this scan exists to catch is precisely a tail with nothing in it. Measured
      # here: an "ends with a brace" heuristic skipped every if ((Guard ...)) call, which
      # is every guard call in the dispatcher, and the scan stayed green on the bug.
      $gvOpen = [regex]::Matches($gvTail, '[({\[]').Count
      $gvClose = [regex]::Matches($gvTail, '[)}\]]').Count
      if ($gvOpen -gt $gvClose) { continue }
      $gvGot = Get-CallArgCount $gvTail
      if ($gvGot -lt [int]$gvPair.Value.Min -or $gvGot -gt [int]$gvPair.Value.Max) {
        [void]$gvBad.Add("$gvName line $(Format-SourceLineRef ($gvi + 1)): $gvGot argument(s), declared $($gvPair.Value.Min)..$($gvPair.Value.Max)")
      }
    }
  }
  ST-Check 'lint: every Test-* guard is called with its declared argument count (a missing one binds to $null and answers for nothing, silently)' (
    ($gvDefs.Count -ge 15) -and ($gvSeen -ge 40) -and (@($gvBad).Count -eq 0))
  foreach ($gvB in @($gvBad)) { Write-Output "      arity miss: $gvB" }
  # .Count on the hashtable, NOT @($hashtable).Count: wrapping a hashtable in @() yields
  # ONE object, so the size assertion could never have failed (measured here: functions=1
  # while 26 were in the table). A gate that cannot read its own subject is not a gate.
  Write-Output ("      guard arity scan: functions=" + $gvDefs.Count + " call-sites=" + $gvSeen + " mismatches=" + @($gvBad).Count)

  # ---------- tab manifest reconciliation (owner ruling 2: restart self-verification) ----------
  $c34Mk = { param($nm, $x) [pscustomobject]@{ Name = $nm; X = $x; Y = 20; W = 300; H = 40 } }
  $c34B = @((Format-TabManifestLine 1 (& $c34Mk 'Alpha' 10)), (Format-TabManifestLine 2 (& $c34Mk 'Beta' 80)), (Format-TabManifestLine 3 (& $c34Mk 'Gamma' 150)), (Format-TabManifestLine 4 (& $c34Mk 'Delta' 220)), (Format-TabManifestLine 5 (& $c34Mk 'Eps' 290)))
  $c34Same = Compare-TabManifest $c34B $c34B
  ST-Check 'unit: Compare-TabManifest five identical rows reconcile as Same' ($c34Same.Ok -and ($c34Same.Reason -eq 'Same'))
  $c34MissAfter = @($c34B[0], $c34B[1], $c34B[2], $c34B[3])
  $c34Miss = Compare-TabManifest $c34B $c34MissAfter
  ST-Check 'unit: Compare-TabManifest reports WHICH tab went missing, not just a count' (
    (-not $c34Miss.Ok) -and $c34Miss.Reason.Contains('count drift: before=5 after=4') -and $c34Miss.Reason.Contains('missing: [Eps]'))
  $c34SwapAfter = @($c34B[0], $c34B[2], $c34B[1], $c34B[3], $c34B[4])
  $c34Swap = Compare-TabManifest $c34B $c34SwapAfter
  ST-Check 'unit: Compare-TabManifest reports an order drift with both titles when tabs swap, not only a count' (
    (-not $c34Swap.Ok) -and $c34Swap.Reason.Contains("order/content drift at position 2: before='Beta' after='Gamma'"))
  $c34PipeRow = & $c34Mk 'A|B' 10
  $c34PipeB = @((Format-TabManifestLine 1 $c34PipeRow))
  $c34PipeParse = Parse-TabManifestLine $c34PipeB[0]
  ST-Check 'unit: a tab title containing | round-trips losslessly through the manifest line (right-anchored parse, no escape table to drift)' (
    ($c34PipeB[0] -eq '1|A|B|10,20,300x40') -and ($c34PipeParse.Name -eq 'A|B') -and ($c34PipeParse.Rect -eq '10,20,300x40') -and (Compare-TabManifest $c34PipeB $c34PipeB).Ok)
  # v4.4.0 (A-15): the chrome-a11y promises are counted over the command's code, so a wrap cannot
  # make the echo or the restart disappear from the scanner's view. $c35Start keeps its meaning (the
  # case line, or -1 when the command is not dispatched) because a later clause tests it.
  $c35Ranges = @(Get-CommandCodeRanges $codeLines 'chrome-a11y')
  $c35Start = $(if (@($c35Ranges).Count -gt 0) { [int]@($c35Ranges)[0][0] } else { -1 })
  $c35Lines = @()
  foreach ($c35Rg in $c35Ranges) { for ($c35i = [int]$c35Rg[0]; $c35i -le [int]$c35Rg[1]; $c35i++) { $c35Lines += [string]$codeLines[$c35i] } }
  $c35Cmp = @($c35Lines | Where-Object { $_.Contains('Compare-TabManifest') }).Count
  $c35Echo = @($c35Lines | Where-Object { $_.Contains('tab-manifest=') }).Count
  $c35Restart = @($c35Lines | Where-Object { $_.Contains('Restart-ChromeWithFlags') }).Count
  ST-Check 'lint: chrome-a11y writes the manifest before, reconciles after, restarts exactly once (a mismatch throws - it never restarts a second time)' (
    ($c35Start -ge 0) -and ($c35Cmp -eq 1) -and ($c35Echo -eq 2) -and ($c35Restart -eq 1))
  $c35BomN = 0
  for ($c35i = 0; $c35i -lt $codeLines.Count; $c35i++) {
    if ($c35i -ge $j5ProdStart -and $c35i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c35i] -match '^\s*#') { continue }
    if ($codeLines[$c35i].Contains(('System.Text.UTF8' + 'Encoding($true)'))) { $c35BomN++ }
  }
  ST-Check 'lint: the manifest writer is a UTF-8 BOM writer (the GBK console would corrupt the reconciliation data itself)' ($c35BomN -eq 1)
  Write-Output ("      tab manifest: cmp=$c35Cmp echoes=$c35Echo restart-in-body=$c35Restart bom-writers=$c35BomN")

  # v4.4.0 (A-14o): family drag-press now lives in lib/selftest-drag-press.ps1; the call sits at the
  # position its first run had and its second run moved up to join it (this family is the drag/press
  # set). It reads the dispatcher case table hoisted in the same card - gaCases/gaCaseIdx arrive
  # published, not as caller locals - and it hands nothing back.
  # v4.4.0 (A-14g): family challenge-workflow now lives in lib/selftest-challenge-workflow.ps1;
  # the call sits at the position its first block had, and its second block moved up to join it.
  # v4.4.0 (A-14p): family live-suite now lives in lib/selftest-live-suite.ps1. This is the MODE family,
  # and it is ONE cut: 20 banners are claimed here but only one of them delimits a run, so the other 19
  # ride inside the block below - cutting per banner would have lifted the middle of the if ($live) block
  # out of that block. The call sits at the position the run had, so the live ladder still runs where it
  # always ran. It needs the audit path, the capture folder, the mode flag and the window snapshot, all
  # published above, and it hands nothing back.

  # ---------- F-00-A: a guard promise made in a comment or in the help text must find its ----------
  # promised wiring inside the very dispatcher case body that makes the promise.
  # P-01 lived under 770 green checks because "Guards like click." in drag's comment (and the
  # same promise in the help page) was prose: click resolves + content-guards + runs the
  # landing check, drag only did the first two. This lint reads the promise out of the
  # comment/help line, locates the promising command's own case body, and counts the promised
  # guard helper's calls there; count 0 is red and names the promise line, the helper and the
  # count. Scan region: every line outside the selftest body (the j5 bounds above) - comment
  # lines anywhere, plus every line of the Get-UsageText help text (a promise in prose is
  # still a promise). Promise forms (case-insensitive), and the wiring each one promises:
  #   "guards and hit-window like <cmd>"  -> Invoke-ContentGuard + Invoke-HitWindowCheck
  #   "guards + landing check like <cmd>" -> Invoke-ContentGuard + Invoke-HitWindowCheck
  #   "guards like <cmd>"                 -> every guard helper the promised case's own body has
  #   "same default-on readback as <cmd>" -> Invoke-AutoPasteExpect
  $gaHelpers = @('Resolve-Target', 'Invoke-ContentGuard', 'Invoke-HitWindowCheck', 'Invoke-AutoPasteExpect')
  # The help page lives inside the usage here-string, and $codeLines deliberately blanks
  # here-string content - so promise matching inside the help region reads the RAW source
  # lines ($gaRaw, same length, same indexes). Comment promises elsewhere keep reading
  # $codeLines: a '#' line that is really here-string data must not count as a comment.
  $gaRaw = @($src -split "`r?`n")
  # v4.4.0 (A-14o): the dispatcher case table below (bounds, $gaCases, $gaCaseIdx) moved up into this
  # section's setup and is published to lifted families through the context object - drag-press reads
  # two of these names, and a lifted body may only be handed published context. Same text, earlier.

  $gaCountIn = {
    param($ci, $helper)
    # v4.4.0 (A-15): a promised wiring can now sit in the command's handler instead of its case body,
    # so the count walks every range that belongs to the command. Counting the case alone would report
    # a guard as never wired exactly when nothing but its location changed - the failure this gate
    # exists to catch, turned against the move itself.
    $n = 0
    foreach ($gaRg in @(Get-CommandCodeRanges $codeLines ([string]$gaCases[$ci][0]))) {
      for ($gj = [int]$gaRg[0]; $gj -le [int]$gaRg[1]; $gj++) {
        if ($gj -ge $clCount) { continue }
        if ($codeLines[$gj] -match '^\s*#') { continue }
        if ($codeLines[$gj].Contains($helper)) { $n++ }
      }
    }
    return $n
  }
  $gaBodyHelpers = {
    param($ci)
    $got = @()
    foreach ($gh in $gaHelpers) { if ((& $gaCountIn $ci $gh) -gt 0) { $got += $gh } }
    return $got
  }
  # v4.4.0 (A-15 pen 2): the promise comment now sits inside the command's handler, so "which case made
  #    this promise" is answered from every range the command owns. Precomputed once - asking
  #    Get-CommandCodeRanges per promise line per case would turn a linear scan quadratic.
  $gaLineOwner = @{}
  for ($gk = 0; $gk -lt $gaCasesCount; $gk++) {
    foreach ($gaRg2 in @(Get-CommandCodeRanges $codeLines ([string]$gaCases[$gk][0]))) {
      for ($gj2 = [int]$gaRg2[0]; $gj2 -le [int]$gaRg2[1]; $gj2++) {
        if ($gj2 -ge $clCount) { continue }
        if (-not $gaLineOwner.ContainsKey($gj2)) { $gaLineOwner[$gj2] = $gk }
      }
    }
  }
  $gaRe = '(?i)(guards and hit-window like|guards \+ landing check like|same default-on readback as|guards like) ([a-z][a-z0-9-]*)'
  $gaPromises = @()
  for ($gai = 0; $gai -lt $codeLines.Count; $gai++) {
    if (($gai -ge $j5ProdStart) -and ($gai -lt $j5ProdEnd)) { continue }
    $gaLine = $codeLines[$gai]
    $gaIsComment = ($gaLine -match '^\s*#')
    $gaInHelp = (($gaHelpStart -ge 0) -and ($gai -ge $gaHelpStart) -and ($gai -lt $gaHelpEnd))
    if (-not $gaIsComment -and -not $gaInHelp) { continue }
    $gaProbe = if ($gaInHelp) { $gaRaw[$gai] } else { $gaLine }
    if (-not ($gaProbe -match $gaRe)) { continue }
    $gaKind = $Matches[1].ToLowerInvariant(); $gaPromised = $Matches[2].ToLowerInvariant()
    $gaHost = -1
    if ($gaInHelp) {
      for ($gj = $gai; $gj -ge $gaHelpStart; $gj--) {
        if ($gaRaw[$gj] -match '^    ([a-z][a-z0-9-]*)(\s|$)') { $gaHost = & $gaCaseIdx $Matches[1]; break }
      }
    } else {
      if ($gaLineOwner.ContainsKey($gai)) { $gaHost = [int]$gaLineOwner[$gai] }
    }
    $gaPromises += ,@(($gai + 1), $gaKind, $gaPromised, $gaHost)
  }
  $gaViolations = @(); $gaWired = 0
  foreach ($gp in $gaPromises) {
    $gaLineNo = $gp[0]; $gaKind = $gp[1]; $gaPromised = $gp[2]; $gaHost = $gp[3]
    $gaPromCase = & $gaCaseIdx $gaPromised
    $gaHostText = if ($gaHost -ge 0) { "case '" + $gaCases[$gaHost][0] + "'" } else { 'NO dispatcher case body' }
    if ($gaPromCase -lt 0) {
      $gaViolations += ("line " + (Format-SourceLineRef ([int]$gaLineNo)) + " (" + $gaKind + " " + $gaPromised + ", made in " + $gaHostText + "): promised command '" + $gaPromised + "' has no dispatcher case to compare against")
      continue
    }
    $gaWant = @()
    if (($gaKind -like 'guards and hit-window*') -or ($gaKind -like 'guards + landing*')) {
      $gaWant = @('Invoke-ContentGuard', 'Invoke-HitWindowCheck')
    } elseif ($gaKind -eq 'same default-on readback as') {
      $gaWant = @('Invoke-AutoPasteExpect')
    } else {
      $gaWant = @(& $gaBodyHelpers $gaPromCase)
      if (@($gaWant).Count -eq 0) {
        $gaViolations += ("line " + (Format-SourceLineRef ([int]$gaLineNo)) + " (" + $gaKind + " " + $gaPromised + ", made in " + $gaHostText + "): promised command '" + $gaPromised + "' itself has no guard helper in its case body, so the promise compares against nothing")
        continue
      }
    }
    $gaMissing = @()
    foreach ($gw in $gaWant) {
      $n = 0
      if ($gaHost -ge 0) { $n = & $gaCountIn $gaHost $gw }
      if ($n -le 0) { $gaMissing += ($gw + ' x0') }
    }
    if (($gaHost -lt 0) -or (@($gaMissing).Count -gt 0)) {
      $gaViolations += ("line " + (Format-SourceLineRef ([int]$gaLineNo)) + " (" + $gaKind + " " + $gaPromised + ", made in " + $gaHostText + "): promised helper(s) missing from the case body: " + (@($gaMissing) -join ', '))
    } else {
      $gaWired++
    }
  }
  ST-Check 'lint (F-00-A): every guard promise in a comment or help line finds its promised wiring inside the same dispatcher case body (violations name the promise line, the helper and the count)' (
    (@($gaViolations).Count -eq 0) -and ($gaDispStart -ge 0) -and ($gaHelpStart -ge 0) -and (@($gaCases).Count -ge 40) -and (@($gaRaw).Count -eq $codeLines.Count))
  if (@($gaViolations).Count -gt 0) { foreach ($gv in $gaViolations) { Write-Output ("      F-00-A: " + $gv) } }
  ST-Check 'lint (F-00-A): the promise forms keep live samples in the file (a lint whose input silently empties out can never fail again)' (
    @($gaPromises).Count -ge 4)
  if (@($gaPromises).Count -gt 0) { Write-Output ("      F-00-A: promise sites=" + @($gaPromises).Count + " wired=" + $gaWired + " (dispatcher cases=" + @($gaCases).Count + ")") }
  ST-Check 'lint (F-00-A): positive control non-zero - at least one promise site is wired and verified (an all-empty positive set means the lint never had teeth)' (
    $gaWired -ge 1)

  # ---------- lint: nothing in production is a PowerShell automatic variable ----------
  # Names are case-INsensitive, so a local called $matches is $Matches - the storage a
  # successful -match writes. The selector family carried eight accumulator assignments
  # plus a PARAMETER named $matches (audit #12); the only reason nothing broke is that no
  # branch read $Matches after one of those assignments. Either direction is a silent
  # data race between the engine and the code, so the name is banned outright.
  $autoList = @('matches', 'args', 'error', 'input', 'psitem', 'foreach', 'switch', 'host', 'profile', 'pwd', 'lastexitcode', '_', 'this', 'credential', 'executioncontext')
  $autoWrites = @()
  $autoParams = @()
  for ($avI = 0; $avI -lt $clCount; $avI++) {
    if ($avI -ge $j5ProdStart -and $avI -lt $j5ProdEnd) { continue }
    $avL = [string]$codeLines[$avI]
    if ($avL -match '^\s*#') { continue }
    $avWm = [regex]::Match($avL, '^\s*\$(\w+)\s*=[^=]')
    if ($avWm.Success -and ($autoList -contains $avWm.Groups[1].Value.ToLowerInvariant())) { $autoWrites += (($avI + 1).ToString() + ':' + $avWm.Groups[1].Value) }
    $avFn = [regex]::Match($avL, '^function [A-Za-z][^(]*\(([^)]*)\)')
    if ($avFn.Success) {
      foreach ($avP in ($avFn.Groups[1].Value -split ',')) {
        $avPm = [regex]::Match($avP, '\$(\w+)')
        if ($avPm.Success -and ($autoList -contains $avPm.Groups[1].Value.ToLowerInvariant())) { $autoParams += (($avI + 1).ToString() + ':' + $avPm.Groups[1].Value); break }
      }
    }
  }
  ST-Check 'lint: no production line assigns to, and no function parameter is named after, a PowerShell automatic variable (the names collide case-insensitively)' (
    (@($autoWrites).Count -eq 0) -and (@($autoParams).Count -eq 0))
  if (@($autoWrites).Count -gt 0) { Write-Output ('      automatic-variable assignments at: ' + (@($autoWrites) -join ', ')) }
  if (@($autoParams).Count -gt 0) { Write-Output ('      automatic-variable parameters at: ' + (@($autoParams) -join ', ')) }

  # ---------- v3.0.1 (audit #16/#17): one owner per constant, one voice per numeric flag ----------
  $constRules = @(
    @{ Fn = 'Get-UiaBigDepth'; Lit = 'Uia-WalkAll @($root) 40' },
    @{ Fn = 'Get-DwmVisibleFrameAttribute'; Lit = 'DwmGetWindowAttribute($h, 9,' },
    @{ Fn = 'Get-ShotViewerWidePx'; Lit = '$iw -gt 1000' }
  )
  $constBad = @()
  foreach ($cr in $constRules) {
    $crDefects = 0
    $crRaw = 0
    for ($crI = 0; $crI -lt $clCount; $crI++) {
      if ($crI -ge $j5ProdStart -and $crI -lt $j5ProdEnd) { continue }
      $crL = [string]$codeLines[$crI]
      if ($crL -match '^\s*#') { continue }
      if ($crL.StartsWith('function ' + $cr.Fn)) { $crDefects++; continue }
      if ($crL.Contains([string]$cr.Lit)) { $crRaw++ }
    }
    if ($crDefects -ne 1 -or $crRaw -ne 0) { $constBad += ($cr.Fn + ' defs=' + $crDefects + ' raw-sites=' + $crRaw) }
  }
  ST-Check 'lint: the numbers the 3.0.0 review found typed more than once now have exactly one owner and no raw site left (a constant that can disagree with itself decides what the tool reports)' (
    (@($constRules).Count -eq 3) -and (@($constBad).Count -eq 0))
  foreach ($cb in @($constBad)) { Write-Output "      constant ownership: $cb" }
  # The challenge-probe alphabet is the one exemption: it also lives inside two LIVE child
  # scripts, which are separate processes and cannot call back into this file (making the
  # parent interpolate them is the real fix and needs a --live round to prove). So the
  # copies are pinned to AGREE with the producer - drift is what actually hurts. The scan
  # reads the RAW source for once: the fixtures live in here-strings, which $codeLines
  # blanks, and it deliberately covers the selftest body because that is where they are.
  $alphaLit = [string]([char]65) + 'CDEFHJKLMNPRTUVWXY'
  $alphaLines = @()
  foreach ($alL in ($src -split "`r?`n")) { if (([string]$alL).Contains($alphaLit)) { $alphaLines += 1 } }
  ST-Check 'lint: every copy of the challenge probe alphabet equals the single producer (two live child fixtures cannot call back, so their drift is what this pins)' (
    (@($alphaLines).Count -eq 3) -and ((Get-ChallengeProbeAlphabet) -ceq $alphaLit))
  Write-Output ("      probe alphabet copies (producer + live fixtures): " + @($alphaLines).Count)
  # Flag values parsed out of a while-loop token list are the audit #17 family. Positional
  # arguments ($Rest[0], $Rest[1]...) are a SEPARATE family with its own gate -
  # Test-IntArgs refuses "argument #N must be a whole number of screen pixels" - so the
  # loop-index shape is what must never come back.
  $rawNumCast = @()
  for ($rNCi = 0; $rNCi -lt $clCount; $rNCi++) {
    if ($rNCi -ge $j5ProdStart -and $rNCi -lt $j5ProdEnd) { continue }
    $rnL = [string]$codeLines[$rNCi]
    if ($rnL -match '^\s*#') { continue }
    if ($rnL -match '\[(int|double)\]\$(words|Rest)\[\$i\]') { $rawNumCast += ($rNCi + 1) }
  }
  ST-Check 'lint: no flag value is cast straight out of the token loop (a bare [int] answers "abc" with a .NET binding error that names no flag)' (
    @($rawNumCast).Count -eq 0)
  if (@($rawNumCast).Count -gt 0) { Write-Output ("      raw numeric casts at line(s): $(Format-SourceLineList @($rawNumCast))") }
  $rfnInt = Read-FlagNumber '--x' '7' $true ''
  $rfnDbl = Read-FlagNumber '--x' '1.5' $false ''
  $rfnIntErr = ''
  try { [void](Read-FlagNumber '--max-tiles' 'abc' $true '(tiles per tiled OCR pass)') } catch { $rfnIntErr = $_.Exception.Message }
  $rfnFracErr = ''
  try { [void](Read-FlagNumber '--keep' '2.5' $true '(images to keep)') } catch { $rfnFracErr = $_.Exception.Message }
  $rfnComma = ''
  try { $rfnComma = Read-FlagNumber '--timeout' '1,5' $false '(seconds)' } catch { $rfnComma = 'THREW' }
  ST-Check 'unit: Read-FlagNumber names the flag on a non-number, refuses a fraction for an int flag, and pins the decimal point to invariant culture' (
    ($rfnInt -eq 7) -and ($rfnDbl -eq 1.5) -and ($rfnIntErr -like '--max-tiles needs a whole number*got: abc') -and
    ($rfnFracErr -like '--keep needs a whole number*') -and ($rfnComma -ceq 'THREW'))
  $rfnParserErr = ''
  try { [void](Split-Target @('10', '20', '--max-tiles', 'lots') 'click') } catch { $rfnParserErr = $_.Exception.Message }
  ST-Check 'unit: the flag parser answers a non-numeric --max-tiles with the flag name, not a .NET cast error (the audit #17 symptom end to end)' (
    ($rfnParserErr -like '--max-tiles needs a whole number*') -and ($rfnParserErr -like '*got: lots'))

  # ---------- v3.0.1 (audit #16 continued): the two copied BLOCKS, not just constants ----------
  # dialog-cancel carried the same 1500ms IsWindow polling loop twice (byte for byte), and
  # the occlusion flags were validated twice each with the error text copied along. A
  # duplicated decision is one that can half-change, so both shapes are now banned by
  # count - and each negative count is paired with a PLANTED sample, because "0 hits" from
  # a detector that cannot match anything is the shapeless green this project keeps hitting.
  $q = [string][char]39
  $occlListPat = $q + 'off' + $q + ', ' + $q + 'warn' + $q + ', ' + $q + 'strict' + $q
  $occlMsgPat = 'must be off|warn|strict, got'
  $occlListPlanted = "  if (`$v -notin @(" + $occlListPat + ')) { throw "x ' + $occlMsgPat + ': `$v" }'
  $occlListPlantedHits = ([regex]::Matches($occlListPlanted, [regex]::Escape($occlListPat))).Count
  $occlMsgPlantedHits = ([regex]::Matches($occlListPlanted, [regex]::Escape($occlMsgPat))).Count
  $prodCodeLines = New-Object System.Collections.ArrayList
  for ($pcI = 0; $pcI -lt $clCount; $pcI++) {
    if ($pcI -ge $j5ProdStart -and $pcI -lt $j5ProdEnd) { continue }
    if (([string]$codeLines[$pcI]) -match '^\s*#') { continue }
    [void]$prodCodeLines.Add([string]$codeLines[$pcI])
  }
  $prodCode = ($prodCodeLines -join "`n")
  $occlListFileHits = ([regex]::Matches($prodCode, [regex]::Escape($occlListPat))).Count
  $occlMsgFileHits = ([regex]::Matches($prodCode, [regex]::Escape($occlMsgPat))).Count
  $occlListOwner = Get-FunctionSlice 'Get-OcclusionModeValues' $codeLines
  $occlMsgOwner = Get-FunctionSlice 'Resolve-OccludeModeArg' $codeLines
  $occlListInOwner = ([regex]::Matches($occlListOwner.Text, [regex]::Escape($occlListPat))).Count
  $occlMsgInOwner = ([regex]::Matches($occlMsgOwner.Text, [regex]::Escape($occlMsgPat))).Count
  $waitLoopHits = ([regex]::Matches($prodCode, 'while \(\$waited -lt 1500\)')).Count
  $waitCalls = 0
  $patienceDefs = 0
  for ($wgI = 0; $wgI -lt $clCount; $wgI++) {
    if ($wgI -ge $j5ProdStart -and $wgI -lt $j5ProdEnd) { continue }
    $wgL = [string]$codeLines[$wgI]
    if ($wgL -match '^\s*#') { continue }
    if ($wgL.Contains('= Wait-WindowGone ')) { $waitCalls++ }
    if ($wgL.StartsWith('function Get-DialogCancelPatienceMs')) { $patienceDefs++ }
  }
  # Each claim is "ONE copy file-wide and it lives inside its owner" - not "zero", which a
  # refactor that centralises can never satisfy. Both counters are paired with a planted
  # sample, because a detector that matches nothing also reports a satisfying 0.
  ST-Check 'lint: dialog-cancel waits through one helper twice, and the occlusion value list plus its error text each live in exactly one function (every 0 has a planted 1 behind it)' (
    (($occlListPlantedHits -eq 1) -and ($occlMsgPlantedHits -eq 1)) -and
    (($occlListFileHits -eq 1) -and ($occlListInOwner -eq 1) -and ($occlListOwner.Found)) -and
    (($occlMsgFileHits -eq 1) -and ($occlMsgInOwner -eq 1) -and ($occlMsgOwner.Found)) -and
    ($waitLoopHits -eq 0) -and ($waitCalls -eq 2) -and ($patienceDefs -eq 1))
  Write-Output ("      copied-block scan: planted list/msg=" + $occlListPlantedHits + '/' + $occlMsgPlantedHits +
    " file list/msg=" + $occlListFileHits + '/' + $occlMsgFileHits + " in-owner=" + $occlListInOwner + '/' + $occlMsgInOwner +
    " copied-wait-loops=$waitLoopHits wait-calls=$waitCalls patience-defs=$patienceDefs")
  $occGood = @((Resolve-OccludeModeArg 'off'), (Resolve-OccludeModeArg 'warn'), (Resolve-OccludeModeArg 'strict'))
  $occBadErr = ''
  try { [void](Resolve-OccludeModeArg 'sometimes') } catch { $occBadErr = $_.Exception.Message }
  $gridErrs = @('', '', '')
  try { [void](Resolve-OcclGridArg '0') } catch { $gridErrs[0] = $_.Exception.Message }
  try { [void](Resolve-OcclGridArg '22') } catch { $gridErrs[1] = $_.Exception.Message }
  try { [void](Resolve-OcclGridArg 'wide') } catch { $gridErrs[2] = $_.Exception.Message }
  ST-Check 'unit: the two occlusion validators accept their legal set and refuse out-of-range or non-numeric values by name' (
    (@($occGood).Count -eq 3) -and ($occGood[0] -ceq 'off') -and ($occBadErr -like '--occlude must be off|warn|strict, got: sometimes') -and
    ($gridErrs[0] -like '--occlude-grid must be 1..21, got: 0*') -and ($gridErrs[1] -like '--occlude-grid must be 1..21, got: 22*') -and
    ($gridErrs[2] -like '--occlude-grid needs a whole number*got: wide'))
  $gridBothParsers = $true
  foreach ($gbp in @(@('10', '20', '--occlude-grid', 'wide'), @('10', '20', '--occlude', 'sometimes'))) {
    $gbpErr = ''
    try { [void](Split-Target $gbp 'click') } catch { $gbpErr = $_.Exception.Message }
    $gbpErr2 = ''
    try { [void](Split-OcclusionFlags $gbp) } catch { $gbpErr2 = $_.Exception.Message }
    if (-not ($gbpErr -and ($gbpErr -ceq $gbpErr2))) { $gridBothParsers = $false; Write-Output "      parsers disagree on $($gbp -join ' '): [$gbpErr] vs [$gbpErr2]" }
  }
  ST-Check 'unit: both flag parsers refuse the same token with the same words (the point of one producer is that they cannot drift)' (
    $gridBothParsers)

  # ---------- v3.0.1 (audit #20): the live suite must not fail on its environment ----------
  # Three shapes, all confirmed at code level by the review and fixed here: a missing
  # external binary reported as a broken invariant, a stderr line turning a JSON capture
  # into an empty one, and a TEMP path with a space being cut in half by cmd.
  $cnvErr = ''
  try { [void](& dtx-no-such-binary-anywhere --version 2>$null | Out-String) } catch { $cnvErr = $_.Exception.GetType().Name }
  ST-Check 'unit: POSITIVE CONTROL for the git gate - a missing external binary really does throw here (2>$null does not catch it), so the gate is load-bearing and not decoration' (
    $cnvErr -ceq 'CommandNotFoundException')
  $wsSlice = Get-FunctionSlice 'Get-WorkspaceSummary' $codeLines
  $wsGitGate = $wsSlice.Text.IndexOf('if ($gitReady) {')
  $wsFirstGit = $wsSlice.Text.IndexOf('& git -C $repo log')
  # v4.0.1 (audit finding 3): `clean` printing n/a is not enough - `ahead` had to be given the
  # same third state, and a lint that only looks at clean would let someone coerce ahead back to
  # [int]$null (which is 0, i.e. "in sync") without anything going red. The needle is assembled at
  # runtime because a scan over the raw source would otherwise match this very checking line.
  $aheadNaMark = '$null -eq $s.A' + 'head'
  $aheadNaSites = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($aheadNaMark) }).Count
  ST-Check 'lint: every git call in status-summary sits behind the availability test, and an unknown worktree prints n/a rather than false or empty (clean AND ahead, both render sites)' (
    $wsSlice.Found -and ($wsGitGate -ge 0) -and ($wsFirstGit -gt $wsGitGate) -and
    ($wsSlice.Text.Contains('Test-GitAvailable')) -and ((Get-FunctionSlice 'Test-GitAvailable' $codeLines).Found) -and
    ($codeLines -contains '          clean = $(if ($null -eq $s.Clean) { $null } else { [bool]$s.Clean })') -and
    ($aheadNaSites -eq 2))
  # These three shapes all live in the LIVE part of the suite, so the scan has to read the
  # RAW source (and must not exclude the selftest body, which is where the cases are).
  # Every marker is assembled by concatenation for that reason: on a raw-file scan, the
  # checking line is itself in the scanned text.
  $gateMark = '$gitAnchor' + 'Ready'
  $bomSkipMark = 'no git binary in PATH - the anchor reads ' + 'history objects'
  $bareJsonMark = 'PSCommandPath @jAr' + 'gs'
  $cmdScriptMark = '= & $apCmd ' + '"script'
  $quoteMark = ([string][char]96) + [char]34 + '$apSteps'
  $bomGate = 0
  $bomAnchorSkip = 0
  $jBare = 0
  $dryLine = ''
  foreach ($e20 in $srcLines) {
    $e20s = [string]$e20
    if ($e20s.Contains($gateMark)) { $bomGate++ }
    if ($e20s.Contains($bomSkipMark)) { $bomAnchorSkip++ }
    if ($e20s.Contains($bareJsonMark)) { $jBare++ }
    if ($e20s.Contains($cmdScriptMark)) { $dryLine = $e20s.Trim() }
  }
  ST-Check 'lint: the live suite hands cmd a quoted temp step path and merges the JSON captures through cmd (no bare 2>&1 left on those two cases)' (
    ($dryLine.Contains($quoteMark)) -and ($jBare -eq 0))
  Write-Output ("      env-robustness: dry-run line found=" + ($dryLine.Length -gt 0) + " quoted=" + $dryLine.Contains($quoteMark) + " bare-json-captures=$jBare")
  ST-Check 'lint: the BOM introduction anchor SKIPs when there is no git binary instead of reporting the history as broken' (
    ($bomGate -ge 3) -and ($bomAnchorSkip -eq 1))
  Write-Output ("      bom-anchor gate lines=$bomGate skip-echoes=$bomAnchorSkip")

  # ---------- v4.2.4: --timing, the per-check cost profile ----------
  # The gate costs minutes and nobody could say WHERE. --timing appends one bracket to each
  # emitted line; the recorded NAME is untouched, so the region reconciliation and the PASS
  # line-count contract keep working. The flag is a single assignment consulted by exactly the
  # two emitters - a profile that could change a verdict would be a different feature. The
  # needles are assembled at runtime because a raw-file scan would otherwise match these very
  # checking lines (the self-referential-scan family, again).
  $tmgAssign = @($srcLines | Where-Object { ([string]$_).Contains('$script:St' + 'Timing = (@($Rest) -contains') }).Count
  $tmgReads = @($srcLines | Where-Object { ([string]$_).Contains('if ($script:St' + 'Timing)') }).Count
  ST-Check 'lint (timing): --timing is one flag assignment consulted by exactly the two emitters (a profile that could change a verdict would be a different feature)' (
    ($tmgAssign -eq 1) -and ($tmgReads -eq 2))
  Write-Output ("      timing plumbing: assign=" + $tmgAssign + " reads=" + $tmgReads)

  # ---------- v4.2.4 (perf): no @(array).Count inside a for-condition (the O(n^2) trap) ----------
  # Measured on this very file: a three-round scan loop whose condition re-evaluated
  # `@(lines).Count` over 20,338 lines cost 44,885 ms; the identical loop with the count
  # hoisted cost 81 ms. (The example spells the array WITHOUT the `$` on purpose: a comment
  # that wrote the shape out literally would match this very lint - the self-referential-scan
  # family, caught by this lint's own first run at 2026-10-11 07:4x.)
  # @( ) re-copies the array on EVERY iteration, so a scan loop over $codeLines is O(n^2) -
  # fourteen lints were spending ~250 s of the gate inside exactly that shape. Hoisting the
  # count changes no verdict: these arrays are built once and never reassigned inside their
  # loops. The needle is assembled at runtime so this checking line cannot match itself, and
  # the planted sample proves the scan is not vacuous (an all-zero scan that cannot see the
  # shape is the "0 hits" trap this file keeps documenting).
  $slowPat = '-lt @\(\$\w' + '+\)\.Count'
  $slowLines = @($srcLines | Where-Object { ([string]$_) -match $slowPat }).Count
  $slowPlant = 'for ($i = 0; $i -lt @(' + '$arr).Count; $i++) { }'
  ST-Check 'lint (perf): no for-condition may carry @(array).Count - @( ) copies the array on every iteration, which cost fourteen scan lints ~250s of the gate (hoist the count)' (
    ($slowLines -eq 0) -and ($slowPlant -match $slowPat))
  if ($slowLines -gt 0) { Write-Output ("      for-conditions still carrying @(array).Count: " + $slowLines) }

  # ---------- v4.3.0 (lang-trap): two preventive lints from the six-trap ledger ----------
  # The screening record (which of the six became checks, which were rejected and why) lives
  # in the iteration log; every scan below carries a planted sample.
  # A-14i: one window, published by the orchestrator as the AST span of every selftest body. This used
  # to be a second copy of that judgement, and A-14b's family-range exemptions below stay in place as
  # deliberate belt-and-braces (a subset of the span, harmless, and it is what proved the original
  # narrowing in the first place).
  $ktSelfStart = $j5ProdStart
  $ktSelfEnd = $j5ProdEnd
  $ktExempt = New-Object System.Collections.ArrayList
  foreach ($ktFn in @('Get-HashKeys', 'Get-OptValue')) {
    $ktS = -1; $ktE = -1
    for ($kti = 0; $kti -lt $clCount; $kti++) {
      if ($codeLines[$kti] -match ('^function ' + [regex]::Escape($ktFn) + '[\s(]')) { $ktS = $kti; continue }
      if ($ktS -ge 0 -and $kti -gt $ktS -and $codeLines[$kti] -match '^function ') { $ktE = $kti; break }
    }
    if ($ktS -ge 0) {
      if ($ktE -lt 0) { $ktE = $clCount }
      [void]$ktExempt.Add(@($ktS, $ktE))
    }
  }
  # A-14b: a lifted family body is the same selftest code, relocated, so the exemption travels with
  # it. The range is that function's own braces, deliberately NOT "to the next ^function": the
  # families sit adjacent in the aggregate, and an open-ended range would exempt the neighbour too
  # and quietly weaken this very lint.
  foreach ($ktFam in @($script:StFamilyLifted)) {
    $ktFs = -1; $ktFe = -1
    $ktFName = '^function ' + [regex]::Escape((Get-FamilyFunctionName $ktFam)) + '[\s(]'
    for ($kti = 0; $kti -lt $clCount; $kti++) {
      if ($codeLines[$kti] -match $ktFName) { $ktFs = $kti; continue }
      if ($ktFs -ge 0 -and $kti -gt $ktFs -and $codeLines[$kti] -match '^\}') { $ktFe = $kti + 1; break }
    }
    if ($ktFs -ge 0) {
      if ($ktFe -lt 0) { $ktFe = $clCount }
      [void]$ktExempt.Add(@($ktFs, $ktFe))
    }
  }
  $ktReal = Get-KeysScanResult -lines $codeLines -selfStart $ktSelfStart -selfEnd $ktSelfEnd -exempt $ktExempt
  $ktViol = @(@($ktReal.Hits) | Where-Object { -not $_.Exempt })
  $ktRaw = @($codeLines | Where-Object { ([string]$_).Contains('.' + 'Keys') }).Count
  $ktPlantBad = Get-KeysScanResult -lines @(('$zz = ($plantedHash).' + 'Keys'), ('# ' + '.Keys in a comment stays quiet'), 'Get-Well') -selfStart -1 -selfEnd -1 -exempt @()
  $ktExOne = New-Object System.Collections.ArrayList
  [void]$ktExOne.Add(@(0, 1))
  $ktPlantEx = Get-KeysScanResult -lines @(('$zz = ($plantedHash).' + 'Keys')) -selfStart -1 -selfEnd -1 -exempt $ktExOne
  $ktPlantViol = @(@($ktPlantBad.Hits) | Where-Object { -not $_.Exempt }).Count
  $ktPlantExViol = @(@($ktPlantEx.Hits) | Where-Object { -not $_.Exempt }).Count
  ST-Check 'lint (lang-trap): production never reads keys-member directly - a key named keys shadows it, so keys go through Get-HashKeys (Get-HashKeys/Get-OptValue bodies exempt)' (
    (@($ktViol).Count -eq 0) -and ($ktRaw -ge 10) -and ($ktPlantViol -eq 1) -and ($ktPlantExViol -eq 0))
  foreach ($ktv in @($ktViol)) { Write-Output ('      keys-member read outside Get-HashKeys: line ' + ([int]$ktv.Line) + ' - ' + [string]$ktv.Text) }
  Write-Output ('      keys-member scan: raw=' + $ktRaw + ' violations=' + @($ktViol).Count)

  $utP1 = 'x | ' + 'Measure-Object -' + 'Line | Out-File y'
  $utP2 = 'Get-' + 'Content a.txt | Set-' + 'Content b.txt'
  $utP3 = '-Encoding ' + 'Byte a.bin'
  $utHits = New-Object System.Collections.ArrayList
  for ($uti = 0; $uti -lt $clCount; $uti++) {
    $utl = [string]$codeLines[$uti]
    if ($utl.TrimStart().StartsWith('#')) { continue }
    if ($utl -match ('Measure-Object -' + 'Line')) { [void]$utHits.Add('shape1@' + ($uti + 1)) }
    elseif ($utl -match ('Get-' + 'Content.*\|.*Set-' + 'Content')) { [void]$utHits.Add('shape2@' + ($uti + 1)) }
    elseif ($utl.Contains('-Encoding ' + 'Byte')) { [void]$utHits.Add('shape3@' + ($uti + 1)) }
  }
  ST-Check 'lint (lang-trap): no unsafe text shapes (blank-line-blind line counting; encode-damaging round-trip; PS5-only byte flag - see the trap ledger)' (
    (@($utHits).Count -eq 0) -and ($utP1 -match ('Measure-Object -' + 'Line')) -and ($utP2 -match ('Get-' + 'Content.*\|.*Set-' + 'Content')) -and ($utP3.Contains('-Encoding ' + 'Byte')))
  foreach ($utv in @($utHits)) { Write-Output ('      unsafe text shape: ' + [string]$utv) }
  Write-Output ('      unsafe-text scan: lines=' + $clCount + ' hits=' + @($utHits).Count)

  # ---------- lint: forbidden @()/$() wrapper on comma-returning helpers ----------

  # (A-14r: this run's input, the comma-return scan, now sits in the setup and arrives as $commaFns -
  # the value the gates below judge is the value the setup computed, unchanged.)
  # the scan itself must work, or the lint silently protects nothing
  ST-Check 'lint: comma-return scan found the known helpers' (
    ($commaFns -contains 'Find-OcrHits') -and ($commaFns -contains 'Invoke-OcrRegion') -and ($commaFns -contains 'Find-ColorMatches'))
  # and the here-string blanking must work, or Usage's prose pollutes the list
  ST-Check 'lint: Usage is not misclassified as a comma-returning helper' ($commaFns -notcontains 'Usage')
  # A-14f: same trap, new shape. A lifted family body is test code that legitimately contains the text
  # this scan hunts for (another lint's planted `return ,`), and once it was its own top-level function
  # it was invented as a helper - which emitted two extra gates out of nowhere and broke the declared
  # total. The exemption list is the declared family set, and the answer must stay empty.
  $a14fAsHelper = @()
  foreach ($a14fK in @($script:StFamilyLifted)) { if (@($commaFns) -contains (Get-FamilyFunctionName $a14fK)) { $a14fAsHelper += (Get-FamilyFunctionName $a14fK) } }
  # and the exemption itself must be measured, not assumed: the same shape in a name that is NOT exempt
  # still has to be caught, while the exempt one is not. Without both directions this gate can only ever
  # read 'nothing happened' - which is how a vacuous check looks exactly like a working one.
  $a14fPlantH = @(
    'function Invoke-SelftestFamily-Planted {',
    '  return ,@(1, 2)',
    '}',
    'function Ordinary-Helper {',
    '  return ,@(3)',
    '}'
  )
  $a14fPlantText = ($a14fPlantH -join "`n")
  $a14fNoExempt = Get-CommaReturningHelperNames $a14fPlantText @()
  $a14fWithExempt = Get-CommaReturningHelperNames $a14fPlantText @('Invoke-SelftestFamily-Planted')
  ST-Check 'lint (A-14f): no lifted family body is classified as a comma-returning helper, and the scan still catches the same shape in a name it does not exempt (so the exemption is measured, not assumed)' (
    (@($a14fAsHelper).Count -eq 0) -and ($a14fNoExempt -ceq 'Invoke-SelftestFamily-Planted,Ordinary-Helper') -and
    ($a14fWithExempt -ceq 'Ordinary-Helper'))
  Write-Output ('      A-14f helper table: helpers=' + @($commaFns).Count + ' family-misclassified=[' + ($a14fAsHelper -join ',') + ']')

  # A-14i: the truncation lint arrived in a family file carrying a SECOND copy of the window judgement
  # and reddened on the move - a second copy is stale by construction, because the span it computes
  # stops at the first thing that no longer exists where it expected it. There is now one published
  # window; this counts recomputations inside selftest bodies and must find none, with a planted copy
  # as the witness so 'none' means measured and not blind.
  $a14iNames = @('Invoke-SelfTest')
  foreach ($a14iK in @($script:StFamilyLifted)) { $a14iNames += Get-FamilyFunctionName $a14iK }
  $a14iCopies = Get-WindowCopyCountInBodies $j5SelfParsed @($script:StSourceLines) @($a14iNames)
  $a14iTok = Get-CharCodeWord @(0x49, 0x6E, 0x76, 0x6F, 0x6B, 0x65, 0x2D, 0x53, 0x65, 0x6C, 0x66, 0x54, 0x65, 0x73, 0x74)
  $a14iPlantLines = @(
    'function Invoke-SelftestFamily-Planted {',
    ('  if ($codeLines[$i] -match ' + [string][char]39 + '^function ' + $a14iTok + [string][char]39 + ') { }'),
    '}',
    'function Other-Body {',
    '  return 1',
    '}'
  )
  $a14iPlantParsed = Parse-SourceForInventory ($a14iPlantLines -join "`n")
  $a14iPlantCopies = Get-WindowCopyCountInBodies $a14iPlantParsed @($a14iPlantLines) @('Invoke-SelftestFamily-Planted')
  $a14iAbsentCopies = Get-WindowCopyCountInBodies $a14iPlantParsed @($a14iPlantLines) @('Nothing-With-This-Name')
  ST-Check 'lint (A-14i): no selftest body re-derives the production window - the published AST span is the only source, and the counter still names a planted copy of the old shape (and says absent for a body that is not there)' (
    ($a14iCopies -ceq '') -and ($a14iPlantCopies -ceq 'Invoke-SelftestFamily-Planted=1') -and ($a14iAbsentCopies -ceq '-absent'))
  Write-Output ('      A-14i window copies: bodies=' + @($a14iNames).Count + ' found=[' + ("$a14iCopies") +
    '] planted=[' + ("$a14iPlantCopies") + '] absent=' + ("$a14iAbsentCopies"))
  # ---------- v2.6.0: the automatic capture-folder trim ----------
  # Policy is pure, so both knobs are pinned with injected probes and no file moves.
  ST-Check 'unit: auto-trim defaults to on, with the same keep as the manual command' (
    ((Get-ShotAutoTrimPolicy '').Enabled -eq $true) -and ((Get-ShotAutoTrimPolicy '').Keep -eq 100))
  ST-Check 'unit: auto-trim switches off on 0/off/false/no, case and space insensitive' (
    ((Get-ShotAutoTrimPolicy '0').Enabled -eq $false) -and ((Get-ShotAutoTrimPolicy ' OFF ').Enabled -eq $false) -and ((Get-ShotAutoTrimPolicy 'False').Enabled -eq $false) -and ((Get-ShotAutoTrimPolicy 'no').Enabled -eq $false))
  ST-Check 'unit: auto-trim treats any other switch value as ON - a typo must not silently stop it' (
    ((Get-ShotAutoTrimPolicy '1').Enabled -eq $true) -and ((Get-ShotAutoTrimPolicy 'on').Enabled -eq $true) -and ((Get-ShotAutoTrimPolicy 'maybe').Enabled -eq $true))
  ST-Check 'unit: auto-trim keep honours a number, clamps negatives to zero, ignores garbage' (
    ((Get-ShotAutoTrimPolicy '' '25').Keep -eq 25) -and ((Get-ShotAutoTrimPolicy '' '0').Keep -eq 0) -and ((Get-ShotAutoTrimPolicy '' '-5').Keep -eq 0) -and ((Get-ShotAutoTrimPolicy '' 'abc').Keep -eq 100) -and ((Get-ShotAutoTrimPolicy '' '').Keep -eq 100))

  # The MOVE touches user files, so it runs END-TO-END on a temp folder against a temp
  # quarantine: the assertions are about files on disk, and nothing here can reach the
  # real shots\ or the real quarantine. The guard flag is saved and cleared around it,
  # which also pins the flag itself: ON must refuse, OFF must move.
  $atTmp = Join-Path $env:TEMP ('st_autotrim_' + [guid]::NewGuid().ToString('N'))
  $atShots = Join-Path $atTmp 'shots'; $atQuar = Join-Path $atTmp 'quar'
  New-Item -ItemType Directory -Force -Path $atShots | Out-Null
  New-Item -ItemType Directory -Force -Path $atQuar | Out-Null
  $atBase = (Get-Date).AddHours(-3)
  foreach ($an in @('a1', 'a2', 'a3')) {
    $p = Join-Path $atShots ($an + '.png'); $s = Join-Path $atShots ($an + '.png.map.txt')
    [System.IO.File]::WriteAllBytes($p, (New-Object byte[] 200))
    [System.IO.File]::WriteAllText($s, "screen = image + (0,0)`r`n", (New-Object System.Text.UTF8Encoding($false)))
    $t = $atBase.AddMinutes(([int]($an.Substring(1)) * 10))
    (Get-Item -LiteralPath $p).LastWriteTime = $t; (Get-Item -LiteralPath $s).LastWriteTime = $t
  }
  [System.IO.File]::WriteAllText((Join-Path $atShots 'actions.log'), "audit line`r`n", (New-Object System.Text.UTF8Encoding($false)))
  try {
    # The guard is ON here because Invoke-SelfTest armed it, so the run below has to
    # disarm it EXPLICITLY - "save and restore" would restore it to ON and the whole
    # e2e would pass by moving nothing (which is exactly how these four checks first
    # presented: green-looking assertions over a null result).
    $script:NoAutoTrim = $true
    $atBlocked = Trim-ShotDir -Dir $atShots -why 'selftest' -Keep 1 -QuarOverride $atQuar -CmdName 'selftest'
    $script:NoAutoTrim = $false
    $atRun1 = Trim-ShotDir -Dir $atShots -why 'selftest' -Keep 1 -QuarOverride $atQuar -CmdName 'selftest'
    $atRun2 = Trim-ShotDir -Dir $atShots -why 'selftest' -Keep 1 -QuarOverride $atQuar -CmdName 'selftest'
    $script:NoAutoTrim = $true
    $atManifest = Join-Path $atQuar 'MANIFEST.md'
    $atDest = @($atRun1.Dest)
    $atMovedFiles = @()
    if ($atRun1) { $atMovedFiles = @(Get-ChildItem -LiteralPath $atRun1.Dest -File | ForEach-Object { $_.Name }) }
    ST-Check 'unit: auto-trim refuses while the selftest guard flag is set (live fixtures stay put)' ($null -eq $atBlocked)
    ST-Check 'e2e: auto-trim moves the over-bound images WITH their sidecars and keeps the newest' (
      ($null -ne $atRun1) -and ($atRun1.Moved -eq 4) -and ($atRun1.Failed -eq 0) -and (Test-Path -LiteralPath (Join-Path $atShots 'a3.png')) -and (-not (Test-Path -LiteralPath (Join-Path $atShots 'a1.png'))) -and (-not (Test-Path -LiteralPath (Join-Path $atShots 'a2.png.map.txt'))))
    ST-Check 'e2e: auto-trim leaves the audit log alone - it is not a capture' (Test-Path -LiteralPath (Join-Path $atShots 'actions.log'))
    ST-Check 'e2e: auto-trim lands the files in the quarantine folder, nothing is deleted' (
      (@($atMovedFiles | Where-Object { $_ -in @('a1.png', 'a1.png.map.txt', 'a2.png', 'a2.png.map.txt') }).Count -eq 4) -and ($atRun1.Moved -eq $atMovedFiles.Count))
    ST-Check 'e2e: auto-trim writes a MANIFEST section naming every original path with its SHA256' (
      (Test-Path -LiteralPath $atManifest) -and ((Get-Content -Raw -LiteralPath $atManifest) -match 'auto-trim v2\.6\.0') -and (((Get-Content -Raw -LiteralPath $atManifest) -split "`n" | Where-Object { $_ -match '^\- ' -and $_ -match 'sha256: ' }).Count -eq 4))
    ST-Check 'e2e: auto-trim is a no-op once the folder is under the bound (it does not churn)' ($null -eq $atRun2)
    ST-Check 'e2e: auto-trim states its own bound and the no-deletion promise in the note' (
      ("$($atRun1.Note)" -match 'keep newest 1') -and ("$($atRun1.Note)" -match 'nothing was deleted'))
  } finally {
    if (Test-Path -LiteralPath $atTmp) { Remove-Item -LiteralPath $atTmp -Recurse -Force }
  }
  # Tokens are assembled at runtime so THIS check's own lines never satisfy the shapes it
  # counts - the same evasion the README badge lint uses, and for the same reason.
  $mvTok = '= Move-ShotsTo' + 'Quarantine '
  $trTok = 'Trim-ShotDir $O' + 'utDir'
  $miTok = 'Move-Item -LiteralPath $m.Fu' + 'llName'
  $gdTok = 'script:NoAutoTrim = $t' + 'rue'
  $aeProbeTok = 'Invoke-AutoPasteExpect $p $target (Get-AutoExpectNeedle $text) $rcpBase'
  # A-14i: this is the start of the one published window (the AST span of every selftest body), not a
  # second hunt for '^function Invoke-SelfTest'. Value-identical here - the span begins at this body -
  # but a second copy is what goes stale on a move, and lint (A-14i) now refuses the shape outright.
  # (A-14r: $stDefIdx/$stEndIdx/$mvProd are computed once in the setup, from the published window - see
  # lint (A-14i): a second hunt for the same span is what goes stale on a move.)
  $guardArmed = $false
  if ($stDefIdx -ge 0) {
    for ($gj = $stDefIdx; $gj -lt [math]::Min($stDefIdx + 14, $codeLines.Count); $gj++) {
      if ($codeLines[$gj].Contains($gdTok)) { $guardArmed = $true }
    }
  }
  # The count is scoped to PRODUCTION, where production = everything OUTSIDE the Invoke-SelfTest
  # body. The naive "lines before the selftest" is wrong in this file: Invoke-SelfTest is defined
  # BEFORE the dispatcher, so the shots-cleanup case itself would have been excluded (measured:
  # the count dropped to 1). The invariant is "one move-and-manifest loop, shared by the command
  # and the automatic trim"; a selftest that CALLS the mover is expected and must not read as a
  # second implementation. Teeth stay: a third PRODUCTION call site still makes this red, and the
  # Move-Item site count staying at 1 is what actually forbids a re-implementation.
  # v4.4.0 (A-14q): production = OUTSIDE THE DECLARED SELFTEST WINDOW (lint (A-14f) measures the AST span
  # of every selftest body), not "up to the next ^function". The positional version was registered in the
  # construction ledger as G-09 and the cut proved it: a body lifted into lib/selftest-<key>.ps1 sits in
  # the aggregate AFTER the first family function, so the old scan re-classified lifted selftest text as
  # production and this gate reddened on a MOVE, not on a change of behaviour. No forward scan, so the
  # A-11b descending-slice trap cannot come back either.
  # ($mvProd is the published slice; $mvInsideWindow below still proves the window is doing the work)
  # A scope that excludes nothing is indistinguishable from a scope that works, so the exclusion gets a
  # witness: a hit that lives INSIDE the window and is left out of $mvProd is what makes the scope real.
  # Measured on this tree: desktop.ps1 carries mv=2 mi=1 (the counts the gate demands) and the section
  # carries one more mv hit inside the window - so an unscoped scan would read mv=3 and go red.
  $mvInsideWindow = @($codeLines[$stDefIdx..($stEndIdx - 1)] | Where-Object { $_.Contains($mvTok) }).Count
  ST-Check 'lint: the move-and-manifest loop exists exactly once, shared by the command and the trim (production-scoped: a selftest call is not a second implementation)' (
    (@($mvProd | Where-Object { $_.Contains($mvTok) }).Count -eq 2) -and (@($mvProd | Where-Object { $_.Contains($miTok) }).Count -eq 1) -and
    ($mvInsideWindow -ge 1))
  Write-Output ('      production scope: window=[' + $stDefIdx + '..' + $stEndIdx +
    ' window-hits-left-out=' + $mvInsideWindow + ' mv=' + (@($mvProd | Where-Object { $_.Contains($mvTok) }).Count) +
    ' mi=' + (@($mvProd | Where-Object { $_.Contains($miTok) }).Count))
  # The trim must have EXACTLY ONE call site and it must be the dispatch tail - a hook on
  # Save-RectEx alone was the v2.6.0 first draft and a real `zoom` (which saves its own
  # bitmap) proved files could be written without ever reaching it.
  $idcStart = -1; $idcEnd = $codeLines.Count
  for ($ki = 0; $ki -lt $codeLines.Count; $ki++) {
    if ($codeLines[$ki] -match '^function Invoke-DesktopCommand') { $idcStart = $ki; continue }
    if ($idcStart -ge 0 -and $ki -gt $idcStart -and $codeLines[$ki] -match '^function ') { $idcEnd = $ki; break }
  }
  $trAll = @($codeLines | Where-Object { $_.Contains($trTok) })
  $trInDispatch = @($codeLines[$idcStart..($idcEnd - 1)] | Where-Object { $_.Contains($trTok) })
  ST-Check 'lint: the capture path actually calls the trim, and Invoke-SelfTest actually arms the guard' (
    ($idcStart -ge 0) -and (@($trAll).Count -eq 1) -and (@($trInDispatch).Count -eq 1) -and $guardArmed)
  # v4.3.3 (G-08, owner ruling 2026-10-16): the auto-trim sentence must not land in the JSON
  # success stream. Measured as a routing shape inside the dispatcher window - error stream when the
  # JSON flag is on, success stream otherwise - and BOTH wrong shapes are planted: a scan that only
  # ever answers 'clean' for the file it likes would also have answered clean for the old one.
  $g08Win = @()
  if ($idcStart -ge 0) { $g08Win = @($codeLines[$idcStart..($idcEnd - 1)]) }
  $g08Route = 'dispatch-window-missing'
  if (@($g08Win).Count -ge 1) { $g08Route = Get-TrimJsonRouteNote @($g08Win) }
  $g08Old = @(
    '  if ($trimNote) { "$($trimNote.Note)"; foreach ($ft in @($trimNote.Failures)) { "$ft" } }'
  )
  $g08OldNote = Get-TrimJsonRouteNote @($g08Old)
  $g08NoErr = @(
    '    if ($script:Json) {',
    '      "$($trimNote.Note)"',
    '    } else {',
    '      "$($trimNote.Note)"',
    '    }'
  )
  $g08ErrNote = Get-TrimJsonRouteNote @($g08NoErr)
  ST-Check 'lint (G-08): the auto-trim sentence leaves the success stream on the --json road and still speaks on the plain road, and the scan names both ways it could be wrong' (
    ("$g08Route" -ceq '') -and (@("$g08OldNote" -split '=')[0] -ceq 'trim-note-echoes') -and
    ("$g08ErrNote" -ceq 'no-error-stream-route'))
  Write-Output ('      G-08 routing: live=[' + ("$g08Route") + '] planted-old=[' + ("$g08OldNote") +
    '] planted-no-error=[' + ("$g08ErrNote") + ']')
  # S-90: the left-down-button release warning must leave the --json success stream too. Scoped to the
  # ENTRY window because this check's own planted shapes live in the aggregate - the self-pollution trap
  # the G-08 gate had to be written around, so the scan is bounded the same way.
  $pwAnchor = 'Invoke-PressWatchdog ' + '$Cm' + 'd'
  $pwStart = -1
  for ($pwI = 0; $pwI -lt $codeLines.Count; $pwI++) {
    if (([string]$codeLines[$pwI]).Contains($pwAnchor)) { $pwStart = $pwI; break }
  }
  $pwWin = @()
  if ($pwStart -ge 0) { $pwWin = @($codeLines[$pwStart..([math]::Min($pwStart + 18, $codeLines.Count - 1))]) }
  $pwRoute = 'press-watchdog-site-missing'
  if (@($pwWin).Count -ge 1) { $pwRoute = Get-PressWarnRouteNote @($pwWin) }
  $pwOld = @('  if ($pressWarn) { Write-Output $pressWarn }')
  $pwOldNote = Get-PressWarnRouteNote @($pwOld)
  $pwNoFlag = @('    if ($true) {', '      [Console]::Error.WriteLine([string]$pressWarn)', '      Write-Output $pressWarn', '    }')
  $pwNoFlagNote = Get-PressWarnRouteNote @($pwNoFlag)
  ST-Check 'lint (S-90): the released-a-left-down-button warning leaves the --json success stream, the plain road still says it exactly once, and the scan names both ways it could be wrong' (
    ("$pwRoute" -ceq '') -and (@("$pwOldNote" -split '=')[0] -ceq 'press-error-route') -and
    ($pwNoFlagNote -match '^press-error-route-at-'))
  Write-Output ('      S-90 routing: live=[' + ("$pwRoute") + '] planted-old=[' + ("$pwOldNote") +
    '] planted-no-flag=[' + ("$pwNoFlagNote") + '] window-at=' + [string]($pwStart + 1))
  # G-24: the process-exit watchdog runs after the command body. Pin BOTH output streams here;
  # S-90 above covers the entry watchdog and cannot stand in for this exit path.
  $g24EntryLines = @(Get-Content -LiteralPath $script:ToolEntryPath -Encoding UTF8)
  $g24FinallyStart = -1
  for ($g24I = 0; $g24I -lt $g24EntryLines.Count; $g24I++) {
    if ($g24EntryLines[$g24I].Trim() -ceq '} finally {') {
      $g24HasPressCheck = $false
      for ($g24Scan = $g24I + 1; $g24Scan -lt $g24EntryLines.Count; $g24Scan++) {
        if ($g24EntryLines[$g24Scan].Trim() -ceq 'if (Get-LeftButtonDown) {') { $g24HasPressCheck = $true; break }
      }
      if ($g24HasPressCheck) { $g24FinallyStart = $g24I }
    }
  }
  $g24FinallyEnd = $g24EntryLines.Count - 1
  while ($g24FinallyEnd -ge 0 -and $g24EntryLines[$g24FinallyEnd].Trim().Length -eq 0) { $g24FinallyEnd-- }
  $g24PressStart = -1
  if ($g24FinallyStart -ge 0) {
    for ($g24I = $g24FinallyStart + 1; $g24I -lt $g24FinallyEnd; $g24I++) {
      if ($g24EntryLines[$g24I].Trim() -ceq 'if (Get-LeftButtonDown) {') { $g24PressStart = $g24I; break }
    }
  }
  $g24PressEnd = -1
  if ($g24PressStart -ge 0) {
    for ($g24I = $g24PressStart + 1; $g24I -le $g24FinallyEnd; $g24I++) {
      if ([string]$g24EntryLines[$g24I] -ceq '  }') { $g24PressEnd = $g24I; break }
    }
  }
  $g24PressWin = @()
  $g24ActualShape = @()
  if ($g24PressStart -ge 0 -and $g24PressEnd -ge $g24PressStart) {
    $g24PressWin = @($g24EntryLines[$g24PressStart..$g24PressEnd])
    foreach ($g24Line in $g24PressWin) {
      $g24Trim = ([string]$g24Line).Trim()
      if ($g24Trim.Length -eq 0 -or $g24Trim.StartsWith('#')) { continue }
      $g24ActualShape += $g24Trim
    }
  }
  $g24Warning = 'WARNING: exiting with the left button still DOWN - releasing it now (P-3 watchdog)'
  $g24WarnErr = '[Console]::Error.WriteLine(' + [string][char]39 + $g24Warning + [string][char]39 + ')'
  $g24WarnOut = 'Write-Output ' + [string][char]39 + $g24Warning + [string][char]39
  $g24ReleaseCall = '$exitReleaseReceipt = Release-Press $script:PressId ' + [string][char]39 + 'process-exit' + [string][char]39 + ' @() $Cmd'
  $g24ExpectedShape = @(
    'if (Get-LeftButtonDown) {',
    'if ($script:Json) {',
    $g24WarnErr,
    '} else {',
    $g24WarnOut,
    '}',
    $g24ReleaseCall,
    'if ($script:Json) {',
    '[Console]::Error.WriteLine([string]$exitReleaseReceipt)',
    '} else {',
    'Write-Output $exitReleaseReceipt',
    '}',
    '}'
  )
  $g24CompareShape = {
    param([string[]]$Candidate, [string[]]$Expected)
    $got = @($Candidate)
    $want = @($Expected)
    if ($got.Count -ne $want.Count) { return ('shape-count=' + $got.Count + '-want' + $want.Count) }
    for ($g24ShapeI = 0; $g24ShapeI -lt $want.Count; $g24ShapeI++) {
      if ([string]$got[$g24ShapeI] -cne [string]$want[$g24ShapeI]) { return ('shape-line-' + ($g24ShapeI + 1) + '-changed') }
    }
    return ''
  }
  $g24RouteNote = & $g24CompareShape $g24ActualShape $g24ExpectedShape
  $g24OldShape = @(
    'if (Get-LeftButtonDown) {',
    $g24WarnOut,
    ('Release-Press $script:PressId ' + [string][char]39 + 'process-exit' + [string][char]39 + ' @() $Cmd'),
    '}'
  )
  $g24OldNote = & $g24CompareShape $g24OldShape $g24ExpectedShape
  $g24NoJsonShape = @($g24ExpectedShape)
  $g24NoJsonShape[1] = 'if ($true) {'
  $g24NoJsonShape[7] = 'if ($true) {'
  $g24NoJsonNote = & $g24CompareShape $g24NoJsonShape $g24ExpectedShape
  $g24ReturnContractCount = @($codeLines | Where-Object {
    ([string]$_).Trim() -ceq 'return "button is UP (id=$rpResolved cause=$cause)"'
  }).Count
  ST-Check 'lint (G-24): exit-watchdog JSON warning and release receipt route to stderr, plain output order and wording stay fixed, Release-Press keeps its return contract, and direct/unguarded plants are rejected' (
    ($g24RouteNote -ceq '') -and ($g24OldNote -ne '') -and ($g24NoJsonNote -ne '') -and ($g24ReturnContractCount -eq 1))
  Write-Output ('      G-24 route: live=[' + [string]$g24RouteNote + '] planted-direct=[' + [string]$g24OldNote + '] planted-no-json=[' + [string]$g24NoJsonNote + '] Release-Press-return=' + $g24ReturnContractCount)

  # Offline injection: execute only the actual finally body in a child with mocked button/release/tracking calls.
  # The child receives no desktop APIs; its stubs return the pinned Release-Press receipt and quiet call tracking.
  $g24InjectOk = $false
  $g24InjectSummary = 'injection-not-run'
  $g24Root = Join-Path $env:TEMP ('dtx-g24-process-exit-' + [guid]::NewGuid().ToString('N'))
  $g24OwnRoot = $false
  try {
    if ($g24FinallyStart -lt 0 -or $g24FinallyEnd -le ($g24FinallyStart + 1)) { throw 'actual final finally body is absent or empty' }
    $g24ExpectedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92) + [IO.Path]::DirectorySeparatorChar
    $g24FullRoot = [IO.Path]::GetFullPath($g24Root)
    if (-not $g24FullRoot.StartsWith($g24ExpectedTemp, [StringComparison]::OrdinalIgnoreCase)) { throw 'refusing a probe path outside the system temp root' }
    if (-not ([IO.Path]::GetFileName($g24FullRoot)).StartsWith('dtx-g24-process-exit-', [StringComparison]::OrdinalIgnoreCase)) { throw 'refusing a probe directory without its unique prefix' }
    if (Test-Path -LiteralPath $g24FullRoot) { throw 'unique G-24 temp directory unexpectedly already exists' }
    New-Item -Path $g24FullRoot -ItemType Directory -ErrorAction Stop | Out-Null
    $g24OwnRoot = $true
    $g24FinallyBody = @($g24EntryLines[($g24FinallyStart + 1)..($g24FinallyEnd - 1)])
    $g24ProbeLines = @(
      'param([string]$JsonMode)',
      '$script:Json = [bool]::Parse($JsonMode)',
      '$script:PressId = ""',
      '$script:CallLease = $null',
      '$script:InvocationResult = "completed"',
      '$script:InvocationExitCode = 0',
      '$script:InvocationErrorCategory = ""',
      '$Cmd = "g24-probe"',
      'function Get-LeftButtonDown { return $true }',
      'function Release-Press([string]$id, [string]$cause, $logArgs, [string]$CmdName) { return "button is UP (id= cause=process-exit)" }',
      'function Complete-DtxCallTracking($Lease, $Result, $ExitCode, $ErrorCategory) { }',
      'try {',
      '} finally {'
    ) + $g24FinallyBody + @('}', 'exit 0')
    $g24ProbePath = Join-Path $g24FullRoot 'g24-finally-probe.ps1'
    [IO.File]::WriteAllText($g24ProbePath, ($g24ProbeLines -join [Environment]::NewLine), (New-Object System.Text.UTF8Encoding($false)))
    $g24EnginePath = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if (-not $g24EnginePath -or -not (Test-Path -LiteralPath $g24EnginePath)) { throw 'current PowerShell engine path is unavailable' }
    $g24Modes = @()
    foreach ($g24JsonMode in @($true, $false)) {
      $g24Arg = if ($g24JsonMode) { 'true' } else { 'false' }
      $g24Psi = New-Object System.Diagnostics.ProcessStartInfo
      $g24Psi.FileName = $g24EnginePath
      $g24Psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $g24ProbePath + '" ' + $g24Arg
      $g24Psi.UseShellExecute = $false
      $g24Psi.CreateNoWindow = $true
      $g24Psi.RedirectStandardOutput = $true
      $g24Psi.RedirectStandardError = $true
      $g24Proc = New-Object System.Diagnostics.Process
      $g24Proc.StartInfo = $g24Psi
      if (-not $g24Proc.Start()) { throw ('could not start injected child mode=' + $g24Arg) }
      $g24OutTask = $g24Proc.StandardOutput.ReadToEndAsync()
      $g24ErrTask = $g24Proc.StandardError.ReadToEndAsync()
      if (-not $g24Proc.WaitForExit(10000)) {
        try { $g24Proc.Kill() } catch { }
        throw ('injected child timed out mode=' + $g24Arg)
      }
      $g24Out = [string]$g24OutTask.Result
      $g24Err = [string]$g24ErrTask.Result
      $g24Code = [int]$g24Proc.ExitCode
      $g24Proc.Dispose()
      $g24OutLines = @($g24Out -split '\r?\n' | Where-Object { $_ -ne '' })
      $g24ErrLines = @($g24Err -split '\r?\n' | Where-Object { $_ -ne '' })
      if ($g24JsonMode) {
        $g24ModeOk = ($g24Code -eq 0) -and ($g24Out.Length -eq 0) -and ($g24ErrLines.Count -eq 2) -and
          ([string]$g24ErrLines[0] -ceq $g24Warning) -and ([string]$g24ErrLines[1] -ceq 'button is UP (id= cause=process-exit)')
      } else {
        $g24ModeOk = ($g24Code -eq 0) -and ($g24Err.Length -eq 0) -and ($g24OutLines.Count -eq 2) -and
          ([string]$g24OutLines[0] -ceq $g24Warning) -and ([string]$g24OutLines[1] -ceq 'button is UP (id= cause=process-exit)')
      }
      $g24Modes += [pscustomobject]@{ Json = [bool]$g24JsonMode; Exit = $g24Code; StdoutChars = $g24Out.Length; StderrChars = $g24Err.Length; StdoutLines = $g24OutLines.Count; StderrLines = $g24ErrLines.Count; Pass = [bool]$g24ModeOk }
    }
    $g24InjectOk = (@($g24Modes).Count -eq 2) -and (@($g24Modes | Where-Object { -not $_.Pass }).Count -eq 0)
    $g24InjectSummary = (($g24Modes | ForEach-Object {
      'json=' + [bool]$_.Json + ',exit=' + [int]$_.Exit + ',stdout-lines=' + [int]$_.StdoutLines + ',stderr-lines=' + [int]$_.StderrLines + ',pass=' + [bool]$_.Pass
    }) -join ' | ')
  } catch {
    $g24InjectSummary = 'injection-error=' + $_.Exception.Message
  } finally {
    if ($g24OwnRoot) {
      $g24FullRoot = [IO.Path]::GetFullPath($g24Root)
      $g24ExpectedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92) + [IO.Path]::DirectorySeparatorChar
      if ($g24FullRoot.StartsWith($g24ExpectedTemp, [StringComparison]::OrdinalIgnoreCase) -and
          ([IO.Path]::GetFileName($g24FullRoot)).StartsWith('dtx-g24-process-exit-', [StringComparison]::OrdinalIgnoreCase)) {
        try { Remove-Item -LiteralPath $g24FullRoot -Recurse -Force -ErrorAction Stop } catch { $g24InjectOk = $false; $g24InjectSummary += ' cleanup-error=' + $_.Exception.Message }
      } else {
        $g24InjectOk = $false
        $g24InjectSummary += ' cleanup-refused-outside-owned-root'
      }
    }
  }
  ST-Check 'e2e (G-24): injected process-exit watchdog keeps JSON stdout clean, sends warning and receipt to stderr, and preserves plain output order and exit 0' $g24InjectOk
  Write-Output ('      G-24 offline injection: ' + $g24InjectSummary + '; button-down and Release-Press are stubs')
  # ---------- v4.5.0 (CU-CALL offline runtime) ----------
  $ccIdentityContext = [ordered]@{
    CallerLabel = "runner`r`nblue"
    CallerSessionId = ('S' * 130)
    IdentitySource = 'selftest-explicit'
  }
  $ccIdentity = Get-DtxCallIdentity $ccIdentityContext
  $ccTarget = Get-DtxCallTargetSummary 'read-text' @('title:private selector words', 'PRIVATE-ARGS-DO-NOT-LOG')
  ST-Check 'unit (CU-CALL): identity is constrained and sourced, while selector and full arguments are replaced by a bounded hash summary' (
    ([string]$ccIdentity.CallerLabel -ceq 'runner blue') -and
    ([string]$ccIdentity.CallerSessionId -ceq ('S' * 96)) -and
    ([string]$ccIdentity.IdentitySource -ceq 'selftest-explicit') -and
    ($ccTarget -match '^selector-kind=title;selector-sha256=[0-9a-f]{16}$') -and
    (-not $ccTarget.Contains('private selector words')) -and (-not $ccTarget.Contains('PRIVATE-ARGS-DO-NOT-LOG')))
  $ccCurrentPid = [Diagnostics.Process]::GetCurrentProcess().Id
  $ccBirth = Get-DtxCallProcessBirth ([int]$ccCurrentPid)
  $ccLiveRecord = [pscustomobject]@{ tool_pid = [int]$ccCurrentPid; tool_process_start_filetime = [string]$ccBirth.FileTime }
  $ccReusedRecord = [pscustomobject]@{ tool_pid = [int]$ccCurrentPid; tool_process_start_filetime = '0' }
  $ccLiveState = Get-DtxCallProcessState $ccLiveRecord
  $ccReusedState = Get-DtxCallProcessState $ccReusedRecord
  ST-Check 'unit (CU-CALL): process birth FILETIME distinguishes this live process from a reused PID' (
    ($ccLiveState -ceq 'alive') -and ($ccReusedState -ceq 'pid-reused'))

  $ccRoot = Join-Path $env:TEMP ('dtx-cucall-selftest-' + [guid]::NewGuid().ToString('N'))
  $ccOwnRoot = $false
  $ccCleanupOk = $true
  $ccRuntimeOk = $false
  $ccRuntimeSummary = 'runtime-probe-not-run'
  $ccOldConsoleError = [Console]::Error
  $ccErrorBuffer = New-Object System.IO.StringWriter
  $ccFirstLease = $null; $ccSecondLease = $null; $ccRecoveryLease = $null
  try {
    $ccExpectedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92) + [IO.Path]::DirectorySeparatorChar
    $ccFullRoot = [IO.Path]::GetFullPath($ccRoot)
    if (-not $ccFullRoot.StartsWith($ccExpectedTemp, [StringComparison]::OrdinalIgnoreCase)) { throw 'CU-CALL probe path is outside system temp' }
    if (-not ([IO.Path]::GetFileName($ccFullRoot)).StartsWith('dtx-cucall-selftest-', [StringComparison]::OrdinalIgnoreCase)) { throw 'CU-CALL probe root is not uniquely owned' }
    if (Test-Path -LiteralPath $ccFullRoot) { throw 'unique CU-CALL probe root unexpectedly exists' }
    New-Item -Path $ccFullRoot -ItemType Directory -ErrorAction Stop | Out-Null
    $ccOwnRoot = $true
    $ccParent = [pscustomobject]@{ ParentPid = 0; ParentName = 'unknown'; ParentStartUtc = ''; ParentStartFileTime = ''; Known = $false }
    $ccContext = [ordered]@{
      RootBase = $ccFullRoot
      WindowsSessionId = '777'
      DesktopName = 'Default'
      CallerLabel = 'CU-CALL-test'
      CallerSessionId = 'same-session-1234'
      IdentitySource = 'selftest-explicit'
      ParentInfo = $ccParent
      SourcePath = 'D:\synthetic\desktop.ps1'
      ToolVersion = '4.5.0'
    }
    [Console]::SetError($ccErrorBuffer)
    $ccFirstLease = Start-DtxCallTracking 'read-text' @('title:private selector words', 'PRIVATE-ARGS-DO-NOT-LOG') $ccContext
    $ccSecondLease = Start-DtxCallTracking 'read-text' @('title:second private selector') $ccContext
    $ccOverlapWarning = $ccErrorBuffer.ToString()
    if (($null -eq $ccFirstLease) -or ($null -eq $ccSecondLease)) { throw 'same-process registration did not return both leases' }
    Complete-DtxCallTracking $ccSecondLease 'completed' 0 ''
    $ccSecondLease = $null
    Complete-DtxCallTracking $ccFirstLease 'completed' 0 ''
    $ccFirstLease = $null

    # Simulate the recovery reader winning after the completed active file is visible but before
    # the original completion writer appends. The completion writer must observe the same ID.
    $ccRecoveryLease = Start-DtxCallTracking 'info' @() $ccContext
    if ($null -eq $ccRecoveryLease) { throw 'recovery-race fixture did not register' }
    $ccRecoveryRecord = $ccRecoveryLease.Record
    $ccRecoveryRecord.status = 'complete'
    $ccRecoveryRecord.ended_utc = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    $ccRecoveryRecord.duration_ms = 0
    $ccRecoveryRecord.result_category = 'observed-during-recovery'
    $ccRecoveryRecord.exit_code = $null
    $ccRecoveryRecord.end_time_kind = 'observed-during-recovery'
    $ccRecoveryRecord.internal_token_sha256 = ''
    Write-DtxCallAtomicJson ([string]$ccRecoveryLease.ActivePath) $ccRecoveryRecord
    Write-DtxCallHistory $ccRecoveryRecord ([string]$ccRecoveryLease.HistoryRoot)
    Complete-DtxCallTracking $ccRecoveryLease 'completed' 0 ''
    $ccRecoveryLease = $null

    $ccStateRoot = Join-Path (Join-Path (Join-Path $ccFullRoot 'AgentComputerUse\runtime\v1') '777') ('desktop-' + (Get-DtxCallSha256 'Default').Substring(0, 16))
    $ccActiveRoot = Join-Path $ccStateRoot 'active'
    $ccHistoryRoot = Join-Path $ccStateRoot 'history'
    $ccRows = @()
    foreach ($ccPath in @([IO.Directory]::GetFiles($ccHistoryRoot, 'calls-*.jsonl'))) {
      foreach ($ccLine in [IO.File]::ReadAllLines($ccPath, [Text.Encoding]::UTF8)) {
        if ($ccLine.Length -gt 0) { $ccRows += (ConvertFrom-Json -InputObject $ccLine -ErrorAction Stop) }
      }
    }
    $ccDuplicateIds = @($ccRows | Group-Object -Property invocation_id | Where-Object { $_.Count -ne 1 })
    $ccRawHistory = @($ccRows | ForEach-Object { ConvertTo-Json -InputObject $_ -Depth 8 -Compress }) -join "`n"
    $ccActiveRemainder = @([IO.Directory]::GetFiles($ccActiveRoot, '*.json')).Count
    $ccRuntimeOk = ($ccOverlapWarning.Contains('desktop tool overlap:')) -and
      ($ccOverlapWarning.Contains('caller=CU-CALL-test')) -and ($ccOverlapWarning.Contains('session=same-ses')) -and
      (@($ccRows).Count -eq 3) -and (@($ccDuplicateIds).Count -eq 0) -and
      (@($ccRows | Where-Object { $_.status -cne 'complete' }).Count -eq 0) -and ($ccActiveRemainder -eq 0) -and
      (-not $ccRawHistory.Contains('private selector words')) -and (-not $ccRawHistory.Contains('PRIVATE-ARGS-DO-NOT-LOG'))
    $ccRuntimeSummary = 'same-label-overlap=' + $ccOverlapWarning.Contains('desktop tool overlap:') +
      ';history-records=' + @($ccRows).Count + ';duplicate-ids=' + @($ccDuplicateIds).Count +
      ';active-residue=' + $ccActiveRemainder + ';raw-args-absent=' + (-not $ccRawHistory.Contains('PRIVATE-ARGS-DO-NOT-LOG'))
  } catch {
    $ccRuntimeSummary = 'runtime-probe-error=' + $_.Exception.Message
  } finally {
    foreach ($ccLease in @($ccRecoveryLease, $ccSecondLease, $ccFirstLease)) {
      if ($null -ne $ccLease) { try { Complete-DtxCallTracking $ccLease 'selftest-cleanup' 1 'probe-cleanup' } catch { } }
    }
    [Console]::SetError($ccOldConsoleError)
    $ccErrorBuffer.Dispose()
    if ($ccOwnRoot) {
      $ccFullRoot = [IO.Path]::GetFullPath($ccRoot)
      $ccExpectedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92) + [IO.Path]::DirectorySeparatorChar
      if ($ccFullRoot.StartsWith($ccExpectedTemp, [StringComparison]::OrdinalIgnoreCase) -and
          ([IO.Path]::GetFileName($ccFullRoot)).StartsWith('dtx-cucall-selftest-', [StringComparison]::OrdinalIgnoreCase)) {
        try { Remove-Item -LiteralPath $ccFullRoot -Recurse -Force -ErrorAction Stop } catch { $ccCleanupOk = $false; $ccRuntimeSummary += ';cleanup-error=' + $_.Exception.Message }
      } else { $ccCleanupOk = $false; $ccRuntimeSummary += ';cleanup-refused-outside-owned-root' }
    }
  }
  ST-Check 'e2e (CU-CALL): same-label independent invocation warns, completion/recovery appends each invocation once, active leases close, and raw selector/arguments stay out of history' ($ccRuntimeOk -and $ccCleanupOk)
  Write-Output ('      CU-CALL owned-root probe: ' + $ccRuntimeSummary + '; cleanup-ok=' + $ccCleanupOk)

  $ccKillRoot = Join-Path $env:TEMP ('dtx-cucall-kill-selftest-' + [guid]::NewGuid().ToString('N'))
  $ccKillOwned = $false
  $ccKillOk = $false
  $ccKillSummary = 'strong-kill-probe-not-run'
  $ccKillSingleFile = ("$script:StSourceMode" -ceq 'single-file')
  $ccHolderProcess = $null; $ccRecoveryProcess = $null
  try {
    if ($ccKillSingleFile) { throw 'single-file layout carries no lib\caller-runtime.ps1 for the owned worker' }
    $ccExpectedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92) + [IO.Path]::DirectorySeparatorChar
    $ccFullKillRoot = [IO.Path]::GetFullPath($ccKillRoot)
    if (-not $ccFullKillRoot.StartsWith($ccExpectedTemp, [StringComparison]::OrdinalIgnoreCase)) { throw 'strong-kill fixture is outside system temp' }
    if (-not ([IO.Path]::GetFileName($ccFullKillRoot)).StartsWith('dtx-cucall-kill-selftest-', [StringComparison]::OrdinalIgnoreCase)) { throw 'strong-kill fixture is not uniquely owned' }
    if (Test-Path -LiteralPath $ccFullKillRoot) { throw 'unique strong-kill fixture unexpectedly exists' }
    New-Item -Path $ccFullKillRoot -ItemType Directory -ErrorAction Stop | Out-Null
    $ccKillOwned = $true
    $ccKillWorkerText = @'
param([string]$Module,[string]$RootBase,[string]$Mode,[string]$Ready)
$ErrorActionPreference = 'Stop'
. $Module
foreach ($n in @('DTX_CALL_INTERNAL_PARENT_ID','DTX_CALL_INTERNAL_PARENT_PID','DTX_CALL_INTERNAL_PARENT_START_FILETIME','DTX_CALL_INTERNAL_PARENT_TOKEN')) { [Environment]::SetEnvironmentVariable($n, '', 'Process') }
$parent = [pscustomobject]@{ ParentPid = 0; ParentName = 'unknown'; ParentStartUtc = ''; ParentStartFileTime = ''; Known = $false }
$ctx = [ordered]@{ RootBase = $RootBase; WindowsSessionId = '780'; DesktopName = 'Synthetic-Test'; CallerLabel = 'CU-CALL-fixture'; CallerSessionId = 'strong-kill'; IdentitySource = 'fixture'; ParentInfo = $parent; SourcePath = 'D:\synthetic\worker.ps1'; ToolVersion = '4.5.0' }
$lease = Start-DtxCallTracking 'script' @() $ctx
if ($null -eq $lease) { Write-Output 'register-failed'; exit 31 }
if ($Mode -ceq 'hold') { [IO.File]::WriteAllText($Ready, [string]$lease.ActivePath, (New-Object Text.UTF8Encoding($false))); while ($true) { Start-Sleep -Milliseconds 40 } }
$id = [string]$lease.Record.invocation_id
Complete-DtxCallTracking $lease 'completed' 0 ''
Write-Output ('once=' + $id)
exit 0
'@
    $ccKillWorker = Join-Path $ccFullKillRoot 'owned-worker.ps1'
    [IO.File]::WriteAllText($ccKillWorker, $ccKillWorkerText, (New-Object Text.UTF8Encoding($false)))
    $ccKillModule = Join-Path (Split-Path -Parent $script:ToolEntryPath) 'lib\caller-runtime.ps1'
    $ccKillReady = Join-Path $ccFullKillRoot 'ready.marker'
    $ccKillEngine = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if (-not $ccKillEngine -or -not (Test-Path -LiteralPath $ccKillEngine)) { throw 'strong-kill engine path unavailable' }
    $ccStartWorker = {
      param([string]$Mode, [string]$Ready)
      $ccWorkerArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$ccKillWorker,'-Module',$ccKillModule,'-RootBase',(Join-Path $ccFullKillRoot 'shared-state'),'-Mode',$Mode,'-Ready',$Ready)
      $ccPsi = New-Object Diagnostics.ProcessStartInfo
      $ccPsi.FileName = $ccKillEngine
      $ccPsi.Arguments = (@($ccWorkerArgs | ForEach-Object { '"' + [string]$_ + '"' }) -join ' ')
      $ccPsi.UseShellExecute = $false; $ccPsi.CreateNoWindow = $true
      $ccPsi.RedirectStandardOutput = $true; $ccPsi.RedirectStandardError = $true
      $ccProc = New-Object Diagnostics.Process; $ccProc.StartInfo = $ccPsi
      if (-not $ccProc.Start()) { throw ('could not start owned fixture mode=' + $Mode) }
      return [pscustomobject]@{ Process = $ccProc; OutTask = $ccProc.StandardOutput.ReadToEndAsync(); ErrTask = $ccProc.StandardError.ReadToEndAsync() }
    }
    $ccHolder = & $ccStartWorker 'hold' $ccKillReady
    $ccHolderProcess = $ccHolder.Process
    $ccWait = [Diagnostics.Stopwatch]::StartNew()
    while ((-not (Test-Path -LiteralPath $ccKillReady)) -and (-not $ccHolderProcess.HasExited) -and $ccWait.ElapsedMilliseconds -lt 12000) { Start-Sleep -Milliseconds 25 }
    if (-not (Test-Path -LiteralPath $ccKillReady)) { throw 'owned child did not publish its active lease before timeout' }
    $ccHolderPid = [int]$ccHolderProcess.Id
    $ccActiveFixture = [IO.File]::ReadAllText($ccKillReady)
    $ccHadActiveFixture = Test-Path -LiteralPath $ccActiveFixture
    $ccHolderProcess.Kill()
    if (-not $ccHolderProcess.WaitForExit(12000)) { throw 'owned child did not exit after its own fixture kill' }
    $ccHolderExit = [int]$ccHolderProcess.ExitCode
    $ccHolderOut = [string]$ccHolder.OutTask.Result
    $ccHolderErr = [string]$ccHolder.ErrTask.Result
    $ccHolderProcess.Dispose(); $ccHolderProcess = $null
    $ccRecovery = & $ccStartWorker 'once' (Join-Path $ccFullKillRoot 'unused')
    $ccRecoveryProcess = $ccRecovery.Process
    if (-not $ccRecoveryProcess.WaitForExit(15000)) { try { $ccRecoveryProcess.Kill() } catch { }; throw 'post-kill recovery invocation timed out' }
    $ccRecoveryExit = [int]$ccRecoveryProcess.ExitCode
    $ccRecoveryOut = [string]$ccRecovery.OutTask.Result
    $ccRecoveryErr = [string]$ccRecovery.ErrTask.Result
    $ccRecoveryProcess.Dispose(); $ccRecoveryProcess = $null
    $ccKillState = Join-Path (Join-Path (Join-Path $ccFullKillRoot 'shared-state\AgentComputerUse\runtime\v1') '780') ('desktop-' + (Get-DtxCallSha256 'Synthetic-Test').Substring(0, 16))
    $ccKilledRows = @()
    foreach ($ccHistoryPath in @([IO.Directory]::GetFiles((Join-Path $ccKillState 'history'), 'calls-*.jsonl'))) {
      foreach ($ccLine in [IO.File]::ReadAllLines($ccHistoryPath, [Text.Encoding]::UTF8)) { if ($ccLine.Length -gt 0) { $ccKilledRows += (ConvertFrom-Json -InputObject $ccLine -ErrorAction Stop) } }
    }
    $ccRecoveredRow = @($ccKilledRows | Where-Object { ([int]$_.tool_pid -eq $ccHolderPid) -and ([string]$_.result_category -ceq 'process-disappeared-observed') })
    $ccKillActivePath = Join-Path $ccKillState 'active'
    $ccKillActiveRemainder = @([IO.Directory]::GetFiles($ccKillActivePath, '*.json')).Count
    $ccKillOk = $ccHadActiveFixture -and ($ccHolderExit -ne 0) -and ($ccRecoveryExit -eq 0) -and
      ($ccHolderOut.Length -eq 0) -and ($ccHolderErr.Length -eq 0) -and ($ccRecoveryErr.Length -eq 0) -and
      ($ccRecoveryOut.Contains('once=')) -and (@($ccKilledRows).Count -eq 2) -and (@($ccRecoveredRow).Count -eq 1) -and
      ($ccKillActiveRemainder -eq 0)
    $ccKillSummary = 'holder-active=' + $ccHadActiveFixture + ';holder-exit=' + $ccHolderExit +
      ';recovery-exit=' + $ccRecoveryExit + ';history=' + @($ccKilledRows).Count +
      ';recovered=' + @($ccRecoveredRow).Count + ';active-residue=' + $ccKillActiveRemainder
  } catch {
    $ccKillSummary = 'strong-kill-error=' + $_.Exception.Message
  } finally {
    foreach ($ccProc in @($ccRecoveryProcess, $ccHolderProcess)) {
      if ($null -ne $ccProc) { if (-not $ccProc.HasExited) { try { $ccProc.Kill(); [void]$ccProc.WaitForExit(5000) } catch { } }; try { $ccProc.Dispose() } catch { } }
    }
    if ($ccKillOwned) {
      $ccFullKillRoot = [IO.Path]::GetFullPath($ccKillRoot)
      $ccExpectedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92) + [IO.Path]::DirectorySeparatorChar
      if ($ccFullKillRoot.StartsWith($ccExpectedTemp, [StringComparison]::OrdinalIgnoreCase) -and
          ([IO.Path]::GetFileName($ccFullKillRoot)).StartsWith('dtx-cucall-kill-selftest-', [StringComparison]::OrdinalIgnoreCase)) {
        try { Remove-Item -LiteralPath $ccFullKillRoot -Recurse -Force -ErrorAction Stop } catch { $ccKillOk = $false; $ccKillSummary += ';cleanup-error=' + $_.Exception.Message }
      } else { $ccKillOk = $false; $ccKillSummary += ';cleanup-refused-outside-owned-root' }
    }
  }
  # Two arms, one name, inline literals (the static index only sees literal arguments): the owned
  # worker is launched against lib\caller-runtime.ps1 beside the entry, which the stitched
  # single-file layout does not have - there the e2e SKIPs under its own name with the measured
  # reason and stays pinned on the aggregate face (A-16/A-23 precedent).
  if ($ccKillSingleFile) {
    ST-Skip 'e2e (CU-CALL): a killed owned child remains active until the next invocation recovers its exact process birth and closes it once' 'single-file layout: the installed artifact has no lib\caller-runtime.ps1 beside the entry, so the owned-worker fixture cannot launch - this recovery e2e is pinned on the aggregate face'
  } else {
    ST-Check 'e2e (CU-CALL): a killed owned child remains active until the next invocation recovers its exact process birth and closes it once' $ccKillOk
  }
  Write-Output ('      CU-CALL strong-kill recovery: ' + $ccKillSummary)

  $ccHistoryRoot = Join-Path $env:TEMP ('dtx-cucall-history-selftest-' + [guid]::NewGuid().ToString('N'))
  $ccHistoryOwnRoot = $false
  $ccHistoryOk = $false
  $ccHistorySummary = 'history-fixture-not-run'
  try {
    $ccExpectedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92) + [IO.Path]::DirectorySeparatorChar
    $ccFullHistoryRoot = [IO.Path]::GetFullPath($ccHistoryRoot)
    if (-not $ccFullHistoryRoot.StartsWith($ccExpectedTemp, [StringComparison]::OrdinalIgnoreCase)) { throw 'history fixture is outside system temp' }
    if (-not ([IO.Path]::GetFileName($ccFullHistoryRoot)).StartsWith('dtx-cucall-history-selftest-', [StringComparison]::OrdinalIgnoreCase)) { throw 'history fixture is not uniquely owned' }
    if (Test-Path -LiteralPath $ccFullHistoryRoot) { throw 'unique history fixture unexpectedly exists' }
    New-Item -Path $ccFullHistoryRoot -ItemType Directory -ErrorAction Stop | Out-Null
    $ccHistoryOwnRoot = $true
    $ccDay = [DateTime]::UtcNow.ToString('yyyyMMdd', [Globalization.CultureInfo]::InvariantCulture)
    $ccFullSegment = Join-Path $ccFullHistoryRoot ('calls-' + $ccDay + '-0001.jsonl')
    $ccSeed = New-Object byte[] 4194300
    $ccSeedStream = [IO.File]::Open($ccFullSegment, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $ccSeedStream.Write($ccSeed, 0, $ccSeed.Length) } finally { $ccSeedStream.Dispose() }
    $ccRotationRecord = [pscustomobject]@{ invocation_id = [guid]::NewGuid().ToString('N'); started_utc = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture); status = 'complete'; result_category = 'completed' }
    Write-DtxCallHistory $ccRotationRecord $ccFullHistoryRoot
    $ccOversizeRejected = $false
    try {
      $ccOversize = [pscustomobject]@{ invocation_id = [guid]::NewGuid().ToString('N'); started_utc = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture); status = 'complete'; padding = ('P' * 17000) }
      Write-DtxCallHistory $ccOversize $ccFullHistoryRoot
    } catch { $ccOversizeRejected = $_.Exception.Message.Contains('16 KiB') }
    $ccSegments = @([IO.Directory]::GetFiles($ccFullHistoryRoot, 'calls-*.jsonl'))
    $ccSecondSegment = Join-Path $ccFullHistoryRoot ('calls-' + $ccDay + '-0002.jsonl')
    $ccSecondLines = @()
    if (Test-Path -LiteralPath $ccSecondSegment) { $ccSecondLines = @([IO.File]::ReadAllLines($ccSecondSegment, [Text.Encoding]::UTF8)) }
    $ccHistoryOk = ($ccSegments.Count -eq 2) -and (([IO.FileInfo]$ccFullSegment).Length -eq 4194300) -and
      (Test-Path -LiteralPath $ccSecondSegment) -and ($ccSecondLines.Count -eq 1) -and
      ($ccSecondLines[0].Length -le 16384) -and $ccOversizeRejected
    $ccHistorySummary = 'segments=' + $ccSegments.Count + ';old-bytes=' + ([IO.FileInfo]$ccFullSegment).Length +
      ';new-lines=' + $ccSecondLines.Count + ';oversize-rejected=' + $ccOversizeRejected
  } catch {
    $ccHistorySummary = 'history-fixture-error=' + $_.Exception.Message
  } finally {
    if ($ccHistoryOwnRoot -and (Test-Path -LiteralPath $ccHistoryRoot)) {
      $ccFullHistoryRoot = [IO.Path]::GetFullPath($ccHistoryRoot)
      $ccExpectedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92) + [IO.Path]::DirectorySeparatorChar
      if ($ccFullHistoryRoot.StartsWith($ccExpectedTemp, [StringComparison]::OrdinalIgnoreCase) -and
          ([IO.Path]::GetFileName($ccFullHistoryRoot)).StartsWith('dtx-cucall-history-selftest-', [StringComparison]::OrdinalIgnoreCase)) {
        try { Remove-Item -LiteralPath $ccFullHistoryRoot -Recurse -Force -ErrorAction Stop } catch { $ccHistoryOk = $false; $ccHistorySummary += ';cleanup-error=' + $_.Exception.Message }
      } else { $ccHistoryOk = $false; $ccHistorySummary += ';cleanup-refused-outside-owned-root' }
    }
  }
  ST-Check 'e2e (CU-CALL): history rolls before the 4 MiB segment limit and rejects a record above 16 KiB without adding a segment' $ccHistoryOk
  Write-Output ('      CU-CALL history bounds: ' + $ccHistorySummary)

  $ccBoundaryRoot = Join-Path $env:TEMP ('dtx-cucall-boundary-selftest-' + [guid]::NewGuid().ToString('N'))
  $ccBoundaryOwned = $false
  $ccBoundaryOk = $false
  $ccBoundarySummary = 'state-boundary-probe-not-run'
  $ccBoundaryBuffer = New-Object System.IO.StringWriter
  $ccBoundaryOldError = [Console]::Error
  $ccLockStream = $null; $ccCorruptLease = $null
  try {
    $ccExpectedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92) + [IO.Path]::DirectorySeparatorChar
    $ccFullBoundaryRoot = [IO.Path]::GetFullPath($ccBoundaryRoot)
    if (-not $ccFullBoundaryRoot.StartsWith($ccExpectedTemp, [StringComparison]::OrdinalIgnoreCase)) { throw 'state boundary fixture is outside system temp' }
    if (-not ([IO.Path]::GetFileName($ccFullBoundaryRoot)).StartsWith('dtx-cucall-boundary-selftest-', [StringComparison]::OrdinalIgnoreCase)) { throw 'state boundary fixture is not uniquely owned' }
    if (Test-Path -LiteralPath $ccFullBoundaryRoot) { throw 'unique state boundary fixture unexpectedly exists' }
    New-Item -Path $ccFullBoundaryRoot -ItemType Directory -ErrorAction Stop | Out-Null
    $ccBoundaryOwned = $true
    $ccBoundaryState = Join-Path (Join-Path (Join-Path $ccFullBoundaryRoot 'AgentComputerUse\runtime\v1') '778') ('desktop-' + (Get-DtxCallSha256 'Default').Substring(0, 16))
    $ccBoundaryActive = Join-Path $ccBoundaryState 'active'
    $ccBoundaryHistory = Join-Path $ccBoundaryState 'history'
    New-Item -Path $ccBoundaryActive -ItemType Directory -Force | Out-Null
    New-Item -Path $ccBoundaryHistory -ItemType Directory -Force | Out-Null
    $ccBoundaryLock = Join-Path $ccBoundaryState 'state.lock'
    $ccLockStream = [IO.File]::Open($ccBoundaryLock, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $ccBoundaryParent = [pscustomobject]@{ ParentPid = 0; ParentName = 'unknown'; ParentStartUtc = ''; ParentStartFileTime = ''; Known = $false }
    $ccBoundaryContext = [ordered]@{ RootBase = $ccFullBoundaryRoot; WindowsSessionId = '778'; DesktopName = 'Default'; CallerLabel = 'unknown'; CallerSessionId = 'unknown'; ParentInfo = $ccBoundaryParent; SourcePath = 'D:\synthetic\unknown.ps1'; ToolVersion = '4.5.0' }
    [Console]::SetError($ccBoundaryBuffer)
    $ccTimedOutLease = Start-DtxCallTracking 'info' @() $ccBoundaryContext
    $ccLockWarning = $ccBoundaryBuffer.ToString()
    $ccLockStream.Dispose(); $ccLockStream = $null
    [IO.File]::WriteAllText((Join-Path $ccBoundaryActive 'corrupt-active.json'), '{', (New-Object Text.UTF8Encoding($false)))
    $ccCorruptLease = Start-DtxCallTracking 'info' @() $ccBoundaryContext
    $ccCorruptRegistered = ($null -ne $ccCorruptLease)
    $ccCorruptWarning = $ccBoundaryBuffer.ToString()
    if ($null -ne $ccCorruptLease) { Complete-DtxCallTracking $ccCorruptLease 'completed' 0 ''; $ccCorruptLease = $null }
    $ccCorruptKept = ([IO.File]::ReadAllText((Join-Path $ccBoundaryActive 'corrupt-active.json')) -ceq '{')
    $ccRemaining = @([IO.Directory]::GetFiles($ccBoundaryActive, '*.json')).Count
    $ccBoundaryOk = ($null -eq $ccTimedOutLease) -and ($ccLockWarning.Contains('call-state=unknown reason=lock-timeout')) -and
      $ccCorruptRegistered -and $ccCorruptWarning.Contains('call-state=unknown; one or more state records could not be verified') -and
      $ccCorruptWarning.Contains('caller identity=unknown') -and $ccCorruptKept -and ($ccRemaining -eq 1)
    $ccBoundarySummary = 'lock-timeout=unknown;' + 'corrupt-preserved=' + $ccCorruptKept + ';identity-unknown=' + $ccCorruptWarning.Contains('caller identity=unknown') + ';active-json=' + $ccRemaining
  } catch {
    $ccBoundarySummary = 'state-boundary-error=' + $_.Exception.Message
  } finally {
    if ($null -ne $ccLockStream) { $ccLockStream.Dispose() }
    if ($null -ne $ccCorruptLease) { try { Complete-DtxCallTracking $ccCorruptLease 'selftest-cleanup' 1 'probe-cleanup' } catch { } }
    [Console]::SetError($ccBoundaryOldError)
    $ccBoundaryBuffer.Dispose()
    if ($ccBoundaryOwned) {
      $ccFullBoundaryRoot = [IO.Path]::GetFullPath($ccBoundaryRoot)
      $ccExpectedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92) + [IO.Path]::DirectorySeparatorChar
      if ($ccFullBoundaryRoot.StartsWith($ccExpectedTemp, [StringComparison]::OrdinalIgnoreCase) -and
          ([IO.Path]::GetFileName($ccFullBoundaryRoot)).StartsWith('dtx-cucall-boundary-selftest-', [StringComparison]::OrdinalIgnoreCase)) {
        try { Remove-Item -LiteralPath $ccFullBoundaryRoot -Recurse -Force -ErrorAction Stop } catch { $ccBoundaryOk = $false; $ccBoundarySummary += ';cleanup-error=' + $_.Exception.Message }
      } else { $ccBoundaryOk = $false; $ccBoundarySummary += ';cleanup-refused-outside-owned-root' }
    }
  }
  ST-Check 'e2e (CU-CALL): lock timeout and corrupt state report unknown without deleting evidence, and unknown identity is explicit' $ccBoundaryOk
  Write-Output ('      CU-CALL unknown-state handling: ' + $ccBoundarySummary)

  $ccDesktopRoot = Join-Path $env:TEMP ('dtx-cucall-desktop-selftest-' + [guid]::NewGuid().ToString('N'))
  $ccDesktopOwned = $false
  $ccDesktopOk = $false
  $ccDesktopSummary = 'desktop-isolation-probe-not-run'
  $ccDesktopBuffer = New-Object System.IO.StringWriter
  $ccDesktopOldError = [Console]::Error
  $ccDefaultLease = $null; $ccOtherDesktopLease = $null
  try {
    $ccExpectedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92) + [IO.Path]::DirectorySeparatorChar
    $ccFullDesktopRoot = [IO.Path]::GetFullPath($ccDesktopRoot)
    if (-not $ccFullDesktopRoot.StartsWith($ccExpectedTemp, [StringComparison]::OrdinalIgnoreCase)) { throw 'desktop fixture is outside system temp' }
    if (-not ([IO.Path]::GetFileName($ccFullDesktopRoot)).StartsWith('dtx-cucall-desktop-selftest-', [StringComparison]::OrdinalIgnoreCase)) { throw 'desktop fixture is not uniquely owned' }
    if (Test-Path -LiteralPath $ccFullDesktopRoot) { throw 'unique desktop fixture unexpectedly exists' }
    New-Item -Path $ccFullDesktopRoot -ItemType Directory -ErrorAction Stop | Out-Null
    $ccDesktopOwned = $true
    $ccDesktopParent = [pscustomobject]@{ ParentPid = 0; ParentName = 'unknown'; ParentStartUtc = ''; ParentStartFileTime = ''; Known = $false }
    $ccStationIdentityA = New-DtxCallDesktopIdentity 'WinSta0' 'Default'
    $ccStationIdentityB = New-DtxCallDesktopIdentity 'Service0' 'Default'
    $ccDesktopContext = [ordered]@{ RootBase = $ccFullDesktopRoot; WindowsSessionId = '779'; DesktopName = $ccStationIdentityA; CallerLabel = 'CU-CALL-test'; CallerSessionId = 'desktop-test'; IdentitySource = 'selftest-explicit'; ParentInfo = $ccDesktopParent; SourcePath = 'D:\synthetic\desktop.ps1'; ToolVersion = '4.5.0' }
    [Console]::SetError($ccDesktopBuffer)
    $ccDefaultLease = Start-DtxCallTracking 'info' @() $ccDesktopContext
    $ccDesktopContext.DesktopName = $ccStationIdentityB
    $ccOtherDesktopLease = Start-DtxCallTracking 'info' @() $ccDesktopContext
    $ccDesktopWarning = $ccDesktopBuffer.ToString()
    $ccDefaultState = Split-Path -Parent (Split-Path -Parent ([string]$ccDefaultLease.ActivePath))
    $ccOtherState = Split-Path -Parent (Split-Path -Parent ([string]$ccOtherDesktopLease.ActivePath))
    Complete-DtxCallTracking $ccOtherDesktopLease 'completed' 0 ''; $ccOtherDesktopLease = $null
    Complete-DtxCallTracking $ccDefaultLease 'completed' 0 ''; $ccDefaultLease = $null
    $ccDesktopOk = (-not $ccDesktopWarning.Contains('desktop tool overlap:')) -and
      ($ccStationIdentityA.Contains('window-station=WinSta0;desktop=Default')) -and
      ($ccStationIdentityB.Contains('window-station=Service0;desktop=Default')) -and
      ($ccDefaultState -cne $ccOtherState) -and ($ccDefaultState -match 'desktop-[0-9a-f]{16}') -and ($ccOtherState -match 'desktop-[0-9a-f]{16}')
    $ccDesktopSummary = 'overlap-warning=' + $ccDesktopWarning.Contains('desktop tool overlap:') + ';same-desktop-distinct-stations=' + ($ccDefaultState -cne $ccOtherState)
  } catch {
    $ccDesktopSummary = 'desktop-isolation-error=' + $_.Exception.Message
  } finally {
    foreach ($ccLease in @($ccOtherDesktopLease, $ccDefaultLease)) { if ($null -ne $ccLease) { try { Complete-DtxCallTracking $ccLease 'selftest-cleanup' 1 'probe-cleanup' } catch { } } }
    [Console]::SetError($ccDesktopOldError)
    $ccDesktopBuffer.Dispose()
    if ($ccDesktopOwned) {
      $ccFullDesktopRoot = [IO.Path]::GetFullPath($ccDesktopRoot)
      $ccExpectedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92) + [IO.Path]::DirectorySeparatorChar
      if ($ccFullDesktopRoot.StartsWith($ccExpectedTemp, [StringComparison]::OrdinalIgnoreCase) -and
          ([IO.Path]::GetFileName($ccFullDesktopRoot)).StartsWith('dtx-cucall-desktop-selftest-', [StringComparison]::OrdinalIgnoreCase)) {
        try { Remove-Item -LiteralPath $ccFullDesktopRoot -Recurse -Force -ErrorAction Stop } catch { $ccDesktopOk = $false; $ccDesktopSummary += ';cleanup-error=' + $_.Exception.Message }
      } else { $ccDesktopOk = $false; $ccDesktopSummary += ';cleanup-refused-outside-owned-root' }
    }
  }
  ST-Check 'e2e (CU-CALL): distinct desktop keys remain separate and do not warn across interactive desktops' $ccDesktopOk
  Write-Output ('      CU-CALL desktop isolation: ' + $ccDesktopSummary)
  # SUP-20261022-1820-J (item 7): every CU-CALL check above hands the tracker a fixture DesktopName
  # (:1302 :1396 :1548 :1601 :1604), so the real read path - Get-DtxCallDesktopName ->
  # Get-DtxCallObjectName -> [DT]::GetUserObjectInformation -> PtrToStringUni - had never been run by
  # any gate. Measured reason it needs one, on this machine 2026-10-22 with both engines: with the
  # default CharSet.Ansi binding the size probe returns the UNICODE byte size (needed=16 for
  # WinSta0/Default) while the A entry writes only the ANSI bytes (neededAfter=8), so the tail of the
  # allocation is never written - and PtrToStringUni searches for its terminating NUL with no bound,
  # so the scan can pass the end of the block this call owns: an OUT-OF-BOUNDS READ, undefined
  # behaviour, and what it reads and how far are set by whatever the heap holds at that moment.
  # Measured on this tree, not copied (block end ruled by _msize, scan clamped by VirtualQuery): 200
  # trips per cell straight against the two bindings -> the A binding passed the owned end on 62/200
  # trips on 5.1 and 73/200 on pwsh 7.6.7 (worst single overshoot 8 and 62 bytes), the Unicode binding
  # 0/200 on both. 40 trips through the real path, three runs of one revision of the ruler: as
  # committed 1 identity and 1 desktop-<sha16> key on both engines (40/40 every run); with the CharSet
  # removed 26/23/26 distinct identities on 5.1 and 40/40/40 on 7.6.7, and trips that came back at the
  # CORRECT length 38 over garbage: 18/1/2 of 40 on 5.1. That spread is what the last paragraph is for.
  # 5.1.26100.9711 decoded 5 units (station) and 7 (desktop) in one run and different bytes in the
  # next; pwsh 7.6.7 decoded 4 and 4. The value is not stable between runs of one engine, and the two
  # runtime records written 8.148 s apart in the same session id hashed to two different
  # desktop-<sha16> state directories - so the identity, not just the spelling, is what is protected.
  # Hence three separate teeth below: the whole identity string, the state key it produces, and the
  # per-object byte accounting (neededAfter must equal needed, which fails deterministically under an
  # ANSI binding no matter what the stale heap happens to contain).
  # ACCEPTANCE CONDITION 5 (SUP-20261022-1905-K) sorts those teeth by how many trips decide them.
  # Red on ONE trip: the identity equality, the key equality, fullyWritten (after == needed).
  # Decidable only by REPEATING, >=20 real-path trips: that the scan stays inside the allocation - a
  # single trip only witnesses the bytes it happened to get. chars*2 + 2 == needed on its own is NOT
  # red-on-one-trip, it goes green whenever an overshoot stops at the right distance, so $ccOneNul
  # stays conjoined with the whole-string equality and fullyWritten rather than being read as a bound.
  # Never soften this check into a shape or length assertion, and never judge the overshoot from one
  # trip: measuring it means repeating many trips.
  $ccRealIdentity = $null
  $ccRealOk = $false
  $ccRealSummary = 'real-desktop-name-probe-not-run'
  try {
    $ccRealExpected = 'window-station=WinSta0;desktop=Default'
    $ccRealIdentity = [string](Get-DtxCallDesktopName)
    $ccRealKey = 'desktop-' + (Get-DtxCallSha256 $ccRealIdentity).Substring(0, 16)
    $ccExpectedKey = 'desktop-' + (Get-DtxCallSha256 $ccRealExpected).Substring(0, 16)
    $ccByteRows = @()
    $ccByteOk = $true
    $ccObjects = @([pscustomobject]@{ Name = 'station'; Handle = [DT]::GetProcessWindowStation() }, [pscustomobject]@{ Name = 'desktop'; Handle = [DT]::GetThreadDesktop([DT]::GetCurrentThreadId()) })
    foreach ($ccObj in $ccObjects) {
      $ccNeed = 0
      [void][DT]::GetUserObjectInformation($ccObj.Handle, 2, [IntPtr]::Zero, 0, [ref]$ccNeed)
      if (($ccNeed -lt 4) -or ($ccNeed -gt 2048)) { throw ('desktop name size unavailable: ' + $ccObj.Name + '=' + $ccNeed) }
      $ccBuf = [Runtime.InteropServices.Marshal]::AllocHGlobal($ccNeed)
      try {
        $ccAfter = 0
        [void][DT]::GetUserObjectInformation($ccObj.Handle, 2, $ccBuf, $ccNeed, [ref]$ccAfter)
        $ccText = [Runtime.InteropServices.Marshal]::PtrToStringUni($ccBuf)
        $ccAscii = (([regex]::Replace($ccText, '[^\x00-\x7F]', '')).Length -eq $ccText.Length)
        $ccOneNul = (((($ccText.Length * 2) + 2) -eq $ccNeed) -and ($ccText.Length -gt 0))
        $ccFull = ($ccAfter -eq $ccNeed)
        $ccByteOk = ($ccByteOk -and $ccAscii -and $ccOneNul -and $ccFull)
        $ccByteRows += ($ccObj.Name + ':needed=' + $ccNeed + ';after=' + $ccAfter + ';chars=' + $ccText.Length + ';oneNul=' + $ccOneNul + ';fullyWritten=' + $ccFull + ';ascii=' + $ccAscii)
      } finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($ccBuf) }
    }
    $ccRealOk = ($ccRealIdentity -ceq $ccRealExpected) -and ($ccRealKey -ceq $ccExpectedKey) -and $ccByteOk
    $ccShown = $(if ($ccRealIdentity -match '[^\x00-\x7F]') { 'units(' + $ccRealIdentity.Length + ')=' + (($ccRealIdentity.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ' ') } else { $ccRealIdentity })
    $ccRealSummary = 'identity=[' + $ccShown + '];key=' + $ccRealKey + ';expectedKey=' + $ccExpectedKey + ';' + ($ccByteRows -join ';')
  } catch {
    $ccRealOk = $false
    $ccRealSummary = 'real-desktop-name-error=' + $_.Exception.Message
  }
  ST-Check 'e2e (CU-CALL): the desktop identity read for real (no fixture DesktopName) is WinSta0/Default with byte-sized needed, one UTF-16 NUL and one state key' $ccRealOk
  Write-Output ('      CU-CALL real desktop identity: ' + $ccRealSummary)


  $ccEntryRaw = [IO.File]::ReadAllText($script:ToolEntryPath, [Text.Encoding]::UTF8)
  $ccStartIndex = $ccEntryRaw.IndexOf('$script:CallLease = Start-DtxCallTracking $Cmd $Rest', [StringComparison]::Ordinal)
  $ccJsonIndex = $ccEntryRaw.IndexOf('# Global --json', [StringComparison]::Ordinal)
  $ccReleaseIndex = $ccEntryRaw.IndexOf('$exitReleaseReceipt = Release-Press', [StringComparison]::Ordinal)
  $ccCompleteIndex = $ccEntryRaw.IndexOf('Complete-DtxCallTracking $script:CallLease', [StringComparison]::Ordinal)
  $ccLastPressCheck = $ccEntryRaw.LastIndexOf('if (Get-LeftButtonDown) {', [StringComparison]::Ordinal)
  $ccRuntimeSourceText = @($codeLines) -join "`n"
  $ccStationApiWired = $ccRuntimeSourceText.Contains('[DT]::GetProcessWindowStation()') -and
    $ccRuntimeSourceText.Contains('return New-DtxCallDesktopIdentity $stationName $desktopName')
  # Two arms, one name, inline literals: this wiring lint audits the SPLIT entry/lib layout, which
  # the stitched single-file artifact does not have - there it SKIPs under its own name (A-16/A-23
  # precedent) and the wiring stays pinned on the aggregate face.
  if ("$script:StSourceMode" -ceq 'single-file') {
    ST-Skip 'lint (CU-CALL): tracking registers before argument parsing and closes after the process-exit release path inside finally' 'single-file layout: no separate entry/lib split to audit - this wiring is pinned on the aggregate face'
  } else {
    ST-Check 'lint (CU-CALL): tracking registers before argument parsing and closes after the process-exit release path inside finally' (
      ($ccStartIndex -ge 0) -and ($ccJsonIndex -gt $ccStartIndex) -and
      ($ccReleaseIndex -gt $ccStartIndex) -and ($ccCompleteIndex -gt $ccReleaseIndex) -and ($ccCompleteIndex -gt $ccLastPressCheck) -and $ccStationApiWired)
  }

  # S-89: the two gates that parse a real child's --json stdout must also print it. Pinned as a wiring
  # shape - one producer, and every consumer labels the field it prints. G-23 added two more consumers
  # (the two planted shapes it pins), so the census is 2 child gates + 2 plants = 4, still an exact
  # equality: a consumer appearing unlabelled or vanishing still turns red.
  $fdTok = 'Format-JsonProbe' + 'Dump'
  $fdDefs = @($codeLines | Where-Object { ([string]$_).StartsWith('function ' + $fdTok) })
  $fdCalls = @($codeLines | Where-Object { ([string]$_).Contains($fdTok) -and -not ([string]$_).StartsWith('function ') })
  $fdMarks = @($codeLines | Where-Object { ([string]$_).Contains('child-std' + 'out=') })
  ST-Check 'lint (S-89): every selftest gate that parses a real child --json stdout also reports that stdout, so a red names the polluter instead of leaving the root cause to be re-guessed' (
    (@($fdDefs).Count -eq 1) -and (@($fdCalls).Count -eq 4) -and (@($fdMarks).Count -eq 2))
  Write-Output ('      S-89 probe dump: defs=' + @($fdDefs).Count + ' calls=' + @($fdCalls).Count +
    ' printed-fields=' + @($fdMarks).Count)
  # The whole safety property of an AUTOMATIC pass is that it moves. M6 in the mutation
  # rig (swap Move-Item for Copy-Item + Remove-Item) was only caught by the "one loop"
  # lint as a side effect, so the promise gets its own direct check: scan the mover's own
  # body for any deletion primitive.
  $mvStart = -1; $mvEnd = $codeLines.Count
  for ($mi = 0; $mi -lt $codeLines.Count; $mi++) {
    if ($codeLines[$mi] -match '^function Move-ShotsToQuarantine') { $mvStart = $mi; continue }
    if ($mvStart -ge 0 -and $mi -gt $mvStart -and $codeLines[$mi] -match '^function ') { $mvEnd = $mi; break }
  }
  $mvBody = ''
  if ($mvStart -ge 0) { $mvBody = ($codeLines[$mvStart..($mvEnd - 1)] -join "`n") }
  ST-Check 'lint: the quarantine mover contains no deletion primitive - an automatic pass may only move' (
    ($mvStart -ge 0) -and ($mvBody.Length -gt 200) -and (-not $mvBody.Contains('Remove-Item')) -and (-not $mvBody.Contains('Remove-ItemRecursively')) -and (-not $mvBody.Contains('[System.IO.File]::Delete')) -and (-not $mvBody.Contains('del ')))

  # ---------- v3.1.0 (P-05): the small-fix bundle, one check per claim ----------
  $iv0 = Get-ImeStateView 1 'T' 0
  $iv1 = Get-ImeStateView 1 'T' 1
  ST-Check 'unit (P-05): ime-state --json derives open from the mode - mode=0 says alphanumeric AND open=false (the row may not contradict its own text)' (
    ($iv0.open -eq $false) -and ($iv0.text -like '*alphanumeric*') -and ($iv1.open -eq $true) -and ($iv1.text -like '*native*'))
  $cpDead = 0; $cpLive = 0
  # the token is assembled at runtime: a scanner whose own source contains the literal it hunts
  # counts itself (measured - the first draft reported dead-pixel-assigns=1 with the code clean).
  $cpTok = '$cpPixel' + 'Hash'
  foreach ($cpL in $codeLines) {
    # comment lines are skipped: the fix left a prose note naming the dead variable.
    $cpT = "$cpL"
    if ($cpT.TrimStart().StartsWith('#')) { continue }
    if ($cpT.Contains($cpTok)) { $cpDead++ }
    if ($cpT.Contains('= Get-ChallengeIdentityHash ')) { $cpLive++ }
  }
  ST-Check 'lint (P-05): challenge-probe keeps no assigned-and-never-read pixel capture, and the identity hash it DOES use is still called twice (the scan cannot pass by being empty)' (
    ($cpDead -eq 0) -and ($cpLive -ge 2))
  Write-Output ('      challenge captures: dead-pixel-assigns=' + $cpDead + ' identity-sites=' + $cpLive)
  # v4.4.0 (A-15): this command's code may live in its handler now, so the promise is checked against
  # the command's code (case plus handler). The old scan read a pure move as a missing promise.
  $scBody = Get-CommandCodeText $codeLines 'shots-cleanup'
  ST-Check 'lint (P-05): shots-cleanup --go names its partial failure with ERROR: before exit 1 (the contract is exit code AND stdout, not one half)' (
    ($scBody.Contains('ERROR: shots-cleanup --go:')) -and ($scBody.Contains('if ($qRes.Failed -gt 0) {')))
  $mfTmp = Join-Path $env:TEMP ('dtx-mf-' + [guid]::NewGuid().ToString('N'))
  try {
    $mfSrc = Join-Path $mfTmp 'shots'
    $mfQ = Join-Path $mfTmp 'quar'
    [void](New-Item -ItemType Directory -Force -Path $mfSrc)
    [void](New-Item -ItemType Directory -Force -Path $mfQ)
    [System.IO.File]::WriteAllText((Join-Path $mfSrc 'a.png'), 'x')
    [System.IO.File]::WriteAllText((Join-Path $mfSrc 'a.png.map.txt'), "MFIRST-dtx-line`nsecond`n", (New-Object System.Text.UTF8Encoding($false)))
    $mfRes = Move-ShotsToQuarantine @(Get-ChildItem -LiteralPath $mfSrc -File) $mfQ 't_' '## t'
    $mfTxt = ''
    if (Test-Path -LiteralPath $mfRes.Manifest) { $mfTxt = (@(Get-Content -LiteralPath $mfRes.Manifest -Encoding UTF8) -join "`n") }
    ST-Check 'e2e (P-05): a quarantined .map.txt keeps its first line in the MANIFEST - the descriptor must read BEFORE the move (after it, the original path is gone)' (
      ($mfRes.Moved -eq 2) -and ($mfRes.Failed -eq 0) -and ($mfTxt.Contains('map sidecar (first line: MFIRST-dtx-line)')))
    if (-not $mfTxt.Contains('MFIRST-dtx-line')) { Write-Output ('      manifest row: ' + (($mfTxt -split "`n" | Where-Object { $_ -like '*map sidecar*' }) -join ' | ')) }
  } finally {
    if (Test-Path -LiteralPath $mfTmp) { [void](Remove-Item -LiteralPath $mfTmp -Recurse -Force) }
  }
  # production-scoped on purpose: the two literals below are also written into this check's own
  # source, so an unscoped scan counts the scanner (same self-reference the pixel-hash token had
  # to be assembled at runtime to dodge).
  $aeFive = 0; $aeThree = 0
  foreach ($aeL in $mvProd) {
    $aeT = "$aeL"
    if ($aeT.Contains($aeProbeTok)) { $aeFive++ }
    if ($aeT.Contains('Invoke-AutoPasteExpect $p $target (Get-AutoExpectNeedle $fi.Name)')) { $aeThree++ }
  }
  $aeDoc = ''
  $aeDocsSeen = 0
  # The documented asymmetry can live in either language edition: the published tree keeps
  # README.md in English plus a separate README.zh-CN.md, so the documentation half checks the
  # UNION of whichever READMEs exist. Measured: looking at README.md alone made this case
  # structurally red in the public tree at the v3.1.0 sync.
  foreach ($aeRd in @('README.md', 'README.zh-CN.md')) {
    $aeRdPath = Join-Path $script:ToolRootPath $aeRd
    if (Test-Path -LiteralPath $aeRdPath) { $aeDocsSeen++; $aeDoc += "`n" + (@(Get-Content -LiteralPath $aeRdPath -Encoding UTF8) -join "`n") }
  }
  # The README phrase is built from code points: this file must stay pure ASCII past its BOM
  # (a lint enforces exactly that, and it bit the first draft of this check).
  $aeNeedle = 'paste-file` ' + [string]::Join('', @([char]0x4E0D, [char]0x8D70, [char]0x8FD9, [char]0x6761, [char]0x8DEF))
  if ($aeDocsSeen -gt 0) {
    ST-Check 'lint (P-06): paste and paste-file differ in the receipt chain ON PURPOSE (paste passes the base and the length, paste-file passes neither) and the README still says so - a silent convergence would be a behaviour change' (
      ($aeFive -eq 1) -and ($aeThree -eq 1) -and ($aeDoc.Contains($aeNeedle)))
  } else {
    ST-Skip 'lint (P-06): paste and paste-file differ in the receipt chain ON PURPOSE (paste passes the base and the length, paste-file passes neither) and the README still says so - a silent convergence would be a behaviour change' 'no README found in this tree - nothing to cross-check the code shape against'
  }
  ST-Check 'unit: popup delta - empty baseline with a new opaque window triggers' (
    (Compare-PopupDelta @() @($wB)).HasNew -eq $true)
  ST-Check 'unit: popup delta - transparent-only after-set never triggers from an empty baseline' (
    (Compare-PopupDelta @() @($wT)).HasNew -eq $false)
  # v2.0.1 (owner ruling 2026-10-01, merge): the REVERSE direction of the same rule.
  # Teeth for each way the merge can be faked: an answered question that ignores the
  # handle it was given, an unanswered question that reads as 'yes', and presence read
  # off the transparent-filtered set (transparency suppresses the ALARM, not existence).
  $dWatchYes = Compare-PopupDelta @($wA) @($wA, $wB) $wA.Handle
  ST-Check 'unit: popup delta - a watched handle still in the after-set reads present=yes and echoes the handle it answered for' (
    ($dWatchYes.Present -eq 'yes') -and ([int64]$dWatchYes.Watch -eq 100))
  $dWatchNo = Compare-PopupDelta @($wA) @($wB) $wA.Handle
  ST-Check 'unit: popup delta - a watched handle missing from the after-set reads present=no (the survival direction the guard asks)' (
    $dWatchNo.Present -eq 'no')
  $dWatchNa = Compare-PopupDelta @($wA) @($wA, $wB)
  ST-Check 'unit: popup delta - nothing watched leaves the presence answer n/a, never yes' (
    ($dWatchNa.Present -eq 'n/a') -and ($null -eq $dWatchNa.Watch))
  $dWatchTip = Compare-PopupDelta @($wA) @($wA, $wT) $wT.Handle
  ST-Check 'unit: popup delta - a click-through popup raises no new-popup alarm but IS present (alarm filter is not an existence filter)' (
    ($dWatchTip.HasNew -eq $false) -and ($dWatchTip.Present -eq 'yes'))

  # ---------- lint: every STATIC regex literal in the file must COMPILE ----------
  # Why: a stray ')' inside a single-quoted pattern is syntactically valid PowerShell -
  # Parser::ParseFile says OK, the file runs, and the failure only appears the moment that
  # -match is evaluated, which for a live-only or rarely-hit branch means "works when I
  # try it". One typo did exactly that to the help index in this round.
  $rxBad = New-Object System.Collections.ArrayList
  $rxSeen = 0
  for ($ri = 0; $ri -lt $codeLines.Count; $ri++) {
    if ($codeLines[$ri] -match '^\s*#') { continue }
    foreach ($rm in [regex]::Matches($codeLines[$ri], "-(?:match|notmatch|replace|split)\s+'([^']*)'")) {
      $pat = $rm.Groups[1].Value
      if (-not $pat) { continue }
      $rxSeen++
      try { [void](New-Object System.Text.RegularExpressions.Regex $pat) }
      catch { [void]$rxBad.Add("line $(Format-SourceLineRef ($ri + 1)): pattern '$pat' -> $($_.Exception.Message)") }
    }
  }
  ST-Check 'lint: every static regex literal in the source compiles (>= 120 patterns scanned)' (
    $rxSeen -ge 120 -and @($rxBad).Count -eq 0)
  Write-Output "      regex literals scanned: $rxSeen"
  foreach ($rb in @($rxBad)) { Write-Output "      uncompilable regex: $rb" }
  # positive control: the scan must notice a broken pattern. The plant's pattern is built by
  # CONCATENATION so this file never contains an uncompilable regex literal (the first
  # version typed it inline and this very lint failed on its own control).
  $rxPlantPat = '(' + '[a-z)' + ')'
  $rxPlantLine = "  if ('x' -match '" + $rxPlantPat + "') { }"
  $rxPlantFound = $false
  $rxPlantCompiles = $true
  foreach ($rm in [regex]::Matches($rxPlantLine, "-(?:match|notmatch|replace|split)\s+'([^']*)'")) {
    $rxPlantFound = $true
    try { [void](New-Object System.Text.RegularExpressions.Regex $rm.Groups[1].Value) } catch { $rxPlantCompiles = $false }
  }
  ST-Check 'lint: the regex-compiles scan sees and rejects a planted broken pattern' (
    $rxPlantFound -and -not $rxPlantCompiles)

  # ---------- TB-3: the MANIFEST row is written while the loop is still running ----------
  # The card asks for an exception injected into the THIRD item, and for the files already moved to
  # still be traceable afterwards. What makes that measurable is a read the mover performs on the
  # third item BEFORE it touches that file: `$target = Join-Path $dest $m.Name`. A wrapper whose Name
  # read counts the rows already on the disk and then makes the MANIFEST unwritable is therefore both
  # the observer and the fault, in one deterministic place - no timing, no background job, nothing that
  # passes on a fast machine and fails on a slow one. The hoisted copy below is the same fixture run
  # against the pre-TB-3 shape (buffer rows, flush once after the loop) so the observer is shown to be
  # able to report zero: without it, midloop=2 would only prove the fixture wrote two rows somewhere.
  function ST-TB3HoistedMover($moveItems, [string]$quar, [string]$prefix, [string]$heading) {
    # Verbatim shape of the mover as it stood before TB-3: the rows accumulate in an ArrayList and ONE
    # AppendAllText after the loop writes them, unguarded. It is a planted copy, not the product.
    $items = @($moveItems)
    $dest = Join-Path $quar ($prefix + 'hoisted')
    [void](New-Item -ItemType Directory -Force -Path $dest)
    $manifest = Join-Path $quar 'MANIFEST.md'
    $logLines = New-Object System.Collections.ArrayList
    $movedN = 0; $failN = 0
    foreach ($m in $items) {
      $target = Join-Path $dest $m.Name
      try {
        $sha = (Get-FileHash -LiteralPath $m.FullName -Algorithm SHA256).Hash
        $mEntry = Get-QuarantineManifestEntry $m.FullName $target $sha $m
        Move-Item -LiteralPath $m.FullName -Destination $target -Force
        [void]$logLines.Add($mEntry)
        $movedN++
      } catch { $failN++ }
    }
    if ($logLines.Count -gt 0) {
      $header = ''
      if (-not (Test-Path -LiteralPath $manifest)) { $header = "# Cleanup manifest - $quar" + "`r`n`r`n" }
      $body = $header + ($heading + "`r`n`r`n") + (($logLines -join "`r`n") + "`r`n")
      [System.IO.File]::AppendAllText($manifest, $body, (New-Object System.Text.UTF8Encoding($false)))
    }
    return @{ Moved = $movedN; Failed = $failN; Dest = $dest; Manifest = $manifest }
  }
  $tb3Root = Join-Path $env:TEMP ('dtx-tb3-' + [guid]::NewGuid().ToString('N'))
  try {
    [void](New-Item -ItemType Directory -Force -Path $tb3Root)
    # one fixture builder, three quarantines: each run gets its own so the second-precision dest name
    # and the fresh-MANIFEST path cannot make one case read the other's rows.
    function ST-TB3Case([string]$tag, [string]$filePrefix) {
      $shots = Join-Path $tb3Root ($tag + '-shots')
      $quar = Join-Path $tb3Root ($tag + '-quar')
      [void](New-Item -ItemType Directory -Force -Path $shots)
      [void](New-Item -ItemType Directory -Force -Path $quar)
      $items = @()
      foreach ($n in @('m1', 'm2', 'm3', 'm4')) {
        $p = Join-Path $shots ($filePrefix + $n + '.png')
        [System.IO.File]::WriteAllBytes($p, (New-Object byte[] 40))
        $items += @(Get-Item -LiteralPath $p)
      }
      return @{ Shots = $shots; Quar = $quar; Items = $items; Manifest = (Join-Path $quar 'MANIFEST.md'); Observer = (Join-Path $tb3Root ($tag + '-observer.txt')) }
    }
    # Closures, not $this. A lifted family must read only names it binds, and lint (A-14b) caught the
    # first version of this wrapper on exactly that: `A-14b state gap: this=free-read-at-26165`
    # (tb3-cand/tb3cand.ps51.normal.stdout.txt:62) - $this is automatic for a ScriptProperty but is not
    # a binding this file can claim, and the gate is right to treat it as a reach outside the body.
    # tb3-fix-probe-{ps51,pwsh7}.txt measured the replacement: a closed ScriptProperty forwards
    # Name/FullName/Length identically on 5.1.26100.9711 and 7.6.7.
    function ST-TB3Wrap([object]$fx, [int]$at) {
      $tb3wItem = $fx.Items[$at]
      $tb3wManifest = [string]$fx.Manifest
      $tb3wObserver = [string]$fx.Observer
      $mid = [pscustomobject]@{ Item = $tb3wItem }
      $mid | Add-Member -MemberType ScriptProperty -Name FullName -Value ({ return [string]$tb3wItem.FullName }.GetNewClosure())
      $mid | Add-Member -MemberType ScriptProperty -Name Length -Value ({ return $tb3wItem.Length }.GetNewClosure())
      $mid | Add-Member -MemberType ScriptProperty -Name LastWriteTimeUtc -Value ({ return $tb3wItem.LastWriteTimeUtc }.GetNewClosure())
      $mid | Add-Member -MemberType ScriptProperty -Name CreationTimeUtc -Value ({ return $tb3wItem.CreationTimeUtc }.GetNewClosure())
      $mid | Add-Member -MemberType ScriptProperty -Name Name -Value ({
        # count, publish the count, THEN fault - so what the observer holds is the row census taken
        # while the mover was still inside its loop.
        $seen = 0
        $existed = Test-Path -LiteralPath $tb3wManifest
        if ($existed) { $seen = @(Get-Content -LiteralPath $tb3wManifest | Where-Object { $_ -match '^- \d{4}-' }).Count }
        [System.IO.File]::WriteAllText($tb3wObserver, ('midloop-rows=' + $seen), (New-Object System.Text.UTF8Encoding($false)))
        # A missing MANIFEST is created read-only instead of being skipped. SetAttributes on a path
        # that does not exist faults nothing: measured on the planted copy (tb3-cand stdout:596 printed
        # rowsOnDisk=4 with the flush succeeding), which is what made case 2 red. Creating the file is
        # what turns "no row has been written yet" into a write target that can actually be refused.
        if (-not $existed) { [System.IO.File]::WriteAllText($tb3wManifest, '', (New-Object System.Text.UTF8Encoding($false))) }
        [System.IO.File]::SetAttributes($tb3wManifest, [System.IO.FileAttributes]::ReadOnly)
        return [string]$tb3wItem.Name
      }.GetNewClosure())
      return $mid
    }
    function ST-TB3Rows([string]$manifest) {
      if (-not (Test-Path -LiteralPath $manifest)) { return @() }
      return @(Get-Content -LiteralPath $manifest | Where-Object { $_ -match '^- ' })
    }
    function ST-TB3Mid([string]$observer) {
      if (-not (Test-Path -LiteralPath $observer)) { return '<observer never ran>' }
      return [string]([System.IO.File]::ReadAllText($observer, [System.Text.Encoding]::UTF8))
    }
    function ST-TB3DestN([string]$dir) {
      if (-not (Test-Path -LiteralPath $dir)) { return 0 }
      return @(Get-ChildItem -LiteralPath $dir -File).Count
    }

    # ---- case 1: the real mover, fault injected into the third item ----
    $tb3a = ST-TB3Case 'a' 'a'
    $tb3a.Items[2] = ST-TB3Wrap $tb3a 2
    $tb3aRes = $null; $tb3aErr = ''
    try { $tb3aRes = Move-ShotsToQuarantine $tb3a.Items $tb3a.Quar 'tb3a_' '## tb3a fixture' } catch { $tb3aErr = ($_.Exception.Message -replace '\s+', ' ') }
    $tb3aRows = ST-TB3Rows $tb3a.Manifest
    $tb3aMovedRows = @($tb3aRows | Where-Object { $_ -match '^- \d{4}-' })
    $tb3aDest = @()
    if ($tb3aRes) { $tb3aDest = @(Get-ChildItem -LiteralPath $tb3aRes.Dest -File | ForEach-Object { [string]$_.Name }) }
    $tb3aLeft = @(Get-ChildItem -LiteralPath $tb3a.Shots -File | ForEach-Object { [string]$_.Name })
    ST-Check 'e2e (TB-3): the quarantine mover writes a file MANIFEST row as that file finishes, so with the row write faulting on the third item the first two rows are already on disk, the moved-but-unrecorded file is reported in its own field, and the fourth file is never touched' (
      ($null -ne $tb3aRes) -and ($tb3aErr -ceq '') -and ((ST-TB3Mid $tb3a.Observer) -ceq 'midloop-rows=2') -and ($tb3aRes.Moved -eq 3) -and ($tb3aRes.Failed -eq 0) -and
      (@($tb3aRes.Unrecorded).Count -eq 1) -and ($tb3aMovedRows.Count -eq 2) -and (@($tb3aDest | Where-Object { $_ -in @('am1.png', 'am2.png', 'am3.png') }).Count -eq 3) -and
      ($tb3aLeft -contains 'am4.png') -and (@($tb3aMovedRows | Where-Object { $_ -match 'am3\.png|am4\.png' }).Count -eq 0) -and
      ($tb3aMovedRows[0].Contains('am1.png') -and $tb3aMovedRows[1].Contains('am2.png')))
    Write-Output ('      TB-3 real mover: midloop=' + (ST-TB3Mid $tb3a.Observer) + ' Moved=' + $tb3aRes.Moved + '/' + $tb3aRes.Failed +
      ' Unrecorded=' + @($tb3aRes.Unrecorded).Count + ' rowsOnDisk=' + $tb3aMovedRows.Count +
      ' stillInShots=' + ($tb3aLeft -join ',') + ' err=[' + $tb3aErr + ']')

    # ---- case 2: the same fixture against the planted pre-TB-3 shape ----
    $tb3b = ST-TB3Case 'b' 'b'
    $tb3b.Items[2] = ST-TB3Wrap $tb3b 2
    $tb3bRes = $null; $tb3bErr = ''
    try { $tb3bRes = ST-TB3HoistedMover $tb3b.Items $tb3b.Quar 'tb3b_' '## tb3b fixture' } catch { $tb3bErr = ($_.Exception.Message -replace '\s+', ' ') }
    $tb3bRows = ST-TB3Rows $tb3b.Manifest
    # the dest census, not the returned counter: the planted copy can die on its own after-loop write,
    # and a run that died is exactly the case where reading its return would be the lie.
    $tb3bDestN = ST-TB3DestN (Join-Path $tb3b.Quar 'tb3b_hoisted')
    ST-Check 'e2e (TB-3): the observer is not vacuous - the planted hoisted-flush copy of the mover shows zero rows on the disk while its loop is still running, all four files leave the shots directory, and the single write after the loop is itself what faults, so the run dies with every move unrecorded' (
      ((ST-TB3Mid $tb3b.Observer) -ceq 'midloop-rows=0') -and ($tb3bDestN -eq 4) -and (@($tb3bRows).Count -eq 0) -and
      ($null -eq $tb3bRes) -and ($tb3bErr -ne ''))
    Write-Output ('      TB-3 planted copy: midloop=' + (ST-TB3Mid $tb3b.Observer) + ' destFiles=' + $tb3bDestN +
      ' rowsOnDisk=' + @($tb3bRows).Count + ' returned=' + [bool]$tb3bRes + ' unrecordedMoves=' + $tb3bDestN +
      ' escape=[' + $tb3bErr.Substring(0, [Math]::Min(60, $tb3bErr.Length)) + ']')

    # ---- case 3: a move that fails must be recorded as a failure, never read as a move ----
    $tb3c = ST-TB3Case 'c' 'c'
    [System.IO.File]::Delete([string]$tb3c.Items[2].FullName)
    $tb3cRes = Move-ShotsToQuarantine $tb3c.Items $tb3c.Quar 'tb3c_' '## tb3c fixture'
    $tb3cRows = ST-TB3Rows $tb3c.Manifest
    $tb3cMovedRows = @($tb3cRows | Where-Object { $_ -match '^- \d{4}-' })
    $tb3cFailRows = @($tb3cRows | Where-Object { $_ -match '^- FAILED' })
    ST-Check 'e2e (TB-3): a move that fails is written to the MANIFEST as a FAILED row and counted as failed, while the rows that claim a move name only files that really moved - the failure state reaches the disk instead of living only in a returned array' (
      ($null -ne $tb3cRes) -and ($tb3cRes.Moved -eq 3) -and ($tb3cRes.Failed -eq 1) -and (@($tb3cRes.Unrecorded).Count -eq 0) -and
      (@($tb3cFailRows).Count -eq 1) -and (@($tb3cMovedRows).Count -eq 3) -and ($tb3cFailRows[0].Contains('cm3.png')) -and
      (@($tb3cMovedRows | Where-Object { $_ -match 'cm3\.png' }).Count -eq 0) -and (-not $tb3cFailRows[0].Contains('sha256: ')) -and (@($tb3cRes.Failures).Count -ge 1))
    Write-Output ('      TB-3 failed-move: Moved=' + $tb3cRes.Moved + ' Failed=' + $tb3cRes.Failed + ' movedRows=' + @($tb3cMovedRows).Count +
      ' failedRows=' + @($tb3cFailRows).Count + ' unrecorded=' + @($tb3cRes.Unrecorded).Count +
      ' row=[' + $tb3cFailRows[0].Substring(0, [Math]::Min(200, $tb3cFailRows[0].Length)) + ']')

    # ---- case 4: the move and the FAILED-row write both fail ----
    $tb3d = ST-TB3Case 'd' 'd'
    [System.IO.File]::Delete([string]$tb3d.Items[0].FullName)
    [void](New-Item -ItemType Directory -Path $tb3d.Manifest)
    $tb3dRes = Move-ShotsToQuarantine $tb3d.Items $tb3d.Quar 'tb3d_' '## tb3d fixture'
    $tb3dFailures = @($tb3dRes.Failures) -join ' | '
    $tb3dLeft = @(Get-ChildItem -LiteralPath $tb3d.Shots -File | ForEach-Object { [string]$_.Name })
    $tb3dDestN = ST-TB3DestN $tb3dRes.Dest
    ST-Check 'e2e (TB-3): when both a move and its FAILED-row write fail, the item stays Failed rather than inflating Unrecorded, the record failure is reported, and later files remain untouched' (
      ($null -ne $tb3dRes) -and ($tb3dRes.Moved -eq 0) -and ($tb3dRes.Failed -eq 1) -and (@($tb3dRes.Unrecorded).Count -eq 0) -and
      (Test-Path -LiteralPath $tb3d.Manifest -PathType Container) -and ($tb3dDestN -eq 0) -and (@($tb3dLeft).Count -eq 3) -and
      (@($tb3dLeft | Where-Object { $_ -in @('dm2.png', 'dm3.png', 'dm4.png') }).Count -eq 3) -and
      $tb3dFailures.Contains('FAILED to move dm1.png') -and $tb3dFailures.Contains('FAILED to record dm1.png in') -and
      $tb3dFailures.Contains('the run stops here'))
    Write-Output ('      TB-3 double failure: Moved=' + $tb3dRes.Moved + ' Failed=' + $tb3dRes.Failed +
      ' Unrecorded=' + @($tb3dRes.Unrecorded).Count + ' destFiles=' + $tb3dDestN + ' stillInShots=' + ($tb3dLeft -join ',') +
      ' manifestIsDirectory=' + (Test-Path -LiteralPath $tb3d.Manifest -PathType Container))
  } finally {
    foreach ($tb3t in @('a', 'b', 'c')) {
      $tb3m = Join-Path $tb3Root ($tb3t + '-quar\MANIFEST.md')
      if (Test-Path -LiteralPath $tb3m) { [System.IO.File]::SetAttributes($tb3m, [System.IO.FileAttributes]::Normal) }
    }
    if (Test-Path -LiteralPath $tb3Root) { [void](Remove-Item -LiteralPath $tb3Root -Recurse -Force) }
  }
  Write-Output ('      TB-3 fixture tree removed again: ' + (-not (Test-Path -LiteralPath $tb3Root)))

  Write-Output "      dialog-cancel wiring: case=$(Format-SourceLineList $dcCase) known=$(Format-SourceLineList $dcKnown)"

  # ---------- v4.5.1 (CU-REL-02): wheel units, axis and preflight ----------
  $wheelRawDefault = Resolve-WheelRequest @() 'raw' 'vertical'
  $wheelRawExplicit = Resolve-WheelRequest @('-3') 'raw' 'vertical'
  ST-Check 'unit (CU-REL-02): omitted amount retains legacy raw -120 and explicit raw delta is unchanged with vertical direction' (
    ($wheelRawDefault.OriginalAmount -ceq '-120') -and ($wheelRawDefault.AmountSource -ceq 'legacy-default') -and ($wheelRawDefault.RawDelta -eq -120) -and
    ($wheelRawExplicit.OriginalAmount -ceq '-3') -and ($wheelRawExplicit.RawDelta -eq -3) -and ($wheelRawExplicit.Direction -ceq 'down') -and ($wheelRawExplicit.InputFlag -eq 0x0800) -and
    (Test-IntArgs 'wheel' @()))
  $wheelNotchDown = Resolve-WheelRequest @('-3') 'notches' 'vertical'
  ST-Check 'unit (CU-REL-02): -3 notches maps to -360 raw vertical delta and means down' (
    ($wheelNotchDown.RawDelta -eq -360) -and ($wheelNotchDown.Direction -ceq 'down') -and ($wheelNotchDown.EventName -ceq 'MOUSE_WHEEL'))
  $wheelNotchRight = Resolve-WheelRequest @('2') 'notches' 'horizontal'
  $wheelRawRight = Resolve-WheelRequest @('5') 'raw' 'horizontal'
  ST-Check 'unit (CU-REL-02): horizontal notches and raw values select the horizontal event and use right-positive direction' (
    ($wheelNotchRight.RawDelta -eq 240) -and ($wheelNotchRight.InputFlag -eq 0x1000) -and ($wheelNotchRight.Direction -ceq 'right') -and
    ($wheelRawRight.RawDelta -eq 5) -and ($wheelRawRight.Direction -ceq 'right'))
  $wheelUp = Resolve-WheelRequest @('1') 'raw' 'vertical'
  $wheelLeft = Resolve-WheelRequest @('-2') 'notches' 'horizontal'
  ST-Check 'unit (CU-REL-02): positive vertical is up and negative horizontal notches map to left with -240 raw delta' (
    ($wheelUp.RawDelta -eq 1) -and ($wheelUp.Direction -ceq 'up') -and ($wheelLeft.RawDelta -eq -240) -and ($wheelLeft.Direction -ceq 'left'))

  if (-not ('DtxWheelProbe' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Text;
public static class DtxWheelProbe {
  public struct POINT { public int X; public int Y; }
  public static int MoveCount, EventCount, SendCount, ClickCount, ResolveCount;
  public static int CursorX, CursorY, ForegroundHandle, HitHandle;
  public static int TargetAlive, Minimized, Visible, RectReads, MoveFails;
  public static int RectX, RectY, RectW, RectH, LastDelta;
  public static uint LastFlag;
  public static uint LastData;
  public static uint InsertedCount;
  public static int LastX;
  public static int LastY;
  public static void Reset() {
    MoveCount=0; EventCount=0; SendCount=0; ClickCount=0; ResolveCount=0; CursorX=41; CursorY=23; ForegroundHandle=77; HitHandle=77;
    TargetAlive=1; Minimized=0; Visible=1; RectReads=0; MoveFails=0; RectX=0; RectY=0; RectW=200; RectH=100; LastDelta=0;
    LastFlag=0; LastData=0; LastX=0; LastY=0; InsertedCount=1;
  }
  public static bool SetCursorPos(int x, int y) { MoveCount++; LastX = x; LastY = y; if (MoveFails == 0) { CursorX=x; CursorY=y; } return MoveFails == 0; }
  public static bool GetCursorPos(out POINT p) { p = new POINT(); p.X = CursorX; p.Y = CursorY; return true; }
  public static IntPtr GetForegroundWindow() { return new IntPtr(ForegroundHandle); }
  public static bool IsWindow(IntPtr h) { return TargetAlive != 0 && h.ToInt64() == 77; }
  public static bool IsIconic(IntPtr h) { return Minimized != 0; }
  public static bool IsWindowVisible(IntPtr h) { return Visible != 0; }
  public static IntPtr WindowFromPoint(POINT p) { return new IntPtr(77); }
  public static uint GetWindowThreadProcessId(IntPtr h, out uint pid) { pid = 91; return 1; }
  public static int GetClassName(IntPtr h, StringBuilder s, int n) { s.Append("WheelProbe"); return 10; }
  public static string Text(IntPtr h) { return "synthetic-wheel-target"; }
  public static uint SendWheelInput(int delta, uint f) { EventCount++; SendCount++; LastDelta=delta; LastFlag = f; LastData = unchecked((uint)delta); return InsertedCount; }
}
"@
  }
  function Invoke-WheelProbeSleep([int]$Milliseconds) { }
  function Invoke-WheelProbeLog([string[]]$Tokens, [string]$Details, [string]$Command) { }
  function Resolve-WheelProbeWindow([string]$Selector) { throw 'unexpected selector lookup in no-target probe' }
  function Invoke-WheelProbeClick([int]$X, [int]$Y, [string]$Button) { throw 'unexpected focus click in wheel probe' }
  function Get-WheelProbePointObservation([int]$X, [int]$Y, $Target, [string]$Phase, [bool]$RequireForeground = $false) {
    return [pscustomobject]@{ X = $X; Y = $Y; Hit = @{ Hwnd = [IntPtr]77; Pid = 91; Title = 'synthetic-wheel-target' }; Foreground = [IntPtr]::Zero; Rect = $null; TargetVerified = $false; Phase = $Phase }
  }
  $wheelAllText = $codeLines -join "`n"
  $wheelTokens = $null; $wheelParseErrors = $null
  $wheelAst = [System.Management.Automation.Language.Parser]::ParseInput($wheelAllText, [ref]$wheelTokens, [ref]$wheelParseErrors)
  $wheelHandlerAst = $wheelAst.Find({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -ceq 'Invoke-Handler-wheel') }, $true)
  $wheelHandlerText = if ($wheelHandlerAst) { $wheelHandlerAst.Extent.Text } else { '' }
  $wheelProbeText = $wheelHandlerText.Replace('function Invoke-Handler-wheel(', 'function Invoke-Handler-wheel-probe(')
  $wheelProbeText = $wheelProbeText.Replace('Get-WheelPointObservation ', 'Get-WheelProbePointObservation ')
  $wheelProbeText = $wheelProbeText.Replace('[DT]', '[DtxWheelProbe]').Replace('DT+POINT', 'DtxWheelProbe+POINT')
  $wheelProbeText = $wheelProbeText.Replace('Start-Sleep -Milliseconds', 'Invoke-WheelProbeSleep -Milliseconds')
  $wheelProbeText = $wheelProbeText.Replace('Log-Action ', 'Invoke-WheelProbeLog ').Replace('Resolve-Window ', 'Resolve-WheelProbeWindow ').Replace('Move-Click ', 'Invoke-WheelProbeClick ')
  if ($wheelHandlerAst -and @($wheelParseErrors).Count -eq 0) { Invoke-Expression $wheelProbeText }
  [DtxWheelProbe]::Reset()
  $wheelProbeOutput = @()
  if ($wheelHandlerAst -and @($wheelParseErrors).Count -eq 0) {
    $wheelProbeOutput = @(Invoke-Handler-wheel-probe 'wheel' @('2', '--unit', 'notches', '--axis', 'horizontal'))
  }
  $wheelProbeTextOut = $wheelProbeOutput -join "`n"
  $wheelHorizontalFlag = [DtxWheelProbe]::LastFlag
  $wheelHorizontalData = [DtxWheelProbe]::LastData
  [DtxWheelProbe]::Reset()
  $wheelVerticalOutput = @()
  if ($wheelHandlerAst -and @($wheelParseErrors).Count -eq 0) {
    $wheelVerticalOutput = @(Invoke-Handler-wheel-probe 'wheel' @('-3', '--unit', 'notches', '--axis', 'vertical'))
  }
  $wheelVerticalTextOut = $wheelVerticalOutput -join "`n"
  $wheelVerticalFlag = [DtxWheelProbe]::LastFlag
  $wheelVerticalData = [DtxWheelProbe]::LastData
  $wheelProbeFlag = $wheelHorizontalFlag
  ST-Check 'e2e (CU-REL-02): isolated handler injections deliver horizontal +240 and vertical -360 with the selected flags and signed DWORD data, and receipts report both requests' (
    ($wheelHandlerAst -ne $null) -and (@($wheelParseErrors).Count -eq 0) -and ($wheelHorizontalFlag -eq 0x1000) -and ($wheelHorizontalData -eq 240) -and
    ([DtxWheelProbe]::EventCount -eq 1) -and ($wheelVerticalFlag -eq 0x0800) -and ($wheelVerticalData -eq 4294966936) -and ([DtxWheelProbe]::MoveCount -eq 0) -and
    $wheelProbeTextOut.Contains('wheel 2 unit=notches axis=horizontal direction=right raw-delta=240') -and
    $wheelVerticalTextOut.Contains('wheel -3 unit=notches axis=vertical direction=down raw-delta=-360'))

  $wheelBadInputs = @(
    @{ Tokens = @('--unit', 'notches'); Needle = 'requires an explicit amount' },
    @{ Tokens = @('1', '10', '20', '--unit', 'dozen'); Needle = 'must be raw or notches' },
    @{ Tokens = @('1', '10', '20', '--axis', 'diagonal'); Needle = 'must be vertical or horizontal' },
    @{ Tokens = @('abc', '10', '20'); Needle = 'whole integer' },
    @{ Tokens = @('17895698', '10', '20', '--unit', 'notches'); Needle = 'overflows the signed 32-bit raw delta' },
    @{ Tokens = @('2147483648', '10', '20'); Needle = 'must fit a signed 32-bit delta' },
    @{ Tokens = @('1', '10', '20', '--unit'); Needle = 'needs a value' }
  )
  $wheelBadCount = 0; $wheelBadNoSideEffect = $true
  foreach ($wheelBad in $wheelBadInputs) {
    [DtxWheelProbe]::Reset()
    $wheelBadMessage = ''
    try { [void](Invoke-Handler-wheel-probe 'wheel' @($wheelBad.Tokens)) } catch { $wheelBadMessage = [string]$_.Exception.Message }
    if ($wheelBadMessage.Contains([string]$wheelBad.Needle)) { $wheelBadCount++ }
    if (-not $wheelBadMessage.Contains([string]$wheelBad.Needle) -or [DtxWheelProbe]::EventCount -ne 0 -or [DtxWheelProbe]::MoveCount -ne 0) { $wheelBadNoSideEffect = $false }
  }
  ST-Check 'unit (CU-REL-02): absent notches amount, bad unit/axis, non-integer, raw/notches overflow and missing flag value all refuse before pointer movement or input' (
    ($wheelBadCount -eq @($wheelBadInputs).Count) -and $wheelBadNoSideEffect)

  $wheelResolveAt = $wheelHandlerText.IndexOf('Resolve-WheelRequest', [StringComparison]::Ordinal)
  $wheelMoveAt = $wheelHandlerText.IndexOf('[DT]::SetCursorPos', [StringComparison]::Ordinal)
  $wheelInjectAt = $wheelHandlerText.IndexOf('[DT]::SendWheelInput([int]$wheelRequest.RawDelta', [StringComparison]::Ordinal)
  $wheelLint = ($wheelResolveAt -ge 0) -and (($wheelMoveAt -lt 0) -or ($wheelResolveAt -lt $wheelMoveAt)) -and ($wheelInjectAt -ge 0) -and
    $wheelHandlerText.Contains('$wheelRequest.RawDelta') -and ($script:StLoadTimeNames -contains 'MOUSE_HWHEEL=1')
  ST-Check 'lint (CU-REL-02): wheel validates before cursor movement, injects the selected axis with converted delta and owns a declared HWHEEL constant' $wheelLint
  Write-Output ('      wheel request probe: invalid-cases=' + $wheelBadCount + '/' + @($wheelBadInputs).Count + ' injected-horizontal-flag=' + $wheelProbeFlag)

  # ---------- v4.5.2 (CU-REL-03): target verification, SendInput count and honest receipt ----------
  if (-not ('DtxWheelProbe' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
public static class DtxWheelProbe {
  public struct POINT { public int X; public int Y; }
  public static int CursorX, CursorY, ForegroundHandle, HitHandle;
  public static int TargetAlive, Minimized, Visible, RectReads, MoveCount, MoveFails, ClickCount, ResolveCount, SendCount;
  public static int RectX, RectY, RectW, RectH, LastDelta;
  public static uint LastFlag, InsertedCount;
  public static void Reset() {
    CursorX=41; CursorY=23; ForegroundHandle=77; HitHandle=77; TargetAlive=1; Minimized=0; Visible=1;
    RectReads=0; MoveCount=0; MoveFails=0; ClickCount=0; ResolveCount=0; SendCount=0; RectX=0; RectY=0; RectW=200; RectH=100;
    LastDelta=0; LastFlag=0; InsertedCount=1;
  }
  public static bool SetCursorPos(int x, int y) { MoveCount++; if (MoveFails == 0) { CursorX=x; CursorY=y; } return MoveFails == 0; }
  public static bool GetCursorPos(out POINT p) { p=new POINT(); p.X=CursorX; p.Y=CursorY; return true; }
  public static IntPtr GetForegroundWindow() { return new IntPtr(ForegroundHandle); }
  public static bool IsWindow(IntPtr h) { return TargetAlive != 0 && h.ToInt64() == 77; }
  public static bool IsIconic(IntPtr h) { return Minimized != 0; }
  public static bool IsWindowVisible(IntPtr h) { return Visible != 0; }
  public static uint SendWheelInput(int delta, uint flag) { SendCount++; LastDelta=delta; LastFlag=flag; return InsertedCount; }
}
"@
  }
  function Reset-WheelProbe {
    [DtxWheelProbe]::Reset()
    $script:WheelProbeTarget = [pscustomobject]@{ Handle = [IntPtr]77; Pid = 91; Title = 'synthetic-wheel-target'; Left = 777; Top = 777; W = 1; H = 1; Right = 778; Bottom = 778 }
    $script:WheelProbeMutateLanding = $false
    $script:WheelProbeMutateForeground = $false
    $script:WheelProbeMutateCursor = $false
    $script:WheelProbeScrollSequence = @(); $script:WheelProbeScrollIndex = 0
    $script:WheelProbeTextSequence = @(); $script:WheelProbeTextIndex = 0
    $script:WheelProbeHashSequence = @(); $script:WheelProbeHashIndex = 0
    $script:WheelProbeSleepMs = 0; $script:WheelProbeMutateRectOnTextIndex = 0
    $script:WheelProbeLoseTargetOnTextIndex = 0
  }
  function Get-WheelProbeRect([IntPtr]$Handle) {
    [DtxWheelProbe]::RectReads++
    return @{ X = [DtxWheelProbe]::RectX; Y = [DtxWheelProbe]::RectY; W = [DtxWheelProbe]::RectW; H = [DtxWheelProbe]::RectH }
  }
  function Get-WheelProbeHitWindow([int]$X, [int]$Y) {
    if ([DtxWheelProbe]::HitHandle -eq 0) { return $null }
    $hh = [IntPtr]::new([long][DtxWheelProbe]::HitHandle)
    $hp = if ([DtxWheelProbe]::HitHandle -eq 77) { 91 } else { 92 }
    $ht = if ([DtxWheelProbe]::HitHandle -eq 77) { 'synthetic-wheel-target' } else { 'synthetic-coverer' }
    return @{ Hwnd = $hh; Pid = $hp; Title = $ht }
  }
  function Resolve-WheelProbeTarget([string]$Selector, [bool]$Force, [bool]$AlwaysActivate, [string]$ExpectHandle) {
    [DtxWheelProbe]::ResolveCount++
    return $script:WheelProbeTarget
  }
  function Invoke-WheelProbeEmitResolveNote { }
  function Invoke-WheelProbeLog([string[]]$Tokens, [string]$Details, [string]$Command) { }
  function Invoke-WheelProbeSleep([int]$Milliseconds) { $script:WheelProbeSleepMs += $Milliseconds }
  function Invoke-WheelProbeClick([int]$X, [int]$Y, [string]$Button) {
    [DtxWheelProbe]::ClickCount++
    if ($script:WheelProbeMutateLanding) { [DtxWheelProbe]::HitHandle = 88 }
    if ($script:WheelProbeMutateForeground) { [DtxWheelProbe]::ForegroundHandle = 88 }
    if ($script:WheelProbeMutateCursor) { [DtxWheelProbe]::CursorX = 42 }
  }
  function Get-WheelProbeBaseline($Parameters, $Target) { return $null }
  function Invoke-WheelProbeExpectChange($Parameters, $Baseline, [string]$What) { }
  function Get-WheelProbeScrollObservation([int]$X, [int]$Y, $Target, [string]$Axis) {
    if (@($script:WheelProbeScrollSequence).Count -eq 0) { return @{ Available = $false; Reason = 'stub-no-scroll-pattern'; Position = $null; ContainerId = ''; Axis = $Axis } }
    $i = [Math]::Min($script:WheelProbeScrollIndex, @($script:WheelProbeScrollSequence).Count - 1); $script:WheelProbeScrollIndex++
    return $script:WheelProbeScrollSequence[$i]
  }
  function Get-WheelProbeVisibleTextObservation($Target, [string]$Needle) {
    if (@($script:WheelProbeTextSequence).Count -eq 0) { return @{ Available = $false; Found = $false; Reason = 'stub-no-uia-content'; Scanned = 0; NodeId = '' } }
    $i = [Math]::Min($script:WheelProbeTextIndex, @($script:WheelProbeTextSequence).Count - 1); $script:WheelProbeTextIndex++
    if ($script:WheelProbeMutateRectOnTextIndex -gt 0 -and $script:WheelProbeTextIndex -eq $script:WheelProbeMutateRectOnTextIndex) { [DtxWheelProbe]::RectX = 10 }
    if ($script:WheelProbeLoseTargetOnTextIndex -gt 0 -and $script:WheelProbeTextIndex -eq $script:WheelProbeLoseTargetOnTextIndex) { [DtxWheelProbe]::TargetAlive = 0 }
    return $script:WheelProbeTextSequence[$i]
  }
  function Get-WheelProbeExpectRegion($Parameters, $Target) {
    $parts = @(([string]$Parameters.ExpectChange) -split ',')
    return @{ X = [int]$parts[0]; Y = [int]$parts[1]; W = [int]$parts[2]; H = [int]$parts[3]; Source = 'synthetic local rect' }
  }
  function ConvertTo-WheelProbeExpectRect([string]$Rect) {
    if ($Rect -match '^-?\d+,-?\d+,\d+,\d+$') { return $Rect }
    return $null
  }
  function Get-WheelProbeHash([int]$X, [int]$Y, [int]$W, [int]$H) {
    if (@($script:WheelProbeHashSequence).Count -eq 0) { return '' }
    $i = [Math]::Min($script:WheelProbeHashIndex, @($script:WheelProbeHashSequence).Count - 1); $script:WheelProbeHashIndex++
    return [string]$script:WheelProbeHashSequence[$i]
  }

  $wheelObservationAst = $wheelAst.Find({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -ceq 'Get-WheelPointObservation') }, $true)
  $wheelObservationText = if ($wheelObservationAst) { $wheelObservationAst.Extent.Text } else { '' }
  $wheelProbeObservationText = $wheelObservationText.Replace('function Get-WheelPointObservation(', 'function Get-WheelPointObservation-probe(')
  $wheelBoundaryAst = $wheelAst.Find({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -ceq 'Test-WheelScrollBoundary') }, $true)
  $wheelDirectionAst = $wheelAst.Find({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -ceq 'Test-WheelScrollDirection') }, $true)
  $wheelScrollObservationAst = $wheelAst.Find({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -ceq 'Get-WheelScrollObservation') }, $true)
  $wheelContentObservationAst = $wheelAst.Find({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -ceq 'Get-WheelVisibleTextObservation') }, $true)
  $wheelBoundaryText = if ($wheelBoundaryAst) { $wheelBoundaryAst.Extent.Text.Replace('function Test-WheelScrollBoundary(', 'function Test-WheelScrollBoundary-probe(') } else { '' }
  $wheelDirectionText = if ($wheelDirectionAst) { $wheelDirectionAst.Extent.Text.Replace('function Test-WheelScrollDirection(', 'function Test-WheelScrollDirection-probe(') } else { '' }
  $wheelScrollObservationText = if ($wheelScrollObservationAst) { $wheelScrollObservationAst.Extent.Text } else { '' }
  $wheelContentObservationText = if ($wheelContentObservationAst) { $wheelContentObservationAst.Extent.Text } else { '' }
  $wheelProbeHandlerText = $wheelHandlerText.Replace('function Invoke-Handler-wheel(', 'function Invoke-Handler-wheel-probe(')
  $wheelProbeHandlerText = $wheelProbeHandlerText.Replace('Get-WheelPointObservation ', 'Get-WheelPointObservation-probe ')
  $wheelProbeHandlerText = $wheelProbeHandlerText.Replace('Get-WheelScrollObservation ', 'Get-WheelProbeScrollObservation ')
  $wheelProbeHandlerText = $wheelProbeHandlerText.Replace('Get-WheelVisibleTextObservation ', 'Get-WheelProbeVisibleTextObservation ')
  $wheelProbeHandlerText = $wheelProbeHandlerText.Replace('Test-WheelScrollBoundary ', 'Test-WheelScrollBoundary-probe ')
  $wheelProbeHandlerText = $wheelProbeHandlerText.Replace('Test-WheelScrollDirection ', 'Test-WheelScrollDirection-probe ')
  foreach ($wheelReplacement in @(
    @{ Old = '[DT]'; New = '[DtxWheelProbe]' },
    @{ Old = 'DT+POINT'; New = 'DtxWheelProbe+POINT' },
    @{ Old = 'Get-HitWindow '; New = 'Get-WheelProbeHitWindow ' },
    @{ Old = 'Get-WindowVisibleRect '; New = 'Get-WheelProbeRect ' },
    @{ Old = 'Resolve-Target '; New = 'Resolve-WheelProbeTarget ' },
    @{ Old = 'Emit-ResolveNote'; New = 'Invoke-WheelProbeEmitResolveNote' },
    @{ Old = 'Start-Sleep -Milliseconds'; New = 'Invoke-WheelProbeSleep -Milliseconds' },
    @{ Old = 'Log-Action '; New = 'Invoke-WheelProbeLog ' },
    @{ Old = 'Move-Click '; New = 'Invoke-WheelProbeClick ' },
    @{ Old = 'Get-ExpectChangeBaseline '; New = 'Get-WheelProbeBaseline ' },
    @{ Old = 'Invoke-ExpectChangeCheck '; New = 'Invoke-WheelProbeExpectChange ' },
    @{ Old = 'Get-ExpectChangeRegion '; New = 'Get-WheelProbeExpectRegion ' },
    @{ Old = 'ConvertTo-ExpectChangeRect '; New = 'ConvertTo-WheelProbeExpectRect ' },
    @{ Old = 'Get-RegionHash '; New = 'Get-WheelProbeHash ' }
  )) {
    $wheelProbeObservationText = $wheelProbeObservationText.Replace([string]$wheelReplacement.Old, [string]$wheelReplacement.New)
    $wheelProbeHandlerText = $wheelProbeHandlerText.Replace([string]$wheelReplacement.Old, [string]$wheelReplacement.New)
  }
  if ($wheelObservationAst -and $wheelHandlerAst -and @($wheelParseErrors).Count -eq 0) {
    Invoke-Expression ($wheelProbeObservationText + "`n" + $wheelBoundaryText + "`n" + $wheelDirectionText + "`n" + $wheelProbeHandlerText)
  }

  Reset-WheelProbe
  $wheelGoodObservation = Get-WheelPointObservation-probe 41 23 $script:WheelProbeTarget 'offline positive' $false
  $wheelFreshRectOk = $wheelGoodObservation.TargetVerified -and ($wheelGoodObservation.Rect.X -eq 0) -and ($script:WheelProbeTarget.Left -eq 0) -and ($wheelGoodObservation.Hit.Hwnd -eq [IntPtr]77)
  $wheelOutsideMessage = ''; $wheelCoverMessage = ''
  try { [void](Get-WheelPointObservation-probe 201 23 $script:WheelProbeTarget 'outside case' $false) } catch { $wheelOutsideMessage = [string]$_.Exception.Message }
  [DtxWheelProbe]::HitHandle = 88
  try { [void](Get-WheelPointObservation-probe 41 23 $script:WheelProbeTarget 'coverer case' $false) } catch { $wheelCoverMessage = [string]$_.Exception.Message }
  Reset-WheelProbe
  [DtxWheelProbe]::HitHandle = 88
  $wheelWrongPreMessage = ''
  try { [void](Invoke-Handler-wheel-probe 'wheel' @('1', '41', '23', '--to', 'Probe', '--focus-first')) } catch { $wheelWrongPreMessage = [string]$_.Exception.Message }
  $wheelWrongPreNoAction = [DtxWheelProbe]::MoveCount -eq 0 -and [DtxWheelProbe]::ClickCount -eq 0 -and [DtxWheelProbe]::SendCount -eq 0
  Reset-WheelProbe
  [DtxWheelProbe]::MoveFails = 1
  $wheelPointMoveMessage = ''
  try { [void](Invoke-Handler-wheel-probe 'wheel' @('1', '80', '50', '--to', 'Probe')) } catch { $wheelPointMoveMessage = [string]$_.Exception.Message }
  ST-Check 'unit (CU-REL-03): target uses a fresh rect and requires the actual point to hit the selected top-level window' (
    $wheelFreshRectOk -and $wheelOutsideMessage.Contains('outside target hwnd=') -and $wheelCoverMessage.Contains('not target hwnd=') -and
    $wheelWrongPreMessage.Contains('not target hwnd=') -and $wheelWrongPreNoAction -and $wheelPointMoveMessage.Contains('requested scroll point (80,50)') -and
    [DtxWheelProbe]::SendCount -eq 0 -and [DtxWheelProbe]::MoveCount -eq 1)

  $wheelStateErrors = @(
    @{ Kind = 'gone'; Needle = 'no longer exists'; Foreground = $false },
    @{ Kind = 'minimized'; Needle = 'is minimized'; Foreground = $false },
    @{ Kind = 'hidden'; Needle = 'is not visible'; Foreground = $false },
    @{ Kind = 'focus'; Needle = 'left foreground'; Foreground = $true }
  )
  $wheelStateErrorCount = 0; $wheelStateNoInput = $true
  foreach ($wheelState in $wheelStateErrors) {
    Reset-WheelProbe
    if ($wheelState.Kind -ceq 'gone') { [DtxWheelProbe]::TargetAlive = 0 }
    elseif ($wheelState.Kind -ceq 'minimized') { [DtxWheelProbe]::Minimized = 1 }
    elseif ($wheelState.Kind -ceq 'hidden') { [DtxWheelProbe]::Visible = 0 }
    elseif ($wheelState.Kind -ceq 'focus') { [DtxWheelProbe]::ForegroundHandle = 88 }
    $wheelStateMessage = ''
    try { [void](Get-WheelPointObservation-probe 41 23 $script:WheelProbeTarget 'after click' ([bool]$wheelState.Foreground)) } catch { $wheelStateMessage = [string]$_.Exception.Message }
    if ($wheelStateMessage.Contains([string]$wheelState.Needle)) { $wheelStateErrorCount++ }
    if (-not $wheelStateMessage.Contains([string]$wheelState.Needle) -or [DtxWheelProbe]::SendCount -ne 0) { $wheelStateNoInput = $false }
  }
  ST-Check 'unit (CU-REL-03): gone, minimized, hidden or unexpectedly unfocused targets refuse a wheel input' (
    $wheelStateErrorCount -eq @($wheelStateErrors).Count -and $wheelStateNoInput)

  $wheelBadTargetCases = @(
    @{ Tokens = @('1', '--at', 'Probe'); Needle = 'requires explicit x y' },
    @{ Tokens = @('1', '10', '20', '--allow-outside'); Needle = 'unknown flag' },
    @{ Tokens = @('1', '10', '20', '--guard-text', 'ready'); Needle = 'unknown flag' },
    @{ Tokens = @('1', '10', '20', '--to', 'Probe', '--at', 'Probe'); Needle = 'choose one target selector' }
  )
  $wheelBadTargetCount = 0; $wheelBadTargetPreflight = $true
  foreach ($wheelBadTarget in $wheelBadTargetCases) {
    Reset-WheelProbe
    $wheelBadTargetMessage = ''
    try { [void](Invoke-Handler-wheel-probe 'wheel' @($wheelBadTarget.Tokens)) } catch { $wheelBadTargetMessage = [string]$_.Exception.Message }
    if ($wheelBadTargetMessage.Contains([string]$wheelBadTarget.Needle)) { $wheelBadTargetCount++ }
    if (-not $wheelBadTargetMessage.Contains([string]$wheelBadTarget.Needle) -or [DtxWheelProbe]::ResolveCount -ne 0 -or [DtxWheelProbe]::MoveCount -ne 0 -or [DtxWheelProbe]::SendCount -ne 0) {
      $wheelBadTargetPreflight = $false
    }
  }
  ST-Check 'unit (CU-REL-03): --at needs explicit coordinates and unsupported shared flags or duplicate selectors reject before target resolution or action' (
    $wheelBadTargetCount -eq @($wheelBadTargetCases).Count -and $wheelBadTargetPreflight)

  Reset-WheelProbe
  $wheelToOutput = @(Invoke-Handler-wheel-probe 'wheel' @('-3', '120', '40', '--unit', 'notches', '--axis', 'horizontal', '--to', 'Probe')) -join "`n"
  $wheelToPass = [DtxWheelProbe]::LastDelta -eq -360 -and [DtxWheelProbe]::LastFlag -eq 0x1000 -and [DtxWheelProbe]::SendCount -eq 1 -and
    [DtxWheelProbe]::MoveCount -eq 1 -and $wheelToOutput.Contains('target-check=matched via --to') -and $wheelToOutput.Contains('SendInput-inserted=1/1') -and
    $wheelToOutput.Contains('observed-before-injection=pid=91 hwnd=77') -and $wheelToOutput.Contains('effect=not-verified')
  Reset-WheelProbe
  $wheelAtOutput = @(Invoke-Handler-wheel-probe 'wheel' @('2', '60', '40', '--unit', 'notches', '--at', 'Probe')) -join "`n"
  $wheelAtPass = [DtxWheelProbe]::LastDelta -eq 240 -and [DtxWheelProbe]::LastFlag -eq 0x0800 -and [DtxWheelProbe]::SendCount -eq 1 -and
    $wheelAtOutput.Contains('target-check=matched via --at') -and $wheelAtOutput.Contains('scroll-point=(60,40)')
  Reset-WheelProbe
  $wheelCursorOutput = @(Invoke-Handler-wheel-probe 'wheel' @('1', '--to', 'Probe')) -join "`n"
  $wheelCursorPass = [DtxWheelProbe]::MoveCount -eq 0 -and [DtxWheelProbe]::LastDelta -eq 1 -and [DtxWheelProbe]::SendCount -eq 1 -and
    $wheelCursorOutput.Contains('scroll-point=(41,23)') -and $wheelCursorOutput.Contains('target-check=matched via --to')
  ST-Check 'e2e (CU-REL-03): --to and --at validate the real scroll point, use SendInput once, and receipts separate request, observed window, count and effect status' (
    $wheelToPass -and $wheelAtPass -and $wheelCursorPass)

  Reset-WheelProbe
  $wheelFocusOutput = @(Invoke-Handler-wheel-probe 'wheel' @('1', '80', '50', '--to', 'Probe', '--focus-first')) -join "`n"
  $wheelFocusGood = [DtxWheelProbe]::ClickCount -eq 1 -and [DtxWheelProbe]::SendCount -eq 1 -and [DtxWheelProbe]::RectReads -eq 3 -and $wheelFocusOutput.Contains('clicked first (--focus-first)')
  Reset-WheelProbe
  $script:WheelProbeMutateLanding = $true
  $wheelFocusLandingMessage = ''
  try { [void](Invoke-Handler-wheel-probe 'wheel' @('1', '80', '50', '--to', 'Probe', '--focus-first')) } catch { $wheelFocusLandingMessage = [string]$_.Exception.Message }
  $wheelFocusLandingSafe = $wheelFocusLandingMessage.Contains('not target hwnd=') -and [DtxWheelProbe]::ClickCount -eq 1 -and [DtxWheelProbe]::SendCount -eq 0 -and [DtxWheelProbe]::RectReads -eq 3
  Reset-WheelProbe
  $script:WheelProbeMutateForeground = $true
  $wheelFocusForegroundMessage = ''
  try { [void](Invoke-Handler-wheel-probe 'wheel' @('1', '80', '50', '--to', 'Probe', '--focus-first')) } catch { $wheelFocusForegroundMessage = [string]$_.Exception.Message }
  $wheelFocusForegroundSafe = $wheelFocusForegroundMessage.Contains('left foreground') -and [DtxWheelProbe]::ClickCount -eq 1 -and [DtxWheelProbe]::SendCount -eq 0
  Reset-WheelProbe
  $script:WheelProbeMutateCursor = $true
  $wheelFocusCursorMessage = ''
  try { [void](Invoke-Handler-wheel-probe 'wheel' @('1', '80', '50', '--to', 'Probe', '--focus-first')) } catch { $wheelFocusCursorMessage = [string]$_.Exception.Message }
  $wheelFocusCursorSafe = $wheelFocusCursorMessage.Contains('cursor moved from selected scroll point') -and [DtxWheelProbe]::ClickCount -eq 1 -and [DtxWheelProbe]::SendCount -eq 0
  ST-Check 'e2e (CU-REL-03): focus-first remains explicit, validates before click, and re-reads rect, foreground and landing before scrolling' (
    $wheelFocusGood -and $wheelFocusLandingSafe -and $wheelFocusForegroundSafe -and $wheelFocusCursorSafe)

  Reset-WheelProbe
  [DtxWheelProbe]::InsertedCount = 0
  $wheelInsertOutput = @(); $wheelInsertMessage = ''
  try { $wheelInsertOutput = @(Invoke-Handler-wheel-probe 'wheel' @('1')) } catch { $wheelInsertMessage = [string]$_.Exception.Message }
  ST-Check 'unit (CU-REL-03): incomplete SendInput count errors once and emits no success receipt or retry' (
    $wheelInsertMessage.Contains('SendInput inserted 0 of 1') -and $wheelInsertMessage.Contains('no automatic retry') -and [DtxWheelProbe]::SendCount -eq 1 -and @($wheelInsertOutput).Count -eq 0)

  $wheelSendMethod = [regex]::Match($src, '(?s)public static uint SendWheelInput\(int delta, uint flags\)\s*\{(?<body>.*?)\n  \}')
  $wheelSendBody = if ($wheelSendMethod.Success) { $wheelSendMethod.Groups['body'].Value } else { '' }
  $wheelResolvePos = $wheelHandlerText.IndexOf('Resolve-WheelRequest', [StringComparison]::Ordinal)
  $wheelPrePos = $wheelHandlerText.IndexOf("'before focus-first'", [StringComparison]::Ordinal)
  $wheelClickPos = $wheelHandlerText.IndexOf('Move-Click', [StringComparison]::Ordinal)
  $wheelPostPos = $wheelHandlerText.IndexOf("'after focus-first click'", [StringComparison]::Ordinal)
  $wheelSendPos = $wheelHandlerText.IndexOf('[DT]::SendWheelInput', [StringComparison]::Ordinal)
  $wheelLint = $wheelObservationText.Contains('Get-WindowVisibleRect') -and $wheelObservationText.Contains('Get-HitWindow') -and $wheelObservationText.Contains('[DT]::IsWindowVisible') -and
    $wheelHandlerText.Contains("requires explicit x y") -and $wheelHandlerText.Contains('SendInput-inserted=') -and $wheelHandlerText.Contains('observed-before-injection=') -and
    $wheelHandlerText.Contains('effect=not-verified') -and -not $wheelHandlerText.Contains('mouse_event(') -and -not $wheelHandlerText.Contains('delivered to hwnd=') -and
    $wheelResolvePos -ge 0 -and $wheelPrePos -ge 0 -and $wheelPrePos -lt $wheelClickPos -and $wheelPostPos -gt $wheelClickPos -and $wheelPostPos -lt $wheelSendPos -and
    $wheelSendBody.Contains('INPUT[] inputs = new INPUT[1]') -and $wheelSendBody.Contains('mouseData = unchecked((uint)delta)') -and $wheelSendBody.Contains('return SendInput(1, inputs, Marshal.SizeOf(typeof(INPUT)))')
  ST-Check 'lint (CU-REL-03): wheel target reads precede input, wheel alone uses a single-count SendInput event, and receipt fields do not claim UI effect' $wheelLint
  Write-Output ('      wheel target probe: invalid-target-cases=' + $wheelBadTargetCount + '/' + @($wheelBadTargetCases).Count + ' unavailable-state-cases=' + $wheelStateErrorCount + '/' + @($wheelStateErrors).Count + ' SendInput-count=' + [DtxWheelProbe]::SendCount)

  # ---------- v4.5.3 (CU-REL-04): bounded scroll-effect evidence and honest fallback ----------
  $wheelDirectionOk =
    (Test-WheelScrollBoundary-probe 0 'vertical' 120) -and (Test-WheelScrollBoundary-probe 100 'vertical' -120) -and
    (Test-WheelScrollBoundary-probe 100 'horizontal' 120) -and (Test-WheelScrollBoundary-probe 0 'horizontal' -120) -and
    (Test-WheelScrollDirection-probe 50 40 'vertical' 120) -and (Test-WheelScrollDirection-probe 50 60 'vertical' -120) -and
    (Test-WheelScrollDirection-probe 50 60 'horizontal' 120) -and (Test-WheelScrollDirection-probe 50 40 'horizontal' -120) -and
    (-not (Test-WheelScrollDirection-probe 50 40 'vertical' -120))
  ST-Check 'unit (CU-REL-04): ScrollPattern edge and expected movement use the requested vertical or horizontal direction' $wheelDirectionOk

  $wheelBadVerifyCases = @(
    @{ Tokens = @('1', '--verify-scroll'); Needle = 'requires --to' },
    @{ Tokens = @('1', '80', '50', '--verify-scroll'); Needle = 'requires --to' },
    @{ Tokens = @('0', '80', '50', '--to', 'Probe', '--verify-scroll'); Needle = 'non-zero wheel delta' },
    @{ Tokens = @('1', '80', '50', '--to', 'Probe', '--verify-scroll', '--expect-visible-text', 'row 5'); Needle = 'choose one verification route' },
    @{ Tokens = @('1', '80', '50', '--to', 'Probe', '--expect-visible-text', 'row 5', '--expect-change', '5,5,20,20'); Needle = 'cannot be combined' }
  )
  $wheelBadVerifyCount = 0; $wheelBadVerifySafe = $true; $wheelBadVerifyDetails = New-Object System.Collections.ArrayList
  foreach ($bad in $wheelBadVerifyCases) {
    Reset-WheelProbe
    $msg = ''
    try { [void](Invoke-Handler-wheel-probe 'wheel' @($bad.Tokens)) } catch { $msg = [string]$_.Exception.Message }
    if ($msg.Contains([string]$bad.Needle)) { $wheelBadVerifyCount++ }
    if (-not $msg.Contains([string]$bad.Needle)) { [void]$wheelBadVerifyDetails.Add(($bad.Tokens -join ' ') + ' => ' + $msg) }
    if (-not $msg.Contains([string]$bad.Needle) -or [DtxWheelProbe]::ResolveCount -ne 0 -or [DtxWheelProbe]::MoveCount -ne 0 -or [DtxWheelProbe]::SendCount -ne 0) { $wheelBadVerifySafe = $false }
  }
  ST-Check 'unit (CU-REL-04): verification argument shapes and conflicting routes refuse before resolution, pointer movement or injection' (
    ($wheelBadVerifyCount -eq @($wheelBadVerifyCases).Count) -and $wheelBadVerifySafe)
  if (@($wheelBadVerifyDetails).Count -gt 0) { Write-Output ('      verification preflight mismatches: ' + (@($wheelBadVerifyDetails) -join ' || ')) }

  Reset-WheelProbe
  $script:WheelProbeScrollSequence = @(
    @{ Available = $true; Reason = ''; Position = 20.0; ContainerId = 'uia-scroll-1'; Axis = 'vertical' },
    @{ Available = $true; Reason = ''; Position = 15.0; ContainerId = 'uia-scroll-1'; Axis = 'vertical' }
  )
  $wheelPosOut = @(Invoke-Handler-wheel-probe 'wheel' @('1', '80', '50', '--to', 'Probe', '--verify-scroll')) -join "`n"
  $wheelPosPass = [DtxWheelProbe]::SendCount -eq 1 -and $wheelPosOut.Contains('verification=position-changed') -and
    $wheelPosOut.Contains('position=20->15') -and $wheelPosOut.Contains('attribution=not-proven') -and $wheelPosOut.Contains('samples=')
  Reset-WheelProbe
  $script:WheelProbeScrollSequence = @(
    @{ Available = $true; Reason = ''; Position = 40.0; ContainerId = 'uia-scroll-h'; Axis = 'horizontal' },
    @{ Available = $true; Reason = ''; Position = 45.0; ContainerId = 'uia-scroll-h'; Axis = 'horizontal' }
  )
  $wheelHorizontalOut = @(Invoke-Handler-wheel-probe 'wheel' @('1', '80', '50', '--axis', 'horizontal', '--to', 'Probe', '--verify-scroll')) -join "`n"
  $wheelHorizontalPass = [DtxWheelProbe]::LastFlag -eq 0x1000 -and [DtxWheelProbe]::SendCount -eq 1 -and
    $wheelHorizontalOut.Contains('verification=position-changed') -and $wheelHorizontalOut.Contains('position=40->45')
  ST-Check 'e2e (CU-REL-04): vertical and horizontal ScrollPattern readback reports the expected directional position change after one wheel event' (
    $wheelPosPass -and $wheelHorizontalPass)

  Reset-WheelProbe
  $script:WheelProbeScrollSequence = @(@{ Available = $true; Reason = ''; Position = 100.0; ContainerId = 'uia-scroll-edge'; Axis = 'vertical' })
  $wheelBoundaryOut = @(Invoke-Handler-wheel-probe 'wheel' @('-1', '80', '50', '--to', 'Probe', '--verify-scroll')) -join "`n"
  ST-Check 'unit (CU-REL-04): a known requested-direction boundary is reported distinctly and suppresses unnecessary input' (
    $wheelBoundaryOut.Contains('verification=at-boundary') -and $wheelBoundaryOut.Contains('requested=0') -and [DtxWheelProbe]::SendCount -eq 0)

  Reset-WheelProbe
  $script:WheelProbeScrollSequence = @(@{ Available = $true; Reason = ''; Position = 50.0; ContainerId = 'uia-scroll-still'; Axis = 'vertical' })
  $wheelNoEffectMessage = ''
  try { [void](Invoke-Handler-wheel-probe 'wheel' @('-1', '80', '50', '--to', 'Probe', '--verify-scroll')) } catch { $wheelNoEffectMessage = [string]$_.Exception.Message }
  $wheelNoEffectBounded = $wheelNoEffectMessage.Contains('status=no-observed-effect') -and [DtxWheelProbe]::SendCount -eq 1 -and
    ($script:WheelProbeSleepMs - 150) -eq 1200
  Reset-WheelProbe
  $script:WheelProbeScrollSequence = @(
    @{ Available = $true; Reason = ''; Position = 50.0; ContainerId = 'uia-scroll-wrong-way'; Axis = 'vertical' },
    @{ Available = $true; Reason = ''; Position = 40.0; ContainerId = 'uia-scroll-wrong-way'; Axis = 'vertical' }
  )
  $wheelWrongWayMessage = ''
  try { [void](Invoke-Handler-wheel-probe 'wheel' @('-1', '80', '50', '--to', 'Probe', '--verify-scroll')) } catch { $wheelWrongWayMessage = [string]$_.Exception.Message }
  ST-Check 'unit (CU-REL-04): no position change and a wrong-direction change fail verification within the poll and single-input bounds' (
    $wheelNoEffectBounded -and $wheelWrongWayMessage.Contains('status=unexpected-position-change') -and [DtxWheelProbe]::SendCount -eq 1)

  Reset-WheelProbe
  $script:WheelProbeTextSequence = @(
    @{ Available = $true; Found = $false; Reason = ''; Scanned = 12; NodeId = '' },
    @{ Available = $true; Found = $true; Reason = ''; Scanned = 13; NodeId = 'uia-item-13' }
  )
  $wheelTextOut = @(Invoke-Handler-wheel-probe 'wheel' @('-1', '80', '50', '--to', 'Probe', '--expect-visible-text', 'row 13')) -join "`n"
  $wheelTextAppeared = $wheelTextOut.Contains('verification=target-content-appeared') -and $wheelTextOut.Contains('evidence=UIA-visible-descendant') -and [DtxWheelProbe]::SendCount -eq 1
  Reset-WheelProbe
  $script:WheelProbeTextSequence = @(@{ Available = $true; Found = $true; Reason = ''; Scanned = 4; NodeId = 'uia-item-visible' })
  $wheelTextAlready = @(Invoke-Handler-wheel-probe 'wheel' @('-1', '80', '50', '--to', 'Probe', '--expect-visible-text', 'row 13')) -join "`n"
  ST-Check 'e2e (CU-REL-04): visible target content is distinguished from content that appears after the wheel, without echoing the needle' (
    $wheelTextAppeared -and $wheelTextAlready.Contains('verification=target-content-already-visible') -and [DtxWheelProbe]::SendCount -eq 0)

  Reset-WheelProbe
  $script:WheelProbeScrollSequence = @(@{ Available = $false; Reason = 'stub-no-scroll-pattern'; Position = $null; ContainerId = ''; Axis = 'vertical' })
  $script:WheelProbeHashSequence = @('before-pixel', 'after-pixel')
  $wheelPixelOut = @(Invoke-Handler-wheel-probe 'wheel' @('-1', '80', '50', '--to', 'Probe', '--verify-scroll', '--expect-change', '5,5,20,20')) -join "`n"
  $wheelPixelOnly = $wheelPixelOut.Contains('verification=pixel-changed-only') -and $wheelPixelOut.Contains('evidence=local-pixel-only') -and
    $wheelPixelOut.Contains('boundary=') -eq $false -and [DtxWheelProbe]::SendCount -eq 1
  Reset-WheelProbe
  $script:WheelProbeScrollSequence = @(@{ Available = $false; Reason = 'stub-no-scroll-pattern'; Position = $null; ContainerId = ''; Axis = 'vertical' })
  $script:WheelProbeHashSequence = @('same-pixel')
  $wheelPixelSameMessage = ''
  try { [void](Invoke-Handler-wheel-probe 'wheel' @('-1', '80', '50', '--to', 'Probe', '--verify-scroll', '--expect-change', '5,5,20,20')) } catch { $wheelPixelSameMessage = [string]$_.Exception.Message }
  $wheelPixelNoChange = $wheelPixelSameMessage.Contains('status=no-pixel-change') -and $wheelPixelSameMessage.Contains('boundary=unknown') -and [DtxWheelProbe]::SendCount -eq 1
  Reset-WheelProbe
  $script:WheelProbeScrollSequence = @(@{ Available = $false; Reason = 'stub-no-scroll-pattern'; Position = $null; ContainerId = ''; Axis = 'vertical' })
  $wheelUnavailableMessage = ''
  try { [void](Invoke-Handler-wheel-probe 'wheel' @('-1', '80', '50', '--to', 'Probe', '--verify-scroll')) } catch { $wheelUnavailableMessage = [string]$_.Exception.Message }
  ST-Check 'e2e (CU-REL-04): inaccessible UIA uses only an explicit local pixel rectangle and reports pixel-only or unknown-boundary outcomes' (
    $wheelPixelOnly -and $wheelPixelNoChange -and $wheelUnavailableMessage.Contains('verification unavailable before input') -and [DtxWheelProbe]::SendCount -eq 0)

  Reset-WheelProbe
  $script:WheelProbeTextSequence = @(
    @{ Available = $true; Found = $false; Reason = ''; Scanned = 5; NodeId = '' },
    @{ Available = $true; Found = $false; Reason = ''; Scanned = 5; NodeId = '' }
  )
  $script:WheelProbeMutateRectOnTextIndex = 2
  $wheelDriftMessage = ''
  try { [void](Invoke-Handler-wheel-probe 'wheel' @('-1', '80', '50', '--to', 'Probe', '--expect-visible-text', 'row 13')) } catch { $wheelDriftMessage = [string]$_.Exception.Message }
  Reset-WheelProbe
  $script:WheelProbeTextSequence = @(
    @{ Available = $true; Found = $false; Reason = ''; Scanned = 5; NodeId = '' },
    @{ Available = $true; Found = $false; Reason = ''; Scanned = 5; NodeId = '' }
  )
  $script:WheelProbeLoseTargetOnTextIndex = 2
  $wheelLostMessage = ''
  try { [void](Invoke-Handler-wheel-probe 'wheel' @('-1', '80', '50', '--to', 'Probe', '--expect-visible-text', 'row 13')) } catch { $wheelLostMessage = [string]$_.Exception.Message }
  ST-Check 'e2e (CU-REL-04): target geometry drift or target loss during bounded polling stops verification without a second input' (
    $wheelDriftMessage.Contains('status=target-changed') -and $wheelLostMessage.Contains('status=target-changed') -and [DtxWheelProbe]::SendCount -eq 1)

  $wheelScrollObservationLint = $wheelScrollObservationText.Contains('AutomationElement]::FromHandle($Target.Handle)') -and
    $wheelScrollObservationText.Contains('AutomationElement]::FromPoint($point)') -and $wheelScrollObservationText.Contains('ScrollPattern]::Pattern') -and
    $wheelScrollObservationText.Contains('point-not-in-selected-window-tree')
  $wheelContentObservationLint = $wheelContentObservationText.Contains('$maxNodes = 512') -and $wheelContentObservationText.Contains('.Current.IsOffscreen') -and
    $wheelContentObservationText.Contains('.Current.BoundingRectangle') -and $wheelContentObservationText.Contains('uia-node-cap')
  $wheelBoundedLint = $wheelHandlerText.Contains('$maxWaitMs = 1200; $pollMs = 100; $maxSamples = 13') -and
    $wheelHandlerText.Contains('attribution=not-proven') -and $wheelHandlerText.Contains('pixel-changed-only') -and
    $wheelHandlerText.Contains('requested=0 SendInput-inserted=0/1 verification=at-boundary') -and
    $wheelHandlerText.IndexOf('[DT]::SendWheelInput([int]$wheelRequest.RawDelta', [StringComparison]::Ordinal) -ge 0 -and
    @([regex]::Matches($wheelHandlerText, '\[DT\]::SendWheelInput\(')).Count -eq 1
  ST-Check 'lint (CU-REL-04): UIA measurements are scoped and visible-only, pixel fallback is bounded and labeled, and one wheel call is the maximum' (
    $wheelScrollObservationLint -and $wheelContentObservationLint -and $wheelBoundedLint)
  Write-Output ('      wheel verification probe: poll-sleep-ms=' + $script:WheelProbeSleepMs + ' input-count=' + [DtxWheelProbe]::SendCount + ' states=position/content/pixel/boundary/target-change')

  # ---------- v4.5.4 (CU-REL-05): closed screenshot arguments before capture ----------
  $shotHandlerAst = $wheelAst.Find({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -ceq 'Invoke-Handler-shot') }, $true)
  $shotHandlerText = if ($shotHandlerAst) { $shotHandlerAst.Extent.Text } else { '' }
  $shotProbeText = $shotHandlerText.Replace('function Invoke-Handler-shot(', 'function Invoke-Handler-shot-probe(')
  $shotProbeText = $shotProbeText.Replace('Split-OcclusionFlags ', 'Split-OcclusionFlags-shot-probe ')
  $shotProbeText = $shotProbeText.Replace('Parse-CaptureFlags ', 'Parse-CaptureFlags-shot-probe ')
  $shotProbeText = $shotProbeText.Replace('[System.Windows.Forms.SystemInformation]::VirtualScreen', 'Get-ShotProbeVirtualScreen')
  $shotProbeText = $shotProbeText.Replace('Default-ShotName ', 'Default-ShotProbeName ')
  $shotProbeText = $shotProbeText.Replace('Save-RectEx ', 'Save-ShotProbeRect ')
  $shotProbeText = $shotProbeText.Replace('Resolve-OcclusionMode ', 'Resolve-ShotProbeOcclusionMode ')
  $shotProbeText = $shotProbeText.Replace('Invoke-OcclusionOwners ', 'Invoke-ShotProbeOwners ')
  $shotOcclusionAst = $wheelAst.Find({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -ceq 'Split-OcclusionFlags') }, $true)
  $shotCaptureAst = $wheelAst.Find({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -ceq 'Parse-CaptureFlags') }, $true)
  $shotOcclusionText = if ($shotOcclusionAst) { $shotOcclusionAst.Extent.Text.Replace('function Split-OcclusionFlags(', 'function Split-OcclusionFlags-shot-probe(') } else { '' }
  $shotCaptureText = if ($shotCaptureAst) { $shotCaptureAst.Extent.Text.Replace('function Parse-CaptureFlags(', 'function Parse-CaptureFlags-shot-probe(') } else { '' }
  if ($shotOcclusionText -and $shotCaptureText -and $shotProbeText) { Invoke-Expression ($shotOcclusionText + "`n" + $shotCaptureText + "`n" + $shotProbeText) }
  function Reset-ShotProbe {
    $script:ShotProbeScreenReads = 0; $script:ShotProbeSaveCalls = 0; $script:ShotProbeSavedPath = ''
  }
  function Get-ShotProbeVirtualScreen {
    $script:ShotProbeScreenReads++
    return [pscustomobject]@{ X = 4; Y = 6; Width = 80; Height = 60 }
  }
  function Default-ShotProbeName([string]$Prefix) { return "synthetic-$Prefix.png" }
  function Save-ShotProbeRect([int]$X, [int]$Y, [int]$W, [int]$H, [string]$Path, [double]$Fit, [int]$Grid, $Marks, [string]$MapKind = '', $MapWin = $null, $CaptureFlags = $null) {
    $script:ShotProbeSaveCalls++
    $script:ShotProbeSavedPath = $Path
    return "saved $Path rect=($X,$Y) size=${W}x$H"
  }
  function Resolve-ShotProbeOcclusionMode($Mode, $Allow, [bool]$ForAssertion) { return @{ Action = 'off' } }
  function Invoke-ShotProbeOwners($Rect, [string]$Action, [int]$Grid) { return @{ Ran = $false; Echo = 'synthetic' } }

  Reset-ShotProbe
  $shotPathEcho = @(Invoke-Handler-shot-probe 'shot' @('0,0,400,80')) -join "`n"
  $shotSinglePathGood = $script:ShotProbeScreenReads -eq 1 -and $script:ShotProbeSaveCalls -eq 1 -and
    $script:ShotProbeSavedPath -ceq '0,0,400,80' -and $shotPathEcho.Contains('saved 0,0,400,80')
  Reset-ShotProbe
  $shotDefaultEcho = @(Invoke-Handler-shot-probe 'shot' @()) -join "`n"
  $shotDefaultGood = $script:ShotProbeScreenReads -eq 1 -and $script:ShotProbeSaveCalls -eq 1 -and
    $script:ShotProbeSavedPath -ceq 'synthetic-shot.png' -and $shotDefaultEcho.Contains('saved synthetic-shot.png')
  ST-Check 'e2e (CU-REL-05): one output path, including a rectangle-shaped filename, and the no-path default reach the existing capture call unchanged' (
    $shotSinglePathGood -and $shotDefaultGood)

  $shotBadCases = @(
    @{ Tokens = @('0', '0', '400', '80'); Needle = 'extra positional arguments' },
    @{ Tokens = @('--unknown'); Needle = 'unknown flag' }
  )
  $shotBadCount = 0; $shotBadNoCapture = $true
  foreach ($shotBad in $shotBadCases) {
    Reset-ShotProbe
    $shotBadMessage = ''
    try { [void](Invoke-Handler-shot-probe 'shot' @($shotBad.Tokens)) } catch { $shotBadMessage = [string]$_.Exception.Message }
    if ($shotBadMessage.Contains([string]$shotBad.Needle) -and $shotBadMessage.Contains('rect 0 2010 400 80 <outPath> --fit 0')) { $shotBadCount++ }
    if (-not $shotBadMessage.Contains([string]$shotBad.Needle) -or $script:ShotProbeScreenReads -ne 0 -or $script:ShotProbeSaveCalls -ne 0) { $shotBadNoCapture = $false }
  }
  ST-Check 'e2e (CU-REL-05): extra positions and unknown flags give the rect remedy before screen read or save' (
    $shotBadCount -eq @($shotBadCases).Count -and $shotBadNoCapture)

  $shotResolveAt = $shotHandlerText.IndexOf('Resolve-ShotOutputPath', [StringComparison]::Ordinal)
  $shotScreenAt = $shotHandlerText.IndexOf('[System.Windows.Forms.SystemInformation]::VirtualScreen', [StringComparison]::Ordinal)
  $shotSaveAt = $shotHandlerText.IndexOf('Save-RectEx ', [StringComparison]::Ordinal)
  $shotHelpSource = [string](Get-UsageText)
  $shotHelpLines = @($shotHelpSource -split "`r?`n")
  $shotUsageText = (@(Format-CommandHelp $shotHelpLines 'shot') -join "`n")
  $shotHelpContract = $shotUsageText.Contains('rect 0 2010 400') -and $shotUsageText.Contains('80 <outPath> --fit 0') -and
    $shotUsageText.Contains('imgclick or unmap') -and $shotUsageText.Contains('.map.txt')
  ST-Check 'lint (CU-REL-05): shot validates before virtual-screen access and save, and command help gives the local-crop mapping route' (
    $shotResolveAt -ge 0 -and $shotResolveAt -lt $shotScreenAt -and $shotScreenAt -lt $shotSaveAt -and $shotHelpContract)
  Write-Output ('      shot probe: invalid-cases=' + $shotBadCount + '/' + @($shotBadCases).Count + ' screen-reads=' + $script:ShotProbeScreenReads + ' save-calls=' + $script:ShotProbeSaveCalls)

}

