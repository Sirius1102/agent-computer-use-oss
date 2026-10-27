# lib/selftest-split-machine.ps1 - one family of the selftest section, lifted out of lib/selftest.ps1 by A-14b (A-beta).
# Bodies are byte-identical to what the section carried; this file exists so that a family of
# checks can be read, moved and counted on its own. The only channel to the orchestrator is the
# explicit context object: shared state arrives through $Ctx and nothing else, because the
# dynamic-scope chain that used to feed these lines is exactly the implicit link A-08/A-09/A-11
# proved can break silently on a move.
# Family: the split machine itself - the source set, the aggregate line map, the mode announcement,
function Invoke-SelftestFamily-SplitMachine($Ctx) {
  # context handover (the one thing in this file that is not lifted text)
  $self = [string]$Ctx['self']
  $src = [string]$Ctx['src']
#   the AST inventories and the audit-name contracts. It is the head of the section by design:
#   every gate that measures how this file was cut lives here, so a bad cut reports itself.
  # ---------- lint: file encoding invariants ----------
  $bytes = [System.IO.File]::ReadAllBytes($self)
  $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
  ST-Check 'lint: UTF-8 BOM present + pure ASCII beyond it (v1.5.0 task invariant; BOM+ASCII parses identically on PS 5.1)' ($hasBom -and (([regex]::Matches($src, '[^\x00-\x7F]')).Count -eq 0))
  ST-Check 'lint: file is pure ASCII' (([regex]::Matches($src, '[^\x00-\x7F]')).Count -eq 0)
  # ---------- v4.4.0 (A-03): the source set is under test, not merely in use ----------
  # Planted fixtures: until the first lib/ file exists the aggregate path is unreachable in
  # the live tree, so the loader, the order it promises and the mode split are measured here
  # instead of being trusted because the run happened to be green.
  $a03Root = Join-Path ([System.IO.Path]::GetTempPath()) ('acu-a03-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
  try {
    New-Item -ItemType Directory -Path $a03Root | Out-Null
    $a03Enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path $a03Root 'first.ps1'), 'MARKER-ONE-line', $a03Enc)
    [System.IO.File]::WriteAllText((Join-Path $a03Root 'second.ps1'), 'MARKER-TWO-line', $a03Enc)
    $a03Fwd = Get-AggregatedSource $a03Root @('first.ps1', 'second.ps1')
    $a03Rev = Get-AggregatedSource $a03Root @('second.ps1', 'first.ps1')
    ST-Check 'unit (A-03): the aggregator concatenates planted sources in the declared order' (
      ($a03Fwd.IndexOf('MARKER-ONE') -ge 0) -and ($a03Fwd.IndexOf('MARKER-ONE') -lt $a03Fwd.IndexOf('MARKER-TWO')))
    ST-Check 'unit (A-03): the same aggregator flips the verdict on a reversed declaration (order is measured, not assumed)' (
      $a03Rev.IndexOf('MARKER-ONE') -gt $a03Rev.IndexOf('MARKER-TWO'))
    $a03Threw = ''
    try { [void](Get-AggregatedSource $a03Root @('first.ps1', 'not-there.ps1')) } catch { $a03Threw = "$($_.Exception.Message)" }
    ST-Check 'unit (A-03): a declared file missing on disk throws and names it (a half-landed split cannot read as green)' (
      $a03Threw.Contains('not-there.ps1'))
    $a03NoLib = Get-SourceModeBeside $a03Root
    New-Item -ItemType Directory -Path (Join-Path $a03Root 'lib') | Out-Null
    $a03WithLib = Get-SourceModeBeside $a03Root
    ST-Check 'unit (A-03): the mode discriminator reads both ways on planted roots (no lib = single-file, lib = aggregate)' (
      ($a03NoLib -ceq 'single-file') -and ($a03WithLib -ceq 'aggregate'))
  } finally {
    if (Test-Path -LiteralPath $a03Root) { Remove-Item -LiteralPath $a03Root -Recurse -Force }
  }
  ST-Check 'lint (A-03): the entry declares itself first, and the predicate rejects a planted reversed set (it cannot pass by being always true) ' (
    (Test-EntryFirstSource @($script:StSourceFiles)) -and (-not (Test-EntryFirstSource @('lib\\z.ps1', 'desktop.ps1'))))
  $a03Ghost = Get-LoadTimeInitsMissing @('$script:RealOne = 1') @('$script:RealOne = 1', '$script:GhostTwo = 2')
  ST-Check 'unit (A-03): the load-time inventory predicate flags a planted missing statement (it cannot pass by seeing nothing)' (
    ($a03Ghost -ceq '$script:GhostTwo = 2'))
  $a03MissingInits = Get-LoadTimeInitsMissing @($script:StSourceLines) $script:StLoadTimeInits
  ST-Check 'lint (A-03): all eleven load-time statements still match verbatim, name and value (a pure move cannot drop or rewrite state)' (
    ($a03MissingInits -ceq ''))
  if ("$a03MissingInits" -ne '') { Write-Output ('      missing load-time inits: ' + $a03MissingInits) }
  # ---------- v4.4.0 (A-04): an aggregate line number must name its file ----------
  $a04Plant = @(
    [pscustomobject]@{ File = 'a.ps1'; Start = 1; Count = 3 },
    [pscustomobject]@{ File = 'lib/b.ps1'; Start = 5; Count = 4 }
  )
  $a04InA = Resolve-SourceLineFromSpans 2 $a04Plant
  $a04InB = Resolve-SourceLineFromSpans 6 $a04Plant
  $a04Out = Resolve-SourceLineFromSpans 99 $a04Plant
  # The aggregate gate that reads the real tree SKIPs until a lib/ directory exists (A-11), so
  # the boundary rule is measured here on a planted pair - otherwise it would ship untested.
  $a04SRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('acu-a04-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
  New-Item -ItemType Directory -Path $a04SRoot | Out-Null
  $a04Enc2 = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText((Join-Path $a04SRoot 'one.ps1'), "a`r`nb`r`nc`r`n", $a04Enc2)
  [System.IO.File]::WriteAllText((Join-Path $a04SRoot 'two.ps1'), "d`r`ne`r`n", $a04Enc2)
  $a04Sp = @(Get-SourceLineSpans $a04SRoot @('one.ps1', 'two.ps1'))
  $a04AggLen = @((Get-AggregatedSource $a04SRoot @('one.ps1', 'two.ps1')) -split "`r?`n").Count
  $a04SpThrew = ''
  try { [void](Get-SourceLineSpans $a04SRoot @('gone.ps1')) } catch { $a04SpThrew = "$($_.Exception.Message)" }
  Remove-Item -LiteralPath $a04SRoot -Recurse -Force
  ST-Check 'unit (A-04): resolver names the owner both sides of a boundary, the planted pair pins the boundary arithmetic, and a declared missing file throws' (
    ($a04InA -ceq 'a.ps1:2') -and ($a04InB -ceq 'lib/b.ps1:2') -and ([string]$a04Out).StartsWith('beyond-aggregate:') -and
    (@($a04Sp).Count -eq 2) -and ([int]$a04Sp[0].Start -eq 1) -and ([int]$a04Sp[0].Count -eq 4) -and
    ([int]$a04Sp[1].Start -eq 5) -and ([int]$a04Sp[1].Count -eq 3) -and
    ([int]$a04Sp[0].Count + [int]$a04Sp[1].Count -eq $a04AggLen) -and
    $a04SpThrew.Contains('gone.ps1'))
  # !! Every token below is ASSEMBLED at run time. A scan token written out as a literal is
  #    present in the very text this gate reads, so the gate would report its own source as a
  #    violation forever (P-05, P-06 and X-01 are this file's named precedents for exactly that).
  $a04D = [char]0x24
  $a04Q = [char]0x27
  $a04Shapes = @(
    ('line ' + $a04D + '(' + '$ti + 1)'),
    ('line ' + $a04D + '(' + '$ri + 1)'),
    ('line ' + $a04D + '(' + '$k + 1)'),
    ('"line " + ' + $a04D + 'gaLineNo'),
    ($a04Q + 'line ' + $a04Q + ' + (' + $a04D + 'ari + 1)')
  )
  $a04Needle = 'Format-SourceLineRef' + ' ('
  $a04Left = @()
  foreach ($sh in $a04Shapes) {
    if (@(@($script:StSourceLines) | Where-Object { ([string]$_).Contains([string]$sh) }).Count -gt 0) { $a04Left += [string]$sh }
  }
  # and the scan is proven ABLE to match: a planted line assembled from the same token must
  # be caught, otherwise "zero left" would be a gate that cannot go red.
  $a04Planted = ('  [void]$x.Add("' + $a04Shapes[0] + ': planted")')
  $a04Canary = 0
  foreach ($sh in $a04Shapes) { if (([string]$a04Planted).Contains([string]$sh)) { $a04Canary++ } }
  $a04Calls = @(@($script:StSourceLines) | Where-Object { ([string]$_).Contains($a04Needle) }).Count
  ST-Check 'lint (A-04): none of the five A-04 echo shapes prints a bare index any more, the resolver has call sites, and the scan catches a planted shape' (
    (@($a04Left).Count -eq 0) -and ($a04Canary -ge 1) -and ($a04Calls -ge 9))
  Write-Output ('      A-04 resolver: call sites=' + $a04Calls + ' bare shapes left=' + @($a04Left).Count + ' shapes scanned=' + @($a04Shapes).Count + ' canary=' + $a04Canary)
  if ("$script:StSourceMode" -ceq 'aggregate') {
    $a04Bad = @()
    foreach ($sp in @($script:StSourceSpans)) {
      $own = @([System.IO.File]::ReadAllLines((Join-Path $script:ToolRootPath ([string]$sp.File)), [System.Text.Encoding]::UTF8))
      $aggAt = [string]$script:StSourceLines[[int]$sp.Start - 1]
      if ("$aggAt" -cne "$($own[0])") { $a04Bad += ([string]$sp.File) }
    }
    ST-Check 'lint (A-04): every declared file really begins on the aggregate line the span map claims (first line against first line)' (
      @($a04Bad).Count -eq 0)
    if (@($a04Bad).Count -gt 0) { Write-Output ('      span starts that do not line up: ' + ($a04Bad -join ' ')) }
  } else {
    ST-Skip 'lint (A-04): every declared file really begins on the aggregate line the span map claims (first line against first line)' 'single-file source mode (no lib/ beside the entry) - one file, no boundary to miss'
  }
  # ---------- v4.4.0 (A-05): the source set and the dot-import list must agree ----------
  $a05Root = Join-Path ([System.IO.Path]::GetTempPath()) ('acu-a05-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
  New-Item -ItemType Directory -Path $a05Root | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $a05Root 'lib') | Out-Null
  $a05Enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText((Join-Path $a05Root 'desktop.ps1'), "entry`r`n", $a05Enc)
  [System.IO.File]::WriteAllText((Join-Path $a05Root 'lib\ghost.ps1'), "x`r`n", $a05Enc)
  $a05Miss = Get-SourceSetDiscrepancy $a05Root @('desktop.ps1', 'lib/ghost.ps1', 'lib/gone.ps1')
  $a05Undecl = Get-SourceSetDiscrepancy $a05Root @('desktop.ps1')
  $a05Both = Get-SourceSetDiscrepancy $a05Root @('desktop.ps1', 'lib/ghost.ps1')
  ST-Check 'unit (A-05): the source-set predicate names a declared-missing file, names an on-disk-undeclared file, and stays silent when both sides agree' (
    $a05Miss.Contains('declared-missing:lib/gone.ps1') -and (-not $a05Miss.Contains('undeclared')) -and
    $a05Undecl.Contains('on-disk-undeclared:lib/ghost.ps1') -and (-not $a05Undecl.Contains('declared-missing')) -and ($a05Both -ceq ''))
  $a05Lines = @(
    ". (Join-Path `$PSScriptRoot 'lib/a.ps1') # <<< stitch: lib/a.ps1",
    ". (Join-Path `$PSScriptRoot 'lib/b.ps1') # <<< stitch: lib/b.ps1"
  )
  $a05Ok = Get-DotImportDiscrepancy $a05Lines @('desktop.ps1', 'lib/a.ps1', 'lib/b.ps1')
  $a05Swap = Get-DotImportDiscrepancy $a05Lines @('desktop.ps1', 'lib/b.ps1', 'lib/a.ps1')
  $a05Short = Get-DotImportDiscrepancy ($a05Lines[0..0]) @('desktop.ps1', 'lib/a.ps1', 'lib/b.ps1')
  $a05NoMark = Get-DotImportDiscrepancy @(". (Join-Path `$PSScriptRoot 'lib/a.ps1')") @('desktop.ps1', 'lib/a.ps1')
  # v4.4.0 (S-93): the swap that used to be invisible - the MARKERS stay in declared order and the REAL
  # paths trade places. A predicate that reads the comment cannot see it; one that reads the loader can.
  $a05PathSwap = Get-DotImportDiscrepancy @(". (Join-Path `$PSScriptRoot 'lib/b.ps1') # <<< stitch: lib/a.ps1", ". (Join-Path `$PSScriptRoot 'lib/a.ps1') # <<< stitch: lib/b.ps1") @('desktop.ps1', 'lib/a.ps1', 'lib/b.ps1')
  Remove-Item -LiteralPath $a05Root -Recurse -Force
  ST-Check 'unit (A-05): the dot-import predicate passes on an ordered pair, names a swapped pair, names a missing line, and names an import with no stitch marker' (
    ($a05Ok -ceq '') -and $a05Swap.Contains('order-at-0=') -and $a05Short.Contains('count-found=1-want=2') -and $a05NoMark.Contains('NO-MARKER') -and
    $a05PathSwap.Contains('path-at-0=lib/b.ps1/lib/a.ps1'))
  if ($script:StSourceMode -ceq 'aggregate') {
    $a05LiveSet = Get-SourceSetDiscrepancy $script:ToolRootPath $script:StSourceFiles
    $a05LiveImp = Get-DotImportDiscrepancy @($script:StSourceLines) $script:StSourceFiles
    ST-Check 'lint (A-05): the declared source set equals what is on disk (no ghost declaration, no unregistered lib file)' (
      $a05LiveSet -ceq '')
    if ($a05LiveSet -ne '') { Write-Output ('      source set: ' + $a05LiveSet) }
    ST-Check 'lint (A-05): the entry dot-imports the declared files in the declared order (one list, four consumers, verified against the text)' (
      $a05LiveImp -ceq '')
    if ($a05LiveImp -ne '') { Write-Output ('      dot-imports: ' + $a05LiveImp) }
  } else {
    ST-Skip 'lint (A-05): the declared source set equals what is on disk (no ghost declaration, no unregistered lib file)' 'single-file source mode (no lib/ beside the entry) - this is also the installed product shape, where the declaration list is inert by design'
    ST-Skip 'lint (A-05): the entry dot-imports the declared files in the declared order (one list, four consumers, verified against the text)' 'single-file source mode (no lib/ beside the entry) - the stitcher replaces those lines, so there is nothing to reconcile'
  }
  # ---------- v4.4.0 (A-06): the mode is announced and provably tied to the discriminator ----------
  $a06Agree = Test-ModeLineAgreement "$script:StSourceMode" ([string]$script:StModeLine)
  $a06BadMode = Test-ModeLineAgreement 'aggregate' 'selftest: single-file source mode (no lib/ beside the entry)'
  $a06BadMode2 = Test-ModeLineAgreement 'single-file' 'selftest: aggregate source mode, 8 file(s) measured as one source'
  $a06Unknown = Test-ModeLineAgreement 'sideways' 'anything'
  ST-Check 'unit (A-06): the mode-agreement predicate passes on the run own pair and rejects all three planted mismatches (it cannot pass by always answering true)' (
    $a06Agree -and (-not $a06BadMode) -and (-not $a06BadMode2) -and (-not $a06Unknown))
  Write-Output ('      mode line: ' + [string]$script:StModeLine)
  ST-Check 'lint (A-06): the source-mode line this run printed agrees with the discriminator, and single-file mode says so out loud' (
    (Test-ModeLineAgreement "$script:StSourceMode" ([string]$script:StModeLine)) -and ($script:StModeLine.Length -gt 20))
  ST-Check 'lint (A-03): the aggregate of a one-file source set equals the entry read raw (A-03 cannot change what selftest measures)' (
    (Get-AggregatedSource $script:ToolRootPath @('desktop.ps1')) -ceq (Get-Content -LiteralPath $self -Raw))

  # ---------- v4.4.0 (A-07): the AST inventory, measured against the tables it must match ----------
  # !! Every local in this block carries the a07 prefix: PowerShell has function scope, not block
  #    scope, so a bare loop variable here would outlive the loop and be read by a later region.
  $a07Parsed = Parse-SourceForInventory (@($script:StSourceLines) -join "`n")
  $a07Case = Get-InventoryDiscrepancy 'ALPHA;alpha' @('alpha=2')
  $a07WordB = Get-CharCodeWord @(0x4C, 0x6F, 0x67, 0x2D, 0x41, 0x63, 0x74, 0x69, 0x6F, 0x6E)
  $a07WordShort = Get-CharCodeWord @(0x4C, 0x6F, 0x67)
  $a07WordLower = Get-CharCodeWord @(0x6C, 0x6F, 0x67, 0x2D, 0x41, 0x63, 0x74, 0x69, 0x6F, 0x6E)
  ST-Check 'unit (A-07): counting is case-sensitive on a planted near-miss, and the scanned word rebuilds identically from its code points' (
    ($a07Case.Contains('alpha:got1-want2')) -and ($a07Case.Contains('observed:ALPHA-declared=0')) -and
    ($a07WordB -ceq "$script:StCommandToken") -and ($a07WordShort -cne "$script:StCommandToken") -and
    ($a07WordLower -cne "$script:StCommandToken") -and ((([string]$script:StCommandToken).Length) -eq 10))
  $a07Plant = @(
    'function Invoke-FakeDispatch([string]$Pick) {',
    '  switch ($Pick) {',
    '    ''alpha'' { Fake-Audited-Command 1 }',
    '    ''beta'' { if ($true) { Fake-Audited-Command 2 } }',
    '    $Pick { Fake-Audited-Command 6 }',
    '    default { Fake-Audited-Command 3 }',
    '  }',
    '}',
    'function Invoke-FakeHelper { Fake-Audited-Command 4 }',
    'Fake-Audited-Command 5'
  )
  $a07PlantParsed = Parse-SourceForInventory ($a07Plant -join "`n")
  $a07PlantKeys = @()
  foreach ($a07S in @((Get-CommandSiteList $a07PlantParsed 'Fake-Audited-Command') -split ';')) {
    if ($a07S -eq '') { continue }
    $a07At = $a07S.LastIndexOf('@')
    $a07PlantKeys += $a07S.Substring(0, $a07At)
  }
  $a07PlantGap = Get-InventoryDiscrepancy ($a07PlantKeys -join ';') @('case:alpha=1', 'case:beta=1', 'case:DEFAULT=1', 'case:NONLITERAL=1', 'fn:Invoke-FakeHelper=1', 'entry-top-level=1')
  ST-Check 'unit (A-07): the site extractor tells a planted case label from its enclosing function, a call nested in an if inside a clause, the default branch, a non-literal label, a helper and a bare top-level call' (
    ($a07PlantParsed.ErrorCount -eq 0) -and ($a07PlantGap -ceq '') -and (@($a07PlantKeys).Count -eq 6))
  $a07Decl = @('alpha=2', 'beta=1')
  $a07Ok = Get-InventoryDiscrepancy 'alpha;alpha;beta' $a07Decl
  $a07Short = Get-InventoryDiscrepancy 'alpha;beta' $a07Decl
  $a07Extra = Get-InventoryDiscrepancy 'alpha;alpha;beta;gamma' $a07Decl
  $a07Dup = Get-InventoryDiscrepancy 'alpha;alpha;beta' @('alpha=2', 'alpha=1', 'beta=1')
  $a07Bad = Get-InventoryDiscrepancy 'alpha;alpha;beta' @('=7', 'beta=x', 'alpha=2')
  ST-Check 'unit (A-07): the inventory counter stays silent on a matching pair and names a planted short count, an undeclared extra, a duplicated declaration and two malformed entries' (
    ($a07Ok -ceq '') -and ($a07Short.Contains('alpha:got1-want2')) -and ($a07Extra.Contains('observed:gamma-declared=0')) -and
    ($a07Dup.Contains('duplicate-declared=2')) -and ($a07Bad.Contains('bad-entry:')) -and ($a07Bad.Contains('bad-count:beta=x')))
  $a07SiteList = Get-CommandSiteList $a07Parsed "$script:StCommandToken"
  $a07Keys = @()
  $a07CallLines = @()
  foreach ($a07S in @($a07SiteList -split ';')) {
    if ($a07S -eq '') { continue }
    $a07At = $a07S.LastIndexOf('@')
    $a07Keys += $a07S.Substring(0, $a07At)
    $a07CallLines += $a07S.Substring($a07At + 1)
  }
  $a07OwnerGap = Get-InventoryDiscrepancy ($a07Keys -join ';') $script:StCommandOwners
  $a07OwnerSum = 0
  foreach ($a07D in @($script:StCommandOwners)) { $a07At = ([string]$a07D).LastIndexOf('='); $a07OwnerSum = $a07OwnerSum + [int]([string]$a07D).Substring($a07At + 1) }
  $a07SiteCount = @($a07Keys).Count
  ST-Check 'lint (A-07): the source parses clean and its AST call-site owners equal the registered table (45 keys, 59 sites, table sums to the same 59)' (
    ([int]$a07Parsed.ErrorCount -eq 0) -and ($a07OwnerGap -ceq '') -and ($a07SiteCount -eq 59) -and
    ($a07OwnerSum -eq 59) -and (@($script:StCommandOwners).Count -eq 45))
  if ($a07OwnerGap -ne '') { Write-Output ('      owner drift: ' + $a07OwnerGap) }
  $a07Mentions = 0
  foreach ($a07Ln in @($script:StSourceLines)) { if (([string]$a07Ln).Contains("$script:StCommandToken")) { $a07Mentions = $a07Mentions + 1 } }
  $a07MentionGap = Get-MentionExclusionDiscrepancy @($script:StSourceLines) "$script:StCommandToken" ($a07CallLines -join ';') $script:StCommandExclusions
  $a07AnchorDup = 0
  foreach ($a07A1 in @($script:StCommandExclusions)) {
    $a07C = 0
    foreach ($a07A2 in @($script:StCommandExclusions)) { if ([string]$a07A1 -ceq [string]$a07A2) { $a07C = $a07C + 1 } }
    if ($a07C -gt 1) { $a07AnchorDup = $a07AnchorDup + 1 }
  }
  ST-Check 'lint (A-07): every line mentioning the audited command is either an AST call site or one of the ten exclusions, and no exclusion certifies two lines (69 = 59 + 10)' (
    ($a07MentionGap -ceq '') -and ($a07Mentions -eq 69) -and (@($script:StCommandExclusions).Count -eq 10) -and
    ($a07AnchorDup -eq 0) -and (($a07SiteCount + 10) -eq $a07Mentions))
  if ($a07MentionGap -ne '') { Write-Output ('      mention gap: ' + $a07MentionGap) }
  $a07FtKeys = @()
  foreach ($a07K in @((Get-FunctionScopeNameList $a07Parsed) -split ';')) {
    if ($a07K -eq '') { continue }
    if ([string]$a07K -ceq "$script:StCommandToken") { $a07FtKeys += '@LA@' } else { $a07FtKeys += [string]$a07K }
  }
  $a07FtCount = @($a07FtKeys).Count
  $a07FtGap = Get-InventoryDiscrepancy ($a07FtKeys -join ';') $script:StFunctionScopeRefs
  ST-Check 'lint (A-07): the function-table test-double family equals the registered eleven names across forty-nine references' (
    ($a07FtGap -ceq '') -and ($a07FtCount -eq 49) -and (@($script:StFunctionScopeRefs).Count -eq 11))
  if ($a07FtGap -ne '') { Write-Output ('      function table: ' + $a07FtGap) }
  $a07LtList = Get-TopLevelAssignmentNameList $a07Parsed
  $a07LtGap = Get-InventoryDiscrepancy "$a07LtList" $script:StLoadTimeNames
  $a07LtSplit = @("$a07LtList" -split ';')
  $a07MovedList = Get-LoadTimeInitNameList $script:StLoadTimeInits
  $a07MovedSplit = @("$a07MovedList" -split ';')
  $a07MovedNotes = @()
  foreach ($a07Mn in $a07MovedSplit) {
    if ($a07Mn -eq '') { continue }
    $a07C = 0
    foreach ($a07K in $a07LtSplit) { if ([string]$a07K -ceq [string]$a07Mn) { $a07C = $a07C + 1 } }
    if ($a07C -lt 1) { $a07MovedNotes += ('moved-missing:' + [string]$a07Mn) }
  }
  $a07LtCount = @($a07LtSplit).Count
  ST-Check 'lint (A-07): the load-time assignment family equals the registered table, and every statement marked for a move is in it (the count is in the inventory line, not in the name)' (
    ($a07LtGap -ceq '') -and ($a07LtCount -eq 108) -and (@($script:StLoadTimeNames).Count -eq 86) -and
    ($a07MovedSplit.Count -eq 14) -and (($a07MovedNotes -join ';') -ceq ''))
  if ($a07LtGap -ne '') { Write-Output ('      load time: ' + $a07LtGap) }
  if (@($a07MovedNotes).Count -gt 0) { Write-Output ('      moved-marked absent: ' + ($a07MovedNotes -join ';')) }
  Write-Output ('      A-07 inventory: sites=' + $a07SiteCount + ' owners=' + @($script:StCommandOwners).Count +
    ' mentions=' + $a07Mentions + ' exclusions=' + @($script:StCommandExclusions).Count +
    ' function-table=' + $a07FtCount + '/' + @($script:StFunctionScopeRefs).Count +
    ' load-time=' + $a07LtCount + ' parse-errors=' + [int]$a07Parsed.ErrorCount)
  # ---------- v4.4.0 (A-08): the command name travels by argument, and the machine proves it ----------
  # Reuses the A-07 parse ($a07Parsed) rather than parsing the source again; under Set-StrictMode an
  # absent $a07Parsed is a loud failure, not a silent zero.
  $a08Records = Get-CommandSiteRecords $a07Parsed "$script:StCommandToken"
  $a08Args = @()
  $a08HandNotes = @()
  $a08Seen = @()
  $a08Helpers = @('Trim-ShotDir', 'Release-Press', 'Close-PressHold', 'Invoke-PressWatchdog', 'Invoke-UiaSettextByPath')
  foreach ($a08R in @($a08Records -split "`n")) {
    if ($a08R -eq '') { continue }
    $a08F = @([string]$a08R -split "`t", 4)
    $a08Args += ([string]$a08F[2] + '|' + (([string]$a08F[3]) -replace ';', ','))
    $a08Owner = [string]$a08F[0]
    if (-not $a08Owner.StartsWith('fn:')) { continue }
    $a08Fn = $a08Owner.Substring(3)
    $a08IsHelper = $false
    foreach ($a08H in $a08Helpers) { if ([string]$a08H -ceq [string]$a08Fn) { $a08IsHelper = $true; $a08Seen += [string]$a08H } }
    if (-not $a08IsHelper) { continue }
    $a08Ok = $false
    foreach ($a08P in @((Get-FunctionParamNameList $a07Parsed $a08Fn) -split ';')) {
      if ($a08P -eq '') { continue }
      if (('$' + [string]$a08P) -ceq [string]$a08F[3]) { $a08Ok = $true }
    }
    if (-not $a08Ok) { $a08HandNotes += ($a08Fn + ':arg=' + [string]$a08F[3]) }
  }
  $a08ArgGap = Get-InventoryDiscrepancy ($a08Args -join ';') $script:StCommandNameArgs
  $a08SeenAll = $true
  foreach ($a08H in $a08Helpers) {
    $a08C = 0
    foreach ($a08S in $a08Seen) { if ([string]$a08S -ceq [string]$a08H) { $a08C = $a08C + 1 } }
    if ($a08C -lt 1) { $a08SeenAll = $false }
  }
  ST-Check 'lint (A-08): every call to the audited command passes the command name as its third argument and the three sources account for all fifty-nine (none left reading caller scope)' (
    ($a08ArgGap -ceq '') -and (@($a08Args).Count -eq 59) -and (@($script:StCommandNameArgs).Count -eq 3))
  if ($a08ArgGap -ne '') { Write-Output ('      name sources: ' + $a08ArgGap) }
  ST-Check 'lint (A-08): the five helpers outside the dispatcher each declare a command-name parameter and hand that very parameter to their audit call, and all five are actually on the list' (
    (@($a08HandNotes).Count -eq 0) -and $a08SeenAll -and (@($a08Helpers).Count -eq 5))
  if (@($a08HandNotes).Count -gt 0) { Write-Output ('      handoff: ' + ($a08HandNotes -join ';')) }
  $a08Align = Get-StubAlignmentDiscrepancy $a07Parsed "$script:StCommandToken"
  $a08Plant = @(
    'function F-Real($a, $b, $c) { }',
    '${function:F-Real} = { param($x, $y) }'
  )
  $a08PlantParsed = Parse-SourceForInventory ($a08Plant -join "`n")
  $a08PlantNote = Get-StubAlignmentDiscrepancy $a08PlantParsed 'F-Real'
  $a08NoStub = Get-StubAlignmentDiscrepancy $a08PlantParsed 'F-Absent'
  ST-Check 'unit (A-08): a planted two-parameter stub against a three-parameter function is refused by name, an absent function is refused, and the shipped pair passes' (
    ($a08Align -ceq '') -and ($a08PlantNote.Contains('stub=2-real=3')) -and ($a08NoStub.Contains('no-function:F-Absent')))
  if ($a08Align -ne '') { Write-Output ('      stub alignment: ' + $a08Align) }
  # The audit line is written for real here, into a temp log, with the script-scope path shadowed
  # for the duration of this block only and restored in finally: what the run reads back is the
  # column layout, which is the one thing A-20 would otherwise have had to prove. The two planted
  # arguments cover both quoting branches: a plain word passes through, a word carrying a space is
  # single-quoted with its apostrophe doubled - so a change to the quoting rule cannot hide here.
  # The two planted calls below go through a local alias whose *value* is the assembled token, so
  # the harness can exercise the real function without becoming two more entries in the product
  # inventory this card is supposed to keep at fifty-five (an alias resolves to the function, and
  # the guard runs the same way it does for every production site).
  $a08Old = $ActionLog
  $a08Log = Join-Path ([System.IO.Path]::GetTempPath()) ('acu-a08-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.log')
  $a08Threw = ''
  $a08ThrewEmpty = ''
  $a08Parts = @()
  try {
    Set-Alias -Name 'a08-planted-audit-call' -Value "$script:StCommandToken"
    $ActionLog = $a08Log
    try { & 'a08-planted-audit-call' @('x') 'target' '' } catch { $a08Threw = "$($_.Exception.Message)" }
    try { & 'a08-planted-audit-call' @('x') 'target' } catch { $a08ThrewEmpty = "$($_.Exception.Message)" }
    & 'a08-planted-audit-call' @('one', "it's here") 'planted-target' 'planted-name'
    $a08Line = [string](@(Get-Content -LiteralPath $a08Log -Encoding UTF8 -ErrorAction SilentlyContinue) | Select-Object -Last 1)
    $a08Parts = @($a08Line -split ' \| ')
  } finally {
    $ActionLog = $a08Old
    if (Test-Path -LiteralPath $a08Log) { Remove-Item -LiteralPath $a08Log -Force }
  }
  ST-Check 'unit (A-08): an omitted command name throws instead of writing an empty audit column, and a planted name lands in the second column with the argument quoting untouched' (
    ($a08Threw.Contains('third argument')) -and ($a08ThrewEmpty.Contains('third argument')) -and (@($a08Parts).Count -eq 4) -and
    ([string]$a08Parts[1] -ceq 'planted-name') -and
    ([string]$a08Parts[2] -ceq "one 'it''s here'") -and ([string]$a08Parts[3] -ceq 'planted-target') -and (([string]$a08Parts[0]).EndsWith(' UTC')))
  Write-Output ('      A-08 planted audit line: parts=' + @($a08Parts).Count + ' [' + ($a08Parts -join ' || ') + ']')
  Write-Output ('      A-08: name sources=' + @($a08Args).Count + ' declared=' + @($script:StCommandNameArgs).Count +
    ' helpers=' + $a08Seen.Count + '/5 alignment=[' + $a08Align + '] planted-stub-note=' + $a08PlantNote)
  # ---------- v4.4.0 (A-09): nothing may reach for the dispatcher variable from someone else scope ----------
  # The variable spelling is assembled here rather than written out: this block measures the source it
  # lives in, and a literal of the scanned name inside the scanner is the trap this file has named
  # three times already (P-05, P-06, X-01).
  $a09Var = [string][char]0x24 + 'Cmd'
  $a09Own = $a09Var + 'Name'
  $a09Plant = @(
    'function F-Borrower($a) { return $Cmd }',
    'function F-Owner([string]$Cmd) { return $Cmd }',
    'function F-Silent($a) { return $a }'
  )
  $a09PlantParsed = Parse-SourceForInventory ($a09Plant -join "`n")
  $a09Bare = Get-VarUseCountInFunction $a07Parsed "$script:StCommandToken" $a09Var
  $a09OwnUses = Get-VarUseCountInFunction $a07Parsed "$script:StCommandToken" $a09Own
  $a09PlantBorrow = Get-VarUseCountInFunction $a09PlantParsed 'F-Borrower' $a09Var
  $a09PlantAbsent = Get-VarUseCountInFunction $a09PlantParsed 'F-No-Such' $a09Var
  ST-Check 'lint (A-09): the audited command body reads no caller-scope command variable at all and uses its own declared parameter twice, while a planted borrow and an absent function both come back named' (
    ($a09Bare -ceq '0') -and ($a09OwnUses -ceq '2') -and ($a09PlantBorrow -ceq '1') -and ($a09PlantAbsent -ceq '-absent'))
  $a09OwnerList = Get-VarUseOwnerList $a07Parsed $a09Var
  $a09OwnerGap = Get-InventoryDiscrepancy $a09OwnerList $script:StCmdVarUses
  $a09Uses = @($a09OwnerList -split ';').Count
  $a09EntryDeclares = $false
  foreach ($a09N in @((Get-EntryParamNameString $a07Parsed) -split ';')) { if ([string]$a09N -ceq 'Cmd') { $a09EntryDeclares = $true } }
  $a09Undeclared = Get-UndeclaredVarUseDiscrepancy $a07Parsed $a09Var $a09EntryDeclares
  $a09NoExemption = Get-UndeclaredVarUseDiscrepancy $a07Parsed $a09Var $false
  $a09PlantNote = Get-UndeclaredVarUseDiscrepancy $a09PlantParsed $a09Var $true
  ST-Check 'lint (A-09): every use of the dispatcher command variable sits in an owner that declares it, a planted borrower is named with its count while a planted owner is left alone, and the top-level exemption is itself load-bearing' (
    ($a09Undeclared -ceq '') -and ($a09PlantNote.Contains('fn:F-Borrower=uses1-undeclared')) -and
    (-not $a09PlantNote.Contains('fn:F-Owner=')) -and ($a09NoExemption.Contains('script-uses15-without-entry-param')))
  if ($a09Undeclared -ne '') { Write-Output ('      undeclared uses: ' + $a09Undeclared) }
  $a09DYes = Get-FunctionDeclaresParameter $a09PlantParsed 'F-Owner' 'Cmd'
  $a09DNo = Get-FunctionDeclaresParameter $a09PlantParsed 'F-Borrower' 'Cmd'
  $a09DAbsent = Get-FunctionDeclaresParameter $a09PlantParsed 'F-No-Such' 'Cmd'
  ST-Check 'unit (A-09): the declare-check keeps yes, no and absent distinguishable, and the registered owners account for every use of the dispatcher variable (the count is in the detail line, not in the name)' (
    ($a09DYes -ceq 'yes') -and ($a09DNo -ceq 'no') -and ($a09DAbsent -ceq 'absent') -and
    ($a09OwnerGap -ceq '') -and ($a09Uses -eq 87) -and (@($script:StCmdVarUses).Count -eq 46))
  if ($a09OwnerGap -ne '') { Write-Output ('      use owners: ' + $a09OwnerGap) }
  Write-Output ('      A-09: uses=' + $a09Uses + ' owners=' + @($script:StCmdVarUses).Count + ' entry-declares=' + $a09EntryDeclares +
    ' bare-reads-in-audited-body=' + $a09Bare + ' own-param-uses=' + $a09OwnUses + ' undeclared=[' + $a09Undeclared + ']')

  # ---------- v4.4.0 (A-11a): the path anchors are the only way a moved section can name the tool ----------
  $a11Parsed = $a07Parsed
  $a11SelfCount = Get-PathReadCountInFunction $a11Parsed 'Invoke-SelfTest'
  $a11Absent = Get-PathReadCountInFunction $a11Parsed 'F-No-Such-Function'
  $a11Plant = @(
    'function F-UsesAutoPath($a) { return ($a + $PSScriptRoot) }',
    'function F-UsesAnchor($a) { return ($a + $script:ToolRootPath) }'
  )
  $a11PlantParsed = Parse-SourceForInventory ($a11Plant -join "`n")
  $a11PlantAuto = Get-PathReadCountInFunction $a11PlantParsed 'F-UsesAutoPath'
  $a11PlantAnchor = Get-PathReadCountInFunction $a11PlantParsed 'F-UsesAnchor'
  ST-Check 'unit (A-11a): the path-read counter sees a planted automatic-variable read, stays at zero for a planted anchor read, and says absent for a function that is not there' (
    ($a11PlantAuto -ceq '1') -and ($a11PlantAnchor -ceq '0') -and ($a11Absent -ceq '-absent'))
  $a11Owners = Get-PathReadOwnerList $a11Parsed
  $a11OwnerGap = Get-InventoryDiscrepancy $a11Owners $script:StPathReadOwners
  # A-11b/A-13/A-14b: every dot-import line is itself a read of $PSScriptRoot at the entry top level
  # (twenty-two of them now) - and that is the one place where it still means the tool root. Registered,
  # not excused. A family file that reintroduced a bare read would show up as an unlisted owner row.
  $a11Total = 0
  if ("$a11Owners" -ne '') { $a11Total = @($a11Owners -split ';').Count }
  # A-22: the owner table attributes each remaining read to the FILE that holds it. In a stitched artifact
  #    there is only one file and the twenty-two dot-import reads are gone by construction, so the table
  #    cannot be reconciled here - it is an aggregate-mode claim, like the A-05 pair above. The two
  #    mode-independent claims (the planted predicate, and the anchors resolving) stay executed in both.
  if ($script:StSourceMode -ceq 'aggregate') {
    ST-Check 'lint (A-11a): the selftest section no longer reads an automatic path variable, and the readers that remain are exactly the registered sections that have not moved yet' (
      ($a11OwnerGap -ceq '') -and ($a11Total -eq 31) -and (@($script:StPathReadOwners).Count -eq 6) -and
      ($a11SelfCount -ceq '0'))
    if ($a11OwnerGap -ne '') { Write-Output ('      path readers: ' + $a11OwnerGap) }
  } else {
    ST-Skip 'lint (A-11a): the selftest section no longer reads an automatic path variable, and the readers that remain are exactly the registered sections that have not moved yet' 'single-file source mode (no lib/ beside the entry) - one file, and the dot-import reads the table counts were replaced by the stitcher'
  }
  $a11Mapped = $script:StFileMap['desktop.ps1']
  $a11LeafOk = [bool](Test-Path -LiteralPath "$script:ToolEntryPath" -PathType Leaf)
  $a11DirOk = $false
  if ($a11LeafOk) { $a11DirOk = ((Get-Item -LiteralPath "$script:ToolEntryPath").Directory.FullName -ceq "$script:ToolRootPath") }
  $a11MapOk = ("$script:ToolEntryPath" -ceq "$a11Mapped")
  ST-Check 'lint (A-11a): the published anchors resolve to a real entry file whose directory is the published root, and the entry they name is the same path the source list maps desktop.ps1 to' (
    $a11LeafOk -and $a11DirOk -and $a11MapOk -and (("$script:ToolRootPath").Length -gt 3))
  Write-Output ('      A-11a anchors: root=[' + "$script:ToolRootPath" + '] entry=[' + ("$script:ToolEntryPath").Substring(0, [Math]::Min(46, ("$script:ToolEntryPath").Length)) + ']' +
    ' selftest-path-reads=' + $a11SelfCount + ' remaining-reads=' + $a11Total + ' registered-owners=' + @($script:StPathReadOwners).Count)

  # ---------- v4.4.0 (A-12): a line number in the moved section has to say which file it means ----------
  # A-11b put the section at the END of the aggregate, so a bare index echoed from here points at a
  # position a reader cannot locate in either visible file. Seven readings still printed raw aggregate
  # indices; they now go through the resolver, which yields 'file:line' in aggregate mode and the same
  # bare number in single-file mode (the installed product must not change shape - A-04's rule).
  # The scan is assembled from characters for the same reason A-04's is: a literal of a forbidden
  # shape is found by the gate that forbids it. The canary proves "zero left" is a measurement.
  $a12D = [string][char]0x24
  $a12Shapes = @(
    ('(@(' + $a12D + 'j5Wire) -join '),
    ('(@(' + $a12D + 'evWire) -join '),
    ('((@(' + $a12D + 'tewCalls) | ForEach-Object'),
    ('(@(' + $a12D + 'dcCase) -join '),
    ('(' + $a12D + 'xEmit -join '),
    ('(@(' + $a12D + 'f2CallSites) -join '),
    ('(@(' + $a12D + 'c6Hard) -join ')
  )
  $a12Left = @()
  foreach ($a12Sh in $a12Shapes) {
    if (@(@($script:StSourceLines) | Where-Object { ([string]$_).Contains([string]$a12Sh) }).Count -gt 0) { $a12Left += [string]$a12Sh }
  }
  $a12Planted = ('  Write-Output "      J-05 sites: $(@(' + $a12D + 'j5Wire).Count) (lines $(@(' + $a12D + 'j5Wire) -join '' ''))"')
  $a12Canary = 0
  foreach ($a12Sh in $a12Shapes) { if (([string]$a12Planted).Contains([string]$a12Sh)) { $a12Canary = $a12Canary + 1 } }
  ST-Check 'lint (A-12): the seven readings A-11b left as bare aggregate indices are resolver-routed, and the scan catches a planted bare join (so zero-left means measured, not blind)' (
    (@($a12Left).Count -eq 0) -and ($a12Canary -ge 1) -and (@($a12Shapes).Count -eq 7))
  Write-Output ('      A-12 bare-index scan: shapes=' + @($a12Shapes).Count + ' left=' + @($a12Left).Count + ' canary=' + $a12Canary)
  if (@($a12Left).Count -gt 0) { Write-Output ('      still bare: ' + ($a12Left -join ' | ')) }
  # The other thing A-11b changed: the audited command and the double that replaces it now live in
  # DIFFERENT files. Attribution is read off the span resolver rather than a remembered line number,
  # so the check moves with the code instead of rotting where it was written.
  $a12ProdMark = 'function ' + "$script:StCommandToken" + '('
  $a12StubMark = '} = { param(' + $a12D + 'la, ' + $a12D + 'detail'
  $a12ProdLine = -1
  $a12StubLine = -1
  for ($a12i = 0; $a12i -lt @($script:StSourceLines).Count; $a12i++) {
    $a12t = [string]$script:StSourceLines[$a12i]
    if (($a12ProdLine -lt 0) -and $a12t.StartsWith($a12ProdMark)) { $a12ProdLine = $a12i + 1 }
    if (($a12StubLine -lt 0) -and $a12t.Contains($a12StubMark)) { $a12StubLine = $a12i + 1 }
  }
  $a12ProdRef = [string](Format-SourceLineRef $a12ProdLine)
  $a12StubRef = [string](Format-SourceLineRef $a12StubLine)
  $a12Align = Get-StubAlignmentDiscrepancy $a07Parsed "$script:StCommandToken"
  $a12Attribution = $false
  if ("$script:StSourceMode" -ceq 'aggregate') {
    # v4.4.0 (A-14o): the predicate used to name the file that held the double, and lifting that body
    # (A-14o moved it to lib/selftest-drag-press.ps1) made a true claim read false. Ask the question the
    # sentence actually asks: the double must sit INSIDE THE SELFTEST SPAN - the window the section
    # publishes - and the definition in the entry. A file name is not a boundary; the span is.
    $a12InWindow = ($a12StubLine -gt [int]$Ctx['j5ProdStart']) -and ($a12StubLine -le [int]$Ctx['j5ProdEnd'])
    $a12Attribution = ($a12ProdRef.StartsWith('desktop.ps1:')) -and $a12InWindow
  } else {
    $a12Attribution = (-not $a12ProdRef.Contains(':')) -and (-not $a12StubRef.Contains(':'))
  }
  ST-Check 'lint (A-12): the audited command is defined in the entry while its test double is installed inside the moved section, each is attributed to the file that really holds it, and the double still matches the production arity' (
    ($a12ProdLine -gt 0) -and ($a12StubLine -gt 0) -and ($a12ProdLine -ne $a12StubLine) -and
    $a12Attribution -and ($a12Align -ceq ''))
  Write-Output ('      A-12 table seam: production=[' + $a12ProdRef + '] double=[' + $a12StubRef + '] alignment=[' + $a12Align + '] mode=' + "$script:StSourceMode")

  # ---------- v4.4.0 (A-14a): the selftest body is attributed to families, by banner text ----
  # The partition must be MEASURED, not guessed: v7 B.3's keyword sketch left 3,610 lines
  # unclassified, which is larger than any real family. So every banner in the selftest body is
  # enumerated here, claimed by exactly one declared family (precedence is data), and each family's
  # banner count and line span are compared with the registered table. When A-14b starts cutting the
  # body into family files, a family that shrinks by accident shows up in this line, not in a comment.
  $a14Scope = @('Invoke-SelfTest')
  foreach ($a14lk in @($script:StFamilyLifted)) { $a14Scope += Get-FamilyFunctionName $a14lk }
  $a14Records = Get-FamilyBannerRecords $a07Parsed @($script:StSourceLines) $a14Scope
  $a14Assign = Get-FamilyAssignText "$a14Records" $script:StFamilyOrder $script:StFamilyFragments
  $a14Notes = Get-FamilyAgreement "$a14Assign" $script:StFamilyOrder $script:StFamilyCounts
  $a14BannerCount = 0
  if ("$a14Records" -ne '') { $a14BannerCount = @("$a14Records" -split "`n").Count }
  ST-Check 'lint (A-14a): every banner in the selftest body is claimed by exactly one declared family, and the measured tallies equal the registered table (a shrunk or empty family is named with its numbers)' (
    ("$a14Notes" -ceq '') -and ($a14BannerCount -eq 165) -and (@($script:StFamilyOrder).Count -eq 15) -and
    (@($script:StFamilyCounts.Keys).Count -eq 15))
  if ("$a14Notes" -ne '') { Write-Output ('      family attribution drift: ' + $a14Notes) }
  Write-Output ('      A-14a families=' + @($script:StFamilyOrder).Count + ' banners=' + $a14BannerCount + ' measured=[' + (("$a14Assign" -split "`n") -join ' / ') + ']')
  $a14PlantRec = (@(
    ("live: v9.9.9 verification-challenge workflow end to end" + "`t" + 7),
    ("v9.9.9 verification-challenge workflow offline shapes" + "`t" + 3),
    ("a banner nobody claimed in a thousand years" + "`t" + 11)
  ) -join "`n")
  $a14PlantAssign = Get-FamilyAssignText $a14PlantRec $script:StFamilyOrder $script:StFamilyFragments
  $a14PlantOk = Get-FamilyAgreement $a14PlantAssign @('live-suite', 'challenge-workflow') @{ 'live-suite' = 'banners=1,lines=7'; 'challenge-workflow' = 'banners=1,lines=3' }
  $a14PlantShrunk = Get-FamilyAgreement $a14PlantAssign @('live-suite', 'challenge-workflow') @{ 'live-suite' = 'banners=9,lines=99'; 'challenge-workflow' = 'banners=1,lines=3' }
  $a14PlantEmpty = Get-FamilyAgreement $a14PlantAssign @('live-suite', 'challenge-workflow', 'drag-press') @{ 'live-suite' = 'banners=1,lines=7'; 'challenge-workflow' = 'banners=1,lines=3'; 'drag-press' = 'banners=3,lines=191' }
  ST-Check 'unit (A-14a): live banners are claimed by the mode family ahead of their topic family, an unclaimed banner is reported instead of dropped, and a shrunk or empty registered family is named with both numbers' (
    ($a14PlantAssign.Contains('live-suite' + [string][char]9 + '1' + [string][char]9 + '7')) -and
    ($a14PlantAssign.Contains('challenge-workflow' + [string][char]9 + '1' + [string][char]9 + '3')) -and
    (-not $a14PlantAssign.Contains('challenge-workflow' + [string][char]9 + '2')) -and
    ($a14PlantOk.Contains('unclaimed-banners=1-lines=11')) -and
    ($a14PlantShrunk.Contains('live-suite=gotbanners=1,lines=7-wantbanners=9,lines=99')) -and
    ($a14PlantEmpty.Contains('drag-press=registered-but-empty')))
  $a14ScopePlant = @(
    'function Invoke-SelfTest([string[]]$Rest) {',
    '  # ---------- v9.9.9 alpha banner inside ----------',
    '  $x = 1',
    '  # ---------- v9.9.9 beta banner inside ----------',
    '  return $x',
    '}',
    'function Other-Thing {',
    '  # ---------- v9.9.9 gamma banner outside ----------',
    '}'
  )
  $a14ScopeParsed = Parse-SourceForInventory ($a14ScopePlant -join "`n")
  $a14ScopeRec = Get-FamilyBannerRecords $a14ScopeParsed @($a14ScopePlant)
  $a14ScopeCount = 0
  if ("$a14ScopeRec" -ne '') { $a14ScopeCount = @("$a14ScopeRec" -split "`n").Count }
  $a14ScopeAbsentParsed = Parse-SourceForInventory 'function Other-Thing { return 1 }'
  $a14ScopeAbsent = Get-FamilyBannerRecords $a14ScopeAbsentParsed @('function Other-Thing { return 1 }')
  $a14ScopeNoParse = Get-FamilyBannerRecords $null @('x')
  ST-Check 'unit (A-14a): the banner scan counts only what sits inside the selftest body, and answers -absent or -no-parse rather than zero when the body or the parse is not there (a count of nothing must never read as a count of zero)' (
    ($a14ScopeCount -eq 2) -and ("$a14ScopeRec".Contains('alpha banner inside')) -and ("$a14ScopeRec".Contains('beta banner inside')) -and
    (-not "$a14ScopeRec".Contains('gamma banner outside')) -and ("$a14ScopeAbsent" -ceq '-absent') -and ("$a14ScopeNoParse" -ceq '-no-parse'))

  # ---------- v4.4.0 (A-14b): a lifted family keeps its own state contract ----------
  # The cut above is only safe if the family that moved out still gets the same state it had when it
  # was inline. That cannot be asserted by "it still runs green": a missing context value reaches a
  # gate as an empty string, and an empty string satisfies a comparison that was never given a
  # non-empty witness. So the contract is measured on both sides - what the orchestrator publishes,
  # what each family asks for, and what each family still reaches for by bare name.
  $a14bPub = Get-CtxPublishedKeys $a07Parsed @($script:StSourceLines)
  $a14bPre = 'lib/selftest-'
  $a14bSuf = '.ps1'
  $a14bMissing = @()
  $a14bOrphan = @()
  $a14bGaps = @()
  foreach ($a14bKey in @($script:StFamilyLifted)) {
    $a14bWant = $a14bPre + [string]$a14bKey + $a14bSuf
    $a14bInList = $false
    foreach ($a14bF in @($script:StSourceFiles)) { if (([string]$a14bF) -ceq $a14bWant) { $a14bInList = $true } }
    if (-not $a14bInList) { $a14bMissing += ([string]$a14bKey + '=' + $a14bWant) }
    # v4.4.0 (A-14l): a family may also write its declared hand-backs back into the context object, so the
    # surface it is allowed to touch is the published keys plus its own export list. A sentinel in the
    # published list never equals a key name, so an unmeasurable publish side still reddens every ask.
    $a14bAllow = (@(@([string]$a14bPub -split ',') + @(Get-FamilyExportNames $a14bKey)) -join ',')
    $a14bGaps += Get-FamilyCtxGap $a07Parsed @($script:StSourceLines) (Get-FamilyFunctionName $a14bKey) $a14bAllow
  }
  # ---------- v4.4.0 (A-14q): the two exemptions above are measured against a real breach ----------
  # An exemption is only honest if the wall still stands next to it. One planted family uses both
  # shapes this lift carries (a nested function with its own parameters, an automatic-variable read)
  # and must come back CLEAN; a second planted family reads a plain caller local and must still be
  # named with its line. If either half is wrong the check says so - it cannot pass by measuring nothing.
  $a14qPlant = @(
    'function Invoke-SelftestFamily-CleanPlanted($Ctx) {',
    '  function Inner-Planted([string]$p, [int]$q) { return ($p + [string]$q) }',
    '  $r = Inner-Planted ''x'' 1',
    '  if ($PSVersionTable.PSVersion.Major -ge 5) { $r = ($r + ''5'') }',
    '  return $r',
    '}',
    'function Invoke-SelftestFamily-LeakPlanted($Ctx) {',
    '  return ($someCallerLocal + 1)',
    '}')
  $a14qPlantParsed = Parse-SourceForInventory ($a14qPlant -join "`n")
  $a14qCleanGap = Get-FamilyCtxGap $a14qPlantParsed @($a14qPlant) 'Invoke-SelftestFamily-CleanPlanted' 'nothing'
  $a14qLeakGap = Get-FamilyCtxGap $a14qPlantParsed @($a14qPlant) 'Invoke-SelftestFamily-LeakPlanted' 'nothing'
  # ---------- v4.4.0 (S-92): the two shapes that used to read as clean ----------
  # Planted, so the fix is measured and not asserted: a DOUBLE-QUOTED ask for an unpublished key must be
  # named, and a single-quoted string that merely CONTAINS $live = 1 must not be credited with binding
  # it - while the line that really assigns $note still has to count as a binding (the control half,
  # without which "I stripped strings" could pass by stripping everything).
  $a92Plant = @(
    'function Invoke-SelftestFamily-DqWritePlanted($Ctx) {',
    '  $Ctx["undeclaredWritePlanted"] = 1',
    '}',
    'function Invoke-SelftestFamily-DqPlanted($Ctx) {',
    '  $v = $Ctx["unpublishedPlanted"]',
    '  return $v',
    '}',
    'function Invoke-SelftestFamily-FakeBindPlanted($Ctx) {',
    '  $note = ''x $live = 1 y''',
    '  return $live',
    '}')
  $a92Parsed = Parse-SourceForInventory ($a92Plant -join "`n")
  $a92DqGap = Get-FamilyCtxGap $a92Parsed @($a92Plant) 'Invoke-SelftestFamily-DqPlanted' 'nothing'
  $a92WriteGap = Get-FamilyExportGap $a92Parsed 'Invoke-SelftestFamily-DqWritePlanted' @()
  $a92FakeGap = Get-FamilyCtxGap $a92Parsed @($a92Plant) 'Invoke-SelftestFamily-FakeBindPlanted' 'nothing'
  ST-Check 'unit (S-92): a double-quoted context ask is scanned, and a binding that lives inside a single-quoted string is not credited (the real assignment on the same line still is)' (
    ($a92DqGap.Contains('unpublishedPlanted=asked-not-published-at-')) -and
    ($a92FakeGap.Contains('live=free-read-at-')) -and (-not $a92FakeGap.Contains('note=free-read')) -and
    ($a92WriteGap.Contains('undeclaredWritePlanted=written-not-declared')))
  Write-Output ('      S-92 fixtures: dq=[' + "$a92DqGap" + '] fakebind=[' + "$a92FakeGap" + '] write=[' + "$a92WriteGap" + ']')
  ST-Check 'unit (A-14q): a nested function binding its own parameters and an automatic-variable read are not scope leaks, while a plain caller-local read still is (both sides of the exemption measured)' (
    ("$a14qCleanGap" -ceq '') -and ("$a14qLeakGap").Contains('somecallerlocal=free-read-at-'))
  Write-Output ('      A-14q gap fixtures: clean=[' + "$a14qCleanGap" + '] leak=[' + "$a14qLeakGap" + ']')

  # the reverse direction: a file named lib/selftest-<x>.ps1 in the source set without <x> being a
  # declared lifted family is a body of gates nothing attributes, which is how a split gets lost
  foreach ($a14bF in @($script:StSourceFiles)) {
    $a14bTxt = [string]$a14bF
    if (-not $a14bTxt.StartsWith($a14bPre)) { continue }
    if (-not $a14bTxt.EndsWith($a14bSuf)) { continue }
    $a14bMid = $a14bTxt.Substring($a14bPre.Length, $a14bTxt.Length - $a14bPre.Length - $a14bSuf.Length)
    $a14bKnown = $false
    foreach ($a14bKey in @($script:StFamilyLifted)) { if (([string]$a14bKey) -ceq $a14bMid) { $a14bKnown = $true } }
    if (-not $a14bKnown) { $a14bOrphan += $a14bMid }
  }
  $a14bGapCount = 0
  foreach ($a14bG in @($a14bGaps)) { if ([string]$a14bG -ne '') { $a14bGapCount = $a14bGapCount + 1 } }
  ST-Check 'lint (A-14b): every lifted family has its file in the declared source set, every lib/selftest-<key>.ps1 in the set has a lifted family behind it, and the context the section publishes is not empty' (
    (@($a14bMissing).Count -eq 0) -and (@($a14bOrphan).Count -eq 0) -and ("$a14bPub" -ne '-none') -and ("$a14bPub" -ne '-no-parse'))
  Write-Output ('      A-14b set: published=[' + $a14bPub + '] file-missing=[' + ($a14bMissing -join ';') + '] orphan=[' + ($a14bOrphan -join ';') + ']')
  ST-Check 'lint (A-14b): a lifted family asks only for published context keys or its own declared hand-backs, and reads no plain variable out of the caller scope (each breach names the variable and its line)' (
    ($a14bGapCount -eq 0))
  foreach ($a14bG in @($a14bGaps)) { if ([string]$a14bG -ne '') { Write-Output ('      A-14b state gap: ' + $a14bG) } }

  # Gates must stay COUNTABLE after the move: the registered number per body is what proves a family
  # file kept its checks, and an empty family - the signature of a body dropped in transit - is refused.
  # The zero has to have a witness: a counter that answers '0' for everything would pass a comparison
  # against a registered 0, and a counter that never answers 0 cannot catch an emptied family. So plant
  # one body with no checks and one with a check, and require the counter to tell them apart.
  $a14bZeroPlant = @(
    'function F-Empty-Family-Planted { return 1 }',
    'function F-One-Check-Planted { ST-Check (1 -eq 1) }'
  )
  $a14bZeroParsed = Parse-SourceForInventory ($a14bZeroPlant -join "`n")
  $a14bZeroGot = Get-CheckCallCountInFunction $a14bZeroParsed 'F-Empty-Family-Planted'
  $a14bOneGot = Get-CheckCallCountInFunction $a14bZeroParsed 'F-One-Check-Planted'
  $a14bCountNotes = @()
  $a14bTotal = 0
  foreach ($a14bRow in @($script:StFamilyCheckCounts)) {
    $a14bPair = @([string]$a14bRow -split '=', 2)
    $a14bBody = [string]$a14bPair[0]
    $a14bWant = [string]$a14bPair[1]
    $a14bGot = Get-CheckCallCountInFunction $a07Parsed $a14bBody
    if ($a14bGot -ceq $a14bWant) {
      $a14bTotal = $a14bTotal + [int]$a14bWant
      if (([int]$a14bWant) -lt 1) { $a14bCountNotes += ($a14bBody + '=registered-empty-body') }
      continue
    }
    $a14bCountNotes += ($a14bBody + '-want' + $a14bWant + '-got' + $a14bGot)
  }
  foreach ($a14bN in (@('Invoke-SelfTest') + @(foreach ($a14bKey in @($script:StFamilyLifted)) { Get-FamilyFunctionName $a14bKey }))) {
    $a14bListed = $false
    foreach ($a14bRow in @($script:StFamilyCheckCounts)) { if (([string]$a14bRow).StartsWith(([string]$a14bN) + '=')) { $a14bListed = $true } }
    if (-not $a14bListed) { $a14bCountNotes += ([string]$a14bN + '=body-unlisted') }
  }
  ST-Check 'lint (A-14b): each selftest body carries the registered number of check emitters, no lifted family is counted as empty, and no body can hold gates without being listed' (
    (@($a14bCountNotes).Count -eq 0) -and ($a14bTotal -ge 3) -and ($a14bZeroGot -ceq '0') -and ($a14bOneGot -ceq '1'))
  Write-Output ('      A-14b check counts: total=' + $a14bTotal + ' planted-empty=' + $a14bZeroGot + ' planted-one=' + $a14bOneGot + ' notes=[' + ($a14bCountNotes -join ';') + ']')

  # ---------- v4.4.0 (A-14c): the published context surface is itself a declared contract ----------
  # A-14b proved a family may only ask for published keys; this proves the PUBLISH side is the one
  # someone chose. Both halves matter: an extra key is a channel opened in passing, a dropped key is
  # a family quietly handed a null. The scan reads the orchestrator's own assignments, and the
  # comparison prints both sorted lists, so a mismatch names the side that moved.
  $a14cPub = Get-CtxPublishedKeys $a07Parsed @($script:StSourceLines)
  $a14cGot = @()
  if (("$a14cPub" -ne '-none') -and ("$a14cPub" -ne '-no-parse')) { $a14cGot = @([string]$a14cPub -split ',') }
  $a14cGotSorted = (@($a14cGot | Sort-Object) -join ',')
  $a14cWantSorted = (@($script:StCtxKeys | Sort-Object) -join ',')
  # The surface must carry VALUES, not just names: a publish line that ships $null would satisfy a
  # key comparison and leave a family with an empty array (the exact silent form A-08's audit column
  # took). So measure the handover live - $codeLines length must equal the $clCount that was hoisted
  # from it, and both must be far above the size of any empty handover.
  $a14cArrLen = @($Ctx['codeLines']).Count
  $a14cCountVal = 0
  $a14cParseOk = [int]::TryParse([string]$Ctx['clCount'], [ref]$a14cCountVal)
  if (-not $a14cParseOk) { $a14cCountVal = -1 }
  ST-Check 'lint (A-14c): the context keys this section publishes equal the registered list, so no family channel opens or closes without a name in the table' (
    ($a14cGotSorted -ceq $a14cWantSorted) -and (@($a14cGot).Count -eq @($script:StCtxKeys).Count) -and (@($a14cGot).Count -ge 2))
  $a14cHLines = @($Ctx['hLines']).Count
  $a14cHCases = @(Get-HashKeys $Ctx['hCaseStarts']).Count
  $a14cHFnEnd = 0
  $a14cHFnOk = [int]::TryParse([string]$Ctx['hFnEnd'], [ref]$a14cHFnEnd)
  if (-not $a14cHFnOk) { $a14cHFnEnd = -1 }
  # v4.4.0 (A-14m): the hoisted marker and its scan result must arrive as values. A handed-over name
  # that is $null would make the reader below compare against an empty string and stay green.
  $a14cEvMarkHit = ([string]$Ctx['evMark']).Contains('Verdict')
  $a14cEvWireN = @($Ctx['evWire']).Count
  # v4.4.0 (A-14o): the case table has to arrive as a table AND as a callable - a handed-over name
  # (or a $null index) would make the reader that asks for a case come back empty and stay green.
  $a14oCasesN = @($Ctx['gaCases']).Count
  # The kind is checked BEFORE the call. Casting a name to a scriptblock parses it, so a handed-over
  # string would throw here and kill the run instead of reporting the breach - a gate has to survive the
  # exact failure it exists to catch (found by this card's own mutant harness, case O3).
  $a14oIdxKind = ($Ctx['gaCaseIdx'] -is [scriptblock])
  $a14oIdxHit = -99
  $a14oIdxMiss = -99
  if ($a14oIdxKind) {
    $a14oIdxHit = & ([scriptblock]$Ctx['gaCaseIdx']) 'click'
    $a14oIdxMiss = & ([scriptblock]$Ctx['gaCaseIdx']) 'no-such-command-planted'
  }
  # A-14p: the three settled values must be a real path pair and a real boolean; the window snapshot
  # must arrive as rows with a usable pid. Each is checked in the shape its consumer uses, so a
  # published NAME (string where an array belongs) or a $null cannot pass by being truthy-ish.
  $a14pLogOk = ($Ctx['actionLog'] -is [string]) -and (([string]$Ctx['actionLog']).EndsWith('actions.log'))
  $a14pOutOk = ($Ctx['outDir'] -is [string]) -and (([string]$Ctx['outDir']).EndsWith('shots'))
  $a14pLiveOk = ($Ctx['live'] -is [bool])
  # v4.4.0 (A-14q): the five names gate-meta reads must arrive as the shapes its consumers use. A
  # handed-over NAME would make an index comparison silently false; a parse object without its root
  # would make the banner scan answer -no-parse inside the family while the run stayed green. Each
  # is measured, not asserted: the count has to EQUAL the table it indexes, the bounds have to order
  # the way the loops expect, and the parse has to still carry an AST root.
  $a14qCasesInt = -1
  [void][int]::TryParse([string]$Ctx['gaCasesCount'], [ref]$a14qCasesInt)
  $a14qCasesMatch = ($a14qCasesInt -eq @($Ctx['gaCases']).Count)
  $a14qHelpStartInt = -1
  [void][int]::TryParse([string]$Ctx['gaHelpStart'], [ref]$a14qHelpStartInt)
  $a14qHelpEndInt = -1
  [void][int]::TryParse([string]$Ctx['gaHelpEnd'], [ref]$a14qHelpEndInt)
  $a14qDispInt = -1
  [void][int]::TryParse([string]$Ctx['gaDispStart'], [ref]$a14qDispInt)
  $a14qBoundsOk = ($a14qHelpStartInt -ge 0) -and ($a14qHelpEndInt -gt $a14qHelpStartInt) -and ($a14qDispInt -ge 0)
  $a14qParseRootOk = ($Ctx['j5SelfParsed']).Root -is [System.Management.Automation.Language.ScriptBlockAst]
  ST-Check 'unit (A-14c): the published context arrives as values, not as names - the handed line array and its hoisted count agree with each other and neither is an empty handover' (
    ($a14cArrLen -eq $a14cCountVal) -and ($a14cArrLen -gt 1000) -and ([int]$Ctx['j5ProdEnd'] -ge [int]$Ctx['j5ProdStart']) -and
    (@($Ctx['srcLines']).Count -eq $a14cArrLen) -and
    ($a14cHLines -gt 100) -and ($a14cHCases -ge 40) -and ($a14cHFnEnd -gt 0) -and
    ($a14cEvMarkHit -eq $true) -and ($a14cEvWireN -eq 2) -and
    ($a14oCasesN -ge 40) -and ($a14oIdxKind -eq $true) -and ($a14oIdxHit -ge 0) -and ($a14oIdxMiss -eq -1) -and
    ($a14pLogOk -eq $true) -and ($a14pOutOk -eq $true) -and ($a14pLiveOk -eq $true) -and
    ($a14qCasesMatch -eq $true) -and ($a14qBoundsOk -eq $true) -and ($a14qParseRootOk -eq $true))
  Write-Output ('      A-14c published: got=[' + $a14cGotSorted + '] want=[' + $a14cWantSorted + '] mode=' + ("$a14cPub"))
  Write-Output ('      A-14c live handover: codeLines=' + $a14cArrLen + ' clCount=' + $a14cCountVal +
    ' j5window=[' + [string]$Ctx['j5ProdStart'] + '..' + [string]$Ctx['j5ProdEnd'] + ']' +
    ' help=[' + $a14cHLines + ' lines, ' + $a14cHCases + ' cases, fnEnd=' + $a14cHFnEnd + ']')
  Write-Output ('      A-14o handover: gaCases=' + $a14oCasesN + ' kind-is-scriptblock=' + $a14oIdxKind + ' idx(click)=' + $a14oIdxHit + ' idx(planted-miss)=' + $a14oIdxMiss)
  Write-Output ('      A-14m handover: evMark-hit=' + $a14cEvMarkHit + ' evWire-sites=' + $a14cEvWireN)
  Write-Output ('      A-14q handover: cases-count=' + $a14qCasesInt + ' matches-table=' + $a14qCasesMatch +
    ' help=[' + $a14qHelpStartInt + '..' + $a14qHelpEndInt + '] disp-start=' + $a14qDispInt +
    ' parse-root-is-ast=' + $a14qParseRootOk)
  # A-14p: only the three values published in setup are witnessed here. The window snapshot is published
  # later in the body (in place, because it is a live enumeration) and this family runs before that
  # point - a first version of this witness reported w0-pid=-1, which was the gate correctly refusing an
  # ordering that never existed. Its check lives at the publish site instead (lint (A-14p) below).
  Write-Output ('      A-14p handover: actionLog-path=' + $a14pLogOk + ' outDir-path=' + $a14pOutOk +
    ' live-is-bool=' + $a14pLiveOk)

  # ---------- v4.4.0 (A-14f): the exemption window is measured, and its width is checked ----------
  # A window that says "everything from here to the next ^function" stops at the first family file, so
  # each family that moved out was quietly re-counted as production - two lints reddened on the move.
  # The fix is an AST extent over every selftest body; the thing that makes the fix safe is this gate:
  # a wider blanket exempts whatever happens to sit under it, so a foreign function inside the span is
  # named, and the planted case below proves the naming is not vacuous.
  $a14fNames = @('Invoke-SelfTest')
  foreach ($a14fK in @($script:StFamilyLifted)) { $a14fNames += Get-FamilyFunctionName $a14fK }
  $a14fWin = Get-SelftestWindow $a07Parsed @($a14fNames)
  $a14fForeign = Get-ForeignFunctionNames $a07Parsed @($a14fNames) "$a14fWin"
  $a14fPlant = @(
    'function Invoke-SelfTest {',
    '  return 1',
    '}',
    'function Helper-Inside-Window {',
    '  return 3',
    '}',
    'function Invoke-SelftestFamily-Fake {',
    '  return 2',
    '}',
    'function Truly-Outside {',
    '  return 4',
    '}'
  )
  $a14fPlantParsed = Parse-SourceForInventory ($a14fPlant -join "`n")
  $a14fPlantWin = Get-SelftestWindow $a14fPlantParsed @('Invoke-SelfTest', 'Invoke-SelftestFamily-Fake')
  $a14fPlantForeign = Get-ForeignFunctionNames $a14fPlantParsed @('Invoke-SelfTest', 'Invoke-SelftestFamily-Fake') "$a14fPlantWin"
  $a14fAbsentWin = Get-SelftestWindow (Parse-SourceForInventory 'function Other-Thing { return 1 }') @('Invoke-SelfTest')
  $a14fBadWindow = Get-ForeignFunctionNames $a14fPlantParsed @('Invoke-SelfTest') 'not-a-window'
  ST-Check 'lint (A-14f): the production window spans every selftest body by AST extent, no foreign function hides inside it, and the scan names a planted one instead of answering empty' (
    (("$a14fWin" -ne '-absent') -and ("$a14fWin" -ne '-no-parse')) -and ($a14fForeign -ceq '') -and
    ($a14fPlantForeign -ceq 'Helper-Inside-Window') -and ($a14fAbsentWin -ceq '-absent') -and ($a14fBadWindow -ceq '-bad-window'))
  Write-Output ('      A-14f window: [' + ("$a14fWin").Replace("`t", '..') + '] bodies=' + @($a14fNames).Count +
    ' foreign=[' + ("$a14fForeign") + '] planted=[' + ("$a14fPlantForeign") + '] absent=' + ("$a14fAbsentWin"))

  # and the scalars handed to the families must still BE the window - a stale pair would re-widen
  # production for every lifted body while every name-level check stayed green
  $a14fW = @([string]$a14fWin -split "`t", 2)
  ST-Check 'unit (A-14f): the window published through $Ctx is the same pair of numbers the AST measures now, so no lifted body is exempted by a stale span' (
    (@($a14fW).Count -eq 2) -and ([int]$Ctx['j5ProdStart'] -eq ([int]$a14fW[0] - 1)) -and ([int]$Ctx['j5ProdEnd'] -eq [int]$a14fW[1]))

  # ---------- v4.4.0 (A-14r): the chain predicate is planted in every breach shape it can name ----------
  # lint (A-14r) at the publish site judges the live tree, so it cannot be broken without editing the
  # tree; this gate judges the PREDICATE, and every fixture below is a shape the orchestration could
  # really drift into. The three the owner named for this card are here: a publish that was never
  # written, a consume that runs before the publish, and a publish carrying a different variable than
  # the re-bind bound. An expectation of "" would be a false green, so the clean fixture is only one
  # of the four readings asserted.
  $a14rChain = @('Invoke-SelftestFamily-PopupOcclusion $Ctx',
    '  $dcCase = $Ctx[''dcCase'']',
    '  $wT = $Ctx[''wT'']',
    '  $Ctx[''dcCase''] = $dcCase',
    '  $Ctx[''wT''] = $wT',
    'Invoke-SelftestFamily-GateMeta $Ctx')
  $a14rNoPub = @($a14rChain[0..3]) + @($a14rChain[5])
  $a14rEarly = @('Invoke-SelftestFamily-PopupOcclusion $Ctx',
    '  $dcCase = $Ctx[''dcCase'']',
    '  $wT = $Ctx[''wT'']',
    'Invoke-SelftestFamily-GateMeta $Ctx',
    '  $Ctx[''dcCase''] = $dcCase',
    '  $Ctx[''wT''] = $wT')
  $a14rCross = @('Invoke-SelftestFamily-PopupOcclusion $Ctx',
    '  $wA = $Ctx[''wA'']',
    '  $wB = $Ctx[''wB'']',
    '  $Ctx[''wA''] = $wB',
    'Invoke-SelftestFamily-GateMeta $Ctx')
  $a14rP = 'Invoke-SelftestFamily-PopupOcclusion'
  $a14rC = 'Invoke-SelftestFamily-GateMeta'
  $a14rG0 = Get-HandbackChainGap $a14rChain $a14rP $a14rC @('dcCase', 'wT')
  $a14rG1 = Get-HandbackChainGap $a14rNoPub $a14rP $a14rC @('dcCase', 'wT')
  $a14rG2 = Get-HandbackChainGap $a14rEarly $a14rP $a14rC @('dcCase', 'wT')
  $a14rG3 = Get-HandbackChainGap $a14rCross $a14rP $a14rC @('wA', 'wB')
  $a14rG4 = Get-HandbackChainGap @('Write-Output nothing-at-all') $a14rP $a14rC @('wA')
  $a14rSwap = @($a14rChain[0], $a14rChain[3], $a14rChain[1], $a14rChain[4], $a14rChain[2], $a14rChain[5])
  $a14rRev = @($a14rChain[5], $a14rChain[0], $a14rChain[1], $a14rChain[2], $a14rChain[3], $a14rChain[4])
  $a14rG5 = Get-HandbackChainGap $a14rSwap $a14rP $a14rC @('dcCase', 'wT')
  $a14rG6 = Get-HandbackChainGap $a14rRev $a14rP $a14rC @('dcCase', 'wT')
  $a14rG7 = Get-HandbackChainGap $a14rChain $a14rP $a14rP @('dcCase')
  $a14rG8 = Get-HandbackChainGap $a14rChain '' $a14rC @('dcCase')
  $a14rG9 = Get-HandbackChainGap $a14rChain $a14rP $a14rC @()
  ST-Check 'unit (A-14r): the chain predicate passes the ordered fixture and names every breach it can emit - missing publish, consume above the publish, a crossed value, a reversed pair, a publish before its re-bind - and refuses blank needles and an empty name list' (
    ($a14rG0 -ceq '') -and ($a14rG1 -ceq 'no-publish:wT') -and
    ($a14rG2 -ceq 'no-publish:dcCase,no-publish:wT') -and ($a14rG3 -ceq 'publish-name-wA=$wB,no-publish:wB') -and
    ($a14rG4 -ceq 'no-produce:Invoke-SelftestFamily-PopupOcclusion,no-consume:Invoke-SelftestFamily-GateMeta') -and
    ($a14rG5 -ceq 'order-rebind-publish-dcCase=2/1,order-rebind-publish-wT=4/3') -and
    ($a14rG6 -ceq 'order-produce-consume=1/0') -and ($a14rG7 -ceq 'bad-needles') -and
    ($a14rG8 -ceq 'bad-needles') -and ($a14rG9 -ceq 'bad-names'))
  Write-Output ('      A-14r chain fixtures: clean=[' + $a14rG0 + '] no-publish=[' + $a14rG1 +
    '] early=[' + $a14rG2 + '] crossed=[' + $a14rG3 + '] absent=[' + $a14rG4 +
    '] swap=[' + $a14rG5 + '] rev=[' + $a14rG6 + '] sameNeedle=[' + $a14rG7 + '] blank=[' + $a14rG8 + '] noNames=[' + $a14rG9 + ']')

  # ---------- v4.4.0 (A-16): a handler group leaves the entry only by naming the file it goes to ----------
  $a16Gap = Get-HandlerGroupGap $a07Parsed $script:StHandlerGroups $script:StHandlerFiles $script:StSourceSpans
  # A-22: same split as A-11a/A-05 - "defined in the file it names" needs the span map, which only exists
  #    in aggregate mode. The count row below still prints in both modes, so a reader always sees what the
  #    tables hold even where the ownership claim is not the thing under test.
  if ($script:StSourceMode -ceq 'aggregate') {
    ST-Check 'lint (A-16): every declared handler group is defined exactly once, in the file it names, with nothing left behind in the entry and nothing ungrouped (30/23/24/8 = all 85)' (
      ($a16Gap -ceq ''))
    if ($a16Gap -ne '') { Write-Output ('      group gap: ' + $a16Gap) }
  } else {
    ST-Skip 'lint (A-16): every declared handler group is defined exactly once, in the file it names, with nothing left behind in the entry and nothing ungrouped (30/23/24/8 = all 85)' 'single-file source mode (no lib/ beside the entry) - the artifact has one file by construction, so file ownership is not a claim it can carry'
  }
  Write-Output ('      A-16 groups: declared=' + @(Get-HashKeys $script:StHandlerGroups).Count + ' named-files=' +
    (@(Get-HashKeys $script:StHandlerFiles | Where-Object { [string]$script:StHandlerFiles[$_] -ne '' }).Count) + ' handlers-seen=' +
    (@($a07Parsed.Root.FindAll({ param($n) ($n -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($n.Name -clike 'Invoke-Handler-*') }, $true)).Count))

  # ---------- v4.4.0 (A-23): the exits inside moved bodies are named, and an artifact imports nothing ----------
  # criterion-5 . The thirteen exits that arrived with the case bodies are keyed by CASE; the eleven that never
  # lived in a case body are keyed by OWNER. Neither cohort can absorb a planting into the other, and
  # both readings come off the same AST the rest of this family uses, so a stitched artifact has to say
  # the same thing as the tree - which is the reason it is measured by name and not by file path.
  $a23Keys = @((Get-ExitOwnerList $a07Parsed) -split ';' | Where-Object { [string]$_ -ne '' })
  $a23CaseKeys = @($a23Keys | Where-Object { (-not ([string]$_).StartsWith('fn:')) -and ($_ -cne '<script>') })
  $a23OtherKeys = @($a23Keys | Where-Object { ([string]$_).StartsWith('fn:') -or ($_ -ceq '<script>') })
  $a23GapHandler = Get-InventoryDiscrepancy ((@($a23CaseKeys) -join ';')) $script:StHandlerExitAllowList
  $a23GapEntry = Get-InventoryDiscrepancy ((@($a23OtherKeys) -join ';')) $script:StEntryExitAllowList
  ST-Check 'lint (A-23): every exit inside a moved handler body is named by its case, the eight registered cases account for exactly fourteen, and a fifteenth is red' (
    ($a23GapHandler -ceq '') -and (@($a23CaseKeys).Count -eq 14) -and (@($script:StHandlerExitAllowList).Count -eq 8))
  if ($a23GapHandler -ne '') { Write-Output ('      handler exits: ' + $a23GapHandler) }
  ST-Check 'lint (A-23): the eleven exits that were never inside a moved body are named by owner too, so an exit planted outside a handler cannot be absorbed into the fourteen above' (
    ($a23GapEntry -ceq '') -and (@($a23OtherKeys).Count -eq 11) -and (@($a23Keys).Count -eq 25) -and (@($a23CaseKeys).Count -eq 14))
  if ($a23GapEntry -ne '') { Write-Output ('      entry exits: ' + $a23GapEntry) }
  # positive control for the predicate itself: a clean fixture counted by case, a planted handler named
  # as an owner nobody declared, a count that moved named, an entry that is gone named, and '-no-parse'
  # distinguishable from a measured zero.
  $a23FixTwoExit = 'function Invoke-Handler-demo($c) { if ($c) { exit 1 }' + "`n" + '  exit 0 }'
  $a23FixThreeExit = $a23FixTwoExit + "`n" + 'function Invoke-Handler-extra($c) { exit 7 }'
  $a23FixKeys = @((Get-ExitOwnerList (Parse-SourceForInventory $a23FixThreeExit)) -split ';' | Where-Object { [string]$_ -ne '' })
  $a23FixGap = Get-InventoryDiscrepancy ((@((Get-ExitOwnerList (Parse-SourceForInventory $a23FixTwoExit)) -split ';' | Where-Object { [string]$_ -ne '' })) -join ';') @('demo=1')
  $a23FixPlantGap = Get-InventoryDiscrepancy ((@($a23FixKeys) -join ';')) @('demo=2')
  $a23FixMissing = Get-InventoryDiscrepancy 'demo;demo' @('demo=2', 'gone=1')
  ST-Check 'unit (A-23): the exit-owner predicate counts a planted fixture by case, names a planted extra handler as an undeclared owner, names a count that moved and an entry that is gone, and answers -no-parse rather than empty' (
    ((@($a23FixKeys) -join ';') -ceq 'demo;demo;extra') -and ($a23FixPlantGap.Contains('observed:extra-declared=0')) -and
    ($a23FixGap.Contains('demo:got2-want1')) -and ($a23FixMissing.Contains('gone:got0-want1')) -and
    ((Get-ExitOwnerList $null) -ceq '-no-parse'))
  Write-Output ('      A-23 exit census: handler=' + @($a23CaseKeys).Count + ' entry=' + @($a23OtherKeys).Count +
    ' exit-statements-total=' + @($a23Keys).Count + ' aggregate-lines=' + @($script:StSourceLines).Count +
    ' parse-errors=' + [int]$a07Parsed.ErrorCount +
    ' registered-cases=' + @($script:StHandlerExitAllowList).Count + ' registered-entry-owners=' + @($script:StEntryExitAllowList).Count +
    ' fixture=' + (@($a23FixKeys) -join ';'))

  # criterion-9 . Only an artifact can be asked this: in this tree the markers and the imports ARE the loader, so
  # the claim is skipped out loud (and counted). When it does run, a breach count of zero only means
  # something if the scan really looked at a big source and had the data spans it protects on record -
  # otherwise an empty scan would report a clean install.
  if ($script:StSourceMode -ceq 'aggregate') {
    ST-Skip 'lint (A-23): the stitched artifact leaves no stitch marker attached to code and no dot-source of a lib path still executing' 'source-tree mode - this tree legitimately carries both the markers and the imports; the claim belongs to the artifact (see the single-file run)'
  } else {
    $a23Res = Get-StitchResidue @($script:StSourceLines)
    ST-Check 'lint (A-23): the stitched artifact leaves no stitch marker attached to code and no dot-source of a lib path still executing' (
      (@($script:StSourceLines).Count -gt 1000) -and ([int]$a23Res.ParseErrors -eq 0) -and ([int]$a23Res.DataSpans -gt 0) -and
      ($a23Res.Count -eq 0))
    Write-Output ('      A-23 artifact residue: lines=' + @($script:StSourceLines).Count + ' breaches=' + [int]$a23Res.Count +
      ' protected-data-spans=' + [int]$a23Res.DataSpans + ' parse-errors=' + [int]$a23Res.ParseErrors +
      ' breach-list=[' + ([string]$a23Res.Breaches) + ']')
  }
  # and the predicate has to answer on planted input in BOTH modes, or the skip above hides a ruler with no
  # marks: a dot-source of a lib path and a call-operator import are each named, a marker written as a
  # bare line of code is named, and the same marker inside a quoted string or a trailing comment is not.
  $a23Ndl = Get-CharCodeWord @(0x3C, 0x3C, 0x20, 0x73, 0x74, 0x69, 0x74, 0x63, 0x68, 0x3A, 0x20)
  $a23Fx1 = '. (Join-Path $PSScriptRoot ' + "'" + 'lib/x.ps1' + "'" + ') # ' + $a23Ndl + 'lib/x.ps1'
  $a23Fx2 = '& (Join-Path $PSScriptRoot ' + "'" + 'lib/q.ps1' + "'" + ')'
  $a23Fx3 = '# a sentence about ' + $a23Ndl + 'lib/z.ps1'
  $a23Fx4 = '$q = ' + "'" + $a23Ndl + "inside a string'"
  $a23FixLines = @($a23Fx1, $a23Fx2, $a23Fx3, $a23Fx4, 'Write-Output 1')
  $a23FixRes = Get-StitchResidue $a23FixLines
  $a23FixCleanRes = Get-StitchResidue @('Write-Output 1', ('$other = ' + "'" + 'nothing here' + "'"))
  $a23BareRes = Get-StitchResidue @('$v = 1', ('x ' + $a23Ndl + 'lib/b.ps1'))
  ST-Check 'unit (A-23): the residue predicate names a dot-source and a call-operator import of a lib path, names a marker written as code, leaves the same marker alone inside a quoted string and inside a comment, and reports zero on a clean fixture' (
    (([string]$a23FixRes.Breaches).Contains('dot-import-at-1')) -and (([string]$a23FixRes.Breaches).Contains('dot-import-at-2')) -and
    ($a23FixRes.Count -eq 2) -and (-not ([string]$a23FixRes.Breaches).Contains('marker-at-1')) -and
    (-not ([string]$a23FixRes.Breaches).Contains('marker-at-3')) -and (-not ([string]$a23FixRes.Breaches).Contains('marker-at-4')) -and
    ($a23FixCleanRes.Count -eq 0) -and ([int]$a23FixRes.DataSpans -ge 3) -and
    (([string]$a23BareRes.Breaches).Contains('marker-at-2')) -and (@($a23Ndl).Count -eq 1) -and ($a23Ndl.Length -eq 11))
  Write-Output ('      A-23 residue fixture: breaches=[' + [string]$a23FixRes.Breaches + '] data-spans=' + [int]$a23FixRes.DataSpans +
    ' bare-marker-fixture=[' + [string]$a23BareRes.Breaches + ']')

  # ---------- v4.4.0 (A-23): the declared version may not appear in a lib file's code (criterion-10) ----------
  # The version is read out of the entry's own authoritative slot, never hardcoded: a card that bumps the
  # version has to see this scan follow it, and a card that writes the number into the scan would be
  # pinning yesterday's value. Comments are the only thing excluded, and only the parser's opinion of what
  # a comment is counts - see the ruling note on Get-CodeTextWithoutComments.
  $a23Version = 'missing'
  if ("$src" -match '(?m)^# version: ([0-9.]+)') { $a23Version = [string]$Matches[1] }
  $a23LibFiles = @($script:StSourceFiles | Where-Object { ([string]$_) -cne 'desktop.ps1' })
  if ($script:StSourceMode -ceq 'aggregate') {
    $a23Scanned = 0
    $a23Unreadable = 0
    $a23Unparsed = 0
    $a23CodeHits = @()
    $a23CommentTokens = 0
    $a23Bytes = 0
    $a23CodeTokens = 0
    $a23Literals = 0
    $a23Searched = 0
    foreach ($f in @($a23LibFiles)) {
      $fp = Join-Path $script:ToolRootPath ([string]$f)
      if (-not (Test-Path -LiteralPath $fp -PathType Leaf)) { $a23Unreadable = $a23Unreadable + 1; continue }
      $nc = Get-CodeTextWithoutComments $fp
      $a23Scanned = $a23Scanned + 1
      $a23Bytes = $a23Bytes + [int]$nc.Bytes
      $a23CommentTokens = $a23CommentTokens + [int]$nc.CommentTokens
      $a23CodeTokens = $a23CodeTokens + [int]$nc.CodeTokens
      $a23Literals = $a23Literals + [int]$nc.LiteralSamples
      $a23Searched = $a23Searched + [int]$nc.SearchedChars
      if ([int]$nc.ParseErrors -gt 0) { $a23Unparsed = $a23Unparsed + 1; continue }
      if (($a23Version -cne 'missing') -and (([string]$nc.Text).Contains($a23Version))) { $a23CodeHits += ([string]$f) }
    }
    # the face of the scan is part of the claim, not a footnote: a zero hit only counts when the size of what
    # was searched and the number of literals in range are both non-zero and printed next to the zero.
    ST-Check 'lint (A-23): the version this entry declares appears in no lib file code - every declared lib file was read and parsed, comments alone are excluded, and an unreadable or unparseable file is a failure not a skip' (
      ($a23Version -cne 'missing') -and (@($a23LibFiles).Count -ge 7) -and ($a23Scanned -eq @($a23LibFiles).Count) -and
      ($a23Unreadable -eq 0) -and ($a23Unparsed -eq 0) -and ($a23CommentTokens -gt 0) -and ($a23Bytes -gt 100000) -and
      ($a23CodeTokens -gt 10000) -and ($a23Literals -gt 1000) -and ($a23Searched -gt 100000) -and
      (@($a23CodeHits).Count -eq 0))
    if (@($a23CodeHits).Count -gt 0) { Write-Output ('      version literal in code: ' + ((@($a23CodeHits) | Sort-Object -Unique) -join ', ')) }
    Write-Output ('      A-23 version scan: version=' + $a23Version + ' files=' + $a23Scanned + '/' + @($a23LibFiles).Count +
      ' bytes=' + $a23Bytes + ' comment-tokens=' + $a23CommentTokens + ' unreadable=' + $a23Unreadable + ' unparsed=' + $a23Unparsed +
      ' code-tokens=' + $a23CodeTokens + ' literal-samples=' + $a23Literals + ' searched-chars=' + $a23Searched +
      ' code-hits=' + @($a23CodeHits).Count)
  } else {
    ST-Skip 'lint (A-23): the version this entry declares appears in no lib file code - every declared lib file was read and parsed, comments alone are excluded, and an unreadable or unparseable file is a failure not a skip' 'single-file source mode (no lib/ beside the entry) - there is no lib set to scan here; the scan and its lower bound belong to the source tree'
  }
  # the exclusion has to be the parser's comment and nothing else: the same literal in a trailing comment
  # is invisible to the scan, in a single-quoted string and in a here-string it is still there, and a file
  # that does not parse is reported rather than passed over. That is the baseline-green / mutant-red pair
  # the ruling asks for, measured here so the gate above is never called a permanent green.
  $a23Tmp = Join-Path $env:TEMP ('a23-version-scan-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
  New-Item -ItemType Directory -Path $a23Tmp -Force | Out-Null
  try {
    $a23VerTok = '9.9.9'
    Set-Content -LiteralPath (Join-Path $a23Tmp 'in-comment.ps1') -Value ('$x = 1 # v' + $a23VerTok + ' landing note' + "`n" + '$y = 2') -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $a23Tmp 'in-string.ps1') -Value ('$x = ' + "'" + 'v' + $a23VerTok + "'" + "`n" + '$y = 2') -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $a23Tmp 'in-herestring.ps1') -Value ('$x = @(' + '"' + "`n" + 'v' + $a23VerTok + "`n" + '"' + '@' + "`n" + '$y = 2') -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $a23Tmp 'broken.ps1') -Value '$x = ( unclosed' -Encoding UTF8
    $a23InComment = Get-CodeTextWithoutComments (Join-Path $a23Tmp 'in-comment.ps1')
    $a23InString = Get-CodeTextWithoutComments (Join-Path $a23Tmp 'in-string.ps1')
    $a23InHere = Get-CodeTextWithoutComments (Join-Path $a23Tmp 'in-herestring.ps1')
    $a23Broken = Get-CodeTextWithoutComments (Join-Path $a23Tmp 'broken.ps1')
    ST-Check 'unit (A-23): the comment blanker removes the version from a comment but leaves it in a string and in a here-string, keeps the byte length it was given, reports a parse error instead of an empty scan, and states the size of the face it searched' (
        (-not (([string]$a23InComment.Text).Contains($a23VerTok))) -and ([int]$a23InComment.CommentTokens -eq 1) -and
        ([int]$a23InComment.BlankedChars -gt 0) -and ([int]$a23InComment.Bytes -eq [System.Text.Encoding]::UTF8.GetByteCount(([string]$a23InComment.Text))) -and
        ([int]$a23InComment.CodeTokens -ge 4) -and ([int]$a23InComment.SearchedChars -gt 0) -and
        (([string]$a23InString.Text).Contains($a23VerTok)) -and (([string]$a23InHere.Text).Contains($a23VerTok)) -and
        ([int]$a23InString.LiteralSamples -ge 1) -and ([int]$a23InHere.LiteralSamples -ge 1) -and
        (([string]$a23Broken.Text).Contains('unclosed')) -and ([int]$a23Broken.ParseErrors -ge 1))
    Write-Output ('      A-23 blanker fixture: comment-tokens=' + [int]$a23InComment.CommentTokens + ' blanked=' + [int]$a23InComment.BlankedChars +
      ' string-kept=' + ([string]$a23InString.Text).Contains($a23VerTok) + ' here-kept=' + ([string]$a23InHere.Text).Contains($a23VerTok) +
      ' broken-parse-errors=' + [int]$a23Broken.ParseErrors + ' code-tokens=' + [int]$a23InComment.CodeTokens +
      ' literal-samples=' + [int]$a23InString.LiteralSamples)
  } finally {
    Remove-Item -LiteralPath $a23Tmp -Recurse -Force
  }
}


