# lib/handlers-ui.ps1 - the ui-group handlers, lifted out of desktop.ps1 (A-17..A-19 line).
#    Byte-identical to what the dispatcher carried after A-15 pen 2: the union of the lifted lines was
#    hashed before the cut and the same bytes are re-hashed from this file afterwards (printed by
#    handler-lift.js, and recorded in the ledger row for this card). The group membership is declared in
#    $script:StHandlerGroups and reconciled against the definitions by lint (A-16) - this file is named in
#    $script:StHandlerFiles in the same write that removes the code from the entry, so neither half can
#    land on its own.

# v4.4.0 (A-15): chrome-tabs - the case body, verbatim
function Invoke-Handler-chrome-tabs([string]$Cmd, [string[]]$Rest) {
      # chrome-tabs [--json] - enumerate open tabs via CDP's HTTP endpoint (no socket).
      # The base is the loopback gate's OUTPUT and that base is what every request
      # below uses - the gate is on the real path, not decoration.
      # Chrome >=136 REFUSES --remote-debugging-port on the DEFAULT profile ("DevTools
      # remote debugging requires a non-default data directory", measured 2026-09-30),
      # so this group only ever talks to a non-default --user-data-dir instance.
      $base = Get-CdpLoopbackBase "127.0.0.1:$script:CdpPort"
      $tabs = @(Get-CdpTargets $base 'page')
      if ($script:Json) {
        [pscustomobject]@{ tabs = @($tabs | ForEach-Object { [pscustomobject]@{ id = $_.id; title = $_.title; domain = (Get-CdpUrlDomain $_.url) } }) } | ConvertTo-Json -Compress -Depth 4
      } else {
        "chrome-tabs: $($tabs.Count) page(s) on $base/json (host+port only - a token can sit in the path as happily as in the query)"
        $n = 0
        foreach ($t in $tabs) { $n++; "T{0:D2} host={1}  title={2}" -f $n, (Get-CdpUrlDomain $t.url), ([string]$t.title) }
      }
}

# v4.4.0 (A-15): chrome-read - the case body, verbatim
function Invoke-Handler-chrome-read([string]$Cmd, [string[]]$Rest) {
      # chrome-read <sel> - visible text of the matching tab's page (body.innerText),
      # through one Runtime.evaluate round trip. Read-only.
      # v3.1.0 (P-06): the selector is REQUIRED. Get-CdpPageId falls back to the FIRST page
      # when it gets an empty selector, so `chrome-read` with a missing argument used to read
      # whichever tab happened to be first and exit 0 - while chrome-find and chrome-click both
      # refuse. Same family, one command silently answering for a page nobody named.
      $base = Get-CdpLoopbackBase "127.0.0.1:$script:CdpPort"
      if ($Rest.Count -lt 1) { throw 'usage: chrome-read <sel>  (the selector names the tab - there is no default tab)' }
      $p = Get-CdpPageId $base $Rest[0]
      $r = Invoke-CdpEval $base $p.Page.id 'document.body.innerText'
      if (-not $r.Ok) { throw "chrome-read: $($r.Error)" }
      $lines = @("$($r.Value)" -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 })
      $shown = @($lines | Select-Object -First 40)
      "chrome-read: tab '$($p.Page.title)' ($($p.Count) page(s) open): $($lines.Count) non-empty line(s)$(if ($lines.Count -gt $shown.Count) { ", showing first $($shown.Count) ($($lines.Count - $shown.Count) more not shown)" })"
      foreach ($ln in $shown) { $ln.Trim() }
}

# v4.4.0 (A-15): chrome-find - the case body, verbatim
function Invoke-Handler-chrome-find([string]$Cmd, [string[]]$Rest) {
      # chrome-find <sel> <text> - locate the innermost element whose text contains
      # <text>, return its rect CONVERTED to physical screen coordinates. The scale
      # factor is measured per call (window.devicePixelRatio), the client origin is
      # derived from window.screenX/Y plus outer/inner deltas - A-3 reconciles the
      # result against find-text OCR (<=3px), never against our own claim.
      $base = Get-CdpLoopbackBase "127.0.0.1:$script:CdpPort"
      if ($Rest.Count -lt 2) { throw 'usage: chrome-find <sel> <text...>' }
      $p = Get-CdpPageId $base $Rest[0]
      $needle = (@($Rest[1..($Rest.Count - 1)]) -join ' ').Trim()
      $needleJson = $needle | ConvertTo-Json -Compress
      $js = @"
const needle = $needleJson;
const els = Array.from(document.querySelectorAll('body *'));
const matches = els.filter(e => e.getClientRects().length > 0 && ((e.innerText || '').indexOf(needle) >= 0));
if (matches.length === 0) { return { found: false }; }
let best = matches[0];
for (const m of matches) { if ((m.innerText || '').length < (best.innerText || '').length) { best = m; } }
best.scrollIntoView({ block: 'center' });
const r = best.getBoundingClientRect();
return { found: true, count: matches.length, rect: { left: r.left, top: r.top, width: r.width, height: r.height }, text: (best.innerText || '').slice(0, 60) };
"@
      $r = Invoke-CdpJson $base $p.Page.id $js
      if (-not $r.Ok) { throw "chrome-find: $($r.Error)" }
      if (-not $r.Value.found) { throw "chrome-find: no element matching '$needle' on page '$($p.Page.title)' (DOM scan, 0 matching leaf elements - this is a DOM verdict, not an OCR miss)" }
      $m = Invoke-CdpJson $base $p.Page.id 'return { dpr: window.devicePixelRatio, iw: window.innerWidth, ih: window.innerHeight, sx: window.screenX, sy: window.screenY, ow: window.outerWidth, oh: window.outerHeight };'
      if (-not $m.Ok) { throw "chrome-find: metrics probe failed: $($m.Error)" }
      $dpr = [double]$m.Value.dpr
      if ($dpr -le 0) { throw "chrome-find: the page reported devicePixelRatio=$dpr - refusing to map through a nonsense scale factor" }
      # sx/ow are not decoration: the JS fallback route needs the X axis of its own. A
      # probe that stops reporting them must not leave the mapping silently half-blind.
      if ($null -eq $m.Value.sx -or $null -eq $m.Value.ow) { throw "chrome-find: the metrics probe returned no screenX/outerWidth - refusing to guess the viewport's left edge" }
      $co = Get-CdpViewportOrigin $base $dpr ([int]$m.Value.ih) ([int]$m.Value.iw) ([int]$m.Value.sy) ([int]$m.Value.oh) ([int]$m.Value.ih) ([int]$m.Value.sx) ([int]$m.Value.ow)
      if (-not $co.Ok) { throw "chrome-find: cannot place the viewport on the screen: $($co.Error)" }
      $clientX = $co.X; $clientY = $co.Y
      $sr = Convert-CdpRectToScreen $r.Value.rect $dpr $clientX $clientY
      $cx = $sr.X + [int]($sr.W / 2); $cy = $sr.Y + [int]($sr.H / 2)
      "chrome-find: '$needle' on '$($p.Page.title)' ($($r.Value.count) leaf hit(s)) rect screen=($($sr.X),$($sr.Y),$($sr.W)x$($sr.H)) centre=($cx,$cy) dpr=$dpr clientOrigin=($clientX,$clientY) origin-formula=$($co.Formula) origin-window-pid=$($co.Pid) -> click $cx $cy"
}

# v4.4.0 (A-15): chrome-click - body verbatim from the case, plus the flag the G-17 ruling allows
function Invoke-Handler-chrome-click([string]$Cmd, [string[]]$Rest, [ref]$SkipTail) {
      # chrome-click <sel> <text> [-dry] - chrome-find then click its centre with the
      # regular injected click. v3.1.0 (P-06) corrected the promise: this command's selector
      # names a CDP PAGE, not a window, so there is no target rect to enforce a landing
      # guard against - what applies is the AUDIT line and the hit-window ECHO (which window is
      # actually under the mapped point), never landing enforcement. DOM-level synthetic clicks
      # are NOT used: they bypass the guards this tool exists to enforce. -dry stops after
      # printing the mapping.
      $base = Get-CdpLoopbackBase "127.0.0.1:$script:CdpPort"
      if ($Rest.Count -lt 2) { throw 'usage: chrome-click <sel> <text...> [-dry]' }
      $dry = $false
      $words = New-Object System.Collections.ArrayList
      foreach ($t in $Rest) { if ($t -eq '-dry') { $dry = $true } else { [void]$words.Add($t) } }
      $Rest = @($words)
      $findOut = $null
      try { $findOut = Invoke-DesktopCommand 'chrome-find' @($Rest) } catch { throw ("chrome-click: " + $_.Exception.Message) }
      $line = (@($findOut) | Where-Object { $_ -like 'chrome-find:*' } | Select-Object -First 1)   # selection-not-display: single mapping line, not a list cut
      if ("$line" -notmatch 'centre=\((-?\d+),(-?\d+)\)') { throw 'chrome-click: could not parse centre from chrome-find output' }
      $cx = [int]$Matches[1]; $cy = [int]$Matches[2]
      if ($dry) { "chrome-click: [dry run] would click $cx,$cy (from chrome-find mapping)"; $SkipTail.Value = $true; return }
      # v3.1.0 (P-06): the CDP->screen mapping is the part most likely to be wrong (scale,
      # scroll, a second monitor), so name the window actually under the point BEFORE the
      # click lands. Echo-only (no target rect exists for a page selector), same shape as
      # `move` uses. A mapping that lands on the wrong window is now visible in the same line
      # the operator already reads, instead of only in hindsight.
      Invoke-HitWindowCheck $cx $cy $null $false $false
      Log-Action @($Rest) "cdp pick at=$cx,$cy" $Cmd
      Move-Click $cx $cy 'left'
      "chrome-click: clicked $cx,$cy (from chrome-find mapping)"
}

# v4.4.0 (A-15): chrome-menu-read - the case body, verbatim
function Invoke-Handler-chrome-menu-read([string]$Cmd, [string[]]$Rest) {
      # chrome-menu-read - OPEN Chrome's app menu, list every MenuItem Name UIA exposes,
      # then dismiss it WITHOUT clicking anything (Escape). This is how the option-B exit
      # route gets evidence on a browser that is still in use: it answers "can this
      # build's menu be read by literal Name, and is exactly one item the exit?" without
      # quitting the browser. NOT read-only - it opens a menu - and it refuses (exit 1)
      # when the exit item cannot be picked, so a caller never reads "menu seen" as
      # "exit drivable".
      $w = Resolve-Window 'Chrome'
      if (-not $w) { throw 'chrome-menu-read: no Chrome window found - there is no menu to read' }
      Log-Action @('chrome-menu-read') "opening the app menu of pid $($w.Pid) to read item names; no item clicked" $Cmd
      $rd = Read-ChromeMenuItems $w 4000
      $pick = Find-ChromeExitItem $rd.Items
      "chrome-menu-read: pid=$($w.Pid) opened-via=$($rd.Via) menu-items=$($rd.Count) dismissed=$($rd.Dismissed) exit-item='$($pick.Name)' exit-verdict=$($pick.Reason)"
      if ($rd.Count -gt 0) { "items: $(@($rd.Items) -join ' ;; ')" }
      if (-not $rd.Opened) { throw "chrome-menu-read: $($rd.Error)" }
      if (-not $pick.Ok) { throw "chrome-menu-read: no exit item was picked - $($pick.Reason). Chrome is still running and nothing was clicked; option B is not drivable on this build." }
}

# v4.4.0 (A-15): chrome-debug-off - the case body, verbatim
function Invoke-Handler-chrome-debug-off([string]$Cmd, [string[]]$Rest) {
      # chrome-debug-off - the B-3 shutdown path: relaunch Chrome WITHOUT the debug
      # flag, then VERIFY the port is dead - /json/version must stop answering and
      # chrome-tabs must refuse. Omission IS the shutdown; Chrome only opens the port
      # when asked. The close goes through Restart-ChromeWithFlags, which prefers
      # Browser.close over WM_CLOSE because WM_CLOSE was measured to leave chrome.exe
      # alive headless (service-worker extension) while still holding 9222 - and a
      # relaunch into that survivor is a singleton hand-off, not a restart.
      $base = Get-CdpLoopbackBase "127.0.0.1:$script:CdpPort"
      $tabsBefore = @(Get-CdpTargets $base 'page')
      Log-Action @('chrome-debug-off') "closing chrome, $($tabsBefore.Count) page(s) expected to come back; relaunch carries no debug flag" $Cmd
      $rs = Restart-ChromeWithFlags @('--restore-last-session') $base 30000
      if (-not $rs.Closed) { throw "chrome-debug-off: $($rs.Error)" }
      $swR = [System.Diagnostics.Stopwatch]::StartNew()
      $portDead = $false
      while ($swR.ElapsedMilliseconds -lt 20000) {
        try { [void](Invoke-RestMethod -Uri "$base/json/version" -TimeoutSec 2); Start-Sleep -Milliseconds 600 } catch { $portDead = $true; break }
      }
      if (-not $portDead) { throw "chrome-debug-off: $base/json/version still answering 20s after the relaunch - the debug port did not close, investigate before trusting the box (chrome processes: $(@(Get-Process chrome -ErrorAction SilentlyContinue).Count))" }
      "chrome-debug-off: Chrome closed via $($rs.CloseVia) close-note=[$($rs.CloseNote)] anchored-pid=$($rs.AnchorPid) anchored-by=$($rs.AnchoredBy) scope=$($rs.Scope) ($($tabsBefore.Count) page(s) saved, waited $($rs.WaitedMs)ms for that browser's $($rs.Scoped) process(es) to exit) and relaunched WITHOUT the debug flag"
      "VERIFIED: $base/json/version no longer answers after $($swR.ElapsedMilliseconds)ms - CDP surface closed (chrome-tabs now refuses, which is the proof)"
      if ($null -eq $rs.Window) { "WARNING: no Chrome window 30s after the relaunch - the port is closed but Chrome did not come back visibly; open it manually" }
}

# v4.4.0 (A-15): chrome-a11y - the case body, verbatim
function Invoke-Handler-chrome-a11y([string]$Cmd, [string[]]$Rest) {
      # chrome-a11y <on|off> - the A-plan relaunch. THIS is the page-driving route for
      # the owner's DEFAULT profile: measured 2026-09-30 on Chrome 154, Chrome refuses
      # --remote-debugging-port there outright and prints
      #   "DevTools remote debugging requires a non-default data directory."
      # so CDP (chrome-*) can only ever drive a NON-default --user-data-dir instance.
      # --force-renderer-accessibility needs no such trade: the page DOM reaches the
      # UIA tree and the existing uia-* family drives real logged-in tabs.
      #   on  -> relaunch with --force-renderer-accessibility --restore-last-session
      #   off -> relaunch with just --restore-last-session (tree returns to collapsed)
      # Self-verifies by product, never by echo: the page-area control count and the
      # TabItem count are measured before and after, so a relaunch that changed nothing
      # cannot be reported as a success, and a restore that lost tabs cannot be hidden.
      if ($Rest.Count -lt 1) { throw 'usage: chrome-a11y <on|off>' }
      $mode = "$($Rest[0])".ToLower()
      if ($mode -ne 'on' -and $mode -ne 'off') { throw "chrome-a11y: mode must be 'on' or 'off' (got '$($Rest[0])')" }
      $wBefore = Resolve-Window 'Chrome'
      if (-not $wBefore) { throw 'chrome-a11y: no Chrome window found - there is no Chrome to relaunch' }
      $before = Measure-A11yTree $wBefore 40
      $flags = @('--restore-last-session')
      if ($mode -eq 'on') { $flags = @('--force-renderer-accessibility', '--restore-last-session') }
      Log-Action @('chrome-a11y') "mode=$mode tabs-before=$($before.Tabs) page-area-before=$($before.PageHits) verdict-before=$($before.Verdict)" $Cmd
      # owner ruling 2: reconcile tabs across EVERY restart this command performs.
      # The manifest goes to a UTF-8 BOM file, never the GBK console.
      $tmBefore = Write-TabManifest $wBefore 'before'
      if ($tmBefore.Error) { throw "chrome-a11y: tab manifest (before) failed: $($tmBefore.Error)" }
      "tab-manifest=$($tmBefore.Path) tabs-before=$($tmBefore.Count)"
      $rs = Restart-ChromeWithFlags $flags '' 45000
      if (-not $rs.Closed) { throw "chrome-a11y: $($rs.Error)" }
      if ($null -eq $rs.Window) { throw "chrome-a11y: Chrome closed but no window came back 45s after the relaunch - open Chrome yourself; the flag was not applied to a live instance" }
      # the tree fills in as pages commit, so re-measure until the verdict flips or the
      # patience runs out - the same "+ verified / NOT met" split the click family uses.
      $after = $null
      $swA = [System.Diagnostics.Stopwatch]::StartNew()
      $wantVerdict = $(if ($mode -eq 'on') { 'exposed' } else { 'collapsed' })
      $wpin = $rs.Window
      while ($swA.ElapsedMilliseconds -lt 20000) {
        # stay on the instance WE launched: a title match could wander onto a second
        # Chrome running from a different --user-data-dir and be measured instead
        $wpid = Resolve-Window ([string]$rs.Window.Pid)
        if ($wpid) { $wpin = $wpid }
        $after = Measure-A11yTree $wpin 40
        if ($after.Verdict -eq $wantVerdict) { break }
        Start-Sleep -Milliseconds 1000
      }
      $met = ($after.Verdict -eq $wantVerdict)
      # reconcile the tabs BEFORE any a11y-verdict throw: the tabs are the owner's
      # state, and a mismatch must stop here - a second restart would make Chrome
      # treat the still-open session as old data and clear it (owner ruling 3).
      $tmAfter = Write-TabManifest $wpin 'after'
      if ($tmAfter.Error) { throw "chrome-a11y: tab manifest (after) failed: $($tmAfter.Error)" }
      $tmCmp = Compare-TabManifest $tmBefore.Lines $tmAfter.Lines
      "tab-manifest=$($tmAfter.Path) tabs-after=$($tmAfter.Count) tab-verify=$($tmCmp.Reason)"
      if (-not $tmCmp.Ok) { throw "chrome-a11y: TAB MISMATCH across the restart - $($tmCmp.Reason). Stopping without a second restart (ruling 3: restarting again makes Chrome treat the open session as old data and clear it). Compare the two manifest files and restore tabs by hand." }
      "chrome-a11y: mode=$mode closed-via=$($rs.CloseVia) close-note=[$($rs.CloseNote)] exit-item='$($rs.ExitName)' scope=$($rs.Scope) waited=$($rs.WaitedMs)ms relaunched-pid=$($rs.Window.Pid) launch-args=[$($rs.LaunchArgs)]"
      "VERIFIED page-tree: before=$($before.Verdict) (nodes=$($before.Nodes) page-area=$($before.PageHits) tabs=$($before.Tabs)) -> after=$($after.Verdict) (nodes=$($after.Nodes) page-area=$($after.PageHits) tabs=$($after.Tabs) kinds=[$($after.Kinds)]) patience $([int]$swA.ElapsedMilliseconds)ms/20000ms met=$met"
      if ($after.Tabs -ne $before.Tabs) { "NOTE: tab count changed across the relaunch: $($before.Tabs) -> $($after.Tabs). Names to check: this command cannot tell you WHICH tabs went missing, run uia-tree <sel> 40 | grep TabItem" }
      # WHAT THIS CAN AND CANNOT PROVE (measured 2026-09-30, owner's own Chrome, A-6b):
      # the same DEFAULT-profile window read page-area 0 on the first UIA contact 110 ms
      # after a NO-FLAG relaunch and 19 / 100 nodes on the next three contacts - Chrome
      # enables renderer accessibility because a UIA client connected, not because of the
      # switch. With the flag the steady reading was identical (19 / 100). So 'exposed'
      # after 'on' is NOT proof the flag caused it, and this command's real job is the
      # graceful relaunch + the tab reconciliation, with the tree numbers reported as
      # observations. What stays sound: if 'on' still measures ZERO after the re-probe
      # patience, the operator has nothing drivable and must be told.
      if ($mode -eq 'on' -and -not $met) { throw "chrome-a11y: relaunched WITH the flag but the page area still exposes 0 interactive controls after 20s of patience - the flag did not take (survivor process? a different profile?). Nothing is drivable via uia-* on this page; do not fall back to clicking coordinates blindly." }
      if ($mode -eq 'off' -and $after.PageHits -gt 0) { "NOTE: the flag is gone but the page area still exposes $($after.PageHits) interactive controls - Chrome keeps renderer accessibility on for any connected UIA client, so chrome-a11y off removes the SWITCH, it does not close a surface. Do not treat 'off' as a privacy boundary." }
}

# v4.4.0 (A-15): a11y-probe - the case body, verbatim
function Invoke-Handler-a11y-probe([string]$Cmd, [string[]]$Rest) {
      # a11y-probe <sel> [bigDepth] - READ-ONLY diagnosis for Chromium/Electron shells:
      # how many controls does the UIA tree expose, and does the PAGE AREA (lower half
      # of the window) hold any interactive control? Verdict page-tree=exposed|collapsed
      # answers "can uia-* drive this app's content" BEFORE attempts fail.
      # A-6b (v1.8.0, measured on the owner's own Chrome): 'collapsed' is often just a
      # COLD-START artifact - Chrome lights renderer accessibility when a UIA client
      # connects, and the walk that triggered it has already finished. Same unflagged
      # process: contact #1 = page-area 0 / 60 nodes, contacts #2-4 = 19 / 100. So a
      # zero here is re-measured ONCE before it is allowed to become a verdict.
      # bigDepth is a real limit now (Uia-WalkAll honours it) - the same selector at
      # depth 3 and depth 40 must report different node counts.
      if ($Rest.Count -lt 1) { throw 'usage: a11y-probe <sel> [bigDepth]' }
      $bigDepth = $(if ($Rest.Count -ge 2 -and $Rest[1]) { [int]$Rest[1] } else { 40 })
      # validated BEFORE any window is resolved: refusing early is what makes this
      # reachable offline, and 0 would silently mean "unlimited" on a command whose
      # whole purpose is reporting the depth it actually walked.
      if ($bigDepth -lt 1) { throw "a11y-probe: bigDepth must be >= 1 (got $bigDepth) - 0 would mean unlimited and this command advertises the depth it walked" }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      $m = Measure-A11yTree $w $bigDepth
      if ($m.Verdict -eq 'no-root') { throw "a11y-probe: no UIA root for pid $($w.Pid)" }
      $reprobe = 'no'
      if ($m.Verdict -eq 'collapsed') {
        # Measure again before a zero is allowed to become a verdict: on Chrome the first
        # UIA contact itself enables renderer accessibility, and that first walk is over
        # before the tree exists (measured on the owner's own default-profile Chrome,
        # no flag: contact #1 page-area=0/60 nodes, contact #2 19/100, #3 19/100).
        $m2 = Measure-A11yTree $w $bigDepth
        $reprobe = $(if ($m2.PageHits -gt 0) { 'yes, lit to ' + $m2.PageHits } else { 'yes, still 0' })
        if ($m2.PageHits -gt 0) { $m = $m2 }
      }
      "a11y-probe: class='$($w.Class)' title='$($w.Title)' depth-walked=$bigDepth nodes=$($m.Nodes) interactive=$($m.Interactive) rectless=$($m.Rectless) page-area-interactive=$($m.PageHits) page-kinds=[$($m.Kinds)] page-sample=[$($m.Sample)] cold-zero-reprobe=$reprobe -> page-tree=$($m.Verdict)"
      if ($m.Verdict -eq 'collapsed') {
        "NOTE: still 0 interactive controls in the page area AFTER a re-probe, so this is not the cold-start artifact - UIA genuinely cannot drive this window's content right now. Order of operations: (1) check the fixture - a page whose lower half holds no interactive elements measures 0 with the tree wide open (that bad fixture cost this project one wrong conclusion on 2026-09-30); (2) chrome-a11y on to relaunch Chrome with --force-renderer-accessibility; (3) CDP (chrome-tabs/chrome-find) exists only for NON-default --user-data-dir instances - Chrome 136+ refuses the debug port on a default profile; (4) whole-page OCR + coordinates last, and 'OCR found nothing' is never evidence of absence."
      }
}

# v4.4.0 (A-15): uia-tree - the case body, verbatim
function Invoke-Handler-uia-tree([string]$Cmd, [string[]]$Rest) {
      # v2.4.0: --actions-all / --no-actions / --no-paths are stripped before the
      # positional shape <sel> [maxDepth] is applied; an unknown --word is refused
      # (a swallowed flag is how a fake knob ships).
      # v4.2.0 (external feedback item 4, 2026-10-10): the reporter wanted "--out <file>"
      # because they did not know `--dump` exists - and --out CANNOT exist here: under
      # `powershell -File` the token binds at PowerShell's own parameter layer as -Out*
      # and dies with "AmbiguousParameter (OutVariable|OutBuffer)" before this file runs
      # (measured 2026-10-10). So the file half stays the ONE existing producer
      # (Emit-DumpOutput, uia-tree has been in Get-DumpCommandSet since v3.0.0) and this
      # command's usage line points at it; a second writer would be a second truncation
      # rule. --path is the genuinely missing half and lives here.
      $aAll = $false; $aOff = $false; $pOff = $false
      $pathTok = ''
      $pos = New-Object System.Collections.ArrayList
      $uiCount = @($Rest).Count
      for ($ui = 0; $ui -lt $uiCount; $ui++) {
        $w0 = "$(@($Rest)[$ui])"
        if ($w0 -eq '--actions-all') { $aAll = $true }
        elseif ($w0 -eq '--no-actions') { $aOff = $true }
        elseif ($w0 -eq '--no-paths') { $pOff = $true }
        elseif ($w0 -eq '--path') {
          if (($ui + 1) -ge @($Rest).Count) { throw 'uia-tree: --path needs a token copied from a line''s path= field, e.g. --path /0/1/6' }
          $ui++; $pathTok = "$(@($Rest)[$ui])"
          if ($pathTok -notmatch '^(/\d+)+$') { throw "uia-tree: --path must look like /0/1/6 (digits after slashes, exactly as printed on the line), got: $pathTok" }
        }
        elseif ($w0.StartsWith('--')) { throw "uia-tree: unknown flag '$w0' (valid: --actions-all | --no-actions | --no-paths | --path </0/1/...>; and --dump <file> for the whole tree as UTF-8 - uia-tree is in its accepted set)" }
        else { [void]$pos.Add($w0) }
      }
      if ($aAll -and $aOff) { throw 'uia-tree: --actions-all and --no-actions are mutually exclusive' }
      if (@($pos).Count -lt 1) { throw 'usage: uia-tree <sel> [maxDepth] [--actions-all|--no-actions] [--no-paths] [--path </0/1/...>] [--dump <file>]' }
      $w = Resolve-Window $pos[0]
      if (-not $w) { throw "no window matching: $($pos[0])" }
      $depth = if (@($pos).Count -ge 2 -and $pos[1]) { [int]$pos[1] } else { 6 }
      # a path deeper than the walked bound would print NOTHING and read as "that node
      # does not exist", so the bound is raised to reach it - and the header says which
      # depth really ran (the depth lint below reads that same line).
      $depthNote = ''
      if ($pathTok) {
        $needDepth = (@($pathTok -split '/')).Count - 2
        if ($needDepth -lt 0) { $needDepth = 0 }
        if ($depth -lt $needDepth) { $depthNote = "note: depth raised $depth -> $needDepth to reach --path $pathTok"; $depth = $needDepth }
      }
      $rr = Uia-Roots $w
      if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
      # Paths are per-root unambiguous only when there is exactly ONE root (the
      # normal FromHandle case); the pid-enum fallback can list several, and
      # identical /0/... labels on different roots would be a lie, so there the
      # path fields stay off (actions still probe).
      $usePaths = (-not $pOff) -and (@($rr.Roots).Count -eq 1)
      if ($pathTok -and -not $usePaths) {
        throw "uia-tree: --path needs path= fields on the lines - roots=$($rr.Roots.Count)$([char]32)(a pid with several top-level windows prints none) or --no-paths was passed. Drop --path, or select a window whose tree has one root"
      }
      $outLines = New-Object System.Collections.ArrayList
      [void]$outLines.Add("scan: handle=$($w.Handle) title='$($w.Title)' pick=$($w.Pick) roots=$($rr.Roots.Count) via=$($rr.Via) depth=$depth")
      if ($depthNote) { [void]$outLines.Add($depthNote) }
      $ctx = @{ NoActions = $aOff; AllActions = $aAll; NoPaths = (-not $usePaths); Nodes = 0; Probed = 0; ProbeMs = 0.0; Sw = [System.Diagnostics.Stopwatch]::StartNew() }
      foreach ($r in $rr.Roots) {
        $rn = ''
        try { $rn = $r.Current.Name } catch { }
        [void]$outLines.Add("root: $rn")
        foreach ($dl in @(Uia-Dump $r 0 $depth $ctx '/0')) { [void]$outLines.Add([string]$dl) }
      }
      $ctx.Sw.Stop()
      # v4.2.0: --path keeps the ancestor chain (where in the tree am I) and the subtree
      # (what this node says), drops every sibling, and reports both counts - a filter
      # that silently matched nothing would read as "the node is gone". The decision lives
      # in Test-UiaPathFilter (pure) so both directions are offline checks.
      if ($pathTok) {
        $fp = Test-UiaPathFilter @($outLines) $pathTok
        if (-not $fp.Ok) { throw "uia-tree: --path $pathTok matched no line at depth $depth - copy the token verbatim from a path= field, or raise [maxDepth]" }
        $outLines = New-Object System.Collections.ArrayList
        foreach ($fl in @($fp.Lines)) { [void]$outLines.Add($fl) }
        [void]$outLines.Add("filter: $($fp.Summary), walked depth=$depth")
      }
      foreach ($ol in $outLines) { Write-Output $ol }
      # Cost self-report on STDERR, so --no-actions keeps stdout byte-identical to
      # the pre-2.4.0 output (the disabled marker still prints, on the diagnostic
      # stream where cost accounting belongs).
      if ($aOff) {
        [Console]::Error.WriteLine('actions-probed=0 (disabled)')
      } else {
        $tag = 'allowlist'; if ($aAll) { $tag = 'all' }
        [Console]::Error.WriteLine('actions-probed=' + $ctx.Probed + ' of ' + $ctx.Nodes + ' nodes (' + $tag + ') elapsed=' + [int]$ctx.ProbeMs + 'ms')
      }
}

# v4.4.0 (A-15): uia-path - the case body, verbatim
function Invoke-Handler-uia-path([string]$Cmd, [string[]]$Rest) {
      # v2.4.0: READ-ONLY resolver for the path handles uia-tree prints. Shares the
      # walk and the refusal shapes with the @path action routes, so a path that
      # fails here fails there for the SAME reason.
      if ($Rest.Count -lt 2) { throw 'usage: uia-path <sel> @/0/2/1 [maxDepth]' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      $maxD = if ($Rest.Count -ge 3 -and $Rest[2]) { [int]$Rest[2] } else { 0 }
      $rr = Uia-Roots $w
      if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
      $res = Resolve-UiaPath $rr.Roots $Rest[1] $maxD
      if (-not $res.Ok) {
        Write-Output (Format-UiaPathRefusal $Rest[1] $res $null $null)
        throw "uia-path: path refused ($($res.Reason))"
      }
      $toks = Get-UiaActionTokens $res.El
      Uia-Line $res.El 0 $res.Path $toks
}

# v4.4.0 (A-15): uia-find - the case body, verbatim
function Invoke-Handler-uia-find([string]$Cmd, [string[]]$Rest) {
      if ($Rest.Count -lt 2) { throw 'usage: uia-find <sel> <nameSub> [typeRe]' }
      # An empty nameSub makes the pattern '**', which matches EVERY element: measured
      # 2026-09-30 as hits=149 for an empty needle, i.e. a "found" that proves nothing and
      # quietly turns a broken caller into a green one. Refuse before touching any window.
      if ("$($Rest[1])".Trim().Length -lt 1) { throw 'uia-find: <nameSub> must not be empty - an empty substring matches every element, so a hit would prove nothing' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      $typeRe = if ($Rest.Count -ge 3) { $Rest[2] } else { '' }
      # v2.1.0 (plan doc 1.2): the walk is handed to Search-UiaTree as a delegate so a cold
      # first contact can be re-measured once before it becomes a verdict. The 400 ms
      # patience lives HERE (it is a production timing), not in the rule - that is what
      # keeps the rule an offline unit test with both directions pinned.
      # v4.2.0 (feedback item 5): the bound is spelled OUT here instead of living in
      # Uia-WalkAll's default, and it travels with the walk so the echo can print the
      # depth that actually ran - "uia-find found nothing" and "uia-find walked nothing"
      # used to be the same line.
      $uDepth = 0
      $uwf = {
        param($contact)
        if ($contact -gt 1) { Start-Sleep -Milliseconds 400 }
        $rr = Uia-Roots $w
        if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
        $els = @(Uia-WalkAll $rr.Roots $uDepth)
        return @{ Elements = $els; Scanned = @($els).Count; Walked = @($els).Count; Depth = [int]$uDepth; Roots = @($rr.Roots).Count; Via = $rr.Via }
      }
      $uFloor = Get-UiaReprobeFloor
      $us = Search-UiaTree $uwf $Rest[1] $typeRe $uFloor
      foreach ($el in @($us.Hits)) { Uia-Line $el 0 }
      "scanned $($us.Scanned) elements in $($us.Roots) root(s) via=$($us.Via), walk-depth=$(Format-UiaWalkDepth ([int](Get-OptValue $us 'Depth'))), hits=$( @($us.Hits).Count) - walks=$($us.Walks) reprobe-floor=$uFloor cold-zero-reprobe=$($us.Reprobe)"
      if (@($us.Hits).Count -eq 0) {
        # Zero is never evidence of absence (the standing rule of this project), and after
        # a re-contact it is not a cold-start artifact either - say which, and hand the
        # caller the OCR road instead of letting them fall back to eyeballing a screenshot.
        "NOTE: $($us.Reason). UIA exposes no element whose Name contains this text - that is NOT proof it is not on screen: it may be painted without a control, sit in a web document the tree has not lit, or live in a Value/HelpText instead of a Name. Next road: find-text <sel> <text> (or 'find', which tries UIA and OCR and reports which one answered)."
      }
}

# v4.4.0 (A-15): uia-click - body verbatim from the case, plus the flag the G-17 ruling allows
function Invoke-Handler-uia-click([string]$Cmd, [string[]]$Rest, [ref]$SkipTail) {
      # v2.4.0 path-handle form routed to Invoke-UiaClickByPath: the @ prefix is
      # the ONLY routing mark, so without it the historical nameSub route below
      # runs with unchanged semantics.
      if ($Rest.Count -ge 2 -and "$($Rest[1])".StartsWith('@')) { Invoke-UiaClickByPath $Rest; $SkipTail.Value = $true; return }
      if ($Rest.Count -lt 2) { throw 'usage: uia-click <sel> <nameSub>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      $rr = Uia-Roots $w
      if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
      $el = Uia-Find $rr.Roots $Rest[1] 'Button|MenuItem|ListItem|TabItem|Hyperlink|Text|Edit|ComboBox|CheckBox|RadioButton'
      if (-not $el) { throw "no clickable element matching: $($Rest[1])" }
      # v3.0.1 (audit #7): this route used to carry its OWN copy of the click tail, which
      # is how the same missing-rectangle bug lived in two places. Both routes now run
      # through Invoke-UiaClickable, so both refuse the same way.
      Invoke-UiaClickable $el
}

# v4.4.0 (A-15): uia-focus - body verbatim from the case, plus the flag the G-17 ruling allows
function Invoke-Handler-uia-focus([string]$Cmd, [string[]]$Rest, [ref]$SkipTail) {
      # v2.4.0 path-handle form: same @-prefix routing as uia-click.
      if ($Rest.Count -ge 2 -and "$($Rest[1])".StartsWith('@')) { Invoke-UiaFocusByPath $Rest; $SkipTail.Value = $true; return }
      if ($Rest.Count -lt 2) { throw 'usage: uia-focus <sel> <nameSub>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      $rr = Uia-Roots $w
      if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
      $el = Uia-Find $rr.Roots $Rest[1] ''
      if (-not $el) { throw "no element matching: $($Rest[1])" }
      $el.SetFocus()
      "focused element: $($Rest[1])"
}

# v4.4.0 (A-15): uia-settext - body verbatim from the case, plus the flag the G-17 ruling allows
function Invoke-Handler-uia-settext([string]$Cmd, [string[]]$Rest, [ref]$SkipTail) {
      # uia-settext <sel> <nameSub> <file> - ValuePattern.SetValue with the UTF-8
      # content of <file>; no keyboard, no clipboard. Readback-verified.
      # v2.4.0 path-handle form: uia-settext <sel> @/0/2/1 <file> "Type|nameSub|X,Y,WxH".
      if ($Rest.Count -ge 2 -and "$($Rest[1])".StartsWith('@')) { Invoke-UiaSettextByPath $Rest $Cmd; $SkipTail.Value = $true; return }
      if ($Rest.Count -lt 3) { throw 'usage: uia-settext <sel> <nameSub> <file>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "no window matching: $($Rest[0])" }
      if (-not (Test-Path -LiteralPath $Rest[2] -PathType Leaf)) { throw "file not found: $($Rest[2])" }
      # v1.5.2 WP-5: same strict UTF-8 gate as paste (audit R-11) - a GBK/ANSI
      # file must not be written into a real control as mojibake.
      $text = (Read-SendFileUtf8 $Rest[2]).Text
      $rr = Uia-Roots $w
      if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
      # Element pick: pass 1 = name match with a settable ValuePattern (edit
      # boxes often carry their current value as Name, so pass 2 also looks
      # for a settable descendant inside any name-matched container, e.g. the
      # "filename:" label/host pane of a save dialog).
      # v3.0.1 (audit #1): both tests below shipped as `Test-NameSubstring  ` with NO
      # arguments from the commit that introduced them (0e90ca5, v2.0.0). PowerShell
      # binds the missing parameters to $null, the helper answers $false for a null
      # name, and the nameSub route therefore always fell through to
      # "no element matching" - the @path form was the only working uia-settext.
      $all = Uia-WalkAll $rr.Roots
      $el = $null
      $named = $null   # first element whose Name matches, even if not settable
      foreach ($cand in $all) {
        $cn = ''
        try { $cn = $cand.Current.Name } catch { }
        if ((Test-NameSubstring $cn $Rest[1])) {
          if ($null -eq $named) { $named = $cand }
          if ($null -ne (Uia-SettableValue $cand)) { $el = $cand; break }
        }
      }
      if (-not $el) {
        foreach ($cand in $all) {
          $cn = ''
          try { $cn = $cand.Current.Name } catch { }
          if ((Test-NameSubstring $cn $Rest[1])) {
            foreach ($d in (Uia-WalkAll @($cand))) {
              if ($null -ne (Uia-SettableValue $d)) { $el = $d; break }
            }
            if ($el) { break }
          }
        }
      }
      if (-not $el) {
        if ($null -ne $named) {
          $nn = ''
          try { $nn = $named.Current.Name } catch { }
          throw "element '$nn' matched but exposes no settable ValuePattern; fall back to: click the field then paste <file>"
        }
        throw "no element matching: $($Rest[1])"
      }
      $nm = ''
      try { $nm = $el.Current.Name } catch { }
      Log-Action $Rest "pid=$($w.Pid) title='$($w.Title)' element='$nm' file=$($Rest[2])" $Cmd
      $via = ''
      $vp = Uia-SettableValue $el
      if ($null -ne $vp) {
        $vp.SetValue($text)
        $via = 'ValuePattern'
      } else {
        # TextPattern is checked for diagnostics only - it exposes no setter.
        $tp = $null
        try { $tp = $el.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern) } catch { }
        if ($null -ne $tp) {
          throw "element '$nm' exposes TextPattern but no settable ValuePattern; fall back to: click the field then paste <file>"
        }
        throw "element '$nm' exposes no settable text pattern; fall back to: click the field then paste <file>"
      }
      $back = $null
      try { $back = $el.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value } catch { }
      if ($null -eq $back) { try { $back = $el.Current.Name } catch { } }
      if ($back -ne $text) { throw "uia-settext readback mismatch on element '$nm' (wrote $($text.Length) chars)" }
      "set text via $via on element '$nm': wrote $($text.Length) chars, readback match=True"
}

# ---------------------------------------------------------------------------
# CU-OPS package E (v4.6.0): UIA semantic state and semantic actions.
# The read side answers "what does this control expose RIGHT NOW" - one line per
# pattern, and a pattern that is absent says so instead of being omitted. The act
# side acts ONLY through the pattern it names and verifies the state afterwards;
# a missing pattern, a read-only range, a stale element or an out-of-bounds value
# is a refusal that changed nothing, never a fallback click.
# ---------------------------------------------------------------------------
function Get-UiaPatternOrNull($el, $pattern) {
  try { return $el.GetCurrentPattern($pattern) } catch { return $null }
}

function Get-UiaElementLabel($el) {
  $nm = ''
  try { $nm = $el.Current.Name } catch { }
  if ("$nm".Length -eq 0) { $nm = '(unnamed)' }
  $ct = ''
  try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { }
  return ($ct + " '" + $nm + "'")
}

function Get-UiaToggleState($el) {
  $tp = Get-UiaPatternOrNull $el ([System.Windows.Automation.TogglePattern]::Pattern)
  if ($null -eq $tp) { return $null }
  return [string]$tp.Current.ToggleState
}

function Get-UiaRangeInfo($el) {
  $rp = Get-UiaPatternOrNull $el ([System.Windows.Automation.RangeValuePattern]::Pattern)
  if ($null -eq $rp) { return $null }
  $ci = $rp.Current
  return @{ Value = $ci.Value; Min = $ci.Minimum; Max = $ci.Maximum; ReadOnly = [bool]$ci.IsReadOnly }
}

function Format-UiaStateLines($el, [bool]$withText) {
  $lines = New-Object System.Collections.ArrayList
  $ct = ''
  try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { }
  $nm = ''
  try { $nm = $el.Current.Name } catch { }
  $en = $null; $off = $null; $pw = $null
  try { $en = [bool]$el.Current.IsEnabled } catch { }
  try { $off = [bool]$el.Current.IsOffscreen } catch { }
  try { $pw = [bool]$el.Current.IsPassword } catch { }
  $ident = ''
  try { $ident = [string]$el.Current.AutomationId } catch { }
  [void]$lines.Add("element: $ct  name='" + $nm + "'  automationId='" + $ident + "'")
  [void]$lines.Add("enabled=" + $(if ($null -eq $en) { 'unknown' } else { $en.ToString().ToLower() }) + "  offscreen=" + $(if ($null -eq $off) { 'unknown' } else { $off.ToString().ToLower() }) + "  password=" + $(if ($null -eq $pw) { 'unknown' } else { $pw.ToString().ToLower() }))
  $tg = Get-UiaToggleState $el
  if ($null -eq $tg) { [void]$lines.Add('toggle: no TogglePattern') } else { [void]$lines.Add('toggle: ' + $tg) }
  $si = Get-UiaPatternOrNull $el ([System.Windows.Automation.SelectionItemPattern]::Pattern)
  if ($null -eq $si) { [void]$lines.Add('selection: no SelectionItemPattern') } else { [void]$lines.Add('selection: isSelected=' + ([bool]$si.Current.IsSelected).ToString().ToLower()) }
  $ec = Get-UiaPatternOrNull $el ([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
  if ($null -eq $ec) { [void]$lines.Add('expand: no ExpandCollapsePattern') } else { [void]$lines.Add('expand: ' + [string]$ec.Current.ExpandCollapseState) }
  $rg = Get-UiaRangeInfo $el
  if ($null -eq $rg) { [void]$lines.Add('range: no RangeValuePattern') } else {
    [void]$lines.Add('range: value=' + $rg.Value + ' min=' + $rg.Min + ' max=' + $rg.Max + ' readonly=' + $rg.ReadOnly.ToString().ToLower())
  }
  $vp = Get-UiaPatternOrNull $el ([System.Windows.Automation.ValuePattern]::Pattern)
  if ($null -eq $vp) { [void]$lines.Add('value: no ValuePattern') } else {
    $ro = $null
    try { $ro = [bool]$vp.Current.IsReadOnly } catch { }
    if ($pw) {
      [void]$lines.Add('value: (password field - value not read)  writable=' + $(if ($null -eq $ro) { 'unknown' } else { (-not $ro).ToString().ToLower() }))
    } else {
      $val = ''
      try { $val = [string]$vp.Current.Value } catch { }
      [void]$lines.Add('value: ' + $val.Length + ' chars  writable=' + $(if ($null -eq $ro) { 'unknown' } else { (-not $ro).ToString().ToLower() }) + $(if ($withText) { "  text='" + $val + "'" } else { '  (pass --text to print it)' }))
    }
  }
  $tx = Get-UiaPatternOrNull $el ([System.Windows.Automation.TextPattern]::Pattern)
  if ($null -eq $tx) { [void]$lines.Add('text: no TextPattern') } else {
    $snippet = ''
    $total = 0
    try {
      $snippet = [string]$tx.DocumentRange.GetText(200)
      $total = ([string]$tx.DocumentRange.GetText(-1)).Length
    } catch { $snippet = '' }
    if ($pw) { [void]$lines.Add('text: (password field - text not read)') }
    else { [void]$lines.Add('text: ' + $total + ' chars' + $(if ($withText) { "  text='" + [regex]::Replace($snippet, '\s+', ' ') + "'" } else { '  (pass --text to print it)' })) }
  }
  $sc = Get-UiaPatternOrNull $el ([System.Windows.Automation.ScrollItemPattern]::Pattern)
  [void]$lines.Add('scrollItem: ' + $(if ($null -eq $sc) { 'no ScrollItemPattern' } else { 'ScrollItemPattern' }))
  return @($lines)
}

function Invoke-Handler-uia-state([string]$Cmd, [string[]]$Rest) {
      $own = Strip-OwnFlags $Rest 'uia-state'
      $p = $own.Rest
      if (@($p).Count -lt 2) { throw 'usage: uia-state <sel> <nameSub> [--text]' }
      $w = Resolve-Window $p[0]
      if (-not $w) { throw (Format-WindowMissMessage $p[0]) }
      $rr = Uia-Roots $w
      if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid) - this target exposes no UIA tree" }
      $el = Uia-Find $rr.Roots $p[1] ''
      if (-not $el) { throw "no element matching: $($p[1]) - re-read with uia-tree / uia-find; nothing was changed" }
      $withText = [bool]$own.Values['--text']
      if ($script:Json) {
        $tg = Get-UiaToggleState $el
        $rg = Get-UiaRangeInfo $el
        $si = Get-UiaPatternOrNull $el ([System.Windows.Automation.SelectionItemPattern]::Pattern)
        $ec = Get-UiaPatternOrNull $el ([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
        $vp = Get-UiaPatternOrNull $el ([System.Windows.Automation.ValuePattern]::Pattern)
        $nm = ''; try { $nm = [string]$el.Current.Name } catch { }
        $ct = ''; try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { }
        $pw = $null; try { $pw = [bool]$el.Current.IsPassword } catch { }
        [pscustomobject]@{
          pid = $w.Pid; title = $w.Title; type = $ct; name = $nm; password = $pw
          toggle = $tg
          selected = $(if ($null -eq $si) { $null } else { [bool]$si.Current.IsSelected })
          expand = $(if ($null -eq $ec) { $null } else { [string]$ec.Current.ExpandCollapseState })
          range = $rg
          value = $(if ($null -eq $vp -or $pw) { $null } elseif ($withText) { [string]$vp.Current.Value } else { $null })
        } | ConvertTo-Json -Compress -Depth 4
      } else {
        "target: pid=$($w.Pid) title='$($w.Title)'"
        Format-UiaStateLines $el $withText
      }
}

function Invoke-Handler-uia-do([string]$Cmd, [string[]]$Rest) {
      $own = Strip-OwnFlags $Rest 'uia-do'
      $p = @($own.Rest)
      if ($p.Count -lt 3) { throw 'usage: uia-do <toggle|toggle-on|toggle-off|select|add-select|remove-select|expand|collapse|scroll-into-view|range-set> <sel> <nameSub> [value]' }
      $action = [string]$p[0]
      $known = @('toggle', 'toggle-on', 'toggle-off', 'select', 'add-select', 'remove-select', 'expand', 'collapse', 'scroll-into-view', 'range-set')
      if ($action -notin $known) { throw ("uia-do: unknown action '" + $action + "' - known: " + ($known -join ', ') + "; nothing was changed") }
      if ($action -eq 'range-set' -and $p.Count -lt 4) { throw 'usage: uia-do range-set <sel> <nameSub> <value>' }
      if ($action -ne 'range-set' -and $p.Count -gt 3) { throw ("uia-do " + $action + ": takes exactly <sel> <nameSub>, got extra argument '" + $p[3] + "'; nothing was changed") }
      $w = Resolve-Window $p[1]
      if (-not $w) { throw (Format-WindowMissMessage $p[1]) }
      $rr = Uia-Roots $w
      if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid) - this target exposes no UIA tree" }
      $el = Uia-Find $rr.Roots $p[2] ''
      if (-not $el) { throw "no element matching: $($p[2]) - re-read with uia-tree / uia-find; nothing was changed" }
      $label = Get-UiaElementLabel $el
      # CU-OPS package E (v4.6.1): a disabled element keeps its patterns, so the old code could
      # call Toggle/Select on a greyed-out control and report a provider no-op as a success.
      # Refuse BEFORE any pattern call: disabled is its own answer, not a missing-pattern error.
      $enabledNow = $null
      try { $enabledNow = [bool]$el.Current.IsEnabled } catch { }
      if ($enabledNow -eq $false) { throw ("uia-do " + $action + ": " + $label + " is disabled (enabled=false) - nothing was changed; enable it first or pick another control") }
      $echo = ''
      # Every branch acts once, then reads the state back; a failed read-back is an
      # error, not a success story.
      if ($action -in @('toggle', 'toggle-on', 'toggle-off')) {
        $tp = Get-UiaPatternOrNull $el ([System.Windows.Automation.TogglePattern]::Pattern)
        if ($null -eq $tp) { throw ("uia-do " + $action + ": " + $label + " exposes no TogglePattern - nothing was changed; the control is not a toggle") }
        $before = [string]$tp.Current.ToggleState
        if ($action -eq 'toggle-on' -and $before -eq 'On') { $echo = 'already On (no toggle sent)' }
        elseif ($action -eq 'toggle-off' -and $before -eq 'Off') { $echo = 'already Off (no toggle sent)' }
        else {
          $tp.Toggle()
          $after = [string]$tp.Current.ToggleState
          if ($action -eq 'toggle') { $echo = 'toggled ' + $before + ' -> ' + $after }
          elseif ($action -eq 'toggle-on') {
            if ($after -ne 'On') { throw ("uia-do toggle-on: " + $label + " reports " + $after + " after Toggle (an indeterminate toggle may need two calls)") }
            $echo = 'toggled ' + $before + ' -> On'
          } else {
            if ($after -ne 'Off') { throw ("uia-do toggle-off: " + $label + " reports " + $after + " after Toggle (an indeterminate toggle may need two calls)") }
            $echo = 'toggled ' + $before + ' -> Off'
          }
        }
      } elseif ($action -eq 'select') {
        $si = Get-UiaPatternOrNull $el ([System.Windows.Automation.SelectionItemPattern]::Pattern)
        if ($null -eq $si) { throw ("uia-do select: " + $label + " exposes no SelectionItemPattern - nothing was changed") }
        if ([bool]$si.Current.IsSelected) { $echo = 'already selected (no select sent)' }
        else {
          $si.Select()
          if (-not [bool]$si.Current.IsSelected) { throw ("uia-do select: " + $label + " still reports isSelected=false after Select") }
          $echo = 'selected (readback isSelected=true)'
        }
      } elseif ($action -in @('add-select', 'remove-select')) {
        # Multi-select needs its OWN pattern calls: Select() on a second item in a Multiple-mode
        # list replaces the selection, so "select the second item too" cannot be expressed with it.
        $si = Get-UiaPatternOrNull $el ([System.Windows.Automation.SelectionItemPattern]::Pattern)
        if ($null -eq $si) { throw ("uia-do " + $action + ": " + $label + " exposes no SelectionItemPattern - nothing was changed") }
        $wasSel = [bool]$si.Current.IsSelected
        if ($action -eq 'add-select') {
          if ($wasSel) { $echo = 'already selected (nothing sent)' }
          else {
            $si.AddToSelection()
            if (-not [bool]$si.Current.IsSelected) { throw ("uia-do add-select: " + $label + " still reports isSelected=false after AddToSelection") }
            $echo = 'added to selection (readback isSelected=true)'
          }
        } else {
          if (-not $wasSel) { $echo = 'already not selected (nothing sent)' }
          else {
            $si.RemoveFromSelection()
            if ([bool]$si.Current.IsSelected) { throw ("uia-do remove-select: " + $label + " still reports isSelected=true after RemoveFromSelection") }
            $echo = 'removed from selection (readback isSelected=false)'
          }
        }
      } elseif ($action -in @('expand', 'collapse')) {
        $ec = Get-UiaPatternOrNull $el ([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
        if ($null -eq $ec) { throw ("uia-do " + $action + ": " + $label + " exposes no ExpandCollapsePattern - nothing was changed") }
        $want = if ($action -eq 'expand') { 'Expanded' } else { 'Collapsed' }
        $before = [string]$ec.Current.ExpandCollapseState
        if ($before -eq $want) { $echo = 'already ' + $want + ' (nothing sent)' }
        else {
          if ($action -eq 'expand') { $ec.Expand() } else { $ec.Collapse() }
          $after = [string]$ec.Current.ExpandCollapseState
          if ($after -ne $want) { throw ("uia-do " + $action + ": " + $label + " reports " + $after + " after the call") }
          # v4.6.1: spell the past tense explicitly. The old 'expand' + 'd' shape printed
          # "expandd" in the receipt (measured 13:02 on the WPF combo).
          $echo = $(if ($action -eq 'expand') { 'expanded' } else { 'collapsed' }) + ' ' + $before + ' -> ' + $after
        }
      } elseif ($action -eq 'scroll-into-view') {
        $sc = Get-UiaPatternOrNull $el ([System.Windows.Automation.ScrollItemPattern]::Pattern)
        if ($null -eq $sc) { throw ("uia-do scroll-into-view: " + $label + " exposes no ScrollItemPattern - nothing was changed") }
        # v4.6.1: the old echo said "no state to read back". IsOffscreen IS that state, so the
        # scroll is now proven rather than asserted: a provider that accepts ScrollIntoView and
        # leaves the item off screen is an error, not a success.
        $offBefore = $null
        try { $offBefore = [bool]$el.Current.IsOffscreen } catch { }
        if ($null -eq $offBefore) { throw ("uia-do scroll-into-view: " + $label + " would not report IsOffscreen - the scroll cannot be verified; nothing was changed") }
        if (-not $offBefore) {
          $echo = 'already on screen (offscreen=false, no scroll sent)'
        } else {
          $sc.ScrollIntoView()
          $offAfter = $null
          try { $offAfter = [bool]$el.Current.IsOffscreen } catch { }
          if ($null -eq $offAfter) { throw ("uia-do scroll-into-view: " + $label + " would not report IsOffscreen after ScrollIntoView - the scroll is unverified") }
          if ($offAfter) { throw ("uia-do scroll-into-view: " + $label + " still reports offscreen=true after ScrollIntoView (the provider accepted the call but did not bring it on screen)") }
          $echo = 'scrolled into view (offscreen: true -> false, read back)'
        }
      } else {
        # range-set
        $rp = Get-UiaPatternOrNull $el ([System.Windows.Automation.RangeValuePattern]::Pattern)
        if ($null -eq $rp) { throw ("uia-do range-set: " + $label + " exposes no RangeValuePattern - nothing was changed") }
        if ([bool]$rp.Current.IsReadOnly) { throw ("uia-do range-set: " + $label + " reports IsReadOnly=true - nothing was changed") }
        $val = 0.0
        if (-not [double]::TryParse([string]$p[3], [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$val)) {
          throw ("uia-do range-set: '" + $p[3] + "' is not a number; nothing was changed")
        }
        $mn = [double]$rp.Current.Minimum; $mx = [double]$rp.Current.Maximum
        if ($val -lt $mn -or $val -gt $mx) { throw ("uia-do range-set: " + $val + " is outside the control's range " + $mn + ".." + $mx + " - nothing was changed (no clamping)") }
        $rp.SetValue($val)
        $after = [double]$rp.Current.Value
        if ([math]::Abs($after - $val) -gt 0.000001) { throw ("uia-do range-set: readback " + $after + " != requested " + $val + " for " + $label) }
        $echo = 'range value ' + $after + ' (range ' + $mn + '..' + $mx + ', readback match=True)'
      }
      Log-Action @($p) "pid=$($w.Pid) title='$($w.Title)' element=$label action=$action" $Cmd
      "uia-do $action on $label`: $echo"
}


# v4.4.0 (A-15): type - the case body, verbatim
function Invoke-Handler-type([string]$Cmd, [string[]]$Rest) {
      # type [--to <sel>] <text...> [--verify] [--guard-text <s>|--guard-region x,y,w,h=s] [--force]
      # v1.3.0: chars go out via SendInput KEYEVENTF_UNICODE - they bypass the
      # IME entirely (no candidate window) and work for CJK as well as ASCII.
      # The payload is literal (no SendKeys escaping); control combos still
      # belong to `keys`. --verify OCR-reads the target window afterwards.
      $p = Split-Target $Rest
      if ($p.Words.Count -lt 1) { throw 'usage: type [--to <sel>] <text...> [--verify] [--guard-text <s>|--guard-region x,y,w,h=s] [--force]' }
      $text = ($p.Words -join ' ')
      $target = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle
      Emit-ResolveNote
      Invoke-ContentGuard $target $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
      Log-Action (Get-RedactedLogArgs $Rest $p.Words $p.LogPayload) "pid=$($target.Pid) title='$($target.Title)'" $Cmd
      $err = [DT]::SendUnicodeText($text)
      if ($err) { throw "type: $err" }
      Start-Sleep -Milliseconds 300
      $ver = ''
      if ($p.Verify) { $ver = Invoke-TypedVerify $target $text $p.VerifyTimeout }
      $warn = Test-PostSendForeground $target $p.Force
      "typed $($text.Length) chars (unicode SendInput, IME bypassed), target pid=$($target.Pid) title='$($target.Title)'  (foreground after send: $(Get-ForegroundInfo))$ver"
      Invoke-ActionExpectation $p $target 'typed'
      if ($warn) { Write-Output $warn; if ($warn -notlike 'NOTICE*') { exit 1 } }
}

# v4.4.0 (A-15): type-in - the case body, verbatim
function Invoke-Handler-type-in([string]$Cmd, [string[]]$Rest) {
      # type-in <x> <y> [--tab <n>] <text...> [--verify]
      # Compound command for webview/Electron forms where a click only produces
      # a selection state and never gives the input element keyboard focus:
      # click the spot -> optionally send <n> TABs to move focus to the real
      # input -> type. Text goes via SendInput Unicode (IME bypassed); the TABs
      # stay SendKeys because they are keys, not characters. For CJK payloads
      # this now works directly - no clipboard detour needed.
      # v1.5.7 (J-06): --tab comes from the flag table (range-checked, default 0, and it can
      # no longer be fed a flag as its value). The payload/verify parsing below stays here
      # because type-in never calls Split-Target - see Get-CommandSharedMap.
      $own = Strip-OwnFlags $Rest 'type-in'
      $ti = @($own.Rest)
      if ($ti.Count -lt 3) { throw 'usage: type-in <x> <y> [--tab <n>] <text...> [--verify] [--verify-timeout <sec>] [--log-payload]  (a literal -- payload goes through --needle)' }
      $x = [int]$ti[0]; $y = [int]$ti[1]
      $words = @($ti[2..($ti.Count - 1)])
      $tabs = [int]$own.Values['--tab']
      $verify = $false
      $logPayload = $false
      # v1.5.3: --verify-timeout is honoured here too (same default 4s as type)
      $vTimeout = 4
      $out = New-Object System.Collections.ArrayList
      $wi = 0
      while ($wi -lt $words.Count) {
        $t = "$($words[$wi])"
        if ($t -eq '--verify') { $verify = $true }
        elseif ($t -eq '--log-payload') { $logPayload = $true }
        elseif ($t -eq '--verify-timeout') {
          $wi++
          if ($wi -ge $words.Count) { throw 'type-in: --verify-timeout needs seconds (e.g. --verify-timeout 8)' }
          if ("$($words[$wi])" -notmatch '^[0-9]+(\.[0-9]+)?$') { throw "type-in: --verify-timeout needs a number of seconds, got: $($words[$wi])" }
          $vTimeout = Read-FlagNumber '--verify-timeout' $words[$wi] $false '(seconds)'
          if ($vTimeout -lt 0.5) { throw "type-in: --verify-timeout must be >= 0.5 seconds (the check polls every 400ms), got: $vTimeout" }
        }
        elseif ($t -eq '--needle') {
          # v1.5.3: the same escape route the rest of the grammar offers. Without
          # it, adding the unknown-flag throw below would make a literal '--xxx'
          # payload impossible to type through type-in (it used to fall through
          # into the text untouched, which is also why a mistyped flag name could
          # be typed into a real window).
          $wi++
          if ($wi -ge $words.Count) { throw 'type-in: --needle needs a value' }
          [void]$out.Add("$($words[$wi])")
        }
        elseif ($t -like '--*') { throw (Get-UnknownFlagMessage 'type-in' $t) }
        else { [void]$out.Add($t) }
        $wi++
      }
      $words = @($out)
      if ($words.Count -lt 1) { throw 'usage: type-in <x> <y> [--tab <n>] <text...> [--verify] [--verify-timeout <sec>] [--log-payload]' }
      $text = ($words -join ' ')
      Log-Action (Get-RedactedLogArgs $Rest $words $logPayload) "click=$x,$y tabs=$tabs" $Cmd
      Move-Click $x $y 'left'
      $before = Get-ForegroundInfo
      for ($t = 0; $t -lt $tabs; $t++) {
        [System.Windows.Forms.SendKeys]::SendWait('{TAB}')
        Start-Sleep -Milliseconds 120
      }
      $err = [DT]::SendUnicodeText($text)
      if ($err) { throw "type-in: $err" }
      Start-Sleep -Milliseconds 300
      $ver = ''
      if ($verify) {
        $fgH = [DT]::GetForegroundWindow()
        $fgw = @(Get-WinList | Where-Object { $_.Handle -eq $fgH })[0]
        $ver = Invoke-TypedVerify $fgw $text $vTimeout
      }
      "type-in: clicked ($x,$y), tabs=$tabs, typed $($text.Length) chars (unicode SendInput)  (fg before: $before; fg after: $(Get-ForegroundInfo))$ver"
}

# v4.4.0 (A-15): keys - the case body, verbatim
function Invoke-Handler-keys([string]$Cmd, [string[]]$Rest) {
      # keys [--to <sel>] <spec> [--guard-text <s>|--guard-region x,y,w,h=s] [--force]
      $p = Split-Target $Rest
      if ($p.Words.Count -lt 1) { throw 'usage: keys [--to <sel>] <spec> [--guard-text <s>|--guard-region x,y,w,h=s] [--force]' }
      $spec = $p.Words[0]
      $target = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle
      Emit-ResolveNote
      Invoke-ContentGuard $target $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
      Log-Action (Get-RedactedLogArgs $Rest @($spec) $p.LogPayload) "pid=$($target.Pid) title='$($target.Title)'" $Cmd
      [System.Windows.Forms.SendKeys]::SendWait($spec)
      Start-Sleep -Milliseconds 300
      $warn = Test-PostSendForeground $target $p.Force
      "sent keys '$spec', target pid=$($target.Pid) title='$($target.Title)'  (foreground after send: $(Get-ForegroundInfo))"
      Invoke-ActionExpectation $p $target 'sent keys'
      if ($warn) { Write-Output $warn; if ($warn -notlike 'NOTICE*') { exit 1 } }
}

# CU-OPS-COMPLETE-20261026-01 (package C): native key gestures.
#
# keys keeps SendKeys verbatim - its '^v'/'%{F4}' syntax is not reinterpreted here, because
# silently changing what an existing spec means is exactly the break this package was told
# to avoid. The native entry point is a NEW command with its own grammar:
#
#   key ctrl+shift+t        press ctrl, press shift, tap t, release shift, release ctrl
#   key f5 --repeat 3       tap F5 three times
#   key enter --hold 800    hold Enter for 800 ms, then release (one bounded hold)
#
# Every press is released inside this call. SendInput reports how many events it inserted,
# and it does not reset an already-down key, so a key someone else holds is refused instead
# of being pressed or released by us. The Windows key is accepted for real shortcuts but a
# small list of session-wide sequences (lock, show desktop, Run dialog, ...) is refused:
# this tool will not lock the owner's screen or rearrange their desktop to prove a green.
$script:KeyVk = @{
  'enter' = @{ Vk = 0x0D; Ext = $false }; 'return' = @{ Vk = 0x0D; Ext = $false }
  'tab' = @{ Vk = 0x09; Ext = $false }; 'esc' = @{ Vk = 0x1B; Ext = $true }; 'escape' = @{ Vk = 0x1B; Ext = $true }
  'space' = @{ Vk = 0x20; Ext = $false }; 'backspace' = @{ Vk = 0x08; Ext = $false }; 'bs' = @{ Vk = 0x08; Ext = $false }
  'delete' = @{ Vk = 0x2E; Ext = $true }; 'del' = @{ Vk = 0x2E; Ext = $true }
  'insert' = @{ Vk = 0x2D; Ext = $true }; 'ins' = @{ Vk = 0x2D; Ext = $true }
  'home' = @{ Vk = 0x24; Ext = $true }; 'end' = @{ Vk = 0x23; Ext = $true }
  'pageup' = @{ Vk = 0x21; Ext = $true }; 'pgup' = @{ Vk = 0x21; Ext = $true }
  'pagedown' = @{ Vk = 0x22; Ext = $true }; 'pgdn' = @{ Vk = 0x22; Ext = $true }
  'left' = @{ Vk = 0x25; Ext = $true }; 'up' = @{ Vk = 0x26; Ext = $true }
  'right' = @{ Vk = 0x27; Ext = $true }; 'down' = @{ Vk = 0x28; Ext = $true }
  'capslock' = @{ Vk = 0x14; Ext = $false }; 'numlock' = @{ Vk = 0x90; Ext = $true }; 'scrolllock' = @{ Vk = 0x91; Ext = $false }
  'printscreen' = @{ Vk = 0x2C; Ext = $true }; 'prtsc' = @{ Vk = 0x2C; Ext = $true }
  'pause' = @{ Vk = 0x13; Ext = $false }; 'apps' = @{ Vk = 0x5D; Ext = $true }
  'minus' = @{ Vk = 0xBD; Ext = $false }; 'equal' = @{ Vk = 0xBB; Ext = $false }
  'comma' = @{ Vk = 0xBC; Ext = $false }; 'period' = @{ Vk = 0xBE; Ext = $false }
  'slash' = @{ Vk = 0xBF; Ext = $false }; 'semicolon' = @{ Vk = 0xBA; Ext = $false }
  'quote' = @{ Vk = 0xDE; Ext = $false }; 'backslash' = @{ Vk = 0xDC; Ext = $false }
  'grave' = @{ Vk = 0xC0; Ext = $false }
  'add' = @{ Vk = 0x6B; Ext = $false }; 'subtract' = @{ Vk = 0x6D; Ext = $false }
  'multiply' = @{ Vk = 0x6A; Ext = $false }; 'divide' = @{ Vk = 0x6F; Ext = $true }
  'decimal' = @{ Vk = 0x6E; Ext = $false }
}

# Pure: one key name -> @{ Vk; Ext }. Letters, digits and F1-F24 are derived, not listed.
function Resolve-KeyName([string]$name) {
  $n = ("$name").Trim().ToLowerInvariant()
  if (-not $n) { throw 'key: empty key name' }
  if ($n.Length -eq 1) {
    $c = [int][char]$n
    if ($n -cmatch '^[a-z]$') { return @{ Vk = 0x41 + ($c - [int][char]'a'); Ext = $false } }
    if ($n -match '^[0-9]$') { return @{ Vk = 0x30 + ($c - [int][char]'0'); Ext = $false } }
  }
  if ($n -match '^f([0-9]{1,2})$') {
    $num = [int]$Matches[1]
    if ($num -lt 1 -or $num -gt 24) { throw "key: '$name' is out of range - F1..F24 only" }
    return @{ Vk = 0x70 + ($num - 1); Ext = $false }
  }
  if ($n -match '^numpad([0-9])$') { return @{ Vk = 0x60 + [int]$Matches[1]; Ext = $false } }
  if ($script:KeyVk.ContainsKey($n)) { return $script:KeyVk[$n] }
  throw "key: unknown key name '$name' - accepted: a-z, 0-9, F1..F24, numpad0..9, enter, tab, esc, space, backspace, delete, insert, home, end, pageup, pagedown, left, up, right, down, capslock, numlock, scrolllock, printscreen, pause, apps, and the punctuation names in 'desktop.ps1 help key'; no key was sent"
}

# Pure: 'ctrl+shift+t' -> @{ Mods = @('ctrl','shift'); Key = 't'; Spec = ... }. Refuses the
# session-wide sequences and any repeat of one modifier, before any input exists.
function Resolve-KeyCombo([string]$combo) {
  $parts = @(("$combo").Trim() -split '\+')
  if ($parts.Count -eq 0 -or -not $parts[$parts.Count - 1]) { throw "key: '$combo' has no base key - write e.g. ctrl+shift+t" }
  $base = $parts[$parts.Count - 1]
  $mods = @()
  for ($i = 0; $i -lt $parts.Count - 1; $i++) {
    $m = $parts[$i].Trim().ToLowerInvariant()
    if ($m -eq 'control') { $m = 'ctrl' }
    if ($m -eq 'windows') { $m = 'win' }
    if ($m -notin @('ctrl', 'shift', 'alt', 'win')) { throw "key: unknown modifier '$($parts[$i])' in '$combo' - accepted: ctrl, shift, alt, win" }
    if ($mods -contains $m) { throw "key: modifier '$m' appears twice in '$combo'" }
    $mods += $m
  }
  $baseInfo = Resolve-KeyName $base
  $bn = $base.Trim().ToLowerInvariant()
  if (($mods -contains 'ctrl') -and ($mods -contains 'alt') -and ($mods -contains 'delete' -or $bn -eq 'delete' -or $bn -eq 'del')) {
    throw "key: Ctrl+Alt+Del is the Secure Attention Sequence - it is handled by the OS/security desktop and cannot be synthesised by SendInput; this tool refuses instead of pretending it can"
  }
  if ($mods -contains 'win') {
    if ($bn -in @('l', 'd', 'u', 'r', 'q', 'w', 'tab', 'esc', 'escape', 'f4')) {
      throw "key: Win+$bn acts on the whole session (lock / desktop / utility / Run / task view), not on a window; this tool will not prove a capability by locking or rearranging the owner's desktop. Ctrl/Shift/Alt are the supported gesture modifiers"
    }
  }
  return @{ Mods = $mods; Key = $bn; Base = $baseInfo; Spec = $combo }
}

# Observed physical state, read-only. GetAsyncKeyState is the same read the mouse family uses.
function Get-InputStateLine {
  $names = @(
    @{ N = 'ctrl'; Vk = 0x11 }, @{ N = 'shift'; Vk = 0x10 }, @{ N = 'alt'; Vk = 0x12 }, @{ N = 'win'; Vk = 0x5B },
    @{ N = 'capslock'; Vk = 0x14 }, @{ N = 'numlock'; Vk = 0x90 }, @{ N = 'scrolllock'; Vk = 0x91 }
  )
  $down = @()
  foreach ($k in $names) { if (([DT]::IsVkDown([int]$k.Vk)) -ne 0) { $down += $k.N } }
  $btn = @()
  foreach ($b in @('left', 'right', 'middle', 'back', 'forward')) {
    try { if (Get-MouseButtonDown $b) { $btn += $b } } catch { }
  }
  return ("down=" + $(if ($down.Count) { $down -join '+' } else { 'none' }) + " buttons=" + $(if ($btn.Count) { $btn -join '+' } else { 'none' }))
}

# The ownership ledger: written while THIS tool has a key down, removed when THAT KEY is
# released. A hard-killed process cannot run its finally block, so the file is what lets a
# later call distinguish "this tool may still be holding X" from "someone else is holding X".
# Nothing is released on a guess: key-release only touches keys named here.
#
# CU-OPS-ADJ-04/05 (v4.6.1): one flat record PER KEY with its own vk/ext/owner/state, so a
# modifier (ctrl/shift/alt/win) can be written and read back without going through
# Resolve-KeyName (which only knows base keys), and so clearing one released key cannot
# erase another key's recovery record. Legacy name-list entries are still read.
#
# CU-OPS-FINAL-REVIEW-20261027-01 / R-01 (v4.6.2): the record now separates three states -
# 'prepared' (intent written, DOWN NOT confirmed), 'down' (SendInput confirmed the DOWN) and
# 'unknown' (a UP was attempted and failed). Only 'down' is ownership. Recording the intent
# as if the key were held was how a key that was never pressed became releasable, and a
# later physically-held Shift could then be sent an UP by key-release. Every read-modify-
# write now runs inside ONE named mutex with a bounded wait and replaces the file atomically,
# and a corrupt/denied/unreadable ledger is REPORTED instead of being re-read as empty and
# overwritten (the old path silently erased recovery records).
function Get-KeyLedgerPath {
  $dir = Join-Path $env:TEMP 'agent-computer-use'
  return (Join-Path $dir 'key-held.json')
}

# Per-machine mutex: two different tool processes contend on the same object. A session-local
# fallback is kept for hosts that refuse a Global name; it still serializes this session.
function Get-KeyLedgerMutex {
  try { return (New-Object System.Threading.Mutex($false, 'Global\AgentComputerUse-KeyLedger-v2')) } catch { }
  return (New-Object System.Threading.Mutex($false, 'Local\AgentComputerUse-KeyLedger-v2'))
}

# One bounded critical section around the whole read-modify-write. Lock expiry is an ERROR,
# never a silent skip: a write that did not happen must not be reported as one that did.
function Invoke-KeyLedgerLocked([scriptblock]$Body, [int]$TimeoutMs = 5000) {
  $m = Get-KeyLedgerMutex
  $held = $false
  try {
    try { $held = $m.WaitOne($TimeoutMs, $false) } catch [System.Threading.AbandonedMutexException] { $held = $true }
    if (-not $held) { throw "key ledger: another call held the ownership ledger for ${TimeoutMs}ms - this call wrote nothing" }
    return (& $Body)
  } finally {
    if ($held) { try { [void]$m.ReleaseMutex() } catch { } }
    try { $m.Dispose() } catch { }
  }
}

# The identity of THIS process: pid AND creation time. A pid alone is reused by the OS, so a
# recovered record whose recorded creation time differs from the live process belongs to an
# owner that has EXITED - it is not the same writer coming back.
function Get-KeyLedgerOwnerIdentity {
  $st = 'unknown'
  try { $st = [System.Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().ToString('o') } catch { $st = 'unknown' }
  return @{ pid = [int]$PID; started_at = $st }
}

# Modifier names resolve here; everything else is a base key.
function Resolve-LedgerKey([string]$name) {
  switch (("$name").Trim().ToLowerInvariant()) {
    'ctrl' { return @{ Vk = 0x11; Ext = $false } }
    'control' { return @{ Vk = 0x11; Ext = $false } }
    'shift' { return @{ Vk = 0x10; Ext = $false } }
    'alt' { return @{ Vk = 0x12; Ext = $false } }
    'win' { return @{ Vk = 0x5B; Ext = $true } }
    'windows' { return @{ Vk = 0x5B; Ext = $true } }
  }
  return (Resolve-KeyName $name)
}

# Normalized entry: @{ pid; name; vk; ext; state; owner_started; combo; at }. Legacy name-list
# entries are expanded to one record per key with state 'down' and no creation stamp.
function Read-KeyLedgerState {
  $p = Get-KeyLedgerPath
  if (-not (Test-Path -LiteralPath $p)) { return @{ Status = 'absent'; Entries = @(); Error = ''; Path = $p } }
  $raw = ''
  try { $raw = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
  catch { return @{ Status = 'denied'; Entries = @(); Error = $_.Exception.Message; Path = $p } }
  if ("$raw".Trim() -eq '') { return @{ Status = 'corrupt'; Entries = @(); Error = 'the file holds 0 bytes of JSON'; Path = $p } }
  $obj = $null
  try { $obj = $raw | ConvertFrom-Json -ErrorAction Stop } catch { return @{ Status = 'corrupt'; Entries = @(); Error = $_.Exception.Message; Path = $p } }
  if ($null -eq $obj) { return @{ Status = 'corrupt'; Entries = @(); Error = 'the JSON parsed to $null'; Path = $p } }
  $ver = 1
  if ($obj.PSObject.Properties['schema']) { try { $ver = [int]$obj.schema } catch { $ver = -1 } }
  if ($ver -ne 1) { return @{ Status = 'unknown-version'; Entries = @(); Error = "schema=$ver, this tool reads schema 1 (and legacy records with no schema field)"; Path = $p } }
  $rawEntries = @()
  if ($obj.PSObject.Properties['entries']) { $rawEntries = @($obj.entries) }
  $out = @()
  foreach ($e in $rawEntries) {
    if ($null -eq $e) { continue }
    $nm = ''
    if ($e.PSObject.Properties['name']) { $nm = [string]$e.name }
    if ($nm -ne '') {
      $stv = 'down'
      if ($e.PSObject.Properties['state'] -and "$($e.state)" -ne '') { $stv = [string]$e.state }
      $ost = ''
      if ($e.PSObject.Properties['owner_started']) { $ost = [string]$e.owner_started }
      $out += @{
        pid = [int]$e.pid; name = $nm; vk = [int]$e.vk
        ext = $(if ($e.PSObject.Properties['ext']) { [bool]$e.ext } else { $false })
        state = $stv; owner_started = $ost
        combo = $(if ($e.PSObject.Properties['combo']) { [string]$e.combo } else { '' })
        at = $(if ($e.PSObject.Properties['at']) { [string]$e.at } else { '' })
      }
      continue
    }
    if ($e.PSObject.Properties['keys']) {
      foreach ($k in @($e.keys)) {
        $info = $null
        try { $info = Resolve-LedgerKey ([string]$k) } catch { $info = $null }
        $out += @{
          pid = [int]$e.pid; name = [string]$k
          vk = $(if ($info) { [int]$info.Vk } else { 0 }); ext = $(if ($info) { [bool]$info.Ext } else { $false })
          state = 'down'; owner_started = ''; combo = [string]$e.combo; at = [string]$e.at
        }
      }
    }
  }
  return @{ Status = 'ok'; Entries = $out; Error = ''; Path = $p }
}

# The old contract for callers that only want the entries. A record that cannot be read is
# an ERROR now, not an empty list - "cannot see it" must never be reported as "nothing held".
function Read-KeyLedger {
  $st = Read-KeyLedgerState
  if ($st.Status -eq 'absent') { return @() }
  if ($st.Status -ne 'ok') {
    throw "key ledger: $($st.Status) at $($st.Path) ($($st.Error)) - this tool cannot tell which keys it owns and will not treat that as 'nothing held'. Inspect or remove that file deliberately."
  }
  return @($st.Entries)
}

# Same-directory temp file + atomic replace, so a reader never sees half a JSON document.
function Write-KeyLedgerAtomic($entries) {
  $p = Get-KeyLedgerPath
  $dir = Split-Path -Parent $p
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $owner = Get-KeyLedgerOwnerIdentity
  $rec = [ordered]@{ schema = 1; written_at = (Get-Date).ToString('o'); pid = $owner.pid; owner_started = $owner.started_at; entries = @($entries) }
  $json = ConvertTo-Json -InputObject $rec -Depth 6 -Compress
  $tmp = "$p.tmp-$PID"
  [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
  if (Test-Path -LiteralPath $p) {
    try { [System.IO.File]::Replace($tmp, $p, $null) } catch { Move-Item -LiteralPath $tmp -Destination $p -Force }
  } else { Move-Item -LiteralPath $tmp -Destination $p -Force }
}

function Clear-KeyLedger {
  $p = Get-KeyLedgerPath
  if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
}

# Upsert ONE key's record for this owner. Bounded lock, atomic replace, and a corrupt or
# unreadable ledger is refused instead of being overwritten. Throws on any write failure, so
# a caller can never mistake a failed registration for a successful one.
function Set-KeyLedgerState([string]$name, [int]$vk, [bool]$ext, [string]$state, [string]$combo) {
  $owner = Get-KeyLedgerOwnerIdentity
  Invoke-KeyLedgerLocked {
    $st = Read-KeyLedgerState
    if ($st.Status -notin @('absent', 'ok')) { throw "key ledger: cannot record '$name' - the ledger is $($st.Status) at $($st.Path) ($($st.Error)); no record was written" }
    $keep = @(@($st.Entries) | Where-Object { -not (([string]$_.name -eq $name) -and ([int]$_.pid -eq $owner.pid) -and ([string]$_.owner_started -eq $owner.started_at)) })
    $keep += @{ pid = $owner.pid; name = $name; vk = $vk; ext = $ext; state = $state; owner_started = $owner.started_at; combo = $combo; at = (Get-Date).ToString('o') }
    Write-KeyLedgerAtomic $keep
  } | Out-Null
}

# Remove ONLY the records for one key owned by one writer (pid + creation time); other keys
# and other owners survive - a recovery must never erase another call's record.
function Remove-KeyLedgerRecords([string]$name, [int]$ownerPid = 0, [string]$ownerStarted = '') {
  $owner = Get-KeyLedgerOwnerIdentity
  $usePid = $(if ($ownerPid -gt 0) { $ownerPid } else { $owner.pid })
  $useStart = $(if ($ownerStarted -ne '') { $ownerStarted } else { $owner.started_at })
  Invoke-KeyLedgerLocked {
    $st = Read-KeyLedgerState
    if ($st.Status -eq 'absent') { return }
    if ($st.Status -ne 'ok') { throw "key ledger: cannot clear '$name' - the ledger is $($st.Status) at $($st.Path) ($($st.Error)); nothing was changed" }
    $keep = @(@($st.Entries) | Where-Object { -not (([string]$_.name -eq $name) -and ([int]$_.pid -eq $usePid) -and ([string]$_.owner_started -eq $useStart)) })
    if ($keep.Count -eq 0) { Clear-KeyLedger } else { Write-KeyLedgerAtomic $keep }
  } | Out-Null
}

# Who wrote this record, judged from the pid AND the creation time it recorded. 'owner-dead'
# covers both "not running" and "the pid was reused"; 'unknown-owner' means liveness could
# not be read (or the record predates the creation stamp) and ownership cannot be proven.
function Get-KeyLedgerOwnerVerdict($e) {
  $opid = [int]$e.pid
  $rec = [string]$e.owner_started
  if ($opid -le 0) { return @{ Kind = 'unknown-owner'; Detail = 'no pid recorded' } }
  # A record naming THIS pid is only 'self-live' when its recorded creation time is the one
  # this process actually has. The OS reuses pids, so a record left by a killed predecessor
  # that happened to carry the same number must not be adopted as this call's own key.
  if ($opid -eq $PID) {
    $self = Get-KeyLedgerOwnerIdentity
    if ($rec -eq '' -or $rec -eq 'unknown' -or $self.started_at -eq 'unknown') {
      return @{ Kind = 'unknown-owner'; Detail = "record names this pid but holds no comparable creation time (record '$rec', now '$($self.started_at)')" }
    }
    if ($rec -eq $self.started_at) { return @{ Kind = 'self-live'; Detail = 'this process' } }
    return @{ Kind = 'owner-dead'; Detail = "pid=$opid was reused: recorded $rec, this process started $($self.started_at)" }
  }
  $pr = $null
  try { $pr = [System.Diagnostics.Process]::GetProcessById($opid) }
  catch [System.ArgumentException] { return @{ Kind = 'owner-dead'; Detail = "pid=$opid is not running" } }
  catch { return @{ Kind = 'unknown-owner'; Detail = "pid=$opid liveness unreadable ($($_.Exception.Message))" } }
  $nowStart = ''
  try { $nowStart = $pr.StartTime.ToUniversalTime().ToString('o') } catch { return @{ Kind = 'unknown-owner'; Detail = "pid=$opid creation time unreadable" } }
  if ($rec -eq '' -or $rec -eq 'unknown') { return @{ Kind = 'unknown-owner'; Detail = "record has no creation time; pid=$opid now started $nowStart, so it cannot be shown to be the writer" } }
  if ($rec -eq $nowStart) { return @{ Kind = 'other-live'; Detail = "pid=$opid is running with the recorded creation time - a live call still owns it" } }
  return @{ Kind = 'owner-dead'; Detail = "pid=$opid was reused: recorded $rec, now $nowStart" }
}

# The case body of `key`. Runs parse -> refuse -> one owned gesture -> receipt.
function Invoke-Handler-key([string]$Cmd, [string[]]$Rest) {
  $own = Strip-OwnFlags $Rest 'key'
  $p = Split-Target @($own.Rest) 'key'
  if ($p.Words.Count -lt 1) { throw 'usage: key [--to <sel>] <combo> [--repeat n] [--interval ms] [--hold ms] [--guard-text <s>] [--expect <needle>] [--force]   e.g. key ctrl+shift+t / key f5 --repeat 3 / key enter --hold 800' }
  $combo = Resolve-KeyCombo $p.Words[0]
  # bounds are the promise the echo makes; they are checked before any input exists
  $repeat = [int]$own.Values['--repeat']; if ($repeat -lt 1 -or $repeat -gt 50) { throw "key: --repeat must be 1..50 (got $repeat); no key was sent" }
  $interval = [int]$own.Values['--interval']; if ($interval -lt 0 -or $interval -gt 5000) { throw "key: --interval must be 0..5000 ms (got $interval); no key was sent" }
  $hold = [int]$own.Values['--hold']; if ($hold -lt 0 -or $hold -gt 20000) { throw "key: --hold must be 0..20000 ms (got $hold); no key was sent" }
  $target = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle
  Emit-ResolveNote
  Invoke-ContentGuard $target $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
  $vks = @()
  foreach ($m in $combo.Mods) {
    $vk = switch ($m) { 'ctrl' { 0x11 } 'shift' { 0x10 } 'alt' { 0x12 } 'win' { 0x5B } }
    if (([DT]::IsVkDown([int]$vk)) -ne 0) {
      throw "key: modifier '$m' is already held down (not by this call); this tool will not press or release a key it does not own - let go of it first. Observed: $(Get-InputStateLine); no key was sent"
    }
    $vks += @{ Name = $m; Vk = [int]$vk; Ext = ($m -eq 'win') }
  }
  if (([DT]::IsVkDown([int]$combo.Base.Vk)) -ne 0) {
    throw "key: '$($combo.Key)' is already held down (not by this call); refusing to press or release it. Observed: $(Get-InputStateLine); no key was sent"
  }
  Log-Action (Get-RedactedLogArgs $Rest @() $p.LogPayload) "pid=$($target.Pid) title='$($target.Title)' combo=$($combo.Spec) repeat=$repeat hold=${hold}ms interval=${interval}ms" $Cmd
  $pressed = @()
  $baseDown = $false
  $inserted = 0
  $fail = ''
  $releaseFail = @()
  # R-01 phase 1: PREPARE. The intent is on record before any input exists, so a crash
  # between SendInput and its acknowledgement still leaves a trace - but as 'prepared',
  # which is a CLUE, not ownership. key-release reports it and refuses to release it.
  foreach ($v in $vks) { Set-KeyLedgerState $v.Name ([int]$v.Vk) ([bool]$v.Ext) 'prepared' $combo.Spec }
  Set-KeyLedgerState $combo.Key ([int]$combo.Base.Vk) ([bool]$combo.Base.Ext) 'prepared' $combo.Spec
  try {
    foreach ($v in $vks) {
      $n = [uint32][DT]::SendKeyInput([int]$v.Vk, $false, [bool]$v.Ext)
      if ($n -ne 1) {
        # DOWN did not happen: drop the clue and never add this key to the releasable set.
        try { Remove-KeyLedgerRecords $v.Name } catch { }
        throw "key: modifier '$($v.Name)' DOWN: SendInput inserted $n of 1; the gesture did not run"
      }
      # R-01 phase 2: CONFIRMED DOWN. Only this acknowledgement makes the key ours.
      $pressed += $v
      $inserted++
      try { Set-KeyLedgerState $v.Name ([int]$v.Vk) ([bool]$v.Ext) 'down' $combo.Spec }
      catch { throw "key: modifier '$($v.Name)' DOWN succeeded but its ownership record could not be written ($($_.Exception.Message)); releasing it now" }
      Start-Sleep -Milliseconds 30
    }
    for ($r = 1; $r -le $repeat; $r++) {
      $n = [uint32][DT]::SendKeyInput([int]$combo.Base.Vk, $false, [bool]$combo.Base.Ext)
      if ($n -ne 1) {
        try { Remove-KeyLedgerRecords $combo.Key } catch { }
        throw "key: '$($combo.Key)' DOWN (repeat $r of $repeat): SendInput inserted $n of 1"
      }
      $baseDown = $true
      $inserted++
      try { Set-KeyLedgerState $combo.Key ([int]$combo.Base.Vk) ([bool]$combo.Base.Ext) 'down' $combo.Spec }
      catch { throw "key: '$($combo.Key)' DOWN succeeded but its ownership record could not be written ($($_.Exception.Message)); the key is still down" }
      Start-Sleep -Milliseconds $hold
      $n = [uint32][DT]::SendKeyInput([int]$combo.Base.Vk, $true, [bool]$combo.Base.Ext)
      if ($n -ne 1) {
        # The UP was attempted and failed: the physical state is now unknown. The record is
        # kept and stamped 'unknown' so recovery can report it instead of guessing.
        try { Set-KeyLedgerState $combo.Key ([int]$combo.Base.Vk) ([bool]$combo.Base.Ext) 'unknown' $combo.Spec } catch { }
        throw "key: '$($combo.Key)' UP (repeat $r of $repeat): SendInput inserted $n of 1 - the key may still be down; its ledger record is kept, run 'key-release'"
      }
      $baseDown = $false
      $inserted++
      try { Remove-KeyLedgerRecords $combo.Key } catch { }
      if ($r -lt $repeat -and $interval -gt 0) { Start-Sleep -Milliseconds $interval }
    }
  } catch {
    $fail = $_.Exception.Message
  } finally {
    $rel = @()
    # Every modifier this call pressed is released and COUNTED, and its UP is verified:
    # a swallowed failed UP used to be receipted as "released" (CU-OPS-ADJ-03/ADJ-04).
    $pos = @($pressed).Count - 1
    while ($pos -ge 0) {
      $v = $pressed[$pos]
      $upOk = $false
      try {
        $n = [uint32][DT]::SendKeyInput([int]$v.Vk, $true, [bool]$v.Ext)
        if ($n -eq 1) { $upOk = $true; $inserted++ } else { $releaseFail += "$($v.Name)(inserted $n/1)" }
      } catch { $releaseFail += "$($v.Name)($($_.Exception.Message))" }
      if ($upOk) {
        $rel += $v.Name
        try { Remove-KeyLedgerRecords $v.Name } catch { }
      } else {
        try { Set-KeyLedgerState $v.Name ([int]$v.Vk) ([bool]$v.Ext) 'unknown' $combo.Spec } catch { }
      }
      $pos--
    }
    # The base key's record is only owed while it is actually down; a failed base UP keeps
    # it so key-release can still recover it (CU-OPS-ADJ-04).
    if (-not $baseDown) { try { Remove-KeyLedgerRecords $combo.Key } catch { } }
    Start-Sleep -Milliseconds 40
    $script:LastKeyReceipt = ("combo=" + $combo.Spec + " mods=" + $(if ($combo.Mods.Count) { $combo.Mods -join '+' } else { 'none' }) + " repeat=$repeat hold=${hold}ms interval=${interval}ms SendInput-inserted=$inserted released=" + $(if ($rel.Count) { $rel -join '+' } else { 'none' }))
  }
  if ($releaseFail.Count -gt 0) {
    $msg = "key: modifier UP failed for: $($releaseFail -join ', ') - those keys may still be down and their ledger records are kept; run 'key-release'"
    if ($fail) { throw ($fail + ' | ' + $msg) }
    throw $msg
  }
  if ($fail) { throw ($fail + " (any key still down is kept in the ownership ledger: run 'key-state' / 'key-release'; observed now: $(Get-InputStateLine))") }
  Start-Sleep -Milliseconds 250
  $warn = Test-PostSendForeground $target $p.Force
  "key $($combo.Spec): target pid=$($target.Pid) title='$($target.Title)'  $($script:LastKeyReceipt)"
  Invoke-ActionExpectation $p $target 'sent key'
  if ($warn) { Write-Output $warn; if ($warn -notlike 'NOTICE*') { exit 1 } }
}

# Read-only: what is down right now, and what (if anything) this tool has on record.
function Invoke-Handler-key-state([string]$Cmd, [string[]]$Rest) {
  $st = Read-KeyLedgerState
  $ledger = @()
  if ($st.Status -eq 'ok') { $ledger = @($st.Entries) }
  $owned = @()
  $clues = @()
  foreach ($e in $ledger) {
    # vk comes from the record itself: modifiers are ledger keys too, and Resolve-KeyName
    # would reject ctrl/shift/alt/win (CU-OPS-ADJ-05).
    $vk = [int]$e.vk
    $isDown = ($vk -ne 0) -and ([DT]::IsVkDown($vk) -ne 0)
    if ([string]$e.state -ne 'down') { $clues += "$($e.name)=$($e.state)$(if ($isDown) { '/down-now' } else { '' })(pid=$($e.pid))"; continue }
    if ($isDown) { $owned += "$($e.name)(pid=$($e.pid))" }
  }
  $ledgerNote = switch ($st.Status) {
    'absent' { 'absent' }
    'ok' { "$(@($ledger).Count) entr(y/ies)" }
    default { "$($st.Status): $($st.Error)" }
  }
  "key-state: $(Get-InputStateLine)  owned-held=$(if ($owned.Count) { $owned -join ',' } else { 'none' })  ledger=$ledgerNote"
  if ($clues.Count) { "  unconfirmed records (state is not 'down' - reported, never released on): $($clues -join ', ')" }
  "note: every key this tool presses is released inside the same call; a 'down' entry can only outlive a killed process. 'key-release' touches only keys the ledger proves this tool pressed."
}

# Releases only keys the ledger proves this tool pressed AND that are still down. Everything
# else is reported, not touched.
function Invoke-Handler-key-release([string]$Cmd, [string[]]$Rest) {
  # The ledger records keys THIS tool pressed and has not released yet. Only those - and only
  # if they are still physically down - are released; anything else is reported, not touched.
  # Release is preview by default: the ledger is the only thing that separates "ours" from
  # "the user is holding this", and a stray release could undo somebody else's chord.
  $own = Strip-OwnFlags $Rest 'key-release'
  if (@($own.Rest).Count -gt 0) { throw "key-release: unexpected argument '$($own.Rest[0])' - it takes no operand, only --go" }
  $go = [bool]$own.Values['--go']
  $st = Read-KeyLedgerState
  if ($st.Status -eq 'absent') {
    "key-release: no ownership ledger exists - this tool has no key on record as held, so there is nothing it may release. Observed: $(Get-InputStateLine)"
    return
  }
  if ($st.Status -ne 'ok') {
    # R-01: an unreadable record is NOT "nothing held". Releasing on it would be a guess and
    # overwriting it would destroy the only recovery clue, so nothing is sent or written.
    throw "key-release: the ownership ledger is $($st.Status) at $($st.Path) ($($st.Error)) - this tool cannot tell which keys it owns, so it released nothing and left the file untouched. Inspect or remove that file deliberately."
  }
  $ledger = @($st.Entries)
  if ($ledger.Count -eq 0) {
    "key-release: the ownership ledger exists and is valid but holds no records - nothing it may release. Observed: $(Get-InputStateLine)"
    return
  }
  $plan = @()
  foreach ($e in $ledger) {
    $vk = [int]$e.vk
    $downNow = ($vk -ne 0) -and (([DT]::IsVkDown($vk)) -ne 0)
    $ov = Get-KeyLedgerOwnerVerdict $e
    $state = [string]$e.state
    $action = ''
    if ($vk -eq 0) { $action = 'REFUSED: unreadable record (no usable vk)' }
    elseif ($state -ne 'down') { $action = "REFUSED: record state '$state' - this tool never confirmed the DOWN, so it will not release it" }
    elseif ($ov.Kind -eq 'other-live') { $action = "REFUSED: $($ov.Detail)" }
    elseif ($ov.Kind -eq 'unknown-owner') { $action = "REFUSED: ownership unprovable - $($ov.Detail)" }
    elseif (-not $downNow) { $action = 'CLEANUP: already up - record removed, no input sent' }
    else { $action = 'WILL RELEASE' }
    $plan += [pscustomobject]@{ Entry = $e; Vk = $vk; Ext = [bool]$e.ext; Action = $action; Owner = $ov.Kind }
  }
  "key-release" + $(if ($go) { '' } else { ' (DRY-RUN: add --go to release; nothing was sent)' }) + ":"
  foreach ($p in $plan) {
    "  $($p.Entry.name) = state=$($p.Entry.state) owner=$($p.Owner)(pid=$($p.Entry.pid)) physical=$(if ($p.Vk -ne 0 -and ([DT]::IsVkDown($p.Vk)) -ne 0) { 'down' } else { 'up' }) -> $($p.Action)"
  }
  if (-not $go) { return }
  $released = @()
  $failed = @()
  $refused = 0
  foreach ($p in $plan) {
    if ($p.Action -like 'REFUSED*') { $refused++; continue }
    if ($p.Action -like 'CLEANUP*') {
      try { Remove-KeyLedgerRecords ([string]$p.Entry.name) ([int]$p.Entry.pid) ([string]$p.Entry.owner_started) } catch { }
      continue
    }
    try {
      $n = [uint32][DT]::SendKeyInput($p.Vk, $true, $p.Ext)
      if ($n -eq 1) {
        $released += [string]$p.Entry.name
        try { Remove-KeyLedgerRecords ([string]$p.Entry.name) ([int]$p.Entry.pid) ([string]$p.Entry.owner_started) } catch { }
      } else { $failed += "$($p.Entry.name)(inserted $n/1)" }
    } catch { $failed += "$($p.Entry.name)($($_.Exception.Message))" }
  }
  "  released=" + $(if ($released.Count) { $released -join '+' } else { 'none' }) + " failed=" + $(if ($failed.Count) { $failed -join ',' } else { 'none' }) + " refused=$refused  observed-after=$(Get-InputStateLine)"
  if ($refused -gt 0) { Write-Output "NOTICE: $refused record(s) were reported but not released - ownership could not be proven. They stay in the ledger for a human decision." }
  if ($failed.Count) { throw "key-release: $($failed.Count) key(s) could not be released: $($failed -join ', ')" }
}

function Invoke-Handler-ime([string]$Cmd, [string[]]$Rest) {
      # ime - read-only: which keyboard layout/IME the FOREGROUND window's
      # thread is using. ime=yes means SendKeys-based `keys` can be swallowed
      # (type no longer cares: it bypasses the IME via SendInput Unicode).
      $f = Get-FgThreadInfo
      "foreground pid=$($f.Pid) title='$($f.Title)'  $(Format-Hkl $f.Hkl)"
}

# v4.4.0 (A-15): paste - the case body, verbatim
function Invoke-Handler-paste([string]$Cmd, [string[]]$Rest) {
      # paste [--to <sel>] <file> [--guard-text <s>|--guard-region x,y,w,h=s] [--force]
      # reads UTF-8, clipboard + Ctrl+V. v1.3.0 note: `type` now handles CJK
      # directly (SendInput Unicode) - paste stays the path for apps that only
      # accept clipboard input or for very long/multiline payloads.
      $p = Split-Target $Rest
      if ($p.Words.Count -lt 1) { throw 'usage: paste [--to <sel>] <file> [--guard-text <s>|--guard-region x,y,w,h=s] [--expect <s>|--expect-gone <s>|--expect-region x,y,w,h=s] [--timeout s] [--interval ms] [--no-expect] [--replace-clipboard] [--force]' }
      $file = $p.Words[0]
      if (-not (Test-Path $file)) { throw "file not found: $file" }
      $target = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle
      Emit-ResolveNote
      # Guard BEFORE touching the clipboard: a failed guard must leave the
      # user's clipboard and the target both untouched.
      Invoke-ContentGuard $target $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
      # v1.5.2 WP-5: strict UTF-8 read - an ANSI/GBK file must error out, not
      # paste garbage into the user's target window. Read BEFORE the clipboard
      # snapshot and the audit line: a rejected file changes nothing at all.
      $readRes = Read-SendFileUtf8 $file
      $text = $readRes.Text
      $bomNote = ''
      if ($readRes.HadBom) { $bomNote = ' [UTF-8 BOM stripped]' }
      $clip = Save-ClipboardState
      # CU-OPS package G: refuse BEFORE the write when the clipboard holds content this
      # tool cannot put back. The user's clipboard is then untouched - the same contract
      # the guard above runs on the target window.
      Assert-ClipboardReplaceable $clip ([bool]$p.ReplaceClipboard) 'paste'
      Log-Action (Get-RedactedLogArgs $Rest @() $p.LogPayload) "pid=$($target.Pid) title='$($target.Title)' file=$file" $Cmd
      # v2.2.0 (plan doc 3): the receipt half is measured BEFORE the send so the comparison is
      # honest, and only when the payload is long enough that a chip fold is possible - a short
      # payload pays nothing and keeps the verbatim-only judgement.
      $rcpBase = Get-PasteReceiptBaseline $p $target $text
      Set-Clipboard -Value $text
      Start-Sleep -Milliseconds 400
      [System.Windows.Forms.SendKeys]::SendWait('^v')
      Start-Sleep -Milliseconds 500
      $restoreNote = Restore-ClipboardState $clip
      $warn = Test-PostSendForeground $target $p.Force
      "pasted $($text.Length) chars from $file$bomNote, target pid=$($target.Pid) title='$($target.Title)'  (foreground after send: $(Get-ForegroundInfo))  [$restoreNote]"
      Invoke-ActionExpectation $p $target 'pasted'
      # v1.5.9 (P-1, default-on per owner ruling): with no expect flag given, prove the
      # payload landed by OCR-reading its tail back from the target; unreadable = WARN
      # + exit 1 (via the throw below, so script steps record a FAIL instead of dying).
      # --no-expect restores the send-only contract; actions.log gets the char count only.
      $auto = Invoke-AutoPasteExpect $p $target (Get-AutoExpectNeedle $text) $rcpBase $text.Length
      if ($auto.Ran) {
        Log-Action @("autoexpect=$($auto.NeedleChars)chars", "readback=$($auto.Criterion)") "target pid=$($target.Pid) verified=$(if ($auto.Ok) { 'yes' } else { 'no' })" $Cmd
        # The knob and the numbers it judged are both spoken - a receipt accepted on a
        # baseline nobody printed is the same unauditable judgement this repo keeps hunting.
        if ($null -ne $rcpBase) {
          Write-Output ('      receipt: fold-threshold=' + (Get-PasteFoldThreshold) + ' payload=' + $text.Length + 'chars baseline(nodes=' + $rcpBase.Nodes + ', h=' + $rcpBase.H + ', lines=' + $rcpBase.Lines + ')')
        }
        Write-Output $auto.Message
        Confirm-AutoExpect $auto
      }
      if ($warn) { Write-Output $warn; if ($warn -notlike 'NOTICE*') { exit 1 } }
      # CU-OPS package G (v4.6.1): the restore note is checked mechanically. The payload
      # went out either way, but a previous clipboard that did not come back must not end
      # with the same exit code as one that did - the user is told, and the code says so.
      $restoreOutcome = Get-ClipboardRestoreOutcome $restoreNote
      if ($restoreOutcome -eq 'partial' -or $restoreOutcome -eq 'failed') {
        throw "paste: the payload WAS sent to pid=$($target.Pid), but the previous clipboard could not be put back fully ($restoreNote). Run 'clip-info' before relying on the clipboard again."
      }
}

# v4.4.0 (A-15): paste-file - the case body, verbatim
function Invoke-Handler-paste-file([string]$Cmd, [string[]]$Rest) {
      # paste-file [--to <sel>] [--image] <path> [--guard-text <s>|--guard-region x,y,w,h=s] [--force]
      # = copy-file + foreground guard + content guard + Ctrl+V, previous
      # clipboard restored. --guard-text/--guard-region are the "am I really
      # talking to the right conversation" check: the file goes out only if the
      # needle is visible in the target window (probed incident: a guard-green
      # window whose active chat had silently switched to a private friend).
      # CU-OPS package G (v4.6.4): --image carries the PNG/BMP PIXELS - the file is decoded
      # and put on the clipboard as an image, not as a path string. The carrier is validated
      # BEFORE the clipboard snapshot, so a bad image path changes nothing at all.
      $useImage = $false
      $rest2 = New-Object System.Collections.ArrayList
      foreach ($a in @($Rest)) {
        if ("$a" -eq '--image') { $useImage = $true } else { [void]$rest2.Add($a) }
      }
      $p = Split-Target @($rest2) 'paste-file'
      if ($p.Words.Count -lt 1) { throw 'usage: paste-file [--to <sel>] [--image] <path> [--guard-text <s>|--guard-region x,y,w,h=s] [--expect <s>|--expect-gone <s>|--expect-region x,y,w,h=s] [--timeout s] [--interval ms] [--no-expect] [--replace-clipboard] [--force]' }
      $srcPath = [string]$p.Words[0]
      $carrier = $null
      if ($useImage) {
        $carrier = Get-ImageCarrier $srcPath
        if (-not [bool]$carrier.Ok) {
          throw ('paste-file: ' + $srcPath + ' is not an image carrier this tool can carry (' + $carrier.Reason + ': ' + $carrier.Detail + '); nothing was sent')
        }
      } elseif (-not (Test-Path -LiteralPath $srcPath -PathType Leaf)) { throw "file not found: $srcPath" }
      $fi = Get-Item -LiteralPath $srcPath
      $target = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle
      Emit-ResolveNote
      Invoke-ContentGuard $target $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
      $clip = Save-ClipboardState
      Assert-ClipboardReplaceable $clip ([bool]$p.ReplaceClipboard) 'paste-file'
      $carrierName = if ($useImage) { 'image' } else { 'file' }
      Log-Action (Get-RedactedLogArgs $Rest @() $p.LogPayload) "pid=$($target.Pid) title='$($target.Title)' file=$($fi.FullName) carrier=$carrierName" $Cmd
      if ($useImage) {
        $ok = Set-ClipboardImageCarrier $carrier
        if (-not $ok) { throw ("paste-file: the image did not come back after the write (size/digest check failed); no paste was sent for: " + $fi.FullName) }
      } else {
        $ok = Set-ClipboardFileDrop $fi.FullName
        if (-not $ok) { throw "clipboard verification failed for: $($fi.FullName)" }
      }
      [System.Windows.Forms.SendKeys]::SendWait('^v')
      Start-Sleep -Milliseconds 500
      $restoreNote = Restore-ClipboardState $clip
      $warn = Test-PostSendForeground $target $p.Force
      if ($useImage) {
        "pasted image $($carrier.Name)  $($carrier.W)x$($carrier.H)  digest=$($carrier.Hash)  carrier=image, target pid=$($target.Pid) title='$($target.Title)'  (foreground after send: $(Get-ForegroundInfo))  [$restoreNote]"
      } else {
        "pasted file $($fi.Name) bytes=$($fi.Length), target pid=$($target.Pid) title='$($target.Title)'  (foreground after send: $(Get-ForegroundInfo))  [$restoreNote]"
      }
      Invoke-ActionExpectation $p $target ($(if ($useImage) { 'pasted image' } else { 'pasted file' }))
      # v1.5.9 (P-1): same default-on readback as paste; the FileDrop's name is the
      # payload handle the target renders, so the needle comes from the file name.
      # CU-OPS package G (v4.6.4): for --image there is nothing textual to read back, and
      # claiming a window effect from a receipt would be exactly the false-green this package
      # exists to kill - so the row says the window was NOT read back instead of faking one.
      if ($useImage) {
        Write-Output '      readback: carrier=image - this tool cannot read pixels back out of a target window; the clipboard digest above proves the PAYLOAD, not the receiving app'
      } else {
        $auto = Invoke-AutoPasteExpect $p $target (Get-AutoExpectNeedle $fi.Name)
        if ($auto.Ran) {
          Log-Action @("autoexpect=$($auto.NeedleChars)chars") "target pid=$($target.Pid) verified=$(if ($auto.Ok) { 'yes' } else { 'no' })" $Cmd
          Write-Output $auto.Message
          Confirm-AutoExpect $auto
        }
      }
      if ($warn) { Write-Output $warn; if ($warn -notlike 'NOTICE*') { exit 1 } }
      # CU-OPS package G (v4.6.1): same mechanical check as paste - the file went out,
      # but a previous clipboard that did not come back is a non-zero exit, not a footnote.
      $restoreOutcome = Get-ClipboardRestoreOutcome $restoreNote
      if ($restoreOutcome -eq 'partial' -or $restoreOutcome -eq 'failed') {
        throw "paste-file: the file WAS sent to pid=$($target.Pid), but the previous clipboard could not be put back fully ($restoreNote). Run 'clip-info' before relying on the clipboard again."
      }
}

# v4.4.0 (A-15): copy-file - the case body, verbatim
function Invoke-Handler-copy-file([string]$Cmd, [string[]]$Rest) {
      # copy-file [--image] [--replace-clipboard] <path>
      # - put a local file on the clipboard as FileDrop (default) or as the IMAGE carrier
      #   (--image: PNG/BMP pixels, not a path), and verify what landed. Deliberately does NOT
      #   restore the previous clipboard: leaving the payload there is the point of this
      #   command (paste / paste-file do restore).
      # - CU-OPS package G (v4.6.4): before ANY write the current clipboard is snapshotted and
      #   the write gate runs. A clipboard holding formats this tool cannot put back is refused
      #   with their names, unless --replace-clipboard says the loss is intended. This is also
      #   what makes the flag meaningful for a command that never restores.
      $useImage = $false
      $replace = $false
      $words = New-Object System.Collections.ArrayList
      foreach ($a in @($Rest)) {
        $s = "$a"
        if ($s -eq '--image') { $useImage = $true; continue }
        if ($s -eq '--replace-clipboard') { $replace = $true; continue }
        [void]$words.Add($s)
      }
      if ($words.Count -lt 1) { throw 'usage: copy-file [--image] [--replace-clipboard] <path> - --image puts the PNG/BMP PIXELS on the clipboard instead of a FileDrop path' }
      if ($words.Count -gt 1) { throw ('copy-file takes exactly one path; extra arguments: ' + (@($words | Select-Object -Skip 1) -join ' ')) }
      $srcPath = [string]$words[0]
      # The payload is validated BEFORE the clipboard is read: a bad image path changes nothing.
      $carrier = $null
      if ($useImage) {
        $carrier = Get-ImageCarrier $srcPath
        if (-not [bool]$carrier.Ok) {
          throw ('copy-file: ' + $srcPath + ' is not an image carrier this tool can carry (' + $carrier.Reason + ': ' + $carrier.Detail + '); nothing was written')
        }
      } elseif (-not (Test-Path -LiteralPath $srcPath -PathType Leaf)) {
        throw "file not found: $srcPath"
      }
      # G: the write gate runs on the SNAPSHOT, before anything is replaced.
      $clip = Save-ClipboardState
      Assert-ClipboardReplaceable $clip $replace 'copy-file'
      $fi = Get-Item -LiteralPath $srcPath
      $carrierName = if ($useImage) { 'image' } else { 'file' }
      Log-Action $Rest "file=$($fi.FullName) bytes=$($fi.Length) carrier=$carrierName" $Cmd
      if ($useImage) {
        $ok = Set-ClipboardImageCarrier $carrier
        if (-not $ok) { throw ('copy-file: the image did not come back after the write (size/digest check failed); the clipboard state is not what the caller asked for: ' + $fi.FullName) }
        ("copied image $($carrier.Name)  $($carrier.W)x$($carrier.H)  digest=$($carrier.Hash)  bytes=$($fi.Length)  carrier=image  clipboard verified (same pixels read back)")
      } else {
        $ok = Set-ClipboardFileDrop $fi.FullName
        if (-not $ok) { throw "clipboard verification failed for: $($fi.FullName)" }
        "copied $($fi.Name)  bytes=$($fi.Length)  carrier=file  clipboard verified: $($fi.FullName)"
      }
}

