# lib/selftest-repo-contract.ps1 - one family of the selftest section, lifted out of lib/selftest.ps1 by A-14b (A-beta).
# Bodies are byte-identical to what the section carried; this file exists so that a family of
# checks can be read, moved and counted on its own. The only channel to the orchestrator is the
# explicit context object: shared state arrives through $Ctx and nothing else, because the
# dynamic-scope chain that used to feed these lines is exactly the implicit link A-08/A-09/A-11
# proved can break silently on a move.
# Family: the repository contract - the version tokens in their four carriers, the tracked-file
function Invoke-SelftestFamily-RepoContract($Ctx) {
  # context handover (the one thing in this file that is not lifted text)
  $self = [string]$Ctx['self']
  $src = [string]$Ctx['src']
#   inventory and the offline-check total this version declares. These are the checks that only
#   mean something inside a checkout, and they are the reason $script:ToolRootPath exists.
  # ---------- lint: version number sync across the 4 locations ----------
  # Spec section 6 wants a machine guard on the version sync list. ASCII-only
  # implementation: the two CJK-named docs are located by "the .md files that
  # are not README.md" (exact count asserted first), and each is checked by its
  # FIRST vX.Y.Z token within the first 12 lines (overview header line 3,
  # iteration log latest-entry heading line 7 - keep those shapes).
  $vMain = 'missing'
  if ($src -match '(?m)^# version: ([0-9.]+)') { $vMain = $Matches[1] }
  $vUsage = 'missing'
  if ($src -match 'desktop\.ps1 v([0-9.]+) - Windows') { $vUsage = $Matches[1] }
  ST-Check 'version: desktop.ps1 header == Usage banner' (($vMain -ne 'missing') -and ($vUsage -eq $vMain))
  # v2.5.0: the block below pins the REPOSITORY-level contract (version carriers +
  # tracked inventory). From an installed copy - the skill ships desktop.ps1 on its
  # own - there is no repository to check, so these checks report SKIP with a reason
  # instead of FAIL. Inside a checkout (even with files deleted) they run as before.
  $isRepoRoot = $false
  try {
    $tl = @(& git -C $script:ToolRootPath rev-parse --show-toplevel 2>$null)
    if (@($tl).Count -ge 1) {
      $tlNorm = ("$($tl[0])" -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
      $prNorm = ("$script:ToolRootPath" -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
      if ($tlNorm -eq $prNorm) { $isRepoRoot = $true }
    }
  } catch { $isRepoRoot = $false }
  # the authority-set helper, pinned BEFORE the guard that uses it: a tracked name must survive,
  # an untracked marker doc must be dropped AND named, and "no git" must fall back to the disk
  # list with the mode labelled - not read as "nothing is tracked", which would have turned this
  # guard red on every machine where git had a bad moment.
  # v4.1.3 (external review A, the third silent-drop family): these three are PURE unit checks
  # on synthetic inputs - they never touch git - but they sat INSIDE the repository-checkout
  # guard below, so a box where git is unresolvable lost three checks silently (measured:
  # context C and D both drop exactly these three). They moved out, so the guard now covers
  # only the checks that genuinely need a checkout.
  $adKeep = Split-AuthorityDocNames @('READMEX.md', 'review-report.md') @('READMEX.md') $true
  $adNoGit = Split-AuthorityDocNames @('READMEX.md', 'review-report.md') @() $false
  $adAll = Split-AuthorityDocNames @('READMEX.md') @('READMEX.md') $true
  ST-Check 'unit: authority docs - an untracked marker doc is dropped and reported, never silently' (
    (@($adKeep.Kept) -contains 'READMEX.md') -and (-not (@($adKeep.Kept) -contains 'review-report.md')) -and
    (@($adKeep.Dropped) -contains 'review-report.md') -and ($adKeep.Mode -eq 'tracked'))
  ST-Check 'unit: authority docs - no git falls back to the disk list and says which mode it used' (
    ($adNoGit.Mode -eq 'disk-fallback') -and (@($adNoGit.Kept).Count -eq 2) -and (@($adNoGit.Dropped).Count -eq 0))
  ST-Check 'unit: authority docs - a fully tracked authority set is kept whole (the normal case, so the two above cannot pass by dropping everything)' (
    (@($adAll.Kept).Count -eq 1) -and (@($adAll.Dropped).Count -eq 0))
  $skipNoRepo = 'not a repository checkout - repository-level check does not apply (installed copy)'
  if ($isRepoRoot) {
  $readmePath = Join-Path $script:ToolRootPath 'README.md'
  $vReadme = 'missing'
  if (Test-Path $readmePath) {
    $rl1 = Get-Content -LiteralPath $readmePath -TotalCount 1
    if ($rl1 -match 'v([0-9.]+)') { $vReadme = $Matches[1] }
  }
  ST-Check 'version: README H1 == desktop.ps1 header' ($vReadme -eq $vMain)
  # Authority docs are identified by content (their first line mentions
  # desktop.ps1), not by counting .md files - the repo root now also carries
  # task-order docs (e.g. the v1.5.0 work order) that must not participate in
  # the version check. -Encoding UTF8 is mandatory: read as ANSI/GBK, a
  # fullwidth bracket's UTF-8 bytes swallow the following ASCII 'd' and the
  # marker regex silently misses.
  $mdDisk = @(Get-ChildItem -LiteralPath $script:ToolRootPath -Filter '*.md' | ForEach-Object { $_.Name } | Where-Object { $_ -ne 'README.md' })
  # -z, because this repo's tracked names are CJK and the quoted form is not comparable.
  $trackedMd = @(); $haveTracked = $false
  try {
    $lsRaw = & git -C $script:ToolRootPath ls-files -z '*.md' 2>$null
    if ($LASTEXITCODE -eq 0) {
      $haveTracked = $true
      $trackedMd = @(($lsRaw -join ([string][char]0)) -split [char]0 | ForEach-Object { "$_".Trim() } | Where-Object { "$_" -ne '' })
    }
  } catch { $haveTracked = $false }
  $authSet = Split-AuthorityDocNames $mdDisk $trackedMd $haveTracked
  if (@($authSet.Dropped).Count -gt 0) {
    Write-Output ('      authority docs: ignored untracked (not part of the authority surface): ' + (@($authSet.Dropped) -join ' '))
  }
  $mds = @(Get-ChildItem -LiteralPath $script:ToolRootPath -Filter '*.md' | Where-Object {
    (@($authSet.Kept) -contains $_.Name) -and ((Get-Content -LiteralPath $_.FullName -TotalCount 1 -Encoding UTF8) -match 'desktop\.ps1')
  })
  # v4.5.5 (OSS-03): the public open-source layout deliberately ships neither authority doc.
  # The public skip below is keyed on POSITIVE public markers (src/ source entry + OSS README
  # H1 + both named docs absent) - never on mere absence - so deleting an authority doc inside
  # the internal checkout still fails these checks exactly as before.
  $ovName = "$([char]0x9879)$([char]0x76EE)$([char]0x603B)$([char]0x89C8).md"
  $ilogName = "$([char]0x8FED)$([char]0x4EE3)$([char]0x65E5)$([char]0x5FD7).md"
  $pubReadmeH1 = ''
  if (Test-Path -LiteralPath $readmePath) { $pubReadmeH1 = [string](Get-Content -LiteralPath $readmePath -TotalCount 1) }
  $isPublicLayout = ((Test-Path -LiteralPath (Join-Path $script:ToolRootPath 'src/desktop.ps1')) -and
    ($pubReadmeH1 -match 'Open Source Edition') -and
    (-not (Test-Path -LiteralPath (Join-Path $script:ToolRootPath $ovName))) -and
    (-not (Test-Path -LiteralPath (Join-Path $script:ToolRootPath $ilogName))))
  $skipPublicAuth = 'public open-source layout: the internal authority docs (overview + iteration log) are deliberately not shipped - their version pins are carried by the README H1s and the CHANGELOG top entry in this layout'
  if ($isPublicLayout) {
    ST-Skip 'version: exactly two content-marked authority docs (first line mentions desktop.ps1)' $skipPublicAuth
  } else {
    ST-Check 'version: exactly two content-marked authority docs (first line mentions desktop.ps1)' ($mds.Count -eq 2)
  }
  # Positive named guard (v1.5.0 residual): a content-only enumeration still
  # passes if a doc is RENAMED to another .md that keeps the marker on line 1.
  # Pin the two expected names; code points keep this file pure ASCII.
  if ($isPublicLayout) {
    ST-Skip 'version: named authority docs exist (overview + iteration log)' $skipPublicAuth
  } else {
    ST-Check 'version: named authority docs exist (overview + iteration log)' (
      (Test-Path -LiteralPath (Join-Path $script:ToolRootPath $ovName)) -and (Test-Path -LiteralPath (Join-Path $script:ToolRootPath $ilogName)))
  }
  $mdOk = ($mds.Count -eq 2)
  foreach ($m in $mds) {
    $head = (Get-Content -LiteralPath $m.FullName -TotalCount 12 -Encoding UTF8) -join "`n"
    $v = 'missing'
    if ($head -match 'v([0-9.]+)') { $v = $Matches[1] }
    if ($v -ne $vMain) { $mdOk = $false }
  }
  if ($isPublicLayout) {
    ST-Skip 'version: overview header + iteration log latest entry == desktop.ps1 header' $skipPublicAuth
  } else {
    ST-Check 'version: overview header + iteration log latest entry == desktop.ps1 header' $mdOk
  }
  } else {
    ST-Skip 'version: README H1 == desktop.ps1 header' $skipNoRepo
    ST-Skip 'version: exactly two content-marked authority docs (first line mentions desktop.ps1)' $skipNoRepo
    ST-Skip 'version: named authority docs exist (overview + iteration log)' $skipNoRepo
    ST-Skip 'version: overview header + iteration log latest entry == desktop.ps1 header' $skipNoRepo
  }

  # ---------- v4.5.5 (TB-1): the version definition, the entry header and the runtime source_version are one source ----------
  # The constant had drifted to 4.5.3 against a 4.5.5 header while the four checks above compared
  # only the prose carriers - nothing pinned the definition the caller runtime actually writes into
  # its records. Three checks close it: the live single-source lint, the record-level source_version
  # flow, and the three planted counterexamples (missing / wrong value / frozen write).
  $tb1HeaderCount = @([regex]::Matches([string]$src, '(?m)^# version: [0-9.]+')).Count
  $tb1DefPattern = '(?m)^\s*\' + [char]0x24 + 'script:ToolVersion\s*=\s*' + [char]39 + '([^' + [char]39 + ']+)' + [char]39
  $tb1Defs = @([regex]::Matches([string]$src, $tb1DefPattern))
  $tb1DefValue = 'missing'
  if ($tb1Defs.Count -ge 1) { $tb1DefValue = [string]$tb1Defs[0].Groups[1].Value }
  ST-Check 'lint (TB-1): the version definition is non-empty, assigned exactly once, the header declares its version exactly once, and definition == header == Usage banner == the version the orchestrator published' (
    ($tb1Defs.Count -eq 1) -and ($tb1DefValue -cmatch '^[0-9]+\.[0-9]+\.[0-9]+$') -and
    ($tb1HeaderCount -eq 1) -and ($tb1DefValue -ceq $vMain) -and ($vMain -ceq $vUsage) -and
    ($tb1DefValue -ceq [string]$Ctx['ToolVersion']))
  Write-Output ('      TB-1 sources: definition=' + $tb1DefValue + ' header=' + $vMain + ' usage=' + $vUsage + ' ctx=' + [string]$Ctx['ToolVersion'] + ' headerCount=' + $tb1HeaderCount)

  # The record-level half: the caller runtime must write the version it resolved - an explicit
  # context override wins, the no-context path falls back to the entry's loaded definition, and the
  # record carries that value in source_version. Fixture machinery mirrors the gate-meta caller
  # fixtures: a unique temp RootBase inside the system temp root, everything released in finally.
  $tb1Lease = $null
  $tb1Root = Join-Path $env:TEMP ('dtx-tb1-source-version-' + [guid]::NewGuid().ToString('N'))
  $tb1OwnRoot = $false
  $tb1OverrideWritten = 'not-run'
  $tb1FallbackWritten = 'not-run'
  try {
    $tb1TempExpect = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92) + [IO.Path]::DirectorySeparatorChar
    if (-not ([IO.Path]::GetFullPath($tb1Root)).StartsWith($tb1TempExpect, [StringComparison]::OrdinalIgnoreCase)) { throw 'refusing a probe path outside the system temp root' }
    New-Item -Path $tb1Root -ItemType Directory -ErrorAction Stop | Out-Null
    $tb1OwnRoot = $true
    $tb1Parent = [pscustomobject]@{ ParentPid = 0; ParentName = 'unknown'; ParentStartUtc = ''; ParentStartFileTime = ''; Known = $false }
    $tb1OverrideCtx = [ordered]@{
      RootBase = $tb1Root
      WindowsSessionId = '771'
      DesktopName = 'Default'
      CallerLabel = 'TB1-override'
      CallerSessionId = 'source-version'
      IdentitySource = 'selftest-explicit'
      ParentInfo = $tb1Parent
      SourcePath = 'D:\synthetic\tb1.ps1'
      ToolVersion = '9.9.9-tb1-fixture'
    }
    $tb1Lease = Start-DtxCallTracking 'info' @('tb1-override-probe') $tb1OverrideCtx
    if ($null -eq $tb1Lease) { throw 'TB-1 override fixture did not register' }
    $tb1OverrideWritten = [string]$tb1Lease.Record.source_version
    Complete-DtxCallTracking $tb1Lease 'completed' 0 ''
    $tb1Lease = $null
    $tb1FallbackCtx = [ordered]@{
      RootBase = $tb1Root
      WindowsSessionId = '772'
      DesktopName = 'Default'
      CallerLabel = 'TB1-fallback'
      CallerSessionId = 'source-version'
      IdentitySource = 'selftest-explicit'
      ParentInfo = $tb1Parent
      SourcePath = 'D:\synthetic\tb1.ps1'
    }
    $tb1Lease = Start-DtxCallTracking 'info' @('tb1-fallback-probe') $tb1FallbackCtx
    if ($null -eq $tb1Lease) { throw 'TB-1 fallback fixture did not register' }
    $tb1FallbackWritten = [string]$tb1Lease.Record.source_version
    Complete-DtxCallTracking $tb1Lease 'completed' 0 ''
    $tb1Lease = $null
    ST-Check 'unit (TB-1): the caller record writes the resolved version - an explicit fixture override wins and the no-context path carries the version the orchestrator published (the definition, not a frozen literal)' (
      ($tb1OverrideWritten -ceq '9.9.9-tb1-fixture') -and
      ($tb1FallbackWritten -ceq [string]$Ctx['ToolVersion']) -and
      ($tb1FallbackWritten -ceq $tb1DefValue))
    Write-Output ('      TB-1 records: override=' + $tb1OverrideWritten + ' fallback=' + $tb1FallbackWritten)
  } finally {
    if ($null -ne $tb1Lease) { Complete-DtxCallTracking $tb1Lease 'completed' 0 ''; $tb1Lease = $null }
    if ($tb1OwnRoot) { Remove-Item -LiteralPath $tb1Root -Recurse -Force -ErrorAction SilentlyContinue }
  }

  # The teeth: the same three questions the live lint asks, run against planted copies - a source
  # without the definition, a definition on the wrong value, and a writer that freezes the version
  # as a literal so a later definition change would not reach the records. A matching control
  # passes, so the detector is a comparison and not an always-red hammer.
  $tb1PlantDetector = {
    param([string]$PlantSource, [string]$PlantHeader, [string]$PlantWritten)
    $pd = @([regex]::Matches([string]$PlantSource, ('(?m)^\s*\' + [char]0x24 + 'script:ToolVersion\s*=\s*' + [char]39 + '([^' + [char]39 + ']+)' + [char]39)))
    if ($pd.Count -eq 0) { return 'definition-missing' }
    if ($pd.Count -gt 1) { return 'definition-not-once' }
    $pdValue = [string]$pd[0].Groups[1].Value
    if ($pdValue -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { return 'definition-malformed' }
    if ($pdValue -cne [string]$PlantHeader) { return 'definition-header-mismatch' }
    if (([string]$PlantWritten -ne '') -and ([string]$PlantWritten -cne $pdValue)) { return 'frozen-write-rejected' }
    return ''
  }
  $tb1Dollar = [char]0x24
  $tb1Quote = [char]39
  $tb1PlantMissing = 'an entry body whose definition line was removed'
  $tb1PlantWrong = $tb1Dollar + 'script:ToolVersion = ' + $tb1Quote + '0.0.0' + $tb1Quote
  $tb1PlantFrozenDef = $tb1Dollar + 'script:ToolVersion = ' + $tb1Quote + '5.5.5' + $tb1Quote
  $tb1LiveSource = $tb1Dollar + 'script:ToolVersion = ' + $tb1Quote + [string]$Ctx['ToolVersion'] + $tb1Quote
  $tb1PlantFlags = @(
    (& $tb1PlantDetector $tb1PlantMissing ([string]$Ctx['ToolVersion']) ''),
    (& $tb1PlantDetector $tb1PlantWrong ([string]$Ctx['ToolVersion']) '0.0.0'),
    (& $tb1PlantDetector $tb1PlantFrozenDef '5.5.5' '0.0.0'),
    (& $tb1PlantDetector $tb1LiveSource ([string]$Ctx['ToolVersion']) ([string]$Ctx['ToolVersion']))
  )
  ST-Check 'unit (TB-1): the planted missing-definition, wrong-value and frozen-literal copies are each rejected by the detector comparison (the live lint asks the same three questions inline, it does not call this detector), and a matching control passes' (
    ($tb1PlantFlags[0] -ceq 'definition-missing') -and
    ($tb1PlantFlags[1] -ceq 'definition-header-mismatch') -and
    ($tb1PlantFlags[2] -ceq 'frozen-write-rejected') -and
    ($tb1PlantFlags[3] -ceq ''))
  Write-Output ('      TB-1 plants: ' + ($tb1PlantFlags -join ' / '))

  # ---------- lint: the tracked-file count written in the overview IS the real one ----------
  # 2026-10-01 round-3 finding: this number drifted three times in one day (9, then 17,
  # then written as 15 while the tree held 16) and nothing noticed, because it was prose
  # no gate measured - a cold-starting agent reads the inventory line and inherits the
  # wrong count. Pinned: the overview must carry tracked=<N> and N must equal git ls-files.
  if ($isRepoRoot) {
  $tfDoc = -1
  if ($isPublicLayout) {
    # v4.5.5 (OSS-03): in the public layout the tracked= line lives in both README editions
    # (there is no overview doc), and the assertion stays real: each edition must carry the
    # number and both must equal git ls-files ($tfDoc=-2 marks a disagreement between editions).
    foreach ($rn in @('README.md', 'README.zh-CN.md')) {
      foreach ($l in @(Get-Content -LiteralPath (Join-Path $script:ToolRootPath $rn) -Encoding UTF8)) {
        if ("$l" -match 'tracked=(\d+)') {
          $rn2 = [int]$Matches[1]
          if ($tfDoc -eq -1) { $tfDoc = $rn2 } elseif ($tfDoc -ne $rn2) { $tfDoc = -2 }
          break
        }
      }
    }
    Write-Output ('      tracked-file inventory: public layout - tracked= is read from both README editions')
  } else {
    foreach ($m in $mds) {
      foreach ($l in @(Get-Content -LiteralPath $m.FullName -Encoding UTF8)) {
        if ("$l" -match 'tracked=(\d+)') { $tfDoc = [int]$Matches[1]; break }
      }
    }
  }
  $tfReal = 0
  try { $tfReal = @((& git -C $script:ToolRootPath ls-files 2>$null) | Where-Object { "$_" -ne '' }).Count } catch { $tfReal = 0 }
  ST-Check 'lint: the overview states the tracked-file count and it equals git ls-files (no stale inventory)' (
    ($tfDoc -gt 0) -and ($tfReal -gt 0) -and ($tfDoc -eq $tfReal))
  Write-Output ("      tracked files: doc=$tfDoc git=$tfReal")
  # ---------- v4.1.3: tracked in the INDEX is not the same as present on the DISK ----------
  # Found the hard way, during this very round: thirteen tracked task-order documents were
  # deleted from this working tree while the gate was running, and nothing noticed. The lint
  # above reads `git ls-files`, which answers from the INDEX - an unstaged deletion is
  # invisible to it. That is the same disease this version is about: "cannot see it" reported
  # as "nothing wrong". The two views must now agree, and every missing name is printed.
  $tfOnDisk = @()
  try {
    $tfRaw = & git -C $script:ToolRootPath ls-files -z 2>$null
    if ($LASTEXITCODE -eq 0) {
      $tfOnDisk = @((($tfRaw -join ([string][char]0)) -split [char]0 | ForEach-Object { "$_".Trim() } | Where-Object { "$_" -ne '' }))
    }
  } catch { $tfOnDisk = @() }
  $tfMissing = @($tfOnDisk | Where-Object { -not (Test-Path -LiteralPath (Join-Path $script:ToolRootPath "$_")) })
  # The predicate gets a planted absent name, because a check that passes by measuring an
  # empty set is exactly the failure mode being fixed here.
  $tfPlantCaught = 0
  foreach ($tfName in @('DTX-no-such-tracked-file-ZQX.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $script:ToolRootPath "$tfName"))) { $tfPlantCaught++ }
  }
  ST-Check 'lint: every name tracked in the index exists on disk (an unstaged deletion cannot read as "nothing wrong")' (
    (@($tfOnDisk).Count -gt 0) -and (@($tfMissing).Count -eq 0))
  ST-Check 'lint: the tracked-on-disk predicate flags a planted absent name (the check above cannot pass by seeing nothing)' (
    $tfPlantCaught -eq 1)
  if (@($tfMissing).Count -gt 0) { Write-Output ("      tracked but absent on disk (" + @($tfMissing).Count + '): ' + ((@($tfMissing) | Sort-Object) -join ', ')) }
  Write-Output ('      tracked inventory: index=' + @($tfOnDisk).Count + ' present=' + (@($tfOnDisk).Count - @($tfMissing).Count))
  } else {
    ST-Skip 'lint: the overview states the tracked-file count and it equals git ls-files (no stale inventory)' $skipNoRepo
    ST-Skip 'lint: every name tracked in the index exists on disk (an unstaged deletion cannot read as "nothing wrong")' $skipNoRepo
    ST-Skip 'lint: the tracked-on-disk predicate flags a planted absent name (the check above cannot pass by seeing nothing)' $skipNoRepo
  }

  # ---------- lint: the overview header's offline-check total IS the declaration in this file ----------
  # F-01 (supervisor, 2026-10-05). The overview has carried "N checks" as prose since v3.0.0 and
  # nothing compared it: it sat at 777 across two batches while the file declared 785, with the
  # whole suite green the entire time. Same disease the tracked-file count had before it was
  # pinned - a number a human maintains is a number that drifts. Built from code points so this
  # file stays pure ASCII, and the MATCH IS COUNTED: a scan that found nothing fails, it may not
  # pass by reading an empty set (pit: a zero-hit assertion needs a planted sample that hits 1).
  $ocTotalSeen = -1
  $ocOvName = "$([char]0x9879)$([char]0x76EE)$([char]0x603B)$([char]0x89C8).md"
  $ocOvPath = Join-Path $script:ToolRootPath $ocOvName
  $ocPat = '^> .*' + [string]::Join('', @([char]0x79BB, [char]0x7EBF, [char]0x5224, [char]0x636E)) + ' \*\*([0-9]+) ' + [string]([char]0x6761)
  $ocHave = Test-Path -LiteralPath $ocOvPath
  if ($ocHave) {
    foreach ($ocL in @(Get-Content -LiteralPath $ocOvPath -Encoding UTF8)) {
      if ("$ocL" -match $ocPat) { $ocTotalSeen = [int]$Matches[1]; break }
    }
  }
  # The overview is an INTERNAL document - the published tree does not carry it. A check that
  # reads it must SKIP there (naming why), not sit structurally red: measured when the v3.1.0
  # sync first ran the public tree, this case failed with doc=-1 because no such file exists.
  # In a tree that DOES have the overview, "present but unmatched" still fails (doc=-1).
  if ($ocHave) {
    ST-Check 'lint (F-01): the overview header states the offline check total and it equals DeclaredCheckTotal (no human-maintained number survives)' (
      ($ocTotalSeen -gt 0) -and ($ocTotalSeen -eq [int]$script:DeclaredCheckTotal))
  } else {
    ST-Skip 'lint (F-01): the overview header states the offline check total and it equals DeclaredCheckTotal (no human-maintained number survives)' 'no internal overview in this tree - the published tree does not carry it'
  }
  Write-Output ("      overview check total: doc=$ocTotalSeen declared=$($script:DeclaredCheckTotal)")

}
