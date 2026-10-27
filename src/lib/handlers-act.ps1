# lib/handlers-act.ps1 - the act-group handlers, lifted out of desktop.ps1 (A-17..A-19 line).
#    Byte-identical to what the dispatcher carried after A-15 pen 2: the union of the lifted lines was
#    hashed before the cut and the same bytes are re-hashed from this file afterwards (printed by
#    handler-lift.js, and recorded in the ledger row for this card). The group membership is declared in
#    $script:StHandlerGroups and reconciled against the definitions by lint (A-16) - this file is named in
#    $script:StHandlerFiles in the same write that removes the code from the entry, so neither half can
#    land on its own.

# v4.4.0 (A-15): move - the case body, verbatim
function Invoke-Handler-move([string]$Cmd, [string[]]$Rest) {
      # move <x> <y> - v1.5.0 WP-3: echoes the top-level window under the point
      # (hit-window) so a moved cursor is never silently parked over the wrong
      # app. move takes no --to, so the echo never blocks (the landing guard
      # applies to the click-family commands).
      if ($Rest.Count -lt 2) { throw 'usage: move <x> <y>' }
      Log-Action $Rest "coords=$($Rest[0]),$($Rest[1])" $Cmd
      [void][DT]::SetCursorPos([int]$Rest[0], [int]$Rest[1])
      Start-Sleep -Milliseconds 120
      "moved to $($Rest[0]),$($Rest[1])"
      Invoke-HitWindowCheck ([int]$Rest[0]) ([int]$Rest[1]) $null $false $false
}

# v4.4.0 (A-15): hover - the case body, verbatim
function Invoke-Handler-hover([string]$Cmd, [string[]]$Rest) {
      # hover <x> <y> [--dwell ms] - move and STAY. Tooltips only render after a
      # short dwell and `move` returns at once, so pointer-triggered popups were
      # invisible to the agent unless the cursor happened to stop there (audit
      # 2026-09-29b #8). The cursor position is global state and survives this
      # process exiting; the dwell is what makes the tooltip actually appear.
      # v1.5.5 (D-1): --dwell is THIS command's flag, so it is stripped before
      # Split-Target (which refuses unknown --x by design). Until now it was read
      # out of $p.Words afterwards, i.e. never reachable - 'hover ... --dwell 50'
      # died with "unknown flag '--dwell"' while help and README advertised it.
      $own = Strip-OwnFlags $Rest 'hover'
      $dwell = [int]$own.Values['--dwell']
      $p = Split-Target @($own.Rest) 'hover'
      if ($p.Words.Count -lt 2) { throw 'usage: hover <x> <y> [--dwell ms] [--to <sel>] [--allow-outside]' }
      # v1.5.0 WP-3: same landing guard as the click family - when --to names a
      # window, a hover point outside its visible rect is refused by default
      # (cursor not moved) unless --allow-outside; without --to it only echoes.
      $hw = $null
      if ($p.Sel) {
        $hw = Resolve-Window $p.Sel
        if (-not $hw) { throw "no window matching: $($p.Sel)" }
        Emit-ResolveNote
      }
      Invoke-HitWindowCheck ([int]$p.Words[0]) ([int]$p.Words[1]) $hw ($p.Sel -ne '') $p.AllowOutside
      Log-Action $Rest "coords=$($p.Words[0]),$($p.Words[1]) dwell=$dwell" $Cmd
      [void][DT]::SetCursorPos([int]$p.Words[0], [int]$p.Words[1])
      Start-Sleep -Milliseconds $dwell
      "hovering ($($p.Words[0]),$($p.Words[1])) for ${dwell}ms - pointer popup should be visible now; screenshot to read it"
}

# v4.4.0 (A-15): click - the case body, verbatim
function Invoke-Handler-click([string]$Cmd, [string[]]$Rest) {
      # click <x> <y> [--button left|right|middle|back|forward] [--mods ctrl+shift...]
      #       [--to <sel>] [--guard-text <s>|--guard-region x,y,w,h=s] [--expect <needle>|--expect-gone <needle>] [--force]
      # v1.4.0: a bare coordinate click is still unguarded (it targets whatever
      # sits at the point), but --to activates + verifies a window first and the
      # content guard can assert context BEFORE the click - the audit-point that
      # coordinate clicks were the only zero-guard link in the chain.
      # CU-OPS package B: --button and --mods are stripped BEFORE Split-Target and
      # validated before the pointer moves, so an unknown button or an already-held
      # modifier refuses with no input sent.
      $own = Strip-OwnFlags $Rest 'click'
      $p = Split-Target @($own.Rest)
      if ($p.Words.Count -lt 2) { throw 'usage: click <x> <y> [--button left|right|middle|back|forward] [--mods ctrl+shift] [--space screen|window|client] [--created <iso>] [--to <sel>] [--guard-text <s>|--guard-region x,y,w,h=s] [--expect <needle>|--expect-gone <needle>] [--allow-outside] [--force]' }
      $button = if ($own.Present['--button']) { [string]$own.Values['--button'] } else { 'left' }
      $mods = [string]$own.Values['--mods']
      # CU-OPS package D: the coordinate space is validated before the pointer moves,
      # and the window origin is read AFTER resolution (see Get-PointSpaceOrigin).
      $space = Test-PointSpaceArg ([string]$own.Values['--space'])
      if ($space -ne 'screen' -and -not $p.Sel) { throw "--space $space needs --to <sel>: a relative point with no named window has no defined origin (the foreground window is not an identity); no input was sent" }
      $created = [string]$own.Values['--created']
      [void](Get-MouseButtonSpec $button)
      [void](Resolve-MouseModifiers $mods)
      $tgt = $null
      if ($p.Sel -or $p.GuardText -or $p.GuardRegion -or $created -or ($space -ne 'screen')) {
        $tgt = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle $created
        Emit-ResolveNote
        if ($p.GuardText -or $p.GuardRegion) {
          Invoke-ContentGuard $tgt $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
        }
      }
      $rx = [int]$p.Words[0]; $ry = [int]$p.Words[1]
      $origin = Get-PointSpaceOrigin $space $tgt
      $pt = Convert-PointSpace $rx $ry $origin
      Invoke-HitWindowCheck $pt.X $pt.Y $tgt ($p.Sel -ne '') $p.AllowOutside
      $ecb = Get-ExpectChangeBaseline $p $tgt
      $clickLogArgs = Get-RedactedLogArgs $Rest @() $p.LogPayload
      if ($null -ne $tgt) { $clickLogArgs = @($clickLogArgs) + @("pid=$($tgt.Pid)") }
      $spaceLog = if ($origin.Space -eq 'screen') { '' } else { " space=$($origin.Space) rel=$rx,$ry" }
      Log-Action $clickLogArgs "coords=$($pt.X),$($pt.Y)$spaceLog button=$($button.ToLowerInvariant()) mods=$(if ($mods) { $mods.ToLowerInvariant() } else { 'none' })" $Cmd
      Move-Click $pt.X $pt.Y $button $mods
      "clicked $($pt.X),$($pt.Y)$(Format-PointSpaceReceipt $origin $rx $ry) button=$($button.ToLowerInvariant())$(if ($mods) { ' mods=' + $mods.ToLowerInvariant() })$($script:LastMouseReceipt)"
      Invoke-ExpectChangeCheck $p $ecb 'clicked'
      Invoke-ActionExpectation $p $tgt 'clicked'
}

# v4.4.0 (A-15): rclick - the case body, verbatim
function Invoke-Handler-rclick([string]$Cmd, [string[]]$Rest) {
      # rclick <x> <y> [--mods shift...] [--to <sel>] [--guard-text <s>|--guard-region x,y,w,h=s] [--allow-outside] [--force] (guards + landing check like click)
      $own = Strip-OwnFlags $Rest 'rclick'
      $p = Split-Target @($own.Rest)
      if ($p.Words.Count -lt 2) { throw 'usage: rclick <x> <y> [--mods shift] [--space screen|window|client] [--created <iso>] [--to <sel>] [--guard-text <s>|--guard-region x,y,w,h=s] [--allow-outside] [--force]' }
      $mods = [string]$own.Values['--mods']
      $space = Test-PointSpaceArg ([string]$own.Values['--space'])
      if ($space -ne 'screen' -and -not $p.Sel) { throw "--space $space needs --to <sel>: a relative point with no named window has no defined origin (the foreground window is not an identity); no input was sent" }
      $created = [string]$own.Values['--created']
      [void](Resolve-MouseModifiers $mods)
      $tgt = $null
      if ($p.Sel -or $p.GuardText -or $p.GuardRegion -or $created -or ($space -ne 'screen')) {
        $tgt = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle $created
        Emit-ResolveNote
        if ($p.GuardText -or $p.GuardRegion) {
          Invoke-ContentGuard $tgt $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
        }
      }
      $rx = [int]$p.Words[0]; $ry = [int]$p.Words[1]
      $origin = Get-PointSpaceOrigin $space $tgt
      $pt = Convert-PointSpace $rx $ry $origin
      Invoke-HitWindowCheck $pt.X $pt.Y $tgt ($p.Sel -ne '') $p.AllowOutside
      $ecb = Get-ExpectChangeBaseline $p $tgt
      $spaceLog = if ($origin.Space -eq 'screen') { '' } else { " space=$($origin.Space) rel=$rx,$ry" }
      Log-Action (Get-RedactedLogArgs $Rest @() $p.LogPayload) "coords=$($pt.X),$($pt.Y)$spaceLog mods=$(if ($mods) { $mods.ToLowerInvariant() } else { 'none' })" $Cmd
      Move-Click $pt.X $pt.Y 'right' $mods
      "right-clicked $($pt.X),$($pt.Y)$(Format-PointSpaceReceipt $origin $rx $ry)$(if ($mods) { ' mods=' + $mods.ToLowerInvariant() })$($script:LastMouseReceipt)"
      Invoke-ExpectChangeCheck $p $ecb 'right-clicked'
      Invoke-ActionExpectation $p $tgt 'right-clicked'
}

# v4.4.0 (A-15): dblclick - the case body, verbatim
function Invoke-Handler-dblclick([string]$Cmd, [string[]]$Rest) {
      # dblclick <x> <y> [--mods ctrl+shift...] [--to <sel>] [--guard-text <s>|--guard-region x,y,w,h=s] [--force] (guards like click)
      $own = Strip-OwnFlags $Rest 'dblclick'
      $p = Split-Target @($own.Rest)
      if ($p.Words.Count -lt 2) { throw 'usage: dblclick <x> <y> [--mods ctrl+shift] [--space screen|window|client] [--created <iso>] [--to <sel>] [--guard-text <s>|--guard-region x,y,w,h=s] [--allow-outside] [--force]' }
      $mods = [string]$own.Values['--mods']
      $space = Test-PointSpaceArg ([string]$own.Values['--space'])
      if ($space -ne 'screen' -and -not $p.Sel) { throw "--space $space needs --to <sel>: a relative point with no named window has no defined origin (the foreground window is not an identity); no input was sent" }
      $created = [string]$own.Values['--created']
      [void](Resolve-MouseModifiers $mods)
      $tgt = $null
      if ($p.Sel -or $p.GuardText -or $p.GuardRegion -or $created -or ($space -ne 'screen')) {
        $tgt = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle $created
        Emit-ResolveNote
        if ($p.GuardText -or $p.GuardRegion) {
          Invoke-ContentGuard $tgt $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
        }
      }
      $rx = [int]$p.Words[0]; $ry = [int]$p.Words[1]
      $origin = Get-PointSpaceOrigin $space $tgt
      $pt = Convert-PointSpace $rx $ry $origin
      Invoke-HitWindowCheck $pt.X $pt.Y $tgt ($p.Sel -ne '') $p.AllowOutside
      $spaceLog = if ($origin.Space -eq 'screen') { '' } else { " space=$($origin.Space) rel=$rx,$ry" }
      Log-Action (Get-RedactedLogArgs $Rest @() $p.LogPayload) "coords=$($pt.X),$($pt.Y)$spaceLog mods=$(if ($mods) { $mods.ToLowerInvariant() } else { 'none' })" $Cmd
      $ecb = Get-ExpectChangeBaseline $p $tgt
      $script:LastMouseReceipt = ''
      $mx = $pt.X; $my = $pt.Y
      $dbl = {
        [void][DT]::SetCursorPos($mx, $my)
        Start-Sleep -Milliseconds 150
        1..2 | ForEach-Object {
          [DT]::mouse_event($MOUSE_LDOWN, 0, 0, 0, [IntPtr]::Zero)
          Start-Sleep -Milliseconds 40
          [DT]::mouse_event($MOUSE_LUP, 0, 0, 0, [IntPtr]::Zero)
          Start-Sleep -Milliseconds 60
        }
      }
      if ($mods) {
        $rc = Invoke-ModifierGesture @(Resolve-MouseModifiers $mods) $dbl
        $script:LastMouseReceipt = (Format-ModifierReceipt $rc)
      } else { & $dbl }
      "double-clicked $($pt.X),$($pt.Y)$(Format-PointSpaceReceipt $origin $rx $ry)$(if ($mods) { ' mods=' + $mods.ToLowerInvariant() })$($script:LastMouseReceipt)"
      Invoke-ExpectChangeCheck $p $ecb 'double-clicked'
      Invoke-ActionExpectation $p $tgt 'double-clicked'
}

# CU-REL-02 (v4.5.1): validate the legacy raw-delta form and the explicit notch form
# before the handler moves the pointer or calls the input backend.
function Resolve-WheelRequest([string[]]$Words, [string]$Unit, [string]$Axis) {
      $unitKey = ([string]$Unit).ToLowerInvariant()
      $axisKey = ([string]$Axis).ToLowerInvariant()
      if ($unitKey -notin @('raw', 'notches')) { throw "wheel: '--unit' must be raw or notches, got '$Unit'" }
      if ($axisKey -notin @('vertical', 'horizontal')) { throw "wheel: '--axis' must be vertical or horizontal, got '$Axis'" }
      $wordsCopy = @($Words)
      $amountPresent = $wordsCopy.Count -gt 0
      if ($unitKey -eq 'notches' -and -not $amountPresent) { throw "wheel: '--unit notches' requires an explicit amount" }
      $original = if ($amountPresent) { [string]$wordsCopy[0] } else { '-120' }
      if ($original -notmatch '^-?\d+$') { throw "wheel: amount must be a whole integer, got '$original'" }
      $amount64 = [long]0
      $parsed = [long]::TryParse($original, [Globalization.NumberStyles]::AllowLeadingSign, [Globalization.CultureInfo]::InvariantCulture, [ref]$amount64)
      if (-not $parsed) { throw "wheel: amount is outside the supported integer range, got '$original'" }
      if ($unitKey -eq 'notches') {
        $minNotches = [long][Math]::Ceiling(([double][int]::MinValue) / 120.0)
        $maxNotches = [long][Math]::Floor(([double][int]::MaxValue) / 120.0)
        if ($amount64 -lt $minNotches -or $amount64 -gt $maxNotches) {
          throw "wheel: notches amount '$original' overflows the signed 32-bit raw delta after multiplying by 120"
        }
        $rawDelta = [int]($amount64 * 120)
      } else {
        if ($amount64 -lt [int]::MinValue -or $amount64 -gt [int]::MaxValue) {
          throw "wheel: raw amount '$original' must fit a signed 32-bit delta"
        }
        $rawDelta = [int]$amount64
      }
      $direction = if ($rawDelta -eq 0) { 'none' }
        elseif ($axisKey -eq 'vertical' -and $rawDelta -gt 0) { 'up' }
        elseif ($axisKey -eq 'vertical') { 'down' }
        elseif ($rawDelta -gt 0) { 'right' }
        else { 'left' }
      $inputFlag = if ($axisKey -eq 'vertical') { $MOUSE_WHEEL } else { $MOUSE_HWHEEL }
      $eventName = if ($axisKey -eq 'vertical') { 'MOUSE_WHEEL' } else { 'MOUSE_HWHEEL' }
      return [pscustomobject]@{
        OriginalAmount = $original
        AmountSource = if ($amountPresent) { 'argument' } else { 'legacy-default' }
        Unit = $unitKey
        Axis = $axisKey
        Direction = $direction
        RawDelta = $rawDelta
        InputFlag = [uint32]$inputFlag
        EventName = $eventName
      }
}

# CU-REL-03 (v4.5.2): obtain a fresh target rectangle and point observation before any
# focus-first click and again after it. A top-level identity match is necessary but is not
# a claim that the exact child control accepted the wheel event.
function Get-WheelPointObservation([int]$X, [int]$Y, $Target, [string]$Phase, [bool]$RequireForeground = $false) {
      $rect = $null
      if ($null -ne $Target) {
        if (-not [DT]::IsWindow($Target.Handle)) { throw "wheel target guard ($Phase): target hwnd=$($Target.Handle) no longer exists; no wheel input was sent." }
        if ([DT]::IsIconic($Target.Handle)) { throw "wheel target guard ($Phase): target hwnd=$($Target.Handle) is minimized; no wheel input was sent." }
        if (-not [DT]::IsWindowVisible($Target.Handle)) { throw "wheel target guard ($Phase): target hwnd=$($Target.Handle) is not visible; no wheel input was sent." }
        $rect = Get-WindowVisibleRect $Target.Handle
        if ($null -eq $rect -or $rect.W -le 0 -or $rect.H -le 0 -or $rect.X -le -32000 -or $rect.Y -le -32000) {
          throw "wheel target guard ($Phase): target hwnd=$($Target.Handle) has no usable visible rectangle; no wheel input was sent. Re-read it with 'wins'."
        }
        $Target | Add-Member -NotePropertyName Left -NotePropertyValue $rect.X -Force
        $Target | Add-Member -NotePropertyName Top -NotePropertyValue $rect.Y -Force
        $Target | Add-Member -NotePropertyName W -NotePropertyValue $rect.W -Force
        $Target | Add-Member -NotePropertyName H -NotePropertyValue $rect.H -Force
        $Target | Add-Member -NotePropertyName Right -NotePropertyValue ($rect.X + $rect.W) -Force
        $Target | Add-Member -NotePropertyName Bottom -NotePropertyValue ($rect.Y + $rect.H) -Force
        if ($X -lt $rect.X -or $X -ge ($rect.X + $rect.W) -or $Y -lt $rect.Y -or $Y -ge ($rect.Y + $rect.H)) {
          throw "wheel target guard ($Phase): scroll point ($X,$Y) is outside target hwnd=$($Target.Handle) visible rect ($($rect.X),$($rect.Y),$($rect.W)x$($rect.H)); no wheel input was sent."
        }
      }
      $hit = Get-HitWindow $X $Y
      $foreground = [DT]::GetForegroundWindow()
      if ($null -ne $Target) {
        $observed = if ($null -eq $hit) { '(none)' } else { "pid=$($hit.Pid) hwnd=$($hit.Hwnd) title='$($hit.Title)'" }
        if ($null -eq $hit -or $hit.Hwnd -ne $Target.Handle) {
          throw "wheel target guard ($Phase): scroll point ($X,$Y) observes $observed, not target hwnd=$($Target.Handle) '$($Target.Title)'; no wheel input was sent."
        }
        if ($RequireForeground -and $foreground -ne $Target.Handle) {
          throw "wheel target guard ($Phase): --focus-first left foreground hwnd=$foreground instead of target hwnd=$($Target.Handle); no wheel input was sent."
        }
      }
      return [pscustomobject]@{ X = $X; Y = $Y; Hit = $hit; Foreground = $foreground; Rect = $rect; TargetVerified = ($null -ne $Target); Phase = $Phase }
}

# CU-REL-04 (v4.5.3): read the nearest usable ScrollPattern at the selected point,
# walking only within the selected top-level window. UIA absence is a measurement
# limit, never a synthetic position.
function Get-WheelScrollObservation([int]$X, [int]$Y, $Target, [string]$Axis) {
      $r = @{ Available = $false; Reason = 'uia-unavailable'; Position = $null; ContainerId = ''; Axis = $Axis }
      try {
        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes
        $root = [System.Windows.Automation.AutomationElement]::FromHandle($Target.Handle)
        if ($null -eq $root) { $r.Reason = 'target-uia-root-unavailable'; return $r }
        $rootId = (@($root.GetRuntimeId()) -join ',')
        if (-not $rootId) { $r.Reason = 'target-uia-identity-unavailable'; return $r }
        $point = New-Object System.Windows.Point($X, $Y)
        $node = [System.Windows.Automation.AutomationElement]::FromPoint($point)
        if ($null -eq $node) { $r.Reason = 'point-uia-element-unavailable'; return $r }
        $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
        $rootSeen = $false
        for ($depth = 0; $depth -le 64 -and $null -ne $node; $depth++) {
          $nodeId = ''
          try { $nodeId = (@($node.GetRuntimeId()) -join ',') } catch { }
          if ($nodeId -and $nodeId -ceq $rootId) { $rootSeen = $true }
          if ($nodeId) {
            try {
              $pattern = $node.GetCurrentPattern([System.Windows.Automation.ScrollPattern]::Pattern)
              $info = $pattern.Current
              $scrollable = if ($Axis -ceq 'vertical') { [bool]$info.VerticallyScrollable } else { [bool]$info.HorizontallyScrollable }
              $position = if ($Axis -ceq 'vertical') { [double]$info.VerticalScrollPercent } else { [double]$info.HorizontalScrollPercent }
              if ($scrollable -and $position -ge 0 -and $position -le 100) {
                return @{ Available = $true; Reason = ''; Position = $position; ContainerId = $nodeId; Axis = $Axis }
              }
            } catch { }
          }
          if ($rootSeen) { break }
          try { $node = $walker.GetParent($node) } catch { $node = $null }
        }
        $r.Reason = if ($rootSeen) { 'no-scroll-pattern-for-axis' } else { 'point-not-in-selected-window-tree' }
        return $r
      } catch {
        $r.Reason = 'uia-scroll-read-failed'
        return $r
      }
}

# Pure: map the requested direction to the UIA edge. The caller avoids sending
# an event when the known position is already at that edge.
function Test-WheelScrollBoundary([double]$Position, [string]$Axis, [int]$RawDelta) {
      if ($RawDelta -eq 0) { return $false }
      if ($Axis -ceq 'vertical') {
        if ($RawDelta -gt 0) { return ($Position -le 0) }
        return ($Position -ge 100)
      }
      if ($RawDelta -gt 0) { return ($Position -ge 100) }
      return ($Position -le 0)
}

# Pure: a same-axis position change in the wrong direction is not a successful
# observation of this request (and may reflect unrelated activity).
function Test-WheelScrollDirection([double]$Before, [double]$After, [string]$Axis, [int]$RawDelta) {
      if ([Math]::Abs($After - $Before) -lt 0.01 -or $RawDelta -eq 0) { return $false }
      if ($Axis -ceq 'vertical') {
        if ($RawDelta -gt 0) { return ($After -lt $Before) }
        return ($After -gt $Before)
      }
      if ($RawDelta -gt 0) { return ($After -gt $Before) }
      return ($After -lt $Before)
}

# CU-REL-04: a bounded ControlView scan for a caller-specified visible UIA name.
# It reports no text only when the complete bounded tree was readable; otherwise
# the caller must report verification unavailable.
function Get-WheelVisibleTextObservation($Target, [string]$Needle) {
      $r = @{ Available = $false; Found = $false; Reason = 'uia-unavailable'; Scanned = 0; NodeId = '' }
      if ([string]::IsNullOrWhiteSpace($Needle)) { $r.Reason = 'empty-needle'; return $r }
      try {
        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes
        $root = [System.Windows.Automation.AutomationElement]::FromHandle($Target.Handle)
        if ($null -eq $root) { $r.Reason = 'target-uia-root-unavailable'; return $r }
        $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
        $nodes = New-Object System.Collections.ArrayList
        [void]$nodes.Add($root)
        $cursor = 0; $incomplete = 0; $maxNodes = 512
        while ($cursor -lt $nodes.Count) {
          if ($cursor -ge $maxNodes) { $r.Reason = 'uia-node-cap'; $r.Scanned = $cursor; return $r }
          $node = $nodes[$cursor]
          $cursor++
          $name = ''; $offscreen = $true; $rect = $null
          try { $name = [string]$node.Current.Name } catch { $incomplete++ }
          try { $offscreen = [bool]$node.Current.IsOffscreen } catch { $incomplete++ }
          try { $rect = $node.Current.BoundingRectangle } catch { $incomplete++ }
          if (-not $offscreen -and $null -ne $rect -and -not $rect.IsEmpty -and $rect.Width -gt 0 -and $rect.Height -gt 0 -and $name.Length -gt 0) {
            $right = [double]$Target.Right; $bottom = [double]$Target.Bottom
            $inside = ($rect.X -lt $right) -and (($rect.X + $rect.Width) -gt [double]$Target.Left) -and
              ($rect.Y -lt $bottom) -and (($rect.Y + $rect.Height) -gt [double]$Target.Top)
            if ($inside -and $name.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
              $id = ''
              try { $id = (@($node.GetRuntimeId()) -join ',') } catch { }
              return @{ Available = $true; Found = $true; Reason = ''; Scanned = $cursor; NodeId = $id }
            }
          }
          try {
            $child = $walker.GetFirstChild($node)
            while ($null -ne $child) {
              if ($nodes.Count -ge $maxNodes) { $r.Reason = 'uia-node-cap'; $r.Scanned = $cursor; return $r }
              [void]$nodes.Add($child)
              $child = $walker.GetNextSibling($child)
            }
          } catch { $r.Reason = 'uia-child-enumeration-failed'; $r.Scanned = $cursor; return $r }
        }
        if ($incomplete -gt 0) { $r.Reason = 'uia-properties-incomplete'; $r.Scanned = $cursor; return $r }
        return @{ Available = $true; Found = $false; Reason = ''; Scanned = $cursor; NodeId = '' }
      } catch {
        $r.Reason = 'uia-content-read-failed'
        return $r
      }
}

# CU-REL-03 (v4.5.2): target flags assert the window under the actual scroll point.
# --at no longer invents the window centre: it requires explicit x/y for a panel.
# Without a selector, the old current-cursor path remains available.
function Invoke-Handler-wheel([string]$Cmd, [string[]]$Rest) {
      # wheel [amount] [x y] [--unit raw|notches] [--axis vertical|horizontal]
      #       [--to <sel>|--at <sel>] [--focus-first] [--expect-change ...]
      #       [--verify-scroll [--expect-change x,y,w,h]|--expect-visible-text <needle>]
      $own = Strip-OwnFlags $Rest 'wheel'
      $ff = [bool]$own.Values['--focus-first']
      $verifyScroll = [bool]$own.Values['--verify-scroll']
      $expectVisibleText = [string]$own.Values['--expect-visible-text']
      $unit = if ($own.Present['--unit']) { [string]$own.Values['--unit'] } else { 'raw' }
      $axis = if ($own.Present['--axis']) { [string]$own.Values['--axis'] } else { 'vertical' }
      # CU-OPS package B: modifiers are an INPUT to the wheel event. What the application
      # does with Ctrl+wheel (zoom, horizontal pan, nothing) is the application's decision,
      # so --verify-scroll is refused with modifiers: a ScrollPattern position change would
      # be read as "the wheel worked" while the gesture was really a zoom request.
      $mods = [string]$own.Values['--mods']
      # CU-OPS package D: relative scroll points are converted against the resolved
      # target right before the cursor moves (never against a point kept from earlier).
      $space = Test-PointSpaceArg ([string]$own.Values['--space'])
      $created = [string]$own.Values['--created']
      $modList = @(Resolve-MouseModifiers $mods)
      if ($modList.Count -gt 0 -and $verifyScroll) {
        throw "wheel: '--verify-scroll' cannot be combined with --mods '$mods' - with modifiers a wheel event is an application-defined gesture (zoom, pan, ...) and a changed ScrollPattern position is not evidence it did what you asked; use '--expect-visible-text <needle>' or '--expect-change x,y,w,h' instead; no wheel input was sent"
      }
      if ($unit.ToLowerInvariant() -notin @('raw', 'notches')) { throw "wheel: '--unit' must be raw or notches, got '$unit'" }
      if ($axis.ToLowerInvariant() -notin @('vertical', 'horizontal')) { throw "wheel: '--axis' must be vertical or horizontal, got '$axis'" }
      $atPresent = [bool]$own.Present['--at']
      $atSel = "$($own.Values['--at'])"
      if ($atPresent -and (-not $atSel -or $atSel -like '--*')) { throw "wheel: '--at' needs a window selector value" }
      $p = Split-Target @($own.Rest) 'wheel'
      if ($atPresent -and $p.Sel) { throw "wheel: choose one target selector, either '--to <sel>' or '--at <sel>', not both" }
      if ($p.Sel -like '--*') { throw "wheel: '--to' needs a window selector value, got flag '$($p.Sel)'" }
      $wordCount = @($p.Words).Count
      if ($wordCount -notin @(0, 1, 3)) { throw "usage: wheel [amount] [x y] [--unit raw|notches] [--axis vertical|horizontal] [--to <sel>|--at <sel>] [--focus-first] [--expect-change [x,y,w,h]] [--verify-scroll [--expect-change x,y,w,h]|--expect-visible-text <needle>] - coordinates must be a complete x/y pair" }
      if ($atPresent -and $wordCount -ne 3) { throw "wheel: '--at <sel>' requires explicit x y coordinates for the scroll point; a window centre does not identify the target control" }
      if ($space -ne 'screen' -and $wordCount -ne 3) { throw "wheel: '--space $space' needs explicit x y - a relative space with no point has nothing to convert; no input was sent" }
      $wheelRequest = Resolve-WheelRequest @($p.Words) $unit $axis
      $verificationRequested = $verifyScroll -or -not [string]::IsNullOrWhiteSpace($expectVisibleText)
      if ($verifyScroll -and -not [string]::IsNullOrWhiteSpace($expectVisibleText)) { throw "wheel: choose one verification route: '--verify-scroll' or '--expect-visible-text <needle>'" }
      if ($own.Present['--expect-visible-text'] -and [string]::IsNullOrWhiteSpace($expectVisibleText)) { throw "wheel: '--expect-visible-text' needs a non-empty UIA name substring" }
      if ($expectVisibleText.Length -gt 512) { throw 'wheel: --expect-visible-text is limited to 512 characters' }
      if ($verificationRequested -and (-not ($p.Sel -or $atPresent) -or $wordCount -ne 3)) {
        throw 'wheel verification requires --to <sel> or --at <sel> and an explicit amount x y scroll point; no input was sent'
      }
      if ($verificationRequested -and [int]$wheelRequest.RawDelta -eq 0) { throw 'wheel verification requires a non-zero wheel delta; no input was sent' }
      if (-not [string]::IsNullOrWhiteSpace($expectVisibleText) -and $p.ExpectChange) {
        throw "wheel: '--expect-visible-text' cannot be combined with pixel-only '--expect-change'"
      }
      $wx = 0; $wy = 0
      if ($wordCount -eq 3) {
        $wx = Read-FlagNumber 'wheel x' $p.Words[1] $true '(screen pixels)'
        $wy = Read-FlagNumber 'wheel y' $p.Words[2] $true '(screen pixels)'
      }
      $targetSel = if ($atPresent) { $atSel } else { [string]$p.Sel }
      $targetSource = if ($atPresent) { '--at' } elseif ($p.Sel) { '--to' } else { '' }
      if ($space -ne 'screen' -and -not $targetSel) { throw "--space $space needs '--to <sel>' or '--at <sel>': a relative scroll point with no named window has no defined origin; no input was sent" }
      if (-not $targetSel -and ($p.Force -or $p.AlwaysActivate -or $p.ExpectHandle -or $created -or ($space -ne 'screen'))) {
        throw "wheel: '--force', '--always-activate', '--expect-handle', '--created' and '--space window|client' require '--to <sel>' or '--at <sel>'"
      }
      $tgt = $null
      if ($targetSel) {
        $tgt = Resolve-Target $targetSel $p.Force $p.AlwaysActivate $p.ExpectHandle $created
        Emit-ResolveNote
      }
      $origin = Get-PointSpaceOrigin $space $tgt
      $posInfo = 'at current cursor position'
      if ($wordCount -eq 3) {
        $wpt = Convert-PointSpace $wx $wy $origin
        $wx = $wpt.X; $wy = $wpt.Y
        $posInfo = "at ($wx,$wy)$(if ($origin.Space -eq 'screen') { '' } else { ' space=' + $origin.Space })"
        $requestedX = $wx; $requestedY = $wy
      } else {
        $requestedPoint = New-Object DT+POINT
        [void][DT]::GetCursorPos([ref]$requestedPoint)
        $requestedX = $requestedPoint.X; $requestedY = $requestedPoint.Y
      }
      if ($tgt) {
        # Reject a wrong destination before moving the pointer. The post-move read below
        # catches a target or layout change between this check and injection.
        [void](Get-WheelPointObservation $requestedX $requestedY $tgt 'before cursor move' $false)
      }
      if ($wordCount -eq 3) {
        [void][DT]::SetCursorPos($wx, $wy)
        Start-Sleep -Milliseconds 150
      }
      $pt = New-Object DT+POINT
      [void][DT]::GetCursorPos([ref]$pt)
      if ($wordCount -eq 3 -and ($pt.X -ne $wx -or $pt.Y -ne $wy)) {
        throw "wheel: requested scroll point ($wx,$wy) but the cursor is at ($($pt.X),$($pt.Y)); no wheel input was sent"
      }
      $pre = Get-WheelPointObservation $pt.X $pt.Y $tgt 'before focus-first' $false
      if ($ff) {
        # This is an intentional real click. The target and landing checks above run before it.
        Move-Click $pt.X $pt.Y 'left'
        $posInfo += ' +clicked first (--focus-first)'
        Start-Sleep -Milliseconds 150
        $ptAfterClick = New-Object DT+POINT
        [void][DT]::GetCursorPos([ref]$ptAfterClick)
        if ($ptAfterClick.X -ne $pt.X -or $ptAfterClick.Y -ne $pt.Y) {
          throw "wheel target guard (after focus-first click): cursor moved from selected scroll point ($($pt.X),$($pt.Y)) to ($($ptAfterClick.X),$($ptAfterClick.Y)); no wheel input was sent"
        }
        $pre = Get-WheelPointObservation $ptAfterClick.X $ptAfterClick.Y $tgt 'after focus-first click' ($null -ne $tgt)
        $pt = $ptAfterClick
      }
      # Capture the effect baseline after the optional click, so it measures only the wheel.
      $ecb = $null
      $verifyMode = 'none'
      $verifyBase = $null
      $pixelRegion = $null
      $pixelHashBefore = ''
      if ($verificationRequested -and $null -eq $tgt) { throw 'wheel verification requires a resolved target window; no wheel input was sent' }
      if (-not [string]::IsNullOrWhiteSpace($expectVisibleText)) {
        $verifyBase = Get-WheelVisibleTextObservation $tgt $expectVisibleText
        if (-not $verifyBase.Available) { throw "wheel verification unavailable before input: UIA visible-text read '$($verifyBase.Reason)'; no wheel input was sent" }
        if ($verifyBase.Found) {
          return "wheel axis=$($wheelRequest.Axis) direction=$($wheelRequest.Direction) raw-delta=$($wheelRequest.RawDelta) scroll-point=($($pre.X),$($pre.Y)) target-check=matched via $targetSource hwnd=$($tgt.Handle) requested=0 SendInput-inserted=0/1 verification=target-content-already-visible evidence=UIA-visible-descendant samples=1 waited-ms=0; no wheel event was sent"
        }
        $verifyMode = 'content'
      } elseif ($verifyScroll) {
        $verifyBase = Get-WheelScrollObservation $pre.X $pre.Y $tgt $wheelRequest.Axis
        if ($verifyBase.Available) {
          if (Test-WheelScrollBoundary ([double]$verifyBase.Position) $wheelRequest.Axis ([int]$wheelRequest.RawDelta)) {
            return "wheel axis=$($wheelRequest.Axis) direction=$($wheelRequest.Direction) position=$($verifyBase.Position) scroll-point=($($pre.X),$($pre.Y)) target-check=matched via $targetSource hwnd=$($tgt.Handle) requested=0 SendInput-inserted=0/1 verification=at-boundary evidence=UIA-ScrollPattern samples=1 waited-ms=0; no wheel event was sent"
          }
          $verifyMode = 'position'
        } elseif ($p.ExpectChange) {
          $ecNorm = ConvertTo-ExpectChangeRect ([string]$p.ExpectChange)
          if ($null -eq $ecNorm) { throw "wheel: UIA ScrollPattern unavailable ($($verifyBase.Reason)); pixel fallback requires explicit --expect-change x,y,w,h" }
          $pixelParams = @{ ExpectChange = $p.ExpectChange; Sel = $targetSel }
          $pixelRegion = Get-ExpectChangeRegion $pixelParams $tgt
          $pr = $pre.Rect
          if ($pixelRegion.X -lt $pr.X -or $pixelRegion.Y -lt $pr.Y -or
              ($pixelRegion.X + $pixelRegion.W) -gt ($pr.X + $pr.W) -or ($pixelRegion.Y + $pixelRegion.H) -gt ($pr.Y + $pr.H)) {
            throw 'wheel: pixel fallback rectangle must be fully inside the selected target visible rectangle; no wheel input was sent'
          }
          $pixelHashBefore = Get-RegionHash $pixelRegion.X $pixelRegion.Y $pixelRegion.W $pixelRegion.H
          $verifyMode = 'pixel'
        } else {
          throw "wheel verification unavailable before input: UIA ScrollPattern '$($verifyBase.Reason)' and no explicit local pixel region; add '--expect-change x,y,w,h' only if pixel-only evidence is acceptable; no wheel input was sent"
        }
      }
      if ($p.ExpectChange -and -not $verificationRequested) {
        $ecp = $p
        if ($tgt -and -not $p.Sel) { $ecp = @{ ExpectChange = $p.ExpectChange; Sel = $targetSel } }
        $ecb = Get-ExpectChangeBaseline $ecp $tgt
      }
      $observed = if ($null -eq $pre.Hit) { '(none)' } else { "pid=$($pre.Hit.Pid) hwnd=$($pre.Hit.Hwnd) title='$($pre.Hit.Title)'" }
      $targetInfo = if ($null -eq $tgt) { 'target=unspecified' } else { "target-check=matched via $targetSource hwnd=$($tgt.Handle)" }
      $effectInfo = if ($verificationRequested) { 'effect-check=bounded-opt-in' } elseif ($p.ExpectChange) { 'effect-check=opt-in-pixel-hash' } else { 'effect=not-verified' }
      Log-Action @($p.Words) "scroll-point=$($pre.X),$($pre.Y) $targetInfo observed=$observed request=$($wheelRequest.EventName):$($wheelRequest.RawDelta) mods=$(if ($modList.Count -gt 0) { $modList -join '+' } else { 'none' })" $Cmd
      $inserted = 0
      $modReceipt = ''
      # ONE call site on purpose: the CU-REL-04 lint pins "one wheel call is the maximum", so a
      # modified gesture reuses the same send instead of growing a second [DT]::SendWheelInput line.
      $wheelSend = { [DT]::SendWheelInput([int]$wheelRequest.RawDelta, [uint32]$wheelRequest.InputFlag) }
      if ($modList.Count -gt 0) {
        # The modifiers are pressed and released inside this one call; the wheel event is
        # the only thing between them, and the release runs even if the event fails.
        $rc = Invoke-ModifierGesture $modList { $script:WheelInserted = & $wheelSend }
        $inserted = $script:WheelInserted
        $modReceipt = Format-ModifierReceipt $rc
      } else {
        $inserted = & $wheelSend
      }
      if ([uint32]$inserted -ne 1) {
        $win32 = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "wheel: SendInput inserted $inserted of 1 requested event (win32 error $win32); no automatic retry was attempted and no successful wheel receipt was produced"
      }
      if (-not $verificationRequested) { Start-Sleep -Milliseconds 300 }
      $p2 = New-Object DT+POINT
      [void][DT]::GetCursorPos([ref]$p2)
      $receipt = "wheel $($wheelRequest.OriginalAmount) unit=$($wheelRequest.Unit) axis=$($wheelRequest.Axis) direction=$($wheelRequest.Direction) raw-delta=$($wheelRequest.RawDelta) amount-source=$($wheelRequest.AmountSource) requested=1 event=$($wheelRequest.EventName) SendInput-inserted=$inserted/1$modReceipt$(if ($modList.Count -gt 0) { ' gesture-scope=application-defined (a modified wheel event is a request; the application decides whether that is zoom, pan or nothing)' }) scroll-point=($($pre.X),$($pre.Y)) observed-before-injection=$observed $targetInfo foreground-before-injection=$($pre.Foreground) $effectInfo  $posInfo  cursor-after=($($p2.X),$($p2.Y))"
      if (-not $verificationRequested) {
        Write-Output $receipt
        if ($ecb) { Invoke-ExpectChangeCheck $p $ecb 'wheel' }
        return
      }
      $verifySw = [System.Diagnostics.Stopwatch]::StartNew()
      $verifySamples = 0; $verifyStatus = ''; $verifyDetail = ''; $verifyPosition = $null; $verifyHash = ''
      $maxWaitMs = 1200; $pollMs = 100; $maxSamples = 13
      while ($verifySamples -lt $maxSamples -and $verifySw.ElapsedMilliseconds -le $maxWaitMs) {
        $verifySamples++
        try { $post = Get-WheelPointObservation $pre.X $pre.Y $tgt 'during effect verification' $false }
        catch { $verifyStatus = 'target-changed'; $verifyDetail = $_.Exception.Message; break }
        if ($null -ne $tgt -and $null -ne $pre.Rect -and
            ($post.Rect.X -ne $pre.Rect.X -or $post.Rect.Y -ne $pre.Rect.Y -or $post.Rect.W -ne $pre.Rect.W -or $post.Rect.H -ne $pre.Rect.H)) {
          $verifyStatus = 'target-changed'; $verifyDetail = 'target-visible-rectangle-changed'; break
        }
        if ($verifyMode -eq 'position') {
          $current = Get-WheelScrollObservation $pre.X $pre.Y $tgt $wheelRequest.Axis
          if (-not $current.Available) { $verifyStatus = 'unavailable'; $verifyDetail = [string]$current.Reason; break }
          if ($current.ContainerId -cne $verifyBase.ContainerId) { $verifyStatus = 'target-changed'; $verifyDetail = 'scroll-container-identity-changed'; break }
          $verifyPosition = [double]$current.Position
          if ([Math]::Abs($verifyPosition - [double]$verifyBase.Position) -ge 0.01) {
            if (Test-WheelScrollDirection ([double]$verifyBase.Position) $verifyPosition $wheelRequest.Axis ([int]$wheelRequest.RawDelta)) { $verifyStatus = 'position-changed' }
            else { $verifyStatus = 'unexpected-position-change'; $verifyDetail = 'observed-direction-differs-from-request' }
            break
          }
          if (Test-WheelScrollBoundary $verifyPosition $wheelRequest.Axis ([int]$wheelRequest.RawDelta)) { $verifyStatus = 'at-boundary'; break }
        } elseif ($verifyMode -eq 'content') {
          $current = Get-WheelVisibleTextObservation $tgt $expectVisibleText
          if (-not $current.Available) { $verifyStatus = 'unavailable'; $verifyDetail = [string]$current.Reason; break }
          if ($current.Found) { $verifyStatus = 'target-content-appeared'; $verifyDetail = "node=$($current.NodeId)"; break }
        } else {
          $verifyHash = Get-RegionHash $pixelRegion.X $pixelRegion.Y $pixelRegion.W $pixelRegion.H
          if ($verifyHash -cne $pixelHashBefore) { $verifyStatus = 'pixel-changed-only'; break }
        }
        if ($verifySamples -ge $maxSamples -or $verifySw.ElapsedMilliseconds -ge $maxWaitMs) { break }
        Start-Sleep -Milliseconds $pollMs
      }
      $verifyWait = [int]$verifySw.ElapsedMilliseconds
      if (-not $verifyStatus) {
        $verifyStatus = if ($verifyMode -eq 'position') { 'no-observed-effect' } elseif ($verifyMode -eq 'content') { 'target-content-not-appeared' } else { 'no-pixel-change' }
        if ($verifyMode -eq 'pixel') { $verifyDetail = 'boundary=unknown' }
      }
      $verifyEvidence = if ($verifyMode -eq 'position') { "evidence=UIA-ScrollPattern position=$($verifyBase.Position)->$verifyPosition container=$($verifyBase.ContainerId)" }
        elseif ($verifyMode -eq 'content') { "evidence=UIA-visible-descendant scan-before=$($verifyBase.Scanned) $verifyDetail" }
        else { "evidence=local-pixel-only rect=($($pixelRegion.X),$($pixelRegion.Y),$($pixelRegion.W)x$($pixelRegion.H)) hash-before=$pixelHashBefore hash-after=$verifyHash $verifyDetail" }
      $verifyReceipt = "$receipt verification=$verifyStatus wait-ms=$verifyWait samples=$verifySamples attribution=not-proven $verifyEvidence"
      Write-Output $verifyReceipt
      if ($verifyStatus -notin @('position-changed', 'target-content-appeared', 'at-boundary', 'pixel-changed-only')) {
        throw "wheel verification status=$verifyStatus after SendInput-inserted=1/1 ($verifyDetail); no automatic retry was attempted"
      }
}

# v4.4.0 (A-15): relclick - the case body, verbatim
function Invoke-Handler-relclick([string]$Cmd, [string[]]$Rest) {
      # CU-REL-01 (v4.4.1): this case used to add the offsets to the rect read at SELECT time and
      # click, going through NONE of the pre-action checks its siblings pass. So a window that moved
      # or restored between the read and the click, an offset that landed outside it, and a point
      # covered by some other top-level window all still printed a confident "clicked" line.
      # It now resolves through the common target path (handle pin, activation with the
      # was-already-foreground skip, the did-not-become-foreground refusal), measures the window
      # AGAIN after that activation, passes the shared landing check plus the new identity check,
      # and refuses unless the window physically under the point IS the resolved target.
      # Positional form is unchanged: relclick <sel> <dx> <dy>.
      $p = Split-Target $Rest
      if ($p.Sel) { throw "relclick: the selector is the FIRST positional argument of this command - pass 'relclick <sel> <dx> <dy>', not --to (got --to '$($p.Sel)')" }
      if (@($p.Words).Count -lt 3) { throw 'usage: relclick <sel> <dx> <dy> [--guard-text <s>|--guard-region x,y,w,h=s] [--allow-outside] [--force]' }
      $rcSel = [string]$p.Words[0]
      $rcDx = [int]$p.Words[1]
      $rcDy = [int]$p.Words[2]
      $tgt = Resolve-Target $rcSel $p.Force $p.AlwaysActivate $p.ExpectHandle
      Emit-ResolveNote
      # v4.4.1 CU-REL-01: the rect is read again, by handle, AFTER the activation above - restoring
      # or re-raising a window moves it, and Get-TargetRect prefers the snapshot taken at select
      # time. The six geometry fields are pinned onto the target so every reader in this call (the
      # content guard and the landing check both go through Get-TargetRect) judges the SAME
      # rectangle this click is computed from; otherwise one call computes from one rect and
      # refuses against another.
      $rcRect = Get-WindowVisibleRect $tgt.Handle
      if ($null -eq $rcRect) { throw "relclick: the target window could not be measured after activation (handle gone?) - NOTHING was clicked. Re-read it with 'wins'." }
      if ($rcRect.X -le -32000 -or $rcRect.Y -le -32000) { throw "relclick: the target still sits at the parked position ($($rcRect.X),$($rcRect.Y)) - it is minimized or off-screen, so NOTHING was clicked. Run 'win-restore <sel>' first." }
      $tgt | Add-Member -NotePropertyName Left -NotePropertyValue $rcRect.X -Force
      $tgt | Add-Member -NotePropertyName Top -NotePropertyValue $rcRect.Y -Force
      $tgt | Add-Member -NotePropertyName W -NotePropertyValue $rcRect.W -Force
      $tgt | Add-Member -NotePropertyName H -NotePropertyValue $rcRect.H -Force
      $tgt | Add-Member -NotePropertyName Right -NotePropertyValue ($rcRect.X + $rcRect.W) -Force
      $tgt | Add-Member -NotePropertyName Bottom -NotePropertyValue ($rcRect.Y + $rcRect.H) -Force
      Invoke-ContentGuard $tgt $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
      $rcX = $rcRect.X + $rcDx
      $rcY = $rcRect.Y + $rcDy
      Invoke-HitWindowCheck $rcX $rcY $tgt $true $p.AllowOutside
      # The rect check above answers "is the point inside the target". It does not answer "whose
      # window is under the point", and that second half is what relclick never asked.
      $rcHit = Get-HitWindow $rcX $rcY
      if (-not (Test-LandingOnTarget $rcHit $tgt)) {
        if (-not $p.AllowOutside) { throw (Format-LandingVerdict $rcX $rcY $rcHit $tgt $false) }
        Write-Output (Format-LandingVerdict $rcX $rcY $rcHit $tgt $true)
      }
      $rcLanding = $(if ($null -eq $rcHit) { 'none' } else { "$($rcHit.Hwnd)" })
      $rcLogArgs = Get-RedactedLogArgs $Rest @() $p.LogPayload
      Log-Action $rcLogArgs "pid=$($tgt.Pid) title='$($tgt.Title)' screen=$rcX,$rcY rect=($($rcRect.X),$($rcRect.Y),$($rcRect.W)x$($rcRect.H)) origin=fresh-after-activation landing=$rcLanding sel='$rcSel'" $Cmd
      Move-Click $rcX $rcY 'left'
      "clicked window-relative ($rcDx,$rcDy) -> screen ($rcX,$rcY) of pid=$($tgt.Pid) hwnd=$($tgt.Handle) rect=($($rcRect.X),$($rcRect.Y),$($rcRect.W)x$($rcRect.H)) (origin re-read after activation, landing window=$rcLanding)"
}

# v4.4.0 (A-15): drag - the case body, verbatim
function Invoke-Handler-drag([string]$Cmd, [string[]]$Rest) {
      # drag <x1> <y1> <x2> <y2> [--steps n] [--hold ms] [--to <sel>] [--guard-text <s>] [--force]
      # Press, interpolate across the path, release. Covers dragging windows,
      # sliders and scrollbars that wheel events cannot move. Guards like click.
      # v1.5.5 (D-1): --steps/--hold stripped before Split-Target (see hover above);
      # both were unreachable dead code before this commit.
      # v3.1.0 (P-01): drag is the only two-point command in the family, so BOTH
      # endpoints pass the landing check BEFORE the button goes down - each point
      # prints its own hit-window line, and with --to a point outside the target's
      # visible rect is refused while nothing is held (a refusal after mouse-down
      # would leave the drag stuck mid-path on whatever the cursor crossed);
      # --allow-outside releases the check and says so, as on the one-point commands.
      $own = Strip-OwnFlags $Rest 'drag'
      $steps = [int]$own.Values['--steps']
      $hold = [int]$own.Values['--hold']
      $p = Split-Target @($own.Rest) 'drag'
      if ($p.Words.Count -lt 4) { throw 'usage: drag <x1> <y1> <x2> <y2> [--steps n] [--hold ms] [--button left|middle|right|back|forward] [--mods ctrl+shift] [--space screen|window|client] [--created <iso>] [--to <sel>] [--guard-text <s>] [--force]' }
      # CU-OPS package B: the same one-call press/act/release ownership as the clicks.
      # Middle-drag (canvas pan), right-drag (some lists and 3D views) and the side
      # buttons all share this one path, so a new button cannot grow its own unguarded
      # copy of the drag code.
      $button = if ($own.Present['--button']) { [string]$own.Values['--button'] } else { 'left' }
      $mods = [string]$own.Values['--mods']
      # CU-OPS package D: both endpoints come from ONE origin read, taken after the
      # target resolved, so a resize between the two conversions cannot split the path.
      $space = Test-PointSpaceArg ([string]$own.Values['--space'])
      if ($space -ne 'screen' -and -not $p.Sel) { throw "--space $space needs --to <sel>: a relative point with no named window has no defined origin (the foreground window is not an identity); no input was sent" }
      $created = [string]$own.Values['--created']
      $buttonSpec = Get-MouseButtonSpec $button
      $modList = @(Resolve-MouseModifiers $mods)
      # X-02: every sibling of this case (click / dblclick / relclick / wheel / press-down /
      # press-up / drag-to / menu-pick) initialises $tgt before the conditional resolve; drag
      # was the one that did not, so a drag WITHOUT --to reached Invoke-HitWindowCheck with a
      # never-set variable. Non-strict that reads as $null; under StrictMode it is a terminating
      # error and the whole command dies before moving the cursor.
      $tgt = $null
      if ($p.Sel -or $p.GuardText -or $p.GuardRegion -or $created -or ($space -ne 'screen')) {
        $tgt = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle $created
        Emit-ResolveNote
        if ($p.GuardText -or $p.GuardRegion) {
          Invoke-ContentGuard $tgt $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
        }
      }
      $rx1 = [int]$p.Words[0]; $ry1 = [int]$p.Words[1]; $rx2 = [int]$p.Words[2]; $ry2 = [int]$p.Words[3]
      $origin = Get-PointSpaceOrigin $space $tgt
      $dpt1 = Convert-PointSpace $rx1 $ry1 $origin
      $dpt2 = Convert-PointSpace $rx2 $ry2 $origin
      $x1 = $dpt1.X; $y1 = $dpt1.Y; $x2 = $dpt2.X; $y2 = $dpt2.Y
      # Both verdicts exist BEFORE the press - the order here is load-bearing.
      Invoke-HitWindowCheck $x1 $y1 $tgt ($p.Sel -ne '') $p.AllowOutside
      Invoke-HitWindowCheck $x2 $y2 $tgt ($p.Sel -ne '') $p.AllowOutside
      $ecb = Get-ExpectChangeBaseline $p $tgt
      $spaceLog = if ($origin.Space -eq 'screen') { '' } else { " space=$($origin.Space) rel=$rx1,$ry1 -> $rx2,$ry2" }
      Log-Action (Get-RedactedLogArgs $Rest @() $p.LogPayload) "coords=$x1,$y1 -> $x2,$y2$spaceLog button=$($buttonSpec.Name) mods=$(if ($modList.Count -gt 0) { $modList -join '+' } else { 'none' })" $Cmd
      $script:LastMouseReceipt = ''
      $dx1 = $x1; $dy1 = $y1; $dx2 = $x2; $dy2 = $y2; $dSteps = $steps; $dHold = $hold; $dBtn = $buttonSpec.Name
      $dragAct = {
        [void][DT]::SetCursorPos($dx1, $dy1)
        Start-Sleep -Milliseconds 150
        [void](Invoke-MouseButtonEvent $dBtn $true)
        # CU-OPS-ADJ-06: once the button is down, the UP lives in a finally. A failure on
        # the path must neither leave the button held nor be replaced by a "dragged" receipt;
        # a failed UP is carried out separately instead of being swallowed.
        $dragErr = $null
        $dUpErr = $null
        try {
          Start-Sleep -Milliseconds $dHold
          for ($s = 1; $s -le $dSteps; $s++) {
            $ix = [int][math]::Round($dx1 + ($dx2 - $dx1) * $s / $dSteps)
            $iy = [int][math]::Round($dy1 + ($dy2 - $dy1) * $s / $dSteps)
            [void][DT]::SetCursorPos($ix, $iy)
            Start-Sleep -Milliseconds 12
          }
          [void][DT]::SetCursorPos($dx2, $dy2)
          Start-Sleep -Milliseconds 100
        } catch {
          $dragErr = $_
        } finally {
          try {
            [void](Invoke-MouseButtonEvent $dBtn $false)
            Start-Sleep -Milliseconds 200
          } catch {
            $dUpErr = $_
          }
        }
        if ($null -ne $dragErr -and $null -ne $dUpErr) {
          throw ('drag: the path failed (' + $dragErr.Exception.Message + ') and the button UP also failed (' + $dUpErr.Exception.Message + ') - ' + $dBtn + ' may still be held down')
        }
        if ($null -ne $dragErr) {
          throw ('drag: the path failed while ' + $dBtn + ' was down: ' + $dragErr.Exception.Message + ' (button released)')
        }
        if ($null -ne $dUpErr) {
          throw ('drag: mouse button ' + $dBtn + ' UP failed: ' + $dUpErr.Exception.Message + ' - the button state is not what the caller asked for')
        }
      }
      if ($modList.Count -gt 0) {
        $rc = Invoke-ModifierGesture $modList $dragAct
        $script:LastMouseReceipt = (Format-ModifierReceipt $rc)
      } else { & $dragAct }
      "dragged ($x1,$y1) -> ($x2,$y2)$(if ($origin.Space -eq 'screen') { '' } else { ' space=' + $origin.Space }) steps=$steps hold=${hold}ms button=$($buttonSpec.Name)$(if ($modList.Count -gt 0) { ' mods=' + ($modList -join '+') })$($script:LastMouseReceipt)"
      Invoke-ExpectChangeCheck $p $ecb 'dragged'
}

# v4.4.0 (A-15): drag-to - the case body, verbatim
function Invoke-Handler-drag-to([string]$Cmd, [string[]]$Rest) {
      # drag-to <x> <y> [--steps n] [--to <sel>] [--guard-text <s>] [--force]
      # Travel while HELD. Refuses when nothing is pressed - the one-call form is
      # `drag <x1> <y1> <x2> <y2>`, and silently "working" without a press would be
      # the silent-success shape this repo keeps having to pin shut.
      $own = Strip-OwnFlags $Rest 'drag-to'
      $steps = [int]$own.Values['--steps']
      $p = Split-Target @($own.Rest) 'drag-to'
      if ($p.Words.Count -lt 2) { throw 'usage: drag-to <x> <y> [--steps n] [--to <sel>] [--guard-text <s>] [--force]' }
      $tgt = $null
      if ($p.Sel -or $p.GuardText -or $p.GuardRegion) {
        $tgt = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle
        Emit-ResolveNote
        Invoke-ContentGuard $tgt $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
      }
      $dg = Get-PressGate 'drag-to' 'drag-to' (Get-LeftButtonDown)
      if ($dg.Refuse) {
        if (Test-PressHoldFired) { Close-PressHold @("$($p.Words[0])", "$($p.Words[1])") '' $Cmd }
        throw "drag-to: $($dg.Reason)"
      }
      $ecb = Get-ExpectChangeBaseline $p $tgt
      $from = New-Object DT+POINT
      [void][DT]::GetCursorPos([ref]$from)
      $x2 = [int]$p.Words[0]; $y2 = [int]$p.Words[1]
      Invoke-HitWindowCheck $x2 $y2 $tgt ($p.Sel -ne '') $p.AllowOutside
      Log-Action (Get-RedactedLogArgs $Rest @() $p.LogPayload) "($($from.X),$($from.Y)) -> $x2,$y2 button=HELD id=$script:PressId" $Cmd
      for ($s = 1; $s -le $steps; $s++) {
        $ix = [int][math]::Round($from.X + ($x2 - $from.X) * $s / $steps)
        $iy = [int][math]::Round($from.Y + ($y2 - $from.Y) * $s / $steps)
        [void][DT]::SetCursorPos($ix, $iy)
        Start-Sleep -Milliseconds 12
      }
      [void][DT]::SetCursorPos($x2, $y2)
      Start-Sleep -Milliseconds 100
      $dgMeas = 'no'
      if (Get-LeftButtonDown) { $dgMeas = 'yes' }
      if ($dgMeas -ne 'yes') {
        # The hold ended mid-travel (a --max-hold that expired, or somebody else let
        # go). Calling that a drag would be a lie: the drop happened somewhere along
        # the path, not at the destination the caller asked for.
        $dgLostId = "$script:PressId"
        $dgCause = 'external'
        if (Test-PressHoldFired) { $dgCause = 'max-hold'; Close-PressHold @("$x2", "$y2") '' $Cmd }
        else { Stop-PressHoldTimer; $script:PressId = '' }
        throw "drag-to: the button was released mid-travel (measured-down=no, cause=$dgCause, id=$dgLostId) - the drag did NOT end in a held state, so do not assume anything was dropped at ($x2,$y2)"
      }
      "dragged-to ($($from.X),$($from.Y)) -> ($x2,$y2) steps=$steps, button still DOWN (measured-down=$dgMeas) - press-up lets go"
      Invoke-ExpectChangeCheck $p $ecb 'dragged-to'
}

# v4.4.0 (A-15): press-down - the case body, verbatim
function Invoke-Handler-press-down([string]$Cmd, [string[]]$Rest) {
      # press-down <x> <y> [--max-hold ms] [--to <sel>] [--guard-text <s>|--guard-region x,y,w=h] [--force]
      # Press and LEAVE IT DOWN, so the caller can look before letting go (the slider
      # shape: the verdict is taken on release). Guards and hit-window like click.
      # A top-level CLI press-down then stays alive until the hold ends - an echo that
      # promises auto-release while the process has already exited would be a lie; as a
      # script step it returns at once and the armed timer holds the deadline while the
      # later steps (shot / find-text / drag-to / press-up) run.
      $own = Strip-OwnFlags $Rest 'press-down'
      $maxHold = [int]$own.Values['--max-hold']
      $p = Split-Target @($own.Rest) 'press-down'
      if ($p.Words.Count -lt 2) { throw 'usage: press-down <x> <y> [--max-hold ms] [--to <sel>] [--guard-text <s>] [--force]' }
      $tgt = $null
      if ($p.Sel -or $p.GuardText -or $p.GuardRegion) {
        $tgt = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle
        Emit-ResolveNote
        Invoke-ContentGuard $tgt $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
      }
      Invoke-HitWindowCheck ([int]$p.Words[0]) ([int]$p.Words[1]) $tgt ($p.Sel -ne '') $p.AllowOutside
      $pg = Get-PressGate 'press-down' 'press-down' (Get-LeftButtonDown)
      if ($pg.Refuse) { throw "press-down: $($pg.Reason)" }
      $script:PressSeq++
      $prId = "p$PID-$($script:PressSeq)"
      $script:PressId = $prId
      $prLog = @($p.Words[0], $p.Words[1], "id=$prId")
      Log-Action $prLog "coords=$($p.Words[0]),$($p.Words[1]) button=DOWN max-hold=${maxHold}ms" $Cmd
      [void][DT]::SetCursorPos([int]$p.Words[0], [int]$p.Words[1])
      Start-Sleep -Milliseconds 150
      Invoke-LeftPress $true
      Start-PressHoldTimer $maxHold
      $prMeas = 'no'
      if (Get-LeftButtonDown) { $prMeas = 'yes' }
      if ($prMeas -ne 'yes') {
        # The press did not take. Echoing "button is DOWN" anyway is the lie this
        # whole feature exists to avoid, and drag-to / press-up would then act on a
        # state that does not exist.
        Release-Press $prId 'press-not-registered' $prLog $Cmd
        throw 'press-down: the press was sent but the left button does NOT read as down (measured-down=no) - refusing to claim a hold that is not real'
      }
      "button is DOWN at ($($p.Words[0]),$($p.Words[1])) id=$prId, will auto-release after ${maxHold}ms (measured-down=$prMeas) - drag-to to travel, press-up to let go"
      if ($script:PressTopLevel) {
        $prWhy = Wait-PressRelease $maxHold
        if ($prWhy -eq 'max-hold') {
          Close-PressHold $prLog $prId $Cmd
          "auto-released after ${maxHold}ms (id=$prId cause=max-hold)"
        }
        elseif ($prWhy -eq 'external') {
          Stop-PressHoldTimer
          Log-Action $prLog (Format-PressReleaseLine $prId '' 'external') $Cmd
          $script:PressId = ''
          "released before its deadline by something outside this process (id=$prId cause=external)"
        }
        else { Release-Press $prId 'deadline' $prLog $Cmd }
      }
}

# v4.4.0 (A-15): press-up - the case body, verbatim
function Invoke-Handler-press-up([string]$Cmd, [string[]]$Rest) {
      # press-up <x> <y> [--to <sel>] [--force] - let go (at that point). The drop is
      # where a slider verdict is taken, so --expect-change is honoured here.
      $p = Split-Target $Rest 'press-up'
      if ($p.Words.Count -lt 2) { throw 'usage: press-up <x> <y> [--to <sel>] [--expect-change [x,y,w,h]] [--force]' }
      $tgt = $null
      if ($p.Sel -or $p.GuardText -or $p.GuardRegion) {
        $tgt = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle
        Emit-ResolveNote
        Invoke-ContentGuard $tgt $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
      }
      $pu = Get-PressGate 'press-up' 'press-up' (Get-LeftButtonDown)
      if ($pu.Refuse) {
        # Nothing is down, but the deadline may be what took it up: write the matching
        # UP line for that DOWN instead of leaving the pair dangling.
        if (Test-PressHoldFired) { Close-PressHold @($p.Words[0], $p.Words[1]) '' $Cmd }
        throw "press-up: $($pu.Reason)"
      }
      Invoke-HitWindowCheck ([int]$p.Words[0]) ([int]$p.Words[1]) $tgt ($p.Sel -ne '') $p.AllowOutside
      $ecb = Get-ExpectChangeBaseline $p $tgt
      [void][DT]::SetCursorPos([int]$p.Words[0], [int]$p.Words[1])
      Start-Sleep -Milliseconds 150
      Release-Press '' 'press-up' @($p.Words[0], $p.Words[1]) $Cmd
      Start-Sleep -Milliseconds 200
      Invoke-ExpectChangeCheck $p $ecb 'dropped'
}

# v4.4.0 (A-15): find-click - the case body, verbatim
function Invoke-Handler-find-click([string]$Cmd, [string[]]$Rest) {
      # find-click <sel|x y w h> <needle...> [--index n] - OCR decides where to
      # click, in ONE call: locate the text with the scaled 2x-retry matcher and
      # click the hit's centre. This is menu-pick for arbitrary regions/windows
      # (not just popup menus) and the fix for "click -> wait-stable -> shoot ->
      # eyeball" being three calls to learn a click did nothing (audit
      # 2026-09-29b #4). Mutates the desktop: audited, and guards apply like click.
      # v1.5.5 (D-1): --index stripped before Split-Target, and its value can no
      # longer leak into the needle (previously the flag was unreachable at all).
      $own = Strip-OwnFlags $Rest 'find-click'
      $index = [int]$own.Values['--index']
      $aimLine = [bool]$own.Values['--aim-line']
      $p = Split-Target @($own.Rest) 'find-click'
      if ($p.Words.Count -lt 2) { throw 'usage: find-click <sel|x y w h> <needle...> [--index n] [--aim-line] [--allow-outside]' }
      $region = Resolve-Region $p.Words 0
      $rw = Region-WordCount $p.Words 0
      if ($p.Words.Count -le $rw) { throw 'find-click: empty needle' }
      $needle = (@($p.Words[$rw..($p.Words.Count - 1)]) -join ' ').Trim()
      if (-not $needle) { throw 'find-click: empty needle' }
      $tgt = $null
      if ($p.Sel -or $p.GuardText -or $p.GuardRegion) {
        $tgt = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle
        Emit-ResolveNote
        Invoke-ContentGuard $tgt $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
      }
      $f = Find-OcrHitsScaled $region.X $region.Y $region.W $region.H $needle $p.Scale $p.MaxTiles $p.NoTile
      $hits = $f.Hits
      if ($hits.Count -eq 0) {
        $missRect = "($($region.X),$($region.Y)) $($region.W)x$($region.H)"
        throw "find-click: '$needle' not found in region $missRect - nothing clicked ($(Format-OcrRetryNote $f)); $(Format-OcrSampleTail $f.Lines 8 @{ Rect = $missRect; Retry = (Format-OcrRetryNote $f); Occlusion = $(if ($p.GuardText -or $p.GuardRegion) { 'checked-by-guard-above' } else { 'not-scanned' }); Needle = $needle })"
      }
      if ($index -ge $hits.Count) { throw "find-click: --index $index but only $($hits.Count) hit(s)" }
      # J-05: said BEFORE the click, so a caller that meant "the second one" can still stop
      # and re-run with --index while the line/occurrence distinction is on screen.
      $j05f = Format-MultiOccurrenceHint $needle $hits
      if ($j05f) { Write-Output $j05f }
      $hit = $hits[$index]
      $cx = $hit.X + [int]($hit.W / 2)
      $cy = $hit.Y + [int]($hit.H / 2)
      # v1.5.9 (P-2): aim at the needle's own sub-span of the matched line, not the
      # line centre. The echo always says which aiming ran, so a caller can tell a
      # sub-span click from a line-centre one (and --aim-line is the rollback).
      $aimNote = ' aim=line-centre (--aim-line)'
      if (-not $aimLine) {
        $aim = Get-NeedleAimX "$($hit.Text)" $hit.X $hit.W $needle
        if ($aim.Matched) {
          $cx = $aim.AimX
          $aimNote = " aim=substring $($aim.SpanStart)-$($aim.SpanEnd)/$($aim.NormLen) of line"
          if ((($aim.SpanEnd - $aim.SpanStart) / $aim.NormLen) -le 0.6) {
            Write-Output 'NOTE: matched line is wider than needle -- aimed at needle sub-span, not line centre'
          }
        } else {
          $aimNote = ' aim=line-centre (needle not locatable in line text)'
        }
      }
      Invoke-HitWindowCheck $cx $cy $tgt ($p.Sel -ne '') $p.AllowOutside
      $ecb = Get-ExpectChangeBaseline $p $tgt
      Log-Action (Get-RedactedLogArgs $Rest @($p.Words[$rw..($p.Words.Count - 1)]) $p.LogPayload) "needle='$needle' hit=$($index + 1)/$($hits.Count) at=$cx,$cy$aimNote" $Cmd
      Move-Click $cx $cy 'left'
      "find-click: clicked '$($hit.Text)' at ($cx,$cy) (hit $($index + 1)/$($hits.Count))$aimNote$(if ($f.Scaled) { ' [found via 2x upscale]' })$(Get-OcrFoldMarker $hits)"
      Invoke-ExpectChangeCheck $p $ecb 'find-click'
      Invoke-ActionExpectation $p $tgt 'clicked'
}

# v4.4.0 (A-15): win-move - the case body, verbatim
function Invoke-Handler-win-move([string]$Cmd, [string[]]$Rest) {
      # win-move <sel> <x> <y> - place the VISIBLE window top-left at x,y.
      if ($Rest.Count -lt 3) { throw 'usage: win-move <sel> <x> <y>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      Emit-ResolveNote
      if ([DT]::IsIconic($w.Handle)) { [void][DT]::ShowWindow($w.Handle, 9); Start-Sleep -Milliseconds 250 }
      $adj = Get-VisibleAdjust $w.Handle
      Log-Action $Rest "pid=$($w.Pid) title='$($w.Title)' visible=($($Rest[1]),$($Rest[2]))" $Cmd
      [void][DT]::MoveWindow($w.Handle, ([int]$Rest[1] - $adj.DL), ([int]$Rest[2] - $adj.DT), ($w.W + $adj.DL + $adj.DR), ($w.H + $adj.DT + $adj.DB), $true)
      Start-Sleep -Milliseconds 250
      $w2 = Resolve-Window $Rest[0]
      "moved pid=$($w.Pid) -> visible top-left ($($w2.Left),$($w2.Top)) size=$($w2.W)x$($w2.H)"
}

# v4.4.0 (A-15): win-resize - the case body, verbatim
function Invoke-Handler-win-resize([string]$Cmd, [string[]]$Rest) {
      # win-resize <sel> <w> <h> - set the VISIBLE size (MoveWindow alone would
      # size the invisible-border rect instead, off by ~7-11px per side).
      if ($Rest.Count -lt 3) { throw 'usage: win-resize <sel> <w> <h>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      Emit-ResolveNote
      if ([DT]::IsIconic($w.Handle)) { [void][DT]::ShowWindow($w.Handle, 9); Start-Sleep -Milliseconds 250 }
      $adj = Get-VisibleAdjust $w.Handle
      Log-Action $Rest "pid=$($w.Pid) title='$($w.Title)' visible=$($Rest[1])x$($Rest[2])" $Cmd
      [void][DT]::MoveWindow($w.Handle, ($w.Left - $adj.DL), ($w.Top - $adj.DT), ([int]$Rest[1] + $adj.DL + $adj.DR), ([int]$Rest[2] + $adj.DT + $adj.DB), $true)
      Start-Sleep -Milliseconds 250
      $w2 = Resolve-Window $Rest[0]
      "resized pid=$($w.Pid) -> visible ($($w2.Left),$($w2.Top)) size=$($w2.W)x$($w2.H)"
}

# v4.4.0 (A-15): win-max - the case body, verbatim
function Invoke-Handler-win-max([string]$Cmd, [string[]]$Rest) {
      if ($Rest.Count -lt 1) { throw 'usage: win-max <sel>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      Log-Action $Rest "pid=$($w.Pid) title='$($w.Title)'" $Cmd
      [void][DT]::ShowWindow($w.Handle, 3)   # SW_MAXIMIZE
      Start-Sleep -Milliseconds 250
      "maximized pid=$($w.Pid) title='$($w.Title)' zoomed=$([DT]::IsZoomed($w.Handle))"
}

# v4.4.0 (A-15): win-min - the case body, verbatim
function Invoke-Handler-win-min([string]$Cmd, [string[]]$Rest) {
      if ($Rest.Count -lt 1) { throw 'usage: win-min <sel>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      Log-Action $Rest "pid=$($w.Pid) title='$($w.Title)'" $Cmd
      [void][DT]::ShowWindow($w.Handle, 6)   # SW_MINIMIZE
      Start-Sleep -Milliseconds 250
      "minimized pid=$($w.Pid) title='$($w.Title)' iconic=$([DT]::IsIconic($w.Handle))"
}

# v4.4.0 (A-15): win-restore - the case body, verbatim
function Invoke-Handler-win-restore([string]$Cmd, [string[]]$Rest) {
      if ($Rest.Count -lt 1) { throw 'usage: win-restore <sel>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      Log-Action $Rest "pid=$($w.Pid) title='$($w.Title)'" $Cmd
      [void][DT]::ShowWindow($w.Handle, 9)   # SW_RESTORE
      Start-Sleep -Milliseconds 250
      "restored pid=$($w.Pid) title='$($w.Title)' iconic=$([DT]::IsIconic($w.Handle)) zoomed=$([DT]::IsZoomed($w.Handle))"
}

# v4.4.0 (A-15): win-close - the case body, verbatim
function Invoke-Handler-win-close([string]$Cmd, [string[]]$Rest) {
      # win-close <sel> - WM_CLOSE, graceful: no focus theft, and the app gets
      # to prompt. Strictly safer than Alt+F4, which hits whatever IS foreground.
      if ($Rest.Count -lt 1) { throw 'usage: win-close <sel>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      Log-Action $Rest "pid=$($w.Pid) title='$($w.Title)'" $Cmd
      $sent = [DT]::PostMessage($w.Handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
      "close requested (WM_CLOSE) pid=$($w.Pid) title='$($w.Title)' posted=$sent (the app may still show a confirm dialog)"
}

# v4.4.0 (A-15): dialog-cancel - the case body, verbatim
function Invoke-Handler-dialog-cancel([string]$Cmd, [string[]]$Rest) {
      # v3.0.0 (B-5): close a dialog by its CANCEL control, or by Escape when the tree has no
      # cancel-shaped button. This command can never CONFIRM anything (see Get-DialogCancelStems
      # for why "close" is not in the set), and it proves its own result by the handle being
      # gone rather than by the click having been delivered.
      $own = Strip-OwnFlags $Rest 'dialog-cancel'
      $p = Split-Target @($own.Rest) 'dialog-cancel'
      $sel = ''
      if ($p.Sel) { $sel = $p.Sel } elseif (@($p.Words).Count -ge 1) { $sel = "$($p.Words[0])" }
      if (-not $sel) { throw 'usage: dialog-cancel <sel> [--allow-window] [--expect-handle <hwnd>] [--expect|--expect-gone ...]' }
      $w = Resolve-Window $sel
      if (-not $w) { throw "no window matching: $sel" }
      $pin = Test-HandlePin $p.ExpectHandle $w.Handle
      if (-not $pin.Ok) {
        throw "dialog-cancel: handle pin - this call may only act on $($pin.Expected) but '$sel' is hwnd=$($pin.Actual) pid=$($w.Pid) '$($w.Title)' ($(Format-HandlePinReason $pin)) - NOTHING was pressed."
      }
      Log-Action $Rest "pid=$($w.Pid) title='$($w.Title)'" $Cmd
      "target: pid=$($w.Pid) hwnd=$($w.Handle) class='$($w.Class)' title='$($w.Title)' (no activation - UIA invoke needs no foreground)"
      $r = Invoke-DialogCancel $w ([bool]$own.Values['--allow-window'])
      "cancelled-via=$($r.Via) pressed='$($r.Pressed)' window-gone=$([bool]$r.Confirmed) waited=$($r.WaitedMs)ms"
      "detail: $($r.Note)"
      if (-not $r.Confirmed) {
        throw "dialog-cancel: NOT CONFIRMED - the dialog (pid=$($w.Pid) hwnd=$($w.Handle)) is still on screen after $($r.WaitedMs)ms via $($r.Via). Nothing more was pressed. Inspect with uia-tree '$sel' 40."
      }
      Invoke-ActionExpectation $p $null 'dialog-cancel'
}

# v4.4.0 (A-15): menu-pick - the case body, verbatim
function Invoke-Handler-menu-pick([string]$Cmd, [string[]]$Rest) {
      # menu-pick <sel> <needle...> [--index n] [--allow-window]
      # Resolve the POPUP window itself (context menus are their own top-level
      # windows; find it in `wins`), OCR its rows, click the row containing the
      # needle. Replaces crop -> measure -> convert -> mis-click loops on
      # fixed-line-height menus.
      if ($Rest.Count -lt 2) { throw 'usage: menu-pick <sel> <needle...> [--index n] [--allow-window] [--expect <needle>|--expect-gone <needle>]' }
      # v1.5.7 (J-06): --index/--allow-window come from the flag table now. The expect family
      # stays parsed HERE (menu-pick declares exactly those shared flags in
      # Get-CommandSharedMap) because this command never calls Split-Target and its
      # timeout/interval defaults (6.0s / 300ms) are its own documented behaviour - moving
      # them into Split-Target would silently change defaults for existing scripts.
      $own = Strip-OwnFlags $Rest 'menu-pick'
      $idx = [int]$own.Values['--index']
      $hadIndex = [bool]$own.Present['--index']
      $allowWindow = [bool]$own.Values['--allow-window']
      # v3.1.0 (P-06): the parse moved into the pure Resolve-MenuPickArgs so the trailing-flag
      # hole (a flag as the LAST token bound its operand to $null -> the expectation silently
      # never ran, and --timeout became 0) is pinned by offline unit checks.
      $mpRes = Resolve-MenuPickArgs @($own.Rest)
      $expect = $mpRes.Expect
      $expectGone = $mpRes.ExpectGone
      $expectRegion = $mpRes.ExpectRegion
      $timeoutSec = $mpRes.TimeoutSec
      $intervalMs = $mpRes.IntervalMs
      $Rest = @($mpRes.Words)
      if ($Rest.Count -lt 2) { throw 'usage: menu-pick <sel> <needle...> [--index n] [--allow-window]' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      Emit-ResolveNote
      # Pointing this at a whole application window (or the desktop) turns "pick
      # the menu row" into "click the first pixel anywhere that happens to contain
      # the text", which is how a send ends up in the wrong conversation. The
      # v1.5.2 predicate is class+shape, NOT the WS_POPUP bit - see Test-MenuWindow
      # (audit R-04: Progman/Settings/Weixin all carry WS_POPUP and were accepted).
      $scrMenu = [System.Windows.Forms.SystemInformation]::VirtualScreen
      $menuVerdict = Test-MenuWindow $w ([int]$scrMenu.Width) ([int]$scrMenu.Height)
      if (-not $menuVerdict.Menu -and -not $allowWindow) {
        throw "menu-pick: target '$($w.Title)' ($($w.W)x$($w.H), class=$($w.Class)) is NOT a menu window ($($menuVerdict.Reason)). Picking a row from a whole app/desktop surface can click anything that merely contains the text - take the real popup from 'wins' (Win32 menus are class #32768), or pass --allow-window if pointing at this window is really intended."
      }
      if ($menuVerdict.Menu) {
        Write-Output "menu target accepted: $($menuVerdict.Reason)"
      } else {
        Write-Output "menu-pick: --allow-window overrides the shape rule ($($menuVerdict.Reason))"
      }
      $needle = (@($Rest[1..($Rest.Count - 1)]) -join ' ').Trim()
      if (-not $needle) { throw 'menu-pick: empty needle' }
      $m = Find-OcrHitsScaled $w.Left $w.Top $w.W $w.H $needle
      $hits = $m.Hits; $lines = $m.Lines
      if ($hits.Count -eq 0) {
        throw "menu-pick: row '$needle' not found in menu window '$($w.Title)' ($($w.W)x$($w.H)); $(Format-OcrSampleTail $lines 12 @{ Rect = "window '$($w.Title)' ($($w.Left),$($w.Top)) $($w.W)x$($w.H)"; Retry = (Format-OcrRetryNote $m); Occlusion = 'menu window, gate not run'; Needle = $needle })"
      }
      if ($idx -ge $hits.Count) { throw "menu-pick: --index $idx out of range ($($hits.Count) row(s) matched)" }
      if ($hits.Count -gt 1 -and -not $hadIndex) {
        Write-Output "menu-pick: WARN $($hits.Count) rows contain '$needle'; picking #$idx - pass --index to choose"
      }
      # J-05: same wording, same producer as find-text/find-click (one renderer per family).
      $j05m = Format-MultiOccurrenceHint $needle $hits
      if ($j05m) { Write-Output $j05m }
      $hit = $hits[$idx]
      $cx = $hit.X + [int]($hit.W / 2)
      $cy = $hit.Y + [int]($hit.H / 2)
      Log-Action (Get-RedactedLogArgs $Rest @($Rest[1..($Rest.Count - 1)]) $false) "pid=$($w.Pid) title='$($w.Title)' row='$($hit.Text)' at=$cx,$cy" $Cmd
      Move-Click $cx $cy 'left'
      "menu-pick: clicked row '$($hit.Text)' at ($cx,$cy) rect=($($hit.X),$($hit.Y),$($hit.W)x$($hit.H))$(if ($m.Scaled) { ' [found via 2x upscale]' })"
      Invoke-ActionExpectation @{ Expect = $expect; ExpectGone = $expectGone; ExpectRegion = $expectRegion; TimeoutSec = $timeoutSec; IntervalMs = $intervalMs } $w 'menu-picked'
}

# v4.4.0 (A-15): open-and-pick - the case body, verbatim
function Invoke-Handler-open-and-pick([string]$Cmd, [string[]]$Rest) {
      # open-and-pick <sel> <opener-x> <opener-y> <needle...> [--region x,y,w,h] [--expect ...]
      # A-1 (J-03 A, owner-adjudicated): one process does click opener -> beat -> shoot the
      # target window (or its --region sub-rect) -> OCR needle -> click the hit's centre.
      # For self-drawn dropdowns / right-click menus that menu-pick cannot see (not
      # #32768, not transient-popup shaped). Deliberately does NOT add an index: the
      # adjudicated shape has none; the pick is the FIRST matching line. Coordinates are
      # WINDOW-RELATIVE (the opener lives inside the target). The 400 ms beat before the
      # shot is the popup's appearance window and is echoed, not hidden. Live behaviour
      # (the real two clicks) is proven in --live; parsing and refusal shapes are
      # provable offline and pinned in selftest.
      $own = Strip-OwnFlags $Rest 'open-and-pick'
      $p = Split-Target @($own.Rest) 'open-and-pick'
      if ($p.Words.Count -lt 4) { throw 'usage: open-and-pick <sel> <opener-x> <opener-y> <needle...> [--region x,y,w,h]' }
      $regionSpec = "$($own.Values['--region'])"
      $region = Parse-OpenPickRegion $regionSpec
      $needle = (@($p.Words[3..($p.Words.Count - 1)]) -join ' ').Trim()
      if (-not $needle) { throw 'open-and-pick: empty needle' }
      if ("$($p.Words[1])" -notmatch '^-?[0-9]+$' -or "$($p.Words[2])" -notmatch '^-?[0-9]+$') { throw "open-and-pick: opener coordinates must be integers, got: '$($p.Words[1])' '$($p.Words[2])'" }
      $ox = [int]$p.Words[1]; $oy = [int]$p.Words[2]
      $tgt = Resolve-Target $p.Words[0] $p.Force $p.AlwaysActivate $p.ExpectHandle
      Emit-ResolveNote
      $irect = Get-TargetRect $tgt
      if ($null -eq $irect) { throw 'open-and-pick: cannot determine target window rect' }
      if ($region) {
        if ($region.W -gt $irect.W -or $region.H -gt $irect.H) { throw "open-and-pick: --region $($region.W)x$($region.H) exceeds window $($irect.W)x$($irect.H)" }
      }
      Invoke-ContentGuard $tgt $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
      $openX = $irect.X + $ox; $openY = $irect.Y + $oy
      Invoke-HitWindowCheck $openX $openY $tgt $true $p.AllowOutside
      Log-Action (Get-RedactedLogArgs $Rest @($p.Words[3..($p.Words.Count - 1)]) $p.LogPayload) "opener click at=$openX,$openY needle pending" $Cmd
      Move-Click $openX $openY 'left'
      Start-Sleep -Milliseconds 400
      $srect = Get-TargetRect $tgt
      if ($null -eq $srect) { throw 'open-and-pick: target window rect disappeared after the opener click' }
      $scanX = $srect.X + $(if ($region) { $region.X } else { 0 })
      $scanY = $srect.Y + $(if ($region) { $region.Y } else { 0 })
      $scanW = $(if ($region) { $region.W } else { $srect.W })
      $scanH = $(if ($region) { $region.H } else { $srect.H })
      $f = Find-OcrHitsScaled $scanX $scanY $scanW $scanH $needle $p.Scale $p.MaxTiles $p.NoTile
      $hits = $f.Hits
      if ($hits.Count -eq 0) {
        $missRect = "($($scanX),$($scanY)) $($scanW)x$($scanH)"
        throw "open-and-pick: '$needle' not found in region $missRect after opener click - nothing picked ($(Format-OcrRetryNote $f)); $(Format-OcrSampleTail $f.Lines 8 @{ Rect = $missRect; Retry = (Format-OcrRetryNote $f); Occlusion = 'scanned-after-opener'; Needle = $needle })"
      }
      $hit = $hits[0]
      $cx = $hit.X + [int]($hit.W / 2)
      $cy = $hit.Y + [int]($hit.H / 2)
      Invoke-HitWindowCheck $cx $cy $tgt $true $p.AllowOutside
      $ecb = Get-ExpectChangeBaseline $p $tgt
      Log-Action (Get-RedactedLogArgs $Rest @($p.Words[3..($p.Words.Count - 1)]) $p.LogPayload) "needle='$needle' hit=1/$($hits.Count) at=$cx,$cy" $Cmd
      Move-Click $cx $cy 'left'
      "open-and-pick: opener ($openX,$openY) beat 400ms, clicked '$($hit.Text)' at ($cx,$cy) (hit 1/$($hits.Count))$(if ($f.Scaled) { ' [found via 2x upscale]' })$(Get-OcrFoldMarker $hits)"
      Invoke-ExpectChangeCheck $p $ecb 'open-and-pick'
      Invoke-ActionExpectation $p $tgt 'picked'
}

# ---------------------------------------------------------------------------
# CU-OPS package A: proc-start / proc-kill.
#   proc-list / proc-info / proc-wait live in handlers-read (observation); the two
#   commands here are the only ones that CREATE or END something. Termination is
#   preview-by-default and binds a PID to its recorded creation time: the identity is
#   re-read THROUGH THE SAME OPENED PROCESS OBJECT that TerminateProcess is issued on,
#   so "verified A, then killed a recycled PID" cannot happen. A terminate request is
#   asynchronous - it is reported as an exit only when the same object has actually ended.
# ---------------------------------------------------------------------------

# Windows argv quoting (CommandLineToArgvW rules): the caller passes an array, this
# makes the single command-line string. Start-Process -ArgumentList is NOT used -
# it does not quote an operand containing a space (see the Chrome restart note).
function Format-ProcArg([string]$a) {
  if ($a -eq '') { return '""' }
  if ($a -notmatch '[\s"]') { return $a }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('"')
  $bs = 0
  foreach ($ch in $a.ToCharArray()) {
    if ($ch -eq [char]'\') { $bs++; continue }
    if ($ch -eq [char]'"') { [void]$sb.Append(('\' * (($bs * 2) + 1))); [void]$sb.Append('"'); $bs = 0; continue }
    if ($bs -gt 0) { [void]$sb.Append(('\' * $bs)); $bs = 0 }
    [void]$sb.Append($ch)
  }
  if ($bs -gt 0) { [void]$sb.Append(('\' * ($bs * 2))) }
  [void]$sb.Append('"')
  return $sb.ToString()
}

# Parent-PID chain of THIS tool's own process, so killing an ancestor that would take
# this session down with it is refused instead of discovering it afterwards.
function Get-ProcAncestors([int]$startId) {
  $set = New-Object System.Collections.ArrayList
  $cur = $startId
  $steps = 0
  while ($cur -gt 0 -and $steps -lt 16) {
    $parent = 0
    try {
      $c = Get-CimInstance Win32_Process -Filter ("ProcessId=$cur") -ErrorAction Stop
      if ($c) { $parent = [int]$c.ParentProcessId }
    } catch { $parent = 0 }
    if ($parent -le 0 -or $parent -eq $cur) { break }
    if ($set.Contains($parent)) { break }
    [void]$set.Add($parent)
    $cur = $parent
    $steps++
  }
  return ,$set
}

# proc-start [--cwd <dir>] [--wait-window <s>] <exe> [argv...]
# The exe is a real path (or a bare image name resolved through App Paths); the rest is
# argv, quoted here - never concatenated into a shell string, never elevated.
function Invoke-Handler-proc-start([string]$Cmd, [string[]]$Rest) {
  $tokens = @($Rest)
  # Flags may only PRECEDE the exe; everything from the first non-flag token on is
  # exe + argv and is never scanned for flags (a program's own --help must reach it).
  # Which own flags take a value is read from the table, not re-typed here.
  $spec = Get-OwnFlagSpec 'proc-start'
  $head = New-Object System.Collections.ArrayList
  $needValue = $false
  $i = 0
  while ($i -lt $tokens.Count) {
    $t = [string]$tokens[$i]
    if ($needValue) { [void]$head.Add($t); $needValue = $false; $i++; continue }
    if ($t -like '--*') {
      [void]$head.Add($t); $i++
      if ($spec.ContainsKey($t) -and -not [bool](Get-OptValue $spec[$t] 'Bool')) { $needValue = $true }
      continue
    }
    break
  }
  $own = Strip-OwnFlags @($head) 'proc-start'
  $cwd = [string]$own.Values['--cwd']
  $waitWindow = [int]$own.Values['--wait-window']
  if ($i -ge $tokens.Count) { throw 'usage: proc-start [--cwd <dir>] [--wait-window <s>] <exe> [argv...]' }
  $exe = [string]$tokens[$i]
  $argv = @()
  if ($i + 1 -lt $tokens.Count) { $argv = @($tokens[($i + 1)..($tokens.Count - 1)]) }
  $rooted = [System.IO.Path]::IsPathRooted($exe)
  if ($rooted) {
    if (-not [System.IO.File]::Exists($exe)) { throw "proc-start: '$exe' is not an existing file - nothing was started" }
  } elseif ($exe -match '[\\/]') {
    throw "proc-start: '$exe' has a directory component but is not rooted - give the full path, nothing was started"
  }
  if ($cwd) {
    if (-not [System.IO.Directory]::Exists($cwd)) { throw "proc-start: --cwd '$cwd' is not an existing directory - nothing was started" }
  }
  Log-Action (Get-RedactedLogArgs $Rest $argv $false) "exe='$exe' argc=$($argv.Count)$(if ($cwd) { " cwd='$cwd'" } else { '' })" $Cmd
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $exe
  if ($argv.Count -gt 0) { $psi.Arguments = (($argv | ForEach-Object { Format-ProcArg ([string]$_) }) -join ' ') }
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $false
  if ($cwd) { $psi.WorkingDirectory = $cwd }
  $pr = $null
  try { $pr = [System.Diagnostics.Process]::Start($psi) } catch { throw "proc-start: could not start '$exe' - $($_.Exception.Message)" }
  $startIso = 'denied'
  try { $startIso = $pr.StartTime.ToString('o') } catch { $startIso = 'denied' }
  "started pid=$($pr.Id) start=$startIso exe='$exe' argc=$($argv.Count)$(if ($startIso -eq 'denied') { ' (creation time denied - proc-kill --go cannot bind it)' } else { '' })"
  if ($waitWindow -gt 0) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $hwnd = 0
    while ($sw.Elapsed.TotalSeconds -lt $waitWindow) {
      try { $pr.Refresh(); $hwnd = $pr.MainWindowHandle.ToInt64() } catch { $hwnd = 0 }
      if ($hwnd -ne 0) { break }
      Start-Sleep -Milliseconds 200
    }
    if ($hwnd -ne 0) {
      "window appeared after $([math]::Round($sw.Elapsed.TotalSeconds,1))s hwnd=0x$($hwnd.ToString('X')) title='$(try { $pr.MainWindowTitle } catch { 'denied' })'"
    } else {
      throw "proc-start: pid=$($pr.Id) is running but has no top-level window after ${waitWindow}s - the process was NOT stopped; use proc-wait/proc-info if a window is still expected"
    }
  }
}

# proc-kill <pid> [--created <iso>] [--timeout <s>] [--go]
# Preview by default. --go needs --created (the identity read with proc-info), refuses
# protected/system/session processes, this tool itself and its own ancestor chain, and
# never kills a subtree.
function Invoke-Handler-proc-kill([string]$Cmd, [string[]]$Rest) {
  $own = Strip-OwnFlags $Rest 'proc-kill'
  $words = @($own.Rest)
  $go = [bool]$own.Values['--go']
  $created = [string]$own.Values['--created']
  $timeout = [int]$own.Values['--timeout']
  if ($words.Count -ne 1) { throw 'usage: proc-kill <pid> [--created <iso>] [--timeout <s>] [--go]   (preview unless --go)' }
  $pidNum = 0
  if (-not [int]::TryParse([string]$words[0], [ref]$pidNum)) { throw "proc-kill: '$($words[0])' is not a pid" }
  $snap = Get-ProcSnapshot $pidNum
  if ($snap.exists -ne $true) {
    throw "proc-kill: pid=$pidNum is not CONFIRMED running (exists=$($snap.exists)$(if ($snap.exists_why) { ': ' + $snap.exists_why } else { '' })) - nothing to kill (a PID alone is not an identity, and a reused PID will not be chased)"
  }
  if ($snap.protected) { throw "proc-kill: pid=$pidNum name=$($snap.name) is a protected system/session process - refused, nothing was terminated" }
  if ($pidNum -eq $PID) { throw "proc-kill: pid=$pidNum is this tool's own process - refused, nothing was terminated" }
  $anc = Get-ProcAncestors ([int]$PID)
  if ($anc.Contains($pidNum)) { throw "proc-kill: pid=$pidNum is an ancestor of this tool (chain: $($anc -join '<-')) - terminating it would take this session down, refused" }
  "target: $(Format-ProcSnapshot $snap)"
  if ($created) {
    $id = Test-ProcIdentity $pidNum $created
    if (-not $id.Ok) { throw "proc-kill: identity refused - $($id.Why). Nothing was terminated." }
    "identity: $($id.Why)"
  }
  if (-not $go) {
    "preview only: nothing was terminated. Re-run with --go$(if (-not $created) { ' AND --created <start> from the line above' }) to send the terminate request. Unsaved work in the target may be lost; a graceful win-close (WM_CLOSE) or dialog-cancel first is safer."
    return
  }
  if (-not $created) { throw 'proc-kill: --go requires --created <iso> so the PID is bound to one observed process; re-read it with proc-info. Nothing was terminated.' }
  # Open ONE process object, pin ONE native handle through it, re-read the creation time
  # THROUGH THAT HANDLE, terminate THROUGH IT, wait THROUGH IT, then release it.
  # CU-OPS-ADJ-02: sharing a .NET Process object is not by itself a stable native handle;
  # Process.Handle opens the handle once and caches that IntPtr, so a later Kill/WaitForExit
  # cannot quietly open a fresh handle on a reused PID.
  $pr = $null
  try { $pr = [System.Diagnostics.Process]::GetProcessById($pidNum) } catch { throw "proc-kill: pid=$pidNum cannot be opened ($($_.Exception.Message)) - nothing was terminated" }
  try {
    $hProcess = [IntPtr]::Zero
    try { $hProcess = $pr.Handle } catch { throw "proc-kill: pid=$pidNum was opened but no native process handle could be pinned ($($_.Exception.Message)) - identity cannot be confirmed, nothing was terminated" }
    if ($hProcess -eq [IntPtr]::Zero) { throw "proc-kill: pid=$pidNum returned a null native handle - identity cannot be confirmed, nothing was terminated" }
    'handle: pinned=yes value=0x' + ([int64]$hProcess).ToString('X')
    $hStart = 'denied'
    try { $hStart = $pr.StartTime.ToString('o') } catch { $hStart = 'denied' }
    if ($hStart -eq 'denied') { throw "proc-kill: pid=$pidNum was opened but its creation time is unreadable through that handle - identity cannot be confirmed, nothing was terminated" }
    $want = [datetime]::MinValue; $have = [datetime]::MinValue
    $parseOk = [datetime]::TryParse($created, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$want)
    if (-not $parseOk) { $parseOk = [datetime]::TryParse($created, [ref]$want) }
    if (-not $parseOk) { throw "proc-kill: --created '$created' is not a parseable time - nothing was terminated" }
    $have = [datetime]::Parse($hStart, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
    # CU-OPS-ADJ-01: exact, with the same no-tolerance rule as Test-ProcIdentity.
    $diff = ($have.ToUniversalTime() - $want.ToUniversalTime()).TotalSeconds
    if ($diff -ne 0) { throw "proc-kill: the opened handle's creation time $hStart does not match --created $created (diff $diff s; the creation time must be exact) - the PID was reused or the pin is stale, nothing was terminated" }
    Log-Action $Rest "pid=$pidNum name=$($snap.name) created=$created handle=0x$(([int64]$hProcess).ToString('X'))" $Cmd
    try { $pr.Kill() } catch {
      $msg = $_.Exception.Message
      if ($pr.HasExited) { "proc-kill: pid=$pidNum had already exited before the request - confirmed by the same pinned handle; no terminate was needed"; return }
      throw "proc-kill: terminate request FAILED for pid=$pidNum ($msg) - the process is still running as far as this tool can see"
    }
    $waited = $false
    try { $waited = $pr.WaitForExit([int]($timeout * 1000)) } catch { $waited = $false }
    $gone = $false
    try { $gone = [bool]$pr.HasExited } catch { $gone = $false }
    if ($gone) {
      "terminated pid=$pidNum name=$($snap.name) confirmed-exit=yes waited=$($timeout)s handle-pinned=yes"
      return
    }
    throw "proc-kill: terminate request was ACCEPTED for pid=$pidNum but the process has not exited within ${timeout}s - a request is not an exit. It may be unwinding; re-check with proc-info $pidNum before retrying"
  } finally {
    # Release LAST, after every read above has been taken from the same handle.
    try { $pr.Dispose() } catch { }
  }
}

