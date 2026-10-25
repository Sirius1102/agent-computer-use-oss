# CU-CALL (v4.5.0): per-invocation caller history and overlap warnings.
# State is local to one Windows logon session and input desktop; it never lives under the repo.

if (-not ('DtxCallProcessNative' -as [type])) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class DtxCallProcessNative {
  [DllImport("kernel32.dll", SetLastError = true)]
  public static extern bool GetProcessTimes(IntPtr process, out long creation, out long exit, out long kernel, out long user);
}
"@
}

function Get-DtxCallContextValue($Context, [string]$Name, $Default = $null) {
  if (($null -ne $Context) -and ($Context -is [System.Collections.IDictionary]) -and $Context.Contains($Name)) {
    return $Context[$Name]
  }
  return $Default
}

function ConvertTo-DtxCallSafeText([string]$Value, [int]$Limit) {
  $safe = [regex]::Replace([string]$Value, '[\x00-\x1F\x7F]', ' ')
  $safe = [regex]::Replace($safe, '\s+', ' ').Trim()
  if ($safe.Length -gt $Limit) { $safe = $safe.Substring(0, $Limit) }
  return $safe
}

function Get-DtxCallSha256([string]$Value) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Value)
    return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

function Get-DtxCallIdentity($Context = $null) {
  $explicitLabel = [string](Get-DtxCallContextValue $Context 'CallerLabel' ([Environment]::GetEnvironmentVariable('DTX_CALLER_LABEL', 'Process')))
  $explicitSession = [string](Get-DtxCallContextValue $Context 'CallerSessionId' ([Environment]::GetEnvironmentVariable('DTX_CALLER_SESSION_ID', 'Process')))
  $codexThread = [string](Get-DtxCallContextValue $Context 'CodexThreadId' ([Environment]::GetEnvironmentVariable('CODEX_THREAD_ID', 'Process')))
  $codexSession = [string](Get-DtxCallContextValue $Context 'CodexSessionId' ([Environment]::GetEnvironmentVariable('CODEX_SESSION_ID', 'Process')))
  if ($null -ne (Get-DtxCallContextValue $Context 'IdentitySource' $null)) {
    return [pscustomobject]@{
      CallerLabel = ConvertTo-DtxCallSafeText $explicitLabel 80
      CallerSessionId = ConvertTo-DtxCallSafeText $explicitSession 96
      IdentitySource = ConvertTo-DtxCallSafeText ([string]$Context.IdentitySource) 48
    }
  }
  if (($explicitLabel.Length -gt 0) -or ($explicitSession.Length -gt 0)) {
    return [pscustomobject]@{
      CallerLabel = if ($explicitLabel) { ConvertTo-DtxCallSafeText $explicitLabel 80 } else { 'unknown' }
      CallerSessionId = if ($explicitSession) { ConvertTo-DtxCallSafeText $explicitSession 96 } else { 'unknown' }
      IdentitySource = if ($explicitLabel -and $explicitSession) { 'explicit-environment' } else { 'partial-explicit-environment' }
    }
  }
  if ($codexThread.Length -gt 0) {
    return [pscustomobject]@{ CallerLabel = 'Codex'; CallerSessionId = ConvertTo-DtxCallSafeText $codexThread 96; IdentitySource = 'codex-thread-environment' }
  }
  if ($codexSession.Length -gt 0) {
    return [pscustomobject]@{ CallerLabel = 'Codex'; CallerSessionId = ConvertTo-DtxCallSafeText $codexSession 96; IdentitySource = 'codex-session-environment' }
  }
  return [pscustomobject]@{ CallerLabel = 'unknown'; CallerSessionId = 'unknown'; IdentitySource = 'unknown' }
}

function Get-DtxCallTargetSummary([string]$Command, [string[]]$Arguments) {
  $commandKey = ([string]$Command).ToLowerInvariant()
  $selector = ''
  $argsCopy = @($Arguments)
  for ($i = 0; $i -lt $argsCopy.Count; $i++) {
    if (([string]$argsCopy[$i] -ceq '--to') -or ([string]$argsCopy[$i] -ceq '--at')) {
      if (($i + 1) -lt $argsCopy.Count) { $selector = [string]$argsCopy[$i + 1] }
      break
    }
  }
  if (-not $selector -and @('focus','info','win','rect-of','assert-window','read-text','uia-tree','wait-win','wait-gone') -ccontains $commandKey) {
    if ($argsCopy.Count -gt 0 -and -not ([string]$argsCopy[0]).StartsWith('--')) { $selector = [string]$argsCopy[0] }
  }
  if ($selector) {
    $kind = if ($selector -match '^\d+$') { 'pid' }
      elseif ($selector -match '^(?i:proc):') { 'proc' }
      elseif ($selector -match '^(?i:class):') { 'class' }
      elseif ($selector -match '^(?i:(t|title)):' ) { 'title' }
      else { 'selector' }
    return ('selector-kind=' + $kind + ';selector-sha256=' + (Get-DtxCallSha256 $selector).Substring(0, 16))
  }
  if (@('click','rclick','dblclick','wheel','move','drag','hover','relclick') -ccontains $commandKey) { return 'coordinates-or-current-pointer' }
  return 'not-specified'
}

function Get-DtxCallProcessBirth([int]$ProcessId) {
  $process = [System.Diagnostics.Process]::GetProcessById($ProcessId)
  try {
    $creation = [long]0
    $exit = [long]0
    $kernel = [long]0
    $user = [long]0
    if (-not [DtxCallProcessNative]::GetProcessTimes($process.Handle, [ref]$creation, [ref]$exit, [ref]$kernel, [ref]$user)) {
      throw (New-Object ComponentModel.Win32Exception([Runtime.InteropServices.Marshal]::GetLastWin32Error()))
    }
    return [pscustomobject]@{
      FileTime = $creation.ToString([Globalization.CultureInfo]::InvariantCulture)
      Utc = [DateTime]::FromFileTimeUtc($creation).ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    }
  }
  finally { $process.Dispose() }
}

function Get-DtxCallParentInfo($Context = $null) {
  $given = Get-DtxCallContextValue $Context 'ParentInfo' $null
  if ($null -ne $given) { return $given }
  try {
    $currentId = [System.Diagnostics.Process]::GetCurrentProcess().Id
    $row = Get-CimInstance -ClassName Win32_Process -Filter ('ProcessId = ' + $currentId) -Property ProcessId,ParentProcessId -ErrorAction Stop
    $parentId = [int]$row.ParentProcessId
    if ($parentId -le 0) { throw 'parent process id unavailable' }
    $parent = [System.Diagnostics.Process]::GetProcessById($parentId)
    try {
      $parentBirth = Get-DtxCallProcessBirth $parentId
      $parentName = ConvertTo-DtxCallSafeText $parent.ProcessName 64
    } finally { $parent.Dispose() }
    return [pscustomobject]@{ ParentPid = $parentId; ParentName = $parentName; ParentStartUtc = $parentBirth.Utc; ParentStartFileTime = $parentBirth.FileTime; Known = $true }
  } catch {
    return [pscustomobject]@{ ParentPid = 0; ParentName = 'unknown'; ParentStartUtc = ''; ParentStartFileTime = ''; Known = $false }
  }
}

function New-DtxCallDesktopIdentity([string]$WindowStation, [string]$DesktopName) {
  $station = ConvertTo-DtxCallSafeText $WindowStation 64
  $desktop = ConvertTo-DtxCallSafeText $DesktopName 64
  if (($station.Length -eq 0) -or ($desktop.Length -eq 0)) { throw 'window station or desktop name unavailable' }
  return ('window-station=' + $station + ';desktop=' + $desktop)
}

function Get-DtxCallObjectName([IntPtr]$Handle) {
  if ($Handle -eq [IntPtr]::Zero) { throw 'window object handle unavailable' }
  $needed = 0
  [void][DT]::GetUserObjectInformation($Handle, 2, [IntPtr]::Zero, 0, [ref]$needed)
  if (($needed -lt 4) -or ($needed -gt 2048)) { throw 'desktop name size unavailable' }
  $buffer = [Runtime.InteropServices.Marshal]::AllocHGlobal($needed)
  try {
    if (-not [DT]::GetUserObjectInformation($Handle, 2, $buffer, $needed, [ref]$needed)) { throw 'window object name read failed' }
    $name = [Runtime.InteropServices.Marshal]::PtrToStringUni($buffer)
    if ([string]::IsNullOrWhiteSpace($name)) { throw 'window object name empty' }
    return ConvertTo-DtxCallSafeText $name 64
  } finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($buffer) }
}

function Get-DtxCallDesktopName {
  $station = [DT]::GetProcessWindowStation()
  if ($station -eq [IntPtr]::Zero) { throw 'process window station unavailable' }
  $stationName = Get-DtxCallObjectName $station
  $threadId = [DT]::GetCurrentThreadId()
  if ($threadId -eq 0) { throw 'current thread id unavailable' }
  $desktop = [DT]::GetThreadDesktop($threadId)
  if ($desktop -eq [IntPtr]::Zero) { throw 'thread desktop unavailable' }
  $desktopName = Get-DtxCallObjectName $desktop
  return New-DtxCallDesktopIdentity $stationName $desktopName
}

function Enter-DtxCallLock([string]$Path, [int]$TimeoutMs = 300) {
  $watch = [System.Diagnostics.Stopwatch]::StartNew()
  while ($watch.ElapsedMilliseconds -lt $TimeoutMs) {
    try { return [System.IO.File]::Open($Path, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }
    catch [System.IO.IOException] { Start-Sleep -Milliseconds 15 }
  }
  return $null
}

function Write-DtxCallAtomicJson([string]$Path, $Value) {
  $tmp = $Path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
  $json = ConvertTo-Json -InputObject $Value -Depth 8 -Compress
  [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
  try {
    if ([System.IO.File]::Exists($Path)) {
      $backup = $Path + '.' + [Guid]::NewGuid().ToString('N') + '.bak'
      try { [System.IO.File]::Replace($tmp, $Path, $backup) }
      finally { if ([System.IO.File]::Exists($backup)) { [System.IO.File]::Delete($backup) } }
    }
    else { [System.IO.File]::Move($tmp, $Path) }
  } finally { if ([System.IO.File]::Exists($tmp)) { [System.IO.File]::Delete($tmp) } }
}

function Read-DtxCallRecord([string]$Path) {
  $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
  return ConvertFrom-Json -InputObject $raw -ErrorAction Stop
}

function Test-DtxCallHistoryHasId([string]$HistoryRoot, [string]$StartUtc, [string]$InvocationId) {
  $day = ([DateTime]::Parse($StartUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)).ToUniversalTime().ToString('yyyyMMdd')
  $needle = '"invocation_id":"' + $InvocationId + '"'
  foreach ($path in @([System.IO.Directory]::GetFiles($HistoryRoot, ('calls-' + $day + '-*.jsonl')))) {
    $raw = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    if ($raw.Contains($needle)) { return $true }
  }
  return $false
}

function Write-DtxCallHistory($Record, [string]$HistoryRoot) {
  $day = ([DateTime]::Parse([string]$Record.started_utc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)).ToUniversalTime().ToString('yyyyMMdd')
  $json = ConvertTo-Json -InputObject $Record -Depth 8 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json + "`n")
  if ($bytes.Length -gt 16384) { throw 'history record exceeds the 16 KiB record limit' }
  $paths = @([System.IO.Directory]::GetFiles($HistoryRoot, ('calls-' + $day + '-*.jsonl')))
  $maxSeq = 0
  $latest = ''
  foreach ($path in $paths) {
    $m = [regex]::Match([System.IO.Path]::GetFileName($path), '^calls-' + $day + '-([0-9]{4})\.jsonl$')
    if ($m.Success) {
      $seq = [int]$m.Groups[1].Value
      if ($seq -gt $maxSeq) { $maxSeq = $seq; $latest = $path }
    }
  }
  $maxSegmentBytes = 4194304
  if (($latest -eq '') -or (([System.IO.FileInfo]$latest).Length + $bytes.Length -gt $maxSegmentBytes)) {
    $maxSeq++
    $latest = Join-Path $HistoryRoot ('calls-' + $day + '-' + $maxSeq.ToString('0000') + '.jsonl')
  }
  $stream = [System.IO.File]::Open($latest, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
  try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
  finally { $stream.Dispose() }
}

function Get-DtxCallProcessState($Record) {
  try {
    $actual = Get-DtxCallProcessBirth ([int]$Record.tool_pid)
    if ([string]$actual.FileTime -ceq [string]$Record.tool_process_start_filetime) { return 'alive' }
    return 'pid-reused'
  } catch [ArgumentException] { return 'dead' }
  catch { return 'unknown' }
}

function Get-DtxCallInternalParent($ActiveById, $ParentInfo, [string]$Root) {
  $parentId = [Environment]::GetEnvironmentVariable('DTX_CALL_INTERNAL_PARENT_ID', 'Process')
  $parentPid = [Environment]::GetEnvironmentVariable('DTX_CALL_INTERNAL_PARENT_PID', 'Process')
  $parentStart = [Environment]::GetEnvironmentVariable('DTX_CALL_INTERNAL_PARENT_START_FILETIME', 'Process')
  $parentToken = [Environment]::GetEnvironmentVariable('DTX_CALL_INTERNAL_PARENT_TOKEN', 'Process')
  if ((-not $parentId) -or (-not $parentPid) -or (-not $parentStart) -or (-not $parentToken)) { return $null }
  if ((-not $ParentInfo.Known) -or ([int]$ParentInfo.ParentPid -ne [int]$parentPid)) { return $null }
  if ([string]$ParentInfo.ParentStartFileTime -cne [string]$parentStart) { return $null }
  if (-not $ActiveById.ContainsKey([string]$parentId)) { return $null }
  $parentRecord = $ActiveById[[string]$parentId]
  if (([string]$parentRecord.status -cne 'active') -or ([int]$parentRecord.tool_pid -ne [int]$parentPid)) { return $null }
  if ([string]$parentRecord.tool_process_start_filetime -cne [string]$parentStart) { return $null }
  if ((Get-DtxCallSha256 $parentToken) -cne [string]$parentRecord.internal_token_sha256) { return $null }
  return $parentRecord
}

function Start-DtxCallTracking([string]$Command, [string[]]$Arguments, $Context = $null) {
  $lock = $null
  try {
    $localRoot = [string](Get-DtxCallContextValue $Context 'RootBase' $null)
    if (-not $localRoot) { $localRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData) }
    $sessionId = [string](Get-DtxCallContextValue $Context 'WindowsSessionId' $null)
    if (-not $sessionId) { $sessionId = [string][System.Diagnostics.Process]::GetCurrentProcess().SessionId }
    $desktopName = [string](Get-DtxCallContextValue $Context 'DesktopName' $null)
    if (-not $desktopName) { $desktopName = Get-DtxCallDesktopName }
    if (($localRoot.Length -eq 0) -or ($sessionId -notmatch '^\d{1,8}$') -or ($desktopName.Length -eq 0)) { throw 'call-state identity unavailable' }
    $desktopKey = 'desktop-' + (Get-DtxCallSha256 $desktopName).Substring(0, 16)
    $stateRoot = Join-Path (Join-Path (Join-Path $localRoot 'AgentComputerUse\runtime\v1') $sessionId) $desktopKey
    $activeRoot = Join-Path $stateRoot 'active'
    $historyRoot = Join-Path $stateRoot 'history'
    [void][System.IO.Directory]::CreateDirectory($activeRoot)
    [void][System.IO.Directory]::CreateDirectory($historyRoot)
    $lockPath = Join-Path $stateRoot 'state.lock'
    $identity = Get-DtxCallIdentity $Context
    $parentInfo = Get-DtxCallParentInfo $Context
    $invocationId = [Guid]::NewGuid().ToString('N')
    $tokenBytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($tokenBytes) } finally { $rng.Dispose() }
    $token = [System.BitConverter]::ToString($tokenBytes).Replace('-', '').ToLowerInvariant()
    $process = [System.Diagnostics.Process]::GetCurrentProcess()
    try {
      $processBirth = Get-DtxCallProcessBirth ([int]$PID)
      $processName = ConvertTo-DtxCallSafeText $process.ProcessName 64
    } finally { $process.Dispose() }
    $processStart = [string]$processBirth.Utc
    $processStartFileTime = [string]$processBirth.FileTime
    $started = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    $sourcePath = [string](Get-DtxCallContextValue $Context 'SourcePath' (Get-Variable -Name ToolEntryPath -Scope Script -ValueOnly -ErrorAction SilentlyContinue))
    if ($sourcePath) { try { $sourcePath = [System.IO.Path]::GetFullPath($sourcePath) } catch { } }
    $toolVersion = [string](Get-DtxCallContextValue $Context 'ToolVersion' (Get-Variable -Name ToolVersion -Scope Script -ValueOnly -ErrorAction SilentlyContinue))
    if (-not $toolVersion) { $toolVersion = 'unknown' }
    $lock = Enter-DtxCallLock $lockPath 300
    if ($null -eq $lock) { throw 'lock-timeout' }

    $stateUnknown = $false
    $activeRecords = New-Object System.Collections.ArrayList
    $activeById = @{}
    foreach ($activePath in @([System.IO.Directory]::GetFiles($activeRoot, '*.json'))) {
      try { $record = Read-DtxCallRecord $activePath }
      catch { $stateUnknown = $true; continue }
      if ([string]$record.status -ceq 'complete') {
        try {
          if (-not (Test-DtxCallHistoryHasId $historyRoot ([string]$record.started_utc) ([string]$record.invocation_id))) { Write-DtxCallHistory $record $historyRoot }
          [System.IO.File]::Delete($activePath)
        } catch { $stateUnknown = $true }
        continue
      }
      if ([string]$record.status -cne 'active') { $stateUnknown = $true; continue }
      $processState = Get-DtxCallProcessState $record
      if ($processState -eq 'alive') {
        [void]$activeRecords.Add($record)
        $activeById[[string]$record.invocation_id] = $record
        continue
      }
      if ($processState -eq 'unknown') { $stateUnknown = $true; continue }
      $observed = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
      $record.status = 'complete'
      $record.ended_utc = $observed
      $record.duration_ms = [long]([DateTime]::Parse($observed).Subtract([DateTime]::Parse([string]$record.started_utc)).TotalMilliseconds)
      $record.result_category = if ($processState -eq 'pid-reused') { 'pid-reused-observed' } else { 'process-disappeared-observed' }
      $record.exit_code = $null
      $record.end_time_kind = 'observed-during-recovery'
      $record.internal_token_sha256 = ''
      try {
        Write-DtxCallAtomicJson $activePath $record
        if (-not (Test-DtxCallHistoryHasId $historyRoot ([string]$record.started_utc) ([string]$record.invocation_id))) { Write-DtxCallHistory $record $historyRoot }
        [System.IO.File]::Delete($activePath)
      } catch { $stateUnknown = $true }
    }

    $verifiedParent = Get-DtxCallInternalParent $activeById $parentInfo $stateRoot
    $rootInvocationId = if ($null -ne $verifiedParent) { [string]$verifiedParent.root_invocation_id } else { $invocationId }
    $parentLink = if ($null -ne $verifiedParent) { [string]$verifiedParent.invocation_id } else { '' }
    $record = [pscustomobject]@{
      schema_version = 1
      invocation_id = $invocationId
      root_invocation_id = $rootInvocationId
      internal_parent_invocation_id = $parentLink
      internal_chain_verified = [bool]($null -ne $verifiedParent)
      status = 'active'
      ended_utc = ''
      duration_ms = $null
      result_category = 'running'
      exit_code = $null
      error_category = ''
      end_time_kind = ''
      caller_label = ConvertTo-DtxCallSafeText ([string]$identity.CallerLabel) 80
      caller_session_id = ConvertTo-DtxCallSafeText ([string]$identity.CallerSessionId) 96
      identity_source = ConvertTo-DtxCallSafeText ([string]$identity.IdentitySource) 48
      command = ConvertTo-DtxCallSafeText $Command 64
      target_summary = Get-DtxCallTargetSummary $Command $Arguments
      tool_pid = [int]$PID
      tool_process_name = $processName
      tool_process_start_utc = $processStart
      tool_process_start_filetime = $processStartFileTime
      parent_pid = [int]$parentInfo.ParentPid
      parent_process_name = ConvertTo-DtxCallSafeText ([string]$parentInfo.ParentName) 64
      parent_process_start_utc = [string]$parentInfo.ParentStartUtc
      parent_process_start_filetime = [string]$parentInfo.ParentStartFileTime
      source_path = ConvertTo-DtxCallSafeText $sourcePath 512
      source_version = ConvertTo-DtxCallSafeText $toolVersion 32
      windows_session_id = $sessionId
      desktop_name = $desktopName
      started_utc = $started
      internal_token_sha256 = Get-DtxCallSha256 $token
    }
    $activePath = Join-Path $activeRoot ($invocationId + '.json')
    Write-DtxCallAtomicJson $activePath $record
    $activeById[$invocationId] = $record

    $overlapGroups = @{}
    foreach ($other in @($activeRecords)) {
      $otherRoot = [string]$other.root_invocation_id
      if ($otherRoot -ceq $rootInvocationId) { continue }
      if (-not $overlapGroups.ContainsKey($otherRoot)) { $overlapGroups[$otherRoot] = $other }
      elseif (($other.invocation_id -ceq $otherRoot) -or ([DateTime]::Parse([string]$other.started_utc) -lt [DateTime]::Parse([string]$overlapGroups[$otherRoot].started_utc))) { $overlapGroups[$otherRoot] = $other }
    }
    $lock.Dispose()
    $lock = $null
    if ($stateUnknown) { [Console]::Error.WriteLine('WARNING: desktop tool call-state=unknown; one or more state records could not be verified. This run is not reported as idle.') }
    if (([string]$identity.CallerLabel -ceq 'unknown') -or ([string]$identity.CallerSessionId -ceq 'unknown')) {
      [Console]::Error.WriteLine('WARNING: desktop tool caller identity=unknown; this invocation remains separately tracked and does not establish desktop exclusivity.')
    }
    foreach ($otherEntry in @($overlapGroups.GetEnumerator())) {
      $otherRoot = [string]$otherEntry.Key
      $other = $otherEntry.Value
      $otherStartedUtc = [string]$other.started_utc
      if ($other.started_utc -is [DateTime]) {
        $otherStartedUtc = $other.started_utc.ToUniversalTime().ToString('o', [Globalization.CultureInfo]::InvariantCulture)
      }
      [Console]::Error.WriteLine('WARNING: desktop tool overlap: caller=' + (ConvertTo-DtxCallSafeText ([string]$other.caller_label) 80) +
        ' session=' + (ConvertTo-DtxCallSafeText ([string]$other.caller_session_id) 8) +
        ' command=' + (ConvertTo-DtxCallSafeText ([string]$other.command) 64) +
        ' started=' + $otherStartedUtc + '; this call may steal focus or invalidate reads.')
    }

    $markerNames = @('DTX_CALL_INTERNAL_PARENT_ID','DTX_CALL_INTERNAL_PARENT_PID','DTX_CALL_INTERNAL_PARENT_START_FILETIME','DTX_CALL_INTERNAL_PARENT_TOKEN')
    $savedMarkers = @{}
    foreach ($markerName in $markerNames) { $savedMarkers[$markerName] = [Environment]::GetEnvironmentVariable($markerName, 'Process') }
    [Environment]::SetEnvironmentVariable('DTX_CALL_INTERNAL_PARENT_ID', $invocationId, 'Process')
    [Environment]::SetEnvironmentVariable('DTX_CALL_INTERNAL_PARENT_PID', [string]$PID, 'Process')
    [Environment]::SetEnvironmentVariable('DTX_CALL_INTERNAL_PARENT_START_FILETIME', $processStartFileTime, 'Process')
    [Environment]::SetEnvironmentVariable('DTX_CALL_INTERNAL_PARENT_TOKEN', $token, 'Process')
    return [pscustomobject]@{ Enabled = $true; InvocationId = $invocationId; ActivePath = $activePath; HistoryRoot = $historyRoot; LockPath = $lockPath; Record = $record; Token = $token; SavedMarkers = $savedMarkers }
  } catch {
    $reason = if ($_.Exception.Message -ceq 'lock-timeout') { 'lock-timeout' } else { 'state-unavailable' }
    [Console]::Error.WriteLine('WARNING: desktop tool call-state=unknown reason=' + $reason + '; no idle claim is made.')
    return $null
  } finally { if ($null -ne $lock) { $lock.Dispose() } }
}

function Complete-DtxCallTracking($Lease, [string]$ResultCategory, [int]$ExitCode, [string]$ErrorCategory = '') {
  if (($null -eq $Lease) -or (-not $Lease.Enabled)) { return }
  $lock = $null
  try {
    $record = $Lease.Record
    $record.status = 'complete'
    $record.ended_utc = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    $record.duration_ms = [long]([DateTime]::Parse([string]$record.ended_utc).Subtract([DateTime]::Parse([string]$record.started_utc)).TotalMilliseconds)
    $record.result_category = ConvertTo-DtxCallSafeText $ResultCategory 48
    $record.exit_code = [int]$ExitCode
    $record.error_category = ConvertTo-DtxCallSafeText $ErrorCategory 48
    $record.end_time_kind = 'recorded-at-process-exit'
    $record.internal_token_sha256 = ''
    # Each lease file has one writer, so an atomic replacement can mark completion before
    # we wait for the shared history lock. A later invocation can finish history recovery.
    Write-DtxCallAtomicJson ([string]$Lease.ActivePath) $record
    $lock = Enter-DtxCallLock ([string]$Lease.LockPath) 300
    if ($null -eq $lock) { throw 'lock-timeout' }
    # A concurrent recovery scan may have observed this completed active record after
    # the atomic status write but before this caller acquired the history lock.
    # Keep the history append idempotent under that handoff race.
    if (-not (Test-DtxCallHistoryHasId ([string]$Lease.HistoryRoot) ([string]$record.started_utc) ([string]$record.invocation_id))) {
      Write-DtxCallHistory $record ([string]$Lease.HistoryRoot)
    }
    [System.IO.File]::Delete([string]$Lease.ActivePath)
  } catch {
    [Console]::Error.WriteLine('WARNING: desktop tool call-history=unknown; this command result is unchanged and recovery may record the active lease later.')
  } finally {
    if ($null -ne $lock) { $lock.Dispose() }
    foreach ($markerEntry in @($Lease.SavedMarkers.GetEnumerator())) { [Environment]::SetEnvironmentVariable([string]$markerEntry.Key, [string]$markerEntry.Value, 'Process') }
  }
}
