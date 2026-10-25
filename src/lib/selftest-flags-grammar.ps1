# lib/selftest-flags-grammar.ps1 - family flags-grammar of the selftest section, lifted out of
# lib/selftest.ps1 by A-14i (A-beta). Bodies are byte-identical to what the section carried.
# Fourteen banners in six gathered pieces: numeric arguments failing readably, menu-pick parser and
# its target predicate, the same hole elsewhere in the dispatcher, the chrome family promises, flag
# reachability, Strip-OwnFlags, the sibling-flag hint, bool-flag shared routing, the auto-grid
# decision, miss tails and premises, truncation self-report, and the six "do not lose" contracts.
# State arrives only through $Ctx and lint (A-14b) names anything that reaches past it. Gathering
# sixteen hundred lines of scatter into one function reorders the section; the card counts that by
# name and position. The clipboard-input CALL statement (1750..1752) is deliberately left in the
# orchestrator - a call belongs to the orchestration, not to whichever body happens to precede it.
function Invoke-SelftestFamily-FlagsGrammar($Ctx) {
  # context handover (the one thing in this file that is not lifted text)
  $src = [string]$Ctx['src']
  $codeLines = $Ctx['codeLines']
  $clCount = $Ctx['clCount']
  $code = $Ctx['code']
  $j5ProdStart = $Ctx['j5ProdStart']
  $j5ProdEnd = $Ctx['j5ProdEnd']
  # A-15: the case-shape gate needs the parse of the whole aggregate (the AST says what the switch
  # really has) and the two counts the other gates print, so the comparison is a cross-check and not
  # a fourth scan invented beside three that already exist.
  $j5SelfParsed = $Ctx['j5SelfParsed']
  $srcLines = $Ctx['srcLines']
  $gaCasesCount = $Ctx['gaCasesCount']
  $hCaseStarts = $Ctx['hCaseStarts']

  # ---------- unit: v1.5.2 R-12 numeric arguments fail readably ----------
  # Before: 'click abc def' surfaced the .NET binder message (Cannot convert value
  # "abc" to type "System.Int32") - true but not an instruction. One table drives
  # a pre-flight check so the family cannot split into "some nice, some internals".
  ST-Check 'unit: int args - valid pixels pass the gate' (
    (Test-IntArgs 'click' @('500', '600')) -and (Test-IntArgs 'rect' @('0', '0', '10', '10')))
  ST-Check 'unit: int args - negative coordinates are legal (multi-monitor)' (
    Test-IntArgs 'move' @('-32000', '-32000'))
  $ia1 = ''
  try { [void](Test-IntArgs 'click' @('abc', 'def')) } catch { $ia1 = $_.Exception.Message }
  ST-Check 'unit: int args - a bad coordinate gives an instruction, not .NET noise' (
    $ia1 -like "*must be a whole number of screen pixels*" -and $ia1 -notlike '*System.Int32*' -and $ia1 -like '*usage: click*')
  Write-Output "      int-arg message: $ia1"
  $ia2 = ''
  try { [void](Test-IntArgs 'move' @('12.5', '20')) } catch { $ia2 = $_.Exception.Message }
  ST-Check 'unit: int args - a fractional coordinate is refused with the same shape' (
    $ia2 -like "*got '12.5'*" -and $ia2 -notlike '*System.Int32*')
  $ia3 = ''
  try { [void](Test-IntArgs 'rect' @('0', '0', '3840')) } catch { $ia3 = $_.Exception.Message }
  ST-Check 'unit: int args - a missing coordinate says which one' ($ia3 -like '*missing argument #4*')
  ST-Check 'unit: int args - flags anywhere disable the positional gate (click --to X 500 600 stays legal)' (
    (Test-IntArgs 'click' @('--to', 'Notepad', '500', '600')) -and (Test-IntArgs 'relclick' @('sel', '--x', '1')))
  ST-Check 'unit: int args - commands with no declared numeric shape are untouched' (
    (Test-IntArgs 'focus' @('Notepad')) -and (Test-IntArgs 'wins' @()))
  # NOTE the foreach: 'Get-IntArgSpec a, Get-IntArgSpec b' would pass ONE array
  # argument to the first call instead of two calls (same family of trap as R-01)
  $iaNamed = @('rect', 'zoom', 'color-at', 'find-color', 'assert-color', 'move', 'click', 'rclick', 'dblclick', 'drag', 'hover', 'wheel', 'relclick', 'win-move', 'win-resize', 'imgclick', 'unmap', 'press-down', 'drag-to', 'press-up')
  $iaFound = 0
  foreach ($c in $iaNamed) { $sp = Get-IntArgSpec $c; if ($null -ne $sp) { $iaFound++ } }
  ST-Check 'unit: int args - the table covers every coordinate command (>= 20)' ($iaFound -ge 20)
  Write-Output "      int-arg table entries: $iaFound of $($iaNamed.Count)"


  # One grammar for every needle-consuming command: bare token, --needle <text>,
  # and unknown --xxx must THROW (never join the search). There is deliberately
  # NO bare -- terminator: powershell.exe swallows it at its own parameter-binding
  # layer before this parser runs, so exercising it in a test would be a green
  # light on a path no user can reach (it was implemented, measured unreachable,
  # and removed again).
  $nt1 = Resolve-NeedleToken 'QXNEEDLE'
  ST-Check 'unit: grammar - bare positional token is literal' ($nt1.Kind -ceq 'literal')
  $nt3 = Resolve-NeedleToken '--needle'
  ST-Check 'unit: grammar - --needle is the explicit form' ($nt3.Kind -ceq 'explicit')
  $nt4 = Resolve-NeedleToken '--expct'
  ST-Check 'unit: grammar - unknown flag is refused, not searched' ($nt4.Kind -ceq 'unknown')
  $nt7 = Resolve-NeedleToken '--'
  ST-Check 'unit: grammar - a lone -- is not a supported terminator (so it throws)' ($nt7.Kind -ceq 'unknown')
  $nt6 = Resolve-NeedleToken '-32000'
  ST-Check 'unit: grammar - a single-dash value token is not treated as a flag' ($nt6.Kind -ceq 'literal')
  $err6 = Get-NeedleFlagError 'find-text' '--expct'
  ST-Check 'unit: grammar - the refusal names exactly one escape route (--needle)' (
    $err6 -like '*unknown flag*' -and $err6 -like '*--needle*' -and $err6 -notlike '*terminator*')
  # the grammar must be wired into every loop that takes a needle - counting the
  # throw sites is the anti-drift nail (find-text/read-text/assert-text/menu-pick
  # each throw with their own command name; Split-Target covers click/type/keys/
  # paste/paste-file/find-click style commands with the shared message)
  $grammarSites = ([regex]::Matches($code, "unknown flag '")).Count
  ST-Check 'unit: grammar - every needle loop throws on an unknown flag (>= 5 sites)' ($grammarSites -ge 5)
  # nothing may half-implement the terminator again (branch or state variable).
  # The patterns are BUILT by concatenation so this line cannot match itself -
  # an earlier version counted its own pattern text and went red on a clean file.
  $termPat = "-eq '" + '--' + "'"
  $statePat = 'lit' + 'All'
  ST-Check 'unit: grammar - no -- terminator branch survives in the source' (
    ([regex]::Matches($code, [regex]::Escape($termPat))).Count -eq 0 -and ([regex]::Matches($code, $statePat)).Count -eq 0)
  Write-Output "      needle grammar refusal sites in source: $grammarSites"

  # ---------- v3.1.0 (P-06): menu-pick's extracted parser, four directions ----------
  $mp6Good = Resolve-MenuPickArgs @('Some Menu', 'File', '--expect', 'Done', '--timeout', '2.5')
  ST-Check 'unit (P-06): Resolve-MenuPickArgs keeps the documented defaults and reads a trailing operand when one is there' (
    (@($mp6Good.Words).Count -eq 2) -and ($mp6Good.Expect -eq 'Done') -and ([double]$mp6Good.TimeoutSec -eq 2.5) -and ($mp6Good.IntervalMs -eq 300))
  $mp6Err = ''
  try { $null = Resolve-MenuPickArgs @('Some Menu', 'File', '--expect') } catch { $mp6Err = "$($_.Exception.Message)" }
  ST-Check 'unit (P-06): a flag that lost its operand is REFUSED by name instead of binding $null (the old shape dropped the expectation and reported green)' (
    ($mp6Err -like '*--expect needs a value*') -and ($mp6Err -like '*silently dropped*'))
  $mp6Err2 = ''
  try { $null = Resolve-MenuPickArgs @('Some Menu', 'File', '--timeout', 'soon') } catch { $mp6Err2 = "$($_.Exception.Message)" }
  ST-Check 'unit (P-06): menu-pick --timeout goes through Read-FlagNumber (a non-number names the flag, no raw cast error)' (
    ($mp6Err2 -like '*--timeout*') -and ($mp6Err2 -like '*soon*'))
  $mp6Err3 = ''
  try { $null = Resolve-MenuPickArgs @('Some Menu', 'File', '--tolerence', '3') } catch { $mp6Err3 = "$($_.Exception.Message)" }
  ST-Check 'unit (P-06): an unknown --xxx in menu-pick is refused through the shared message, not fed to the positional words' (
    ($mp6Err3 -like '*--tolerence*') -and ($mp6Err3.Length -gt 0))
  # ---------- v3.1.0 (P-06): the same hole elsewhere - a family lint over the dispatcher ----------
  # Every hand-written `while ($i -lt $Rest.Count)` loop must refuse an unknown --xxx BEFORE the
  # else that pushes it into the positional words. find-color / assert-color / wait-stable did not
  # (measured: `--tolerence 30` was swallowed as a positional word and the command ran with the
  # default tolerance, exit 0). The loop COUNT is asserted too: a scan that sees nothing must fail.
  $hfLoops = 0; $hfBad = @()
  for ($hfi = 0; $hfi -lt $clCount; $hfi++) {
    if ("$($codeLines[$hfi])" -match 'while \(\$i -lt \$Rest\.Count\) \{') {
      $hfLoops++
      # The window is the loop itself, not a fixed line count: find-text refuses unknown flags
      # fourteen lines into its chain, so a 9-line lookahead reported an honest command as an
      # offender (measured). The loop's closing brace sits at six spaces in this file's style.
      $hfEnd = $hfi
      for ($hfj = $hfi + 1; $hfj -lt $clCount; $hfj++) {
        if ("$($codeLines[$hfj])" -match '^\s{6}\}\s*$') { $hfEnd = $hfj; break }
      }
      $hfWin = (@($codeLines[$hfi..$hfEnd]) -join "`n")
      if ($hfWin.Contains('[void]$words.Add($Rest[$i])') -and (-not $hfWin.Contains("-like '--*'"))) { $hfBad += ($hfi + 1) }
    }
  }
  ST-Check 'lint (P-06): no hand-written dispatcher flag loop swallows an unknown --xxx (loops-seen floor makes an empty scan fail)' (
    ($hfLoops -ge 3) -and (@($hfBad).Count -eq 0))
  Write-Output ('      flag loops: seen=' + $hfLoops + ' offenders=[' + (@($hfBad) -join ' ') + ']')
  # ---------- v3.1.0 (P-06): the chrome family's own promises ----------
  # v4.4.0 (A-15): this command's code may live in its handler now, so the promise is checked against
  # the command's code (case plus handler). The old scan read a pure move as a missing promise.
  $ccBody = Get-CommandCodeText $codeLines 'chrome-click'
  ST-Check 'lint (P-06): chrome-click carries the two things its comment now claims - a hit-window echo before the click and the audit line' (
    ($ccBody.Contains('Invoke-HitWindowCheck $cx $cy')) -and ($ccBody.Contains('Log-Action')) -and (-not $ccBody.Contains('applies verbatim')))
  # v4.4.0 (A-15): this command's code may live in its handler now, so the promise is checked against
  # the command's code (case plus handler). The old scan read a pure move as a missing promise.
  $crBody = Get-CommandCodeText $codeLines 'chrome-read'
  ST-Check 'lint (P-06): chrome-read refuses a missing selector instead of reading whichever tab is first (its siblings refuse)' (
    $crBody.Contains('usage: chrome-read <sel>'))
  # ---------- lint: v1.5.5 (A-4) a flag must be REACHABLE, not just parsed ----------
  # Why this exists (D-1): hover --dwell, drag --steps/--hold and find-click --index
  # were all documented in help AND parsed in their handler - but the parsing ran after
  # Split-Target had already refused the token, so every one of them was unreachable and
  # 297 green selftest checks never noticed. Documented-vs-reachable is a shape no unit
  # test of the parser can see, so the dispatcher source itself gets scanned here.
  $d1CaseStarts = @{}
  $d1FnStart = -1; $d1FnEnd = $codeLines.Count
  for ($i = 0; $i -lt $codeLines.Count; $i++) { if ($codeLines[$i] -match '^function Invoke-DesktopCommand') { $d1FnStart = $i; break } }
  if ($d1FnStart -ge 0) {
    for ($i = $d1FnStart + 1; $i -lt $codeLines.Count; $i++) { if ($codeLines[$i] -match '^function ') { $d1FnEnd = $i; break } }
    for ($i = $d1FnStart; $i -lt $d1FnEnd; $i++) {
      if ($codeLines[$i] -match ('^\s{4}' + "'" + '([a-z0-9-]+)' + "'" + ' \{$')) {
        $d1Name = "$($Matches[1])"
        if (-not $d1CaseStarts.ContainsKey($d1Name)) { $d1CaseStarts[$d1Name] = $i }
      }
    }
  }
  # a scan that finds nothing is a silent pass - pin the scan itself first.
  # .Count is used bare on purpose: in PS 5.1 @(hashtable) wraps the table into ONE array
  # element, so @($t).Count is always 1 and a scan that found nothing would look identical
  # to one that found everything. That exact shape made the first version of this lint
  # report "1 case" while its own >= 50 guard sat there red - the guard worked, the number
  # it printed did not. KEYS are enumerated through Get-HashKeys, never .Keys: a key named
  # 'keys' shadows the property (see Get-HashKeys), and this table is keyed by command names.
  ST-Check 'lint: dispatcher case scan sees the dispatcher (>= 50 cases inside Invoke-DesktopCommand)' ($d1CaseStarts.Count -ge 50)
  if ($d1CaseStarts.Count -lt 50) { Write-Output "      cases found: $($d1CaseStarts.Count)" }
  $d1Shared = @(Get-SharedFlagSet)
  $d1Dead = New-Object System.Collections.ArrayList
  $d1SplitSeen = 0
  foreach ($cmd in @(Get-HashKeys $d1CaseStarts)) {
    # v4.4.0 (A-15 pen 2): a named command's body now lives in its handler, so this scan walks every range
    #    the command owns. Reading only the case span would leave the lint green while it looked at a
    #    three-line stub - a hollow ruler, and this file already argues about that failure mode, so the
    #    walk is paired with a coverage count instead of trusted.
    $d1RgA = @(Get-CommandCodeRanges $codeLines $cmd)
    # A comment that mentions Split-Target is not a call to it - the first version of
    # this lint read hover's explanatory comment as the call site and reported
    # "strip comes after split" for all three commands. Comment lines are skipped.
    $splitAt = -1; $d1BodyEnd = -1
    foreach ($d1rA in $d1RgA) {
      for ($k = [int]$d1rA[0]; $k -lt [int]$d1rA[1]; $k++) {
        if ($codeLines[$k] -match '^\s*#') { continue }
        if ($codeLines[$k] -match 'Split-Target') { $splitAt = $k; $d1BodyEnd = [int]$d1rA[1]; break }
      }
      if ($splitAt -ge 0) { break }
    }
    if ($splitAt -lt 0) { continue }
    $d1SplitSeen = $d1SplitSeen + 1
    for ($k = $splitAt + 1; $k -lt $d1BodyEnd; $k++) {
      if ($codeLines[$k] -match '^\s*#') { continue }
      foreach ($mm in [regex]::Matches($codeLines[$k], '-(eq|like|in|contains)\s+''(--[a-z0-9-]+)''')) {
        $fl = $mm.Groups[2].Value
        if ($d1Shared -contains $fl) { continue }
        if (@((Get-OwnFlagSpec $cmd).Keys) -contains $fl) { continue }
        [void]$d1Dead.Add("$cmd : '$fl' compared at line $(Format-SourceLineRef ($k + 1)), after Split-Target already refused it")
      }
    }
  }
  ST-Check 'lint: no handler parses a flag its own Split-Target call has already refused (the D-1 shape)' (@($d1Dead).Count -eq 0)
  ST-Check 'lint (A-15c): the dead-flag scan is not hollow - it counted the command bodies that really do call Split-Target (a scan whose input emptied out at the wrap would report zero findings forever)' ($d1SplitSeen -ge 5)
  Write-Output ('      dead-flag scan: Split-Target bodies seen=' + $d1SplitSeen)
  foreach ($d in @($d1Dead)) { Write-Output "      unreachable flag: $d" }
  # the printed "valid here" list must be the parser, not a copy of it
  $d1St = -1
  for ($i = 0; $i -lt $codeLines.Count; $i++) { if ($codeLines[$i] -match '^function Split-Target') { $d1St = $i; break } }
  $d1Branches = New-Object System.Collections.ArrayList
  if ($d1St -ge 0) {
    for ($i = $d1St + 1; $i -lt $codeLines.Count; $i++) {
      if ($codeLines[$i] -match '^function ') { break }
      foreach ($mm in [regex]::Matches($codeLines[$i], '\$t\s+-eq\s+''(--[a-z0-9-]+)''')) { [void]$d1Branches.Add($mm.Groups[1].Value) }
    }
  }
  $d1Missing = @((@(Get-SharedFlagSet) | Where-Object { -not (@($d1Branches) -contains $_) }))
  $d1Extra = @((@($d1Branches) | Where-Object { -not ($d1Shared -contains $_) }) | Sort-Object -Unique)
  ST-Check 'lint: Get-SharedFlagSet is exactly Split-Target branch set (error text cannot lie)' (
    $d1St -ge 0 -and @($d1Missing).Count -eq 0 -and @($d1Extra).Count -eq 0 -and @($d1Branches).Count -ge 20)
  if (@($d1Missing).Count -gt 0) { Write-Output "      listed but not parsed: $(@($d1Missing) -join ' ')" }
  if (@($d1Extra).Count -gt 0) { Write-Output "      parsed but not listed: $(@($d1Extra) -join ' ')" }
  Write-Output "      flag scan: $($d1CaseStarts.Count) dispatcher cases, $(@($d1Branches).Count) shared flags, $((Get-OwnFlagTable).Count) commands with private flags"
  # every private flag must be stripped BEFORE its command's Split-Target call, its
  # parsed value must be READ by the handler, and it must be documented in that
  # command's help block - all three halves of "reachable". A flag that is stripped
  # into $own.Values and never used is the same dead end as one that was refused: the
  # table would say it works while the behaviour stayed frozen.
  $d1Src = $src -split "`r?`n"
  $d1OwnBad = New-Object System.Collections.ArrayList
  foreach ($cmd in @(Get-HashKeys (Get-OwnFlagTable))) {
    if (-not $d1CaseStarts.ContainsKey($cmd)) { [void]$d1OwnBad.Add("$cmd : in the flag table but has no dispatcher case"); continue }
    # v4.4.0 (A-15 pen 2): same reason - the strip/split sites are in the handler now, so the text walked
    #    is the command's own code wherever it lives, in file order (the ordering verdict needs that).
    $d1Lines = @((Get-CommandCodeText $codeLines $cmd) -split "`n")
    $stripAt = -1; $splitAt = -1
    $d1Block = ''
    for ($k = 0; $k -lt $d1Lines.Count; $k++) {
      if ($d1Lines[$k] -match '^\s*#') { continue }
      if ($stripAt -lt 0 -and $d1Lines[$k] -match 'Strip-OwnFlags') { $stripAt = $k }
      if ($splitAt -lt 0 -and $d1Lines[$k] -match 'Split-Target') { $splitAt = $k }
      $d1Block += $d1Lines[$k]
    }
    # v3.1.0 (P-06): a handler may delegate its own argument parse to a pure Resolve-*Args
    # function - menu-pick did exactly that so a trailing-flag hole could be tested offline.
    # FOLLOW the delegation instead of exempting it: the branch has to exist in the called
    # parser, and only functions named Resolve-*Args that the case body actually calls are
    # folded in, so no command can claim routing a flag it parses nowhere.
    foreach ($dm in @([regex]::Matches($d1Block, '(Resolve-[A-Za-z0-9]+Args)'))) {
      $d1Fn = $dm.Groups[1].Value
      $d1Fs = -1; $d1Fe = -1
      for ($dq = 0; $dq -lt $d1Src.Count; $dq++) {
        if ($d1Fs -lt 0) { if ($d1Src[$dq].StartsWith('function ' + $d1Fn)) { $d1Fs = $dq }; continue }
        if ($d1Src[$dq] -eq '}') { $d1Fe = $dq; break }
      }
      if ($d1Fs -ge 0 -and $d1Fe -gt ($d1Fs + 1)) { $d1Block += ("`n" + (@($d1Src[($d1Fs + 1)..($d1Fe - 1)]) -join "`n")) }
    }
    # v1.5.7 (J-06): the ordering rule only makes sense for a command that CALLS
    # Split-Target. menu-pick / type-in / unmap parse their own arguments and never reach it,
    # so requiring a Split-Target site there produced a false gap for three honest commands.
    if ($stripAt -lt 0) {
      [void]$d1OwnBad.Add("$cmd : is in the flag table but the handler never calls Strip-OwnFlags")
    } elseif ($splitAt -ge 0 -and $stripAt -gt $splitAt) {
      [void]$d1OwnBad.Add("$cmd : private flags are stripped AFTER Split-Target refused them (strip@$stripAt split@$splitAt)")
    }
    # its help block: from the synopsis line to the next synopsis line of ANY command
    $d1Hl = -1
    for ($k = 0; $k -lt $d1Src.Count; $k++) { if ($d1Src[$k] -match ('^\s{4}' + [regex]::Escape($cmd) + '\s')) { $d1Hl = $k; break } }
    if ($d1Hl -lt 0) { [void]$d1OwnBad.Add("$cmd : no help synopsis line found"); continue }
    $d1Doc = ''
    for ($k = $d1Hl; $k -lt $d1Src.Count; $k++) {
      if ($k -gt $d1Hl -and $d1Src[$k] -match '^\s{4}[a-z][a-z0-9-]*\s') { break }
      $d1Doc += $d1Src[$k]
    }
    $d1Spec = Get-OwnFlagSpec $cmd
    foreach ($fl in @(Get-HashKeys $d1Spec)) {
      # Contains, not -like: '[' is a WILDCARD character class in -like patterns,
      # so the first version of this check blew up on the pattern itself.
      if (-not $d1Doc.Contains('[' + $fl)) { [void]$d1OwnBad.Add("$cmd : '$fl' is stripped+parsed but not documented in its help block") }
      if (-not $d1Block.Contains("Values['" + $fl + "']")) { [void]$d1OwnBad.Add("$cmd : '$fl' is parsed but the handler never reads its value") }
      # J-06: a table flag must not ALSO be hand-compared in the same body - that is two
      # implementations of one flag, which is how "the table says it works" and "the code
      # says otherwise" can both be true at once.
      if ($d1Block.Contains("-eq '" + $fl + "'") -or $d1Block.Contains("-like '" + $fl + "'")) {
        [void]$d1OwnBad.Add("$cmd : '$fl' is table-driven AND hand-compared in the handler")
      }
    }
    # J-06: a command that parses its own arguments declares the shared flags it routes;
    # every one of them must have a real branch, or the declaration is a lie in the error text.
    if ($splitAt -lt 0) {
      foreach ($ds in @(Get-CommandSharedSet $cmd)) {
        if (-not $d1Block.Contains("-eq '" + $ds + "'")) { [void]$d1OwnBad.Add("$cmd : declares it routes '$ds' but nothing here parses it") }
      }
    }
  }
  ST-Check 'lint: every private flag is stripped before Split-Target, read by the handler and documented in help (D-1 anti-drift)' (@($d1OwnBad).Count -eq 0)
  foreach ($d in @($d1OwnBad)) { Write-Output "      flag-reachability gap: $d" }
  # positive controls: neither scan is vacuous
  $d1Plant = "      if (`$p.Words[`$i] -eq '--dwell') { x }"
  $d1PlantHit = $false
  foreach ($mm in [regex]::Matches($d1Plant, '-(eq|like|in|contains)\s+''(--[a-z0-9-]+)''')) { if ($mm.Groups[2].Value -ceq '--dwell') { $d1PlantHit = $true } }
  ST-Check 'lint: dead-flag pattern detects a planted D-1 violation' ($d1PlantHit)
  $d1BranchPlant = "    } elseif (`$t -eq '--demo') {"
  $d1BranchHit = $false
  foreach ($mm in [regex]::Matches($d1BranchPlant, '\$t\s+-eq\s+''(--[a-z0-9-]+)''')) { if ($mm.Groups[1].Value -ceq '--demo') { $d1BranchHit = $true } }
  ST-Check 'lint: branch-scan pattern detects a planted shared flag' ($d1BranchHit)

  # ---------- unit: v1.5.5 Strip-OwnFlags (the flags are now actually reachable) ----------
  $sfHover = Strip-OwnFlags @('10', '20', '--dwell', '1500', '--to', 'Win') 'hover'
  ST-Check 'unit: hover --dwell is stripped with its value and the rest still parses' (
    (@((Get-OptValue $sfHover 'Rest')) -join ' ') -ceq '10 20 --to Win' -and [int]$sfHover.Values['--dwell'] -eq 1500)
  $sfDrag = Strip-OwnFlags @('1', '2', '3', '4', '--steps', '30', '--hold', '50') 'drag'
  ST-Check 'unit: drag strips both of its flags and honours declared defaults' (
    (@((Get-OptValue $sfDrag 'Rest')) -join ' ') -ceq '1 2 3 4' -and [int]$sfDrag.Values['--steps'] -eq 30 -and [int]$sfDrag.Values['--hold'] -eq 50)
  $sfDef = Strip-OwnFlags @('1', '2', '3', '4') 'drag'
  ST-Check 'unit: an absent private flag reports its documented default, not null' (
    [int]$sfDef.Values['--steps'] -eq 14 -and [int]$sfDef.Values['--hold'] -eq 120)
  $sfE1 = ''
  try { [void](Strip-OwnFlags @('1', '2', '--dwell', '--to', 'Win') 'hover') } catch { $sfE1 = $_.Exception.Message }
  ST-Check 'unit: --dwell refuses to eat the next FLAG as its value (selector must not vanish)' (
    $sfE1 -like "*'--dwell' got the flag '--to' instead of its value*" -and $sfE1 -notlike '*needs a value*')
  $sfE2 = ''
  try { [void](Strip-OwnFlags @('1', '2', '--dwell', 'abc') 'hover') } catch { $sfE2 = $_.Exception.Message }
  ST-Check 'unit: --dwell rejects a non-numeric value by name' ($sfE2 -like "*'--dwell' needs a whole number, got: 'abc'*")
  $sfE3 = ''
  try { [void](Strip-OwnFlags @('1', '2', '--steps', '9999') 'drag') } catch { $sfE3 = $_.Exception.Message }
  ST-Check 'unit: --steps outside its declared range is refused with the range printed' (
    $sfE3 -like "*'--steps' must be 1..200, got: 9999*")
  $sfE4 = ''
  try { [void](Strip-OwnFlags @('1', '2', '--dwell') 'hover') } catch { $sfE4 = $_.Exception.Message }
  ST-Check 'unit: a private flag with nothing after it says what it needs' (
    $sfE4 -like "*'--dwell' needs a value*" -and $sfE4 -notlike '*valid here*')
  $sfE5 = ''
  try { [void](Strip-OwnFlags @('10', '20', '--index', '1') 'hover') } catch { $sfE5 = $_.Exception.Message }
  # --index belongs to find-click AND (since J-06) menu-pick: the message must name every
  # owner, in sorted order, so it cannot change between runs.
  ST-Check 'unit: another command private flag names every owner of it, not as a typo' (
    $sfE5.Contains("'--index' is a flag of find-click, menu-pick, not of this command") -and $sfE5.Contains('valid here:') -and $sfE5.Contains('--dwell'))
  # the D-5 wording: coordinate-only commands must not be sent hunting for a needle.
  # The test is on the ADVICE SENTENCE, not on the word --needle - --needle is a shared
  # flag that genuinely reaches hover's parser, so it must appear in its "valid here"
  # list. Asserting it away would make the message lie about its own parser.
  $uw1 = Get-UnknownFlagMessage 'hover' '--zz'
  $uw2 = Get-UnknownFlagMessage 'find-text' '--zz'
  $uw3 = Get-UnknownFlagMessage '' '--zz'
  ST-Check 'unit: unknown-flag text lists the real flag set and drops the needle advice for coordinate commands' (
    $uw1 -like "*for 'hover'*" -and $uw1 -like '*valid here:*--dwell*' -and $uw1 -notlike '*pass it as*' -and
    $uw2 -like '*pass it as --needle*' -and $uw2 -like "*for 'find-text'*")
  ST-Check 'unit: an unlabelled Split-Target call still offers the needle escape route (no regression)' (
    $uw3 -like '*unknown flag*' -and $uw3 -like '*pass it as --needle*')
  ST-Check 'unit: Test-CoordinateOnlyCommand is derived, not guessed (hover yes, relclick no, nothing no)' (
    (Test-CoordinateOnlyCommand 'hover') -eq $true -and (Test-CoordinateOnlyCommand 'drag') -eq $true -and
    (Test-CoordinateOnlyCommand 'relclick') -eq $false -and (Test-CoordinateOnlyCommand 'find-text') -eq $false -and
    (Test-CoordinateOnlyCommand '') -eq $false)
  # ---------- unit + lint: v4.2.0 feedback item 3 - the sibling-flag hint ----------
  # The three hand-written rect-family refusals live inside dispatcher cases that need a
  # screen to run, so the wiring itself is asserted as a source scan: all three, exactly
  # once each. The wording is asserted through the pure helper it is built from.
  # the needle is assembled so this very check line cannot match itself (a literal here
  # would count its own source as a fourth call site).
  $aliasCallNeedle = '$' + '(Get-RectFlagAliasHint'
  $aliasSites = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($aliasCallNeedle) })
  ST-Check 'lint: every hand-written rect-family unknown-flag refusal appends the sibling-flag hint (read-text, find-text, assert-text)' (
    (@($aliasSites).Count -eq 3) -and
    (@($aliasSites | Where-Object { $_.Contains('"read-text: unknown flag') }).Count -eq 1) -and
    (@($aliasSites | Where-Object { $_.Contains('"find-text: unknown flag') }).Count -eq 1) -and
    (@($aliasSites | Where-Object { $_.Contains('"assert-text: unknown flag') }).Count -eq 1))
  $aliasHint = Get-RectFlagAliasHint 'read-text' '--region'
  ST-Check 'unit: a sibling flag names its real owner AND the positional rectangle this command takes' (
    $aliasHint.Contains('POSITIONALLY as ''read-text <sel|x y w h>''') -and
    $aliasHint.Contains('''--region'' is the spelling used by ''find'''))
  ST-Check 'unit: an unknown flag that is not a known sibling alias adds no noise' (
    ((Get-RectFlagAliasHint 'read-text' '--json') -ceq '') -and
    ((Get-RectFlagAliasHint 'click' '--region') -ceq '') -and
    ((Get-UnknownFlagMessage 'find-text' '--region').Contains('POSITIONALLY as ''find-text <sel|x y w h> <needle...>''')))

  # ---------- unit: v1.5.7 (J-06) Bool flags, per-command shared routing ----------
  $sfDry = Strip-OwnFlags @('img.png', '10', '20', '--dry') 'imgclick'
  ST-Check 'unit: a Bool flag takes no value, defaults false and reports presence' (
    (@($sfDry.Rest) -join ' ') -ceq 'img.png 10 20' -and $sfDry.Values['--dry'] -eq $true -and
    $sfDry.Present['--dry'] -eq $true -and $sfDry.Present['--stale-ok'] -eq $false)
  $sfNone = Strip-OwnFlags @('img.png', '10', '20') 'imgclick'
  ST-Check 'unit: an absent Bool flag is false and Present says so (--dry vs --index 0 differ)' (
    $sfNone.Values['--dry'] -eq $false -and $sfNone.Present['--dry'] -eq $false -and @($sfNone.Rest).Count -eq 3)
  $sfMenu = Strip-OwnFlags @('Pop', 'OK', '--allow-window', '--index', '2') 'menu-pick'
  ST-Check 'unit: menu-pick strips its two flags before its own parser sees them' (
    (Get-OptValue $sfMenu 'Values')['--allow-window'] -eq $true -and [int](Get-OptValue $sfMenu 'Values')['--index'] -eq 2 -and
    ((@($sfMenu.Rest) -join ' ') -ceq 'Pop OK'))
  $sfMenuExpect = Strip-OwnFlags @('Pop', 'OK', '--expect', 'Saved') 'menu-pick'
  ST-Check 'unit: menu-pick lets through exactly the shared flags it declares' (
    (@($sfMenuExpect.Rest) -join ' ') -ceq 'Pop OK --expect Saved')
  $sfMenuTo = ''
  try { [void](Strip-OwnFlags @('Pop', 'OK', '--to', 'X') 'menu-pick') } catch { $sfMenuTo = $_.Exception.Message }
  ST-Check 'unit: menu-pick refuses --to (it never routed it) with the central wording' (
    $sfMenuTo.Contains("unknown flag '--to' for 'menu-pick'") -and $sfMenuTo.Contains('pass it as --needle <text>'))
  $sfUnmap = ''
  try { [void](Strip-OwnFlags @('a.png', '1', '2', '--dry') 'unmap') } catch { $sfUnmap = $_.Exception.Message }
  # --dry is imgclick's, so the refusal names the owner (unmap has no --dry of its own);
  # --allow-occluded belongs to nobody in unmap's world, so the generic wording + the
  # honest one-flag list is what a reader gets. Neither may offer --needle: unmap has none.
  ST-Check 'unit: unmap names the real owner of a flag it does not take' (
    $sfUnmap.Contains("'--dry' is a flag of imgclick, not of this command") -and $sfUnmap.Contains('valid here: --stale-ok') -and
    -not $sfUnmap.Contains('pass it as --needle'))
  $sfUnmap2 = ''
  try { [void](Strip-OwnFlags @('a.png', '1', '2', '--allow-occluded') 'unmap') } catch { $sfUnmap2 = $_.Exception.Message }
  ST-Check 'unit: unmap refuses an unknown flag with only what it really accepts' (
    $sfUnmap2.Contains("unknown flag '--allow-occluded' for 'unmap'") -and $sfUnmap2.Contains('valid here: --stale-ok') -and
    -not $sfUnmap2.Contains('--occlude '))
  $sfTi = Strip-OwnFlags @('--tab', '2', '100', '200', 'hello') 'type-in'
  ST-Check 'unit: type-in --tab works in any position now (it used to break x/y parsing)' (
    [int](Get-OptValue $sfTi 'Values')['--tab'] -eq 2 -and ((@($sfTi.Rest) -join ' ') -ceq '100 200 hello'))
  $sfTiBad = ''
  try { [void](Strip-OwnFlags @('100', '200', '--tab', '--verify') 'type-in') } catch { $sfTiBad = $_.Exception.Message }
  ST-Check 'unit: --tab refuses a FLAG as its value instead of typing a number away' ($sfTiBad.Contains("got the flag '--verify' instead of its value"))
  $sfTiRange = ''
  try { [void](Strip-OwnFlags @('100', '200', '--tab', '99', 'x') 'type-in') } catch { $sfTiRange = $_.Exception.Message }
  ST-Check 'unit: type-in --tab range comes from the table (0..20)' ($sfTiRange.Contains("'--tab' must be 0..20, got: 99"))
  ST-Check 'unit: every command in the shared map declares a subset of the shared set (and the map is non-empty: >= 4 keys, so an empty table cannot satisfy it by comparing nothing)' (
    $(
      $bad = @()
      # X-02: this used to wrap the map in @() and then index the WRAPPER by a command NAME.
      # Wrapping a hashtable in @() yields ONE hashtable element (not its entries), so that
      # index silently answered $null and the inner loop ran zero times - the check compared
      # nothing and could never have gone red. Index the dictionary itself, like the
      # production getter for the same table does.
      $csMap = Get-CommandSharedMap
      foreach ($k in @(Get-HashKeys $csMap)) {
        foreach ($f in (Get-OptValue $csMap $k)) { if (-not (@(Get-SharedFlagSet) -contains $f)) { $bad += "$k=$f" } }
      }
      # v4.0.1 (audit observation 6): the green condition is "nothing bad found", which an empty
      # table satisfies for free - the exact shape that made this check vacuous before X-02
      # batch 4 fixed the indexing. The floor is what makes "it compared something" part of the
      # assertion. EXPECTATION ADDED, not relaxed: 4 is the measured key count, and a legitimate
      # shrink below it has to be stated here rather than silently passing.
      (@($bad).Count -eq 0) -and (@(Get-HashKeys $csMap).Count -ge 4)
    ))
  # the flag-reachability lint must now cover the migrated commands, not just three
  ST-Check 'unit: the private-flag table covers 13 commands (J-06 migrated four, v1.6.0 adds open-and-pick, v2.0.0 adds wheel modifiers, v2.0.1 adds the press trio, v2.1.0 adds find, v3.0.0 adds dialog-cancel; EXPECTATION RAISED 12->13, and the two lints either side still refuse an entry that is unused or a flag that is undeclared)' (
    @(Get-HashKeys (Get-OwnFlagTable)).Count -eq 13)

  # the escape route must survive the strip: everything after a value-taking flag is DATA.
  # J-06's central unknown-flag refusal nearly ate `--needle <--payload>` and only a --live
  # round (type-in --verify-timeout ladder) noticed, so this shape is now pinned offline too.
  $sfNd = ''
  $sfNdRest = ''
  try { $sfNd = Strip-OwnFlags @('10', '20', '--needle', '--DTXVT', '--verify') 'type-in'; $sfNdRest = (@($sfNd.Rest) -join ' ') } catch { $sfNdRest = 'THREW: ' + $_.Exception.Message }
  ST-Check 'unit: a --needle payload starting with -- passes the strip untouched' (
    $sfNdRest -ceq '10 20 --needle --DTXVT --verify' -and [int]$sfNd.Values['--tab'] -eq 0)
  $sfNd2Rest = ''
  try { $x2 = Strip-OwnFlags @('Win', '--needle', '--fit', '--index', '1') 'find-click'; $sfNd2Rest = (@($x2.Rest) -join ' ') + '|' + [int]$x2.Values['--index'] } catch { $sfNd2Rest = 'THREW: ' + $_.Exception.Message }
  ST-Check 'unit: find-click keeps --needle <--literal> while stripping its own --index' (
    $sfNd2Rest -ceq 'Win --needle --fit|1')
  $sfNd3Rest = ''
  try { $x3 = Strip-OwnFlags @('Pop', '--needle', '--x', '--expect', '--y') 'menu-pick'; $sfNd3Rest = (@($x3.Rest) -join ' ') } catch { $sfNd3Rest = 'THREW: ' + $_.Exception.Message }
  ST-Check 'unit: menu-pick passes two value flags whose data begins with --' ($sfNd3Rest -ceq 'Pop --needle --x --expect --y')
  $sfVsBad = @(@(Get-SharedValueFlagSet) | Where-Object { -not (@(Get-SharedFlagSet) -contains $_) })
  ST-Check 'unit: every value-taking shared flag is in the shared set (no typo in the route table)' (
    @($sfVsBad).Count -eq 0 -and @(Get-SharedValueFlagSet).Count -ge 10)
  if (@($sfVsBad).Count -gt 0) { Write-Output ("      value flag not shared: " + (@($sfVsBad) -join ' ')) }

  # ---------- unit: v1.5.7 (D-6) the auto-grid decision is explicit, and travels ----------
  $gFit = Parse-CaptureFlags @('--fit', '1400')
  ST-Check 'unit: --fit is recorded as a USER choice (the auto-grid rule depends on it)' (
    $gFit.Fit -eq 1400 -and $gFit.FitUser -eq $true -and $gFit.GridUser -eq $false -and $gFit.Grid -le 0)
  $gPlain = Parse-CaptureFlags @('something')
  ST-Check 'unit: a capture nobody fitted has no grid claim (default behaviour unchanged)' (
    $gPlain.FitUser -eq $false -and $gPlain.GridUser -eq $false)
  $gNoGrid = Parse-CaptureFlags @('--fit', '1400', '--no-grid')
  ST-Check 'unit: --no-grid overrides the auto grid and says it was the user speaking' (
    $gNoGrid.GridUser -eq $true -and $gNoGrid.Grid -le 0)
  $gExplicit = Parse-CaptureFlags @('--grid', '25')
  ST-Check 'unit: an explicit --grid step still wins over any default' (
    $gExplicit.Grid -eq 25 -and $gExplicit.GridUser -eq $true)
  $gSide = Join-Path $env:TEMP ('dtx-grid-sidecar-' + [guid]::NewGuid().ToString('N') + '.png')
  Write-MapSidecar $gSide 10 20 0.5 100 80 'rect' $null 50
  $gBack = Read-MapSidecar $gSide
  $gSide2 = Join-Path $env:TEMP ('dtx-grid-sidecar-' + [guid]::NewGuid().ToString('N') + '.png')
  Write-MapSidecar $gSide2 10 20 1.0 100 80 'rect'
  $gBack2 = Read-MapSidecar $gSide2
  Remove-Item -LiteralPath @(($gSide + '.map.txt'), ($gSide2 + '.map.txt')) -Force -ErrorAction SilentlyContinue
  ST-Check 'unit: a grid step round-trips through the sidecar, and its absence reads as 0' (
    $gBack.Grid -eq 50 -and $gBack2.Grid -eq 0)
  # the bitmap is the only thing imgclick reads, so every capture that can auto-grid must
  # hand Save-RectEx the user's flag context - a missed call site would silently disable
  # the rule for that one command (the v1.5.3 / v1.5.6 "only lives in the signature" family)
  # Internal captures (script steps) pass literal "0 -1 @()" - they have no user flags to
  # forward, so the rule is stated over the call sites that DO read the parsed flags:
  # any Save-RectEx that consumes $pf.X must also hand over $pf itself.
  $gForw = New-Object System.Collections.ArrayList
  for ($gi = 0; $gi -lt $codeLines.Count; $gi++) {
    $gl = $codeLines[$gi]
    if ($gl -match '^\s*#') { continue }
    if ($gl -notmatch 'Save-RectEx .* \$pf\.') { continue }
    if ($gl -notmatch '\$pf\s*\|\s*Write-Output') { [void]$gForw.Add("$($gi + 1): $($gl.Trim())") }
  }
  ST-Check 'lint: every capture call site forwards the flag context (no command quietly loses the auto grid)' (@($gForw).Count -eq 0)
  foreach ($gf in @($gForw)) { Write-Output "      Save-RectEx call without the cf argument: $gf" }

  # ---------- contract: v1.5.5 (D-4) no miss message writes its own tail ----------
  # Why this is a LINT and not just a live case: the live check that the tails match
  # only runs with --live, so the fast gate sat green while one call site quietly went
  # back to hand-written wording (measured: bypassing find-click's call site left the
  # offline run at full green before this lint existed). Rule derived, not enumerated -
  # any refusal that reports a missing needle must get its OCR evidence from the one
  # formatter. find-color is correctly excluded: it searches pixels, so it has no OCR
  # lines to report.
  # The mark is ASSEMBLED rather than written as one literal: a line that contains the
  # mark text would be counted by this very scan (it reads the whole file, selftest
  # included) and reported as a bypass - which is exactly how the first version of this
  # block failed on its own definition.
  $d4Mark = "'" + '$needle' + "' not found"
  $d4Sites = 0
  $d4NoTail = New-Object System.Collections.ArrayList
  for ($d4i = 0; $d4i -lt $codeLines.Count; $d4i++) {
    if ($codeLines[$d4i] -match '^\s*#') { continue }
    if ($codeLines[$d4i].Contains($d4Mark)) {
      $d4Sites++
      if (-not $codeLines[$d4i].Contains('Format-OcrSampleTail')) { [void]$d4NoTail.Add($d4i + 1) }
    }
  }
  ST-Check 'contract: every needle-miss refusal reports its OCR evidence through Format-OcrSampleTail (>= 5 sites)' (
    $d4Sites -ge 5 -and @($d4NoTail).Count -eq 0)
  foreach ($d4n in @($d4NoTail)) { Write-Output "      miss message bypasses the tail formatter: line $d4n" }
  $d4Plant = '        throw "x: ' + $d4Mark + ' in region; 3 lines"'
  ST-Check 'contract: the tail-bypass scan detects a planted hand-written miss message' (
    $d4Plant.Contains($d4Mark) -and -not $d4Plant.Contains('Format-OcrSampleTail'))

  # ---------- contract: v1.5.7 (owner supplement 3 + J-06) truncation must self-report ----------
  # "total N / shown M / hidden N-M" is the generalised R-25 lesson: every list this tool
  # cuts must say it cut something. Checked by scanning production code for
  # Select-Object -First and requiring a hidden-count token within the same statement
  # (the line plus the two around it). Sites that CHOOSE rather than display (picking the
  # largest window, taking the first hit for a report field) carry the marker
  # "selection-not-display" - the lint cannot read intent, so the code has to say it.
  $t0 = $codeLines.Count
  # A-14i: this used to be a SECOND copy of the window judgement - it hunted '^function Invoke-SelfTest'
  # and stopped at the next '^function '. One copy is stale by construction once a body moves into its
  # own file (measured: this very lift reddened this lint, because the span no longer covered the family
  # it lived in). There is now exactly one window in this section - the AST span the orchestrator
  # publishes through $Ctx - and lint (A-14f) is what keeps that span honest.
  $tSelfStart = $j5ProdStart
  $tSelfEnd = $j5ProdEnd
  $tSilent = New-Object System.Collections.ArrayList
  $tSeen = 0
  for ($ti = 0; $ti -lt $t0; $ti++) {
    if ($ti -ge $tSelfStart -and $ti -lt $tSelfEnd) { continue }
    if ($codeLines[$ti] -match '^\s*#') { continue }
    if ($codeLines[$ti] -notmatch 'Select-Object -First') { continue }
    $tSeen++
    if ($codeLines[$ti].Contains('selection-not-display')) { continue }
    $tNear = ''
    # +/-4 lines: the "we hid some" statement has to be part of the same statement, and a
    # multi-line pipeline legitimately says it on the reporting line rather than the cut.
    for ($tj = [Math]::Max(0, $ti - 4); $tj -le [Math]::Min($t0 - 1, $ti + 4); $tj++) { $tNear += $codeLines[$tj] }
    if ($tNear -match 'more|hidden|cut|not shown|\+K|of \$\(') { continue }
    [void]$tSilent.Add("line $(Format-SourceLineRef ($ti + 1)): $($codeLines[$ti].Trim())")
  }
  ST-Check 'contract: no user-visible list is truncated silently (>= 6 truncation sites scanned)' (
    $tSeen -ge 6 -and @($tSilent).Count -eq 0)
  foreach ($tS in @($tSilent)) { Write-Output "      silent truncation: $tS" }
  Write-Output "      truncation scan: $tSeen site(s) outside selftest, $(@($tSilent).Count) silent"
  $tPlant = '  $x = @($rows | Select-Object -First 4); foreach ($r in $x) { Write-Output $r.Text }'
  ST-Check 'contract: the truncation scan catches a planted silent cut' (
    $tPlant -match 'Select-Object -First' -and $tPlant -notmatch 'more|hidden|cut|not shown|\+K|of \$\(' -and
    -not $tPlant.Contains('selection-not-display'))

  # ---------- unit: v1.5.7 (supplement 3) a miss carries every premise on one line ----------
  $pmLines = @('alpha', 'beta', 'gamma', 'delta', 'epsilon') | ForEach-Object { [pscustomobject]@{ Text = $_ } }
  $pmCtx = @{ Rect = '(10,20) 300x200'; Retry = 'also retried at 2x'; Occlusion = '12% scan=read occluded=12%'; Needle = 'QXW' }
  $pmOut = Format-OcrSampleTail $pmLines 2 $pmCtx
  ST-Check 'unit: a miss line carries rect / scan / occlusion / fold-pass / shown-of-total on the SAME line' (
    $pmOut.Contains('premises:') -and $pmOut.Contains('rect=(10,20) 300x200') -and $pmOut.Contains('scan=also retried at 2x') -and
    $pmOut.Contains('occluded=12%') -and $pmOut.Contains('fold-pass=ran(identical)') -and $pmOut.Contains('shown=2 of 5') -and
    $pmOut.Contains('(+3 more lines not shown)'))
  ST-Check 'unit: the premises fit on one line (a fragment must not be readable as the whole fact)' (
    @($pmOut -split "`r?`n").Count -eq 1)
  $pmFold = Format-OcrSampleTail $pmLines 8 @{ Needle = 'I0l1O' }
  ST-Check 'unit: fold-pass prints the folded needle actually searched on the second pass' ($pmFold.Contains('fold-pass=ran(lollo)'))
  $pmBare = Format-OcrSampleTail $pmLines 8
  ST-Check 'unit: without a context the tail is unchanged (v1.5.5 callers must not shift)' (
    -not $pmBare.Contains('premises:') -and $pmBare.Contains('OCR read 5 line(s) total:'))

  # ---------- unit: v1.5.2 WP-3 menu-pick target predicate (audit R-04) ----------
  # The old rule was "has the WS_POPUP style bit". On this machine the desktop,
  # the Settings shell, Weixin and several app shells carry that bit, so the
  # documented refusal of "non-popup targets" protected nothing. Synthetic windows
  # only - pure geometry, no desktop touched.
  $sW = 3840; $sH = 2160
  $mwProgman = [pscustomobject]@{ Class = 'Progman'; W = 3840; H = 2160; Title = 'Program Manager' }
  $mwWorkerW = [pscustomobject]@{ Class = 'WorkerW'; W = 800; H = 600; Title = '' }
  $mwWin32 = [pscustomobject]@{ Class = '#32768'; W = 345; H = 435; Title = '' }
  $mwForms = [pscustomobject]@{ Class = 'WindowsForms10.Window.8.app'; W = 345; H = 435; Title = 'ctx' }
  $mwApp = [pscustomobject]@{ Class = 'Chrome_WidgetWin_1'; W = 2500; H = 1500; Title = 'app' }
  $mwOverlay = [pscustomobject]@{ Class = 'CEF-OSC-WIDGET'; W = 3839; H = 2160; Title = 'NVIDIA GeForce Overlay' }
  $vProgman = Test-MenuWindow $mwProgman $sW $sH
  ST-Check 'unit: menu rule refuses the desktop by class, not by size' (
    $vProgman.Menu -eq $false -and $vProgman.Reason -like '*shell surface*')
  $vWorkerW = Test-MenuWindow $mwWorkerW $sW $sH
  ST-Check 'unit: menu rule refuses a small WorkerW (explicit shell exclusion beats the area rule)' (
    $vWorkerW.Menu -eq $false -and $vWorkerW.Reason -like '*shell surface*')
  $v32768 = Test-MenuWindow $mwWin32 $sW $sH
  ST-Check 'unit: menu rule accepts class #32768' ($v32768.Menu -eq $true -and $v32768.Reason -like '*#32768*')
  $vForms = Test-MenuWindow $mwForms $sW $sH
  ST-Check 'unit: menu rule accepts a transient popup shape' ($vForms.Menu -eq $true -and $vForms.Reason -like '*popup shape*')
  $vApp = Test-MenuWindow $mwApp $sW $sH
  ST-Check 'unit: menu rule refuses a large app window (would click anything)' ($vApp.Menu -eq $false)
  $vOver = Test-MenuWindow $mwOverlay $sW $sH
  ST-Check 'unit: menu rule refuses a full-screen overlay' ($vOver.Menu -eq $false -and $vOver.Reason -like '*spans the screen*')
  ST-Check 'unit: menu rule refuses a null window' ((Test-MenuWindow $null $sW $sH).Menu -eq $false)
  ST-Check 'unit: menu rule with no screen size accepts #32768 by class and refuses shape matches' (
    (Test-MenuWindow $mwWin32 0 0).Menu -eq $true -and (Test-MenuWindow $mwApp 0 0).Menu -eq $false)
  Write-Output "      menu rule: progman=$($vProgman.Reason) / 32768=$($v32768.Reason) / app=$($vApp.Reason)"

  # ---------- lint: v1.7.0 J-07 A - the six "do not lose" contracts, named and pinned ----------
  # Owner ruling: the six things that saved the Steam session must never be lost to a
  # refactor. #5 (occlusion scan=/rect= labels) and #6 (--json key sets) are already
  # pinned by named checks elsewhere; here their TITLES are re-found by traversal so a
  # silent rename/deletion of those checks itself goes red. #1/#3/#4 get new source lints.
  # #2 (win-close -> wins no longer lists the pid) is behavioural and lives in the --live
  # section against the spawned probe window.
  $j7Img = @()
  $j7Mark = '"imgclick:' + ' $img'
  for ($j7i = 0; $j7i -lt $codeLines.Count; $j7i++) {
    if ($j7i -ge $j5ProdStart -and $j7i -lt $j5ProdEnd) { continue }
    if ($codeLines[$j7i] -match '^\s*#') { continue }
    if ($codeLines[$j7i].Contains($j7Mark)) { $j7Img += $codeLines[$j7i] }
  }
  $j7MapForm = @()
  $j7FMark = '$mapForm = $(if ($map.Scale' + ' -eq 1)'
  for ($j7i = 0; $j7i -lt $codeLines.Count; $j7i++) {
    if ($j7i -ge $j5ProdStart -and $j7i -lt $j5ProdEnd) { continue }
    if ($codeLines[$j7i] -match '^\s*#') { continue }
    if ($codeLines[$j7i].Contains($j7FMark)) { $j7MapForm += $codeLines[$j7i] }
  }
  ST-Check 'lint: J-07 #1 imgclick echo carries the sidecar name and the scale-aware screen = image formula (exactly 1 each)' (
    (@($j7Img).Count -eq 1) -and $j7Img[0].Contains('[map: ') -and
    (@($j7MapForm).Count -eq 1) -and $j7MapForm[0].Contains('screen = image + (') -and $j7MapForm[0].Contains('screen = image / '))
  $j7Keys = @()
  $j7KMark = '"sent keys' + ' '
  for ($j7i = 0; $j7i -lt $codeLines.Count; $j7i++) {
    if ($j7i -ge $j5ProdStart -and $j7i -lt $j5ProdEnd) { continue }
    if ($codeLines[$j7i] -match '^\s*#') { continue }
    if ($codeLines[$j7i].Contains($j7KMark)) { $j7Keys += $codeLines[$j7i] }
  }
  ST-Check 'lint: J-07 #3 keys --to echo self-verifies the landing with foreground after send (exactly 1 echo line)' (
    @($j7Keys).Count -eq 1 -and $j7Keys[0].Contains('foreground after send'))
  $j7Hit = @()
  $j7HMark = '"hit: text=' + "'"
  for ($j7i = 0; $j7i -lt $codeLines.Count; $j7i++) {
    if ($j7i -ge $j5ProdStart -and $j7i -lt $j5ProdEnd) { continue }
    if ($codeLines[$j7i] -match '^\s*#') { continue }
    if ($codeLines[$j7i].Contains($j7HMark)) { $j7Hit += $codeLines[$j7i] }
  }
  ST-Check 'lint: J-07 #4 find-text hit echo exposes the ready-made centre= click point (exactly 1 echo line)' (
    @($j7Hit).Count -eq 1 -and $j7Hit[0].Contains('centre=('))
  # #5/#6 by traversal: the pinning check titles must still exist (renaming or deleting
  # them is exactly the "checklist lost a file" drift this ruling exists to stop).
  $j7Titles = New-Object System.Collections.ArrayList
  for ($j7i = $j5ProdStart; $j7i -lt $j5ProdEnd; $j7i++) {
    if ($codeLines[$j7i] -match "ST-Check '([^']+)'") { [void]$j7Titles.Add($Matches[1]) }
  }
  ST-Check 'lint: J-07 #5 the occlusion scan/rect labelling contract check still exists (found by traversal, exactly 1)' (
    @(@($j7Titles) | Where-Object { $_.Contains('scan+rect') }).Count -eq 1)
  ST-Check 'lint: J-07 #6 the --json top-level key-set contract checks still exist (found by traversal, exactly 2)' (
    @(@($j7Titles) | Where-Object { $_.Contains('--json top-level keys are exactly') }).Count -eq 2)


  # ---------- v4.4.0 (A-15): the case shape is judged from the AST, and a shape break names the case ----------
  # Design gate 12, landed BEFORE any case body moves. Measured on this tree (a15-probe.ps1): the
  # dispatcher holds ONE switch with 79 clauses; 76 of them begin on a line the strict 76-case regex
  # sees; the other 3 are single-line cases and they are exactly selftest / script / replay; 0 clauses
  # begin on a line that is neither. The unscoped file-wide count of the same regex is 90 - 14 more
  # lines live in OTHER switches - which is why this gate (and the three older scans) must be scoped
  # to the dispatcher, and why the difference is asserted rather than a number being trusted.
  $a15Gap = Get-CaseShapeGap $j5SelfParsed $srcLines 'Invoke-DesktopCommand' @('selftest', 'script', 'replay') 76 79
  $a15Unscoped = 0
  foreach ($a15l in $srcLines) { if ([regex]::IsMatch([string]$a15l, '^    ''[a-z0-9-]+'' \{$')) { $a15Unscoped = $a15Unscoped + 1 } }
  ST-Check 'lint (A-15): every case the switch really has begins on a line the case scans can see (AST clauses = strict-shape cases + the three registered single-line cases), the three existing counts agree on 76 and 79, and the unscoped count is larger, so the scope is what is being measured' (
    ($a15Gap -ceq '') -and ($d1CaseStarts.Count -eq 76) -and ($hCaseStarts.Count -eq 76) -and
    ($gaCasesCount -eq 79) -and ($a15Unscoped -gt 76))
  Write-Output ('      A-15 case shape: gap=[' + $a15Gap + '] flag-scan=' + $d1CaseStarts.Count + ' help-index=' + $hCaseStarts.Count +
    ' f-00-a=' + $gaCasesCount + ' unscoped-file-wide=' + $a15Unscoped)
  # the teeth: every note this predicate can emit is planted, on text - not on the tree. The clean
  # fixture must be empty AND every breach must say which case, because "some count got smaller" is not
  # a finding a reader can act on.
  $a15Cases = @('function Invoke-DesktopCommand([string]$Cmd, [string[]]$Rest) {',
    '  switch ($Cmd) {',
    '    ''click'' {',
    '      Move-Mouse 1 2',
    '    }',
    '    ''grid'' {',
    '      Usage',
    '    }',
    '    ''selftest'' { Invoke-SelfTest $Rest }',
    '  }',
    '}')
  $a15F = 'Invoke-DesktopCommand'
  $a15Parsed = Parse-SourceForInventory ($a15Cases -join "`n")
  $a15Clean = Get-CaseShapeGap $a15Parsed $a15Cases $a15F @('selftest') 2 3
  # a brace that moved to the next line: measured on both engines, the switch STILL has the clause
  # (labels click@3, grid@6, selftest@10) while the strict regex now sees one line fewer - the exact
  # silent disappearance the design warned about for A-15, and the reason the AST is the authority here.
  $a15Odd = @($a15Cases[0..4]) + @('    ''grid''', '    {', '      Usage', '    }') + @($a15Cases[8..10])
  # a fourth single-line case that nobody registered as an exception
  $a15Extra = @($a15Cases[0..4]) + @('    ''grid'' { Usage }') + @($a15Cases[8..10])
  # a registered exception that changed shape (selftest written across three lines)
  $a15Regained = @($a15Cases[0..7]) + @('    ''selftest'' {', '      Invoke-SelfTest $Rest', '    }') + @($a15Cases[9..10])
  # a body with no switch at all, a name with no body, a null parse, an empty line set, and a text that
  # does not parse: every one of them must REFUSE with a named reason, never answer "no gap"
  $a15NoSwitch = @('function Invoke-DesktopCommand([string]$Cmd) {', '  Usage', '}')
  $a15Broken = @('function Invoke-DesktopCommand([string]$Cmd) {', '  switch ($Cmd) {', '    ''x'' {')
  $a15OddParsed = Parse-SourceForInventory ($a15Odd -join "`n")
  $a15ExtraParsed = Parse-SourceForInventory ($a15Extra -join "`n")
  $a15RegParsed = Parse-SourceForInventory ($a15Regained -join "`n")
  $a15NoSwitchParsed = Parse-SourceForInventory ($a15NoSwitch -join "`n")
  $a15BrokenParsed = Parse-SourceForInventory ($a15Broken -join "`n")
  $a15OddGap = Get-CaseShapeGap $a15OddParsed $a15Odd $a15F @('selftest') 2 3
  $a15ExtraGap = Get-CaseShapeGap $a15ExtraParsed $a15Extra $a15F @('selftest') 2 3
  $a15Regap = Get-CaseShapeGap $a15RegParsed $a15Regained $a15F @('selftest') 2 3
  $a15NoSwitchGap = Get-CaseShapeGap $a15NoSwitchParsed $a15NoSwitch $a15F @('selftest') 0 0
  $a15AbsentGap = Get-CaseShapeGap $a15Parsed $a15Cases 'Invoke-Nope' @('selftest') 2 3
  $a15NullGap = Get-CaseShapeGap $null $a15Cases $a15F @('selftest') 2 3
  $a15EmptyGap = Get-CaseShapeGap $a15Parsed @() $a15F @('selftest') 2 3
  $a15BrokenGap = Get-CaseShapeGap $a15BrokenParsed $a15Broken $a15F @('selftest') 0 0
  ST-Check 'unit (A-15): the case-shape predicate passes the clean fixture and names a moved brace, an unregistered single-line case, a registered exception that changed shape and a body with no switch, and refuses an absent body, a null parse, an empty line set and a text that does not parse' (
    ($a15Clean -ceq '') -and ($a15OddGap -ceq 'odd-shape=grid@6,strict-count=1-want=2') -and
    ($a15ExtraGap -ceq 'inline-not-allowed=grid,strict-count=1-want=2') -and
    ($a15Regap -ceq 'allowed-not-inline=selftest,strict-count=3-want=2') -and
    ($a15NoSwitchGap -ceq 'switch-count=0') -and ($a15AbsentGap -ceq '-absent-body:Invoke-Nope') -and
    ($a15NullGap -ceq '-no-parse') -and ($a15EmptyGap -ceq '-no-lines') -and ($a15BrokenGap -like '-parse-errors=*'))
  Write-Output ('      A-15 fixtures: clean=[' + $a15Clean + '] odd=[' + $a15OddGap + '] extra-inline=[' + $a15ExtraGap +
    '] regained=[' + $a15Regap + '] no-switch=[' + $a15NoSwitchGap + '] absent=[' + $a15AbsentGap +
    '] null=[' + $a15NullGap + '] empty=[' + $a15EmptyGap + '] broken=[' + $a15BrokenGap + ']')

  # ---------- v4.4.0 (A-15b): the named-stub conversion is machine-checked, one case at a time ----------
  # The conversion is 79 clauses turned into handler calls, and a card lowers the unwrapped count. That is
  # exactly the shape of work where a case can be lost in silence (a body copied wrong, a stub pointed at
  # another command's handler, a flag protocol half applied), so the predicate runs over the real parse
  # and every clause must answer with one of the four legal shapes. The registered numbers below are what
  # this card moves; the same commit that wraps a case lowers the count and raises the flag list.
  $a15bGap = Get-HandlerStubGap $j5SelfParsed $script:StHandlerInlineCases $script:StHandlerFlagCases ([int]$script:StHandlerUnwrapped)
  $a15bHandlers = 0
  foreach ($a15bf in @($j5SelfParsed.Root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (([string]$a15bf.Name).StartsWith('Invoke-Handler-')) { $a15bHandlers = $a15bHandlers + 1 }
  }
  ST-Check 'lint (A-15b): every dispatcher case is an allowed inline case, a plain handler stub, a flag stub or a registered unwrapped body; each stub names its own handler and passes the literal command name and $Rest; the [ref] protocol is complete on both sides; and the unwrapped count equals the registered number' (
    ($a15bGap -ceq '') -and (@($script:StHandlerInlineCases).Count -eq 3) -and (@($script:StHandlerFlagCases).Count -eq 4))
  Write-Output ('      A-15b stubs: gap=[' + $a15bGap + '] handlers=' + $a15bHandlers + ' inline=' + @($script:StHandlerInlineCases).Count +
    ' flag=' + @($script:StHandlerFlagCases).Count + ' unwrapped-want=' + [int]$script:StHandlerUnwrapped)
  # every note the predicate can emit, planted on text. The expectations are literal strings because a
  # reading that merely "is not empty" would pass on any bug - and this is the gate that watches 79 moves.
  $a15bGood = @'
  function Invoke-Handler-shot([string]$Cmd, [string[]]$Rest) {
    Write-Output 'shot ran'
  }
  function Invoke-Handler-uia-click([string]$Cmd, [string[]]$Rest, [ref]$SkipTail) {
    if ($Rest.Count -ge 2) { Invoke-UiaClickByPath $Rest; $SkipTail.Value = $true; return }
    Write-Output 'normal end'
  }
  function Invoke-DesktopCommand([string]$Cmd, [string[]]$Rest) {
    switch ($Cmd) {
      'shot' {
        Invoke-Handler-shot 'shot' $Rest
      }
      'uia-click' {
        $a15SkipTail = $false
        Invoke-Handler-uia-click 'uia-click' $Rest ([ref]$a15SkipTail)
        if ($a15SkipTail) { return }
      }
      'selftest' { Invoke-SelfTest $Rest }
      'legacy' {
        $a = 1
        Write-Output $a
      }
    }
    Trim-After
  }
'@
  $a15bWrongName = @'
  function Invoke-Handler-shot([string]$Cmd, [string[]]$Rest) { Write-Output 1 }
  function Invoke-DesktopCommand([string]$Cmd, [string[]]$Rest) {
    switch ($Cmd) {
      'shot' {
        Invoke-Handler-other 'shot' $Rest
      }
    }
  }
'@
  $a15bWrongCmd = @'
  function Invoke-Handler-shot([string]$Cmd, [string[]]$Rest) { Write-Output 1 }
  function Invoke-DesktopCommand([string]$Cmd, [string[]]$Rest) {
    switch ($Cmd) {
      'shot' {
        Invoke-Handler-shot 'shotx' $Rest
      }
    }
  }
'@
  $a15bWrongRest = @'
  function Invoke-Handler-shot([string]$Cmd, [string[]]$Rest) { Write-Output 1 }
  function Invoke-DesktopCommand([string]$Cmd, [string[]]$Rest) {
    switch ($Cmd) {
      'shot' {
        Invoke-Handler-shot 'shot' $Cmd
      }
    }
  }
'@
  $a15bInline = @'
  function Invoke-DesktopCommand([string]$Cmd, [string[]]$Rest) {
    switch ($Cmd) {
      'selftest' { Invoke-SelfTest $Rest }
      'help' { Usage }
    }
  }
'@
  $a15bOrphan = @'
  function Invoke-Handler-orphaned([string]$Cmd, [string[]]$Rest) { Write-Output 1 }
  function Invoke-DesktopCommand([string]$Cmd, [string[]]$Rest) {
    switch ($Cmd) {
      'selftest' { Invoke-SelfTest $Rest }
    }
  }
'@
  $a15bNoMark = @'
  function Invoke-Handler-markme([string]$Cmd, [string[]]$Rest, [ref]$SkipTail) {
    if ($Rest.Count -ge 2) { Invoke-Something $Rest; return }
  }
  function Invoke-DesktopCommand([string]$Cmd, [string[]]$Rest) {
    switch ($Cmd) {
      'markme' {
        $a15SkipTail = $false
        Invoke-Handler-markme 'markme' $Rest ([ref]$a15SkipTail)
        if ($a15SkipTail) { return }
      }
    }
  }
'@
  $a15bEscape = @'
  function Invoke-Handler-escapeme([string]$Cmd, [string[]]$Rest, [ref]$SkipTail) {
    Write-Output $SkipTail
    $SkipTail.Value = $true
    return
  }
  function Invoke-DesktopCommand([string]$Cmd, [string[]]$Rest) {
    switch ($Cmd) {
      'escapeme' {
        $a15SkipTail = $false
        Invoke-Handler-escapeme 'escapeme' $Rest ([ref]$a15SkipTail)
        if ($a15SkipTail) { return }
      }
    }
  }
'@
  $a15bNoRef = @'
  function Invoke-Handler-noref([string]$Cmd, [string[]]$Rest, $SkipTail) {
    $SkipTail.Value = $true
    return
  }
  function Invoke-DesktopCommand([string]$Cmd, [string[]]$Rest) {
    switch ($Cmd) {
      'noref' {
        $a15SkipTail = $false
        Invoke-Handler-noref 'noref' $Rest ([ref]$a15SkipTail)
        if ($a15SkipTail) { return }
      }
    }
  }
'@
  $a15bTwo = @'
  function Invoke-DesktopCommand([string]$Cmd) { switch ($Cmd) { 'a' { } } ; switch ($Cmd) { 'b' { } } }
'@
  $a15bI = @('selftest')
  $a15bClean = Get-HandlerStubGap (Parse-SourceForInventory $a15bGood) $a15bI @('uia-click') 1
  $a15bNoFlag = Get-HandlerStubGap (Parse-SourceForInventory $a15bGood) $a15bI @() 1
  $a15bGhost = Get-HandlerStubGap (Parse-SourceForInventory $a15bGood) $a15bI @('uia-click', 'ghost') 1
  $a15bCount = Get-HandlerStubGap (Parse-SourceForInventory $a15bGood) $a15bI @('uia-click') 3
  $a15bName = Get-HandlerStubGap (Parse-SourceForInventory $a15bWrongName) $a15bI @() 0
  $a15bCmd = Get-HandlerStubGap (Parse-SourceForInventory $a15bWrongCmd) $a15bI @() 0
  $a15bRest = Get-HandlerStubGap (Parse-SourceForInventory $a15bWrongRest) $a15bI @() 0
  $a15bInlineGap = Get-HandlerStubGap (Parse-SourceForInventory $a15bInline) $a15bI @() 0
  $a15bOrphanGap = Get-HandlerStubGap (Parse-SourceForInventory $a15bOrphan) $a15bI @() 0
  $a15bMarkGap = Get-HandlerStubGap (Parse-SourceForInventory $a15bNoMark) $a15bI @('markme') 0
  $a15bEscGap = Get-HandlerStubGap (Parse-SourceForInventory $a15bEscape) $a15bI @('escapeme') 0
  $a15bRefGap = Get-HandlerStubGap (Parse-SourceForInventory $a15bNoRef) $a15bI @('noref') 0
  $a15bNullGap = Get-HandlerStubGap $null $a15bI @() 0
  $a15bAbsentGap = Get-HandlerStubGap (Parse-SourceForInventory 'function Other-Thing { return 1 }') $a15bI @() 0
  $a15bNoSwGap = Get-HandlerStubGap (Parse-SourceForInventory 'function Invoke-DesktopCommand([string]$Cmd) { Write-Output 1 }') $a15bI @() 0
  $a15bTwoGap = Get-HandlerStubGap (Parse-SourceForInventory $a15bTwo) $a15bI @() 0
  $a15bMap = (Get-HandlerName 'chrome-click') + '/' + (Get-HandlerName 'uia-settext')
  ST-Check 'unit (A-15b): the stub predicate passes the good fixture and names an unregistered flag case, a registered flag case that is gone, a wrong unwrapped count, a stub pointing at another handler, a wrong literal command name, a wrong rest argument, an unregistered inline case, an orphan handler, an unmarked early return, a flag that reaches the output, a third parameter that is not [ref], a null parse, an absent dispatcher and a switch count that is not one' (
    ($a15bClean -ceq '') -and ($a15bNoFlag -ceq 'flag-not-registered=uia-click') -and
    ($a15bGhost -ceq 'flag-registered-missing=ghost') -and ($a15bCount -ceq 'unwrapped=1-want=3') -and
    ($a15bName -ceq 'stub-name=shot=Invoke-Handler-other,handler-orphan=Invoke-Handler-shot') -and
    ($a15bCmd -ceq 'stub-cmdname=shot=shotx') -and ($a15bRest -ceq 'stub-rest=shot=Cmd') -and
    ($a15bInlineGap -ceq 'inline-not-allowed=help') -and ($a15bOrphanGap -ceq 'handler-orphan=Invoke-Handler-orphaned') -and
    ($a15bMarkGap -ceq 'flag-return-unmarked=Invoke-Handler-markme@2') -and ($a15bEscGap -ceq 'flag-escape=Invoke-Handler-escapeme@2') -and
    ($a15bRefGap -ceq 'handler-not-ref=Invoke-Handler-noref=$SkipTail') -and ($a15bNullGap -ceq '-no-parse') -and
    ($a15bAbsentGap -ceq '-absent-body:Invoke-DesktopCommand') -and ($a15bNoSwGap -ceq 'switch-count=0') -and
    ($a15bTwoGap -ceq 'switch-count=2') -and
    ($a15bMap -ceq 'Invoke-Handler-chrome-click/Invoke-Handler-uia-settext'))
  Write-Output ('      A-15b fixtures: clean=[' + $a15bClean + '] no-flag=[' + $a15bNoFlag + '] ghost=[' + $a15bGhost +
    '] count=[' + $a15bCount + '] name=[' + $a15bName + '] cmd=[' + $a15bCmd + '] rest=[' + $a15bRest +
    '] inline=[' + $a15bInlineGap + '] orphan=[' + $a15bOrphanGap + '] unmarked=[' + $a15bMarkGap +
    '] escape=[' + $a15bEscGap + '] no-ref=[' + $a15bRefGap + '] refusals=[' + $a15bNullGap + '/' + $a15bAbsentGap +
    '/' + $a15bNoSwGap + '/' + $a15bTwoGap + '] map=' + $a15bMap)

}
