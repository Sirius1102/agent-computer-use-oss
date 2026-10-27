# lib/selftest-docs-contract.ps1 - one family of the selftest section, lifted out of lib/selftest.ps1 by A-14k (A-beta).
# Bodies are byte-identical to what the section carried. The only channel to the orchestrator is the
# explicit context object: shared state arrives through $Ctx and nothing else, because A-14e/A-14i
# measured what happens when a body reaches for a caller local instead.
# The outward-documentation family: the help-page index and the per-command page, the document-
# consistency sweep over the markdown, the skill loader command list and its scripts, the quick-start
# guide, and the shape of the usage page itself. A-14j hoisted the producers this family used to own,
# so after that lift it needed nothing from another body - which is why it could move at all.
function Invoke-SelftestFamily-DocsContract($Ctx) {
  # context handover (the one thing in this file that is not lifted text)
  $clCount = $Ctx['clCount']
  $codeLines = $Ctx['codeLines']
  $hCaseStarts = $Ctx['hCaseStarts']
  $hFnStart = $Ctx['hFnStart']
  $hLines = $Ctx['hLines']
  $src = [string]$Ctx['src']

  # ---------- unit: v1.5.7 help <command> - the page gets an index ----------
  $hNames = Get-HelpCommandNames $hLines
  ST-Check 'unit: the help index sees the commands (>= 55 entries, scan is not vacuous)' (@($hNames).Count -ge 55)
  $hClick = @(Format-CommandHelp $hLines 'click')
  $hShot = @(Format-CommandHelp $hLines 'shot')
  $hWins = @(Format-CommandHelp $hLines 'wins')
  $hType = @(Format-CommandHelp $hLines 'type')
  $hExpChg = @(Format-CommandHelp $hLines '--expect-change')
  ST-Check 'unit: help click returns its own entry and points at where shared flags live' (
    (@($hClick).Count -ge 2) -and $hClick[0].Trim().StartsWith('click ') -and
    (@($hClick | Where-Object { $_ -match 'global flags' }).Count -eq 1))
  ST-Check 'unit: help <flag> finds the shared paragraph a per-command slice cannot show' (
    (@($hExpChg).Count -ge 2) -and (@($hExpChg | Where-Object { $_ -match 'expect-change' }).Count -ge 1))
  ST-Check 'unit: help shot lists its own flags including --no-grid (v1.5.7b)' (
    $hShot[0].Contains('--no-grid') -and $hShot[0].Contains('--grid'))
  ST-Check 'unit: help wins lists the D-7 columns' (@($hWins | Where-Object { $_ -match 'main' }).Count -ge 1)
  ST-Check 'unit: help type stays inside type (the slice does not run into type-in)' (
    $hType[0].Trim().StartsWith('type ') -and (@($hType | Where-Object { $_ -match '^    type-in ' }).Count -eq 0))
  # option-list pipes inside a synopsis (--occlude off|warn|strict) are NOT commands
  ST-Check 'unit: the help index does not mistake option values for command names' (
    -not (@($hNames) -contains 'warn') -and -not (@($hNames) -contains 'strict') -and (@($hNames) -contains 'shot'))
  # a multi-command synopsis line must resolve for EVERY name on it. These calls are
  # wrapped so a regression produces a NAMED FAIL instead of aborting selftest before its
  # summary (an abort is red too, but it hides every check that comes after it).
  $hMinTxt = ''
  try { $hMinTxt = (@(Format-CommandHelp $hLines 'win-min') -join "`n") } catch { $hMinTxt = 'THREW: ' + $_.Exception.Message }
  $hCloseTxt = ''
  try { $hCloseTxt = (@(Format-CommandHelp $hLines 'win-close') -join "`n") } catch { $hCloseTxt = 'THREW: ' + $_.Exception.Message }
  ST-Check 'unit: a shared synopsis line resolves for each name on it (win-min/win-close)' (
    ($hMinTxt -match 'win-min') -and ($hCloseTxt -match 'win-close'))
  $hErr = ''
  try { [void](Format-CommandHelp $hLines 'no-such-command') } catch { $hErr = $_.Exception.Message }
  ST-Check 'unit: help <unknown> refuses and offers the whole page' (
    $hErr.Contains("no help entry for 'no-such-command'") -and -not ($hErr -like '*did you mean*'))
  $hSug = ''
  try { [void](Format-CommandHelp $hLines 'clik') } catch { $hSug = $_.Exception.Message }
  ST-Check 'unit: a near-miss command name gets candidates, not a bare refusal' ($hSug.Contains('did you mean') -and $hSug.Contains('click'))
  $hFlag = ''
  try { [void](Format-CommandHelp $hLines '--definitely-not-a-flag') } catch { $hFlag = $_.Exception.Message }
  ST-Check 'unit: help --<unknown flag> refuses instead of printing nothing' ($hFlag.Contains('no mention of'))
  # a page-level entry resolves (selftest is documented at 2-space indent, not as a command
  # synopsis), but the GROUP HEADERS at the same indent are not commands and must be refused
  $hSelf = @(Format-CommandHelp $hLines 'selftest')
  ST-Check 'unit: help selftest finds the page-level entry' (@($hSelf | Where-Object { $_ -match 'mechanical regression' }).Count -ge 1)
  $hHdr = ''
  try { [void](Format-CommandHelp $hLines 'clipboard') } catch { $hHdr = $_.Exception.Message }
  ST-Check 'unit: a 2-space group header is not treated as a command' ($hHdr.Contains("no help entry for 'clipboard'"))
  # meta entries the page documents in prose instead of a synopsis line - kept as an
  # explicit list so a new command cannot quietly join it
  $hExcept = @()
  # @(hashtable).Count is ALWAYS 1 in PS 5.1, AND a key named 'keys' shadows the .Keys
  # property (see Get-HashKeys) - both traps are pinned here because the dispatcher scan is
  # keyed by COMMAND NAMES, one of which is literally 'keys'. The first version of the
  # reachability lint iterated .Keys, ran its body ONCE over an Int32 line number, and
  # reported green for every private flag in the table.
  $hkProbe = @{}
  $hkProbe['keys'] = 8017
  $hkProbe['click'] = 100
  $hkProbe['shot'] = 200
  ST-Check 'unit: a hashtable key shadows .Keys while Get-HashKeys stays honest' (
    @($hkProbe.Keys).Count -eq 1 -and @($hkProbe.Keys)[0] -eq 8017 -and (Get-HashKeys $hkProbe).Count -eq 3)
  $hNoDoc = @(@(Get-HashKeys $hCaseStarts) | Where-Object { -not (@($hNames) -contains $_) -and -not ($hExcept -contains $_) })
  ST-Check 'lint: every dispatcher command has a help entry (help <cmd> cannot have blind spots)' (
    $hFnStart -ge 0 -and $hCaseStarts.Count -ge 50 -and @($hNoDoc).Count -eq 0)
  foreach ($x in @($hNoDoc)) { Write-Output ("      command with no help entry: [" + $x + "] type=" + $(if ($null -eq $x) { 'null' } else { $x.GetType().Name }) + " cases=" + $hCaseStarts.Count) }
  Write-Output ("      all case keys: " + ((Get-HashKeys $hCaseStarts | Sort-Object) -join ' '))
  # @(hashtable).Count is ALWAYS 1 in PS 5.1 - use .Count / .Keys bare (see the D-1 note).
  Write-Output ("      help index entries=" + @($hNames).Count + " dispatcher cases=" + $hCaseStarts.Count)

  # ---------- R-05: the page and the registry are checked in BOTH directions ----------------
  # The old coverage lint only asked "does every dispatch case have a page entry". The reverse
  # was never tested, so a name the page INVENTED was invisible: `    Taking a coordinate off the
  # screen - ...` is a section heading, but the index read it as a command called 'Taking' and
  # `help Taking` answered. Both directions are compared here, and the predicate is fed planted
  # copies first - a comparison whose failure mode is "silently agrees" is not evidence.
  $capMeta = @('script', 'replay', 'selftest')
  $capNames = @()
  foreach ($cg in @(Get-HashKeys $script:StHandlerGroups | Sort-Object)) {
    foreach ($cn in @($script:StHandlerGroups[$cg])) { $capNames += [string]$cn }
  }
  $capPred = {
    param($advArg, $caseArg)
    return [pscustomobject]@{
      Phantom = @(@($advArg) | Where-Object { -not ($caseArg.ContainsKey([string]$_)) -and -not ($capMeta -contains [string]$_) })
      Missing = @(Get-HashKeys $caseArg | Where-Object { -not (@($advArg) -contains [string]$_) -and -not ($capMeta -contains [string]$_) })
    }
  }
  $hPhantom = @((& $capPred $hNames $hCaseStarts).Phantom)
  ST-Check 'lint (R-05): every help entry is a real dispatch case (the page cannot invent a command)' (
    (@($hNames).Count -ge 55) -and (@($hPhantom).Count -eq 0))
  if (@($hPhantom).Count -gt 0) { Write-Output ("      page entries with no dispatch case: " + (@($hPhantom) -join ', ')) }
  $hPhantomPlanted = @((& $capPred (@($hNames) + @('ghost-command', 'Taking')) $hCaseStarts).Phantom)
  ST-Check 'lint (R-05 teeth): the page-phantom predicate flags a planted fake name and the exact heading that used to leak' (
    (@($hPhantomPlanted).Count -eq 2) -and (@($hPhantomPlanted) -contains 'ghost-command') -and (@($hPhantomPlanted) -contains 'Taking'))
  $capReal = & $capPred $capNames $hCaseStarts
  ST-Check 'lint (R-05): capabilities advertises exactly the dispatcher (no ghost command, no blind spot)' (
    (@($capNames).Count -ge 85) -and (@($capReal.Phantom).Count -eq 0) -and (@($capReal.Missing).Count -eq 0))
  if (@($capReal.Phantom).Count -gt 0 -or @($capReal.Missing).Count -gt 0) {
    Write-Output ("      advertised-not-dispatched: [" + (@($capReal.Phantom) -join ',') + "] dispatched-not-advertised: [" + (@($capReal.Missing) -join ',') + "]")
  }
  $capPlanted = & $capPred (@($capNames) + @('ghost-command')) $hCaseStarts
  $capDropped = & $capPred (@($capNames) | Where-Object { $_ -ne 'wins' }) $hCaseStarts
  ST-Check 'lint (R-05 teeth): the capabilities predicate flags a planted ghost name and a dropped real one' (
    (@($capPlanted.Phantom).Count -eq 1) -and (@($capDropped.Missing).Count -eq 1))
  # The --json column must equal the ONE gate the dispatcher refuses on. It used to be filled
  # from the action table alone, which marked 17 readable commands json=false although they do
  # answer --json. Read the table the command really prints, not the source that builds it.
  $capJsonErr = ''
  $capJsonRows = @()
  try {
    $capSavedJson = [bool]$script:Json
    $script:Json = $true
    try { $capJsonRows = @((((Invoke-Handler-capabilities 'capabilities' @()) -join "`n") | ConvertFrom-Json).commands) }
    finally { $script:Json = $capSavedJson }
  } catch { $capJsonErr = $_.Exception.Message; $capJsonRows = @() }
  $capJsonPred = {
    param($rowArg)
    return @(@($rowArg) | Where-Object { [bool]$_.json -ne [bool](Test-JsonCapableCommand ([string]$_.name)) } | ForEach-Object { [string]$_.name })
  }
  $capJsonWrong = @(& $capJsonPred $capJsonRows)
  ST-Check 'lint (R-05): every advertised json flag equals the --json gate result (read family included)' (
    ($capJsonErr -eq '') -and (@($capJsonRows).Count -ge 85) -and (@($capJsonWrong).Count -eq 0))
  if ($capJsonErr -ne '') { Write-Output ("      capabilities --json could not be read: " + $capJsonErr) }
  if (@($capJsonWrong).Count -gt 0) { Write-Output ("      json flag disagrees with the gate: " + (@($capJsonWrong) -join ', ')) }
  $capJsonFlip = @($capJsonRows)
  if (@($capJsonFlip).Count -gt 0) {
    $capJsonFlip = @($capJsonFlip | ForEach-Object { if ([string]$_.name -eq 'info') { [pscustomobject]@{ name = $_.name; json = (-not [bool]$_.json) } } else { $_ } })
  }
  ST-Check 'lint (R-05 teeth): the json-flag predicate flags a planted flipped row' (
    (@(& $capJsonPred $capJsonFlip).Count -eq 1) -and (@(& $capJsonPred $capJsonFlip) -contains 'info'))

  # ---------- lint: v1.7.0 document-consistency sweep (traversal, no hand-maintained list) ----------
  # The owner named this version for exactly one disease: stale references and checklists
  # that quietly lose a file. Both directions are checked by traversal, never a list:
  #   README quick-reference lines must name REAL dispatcher commands, and every
  #   dispatcher command must appear somewhere in the README.
  $rdPath = Join-Path $script:ToolRootPath 'README.md'
  if (Test-Path -LiteralPath $rdPath) {
  $rdLines = @(Get-Content -LiteralPath (Join-Path $script:ToolRootPath 'README.md') -Encoding UTF8)
  $rdAllText = $rdLines -join "`n"
  $dcStartPat = '^## ' + [string]::Join('', @([char]0x547D, [char]0x4EE4, [char]0x901F, [char]0x67E5))
  $dcEndPat = '^## ' + [string]::Join('', @([char]0x5FC5, [char]0x987B, [char]0x8BB0, [char]0x4F4F, [char]0x7684, [char]0x5751))
  $dcStart = -1; $dcEnd = -1
  for ($j7i = 0; $j7i -lt $rdLines.Count; $j7i++) {
    if ($dcStart -lt 0 -and $rdLines[$j7i] -match $dcStartPat) { $dcStart = $j7i }
    elseif ($dcStart -ge 0 -and $rdLines[$j7i] -match $dcEndPat) { $dcEnd = $j7i; break }
  }
  $dcNames = New-Object System.Collections.ArrayList
  for ($j7i = $dcStart + 1; $j7i -lt $dcEnd; $j7i++) {
    if ($rdLines[$j7i] -match ('^-\s+`([a-z][a-z0-9-]+)')) { [void]$dcNames.Add($Matches[1]) }
  }
  $dcCase = @(Get-HashKeys $hCaseStarts)
  # entry-point commands dispatched OUTSIDE Invoke-DesktopCommand - an explicit list like
  # $hExcept, and each entry must still exist as a real dispatch case (asserted below), so
  # the exemptions cannot grow into a second hand-maintained command universe.
  $dcMeta = @('script', 'replay', 'selftest')
  $dcMetaLive = @($codeLines | Where-Object { $_ -match ('^\s{4}' + "'" + '(script|replay|selftest)' + "'" + ' \{') })
  ST-Check 'lint: the README-sweep exemptions are real dispatch targets (script/replay/selftest cases exist)' (@($dcMetaLive).Count -ge 3)
  $dcStale = @(@($dcNames) | Where-Object { ($dcCase -notcontains $_) -and ($dcMeta -notcontains $_) })
  ST-Check 'lint: every command in the README quick reference exists in the dispatcher (no stale references)' (
    ($dcStart -ge 0) -and ($dcEnd -gt $dcStart) -and (@($dcNames).Count -ge 30) -and (@($dcStale).Count -eq 0))
  if (@($dcStale).Count -gt 0) { Write-Output "      stale README commands: $(@($dcStale) -join ', ')" }
  $dcMissing = @(@($dcCase) | Where-Object { -not ("$rdAllText".Contains($_)) })
  ST-Check 'lint: every dispatcher command appears in the README (no under-documented command)' (
    (@($dcCase).Count -ge 50) -and (@($dcMissing).Count -eq 0))
  if (@($dcMissing).Count -gt 0) { Write-Output "      commands missing from README: $(@($dcMissing) -join ', ')" }
  } else {
    ST-Skip 'lint: the README-sweep exemptions are real dispatch targets (script/replay/selftest cases exist)' 'README documentation not present (installed copy) - the sweep cannot run'
    ST-Skip 'lint: every command in the README quick reference exists in the dispatcher (no stale references)' 'README documentation not present (installed copy)'
    ST-Skip 'lint: every dispatcher command appears in the README (no under-documented command)' 'README documentation not present (installed copy)'
  }

  # ---------- v4.1.3 (external review L): the skill loader's command list is an outward ----
  # contract, so it may only name commands THIS tree can run. The loader docs ship with the
  # installed skill, which means a phantom there is something an agent will keep trying to
  # call. The README sweep above only reads README.md, so when this tree dropped the
  # Per-Monitor V2 block that the published tree still carries, `dpi` stayed taught in
  # SKILL.md and every offline check stayed green. Traversal, not a hand list: the case set
  # comes from the dispatcher itself, and the exemption list is pinned against it.
  $skCaseSet = @(Get-HashKeys $hCaseStarts)
  $skMeta = @('script', 'replay', 'selftest')
  $skDocs = @('skill/agent-computer-use/SKILL.md', 'skill/agent-computer-use/reference.md')
  $skPresent = @($skDocs | Where-Object { Test-Path -LiteralPath (Join-Path $script:ToolRootPath $_) })
  if (@($skPresent).Count -eq @($skDocs).Count) {
    $skPhantom = @()
    $skSeen = 0
    foreach ($skDoc in @($skPresent)) {
      $skLines = @(Get-Content -LiteralPath (Join-Path $script:ToolRootPath $skDoc) -Encoding UTF8)
      foreach ($skl in $skLines) {
        if ($skl -match '^-\s+`([a-z][a-z0-9-]+)') {
          $skName = $Matches[1]
          $skSeen = $skSeen + 1
          if ((-not (@($skCaseSet) -contains $skName)) -and (-not (@($skMeta) -contains $skName))) { $skPhantom += ($skDoc + ':' + $skName) }
        }
      }
    }
    # script/replay/selftest are dispatched OUTSIDE Invoke-DesktopCommand (the same
    # exemption the README sweep makes), so they are not in $skCaseSet by construction -
    # they must still be proven to be real targets, or the exemption list becomes a second
    # command universe that the phantom lint cannot see.
    $skMetaLive = @($codeLines | Where-Object { $_ -match ('^\s{4}' + "'" + '(script|replay|selftest)' + "'" + ' \{') })
    ST-Check 'lint: the loader-doc exemptions are real dispatch targets (script/replay/selftest cases exist outside the main dispatcher)' (
      (@($skCaseSet).Count -ge 50) -and (@($skMetaLive).Count -ge 3) -and (@($skMeta).Count -eq 3))
    ST-Check 'lint: every command the skill loader teaches exists in this tree dispatcher (no phantom in the outward contract)' (
      $skSeen -ge 40 -and (@($skPhantom).Count -eq 0))
    if (@($skPhantom).Count -gt 0) { Write-Output ("      loader teaches commands this tree cannot run: " + ((@($skPhantom) | Sort-Object -Unique) -join ', ')) }
    Write-Output ("      loader command lines seen=" + $skSeen + " dispatcher cases=" + @($skCaseSet).Count)
  } else {
    ST-Skip 'lint: the loader-doc exemptions are real dispatch targets (script/replay/selftest cases exist outside the main dispatcher)' 'skill loader docs not both present (installed copy) - the sweep cannot run'
    ST-Skip 'lint: every command the skill loader teaches exists in this tree dispatcher (no phantom in the outward contract)' 'skill loader docs not both present (installed copy) - the sweep cannot run'
  }

  # ---------- v4.2.3: the quick-start guide is an outward contract too ----------
  # The quick-start guide (its filename is assembled from code points just below, so this file
  # stays pure ASCII) is the FIRST document a new agent reads, and it teaches commands by name.
  # Nothing compared it against this tree: the v1.7.0 sweep covers README.md and the v4.1.3 lint
  # covers the two skill-loader docs - the guide was the THIRD carrier of the same disease
  # (rename or drop a command and the newcomer document keeps teaching a dead one, silently).
  # Traversal, not a hand list. The exemption list is the same three entry-point commands both
  # sweeps above already pin as real dispatch targets; the floors (>=50 cases, >=3 taught lines)
  # are the positive controls that stop an empty scan from reading as "nothing wrong".
  $qsName = [string]::Join('', @([char]0x5FEB, [char]0x901F, [char]0x4E0A, [char]0x624B, [char]0x6307, [char]0x5357)) + '.md'
  $qsCaseSet = @(Get-HashKeys $hCaseStarts)
  $qsMeta = @('script', 'replay', 'selftest')
  $qsFile = Join-Path $script:ToolRootPath $qsName
  if (Test-Path -LiteralPath $qsFile) {
    $qsSeen = 0
    $qsPhantom = @()
    foreach ($qsl in @(Get-Content -LiteralPath $qsFile -Encoding UTF8)) {
      # The CLOSING backtick is load-bearing: a taught command is written `cmd` in full, while a
      # PATH in backticks must not read as a command name. Without it this check failed on a
      # perfectly correct document - the shared-audit-log line captured "shots" from
      # `shots/actions.log` (measured 2026-10-10: seen=6 with the false positive, 5 without).
      # Tightening the pattern is the fix; whitelisting "shots" would have hidden a real miss.
      if ($qsl -match '^-\s+`([a-z][a-z0-9-]+)`') {
        $qsN = $Matches[1]
        $qsSeen = $qsSeen + 1
        if ((-not (@($qsCaseSet) -contains $qsN)) -and (-not (@($qsMeta) -contains $qsN))) { $qsPhantom += $qsN }
      }
    }
    ST-Check 'lint: every command the quick-start guide teaches exists in this tree dispatcher (the newcomer document cannot teach a dead command)' (
      (@($qsCaseSet).Count -ge 50) -and ($qsSeen -ge 3) -and (@($qsPhantom).Count -eq 0))
    if (@($qsPhantom).Count -gt 0) { Write-Output ("      quick-start teaches commands this tree cannot run: " + ((@($qsPhantom) | Sort-Object -Unique) -join ', ')) }
    Write-Output ("      quick-start guide command lines seen=" + $qsSeen)
  } else {
    ST-Skip 'lint: every command the quick-start guide teaches exists in this tree dispatcher (the newcomer document cannot teach a dead command)' 'quick-start guide not present (installed copy) - the sweep cannot run'
  }

  # ---------- contract: the usage PAGE itself is well-formed (v3.0.1, 3.0.0 audit item 15) ----------
  # The page is a here-string, so $codeLines blanks it out and every check above is
  # blind to it; these read the raw source. Three shapes were measured broken:
  #   * one command named by two entry lines -> `help <cmd>` prints two entries with
  #     two different descriptions (measured: hash, wheel, a11y-probe),
  #   * a description glued to its label with a wide space run instead of wrapped,
  #     which renders as a column the eye cannot follow (measured: replay, --needle),
  #   * a paragraph whose lead-in is printed twice, so the sentence has no verb left
  #     on the first line (measured: the occlusion paragraph).
  # The gap rule needs a number: a label column always ends before index 45 (widest
  # label measured starts its description at 36), and the two broken lines put theirs
  # at 55 and 83. That is where the 45 comes from - not a tolerance, a measured seam.
  $usageRaw = @()
  $usageIn = $false
  $usageOpen = $false
  foreach ($uLine in ($src -split "`r?`n")) {
    if (-not $usageIn) { if ($uLine -match '^function Get-UsageText \{') { $usageIn = $true }; continue }
    if (-not $usageOpen) { if ($uLine -match "^\s*@'") { $usageOpen = $true }; continue }
    if ($uLine -match "^'@") { break }
    $usageRaw += [string]$uLine
  }
  # the extractor must actually find the page, or all three checks below are vacuous
  ST-Check 'lint: the usage-page shape checks can see the page (extractor is not vacuous)' (
    (@($usageRaw).Count -gt 500) -and ((@($usageRaw | Where-Object { $_ -match '^  read$' }).Count) -eq 1))
  $usageSeen = @{}
  $usageDupes = @()
  foreach ($uLine in $usageRaw) {
    $uEntry = [regex]::Match($uLine, '^    ([a-z][a-z0-9-]*)[ <\[]')
    if (-not $uEntry.Success) { continue }
    $uName = $uEntry.Groups[1].Value
    if ($usageSeen.ContainsKey($uName)) { $usageDupes += $uName } else { $usageSeen[$uName] = 1 }
  }
  ST-Check 'contract: no command name heads two usage entries (help <cmd> prints exactly one)' (
    @($usageDupes).Count -eq 0)
  if (@($usageDupes).Count -gt 0) { Write-Output ("      duplicated usage entries: " + (($usageDupes | Sort-Object -Unique) -join ', ')) }
  $usageGlued = @()
  foreach ($uLine in $usageRaw) {
    foreach ($uGap in [regex]::Matches($uLine, ' {20,}')) { if ($uGap.Index -ge 45) { $usageGlued += $uLine.Trim() } }
  }
  ST-Check 'contract: no usage line glues a description to its label with a wide space run' (
    @($usageGlued).Count -eq 0)
  foreach ($uBad in $usageGlued) { Write-Output "      glued usage line: $uBad" }
  $coverLeadIn = 'A covered' + ' target prints'
  $coverLines = @($usageRaw | Where-Object { $_.Contains($coverLeadIn) })
  ST-Check 'contract: the occlusion paragraph says once what a covered target prints' (
    @($coverLines).Count -eq 1)
  # v3.0.1 (audit item 15, fourth spot): a two-line fragment had drifted to the tail of
  # the --expect-handle entry, leaving a continuation line that was only the word
  # "wait-stable". It now lives inside that command entry, where --changed belongs.
  ST-Check 'contract: wait-stable documents --changed once and no entry ends in a stray command name' (
    (@($usageRaw | Where-Object { $_.Contains('[--changed]') }).Count -eq 1) -and
    (@($usageRaw | Where-Object { $_.Trim() -ceq 'wait-stable' }).Count -eq 0))

  # ---------- contract: a comment that advertises a ladder must walk the same one ----------
  # v3.0.1 (audit item 24): the paragraph above Wait-Foreground still described the
  # pre-v1.5.2 loop ("3 tries, 400ms apart") after the code had become a six-step
  # back-off. Narrow on purpose - this pins ONE comment, because a general prose lint
  # needs an exemption list and gets switched off inside a week. The expected text is
  # DERIVED from the loop, so editing the ladder without editing the paragraph is red.
  $wfI = -1
  for ($wI = 0; $wI -lt $clCount; $wI++) { if ([string]$codeLines[$wI] -match '^function Wait-Foreground') { $wfI = $wI; break } }
  $wfWant = ''
  $wfHead = ''
  $wfProse = ''
  if ($wfI -gt 9) {
    $wfMs = [regex]::Match([string]$codeLines[$wfI + 1], '@\(([\d,\s]+)\)')
    if ($wfMs.Success) { $wfWant = ((@($wfMs.Groups[1].Value -split ',') | ForEach-Object { $_.Trim() }) -join '/') }
    $wfHead = (($codeLines[($wfI - 9)..($wfI - 1)]) -join ' ')
    # WHOLE token, not a substring: measured with the ladder shortened by one step, a
    # Contains() test stayed GREEN because "0/100/200/300/300" sits inside the prose's
    # "0/100/200/300/300/300". Exactly one slash-run in the paragraph, exactly equal.
    $wfRuns = @([regex]::Matches($wfHead, '\d+(/\d+)+'))
    if (@($wfRuns).Count -eq 1) { $wfProse = [string]$wfRuns[0].Value }
  }
  ST-Check 'contract: the Wait-Foreground paragraph names the back-off ladder the loop walks' (
    ($wfI -gt 9) -and ($wfWant -ne '') -and (@([regex]::Matches($wfHead, '\d+(/\d+)+')).Count -eq 1) -and
    ($wfProse -ceq $wfWant) -and (-not $wfHead.Contains('400ms')))
  if (($wfWant -ne '') -and ($wfProse -cne $wfWant)) { Write-Output "      ladder drift: the loop walks $wfWant, the paragraph above says '$wfProse'" }

  # ---------- v3.0.1 (audit #23): the skill loader scripts carry the project guards ----------
  # The two scripts are tracked files and were written before the three-hard-guards rule
  # existed, so nothing connected them to it. StrictMode is now ON in both (verified by
  # installing into and uninstalling from a throwaway temp dir with this round's change in
  # place); $ErrorActionPreference stays 'Continue' ON PURPOSE - a terminating first error
  # in an installer leaves a half-copied skill behind, which is worse than collecting the
  # problems and exiting with a code. The check therefore pins the guard AND the reason.
  $skillGuards = @('Set-StrictMode -Version Latest', 'ErrorActionPreference')
  $skillFiles = @('skill\agent-computer-use\install.ps1', 'skill\agent-computer-use\uninstall.ps1')
  # A-22: the two loader scripts ship with the REPOSITORY, not with the stitched artifact, so an installed
  #    copy cannot have them. The same shape the loader-doc sweep above already uses - measure when the
  #    carriers are here, say so out loud when they are not; never a silent disappearance either way.
  $skillHere = @($skillFiles | Where-Object { Test-Path -LiteralPath (Join-Path $script:ToolRootPath $_) })
  if (@($skillHere).Count -eq @($skillFiles).Count) {
    $skillNoGuard = @()
    $skillNoReason = @()
    foreach ($sf in @($skillHere)) {
      $sfText = [System.IO.File]::ReadAllText((Join-Path $script:ToolRootPath $sf), [System.Text.Encoding]::UTF8)
      foreach ($sg in $skillGuards) { if (-not $sfText.Contains($sg)) { $skillNoGuard += ("$sf lacks $sg") } }
      if (-not $sfText.Contains('audit item 23')) { $skillNoReason += $sf }
    }
    ST-Check 'lint: both skill loader scripts exist, carry StrictMode plus an explicit error preference, and state why Continue is deliberate' (
      (@($skillNoGuard).Count -eq 0) -and (@($skillNoReason).Count -eq 0))
    foreach ($sgb in (@($skillNoGuard) + @($skillNoReason))) { Write-Output "      skill guard: $sgb" }
  } else {
    ST-Skip 'lint: both skill loader scripts exist, carry StrictMode plus an explicit error preference, and state why Continue is deliberate' 'skill loader scripts not both present (installed copy) - the installer lives in the repository, never beside the stitched artifact'
  }

  # ---------- TB-5: the uninstaller's recursive delete is gated and bounded ----------
  # This is the only rm-rf-shaped operation shipped in the repository, and it deletes a CHILD of a
  # directory the operator names, so two properties have to survive edits: the delete sits behind
  # exactly one ShouldProcess gate whose inner cmdlet is explicitly told not to ask again, and the
  # dangerous-target refusal is in the file at all. The -Confirm:$false is load-bearing, not
  # cosmetic - measured on this machine, when -Confirm propagates into Remove-Item the recursive
  # delete throws NullReferenceException on BOTH Windows PowerShell 5.1 and PowerShell 7.6.7.
  $unRel = 'skill\agent-computer-use\uninstall.ps1'
  $unPath = Join-Path $script:ToolRootPath $unRel
  if (Test-Path -LiteralPath $unPath) {
    $unText = [System.IO.File]::ReadAllText($unPath, [System.Text.Encoding]::UTF8)
    # 'SupportsShouldProcess' alone is a weak needle: the header prose says the word too. The
    # bracketed attribute prefix appears exactly once, in [CmdletBinding(...)], so that is what
    # the predicate asks for, and the refusal needles are the reason strings the script emits.
    $unNeedles = @(
      '[CmdletBinding(SupportsShouldProcess',
      '$PSCmdlet.ShouldProcess(',
      'Remove-Item -LiteralPath $skillFull -Recurse -Force -Confirm:$false',
      'Test-ReparsePoint',
      'holds .git (a repository or worktree)',
      'holds desktop.ps1 (this tool owns that tree)',
      'source directory with .ps1 files',
      'is a volume root',
      'exit 5')
    $unLack = @($unNeedles | Where-Object { -not $unText.Contains($_) })
    $unGates = @([regex]::Matches($unText, '\$PSCmdlet\.ShouldProcess\(')).Count
    ST-Check 'lint (TB-5): the uninstaller gates its recursive delete behind one ShouldProcess call, keeps -Confirm off the inner cmdlet and refuses repository-shaped and reparse targets' (
      (@($unLack).Count -eq 0) -and ($unGates -eq 1))
    foreach ($ul in $unLack) { Write-Output "      TB-5 uninstall guard lacks: $ul" }
    Write-Output ("      TB-5 uninstall ShouldProcess call count: " + $unGates)
    # Teeth: rub the guards out of an in-memory copy and run the SAME predicate over it. A copy
    # with the attribute and the inner -Confirm:$false removed must come back flagged, or the
    # check above would stay green on a file that no longer has either.
    $unMutated = $unText.Replace('[CmdletBinding(SupportsShouldProcess', '[CmdletBinding(Process').Replace(' -Confirm:$false', '')
    $unMutLack = @($unNeedles | Where-Object { -not $unMutated.Contains($_) })
    ST-Check 'lint (TB-5): the uninstaller guard predicate flags the planted guard-free copy (teeth, not decoration)' (
      (@($unLack).Count -eq 0) -and (@($unMutLack).Count -ge 2) -and ($unMutLack.Contains('[CmdletBinding(SupportsShouldProcess')))
    Write-Output ("      TB-5 planted-copy flagged: " + (@($unMutLack).Count) + " needle(s)")
  } else {
    ST-Skip 'lint (TB-5): the uninstaller gates its recursive delete behind one ShouldProcess call, keeps -Confirm off the inner cmdlet and refuses repository-shaped and reparse targets' 'no uninstaller in this tree - the loader scripts ship with the repository, never beside the stitched artifact'
    ST-Skip 'lint (TB-5): the uninstaller guard predicate flags the planted guard-free copy (teeth, not decoration)' 'no uninstaller in this tree - the loader scripts ship with the repository, never beside the stitched artifact'
  }

  # ---------- TB-4: the outward docs must not teach a send into a real conversation ----------
  # A doc example that names a messaging window is an instruction an agent will follow against a
  # human on the other side. The guard family proves WHICH window took the keys; it never proves the
  # send was authorized, so the docs are the control here and both sides have to hold: the banned
  # example shape is gone from each carrier AND the red line is actually present in each - an
  # example-only edit would let the next round put the target back. The docs resolve either at the
  # repository path or, in an installed tree, above scripts\, so this reads the installed face
  # instead of substituting the source file for it.
  $tb4Banned = @('MyChat', 'into a chat window', 'for chat windows')
  $tb4Needles = @('paste-file --to "Notepad"', 'dtx-fixture.txt', 'hard red line')
  $tb4Docs = @('SKILL.md', 'reference.md')
  $tb4Texts = @{}
  $tb4Missing = @()
  $tb4Where = @()
  foreach ($tb4Name in $tb4Docs) {
    $tb4Cand = @(
      (Join-Path $script:ToolRootPath (Join-Path (Join-Path 'skill' 'agent-computer-use') $tb4Name)),
      (Join-Path (Split-Path -Parent $script:ToolRootPath) $tb4Name),
      (Join-Path $script:ToolRootPath $tb4Name))
    $tb4Hit = @($tb4Cand | Where-Object { Test-Path -LiteralPath $_ })
    if (@($tb4Hit).Count -eq 0) { $tb4Missing += $tb4Name }
    else {
      $tb4Where += ($tb4Name + '=' + $tb4Hit[0])
      $tb4Texts[$tb4Name] = [System.IO.File]::ReadAllText($tb4Hit[0], [System.Text.Encoding]::UTF8)
    }
  }
  if (@($tb4Missing).Count -eq 0) {
    $tb4Bad = @()
    foreach ($tb4Name in $tb4Docs) {
      $tb4T = [string]$tb4Texts[$tb4Name]
      # fail closed: an emptied needle list or a truncated read would both look like "nothing to flag"
      if ((@($tb4Needles).Count -lt 3) -or (@($tb4Banned).Count -lt 3)) { $tb4Bad += ($tb4Name + ': the guard lost its own needle list') }
      if ($tb4T.Length -lt 200) { $tb4Bad += ($tb4Name + ': read back only ' + $tb4T.Length + ' chars, too small to judge') }
      foreach ($tb4N in $tb4Needles) { if (-not $tb4T.Contains($tb4N)) { $tb4Bad += ($tb4Name + ' lacks: ' + $tb4N) } }
      foreach ($tb4X in $tb4Banned) { if ($tb4T.Contains($tb4X)) { $tb4Bad += ($tb4Name + ' still teaches the chat target: ' + $tb4X) } }
    }
    ST-Check 'lint (TB-4): both outward docs carry the messaging red line with a fixture-only send example and no chat-window target (read from whichever face this tree is)' (
      (@($tb4Bad).Count -eq 0))
    foreach ($tb4B in $tb4Bad) { Write-Output ("      TB-4 doc face: " + $tb4B) }
    Write-Output ("      TB-4 doc paths read: " + ($tb4Where -join ' | '))
    # Teeth: rebuild the pre-fix shape in memory - target back, red line out, fixture name out - and
    # run the SAME needles over it. If that copy is not flagged, the check above is a needle count.
    $tb4Mut = ([string]$tb4Texts['SKILL.md']).Replace('paste-file --to "Notepad"', 'paste-file --to "MyChat"').Replace('hard red line', 'note').Replace('dtx-fixture.txt', 'report.pdf')
    $tb4MutBad = @()
    foreach ($tb4X in $tb4Banned) { if ($tb4Mut.Contains($tb4X)) { $tb4MutBad += ('restored: ' + $tb4X) } }
    foreach ($tb4N in $tb4Needles) { if (-not $tb4Mut.Contains($tb4N)) { $tb4MutBad += ('lost: ' + $tb4N) } }
    ST-Check 'lint (TB-4): the doc-face predicate flags the planted copy that restores the chat target and drops the red line (teeth, not decoration)' (
      (@($tb4Bad).Count -eq 0) -and (@($tb4MutBad).Count -ge 1) -and ($tb4Mut.Contains('MyChat')) -and (-not $tb4Mut.Contains('hard red line')))
    Write-Output ("      TB-4 planted-copy flags: " + (@($tb4MutBad).Count) + " (" + ($tb4MutBad -join '; ') + ")")
  } else {
    ST-Skip 'lint (TB-4): both outward docs carry the messaging red line with a fixture-only send example and no chat-window target (read from whichever face this tree is)' ('outward doc(s) not resolvable here (missing: ' + (@($tb4Missing) -join ', ') + ') - nothing to read the red line off')
    ST-Skip 'lint (TB-4): the doc-face predicate flags the planted copy that restores the chat target and drops the red line (teeth, not decoration)' ('outward doc(s) not resolvable here (missing: ' + (@($tb4Missing) -join ', ') + ') - nothing to plant the mutant into')
  }

  # ---------- TB-6: the newcomer document the entry doc links at ships beside it ----------
  # SKILL.md pointed its quick-start link two levels ABOVE the package directory. That resolves inside a
  # repository clone and dangles in the installed layout - and the installed layout is the only place an
  # agent that loaded this skill ever reads the entry document. TB-6 makes the link a sibling and ships
  # the guide inside the package. The guide is also a THIRD carrier of the TB-4 disease: it taught a file
  # send aimed at a chat window, so delivering it into every install would have put that instruction in
  # front of every loader. Both halves are read from the face the run is on: the entry document and the
  # guide beside it are measured wherever they resolve (installed face included), while the carrier/root
  # byte identity and the installer behaviour only exist in a repository tree - an installed copy has
  # neither the root document nor install.ps1, and says so instead of silently passing.
  # Every CJK needle here is assembled from code points, like the quick-start name above: this file must
  # stay pure ASCII past its BOM, and a literal in the file would also be a hit in its own scan.
  $tb6Qs = [string]::Join('', @([char]0x5FEB, [char]0x901F, [char]0x4E0A, [char]0x624B, [char]0x6307, [char]0x5357)) + '.md'
  $tb6Ben = [string]::Join('', @([char]0x8BB0, [char]0x4E8B, [char]0x672C))
  $tb6ChatWin = [string]::Join('', @([char]0x804A, [char]0x5929, [char]0x7A97, [char]0x53E3))
  $tb6SendTo = [string]::Join('', @([char]0x7ED9, [char]0x804A, [char]0x5929, [char]0x7A97, [char]0x53E3, [char]0x53D1, [char]0x9001))
  $tb6Fixture = 'paste-file --to "' + $tb6Ben + '" dtx-fixture.txt'
  $tb6RedNeedles = @('hard red line', 'dtx-fixture.txt', $tb6Fixture)
  $tb6Banned = @($tb6SendTo, 'MyChat', 'into a chat window', 'for chat windows')
  $tb6SkillCand = @(
    (Join-Path $script:ToolRootPath (Join-Path (Join-Path 'skill' 'agent-computer-use') 'SKILL.md')),
    (Join-Path (Split-Path -Parent $script:ToolRootPath) 'SKILL.md'),
    (Join-Path $script:ToolRootPath 'SKILL.md'))
  $tb6SkillHit = @($tb6SkillCand | Where-Object { Test-Path -LiteralPath $_ })
  if (@($tb6SkillHit).Count -gt 0) {
    $tb6SkillPath = [string]$tb6SkillHit[0]
    $tb6SkillText = [string]([System.IO.File]::ReadAllText($tb6SkillPath, [System.Text.Encoding]::UTF8))
    $tb6QsPath = Join-Path (Split-Path -Parent $tb6SkillPath) $tb6Qs
    $tb6QsText = ''
    $tb6Bad = @()
    if ($tb6SkillText.Length -lt 200) { $tb6Bad += ('entry doc read back only ' + $tb6SkillText.Length + ' chars, too small to judge') }
    if (-not $tb6SkillText.Contains('](' + $tb6Qs + ')')) { $tb6Bad += 'entry doc carries no sibling link to the quick-start guide' }
    if ($tb6SkillText.Contains('../' + $tb6Qs)) { $tb6Bad += 'entry doc still links above the package directory' }
    if (-not (Test-Path -LiteralPath $tb6QsPath -PathType Leaf)) {
      $tb6Bad += ('no quick-start guide beside the entry doc: ' + $tb6Qs)
    } else {
      $tb6QsText = [string]([System.IO.File]::ReadAllText($tb6QsPath, [System.Text.Encoding]::UTF8))
      if ($tb6QsText.Length -lt 200) { $tb6Bad += ('guide read back only ' + $tb6QsText.Length + ' chars, too small to judge') }
      foreach ($tb6N in $tb6RedNeedles) { if (-not $tb6QsText.Contains($tb6N)) { $tb6Bad += ('guide lacks: ' + $tb6N) } }
      foreach ($tb6X in $tb6Banned) { if ($tb6QsText.Contains($tb6X)) { $tb6Bad += ('guide still teaches: ' + $tb6X) } }
    }
    ST-Check 'lint (TB-6): the entry document links the quick-start guide as a sibling, that guide is present beside it and carries the messaging red line with a fixture-only file-send example and no chat-window send teaching (read from whichever face this tree is)' (
      (@($tb6Bad).Count -eq 0) -and (@($tb6RedNeedles).Count -eq 3) -and (@($tb6Banned).Count -eq 4))
    foreach ($tb6B in @($tb6Bad)) { Write-Output ('      TB-6 delivery face: ' + [string]$tb6B) }
    Write-Output ('      TB-6 entry doc: ' + $tb6SkillPath + ' | guide: ' + $tb6QsPath + ' | guide chars: ' + $tb6QsText.Length)
    # Teeth: plant the pre-fix shape three ways and run the SAME arms over each copy - the escaped link
    # back into the entry doc, the red line out of the guide, the chat-window send line back into the
    # guide. Each plant carries its own positive control, so an arm that can only ever answer 'clean'
    # is named rather than flattered. Nothing is written to disk here.
    $tb6MutSkill = $tb6SkillText.Replace('](' + $tb6Qs + ')', ('](../../' + $tb6Qs + ')'))
    $tb6MutNoRed = $tb6QsText.Replace('hard red line', 'note')
    $tb6MutBanned = ($tb6QsText + '- ' + $tb6SendTo + ' report.pdf')
    $tb6Planted = @(
      [pscustomobject]@{ Name = 'escaped-link'; Text = $tb6MutSkill; Arm = 'link'; Took = ($tb6MutSkill.Contains('../' + $tb6Qs) -and (-not $tb6MutSkill.Contains('](' + $tb6Qs + ')'))) },
      [pscustomobject]@{ Name = 'red-line-removed'; Text = $tb6MutNoRed; Arm = 'needle'; Took = (-not $tb6MutNoRed.Contains('hard red line')) },
      [pscustomobject]@{ Name = 'chat-send-restored'; Text = $tb6MutBanned; Arm = 'banned'; Took = $tb6MutBanned.Contains($tb6SendTo) })
    $tb6PlantBad = @()
    foreach ($tb6P in @($tb6Planted)) {
      if (-not [bool]$tb6P.Took) { $tb6PlantBad += ('plant did not take: ' + [string]$tb6P.Name) }
      $tb6PFlagged = $false
      if (([string]$tb6P.Arm) -ceq 'link') {
        if ($tb6P.Text.Contains('../' + $tb6Qs)) { $tb6PFlagged = $true }
      } elseif (([string]$tb6P.Arm) -ceq 'needle') {
        foreach ($tb6N in $tb6RedNeedles) { if (-not $tb6P.Text.Contains($tb6N)) { $tb6PFlagged = $true } }
      } else {
        foreach ($tb6X in $tb6Banned) { if ($tb6P.Text.Contains($tb6X)) { $tb6PFlagged = $true } }
      }
      if (-not $tb6PFlagged) { $tb6PlantBad += ('planted copy NOT flagged: ' + [string]$tb6P.Name) }
    }
    ST-Check 'lint (TB-6): the delivery predicate flags each planted copy - the entry doc with the link escaped above the package, the guide with the red line removed and the guide with the chat-window send line restored (teeth, not decoration)' (
      (@($tb6PlantBad).Count -eq 0) -and (@($tb6Planted).Count -eq 3) -and (@($tb6Bad).Count -eq 0))
    foreach ($tb6Pb in @($tb6PlantBad)) { Write-Output ('      TB-6 teeth: ' + [string]$tb6Pb) }
    Write-Output ('      TB-6 planted copies: ' + (@($tb6Planted | ForEach-Object { [string]$_.Name }) -join ','))
  } else {
    ST-Skip 'lint (TB-6): the entry document links the quick-start guide as a sibling, that guide is present beside it and carries the messaging red line with a fixture-only file-send example and no chat-window send teaching (read from whichever face this tree is)' 'no entry document resolvable here - nothing to read the newcomer link off'
    ST-Skip 'lint (TB-6): the delivery predicate flags each planted copy - the entry doc with the link escaped above the package, the guide with the red line removed and the guide with the chat-window send line restored (teeth, not decoration)' 'no entry document resolvable here - nothing to plant into'
  }

  # ---------- TB-6 (repository face): two copies, one byte face, and an installer that refuses ----------
  # The package carries a COPY of the repository-root guide because the installed layout has no root to
  # link into. A copy without a reconciliation drifts silently, so the two are pinned by SHA256 over the
  # raw bytes, and the installer is pinned on both shapes it has to keep: it resolves the guide from the
  # package directory (not from the repository root, which is absent by then) and it REFUSES the install
  # when the carrier is missing instead of shipping a package whose entry document links at nothing.
  $tb6PkgDir = Join-Path $script:ToolRootPath (Join-Path 'skill' 'agent-computer-use')
  $tb6RootQs = Join-Path $script:ToolRootPath $tb6Qs
  $tb6PkgQs = Join-Path $tb6PkgDir $tb6Qs
  $tb6InstPath = Join-Path $tb6PkgDir 'install.ps1'
  if ((Test-Path -LiteralPath $tb6RootQs -PathType Leaf) -and (Test-Path -LiteralPath $tb6PkgQs -PathType Leaf) -and (Test-Path -LiteralPath $tb6InstPath -PathType Leaf)) {
    $tb6RootB = [System.IO.File]::ReadAllBytes($tb6RootQs)
    $tb6PkgB = [System.IO.File]::ReadAllBytes($tb6PkgQs)
    $tb6ShaRoot = [System.BitConverter]::ToString(([System.Security.Cryptography.SHA256]::Create()).ComputeHash([byte[]]$tb6RootB)).Replace('-', '')
    $tb6ShaPkg = [System.BitConverter]::ToString(([System.Security.Cryptography.SHA256]::Create()).ComputeHash([byte[]]$tb6PkgB)).Replace('-', '')
    $tb6InstText = [string]([System.IO.File]::ReadAllText($tb6InstPath, [System.Text.Encoding]::UTF8))
    $tb6InstNeedles = @('$srcQuickStart = Join-Path $PSScriptRoot', 'if (-not (Test-Path -LiteralPath $srcQuickStart -PathType Leaf)) { $missing += $srcQuickStart }', 'Copy-Item -LiteralPath $srcQuickStart', 'exit 3')
    $tb6Bad2 = @()
    if (@($tb6InstNeedles).Count -ne 4) { $tb6Bad2 += ('the installer needle list lost its own shape: ' + @($tb6InstNeedles).Count) }
    if ($tb6RootB.Length -lt 2000) { $tb6Bad2 += ('repository-root guide is only ' + $tb6RootB.Length + ' bytes') }
    if ($tb6RootB.Length -ne $tb6PkgB.Length) { $tb6Bad2 += ('carrier is ' + $tb6PkgB.Length + ' bytes, root guide is ' + $tb6RootB.Length) }
    if ($tb6ShaRoot -cne $tb6ShaPkg) { $tb6Bad2 += ('carrier differs from the repository-root guide: root=' + $tb6ShaRoot + ' carrier=' + $tb6ShaPkg) }
    foreach ($tb6IN in $tb6InstNeedles) { if (-not $tb6InstText.Contains([string]$tb6IN)) { $tb6Bad2 += ('installer lacks: ' + [string]$tb6IN) } }
    # Presence is not POSITION. The shape that was actually wrong carried both the refusal and the copy
    # in the same file - just after the first write, so a package with no carrier still landed an entry
    # document whose newcomer link dangles. The order is measured off the same text, and a -1 is
    # refused, so a missing needle cannot win the comparison by sorting before everything.
    $tb6RefusalAt = $tb6InstText.IndexOf('$missing += $srcQuickStart')
    $tb6FirstWriteAt = $tb6InstText.IndexOf('New-Item -ItemType Directory -Path $scriptsDir')
    $tb6OrderOk = (($tb6RefusalAt -ge 0) -and ($tb6FirstWriteAt -ge 0) -and ($tb6RefusalAt -lt $tb6FirstWriteAt))
    if (-not $tb6OrderOk) { $tb6Bad2 += ('the carrier is not refused before the first write: refusal at ' + $tb6RefusalAt + ', first write at ' + $tb6FirstWriteAt) }
    ST-Check 'lint (TB-6): the quick-start guide ships inside the skill package as a byte-for-byte copy of the repository-root document, and the installer resolves it from the package, refuses the install when it is absent (before its first write) and copies it beside the entry doc' (
      (@($tb6Bad2).Count -eq 0))
    foreach ($tb6B2 in @($tb6Bad2)) { Write-Output ('      TB-6 delivery: ' + [string]$tb6B2) }
    Write-Output ('      TB-6 copies sha256: root=' + $tb6ShaRoot + ' carrier=' + $tb6ShaPkg + ' bytes=' + $tb6RootB.Length + '/' + $tb6PkgB.Length)
    Write-Output ('      TB-6 installer order: refusal char ' + $tb6RefusalAt + ' < first write char ' + $tb6FirstWriteAt)
    # Teeth, both arms: rub the refusal and the copy step out of an in-memory installer and re-run the
    # SAME needles - they must come back missing AND the refusal-before-write test must stop holding.
    # Then flip ONE byte at the end of the carrier and re-hash - the identity comparison must be able
    # to say 'different', or the check above is a length test wearing a hash costume.
    $tb6MutInst = $tb6InstText.Replace('if (-not (Test-Path -LiteralPath $srcQuickStart -PathType Leaf)) { $missing += $srcQuickStart }', 'if ($false) {').Replace('Copy-Item -LiteralPath $srcQuickStart', 'Set-Content -Value 1')
    $tb6MutLack = @($tb6InstNeedles | Where-Object { -not $tb6MutInst.Contains([string]$_) })
    $tb6MutRefusalAt = $tb6MutInst.IndexOf('$missing += $srcQuickStart')
    $tb6MutOrderOk = (($tb6MutRefusalAt -ge 0) -and ($tb6MutRefusalAt -lt $tb6MutInst.IndexOf('New-Item -ItemType Directory -Path $scriptsDir')))
    $tb6PlantB = [byte[]]$tb6PkgB.Clone()
    $tb6PlantB[($tb6PlantB.Length - 1)] = [byte]((([int]$tb6PlantB[($tb6PlantB.Length - 1)]) + 1) -band 255)
    $tb6ShaPlant = [System.BitConverter]::ToString(([System.Security.Cryptography.SHA256]::Create()).ComputeHash([byte[]]$tb6PlantB)).Replace('-', '')
    ST-Check 'lint (TB-6): the delivery predicate flags the planted installer copy that drops both the refusal and the copy step, loses the refusal-before-first-write order, and the one-byte carrier mutation changes the hash (teeth, not decoration)' (
      (@($tb6MutLack).Count -ge 2) -and (-not $tb6MutOrderOk) -and ($tb6ShaPlant -cne $tb6ShaPkg) -and ($tb6ShaRoot -ceq $tb6ShaPkg) -and ($tb6PlantB.Length -eq $tb6PkgB.Length))
    Write-Output ('      TB-6 planted installer flags: ' + (@($tb6MutLack).Count) + ' | refusal-before-write on the plant: ' + $tb6MutOrderOk + ' | planted carrier sha: ' + $tb6ShaPlant)
  } else {
    ST-Skip 'lint (TB-6): the quick-start guide ships inside the skill package as a byte-for-byte copy of the repository-root document, and the installer resolves it from the package, refuses the install when it is absent (before its first write) and copies it beside the entry doc' 'no skill package / installer in this tree - the loader scripts and the root document ship with the repository, never beside the stitched artifact'
    ST-Skip 'lint (TB-6): the delivery predicate flags the planted installer copy that drops both the refusal and the copy step, loses the refusal-before-first-write order, and the one-byte carrier mutation changes the hash (teeth, not decoration)' 'no skill package / installer in this tree - nothing to plant into'
  }

}
