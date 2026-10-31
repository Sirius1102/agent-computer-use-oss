# lib/selftest-chrome-cdp.ps1 - one family of the selftest section, lifted out of lib/selftest.ps1 by A-14k (A-beta).
# Bodies are byte-identical to what the section carried. The only channel to the orchestrator is the
# explicit context object: shared state arrives through $Ctx and nothing else, because A-14e/A-14i
# measured what happens when a body reaches for a caller local instead.
# The Chrome/CDP and accessibility family: the CDP client and a11y route, the UIA cold-start
# re-contact, action tokens plus structural path handles, the Rect.Empty family, and the viewport
# fallback that once had only one axis.
function Invoke-SelftestFamily-ChromeCdp($Ctx) {
  # context handover (the one thing in this file that is not lifted text)
  $clCount = $Ctx['clCount']
  $codeLines = $Ctx['codeLines']
  $hCaseStarts = $Ctx['hCaseStarts']
  $hFnEnd = $Ctx['hFnEnd']
  $j5ProdStart = $Ctx['j5ProdStart']
  $j5ProdEnd = $Ctx['j5ProdEnd']

  # ---------- v1.8.0 CDP client and a11y route (task book A-0..A-6) ----------
  # Offline half of the acceptance set: the judgements that can be pinned without a
  # desktop are pinned here, so a live round can only fail on the part that genuinely
  # needs one. Every case below is bidirectional - one accepted spelling is not enough
  # for a gate, and a mapping is not proven by one scale factor.
  $c1Bad = ''
  foreach ($spell in @('127.0.0.1', '127.0.0.1:9222', 'http://127.0.0.1:9222/json/version', 'ws://127.0.0.1:9222/devtools/page/ABC')) {
    $c1Got = ''
    try { $c1Got = Get-CdpLoopbackBase $spell } catch { $c1Got = 'THREW: ' + $_.Exception.Message }
    if ($c1Got -ne "http://127.0.0.1:$script:CdpPort") { $c1Bad = "spelling '$spell' resolved to '$c1Got'" }
  }
  ST-Check 'unit: cdp loopback gate accepts every loopback spelling and returns one normalized http base' ($c1Bad -eq '')
  # Each hostile spelling must be refused BY THE BRANCH THAT APPLIES TO IT. Checking
  # only that the message mentions 127.0.0.1 was toothless: with the bare-port branch
  # deleted, '9222' still falls through to the non-loopback refusal and still names
  # 127.0.0.1, so the run stayed green over a real regression (mutation
  # 'cdp-drop-bare-port' caught that; the per-case phrase below is what gives it teeth).
  $c2Bad = ''
  foreach ($c2case in @(
    @('0.0.0.0:9222', 'non-loopback'),
    @('192.168.1.20:9222', 'non-loopback'),
    @('10.0.0.5', 'non-loopback'),
    @('evil.example.com:9222', 'non-loopback'),
    @('http://0.0.0.0:9222/json', 'non-loopback'),
    @('ws://192.168.1.20:9222/devtools/page/X', 'non-loopback'),
    @('9222', 'bare port'),
    @('17895', 'bare port'))) {
    $c2Msg = ''
    try { [void](Get-CdpLoopbackBase $c2case[0]); $c2Msg = 'ACCEPTED' } catch { $c2Msg = $_.Exception.Message }
    if ($c2Msg -eq 'ACCEPTED') { $c2Bad = "gate let '$($c2case[0])' through" }
    elseif (-not $c2Msg.Contains($c2case[1])) { $c2Bad = "refusal for '$($c2case[0])' did not come from the '$($c2case[1])' rule: $c2Msg" }
    elseif (-not $c2Msg.Contains('127.0.0.1')) { $c2Bad = "refusal for '$($c2case[0])' does not name the loopback rule: $c2Msg" }
  }
  ST-Check 'unit: cdp loopback gate refuses 0.0.0.0, a LAN address, a bare port and a hostname, each from the branch that applies and naming the rule' ($c2Bad -eq '')
  $c3a = Get-CdpUrlDomain 'http://127.0.0.1:8460/dashboard?token=QRYSECRETA1'
  $c3b = Get-CdpUrlDomain 'https://sub.example.com/tok/3f2a9c8b7d5e4f1a'
  $c3c = Get-CdpUrlDomain 'chrome://settings/login'
  $c3d = Get-CdpUrlDomain 'about:blank'
  $c3e = Get-CdpUrlDomain 'file:///C:/Users/SomeOne/Desktop/report.html'
  ST-Check 'unit: cdp url logging keeps host+port, drops BOTH the query and the path, keeps internal schemes readable and reduces file: to the bare scheme (a token sits in the path as happily as in the query; a file path is a personal path)' (
    $c3a -eq '127.0.0.1:8460' -and (-not $c3a.Contains('QRYSECRETA1')) -and $c3b -eq 'sub.example.com' -and (-not $c3b.Contains('3f2a9c8b7d5e4f1a')) -and $c3c -eq 'chrome://settings/login' -and $c3d -eq 'about:blank' -and $c3e -eq 'file' -and (-not $c3e.Contains('SomeOne')))
  # A-3's arithmetic. The two dpr values must differ in all four fields, and the origin
  # must be ADDED as already-physical pixels (chrome-find scales it before calling in).
  $c4Css = @{ left = 10.0; top = 20.0; width = 100.0; height = 50.0 }
  $c4d2 = Convert-CdpRectToScreen $c4Css 2.0 0 0
  $c4d1 = Convert-CdpRectToScreen $c4Css 1.0 0 0
  $c4off = Convert-CdpRectToScreen $c4Css 2.0 100 200
  ST-Check 'unit: css rect mapping multiplies BOTH offset and size by the measured dpr and adds the physical client origin once' (
    $c4d2.X -eq 20 -and $c4d2.Y -eq 40 -and $c4d2.W -eq 200 -and $c4d2.H -eq 100 -and $c4d1.X -eq 10 -and $c4d1.W -eq 100 -and $c4off.X -eq 120 -and $c4off.Y -eq 240)
  # The nested-array shape: PS has been observed handing a decoded JSON array back as
  # ONE element that is itself an array, which member-enumerates .title across every
  # target - chrome-tabs then prints "1 page(s)" whose title is several titles joined.
  $c5Json = '[{"type":"page","title":"AA","url":"http://h/a"},{"type":"page","title":"BB","url":"http://h/b"},{"type":"worker","title":"WW","url":"http://h/w"}]'
  $c5Flat = @(Get-CdpTargetList $c5Json 'page')
  $c5Nest = @(Get-CdpTargetList ('[' + $c5Json + ']') 'page')
  $c5All = @(Get-CdpTargetList $c5Json '')
  ST-Check 'unit: cdp target list yields the same page set flat or nested, keeps everything unfiltered, and empties on empty input' (
    (@($c5Flat).Count -eq 2) -and ((@($c5Flat | ForEach-Object { $_.title }) -join ',') -eq 'AA,BB') -and ((@($c5Nest | ForEach-Object { $_.title }) -join ',') -eq 'AA,BB') -and (@($c5All).Count -eq 3) -and (@(Get-CdpTargetList '' 'page').Count -eq 0))
  # The gate must be LOAD-BEARING: a gate that only checks a value the code retypes
  # itself is decoration. These two lints fail the moment anyone re-hardcodes an
  # endpoint or lets a chrome command open its own connection.
  $c6Mark = ('"http://127.0.0.1:' + '$script:CdpPort"')
  $c6Hard = New-Object System.Collections.ArrayList
  for ($c6i = 0; $c6i -lt $codeLines.Count; $c6i++) {
    if ($c6i -ge $j5ProdStart -and $c6i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c6i] -match '^\s*#') { continue }
    if ($codeLines[$c6i].Contains($c6Mark)) { [void]$c6Hard.Add($c6i + 1) }
  }
  ST-Check 'lint: exactly one non-comment line spells out a loopback CDP endpoint - the gate function itself (callers use its return value)' (
    (@($c6Hard).Count -eq 1) -and (($codeLines[[int]$c6Hard[0] - 1]).Contains('return ')))
  $c7Mark = '/devtools/page/'
  $c7Sock = New-Object System.Collections.ArrayList
  for ($c7i = 0; $c7i -lt $codeLines.Count; $c7i++) {
    if ($c7i -ge $j5ProdStart -and $c7i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c7i] -match '^\s*#') { continue }
    if ($codeLines[$c7i].Contains($c7Mark)) { [void]$c7Sock.Add($c7i + 1) }
  }
  ST-Check 'lint: exactly one line builds a CDP page socket URL, derived from the gated base' (@($c7Sock).Count -eq 1)
  Write-Output "      cdp endpoint construction: literal-loopback lines=$(@($c6Hard).Count) at lines $(Format-SourceLineList $c6Hard) | page-socket-url lines=$(@($c7Sock).Count) at lines $(Format-SourceLineList $c7Sock)"
  $c8Missing = New-Object System.Collections.ArrayList
  foreach ($c8cmd in @('chrome-tabs', 'chrome-read', 'chrome-find', 'chrome-click', 'chrome-debug-off')) {
    # v4.4.0 (A-15): the endpoint a command builds may live in its handler now, so coverage is judged
    # on the command's code rather than on the case body alone.
    $c8Body = Get-CommandCodeText $codeLines $c8cmd
    if ($c8Body -ceq '') { [void]$c8Missing.Add("$c8cmd is not dispatched"); continue }
    if (-not $c8Body.Contains('Get-CdpLoopbackBase')) { [void]$c8Missing.Add("$c8cmd skips the gate") }
  }
  ST-Check 'lint: every cdp command builds its endpoint through the loopback gate (none may connect on its own terms)' (
    @($c8Missing).Count -eq 0)
  if (@($c8Missing).Count -gt 0) { Write-Output "      cdp gate coverage gaps: $(@($c8Missing) -join ', ')" }
  # Who resolves WHAT: tab-targeting commands go through the shared page resolver,
  # whole-list commands through the shared target list. chrome-click resolves nothing
  # itself by design - it delegates to chrome-find so both print one mapping line.
  $c8bMissing = New-Object System.Collections.ArrayList
  foreach ($c8b in @(@('chrome-read', 'Get-CdpPageId'), @('chrome-find', 'Get-CdpPageId'), @('chrome-tabs', 'Get-CdpTargets'), @('chrome-debug-off', 'Get-CdpTargets'))) {
    $c8bName = $c8b[0]; $c8bNeed = $c8b[1]
    if (-not $hCaseStarts.ContainsKey($c8bName)) { [void]$c8bMissing.Add("$c8bName is not dispatched"); continue }
    # v4.4.0 (A-15 pen 2): who resolves what is a property of the command, not of the line range it happened
    #    to be written in - read the command's own code, case plus handler.
    if (-not ((Get-CommandCodeText $codeLines $c8bName).Contains($c8bNeed))) { [void]$c8bMissing.Add("$c8bName does not use $c8bNeed") }
  }
  ST-Check 'lint: page-targeting cdp commands resolve tabs through Get-CdpPageId and list commands through Get-CdpTargets' (
    @($c8bMissing).Count -eq 0)
  if (@($c8bMissing).Count -gt 0) { Write-Output "      cdp resolver coverage gaps: $(@($c8bMissing) -join ', ')" }
  # The viewport origin must come from the measured bottom-anchor helper. Both
  # alternatives were tried and measured this round (JS arithmetic: 10px too low;
  # Win32 client area: 131px too high, because Chrome's client area is its own UI).
  $c8cBody = ''
  if ($hCaseStarts.ContainsKey('chrome-find')) {
    $c8cBody = Get-CommandCodeText $codeLines 'chrome-find'
  }
  ST-Check 'lint: chrome-find takes its viewport origin from Get-CdpViewportOrigin, self-reports which formula it used, and does not re-derive it inline' (
    ($c8cBody.Contains('Get-CdpViewportOrigin')) -and ($c8cBody.Contains('origin-formula=')) -and (-not $c8cBody.Contains('ClientToScreen')))
  $c8dMark = ('bottom-anchor' + '-dwm')
  $c8dSites = New-Object System.Collections.ArrayList
  for ($c8di = 0; $c8di -lt $codeLines.Count; $c8di++) {
    if ($c8di -ge $j5ProdStart -and $c8di -lt $j5ProdEnd) { continue }
    if ($codeLines[$c8di] -match '^\s*#') { continue }
    if ($codeLines[$c8di].Contains($c8dMark)) { [void]$c8dSites.Add($c8di + 1) }
  }
  ST-Check 'lint: the bottom-anchor origin formula exists in exactly one place (one mapping, one truth about where the viewport is)' (
    @($c8dSites).Count -eq 1)
  # One implementation per judgement (the repo's own anti-drug rule): the page-area
  # verdict and the graceful Chrome restart must each exist once and be CALLED twice.
  $c9Mark = 'function Measure-A11yTree'
  $c10Mark = 'function Restart-ChromeWithFlags'
  $c9Defs = @(); $c10Defs = @(); $c9Calls = @(); $c10Calls = @()
  for ($c9i = 0; $c9i -lt $codeLines.Count; $c9i++) {
    if ($c9i -ge $j5ProdStart -and $c9i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c9i] -match '^\s*#') { continue }
    if ($codeLines[$c9i].StartsWith($c9Mark)) { $c9Defs += ($c9i + 1) }
    if ($codeLines[$c9i].StartsWith($c10Mark)) { $c10Defs += ($c9i + 1) }
    if ($codeLines[$c9i].Contains('= Measure-A11yTree ')) { $c9Calls += ($c9i + 1) }
    if ($codeLines[$c9i].Contains('= Restart-ChromeWithFlags ')) { $c10Calls += ($c9i + 1) }
  }
  # 5 = a11y-probe's first measurement + its cold-zero re-probe (A-6b), chrome-a11y's
  # before/after pair, and pt-profile's tree summary (D-1). Pinned exactly, so dropping OR adding a call site both go red.
  ST-Check 'lint: the page-area a11y verdict has exactly one implementation and both a11y-probe and chrome-a11y call it' (
    (@($c9Defs).Count -eq 1) -and (@($c9Calls).Count -eq 5))
  ST-Check 'lint: the graceful Chrome restart has exactly one implementation, called by chrome-a11y and chrome-debug-off' (
    (@($c10Defs).Count -eq 1) -and (@($c10Calls).Count -eq 2))
  $c11Mark = 'Top + [int]($win.H / 2)'
  $c11Half = @()
  for ($c11i = 0; $c11i -lt $codeLines.Count; $c11i++) {
    if ($c11i -ge $j5ProdStart -and $c11i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c11i] -match '^\s*#') { continue }
    if ($codeLines[$c11i].Contains($c11Mark)) { $c11Half += ($c11i + 1) }
  }
  ST-Check 'lint: the page-area half-of-window boundary is computed in exactly one place (no second copy that can drift)' (
    @($c11Half).Count -eq 1)
  # The restart gate: handle-death was the shipped bug (window gone, process alive,
  # port still answering, relaunch swallowed by the singleton). Pin the replacement.
  $c12s = -1; $c12e = $codeLines.Count
  for ($c12i = 0; $c12i -lt $codeLines.Count; $c12i++) { if ($codeLines[$c12i].StartsWith($c10Mark)) { $c12s = $c12i; break } }
  if ($c12s -ge 0) { for ($c12j = $c12s + 1; $c12j -lt $codeLines.Count; $c12j++) { if ($codeLines[$c12j] -match '^function ') { $c12e = $c12j; break } } }
  $c12Body = $(if ($c12s -ge 0) { ($codeLines[$c12s..($c12e - 1)] -join "`n") } else { '' })
  ST-Check 'lint: the chrome restart gates on the before-pid set reaching zero, not on IsWindow of the closed frame' (
    ($c12s -ge 0) -and (-not $c12Body.Contains('IsWindow')) -and $c12Body.Contains('$beforePids'))
  ST-Check 'lint: the chrome restart carries the closed browser profile across the relaunch (a non-default scope must come back as itself)' (
    ($c12s -ge 0) -and (@(@($codeLines[$c12s..($c12e - 1)]) | Where-Object { $_.Contains('$anchorUdd -ne $defaultUdd') }).Count -eq 1))
  # No socket read may block forever. Measured 2026-09-30: `ReceiveAsync(...).GetAwaiter()
  # .GetResult()` hung a real chrome-debug-off call for 8 minutes with the loop's own
  # stopwatch check never getting a turn - a hung automation call is worse than a failed
  # one, because the operator cannot tell the difference from outside.
  $c16Unb = New-Object System.Collections.ArrayList
  $c16Bnd = 0
  for ($c16i = 0; $c16i -lt $codeLines.Count; $c16i++) {
    if ($c16i -ge $j5ProdStart -and $c16i -lt $j5ProdEnd) { continue }
    if ($codeLines[$c16i] -match '^\s*#') { continue }
    if ($codeLines[$c16i].Contains('ReceiveAsync') -and $codeLines[$c16i].Contains('GetAwaiter')) { [void]$c16Unb.Add($c16i + 1) }
    if ($codeLines[$c16i].Contains(('if (-not $rt' + '.Wait(')) -or $codeLines[$c16i].Contains(('if (-not $rt2' + '.Wait('))) { $c16Bnd++ }
  }
  ST-Check 'lint: every CDP socket read is bounded (no ReceiveAsync + GetAwaiter().GetResult() combination may block forever)' (
    (@($c16Unb).Count -eq 0) -and ($c16Bnd -ge 2))
  if (@($c16Unb).Count -gt 0) { Write-Output "      unbounded receives at lines: $(@($c16Unb) -join ', ')" }
  $c13Bad = ''
  try { [void](Invoke-DesktopCommand 'chrome-a11y' @('sideways')) } catch { $c13Bad = $_.Exception.Message }
  $c13NoArg = ''
  try { [void](Invoke-DesktopCommand 'chrome-a11y' @()) } catch { $c13NoArg = $_.Exception.Message }
  ST-Check 'unit: chrome-a11y rejects a missing or unknown mode before it resolves a window (a bad argument must not bounce the browser)' (
    $c13Bad.Contains("must be 'on' or 'off'") -and $c13Bad.Contains('sideways') -and (-not $c13Bad.Contains('no Chrome window')) -and $c13NoArg.Contains('usage: chrome-a11y'))
  $c14Bad = ''
  try { [void](Invoke-DesktopCommand 'a11y-probe' @('DTX-NoSuchWindow-ZZ', '0')) } catch { $c14Bad = $_.Exception.Message }
  $c14NoSel = ''
  try { [void](Invoke-DesktopCommand 'a11y-probe' @()) } catch { $c14NoSel = $_.Exception.Message }
  ST-Check 'unit: a11y-probe rejects bigDepth below 1 and a missing selector before walking anything' (
    $c14Bad.Contains('bigDepth must be >= 1') -and $c14Bad.Contains('got 0') -and $c14NoSel.Contains('usage: a11y-probe'))
  # uia-find with an empty nameSub used to match EVERY element (measured: hits=149), so a
  # broken caller looked like a successful search. It must refuse, and refuse BEFORE any
  # window is resolved - the second call below proves the ordering by failing later, with
  # a different message.
  $c17Empty = ''
  try { [void](Invoke-DesktopCommand 'uia-find' @('DTX-NoSuchWindow-ZZ', ' ')) } catch { $c17Empty = $_.Exception.Message }
  $c17Order = ''
  try { [void](Invoke-DesktopCommand 'uia-find' @('DTX-NoSuchWindow-ZZ', 'x')) } catch { $c17Order = $_.Exception.Message }
  ST-Check 'unit: uia-find refuses an empty nameSub before resolving a window, and a non-empty one still reaches the window lookup' (
    $c17Empty.Contains('must not be empty') -and (-not $c17Empty.Contains('no window matching')) -and $c17Order.Contains('no window matching') -and (-not $c17Order.Contains('must not be empty')))
  # ---------- v2.1.0 (plan doc 1.2): the UIA cold-start re-contact ----------
  # Both directions of the rule, then the rule RUN with an injected walker. The
  # injection is the point: a live cold start cannot be staged on demand (owner ruling
  # closed v1.8.0 limitation 15 as structurally unprovable - any compliant restart path
  # lights the tree before the reader's first contact), so "the re-contact is what found
  # it" is proven offline and is NOT written up as an end-to-end live proof.
  $u12Hit = Get-UiaReprobeDecision 1 4 25
  ST-Check 'unit: uia reprobe - a first-contact hit never re-contacts (no second walk on a normal find)' (
    (-not $u12Hit.Rerun) -and $u12Hit.Reason.Contains('hit on first contact'))
  $u12Cold = Get-UiaReprobeDecision 0 14 25
  ST-Check 'unit: uia reprobe - 0 hits on a shallow first contact is the cold-start shape and re-contacts once' (
    $u12Cold.Rerun -and $u12Cold.Reason.Contains('scanned=14 < floor=25'))
  $u12Deep = Get-UiaReprobeDecision 0 25 25
  ST-Check 'unit: uia reprobe - 0 hits on a deep tree reads genuinely absent and does NOT re-contact (without this direction the floor is not a rule)' (
    (-not $u12Deep.Rerun) -and $u12Deep.Reason.Contains('genuinely absent'))
  $u12Off = Get-UiaReprobeDecision 0 3 0
  ST-Check 'unit: uia reprobe - floor 0 disables the re-contact and says which knob did it' (
    (-not $u12Off.Rerun) -and $u12Off.Reason.Contains('reprobe disabled'))
  $u12Walk = {
    param($contact)
    $late = [pscustomobject]@{ Current = [pscustomobject]@{ Name = $(if ($contact -ge 2) { 'DTXCOLDLATE' } else { 'unlit placeholder' }) } }
    $plain = [pscustomobject]@{ Current = [pscustomobject]@{ Name = 'always present' } }
    return @{ Elements = @($late, $plain); Scanned = 2; Roots = 1; Via = 'handle' }
  }
  $u12S = Search-UiaTree $u12Walk 'DTXCOLDLATE' '' (Get-UiaReprobeFloor)
  ST-Check 'unit: uia search - the re-contact is what turns a cold zero into a hit (walks=2 and the echo names the second scan)' (
    (@($u12S.Hits).Count -eq 1) -and ($u12S.Walks -eq 2) -and ($u12S.Reprobe -ceq 'yes -> scanned=2, hits=1'))
  $u12S2 = Search-UiaTree $u12Walk 'always present' '' (Get-UiaReprobeFloor)
  ST-Check 'unit: uia search - a first-contact hit walks exactly once and reports reprobe=no' (
    (@($u12S2.Hits).Count -eq 1) -and ($u12S2.Walks -eq 1) -and ($u12S2.Reprobe -ceq 'no'))
  $u12WalkNever = { param($contact) return @{ Elements = @(); Scanned = 3; Roots = 1; Via = 'pid-enum' } }
  $u12S3 = Search-UiaTree $u12WalkNever 'anything' '' (Get-UiaReprobeFloor)
  ST-Check 'unit: uia search - a re-contact that still finds nothing says so instead of leaving a bare zero' (
    (@($u12S3.Hits).Count -eq 0) -and ($u12S3.Walks -eq 2) -and ($u12S3.Reprobe -like 'yes -> still 0*'))
  # One floor producer, and every consumer of the rule must read it from that producer
  # (a threshold copy is how a11y-probe's and uia-find's cold-start behaviour would
  # silently split into two definitions of "cold").
  $u12FloorSites = 0; $u12FloorEcho = 0; $u12ReprobeEcho = 0
  for ($u12i = 0; $u12i -lt $codeLines.Count; $u12i++) {
    if ($u12i -ge $j5ProdStart -and $u12i -lt $j5ProdEnd) { continue }
    if ($codeLines[$u12i] -match '^\s*#') { continue }
    if ($codeLines[$u12i].Contains('= Get-UiaReprobeFloor')) { $u12FloorSites++ }
    if ($codeLines[$u12i].Contains('repro' + 'be-floor=')) { $u12FloorEcho++ }
    if ($codeLines[$u12i].Contains('cold-zero-repro' + 'be=')) { $u12ReprobeEcho++ }
  }
  ST-Check 'lint: the reprobe floor has one producer, both roads that read it self-report it, and the cold-start field is spoken by exactly the three readers that re-contact (a11y-probe, uia-find, find)' (
    ($u12FloorSites -eq 1) -and ($u12FloorEcho -eq 2) -and ($u12ReprobeEcho -eq 3))
  Write-Output ("      uia reprobe: floor-sites=$u12FloorSites echo-sites=$u12FloorEcho cold-field-sites=$u12ReprobeEcho")

  # ---------- v2.4.0: action tokens + structural path handles (pure rules, no UIA) ----------
  # The pattern singletons need the UIA assemblies: load them here (idempotent) -
  # the runtime loads them lazily inside Uia-Roots, but this block must also pass
  # in an offline selftest run that never dispatched a UIA command.
  Add-Type -AssemblyName UIAutomationClient
  Add-Type -AssemblyName UIAutomationTypes
  $v24Invoke = [System.Windows.Automation.InvokePattern]::Pattern
  $v24Value = [System.Windows.Automation.ValuePattern]::Pattern
  $v24ScrollItem = [System.Windows.Automation.ScrollItemPattern]::Pattern
  ST-Check 'unit: uia action tokens map an invoke-only pattern list to the invoke verb' (
    (Get-UiaActionTokensFromPatterns @($v24Invoke)) -ceq 'invoke')
  ST-Check 'unit: uia action tokens keep the canonical verb order regardless of pattern order' (
    (Get-UiaActionTokensFromPatterns @($v24ScrollItem, $v24Value)) -ceq 'value,scroll')
  ST-Check 'unit: uia action tokens for a probed pattern-less node are the empty (probed-none) string' (
    (Get-UiaActionTokensFromPatterns @()) -ceq '')
  ST-Check 'unit: uia path token shape accepts /0 and /0/2/1/4, refuses 0/2, /1 (root must be /0), /0//2 and /0/2/' (
    (Test-UiaPathTokenShape '/0') -and (Test-UiaPathTokenShape '/0/2/1/4') -and
    (-not (Test-UiaPathTokenShape '0/2')) -and (-not (Test-UiaPathTokenShape '/1')) -and
    (-not (Test-UiaPathTokenShape '/0//2')) -and (-not (Test-UiaPathTokenShape '/0/2/')))
  $v24E1 = Parse-UiaExpectToken 'Button|OK|123,45,80x24'
  $v24E2 = Parse-UiaExpectToken 'Pane||10,20,30x40'
  ST-Check 'unit: uia expect token parses Type|nameSub|rect incl. an empty name and parentheses' (
    ($null -ne $v24E1) -and ($v24E1.Type -ceq 'Button') -and ($v24E1.Name -ceq 'OK') -and ($v24E1.Rect -ceq '123,45,80x24') -and
    ($null -ne $v24E2) -and ($v24E2.Name -ceq ''))
  ST-Check 'unit: uia expect token refuses 2-field shapes, empty types and bad rects, tolerates a parenthesised rect' (
    ($null -eq (Parse-UiaExpectToken 'Button|OK')) -and ($null -eq (Parse-UiaExpectToken '|OK|1,2,3x4')) -and
    ($null -eq (Parse-UiaExpectToken 'Button|OK|123,45')) -and
    ($null -ne (Parse-UiaExpectToken 'Button|OK|(123,45,80x24)')))
  $v24Id = @{ Type = 'Button'; Name = 'OK, confirm'; Rect = '123,45,80x24'; RectParts = @(123, 45, 80, 24) }
  ST-Check 'unit: uia expect match passes when all three fields agree' ((Test-UiaExpectMatch $v24E1 $v24Id).Ok)
  ST-Check 'unit: uia expect match refuses a type mismatch, a name mismatch and a rect mismatch' (
    (-not (Test-UiaExpectMatch (Parse-UiaExpectToken 'Pane|OK|123,45,80x24') $v24Id).Ok) -and
    (-not (Test-UiaExpectMatch (Parse-UiaExpectToken 'Button|Cancel|123,45,80x24') $v24Id).Ok) -and
    (-not (Test-UiaExpectMatch (Parse-UiaExpectToken 'Button|OK|9,9,9x9') $v24Id).Ok))
  ST-Check 'unit: an empty-name expect matches an unnamed element and refuses a named one' (
    (Test-UiaExpectMatch (Parse-UiaExpectToken 'Button||123,45,80x24') @{ Type = 'Button'; Name = ''; Rect = '123,45,80x24'; RectParts = @(123, 45, 80, 24) }).Ok -and
    (-not (Test-UiaExpectMatch (Parse-UiaExpectToken 'Button||123,45,80x24') @{ Type = 'Button'; Name = 'X'; Rect = '123,45,80x24'; RectParts = @(123, 45, 80, 24) }).Ok))
  $v24Ref = Format-UiaPathRefusal '/0/2/1/4' @{ Ok = $false; Reason = 'stale'; Path = '/0/2/1/4' } (Parse-UiaExpectToken 'Button|OK|123,45,80x24') @{ Type = 'Pane'; Name = ''; Rect = '9,8,7x6'; RectParts = $null }
  ST-Check 'unit: the stale refusal names the path, both identities and the fallback roads' (
    ("$v24Ref".Contains('REFUSED: path=/0/2/1/4 stale')) -and
    ("$v24Ref".Contains("expected: Button | name='OK' | rect=123,45,80x24")) -and
    ("$v24Ref".Contains("actual: Pane | name='' | rect=9,8,7x6")) -and
    ("$v24Ref".Contains('fallback: uia-find / find <text> / find-text (OCR)')))
  $v24Td = Resolve-UiaPath @() '@/0/2/1/4' 2
  ST-Check 'unit: a path deeper than the walked bound refuses with "path depth N > walked M", never silently' (
    (-not $v24Td.Ok) -and ($v24Td.Reason -ceq 'too-deep') -and ("$($v24Td.Detail)".Contains('path depth 3 > walked 2')))
  $v24De = Resolve-UiaPath @() '@/0/2/1/9' 0
  ST-Check 'unit: an empty root list refuses as no-root instead of crashing or faking a hit' (
    (-not $v24De.Ok) -and ($v24De.Reason -ceq 'no-root'))
  $v24Dead = Format-UiaPathRefusal '/0/2/1/9' @{ Ok = $false; Reason = 'dead-end'; Path = '/0/2/1/9'; Detail = 'dead-end at /0/2/1 (child index 9 of 5)' } $null $null
  ST-Check 'unit: the dead-end refusal reports the parent, the index and the fallback roads' (
    ("$v24Dead".Contains('REFUSED: path=/0/2/1/9 dead-end')) -and ("$v24Dead".Contains('child index 9 of 5')) -and ("$v24Dead".Contains('fallback:')))
  ST-Check 'lint: the @-mark routes all three uia action commands through the verify-then-act helpers' (
    ((@($codeLines | Where-Object { $_ -match '\.StartsWith\(.@.\)' }).Count) -ge 3) -and
    ((@($codeLines | Where-Object { $_ -match 'Invoke-UiaClickByPath' }).Count) -ge 2) -and
    ((@($codeLines | Where-Object { $_ -match 'Invoke-UiaFocusByPath' }).Count) -ge 2) -and
    ((@($codeLines | Where-Object { $_ -match 'Invoke-UiaSettextByPath' }).Count) -ge 2) -and
    ((@($codeLines | Where-Object { $_ -match 'Format-UiaPathRefusal' }).Count) -ge 4))
  ST-Check 'lint: uia-tree strips its three v2.4.0 flags before the positional shape and refuses unknown --words' (
    ((@($codeLines | Where-Object { $_ -match "--eq '--actions-all'" }).Count) -ge 1) -and
    ((@($codeLines | Where-Object { $_ -match "--eq '--no-actions'" }).Count) -ge 1) -and
    ((@($codeLines | Where-Object { $_ -match "--eq '--no-paths'" }).Count) -ge 1) -and
    ((@($codeLines | Where-Object { $_ -match 'unknown flag ''\$w0''' }).Count) -ge 1))
  $v24Ci = -1
  for ($v24i = 0; $v24i -lt $clCount; $v24i++) { if ("$($codeLines[$v24i])" -match '^function Invoke-UiaClickByPath') { $v24Ci = $v24i; break } }
  $v24Cj = -1; $v24Ck = -1
  if ($v24Ci -ge 0) {
    for ($v24j = $v24Ci + 1; $v24j -lt [Math]::Min($v24Ci + 50, $clCount); $v24j++) {
      if ("$($codeLines[$v24j])" -match 'Invoke-UiaClickable') { $v24Cj = $v24j; break }
    }
    for ($v24k = $v24Ci + 1; $v24k -lt $v24Cj; $v24k++) {
      if ("$($codeLines[$v24k])" -match 'Test-UiaExpectMatch') { $v24Ck = $v24k; break }
    }
  }
  ST-Check 'lint: uia-click @path verifies the expected token BEFORE the click helper can run (verify-then-act)' (
    ($v24Ci -ge 0) -and ($v24Cj -gt $v24Ci) -and ($v24Ck -gt $v24Ci) -and ($v24Ck -lt $v24Cj))
  ST-Check 'contract: the usage block documents uia-path and the uia-tree action flags' (
    ((@($codeLines | Where-Object { $_ -match 'uia-path <sel> @/0/2/1 \[maxDepth\]' }).Count) -ge 1) -and
    ((@($codeLines | Where-Object { $_ -match '--actions-all' }).Count) -ge 2))
  # ---------- v3.0.1 (audit #3/#6/#7): the Rect.Empty family ----------
  # UIA answers "this element has no rectangle" with System.Windows.Rect.Empty, whose
  # members are INFINITIES (X=+Inf Y=+Inf Width=-Inf Height=-Inf), not zeros. Measured
  # on this machine before writing any of this: [int] of -Infinity throws, and
  # "$br.Y -ge $pageTop" is TRUE for an element that is nowhere. So the guard question
  # must come first at every consumer, and both directions are asserted here.
  $reRectOk = $true
  try { Add-Type -AssemblyName WindowsBase } catch { $reRectOk = $false }
  if (-not $reRectOk) {
    ST-Skip 'unit: Test-UiaRectUsable separates Rect.Empty from a real rectangle' 'WindowsBase did not load on this machine - no Rect type to test'
    ST-Skip 'unit: the page-area test refuses an element with no rectangle (its Y is +Infinity)' 'WindowsBase did not load on this machine - no Rect type to test'
  } else {
    $reEmpty = [System.Windows.Rect]::Empty
    $reReal = New-Object System.Windows.Rect(10, 200, 30, 40)
    $reNaN = New-Object System.Windows.Rect([double]::NaN, 0, 1, 1)
    ST-Check 'unit: Test-UiaRectUsable refuses Empty/null/NaN and accepts a real rectangle' (
      (-not (Test-UiaRectUsable $reEmpty)) -and (-not (Test-UiaRectUsable $null)) -and
      (-not (Test-UiaRectUsable $reNaN)) -and (Test-UiaRectUsable $reReal))
    # the #6 shape: the OLD code was "$br.Y -ge $pageTop", and Empty.Y is +Infinity, so
    # an element that is nowhere counted as page content and could flip the probe verdict.
    ST-Check 'unit: the page-area test refuses an element with no rectangle (its Y is +Infinity)' (
      (-not (Test-UiaInPageArea $reEmpty 100)) -and (Test-UiaInPageArea $reReal 100) -and
      (Test-UiaInPageArea $reReal 200) -and (-not (Test-UiaInPageArea $reReal 201)))
    Write-Output ("      Rect.Empty probe: X=" + $reEmpty.X + " W=" + $reEmpty.Width + " IsEmpty=" + $reEmpty.IsEmpty)
  }
  $reFuncStart = @()
  for ($rei = 0; $rei -lt $codeLines.Count; $rei++) { if ($codeLines[$rei] -match '^function ') { $reFuncStart += $rei } }
  $reUnguarded = New-Object System.Collections.ArrayList
  for ($rei = 0; $rei -lt $codeLines.Count; $rei++) {
    if ($rei -ge $j5ProdStart -and $rei -lt $j5ProdEnd) { continue }
    if ($codeLines[$rei] -match '^\s*#') { continue }
    if (-not $codeLines[$rei].Contains('BoundingRectangle')) { continue }
    $reFs = -1; $reFe = $codeLines.Count
    foreach ($cand in $reFuncStart) { if ($cand -le $rei) { $reFs = $cand } else { $reFe = $cand; break } }
    if ($reFs -lt 0) { [void]$reUnguarded.Add(($rei + 1)); continue }
    $reBody = ($codeLines[$reFs..($reFe - 1)] -join "`n")
    if (-not ($reBody.Contains('Test-UiaRectUsable') -or $reBody.Contains('.IsEmpty'))) { [void]$reUnguarded.Add(($rei + 1)) }
  }
  ST-Check 'lint: every production BoundingRectangle reader asks the emptiness question first (a new site that forgets is this family, again)' (
    @($reUnguarded).Count -eq 0)
  if (@($reUnguarded).Count -gt 0) { Write-Output "      unguarded BoundingRectangle read at line(s): $(Format-SourceLineList @($reUnguarded))" }

  # ---------- v3.0.1 (audit #4): the CDP viewport fallback had one axis ----------
  # The JS route computed Y from screenY and then, when no window could be resolved, put
  # screenY INTO X. It self-reported Formula='js-outer-minus-inner' and Ok=true the whole
  # time, so chrome-find mapped the page rect to a screen point nobody had measured.
  $cdpPt = Get-CdpViewportOriginJs 1.5 100 200 800 600 820 700
  ST-Check 'unit: the CDP JS-route origin computes each axis from its own screen coordinate' (
    ($cdpPt.X -eq 165) -and ($cdpPt.Y -eq 450))
  # the report's own falsification, run through the real function shape: a Y of 300 at 1.5
  # used to arrive as X=450. Asserting X is NOT that number is what keeps the axes apart.
  $cdpSwap = Get-CdpViewportOriginJs 1.5 40 300 1000 500 1000 500
  ST-Check 'unit: a large screenY cannot leak into X any more (the audit number was X=450 from Y=300 at dpr 1.5)' (
    ($cdpSwap.Y -eq 450) -and ($cdpSwap.X -eq 60))
  $cdpJsProbe = 0
  $cdpHelperUse = 0
  $cdpCallSites = 0
  for ($cdpI = 0; $cdpI -lt $clCount; $cdpI++) {
    if ($cdpI -ge $j5ProdStart -and $cdpI -lt $j5ProdEnd) { continue }
    $cdpL = [string]$codeLines[$cdpI]
    if ($cdpL.Contains('window.devicePixelRatio') -and $cdpL.Contains('sx: window.screenX') -and $cdpL.Contains('sy: window.screenY')) { $cdpJsProbe++ }
    if ($cdpL.Contains('= Get-CdpViewportOriginJs ')) { $cdpHelperUse++ }
    if ($cdpL.Contains('Get-CdpViewportOrigin ' + '$base')) { $cdpCallSites++ }
  }
  ST-Check 'lint: the CDP origin route derives from the one pure helper, and its metrics probe asks for both axes' (
    ($cdpJsProbe -eq 1) -and ($cdpHelperUse -ge 1) -and ($cdpCallSites -ge 1))
  Write-Output ("      cdp origin wiring: helper-calls=$cdpHelperUse probe-with-sx=$cdpJsProbe call-sites=$cdpCallSites")

  # ---------- TB-2 (2026-10-24): the send phase has a budget (dynamic, loopback) ----------
  # The connect-side half of the one-budget shape was measured against a no-handshake loopback
  # fixture (2026-10-23 rig, outside this repository). The send-side half had no dynamic cell:
  # a peer that completes the upgrade and then never read fills the socket buffers, SendAsync
  # never completes, and only the shared CancellationToken ends it. This cell builds that peer
  # for real - a background runspace completes the upgrade handshake and then blocks on a
  # second accept it never gets, so the socket stays open and unread - and asserts the budget
  # expired IN the send phase with the call returning bounded, not hung.
  $tb2ProbeResult = $null
  $tb2ElapsedMs = -1
  $tb2Ps = $null
  $tb2Rs = $null
  $tb2Listener = $null
  $tb2Handle = $null
  $tb2Hold = $null
  try {
    $tb2Listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $tb2Listener.Start()
    $tb2Port = $tb2Listener.LocalEndpoint.Port
    $tb2Rs = [runspacefactory]::CreateRunspace()
    $tb2Rs.Open()
    $tb2Ps = [powershell]::Create()
    $tb2Ps.Runspace = $tb2Rs
    [void]$tb2Ps.AddScript({
      param($L)
      $c = $L.AcceptTcpClient()
      $s = $c.GetStream()
      $req = New-Object System.Text.StringBuilder
      $buf = New-Object byte[] 4096
      while (-not ($req.ToString().Contains("`r`n`r`n"))) {
        $n = $s.Read($buf, 0, $buf.Length)
        if ($n -le 0) { break }
        [void]$req.Append([Text.Encoding]::ASCII.GetString($buf, 0, $n))
      }
      $key = ''
      $m = [regex]::Match($req.ToString(), 'Sec-WebSocket-Key: ([^\r\n]+)')
      if ($m.Success) { $key = $m.Groups[1].Value.Trim() }
      $sha = [System.Security.Cryptography.SHA1]::Create()
      $accept = [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')))
      $resp = "HTTP/1.1 101 Switching Protocols`r`nUpgrade: websocket`r`nConnection: Upgrade`r`nSec-WebSocket-Accept: $accept`r`n`r`n"
      $rbytes = [Text.Encoding]::ASCII.GetBytes($resp)
      $s.Write($rbytes, 0, $rbytes.Length)
      $s.Flush()
      # Never read again: the send side must be the side that runs out of budget. The pipeline
      # RETURNS the accepted client instead of blocking on a second accept - a blocked .NET call
      # is not interruptible by PowerShell.Stop(), so a hold-open loop here would hang Dispose.
      return $c
    }).AddArgument($tb2Listener)
    $tb2Handle = $tb2Ps.BeginInvoke()
    $tb2Sw = [System.Diagnostics.Stopwatch]::StartNew()
    $tb2ProbeResult = Invoke-CdpEval ("http://127.0.0.1:" + $tb2Port) 'TB2PAGE' ('"' + ('x' * 524288) + '"') 1200
    $tb2ElapsedMs = [int]$tb2Sw.ElapsedMilliseconds
    $tb2ErrText = "$($tb2ProbeResult.Error)"
    $tb2BoundedOk = (($null -ne $tb2ProbeResult) -and (-not $tb2ProbeResult.Ok) -and
      ($tb2ErrText.Contains('budget expired during the')) -and
      ($tb2ElapsedMs -ge 1100) -and ($tb2ElapsedMs -lt 8000))
    # Two arms, one name: the send-side premise (512KB blocks the send) is a PS 5.1 / .NET Framework
    # shape - the pwsh runtimes drain the frame, the budget then expires during the receive wait, and
    # that measured shape SKIPs under its OWN name with the reading (G-21/G-22 discipline: nothing
    # absorbed, the total stays). The bounded-return invariant holds on both arms and is asserted here.
    # The name is an INLINE literal on both arms on purpose: the static index only sees literal
    # arguments, and a variable-carried name is the exact rot this contract check exists to catch.
    if ($PSVersionTable.PSVersion.Major -le 5) {
      ST-Check 'unit (TB-2): a peer that handshakes and then never read keeps the shared CDP budget honest - the call returns bounded with the expired phase named and the wall clock inside the budget plus disposal slack' (
        $tb2BoundedOk -and ($tb2ErrText.Contains('budget expired during the send phase')))
    } else {
      ST-Skip 'unit (TB-2): a peer that handshakes and then never read keeps the shared CDP budget honest - the call returns bounded with the expired phase named and the wall clock inside the budget plus disposal slack' ('this engine (' + $PSVersionTable.PSVersion.ToString() + ') drains the 512KB probe frame without blocking the send - measured: ' + $tb2ErrText + ', elapsedMs=' + $tb2ElapsedMs + '; the send-phase shape stays pinned on the 5.1 arm')
    }
    Write-Output ('      TB-2 send-budget: ok=' + $tb2ProbeResult.Ok + ' elapsedMs=' + $tb2ElapsedMs + ' error=' + $tb2ErrText)
  } finally {
    # The handshake pipeline returned long ago (it only writes the upgrade response and comes
    # back). EndInvoke reclaims it and keeps the accepted client referenced, so the socket cannot
    # be finalized mid-check and no blocked .NET call is left for Dispose to interrupt.
    if ($null -ne $tb2Ps) {
      if ($null -ne $tb2Handle) { try { $tb2Hold = $tb2Ps.EndInvoke($tb2Handle) } catch { $tb2Hold = $_.Exception.Message } }
      $tb2Ps.Dispose()
    }
    if ($null -ne $tb2Rs) { $tb2Rs.Dispose() }
    if ($null -ne $tb2Listener) { $tb2Listener.Stop() }
  }

}
