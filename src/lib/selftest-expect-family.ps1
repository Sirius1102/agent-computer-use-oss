# lib/selftest-expect-family.ps1 - one family of the selftest section, lifted out of lib/selftest.ps1
# by A-14n (A-beta). Bodies are byte-identical to what the section carried, with three structural
# notes: the F-02 section travels inside the try/finally that contains it (a deeper-indented banner is
# not a run boundary, and cutting at one would lift the middle of a block out of the block); one
# banner of this family - the live --verify-timeout case - is nested inside a body that has not moved
# yet, so it stays in lib/selftest.ps1 and moves with that body; and the dialog-cancel wiring echo
# (left here by A-14m, physically inside this family's run) stays too, because it reads the
# hand-back names A-14l binds into the orchestration scope and a lifted family reads only published
# context.
#
# The expectation family: --verify-timeout parsing and forwarding, the patience each verdict names,
# B-1/B-2/B-3 (fold marker, handle pin, needle lists), autoexpect wiring, the fail-closed anchor, the
# verbatim expectation legs, every verify call site passing the patience, and the 7th positional
# argument that IS the occlusion gate switch.
function Invoke-SelftestFamily-ExpectFamily($Ctx) {
  # context handover (the one thing in this file above the lifted text that is not lifted text)
  $clCount = $Ctx['clCount']
  $codeLines = $Ctx['codeLines']
  $evWire = $Ctx['evWire']
  $j5ProdEnd = $Ctx['j5ProdEnd']
  $j5ProdStart = $Ctx['j5ProdStart']

  # ---------- unit: v1.5.3 --verify-timeout is parsed and forwarded ----------
  # Closes the '--verify 4s not parameterised' leftover: the parameter already
  # existed on Invoke-TypedVerify, the flag was never wired to it. Teeth follow
  # the --needle lesson - the assertions must be able to tell "parsed" from
  # "ignored", not merely "the command still ran".
  $vtOn = $null
  try { $vtOn = Split-Target @('--to', 'Notepad', '--needle', '--DTX-VERIFY', '--verify', '--verify-timeout', '9') } catch { }
  ST-Check 'unit: --verify-timeout value is parsed out of the payload' (
    $null -ne $vtOn -and $vtOn.VerifyTimeout -eq 9 -and $vtOn.Verify -eq $true)
  # the payload is a '--' sentinel fed through --needle (the --needle lesson): if
  # this flag ever stops being consumed, the sentinel is what goes red first - the
  # leftover '--verify-timeout' then hits the unknown-flag branch and the whole
  # call throws, and a half-eaten value would leave '9' in the text. Both are
  # caught here BEFORE anything is ever sent to a real window.
  ST-Check 'unit: --verify-timeout and its value never reach the typed text' (
    $null -ne $vtOn -and $vtOn.Words -notcontains '--verify-timeout' -and $vtOn.Words -notcontains '9' -and ($vtOn.Words -join ' ') -ceq '--DTX-VERIFY')
  $vtDef = $null
  try { $vtDef = Split-Target @('--to', 'Notepad', '--needle', '--DTX-VERIFY', '--verify') } catch { }
  ST-Check 'unit: --verify-timeout default stays 4s (no silent behaviour drift for existing callers)' (
    $null -ne $vtDef -and $vtDef.VerifyTimeout -eq 4)
  ST-Check 'unit: a -- payload without --verify-timeout is still typed verbatim' (
    $null -ne $vtDef -and ($vtDef.Words -join ' ') -ceq '--DTX-VERIFY')
  $vtBad = ''
  try { [void](Split-Target @('--verify-timeout')) } catch { $vtBad = $_.Exception.Message }
  ST-Check 'unit: --verify-timeout without a value throws' ($vtBad -like '--verify-timeout needs seconds*')
  $vtTxt = ''
  try { [void](Split-Target @('abc', '--verify-timeout', 'x')) } catch { $vtTxt = $_.Exception.Message }
  ST-Check 'unit: --verify-timeout rejects a non-numeric value instead of coercing it' ($vtTxt -like '*needs a number of seconds, got: x*')
  $vtLo = ''
  try { [void](Split-Target @('--verify-timeout', '0.2')) } catch { $vtLo = $_.Exception.Message }
  ST-Check 'unit: --verify-timeout below the 400ms poll floor is refused with a reason' ($vtLo -like '*must be >= 0.5*')
  # the sharp one: a flag name must never be eaten as the timeout value
  $vtFlag = ''
  try { [void](Split-Target @('--verify-timeout', '--to', 'Notepad', 'hi')) } catch { $vtFlag = $_.Exception.Message }
  ST-Check 'unit: --verify-timeout refuses to swallow the next FLAG as its value' (
    $vtFlag -like '*needs a number of seconds, got: --to*' -and $vtFlag -notlike '--to needs*')
  # 'type-in' has its own flag loop (it never goes through Split-Target), so its
  # parse is asserted separately. Both cases below throw DURING PARSING, before
  # any click or keystroke, so they are safe to run offline.
  $tiBad = ''
  try { Invoke-DesktopCommand 'type-in' @('10', '20', 'hello', '--verify-timout', '3') } catch { $tiBad = $_.Exception.Message }
  # J-06: type-in's refusal now comes from the one renderer (it used to hand-write its own),
  # so the anchors are the flag it mistyped and the list of what really reaches type-in -
  # still thrown during PARSING, before any click or keystroke.
  ST-Check 'unit: type-in refuses a mistyped --verify-timeout instead of typing it into the window' (
    $tiBad.Contains("unknown flag '--verify-timout' for 'type-in'") -and $tiBad.Contains('--verify-timeout') -and
    $tiBad.Contains('valid here:'))
  $tiNoVal = ''
  try { Invoke-DesktopCommand 'type-in' @('10', '20', 'hello', '--verify-timeout') } catch { $tiNoVal = $_.Exception.Message }
  ST-Check 'unit: type-in --verify-timeout without a value throws (and says so, not a silent 4s)' (
    $tiNoVal -like 'type-in: --verify-timeout needs seconds*')
  $tiPay = ''
  try { Invoke-DesktopCommand 'type-in' @('10', '20', '--verify-timeout', '0.2') } catch { $tiPay = $_.Exception.Message }
  ST-Check 'unit: type-in enforces the same 0.5s floor as type (one grammar, not two)' (
    $tiPay -like 'type-in: --verify-timeout must be >= 0.5*')

  # ---------- lint: v1.5.3 every verify call site passes the patience ----------
  # The offline units above prove the flag is PARSED; they cannot prove the parsed
  # value is HANDED OVER - dropping the third argument silently falls back to the
  # parameter default and every offline check stays green. This nails the shape of
  # the call itself. A bare call is "two arguments and no third", and that has to
  # be caught mid-line too (an assignment inside an if-block), so the test is
  # "has 2 args" AND NOT "has 3" rather than an end-of-line anchor.
  $vtArg2Pat = 'Invoke-TypedVerify' + '\s+\$\w+\s+\$\w+'
  $vtArg3Pat = 'Invoke-TypedVerify' + '\s+\$\w+\s+\$\w+\s+\$'
  $vtBare = New-Object System.Collections.ArrayList
  $vtFull = 0
  for ($i = 0; $i -lt $codeLines.Count; $i++) {
    $l = $codeLines[$i]
    if ($l -match 'SELFTEST-EXEMPT') { continue }
    if ($l -match '^\s*function\s') { continue }
    $has3 = ($l -match $vtArg3Pat)
    if (($l -match $vtArg2Pat) -and -not $has3) { [void]$vtBare.Add($i + 1) }
    if ($has3) { $vtFull++ }
  }
  ST-Check 'lint: no Invoke-TypedVerify call omits the timeout argument' ($vtBare.Count -eq 0)
  if ($vtBare.Count -gt 0) { Write-Output "      bare verify calls at line(s): $(Format-SourceLineList $vtBare)" }
  # two call sites exist today (type, type-in); a third is welcome but a drop is not
  ST-Check 'lint: both verify call sites pass a timeout argument' ($vtFull -ge 2)
  # the defaults themselves: 'don't change a default on the way past' is an
  # explicit instruction, so drift must be machine-caught, not review-caught
  $vtDefaults = 0
  for ($i = 0; $i -lt $codeLines.Count; $i++) {
    if ($codeLines[$i] -match '^\s*\$v(erifyTimeout|Timeout)\s*=\s*4\s*$') { $vtDefaults++ }
  }
  ST-Check 'lint: both --verify-timeout defaults are still the literal 4' ($vtDefaults -eq 2)
  # positive controls: neither pattern is vacuous, and the mid-line form - the one
  # the first draft of this lint missed - is what actually trips the bare pattern.
  # Built by concatenation: written plainly, these sample lines would be scanned
  # as real call sites and the lint would fail on its own test fixture.
  $vtName = 'Invoke-TypedVerify'
  $vtPlantBare = '$v = ' + $vtName + ' $t $x'
  $vtPlantMid = 'if ($p.Verify) { $ver = ' + $vtName + ' $target $text }'
  ST-Check 'lint: bare-call pattern detects planted violations (line-end and mid-line)' (
    ($vtPlantBare -match $vtArg2Pat) -and ($vtPlantBare -notmatch $vtArg3Pat) -and
    ($vtPlantMid -match $vtArg2Pat) -and ($vtPlantMid -notmatch $vtArg3Pat))
  $vtPlantFull = '$v = ' + $vtName + ' $t $x $p.VerifyTimeout'
  ST-Check 'lint: a planted full call trips neither the bare rule nor a false end' (
    ($vtPlantFull -match $vtArg3Pat) -and (-not (($vtPlantFull -match $vtArg2Pat) -and -not ($vtPlantFull -match $vtArg3Pat))))
  # passing a literal instead of the parsed value is the other way this regresses
  $vtPlantLit = '$v = ' + $vtName + ' $t $x 4'
  ST-Check 'lint: hardcoding the patience is refused too, not just dropping it' (
    ($vtPlantLit -match $vtArg2Pat) -and ($vtPlantLit -notmatch $vtArg3Pat))

  # ---------- unit: v1.5.7 "self-reported value" - the expect family names its patience ----------
  $evOk = Format-ExpectationVerdict $true 1.24 6.0 300 '' '' '' 'clicked'
  ST-Check 'unit: a satisfied expectation names the patience and interval it ran with' (
    $evOk.StartsWith('  + verified in 1.2 s') -and $evOk.Contains('patience 6s') -and $evOk.Contains('polled every 300 ms'))
  $evBad = Format-ExpectationVerdict $false 6.02 30.0 100 'Saved' 'not visible' 'whole anchored region' 'clicked'
  ST-Check 'unit: an unmet expectation says OF HOW MUCH patience, so --timeout cannot be silently ignored' (
    $evBad.Contains("clicked OK but expectation NOT met: 'Saved' not visible in whole anchored region") -and
    $evBad.Contains('after 6s of 30s') -and $evBad.Contains('patience 30s, polled every 100 ms'))
  # the printed number must be what the LOOP used: the clamp rewrites $intervalMs at the top
  # of Invoke-Expectation, so every return has to carry it out or the verdict lies.
  # the marker is assembled AND the count is exact: the first version wrote the literal
  # inline, so this very line matched itself (4 instead of 3) and a dropped `Timeout =`
  # still left 3 - the mutation came back green and that was the lint's fault, not the
  # code's (third time today a scan matched its own search string).
  $evCarryPat = 'Timeout = $timeoutSec;' + ' Interval = $intervalMs'
  $evCarry = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($evCarryPat) })
  # v3.0.0 EXPECTATION CHANGE - 3 -> 2, and the reason is a merge, NOT a loosening.
  # Pre-v3.0.0 Invoke-Expectation had three patience-carrying returns because the "expect"
  # and "expect-gone" successes were two separate return statements; the any-of/all-gone
  # lists (B-3) made them one AND-semantics return, so the literal now appears twice.
  # The invariant this check exists for is unchanged and still holds: EVERY return that can
  # be reached after waiting carries the patience and the clamped interval it ran with, and
  # the early "nothing asked" return never did and still does not. Verified, not assumed:
  # dropping `Timeout =` from either remaining return still turns this red.
  $evCarryExpect = 2
  ST-Check 'unit: every Invoke-Expectation return carries the patience/interval it ran with (exactly 2 since the v3.0.0 merge)' (@($evCarry).Count -eq $evCarryExpect)
  if (@($evCarry).Count -ne $evCarryExpect) { Write-Output "      returns carrying patience: $(@($evCarry).Count)" }
  ST-Check 'lint: both expect verdicts come from the one formatter (exactly 2 production sites)' (@($evWire).Count -eq 2)

  # ---------- unit + lint: v3.0.0 B-1/B-2/B-3 (expect evidence, handle pin, needle lists) ----------
  # B-1: the fold marker first, because splitting Get-FoldMarkerFromCounts out of
  # Get-OcrFoldMarker is what surfaced a SHIPPED defect: the partial-fold branch was
  # " [$$($folded.Count) of ...]" and `$$(` in a double-quoted string is neither an escape
  # nor a subexpression - it stringifies the ARRAY and appends a literal ".Count", so a
  # 2-of-5 fold printed "[lineA lineB.Count of 5 matched via confusable-fold ...]". Only the
  # all-folded branch was ever exercised (its corpus had exactly one hit) and that branch has
  # no interpolation, so the marker whose whole job is honesty was lying in the one shape no
  # check built. These cases build that shape.
  ST-Check 'unit: fold marker - no folds prints nothing' (
    (Get-FoldMarkerFromCounts 0 5) -eq '' -and (Get-FoldMarkerFromCounts 0 0) -eq '')
  ST-Check 'unit: fold marker - all-folded wording is unchanged from v1.5.2' (
    (Get-FoldMarkerFromCounts 5 5) -eq ' [matched via confusable-fold - not an exact read]')
  # the exact rendered line, not a substring: `-like '*confusable-fold*'` (the pre-v3.0.0
  # check) passed on the broken output, which is why "the phrase appears" is not a verdict.
  ST-Check 'unit: fold marker - the PARTIAL branch renders counts, not the hit list' (
    (Get-FoldMarkerFromCounts 2 5) -eq ' [2 of 5 matched via confusable-fold - not an exact read]')
  $foldCorpus = New-Object System.Collections.ArrayList
  for ($fk = 1; $fk -le 5; $fk++) {
    $fo = [pscustomobject]@{ Text = "QXHELL0123$fk"; X = 10; Y = 10; W = 80; H = 14 }
    if ($fk -le 2) { $fo | Add-Member -NotePropertyName Folded -NotePropertyValue $true }
    [void]$foldCorpus.Add($fo)
  }
  ST-Check 'unit: Get-OcrFoldMarker on a real 2-of-5 corpus agrees with the count renderer (one producer, both callers)' (
    (Get-OcrFoldMarker $foldCorpus) -eq (Get-FoldMarkerFromCounts 2 5) -and
    (Get-OcrFoldMarker $foldCorpus) -eq ' [2 of 5 matched via confusable-fold - not an exact read]')
  ST-Check 'unit: Get-OcrFoldMarker on exact hits prints nothing (the corpus is not all-folded)' (
    (Get-OcrFoldMarker @([pscustomobject]@{ Text = 'x' })) -eq '')

  # B-1: what a satisfied expectation now says out loud. Built from a result object, so the
  # shape is pinned offline; the live check that the real loop fills these keys is separate.
  $pfFull = Format-ExpectationProof @{ Matched = 'QXOK'; Rect = '(606,861,260x24)'; Centre = '736,873'; Hits = 3; Via = 'tiled(4)'; FoldedHits = 0; Polls = 2 }
  ST-Check 'unit: a satisfied --expect echoes the rect it read, where it would click, how it read it and how often' (
    $pfFull.Contains('matched=QXOK') -and $pfFull.Contains('at=(606,861,260x24)') -and
    $pfFull.Contains('centre=736,873') -and $pfFull.Contains('hits=3') -and
    $pfFull.Contains('via=tiled(4)') -and $pfFull.Contains('polls=2'))
  # a single hit must not print hits=1 (noise), and a gone-list success has no rect at all -
  # the absence is the honest output, not an empty at=().
  ST-Check 'unit: the proof line omits what did not happen (no hits=1, no empty at= for a gone-list)' (
    (Format-ExpectationProof @{ Rect = '(1,2,3x4)'; Hits = 1; Polls = 1 }).Contains('hits=') -eq $false -and
    (Format-ExpectationProof @{ Polls = 3 }) -eq ' polls=3')
  ST-Check 'unit: a folded expectation success carries the fold marker in its proof line' (
    (Format-ExpectationProof @{ Matched = 'A'; Rect = '(1,2,3x4)'; Hits = 2; FoldedHits = 1; Polls = 1 }) -like '*1 of 2 matched via confusable-fold*')
  ST-Check 'unit: Format-ExpectationProof on nothing-to-say prints the empty string, not a stray space' (
    (Format-ExpectationProof @{}) -eq '')
  # the retry geometry as ONE word, and it must be able to tell 1x from 2x from tiled - the
  # three-state shape Format-OcrRetryNote already established for miss messages.
  ST-Check 'unit: the via word distinguishes 1x, single 2x and tiled(n) - never a bare "retried"' (
    (Get-ExpectationVia $false $false 0) -eq '1x' -and (Get-ExpectationVia $true $false 1) -eq '2x' -and
    (Get-ExpectationVia $true $true 6) -eq 'tiled(6)')
  # missing keys must degrade to '1x', not abort: an absent hashtable key reads as $null, and
  # a [bool] parameter on $null is a conversion ERROR that would kill the command after the
  # action already worked (measured: this exact shape aborted a selftest run mid-way).
  ST-Check 'unit: the via word survives an absent Scaled/Tiled key instead of erroring the caller' (
    (Get-ExpectationVia $null $null $null) -eq '1x' -and (Get-ExpectationVia '' '' '') -eq '1x')
  # production-side anchor: before v3.0.0 the success return carried no Rect, so this red.
  # The marker is assembled because this very line would otherwise match its own search.
  $exRectPat = '$r.' + 'Rect ='
  $exRectSites = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($exRectPat) })
  ST-Check 'lint: Invoke-Expectation success actually populates a rect (production site, not a test fixture)' (@($exRectSites).Count -ge 1)
  Write-Output "      expect-evidence: rect-sites=$(@($exRectSites).Count)"

  # B-2: the handle pin. Pure comparison first - including the two shapes that would make a
  # pin useless if they were wrong: an EMPTY pin must mean "nobody asked" (Ok), never
  # "match nothing" (which would refuse every call), and a mismatch must name BOTH handles
  # so the reader can see which window the selector actually landed on.
  $pinH = [IntPtr]0x1F3A
  $pinOk = Test-HandlePin '' $pinH
  ST-Check 'unit: an absent handle pin passes and reports the window it saw (never "match nothing")' (
    $pinOk.Ok -and $pinOk.Expected -eq '' -and $pinOk.Actual -eq '0x1f3a' -and $pinOk.Reason -eq '')
  $pinHex = Test-HandlePin '0x1f3a' $pinH
  $pinDec = Test-HandlePin '7994' $pinH
  ST-Check 'unit: a handle pin accepts 0x-hex and decimal and normalizes both to one hex form' (
    $pinHex.Ok -and $pinDec.Ok -and $pinHex.Expected -eq '0x1f3a' -and $pinDec.Expected -eq '0x1f3a')
  $pinBad = Test-HandlePin '0x9999' $pinH
  ST-Check 'unit: a mismatched pin refuses and names both handles (the drift must be visible)' (
    -not $pinBad.Ok -and $pinBad.Reason -eq 'mismatch' -and $pinBad.Expected -eq '0x9999' -and $pinBad.Actual -eq '0x1f3a')
  $pinJunk = Test-HandlePin 'hwnd=123' $pinH
  ST-Check 'unit: a malformed pin is refused as invalid-format, quoting the raw token' (
    -not $pinJunk.Ok -and $pinJunk.Reason -eq 'invalid-format' -and $pinJunk.Expected -eq 'hwnd=123')
  # v3.0.1 (audit #24): the RIGHT shape and the WRONG range used to be different failures -
  # a 20-hex-digit pin matched the pattern and then died inside [Convert]::ToInt64 with a
  # raw OverflowException, so the flag whose whole job is a legible refusal printed a .NET
  # stack trace. Both directions are refused here, with the reason spelled out.
  $pinHugeHex = $null
  $pinHugeHexErr = ''
  try { $pinHugeHex = Test-HandlePin '0x1234567890abcdef1234' $pinH } catch { $pinHugeHexErr = $_.Exception.GetType().Name }
  ST-Check 'unit: an out-of-range hex handle pin is refused, not thrown as OverflowException' (
    ($pinHugeHexErr -ceq '') -and ($null -ne $pinHugeHex) -and (-not $pinHugeHex.Ok) -and
    ($pinHugeHex.Reason -ceq 'invalid-format') -and ("$($pinHugeHex.Hint)".Length -gt 0))
  $pinHugeDec = $null
  $pinHugeDecErr = ''
  # built, not written as a literal: a 23-digit run in this file is exactly what the
  # publication gate's LONG-HEX rule exists to question, and a fixture must not cost an
  # exemption (the same lesson as the app-name comment the v3.0.0 gate caught).
  $pinHugeDecIn = ('9' * 23)
  try { $pinHugeDec = Test-HandlePin $pinHugeDecIn $pinH } catch { $pinHugeDecErr = $_.Exception.GetType().Name }
  ST-Check 'unit: an out-of-range DECIMAL handle pin is refused the same way (both casts are guarded)' (
    ($pinHugeDecErr -ceq '') -and ($null -ne $pinHugeDec) -and (-not $pinHugeDec.Ok) -and
    ($pinHugeDec.Reason -ceq 'invalid-format') -and ("$($pinHugeDec.Hint)".Length -gt 0))
  ST-Check 'unit: the refusal formatter appends the hint only when there is one (three call sites print through it)' (
    ((Format-HandlePinReason @{ Reason = 'mismatch'; Hint = '' }) -ceq 'mismatch') -and
    ((Format-HandlePinReason @{ Reason = 'invalid-format'; Hint = 'too wide' }) -ceq 'invalid-format: too wide'))
  # parser-side: the flag must be refused where it is typed, naming the flag, before any
  # window resolution happens. (Written with try/catch on purpose: an earlier draft of this
  # very check was `($p.ExpectHandle -eq '') -or ($p.ExpectHandle -eq 'hwnd=123')`, which
  # passes whichever way the parser behaves - i.e. a check with no teeth at all.)
  $pinThrew = ''
  try { [void](Split-Target @('500', '600', '--to', 'X', '--expect-handle', 'hwnd=123') 'click') } catch { $pinThrew = "$($_.Exception.Message)" }
  ST-Check 'unit: --expect-handle refuses a non-handle value at the parser and names the flag' (
    $pinThrew -like '*--expect-handle*' -and $pinThrew -like '*0x*')
  $pinEmptyThrew = ''
  try { [void](Split-Target @('500', '600', '--expect-handle') 'click') } catch { $pinEmptyThrew = "$($_.Exception.Message)" }
  ST-Check 'unit: --expect-handle with no value is refused (it must not eat the next selector)' (
    $pinEmptyThrew -like '*--expect-handle needs*')
  $pinGood = Split-Target @('500', '600', '--to', 'X', '--expect-handle', '0x1f3a') 'click'
  ST-Check 'unit: --expect-handle keeps the handle token and does not leak it into the payload' (
    $pinGood.ExpectHandle -eq '0x1f3a' -and -not (@($pinGood.Words) -contains '0x1f3a') -and
    -not (@($pinGood.Words) -contains '--expect-handle'))
  # --expect-handle must be declared as a VALUE-consuming flag, or the central pre-strip in
  # Strip-OwnFlags validates the handle as a flag - the exact shape that ate `--needle
  # --DTXVT` in v1.5.7 and only went red on a --live round.
  $pinValueFlags = @('--expect-handle', '--expect-any', '--expect-any-gone')
  $pinVsShared = @($pinValueFlags | Where-Object { -not (@(Get-SharedFlagSet) -contains $_) })
  $pinVsValue = @($pinValueFlags | Where-Object { -not (@(Get-SharedValueFlagSet) -contains $_) })
  ST-Check 'lint: every new expect flag is in BOTH the shared set and the value-consuming set (error text and pre-strip cannot lie)' (
    @($pinVsShared).Count -eq 0 -and @($pinVsValue).Count -eq 0)
  # wiring, production only: a pin that is parsed but never reaches the resolver is the D-1
  # defect ("documented, parsed, unreachable") one layer down. Marker assembled to self-match.
  $pinWirePat = 'AlwaysActivate ' + '$p.ExpectHandle'
  $pinWire = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($pinWirePat) })
  ST-Check 'lint: every canonical Resolve-Target call threads the handle pin through (>= 14 production sites)' (@($pinWire).Count -ge 14)
  # and the refusal must happen BEFORE activation, or the call that says "I refused" has
  # already moved the user's window.
  $pinFnStart = -1; $pinFnEnd = -1
  for ($pk = 0; $pk -lt $codeLines.Count; $pk++) {
    if ($codeLines[$pk] -match '^\s*function Resolve-Target\(' -and $pinFnStart -lt 0) { $pinFnStart = $pk }
    elseif ($pinFnStart -ge 0 -and $codeLines[$pk] -match '^\}$' -and $pk -gt $pinFnStart) { $pinFnEnd = $pk; break }
  }
  $pinBody = @()
  $pinAct = -1; $pinCheck = -1
  if ($pinFnStart -ge 0 -and $pinFnEnd -gt $pinFnStart) {
    for ($pk = $pinFnStart; $pk -lt $pinFnEnd; $pk++) {
      if ($codeLines[$pk].Contains('Activate-Win $w') -and $pinAct -lt 0) { $pinAct = $pk }
      if ($codeLines[$pk].Contains('Test-HandlePin $expectHandle $w.Handle') -and $pinCheck -lt 0) { $pinCheck = $pk }
    }
  }
  ST-Check 'lint: the handle pin is evaluated before Activate-Win, so a refusal never disturbs the desktop' (
    $pinFnStart -ge 0 -and $pinCheck -ge 0 -and $pinAct -gt $pinCheck)
  Write-Output "      handle pin: wire-sites=$(@($pinWire).Count) pin-line=$(Format-SourceLineList @($pinCheck + 1)) activate-line=$(Format-SourceLineList @($pinAct + 1))"

  # B-3: needle LISTS. The parsing is checked directly; the MERGE (single flags + list flags
  # into one assertion) is checked with Invoke-Expectation replaced in-process (the v1.5.9
  # ${function:...} technique this repo already allows for the autoexpect orchestration), because the
  # thing worth pinning is "what list reaches the matcher" - and that must not depend on a
  # real OCR round trip or on the desktop.
  $b3Orig = ${function:Invoke-Expectation}
  try {
    ${function:Invoke-Expectation} = { param($base, $pres, $gones, $region, $to, $iv, $ah)
      $script:B3Seen = @{ Present = @($pres); Gone = @($gones) }
      return @{ Ok = $true; Elapsed = 0.4; Timeout = $to; Interval = $iv; Polls = 1; Matched = 'A'; Rect = '(1,2,3x4)'; Centre = '2,3'; Hits = 1 }
    }
    $b3a = Split-Target @('10', '20', '--to', 'X', '--expect', 'A', '--expect-any', 'B,C') 'click'
    $null = Invoke-ActionExpectation $b3a $null 'clicked'
    $b3ListA = (@($script:B3Seen.Present) -join ',')
    $b3a2 = Split-Target @('10', '20', '--to', 'X', '--expect-gone', 'D', '--expect-any-gone', 'E,F') 'click'
    $null = Invoke-ActionExpectation $b3a2 $null 'clicked'
    $b3ListB = (@($script:B3Seen.Gone) -join ',')
    # AND across the two kinds: a caller that asks for both gets both lists, never one.
    $b3a3 = Split-Target @('10', '20', '--to', 'X', '--expect', 'A', '--expect-any-gone', 'G') 'click'
    $null = Invoke-ActionExpectation $b3a3 $null 'clicked'
    $b3Both = (@($script:B3Seen.Present).Count -eq 1 -and (@($script:B3Seen.Gone) -join ',') -eq 'G')
    # duplicates are collapsed (the same text from two flags is one assertion, not two OCR passes)
    $b3a4 = Split-Target @('10', '20', '--to', 'X', '--expect', 'A', '--expect-any', 'A') 'click'
    $null = Invoke-ActionExpectation $b3a4 $null 'clicked'
    $b3Dedup = (@($script:B3Seen.Present).Count -eq 1)
    $b3a5 = Split-Target @('10', '20', '--to', 'X') 'click'
    $script:B3Seen = $null
    $null = Invoke-ActionExpectation $b3a5 $null 'clicked'
    $b3Skipped = ($null -eq $script:B3Seen)
    ST-Check 'unit: single + list expectation flags merge into one needle list in order' (
      $b3ListA -eq 'A,B,C' -and $b3ListB -eq 'D,E,F' -and $b3Both -and $b3Dedup)
    ST-Check 'unit: a command with no expectation at all never reaches the matcher' ($b3Skipped)
    # the success line must carry the proof through the SHARED tail, not just the builder
    $b3Line = (Invoke-ActionExpectation (Split-Target @('10', '20', '--to', 'X', '--expect', 'A') 'click') $null 'clicked') -join ' '
    ST-Check 'unit: the shared expect tail prints the proof line (at=/centre=/polls=) after the verdict' (
      $b3Line.StartsWith('  + verified in 0.4 s') -and $b3Line.Contains('at=(1,2,3x4)') -and
      $b3Line.Contains('centre=2,3') -and $b3Line.Contains('polls=1') -and $b3Line.Contains('via=1x'))
  } finally {
    ${function:Invoke-Expectation} = $b3Orig
    $script:B3Seen = $null
  }
  # parsing shapes: trim, drop empty items, refuse an all-empty list, and --no-expect must
  # clear the new flags too (a stale list surviving --no-expect is a send-only escape that
  # still asserts, which is the opposite of what the flag promises).
  $b3p = Split-Target @('10', '20', '--to', 'X', '--expect-any', ' A, B,,C, ') 'click'
  ST-Check 'unit: --expect-any trims items and drops empty ones (a,b,, is not an empty-string assertion)' (
    (@($b3p.ExpectAny) -join ',') -eq 'A,B,C')
  $b3pOff = Split-Target @('10', '20', '--to', 'X', '--expect', 'A', '--expect-any', 'B', '--expect-gone', 'C', '--expect-any-gone', 'D', '--no-expect') 'click'
  ST-Check 'unit: --no-expect clears the single AND the list expectation flags' (
    $b3pOff.Expect -eq '' -and $b3pOff.ExpectGone -eq '' -and
    @($b3pOff.ExpectAny).Count -eq 0 -and @($b3pOff.ExpectAnyGone).Count -eq 0 -and $b3pOff.NoExpect)
  $b3Throw = ''
  try { [void](Split-Target @('10', '20', '--expect-any', ',,') 'click') } catch { $b3Throw = "$($_.Exception.Message)" }
  ST-Check 'unit: an --expect-any that reduces to nothing is refused (an assertion that cannot fail)' (
    $b3Throw -like '*--expect-any*non-empty*')
  $b3NoVal = ''
  try { [void](Split-Target @('10', '20', '--expect-any') 'click') } catch { $b3NoVal = "$($_.Exception.Message)" }
  ST-Check 'unit: --expect-any with no value is refused rather than swallowing the next token' (
    $b3NoVal -like '*--expect-any needs*')
  # a '--' leading list must still be reachable through --needle-style data flow: the value
  # is DATA, so the central pre-strip may not validate it as a flag (covered above by the
  # Get-SharedValueFlagSet lint; this pins the observable behaviour for one list flag).
  $b3Lead = Split-Target @('10', '20', '--expect-any', '--DTXA,--DTXB') 'click'
  ST-Check 'unit: --expect-any accepts a list whose items start with -- (they are data, not flags)' (
    (@($b3Lead.ExpectAny) -join ',') -eq '--DTXA,--DTXB')

  # ---------- unit: v1.5.9 P-1 autoexpect - needle derivation, orchestration, gate ----------
  # The v1.5.9 task order allows exactly this offline shape: "mock out the OCR result".
  # The function override below stands in for the screen-reading loop, so the skip logic,
  # both messages and the failure gate are behaviour-tested without a desktop. The
  # finally is load-bearing: a leaking mock would silently re-route every later OCR
  # expectation (including the --live section) through the fake.
  $anLast = Get-AutoExpectNeedle "first line`nsecond line`n  DTX tail for readback  `n`n"
  ST-Check 'unit: autoexpect needle is the LAST non-empty line, trimmed (not the first)' ($anLast -ceq 'DTX tail for readback')
  $anCap = Get-AutoExpectNeedle ("x`n" + ('A' * 40))
  ST-Check 'unit: autoexpect needle caps the payload tail at 24 chars' ($anCap.Length -eq 24 -and $anCap -ceq ('A' * 24))
  ST-Check 'unit: autoexpect needle of a whitespace-only payload is empty (readback skipped)' ((Get-AutoExpectNeedle "  `n`t`n") -ceq '')
  ST-Check 'unit: autoexpect needle of an empty payload is empty' ((Get-AutoExpectNeedle '') -ceq '')

  $aeMockSeen = New-Object System.Collections.ArrayList
  $aeMockReal = ${function:Invoke-Expectation}
  $aeReceiptSeen = New-Object System.Collections.ArrayList
  $aeReceiptReal = ${function:Get-PasteReceipt}
  $pAe = @{ Expect = ''; ExpectGone = ''; ExpectRegion = ''; NoExpect = $false; TimeoutSec = 6; IntervalMs = 300 }
  try {
    ${function:Invoke-Expectation} = { param($baseRect, $ex, $exGone, $exRegion, $to, $iv, $ah)
      [void]$aeMockSeen.Add(@{ Needle = $ex; PassedTo = $to; Iv = $iv })
      if ($script:aeMockOk) { return @{ Ok = $true; Elapsed = 0.4; Where = 'mock region'; Timeout = 6; Interval = 300 } }
      return @{ Ok = $false; Elapsed = 6.0; Where = 'mock region'; Timeout = 6; Interval = 300 }
    }
    # Get-PasteReceipt really captures the screen and walks a UIA tree, so the receipt
    # half of this gate is mocked too - an offline selftest must never touch the desktop.
    ${function:Get-PasteReceipt} = { param($t) [void]$aeReceiptSeen.Add('call'); return @{ H = 100; Lines = 1; Nodes = 2; Hash = 'mockhash'; Rect = @(0, 0, 10, 10); Occluded = 0.0; CoveredBy = '' } }
    $script:aeMockOk = $false
    [void]$aeMockSeen.Clear()
    $aeBad = Invoke-AutoPasteExpect $pAe $null 'DTXMOCKTAIL'
    ST-Check 'unit: autoexpect unreadable payload -> NOT ok, names the escape hatch and the patience it used' (
      $aeBad.Ran -and (-not $aeBad.Ok) -and $aeBad.Message.Contains('WARN: payload not visible in target after send') -and
      $aeBad.Message.Contains('pass --no-expect to accept send-only') -and $aeBad.Message.Contains('patience 6s') -and
      $aeBad.Message.Contains('polled every 300 ms') -and $aeBad.Message.Contains('autoexpect=11chars') -and
      $aeBad.Message.Contains('DO NOT resend blindly') -and $aeBad.Message.Contains('receipt-tried=verbatim-tail-only'))
    ST-Check 'unit: the autoexpect failure message does not echo the payload tail' (-not $aeBad.Message.Contains('DTXMOCKTAIL'))
    # v4.2.0 item 1: the verdict's EXIT must lead with verification, never with a resend.
    # Both halves are pinned by position, not by presence - "DO NOT resend" appearing
    # somewhere after a "please resend" would not be a fix.
    $aeIdxNoResend = $aeBad.Message.IndexOf('DO NOT resend blindly')
    $aeIdxVerify = $aeBad.Message.IndexOf('Verify first with read-text / uia-find / find-text')
    $aeIdxRetry = $aeBad.Message.IndexOf('only if verified absent')
    ST-Check 'unit: the autoexpect failure leads with "do not resend" + a verification route, and the retry comes last' (
      ($aeIdxNoResend -ge 0) -and ($aeIdxVerify -gt $aeIdxNoResend) -and ($aeIdxRetry -gt $aeIdxVerify))
    # short payload (no baseline): the SAME three v2.2.0 measurements still run, AFTER
    # only, and say so - a number without a "not a verdict" label would be read as one.
    ST-Check 'unit: the short-payload failure still reports the three receipt measurements, labelled AFTER-state and not a verdict' (
      $aeBad.Message.Contains('receipt-tried=verbatim-tail-only') -and
      $aeBad.Message.Contains('after-state: diag-skipped(no-target)') -and
      $aeBad.Message.Contains('AFTER-state only, not a verdict') -and
      $aeBad.Message.Contains('no baseline was taken'))
    ST-Check 'unit: the failure Receipt field carries the same numbers as the message (gate and caller cannot disagree)' (
      $aeBad.Receipt -ceq 'after-state: diag-skipped(no-target)')
    # long payload WITH a baseline: all three legs ran in the verdict and the refusal
    # prints what each measured (none-of-three detail), so "we looked" is visible.
    $aeBase = @{ H = 100; Lines = 1; Nodes = 2; Hash = 'aaaa1111bbbb2222'; Rect = @(0, 0, 10, 10); Occluded = 0.0; CoveredBy = '' }
    $script:aeMockOk = $false
    $aeLong = Invoke-AutoPasteExpect $pAe $null 'DTXMOCKTAIL' $aeBase 240
    ST-Check 'unit: a long-payload failure reports every receipt leg''s measured numbers instead of a bare "not visible"' (
      $aeLong.Ran -and (-not $aeLong.Ok) -and
      $aeLong.Message.Contains('receipt-tried=none-of-three') -and
      $aeLong.Message.Contains('uia nodes 2->2') -and
      $aeLong.Message.Contains('h 100->100 (needs +8)') -and
      $aeLong.Message.Contains('lines 1->1') -and
      $aeLong.Message.Contains('fold-threshold=200'))
    # that probe spent one receipt call of its own; hand the counter back to zero so the
    # baseline assertion below still measures ITS two calls (counters are per-assertion).
    [void]$aeReceiptSeen.Clear()
    $script:aeMockOk = $true
    [void]$aeMockSeen.Clear()
    $aeOk = Invoke-AutoPasteExpect $pAe $null 'DTXMOCKTAIL'
    ST-Check 'unit: autoexpect verified payload -> + verified line carrying the autoexpect tag and patience' (
      $aeOk.Ran -and $aeOk.Ok -and $aeOk.Message.StartsWith('  + verified in 0.4 s') -and
      $aeOk.Message.Contains('patience 6s') -and $aeOk.Message.Contains('polled every 300 ms') -and
      $aeOk.Message.Contains('autoexpect=11chars'))
    ST-Check 'unit: autoexpect polls the OCR loop exactly once per call, with the payload tail as needle' (
      @($aeMockSeen).Count -eq 1 -and "$($aeMockSeen[0].Needle)" -ceq 'DTXMOCKTAIL' -and
      $aeMockSeen[0].PassedTo -eq 6 -and $aeMockSeen[0].Iv -eq 300)
    [void]$aeMockSeen.Clear()
    $pNoExp = @{ Expect = ''; ExpectGone = ''; ExpectRegion = ''; NoExpect = $true; TimeoutSec = 6; IntervalMs = 300 }
    $pExplicit = @{ Expect = 'Given'; ExpectGone = ''; ExpectRegion = ''; NoExpect = $false; TimeoutSec = 6; IntervalMs = 300 }
    $pRegion = @{ Expect = ''; ExpectGone = ''; ExpectRegion = '1,2,30,40'; NoExpect = $false; TimeoutSec = 6; IntervalMs = 300 }
    $aeSkip1 = Invoke-AutoPasteExpect $pNoExp $null 'DTXMOCKTAIL'
    $aeSkip2 = Invoke-AutoPasteExpect $pExplicit $null 'DTXMOCKTAIL'
    $aeSkip3 = Invoke-AutoPasteExpect $pRegion $null 'DTXMOCKTAIL'
    $aeSkip4 = Invoke-AutoPasteExpect $pAe $null ''
    ST-Check 'unit: --no-expect / explicit --expect / --expect-region / empty needle all skip the readback' (
      @($aeMockSeen).Count -eq 0 -and (-not $aeSkip1.Ran) -and (-not $aeSkip2.Ran) -and (-not $aeSkip3.Ran) -and (-not $aeSkip4.Ran))
    # v3.0.1 (audit item 2, the one this round SHIPPED): the two skip gates enumerate the
    # expect flags by hand, and the v3.0.0 list form (--expect-any / --expect-any-gone)
    # was added to neither - so a call that already asserts an any-of list ALSO paid the
    # verbatim-tail readback and could fail on it. One producer now, both shapes.
    $pAny = @{ Expect = ''; ExpectGone = ''; ExpectRegion = ''; NoExpect = $false; TimeoutSec = 6; IntervalMs = 300; ExpectAny = @('A', 'B'); ExpectAnyGone = @() }
    $pAnyGone = @{ Expect = ''; ExpectGone = ''; ExpectRegion = ''; NoExpect = $false; TimeoutSec = 6; IntervalMs = 300; ExpectAny = @(); ExpectAnyGone = @('C') }
    [void]$aeMockSeen.Clear()
    $aeSkip5 = Invoke-AutoPasteExpect $pAny $null 'DTXMOCKTAIL'
    $aeSkip6 = Invoke-AutoPasteExpect $pAnyGone $null 'DTXMOCKTAIL'
    ST-Check 'unit: an --expect-any / --expect-any-gone list counts as an explicit expectation and skips the readback' (
      @($aeMockSeen).Count -eq 0 -and (-not $aeSkip5.Ran) -and (-not $aeSkip6.Ran))
    # the same gate guards the CHEAP half: a paste that already asserts must not pay for
    # a receipt baseline either. Asserted through the mock, not through the screen.
    [void]$aeMockSeen.Clear()
    $rbSkipAny = Get-PasteReceiptBaseline $pAny $null ('x' * 200)
    $rbRunPlain = Get-PasteReceiptBaseline $pAe $null ('x' * 200)
    ST-Check 'unit: the receipt baseline is skipped for an any-of expectation and still taken without one' (
      (@($aeReceiptSeen).Count -eq 1) -and ($null -eq $rbSkipAny) -and ($null -ne $rbRunPlain))
    try { Confirm-AutoExpect $aeBad; $aeGate = 'NO-THROW' } catch { $aeGate = $_.Exception.Message }
    ST-Check 'unit: the autoexpect gate throws a self-reporting FAIL on an unmet verdict' (
      $aeGate.Contains('autoexpect NOT met') -and $aeGate.Contains('patience 6s') -and $aeGate.Contains('autoexpect=11chars') -and
      $aeGate.Contains('pass --no-expect to accept send-only') -and $aeGate.Contains('DO NOT resend blindly'))
    $aeGateOk = 'NOT-RUN'
    try { Confirm-AutoExpect $aeOk; $aeGateOk = 'SILENT' } catch { $aeGateOk = 'THREW: ' + $_.Exception.Message }
    ST-Check 'unit: the autoexpect gate is silent on a met verdict' ($aeGateOk -ceq 'SILENT')
  } finally {
    ${function:Invoke-Expectation} = $aeMockReal
    ${function:Get-PasteReceipt} = $aeReceiptReal
  }

  # ---------- lint: v1.5.9 P-1 wiring (default-on must stay WIRED, not just defined) ----------
  $aeWire = @()
  for ($awi = 0; $awi -lt $codeLines.Count; $awi++) {
    if ($awi -ge $j5ProdStart -and $awi -lt $j5ProdEnd) { continue }
    if ($codeLines[$awi] -match '^\s*#') { continue }
    if ($codeLines[$awi].Contains('Invoke-AutoPasteExpect')) { $aeWire += ($awi + 1) }
  }
  ST-Check 'lint: paste AND paste-file both wire the autoexpect readback (exactly 3 sites: 1 def + 2 calls)' (@($aeWire).Count -eq 3)
  if (@($aeWire).Count -ne 3) { Write-Output "      autoexpect wiring sites: $(@($aeWire) -join ', ')" }
  # The skip decision must have ONE producer. Counting calls is not enough on its own:
  # a hand-written enumeration re-added somewhere else would leave the call count alone,
  # so the scan also fails any production line that chains -or through the flags again.
  $tewDef = -1
  $tewEnd = -1
  for ($ti = 0; $ti -lt $clCount; $ti++) {
    if ($ti -ge $j5ProdStart -and $ti -lt $j5ProdEnd) { continue }
    if ($tewDef -lt 0) { if (([string]$codeLines[$ti]) -match '^function Test-ExpectationGiven') { $tewDef = $ti }; continue }
    if ([string]$codeLines[$ti] -ceq '}') { $tewEnd = $ti; break }
  }
  $tewHand = @()
  $tewCalls = @()
  for ($ti = 0; $ti -lt $clCount; $ti++) {
    if ($ti -ge $j5ProdStart -and $ti -lt $j5ProdEnd) { continue }
    if ($tewDef -ge 0 -and $ti -ge $tewDef -and ($tewEnd -lt 0 -or $ti -le $tewEnd)) { continue }
    $tiLine = [string]$codeLines[$ti]
    if ($tiLine -match 'NoExpect\s+-or\s+\$p\.' -and $tiLine -match '\$p\.Expect\w*\s+-or') { $tewHand += ($ti + 1) }
    if ($tiLine.Contains('Test-ExpectationGiven $')) { $tewCalls += ($ti + 1) }
  }
  ST-Check 'lint: the "an expectation was already given" decision has one producer and no hand-run enumeration left' (
    ($tewDef -ge 0) -and ($tewEnd -gt $tewDef) -and (@($tewCalls).Count -eq 2) -and (@($tewHand).Count -eq 0))
  Write-Output ("      expectation-given producer: def=" + (Format-SourceLineRef ($tewDef + 1)) + " calls=" + (Format-SourceLineList $tewCalls) + " hand-run enumerations left=" + @($tewHand).Count)
  $aeNeedleSites = @()
  for ($awi = 0; $awi -lt $codeLines.Count; $awi++) {
    if ($awi -ge $j5ProdStart -and $awi -lt $j5ProdEnd) { continue }
    if ($codeLines[$awi] -match '^\s*#') { continue }
    if ($codeLines[$awi].Contains('Get-AutoExpectNeedle')) { $aeNeedleSites += ($awi + 1) }
  }
  ST-Check 'lint: both autoexpect call sites derive the needle from the payload (exactly 3 sites)' (@($aeNeedleSites).Count -eq 3)
  if (@($aeNeedleSites).Count -ne 3) { Write-Output "      needle derivation sites: $(@($aeNeedleSites) -join ', ')" }
  $aeGateSites = @()
  for ($awi = 0; $awi -lt $codeLines.Count; $awi++) {
    if ($awi -ge $j5ProdStart -and $awi -lt $j5ProdEnd) { continue }
    if ($codeLines[$awi] -match '^\s*#') { continue }
    if ($codeLines[$awi].Contains('Confirm-AutoExpect')) { $aeGateSites += ($awi + 1) }
  }
  ST-Check 'lint: both autoexpect call sites run the failure gate (exactly 3 sites: 1 def + 2 calls)' (@($aeGateSites).Count -eq 3)
  if (@($aeGateSites).Count -ne 3) { Write-Output "      gate wiring sites: $(@($aeGateSites) -join ', ')" }
  # search string assembled by concatenation: the scan line must not contain its own
  # pattern (the self-match shape that fed "at least N" lints three times in one day)
  $aeUsagePat = "throw 'usage: pas" + "te(-file)? \["
  $aeUsage = @()
  for ($awi = 0; $awi -lt $codeLines.Count; $awi++) {
    if ($awi -ge $j5ProdStart -and $awi -lt $j5ProdEnd) { continue }
    if ($codeLines[$awi] -match '^\s*#') { continue }
    if ($codeLines[$awi] -match $aeUsagePat) { $aeUsage += $codeLines[$awi] }
  }
  ST-Check 'lint: paste and paste-file usage lines list the expect family (default-on must be discoverable)' (
    @($aeUsage).Count -eq 2 -and @($aeUsage | Where-Object { $_.Contains('--expect') }).Count -eq 2 -and
    @($aeUsage | Where-Object { $_.Contains('--no-expect') }).Count -eq 2)

  # ---------- v3.1.0 (P-03): the expectation anchor is fail-closed for a lost target, and
  # the no-target case self-reports what it is actually waiting on ----------
  # Pre-fix, "gave --to but the window died before the wait" and "never gave a target"
  # both fell into the same silent whole-virtual-screen fallback that called itself
  # "whole anchored region" - an expectation answering from the whole screen is not an
  # anchored expectation at all, and the content guard has thrown on the same situation
  # all along. Now: lost target = refuse (Confirm-ExpectAnchor, one producer, callers
  # Invoke-ActionExpectation and Invoke-AutoPasteExpect); no target = still allowed, but
  # the verdict carries anchor=no-target (whole virtual screen) instead of the old
  # honest-sounding label.
  $exOcrReal = ${function:Find-OcrHitsScaled}
  $script:ex4Sentinel = 0
  try {
    ${function:Find-OcrHitsScaled} = { param($x, $y, $w, $h, $needle, $scale, $maxTiles, $noTile)
      $script:ex4Sentinel++
      throw 'ex4-sentinel: the OCR loop was reached (the anchor refusal did not run first)' }
    $ex4NoRectTarget = [pscustomobject]@{ Pid = 41998; Title = 'ex4-fake-gone'; Handle = [IntPtr]::Zero }
    $ex4P = @{ Expect = @('NEEDLE'); ExpectAny = @(); ExpectGone = @(); ExpectAnyGone = @(); ExpectRegion = $null; TimeoutSec = 0.3; IntervalMs = 100; MinLineDensity = 1.5 }
    $ex4Err = ''
    try { Invoke-ActionExpectation $ex4P $ex4NoRectTarget 'clicked' | Out-Null }
    catch { $ex4Err = "$($_.Exception.Message)" }
    $ex4AOk = ((($ex4Err -like '*expectation anchor*') -and ($ex4Err -like '*NOT waiting on the whole screen*')) -and ($script:ex4Sentinel -eq 0))
    ST-Check 'unit (P-03): an expectation whose target existed but whose rect is gone refuses with the anchor refusal before a single OCR poll happens (the content guard has failed this way all along; the silent whole-screen fallback was the lie)' (
      $ex4AOk)
    if (-not $ex4AOk) { Write-Output ("      P-03 unitA: err=[" + $ex4Err + "] sentinel=" + $script:ex4Sentinel) }
    ${function:Find-OcrHitsScaled} = { param($x, $y, $w, $h, $needle, $scale, $maxTiles, $noTile)
      return @{ Hits = @([pscustomobject]@{ X = 1; Y = 1; W = 8; H = 8 }); Lines = @('ex4-line'); Scaled = $false; Tiled = $false; TileCount = 0 } }
    $ex4B = Invoke-Expectation $null @('NEEDLE') @() $null 0.3 100
    ST-Check 'unit (P-03): no target at all still waits on the whole virtual screen, but the verdict now SAYS so - Where is exactly anchor=no-target (whole virtual screen), not the old whole-anchored-region label' (
      (($ex4B.Ok) -and ($ex4B.Where -ceq 'anchor=no-target (whole virtual screen)')))
    $ex4C = Invoke-Expectation $null @('NEEDLE') @() '5,5,50,50' 0.3 100
    ST-Check 'unit (P-03): no-target with --expect-region keeps the virtual-screen anchor NAMED in the verdict (anchor=no-target (whole virtual screen), region ... (anchor-relative))' (
      (($ex4C.Ok) -and ($ex4C.Where -like 'anchor=no-target (whole virtual screen), region 5,5,50x50 (anchor-relative)')))
    $ex4D = Invoke-Expectation @{ X = 0; Y = 0; W = 100; H = 100 } @() @() $null 0.3 100
    ST-Check 'unit (P-03): a real target rect keeps the historical wording - whole anchored region means the TARGET rect there, and that case did not drift' (
      (($ex4D.Ok) -and ($ex4D.Where -ceq 'whole anchored region')))
  } finally {
    ${function:Find-OcrHitsScaled} = $exOcrReal
  }

  # ---------- v3.1.0 (P-04): the verbatim expectation legs get the occlusion front gate ----------
  # v2.3.0 measured the false-accept on the receipt chain (a covered target's screen rect
  # reads the COVERER, so lines-changed "moved" on someone else's video). The verbatim
  # expect legs read the same kind of screen rect on every poll and had no gate at all.
  # The gate is same-source same-knob (Get-OcclusionVerdict + Get-PasteReceiptOcclusionMax,
  # shipped at 0): a covered anchor refuses the wait at once with exit 1; sampler failure
  # is fail-OPEN and self-reported through OccErr (registered limitation); no target
  # handle (the P-03 anchor=no-target case) has no occlusion semantics, so no gate there.
  $ex5OccReal = ${function:Get-OcclusionVerdict}
  $ex5FocReal = ${function:Format-OcclusionCovering}
  $ex5KnobReal = ${function:Get-PasteReceiptOcclusionMax}
  $ex5OcrReal = ${function:Find-OcrHitsScaled}
  $script:ex5OccCalls = 0
  $script:ex5OcrCalls = 0
  try {
    ${function:Format-OcclusionCovering} = { param($items, $checked) return @{ Items = @($items); Lines = @(); Summary = "pid=999 'ex5-coverer' (" + @($items).Count + " of " + $checked + " sample points)"; Top = $null } }
    ${function:Find-OcrHitsScaled} = { param($x, $y, $w, $h, $needle, $scale, $maxTiles, $noTile)
      $script:ex5OcrCalls++
      return @{ Hits = @([pscustomobject]@{ X = 1; Y = 1; W = 8; H = 8 }); Lines = @('ex5-line'); Scaled = $false; Tiled = $false; TileCount = 0 } }
    ${function:Get-OcclusionVerdict} = { param($x, $y, $w, $h, $handle, $grid) $script:ex5OccCalls++; return @{ Checked = 25; Mismatch = 0; Pct = 0.0; Covering = @(); Skipped = 0; Err = ''; Ms = 1.0 } }
    $script:ex5OccCalls = 0; $script:ex5OcrCalls = 0
    $ex5Clean = Invoke-Expectation @{ X = 0; Y = 0; W = 100; H = 100 } @('NEEDLE') @() $null 0.3 100 ([IntPtr]1)
    ST-Check 'unit (P-04): a clean anchor (occluded=0) passes the verbatim wait and the gate really sampled the anchor rect (the sampler runs before the first OCR poll)' (
      (($ex5Clean.Ok) -and ($script:ex5OccCalls -ge 1) -and ($script:ex5OcrCalls -ge 1) -and (-not $ex5Clean.OccErr)))
    ${function:Get-OcclusionVerdict} = { param($x, $y, $w, $h, $handle, $grid) $script:ex5OccCalls++; return @{ Checked = 25; Mismatch = 25; Pct = 100.0; Covering = @([pscustomobject]@{ Pid = 999; Samples = 25 }); Skipped = 0; Err = ''; Ms = 1.0 } }
    $script:ex5OccCalls = 0; $script:ex5OcrCalls = 0
    $ex5Err = ''
    try { Invoke-Expectation @{ X = 0; Y = 0; W = 100; H = 100 } @('NEEDLE') @() $null 0.3 100 ([IntPtr]1) | Out-Null }
    catch { $ex5Err = "$($_.Exception.Message)" }
    $ex5Leg2Ok = ((($ex5Err -like '*expect refused*') -and ($ex5Err -like '*occluded=100%*') -and ($ex5Err -like '*coveredBy=pid=999*')) -and ($script:ex5OcrCalls -eq 0))
    ST-Check 'unit (P-04): a covered anchor refuses the wait AT ONCE with expect refused: target occluded=N% coveredBy=... - and the refusal lands BEFORE the first OCR read of that poll (no wait-and-see; the coverer never gets to answer the needle)' (
      $ex5Leg2Ok)
    if (-not $ex5Leg2Ok) { Write-Output ("      P-04 leg2: err=[" + $ex5Err + "] occ-calls=" + $script:ex5OccCalls + " ocr-calls=" + $script:ex5OcrCalls) }
    ${function:Get-OcclusionVerdict} = { param($x, $y, $w, $h, $handle, $grid) $script:ex5OccCalls++; return @{ Checked = 0; Mismatch = 0; Pct = 0.0; Covering = @(); Skipped = 25; Err = 'ex5-sample-failed'; Ms = 1.0 } }
    $script:ex5OccCalls = 0; $script:ex5OcrCalls = 0
    $ex5Open = Invoke-Expectation @{ X = 0; Y = 0; W = 100; H = 100 } @('NEEDLE') @() $null 0.3 100 ([IntPtr]1)
    ST-Check 'unit (P-04): a failed occlusion sampler does NOT refuse (Err is not a rejection reason, same as the receipt gate) and the wait self-reports it through OccErr' (
      (($ex5Open.Ok) -and ($ex5Open.OccErr -ceq 'ex5-sample-failed') -and ($script:ex5OcrCalls -ge 1)))
    # leg 3 leaves a FAILED sampler mock on the wire (Err non-empty), and the gate fail-opens on
    # Err BEFORE comparing anything - so flipping the knob there is structurally invisible. Measured:
    # replacing the production knob with a literal 0 left this leg green. Put a real 100%-covered
    # verdict back, then move ONLY the knob and demand two outcomes from the same input.
    ${function:Get-OcclusionVerdict} = { param($x, $y, $w, $h, $handle, $grid) $script:ex5OccCalls++; return @{ Checked = 25; Mismatch = 25; Pct = 100.0; Covering = @([pscustomobject]@{ Pid = 999; Samples = 25 }); Skipped = 0; Err = ''; Ms = 1.0 } }
    ${function:Get-PasteReceiptOcclusionMax} = { return 100 }
    $script:ex5OccCalls = 0; $script:ex5OcrCalls = 0
    $ex5Knob = $null
    $ex5KnobOpenErr = ''
    try { $ex5Knob = Invoke-Expectation @{ X = 0; Y = 0; W = 100; H = 100 } @('NEEDLE') @() $null 0.3 100 ([IntPtr]1) }
    catch { $ex5KnobOpenErr = "$($_.Exception.Message)" }
    $ex5KnobPassed = (($null -ne $ex5Knob) -and $ex5Knob.Ok)
    # the OCR counter has to be read from the PASSING half - the refusing half throws before the
    # first read by design, so asserting it after the second call would pin nothing (measured).
    $ex5KnobOcrCalls = $script:ex5OcrCalls
    ${function:Get-PasteReceiptOcclusionMax} = $ex5KnobReal
    $script:ex5OccCalls = 0; $script:ex5OcrCalls = 0
    $ex5KnobErr = ''
    try { Invoke-Expectation @{ X = 0; Y = 0; W = 100; H = 100 } @('NEEDLE') @() $null 0.3 100 ([IntPtr]1) | Out-Null }
    catch { $ex5KnobErr = "$($_.Exception.Message)" }
    ST-Check 'unit (P-04): the gate compares against Get-PasteReceiptOcclusionMax - the SAME 100%-covered anchor passes at knob=100 and refuses at the production knob (a hardcoded zero cannot pass this)' (
      ($ex5KnobPassed) -and ($ex5KnobOcrCalls -ge 1) -and ($ex5KnobErr -like '*expect refused*'))
    if (-not (($ex5KnobPassed) -and ($ex5KnobOcrCalls -ge 1) -and ($ex5KnobErr -like '*expect refused*'))) { Write-Output ("      P-04 leg4: knob100-pass=" + $ex5KnobPassed + " knob100-err=[" + $ex5KnobOpenErr + "] knob100-ocr=" + $ex5KnobOcrCalls + " prod-refused=[" + $ex5KnobErr + "] occ-calls=" + $script:ex5OccCalls) }
    # ---------- F-02: the 7th positional argument IS the gate switch ------------------------
    # Invoke-Expectation's LAST parameter ($anchorHandle) is the only thing that turns the v3.1.0
    # P-04 occlusion front gate on; the body reads
    #   if (($null -ne $anchorHandle) -and (-not $anchorHandle.Equals([IntPtr]::Zero)))
    # so a call that forgets it does not fail, does not warn and does not refuse - it waits with
    # the coverer free to answer the needle, which is the exact false-accept P-04 exists to stop.
    # The pre-existing arity lint only catches TOO MANY arguments (Get-CallArgCount vs declared),
    # so "one short" was structurally invisible. Three arities on the SAME wire, with a 100%
    # covered anchor in place: handle -> refuse; nothing -> silently no gate (the defect);
    # explicit [IntPtr]::Zero -> silently no gate (the documented anchor=no-target case).
    # The behavioural half matters as much as the text count: a lint that counts arguments would
    # still be green if the parameter did nothing at all.
    $f2Rect5 = @{ X = 0; Y = 0; W = 100; H = 100 }
    $script:ex5OccCalls = 0; $script:ex5OcrCalls = 0
    $f2Six = $null; $f2SixErr = ''
    try { $f2Six = Invoke-Expectation $f2Rect5 @('NEEDLE') @() $null 0.3 100 }
    catch { $f2SixErr = "$($_.Exception.Message)" }
    $f2SixOcc = $script:ex5OccCalls; $f2SixOcr = $script:ex5OcrCalls
    $script:ex5OccCalls = 0; $script:ex5OcrCalls = 0
    $f2ZeroErr = ''
    try { $null = Invoke-Expectation $f2Rect5 @('NEEDLE') @() $null 0.3 100 ([IntPtr]::Zero) }
    catch { $f2ZeroErr = "$($_.Exception.Message)" }
    $f2ZeroOcc = $script:ex5OccCalls
    $script:ex5OccCalls = 0; $script:ex5OcrCalls = 0
    $f2SevenErr = ''
    try { $null = Invoke-Expectation $f2Rect5 @('NEEDLE') @() $null 0.3 100 ([IntPtr]1) }
    catch { $f2SevenErr = "$($_.Exception.Message)" }
    $f2SevenOcc = $script:ex5OccCalls
    Write-Output ('      F-02 arity behaviour: six(six-occ,ocr,err)=' + $f2SixOcc + ',' + $f2SixOcr + ',[' + $f2SixErr +
      '] zero-occ=' + $f2ZeroOcc + ' seven-occ=' + $f2SevenOcc + ' seven-err=[' + $f2SevenErr + ']')
    ST-Check 'unit (F-02): the anchor handle is load-bearing - same 100%-covered anchor, a handle refuses, NO handle silently skips the gate (occ-calls=0 and the needle is read off the coverer), an explicit [IntPtr]::Zero is the documented no-anchor case' (
      ($null -ne $f2Six) -and ($f2Six.Ok) -and ($f2SixErr -eq '') -and ($f2SixOcc -eq 0) -and ($f2SixOcr -ge 1) -and
      ($f2ZeroOcc -eq 0) -and ($f2ZeroErr -eq '') -and
      ($f2SevenOcc -ge 1) -and ($f2SevenErr -like '*expect refused*'))
    # The static half: every PRODUCTION call site must pass all seven (the two autoexpect/expect
    # legs), and the declaration itself must still have seven parameters - an eighth added here
    # without touching this check is a red, not a silent widening. Marker assembled at runtime:
    # the scanner's own source names the function it hunts (fifth occurrence of that family).
    $f2Mark = 'Invoke-' + 'Expectation '
    $f2SigMark = 'function Invoke-' + 'Expectation'
    $f2Sites = @(); $f2Offend = @(); $f2Decl = 0
    for ($f2i = 0; $f2i -lt $codeLines.Count; $f2i++) {
      if ($f2i -ge $j5ProdStart -and $f2i -lt $j5ProdEnd) { continue }
      $f2l = [string]$codeLines[$f2i]
      if ($f2l -match '^\s*#') { continue }
      if ($f2l.StartsWith($f2SigMark)) {
        # declared parameter count = comma-separated slots in the signature
        $f2Decl = (("$f2l" -split ',').Count)
        continue
      }
      $f2After = Get-CodeTailAfterMark $f2l $f2Mark
      if ($null -eq $f2After) { continue }
      $f2Sites += ($f2i + 1)
      $f2N = Get-CallArgCount $f2After
      if ($f2N -ne 7) { $f2Offend += ('' + ($f2i + 1) + '=' + $f2N) }
    }
    Write-Output ('      F-02 arity lint: sites=[' + ($f2Sites -join ',') + '] offenders=[' + ($f2Offend -join ',') + '] declared-params=' + $f2Decl)
    ST-Check 'lint (F-02): every production Invoke-Expectation call site passes all seven arguments (a missing anchor handle is a silent gate-off, and the >=2 site floor proves the scan is looking)' (
      @($f2Offend).Count -eq 0 -and @($f2Sites).Count -ge 2 -and $f2Decl -eq 7)
    # Teeth for the detector itself (a text counter that always answers 7 fails nothing):
    # the real production tail and a hand-stripped six-argument tail must read differently.
    $f2RealTail = '$base $presentList $goneList $p.ExpectRegion $p.TimeoutSec $p.IntervalMs $exHandle'
    $f2ShortTail = '$base $presentList $goneList $p.ExpectRegion $p.TimeoutSec $p.IntervalMs'
    $f2ZoneTail = '$base $presentList $goneList $p.ExpectRegion $p.TimeoutSec $p.IntervalMs ([IntPtr]::Zero)'
    Write-Output ('      F-02 counter: seven=' + (Get-CallArgCount $f2RealTail) + ' six=' + (Get-CallArgCount $f2ShortTail) +
      ' zero-literal=' + (Get-CallArgCount $f2ZoneTail))
    ST-Check 'unit (F-02): the arity counter reads 7 / 6 / 7 on the planted tails (a counter blind to a dropped argument would make the lint above decorative)' (
      (Get-CallArgCount $f2RealTail) -eq 7 -and (Get-CallArgCount $f2ShortTail) -eq 6 -and (Get-CallArgCount $f2ZoneTail) -eq 7)
  } finally {
    ${function:Get-OcclusionVerdict} = $ex5OccReal
    ${function:Format-OcclusionCovering} = $ex5FocReal
    ${function:Get-PasteReceiptOcclusionMax} = $ex5KnobReal
    ${function:Find-OcrHitsScaled} = $ex5OcrReal
  }

}
