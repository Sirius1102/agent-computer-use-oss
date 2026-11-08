# lib/quirks.ps1 - v4.10.0 (UU-absorb v1): the declarative per-window adaptation policy.
#    Absorbed pattern: NetEase UU Remote's streamer-config.json ships device-specific behavior as DATA
#    (declarative rules with regex matchers, remotely updatable, fail-closed on a rule the
#    client cannot understand) instead of hardcoding every special case. This file is this
#    repo's version of that: a JSON policy file (lib/quirks.json) matches windows by
#    process/class/title and attaches per-window overrides, so a NEW quirk lands as a rule
#    edit instead of a code branch.
#
#    Contract, stated so it can be tested:
#    - The file is OPTIONAL. No file anywhere = built-in defaults = today's behavior, byte
#      for byte. That is why nothing here can break an offline selftest run on a clean tree.
#    - The file is fail-closed: ANY schema violation (unknown key, wrong type, a matcher
#      regex that does not compile) rejects the WHOLE file, one WARNING on stderr, and
#      built-in defaults apply. A half-understood policy must never half-apply.
#    - First matching rule wins entirely. No merging - two rules fighting over one window
#      is a policy-authoring bug, and a merge order would silently pick the winner.
#    - v1 wires exactly ONE behavior knob (waitStableIntervalMs: the DEFAULT poll interval
#      of wait-stable, always losing to a caller-passed --interval) plus `note`, a string
#      surfaced at the point of failure (wait-stable's not-stable message) and by
#      `quirks --match`. Notes carry knowledge ("this window animates forever - prefer
#      wait-win or a sub-region") without changing any guard's semantics.
#
#    Data shapes (validated by Test-QuirksPolicyText):
#      { "schemaVersion": 1, "rules": [ {
#          "note":  "why this rule exists (optional, <= 200 chars)",
#          "match": { "process": "regex", "windowClass": "regex", "title": "regex" },  # >= 1
#          "set":   { "waitStableIntervalMs": 250 }                                    # optional
#      } ] }

# (No load-time $script: assignment on purpose: the cache initializes lazily through
# Get/Set-Variable below, the same house pattern the DPI-fallback latch uses - a top-level
# init here would join the load-time assignment family and owe the A-07 table a row.)

# Pure. Parses and validates policy TEXT; never touches the console, the cache or the disk
# beyond what the caller already read. Every violation names itself in Why - a rejected file
# the operator cannot diagnose is a policy file that will stay broken.
function Test-QuirksPolicyText([string]$text) {
  if ([string]$text.Trim() -eq '') { return @{ Ok = $false; Why = 'file is empty'; Rules = @() } }
  $doc = $null
  try { $doc = $text | ConvertFrom-Json } catch { return @{ Ok = $false; Why = ('invalid JSON: ' + $_.Exception.Message); Rules = @() } }
  if ($null -eq $doc) { return @{ Ok = $false; Why = 'JSON parsed to nothing'; Rules = @() } }
  # !! [string] applied to an ARRAY joins it with spaces ("schemaVersion rules" was measured
  # live through exactly this trap) - the property names go through one cast EACH, never a
  # cast of the collection.
  $topKeys = @($doc.PSObject.Properties.Name | ForEach-Object { [string]$_ })
  foreach ($k in @($topKeys)) { if (@('schemaVersion', 'rules') -notcontains $k) { return @{ Ok = $false; Why = ("unknown top-level key '" + $k + "' (valid: schemaVersion, rules)"); Rules = @() } } }
  if (-not ($topKeys -ccontains 'schemaVersion')) { return @{ Ok = $false; Why = 'missing schemaVersion'; Rules = @() } }
  if (-not ($topKeys -ccontains 'rules')) { return @{ Ok = $false; Why = 'missing rules'; Rules = @() } }
  if ("$($doc.schemaVersion)" -ne '1') { return @{ Ok = $false; Why = ("schemaVersion must be 1, got '" + "$($doc.schemaVersion)" + "'"); Rules = @() } }
  $rawRules = @()
  try { $rawRules = @($doc.rules) } catch { $rawRules = @() }
  if ($null -eq $doc.rules) { return @{ Ok = $false; Why = 'rules must be an array (null is not an array)'; Rules = @() } }
  $out = New-Object System.Collections.ArrayList
  $i = 0
  foreach ($r in $rawRules) {
    $i++
    if ($null -eq $r) { return @{ Ok = $false; Why = ("rule #$i is null"); Rules = @() } }
    $rKeys = @($r.PSObject.Properties.Name | ForEach-Object { [string]$_ })
    foreach ($k in @($rKeys)) { if (@('note', 'match', 'set') -notcontains $k) { return @{ Ok = $false; Why = ("rule #$i has unknown key '" + $k + "' (valid: note, match, set)"); Rules = @() } } }
    if (-not ($rKeys -ccontains 'match')) { return @{ Ok = $false; Why = ("rule #$i has no match object"); Rules = @() } }
    $mKeys = @($r.match.PSObject.Properties.Name | ForEach-Object { [string]$_ })
    foreach ($k in @($mKeys)) { if (@('process', 'windowClass', 'title') -notcontains $k) { return @{ Ok = $false; Why = ("rule #$i match has unknown key '" + $k + "' (valid: process, windowClass, title)"); Rules = @() } } }
    if (@($mKeys).Count -lt 1) { return @{ Ok = $false; Why = ("rule #$i match names no field (need at least one of: process, windowClass, title)"); Rules = @() } }
    $mOut = @{}
    foreach ($k in @($mKeys)) {
      $pat = ''
      try { $pat = [string]$r.match.$k } catch { $pat = '' }
      if ($pat -eq '') { return @{ Ok = $false; Why = ("rule #$i match.$k is empty - drop the key instead of matching everything with an empty string"); Rules = @() } }
      try { [void][regex]::new($pat) } catch { return @{ Ok = $false; Why = ("rule #$i match.$k is not a compilable regex ('" + $pat + "'): " + $_.Exception.Message); Rules = @() } }
      $mOut[$k] = $pat
    }
    $setOut = @{}
    if ($rKeys -ccontains 'set') {
      if ($null -eq $r.set) { return @{ Ok = $false; Why = ("rule #$i set is null (drop the key instead)"); Rules = @() } }
      $sKeys = @($r.set.PSObject.Properties.Name | ForEach-Object { [string]$_ })
      foreach ($k in @($sKeys)) {
        if (@('waitStableIntervalMs') -notcontains $k) { return @{ Ok = $false; Why = ("rule #$i set has unknown key '" + $k + "' (v1 wires exactly: waitStableIntervalMs)"); Rules = @() } }
        $nv = 0
        $sv = ''
        try { $sv = [string]$r.set.$k } catch { $sv = '' }
        if ($sv -notmatch '^[0-9]+$') { return @{ Ok = $false; Why = ("rule #$i set.waitStableIntervalMs must be a whole number, got '" + $sv + "'"); Rules = @() } }
        $nv = [int]$sv
        if ($nv -lt 50 -or $nv -gt 5000) { return @{ Ok = $false; Why = ("rule #$i set.waitStableIntervalMs must be 50..5000, got $nv"); Rules = @() } }
        $setOut[$k] = $nv
      }
    }
    $noteTxt = ''
    if ($rKeys -ccontains 'note') {
      try { $noteTxt = [string]$r.note } catch { $noteTxt = '' }
      if ($noteTxt.Length -gt 200) { return @{ Ok = $false; Why = ("rule #$i note exceeds 200 chars (" + $noteTxt.Length + ") - it travels inside failure messages, so it stays short"); Rules = @() } }
    }
    [void]$out.Add(@{ Note = $noteTxt; Match = $mOut; Set = $setOut })
  }
  return @{ Ok = $true; Why = ''; Rules = @($out) }
}

# Lazy, cached, never throws. Resolves the policy file (script dir first - the stitched
# single-file delivery - then lib\ next to it, the repository form), reads and validates it
# once, and reports the verdict the same way whether or not a file exists: Loaded tells the
# truth, Error names the reason, and a rejected or unreadable file warns ONCE on stderr and
# then behaves, for the rest of the process, exactly like no file at all.
function Get-QuirksState {
  $cached = $null
  try { $cached = Get-Variable -Name 'QuirksStateCache' -Scope Script -ValueOnly -ErrorAction SilentlyContinue } catch { $cached = $null }
  if ($null -ne $cached) { return $cached }
  $found = ''
  foreach ($c in @((Join-Path $script:ToolRootPath 'quirks.json'), (Join-Path $script:ToolRootPath 'lib/quirks.json'))) {
    if (Test-Path -LiteralPath $c -PathType Leaf) { $found = $c; break }
  }
  if ($found -eq '') {
    Set-Variable -Name 'QuirksStateCache' -Scope Script -Value @{ Loaded = $false; File = ''; RuleCount = 0; Error = ''; Rules = @() }
    return (Get-Variable -Name 'QuirksStateCache' -Scope Script -ValueOnly)
  }
  $text = ''
  try { $text = [System.IO.File]::ReadAllText($found) } catch {
    Set-Variable -Name 'QuirksStateCache' -Scope Script -Value @{ Loaded = $false; File = $found; RuleCount = 0; Error = ('read failed: ' + $_.Exception.Message); Rules = @() }
    [Console]::Error.WriteLine('WARNING: quirks policy ' + $found + ' could not be read - built-in defaults apply (' + $script:QuirksStateCache.Error + ')')
    return $script:QuirksStateCache
  }
  $v = Test-QuirksPolicyText $text
  if (-not [bool]$v.Ok) {
    Set-Variable -Name 'QuirksStateCache' -Scope Script -Value @{ Loaded = $false; File = $found; RuleCount = 0; Error = [string]$v.Why; Rules = @() }
    [Console]::Error.WriteLine('WARNING: quirks policy ' + $found + ' rejected - built-in defaults apply (' + $v.Why + ')')
    return $script:QuirksStateCache
  }
  Set-Variable -Name 'QuirksStateCache' -Scope Script -Value @{ Loaded = $true; File = $found; RuleCount = @($v.Rules).Count; Error = ''; Rules = @($v.Rules) }
  return $script:QuirksStateCache
}

# Pure matcher: every field the rule NAMES must match (a rule that names nothing cannot
# exist - the validator refuses it). An uncompilable regex cannot reach here (validated at
# load), but the defensive catch keeps the matcher itself honest under any caller.
function Test-QuirkRuleMatch($rule, [string]$proc, [string]$class, [string]$title) {
  if ($null -eq $rule -or $null -eq $rule.Match) { return $false }
  foreach ($k in @(Get-HashKeys $rule.Match)) {
    $pat = [string]$rule.Match[$k]
    $val = $proc
    if ($k -ceq 'windowClass') { $val = $class }
    elseif ($k -ceq 'title') { $val = $title }
    try { if (-not [regex]::IsMatch([string]$val, $pat)) { return $false } } catch { return $false }
  }
  return $true
}

# The one lookup the wired commands call. Never throws, never returns $null: an unmatched
# window (or a rejected policy) is Matched=$false with an empty Set - the built-in defaults.
function Get-WindowQuirks($w) {
  $res = @{ Matched = $false; RuleIndex = 0; Set = @{}; Note = '' }
  if ($null -eq $w) { return $res }
  $st = Get-QuirksState
  if (-not [bool]$st.Loaded) { return $res }
  $i = 0
  foreach ($r in @($st.Rules)) {
    $i++
    if (Test-QuirkRuleMatch $r ([string]$w.Proc) ([string]$w.Class) ([string]$w.Title)) {
      return @{ Matched = $true; RuleIndex = $i; Set = $r.Set; Note = [string]$r.Note }
    }
  }
  return $res
}
