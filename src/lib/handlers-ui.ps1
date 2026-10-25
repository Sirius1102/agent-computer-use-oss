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

# v4.4.0 (A-15): ime - the case body, verbatim
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
      if ($p.Words.Count -lt 1) { throw 'usage: paste [--to <sel>] <file> [--guard-text <s>|--guard-region x,y,w,h=s] [--expect <s>|--expect-gone <s>|--expect-region x,y,w,h=s] [--timeout s] [--interval ms] [--no-expect] [--force]' }
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
}

# v4.4.0 (A-15): paste-file - the case body, verbatim
function Invoke-Handler-paste-file([string]$Cmd, [string[]]$Rest) {
      # paste-file [--to <sel>] <path> [--guard-text <s>|--guard-region x,y,w,h=s] [--force]
      # = copy-file + foreground guard + content guard + Ctrl+V, previous
      # clipboard restored. --guard-text/--guard-region are the "am I really
      # talking to the right conversation" check: the file goes out only if the
      # needle is visible in the target window (probed incident: a guard-green
      # window whose active chat had silently switched to a private friend).
      $p = Split-Target $Rest
      if ($p.Words.Count -lt 1) { throw 'usage: paste-file [--to <sel>] <path> [--guard-text <s>|--guard-region x,y,w,h=s] [--expect <s>|--expect-gone <s>|--expect-region x,y,w,h=s] [--timeout s] [--interval ms] [--no-expect] [--force]' }
      if (-not (Test-Path -LiteralPath $p.Words[0] -PathType Leaf)) { throw "file not found: $($p.Words[0])" }
      $fi = Get-Item -LiteralPath $p.Words[0]
      $target = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle
      Emit-ResolveNote
      Invoke-ContentGuard $target $p.GuardText $p.GuardRegion $p.Scale $p.MaxTiles $p.NoTile $p.Occlude $p.AllowOccluded $p.OcclGrid
      $clip = Save-ClipboardState
      Log-Action (Get-RedactedLogArgs $Rest @() $p.LogPayload) "pid=$($target.Pid) title='$($target.Title)' file=$($fi.FullName)" $Cmd
      $ok = Set-ClipboardFileDrop $fi.FullName
      if (-not $ok) { throw "clipboard verification failed for: $($fi.FullName)" }
      [System.Windows.Forms.SendKeys]::SendWait('^v')
      Start-Sleep -Milliseconds 500
      $restoreNote = Restore-ClipboardState $clip
      $warn = Test-PostSendForeground $target $p.Force
      "pasted file $($fi.Name) bytes=$($fi.Length), target pid=$($target.Pid) title='$($target.Title)'  (foreground after send: $(Get-ForegroundInfo))  [$restoreNote]"
      Invoke-ActionExpectation $p $target 'pasted file'
      # v1.5.9 (P-1): same default-on readback as paste; the FileDrop's name is the
      # payload handle the target renders, so the needle comes from the file name.
      $auto = Invoke-AutoPasteExpect $p $target (Get-AutoExpectNeedle $fi.Name)
      if ($auto.Ran) {
        Log-Action @("autoexpect=$($auto.NeedleChars)chars") "target pid=$($target.Pid) verified=$(if ($auto.Ok) { 'yes' } else { 'no' })" $Cmd
        Write-Output $auto.Message
        Confirm-AutoExpect $auto
      }
      if ($warn) { Write-Output $warn; if ($warn -notlike 'NOTICE*') { exit 1 } }
}

# v4.4.0 (A-15): copy-file - the case body, verbatim
function Invoke-Handler-copy-file([string]$Cmd, [string[]]$Rest) {
      # copy-file <path> - put a local file on the clipboard as FileDrop and
      # verify the drop list really contains it. Deliberately does NOT restore
      # the previous clipboard: leaving the file there is the point of this
      # command (paste / paste-file do restore).
      if ($Rest.Count -lt 1) { throw 'usage: copy-file <path>' }
      if (-not (Test-Path -LiteralPath $Rest[0] -PathType Leaf)) { throw "file not found: $($Rest[0])" }
      $fi = Get-Item -LiteralPath $Rest[0]
      Log-Action $Rest "file=$($fi.FullName) bytes=$($fi.Length)" $Cmd
      $ok = Set-ClipboardFileDrop $fi.FullName
      if (-not $ok) { throw "clipboard verification failed for: $($fi.FullName)" }
      "copied $($fi.Name)  bytes=$($fi.Length)  clipboard verified: $($fi.FullName)"
}

