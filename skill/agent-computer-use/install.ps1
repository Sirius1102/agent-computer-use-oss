# install.ps1 - load the agent-computer-use skill into an agent skill directory.
#
# Usage (run from inside the repository):
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -TargetDir <path>
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -RepoRoot <path> -SkipSelftest
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -StitchTo <artifact.ps1>
#     (-StitchTo builds the single-file deliverable from the split tree and stops: nothing is resolved,
#      created, copied, registered or smoke-tested)
#
# Target resolution - first match wins, nothing is guessed:
#   1. -TargetDir <path>
#   2. environment variable AGENT_COMPUTER_USE_SKILL_DIR
#   3. first EXISTING directory of:
#        %APPDATA%\LobsterAI\SKILLs
#        %USERPROFILE%\.cursor\skills
#        <RepoRoot>\.cursor\skills
#   All missing -> the script stops with instructions; it never creates a guess.
#
# Installed layout (idempotent - only this skill's own files are touched):
#   <Target>\agent-computer-use\SKILL.md
#   <Target>\agent-computer-use\reference.md            (when present in the repo)
#   <Target>\agent-computer-use\快速上手指南.md          (MANDATORY - TB-⑥: this is what SKILL.md's
#                                                        quick-start link points at, the link has to
#                                                        resolve in the INSTALLED layout, and a package
#                                                        without this carrier is refused before the
#                                                        first write)
#   <Target>\agent-computer-use\scripts\desktop.ps1     (stitched from <RepoRoot>\desktop.ps1 + lib\*.ps1)
# When <Target>\skills.config.json exists it is updated with
#   "agent-computer-use": { "order": 205, "enabled": true }
# inside "defaults" (other entries are preserved; note: the file is rewritten via a
# JSON round-trip, so formatting may normalize while every value stays the same).
#
# Smoke test: runs "desktop.ps1 selftest" and "desktop.ps1 help" and prints their
# output verbatim. Any non-zero exit -> "installed, but the smoke test did not
# pass" and exit 1. (-SkipSelftest skips it.)
#
# Exit codes:
#   0  installed (and smoke test passed, unless skipped)
#   1  installed, but the smoke test did NOT pass
#   2  no target directory could be resolved
#   3  source files missing (run from inside the repository)
#   4  the stitcher refused (a declared lib file is missing, a marker path is not lib/<name>.ps1, the
#      marker accounting does not close, a dot-import still executes in the artifact, the artifact is not
#      pure ASCII or does not parse, or the marker set does not converge) - desktop.ps1 was not installed

param(
  [string]$TargetDir = '',
  [string]$RepoRoot = '',
  [switch]$SkipSelftest,
  [string]$StitchTo = ''
)

# v3.0.1 (external audit item 23): the project's three hard guards, applied as far as this
# script's job allows. Set-StrictMode catches the typo-a-variable class in a script that
# moves files around - an unset variable here is a path that silently becomes empty.
# $ErrorActionPreference deliberately stays 'Continue': this installer reports every problem
# it collected and exits with a CODE (see the usage block), and a terminating first error
# would leave a half-copied skill behind, which is the worse failure. The deviation is a
# choice, not an oversight, and selftest pins both lines so neither can drift away.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Say([string]$m) { Write-Host $m }

#
# A-21 (v6 3.4): the single-file deliverable is BUILT, not copied. The split tree loads its lib files by
#    one-line dot-imports that each carry a stitch marker; the stitcher below replaces every such line
#    with the whole text of the file it names and leaves every other byte alone, so the artifact is the
#    same program the source tree runs - and the source tree stays a valid one-file-per-section layout.
#    Refusals are part of the contract: a declared file that is not on disk, a name that is not
#    lib/<file>.ps1 (this is a path taken from a comment, it is not trusted), marker accounting that
#    does not close, a dot-import that still executes in the artifact, an artifact that is not pure
#    ASCII or does not parse, or a recursion that does not converge.
function Get-StitchedDesktop([string]$Root) {
  $markerTail = '<<< ' + 'stitch: '
  $readLines = { param($p) @(([System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)) -split "`n") }
  $countMarker = { param($arr) $n = 0; foreach ($x in $arr) { if (([string]$x).Contains($markerTail)) { $n = $n + 1 } }; $n }
  $cur = & $readLines (Join-Path $Root 'desktop.ps1')
  $markerIn = & $countMarker @($cur)
  $markerBrought = 0
  $expanded = 0
  $pass = 0
  while ($true) {
    $pass = $pass + 1
    if ($pass -gt 6) { throw 'stitch: the marker set did not converge in 6 passes - refusing to emit a half-expanded file' }
    $next = @()
    $went = 0
    for ($i = 0; $i -lt $cur.Count; $i++) {
      $line = [string]$cur[$i]
      $at = $line.IndexOf($markerTail)
      $isDotImport = $line.TrimStart().StartsWith('. (Join-Path')
      if (($at -lt 0) -or (-not $isDotImport)) { $next += $line; continue }
      $rel = ([string]$line.Substring($at + $markerTail.Length)).Trim().TrimEnd([char]39).Trim()
      if ($rel -notmatch '^lib/[A-Za-z0-9._-]+\.ps1$') { throw ('stitch: marker names a path I will not read: [' + $rel + ']') }
      $path = Join-Path $Root $rel
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('stitch: declared file is not on disk: ' + $rel) }
      $add = & $readLines $path
      $markerBrought = $markerBrought + (& $countMarker @($add))
      $next += $add
      $went = $went + 1
    }
    $expanded = $expanded + $went
    $cur = $next
    if ($went -eq 0) { break }
  }
  #    The accounting identity is the proof that nothing was left half-expanded. A blanket "the marker is
  #    gone" rule is not available and was the first version of this function - it refused on its own
  #    tree, because selftest-split-machine.ps1 keeps three fixture lines that quote a dot-import as
  #    DATA, so markers legitimately survive in the artifact. What must be zero is a marker attached to
  #    code: in minus out plus what the lib files brought in has to equal the number of lines expanded.
  $markerOut = & $countMarker @($cur)
  if (($markerIn + $markerBrought - $markerOut) -ne $expanded) {
    throw ('stitch: marker accounting does not close (in=' + $markerIn + ' brought=' + $markerBrought + ' out=' + $markerOut + ' expanded=' + $expanded + ')')
  }
  $residue = 0
  foreach ($l in @($cur)) {
    #    Any dot-source of a lib path is residue however it is spaced. The first version of this rule
    #    tested the literal '. (Join-Path' - one space after the open parenthesis hid a still-executing
    #    import from it (and from the expander, which keys on the same literal), so the artifact would
    #    have been installed referencing a file that is not there.
    $t = [string]$l
    if (($t -match '^\s*\.\s') -and ($t -match 'lib[\\/][A-Za-z0-9._-]+\.ps1')) { $residue = $residue + 1 }
  }
  if ($residue -gt 0) { throw ('stitch: ' + $residue + ' dot-import line(s) still execute in the artifact') }
  $text = (@($cur) -join "`n")
  if (([regex]::Matches($text, '[^\x00-\x7F]')).Count -gt 0) { throw 'stitch: the artifact is not pure ASCII (the BOM is added on write)' }
  $perr = $null
  [void][System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$perr)
  if (@($perr).Count -gt 0) { throw ('stitch: the artifact does not parse - ' + @($perr).Count + ' error(s), first: ' + $perr[0].Message) }
  return $text
}

# ---------- locate sources ----------
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  # The public release keeps the built artifact at the repo root and the build sources under src/;
  # the in-repo development tree keeps desktop.ps1 at the root. First existing wins, nothing is guessed.
  $srcRoot = Join-Path $projectRoot 'src'
  if (Test-Path -LiteralPath (Join-Path $srcRoot 'desktop.ps1') -PathType Leaf) {
    $RepoRoot = $srcRoot
  } else {
    $RepoRoot = $projectRoot
  }
}
$srcSkill = Join-Path $PSScriptRoot 'SKILL.md'
$srcRef = Join-Path $PSScriptRoot 'reference.md'
# TB-⑥: the quick-start guide is the FIRST document the loader doc points a newcomer at, and that
#    link is written relative to SKILL.md. Shipping the file next to the installed SKILL.md is what
#    makes the link resolve in the layout an agent actually reads - the repo layout is not it. It
#    ships from THIS directory (the package carrier), so what installs is what the link names; an
#    offline check pins this carrier byte-for-byte against the repository-root copy.
$srcQuickStart = Join-Path $PSScriptRoot '快速上手指南.md'
$srcDesktop = Join-Path $RepoRoot 'desktop.ps1'

$missing = @()
foreach ($f in @($srcSkill, $srcDesktop)) { if (-not (Test-Path -LiteralPath $f)) { $missing += $f } }
# TB-⑥: the carrier is validated HERE, before the first write - not beside its Copy-Item. Measured: the
#    first version put that refusal after New-Item of scripts\ and Copy-Item of SKILL.md, so a package
#    with no carrier still installed an entry document whose newcomer link dangles - the exact defect
#    this card exists for, left on disk by the run that was supposed to catch it.
if (-not (Test-Path -LiteralPath $srcQuickStart -PathType Leaf)) { $missing += $srcQuickStart }
if (@($missing).Count -gt 0) {
  Say ('ERROR: source file(s) not found: ' + (@($missing) -join '; '))
  Say 'Run this script from inside the repository: <repo>/skill/agent-computer-use/install.ps1'
  exit 3
}

if (-not [string]::IsNullOrWhiteSpace($StitchTo)) {
  # A-21: emit the deliverable and stop. Nothing is resolved, created, copied, registered or smoked -
  #    this path exists so the acceptance run (determinism, help exit, residue) can build the artifact
  #    without ever touching a skill directory. A refusal here carries the same exit code the install
  #    path promises (4) - the first version let the exception escape, which exits 1 and contradicts
  #    the usage block at the top of this file.
  $only = $null
  try {
    $only = Get-StitchedDesktop $RepoRoot
  } catch { Say ('ERROR: ' + $_.Exception.Message); Say 'Nothing was written - the artifact was refused.'; exit 4 }
  [System.IO.File]::WriteAllText($StitchTo, (([string][char]0xFEFF) + $only), (New-Object System.Text.UTF8Encoding($false)))
  Say ('stitched to: ' + $StitchTo + ' lines=' + (([regex]::Matches($only, '\n').Count + 1)) + ' sha256=' + (Get-FileHash -Algorithm SHA256 -LiteralPath $StitchTo).Hash.ToLower())
  exit 0
}

# ---------- resolve the skill root ----------
$root = ''
$resolvedBy = ''
if (-not [string]::IsNullOrWhiteSpace($TargetDir)) {
  $root = $TargetDir; $resolvedBy = '-TargetDir'
} elseif (-not [string]::IsNullOrWhiteSpace($env:AGENT_COMPUTER_USE_SKILL_DIR)) {
  $root = $env:AGENT_COMPUTER_USE_SKILL_DIR; $resolvedBy = 'env AGENT_COMPUTER_USE_SKILL_DIR'
} else {
  $probes = @(
    (Join-Path $env:APPDATA 'LobsterAI\SKILLs'),
    (Join-Path $env:USERPROFILE '.cursor\skills'),
    (Join-Path $projectRoot '.cursor\skills')
  )
  foreach ($p in $probes) {
    if (Test-Path -LiteralPath $p) { $root = $p; $resolvedBy = 'probe (first existing): ' + $p; break }
  }
}
if ([string]::IsNullOrWhiteSpace($root)) {
  Say 'ERROR: no skill directory found to install into.'
  Say 'Probed, first existing wins: %APPDATA%\LobsterAI\SKILLs ; %USERPROFILE%\.cursor\skills ; <repo>\.cursor\skills'
  Say 'Pass -TargetDir <path> (or set AGENT_COMPUTER_USE_SKILL_DIR) to name one explicitly.'
  exit 2
}
Say ('skill root : ' + $root)
Say ('resolved by: ' + $resolvedBy)

$skillDir = Join-Path $root 'agent-computer-use'
$scriptsDir = Join-Path $skillDir 'scripts'
New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null

# ---------- copy (idempotent: this skill's files only, overwrite) ----------
Copy-Item -LiteralPath $srcSkill -Destination (Join-Path $skillDir 'SKILL.md') -Force
if (Test-Path -LiteralPath $srcRef) {
  Copy-Item -LiteralPath $srcRef -Destination (Join-Path $skillDir 'reference.md') -Force
}
# TB-⑥: NOT a best-effort copy like reference.md - its absence is refused above, before anything lands.
Copy-Item -LiteralPath $srcQuickStart -Destination (Join-Path $skillDir '快速上手指南.md') -Force
# v4.4.0 (A-21): desktop.ps1 is no longer a single file in the repository, so a plain Copy-Item would
#    install a program whose every section is missing. The artifact is stitched instead - and a failure
#    to stitch is a hard stop, never a fallback onto the copy that would install a broken tool.
try {
  $stitched = Get-StitchedDesktop $RepoRoot
} catch { Say ('ERROR: ' + $_.Exception.Message); Say 'Nothing was installed for desktop.ps1 - the entry was left alone.'; exit 4 }
[System.IO.File]::WriteAllText((Join-Path $scriptsDir 'desktop.ps1'), (([string][char]0xFEFF) + $stitched), (New-Object System.Text.UTF8Encoding($false)))
Say ('stitched : desktop.ps1 from the split tree (' + (@($stitched -split "`n").Count) + ' lines)')
Say ('installed  : ' + $skillDir)

# ---------- optional registration in skills.config.json ----------
$cfgPath = Join-Path $root 'skills.config.json'
if (Test-Path -LiteralPath $cfgPath) {
  try {
    $cfg = [System.IO.File]::ReadAllText($cfgPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $container = $cfg
    if ($cfg.PSObject.Properties.Name -contains 'defaults') { $container = $cfg.defaults }
    $already = $false
    if ($container.PSObject.Properties.Name -contains 'agent-computer-use') {
      $cur = $container.'agent-computer-use'
      if (($cur.order -eq 205) -and ($cur.enabled -eq $true)) { $already = $true }
    }
    if ($already) {
      Say ('registered : already present and correct (order 205, enabled) in ' + $cfgPath)
    } else {
      $want = [pscustomobject]@{ order = 205; enabled = $true }
      $container | Add-Member -MemberType NoteProperty -Name 'agent-computer-use' -Value $want -Force
      $json = $cfg | ConvertTo-Json -Depth 32
      [System.IO.File]::WriteAllText($cfgPath, $json + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
      Say ('registered : agent-computer-use -> { order: 205, enabled: true } in ' + $cfgPath)
    }
  } catch {
    Say ('WARNING: could not update skills.config.json: ' + $_.Exception.Message)
    Say '         files are installed, registration skipped.'
  }
} else {
  Say ('note       : no skills.config.json at ' + $cfgPath + ' (registration skipped)')
}

# ---------- smoke test ----------
$smokeOk = $true
$codeSelftest = 'n/a'
$codeHelp = 'n/a'
if (-not $SkipSelftest) {
  $dps = Join-Path $scriptsDir 'desktop.ps1'
  Say ''
  Say 'smoke test : desktop.ps1 selftest (offline) ...'
  & powershell -NoProfile -ExecutionPolicy Bypass -File $dps selftest 2>&1 | ForEach-Object { Write-Host $_ }
  $codeSelftest = $LASTEXITCODE
  Say ('selftest exit : ' + $codeSelftest)
  Say ''
  Say 'smoke test : desktop.ps1 help ...'
  & powershell -NoProfile -ExecutionPolicy Bypass -File $dps help 2>&1 | ForEach-Object { Write-Host $_ }
  $codeHelp = $LASTEXITCODE
  Say ('help exit : ' + $codeHelp)
  if (($codeSelftest -ne 0) -or ($codeHelp -ne 0)) { $smokeOk = $false }
}

# ---------- capability note ----------
Say ''
Say 'Capability note / 能力与风险:'
Say '  This skill can click, type and read/write the clipboard, and can paste real files'
Say '  into applications - it hands desktop control to whichever agent calls it.'
Say '  Typed payloads are stored redacted in the audit log (<redacted:Nchars>).'
Say '  本技能可点击、可键入、可读写剪贴板，等于把桌面控制权交给调用它的 Agent；操作日志默认脱敏。'

if (-not $smokeOk) {
  Say ''
  Say 'RESULT: 装载完成但自检未过 / installed, but the smoke test did NOT pass.'
  Say ('        selftest exit=' + $codeSelftest + ', help exit=' + $codeHelp)
  exit 1
}
Say ''
if ($SkipSelftest) { Say 'RESULT: installed (-SkipSelftest: smoke test skipped).' } else { Say 'RESULT: installed and smoke-tested OK.' }
exit 0
