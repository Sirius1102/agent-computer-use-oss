# install.ps1 - load the agent-computer-use skill into an agent skill directory.
#
# Usage (run from inside the repository):
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -TargetDir <path>
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -RepoRoot <path> -SkipSelftest
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
#   <Target>\agent-computer-use\scripts\desktop.ps1     (copied from <RepoRoot>\desktop.ps1)
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

param(
  [string]$TargetDir = '',
  [string]$RepoRoot = '',
  [switch]$SkipSelftest
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Say([string]$m) { Write-Host $m }

# ---------- locate sources ----------
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
$srcSkill = Join-Path $PSScriptRoot 'SKILL.md'
$srcRef = Join-Path $PSScriptRoot 'reference.md'
$srcDesktop = Join-Path $RepoRoot 'desktop.ps1'

$missing = @()
foreach ($f in @($srcSkill, $srcDesktop)) { if (-not (Test-Path -LiteralPath $f)) { $missing += $f } }
if (@($missing).Count -gt 0) {
  Say ('ERROR: source file(s) not found: ' + (@($missing) -join '; '))
  Say 'Run this script from inside the repository: <repo>/skill/agent-computer-use/install.ps1'
  exit 3
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
    (Join-Path $RepoRoot '.cursor\skills')
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
Copy-Item -LiteralPath $srcDesktop -Destination (Join-Path $scriptsDir 'desktop.ps1') -Force
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
