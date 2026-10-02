# uninstall.ps1 - remove the agent-computer-use skill from a skill directory.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1 -TargetDir <path>
#
# Resolution - first match wins:
#   1. -TargetDir <path>
#   2. environment variable AGENT_COMPUTER_USE_SKILL_DIR
#   3. first probe that actually CONTAINS an agent-computer-use folder:
#        %APPDATA%\LobsterAI\SKILLs ; %USERPROFILE%\.cursor\skills ; <RepoRoot>\.cursor\skills
# Removes <Target>\agent-computer-use\ and drops the "agent-computer-use" key from
# <Target>\skills.config.json (when present), leaving every other entry untouched.
#
# Exit codes:
#   0  removed
#   2  no target directory could be resolved
#   4  nothing installed at the resolved root

param(
  [string]$TargetDir = ''
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Say([string]$m) { Write-Host $m }

$root = ''
$resolvedBy = ''
if (-not [string]::IsNullOrWhiteSpace($TargetDir)) {
  $root = $TargetDir; $resolvedBy = '-TargetDir'
} elseif (-not [string]::IsNullOrWhiteSpace($env:AGENT_COMPUTER_USE_SKILL_DIR)) {
  $root = $env:AGENT_COMPUTER_USE_SKILL_DIR; $resolvedBy = 'env AGENT_COMPUTER_USE_SKILL_DIR'
} else {
  $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $probes = @(
    (Join-Path $env:APPDATA 'LobsterAI\SKILLs'),
    (Join-Path $env:USERPROFILE '.cursor\skills'),
    (Join-Path $repoRoot '.cursor\skills')
  )
  foreach ($p in $probes) {
    if (Test-Path -LiteralPath (Join-Path $p 'agent-computer-use')) { $root = $p; $resolvedBy = 'probe (contains the skill): ' + $p; break }
  }
}
if ([string]::IsNullOrWhiteSpace($root)) {
  Say 'ERROR: could not find an installed agent-computer-use skill to remove.'
  Say 'Probed: %APPDATA%\LobsterAI\SKILLs ; %USERPROFILE%\.cursor\skills ; <repo>\.cursor\skills'
  Say 'Pass -TargetDir <path> (or set AGENT_COMPUTER_USE_SKILL_DIR) to name the root explicitly.'
  exit 2
}
Say ('skill root : ' + $root)
Say ('resolved by: ' + $resolvedBy)

$skillDir = Join-Path $root 'agent-computer-use'
if (-not (Test-Path -LiteralPath $skillDir)) {
  Say ('nothing to remove: ' + $skillDir + ' does not exist.')
  exit 4
}

$removed = @(Get-ChildItem -LiteralPath $skillDir -Recurse -File | ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\') })
Remove-Item -LiteralPath $skillDir -Recurse -Force
Say ('removed    : ' + $skillDir)
foreach ($f in $removed) { Say ('  - ' + $f) }

$cfgPath = Join-Path $root 'skills.config.json'
if (Test-Path -LiteralPath $cfgPath) {
  try {
    $cfg = [System.IO.File]::ReadAllText($cfgPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $container = $cfg
    if ($cfg.PSObject.Properties.Name -contains 'defaults') { $container = $cfg.defaults }
    if ($container.PSObject.Properties.Name -contains 'agent-computer-use') {
      $container.PSObject.Properties.Remove('agent-computer-use')
      $json = $cfg | ConvertTo-Json -Depth 32
      [System.IO.File]::WriteAllText($cfgPath, $json + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
      Say ('unregistered: removed "agent-computer-use" from ' + $cfgPath)
    } else {
      Say ('note       : no "agent-computer-use" key in ' + $cfgPath + ' (nothing to remove)')
    }
  } catch {
    Say ('WARNING: could not update skills.config.json: ' + $_.Exception.Message)
  }
} else {
  Say ('note       : no skills.config.json at ' + $cfgPath)
}
Say 'done.'
exit 0
