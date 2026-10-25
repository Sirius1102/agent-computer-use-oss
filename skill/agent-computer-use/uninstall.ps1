# uninstall.ps1 - remove the agent-computer-use skill from a skill directory.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1 -TargetDir <path>
#   powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1 -TargetDir <path> -WhatIf
#   powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1 -Confirm
#
# Target resolution - first match wins:
#   1. -TargetDir <path>
#   2. environment variable AGENT_COMPUTER_USE_SKILL_DIR
#   3. first probe that actually CONTAINS an agent-computer-use folder:
#        %APPDATA%\LobsterAI\SKILLs ; %USERPROFILE%\.cursor\skills ; <RepoRoot>\.cursor\skills
# Removes <Target>\agent-computer-use\ and drops the "agent-computer-use" key from
# <Target>\skills.config.json (when present), leaving every other entry untouched.
#
# TB-5 (12-hour taskbook item 5): the recursive delete is now bounded AND opt-in.
#   - SupportsShouldProcess. One gate covers the whole uninstall (the skill directory plus its
#     skills.config.json key), so -WhatIf previews both targets and -Confirm asks once;
#     declining writes nothing at all and exits 0, and a "yes" that ends up leaving the
#     directory in place exits 1 instead of claiming success. ConfirmImpact deliberately stays
#     Medium: making it High would turn the documented one-line invocation into a prompt, and a
#     prompt read from a redirected or closed stdin answers itself with the default, which in a
#     remover is the wrong way to fail silently. The hard protection is the refusal below - it
#     runs before any mutation and no switch can talk past it.
#     Measured with a redirected stdin (the offline harness is the only non-desktop channel
#     here): the host does not echo the '[Y] Yes ...' prompt block into stdout, but the answer
#     piped to it IS consumed and does change the outcome - 'Y' removes, 'N' declines and keeps
#     the registration. A prompt drawn on a real console has not been exercised.
#   - Refusal covers the root that ends up resolved, whether it came from -TargetDir, from
#     the environment variable or from a probe. -TargetDir names a DIRECTORY WHOSE CHILD is
#     deleted recursively, so a root that carries repository / worktree / source-tree /
#     broad-container features is refused outright, and so is any root or child reached
#     through a reparse point, because a junction aims the recursive delete somewhere the
#     operator never typed.
#
# Refused (exit 5, nothing removed and nothing rewritten):
#   .git in the root            - a repository or a worktree (the file form covers worktrees)
#   desktop.ps1 in the root     - this tool's own tree, or an install root of it
#   lib\*.ps1 in the root       - a split source tree
#   the root is the uninstaller's own directory or an ancestor of it
#   the root is a volume root, or at or above the directory that holds user profiles
#   the root is the profile, roaming/local appdata, the OneDrive folder or the Desktop
#   the root or the skill child is a reparse point (junction / symlink)
# Not a skill install (exit 6, nothing removed): the child directory exists but holds no
#   SKILL.md, so it is not this skill's install layout and was never ours to delete.
#
# Exit codes:
#   0  removed (or, with -WhatIf, would have been removed - nothing was touched)
#   1  the removal was attempted and the directory is still there, or the confirmation gate
#      itself threw - in both cases the registration was left alone
#   2  no target directory could be resolved
#   4  nothing installed at the resolved root
#   5  the resolved target was refused as dangerous - nothing removed
#   6  the target exists but is not a recognizable skill install - nothing removed

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [string]$TargetDir = ''
)

# v3.0.1 (external audit item 23): same pair of guards as install.ps1, same reasoning -
# StrictMode for the unset-variable class (an empty path in a REMOVER is the worst possible
# silent value), 'Continue' kept on purpose so one locked file does not abort the run after
# the directory is already gone and the exit code stops meaning anything.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Say([string]$m) { Write-Host $m }

function Get-FullPath([string]$p) {
  # Normalize without touching the disk: trailing separators, dot segments and drive-relative
  # spellings all resolve here, so the comparisons below cannot be slipped past by spelling.
  # 'D:\' must survive as 'D:\': trimming it to 'D:' hands back the process's current directory
  # on that drive, which is some other folder entirely - measured, not assumed.
  if ([string]::IsNullOrWhiteSpace($p)) { return '' }
  $q = $p.TrimEnd(' ')
  if ($q -match '^[A-Za-z]:\\?$') { $q = $q.Substring(0, 2) + '\' }
  try {
    $full = [System.IO.Path]::GetFullPath($q)
    $rootPart = [System.IO.Path]::GetPathRoot($full)
    if ($full.Equals($rootPart, [System.StringComparison]::OrdinalIgnoreCase)) { return $rootPart }
    return $full.TrimEnd('\')
  } catch { return '' }
}

function Test-ReparsePoint([string]$p) {
  # Resolving where a reparse point leads needs an engine-specific API (.NET 6+ on one side,
  # nothing on the other), so this guard does not resolve it - it refuses it.
  if (-not (Test-Path -LiteralPath $p)) { return $false }
  try {
    $attr = (Get-Item -LiteralPath $p -Force -ErrorAction Stop).Attributes
    return (([int]$attr -band [int][System.IO.FileAttributes]::ReparsePoint) -ne 0)
  } catch { return $false }
}

function Get-RefusalReason([string]$rootFull, [string]$selfFull) {
  # Every check that matches contributes one string; the caller collects them with @() and
  # refuses on a non-empty set. Reads metadata only and mutates nothing.
  $out = New-Object 'System.Collections.Generic.List[string]'
  if ([string]::IsNullOrWhiteSpace($rootFull)) {
    $out.Add('the named root does not resolve to a full path'); return $out.ToArray()
  }
  if ($rootFull -eq [System.IO.Path]::GetPathRoot($rootFull)) { $out.Add("the named root is a volume root: $rootFull") }
  if (Test-Path -LiteralPath (Join-Path $rootFull '.git')) { $out.Add("the named root holds .git (a repository or worktree): $rootFull") }
  if (Test-Path -LiteralPath (Join-Path $rootFull 'desktop.ps1')) { $out.Add("the named root holds desktop.ps1 (this tool owns that tree): $rootFull") }
  $libDir = Join-Path $rootFull 'lib'
  if ((Test-Path -LiteralPath $libDir -PathType Container) -and
      (@(Get-ChildItem -LiteralPath $libDir -Filter '*.ps1' -File -ErrorAction SilentlyContinue).Count -gt 0)) {
    $out.Add("the named root holds a lib\ source directory with .ps1 files in it: $rootFull")
  }
  if ($selfFull.Length -gt 0 -and $selfFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    # Covers the root being the uninstaller's own directory as well as any ancestor of it.
    $out.Add("the named root is the uninstaller's own tree or an ancestor of it: $rootFull")
  }
  $profileDir = Get-FullPath $env:USERPROFILE
  $profilesContainer = Get-FullPath (Split-Path -Parent $profileDir)
  if ($profilesContainer.Length -gt 0 -and
      ($profileDir.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -or
       $rootFull.Equals($profilesContainer, [System.StringComparison]::OrdinalIgnoreCase))) {
    $out.Add("the named root is at or above the directory that holds user profiles: $rootFull")
  }
  $broad = @($profileDir, [Environment]::GetEnvironmentVariable('APPDATA'),
             [Environment]::GetEnvironmentVariable('LOCALAPPDATA'),
             [Environment]::GetEnvironmentVariable('OneDrive'),
             (Get-FullPath ([Environment]::GetFolderPath('Desktop'))))
  foreach ($b in $broad) {
    if ($b.Length -gt 0 -and $rootFull.Equals($b, [System.StringComparison]::OrdinalIgnoreCase)) {
      $out.Add("the named root is a broad container that a recursive delete would sweep up: $rootFull")
      break
    }
  }
  if (Test-ReparsePoint $rootFull) { $out.Add("the named root is itself a reparse point (junction / symlink): $rootFull") }
  $out.ToArray()
}

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

# TB-5: the guard runs on whatever got resolved, before the existence check and long before
# any mutation, so a refused target is reported the same way whether or not it is installed.
$rootFull = Get-FullPath $root
$skillFull = Get-FullPath (Join-Path $root 'agent-computer-use')
$selfFull = Get-FullPath $PSScriptRoot
$reasons = @(Get-RefusalReason -rootFull $rootFull -selfFull $selfFull)
if (Test-ReparsePoint $skillFull) { $reasons += "the skill directory is a reparse point (junction / symlink): $skillFull" }
if (@($reasons).Count -gt 0) {
  Say 'REFUSED: the resolved target carries dangerous-target features; nothing was removed.'
  foreach ($r in $reasons) { Say ('  - ' + $r) }
  Say 'Point -TargetDir at the directory that CONTAINS the installed skill (its agent-computer-use child is what gets removed), or remove the reparse point.'
  exit 5
}

if (-not (Test-Path -LiteralPath $skillFull)) {
  Say ('nothing to remove: ' + $skillFull + ' does not exist.')
  exit 4
}
if (-not (Test-Path -LiteralPath (Join-Path $skillFull 'SKILL.md') -PathType Leaf)) {
  Say ('REFUSED: ' + $skillFull + ' holds no SKILL.md, so it is not an agent-computer-use install; nothing was removed.')
  exit 6
}

$removed = @(Get-ChildItem -LiteralPath $skillFull -Recurse -File | ForEach-Object { $_.FullName.Substring($rootFull.Length).TrimStart('\') })
$cfgPath = Join-Path $rootFull 'skills.config.json'
$opTarget = $skillFull
if (Test-Path -LiteralPath $cfgPath) { $opTarget = $skillFull + ' + ' + $cfgPath }
# ONE gate for the whole uninstall. Measured reasoning: with a gate per mutation a -Confirm run
# had to be answered twice, and when the second question had no answer left to read it threw
# NullReferenceException inside the host on BOTH Windows PowerShell 5.1 and PowerShell 7.6.7
# (reproduced on this machine; the decline itself still held). Removing the directory and
# dropping its registration key is one operation as the user means it, so it is one
# confirmation, and the preview names both targets.
# -Confirm:$false on the inner Remove-Item is the fix for a second measured defect: when
# -Confirm propagates into Remove-Item as well, the recursive delete dies with
# NullReferenceException on both engines after the gate has already asked. Confirmation belongs
# to the gate and to nothing else. -WhatIf is left to propagate on purpose (defence in depth).
$errMarkBefore = @($Error).Count
$proceed = $false
$gateError = ''
try { $proceed = $PSCmdlet.ShouldProcess($opTarget, 'uninstall agent-computer-use (remove the skill directory and drop its registration key)') }
catch { $gateError = [string]$_.Exception.Message }
# Measured on this machine: with -Confirm and no answer left to read, the host throws
# NullReferenceException out of ShouldProcess on both engines, and because that error is
# non-terminating the whole if/else is skipped - the script used to fall through to 'done.' and
# exit 0 having removed nothing. A gate that could not be answered is a failure, not a success.
if ($gateError.Length -gt 0) {
  Say ('ERROR: the confirmation gate itself failed, so nothing was decided: ' + $gateError)
  Say ('Nothing was removed and the registration was left alone: ' + $opTarget)
  exit 1
}
if ($proceed) {
  Remove-Item -LiteralPath $skillFull -Recurse -Force -Confirm:$false
  # An exit code has to mean something: said yes and the directory is still there is a failure,
  # not a success with a warning buried in the output. Checked before the registration is
  # touched on purpose - a skill that could not be removed stays registered.
  if (Test-Path -LiteralPath $skillFull) {
    Say ('ERROR: the removal was attempted but ' + $skillFull + ' still exists (' + (@($Error).Count - $errMarkBefore) + ' new error(s)); the registration was left alone.')
    exit 1
  }
  Say ('removed    : ' + $skillFull)
  foreach ($f in $removed) { Say ('  - ' + $f) }
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
} else {
  Say ('not uninstalled (preview or declined): ' + $opTarget)
  foreach ($f in $removed) { Say ('  would remove - ' + $f) }
}
Say 'done.'
exit 0
