# lib/selftest.ps1 - the selftest section, lifted out of desktop.ps1 by A-11b.
# Bodies are byte-identical to what the entry carried; the only reason this file can exist at all
# is A-11a: inside a dot-sourced file $PSCommandPath names THIS file and $PSScriptRoot names lib/,
# so the section goes through $script:ToolEntryPath / $script:ToolRootPath, which the entry
# publishes at load time. A lint counts bare reads of either automatic variable per section and the
# count here must stay zero - a future card that moves code and reintroduces one fails by name.
function Invoke-SelfTest([string[]]$Rest) {
  # v2.6.0: a selftest run must never have its own captures moved out from under it -
  # `--live` writes st-* fixtures early and reads them back later, and the automatic
  # trim after each capture would sweep exactly the files still to be asserted. The flag
  # is never cleared: selftest is terminal for the process, and the worst a later command
  # in the same process can suffer is one skipped trim.
  $script:NoAutoTrim = $true
  # v4.3.0 (--index): a static listing read from this file's own source; never runs a check.
  # Combined use with any other selftest flag is refused by name, not ignored.
  if (@($Rest) -contains '--index') {
    foreach ($ixOther in @('--live', '--timing', '--only')) {
      if (@($Rest) -contains $ixOther) { throw ('selftest: --index cannot be combined with ' + $ixOther + ' (it lists checks; it never runs them)') }
    }
    $script:StModeLine = Get-SourceModeLine "$script:StSourceMode" @($script:StSourceFiles).Count
    Write-Output ('      ' + $script:StModeLine)
    if ("$script:StSourceMode" -ceq 'aggregate') {
      $script:StSourceSpans = Get-SourceLineSpans $script:ToolRootPath $script:StSourceFiles
      $ixLines = @((Get-AggregatedSource $script:ToolRootPath $script:StSourceFiles) -split "`r?`n")
    } else {
      $ixLines = @([System.IO.File]::ReadAllLines($script:ToolEntryPath, [System.Text.Encoding]::UTF8))
    }
    $ixEntries = @((Get-SelftestIndexEntries $ixLines).Entries)
    $ixStatic = @($ixEntries | Where-Object { $_.Kind -ceq 'static' }).Count
    $ixRegion = @($ixEntries | Where-Object { $_.Kind -ceq 'region' }).Count
    $ixTempl = @($ixEntries | Where-Object { $_.Kind -ceq 'template' }).Count
    Write-Output ('selftest index: ' + @($ixEntries).Count + ' entries (static=' + $ixStatic + ' region=' + $ixRegion + ' template=' + $ixTempl + ') declared-offline=' + $script:DeclaredCheckTotal)
    foreach ($ixE in @($ixEntries | Sort-Object -Property Line, Name)) {
      if ($ixE.Kind -ceq 'static') { Write-Output ((Format-SourceLineRef ([int]$ixE.Line)) + "`t" + [string]$ixE.Name) }
      else { Write-Output ('+' + "`t" + [string]$ixE.Name) }
    }
    return
  }
  $live = @($Rest) -contains '--live'
  $script:StPass = 0; $script:StFail = 0; $script:StSkip = 0
  $script:StPassLines = New-Object System.Collections.ArrayList
  # StrictMode is on: ST-Check/ST-Skip read this on EVERY call, so it must exist before
  # the first check runs - an unset script variable aborts the whole gate, which is a
  # louder failure than the one it guards but a useless one. Regions set it to a list.
  $script:StRecord = $null
  # v4.3.0 (--only): scope filter. Parsed here (the --index fast path above returned already).
  # Consulted ONLY through Test-StOnlyAbsorb, whose only two call sites are the emitters.
  $script:StOnlyPat = Resolve-SelftestOnlyPattern $Rest
  $script:StOnlyActive = ($script:StOnlyPat -ne '')
  $script:StAbsorbed = 0
  $script:StAbsorbedFail = 0
  $script:StEmittedAll = New-Object System.Collections.ArrayList
  if ($script:StOnlyActive) {
    if ($live) { throw 'selftest: --only cannot be combined with --live (the live ladder runs as a whole)' }
    Write-Output ("      filter: --only '" + $script:StOnlyPat + "' - only matching checks are reported; every check still executes and absorbed results are disclosed in the summary, not in the exit code")
  }
  # v4.2.4 (--timing): the per-check cost profile. The stopwatch starts HERE, before the file
  # reads its own source, so the first check's delta also carries the gate's own setup - the
  # profile answers "where do the minutes go", it is not there to flatter the first check.
  $script:StTiming = (@($Rest) -contains '--timing')
  $script:StSw = [System.Diagnostics.Stopwatch]::StartNew()
  $script:StLastMs = 0.0
  $self = $script:ToolEntryPath
  $src = if ("$script:StSourceMode" -ceq 'aggregate') { Get-AggregatedSource $script:ToolRootPath $script:StSourceFiles } else { Get-Content -LiteralPath $self -Raw }
  # !! Built here, not only in the --index fast path: every echo below resolves through it,
  #    and an empty span map would print beyond-aggregate for every single line number.
  if ($script:StSourceMode -ceq 'aggregate') { $script:StSourceSpans = Get-SourceLineSpans $script:ToolRootPath $script:StSourceFiles }
  $script:StModeLine = Get-SourceModeLine "$script:StSourceMode" @($script:StSourceFiles).Count
  Write-Output ('      ' + $script:StModeLine)
  # v4.1.3: the region helpers below need the file's own lines from the FIRST gated
  # region onward, which is earlier than $codeLines is built - so the raw split is
  # published here. Line numbers match $codeLines exactly (that pass never deletes lines).
  $script:StSourceLines = @($src -split "`r?`n")

  # v4.1.3 (external review D): the call operator resolves through PATH, so a harness whose
  # PATH lacks WindowsPowerShell cannot spawn a child at all - three offline checks then
  # reported a product failure for the caller's environment. The git family in this same
  # file already treats "no git in PATH" as "nothing to measure" and SKIPS; that stance is
  # now shared. One probe, and every `& powershell` check accounts for itself either way.
  # (Start-Process -FilePath 'powershell.exe' still resolves through App Paths, so the
  # fixture families that spawn that way are unaffected - measured in the 4-context matrix.)
  $script:PsChildOk = $true
  $script:PsChildWhy = ''
  try {
    if ($null -eq (Get-Command powershell.exe -ErrorAction SilentlyContinue)) {
      $script:PsChildOk = $false
      $script:PsChildWhy = 'no powershell.exe resolvable in PATH'
    }
  } catch {
    $script:PsChildOk = $false
    $script:PsChildWhy = 'probe threw: ' + $_.Exception.Message
  }
  Write-Output ('      child-spawn probe: ok=' + [bool]$script:PsChildOk + $(if ($script:PsChildOk) { '' } else { ' reason=' + $script:PsChildWhy }))

  # G-21 (owner ruling 2026-10-20 14:4x, item 3): the two child faces are ONE question only if
  # nobody measures them. Measured on this box in both engines
  # (start-process-face-ps51.json and start-process-face-pwsh7.json in the G-21 evidence directory,
  # whose full path is registered in the construction ledger): with
  # System32\WindowsPowerShell off PATH, Get-Command powershell.exe answers nothing and a bare
  # `& powershell` yields an empty face, while `Start-Process powershell -Wait -PassThru` STILL runs
  # the child and reads back its exit code, because Start-Process resolves through App Paths. A block
  # that raises its fixture with Start-Process and then drives the tool with `& powershell` therefore
  # needs BOTH answers, each carrying its own reason. The value below is a runtime probe of a real
  # child - NOT a count of how many sites reference it; lint (G-21) prints the two apart.
  $script:PsStartOk = $true
  $script:PsStartWhy = ''
  try {
    $psStartProbe = Start-Process powershell -ArgumentList '-NoProfile', '-Command', 'exit 0' -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
    if ($null -eq $psStartProbe -or $psStartProbe.ExitCode -ne 0) {
      $script:PsStartOk = $false
      $script:PsStartWhy = 'Start-Process powershell gave no clean exit (child=' + $(if ($psStartProbe) { [string]$psStartProbe.ExitCode } else { 'null' }) + ')'
    }
  } catch {
    $script:PsStartOk = $false
    $script:PsStartWhy = 'Start-Process probe threw: ' + $_.Exception.Message
  }
  Write-Output ('      start-process probe: ok=' + [bool]$script:PsStartOk + $(if ($script:PsStartOk) { '' } else { ' reason=' + $script:PsStartWhy }))

  # v4.4.0 (A-14c): shared state that the families consume is produced HERE, not inside one gate body.
  # A-14b measured it: nearly every remaining family reads $codeLines / $clCount / $code (and the
  # production-window pair), while those were built inside the wrapper-lint and J-05 bodies. A lifted
  # family cannot read a caller local - $Ctx is the only channel by design - so the producers move up
  # and get published. No check moves with them, and the emitted order is asserted unchanged in this
  # same commit: relocating production must not be able to shuffle what a run reports.
  # One pass over the real source lines, blanking everything inside a here-string.
  # Needed twice: Usage() documents the literal shapes "@(Fn)" and "return ,$list",
  # and scanning that prose would both misclassify Usage as a comma-returning
  # helper and make the helper list (hence the whole lint) garbage while still
  # reporting PASS. Line numbers stay true because we never delete lines.
  $codeLines = @()
  $inHere = $false
  foreach ($l in ($src -split "`r?`n")) {
    if ($inHere) {
      $codeLines += ''
      if ($l -match "^'@") { $inHere = $false }
      continue
    }
    if ($l -match "@'\s*$") { $codeLines += ''; $inHere = $true; continue }
    $codeLines += $l
  }
  # v4.2.4 (perf): hoist the count ONCE. @( ) re-copies the array on every evaluation, so a
  # for-condition carrying @($codeLines).Count is O(n^2) - measured on this very file: the
  # three-round loop with the count inline cost 44,885 ms, the identical loop with it hoisted
  # cost 81 ms. $codeLines is built once above and never reassigned afterwards, so one hoist
  # covers every scan below without changing what any of them read.
  $clCount = $codeLines.Count
  $code = $codeLines -join "`n"
  $srcLines = @($src -split "`r?`n")
  # v4.4.0 (A-14j): three more shared inputs are produced here rather than inside the docs-contract
  # body, for the same reason as the A-14c set - window-targeting and chrome-cdp read them, and a
  # lifted family cannot reach a caller local. The usage page is built from $src, and the case-start
  # scan walks the dispatcher body once; both are pure measurements, so hoisting them changes no
  # verdict, only where the number is produced.
  $hLines = Get-UsageLines
  # the coverage lint: every real command the dispatcher accepts must be findable in help.
  $hCaseStarts = @{}
  $hFnStart = -1; $hFnEnd = $codeLines.Count
  for ($i = 0; $i -lt $codeLines.Count; $i++) { if ($codeLines[$i] -match '^function Invoke-DesktopCommand') { $hFnStart = $i; break } }
  if ($hFnStart -ge 0) { for ($i = $hFnStart + 1; $i -lt $codeLines.Count; $i++) { if ($codeLines[$i] -match '^function ') { $hFnEnd = $i; break } } }
  for ($i = $hFnStart; $i -lt $hFnEnd; $i++) {
    if ($codeLines[$i] -match ('^\s{4}' + "'" + '([a-z0-9-]+)' + "'" + ' \{$')) {
      $hn = "$($Matches[1])"
      if (-not $hCaseStarts.ContainsKey($hn)) { $hCaseStarts[$hn] = $i }
    }
  }

  # count PRODUCTION sites only: the selftest bodies call these helpers themselves, and a scan that
  # does not exclude its own test code measures the wrong thing (9 here at first).
  # v4.4.0 (A-14f): the window used to be "up to the next ^function", which stops at the first family
  # file - so every family that moved out was re-counted as production (measured 2026-10-15: the
  # attempt-gate and F2 normalizer lints reddened on the move). It is now the AST extent of EVERY
  # selftest body, orchestrator plus each lifted family, and lint (A-14f) checks that no foreign
  # function hides inside that span - the width is verified, not assumed.
  # ST-Check is deliberately NOT named here: it lives in the entry's tail, which in aggregate
  # coordinates sits after every family file, so naming it stretched the span across the whole
  # dispatcher and made production code read as exempt. lint (A-14f) is what keeps that honest.
  $j5Names = @('Invoke-SelfTest')
  foreach ($j5k in @($script:StFamilyLifted)) { $j5Names += Get-FamilyFunctionName $j5k }
  $j5SelfParsed = Parse-SourceForInventory (@($script:StSourceLines) -join "`n")
  $j5Window = Get-SelftestWindow $j5SelfParsed @($j5Names)
  $j5ProdEnd = $codeLines.Count
  $j5ProdStart = 0
  if (("$j5Window" -ne '-absent') -and ("$j5Window" -ne '-no-parse')) {
    $j5W = @([string]$j5Window -split "`t", 2)
    $j5ProdStart = ([int]$j5W[0] - 1)
    $j5ProdEnd = [int]$j5W[1]
  }

  # ---------- v4.4.0 (A-14r): two producers hoisted out of the gate bodies ----------
  # Both were inline leftovers: the comma scan fed a body two runs away, and the production slice fed the
  # move-and-manifest gate plus the P-06 gate. A lifted family may only be handed published context, so
  # each is computed HERE - above every publish - and handed over as a key. Neither is a re-derivation
  # of the window: the slice uses $j5ProdStart/$j5ProdEnd exactly as computed above, which is the whole
  # reason it could move without inventing a second window scan (lint (A-14i) refuses that shape).
  # Value invariance is asserted at the publish site by lint (A-14r), not argued: the slice length has to
  # equal the window formula, and the helper list has to be the same object the setup built.
  $a14fExempt = @('Invoke-SelfTest', 'ST-Check')
  foreach ($a14fK in @($script:StFamilyLifted)) { $a14fExempt += Get-FamilyFunctionName $a14fK }
  $commaFns = New-Object System.Collections.ArrayList
  foreach ($cn in (@((Get-CommaReturningHelperNames "$code" @($a14fExempt)) -split ','))) {
    if ($cn -ne '') { [void]$commaFns.Add([string]$cn) }
  }
  $stDefIdx = $j5ProdStart
  $stEndIdx = $j5ProdEnd
  $mvProd = @($codeLines)
  if ($stDefIdx -ge 0) {
    $mvProd = @($codeLines[0..($stDefIdx - 1)])
    if ($stEndIdx -lt $clCount) { $mvProd = @($mvProd + @($codeLines[$stEndIdx..($clCount - 1)])) }
  }

  # assembled marker: a scan line must not contain its own search string (it would match itself)
  $evMark = 'Format-Expectation' + 'Verdict '
  # production sites only ($j5ProdStart/$j5ProdEnd are the selftest body bounds computed just above)
  # - counting the units that call the formatter is not counting wiring. v4.4.0 (A-14m): this producer
  # moved up here from the inline body because the family that READS the result is moving out of the
  # section, and a lifted body may only be handed published context - not a caller local.
  $evWire = @()
  for ($ei = 0; $ei -lt $codeLines.Count; $ei++) {
    if ($ei -ge $j5ProdStart -and $ei -lt $j5ProdEnd) { continue }
    if ($codeLines[$ei] -match '^\s*#') { continue }
    if ($codeLines[$ei].Contains($evMark)) { $evWire += ($ei + 1) }
  }
  # v4.4.0 (A-14o): hoisted out of the F-00-A body so a lifted family can be handed it. Deterministic
  # scans over $codeLines, which is built above this point and never rewritten after it - the values
  # the inline gates read are the same objects they were before the move.
  $gaDispStart = -1; $gaDispEnd = $codeLines.Count; $gaHelpStart = -1; $gaHelpEnd = -1
  for ($gai = 0; $gai -lt $codeLines.Count; $gai++) {
    if ($codeLines[$gai] -match ('^function Invoke-' + 'DesktopCommand')) { $gaDispStart = $gai }
    elseif (($gaDispStart -ge 0) -and ($codeLines[$gai] -match '^function ')) { $gaDispEnd = $gai; break }
  }
  for ($gai = 0; $gai -lt $codeLines.Count; $gai++) {
    if ($codeLines[$gai] -match ('^function Get-' + 'UsageText')) { $gaHelpStart = $gai }
    elseif (($gaHelpStart -ge 0) -and ($codeLines[$gai] -match '^function ')) { $gaHelpEnd = $gai; break }
  }
  $gaCases = @()
  $gaCurName = ''; $gaCurStart = -1
  for ($gai = $gaDispStart; $gai -lt $gaDispEnd; $gai++) {
    if ($codeLines[$gai] -match "^    '([A-Za-z0-9-]+)' \{") {
      if ($gaCurStart -ge 0) { $gaCases += ,@($gaCurName, $gaCurStart, $gai) }
      $gaCurName = $Matches[1]; $gaCurStart = $gai
    }
  }
  if ($gaCurStart -ge 0) { $gaCases += ,@($gaCurName, $gaCurStart, $gaDispEnd) }
  $gaCasesCount = @($gaCases).Count
  $gaCaseIdx = {
    param($nm)
    for ($gk = 0; $gk -lt $gaCasesCount; $gk++) { if ($gaCases[$gk][0] -eq $nm) { return $gk } }
    return -1
  }
  # v4.4.0 (A-14b, A-beta): the two families that used to be this section's contiguous head are
  # their own files now. $Ctx is the only channel between them and this scope, the calls sit
  # exactly where the bodies sat, and nothing in this section changed its relative order.
  $Ctx = @{}
  $Ctx['self'] = $self
  $Ctx['src'] = $src
  # the published set is the family contract; lint (A-14c) reconciles it against $script:StCtxKeys
  $Ctx['codeLines'] = $codeLines
  $Ctx['clCount'] = $clCount
  $Ctx['code'] = $code
  $Ctx['j5ProdStart'] = $j5ProdStart
  $Ctx['j5ProdEnd'] = $j5ProdEnd
  $Ctx['srcLines'] = $srcLines
  $Ctx['hLines'] = $hLines
  $Ctx['hCaseStarts'] = $hCaseStarts
  $Ctx['hFnStart'] = $hFnStart
  $Ctx['hFnEnd'] = $hFnEnd
  $Ctx['evMark'] = $evMark
  $Ctx['evWire'] = $evWire
  $Ctx['gaCases'] = $gaCases
  $Ctx['gaCaseIdx'] = $gaCaseIdx
  # A-14p: the live family needs the audit path, the capture folder and the mode flag. All three are
  # settled before this point (entry load-time globals and the --live parse at the top of the body), so
  # publishing them here hands over the same value the inline body has always read.
  $Ctx['actionLog'] = $ActionLog
  $Ctx['outDir'] = $OutDir
  $Ctx['live'] = $live
  # A-14q: gate-meta's gates read the case-table count and the help/dispatcher bounds alongside the
  # arrays already handed over. Every producer sits ABOVE this point (155 j5SelfParsed, 180 the ga*
  # bounds, 198 gaCasesCount - measured by a14q-producers.js), so this is the safe half of the A-14p
  # rule: a value that already exists may be published, a live enumeration may not be re-taken earlier.
  $Ctx['gaCasesCount'] = $gaCasesCount
  $Ctx['gaDispStart'] = $gaDispStart
  $Ctx['gaHelpStart'] = $gaHelpStart
  $Ctx['gaHelpEnd'] = $gaHelpEnd
  $Ctx['j5SelfParsed'] = $j5SelfParsed
  # v4.4.0 (A-14r): the two hoisted producers join the published surface. Registering a key without
  # publishing it is caught by lint (A-14c) - it did catch it, on the first run of this card.
  $Ctx['commaFns'] = $commaFns
  $Ctx['stDefIdx'] = $stDefIdx
  $Ctx['stEndIdx'] = $stEndIdx
  $Ctx['mvProd'] = $mvProd
  # v4.5.5 (TB-1): the version definition joins the published surface so the version family can pin
  # definition == header == runtime source_version without a lifted body reaching into the entry's
  # script scope. The constant is settled at load time, so this is a settled publish, not a re-read.
  $Ctx['ToolVersion'] = "$script:ToolVersion"
  Invoke-SelftestFamily-SplitMachine $Ctx
  Invoke-SelftestFamily-RepoContract $Ctx
  # ---------- v4.4.0 (A-14l): state handed back out of a lifted family is declared on both sides ----------
  # A lifted body still produces values the orchestration reads later. Those travel back through $Ctx and
  # get re-bound by name, so the downstream bodies stay byte-identical - but an undeclared write is
  # invisible to every table, and a declared-but-unwritten key re-binds to $null. Both directions are
  # measured here, and the witnesses below run even while no family declares an export: a gate over an
  # empty set is precisely how a silent green is born.
  $a14lGaps = @()
  # Every lifted family is scanned, including the ones that declare NO hand-back: for those the
  # declared list is empty, so the scan's job is to refuse any write into the context at all. Skipping
  # them was a coverage hole - a family could start writing $Ctx keys and only the A-14b contract would
  # notice, while the gate whose name promises this direction stayed silent by construction.
  foreach ($a14lK in @($script:StFamilyLifted)) {
    $a14lGaps += Get-FamilyExportGap $j5SelfParsed (Get-FamilyFunctionName $a14lK) @(Get-FamilyExportNames $a14lK)
  }
  $a14lGapCount = 0
  foreach ($a14lG in @($a14lGaps)) { if ([string]$a14lG -ne '') { $a14lGapCount = $a14lGapCount + 1 } }
  $a14lPlant = @(
    'function Invoke-SelftestFamily-Written {',
    '  $Ctx[''declared''] = 1',
    '  return 1',
    '}',
    'function Invoke-SelftestFamily-Silent {',
    '  return 1',
    '}'
  )
  $a14lPlantParsed = Parse-SourceForInventory ($a14lPlant -join "`n")
  # one witness per direction: a declared key the body never writes, a written key nobody declared,
  # and a body that is not there at all
  $a14lPDeclOnly = Get-FamilyExportGap $a14lPlantParsed 'Invoke-SelftestFamily-Written' @('declared', 'missing')
  $a14lPUndecl = Get-FamilyExportGap $a14lPlantParsed 'Invoke-SelftestFamily-Written' @()
  $a14lPSilent = Get-FamilyExportGap $a14lPlantParsed 'Invoke-SelftestFamily-Silent' @('x')
  $a14lPAbsent = Get-FamilyExportGap $a14lPlantParsed 'Nowhere-At-All' @('x')
  ST-Check 'lint (A-14l): every exported key a lifted family declares is actually handed back, every hand-back is declared, and the scanner reports both mistakes plus the absent body on planted sources' (
    ($a14lGapCount -eq 0) -and ($a14lPDeclOnly -ceq 'missing=declared-not-written') -and
    ($a14lPUndecl -ceq 'declared=written-not-declared') -and ($a14lPSilent -ceq 'x=declared-not-written') -and
    ($a14lPAbsent -ceq '-absent'))
  foreach ($a14lG in @($a14lGaps)) { if ([string]$a14lG -ne '') { Write-Output ('      A-14l export gap: ' + [string]$a14lG) } }
  Write-Output ('      A-14l exports: families=' + @($script:StFamilyLifted).Count +
    ' declared-not-written=[' + ("$a14lPDeclOnly") + '] written-not-declared=[' + ("$a14lPUndecl") +
    '] silent=[' + ("$a14lPSilent") + '] absent=' + ("$a14lPAbsent"))
  # ---------- v4.4.0 (A-14l): a declared hand-back is only useful if the orchestration binds it back ----------
  # The family side is measured above; this is the caller side, and it is the half a later card can break
  # without touching a family file at all (delete one re-bind line, or move it above the call). Three more
  # refusals come from the same leaf: a doubled re-bind, a hand-back nobody reads, and a hand-back declared
  # for a family that was never lifted - a dead table row that claims a channel which does not exist, and
  # the loop over lifted families would never look at it.
  $a14lRbPlant = @(
    'function Invoke-SelftestFamily-RbGood($Ctx) { return 1 }',
    '  Invoke-SelftestFamily-RbGood $Ctx',
    '  $good = $Ctx[''good'']',
    '  Write-Output $good',
    'function Invoke-SelftestFamily-RbEarly($Ctx) { return 1 }',
    '  $early = $Ctx[''early'']',
    '  Invoke-SelftestFamily-RbEarly $Ctx',
    'function Invoke-SelftestFamily-RbDup($Ctx) { return 1 }',
    '  Invoke-SelftestFamily-RbDup $Ctx',
    '  $dup = $Ctx[''dup'']',
    '  $dup = $Ctx[''dup'']',
    'function Invoke-SelftestFamily-RbQuiet($Ctx) { return 1 }',
    '  Invoke-SelftestFamily-RbQuiet $Ctx',
    '  $unread = $Ctx[''unread'']',
    'function Invoke-SelftestFamily-RbNoCall($Ctx) { return 1 }'
  )
  $a14lRbPlantParsed = Parse-SourceForInventory ($a14lRbPlant -join "`n")
  $a14lRbGood = Get-FamilyExportReadbackGap $a14lRbPlantParsed @($a14lRbPlant) 'Invoke-SelftestFamily-RbGood' @('good')
  $a14lRbEarly = Get-FamilyExportReadbackGap $a14lRbPlantParsed @($a14lRbPlant) 'Invoke-SelftestFamily-RbEarly' @('early')
  $a14lRbDup = Get-FamilyExportReadbackGap $a14lRbPlantParsed @($a14lRbPlant) 'Invoke-SelftestFamily-RbDup' @('dup')
  $a14lRbQuiet = Get-FamilyExportReadbackGap $a14lRbPlantParsed @($a14lRbPlant) 'Invoke-SelftestFamily-RbQuiet' @('unread', 'gone')
  $a14lRbNoCall = Get-FamilyExportReadbackGap $a14lRbPlantParsed @($a14lRbPlant) 'Invoke-SelftestFamily-RbNoCall' @('x')
  $a14lRbNoBody = Get-FamilyExportReadbackGap $a14lRbPlantParsed @($a14lRbPlant) 'Invoke-SelftestFamily-NoSuchBody' @('x')
  $a14lRbGaps = @()
  $a14lRbUnknown = @()
  foreach ($a14lX in @(Get-HashKeys $script:StFamilyExports)) {
    $a14lSeen = $false
    foreach ($a14lK in @($script:StFamilyLifted)) { if (([string]$a14lK) -ceq ([string]$a14lX)) { $a14lSeen = $true } }
    if (-not $a14lSeen) { $a14lRbUnknown += ([string]$a14lX) }
  }
  foreach ($a14lK in @($script:StFamilyLifted)) {
    $a14lEx = @(Get-FamilyExportNames $a14lK)
    if ($a14lEx.Count -eq 0) { continue }
    $a14lRbGaps += Get-FamilyExportReadbackGap $j5SelfParsed @($script:StSourceLines) (Get-FamilyFunctionName ([string]$a14lK)) $a14lEx
  }
  $a14lRbCount = 0
  foreach ($a14lG in @($a14lRbGaps)) { if ([string]$a14lG -ne '') { $a14lRbCount = $a14lRbCount + 1 } }
  ST-Check 'lint (A-14l): every declared hand-back is re-bound by name below its family call and read by a body that stayed in the section, no hand-back is declared for a family that was not lifted, and the scanner reports a missing, an early, a doubled and an unread re-bind plus the absent call and the absent body on planted sources' (
    ($a14lRbCount -eq 0) -and (@($a14lRbUnknown).Count -eq 0) -and
    ($a14lRbGood -ceq '') -and ($a14lRbEarly -ceq 'early=read-before-call') -and
    ($a14lRbDup -ceq 'dup=read-back-dup2') -and
    ($a14lRbQuiet -ceq 'unread=no-downstream-reader;gone=never-read-back') -and
    ($a14lRbNoCall -ceq 'Invoke-SelftestFamily-RbNoCall-no-call') -and ($a14lRbNoBody -ceq '-absent-body'))
  foreach ($a14lG in @($a14lRbGaps)) { if ([string]$a14lG -ne '') { Write-Output ('      A-14l read-back gap: ' + [string]$a14lG) } }
  Write-Output ('      A-14l read-backs: families-with-exports=' + @($a14lRbGaps).Count + ' unknown=[' + ($a14lRbUnknown -join ';') +
    '] plants=[good=' + ("$a14lRbGood") + ' early=' + ("$a14lRbEarly") + ' dup=' + ("$a14lRbDup") +
    ' quiet=' + ("$a14lRbQuiet") + ' no-call=' + ("$a14lRbNoCall") + ' no-body=' + ("$a14lRbNoBody") + ']')
  Write-Output "      comma-returning helpers: $($commaFns -join ', ')"

  foreach ($fn in $commaFns) {
    $pat = '[@$]\(\s*' + [regex]::Escape($fn) + '\b'
    $bad = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $codeLines.Count; $i++) {
      $l = $codeLines[$i]
      if ($l -match 'SELFTEST-EXEMPT') { continue }
      if ($l -match $pat) { [void]$bad.Add($i + 1) }
    }
    ST-Check "lint: no @()/`$() wrapper around $fn" ($bad.Count -eq 0)
    if ($bad.Count -gt 0) { Write-Output "      planted at line(s): $(Format-SourceLineList $bad)" }
    # positive control: prove the pattern is not vacuous, i.e. it WOULD fire
    $planted = '$x = @(' + $fn + ' $a $b)'
    ST-Check "lint: pattern detects a planted violation for $fn" ($planted -match $pat)
  }

  # v1.5.0 task invariant: new helpers return hashtables, and even a hashtable
  # result must never be wrapped in @()/$() - pointless at best, Object[1]{...}
  # at worst. Same no-wrapper rule, same planted-violation control per helper.
  $hashFns = @('Get-OcrTilePlan', 'Get-ScreenBitmap', 'Invoke-OcrBitmap', 'Merge-OcrTileLines', 'Invoke-OcrBitmapTiled', 'Invoke-OcrRegionTiled', 'Get-HitWindow', 'Read-MapSidecar', 'Convert-ImageToScreen', 'Get-OcclusionPoints', 'Merge-OcclusionHits', 'Get-OcclusionScan', 'Get-OcclusionVerdict', 'Get-RegionOwners', 'Resolve-OcclusionMode', 'Split-OcclusionFlags', 'Invoke-OcclusionGate', 'Invoke-OcclusionOwners', 'Get-WindowVisibleRect', 'Test-MapSidecarStale', 'Split-ReplayFlags', 'Test-ReplayStepRedacted', 'Resolve-ClipboardKind', 'Read-SendFileUtf8', 'Get-UiaVerifyCrossCheck', 'Get-UiaWindowNames', 'New-OcrJsonEnvelope', 'Format-OcclusionCovering', 'Get-OwnFlagTable', 'Get-OwnFlagSpec', 'Strip-OwnFlags')
  foreach ($fn in $hashFns) {
    $pat = '[@$]\(\s*' + [regex]::Escape($fn) + '\b'
    $bad = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $codeLines.Count; $i++) {
      $l = $codeLines[$i]
      if ($l -match 'SELFTEST-EXEMPT') { continue }
      if ($l -match $pat) { [void]$bad.Add($i + 1) }
    }
    ST-Check "lint: no @()/`$() wrapper around hashtable helper $fn" ($bad.Count -eq 0)
    $planted = '$x = @(' + $fn + ' $a $b)'
    ST-Check "lint: pattern detects a planted violation for $fn" ($planted -match $pat)
  }
  # negative control: a legit BARE hashtable-helper call must not trip the pattern
  ST-Check 'lint: bare hashtable helper call does not match the wrapper pattern' (
    'Invoke-OcrRegionTiled $x $y $w $h 2.0 16' -notmatch '[@$]\(\s*Invoke-OcrRegionTiled\b')

  # v4.4.0 (A-14i): family flags-grammar now lives in lib/selftest-flags-grammar.ps1; the call sits
  # at the position its first piece had, and the thirteen pieces behind it moved up to join it.
  Invoke-SelftestFamily-FlagsGrammar $Ctx
  # v4.4.0 (A-14q + A-14r): family gate-meta lives in lib/selftest-gate-meta.ps1 - the last family.
  # A-14q moved 18 of its 24 banner runs; A-14r moves 4 more (the ones held back because a re-bound
  # hand-back or an un-hoisted producer was still read inline) and moves the CALL to sit below the
  # publish further in, because registering the five keys never proved the values were ready when
  # gate-meta ran - lint (A-14r) measures that chain per name. Two runs stay for structure: the live
  # window-snapshot production with the A-14p publish site, and the --index/--only tail, which grades
  # this run's own transcript and belongs at the end.
  # v4.4.0 (A-14h): family capture-ocr now lives in lib/selftest-capture-ocr.ps1; the call sits at
  # the position its first piece had, and the seven pieces behind it moved up to join it.
  Invoke-SelftestFamily-CaptureOcr $Ctx
  # v4.4.0 (A-14l): family popup-occlusion now lives in lib/selftest-popup-occlusion.ps1; the call sits
  # at the position its first piece had, and its four later pieces moved up to join it (this family is
  # the popup/occlusion set). The five names below are the hand-back: every one of them is still
  # read by inline bodies further down this section, so they come back by declaration, not by scope luck.
  Invoke-SelftestFamily-PopupOcclusion $Ctx
  $dcCase = $Ctx['dcCase']
  $dcKnown = $Ctx['dcKnown']
  $wA = $Ctx['wA']
  $wB = $Ctx['wB']
  $wT = $Ctx['wT']
  # >>> A-14r CHAIN - fenced so the cutter leaves this block in the orchestration: it judges the order of
  #     lines that exist only here, and it reads $Ctx as the orchestrator rather than as a family.
  # v4.4.0 (A-14r): the chain is now produce -> named re-bind -> PUBLISH -> consume. Registering the five
  # keys would not prove a consumer can read a value that exists, so the order is measured from the
  # source and the values are pinned: each published entry must be the SAME object the re-bind just
  # bound (an interleaved value reddens it), the shapes must be what the consumers use, and the gate-meta
  # call must sit BELOW the publish - which is the point of this card, because the call used to run
  # above it and only got away with it because its hand-back consumers stayed inline.
  $Ctx['dcCase'] = $dcCase
  $Ctx['dcKnown'] = $dcKnown
  $Ctx['wA'] = $wA
  $Ctx['wB'] = $wB
  $Ctx['wT'] = $wT
  $a14rChainGap = Get-HandbackChainGap $codeLines 'Invoke-SelftestFamily-PopupOcclusion' 'Invoke-SelftestFamily-GateMeta' @('dcCase', 'dcKnown', 'wA', 'wB', 'wT')
  $a14rOrder = ($a14rChainGap -ceq '')
  $a14rSame = ([object]::ReferenceEquals($Ctx['wA'], $wA)) -and ([object]::ReferenceEquals($Ctx['wB'], $wB)) -and ([object]::ReferenceEquals($Ctx['wT'], $wT))
  $a14rShape = (@($Ctx['dcCase']).Count -ge 1) -and (@($Ctx['dcKnown']).Count -ge 1) -and ($null -ne $Ctx['wA'].Handle) -and ($Ctx['wT'].Transparent -eq $true)
  $a14rSlice = (@($Ctx['mvProd']).Count -eq ($clCount - ($j5ProdEnd - $j5ProdStart)))
  $a14rComma = (@($Ctx['commaFns']).Count -eq @($commaFns).Count) -and ($Ctx['commaFns'].Count -ge 3)
  ST-Check 'lint (A-14r): the hand-back chain is ordered produce -> re-bind -> publish -> family call, the published values are the very objects re-bound above, and the two hoisted producers hand over the value the setup computed' (
    $a14rOrder -and $a14rSame -and $a14rShape -and $a14rSlice -and $a14rComma)
  Write-Output ('      A-14r chain: gap=[' + $a14rChainGap + ']' +
    ' same-objects=' + $a14rSame + ' mvProd=' + (@($Ctx['mvProd']).Count) + '/' + ($clCount - ($j5ProdEnd - $j5ProdStart)) +
    ' commaFns=' + (@($Ctx['commaFns']).Count) + '/' + @($commaFns).Count + ' dcCase=' + (@($Ctx['dcCase']).Count))
  # <<< A-14r CHAIN
  # v4.4.0 (A-14r): the call sits HERE, below the publish it consumes. The four runs lifted by this
  # cut read $dcCase / $dcKnown / $wA out of $Ctx (bound by the adapter in the family file), so the
  # chain the gate above just certified is the channel they really use.
  Invoke-SelftestFamily-GateMeta $Ctx
  # v4.4.0 (A-14m): family audit-output now lives in lib/selftest-audit-output.ps1; the call sits at
  # the position its first piece had, and its four later pieces moved up to join it (this family is the
  # audit/outlet set). One line from its third piece is deliberately left in place below: the
  # dialog-cancel echo reads the hand-back names A-14l binds into this scope, and a lifted family
  # reads only published context - routing a value between two families would be a new channel.
  Invoke-SelftestFamily-AuditOutput $Ctx
  # v4.4.0 (A-14j): family window-targeting now lives in lib/selftest-window-targeting.ps1; the call
  # sits at the position its first piece had, and the nine pieces behind it moved up to join it.
  Invoke-SelftestFamily-WindowTargeting $Ctx
  # v4.4.0 (A-14n): family expect-family now lives in lib/selftest-expect-family.ps1; the call sits at
  # the position its first run had, and its later runs moved up to join it (this family is the
  # expectation set). The F-02 section rides inside a try/finally, so its deeper-indented banner does
  # not delimit a run; the live --verify-timeout banner of this family is nested in a body that has
  # not moved and stays here; and the dialog-cancel echo below stays because it reads hand-back names
  # A-14l binds in this scope.
  Invoke-SelftestFamily-ExpectFamily $Ctx
  Invoke-SelftestFamily-ClipboardInput $Ctx
  # ---------- unit: window model ----------
  $wins = @(Get-WinList)
  ST-Check 'unit: Get-WinList non-empty' ($wins.Count -gt 0)
  $w0 = $wins | Sort-Object -Property Area -Descending | Select-Object -First 1
  # A-14p: published IN PLACE on purpose. Get-WinList enumerates live windows; hoisting the production
  # into setup would move that snapshot hundreds of gates earlier and let the live family judge a
  # different desktop than the one this point in the run has always seen. A-14o's precondition checks
  # (no later write, consumers re-initialise) were both run: 967/969 are the only writes in the
  # section, and the family reads them once each, downstream of here.
  $Ctx['wins'] = $wins
  $Ctx['w0'] = $w0
  # A-14p: the publish is here, not in setup, and this check is what pins that choice. ReferenceEquals
  # says the family receives the very snapshot this line produced - a hoisted re-derivation would pass a
  # count test and still be a different enumeration taken at a different moment.
  $a14pSameWins = [object]::ReferenceEquals($Ctx['wins'], $wins)
  $a14pSameW0 = [object]::ReferenceEquals($Ctx['w0'], $w0)
  $a14pWinsN = @($Ctx['wins']).Count
  $a14pW0Pid = -1
  if ($null -ne $Ctx['w0']) { $a14pW0Pid = [int]$Ctx['w0'].Pid }
  ST-Check 'lint (A-14p): the live window snapshot is published where it is produced and handed over as the same objects, so no family can receive a re-taken enumeration' (
    ($a14pSameWins -eq $true) -and ($a14pSameW0 -eq $true) -and ($a14pWinsN -ge 1) -and ($a14pW0Pid -gt 0))
  Write-Output ('      A-14p in-place publish: same-wins=' + $a14pSameWins + ' same-w0=' + $a14pSameW0 +
    ' rows=' + $a14pWinsN + ' w0-pid=' + $a14pW0Pid)
  ST-Check 'unit: every row carries pid/proc/class/handle/title' (
    $w0.Pid -gt 0 -and $w0.Proc -and $w0.Class -and $w0.Handle -ne [IntPtr]::Zero -and $null -ne $w0.Title)
  # v1.5.7 (D-7): owner/main are part of the row contract now, and the map must leave
  # EXACTLY ONE main=yes per process - two of them would make the note meaningless and
  # zero of them would mean every pick looks wrong.
  ST-Check 'unit: every row carries owner and main (D-7 columns exist on all rows)' (
    $null -ne $w0.PSObject.Properties['Owner'] -and ($w0.Main -ceq 'yes' -or $w0.Main -ceq 'no'))
  $badMain = @($wins | Group-Object -Property Pid | Where-Object { @($_.Group | Where-Object { $_.Main -ceq 'yes' }).Count -ne 1 })
  ST-Check 'unit: exactly one main=yes per pid on the real window list' (@($badMain).Count -eq 0)
  foreach ($bm in @($badMain)) { Write-Output "      pid=$($bm.Name) rows=$(@($bm.Group).Count) main=yes count=$(@($bm.Group | Where-Object { $_.Main -ceq 'yes' }).Count)" }
  $rw = Resolve-Window ([string]$w0.Pid)
  ST-Check 'unit: Resolve-Window by numeric pid selects a window' ($null -ne $rw)
  $cm = New-Object System.Collections.ArrayList
  foreach ($w in $wins) { if ($w.Popup) { [void]$cm.Add($w) } }
  Write-Output "      popup windows visible right now: $($cm.Count)"

  # v4.4.0 (A-14k): family docs-contract now lives in lib/selftest-docs-contract.ps1;
  # the call sits at the position its first piece had, and its four later pieces moved up to join it (this family is the outward-documentation set).
  Invoke-SelftestFamily-DocsContract $Ctx
  # v4.4.0 (A-14k): family chrome-cdp now lives in lib/selftest-chrome-cdp.ps1;
  # the call sits at the position its first piece had, and its three later pieces moved up to join it (this family is the CDP/a11y set).
  Invoke-SelftestFamily-ChromeCdp $Ctx
  Invoke-SelftestFamily-DragPress $Ctx
  Invoke-SelftestFamily-ChallengeWorkflow $Ctx
  Invoke-SelftestFamily-LiveSuite $Ctx
  # ---------- v4.3.0: --index / --only contracts ----------
  $xi = Get-SelftestIndexEntries @($script:StSourceLines)
  $xiEntries = @($xi.Entries)
  $xiPlant = @()
  $xiPlant += "  ST-Check 'unit: planted index probe must be found' (1 -eq 1)"
  $xiPlant += "  ST-Skip 'unit: planted skip probe must be found' 'because'"
  $xiPlant += "  ST-Check 'unit: planted ''quoted'' probe must be found' (1 -eq 1)"
  $xiPlant += "  # ST-Check 'unit: planted comment must NOT be found' (1 -eq 1)"
  # v4.4.2 (SUP-0842-A item 1): the comment plant above is space-indented only, and a filter written
  #    `^#` instead of `^[ \t]*#` would still pass it - so a name quoted inside an INDENTED or a
  #    TAB-indented comment (the shape that lives in a prose example, and the one an offline census
  #    tool got wrong on 2026-10-21) would inflate the published name set without any gate noticing.
  $xiPlant += "`t# ST-Check 'unit: planted tab comment must NOT be found' (1 -eq 1)"
  $xiPlant += "# ST-Check 'unit: planted flush comment must NOT be found' (1 -eq 1)"
  $xiPNames = @(@((Get-SelftestIndexEntries $xiPlant).Entries) | Where-Object { $_.Kind -ceq 'static' } | ForEach-Object { $_.Name })
  Write-Output ('      index plant census: found=' + @($xiPNames).Count + ' of ' + @($xiPlant).Count + ' planted lines')
  ST-Check 'unit (index): extraction finds planted checks (including a doubled-quote name) and ignores comments (the scan is not vacuous)' (
    (@($xiPNames).Count -eq 3) -and (@($xiPNames) -contains 'unit: planted index probe must be found') -and (@($xiPNames) -contains 'unit: planted skip probe must be found') -and (@($xiPNames) -contains "unit: planted 'quoted' probe must be found") -and
    (-not (@($xiPNames) -contains 'unit: planted tab comment must NOT be found')) -and (-not (@($xiPNames) -contains 'unit: planted flush comment must NOT be found')))

  $xiBad = New-Object System.Collections.ArrayList
  foreach ($xe in $xiEntries) {
    if ($xe.Kind -cne 'static') { continue }
    $xLn = [int]$xe.Line
    if (($xLn -lt 1) -or ($xLn -gt @($script:StSourceLines).Count)) { [void]$xiBad.Add([string]$xe.Name); continue }
    $xTxt = [string]$script:StSourceLines[$xLn - 1]
    if (-not ($xTxt.Contains([string]$xe.Name) -or $xTxt.Contains(([string]$xe.Name).Replace("'", "''")))) { [void]$xiBad.Add([string]$xe.Name) }
  }
  ST-Check 'unit (index): every static entry points at a line that carries its name (full pass, not a sample) and the entry count clears a floor' (
    (@($xiBad).Count -eq 0) -and (@($xiEntries).Count -ge [int]$script:DeclaredCheckTotal))
  if (@($xiBad).Count -gt 0) { Write-Output ('      index entries whose line does not carry the name: ' + @($xiBad).Count) }

  $xmBad = 0
  if (-not (Test-OnlyPatternMatch 'P-06' 'lint (P-06): kept')) { $xmBad++ }
  if (Test-OnlyPatternMatch 'P-06' 'lint (P-01): other') { $xmBad++ }
  if (-not (Test-OnlyPatternMatch 'p-06' 'lint (P-06): case stays insensitive')) { $xmBad++ }
  if (Test-OnlyPatternMatch 'P-0.' 'P-06 dot stays literal') { $xmBad++ }
  if (-not (Test-OnlyPatternMatch 'contract' 'contract: region check')) { $xmBad++ }
  ST-Check 'unit (only): the matcher is a literal, case-insensitive substring (no regex, no wildcards)' ($xmBad -eq 0)

  $xrOk = 0
  if ((Resolve-SelftestOnlyPattern @()) -eq '') { $xrOk++ }
  if ((Resolve-SelftestOnlyPattern @('--only', 'P-06')) -eq 'P-06') { $xrOk++ }
  foreach ($xrBad in @(@('--live', '--only'), @('--only', '--live'), @('--only', 'a', '--only', 'b'))) {
    $xrThrew = $false
    try { [void](Resolve-SelftestOnlyPattern $xrBad) } catch { $xrThrew = $true }
    if ($xrThrew) { $xrOk++ }
  }
  ST-Check 'unit (only): value parsing leaves an absent flag alone and refuses missing, flag-like and duplicate values' ($xrOk -eq 5)

  $xsLegacy = Format-SelftestSummary 853 0 2 0 0 ''
  $xsFiltered = Format-SelftestSummary 3 1 0 851 4 'P-06'
  ST-Check 'unit (only): the summary is byte-identical without a filter and discloses the absorbed counts with one' (
    ($xsLegacy -ceq '----- selftest: 853 passed, 0 failed, 2 skipped -----') -and
    ($xsFiltered -ceq "----- selftest: 3 passed, 1 failed, 0 skipped (--only 'P-06': 4 reported, 851 absorbed incl. 4 failed, of 855) -----"))

  $xwAbsorb = @($srcLines | Where-Object { ([string]$_).Contains('Test-St' + 'OnlyAbsorb ') }).Count
  $xwActive = @($srcLines | Where-Object { ([string]$_).Contains('$script:St' + 'OnlyActive') }).Count
  $xwResolve = @($srcLines | Where-Object { ([string]$_).Contains('= Resolve-Selftest' + 'OnlyPattern ') }).Count
  ST-Check 'lint (only): one resolver call site, one absorb helper called by exactly the two emitters, state read in four pinned places (a drifting rename reads as red)' (
    ($xwResolve -eq 1) -and ($xwAbsorb -eq 2) -and ($xwActive -eq 4))
  Write-Output ('      only plumbing: resolve=' + $xwResolve + ' absorb=' + $xwAbsorb + ' active=' + $xwActive)

  if ($script:PsChildOk) {
    $xiChildOut = Join-Path $env:TEMP ('st_idxe2e_' + [guid]::NewGuid().ToString('N') + '.txt')
    $xiChildArgs = '-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" selftest --index'
    $xiCp = Start-Process -FilePath 'powershell.exe' -ArgumentList $xiChildArgs -RedirectStandardOutput $xiChildOut -RedirectStandardError ($xiChildOut + '.err') -Wait -PassThru -NoNewWindow
    $xiChildTxt = ''
    if (Test-Path -LiteralPath $xiChildOut) { $xiChildTxt = [string](Get-Content -Raw -LiteralPath $xiChildOut) }
    $xiChildN = @(($xiChildTxt -split "`r?`n") | Where-Object { (([string]$_).Contains("`t")) }).Count
    ST-Check 'e2e (index): a real child lists the checks without running them (no summary line, entry floor met)' (
      ($xiCp.ExitCode -eq 0) -and ($xiChildTxt.Contains('selftest index: ')) -and (-not $xiChildTxt.Contains(' passed,')) -and ($xiChildN -ge [int]$script:DeclaredCheckTotal))
    Remove-Item -LiteralPath $xiChildOut -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath ($xiChildOut + '.err') -Force -ErrorAction SilentlyContinue

    $xiComboOut = Join-Path $env:TEMP ('st_idxcombo_' + [guid]::NewGuid().ToString('N') + '.txt')
    $xiComboArgs = '-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" selftest --index --live'
    $xiCb = Start-Process -FilePath 'powershell.exe' -ArgumentList $xiComboArgs -RedirectStandardOutput $xiComboOut -RedirectStandardError ($xiComboOut + '.err') -Wait -PassThru -NoNewWindow
    $xiComboTxt = ''
    if (Test-Path -LiteralPath $xiComboOut) { $xiComboTxt = [string](Get-Content -Raw -LiteralPath $xiComboOut) }
    if (Test-Path -LiteralPath ($xiComboOut + '.err')) { $xiComboTxt += [string](Get-Content -Raw -LiteralPath ($xiComboOut + '.err')) }
    ST-Check 'e2e (index): the fast path refuses a combined flag by name and exits 1' (
      ($xiCb.ExitCode -eq 1) -and ($xiComboTxt.Contains('--index cannot be combined with --live')))
    Remove-Item -LiteralPath $xiComboOut -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath ($xiComboOut + '.err') -Force -ErrorAction SilentlyContinue
  } else {
    ST-Skip 'e2e (index): a real child lists the checks without running them (no summary line, entry floor met)' ('no powershell.exe resolvable in PATH: ' + $script:PsChildWhy)
    ST-Skip 'e2e (index): the fast path refuses a combined flag by name and exits 1' ('no powershell.exe resolvable in PATH: ' + $script:PsChildWhy)
  }

  $xiSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
  $xiTpl = New-Object System.Collections.ArrayList
  foreach ($xe in $xiEntries) {
    if ($xe.Kind -ceq 'template') { [void]$xiTpl.Add([string]$xe.Pattern) } else { [void]$xiSet.Add([string]$xe.Name) }
  }
  $xiMiss = New-Object System.Collections.ArrayList
  foreach ($xn in @($script:StEmittedAll)) {
    $xOkName = $xiSet.Contains([string]$xn)
    if (-not $xOkName) {
      foreach ($xp in @($xiTpl)) { if ([string]$xn -match $xp) { $xOkName = $true; break } }
    }
    if (-not $xOkName) { [void]$xiMiss.Add([string]$xn) }
  }
  ST-Check 'contract: selftest index lists every check name this run emitted (the index cannot rot silently)' (
    (@($script:StEmittedAll).Count -ge 700) -and (@($xiMiss).Count -eq 0))
  if (@($xiMiss).Count -gt 0) { Write-Output ('      emitted but missing from the index: ' + (@($xiMiss) -join ' | ')) }

  ST-Check 'contract: selftest PASS line count equals passed summary count' (@($script:StPassLines).Count -eq $script:StPass)
  # v3.0.0 (S-4): the LAST check, so the arithmetic covers every check above AND itself.
  # Only the offline run is pinned - a --live run legitimately has more checks, and pretending
  # otherwise would make the declaration a live-mode failure instead of a version record. The
  # live path reports SKIP with the number it saw, which is the honest form of "not measured".
  $s4Total = [int]$script:StPass + [int]$script:StFail + [int]$script:StSkip + 1
  if ($live) {
    ST-Skip 'contract: declared check total (live run adds checks, so the offline declaration does not apply)' "live-total=$s4Total"
  } elseif ($script:StOnlyActive) {
    ST-Skip 'contract: declared check total (a scoped run reports a subset, so the offline declaration does not apply)' "filtered=$s4Total"
  } else {
    ST-Check 'contract: this version declares its offline check total and the run matches it' ($s4Total -eq [int]$script:DeclaredCheckTotal)
    if ($s4Total -ne [int]$script:DeclaredCheckTotal) {
      Write-Output "      declared=$($script:DeclaredCheckTotal) this-run-would-be=$s4Total - set the declaration at the top of the file (RAISING AN EXPECTED COUNT; it does not loosen any check)"
    }
  }
  Write-Output (Format-SelftestSummary $script:StPass $script:StFail $script:StSkip $script:StAbsorbed $script:StAbsorbedFail $script:StOnlyPat)
  if ($script:StFail -gt 0) { throw "selftest: $($script:StFail) check(s) FAILED" }
}

