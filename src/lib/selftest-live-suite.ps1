# lib/selftest-live-suite.ps1 - one family of the selftest section, lifted out of lib/selftest.ps1
# by A-14p (A-beta). The body is byte-identical to what the section carried: the span was hashed before
# the cut and this region is re-hashed after it, so "identical" is a measurement, not a claim. The only
# channel to the orchestrator is the context object, and this family hands nothing back - it writes no
# $Ctx[...] key (measured: zero $Ctx index-assignments in the span), and the $script: names it sets
# (popup, pgProc, chProc, held, ups, gaN, and the temporary $script:Json flip around one child run) are
# script-scope state the inline body already shared with the rest of the section, not hand-backs on the
# declared channel.
#
# live-suite is a MODE family, not a topic: all 20 banners here are checks that only run under --live,
# and each of them also repeats its topic family's words. That claim conflict is decided by data -
# StFamilyOrder puts live-suite first, so precedence is a choice someone made rather than a hashtable
# accident. Three structural notes, all measured before the cut:
# * the run is ONE contiguous block. 20 banners are attributed to this family but exactly one of them
#   delimits a run (two-space indent); the other 19 ride inside the block that contains them, and
#   cutting at each of the 20 would have lifted the middle of the if ($live) block out of that block.
# * the workshop self-report leg and the outcome-prefix ownership lint at the tail sit INSIDE this run,
#   so they travel with it.
# * the window snapshot is handed over by reference, not re-taken: a family that enumerated the screen
#   again would judge a different screen than the one the inline body judged. lint (A-14p) pins that.
# * nothing this body assigns survives the lift (audited: of the 719 names bound inside the span, the 4
#   that are read again after it bind that value themselves before reading it).
function Invoke-SelftestFamily-LiveSuite($Ctx) {
  # context handover (the one thing in this file above the lifted text that is not lifted text)
  $ActionLog = $Ctx['actionLog']
  $codeLines = $Ctx['codeLines']
  $j5ProdEnd = $Ctx['j5ProdEnd']
  $j5ProdStart = $Ctx['j5ProdStart']
  $live = $Ctx['live']
  $OutDir = $Ctx['outDir']
  $w0 = $Ctx['w0']
  $wins = $Ctx['wins']

  # INC-02 (CU-REMAINDER-FINAL-20261029-01): a live block that writes the SHARED clipboard has to be
  # able to put it back, and has to not write when it cannot. Both normalization writes below pipe a
  # fixed string into clip.exe, which replaces whatever the machine owner (or another app) left
  # there: no snapshot before the write, no restore on any exit path, and the family's one existing
  # clipboard guard (the round-trip block) opens ~380 lines AFTER the first of them - its finally
  # cannot put back a value that was already replaced.
  # The guard is a pair because the write and the end of a block are far apart:
  #   Start- snapshots the shared clipboard and asks the tool's OWN verdict whether it can be put
  #   back. 'no ...' and 'unknown ...' refuse the write; the caller then skips the legs it owns under
  #   an environment gate carrying the verdict as the reason, which is the G-20 shape - a desktop that
  #   could not be made clean is neither a build failure nor a pass.
  #   Stop- runs in the finally, so success, exception and cancellation all restore. The note goes
  #   through Get-ClipboardRestoreOutcome and 'partial'/'failed' make the guard's own check RED:
  #   "the clipboard was lost anyway" is not a clean exit, and only the process kill below is
  #   outside what any of this can cover.
  # $seam is the isolated interface the lifecycle is proven through OFFLINE (three scriptblocks
  # replacing save/verdict/restore). No offline leg touches the shared clipboard; the on-site leg
  # stays unrun until a live round is authorized.
  function Start-LiveClipboardGuard([string]$who, $seam) {
    $q2Save = { Save-ClipboardState }
    $q2Verdict = { param($st) Get-ClipboardRestorableVerdict $st }
    $q2Restore = { param($st) Restore-ClipboardState $st }
    if ($seam) {
      if ($seam.Save) { $q2Save = $seam.Save }
      if ($seam.Verdict) { $q2Verdict = $seam.Verdict }
      if ($seam.Restore) { $q2Restore = $seam.Restore }
    }
    $q2St = & $q2Save
    $q2V = '' + (& $q2Verdict $q2St)
    # 'yes - if the writing command can save the image carrier' starts: it is a yes, and the image
    # leg that cannot be carried is refused later by the tool's own write guard, in the clear.
    $q2Ok = (($q2V -notlike 'no*') -and ($q2V -notlike 'unknown*'))
    return @{ Who = $who; Started = $q2Ok; Verdict = $q2V; Snapshot = $q2St; RestoreFn = $q2Restore; Written = $false }
  }

  function Stop-LiveClipboardGuard($g) {
    if (-not $g) { return 'skipped clipboard restore (no guard was started for this block)' }
    if (-not $g.Started) { return ('skipped clipboard restore (the guard refused the write: ' + [string]$g.Verdict + ')') }
    if (-not $g.Written) { return 'skipped clipboard restore (the guard started but this block never wrote)' }
    return '' + (& $g.RestoreFn $g.Snapshot)
  }

  # ---------- live: real OCR against a real window ----------
  if ($live) {
    # ---------- live: workshop self-report (printed first, every round) ----------
    # This repo's "is the workshop clean?" gate reads shots/actions.log - which only ever
    # contains activity ORIGINATED BY THIS TOOL. The blind spot was proved on 2026-10-01:
    # another actor drove the desktop through raw UIAutomation for about two minutes (a
    # near-fullscreen window raised to the foreground), produced ZERO lines in
    # actions.log, and coordinate-class checks (hover / drag / type-in) ran underneath it
    # while the gate said "clean". The gate cannot see that class of actor, so the round
    # stops pretending it does: say out loud who owns the foreground and the cursor the
    # moment the round starts, so the transcript can be reconciled against an external
    # timeline afterwards. This is a DISCLOSURE, not an exclusivity guarantee.
    $wsFg = [DT]::GetForegroundWindow()
    $wsPid = 0
    [void][DT]::GetWindowThreadProcessId($wsFg, [ref]$wsPid)
    $wsProc = 'unknown'
    try { $wsProc = (Get-Process -Id $wsPid -ErrorAction Stop).ProcessName } catch { }
    $wsCur = New-Object DT+POINT
    [void][DT]::GetCursorPos([ref]$wsCur)
    Write-Output "      workshop: foreground pid=$wsPid proc='$wsProc' title='$([DT]::Text($wsFg))' cursor=$($wsCur.X),$($wsCur.Y) (actions.log only proves tool-originated activity - an actor using raw Win32/UIAutomation leaves no line here)"
    ST-Check 'live: workshop self-report measured a real foreground owner at round start (the transcript names who holds the desktop, not just "clean")' (
      ($wsPid -gt 0) -and ($wsProc -ne 'unknown') -and ("$wsProc").Length -gt 0)
    $wsNeed = '      workshop: foreground ' + 'pid='
    $wsMarker = 0
    for ($wsi = $j5ProdStart; $wsi -lt $j5ProdEnd; $wsi++) {
      if ($codeLines[$wsi].Contains($wsNeed)) { $wsMarker++ }
    }
    ST-Check 'lint: the live ladder opens with the workshop self-report (deleting the disclosure must be loud)' ($wsMarker -eq 1)

    # ---------- live: child caller identity (the stderr-silence contract) ----------
    # Every native child of this ladder (the first one is the imgclick --dry below) reads
    # its caller identity from the caller-label / caller-session env vars. Without them
    # the child prints the caller-identity WARNING to stderr, and under
    # ErrorActionPreference=Stop a native-stderr line through 2>&1 becomes a terminating
    # NativeCommandError: on 2026-10-29 the ladder died exactly there, at the first child,
    # and the whole paste ladder behind it never ran. Declaring the identity here is what
    # keeps the bare 2>&1 capture sites of this file alive; the label also lands in each
    # child's own call record, so a live round's children are auditable as selftest-live.
    function Set-StLiveCallerIdentity([string]$label) {
      # the env names are spelled split so this source never carries them unsplit
      # (the lint below counts the call sites, and its own marker must not self-match)
      [Environment]::SetEnvironmentVariable('DTX_CALLER_L' + 'ABEL', $label, 'Process')
      [Environment]::SetEnvironmentVariable('DTX_CALLER_S' + 'ESSION_ID', $(if ($label) { [guid]::NewGuid().ToString('N') } else { $null }), 'Process')
    }
    # INC-03 (CU-REMAINDER-FINAL-20261029-01): the unlabeled control below cleared the TWO DTX names,
    # but Get-DtxCallIdentity (lib/caller-runtime.ps1) reads FOUR sources - the two DTX names, then
    # CODEX_THREAD_ID, then CODEX_SESSION_ID. Measured 2026-10-30 on the real resolver: both DTX names
    # empty with a Codex thread id present answers CallerLabel='Codex' /
    # IdentitySource='codex-thread-environment' and prints NO 'caller identity=unknown' line at all.
    # So in a Codex-launched round the negative control asserted a warning the tool was RIGHT not to
    # print - the ruler was measuring the environment, not the code. The control now isolates every
    # source the resolver reads, and the fallback gets its own positive leg instead of being stepped
    # on by a control that cannot see it.
    function Get-StLiveIdentitySources {
      return @{
        Label = [Environment]::GetEnvironmentVariable('DTX_CALLER_L' + 'ABEL', 'Process')
        Session = [Environment]::GetEnvironmentVariable('DTX_CALLER_S' + 'ESSION_ID', 'Process')
        CodexThread = [Environment]::GetEnvironmentVariable('CODEX_THREAD_' + 'ID', 'Process')
        CodexSession = [Environment]::GetEnvironmentVariable('CODEX_SESSION_' + 'ID', 'Process')
      }
    }
    function Set-StLiveCodexIdentity([string]$thread, [string]$session) {
      [Environment]::SetEnvironmentVariable('CODEX_THREAD_' + 'ID', $thread, 'Process')
      [Environment]::SetEnvironmentVariable('CODEX_SESSION_' + 'ID', $session, 'Process')
    }
    # what this round INHERITED, taken before anything is cleared: the fallback leg below runs on that
    # value only. Injecting a synthetic id would answer the question with a fixture and would also put
    # a made-up session into the shared per-session call history.
    $stIdBase = Get-StLiveIdentitySources
    $stIdCodexLeg = 'CODEX_THREAD_ID'
    if (-not [string]$stIdBase.CodexThread) { $stIdCodexLeg = 'CODEX_SESSION_ID' }
    if ((-not [string]$stIdBase.CodexThread) -and (-not [string]$stIdBase.CodexSession)) { $stIdCodexLeg = '' }
    # two-sided control first: clear any inherited label AND both Codex fallbacks, then pin that an
    # unlabeled child still warns - a future silent removal of the warning cannot let the labeled-side
    # check below pass vacuously.
    # the child command line is built OUTSIDE the try: the labeled leg below reads this same variable
    # after the finally, and a throw between the clears and this assignment would leave it undefined.
    $stIdArgs = '-NoProfile -ExecutionPolicy Bypass -File "' + $script:ToolEntryPath + '" help'
    try {
      Set-StLiveCallerIdentity $null
      Set-StLiveCodexIdentity $null $null
      $stIdErrB = Join-Path $OutDir ('st-id-unlabeled-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.stderr.txt')
      $stIdOutB = $stIdErrB -replace '\.stderr\.txt$', '.stdout.txt'
      $stIdCpB = Start-Process -FilePath 'powershell.exe' -ArgumentList $stIdArgs -RedirectStandardOutput $stIdOutB -RedirectStandardError $stIdErrB -Wait -PassThru -NoNewWindow
      $stIdErrTxtB = ''
      if (Test-Path -LiteralPath $stIdErrB) { $stIdErrTxtB = [IO.File]::ReadAllText($stIdErrB) }
      ST-Check 'live: the same child without the caller label still warns (the two-sided identity contract is pinned, with every identity source isolated)' (
        ($stIdCpB.ExitCode -eq 0) -and $stIdErrTxtB.Contains('caller identity=unknown'))
      Write-Output ('      child identity probe (unlabeled): exit=' + $stIdCpB.ExitCode + ' stderr-bytes=' + $stIdErrTxtB.Length +
        ' codex-sources-inherited=' + $(if ([string]$stIdBase.CodexThread) { 'thread' } elseif ([string]$stIdBase.CodexSession) { 'session' } else { 'none' }))
      # the Codex fallback, as a POSITIVE leg: the label stays empty, the identity this session really
      # carries comes back, and the unknown warning must not appear. This is the leg that used to be
      # indistinguishable from the negative one - the negative control could only be green when the
      # machine happened to have no Codex id, and there it proved nothing about the fallback.
      if ($stIdCodexLeg -ne '') {
        Set-StLiveCodexIdentity $stIdBase.CodexThread $stIdBase.CodexSession
        $stIdErrC = Join-Path $OutDir ('st-id-codex-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.stderr.txt')
        $stIdOutC = $stIdErrC -replace '\.stderr\.txt$', '.stdout.txt'
        $stIdCpC = Start-Process -FilePath 'powershell.exe' -ArgumentList $stIdArgs -RedirectStandardOutput $stIdOutC -RedirectStandardError $stIdErrC -Wait -PassThru -NoNewWindow
        $stIdErrTxtC = ''
        if (Test-Path -LiteralPath $stIdErrC) { $stIdErrTxtC = [IO.File]::ReadAllText($stIdErrC) }
        ST-Check 'live: a child with no caller label but the Codex identity this session carries resolves through the fallback and prints no unknown warning (the source the negative control isolates)' (
          ($stIdCpC.ExitCode -eq 0) -and (-not $stIdErrTxtC.Contains('caller identity=unknown')) -and
          ($stIdErrTxtC -notmatch 'identity=unknown'))
        Write-Output ('      child identity probe (codex fallback via ' + $stIdCodexLeg + '): exit=' + $stIdCpC.ExitCode + ' stderr-bytes=' + $stIdErrTxtC.Length)
      } else {
        ST-Skip 'live: a child with no caller label but the Codex identity this session carries resolves through the fallback and prints no unknown warning (the source the negative control isolates)' 'this process carries neither CODEX_THREAD_ID nor CODEX_SESSION_ID - the fallback leg has no premise, and a synthetic id would answer the question with a fixture and land in the shared call history'
      }
    } finally {
      # every source the round inherited comes back before anything else in the ladder runs, and the
      # label is declared from here on - both on the success path and on the path that throws.
      Set-StLiveCodexIdentity $stIdBase.CodexThread $stIdBase.CodexSession
      Set-StLiveCallerIdentity 'selftest-live'
    }
    $stIdAfter = Get-StLiveIdentitySources
    # Only the two CODEX names are RESTORED to what the round inherited. The DTX pair is deliberately
    # NOT restored: line-level, the finally above re-declares 'selftest-live' because every child below
    # needs it (that is the v4.6.12 stderr-resilience contract), so asserting the label byte-for-byte
    # against the inherited value would compare a value this file intentionally changed - a ruler that
    # can only be red. The honest shape is: fallback sources back exactly, declared label present and
    # named, session id non-empty and regenerated.
    ST-Check 'live: the identity legs put the two Codex fallback sources back byte-for-byte and leave the DTX pair in the declared state the ladder needs (not the inherited one)' (
      ([string]$stIdAfter.CodexThread -ceq [string]$stIdBase.CodexThread) -and
      ([string]$stIdAfter.CodexSession -ceq [string]$stIdBase.CodexSession) -and
      ([string]$stIdAfter.Label -ceq 'selftest-live') -and
      ([string]$stIdAfter.Session).Length -gt 0)
    Write-Output ('      identity restore: base=[' + $(if ([string]$stIdBase.CodexThread) { 'thread' } else { '-' }) + $(if ([string]$stIdBase.CodexSession) { '/session' } else { '-' }) +
      '] after=[' + $(if ([string]$stIdAfter.CodexThread) { 'thread' } else { '-' }) + $(if ([string]$stIdAfter.CodexSession) { '/session' } else { '-' }) + '] label-declared=' + [bool][string]$stIdAfter.Label)
    $stIdErrA = Join-Path $OutDir ('st-id-labeled-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.stderr.txt')
    $stIdOutA = $stIdErrA -replace '\.stderr\.txt$', '.stdout.txt'
    $stIdCpA = Start-Process -FilePath 'powershell.exe' -ArgumentList $stIdArgs -RedirectStandardOutput $stIdOutA -RedirectStandardError $stIdErrA -Wait -PassThru -NoNewWindow
    # ReadAllText, not [string](Get-Content -Raw): an EMPTY stderr file is exactly the shape
    # this labeled check is guarding for (silence IS the pass), and PS 5.1's Get-Content -Raw
    # returns $null for an empty file while [string]$null stays $null (null passthrough) -
    # which died on .Contains in the check below on the first labeled run (2026-10-29).
    # ReadAllText returns '' for an empty file, always a real string.
    $stIdErrTxtA = ''
    if (Test-Path -LiteralPath $stIdErrA) { $stIdErrTxtA = [IO.File]::ReadAllText($stIdErrA) }
    ST-Check 'live: a child tool call with the ladder-declared caller label writes no caller-identity warning to stderr (the 2>&1 capture sites stay alive)' (
      ($stIdCpA.ExitCode -eq 0) -and (-not $stIdErrTxtA.Contains('caller identity=unknown')))
    Write-Output ('      child identity probe (labeled): exit=' + $stIdCpA.ExitCode + ' stderr-bytes=' + $stIdErrTxtA.Length)
    $stIdSites = 0
    $stIdNeed = 'Set-StLiveCaller' + 'Identity'
    for ($wsi = $j5ProdStart; $wsi -lt $j5ProdEnd; $wsi++) {
      if ($codeLines[$wsi].Contains($stIdNeed)) { $stIdSites++ }
    }
    ST-Check 'lint: the caller-identity helper is defined once and called exactly twice (unlabeled control first, then the label for every child below)' ($stIdSites -eq 3)
    Write-Output ('      caller-label helper sites: ' + $stIdSites)

    # Skip full-screen phantom windows (the IME host window, Program Manager,
    # the NVIDIA overlay): they are the biggest by area but hold no text of
    # their own, so OCR'ing them proves nothing about a real target.
    $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $real = @($wins | Where-Object { $_.Title -and -not ($_.W -ge $vs.Width -and $_.H -ge $vs.Height) })
    $tgt = if ($real.Count -gt 0) { $real | Sort-Object -Property Area -Descending | Select-Object -First 1 } else { $w0 }
    $ocrOk = $true
    try { $null = Get-OcrEngine } catch { $ocrOk = $false }
    if (-not $ocrOk) {
      ST-Skip 'live: OCR engine unavailable' 'no OCR language pack installed - OCR-backed checks cannot run'
    }
    else {
      $linesL = Invoke-OcrRegion $tgt.Left $tgt.Top $tgt.W $tgt.H
      ST-Check 'live: Invoke-OcrRegion returns ArrayList' ($linesL -is [System.Collections.ArrayList])
      Write-Output "      OCR read $($linesL.Count) line(s) from '$($tgt.Title)' [$($tgt.Proc)]"
      if ($linesL.Count -gt 0) {
        $needle = $linesL[0].Text
        $hitsL = Find-OcrHits $linesL $needle
        ST-Check 'live: needle taken from OCR output is found again' ($hitsL.Count -ge 1)
        ST-Check 'live: hit rect is screen-space and inside the window' (
          $hitsL[0].X -ge $tgt.Left -and $hitsL[0].Y -ge $tgt.Top -and ($hitsL[0].X + $hitsL[0].W) -le $tgt.Right)
        # Whole-window search through the scaled matcher: on a >2200px window
        # this is exactly the path the old hardcoded guard silently skipped.
        $fL = Find-OcrHitsScaled $tgt.Left $tgt.Top $tgt.W $tgt.H $needle
        ST-Check 'live: scaled whole-window search finds the self-OCR needle' ($fL.Hits.Count -ge 1)
        Write-Output "      scaled search on $($tgt.W)x$($tgt.H) window: retried=$($fL.Retried) verdict-from-2x=$($fL.Scaled)"
        # item 12 (WP-3 sidecar): imgclick --dry must land within 2px of the
        # find-text centre for the same control. Capture this window WITH a
        # sidecar, convert the centre into image pixels through the sidecar
        # scale, and let imgclick --dry map it back (<=2px).
        $mapPath = Join-Path $OutDir ('st-map-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.png')
        Invoke-DesktopCommand 'rect' @([string]$tgt.Left, [string]$tgt.Top, [string]$tgt.W, [string]$tgt.H, $mapPath, '--fit', '1400') | Out-Null
        $mapS = Read-MapSidecar $mapPath
        $ccx = $hitsL[0].X + $hitsL[0].W / 2.0
        $ccy = $hitsL[0].Y + $hitsL[0].H / 2.0
        $mix = [int][math]::Round(($ccx - $mapS.OriginX) * $mapS.Scale)
        $miy = [int][math]::Round(($ccy - $mapS.OriginY) * $mapS.Scale)
        if ($mix -ge $mapS.OutW) { $mix = $mapS.OutW - 1 }
        if ($miy -ge $mapS.OutH) { $miy = $mapS.OutH - 1 }
        if ($mix -lt 0) { $mix = 0 }
        if ($miy -lt 0) { $miy = 0 }
        $dryOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath imgclick $mapPath $mix $miy --dry 2>&1 | Out-String
        $dryCode = $LASTEXITCODE
        $mRt = $dryOut -match 'screen \((\d+),(\d+)\)'
        $rtD1 = 9999; $rtD2 = 9999; $rtPt = 'none'
        if ($mRt) {
          $rtD1 = [math]::Abs([int]$Matches[1] - [int]$ccx)
          $rtD2 = [math]::Abs([int]$Matches[2] - [int]$ccy)
          $rtPt = "$($Matches[1]),$($Matches[2])"
        }
        ST-Check 'live: imgclick --dry within 2px of find-text centre (sidecar round-trip)' ($dryCode -eq 0 -and $mRt -and $rtD1 -le 2 -and $rtD2 -le 2)
        Write-Output "      sidecar round-trip: centre=$([int]$ccx),$([int]$ccy) dry=$rtPt delta=$rtD1,$rtD2 px (map=$($mapS.OutW)x$($mapS.OutH) scale=$($mapS.Scale))"
      } else {
        ST-Skip 'live: window self-check needle' 'the largest real window yielded no text'
      }

      # Synthetic-bitmap tiled OCR: the hard evidence that the tiled path
      # reads text at a known position. The canvas is drawn by System.Drawing
      # (deterministic - real-window screenshots change run to run and are
      # explicitly not acceptable for this check), then fed through the tiled
      # bitmap path; the unique probe string must come back with its rect at
      # the drawn position (<= 3px).
      $canvas1 = $null; $canvas2 = $null
      try {
        # Fixed short token (readback-verified exact over many trials): random
        # tails kept attracting OCR slips (confusable digits, inserted spaces
        # and CJK punctuation), and the canvas is memory-only so no anti-stale
        # randomness is needed.
        $probeA = 'TILEDPROBEA'
        $canvas1 = New-Object System.Drawing.Bitmap(2600, 1600)
        $gA = [System.Drawing.Graphics]::FromImage($canvas1)
        $gA.Clear([System.Drawing.Color]::FromArgb(18, 18, 22))
        $fntA = New-Object System.Drawing.Font('Consolas', 11, [System.Drawing.FontStyle]::Regular)
        $brsA = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240, 240, 240))
        # Draw so the INK (not the layout box) starts at (1200,800): the glyph
        # outline offset is measured with the same GDI+ text engine, keeping
        # the <=3px assertion meaningful instead of absorbing font padding.
        $gpA = New-Object System.Drawing.Drawing2D.GraphicsPath
        $gpA.AddString($probeA, $fntA.FontFamily, [int]$fntA.Style, $fntA.Size, (New-Object System.Drawing.PointF(0, 0)), [System.Drawing.StringFormat]::GenericDefault)
        $inkA = $gpA.GetBounds()
        $gA.DrawString($probeA, $fntA, $brsA, [single](1200 - $inkA.X), [single](800 - $inkA.Y))
        $gA.Dispose(); $fntA.Dispose(); $brsA.Dispose()
        $tA = Invoke-OcrBitmapTiled $canvas1 2600 1600 2.0 16 0 0
        # Space-insensitive local match: live readback showed the engine
        # inserts spaces into long letter runs ('DTXPROBEWUUDJ E'), and the
        # tool's matcher preserves English spacing BY DESIGN - the mapping
        # assertion must not flake on that.
        $hA = @($tA.Lines | Where-Object { ($_.Text -replace ' ', '') -like ('*' + $probeA + '*') })
        $synA = ($hA.Count -eq 1 -and $tA.Tiles -ge 1 -and [math]::Abs($hA[0].X - 1200) -le 3 -and [math]::Abs($hA[0].Y - 800) -le 3)
        ST-Check 'live: synthetic bitmap 2600x1600 via tiled OCR - hit + <=3px mapping' $synA
        $rA = 'none'; if ($hA.Count -gt 0) { $rA = "$($hA[0].X),$($hA[0].Y)" }
        Write-Output "      synthetic tiled OCR (2600x1600): tiles=$($tA.Tiles) hits=$($hA.Count) rect=$rA (expect 1200,800) [$probeA]"
        if ($hA.Count -eq 0) { Write-Output ("      tile notes: " + (@($tA.Notes) -join ' ') + " | lines: " + ((@($tA.Lines | Select-Object -First 6 | ForEach-Object { $_.Text })) -join ' / ')) }
        # Same idea, sized so the plan actually SPLITS on this engine's limit.
        # Both probes sit in single-tile zones (b1 left of the overlap, b2
        # right of tile1's reach) so each maps through exactly one tile - the
        # per-tile offset math of BOTH tiles is proven. Fidelity is asserted
        # against a SAME-RUN 1x reference read of the very same canvas: the
        # engine's absolute boxes carry pad/jitter of their own (+1..9px, and
        # on some draw phases a line is reported up to ~90px off even though
        # the image is pixel-verified - all measured live), so absolute-vs-ink
        # comparisons bounce on engine noise instead of testing OUR transform.
        # mapped-vs-reference isolates the split/upscale/map math (the <=3px
        # clause) and cancels the pad. Draw phases below are live-verified
        # deterministic (3/3 runs, deltas (-1,0) and (-1,-1)).
        $dimSyn = 0L; try { $dimSyn = Get-OcrMaxDimension } catch { $dimSyn = 0L }
        if ($dimSyn -le 0) { $dimSyn = 4000L }
        $multiW = [int]([math]::Floor($dimSyn / 2.0)) + 1200
        $pb1x = 602; $pb1y = 803
        $pb2x = 5300; $pb2y = 800
        $probeB1 = 'TILEDPROBEA'
        $probeB2 = 'TILEDPROBEB'
        $canvas2 = New-Object System.Drawing.Bitmap($multiW, 1600)
        $gB = [System.Drawing.Graphics]::FromImage($canvas2)
        $gB.Clear([System.Drawing.Color]::FromArgb(18, 18, 22))
        $fntB = New-Object System.Drawing.Font('Consolas', 16, [System.Drawing.FontStyle]::Regular)
        $brsB = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240, 240, 240))
        $gpB1 = New-Object System.Drawing.Drawing2D.GraphicsPath
        $gpB1.AddString($probeB1, $fntB.FontFamily, [int]$fntB.Style, $fntB.Size, (New-Object System.Drawing.PointF(0, 0)), [System.Drawing.StringFormat]::GenericDefault)
        $inkB1 = $gpB1.GetBounds()
        $gpB2 = New-Object System.Drawing.Drawing2D.GraphicsPath
        $gpB2.AddString($probeB2, $fntB.FontFamily, [int]$fntB.Style, $fntB.Size, (New-Object System.Drawing.PointF(0, 0)), [System.Drawing.StringFormat]::GenericDefault)
        $inkB2 = $gpB2.GetBounds()
        $gB.DrawString($probeB1, $fntB, $brsB, [single]($pb1x - $inkB1.X), [single]($pb1y - $inkB1.Y))
        $gB.DrawString($probeB2, $fntB, $brsB, [single]($pb2x - $inkB2.X), [single]($pb2y - $inkB2.Y))
        $gB.Dispose(); $fntB.Dispose(); $brsB.Dispose()
        # v2.9.0 - the reference is the SAME TILE cropped and read at 1x, not the whole
        # canvas. The old shape compared a 2x-upscaled tile against a whole-canvas 1x read,
        # and on this machine the engine moves line boxes by tens of pixels on tiles whose
        # upscaled size sits exactly at MaxImageDimension (measured: Y off 53px, X off 1px -
        # identical on two consecutive rounds and on the pre-change HEAD, so it was neither
        # flaky nor ours). That assertion was measuring the engine's geometry while claiming
        # to measure our mapping math, and the only way it could react was going red on a
        # round where nothing of ours was wrong. Both sides now come from one tile and the
        # 3px tolerance stays; the whole-canvas delta is REPORTED as engine-jitter= so drift
        # is visible without being a gate.
        $refB = Invoke-OcrBitmap $canvas2
        $rB1 = @($refB.Lines | Where-Object { ($_.Text -replace ' ', '') -like ('*' + $probeB1 + '*') })
        $rB2 = @($refB.Lines | Where-Object { ($_.Text -replace ' ', '') -like ('*' + $probeB2 + '*') })
        $tB = Invoke-OcrBitmapTiled $canvas2 $multiW 1600 2.0 16 0 0
        $hB1 = @($tB.Lines | Where-Object { ($_.Text -replace ' ', '') -like ('*' + $probeB1 + '*') })
        $hB2 = @($tB.Lines | Where-Object { ($_.Text -replace ' ', '') -like ('*' + $probeB2 + '*') })
        $synMaxDim = 0
        try { $synMaxDim = Get-OcrMaxDimension } catch { $synMaxDim = 0 }
        $synPlan = Get-OcrTilePlan $multiW 1600 2.0 $synMaxDim 64 16
        $tileRef = @{}
        $tileRefErr = ''
        foreach ($pd in @(@{ N = $probeB1; X = $pb1x; Y = $pb1y }, @{ N = $probeB2; X = $pb2x; Y = $pb2y })) {
          $ht = $null
          foreach ($tl in @($synPlan.Tiles)) {
            if ($pd.X -ge $tl.X -and $pd.X -lt ($tl.X + $tl.W) -and $pd.Y -ge $tl.Y -and $pd.Y -lt ($tl.Y + $tl.H)) { $ht = $tl; break }
          }
          if ($null -eq $ht) { $tileRefErr += "no-tile-for-$($pd.N) "; continue }
          $tcrop = $canvas2.Clone((New-Object System.Drawing.Rectangle($ht.X, $ht.Y, $ht.W, $ht.H)), $canvas2.PixelFormat)
          $tl2 = @()
          try { $tl2 = @((Invoke-OcrBitmap $tcrop).Lines) } finally { $tcrop.Dispose() }
          $th = @($tl2 | Where-Object { ($_.Text -replace ' ', '') -like ('*' + $pd.N + '*') })
          if ($th.Count -ne 1) { $tileRefErr += "$($pd.N) crop-hits=$($th.Count) "; continue }
          $tileRef[$pd.N] = @{ X = ($ht.X + [int]$th[0].X); Y = ($ht.Y + [int]$th[0].Y) }
        }
        # >=2 tiles, both probes found in the merged result, and each mapped 2x rect within
        # 3px of its OWN TILE's 1x read - per axis, strictly.
        $synB = ($tB.Tiles -ge 2) -and (-not $synPlan.Error) -and ($tileRefErr -eq '') -and
          ($hB1.Count -eq 1) -and ($hB2.Count -eq 1) -and
          [bool]($tileRef.ContainsKey($probeB1)) -and [bool]($tileRef.ContainsKey($probeB2)) -and
          [math]::Abs($hB1[0].X - $tileRef[$probeB1].X) -le 3 -and [math]::Abs($hB1[0].Y - $tileRef[$probeB1].Y) -le 3 -and
          [math]::Abs($hB2[0].X - $tileRef[$probeB2].X) -le 3 -and [math]::Abs($hB2[0].Y - $tileRef[$probeB2].Y) -le 3
        ST-Check 'live: synthetic split - >=2 tiles, mapped reads within 3px of the SAME TILE read at 1x (engine jitter reported, not asserted)' $synB
        $sB1 = 'none'; if ($hB1.Count -gt 0) { $sB1 = "$($hB1[0].X),$($hB1[0].Y)" }
        $sB2 = 'none'; if ($hB2.Count -gt 0) { $sB2 = "$($hB2[0].X),$($hB2[0].Y)" }
        $sR1 = 'none'; if ($rB1.Count -gt 0) { $sR1 = "$($rB1[0].X),$($rB1[0].Y)" }
        $sR2 = 'none'; if ($rB2.Count -gt 0) { $sR2 = "$($rB2[0].X),$($rB2[0].Y)" }
        $sT1 = 'none'; if ($tileRef.ContainsKey($probeB1)) { $sT1 = "$($tileRef[$probeB1].X),$($tileRef[$probeB1].Y)" }
        $sT2 = 'none'; if ($tileRef.ContainsKey($probeB2)) { $sT2 = "$($tileRef[$probeB2].X),$($tileRef[$probeB2].Y)" }
        # reported, NOT asserted: how far the merged tiled read sits from a whole-canvas 1x
        # read. This is the engine's own box placement on limit-sized tiles.
        $jit1 = 'n/a'; if ($hB1.Count -eq 1 -and $rB1.Count -eq 1) { $jit1 = "$([math]::Abs($hB1[0].X - $rB1[0].X))/$([math]::Abs($hB1[0].Y - $rB1[0].Y))px" }
        $jit2 = 'n/a'; if ($hB2.Count -eq 1 -and $rB2.Count -eq 1) { $jit2 = "$([math]::Abs($hB2[0].X - $rB2[0].X))/$([math]::Abs($hB2[0].Y - $rB2[0].Y))px" }
        Write-Output "      synthetic tiled OCR (${multiW}x1600): tiles=$($tB.Tiles) plan=$($synPlan.Count) mapped1=$sB1 tileRef1=$sT1 whole1=$sR1 engine-jitter1=$jit1"
        Write-Output "      synthetic tiled OCR probe2: mapped2=$sB2 tileRef2=$sT2 whole2=$sR2 engine-jitter2=$jit2 (jitter is reported, not asserted - see the comment above)"
        if ($tileRefErr) { Write-Output "      tile reference problem: $tileRefErr" }
        if (-not $synB) {
          Write-Output "      DEBUG split failure: tiles=$($tB.Tiles) planErr='$($synPlan.Error)' hB1=$($hB1.Count) hB2=$($hB2.Count) tileRefErr='$tileRefErr'"
          Write-Output "      DEBUG merged tiled lines ($($tB.Lines.Count)):"
          $tB.Lines | Select-Object -First 12 | ForEach-Object { Write-Output "        [$($_.Text)] X=$($_.X) Y=$($_.Y) W=$($_.W) H=$($_.H)" }
          Write-Output "      DEBUG reference lines ($($refB.Lines.Count)):"
          $refB.Lines | Select-Object -First 8 | ForEach-Object { Write-Output "        [$($_.Text)] X=$($_.X) Y=$($_.Y)" }
        }
      } finally {
        if ($null -ne $canvas1) { $canvas1.Dispose() }
        if ($null -ne $canvas2) { $canvas2.Dispose() }
      }

      # Big-window retry lock + --no-tile contrast (miss needle): the
      # v1.3.1-v1.4.1 bug silently skipped the retry on big windows
      # (Retried stayed false and nothing said so). No window on this display
      # can exceed maxDim/2 at the probed limit, so the lock asserts the
      # retry ACTIVATES on the largest real window; --no-tile must match the
      # v1.4.1 decision exactly (never tiled; single 2x only when it fits).
      $absent9 = 'DTXABSENT-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
      $dim9 = 0L; try { $dim9 = Get-OcrMaxDimension } catch { $dim9 = 0L }
      $fits9 = Test-OcrRetryFits $tgt.W $tgt.H $dim9
      $fBig = Find-OcrHitsScaled $tgt.Left $tgt.Top $tgt.W $tgt.H $absent9 'auto' 16 $false
      ST-Check 'live: big-window miss still retried (Retried=true - no silent skip)' ($fBig.Retried -eq $true -and $fBig.Tiled -eq (-not $fits9))
      Write-Output "      retry lock on $($tgt.W)x$($tgt.H) (maxDim=$dim9): fits=$fits9 retried=$($fBig.Retried) tiled=$($fBig.Tiled)"
      $fNT = Find-OcrHitsScaled $tgt.Left $tgt.Top $tgt.W $tgt.H $absent9 'auto' 16 $true
      ST-Check 'live: --no-tile matches v1.4.1 decision (never tiled, retry == fits)' ((-not $fNT.Tiled) -and ($fNT.Retried -eq $fits9))
      Write-Output "      --no-tile contrast: fits=$fits9 retried=$($fNT.Retried) tiled=$($fNT.Tiled)"

      # Expect family exit codes + message split, against a probe window THIS
      # test owns (no user app involved): one click must verify (exit 0,
      # "+ verified"), one must fail loudly (exit 1, "clicked OK but
      # expectation NOT met").
      $staleP = Resolve-Window 'DTX-ExpectProbe'
      if ($staleP) {
        [void][DT]::PostMessage($staleP.Handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 400
      }
      $probeScript = Join-Path $env:TEMP ('dtx-probe-' + [guid]::NewGuid().ToString('N') + '.ps1')
      $probeProc = $null
      try {
        # Constant label with no random tail: OCR inserts spaces into LONG
        # letter runs (live readback: 'DTXPROBEWUUDJ E'), and the tool's
        # matcher preserves English spacing by design - an 8-char run reads
        # cleanly every time. Freshness comes from closing any stale probe
        # window before spawning.
        $safeP = 'ACDEFHJKLMNPRTUVWXY'
        $randP = ''
        1..6 | ForEach-Object { $randP += $safeP[(Get-Random -Maximum $safeP.Length)] }
        $labelText = 'DTXPROBE'
        $pSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-ExpectProbe'
$f.ClientSize = New-Object System.Drawing.Size(460, 240)
$f.StartPosition = 'CenterScreen'
$f.TopMost = $true
$f.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 40)
$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = 'LABELTEXT'
$lbl.ForeColor = [System.Drawing.Color]::White
$lbl.Font = New-Object System.Drawing.Font('Consolas', 22, [System.Drawing.FontStyle]::Bold)
$lbl.AutoSize = $true
$lbl.Location = New-Object System.Drawing.Point(30, 40)
$f.Controls.Add($lbl)
[System.Windows.Forms.Application]::Run($f)
'@
        [System.IO.File]::WriteAllText($probeScript, $pSrc.Replace('LABELTEXT', $labelText), (New-Object System.Text.UTF8Encoding($false)))
        $probeProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $probeScript -PassThru
        $pw2 = $null
        $swP = [System.Diagnostics.Stopwatch]::StartNew()
        while ($swP.Elapsed.TotalSeconds -lt 15) {
          $pw2 = Resolve-Window 'DTX-ExpectProbe'
          if ($pw2) { break }
          Start-Sleep -Milliseconds 400
        }
        if ($null -eq $pw2) { throw 'expect-probe window did not appear within 15s' }
        Start-Sleep -Milliseconds 600
        [void][DT]::SetForegroundWindow($pw2.Handle)
        Start-Sleep -Milliseconds 200
        $cpx = [int]($pw2.Left + $pw2.W / 2)
        $cpy = [int]($pw2.Top + $pw2.H - 60)
        $outOk = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath click $cpx $cpy --to 'DTX-ExpectProbe' --expect $labelText --timeout 6 2>&1 | Out-String
        $codeOk = $LASTEXITCODE
        # "self-reported value" (v1.5.7): the two calls pass DIFFERENT --timeout values, so demanding the
        # printed patience match each one is what proves the flag reached the loop - an echo of
        # elapsed time alone cannot tell a honoured --timeout 2 from a silently ignored one.
        $okPatience = ($outOk -match 'patience 6s, polled every [0-9]+ ms')
        ST-Check 'live: expect satisfied -> exit 0 + verified, naming the 6s patience it used' (
          ($codeOk -eq 0) -and ($outOk -match '\+ verified in') -and $okPatience)
        Write-Output "      expect probe: satisfied-exit=$codeOk patience-named=$okPatience label=$labelText"
        Write-Output ("      satisfied-output: " + (($outOk.Trim() -split "`r?`n" | Select-Object -First 4) -join ' | '))
        $absentP = 'DTXABSENT' + $randP
        $outBad = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath click $cpx $cpy --to 'DTX-ExpectProbe' --expect $absentP --timeout 2 2>&1 | Out-String
        $codeBad = $LASTEXITCODE
        $badPatience = ($outBad -match 'after [0-9.]+s of 2s') -and ($outBad -match 'patience 2s')
        ST-Check 'live: expect unsatisfied -> exit 1 + action/assertion split message naming the 2s patience' (
          (($codeBad -eq 1) -and ($outBad -match 'clicked OK but expectation NOT met')) -and $badPatience)
        Write-Output "      expect probe: unsatisfied-exit=$codeBad patience-named=$badPatience"
        Write-Output ("      unsatisfied-output: " + (($outBad.Trim() -split "`r?`n" | Select-Object -First 4) -join ' | '))
        # R-06: after CU-REL-03 a wheel call needs an explicit x/y scroll point with --at - the old
        # no-coordinate call is refused before any input. Effect is deliberately NOT claimed here:
        # this row proves the refusal path AND exactly one delivered event whose receipt names the
        # scroll point and the window actually under it. Only package B's own fixture reads effect.
        $outWheelNoXY = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath wheel -3 --at 'DTX-ExpectProbe' 2>&1 | Out-String
        $codeWheelNoXY = $LASTEXITCODE
        $wheelGuardOk = ($codeWheelNoXY -ne 0) -and ($outWheelNoXY -match 'requires explicit x y coordinates') -and
          (-not ($outWheelNoXY -match 'SendInput-inserted=1/1'))
        $outWheel = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath wheel -3 $cpx $cpy --at 'DTX-ExpectProbe' 2>&1 | Out-String
        $codeWheel = $LASTEXITCODE
        $wheelSelfReport = ($outWheel -match 'wheel -3 ') -and ($outWheel -match 'SendInput-inserted=1/1') -and
          ($outWheel -match ('scroll-point=\(' + $cpx + ',' + $cpy + '\)')) -and
          ($outWheel -match 'target-check=matched via --at hwnd=') -and
          ($outWheel -match ('observed-before-injection=pid=' + [regex]::Escape("$($pw2.Pid)"))) -and
          ($outWheel -match "title='DTX-ExpectProbe'") -and
          ($outWheel -match 'effect=not-verified') -and (-not ($outWheel -match 'delivered to hwnd='))
        ST-Check 'live: wheel without coordinates is refused pre-input, then one event lands on the named scroll point and window (effect not verified)' (
          $wheelGuardOk -and ($codeWheel -eq 0) -and $wheelSelfReport)
        Write-Output "      wheel probe: guard-refused=$wheelGuardOk exit=$codeWheel self-report=$wheelSelfReport"
        Write-Output ("      wheel-no-coordinate-output: " + (($outWheelNoXY.Trim() -split "`r?`n" | Select-Object -First 2) -join ' | '))
        Write-Output ("      wheel-output: " + (($outWheel.Trim() -split "`r?`n" | Select-Object -First 2) -join ' | '))
        # v1.7.0 (J-07 A, "do not lose" #2): win-close must REALLY remove the window -
        # close it via the tool, then 'wins' must no longer list that pid.
        $outClose = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath win-close 'DTX-ExpectProbe' 2>&1 | Out-String
        $codeClose = $LASTEXITCODE
        Start-Sleep -Milliseconds 800
        $winsAfter = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath wins 2>&1 | Out-String
        $gonePat = 'pid=' + $probeProc.Id + '\s'
        $stillListed = ($winsAfter -match $gonePat)
        ST-Check 'live: win-close removes the target - wins no longer lists that pid (J-07 contract)' (
          ($codeClose -eq 0) -and (-not $stillListed))
        Write-Output "      win-close contract: close-exit=$codeClose wins-still-lists-pid=$stillListed"
      } catch {
        ST-Check 'live: expect probe setup+run' $false
        Write-Output "      expect probe error: $($_.Exception.Message)"
      } finally {
        if ($probeProc -and -not $probeProc.HasExited) { try { Stop-Process -Id $probeProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        if (Test-Path -LiteralPath $probeScript) { Remove-Item -LiteralPath $probeScript -Force -ErrorAction SilentlyContinue }
      }

      # ---------- live: v1.9.0 popup survival guard end-to-end (T-1..T-4) ----------
      # Fixture: a per-run owned window (DTXP-M-<tag>) spawns an OWNED popup (DTXP-P-<tag>)
      # when clicked - real windows, tool-owned, never a real app's flaky popup. mode=fuse
      # closes the popup only when THIS test writes a marker file, and only after the test
      # has seen the guard's arming line; mode=keep leaves it alive for the control run and
      # the win-close dismissal path.
      # X-02 residual (v4.1.1): see the chProc note - this block reads $script:pgProc in its
      # finally (and the inner finally re-reads it), while the real initialiser sat INSIDE the
      # try, so a throw before it left the outer finally reading an unassigned variable.
      $script:pgProc = $null
      $pgTmp = New-Object System.Collections.ArrayList
      try {
        # OPS-7: every fixture window now carries a PER-RUN tag in its title, so
        # the old "kill whatever is named DTX-PGMain/DTX-PGPopup" sweep is gone - it could
        # take another run's fixture down and made cleanup a claim about OTHER processes.
        # Identity is the fixture's own PID, and the only thing finally may stop is that PID.
        $pgScript = Join-Path $env:TEMP ('dtx-pg-' + [guid]::NewGuid().ToString('N') + '.ps1')
        [void]$pgTmp.Add($pgScript)
        $pgSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HXPG {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[void][HXPG]::SetProcessDPIAware()
$mode = if ($args.Count -ge 1) { [string]$args[0] } else { 'keep' }
$mainTitle = if ($args.Count -ge 2) { [string]$args[1] } else { 'DTXP-M' }
$popupTitle = if ($args.Count -ge 3) { [string]$args[2] } else { 'DTXP-P' }
$closeFlag = if ($args.Count -ge 4) { [string]$args[3] } else { '' }
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$main = New-Object System.Windows.Forms.Form
$main.Text = $mainTitle
$main.ClientSize = New-Object System.Drawing.Size(300, 180)
$main.StartPosition = 'Manual'
$main.Location = New-Object System.Drawing.Point(80, [int]($wa.Height - 260))
$main.TopMost = $true
$script:popup = $null
$script:waited = 0
$main.Add_MouseClick({
  param($s, $e)
  if ($null -ne $script:popup) { return }
  $p = New-Object System.Windows.Forms.Form
  $p.Text = $popupTitle
  $p.ClientSize = New-Object System.Drawing.Size(220, 120)
  $p.StartPosition = 'Manual'
  $p.Location = New-Object System.Drawing.Point(($s.Location.X + 330), $s.Location.Y)
  $p.TopMost = $true
  $s.AddOwnedForm($p)
  $p.Show()
  $script:popup = $p
  if ($mode -eq 'fuse' -and $closeFlag -ne '') {
    # OPS-7: the popup closes ONLY on the test's marker file, and the wait is
    # bounded (200 ticks x 100ms). No wall-clock self-destruct: the close cannot beat the
    # arming step, so "gone before require-popup" is not a timing accident any more.
    $t = New-Object System.Windows.Forms.Timer
    $t.Interval = 100
    $t.Add_Tick({
      param($ts, $te)
      $script:waited++
      if ([System.IO.File]::Exists($closeFlag)) {
        $ts.Stop()
        if ($null -ne $script:popup) { $script:popup.Close(); $script:popup = $null }
        return
      }
      if ($script:waited -ge 200) { $ts.Stop() }
    })
    $t.Start()
  }
})
[System.Windows.Forms.Application]::Run($main)
'@
        [System.IO.File]::WriteAllText($pgScript, $pgSrc, (New-Object System.Text.UTF8Encoding($false)))
        # spawn / run / stop are separate phases: the click coordinates must come from
        # the RESOLVED physical rect of the spawned window (150% scaling - a fixture
        # without SetProcessDPIAware parks its windows at virtualized coordinates and
        # the click lands on the desktop instead; measured in the first live run).
        $script:pgProc = $null
        $pgSpawn = {
          param($mode, $tag)
          $pgMainTitle = 'DTXP-M-' + $tag
          $pgPopupTitle = 'DTXP-P-' + $tag
          $pgFlag = Join-Path $env:TEMP ('dtx-pg-' + [guid]::NewGuid().ToString('N') + '.close')
          [void]$pgTmp.Add($pgFlag)
          $pgArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $pgScript, $mode, $pgMainTitle, $pgPopupTitle, $pgFlag)
          $script:pgProc = Start-Process powershell -ArgumentList $pgArgs -PassThru
          $pgWantPid = $script:pgProc.Id
          $pgMain = $null
          $swPg = [System.Diagnostics.Stopwatch]::StartNew()
          while ($swPg.Elapsed.TotalSeconds -lt 15) {
            $pgMain = Resolve-Window $pgMainTitle
            if ($pgMain -and ($pgMain.Pid -eq $pgWantPid)) { break }
            Start-Sleep -Milliseconds 300
          }
          if ($null -eq $pgMain) { throw "popup-guard fixture ($tag) did not appear within 15s" }
          if ($pgMain.Pid -ne $pgWantPid) { throw "popup-guard fixture ($tag): resolved pid=$($pgMain.Pid) is not the fixture pid=$pgWantPid" }
          Start-Sleep -Milliseconds 400
          return @{ Main = $pgMain; Popup = $pgPopupTitle; Flag = $pgFlag; Pid = $pgWantPid }
        }
        $pgStop = {
          if ($script:pgProc -and -not $script:pgProc.HasExited) { try { Stop-Process -Id $script:pgProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
          $script:pgProc = $null
        }
        $pgScriptRun = {
          param($stepsJson)
          $pgSteps = Join-Path $env:TEMP ('dtx-pg-' + [guid]::NewGuid().ToString('N') + '.json')
          [void]$pgTmp.Add($pgSteps)
          [System.IO.File]::WriteAllText($pgSteps, $stepsJson, (New-Object System.Text.UTF8Encoding($false)))
          $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath script $pgSteps 2>&1 | Out-String
          return @{ Out = $out; Code = $LASTEXITCODE }
        }
        # OPS-7: T-1's close has to be written by THIS process while the child script
        # is still running, so that run is started in the background and its stdout/stderr are
        # read back from files. The exit code is the child's own, never $LASTEXITCODE of a pipe.
        $pgScriptRunAsync = {
          param($stepsJson)
          $pgSteps = Join-Path $env:TEMP ('dtx-pg-' + [guid]::NewGuid().ToString('N') + '.json')
          [void]$pgTmp.Add($pgSteps)
          [System.IO.File]::WriteAllText($pgSteps, $stepsJson, (New-Object System.Text.UTF8Encoding($false)))
          $pgSo = Join-Path $env:TEMP ('dtx-pg-' + [guid]::NewGuid().ToString('N') + '.out')
          $pgSe = Join-Path $env:TEMP ('dtx-pg-' + [guid]::NewGuid().ToString('N') + '.err')
          [void]$pgTmp.Add($pgSo)
          [void]$pgTmp.Add($pgSe)
          # The child runs under cmd with delayed expansion so its own ERRORLEVEL is echoed
          # into the capture file: a bounded WaitForExit on a redirected child can surface
          # 0 even when the child ended with exit 1 (measured on the popup-abort path).
          # The echo is the ground truth here; the process object is only the fallback.
          $pgLine = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $script:ToolEntryPath + '" script "' + $pgSteps + '" & echo EXITCODE=!ERRORLEVEL!'
          $pgPr = Start-Process cmd -ArgumentList @('/v:on', '/c', $pgLine) -RedirectStandardOutput $pgSo -RedirectStandardError $pgSe -PassThru -WindowStyle Hidden
          return @{ Proc = $pgPr; OutFile = $pgSo; ErrFile = $pgSe }
        }
        $pgAwaitAsync = {
          param($a, $boundSec)
          if (-not $a.Proc.WaitForExit([int]($boundSec * 1000))) {
            try { Stop-Process -Id $a.Proc.Id -Force -ErrorAction SilentlyContinue } catch { }
            return @{ TimedOut = $true; Code = -1; Out = '' }
          }
          # A bounded WaitForExit returns once the process has exited, but with redirected
          # streams the exit code is only guaranteed after the unbounded call (which also
          # drains the async readers). Read it only after that, and refresh the handle.
          try { $a.Proc.WaitForExit() } catch { }
          try { $a.Proc.Refresh() } catch { }
          $pgO = if (Test-Path -LiteralPath $a.OutFile) { [System.IO.File]::ReadAllText($a.OutFile) } else { '' }
          $pgE = if (Test-Path -LiteralPath $a.ErrFile) { [System.IO.File]::ReadAllText($a.ErrFile) } else { '' }
          $pgCode = [int]$a.Proc.ExitCode
          if ($pgO -match 'EXITCODE=(\d+)') { $pgCode = [int]$Matches[1] }
          return @{ TimedOut = $false; Code = $pgCode; Out = ($pgO + $pgE) }
        }
        # T-1: the popup opens, is guarded alive, and THIS test closes it only after it has
        # SEEN the arming line in actions.log (bounded poll, 15s). The close is armed->close
        # by evidence, not by a wall clock: a slow arm cannot be outrun, and the marker is
        # never written before the guard exists.
        $fi1 = & $pgSpawn 'fuse' ([guid]::NewGuid().ToString('N').Substring(0, 8))
        $cx = [int]($fi1.Main.Left + $fi1.Main.W / 2)
        $cy = [int]($fi1.Main.Top + $fi1.Main.H / 2)
        $t1Json = '[{"click":[' + $cx + ',' + $cy + ']},{"sleep":150},{"require-popup":"' + $fi1.Popup + '","tolerance":3},{"sleep":1500},{"assert-window":"' + $fi1.Popup + '"}]'
        $t1a = & $pgScriptRunAsync $t1Json
        $t1Armed = $false
        $swArm = [System.Diagnostics.Stopwatch]::StartNew()
        while ($swArm.Elapsed.TotalSeconds -lt 15) {
          if (Test-Path -LiteralPath $ActionLog) {
            $lg = [System.IO.File]::ReadAllText($ActionLog)
            if ($lg.Contains("popup guard armed at step 3 (pid=$($fi1.Pid) ")) { $t1Armed = $true; break }
          }
          Start-Sleep -Milliseconds 100
        }
        if ($t1Armed) { [System.IO.File]::WriteAllText($fi1.Flag, 'close', (New-Object System.Text.UTF8Encoding($false))) }
        $t1 = & $pgAwaitAsync $t1a 20
        & $pgStop
        $t1Shape = $t1Armed -and ($t1.Out -match 'popup guard: popup GONE') -and ($t1.Out -match 'before step 5 of 5') -and
          ($t1.Out -match '  baseline: pid=') -and ($t1.Out -match '  now     : ') -and ($t1.Out -match '  delta   : ') -and
          ($t1.Out -match 'script aborted: popup guard failed \(nothing after this step ran\)') -and
          ($t1.Out -match 'armed at step 3 ') -and (-not ($t1.Out -match '#5 assert-window FAIL'))
        ST-Check 'live: T-1 a self-closing popup aborts the rest of the script with baseline/now/delta echoed, nothing after it runs' (
          ($t1.Code -eq 1) -and $t1Shape)
        Write-Output "      T-1 exit=$($t1.Code) shape=$t1Shape armed-observed=$t1Armed timedout=$($t1.TimedOut)"
        Write-Output ("      T-1 output: " + (($t1.Out.Trim() -split "`r?`n" | Where-Object { $_ -match 'popup guard|baseline|now|delta|aborted' } | Select-Object -First 6) -join ' | '))
        # T-4: the aborted run left its marker in actions.log - replay must refuse the
        # slice that carries it (dry run included; no --force backdoor exists).
        $t4Out = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath replay --last 6 2>&1 | Out-String
        $t4Code = $LASTEXITCODE
        ST-Check 'live: T-4 replay of an aborted-by-the-popup-guard run is refused by default' (
          ($t4Code -eq 1) -and ($t4Out -match 'refusing to replay a script that was aborted by the popup guard'))
        Write-Output "      T-4 exit=$t4Code refused=$($t4Out -match 'refusing to replay')"
        # T-2 (control): the same shape with a popup that STAYS - the script must run to
        # completion, arm at step 3 and release at step 5, exit 0 (no false red).
        $fi2 = & $pgSpawn 'keep' ([guid]::NewGuid().ToString('N').Substring(0, 8))
        $cx2 = [int]($fi2.Main.Left + $fi2.Main.W / 2)
        $cy2 = [int]($fi2.Main.Top + $fi2.Main.H / 2)
        $t2Json = '[{"click":[' + $cx2 + ',' + $cy2 + ']},{"sleep":150},{"require-popup":"' + $fi2.Popup + '","tolerance":3},{"assert-window":"' + $fi2.Popup + '"},{"release-popup":""},{"assert-window":"' + $fi2.Main.Title + '"}]'
        $t2 = & $pgScriptRun $t2Json
        & $pgStop
        $t2Ok = ($t2.Code -eq 0) -and ($t2.Out -match 'armed at step 3 ') -and ($t2.Out -match 'popup guard: released at step 5') -and ($t2.Out -match '6 steps, all ok')
        ST-Check 'live: T-2 a popup alive throughout runs to completion and releases cleanly (exit 0, no false red)' ($t2Ok)
        Write-Output "      T-2 exit=$($t2.Code) ok=$t2Ok"
        Write-Output ("      T-2 output: " + (($t2.Out.Trim() -split "`r?`n" | Where-Object { $_ -match 'popup guard|FAIL|aborted|steps,' } | Select-Object -First 6) -join ' | '))
        # T-4 negative control: a slice WITHOUT an abort marker must replay (the gate
        # bites only aborted runs, not every guarded script). --last 3 = the click line
        # plus the two markers of the successful T-2 run: one replayable job, no marker.
        $t4bOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath replay --last 3 2>&1 | Out-String
        $t4bCode = $LASTEXITCODE
        ST-Check 'live: T-4 negative - a successful run leaves no abort marker, its slice still replays (the gate bites only abort markers)' (
          ($t4bCode -eq 0) -and ($t4bOut -match 'WOULD'))
        Write-Output "      T-4n exit=$t4bCode would-list=$($t4bOut -match 'WOULD')"
        # T-3: the script's OWN win-close of the guarded popup is a legal dismissal -
        # auto-release with a notice, then later steps keep running (exit 0).
        $fi3 = & $pgSpawn 'keep' ([guid]::NewGuid().ToString('N').Substring(0, 8))
        $cx3 = [int]($fi3.Main.Left + $fi3.Main.W / 2)
        $cy3 = [int]($fi3.Main.Top + $fi3.Main.H / 2)
        $t3Json = '[{"click":[' + $cx3 + ',' + $cy3 + ']},{"sleep":150},{"require-popup":"' + $fi3.Popup + '","tolerance":3},{"win-close":"' + $fi3.Popup + '"},{"assert-window":"' + $fi3.Main.Title + '"}]'
        $t3 = & $pgScriptRun $t3Json
        & $pgStop
        $t3Ok = ($t3.Code -eq 0) -and ($t3.Out -match 'popup guard: released at step 4 \(win-close closed the guarded popup\)') -and ($t3.Out -match '5 steps, all ok')
        ST-Check 'live: T-3 the script closing its own guarded popup via win-close auto-releases and continues (no false red)' ($t3Ok)
        Write-Output "      T-3 exit=$($t3.Code) ok=$t3Ok"
        Write-Output ("      T-3 output: " + (($t3.Out.Trim() -split "`r?`n" | Where-Object { $_ -match 'popup guard|FAIL|aborted|steps,' } | Select-Object -First 6) -join ' | '))
      } catch {
        ST-Check 'live: popup guard setup+run' $false
        Write-Output "      popup guard error: $($_.Exception.Message)"
      } finally {
        # OPS-7: cleanup is identity-based only. The fixture windows die with the
        # fixture PID, so this stops that PID and nothing else - there is no title sweep left
        # that could kill another run's fixture.
        if ($script:pgProc -and -not $script:pgProc.HasExited) { try { Stop-Process -Id $script:pgProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        foreach ($f in $pgTmp) { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue } }
      }

      # ---------- live: v2.0.1 P-3 drag mid-state (press-down / drag-to / press-up + the three watchdogs) ----------
      # Fixture: one plain DTX window. Every press is computed from ITS rect, and the
      # CLI half passes --to, so the hit-window guard refuses any point outside that
      # window - the red line "act judgements only hit tool-made DTX-* windows" is
      # enforced by the tool, not by this comment.
      $p3Proc = $null; $p3Child = $null
      $p3Tmp = New-Object System.Collections.ArrayList
      $p3Ids = New-Object System.Collections.ArrayList
      # v2.2.0 (P3-6 reverse direction): remember how many audit lines exist BEFORE this block
      # runs, so the reverse check can only see pairings this round opened. A tail window alone
      # cannot do that - the first round of the reverse check called eleven 'orphans' that were
      # simply the previous round's presses.
      $p3LogStart = 0
      try { $p3LogStart = @(Get-Content -LiteralPath $ActionLog -Encoding UTF8 -ErrorAction SilentlyContinue).Count } catch { }
      try {
        $p3Old = Resolve-Window 'DTX-PressProbe'
        if ($p3Old) { try { Stop-Process -Id $p3Old.Pid -Force -ErrorAction SilentlyContinue } catch { }; Start-Sleep -Milliseconds 500 }
        $p3Script = Join-Path $env:TEMP ('dtx-press-' + [guid]::NewGuid().ToString('N') + '.ps1')
        [void]$p3Tmp.Add($p3Script)
        $p3Src = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HXP3 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[void][HXP3]::SetProcessDPIAware()
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-PressProbe held=0 up=0'
$f.ClientSize = New-Object System.Drawing.Size(420, 240)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(60, 1500)
$f.TopMost = $true
$script:held = 0
$script:ups = 0
$f.Add_MouseMove({
  param($s, $e)
  if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
    $script:held++
    $s.Text = 'DTX-PressProbe held=' + $script:held + ' up=' + $script:ups
  }
})
$f.Add_MouseUp({
  param($s, $e)
  if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
    $script:ups++
    $s.Text = 'DTX-PressProbe held=' + $script:held + ' up=' + $script:ups
  }
})
[System.Windows.Forms.Application]::Run($f)
'@
        [System.IO.File]::WriteAllText($p3Script, $p3Src, (New-Object System.Text.UTF8Encoding($false)))
        $p3Proc = Start-Process -FilePath powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $p3Script) -PassThru
        $p3Sw = [System.Diagnostics.Stopwatch]::StartNew()
        $p3Win = $null
        while ($p3Sw.Elapsed.TotalSeconds -lt 15) { $p3Win = Resolve-Window 'DTX-PressProbe'; if ($p3Win) { break }; Start-Sleep -Milliseconds 400 }
        if ($null -eq $p3Win) { throw 'press-probe window did not appear within 15s' }
        Start-Sleep -Milliseconds 600
        $p3X = [int]($p3Win.Left + $p3Win.W / 2)
        $p3Y = [int]($p3Win.Top + [int]($p3Win.H / 2))

        # P3-1 watchdog 1 OBSERVED: the child holds the button, its own deadline lets
        # go. The echo must carry the measured state (not the requested one) and the
        # parent must see the button genuinely up afterwards.
        $p3aOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath press-down $p3X $p3Y --to 'DTX-PressProbe' --max-hold 2000 2>&1 | Out-String
        $p3aEcho = ($p3aOut -match 'button is DOWN at \(') -and ($p3aOut -match 'measured-down=yes') -and ($p3aOut -match 'will auto-release after 2000ms')
        $p3aAuto = ($p3aOut -match 'auto-released after 2000ms \(id=(p\d+-\d+) cause=max-hold\)')
        if ($p3aAuto) { [void]$p3Ids.Add($Matches[1]) }
        ST-Check 'live: P3-1 press-down reports the measured press state and --max-hold releases it inside the same process (watchdog 1 observed, not claimed)' (
          $p3aEcho -and $p3aAuto -and (-not (Get-LeftButtonDown)))
        Write-Output ("      P3-1 " + (($p3aOut.Trim() -split "`r?`n" | Where-Object { $_ -match 'button is|hit-window|ERROR' } | Select-Object -First 5) -join ' | '))

        # P3-2 / P3-3 the two refusals with their real exit codes (a refusal that only
        # prints and still exits 0 is the silent-success shape).
        $p3bOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath drag-to $p3X $p3Y 2>&1 | Out-String
        $p3bCode = $LASTEXITCODE
        ST-Check 'live: P3-2 drag-to with nothing pressed is REFUSED with exit 1 (it must not echo a drag that never happened)' (
          ($p3bCode -eq 1) -and ($p3bOut -match 'needs an existing press state'))
        $p3cOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath press-up $p3X $p3Y 2>&1 | Out-String
        $p3cCode = $LASTEXITCODE
        ST-Check 'live: P3-3 press-up with nothing pressed is REFUSED with exit 1 instead of reporting a release' (
          ($p3cCode -eq 1) -and ($p3cOut -match 'the left button is not down'))

        # P3-4 the mid-state really delivers a HELD drag: press inside the fixture's
        # client area, travel while held, let go. The witness is the fixture itself -
        # it counts MouseMove events that arrive with the left button down and
        # MouseUp events, and publishes both in its window title. (A window-manager
        # caption drag was tried first and measures nothing: WinForms captions do not
        # move on a synthetic press here, and a counter in the target is the honest
        # replacement - it proves delivery to the window under the cursor.)
        $p3Witness = {
          $p3w2 = Resolve-Window 'DTX-PressProbe'
          if ($null -eq $p3w2) { return @{ Held = -1; Up = -1 } }
          $p3h = -1; $p3u = -1
          if ("$($p3w2.Title)" -match 'held=(\d+) up=(\d+)') { $p3h = [int]$Matches[1]; $p3u = [int]$Matches[2] }
          return @{ Held = $p3h; Up = $p3u }
        }
        $p3Before = & $p3Witness
        $p3Win2 = Resolve-Window 'DTX-PressProbe'
        $p3Tx = [int]($p3Win2.Left + 80)
        $p3Ty = [int]($p3Win2.Top + 100)
        $p3Ex = [int]($p3Win2.Left + 300)
        $p3Ey = [int]($p3Win2.Top + 240)
        $p3Json = '[{"press-down":[' + $p3Tx + ',' + $p3Ty + '],"to":"DTX-PressProbe"},' + '{"sleep":120},' +
          '{"drag-to":[' + $p3Ex + ',' + $p3Ey + ',14],"to":"DTX-PressProbe"},' + '{"sleep":120},' +
          '{"press-up":[' + $p3Ex + ',' + $p3Ey + '],"to":"DTX-PressProbe"}]'
        $p3JsonPath = Join-Path $env:TEMP ('dtx-press-' + [guid]::NewGuid().ToString('N') + '.json')
        [void]$p3Tmp.Add($p3JsonPath)
        [System.IO.File]::WriteAllText($p3JsonPath, $p3Json, (New-Object System.Text.UTF8Encoding($false)))
        $p3dOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath script $p3JsonPath 2>&1 | Out-String
        $p3dCode = $LASTEXITCODE
        Start-Sleep -Milliseconds 400
        $p3After = & $p3Witness
        $p3HeldDelta = $p3After.Held - $p3Before.Held
        $p3UpDelta = $p3After.Up - $p3Before.Up
        $p3dUp = ($p3dOut -match 'button is UP \(id=(p\d+-\d+) cause=press-up\)')
        if ($p3dUp) { [void]$p3Ids.Add($Matches[1]) }
        ST-Check 'live: P3-4 press-down -> drag-to -> press-up delivers a HELD drag to the target (>=5 MouseMoves with the button down, exactly 1 MouseUp) and the button is measurably down between the steps' (
          ($p3dCode -eq 0) -and ($p3dOut -match 'button is DOWN') -and ($p3dOut -match 'button still DOWN \(measured-down=yes\)') -and
          $p3dUp -and ($p3dOut -match '5 steps, all ok') -and ($p3HeldDelta -ge 5) -and ($p3UpDelta -eq 1))
        Write-Output ("      P3-4 exit=$p3dCode held-delta=$p3HeldDelta up-delta=$p3UpDelta  " + (($p3dOut.Trim() -split "`r?`n" | Where-Object { $_ -match 'button is|button still|steps,' } | Select-Object -First 4) -join ' | '))

        # P3-5 THE TEETH (the task order: "must be measured, code that merely says so
        # does not count"). A process that dies mid-press must be recovered by the NEXT
        # invocation. No clean exit can leave the button down (the entry finally
        # releases it), so the crash is simulated by stopping the tool's OWN child -
        # nothing else on this machine is touched.
        $p3eWin = Resolve-Window 'DTX-PressProbe'
        $p3eX = [int]($p3eWin.Left + $p3eWin.W / 2)
        $p3eY = [int]($p3eWin.Top + [int]($p3eWin.H / 2))
        $p3Child = Start-Process -FilePath powershell -PassThru -WindowStyle Hidden -ArgumentList @(
          '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script:ToolEntryPath, 'press-down', "$p3eX", "$p3eY", '--to', 'DTX-PressProbe', '--max-hold', '60000')
        $p3eDown = $false
        $p3eSw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($p3eSw.Elapsed.TotalSeconds -lt 10) { if (Get-LeftButtonDown) { $p3eDown = $true; break }; Start-Sleep -Milliseconds 100 }
        try { if ($p3Child -and -not $p3Child.HasExited) { Stop-Process -Id $p3Child.Id -Force -ErrorAction SilentlyContinue } } catch { }
        Start-Sleep -Milliseconds 400
        $p3eStray = Get-LeftButtonDown
        $p3eOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath wins 2>&1 | Out-String
        $p3eWarn = ($p3eOut -match 'released a button left down by a previous run')
        ST-Check 'live: P3-5 a press left down by a dead process is released by the NEXT invocation (WARNING echoed and the button measurably up again) - watchdog 2 has teeth' (
          $p3eDown -and $p3eStray -and $p3eWarn -and (-not (Get-LeftButtonDown)))
        Write-Output ("      P3-5 pressed-by-child=$p3eDown stray-after-kill=$p3eStray warning=$p3eWarn now=" + $(if (Get-LeftButtonDown) { 'down' } else { 'up' }))

        # P3-6 the pairing contract: every DOWN opened in this round must have its UP
        # in actions.log (the task order: an unpaired press-down FAILS the round).
        # The >= 2 floor is the anti-vacuity guard - if the ids were never collected
        # this check must go red, not green by absence of evidence.
        $p3Log = @(Get-Content -LiteralPath $ActionLog -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -Last 600)
        $p3Unpaired = New-Object System.Collections.ArrayList
        $p3WrongId = New-Object System.Collections.ArrayList
        foreach ($p3i2 in @($p3Ids)) {
          # the pairing is by ID, not by "some UP line exists": an UP that names a different
          # id, or one that admits it could not attribute the id, does not close this DOWN.
          $p3UpHit = @($p3Log | Where-Object { $_.Contains('button=UP') -and $_.Contains("id=$p3i2 ") -and $_.Contains('id-source=') -and (-not $_.Contains('id-source=none')) })
          if (@($p3UpHit).Count -lt 1) { [void]$p3Unpaired.Add($p3i2) }
        }
        # the reverse direction: a UP line whose id never appeared in a DOWN this round is a
        # rebuilt/guessed id - exactly the shape the hardening is meant to make impossible.
        # Two things this had to learn the hard way (first round of the check, 2026-10-02):
        # 1) actions.log renders as `<args> | <verb> | <text>', so the press id sits in the
        #    ARGUMENTS - BEFORE the words 'button=DOWN'. A regex demanding both in one order
        #    matches nothing, and every UP line looked like an orphan.
        # 2) the window must be scoped to this round (see $p3LogStart), or the previous round's
        #    perfectly-paired presses are reported as orphans.
        $p3Round = @()
        try { $p3Round = @(Get-Content -LiteralPath $ActionLog -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -Skip $p3LogStart) } catch { }
        $p3DownIds = New-Object System.Collections.ArrayList
        foreach ($p3l2 in $p3Round) {
          if ($p3l2.Contains('button=DOWN') -and ($p3l2 -match 'id=(p\d+-\d+)')) { [void]$p3DownIds.Add($Matches[1]) }
        }
        foreach ($p3l3 in $p3Round) {
          if ($p3l3.Contains('button=UP') -and ($p3l3 -match 'id=(p\d+-\d+)') -and (@($p3DownIds) -notcontains $Matches[1])) { [void]$p3WrongId.Add($Matches[1]) }
        }
        Write-Output ("      P3-6 scope: before-block=" + $p3LogStart + " in-round=" + @($p3Round).Count + " down-ids=" + (@($p3DownIds) -join ','))
        ST-Check 'live: P3-6 every press-down this round left a paired press-up line in actions.log, carrying the SAME id and an attributable id-source (a UP with another id, an empty id, or a UP never opened by any DOWN all fail the round)' (
          (@($p3Ids).Count -ge 2) -and (@($p3Unpaired).Count -eq 0) -and (@($p3WrongId).Count -eq 0))
        Write-Output ("      P3-6 ids=" + (@($p3Ids) -join ',') + " unpaired=" + (@($p3Unpaired) -join ',') + " orphan-up-ids=" + (@($p3WrongId) -join ','))
      } catch {
        ST-Check 'live: press trio setup+run' $false
        Write-Output "      press trio error: $($_.Exception.Message)"
      } finally {
        if ($p3Child -and -not $p3Child.HasExited) { try { Stop-Process -Id $p3Child.Id -Force -ErrorAction SilentlyContinue } catch { } }
        if ($p3Proc -and -not $p3Proc.HasExited) { try { Stop-Process -Id $p3Proc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        $p3Left = Resolve-Window 'DTX-PressProbe'
        if ($p3Left) { try { Stop-Process -Id $p3Left.Pid -Force -ErrorAction SilentlyContinue } catch { } }
        # whatever happened above, the OWNER is never left holding a button
        if (Get-LeftButtonDown) {
          Invoke-LeftPress $false
          Write-Output 'WARNING: the press fixture left the button down - released in the live finally'
        }
        foreach ($p3f in $p3Tmp) { if (Test-Path -LiteralPath $p3f) { Remove-Item -LiteralPath $p3f -Force -ErrorAction SilentlyContinue } }
      }

      # ---------- live: v2.1.0 (plan doc 1.1) the composite locator 'find' ----------
      # One fixture, two roads, proven from opposite directions: a real Button carries the
      # ASCII name (UIA sees it, OCR would too), and a CJK string is PAINTED with GDI so no
      # control and no Name exist anywhere - UIA genuinely cannot answer that one and OCR
      # must. CJK on purpose: Windows OCR inserts spaces inside latin strings
      # non-deterministically (same bitmap read as 'AAA BBB' then 'AAAB BB'), which would
      # turn this into a flake instead of a gate.
      # Nothing here activates or raises a window, and every click point stays inside this
      # fixture's own rect - find is a locator, and act-class judgements only ever hit DTX-*.
      $fFindProc = $null
      $fFindTmp = New-Object System.Collections.ArrayList
      try {
        $fPaint = [string]::Join('', @([char]0x5B9A, [char]0x4F4D, [char]0x515C, [char]0x5E95))
        $fOld = Resolve-Window 'DTX-FindProbe'
        if ($fOld) { try { Stop-Process -Id $fOld.Pid -Force -ErrorAction SilentlyContinue } catch { }; Start-Sleep -Milliseconds 500 }
        $fFixScript = Join-Path $env:TEMP ('dtx-find-' + [guid]::NewGuid().ToString('N') + '.ps1')
        [void]$fFindTmp.Add($fFixScript)
        $fSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HXFIND {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[void][HXFIND]::SetProcessDPIAware()
$form = New-Object System.Windows.Forms.Form
$form.Text = 'DTX-FindProbe'
$form.ClientSize = New-Object System.Drawing.Size(660, 430)
$form.StartPosition = 'Manual'
$form.Location = New-Object System.Drawing.Point(60, 1000)
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::White
$btn = New-Object System.Windows.Forms.Button
$btn.Text = 'DTXFINDHITU01'
$btn.Location = New-Object System.Drawing.Point(30, 30)
$btn.Size = New-Object System.Drawing.Size(320, 70)
$form.Controls.Add($btn)
$form.Add_Paint({
  param($s, $e)
  # assembled FROM CODE POINTS inside the fixture: this file is written UTF-8 WITHOUT a
  # BOM (every fixture here is), and PowerShell 5.1 decodes a BOM-less .ps1 as ANSI/GBK,
  # so a literal CJK string in it paints mojibake instead of the glyphs the test asks
  # for - that is how this case first failed live (OCR found nothing, exit 1).
  $paint = [string]::Join('', @([char]0x5B9A, [char]0x4F4D, [char]0x515C, [char]0x5E95))
  $fnt = New-Object System.Drawing.Font('SansSerif', 34)
  $br = [System.Drawing.Brushes]::Black
  $e.Graphics.DrawString($paint, $fnt, $br, 30, 300)
  $fnt.Dispose()
})
[System.Windows.Forms.Application]::Run($form)
'@
        [System.IO.File]::WriteAllText($fFixScript, $fSrc, (New-Object System.Text.UTF8Encoding($false)))
        $fFindProc = Start-Process powershell -PassThru -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $fFixScript)
        $fWin = $null
        $fSw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($fSw.Elapsed.TotalSeconds -lt 15) { $fWin = Resolve-Window 'DTX-FindProbe'; if ($fWin) { break }; Start-Sleep -Milliseconds 400 }
        if ($null -eq $fWin) { throw 'the DTX-FindProbe fixture window did not appear within 15s' }
        Start-Sleep -Milliseconds 800
        # 1) UIA road: a control whose Name the tree really exposes must be answered by UIA
        $fOutUia = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath find DTXFINDHITU01 --target DTX-FindProbe 2>&1 | Out-String
        $fCodeUia = $LASTEXITCODE
        ST-Check 'live: find answers a UIA-reachable Name with source=uia and hands back a ready centre (road 1 wins where road 1 can see)' (
          ($fCodeUia -eq 0) -and ($fOutUia -match 'find: source=uia ') -and ($fOutUia -match 'DTXFINDHITU01') -and ($fOutUia -match 'centre=[0-9]+,[0-9]+ -> click '))
        # 2) the OCR road must STILL WORK and must announce itself - plan 2 forbids deleting
        # or weakening it because of 'UIA first', and forbids a silent fallback.
        # The assertion deliberately does NOT compare the CJK text through the pipe: a
        # child's stdout is decoded with the PARENT's console codepage (GBK here), so CJK
        # coming back through `& powershell ... | Out-String` is mojibake whatever the
        # child printed - that is what kept this case red while the feature worked (found
        # by 'find live: ocr=exit0' next to a FAIL line, 2026-10-01). Text equality is
        # checked in the --json case below, where ConvertTo-Json escapes to \uXXXX and
        # survives the pipe. Here the witness is geometric and encoding-free: exactly one
        # hit line, inside the target window, and BELOW the button (the painted string).
        $fOutOcr = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath find $fPaint --target DTX-FindProbe 2>&1 | Out-String
        $fCodeOcr = $LASTEXITCODE
        $fOcrLines = @($fOutOcr -split "`r?`n" | Where-Object { $_ -like '  line *centre=*' })
        $fOcrCx = -1; $fOcrCy = -1
        if (@($fOcrLines).Count -ge 1 -and $fOcrLines[0] -match 'centre=([0-9]+),([0-9]+)') { $fOcrCx = [int]$Matches[1]; $fOcrCy = [int]$Matches[2] }
        $fOcrInside = ($fOcrCx -ge $fWin.Left) -and ($fOcrCx -lt ($fWin.Left + $fWin.W)) -and ($fOcrCy -ge $fWin.Top) -and ($fOcrCy -lt ($fWin.Top + $fWin.H))
        ST-Check 'live: find falls back to OCR for painted text UIA cannot see, announces the fallback in words, and lands on one rect inside the target and below the button (no silent degradation, OCR road intact)' (
          ($fCodeOcr -eq 0) -and ($fOutOcr -match 'falling back to OCR on the same rect') -and ($fOutOcr -match 'find: source=ocr ') -and
          (@($fOcrLines).Count -eq 1) -and $fOcrInside -and ($fOcrCy -gt 1200))
        # 3) a miss names BOTH roads with what each measured
        $fOutMiss = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath find QXNOSUCHTHINGZQX9 --target DTX-FindProbe 2>&1 | Out-String
        $fCodeMiss = $LASTEXITCODE
        ST-Check 'live: a find miss exits 1 and states what EACH road scanned (uia scanned N elements / OCR read M lines) instead of a bare not-found' (
          ($fCodeMiss -eq 1) -and ($fOutMiss -match 'uia scanned [0-9]+ element') -and ($fOutMiss -match 'OCR read [0-9]+ line') -and ($fOutMiss -match "NOT 'absent'"))
        # 4/5) --json carries the same verdict end to end (the key set is a published shape)
        $fJsonUia = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath find DTXFINDHITU01 --target DTX-FindProbe --json 2>&1 | Out-String
        $fJsonOcr = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath find $fPaint --target DTX-FindProbe --json 2>&1 | Out-String
        $fJokUia = $false; $fJokOcr = $false
        try {
          $fPJ1 = ($fJsonUia.Trim() -split "`r?`n" | Where-Object { $_ -like '{*"schemaVersion*' } | Select-Object -First 1) | ConvertFrom-Json
          $fKeys1 = (@($fPJ1.PSObject.Properties.Name) | Sort-Object) -join ','
          $fJokUia = ($fKeys1 -ceq (@(Get-FindJsonTopKeys | Sort-Object) -join ',')) -and ($fPJ1.source -ceq 'uia') -and (@($fPJ1.hits).Count -ge 1) -and (@($fPJ1.hits[0].road) -ceq 'uia')
          $fPJ2 = ($fJsonOcr.Trim() -split "`r?`n" | Where-Object { $_ -like '{*"schemaVersion*' } | Select-Object -First 1) | ConvertFrom-Json
          $fJokOcr = ($fPJ2.source -ceq 'ocr') -and (@($fPJ2.hits).Count -ge 1) -and (@($fPJ2.PSObject.Properties.Name) -contains 'target')
        } catch { Write-Output "      find --json parse error: $($_.Exception.Message)" }
        ST-Check 'live: find --json emits the pinned key set end to end with source=uia on the UIA road (the field consumers route on is real output, not only an offline shape)' (
          $fJokUia -and ($fJsonUia -notmatch 'find: source=|  uia: scanned|  line '))
        ST-Check 'live: find --json reports source=ocr through a real child process, with the pinned key set intact (ASCII-safe fields only - see the next case for the text)' ($fJokOcr)
        # 6) the hit TEXT itself, compared IN PROCESS. Measured twice the hard way on
        # 2026-10-01: PS 5.1 ConvertTo-Json emits CJK RAW (no \uXXXX), and a child's
        # stdout is decoded by the parent's GBK console - so any CJK equality routed
        # through a pipe is mojibake no matter what the code does. In process there is no
        # console in the way, and OCR's raw line text may still carry inter-glyph spaces,
        # which is exactly what Normalize-OcrText exists to fold for matching.
        $fJsonSave = $script:Json; $script:Json = $true
        $fTextOk = $false
        try {
          $fInProc = (@(Invoke-DesktopCommand 'find' @($fPaint, '--target', 'DTX-FindProbe')) -join "`n")
          $fObj = ($fInProc -split "`r?`n" | Where-Object { $_ -like '{*"schemaVersion*' } | Select-Object -First 1) | ConvertFrom-Json
          $fTextOk = ($fObj.source -ceq 'ocr') -and (@($fObj.hits).Count -ge 1) -and
            ((Normalize-OcrText "$($fObj.hits[0].text)") -ceq (Normalize-OcrText $fPaint))
        } catch {
          Write-Output "      find in-process json error: $($_.Exception.Message)"
        }
        $script:Json = $fJsonSave
        ST-Check 'live: find hands back the painted string ITSELF as the hit text (compared in-process on purpose: ConvertTo-Json emits raw CJK and a GBK console makes any piped CJK comparison false)' ($fTextOk)
        Write-Output ("      find live: uia=" + $(if ($fCodeUia -eq 0) { 'exit0' } else { "exit$fCodeUia" }) + " ocr=" + $(if ($fCodeOcr -eq 0) { 'exit0' } else { "exit$fCodeOcr" }) + " miss=exit$fCodeMiss jsonUia=$fJokUia jsonOcr=$fJokOcr")
        Write-Output ("      find ocr echo: " + (($fOutOcr.Trim() -split "`r?`n" | Where-Object { $_ -match 'source=|falling back|line ' } | Select-Object -First 4) -join ' | '))
      } catch {
        ST-Check 'live: find composite locator setup+run' $false
        Write-Output "      find composite error: $($_.Exception.Message)"
      } finally {
        if ($fFindProc -and -not $fFindProc.HasExited) { try { Stop-Process -Id $fFindProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        $fLeft = Resolve-Window 'DTX-FindProbe'
        if ($fLeft) { try { Stop-Process -Id $fLeft.Pid -Force -ErrorAction SilentlyContinue } catch { } }
        foreach ($f in $fFindTmp) { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue } }
      }

      # ---------- live: v1.10.0 challenge-probe (detect / stale / one authorized attempt / fuse) ----------
      # Fixture: DTX-ChalProbe renders the challenge text (please-complete + drag-the-
      # slider + puzzle, drawn glyph by glyph from code points) on a dark bitmap. mode=fail
      # ignores clicks (the attempt must fail and arm the fuse); mode=clear hides the
      # challenge on the first click (the success path). No solver is being built - the
      # fixture decides the outcome so the GATE is what is under test.
      # X-02 residual (v4.1.1): the handle is read as $script:chProc in the finally below AND in
      # the $chStop scriptblock, so a bare LOCAL initialiser here initialised nothing. When the
      # fixture assembly threw before the assignment ran, the finally read an unassigned variable
      # and raised a SECOND StrictMode error that masked the real one. Same shape as pgProc.
      $script:chProc = $null
      $chTmp = New-Object System.Collections.ArrayList
      try {
        $chOld = Resolve-Window 'DTX-ChalProbe'
        if ($chOld) { try { Stop-Process -Id $chOld.Pid -Force -ErrorAction SilentlyContinue } catch { }; Start-Sleep -Milliseconds 400 }
        $chScript = Join-Path $env:TEMP ('dtx-chal-' + [guid]::NewGuid().ToString('N') + '.ps1')
        [void]$chTmp.Add($chScript)
        $chSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HXCH {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[void][HXCH]::SetProcessDPIAware()
$mode = if ($args.Count -ge 1) { $args[0] } else { 'fail' }
$zhPlease = [string][char]0x8BF7 + [char]0x5B8C + [char]0x6210 + [char]0x5B89 + [char]0x5168 + [char]0x9A8C + [char]0x8BC1
$zhDrag = [string][char]0x62D6 + [char]0x52A8 + [char]0x6ED1 + [char]0x5757
$zhPuzzle = [string][char]0x62FC + [char]0x56FE
$bmp = New-Object System.Drawing.Bitmap(700, 420)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(40, 40, 46))
$fnt = New-Object System.Drawing.Font('Microsoft YaHei', 20, [System.Drawing.FontStyle]::Bold)
$g.DrawString($zhPlease, $fnt, [System.Drawing.Brushes]::White, 40, 60)
$g.DrawString(($zhDrag + [char]0x5B8C + [char]0x6210 + $zhPuzzle), $fnt, [System.Drawing.Brushes]::White, 40, 140)
$g.DrawString('>>', (New-Object System.Drawing.Font('Consolas', 26, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Yellow, 60, 230)
$g.DrawString('CertifyId=8F2D91', (New-Object System.Drawing.Font('Consolas', 14)), [System.Drawing.Brushes]::Gray, 40, 330)
$g.Dispose()
$form = New-Object System.Windows.Forms.Form
$form.Text = 'DTX-ChalProbe'
$form.ClientSize = New-Object System.Drawing.Size(700, 420)
$form.StartPosition = 'Manual'
$form.Location = New-Object System.Drawing.Point(120, 620)
$form.TopMost = $true
$form.BackgroundImage = $bmp
$form.Add_MouseClick({
  param($s, $e)
  if ($mode -ne 'clear') { return }
  $nb = New-Object System.Drawing.Bitmap(700, 420)
  $g2 = [System.Drawing.Graphics]::FromImage($nb)
  $g2.Clear([System.Drawing.Color]::FromArgb(40, 40, 46))
  $g2.DrawString('clean', (New-Object System.Drawing.Font('Consolas', 14)), [System.Drawing.Brushes]::Gray, 40, 330)
  $g2.Dispose()
  $s.BackgroundImage = $nb
})
[System.Windows.Forms.Application]::Run($form)
'@
        [System.IO.File]::WriteAllText($chScript, $chSrc, (New-Object System.Text.UTF8Encoding($false)))
        $chSpawn = {
          param($mode)
          $chArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $chScript, $mode)
          $script:chProc = Start-Process powershell -ArgumentList $chArgs -PassThru
          $chw = $null
          $swCh = [System.Diagnostics.Stopwatch]::StartNew()
          while ($swCh.Elapsed.TotalSeconds -lt 15) {
            $chw = Resolve-Window 'DTX-ChalProbe'
            if ($chw) { break }
            Start-Sleep -Milliseconds 400
          }
          if ($null -eq $chw) { throw 'challenge fixture did not appear within 15s' }
          Start-Sleep -Milliseconds 1500   # let the DWM show-animation finish before the first pixel hash
          return $chw
        }
        $chStop = {
          if ($script:chProc -and -not $script:chProc.HasExited) { try { Stop-Process -Id $script:chProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
          $script:chProc = $null
        }
        $chActCount = {
          param([int]$targetPid)
          # act-family lines naming this pid in actions.log - the independent
          # "did anything get injected" witness (V-3). -1 when the log cannot be read: a failed
          # read that returned 0 would agree with a previous 0 and the witness would pass while
          # measuring nothing (same fail-open family as the challenge fuse, v4.0.1 finding 2).
          $chLogErr = ''
          $chLog = @()
          try { $chLog = @(Get-Content -LiteralPath $ActionLog -Encoding UTF8 -ErrorAction Stop) } catch { $chLogErr = $_.Exception.Message }
          if ($chLogErr) { return -1 }
          @($chLog | Where-Object { $_ -match '\| (click|type|keys|paste|drag|wheel|hover|relclick) \|' -and $_.Contains("pid=$targetPid ") }).Count
        }
        $chw1 = & $chSpawn 'fail'
        $chPid = $chw1.Pid
        $chAct0 = & $chActCount $chPid
        $chOut1 = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath challenge-probe 'DTX-ChalProbe' 2>&1 | Out-String
        $chCode1 = $LASTEXITCODE
        $chAct1 = & $chActCount $chPid
        $chShape1 = ($chCode1 -eq 0) -and ($chOut1 -match 'challenge: type=slider-captcha') -and ($chOut1 -match 'confidence=high') -and
          ($chOut1 -match 'handle: \(') -and ($chOut1 -match '  shot: ') -and ($chOut1 -match 'challenge handoff: type=slider-captcha') -and
          ($chOut1 -match 'rect=\(') -and ($chOut1 -match 'attempt: not authorized')
        ST-Check 'live: V-1/V-4 the probe classifies the synthetic challenge and hands off with all four contract fields, and reports the attempt as unauthorized' ($chShape1)
        ST-Check 'live: V-3 independent witness - the read-only probe injected nothing (act-line count for this pid unchanged)' (
          ($chAct0 -ge 0) -and ($chAct1 -ge 0) -and ($chAct1 -eq $chAct0))
        Write-Output "      challenge-probe: exit=$chCode1 shape=$chShape1 act-lines=$chAct0->$chAct1"
        Write-Output ("      first lines: " + (($chOut1.Trim() -split "`r?`n" | Where-Object { $_ -match 'challenge:|stale=|handoff|attempt:' } | Select-Object -First 4) -join ' | '))
        $chOut1b = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath challenge-probe 'DTX-ChalProbe' 2>&1 | Out-String
        ST-Check 'live: V-2 the same challenge image on a second sample reads stale=yes with the dismiss advice' (
          ($LASTEXITCODE -eq 0) -and ($chOut1b -match 'stale=True') -and ($chOut1b -match 'dismiss-not-solve'))
        Write-Output "      second sample stale-yes=$($chOut1b -match 'stale=True')"
        $chNeg = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath challenge-probe 'DTX-ChalProbe' --allow-attempt 2>&1 | Out-String
        ST-Check 'live: V-3 --allow-attempt without a named click is refused (an attempt is one caller-named click, never a free hand)' (
          ($LASTEXITCODE -eq 1) -and ($chNeg -match '--attempt-click'))
        $chOut2 = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath challenge-probe 'DTX-ChalProbe' --allow-attempt --attempt-click 350,300 2>&1 | Out-String
        $chCode2 = $LASTEXITCODE
        $chAct2 = & $chActCount $chPid
        ST-Check 'live: V-3 the authorized attempt really clicks once (act count +1) and its failure arms the fuse (exit 1 + FAILED)' (
          ($chCode2 -eq 1) -and ($chOut2 -match 'challenge attempt FAILED') -and (($chAct2 - $chAct1) -ge 1))
        $chOut3 = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath challenge-probe 'DTX-ChalProbe' --allow-attempt --attempt-click 350,300 2>&1 | Out-String
        ST-Check 'live: V-3 the second attempt on the same challenge image is refused by the fuse (no retry escalation)' (
          ($LASTEXITCODE -eq 1) -and ($chOut3 -match 'challenge attempt refused'))
        # WHY the attempt failed, taken from the tool's own FAILED line (production already
        # distinguishes "the click itself was refused by a guard" from "the click landed and
        # the challenge stayed up" - live-v210-4 lost a point to exactly this: exit 1 and
        # FAILED were both true and only the act delta was flat, so the red could not say
        # which of the two it was). Diagnostic only and never compared, on purpose: a guard
        # message can carry CJK from a localized exception, and CJK through a child pipe is
        # unreadable (see the find live cases). One FAILED line by construction (the command
        # throws once and exits), so this indexes instead of Select-Object -First.
        $chFailLines = @($chOut2 -split "`r?`n" | Where-Object { $_ -match 'challenge attempt FAILED' })
        $chWhy = 'no-FAILED-line'
        if ($chFailLines.Count -gt 0) {
          $chWhyTail = [string]$chFailLines[0]
          $chWhy = $(if ($chWhyTail.Length -gt 150) { $chWhyTail.Substring($chWhyTail.Length - 150) + ' (front 150+ chars cut, full text is in the tool output)' } else { $chWhyTail })
        }
        Write-Output "      attempt: exit=$chCode2 refused-fuse=$($chOut3 -match 'challenge attempt refused') act-lines=$chAct1->$chAct2 click-reason=$chWhy"
        & $chStop
        $chw2 = & $chSpawn 'clear'
        $chOut4 = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath challenge-probe 'DTX-ChalProbe' --allow-attempt --attempt-click 350,300 2>&1 | Out-String
        ST-Check 'live: V-3 success path - on a challenge that closes, the one authorized click reads cleared and exits 0' (
          ($LASTEXITCODE -eq 0) -and ($chOut4 -match 'challenge attempt: cleared'))
        Write-Output "      cleared-path: exit=$LASTEXITCODE ok=$($chOut4 -match 'cleared')"
      } catch {
        ST-Check 'live: challenge-probe setup+run' $false
        Write-Output "      challenge probe error: $($_.Exception.Message)"
      } finally {
        if ($script:chProc -and -not $script:chProc.HasExited) { try { Stop-Process -Id $script:chProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        $chLeft = Resolve-Window 'DTX-ChalProbe'
        if ($chLeft) { try { Stop-Process -Id $chLeft.Pid -Force -ErrorAction SilentlyContinue } catch { } }
        foreach ($f in $chTmp) { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue } }
      }

      # ---------- live: v1.5.2 WP-1 script payload purity (audit R-01, HIGH) ----------
      # The shipped defect typed the expect FLAGS into the target window as the
      # payload and still echoed ok (exit 0), so this case asserts what actually
      # landed in the control - exact string equality, never just the exit code
      # (task order section 10). Own window only: spawned here, killed in finally.
      $stepProc = $null
      $stepTmpFiles = New-Object System.Collections.ArrayList
      # INC-02: both names are declared AHEAD of the try because the guard is the first thing this
      # block does and the catch has to be able to tell a refused write from a real failure.
      $stepGate = ''
      $stepGuard = $null
      try {
        # Clipboard hygiene (2026-10-29, live-r4): the script's paste step goes through the
        # clipboard, and a PNG/Bitmap restored back by an earlier check's snapshot-restore
        # chain makes the CU-OPS write guard refuse the paste BEFORE the payload lands -
        # the step then reads as FAILED while type and keys both still land (measured:
        # want=30chars got=[payType+payKeys], 1 FAILED, and the missing member was exactly
        # the paste one). Normalizing to a plain text format gives the paste a clipboard
        # this tool can snapshot, overwrite, and restore.
        # INC-02: normalizing is a write to the SHARED clipboard, so it now happens only over a
        # snapshot the tool can put back. Refused => the five names this block owns skip under the
        # verdict as their reason (the G-20 branch of the catch), which is neither a silent pass
        # nor a build failure; the finally restores on every path that reaches it.
        $stepGuard = Start-LiveClipboardGuard 'step-probe normalization write' $null
        if (-not $stepGuard.Started) { $stepGate = 'clipboard guard refused the normalization write: ' + $stepGuard.Verdict; throw $stepGate }
        'DTX-CLIP-NORMALIZED' | & "$env:SystemRoot\System32\clip.exe"
        $stepGuard.Written = $true
        $swOld = Resolve-Window 'DTX-StepProbe'
        if ($swOld) { try { Stop-Process -Id $swOld.Pid -Force -ErrorAction SilentlyContinue } catch { }; Start-Sleep -Milliseconds 500 }
        $sAlpha = 'ACDEFHJKLMNPRTUVWXY'
        $sRnd = ''
        1..6 | ForEach-Object { $sRnd += $sAlpha[(Get-Random -Maximum $sAlpha.Length)] }
        $payType = 'DTXT' + $sRnd
        $payFile = 'DTXF' + $sRnd
        $payKeys = 'DTXK' + $sRnd
        $sScript = Join-Path $env:TEMP ('dtx-step-' + [guid]::NewGuid().ToString('N') + '.ps1')
        $sJson = Join-Path $env:TEMP ('dtx-step-' + [guid]::NewGuid().ToString('N') + '.json')
        $sFile = Join-Path $env:TEMP ('dtx-step-' + [guid]::NewGuid().ToString('N') + '.txt')
        # G-20 F1/F2: the fixture reports its OWN foreground / in-window-focus / IME-association
        # state into this file. Nothing else in the round can see inside the fixture process, and a
        # red payload assertion that cannot say where the keystrokes actually went is the exact
        # shape this card exists to remove.
        $sReport = Join-Path $env:TEMP ('dtx-step-report-' + [guid]::NewGuid().ToString('N') + '.txt')
        [void]$stepTmpFiles.Add($sScript); [void]$stepTmpFiles.Add($sJson); [void]$stepTmpFiles.Add($sFile); [void]$stepTmpFiles.Add($sReport)
        # G-20: '' means "nothing blocked this leg". Non-empty is an ENVIRONMENT reason, carried to
        # the catch so a disturbed desktop reports as NOT VERIFIED instead of as a build failure.
        # INC-02: the declaration moved above the try (the guard needs it before any of this runs);
        # it is deliberately NOT reset here, because a cleared gate would turn a refused write back
        # into a red build.
        # G-21 (owner ruling 2026-10-20 14:4x, item 3; scope explicitly = the WHOLE step-probe
        # dependency block, not only the five sites my G-20 pen diff touched): this block raises its
        # fixture with `Start-Process powershell` (App Paths) and then drives the tool with
        # `& powershell` (PATH) - two different child faces, measured separately by the pre-flight
        # above because they answer differently: with System32\WindowsPowerShell off PATH the
        # Start-Process face still works while the call-operator face returns an empty string. If the
        # face this block uses most cannot spawn, NOTHING here is measurable, so the fixture is not
        # started at all and every name the block owns skips under its own name with its own reason.
        # This is deliberately placed BEFORE the temp files are written and before Start-Process, and
        # it is deliberately NOT a blanket: an exception raised later in the try, after the
        # pre-checks passed, still goes through the catch's other branch and reports RED.
        if (-not $script:PsChildOk) { $stepGate = 'child-spawn pre-check: ' + $script:PsChildWhy; throw $stepGate }
        if (-not $script:PsStartOk) { $stepGate = 'start-process pre-check: ' + $script:PsStartWhy; throw $stepGate }
        $sSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HX3 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("imm32.dll")] public static extern IntPtr ImmAssociateContext(IntPtr h, IntPtr himc);
  [DllImport("imm32.dll")] public static extern IntPtr ImmGetDefaultIMEWnd(IntPtr h);
}
"@
[void][HX3]::SetProcessDPIAware()
$rep = if ($args.Count -ge 1) { [string]$args[0] } else { '' }
function St-Rep([string]$k, $v) {
  if (-not $rep) { return }
  try { [System.IO.File]::AppendAllText($rep, ($k + '=' + [string]$v + [Environment]::NewLine), (New-Object System.Text.UTF8Encoding($false))) } catch { }
}
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-StepProbe'
$f.ClientSize = New-Object System.Drawing.Size(700, 220)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(80, 1500)
$tb = New-Object System.Windows.Forms.TextBox
$tb.Multiline = $true
$tb.Font = New-Object System.Drawing.Font('Consolas', 14)
$tb.Location = New-Object System.Drawing.Point(10, 10)
$tb.Size = New-Object System.Drawing.Size(680, 200)
[void]$f.Controls.Add($tb)
[void]$f.Show()
# G-20 F3 (fixture placement / Z order): this call used [IntPtr]::Zero = HWND_TOP, which lifts the fixture
# above the NON-topmost windows only. The WeChat IME candidate window is topmost, so it stayed
# 40-60% over this exact rect in 8 of 8 live rounds while every read that matters here is
# zero-tolerance (Get-PasteReceiptOcclusionMax returns 0). HWND_TOPMOST (-1) makes the fixture's
# own pixels the pixels being read; the guard itself is untouched - no --allow-occluded, no
# --occlude off, no threshold moved, no needle weakened.
[void][HX3]::SetWindowPos($f.Handle, [IntPtr](-1), 80, 1500, 716, 259, 0x0040 -bor 0x0003)
# G-20 F2 (IME state): bind NO input-method context to this fixture's two handles. `keys` sends
# real virtual-key codes, and a TSF Chinese IME keeps composing even when the legacy
# WM_IME_CONTROL readback this tool uses reports alphanumeric - measured: ime-en answered
# "now alphanumeric (previous mode=0x1)" in 8 of 8 rounds and the 10-character keys payload
# still never reached the control. ImmAssociateContext(NULL) is scoped to these windows: it
# cannot change the owner's IME configuration, cannot touch another process and is not aimed at
# the WeChat input process (which this card is forbidden to touch).
$assocPrevForm = [HX3]::ImmAssociateContext($f.Handle, [IntPtr]::Zero)
$assocPrevBox = [HX3]::ImmAssociateContext($tb.Handle, [IntPtr]::Zero)
[void]$tb.Focus()
St-Rep 'hwnd' $f.Handle
St-Rep 'boxHwnd' $tb.Handle
St-Rep 'imeWndForm' ([HX3]::ImmGetDefaultIMEWnd($f.Handle))
St-Rep 'imeAssocPrevForm' ('0x' + $assocPrevForm.ToInt64().ToString('X'))
St-Rep 'imeAssocPrevBox' ('0x' + $assocPrevBox.ToInt64().ToString('X'))
St-Rep 'fgIsSelf' (([HX3]::GetForegroundWindow()) -eq $f.Handle)
St-Rep 'containsFocus' $f.ContainsFocus
St-Rep 'activeControl' ($(if ($f.ActiveControl) { $f.ActiveControl.GetType().Name } else { 'none' }))
# G-20 F1 (input focus): focus has to HOLD, not merely be set once. Every command the ladder sends
# re-activates the window, and a Form can come back holding focus itself instead of the TextBox -
# the keystrokes then land nowhere while the assertion reads as a payload failure. Self-heal on a
# timer and keep writing the state, so a red names the face that actually went.
$fxTimer = New-Object System.Windows.Forms.Timer
$fxTimer.Interval = 150
$fxTimer.Add_Tick({
  if ($f.ContainsFocus -and $f.ActiveControl -and -not $f.ActiveControl.Equals($tb)) { [void]$tb.Focus() }
  St-Rep 'fgIsSelf' (([HX3]::GetForegroundWindow()) -eq $f.Handle)
  St-Rep 'containsFocus' $f.ContainsFocus
  St-Rep 'activeControl' ($(if ($f.ActiveControl) { $f.ActiveControl.GetType().Name } else { 'none' }))
})
$fxTimer.Start()
[System.Windows.Forms.Application]::Run($f)
'@
        [System.IO.File]::WriteAllText($sScript, $sSrc, (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::WriteAllText($sFile, $payFile, (New-Object System.Text.UTF8Encoding($false)))
        $stepProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $sScript, $sReport -PassThru
        $swp = $null
        $swS = [System.Diagnostics.Stopwatch]::StartNew()
        while ($swS.Elapsed.TotalSeconds -lt 15) { $swp = Resolve-Window 'DTX-StepProbe'; if ($swp) { break }; Start-Sleep -Milliseconds 400 }
        if ($null -eq $swp) { throw 'step-probe window did not appear within 15s' }
        Start-Sleep -Milliseconds 600
        # v4.2.4: pin THIS fixture's own IME to English before the keystroke steps. The keys
        # step sends real keystrokes, and a Chinese-mode IME intercepts ASCII as pinyin - it
        # pops the candidate window over this fixture and eats the payload (measured 2026-10-11,
        # two live rounds: occluded=60% coveredBy=wetype_candidate pid=9188, the window text
        # stayed short, and every later read was refused). ime-en poll-verifies the switch, so
        # an IME that ignores the control message becomes an honest ERROR instead of a false OK.
        # No restore is needed and none is attempted: the conversion mode belongs to the
        # fixture's own thread, which dies with the fixture process in the finally below - the
        # owner's own windows are untouched. On this machine the live ladder is also its own
        # mutation tester for this pin: remove it and the keys step fails deterministically.
        # G-20 SUPERSEDES that last sentence by measurement. The fixture now ALSO detaches its own
        # input-method context (F2 below), because the legacy WM_IME_CONTROL view this pin sets is not
        # what a TSF IME consults when it composes - so the keystroke leg by itself can no longer prove
        # the pin ran. What puts the teeth back is F6: an independent ime-state read of the fixture's
        # conversion mode, answered by a DIFFERENT command than the one that sets it, so the pin cannot
        # attest itself. Removing the pin makes that assertion fail; that is the test that matters.
        # G-20 pre-type gate (four faces: placement / focus / IME state / cross-round residue). Nothing is typed until
        # three things are MEASURED and printed: the product's own focus command says fg_ok=True for
        # the fixture's pid, the product's own ime-en answers for that same pid, and the product's
        # OWN 25-point sampler reports zero of the fixture's pixels belonging to somebody else. The
        # verdict is taken by calling production functions in-process (no second sampler is written
        # here, so the pre-gate and the send-time guard cannot drift into two different rules).
        $focusOut = ''
        try { $focusOut = (& powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath focus 'DTX-StepProbe' 2>&1 | Out-String) } catch { $focusOut = 'CAPTURED-THROW: ' + $_.Exception.Message }
        $imePinOut = ''
        try { $imePinOut = (& powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath ime-en 2>&1 | Out-String) } catch { $imePinOut = 'CAPTURED-THROW: ' + $_.Exception.Message }
        Write-Output ("      ime pin: " + (($imePinOut.Trim() -split "`r?`n" | Select-Object -First 1)))
        # G-20 F6: assert the pin with a second command instead of logging it. ime-en sets the mode and
        # re-reads the same handle, which is self-attestation; ime-state is a separate command that
        # resolves the FOREGROUND thread again. Same pid = the pin acted on the fixture; mode=0x0 = the
        # IMM32 conversion view really is alphanumeric. A pid that moved is an ENVIRONMENT event
        # (somebody else took the foreground between the two calls) and is reported as NOT VERIFIED;
        # the right pid with a mode that did not switch is a real product failure and goes RED.
        $imeStateOut = ''
        try { $imeStateOut = (& powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath ime-state 2>&1 | Out-String) } catch { $imeStateOut = 'CAPTURED-THROW: ' + $_.Exception.Message }
        $imeStateLine = (($imeStateOut.Trim() -split "`r?`n" | Select-Object -First 1))
        Write-Output ('      ime-state independent read: ' + $imeStateLine)
        if ($imeStateOut -notmatch ('pid=' + [string]$swp.Pid)) {
          $stepGate = 'input focus moved between calls: ime-state answered a window other than the fixture (pid=' + [string]$swp.Pid + '), readback=[' + $imeStateLine + ']'
          throw ('G-20 environment gate: ' + $stepGate)
        }
        if ($imeStateOut -notmatch 'mode=0x0 ') {
          throw ('ime-en left the fixture in a converting mode (IMM32 view), keys would be composed not typed: ' + $imeStateLine)
        }
        $fxRect = @{ X = $swp.Left; Y = $swp.Top; W = $swp.W; H = $swp.H }
        $fxOcc = Get-OcclusionVerdict $swp.Left $swp.Top $swp.W $swp.H $swp.Handle 5
        $fxOccRep = Format-OcclusionCovering @($fxOcc.Covering) $fxOcc.Checked
        Write-Output ("      pre-type gate pass 1: " + (Format-OcclusionVerdict 'read' $fxRect ([int][math]::Round($fxOcc.Pct)) $fxOccRep.Summary $fxOcc.Err))
        if ($fxOcc.Err -eq '' -and [double]$fxOcc.Pct -gt [double](Get-PasteReceiptOcclusionMax)) {
          # one re-raise through the product's own focus command, then re-measure: a coverer that a
          # plain raise defeats must not be reported as an environment block
          $fxReRaise = ''
          try { $fxReRaise = (& powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath focus 'DTX-StepProbe' 2>&1 | Out-String) } catch { $fxReRaise = 'CAPTURED-THROW: ' + $_.Exception.Message }
          Write-Output ('      re-raise readback: ' + (($fxReRaise.Trim() -split "`r?`n" | Select-Object -First 1)))
          Start-Sleep -Milliseconds 400
          $fxOcc = Get-OcclusionVerdict $swp.Left $swp.Top $swp.W $swp.H $swp.Handle 5
          $fxOccRep = Format-OcclusionCovering @($fxOcc.Covering) $fxOcc.Checked
          Write-Output ("      pre-type gate pass 2: " + (Format-OcclusionVerdict 'read' $fxRect ([int][math]::Round($fxOcc.Pct)) $fxOccRep.Summary $fxOcc.Err))
        }
        $fxRepLines = @()
        if (Test-Path -LiteralPath $sReport) { $fxRepLines = @(Get-Content -LiteralPath $sReport -ErrorAction SilentlyContinue) }
        Write-Output ("      fixture self-report (last 6 of " + @($fxRepLines).Count + " lines): " + (($fxRepLines | Select-Object -Last 6) -join ' | '))
        $fxFgOk = $focusOut -match 'fg_ok=True'
        $fxFocusPid = ''
        if ($focusOut -match 'focused pid=(\d+)') { $fxFocusPid = $Matches[1] }
        Write-Output ("      focus pin: " + (($focusOut.Trim() -split "`r?`n" | Select-Object -First 1)) + "  (need fg_ok=True and pid=" + [string]$swp.Pid + ")")
        if ($imePinOut -notmatch ('pid=' + [string]$swp.Pid)) {
          $stepGate = 'IME state: the product ime-en did not answer for the fixture (pid=' + [string]$swp.Pid + '), readback=[' + (($imePinOut.Trim() -split "`r?`n" | Select-Object -First 1)) + ']'
        } elseif (-not $fxFgOk) {
          $stepGate = 'input focus: focus did not report fg_ok=True for the fixture, readback=[' + (($focusOut.Trim() -split "`r?`n" | Select-Object -First 1)) + ']'
        } elseif ($fxFocusPid -and ($fxFocusPid -ne [string]$swp.Pid)) {
          $stepGate = 'input focus: focus answered pid=' + $fxFocusPid + ' while the fixture is pid=' + [string]$swp.Pid
        } elseif ($fxOcc.Err -ne '') {
          $stepGate = 'fixture placement: the sampler could not read this rect (err=' + $fxOcc.Err + ' checked=' + [int]$fxOcc.Checked + ' skipped=' + [int]$fxOcc.Skipped + ')'
        } elseif ([double]$fxOcc.Pct -gt [double](Get-PasteReceiptOcclusionMax)) {
          $stepGate = 'fixture placement / cross-round residue: a window that is not mine owns ' + [int][math]::Round($fxOcc.Pct) + '% of the fixture pixels, coveredBy=' + $fxOccRep.Summary + ' - the zero-tolerance guard was left exactly as it is and nothing was typed'
        }
        if ($stepGate) { throw ('G-20 environment gate: ' + $stepGate) }
        $sSteps = @(
          [ordered]@{ type = @($payType); to = 'DTX-StepProbe'; expectText = $payType; timeoutSec = 4 },
          [ordered]@{ paste = $sFile; to = 'DTX-StepProbe'; expectText = $payFile; timeoutSec = 4 },
          [ordered]@{ keys = $payKeys; to = 'DTX-StepProbe'; expectGone = 'DTXABSENTZZ'; timeoutSec = 2 }
        )
        [System.IO.File]::WriteAllText($sJson, ($sSteps | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding($false)))
        $sOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath script $sJson 2>&1 | Out-String
        Start-Sleep -Milliseconds 400
        $sRoots = Uia-Roots $swp
        $tbName = ''
        foreach ($el in (Uia-WalkAll $sRoots.Roots)) {
          $nmEl = ''
          try { $nmEl = $el.Current.Name } catch { }
          if ($nmEl -like ($payType + '*')) { $tbName = $nmEl; break }
        }
        $wantSeq = $payType + $payFile + $payKeys
        ST-Check 'live: script type/paste/keys + expect land EXACTLY the payloads (no flags in the control)' ($tbName -ceq $wantSeq)
        ST-Check 'live: no expect-flag text leaked into the target window' (-not ($tbName -match '--'))
        Write-Output ("      step probe: want=" + $wantSeq.Length + "chars got=[" + $tbName + "]")
        Write-Output ("      step probe run (last 6): " + (($sOut.Trim() -split "`r?`n" | Select-Object -Last 6) -join ' | '))
        # anti-drift nail (v1.5.2 R-08, teeth added v1.5.3): --needle must survive
        # the REAL 'powershell -File' binding AND must be what carries a needle that
        # itself starts with -- - the only reason the flag exists.
        # The payload is therefore '--DTX-NEEDLE':
        #   - flag parsed correctly      -> searches '--DTX-NEEDLE' -> hit
        #   - flag branch removed        -> '--needle' is an unknown flag  -> RED
        #   - PowerShell swallows it     -> '--DTX-NEEDLE' is an unknown flag -> RED
        #   - flag ignored, value falls  -> needle becomes '--needle --DTX-NEEDLE' -> no hit -> RED
        # (a plain word as payload would stay green in the last two cases, which is
        # exactly the toothlessness this note exists to prevent.)
        $dashPay = '--DTX-NEEDLE'
        $tpOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath type --to 'DTX-StepProbe' --needle $dashPay 2>&1 | Out-String
        $tpCode = $LASTEXITCODE
        Start-Sleep -Milliseconds 400
        $tbName2 = ''
        foreach ($el in (Uia-WalkAll (Uia-Roots (Resolve-Window 'DTX-StepProbe')).Roots)) {
          $nmEl2 = ''
          try { $nmEl2 = $el.Current.Name } catch { }
          if ($nmEl2 -like ($payType + '*')) { $tbName2 = $nmEl2; break }
        }
        ST-Check 'live: --needle carries a payload that starts with -- into the window (UIA byte-exact)' (
          $tpCode -eq 0 -and $tbName2 -ceq ($wantSeq + $dashPay) -and $tpOut -notmatch 'unknown flag')
        $ndOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath find-text 'DTX-StepProbe' --needle $dashPay 2>&1 | Out-String
        $ndCode = $LASTEXITCODE
        # Pinned property = the flag reached the parser and IS the needle, judged by
        # what the tool echoes, not by whether OCR could read the screen (OCR mangles
        # '--' runs: measured here as '- <CJK-homoglyph> DTX' / '-NEEDLEI', so a
        # not-found is a legitimate outcome and must not be punished). The three
        # failure modes stay distinguishable:
        #   unknown flag / swallowed      -> 'unknown flag' appears      -> RED
        #   flag ignored, value joined    -> quoted needle is '--needle --DTX-NEEDLE'
        #                                     and '--needle' leaks into it -> RED
        #   correct parse                  -> hits, or quotes exactly '--DTX-NEEDLE'
        $ndQuoted = $ndOut -match "'--DTX-NEEDLE' not found"
        ST-Check 'live: --needle is reachable through the powershell -File call form' (
          (($ndCode -eq 0 -and $ndOut -match 'hit: text=') -or $ndQuoted) -and
          $ndOut -notmatch 'unknown flag' -and $ndOut -notmatch 'empty needle' -and $ndOut -notmatch "'--needle ")
        Write-Output ("      --needle payload='" + $dashPay + "' type-exit=$tpCode find-exit=$ndCode content=[" + $tbName2 + "]")
        Write-Output ("      --needle search: " + (($ndOut.Trim() -split "`r?`n" | Select-Object -First 1)))
      } catch {
        # G-20: an environment block is neither a build failure nor a pass. All five names this
        # block owns report as skipped, each carrying the measured reason, so the check total is
        # unchanged and a reader can tell "this desktop could not be made clean" from "the code is
        # wrong" - indistinguishable before, which is precisely how the three reds got read as a
        # split regression. The gate's own lines are printed above, so the SKIP is positive
        # evidence rather than an absence. NO exemption by check name, and nothing is tolerated.
        if ($stepGate) {
          Write-Output ("      step probe NOT VERIFIED (environment blocked, never a pass): " + $stepGate)
          ST-Skip 'live: step probe setup+run' ('environment blocked - ' + $stepGate)
          ST-Skip 'live: script type/paste/keys + expect land EXACTLY the payloads (no flags in the control)' ('environment blocked - ' + $stepGate)
          ST-Skip 'live: no expect-flag text leaked into the target window' ('environment blocked - ' + $stepGate)
          ST-Skip 'live: --needle carries a payload that starts with -- into the window (UIA byte-exact)' ('environment blocked - ' + $stepGate)
          ST-Skip 'live: --needle is reachable through the powershell -File call form' ('environment blocked - ' + $stepGate)
        } else {
          ST-Check 'live: step probe setup+run' $false
          Write-Output ("      step probe error (environment gate was clean, so this is a real failure): " + $_.Exception.Message)
        }
      } finally {
        # INC-02: the restore is the FIRST thing this finally does, on every path that reaches it
        # (success, exception, cancellation), and its outcome is asserted instead of assumed:
        # ok/skipped is a clean exit, partial/failed is RED, because "the clipboard was lost
        # anyway" is exactly the loss this guard exists to prevent. A process killed from outside
        # runs no finally at all - that path is disclosed, not covered.
        $stepGuardNote = Stop-LiveClipboardGuard $stepGuard
        $stepGuardOutcome = Get-ClipboardRestoreOutcome $stepGuardNote
        ST-Check 'live: the step-probe clipboard guard restores the pre-write clipboard on every exit path (partial or failed restore is red, refused write never wrote anything to restore)' (
          (@('ok', 'skipped') -ccontains $stepGuardOutcome))
        Write-Output ('      step probe clipboard guard: verdict=[' + $(if ($stepGuard) { [string]$stepGuard.Verdict } else { '(no guard object)' }) + '] written=' +
          $(if ($stepGuard) { [string]$stepGuard.Written } else { '-' }) + '] outcome=' + $stepGuardOutcome + ' restore=[' + $stepGuardNote + ']')
        if ($stepProc -and -not $stepProc.HasExited) { try { Stop-Process -Id $stepProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        foreach ($tf in $stepTmpFiles) { if (Test-Path -LiteralPath $tf) { Remove-Item -LiteralPath $tf -Force -ErrorAction SilentlyContinue } }
      }
      # G-20 self-clean / cross-round residue: residue accounting for what of MY fixture is still on the machine
      # after this block. A leftover fixture window or temp file is what made the next round judge
      # a different desktop than this one, so the count is measured and printed - 0 included.
      $fxLeftProcs = @(Get-Process -Name powershell -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -eq 'DTX-StepProbe' })
      $fxTmpLeft = 0
      foreach ($tf in $stepTmpFiles) { if (Test-Path -LiteralPath $tf) { $fxTmpLeft++ } }
      Write-Output ("      step probe residue: fixture windows=" + @($fxLeftProcs).Count + " fixture temp files=" + $fxTmpLeft + " (registered=" + @($stepTmpFiles).Count + ")")

      # ---------- live: v1.5.2 WP-3 menu-pick accepts a menu, refuses the desktop ----------
      # audit R-04: with the old WS_POPUP test, `menu-pick "Program Manager" <x>`
      # reached OCR over the whole desktop and would have clicked a row. Both
      # directions are proven through the real command path. Nothing is clicked in
      # any of them: the needle cannot exist, and a refusal stops before OCR.
      $menuProc = $null
      $menuScript = Join-Path $env:TEMP ('dtx-menu-' + [guid]::NewGuid().ToString('N') + '.ps1')
      try {
        $moOld = Resolve-Window 'DTX-MenuProbe'
        if ($moOld) { try { Stop-Process -Id $moOld.Pid -Force -ErrorAction SilentlyContinue } catch { }; Start-Sleep -Milliseconds 500 }
        $moSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HX4 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@
[void][HX4]::SetProcessDPIAware()
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-MenuProbe'
$f.ClientSize = New-Object System.Drawing.Size(420, 300)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(120, 1150)
[void]$f.Show()
[void][HX4]::SetWindowPos($f.Handle, [IntPtr]::Zero, 120, 1150, 436, 339, 0x0040 -bor 0x0003)
[System.Windows.Forms.Application]::Run($f)
'@
        [System.IO.File]::WriteAllText($menuScript, $moSrc, (New-Object System.Text.UTF8Encoding($false)))
        $menuProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $menuScript -PassThru
        $mwin = $null
        $mSw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($mSw.Elapsed.TotalSeconds -lt 15) { $mwin = Resolve-Window 'DTX-MenuProbe'; if ($mwin) { break }; Start-Sleep -Milliseconds 400 }
        if ($null -eq $mwin) { throw 'menu probe window did not appear within 15s' }
        Start-Sleep -Milliseconds 400
        $mAbsent = 'DTXZZABSENT'
        $mPos = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath menu-pick 'DTX-MenuProbe' $mAbsent 2>&1 | Out-String
        $mPosCode = $LASTEXITCODE
        ST-Check 'live: menu-pick passes the shape rule for a popup-sized window and reaches OCR' (
          $mPosCode -eq 1 -and $mPos -notmatch 'NOT a menu window' -and $mPos -match 'not found in menu window')
        $mNeg = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath menu-pick 'Program Manager' $mAbsent 2>&1 | Out-String
        $mNegCode = $LASTEXITCODE
        ST-Check 'live: menu-pick refuses the desktop (class Progman) before OCR and exits 1' (
          $mNegCode -eq 1 -and $mNeg -match 'NOT a menu window' -and $mNeg -match 'shell surface' -and $mNeg -notmatch 'OCR read')
        $mOv = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath menu-pick 'Program Manager' $mAbsent --allow-window 2>&1 | Out-String
        $mOvCode = $LASTEXITCODE
        ST-Check 'live: menu-pick --allow-window overrides the shape rule (escape hatch works)' (
          $mOv -match 'overrides the shape rule' -and $mOvCode -eq 1 -and $mOv -match 'not found in menu window')
        Write-Output ("      menu-pick refusal (desktop): " + (($mNeg.Trim() -split "`r?`n" | Select-Object -First 1)))
      } catch {
        ST-Check 'live: menu probe setup+run' $false
        Write-Output "      menu probe error: $($_.Exception.Message)"
      } finally {
        if ($menuProc -and -not $menuProc.HasExited) { try { Stop-Process -Id $menuProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        if (Test-Path -LiteralPath $menuScript) { Remove-Item -LiteralPath $menuScript -Force -ErrorAction SilentlyContinue }
      }

      # ---------- live: v1.5.2 R-19 the README script sample is executable ----------
      # A copyable schema that nothing ever runs is how "the step schema has
      # nowhere to copy from" became a defect in the first place: the sample rots
      # silently and the next session guesses a {"steps": [...]} wrapper. So the
      # fenced json block in README is extracted VERBATIM, run
      # through the real command line as a dry run, and its step count plus every
      # action name must parse. Nothing executes (dry run), nothing is clicked.
      $rsPath = $null
      try {
        $rdText = [System.IO.File]::ReadAllText((Join-Path $script:ToolRootPath 'README.md'), [System.Text.Encoding]::UTF8)
        $mJson = [regex]::Match($rdText, '```json\s*\r?\n(?<body>\[[\s\S]*?\])\s*\r?\n```')
        ST-Check 'live: README carries a fenced script step sample' ($mJson.Success)
        if ($mJson.Success) {
          $rsPath = Join-Path $env:TEMP ('dtx-readme-steps-' + [guid]::NewGuid().ToString('N') + '.json')
          [System.IO.File]::WriteAllText($rsPath, $mJson.Groups['body'].Value, (New-Object System.Text.UTF8Encoding($false)))
          $rsOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath script $rsPath --dry-run 2>&1 | Out-String
          $rsCode = $LASTEXITCODE
          ST-Check 'live: the README script sample parses as 5 steps under --dry-run' (
            $rsCode -eq 0 -and $rsOut -match '5 step\(s\)' -and $rsOut -match 'DRY RUN')
          $rsMissing = @('focus', 'type', 'find-click', 'assert-text', 'sleep' | Where-Object { $rsOut -notmatch ('#\d+ ' + $_) })
          ST-Check 'live: every action name used in the README sample resolves' (@($rsMissing).Count -eq 0)
          if (@($rsMissing).Count -gt 0) { Write-Output ("      sample steps that did NOT parse: " + ($rsMissing -join ', ')) }
          Write-Output ("      README sample dry-run head: " + (($rsOut.Trim() -split "`r?`n" | Select-Object -First 1)))
        }
      } catch {
        ST-Check 'live: README sample run' $false
        Write-Output "      README sample error: $($_.Exception.Message)"
      } finally {
        if ($rsPath -and (Test-Path -LiteralPath $rsPath)) { Remove-Item -LiteralPath $rsPath -Force -ErrorAction SilentlyContinue }
      }

      # ---------- live: v1.5.2 WP-4 clipboard round trips (audit R-05) ----------
      # What IS reachable from a script, asserted by CONTENT (task order section
      # 10): exact text back, exact file path back, and an echo that never claims
      # "restored" over an empty file list. A faithful text+FileDrop clipboard
      # cannot be synthesized here (ContainsFileDropList=True while the list is
      # EMPTY, and cross-process the FileDrop is gone), so the 'both' branch is
      # pinned by the Resolve-ClipboardKind unit tests + this honesty test below.
      $clipBeforeTest = Save-ClipboardState
      $qxF = Join-Path $env:TEMP ('dtx-clip-' + [guid]::NewGuid().ToString('N') + '.txt')
      try {
        [System.IO.File]::WriteAllText($qxF, 'qx clip probe')
        # (1) text-only round trip, exact content
        [System.Windows.Forms.Clipboard]::Clear()
        [System.Windows.Forms.Clipboard]::SetText('QXCLIPTEXT-0421')
        Start-Sleep -Milliseconds 200
        $stT = Save-ClipboardState
        [System.Windows.Forms.Clipboard]::SetText('OTHER')
        $noteT = Restore-ClipboardState $stT
        ST-Check 'live: text-only clipboard restores the exact text' (
          $stT.Kind -ceq 'text' -and ([System.Windows.Forms.Clipboard]::GetText()) -ceq 'QXCLIPTEXT-0421' -and $noteT -like 'clipboard restored (previous content was text, 15 chars)*')
        Write-Output ("      clip text probe: kind=[" + $stT.Kind + "] text-back=[" + ([System.Windows.Forms.Clipboard]::GetText()) + "] note=[" + $noteT + "]")
        # (2) FileDrop-only round trip through the tool's own setter, exact path
        [System.Windows.Forms.Clipboard]::Clear()
        $setOk = Set-ClipboardFileDrop $qxF
        $stF = Save-ClipboardState
        [System.Windows.Forms.Clipboard]::Clear()
        $noteF = Restore-ClipboardState $stF
        $backF = @()
        if ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) { $backF = @([System.Windows.Forms.Clipboard]::GetFileDropList()) }
        ST-Check 'live: FileDrop-only clipboard restores the exact path' (
          $setOk -and $stF.Kind -ceq 'files' -and @($backF).Count -eq 1 -and $backF[0] -ceq $qxF -and $noteF -like 'clipboard restored (previous content was FileDrop, 1 file(s))*')
        Write-Output ("      clip file probe: setOk=$setOk kind=[" + $stF.Kind + "] back=[" + (@($backF) -join '; ') + "] note=[" + $noteF + "]")
        # (3) empty clipboard gets its own honest echo (not "non-text")
        [System.Windows.Forms.Clipboard]::Clear()
        Start-Sleep -Milliseconds 200
        $stE = Save-ClipboardState
        ST-Check 'live: empty clipboard is its own kind, not the unsupported bucket' (
          $stE.Kind -ceq 'none' -and (Restore-ClipboardState $stE) -like 'skipped clipboard restore (empty)*')
        # (4) the anti-false-green: an injected 'both' state whose file list cannot
        # come back must be reported as PARTIALLY restored, never as restored
        $noteFake = Restore-ClipboardState @{ Kind = 'both'; Text = 'QXFAKEBOTH'; Files = @() }
        ST-Check 'live: both-restore never claims success over zero files' (
          $noteFake -like 'clipboard PARTIALLY restored*' -and $noteFake -notlike 'clipboard restored (*')
        Write-Output ("      clipboard both echo (zero files): " + $noteFake)
      } catch {
        ST-Check 'live: clipboard round trips run' $false
        Write-Output "      clipboard round trip error: $($_.Exception.Message)"
      } finally {
        try {
          [System.Windows.Forms.Clipboard]::Clear()
          Write-Output ("      user clipboard put back: " + (Restore-ClipboardState $clipBeforeTest))
        } catch { }
        if (Test-Path -LiteralPath $qxF) { Remove-Item -LiteralPath $qxF -Force -ErrorAction SilentlyContinue }
      }

      # ---------- live: v1.5.2 WP-5 verify never fails naked (audit R-10) ----------
      # Payload chosen to be confusion-prone (O/0, 1/l). The invariant is not
      # "OCR must read it right" - it is: if OCR misses, the caller must be told
      # whether the text actually landed (UIA Name is byte-exact), and the fold
      # path must be labelled, never silently presented as an exact read.
      $verProc = $null
      $verScript = Join-Path $env:TEMP ('dtx-verify-' + [guid]::NewGuid().ToString('N') + '.ps1')
      try {
        $voOld = Resolve-Window 'DTX-VerifyProbe'
        if ($voOld) { try { Stop-Process -Id $voOld.Pid -Force -ErrorAction SilentlyContinue } catch { }; Start-Sleep -Milliseconds 500 }
        $voSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HX5 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@
[void][HX5]::SetProcessDPIAware()
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-VerifyProbe'
$f.ClientSize = New-Object System.Drawing.Size(640, 200)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(140, 1300)
$tb = New-Object System.Windows.Forms.TextBox
$tb.Multiline = $true
$tb.Font = New-Object System.Drawing.Font('Consolas', 18)
$tb.Location = New-Object System.Drawing.Point(10, 10)
$tb.Size = New-Object System.Drawing.Size(620, 180)
[void]$f.Controls.Add($tb)
[void]$f.Show()
[void][HX5]::SetWindowPos($f.Handle, [IntPtr]::Zero, 140, 1300, 656, 239, 0x0040 -bor 0x0003)
[void]$tb.Focus()
[System.Windows.Forms.Application]::Run($f)
'@
        [System.IO.File]::WriteAllText($verScript, $voSrc, (New-Object System.Text.UTF8Encoding($false)))
        $verProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $verScript -PassThru
        $vwin = $null
        $vSw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($vSw.Elapsed.TotalSeconds -lt 15) { $vwin = Resolve-Window 'DTX-VerifyProbe'; if ($vwin) { break }; Start-Sleep -Milliseconds 400 }
        if ($null -eq $vwin) { throw 'verify probe window did not appear within 15s' }
        Start-Sleep -Milliseconds 400
        $vPay = 'QXVERIFY-OK12'
        $vOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath type --to 'DTX-VerifyProbe' $vPay --verify 2>&1 | Out-String
        $vCode = $LASTEXITCODE
        $vRoots = Uia-Roots $vwin
        $vName = ''
        foreach ($el in (Uia-WalkAll $vRoots.Roots)) {
          $nmV = ''
          try { $nmV = $el.Current.Name } catch { }
          if ($nmV -like '*QXVERIFY*') { $vName = $nmV; break }
        }
        ST-Check 'live: the confusion-prone payload really landed (UIA Name byte-exact)' ($vName -ceq $vPay)
        ST-Check 'live: --verify never fails naked (either passes, or reports the UIA cross-check)' (
          $vCode -eq 0 -or $vOut -match 'UIA cross-check')
        $vFoldMark = ''
        if ($vOut -match 'confusable-fold') { $vFoldMark = ' (matched via fold, labelled)' }
        Write-Output ("      verify path: exit=$vCode label=$(if ($vOut -match '\+ |\[verify') { 'ok' } else { 'fail' })$vFoldMark")
        ST-Check 'live: a folded verify match is labelled, never presented as an exact read' (
          -not ($vOut -match '\[verify: OCR match') -or ($vOut -notmatch 'confusable') -or ($vOut -match 'confusable-fold'))
      } catch {
        ST-Check 'live: verify probe setup+run' $false
        Write-Output "      verify probe error: $($_.Exception.Message)"
      } finally {
        if ($verProc -and -not $verProc.HasExited) { try { Stop-Process -Id $verProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        if (Test-Path -LiteralPath $verScript) { Remove-Item -LiteralPath $verScript -Force -ErrorAction SilentlyContinue }
      }

      # ---------- live: v1.5.3 --verify-timeout, measured both ways ----------
      # Closes the '--verify 4s not parameterised' leftover. The fixture is a
      # single MASKED TextBox filling the client area: whatever is typed renders
      # as dots, so the OCR verification can never succeed and the give-up is
      # deterministic (a normal field would make this test race the OCR instead of
      # measuring the timeout). The field covers the whole client rect, so every
      # click inside the window is guaranteed to land in it - no off-screen or
      # occluded coordinate maths, which is exactly how the first draft of this
      # case was wrong.
      #   with --verify-timeout 1 -> gives up at ~1s
      #   without the flag        -> still waits the full default 4s
      # Only the pair proves the flag reached the function AND that the default
      # did not drift; a single green run would prove neither.
      $mpProc = $null
      $mpScript = Join-Path $env:TEMP ('dtx-mask-' + [guid]::NewGuid().ToString('N') + '.ps1')
      try {
        $moOld = Resolve-Window 'DTX-MaskProbe'
        if ($moOld) { try { Stop-Process -Id $moOld.Pid -Force -ErrorAction SilentlyContinue } catch { }; Start-Sleep -Milliseconds 500 }
        $moSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HX9 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@
[void][HX9]::SetProcessDPIAware()
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-MaskProbe'
$f.ClientSize = New-Object System.Drawing.Size(700, 400)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(300, 500)
$tb = New-Object System.Windows.Forms.TextBox
$tb.Multiline = $true
$tb.UseSystemPasswordChar = $true
$tb.Font = New-Object System.Drawing.Font('Consolas', 18)
# explicit bounds, no Dock: docked-layout order across two controls is exactly the
# kind of thing that would silently move the click target off the field. Client is
# 700x400 -> label strip 0..60 (OCR-readable), masked field 60..400 (every click
# at the window centre lands in it).
$tb.Location = New-Object System.Drawing.Point(0, 60)
$tb.Size = New-Object System.Drawing.Size(700, 340)
[void]$f.Controls.Add($tb)
# The OCR-FRIENDLY half of the fixture. The masked box guarantees the verification
# timeout; this label guarantees a find-text hit, so the pinned --json contract can
# be asserted against real output from BOTH commands without leaving the probe
# window. Letter set deliberately avoids the confusable glyphs (no I/l/1/O/0), so
# the hit never depends on the fold path.
$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = 'QXSHAPETXT'
$lbl.Font = New-Object System.Drawing.Font('Consolas', 26, [System.Drawing.FontStyle]::Bold)
$lbl.TextAlign = 'MiddleCenter'
$lbl.Location = New-Object System.Drawing.Point(0, 0)
$lbl.Size = New-Object System.Drawing.Size(700, 60)
$lbl.BackColor = [System.Drawing.Color]::White
$lbl.ForeColor = [System.Drawing.Color]::Black
[void]$f.Controls.Add($lbl)
[void]$f.Show()
[void][HX9]::SetWindowPos($f.Handle, [IntPtr]::Zero, 300, 500, 716, 439, 0x0040 -bor 0x0003)
[void]$tb.Focus()
[System.Windows.Forms.Application]::Run($f)
'@
        [System.IO.File]::WriteAllText($mpScript, $moSrc, (New-Object System.Text.UTF8Encoding($false)))
        $mpProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $mpScript -PassThru
        $mwin = $null
        $mSw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($mSw.Elapsed.TotalSeconds -lt 15) { $mwin = Resolve-Window 'DTX-MaskProbe'; if ($mwin) { break }; Start-Sleep -Milliseconds 400 }
        if ($null -eq $mwin) { throw 'mask probe window did not appear within 15s' }
        Start-Sleep -Milliseconds 400
        $mRect = Get-TargetRect $mwin
        $mcx = [int]($mRect.X + $mRect.W / 2)
        $mcy = [int]($mRect.Y + $mRect.H / 2)

        # W / A / C / B form a timeout LADDER: a discarded warm-up call, then
        # 1s / 2s / default 4s. What is compared is the patience the tool reports it
        # ACTUALLY SPENT ('waited Ns' in the failure line), not the child process's
        # wall clock - the first measurement run buried the signal in startup noise
        # (timeout 1 took 3.75s end to end, timeout 2 took 3.51s: the ordering
        # itself came out wrong). Measured patience here: 1.2s / 2.1s / 4.1s, so
        # every rung gets its own band plus a gap to its neighbour - drop the flag
        # at one call site and that rung collapses onto ~4s (band and gap both break),
        # drift the default and the 4s rung breaks, swap two settings and their gap
        # breaks. A single green rung would prove none of this.
        # All payloads are '--' sentinels fed through --needle, so the content
        # assertion does triple duty: the flag was consumed, its value was consumed
        # with it, and nothing of the flag itself leaked into what got typed.
        $payW = '--DTXVTW'
        $payA = '--DTXVTA'
        $payC = '--DTXVTC'
        $payB = '--DTXVTB'
        $outW = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath type --to 'DTX-MaskProbe' --needle $payW --verify --verify-timeout 1 2>&1 | Out-String
        $txtW = ''
        $snapW = Get-UiaWindowNames $mwin
        $txtW = (@($snapW.Names | Where-Object { $_ -like '*DTXVT*' }) | Select-Object -First 1)
        $warmOk = ($outW -match 'verify FAILED after 1s' -and $txtW -ceq $payW)
        Write-Output "      (warm-up call ok=$warmOk field='$txtW')"

        # A: the 'type --to' call site, 1s
        $outA = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath type --to 'DTX-MaskProbe' --needle $payA --verify --verify-timeout 1 2>&1 | Out-String
        $codeA = $LASTEXITCODE
        $txtA = ''
        $snapA = Get-UiaWindowNames $mwin
        $txtA = (@($snapA.Names | Where-Object { $_ -like '*DTXVT*' }) | Select-Object -First 1)
        $wA = 0.0
        if ($outA -match 'waited ([0-9.]+)s') { $wA = [double]$Matches[1] }
        # content equality: the field must hold EXACTLY what was sent. UIA reports
        # the real text even though the field renders dots, which rules out "it
        # timed out because nothing was ever sent" as the explanation for the FAIL.
        ST-Check 'live: type --to honours --verify-timeout 1 (patience reported, exit 1, keys really landed)' (
          $outA -match 'verify FAILED after 1s' -and $codeA -eq 1 -and $txtA -ceq ($txtW + $payA))
        ST-Check 'live: --verify-timeout 1 spent 1-3s of patience, not the 4s default' (
          $wA -ge 1.0 -and $wA -le 3.0)

        # C: the 'type-in' call site parses and forwards it too (its own parser)
        $outC = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath type-in $mcx $mcy --needle $payC --verify --verify-timeout 2 2>&1 | Out-String
        $txtC = ''
        $snapC = Get-UiaWindowNames $mwin
        $txtC = (@($snapC.Names | Where-Object { $_ -like '*DTXVT*' }) | Select-Object -First 1)
        $wC = 0.0
        if ($outC -match 'waited ([0-9.]+)s') { $wC = [double]$Matches[1] }
        ST-Check 'live: type-in honours --verify-timeout 2 (separate parser, separate call site, waits after the 1s rung)' (
          $outC -match 'verify FAILED after 2s' -and $outC -notmatch 'unknown flag' -and
          $wC -ge 2.0 -and $wC -le 4.0 -and ($wC - $wA) -ge 0.5)
        # 'type-in' clicks first, so the caret parks wherever the click lands and
        # the payload may be inserted mid-string; what must hold regardless is that
        # EXACTLY its characters were added - no keystrokes lost or doubled.
        ST-Check 'live: type-in added exactly the payload length to the field (no keys lost or doubled)' (
          $txtC -like ('*' + $payC) -and $txtC.Length -eq ($txtA.Length + $payC.Length))

        # B: no flag -> the 4s default is untouched (regression against drift)
        $outB = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath type --to 'DTX-MaskProbe' --needle $payB --verify 2>&1 | Out-String
        $txtB = ''
        $snapB = Get-UiaWindowNames $mwin
        $txtB = (@($snapB.Names | Where-Object { $_ -like '*DTXVT*' }) | Select-Object -First 1)
        $wB = 0.0
        if ($outB -match 'waited ([0-9.]+)s') { $wB = [double]$Matches[1] }
        ST-Check 'live: without --verify-timeout the default 4s patience is unchanged' (
          $outB -match 'verify FAILED after 4s' -and $wB -ge 4.0 -and $wB -le 7.0)
        ST-Check 'live: the 4s default outwaits both short settings by their real margin (flag not ignored)' (
          ($wB - $wA) -ge 2.0 -and ($wB - $wC) -ge 1.5)
        ST-Check 'live: the masked field accumulated every payload exactly (no keystrokes lost)' (
          $txtB.Length -eq ($txtC.Length + $payB.Length) -and $txtB -like ('*' + $payB))
        Write-Output "      mask probe content: W='$txtW' A='$txtA' C='$txtC' B='$txtB'"
        Write-Output ("      verify-timeout patience spent: 1s=${wA}s 2s=${wC}s default=${wB}s (click $mcx,$mcy; A-exit=$codeA)")

        # v1.5.3 JSON contract, checked against REAL command output rather than only
        # the builder: the offline contract units prove what the builder emits, this
        # proves the two --json branches really go through it (a hand-built object at
        # a call site would otherwise stay invisible to every other check). The probe's
        # own label is the needle, drawn 26pt bold on white deliberately so the hit is
        # not a coin flip; its letters avoid the confusable set (no I/l/1/O/0), so the
        # hit never depends on the fold path either. Isolated in its own try/catch:
        # an OCR miss here must name itself, not silence the timeout checks above.
        # NOTE: these go through a child process, not Invoke-DesktopCommand - the
        # global --json flag is stripped in the CLI entry, so calling the dispatcher
        # in-process hands the case parser a flag it legitimately does not own
        # (measured: "read-text: unknown flag '--json'"). End to end means end to end.
        try {
          $jRect = Get-TargetRect $mwin
          # expected sets in their own variables: `$x -ceq (@(..) | Sort-Object) -join ','`
          # binds LEFT to right, so the -ceq would evaluate first and -join would hand
          # ST-Check a STRING where it declares [bool] - that is exactly what made this
          # case die on its first run (ParameterBindingArgumentTransformation on 'ok').
          $jWantRead = Get-JsonContractKeySet 'read'
          $jWantFind = Get-JsonContractKeySet 'find'
          # The FULL CLI head must ride along: the first live run of the split-stream capture
          # shipped the bare arguments, so powershell.exe read 'find-text ...' as ITS OWN
          # command line (CommandNotFoundException, exit 1, empty stdout). One string, quotes
          # around the entry path - the same shape the child identity probe below uses.
          $jArgRead = '-NoProfile -ExecutionPolicy Bypass -File "' + $script:ToolEntryPath + '" read-text ' + ([string]$jRect.X) + ' ' + ([string]$jRect.Y) + ' ' + ([string]$jRect.W) + ' ' + ([string]$jRect.H) + ' --json'
          # v3.0.1 (audit #20): the sibling cases below (assert-*, imgclick) already go
          # through cmd /c and even name this trap - these two were left on a bare
          # `powershell ... 2>&1`, where ANY stderr line from the child is turned into a
          # terminating NativeCommandError while $ErrorActionPreference is Stop. cmd /c
          # fixed THAT, but 2026-10-29's first-ever live paste ladder exposed the second
          # layer: cmd /c makes cmd.exe the child's REAL parent, so the internal-parent
          # verification (marker PID vs real parent PID, caller-runtime) fails, the child
          # is treated as its own root, the legitimate father-and-child coexistence of a
          # live ladder is reported as `desktop tool overlap` on stderr - and cmd merges
          # that WARNING straight into the JSON stream, so ConvertFrom-Json gets nothing.
          # Start-Process with SEPARATE redirect files keeps stdout JSON-pure (any warning
          # lands in the stderr file, read but never parsed), and restores the direct
          # parentage the root-id chain expects, so the overlap report does not fire at
          # all. ReadAllText, not [string](Get-Content -Raw): an empty stdout must parse
          # as failure, not as a null that dies on .Trim (2026-10-29, live-r2).
          $jErr = Join-Path $OutDir ('st-json-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.stderr.txt')
          $jOut = $jErr -replace '\.stderr\.txt$', '.stdout.txt'
          $jCp = Start-Process -FilePath 'powershell.exe' -ArgumentList $jArgRead -RedirectStandardOutput $jOut -RedirectStandardError $jErr -Wait -PassThru -NoNewWindow
          $jTxt = ''
          if (Test-Path -LiteralPath $jOut) { $jTxt = [IO.File]::ReadAllText($jOut).Trim() }
          $jObj = $null
          try { $jObj = $jTxt | ConvertFrom-Json } catch { }
          $jKeys = ''
          if ($jObj) { $jKeys = (@($jObj.PSObject.Properties.Name | Sort-Object) -join ',') }
          ST-Check 'live: read-text --json top-level key set matches the pinned contract end to end' (
            $jKeys -ceq $jWantRead)
          $jArgsFind = @('find-text', [string]$jRect.X, [string]$jRect.Y, [string]$jRect.W, [string]$jRect.H, '--needle', 'QXSHAPETXT', '--json')
          $jArgFind = '-NoProfile -ExecutionPolicy Bypass -File "' + $script:ToolEntryPath + '" find-text ' + ([string]$jRect.X) + ' ' + ([string]$jRect.Y) + ' ' + ([string]$jRect.W) + ' ' + ([string]$jRect.H) + ' --needle QXSHAPETXT --json'
          $jErr2 = Join-Path $OutDir ('st-json-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.stderr.txt')
          $jOut2 = $jErr2 -replace '\.stderr\.txt$', '.stdout.txt'
          $jCp2 = Start-Process -FilePath 'powershell.exe' -ArgumentList $jArgFind -RedirectStandardOutput $jOut2 -RedirectStandardError $jErr2 -Wait -PassThru -NoNewWindow
          $jTxt2 = ''
          if (Test-Path -LiteralPath $jOut2) { $jTxt2 = [IO.File]::ReadAllText($jOut2).Trim() }
          $jObj2 = $null
          try { $jObj2 = $jTxt2 | ConvertFrom-Json } catch { }
          $jKeys2 = ''
          if ($jObj2) { $jKeys2 = (@($jObj2.PSObject.Properties.Name | Sort-Object) -join ',') }
          # a miss yields an ERROR line, never an object: that must show up as RED
          # here, because "shape matches" inferred from no output is not a shape check
          ST-Check 'live: find-text --json top-level key set matches the pinned contract end to end' (
            $jKeys2 -ceq $jWantFind)
          Write-Output "      --json contract (real output): read-text=[$jKeys] find-text=[$jKeys2]"
          if (-not $jKeys) { Write-Output "      read-text --json produced no object (exit=$($jCp.ExitCode)): $((($jTxt -split "`r?`n") | Select-Object -First 1))" }
          if (-not $jKeys2) { Write-Output "      find-text --json produced no object (exit=$($jCp2.ExitCode)): $((($jTxt2 -split "`r?`n") | Select-Object -First 1))" }
        } catch {
          ST-Check 'live: --json contract cases ran' $false
          Write-Output "      --json contract error: $($_.Exception.Message)"
        }

        # D-1 (v4.6.13) live: one real window, one real move, two real reads (a sub-block of the probe case, no banner of its own)
        # Anchors are WINDOW-RELATIVE by contract, so moving the window must NOT look like drift:
        # the relocation re-resolves the window it profiles (pid + proc, title as tiebreak), reads
        # the surface again and subtracts the CURRENT rect origin. The profile's own rect= line
        # must therefore show the moved origin while drift stays ~0. That is the whole point of
        # calibrating anchors instead of remembering screen coordinates.
        if (-not $ocrOk) {
          ST-Skip 'live (D-1): pt-profile on a real window names the rendered label as an anchor' 'no OCR language pack / recognizer unreachable - the anchor road cannot be measured'
          ST-Skip 'live (D-1): pt-anchor re-reads the moved window with window-relative drift and the new rect' 'no OCR language pack / recognizer unreachable - the anchor road cannot be measured'
        } else {
          try {
            $ptLvTag = [guid]::NewGuid().ToString('N').Substring(0, 8)
            $ptLvProf = Join-Path $OutDir ('st-pt-' + $ptLvTag + '.json')
            $ptLvErr = Join-Path $OutDir ('st-pt-' + $ptLvTag + '.stderr.txt')
            $ptLvOut = $ptLvErr -replace '\.stderr\.txt$', '.stdout.txt'
            $ptLvArg = '-NoProfile -ExecutionPolicy Bypass -File "' + $script:ToolEntryPath + '" pt-profile "DTX-MaskProbe" --samples 2 --save "' + $ptLvProf + '"'
            $ptLvCp = Start-Process -FilePath 'powershell.exe' -ArgumentList $ptLvArg -RedirectStandardOutput $ptLvOut -RedirectStandardError $ptLvErr -Wait -PassThru -NoNewWindow
            $ptLvTxt = ''
            if (Test-Path -LiteralPath $ptLvOut) { $ptLvTxt = [IO.File]::ReadAllText($ptLvOut) }
            $ptLvObj = $null
            try { $ptLvObj = Import-PtProfile $ptLvProf 'pt-anchor' } catch { }
            $ptLvPid = -1
            $ptLvAnch = @()
            $ptLvHit = $null
            if ($null -ne $ptLvObj) {
              $ptLvPid = [int](Get-OptValue (Get-OptValue $ptLvObj 'window') 'pid')
              $ptLvAnch = @(Get-OptValue $ptLvObj 'anchors')
              $ptLvHit = Find-PtAnchorMatch $ptLvAnch 'QXSHAPETXT'
            }
            ST-Check 'live (D-1): pt-profile on a real window names the rendered label as an anchor' (
              ($ptLvCp.ExitCode -eq 0) -and ($null -ne $ptLvObj) -and
              (([string](Get-OptValue $ptLvObj 'basis')) -ceq 'window') -and
              ($ptLvPid -eq [int]$mwin.Pid) -and ($null -ne $ptLvHit) -and ($ptLvHit.Kind -ceq 'exact') -and
              ($ptLvTxt -match 'saved: '))
            if (($ptLvCp.ExitCode -ne 0) -or ($null -eq $ptLvObj) -or ($ptLvPid -ne [int]$mwin.Pid)) {
              Write-Output "      D-1 live profile: exit=$($ptLvCp.ExitCode) pid=$ptLvPid want=$([int]$mwin.Pid) anchors=$(@($ptLvAnch).Count) out=[$ptLvTxt]"
            }
            $ptLvRect = Get-TargetRect $mwin
            $ptLvNx = [int]$ptLvRect.X + 60
            $ptLvNy = [int]$ptLvRect.Y - 40
            Invoke-DesktopCommand 'win-move' @('DTX-MaskProbe', [string]$ptLvNx, [string]$ptLvNy) | Out-Null
            Start-Sleep -Milliseconds 600
            $ptLvErr2 = Join-Path $OutDir ('st-pt-' + $ptLvTag + '-a.stderr.txt')
            $ptLvOut2 = $ptLvErr2 -replace '\.stderr\.txt$', '.stdout.txt'
            $ptLvArg2 = '-NoProfile -ExecutionPolicy Bypass -File "' + $script:ToolEntryPath + '" pt-anchor "' + $ptLvProf + '" --needle QXSHAPETXT --max-drift 8'
            $ptLvCp2 = Start-Process -FilePath 'powershell.exe' -ArgumentList $ptLvArg2 -RedirectStandardOutput $ptLvOut2 -RedirectStandardError $ptLvErr2 -Wait -PassThru -NoNewWindow
            $ptLvTxt2 = ''
            if (Test-Path -LiteralPath $ptLvOut2) { $ptLvTxt2 = [IO.File]::ReadAllText($ptLvOut2) }
            $ptLvDx = 999
            $ptLvDy = 999
            if ($ptLvTxt2 -match 'drift=\(([-0-9]+),([-0-9]+)\)') { $ptLvDx = [int]$Matches[1]; $ptLvDy = [int]$Matches[2] }
            $ptLvRx = -99999
            if ($ptLvTxt2 -match 'rect=\(([0-9]+),([0-9]+),([0-9]+),([0-9]+)\)') { $ptLvRx = [int]$Matches[1] }
            ST-Check 'live (D-1): pt-anchor re-reads the moved window with window-relative drift and the new rect' (
              ($ptLvCp2.ExitCode -eq 0) -and ($ptLvTxt2 -match 'match=exact') -and ($ptLvTxt2 -match 'verdict=within') -and
              ([math]::Abs($ptLvDx) -le 3) -and ([math]::Abs($ptLvDy) -le 3) -and
              ([math]::Abs($ptLvRx - $ptLvNx) -le 2))
            if (($ptLvCp2.ExitCode -ne 0) -or ([math]::Abs($ptLvDx) -gt 3) -or ([math]::Abs($ptLvDy) -gt 3) -or ([math]::Abs($ptLvRx - $ptLvNx) -gt 2)) {
              Write-Output "      D-1 live anchor: exit=$($ptLvCp2.ExitCode) drift=($ptLvDx,$ptLvDy) rect-x=$ptLvRx want-x=$ptLvNx out=[$ptLvTxt2]"
            }
          } catch {
            ST-Check 'live (D-1): the pt-profile / pt-anchor anchor road ran' $false
            Write-Output "      D-1 live error: $($_.Exception.Message)"
          }
        }
      } catch {
        ST-Check 'live: mask probe setup+run' $false
        Write-Output "      mask probe error: $($_.Exception.Message)"
      } finally {
        if ($mpProc -and -not $mpProc.HasExited) { try { Stop-Process -Id $mpProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        if (Test-Path -LiteralPath $mpScript) { Remove-Item -LiteralPath $mpScript -Force -ErrorAction SilentlyContinue }
      }

      # ---------- live: v1.5.5 D-1 reachability + D-4 miss tail + D-8 anonymous coverer ----------
      # D-1 sat under 297 green checks because each handler parsed its own flag AFTER
      # its own Split-Target call had already refused the token: the flags were
      # documented, the parsing code existed, nothing was reachable. Offline units can
      # only show that Strip-OwnFlags parses - so the judge here is the real
      # 'powershell -File' path, and what is pinned is (a) the value the tool reports it
      # used, (b) the wall time that value actually bought, (c) for --index, WHICH OF
      # TWO IDENTICAL LABELS took the click. "exit 0" alone was already true when the
      # feature was broken, so it is never the assertion.
      $fpProc = $null
      $anProc = $null
      $fpScript = Join-Path $env:TEMP ('dtx-flag-' + [guid]::NewGuid().ToString('N') + '.ps1')
      $anScript = Join-Path $env:TEMP ('dtx-anon-' + [guid]::NewGuid().ToString('N') + '.ps1')
      $fpRes = Join-Path $env:TEMP 'dtx-flagprobe-click.txt'
      try {
        $fpOld = Resolve-Window 'DTX-FlagProbe'
        if ($fpOld) { try { Stop-Process -Id $fpOld.Pid -Force -ErrorAction SilentlyContinue } catch { }; Start-Sleep -Milliseconds 400 }
        $fpSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HX11 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[void][HX11]::SetProcessDPIAware()
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-FlagProbe'
$f.ClientSize = New-Object System.Drawing.Size(700, 420)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(300, 470)
$f.TopMost = $true
$f.BackColor = [System.Drawing.Color]::White
# Two labels with the SAME text, deliberately on different rows: OCR groups by
# vertical position, so they are two hits in a known order (top first). Each one
# writes its own tag when it receives a real mouse-down, which is what makes
# --index observable instead of merely echoable. Glyph set avoids I/l/1/O/0.
$lblA = New-Object System.Windows.Forms.Label
$lblA.Text = 'QXDWNTXT'
$lblA.Font = New-Object System.Drawing.Font('Consolas', 26, [System.Drawing.FontStyle]::Bold)
$lblA.TextAlign = 'MiddleCenter'
$lblA.Location = New-Object System.Drawing.Point(0, 0)
$lblA.Size = New-Object System.Drawing.Size(340, 60)
$lblA.BackColor = [System.Drawing.Color]::White
$lblA.ForeColor = [System.Drawing.Color]::Black
$lblA.Add_MouseDown({ [System.IO.File]::WriteAllText(($env:TEMP + '\dtx-flagprobe-click.txt'), 'A') })
[void]$f.Controls.Add($lblA)
$lblB = New-Object System.Windows.Forms.Label
$lblB.Text = 'QXDWNTXT'
$lblB.Font = New-Object System.Drawing.Font('Consolas', 26, [System.Drawing.FontStyle]::Bold)
$lblB.TextAlign = 'MiddleCenter'
$lblB.Location = New-Object System.Drawing.Point(0, 100)
$lblB.Size = New-Object System.Drawing.Size(340, 60)
$lblB.BackColor = [System.Drawing.Color]::White
$lblB.ForeColor = [System.Drawing.Color]::Black
$lblB.Add_MouseDown({ [System.IO.File]::WriteAllText(($env:TEMP + '\dtx-flagprobe-click.txt'), 'B') })
[void]$f.Controls.Add($lblB)
[void]$f.Show()
[System.Windows.Forms.Application]::Run($f)
'@
        [System.IO.File]::WriteAllText($fpScript, $fpSrc, (New-Object System.Text.UTF8Encoding($false)))
        $fpProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $fpScript -PassThru
        $fwin = $null
        $fpSw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($fpSw.Elapsed.TotalSeconds -lt 15) { $fwin = Resolve-Window 'DTX-FlagProbe'; if ($fwin) { break }; Start-Sleep -Milliseconds 400 }
        if ($null -eq $fwin) { throw 'flag probe window did not appear within 15s' }
        Start-Sleep -Milliseconds 600
        $fr = Get-TargetRect $fwin
        # one child process per call, exactly the way a user invokes the tool
        $fpCmd = {
          param([string]$fpArgs)
          $swF = [System.Diagnostics.Stopwatch]::StartNew()
          $oF = (& cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File `"$script:ToolEntryPath`" $fpArgs 2>&1") | Out-String
          $cF = $LASTEXITCODE
          $swF.Stop()
          return @{ Out = $oF; Code = $cF; Sec = $swF.Elapsed.TotalSeconds }
        }

        $hvDef = & $fpCmd 'hover 60 60'
        $hvLong = & $fpCmd 'hover 60 60 --dwell 2200'
        $hvBad = & $fpCmd 'hover 60 60 --dwell abc'
        ST-Check 'live: hover --dwell reaches the handler through the real CLI and reports the value it used' (
          $hvLong.Code -eq 0 -and $hvLong.Out -match 'for 2200ms' -and $hvLong.Out -notmatch 'unknown flag')
        ST-Check 'live: hover without --dwell still dwells the documented 800ms (default did not drift)' (
          $hvDef.Code -eq 0 -and $hvDef.Out -match 'for 800ms')
        ST-Check 'live: --dwell 2200 bought ~1.4s of real dwell over the default (flag not merely parsed)' (
          ($hvLong.Sec - $hvDef.Sec) -ge 1.2)
        ST-Check 'live: hover --dwell abc is refused by name instead of defaulting or going into the payload' (
          $hvBad.Code -ne 0 -and $hvBad.Out.Contains('--dwell') -and $hvBad.Out.Contains('needs a whole number'))
        Write-Output ("      dwell: default=" + [math]::Round($hvDef.Sec, 2) + "s set=" + [math]::Round($hvLong.Sec, 2) +
          "s delta=" + [math]::Round(($hvLong.Sec - $hvDef.Sec), 2) + "s bad-exit=$($hvBad.Code)")

        # drag points are measured from THIS window's own visible rect and land in its
        # empty client area (labels sit top-left, x<340 / y<160): a press-drag-release
        # across nothing of anyone else's.
        $dx1 = [int]($fr.X + $fr.W * 0.60); $dy1 = [int]($fr.Y + $fr.H * 0.70)
        $dx2 = [int]($fr.X + $fr.W * 0.80); $dy2 = [int]($fr.Y + $fr.H * 0.86)
        $dgDef = & $fpCmd ("drag $dx1 $dy1 $dx2 $dy2")
        $dgSet = & $fpCmd ("drag $dx1 $dy1 $dx2 $dy2 --steps 60 --hold 1100")
        ST-Check 'live: drag --steps/--hold reach the handler and are reported back verbatim' (
          $dgSet.Code -eq 0 -and $dgSet.Out -match 'steps=60 hold=1100ms' -and $dgSet.Out -notmatch 'unknown flag')
        ST-Check 'live: drag without the flags keeps the documented steps=14 hold=120ms defaults' (
          $dgDef.Code -eq 0 -and $dgDef.Out -match 'steps=14 hold=120ms')
        ST-Check 'live: --steps 60 --hold 1100 really cost ~1.5s more than the defaults (both flags bite)' (
          ($dgSet.Sec - $dgDef.Sec) -ge 1.2)
        Write-Output ("      drag: default=" + [math]::Round($dgDef.Sec, 2) + "s set=" + [math]::Round($dgSet.Sec, 2) +
          "s delta=" + [math]::Round(($dgSet.Sec - $dgDef.Sec), 2) + "s")

        if (Test-Path -LiteralPath $fpRes) { Remove-Item -LiteralPath $fpRes -Force }
        $fc0 = & $fpCmd 'find-click DTX-FlagProbe QXDWNTXT --index 0'
        $fc0Tag = ''
        if (Test-Path -LiteralPath $fpRes) { $fc0Tag = [System.IO.File]::ReadAllText($fpRes).Trim() }
        if (Test-Path -LiteralPath $fpRes) { Remove-Item -LiteralPath $fpRes -Force }
        $fc1 = & $fpCmd 'find-click DTX-FlagProbe QXDWNTXT --index 1'
        $fc1Tag = ''
        if (Test-Path -LiteralPath $fpRes) { $fc1Tag = [System.IO.File]::ReadAllText($fpRes).Trim() }
        $fcOob = & $fpCmd 'find-click DTX-FlagProbe QXDWNTXT --index 9'
        ST-Check 'live: find-click --index 0/1 really clicks the first and the second identical hit' (
          $fc0.Code -eq 0 -and $fc0Tag -ceq 'A' -and $fc1.Code -eq 0 -and $fc1Tag -ceq 'B')
        ST-Check 'live: an out-of-range --index is refused with the number it received, nothing clicked' (
          $fcOob.Code -ne 0 -and $fcOob.Out.Contains('--index 9') -and $fcOob.Out.Contains('but only'))
        Write-Output ("      index: i0 exit=$($fc0.Code) tag=[$fc0Tag] i1 exit=$($fc1.Code) tag=[$fc1Tag] i9 exit=$($fcOob.Code)")
        Write-Output ("      index: " + ((($fc1.Out.Trim() -split "`r?`n") | Select-Object -First 1)))

        $ftMiss = & $fpCmd 'find-text DTX-FlagProbe --needle ZZZNOZZZ'
        $fcMiss = & $fpCmd 'find-click DTX-FlagProbe ZZZNOZZZ'
        ST-Check 'live: find-text and find-click misses print the SAME OCR tail shape (one constructor, real output)' (
          $ftMiss.Code -ne 0 -and $fcMiss.Code -ne 0 -and
          $ftMiss.Out -match 'OCR read [0-9]+ line\(s\) total:' -and $fcMiss.Out -match 'OCR read [0-9]+ line\(s\) total:')
        Write-Output ("      miss tail: " + ((($ftMiss.Out.Trim() -split "`r?`n") | Select-Object -Last 1)))

        # D-8: the covering window here has NO title at all - the shape that used to
        # print as title='' and send people looking for a window the taskbar does not
        # even show. It is placed over the centre of the flag probe so the 5x5 grid
        # must hit it.
        $anSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HX12 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[void][HX12]::SetProcessDPIAware()
$f2 = New-Object System.Windows.Forms.Form
$f2.Text = ''
$f2.ClientSize = New-Object System.Drawing.Size(260, 180)
$f2.StartPosition = 'Manual'
$f2.Location = New-Object System.Drawing.Point(560, 620)
$f2.TopMost = $true
$f2.BackColor = [System.Drawing.Color]::RosyBrown
[void]$f2.Show()
[System.Windows.Forms.Application]::Run($f2)
'@
        [System.IO.File]::WriteAllText($anScript, $anSrc, (New-Object System.Text.UTF8Encoding($false)))
        $anProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $anScript -PassThru
        $anSeen = $false
        $anOut = $null
        for ($anTry = 0; $anTry -lt 4 -and -not $anSeen; $anTry++) {
          Start-Sleep -Milliseconds 700
          $anOut = & $fpCmd 'read-text DTX-FlagProbe --max-lines 2'
          if ($anOut.Out.Contains("pid=$($anProc.Id) proc=")) { $anSeen = $true }
        }
        $anLine = ''
        foreach ($anL in ($anOut.Out -split "`r?`n")) { if ($anL -like ('*covering: pid=' + $anProc.Id + '*')) { $anLine = $anL.Trim() } }
        ST-Check 'live: an anonymous covering window is named by its class, never as an empty title (D-8)' (
          $anSeen -and $anOut.Out -match 'title=\(class ' -and $anOut.Out -notmatch "title=''")
        Write-Output ("      anon coverer pid=$($anProc.Id): " + $anLine)
      } catch {
        ST-Check 'live: v1.5.5 flag-reachability probe setup+run' $false
        Write-Output "      flag reachability error: $($_.Exception.Message)"
      } finally {
        if ($anProc -and -not $anProc.HasExited) { try { Stop-Process -Id $anProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        if ($fpProc -and -not $fpProc.HasExited) { try { Stop-Process -Id $fpProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        foreach ($fpT in @($fpScript, $anScript, $fpRes)) { if (Test-Path -LiteralPath $fpT) { Remove-Item -LiteralPath $fpT -Force -ErrorAction SilentlyContinue } }
      }

      # ---------- live: v1.5.6 idempotent activation, PROVEN BY Z-ORDER (owner supplement 4) ----------
      # `activated=no (was fg)` is a string the code writes about itself - exactly the
      # shape this project has been killing for five rounds ("exit 0 is not a judge").
      # So the verdict is corroborated by an EXTERNAL observable: a second window of the
      # same process is raised ABOVE the (still foreground) host with SWP_NOACTIVATE.
      # Re-raising the host via BringWindowToTop must push that popup down - which is the
      # mechanism behind report D-2's "the second click of a dropdown never lands".
      # Idempotent path: order preserved. --always-activate (the rollback switch) doubles
      # as the CONTROL GROUP: if the order assertion were insensitive it would stay green
      # here too, and it does not.
      $apProc = $null
      $apScript = Join-Path $env:TEMP ('dtx-act-' + [guid]::NewGuid().ToString('N') + '.ps1')
      try {
        $apOld = Resolve-Window 'DTX-ActA'
        if ($apOld) { try { Stop-Process -Id $apOld.Pid -Force -ErrorAction SilentlyContinue } catch { }; Start-Sleep -Milliseconds 500 }
        $apSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HX13 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
}
"@
[void][HX13]::SetProcessDPIAware()
$a = New-Object System.Windows.Forms.Form
$a.Text = 'DTX-ActA'
$a.ClientSize = New-Object System.Drawing.Size(600, 400)
$a.StartPosition = 'Manual'
$a.Location = New-Object System.Drawing.Point(300, 500)
$a.BackColor = [System.Drawing.Color]::White
# the toggle target: it fills the lower-left band of the client area, so the test can
# aim at a fraction of the MEASURED window rect instead of trusting these numbers
$cb = New-Object System.Windows.Forms.CheckBox
$cb.Text = 'QXWKMT'
$cb.Font = New-Object System.Drawing.Font('Consolas', 22, [System.Drawing.FontStyle]::Bold)
$cb.Location = New-Object System.Drawing.Point(10, 300)
$cb.Size = New-Object System.Drawing.Size(350, 90)
$cb.UseVisualStyleBackColor = $false
$cb.BackColor = [System.Drawing.Color]::White
[void]$a.Controls.Add($cb)
[void]$a.Show()
$b = New-Object System.Windows.Forms.Form
$b.Text = 'DTX-ActB'
$b.ClientSize = New-Object System.Drawing.Size(260, 150)
$b.StartPosition = 'Manual'
$b.Location = New-Object System.Drawing.Point(700, 520)
$b.BackColor = [System.Drawing.Color]::RosyBrown
$b.TopMost = $false
# SWP_NOACTIVATE (0x10) | SWP_SHOWWINDOW (0x40): B goes to the top of the NON-topmost
# band without taking foreground, so A stays GetForegroundWindow() while B sits above it.
[void][HX13]::SetWindowPos($b.Handle, [IntPtr]::Zero, 700, 520, 276, 189, 0x10 -bor 0x40)
# Stage the state report D-2 describes FROM INSIDE the process that owns both windows.
# WHY THE CONSOLE MATTERS (measured three times): Windows only lets a process take
# foreground when it already owns it. A fixture launched with -WindowStyle Hidden never
# owns it, so its SetForegroundWindow is refused no matter how long it retries - and
# hiding the console was exactly the change that broke this test. Launched with its
# console, the new process DOES own foreground at spawn; the loop below hands that to
# the form, and only then hides the console window.
$stageLoop = {
  $swSt = [System.Diagnostics.Stopwatch]::StartNew()
  $staged = $false
  while ($swSt.Elapsed.TotalSeconds -lt 8 -and -not $staged) {
    [void][HX13]::SetForegroundWindow($a.Handle)
    [void][HX13]::BringWindowToTop($a.Handle)
    Start-Sleep -Milliseconds 250
    [void][HX13]::SetWindowPos($b.Handle, [IntPtr]::Zero, 700, 520, 276, 189, 0x10)
    Start-Sleep -Milliseconds 150
    if ([HX13]::GetForegroundWindow() -eq $a.Handle) { $staged = $true }
  }
  return $staged
}
$staged = & $stageLoop
# Hiding the console can hand foreground to the NEXT window in z order - measured here:
# after SW_HIDE the foreground had moved to B, not stayed on A. So re-stage after it and
# report the RESULT OF THAT, never the earlier success: the status file must describe the
# state the test will actually find.
$consoleHwnd = [HX13]::GetConsoleWindow()
if ($consoleHwnd -ne [IntPtr]::Zero) { [void][HX13]::ShowWindow($consoleHwnd, 0) }   # SW_HIDE
$staged = & $stageLoop
[System.IO.File]::WriteAllText((Join-Path $env:TEMP 'dtx-act-stage.txt'), $(if ($staged) { 'staged=1' } else { 'staged=0' }))
[System.Windows.Forms.Application]::Run($a)
'@
        [System.IO.File]::WriteAllText($apScript, $apSrc, (New-Object System.Text.UTF8Encoding($false)))
        $apStageFile = Join-Path $env:TEMP 'dtx-act-stage.txt'
        # removed BEFORE the spawn: the fixture writes its own verdict a few seconds after
        # it comes up, and deleting it later would race that write away
        if (Test-Path -LiteralPath $apStageFile) { Remove-Item -LiteralPath $apStageFile -Force }
        # launched WITH its console (see the fixture): the new console owns foreground at
        # spawn, which is what lets the fixture hand foreground to its own form. The
        # fixture hides the console itself once staged.
        $apProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $apScript -PassThru
        $awin = $null
        $apSw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($apSw.Elapsed.TotalSeconds -lt 15) { $awin = Resolve-Window 'DTX-ActA'; if ($awin) { break }; Start-Sleep -Milliseconds 400 }
        if ($null -eq $awin) { throw 'activation probe window did not appear within 15s' }
        Start-Sleep -Milliseconds 800
        # z-order index of a titled top-level window, read from the enumeration order
        # (EnumWindows walks top -> bottom). This is the EXTERNAL observable - the whole
        # point is that `activated=` alone would only be the code talking about itself.
        $zPair = {
          param([string]$t1, [string]$t2)
          $rows = @(Get-WinList)
          $i1 = -1; $i2 = -1; $k = 0
          foreach ($r in $rows) {
            if ($i1 -lt 0 -and $r.Title -ceq $t1) { $i1 = $k }
            if ($i2 -lt 0 -and $r.Title -ceq $t2) { $i2 = $k }
            $k++
          }
          return @{ A = $i1; B = $i2 }
        }
        $bRow = @(Get-WinList | Where-Object { $_.Title -ceq 'DTX-ActB' })
        if (@($bRow).Count -lt 1) { throw 'the second (popup-like) fixture window is not enumerable' }
        $bH = $bRow[0].Handle
        $ar = Get-TargetRect $awin
        # click points are fractions of the MEASURED window rect (never constants):
        # $cby lands on the checkbox, $esy on the empty white band, both clear of B
        # (B covers screen x 700..976, y 520..709).
        $cbx = [int]($ar.X + $ar.W * 0.30); $cby = [int]($ar.Y + $ar.H * 0.86)
        $esx = [int]($ar.X + $ar.W * 0.82); $esy = [int]($ar.Y + $ar.H * 0.93)
        $ecBox = "$([int]($ar.X + 6)),$([int]($ar.Y + $ar.H * 0.72)),$([int]($ar.W * 0.55)),$([int]($ar.H * 0.24))"
        $ecStill = "$([int]($ar.X + 6)),$([int]($ar.Y + $ar.H * 0.35)),$([int]($ar.W * 0.50)),$([int]($ar.H * 0.20))"
        # Format-ExpectChangeVerdict is the single producer of this line and it renders a
        # rect as "region (X,Y) WxH", NOT as the comma form the flag was given. Asking the
        # live output to contain "315,656,302,89" was red while the product was right - the
        # red meant "my assertion typed the shape by hand". Derive the shown form instead.
        $ecShown = { param([string]$s) $q = ($s -split ','); return "($($q[0]),$($q[1])) $($q[2])x$($q[3])" }
        $apCmd = {
          param([string]$apArgs)
          $oA = (& cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File `"$script:ToolEntryPath`" $apArgs 2>&1") | Out-String
          $cA = $LASTEXITCODE
          return @{ Out = $oA; Code = $cA }
        }
        # BringWindowToTop does NOT activate, so this puts B back above a still-foreground
        # A between cases without touching who owns the keyboard.
        $raiseB = { [void][DT]::BringWindowToTop($bH); Start-Sleep -Milliseconds 350 }
        # The fixture staged itself (see the staging loop in $apSrc) and reports the result
        # through a status file: the parent NEVER tries to take foreground, because
        # SetForegroundWindow from a non-foreground process is blocked by the foreground
        # lock and that is exactly what made three live rounds report fg=False (while a
        # standalone probe running `focus` could take it - the difference is which process
        # owns the input, not the API).
        $apStageFile = Join-Path $env:TEMP 'dtx-act-stage.txt'
        $stageTxt = ''
        $apStageSw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($apStageSw.Elapsed.TotalSeconds -lt 14 -and -not $stageTxt) {
          Start-Sleep -Milliseconds 300
          if (Test-Path -LiteralPath $apStageFile) { $stageTxt = ([System.IO.File]::ReadAllText($apStageFile)).Trim() }
        }
        $zPre = & $zPair 'DTX-ActA' 'DTX-ActB'
        $fgPre = ([DT]::GetForegroundWindow() -eq $awin.Handle)
        $stageOk = ($stageTxt -ceq 'staged=1' -and $fgPre -eq $true -and $zPre.A -ge 0 -and $zPre.B -ge 0 -and $zPre.B -lt $zPre.A)
        if ($stageOk) {
          ST-Check 'live: activation fixture staged itself - A foreground AND B above it (precondition measured, not assumed)' $true
        } else {
          # An ENVIRONMENT precondition, not a behaviour under test: this is reported as a
          # SKIP with the numbers, never as a green and never as a code-red. Relaxing the
          # assertions below is the thing the owner has sent back three times, so the case
          # count drops instead and says why.
          Write-Output "      stage NOT set (file='$stageTxt' fgOnA=$fgPre z: A=$($zPre.A) B=$($zPre.B))"
          ST-Skip 'live: activation fixture staged itself - A foreground AND B above it' "foreground is held by another app during this run ($stageTxt, fgOnA=$fgPre); the cases below cannot be staged"
          ST-Skip 'live: v1.5.6 z-order / activated= / PreSendAbove / expect-change cases' 'same - see the precondition skip line for the measured numbers'
          throw 'stage-not-set'
        }
        $rIdem = & $apCmd "click $esx $esy --to DTX-ActA"
        $zIdem = & $zPair 'DTX-ActA' 'DTX-ActB'
        ST-Check 'live: --to on the already-foreground window says activated=no and does not re-raise it' (
          $rIdem.Code -eq 0 -and $rIdem.Out -match 'activated=no \(was fg\)' -and $rIdem.Out -notmatch 'this call activated')
        ST-Check 'live: the window sitting ABOVE the foreground host keeps its z position (external proof, not self-report)' (
          $zIdem.B -lt $zIdem.A)
        Write-Output ("      z-order after idempotent click: A=$($zIdem.A) B=$($zIdem.B) (precondition A=$($zPre.A) B=$($zPre.B))")
        # R-06 baseline (owner Q-02): the skip must not change what the guard records as
        # "same-pid windows already on top". Measured against the forced path, not argued.
        # !! The first version of this check also demanded a z-order read taken AFTER the
        # in-process Resolve-Target call. That conjunct is confounded by the test itself:
        # Resolve-Target runs inside the selftest process, and if A had lost foreground to
        # whatever the previous sub-case left running, the idempotent branch is not the one
        # being exercised - the call activates A and pushes B down, so the post-read can only
        # ever be red. The staged state is therefore sampled BEFORE each call (that is what
        # the case assumes), and the thing under test is the B-in-baseline set difference.
        & $raiseB
        $zPreIdem = & $zPair 'DTX-ActA' 'DTX-ActB'
        $idTgt = Resolve-Target 'DTX-ActA'
        $idBase = @($idTgt.PreSendAbove)
        & $raiseB
        $zPreForced = & $zPair 'DTX-ActA' 'DTX-ActB'
        $fcTgt = Resolve-Target 'DTX-ActA' $false $true
        $fcBase = @($fcTgt.PreSendAbove)
        # !! PreSendAbove holds the OBJECTS Get-SamePidWindowsAbove builds (Handle/Class/
        # Title), not bare handles - the first version of this compared `$_ -eq $bH`, which
        # is an object against an IntPtr and is false for every element, so the case could
        # NEVER go green while the product behaved correctly. Compare on .Handle and print
        # the handles, so a future mismatch names what it saw instead of being red forever.
        $idHandles = @($idBase | ForEach-Object { $_.Handle })
        $fcHandles = @($fcBase | ForEach-Object { $_.Handle })
        $bInIdem = (@($idHandles | Where-Object { $_ -eq $bH }).Count -eq 1)
        $bInForced = (@($fcHandles | Where-Object { $_ -eq $bH }).Count -ge 1)
        # both halves must start from the SAME staged state, or the set difference says
        # nothing about activation - that is an unstaged environment and gets a SKIP, never
        # a code-red and never a green.
        $reStageOk = ($zPreIdem.B -lt $zPreIdem.A -and $zPreForced.B -lt $zPreForced.A)
        Write-Output ("      precondition before each call: idempotent A=$($zPreIdem.A) B=$($zPreIdem.B) / forced A=$($zPreForced.A) B=$($zPreForced.B)")
        if ($reStageOk) {
          ST-Check 'live: skipping activation keeps the PreSendAbove baseline intact (R-06 semantics, measured not inferred)' (
            $bInIdem -and -not $bInForced)
        } else {
          ST-Skip 'live: skipping activation keeps the PreSendAbove baseline intact (R-06 semantics, measured not inferred)' "B was not above A before the call (idem A=$($zPreIdem.A) B=$($zPreIdem.B), forced A=$($zPreForced.A) B=$($zPreForced.B)) - the fixture lost its staged state mid-block, an environment fact and not a behaviour"
        }
        Write-Output ("      PreSendAbove: idempotent=$($idBase.Count) forced=$($fcBase.Count) (B handle $bH) activated: idem=$($idTgt.Activated) forced=$($fcTgt.Activated) saw: idem=[" + ($idHandles -join ',') + "] forced=[" + ($fcHandles -join ',') + "]")
        # expect-change: the no-effect case FIRST (nothing focusable has been touched
        # yet, so no focus rectangle can move pixels inside the measured rect), then the
        # toggle case. Both must exit 0 - a WARN is not a failure.
        & $raiseB
        $ecNo = & $apCmd "click $esx $esy --to DTX-ActA --expect-change $ecStill"
        $ecYes = & $apCmd "click $cbx $cby --to DTX-ActA --expect-change $ecBox"
        # expected values are built into variables FIRST (never call a scriptblock from
        # inside a double-quoted string: PowerShell 5.1 cannot parse `$( ... & $sb $x ... )`
        # there and the whole line failed to compile)
        $ecStillShown = & $ecShown $ecStill
        $ecBoxShown = & $ecShown $ecBox
        $ecNoWarn = ($ecNo.Out -match 'PIXEL-IDENTICAL')
        $ecNoRect = $ecNo.Out.Contains($ecStillShown)
        $ecYesChg = ($ecYes.Out -match 'changed \(md5')
        $ecYesRect = $ecYes.Out.Contains($ecBoxShown)
        Write-Output ("      expect-change measured: no exit=" + $ecNo.Code + " warn=" + $ecNoWarn + " names-region=" + $ecNoRect + " [" + $ecStillShown + "] / yes exit=" + $ecYes.Code + " changed=" + $ecYesChg + " names-region=" + $ecYesRect + " [" + $ecBoxShown + "]")
        ST-Check 'live: --expect-change WARNs on a pixel-identical region and still exits 0 (WARN is not failure)' (
          $ecNo.Code -eq 0 -and $ecNoWarn -and $ecNoRect)
        ST-Check 'live: --expect-change reports CHANGED when the click really toggled something, exit 0' (
          $ecYes.Code -eq 0 -and $ecYesChg -and $ecYesRect)
        $ecBad = & $apCmd "click $esx $esy --to DTX-ActA --expect-change 1,2,3"
        ST-Check 'live: a malformed --expect-change rect is refused before anything is clicked' (
          $ecBad.Code -ne 0 -and $ecBad.Out -match 'expect-change needs x,y,w,h')
        # CONTROL GROUP last (it reorders the fixture by design): the rollback switch must
        # take the old path, say so, warn, and demonstrably push the popup down. If this
        # went green without the flip, the assertion above would have been vacuous.
        & $raiseB
        $zCtlPre = & $zPair 'DTX-ActA' 'DTX-ActB'
        $rCtl = & $apCmd "click $esx $esy --to DTX-ActA --always-activate"
        $zCtl = & $zPair 'DTX-ActA' 'DTX-ActB'
        ST-Check 'live: --always-activate takes the old path, reports activated=yes and emits the NOTICE' (
          $zCtlPre.B -lt $zCtlPre.A -and $rCtl.Code -eq 0 -and $rCtl.Out -match 'activated=yes \(--always-activate\)' -and $rCtl.Out -match 'this call activated')
        ST-Check 'live: CONTROL GROUP - the old behaviour really does push the popup below the host (so the test above has teeth)' (
          $zCtl.A -lt $zCtl.B)
        Write-Output ("      control: pre A=$($zCtlPre.A) B=$($zCtlPre.B) -> after A=$($zCtl.A) B=$($zCtl.B)")
        # D-7 on the real CLI, with the SAME two-window fixture: A (604x447, unowned) is
        # the process's main window and B (276x189) is not, so focusing B must name A and
        # focusing A must say nothing. Both halves are required - an unconditional note
        # would be the noise people learn to skip, and a note nobody checks is the D-7 bug.
        $d7B = & $apCmd 'focus DTX-ActB'
        $d7A = & $apCmd 'focus DTX-ActA'
        $d7NoteB = ($d7B.Out -match 'has a main window handle=')
        $d7NoteA = ($d7A.Out -match 'has a main window handle=')
        ST-Check 'live: focusing the NON-MAIN window of a two-window pid names the main one (D-7)' (
          $d7B.Code -eq 0 -and $d7NoteB -and $d7B.Out.Contains('DTX-ActB'))
        ST-Check 'live: focusing the MAIN window says nothing (the note is conditional, not noise)' (
          $d7A.Code -eq 0 -and -not $d7NoteA)
        Write-Output ("      D-7 note: B(non-main) shown=" + $d7NoteB + " / A(main) silent=" + (-not $d7NoteA))
        $d7Rows = & $apCmd 'wins'
        $d7RowB = @(($d7Rows.Out -split "`r?`n") | Where-Object { $_.Contains('DTX-ActB') })
        $d7RowA = @(($d7Rows.Out -split "`r?`n") | Where-Object { $_.Contains('DTX-ActA') })
        $d7Cols = ''
        if (@($d7RowB).Count -ge 1 -and @($d7RowA).Count -ge 1) { $d7Cols = "A[" + $d7RowA[0].Substring(0, [math]::Min(120, $d7RowA[0].Length)) + "] B[" + $d7RowB[0].Substring(0, [math]::Min(120, $d7RowB[0].Length)) + "]" }
        ST-Check 'live: wins carries main=yes on the host row and main=no on the popup row (columns are real, not lint-only)' (
          @($d7RowA).Count -ge 1 -and @($d7RowB).Count -ge 1 -and $d7RowA[0].Contains('main=yes') -and $d7RowB[0].Contains('main=no'))
        Write-Output ("      D-7 wins rows: " + $d7Cols)
        $apSteps = Join-Path $env:TEMP ('dtx-dry-' + [guid]::NewGuid().ToString('N') + '.json')
        [System.IO.File]::WriteAllText($apSteps, ('[ { "click": [' + $esx + ', ' + $esy + '], "to": "DTX-ActA" } ]'), (New-Object System.Text.UTF8Encoding($false)))
        # v3.0.1 (audit #20): $apSteps is a TEMP path, and TEMP is under the profile on
        # every Windows box - a profile directory whose own name contains a space, which
        # is what makes the unquoted concatenation split into two arguments. The path
        # shape stays out of this file on purpose: the publication gate's USER-PATH rule
        # is not something a comment should ask an exemption for.
        # made cmd /c hand powershell two arguments and the case failed on a missing file.
        # Quoted now, like the -File path a few lines above.
        $dryOut = & $apCmd "script `"$apSteps`" --dry-run"
        ST-Check 'live: script dry-run flags action steps that have no expectation (A-5)' (
          $dryOut.Code -eq 0 -and $dryOut.Out -match 'no expect/expect-gone' -and $dryOut.Out -match '#1 ')
        if (Test-Path -LiteralPath $apSteps) { Remove-Item -LiteralPath $apSteps -Force -ErrorAction SilentlyContinue }
      } catch {
        if ("$($_.Exception.Message)" -ceq 'stage-not-set') {
          # already reported as SKIPs above - a blocked environment precondition must not
          # also show up as a code red, or the next reader will hunt for a defect
          Write-Output '      activation block skipped (foreground precondition), not failed'
        } else {
          ST-Check 'live: v1.5.6 activation/expect-change probe setup+run' $false
          Write-Output "      activation probe error: $($_.Exception.Message)"
        }
      } finally {
        if ($apProc -and -not $apProc.HasExited) { try { Stop-Process -Id $apProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        $apLeft = Resolve-Window 'DTX-ActB'
        if ($apLeft) { try { Stop-Process -Id $apLeft.Pid -Force -ErrorAction SilentlyContinue } catch { } }
        if (Test-Path -LiteralPath $apScript) { Remove-Item -LiteralPath $apScript -Force -ErrorAction SilentlyContinue }
      }

      # ---------- live: v1.5.2 WP-6 foreground guard phases (audit R-13) ----------
      # Fast path must be FAST (the old loop slept 400ms before its first check),
      # and the give-up path must still spend the full patience (so a target that
      # cannot be raised is still refused, not merely slow to refuse). The desktop
      # is the natural unfakeable negative: a background process cannot force
      # Program Manager foreground under the lock (documented machine fact).
      $gfxProc = $null
      $gfxScript = Join-Path $env:TEMP ('dtx-gfx-' + [guid]::NewGuid().ToString('N') + '.ps1')
      try {
        $gOld = Resolve-Window 'DTX-GfxProbe'
        if ($gOld) { try { Stop-Process -Id $gOld.Pid -Force -ErrorAction SilentlyContinue } catch { }; Start-Sleep -Milliseconds 400 }
        $gSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HX6 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@
[void][HX6]::SetProcessDPIAware()
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-GfxProbe'
$f.ClientSize = New-Object System.Drawing.Size(300, 160)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(200, 1400)
$f.TopMost = $true
[void]$f.Show()
[void][HX6]::SetWindowPos($f.Handle, [IntPtr]::Zero, 200, 1400, 316, 199, 0x0040)
[void]$f.Activate()
[System.Windows.Forms.Application]::Run($f)
'@
        [System.IO.File]::WriteAllText($gfxScript, $gSrc, (New-Object System.Text.UTF8Encoding($false)))
        $gfxProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $gfxScript -PassThru
        $gWin = $null
        $gSw0 = [System.Diagnostics.Stopwatch]::StartNew()
        while ($gSw0.Elapsed.TotalSeconds -lt 15) { $gWin = Resolve-Window 'DTX-GfxProbe'; if ($gWin) { break }; Start-Sleep -Milliseconds 300 }
        if ($null -eq $gWin) { throw 'gfx probe window did not appear within 15s' }
        Start-Sleep -Milliseconds 400
        $gAct = Activate-Win $gWin
        $gSw = [System.Diagnostics.Stopwatch]::StartNew()
        $gHit = Wait-Foreground $gWin
        $gMs = $gSw.Elapsed.TotalMilliseconds
        # the teeth are in the SHAPE, not in whether this machine granted the
        # activation: whenever the window is foreground, the guard must confirm on
        # the very first look (old shape: >=400 ms because it slept before checking)
        ST-Check 'live: guard fast path never sleeps before its first check (hit => <250ms)' (
          (-not $gHit) -or ($gMs -lt 250))
        ST-Check 'live: probe window can be made foreground at all (test fixture is valid)' ($gAct -eq $true -and $gHit -eq $true)
        Write-Output ("      guard fast path: activated=$gAct hit=$gHit in $([math]::Round($gMs, 0)) ms (old shape: >=400 ms)")
        $gDesk = Resolve-Window 'Program Manager'
        $gSw2 = [System.Diagnostics.Stopwatch]::StartNew()
        $gHit2 = $false
        if ($gDesk) { $gHit2 = Wait-Foreground $gDesk }
        $gMs2 = $gSw2.Elapsed.TotalMilliseconds
        ST-Check 'live: guard give-up path still spends the full patience (~1.1s) and returns false' (
          $gDesk -ne $null -and $gHit2 -eq $false -and $gMs2 -gt 900)
        Write-Output ("      guard give-up path: hit=$gHit2 in $([math]::Round($gMs2, 0)) ms")
      } catch {
        ST-Check 'live: guard phase tests run' $false
        Write-Output "      guard phase error: $($_.Exception.Message)"
      } finally {
        if ($gfxProc -and -not $gfxProc.HasExited) { try { Stop-Process -Id $gfxProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        if (Test-Path -LiteralPath $gfxScript) { Remove-Item -LiteralPath $gfxScript -Force -ErrorAction SilentlyContinue }
      }

      # ---------- live: v1.5.3 R-06 same-process popup on top is reported ----------
      # Own windows only, spawned and killed here. The child shows a second
      # top-level window of ITS pid 150ms after being activated; mode 'opaque' is
      # menu-shaped (can hold the keyboard) and must be reported, mode
      # 'transparent' is tooltip-shaped (WS_EX_TRANSPARENT, click-through) and must
      # NOT be reported - and in that case the payload has to be proven to have
      # landed byte-exact (task order rule 10: never assert only the exit code).
      $popProc = $null
      $popScript = Join-Path $env:TEMP ('dtx-pop-' + [guid]::NewGuid().ToString('N') + '.ps1')
      try {
        $popSrc = @'
param([string]$Mode)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HX7 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
}
"@
[void][HX7]::SetProcessDPIAware()
$Main = New-Object System.Windows.Forms.Form
$Main.Text = 'DTX-PopupProbe'
$Main.ClientSize = New-Object System.Drawing.Size(700, 300)
$Main.StartPosition = 'Manual'
$Main.Location = New-Object System.Drawing.Point(150, 1250)
$Tb = New-Object System.Windows.Forms.TextBox
$Tb.Multiline = $true
$Tb.Font = New-Object System.Drawing.Font('Consolas', 16)
$Tb.Location = New-Object System.Drawing.Point(10, 10)
$Tb.Size = New-Object System.Drawing.Size(680, 280)
[void]$Main.Controls.Add($Tb)
$Pop = New-Object System.Windows.Forms.Form
$Pop.Text = 'DTX-PopupLayer'
$Pop.FormBorderStyle = 'None'
$Pop.ShowInTaskbar = $false
$Pop.StartPosition = 'Manual'
$Pop.Location = New-Object System.Drawing.Point(300, 1350)
$Pop.Size = New-Object System.Drawing.Size(300, 120)
$Pop.TopMost = $true
$Pop.Opacity = 0.98
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 150
$Timer.Add_Tick({
  $Timer.Stop()
  [void]$Pop.Show()
  [void][HX7]::SetWindowPos($Pop.Handle, [IntPtr](-1), 300, 1350, 300, 120, 0x0040)
  if ($Mode -eq 'transparent') {
    $ex = [HX7]::GetWindowLong($Pop.Handle, -20)
    [void][HX7]::SetWindowLong($Pop.Handle, -20, ($ex -bor 0x20))
  } else {
    [void]$Pop.Activate()
  }
})
# Every time the MAIN window is (re)activated - which is exactly what the tool's
# foreground guard does - the layer is hidden first and re-shown 150ms later.
# That reproduces the real shape: the popup appears AFTER the guard took its
# baseline, not before it (a pre-existing layer is correctly NOT a new event).
$Main.Add_Activated({
  if ($Pop.Visible) { [void]$Pop.Hide() }
  $Timer.Start()
})
[void]$Main.Show()
[void][HX7]::SetWindowPos($Main.Handle, [IntPtr]::Zero, 150, 1250, 716, 339, 0x0040)
[void]$Main.Activate()
[void]$Tb.Focus()
[System.Windows.Forms.Application]::Run($Main)
'@
        $popPathT = $popScript
        [System.IO.File]::WriteAllText($popScript, $popSrc, (New-Object System.Text.UTF8Encoding($false)))
        foreach ($mode in @('transparent', 'opaque')) {
          $stale = Resolve-Window 'DTX-PopupProbe'
          if ($stale) { try { Stop-Process -Id $stale.Pid -Force -ErrorAction SilentlyContinue } catch { }; Start-Sleep -Milliseconds 500 }
          $popProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $popPathT, '-Mode', $mode -PassThru
          $pwin = $null
          $pSw = [System.Diagnostics.Stopwatch]::StartNew()
          while ($pSw.Elapsed.TotalSeconds -lt 15) { $pwin = Resolve-Window 'DTX-PopupProbe'; if ($pwin) { break }; Start-Sleep -Milliseconds 300 }
          if ($null -eq $pwin) { throw "popup probe ($mode) did not appear within 15s" }
          Start-Sleep -Milliseconds 600
          $pay = 'QXPOP-' + $mode.ToUpper()
          $pOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath type --to 'DTX-PopupProbe' $pay 2>&1 | Out-String
          $pCode = $LASTEXITCODE
          $pRoots = Uia-Roots (Resolve-Window 'DTX-PopupProbe')
          $pName = ''
          foreach ($el in (Uia-WalkAll $pRoots.Roots)) { $nmP = ''; try { $nmP = $el.Current.Name } catch { }; if ($nmP -like '*QXPOP-*') { $pName = $nmP; break } }
          if ($mode -eq 'transparent') {
            ST-Check 'live: a click-through tooltip on top does NOT warn and the payload lands byte-exact' (
              $pCode -eq 0 -and $pName -ceq $pay -and $pOut -notmatch 'same-process popup')
          } else {
            ST-Check 'live: a keyboard-capable same-process popup on top is reported (WARN + exit 1)' (
              $pCode -eq 1 -and $pOut -match 'same-process popup' -and $pOut -match 'NOT confirmed changed')
          }
          Write-Output ("      popup probe ($mode): exit=$pCode landed=[" + $pName + "] out=" + (($pOut.Trim() -split "`r?`n" | Select-Object -Last 1)))
          if ($popProc -and -not $popProc.HasExited) { try { Stop-Process -Id $popProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        }
      } catch {
        ST-Check 'live: popup probe setup+run' $false
        Write-Output "      popup probe error: $($_.Exception.Message)"
      } finally {
        if ($popProc -and -not $popProc.HasExited) { try { Stop-Process -Id $popProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
        if (Test-Path -LiteralPath $popScript) { Remove-Item -LiteralPath $popScript -Force -ErrorAction SilentlyContinue }
        $strag = Resolve-Window 'DTX-PopupProbe'
        if ($strag) { try { Stop-Process -Id $strag.Pid -Force -ErrorAction SilentlyContinue } catch { } }
        $strag2 = Resolve-Window 'DTX-PopupLayer'
        if ($strag2) { try { Stop-Process -Id $strag2.Pid -Force -ErrorAction SilentlyContinue } catch { } }
      }

      # ocr-cap: the read-only threshold view must report a live engine limit.
      $capOut = (Invoke-DesktopCommand 'ocr-cap' @()) -join "`n"
      $mCap = $capOut -match 'MaxImageDimension = (\d+)'
      $capVal = 0L
      if ($mCap) { $capVal = [long]$Matches[1] }
      $capReal = 0L; try { $capReal = Get-OcrMaxDimension } catch { $capReal = 0L }
      ST-Check 'live: ocr-cap reports MaxImageDimension > 0 (equals engine value)' ($mCap -and $capVal -gt 0 -and $capVal -eq $capReal)
      Write-Output "      ocr-cap: MaxImageDimension=$capVal (engine=$capReal)"

      # ---------- live: v1.5.1 occlusion self-proof + sidecar staleness ----------
      # Everything here spawns its OWN windows (a blank target form in the
      # bottom-left free area + a small topmost coverer form) and never
      # touches user windows; both child processes are killed in the finally.
      $occTProcs = New-Object System.Collections.ArrayList
      $occTmp = New-Object System.Collections.ArrayList
      try {
        $tgtTitle = 'DTX-OccTarget'
        $covTitle = 'DTX-OccCover'
        foreach ($tt in @($tgtTitle, $covTitle)) {
          $sw0 = Resolve-Window $tt
          if ($sw0) { try { Stop-Process -Id $sw0.Pid -Force -ErrorAction SilentlyContinue } catch { } }
        }
        Start-Sleep -Milliseconds 400
        $tScript = Join-Path $env:TEMP ('dtx-occt-' + [guid]::NewGuid().ToString('N') + '.ps1')
        $cScript = Join-Path $env:TEMP ('dtx-occc-' + [guid]::NewGuid().ToString('N') + '.ps1')
        [void]$occTmp.Add($tScript); [void]$occTmp.Add($cScript)
        $tSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HX1 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@
[void][HX1]::SetProcessDPIAware()
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-OccTarget'
$f.ClientSize = New-Object System.Drawing.Size(500, 360)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(60, 1600)
$f.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 40)
$f.Show()
[void][HX1]::SetWindowPos($f.Handle, [IntPtr]::Zero, 60, 1600, 516, 399, 0x50)
while ($true) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100 }
'@
        $cSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HX2 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@
[void][HX2]::SetProcessDPIAware()
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-OccCover'
$f.ClientSize = New-Object System.Drawing.Size(320, 220)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(1900, 300)
$f.TopMost = $true
$f.BackColor = [System.Drawing.Color]::FromArgb(18, 58, 24)
$f.Show()
[void][HX2]::SetWindowPos($f.Handle, [IntPtr](-1), 1900, 300, 336, 259, 0x50)
while ($true) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100 }
'@
        [System.IO.File]::WriteAllText($tScript, $tSrc, (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::WriteAllText($cScript, $cSrc, (New-Object System.Text.UTF8Encoding($false)))
        $tProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tScript -PassThru -WindowStyle Hidden
        [void]$occTProcs.Add($tProc)
        $tW = $null
        $swT = [System.Diagnostics.Stopwatch]::StartNew()
        while ($swT.Elapsed.TotalSeconds -lt 15) { $tW = Resolve-Window $tgtTitle; if ($tW) { break }; Start-Sleep -Milliseconds 300 }
        if (-not $tW) { throw 'DTX-OccTarget window did not appear within 15s' }
        Start-Sleep -Milliseconds 300
        $occFg = [bool][DT]::SetForegroundWindow($tW.Handle)
        Start-Sleep -Milliseconds 300

        # Item 6 premise, established rather than assumed. Measured 2026-10-30 (live-r1/r2 plus
        # standalone probes outside the ladder): when a foreign process owns the foreground, this
        # fixture cannot be put above it. Inside the fixture's own process, TopMost=$true together
        # with SetWindowPos(HWND_TOPMOST) still left 4 of these 25 points owned by that window; a
        # SetWindowPos(HWND_TOPMOST) issued from outside answers True with the WS_EX_TOPMOST bit
        # still clear and the same 4 points unchanged. So "this hardcoded rect is empty" is not a
        # premise I get for free - it depends on what the owner happens to have open.
        # The lever that does work is geometry: move OUR OWN window (a user window is never
        # touched) to a rect whose sample points all hit-test back to the fixture. Candidate 1 is
        # the rect the fixture already sits in, so an uncluttered desktop takes the old path and
        # spends nothing. Verification uses Get-HitWindow, the primitive item 7 already leans on,
        # not the verdict function under test.
        $vsO = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $occCands = @( ,@($tW.Left, $tW.Top) )
        for ($occCy = [int]($vsO.Y + 60); ($occCy + $tW.H) -le ($vsO.Y + $vsO.Height); $occCy += ($tW.H + 60)) {
          for ($occCx = [int]($vsO.X + 60); ($occCx + $tW.W) -le ($vsO.X + $vsO.Width); $occCx += ($tW.W + 60)) { $occCands += , @($occCx, $occCy) }
        }
        $occOwn = $false
        $occTries = 0
        foreach ($occCd in $occCands) {
          $occTries++
          if (-not ($occCd[0] -eq $tW.Left -and $occCd[1] -eq $tW.Top)) {
            Invoke-DesktopCommand 'win-move' @($tgtTitle, [string]$occCd[0], [string]$occCd[1]) | Out-Null
            Start-Sleep -Milliseconds 250
            $tW = Resolve-Window $tgtTitle
          }
          $occOwn = $true
          foreach ($occQ in @((Get-OcclusionPoints $tW.Left $tW.Top $tW.W $tW.H 5).Points)) {
            $occH = Get-HitWindow $occQ.X $occQ.Y
            if (-not $occH -or $occH.Hwnd -ne $tW.Handle) { $occOwn = $false; break }
          }
          if ($occOwn -or $occTries -ge 12) { break }
        }

        # item 6 (true negative): an uncovered target reads 0%
        $occN = Get-OcclusionVerdict $tW.Left $tW.Top $tW.W $tW.H $tW.Handle 5
        if ($occOwn) {
          ST-Check 'live: occlusion true negative - clean target reads 0%' ($occN.Checked -gt 0 -and $occN.Mismatch -eq 0 -and $occN.Pct -eq 0)
        } else {
          ST-Skip 'live: occlusion true negative - clean target reads 0%' "premise not established: no rect owned all 25 sample points in $occTries tries (the desktop is covered; this is not a verdict failure)"
        }
        # This line is the ONLY way this leg can be attributed from the transcript, and a bare
        # percentage cannot attribute anything: it says "16%", not "who". It therefore goes
        # through the same renderer pair the product uses (R-25), and reports the two facts that
        # decide whether the leg was ever runnable - whether the fixture ended up owning its own
        # pixels, how many rects it took to get there, and whether the foreground change Windows
        # refuses was granted.
        $occNCov = Format-OcclusionCovering @($occN.Covering) $occN.Checked
        Write-Output ("      occlusion negative: " + (Format-OcclusionVerdict 'read' @{ X = $tW.Left; Y = $tW.Top; W = $tW.W; H = $tW.H } ([int]$occN.Pct) (Get-OptValue $occNCov 'Summary') ([string]$occN.Err)) + " checked=$($occN.Checked) ms=$($occN.Ms) foreground-set=$occFg premise-free=$occOwn rect-tries=$occTries")
        foreach ($occNCovLine in @((Get-OptValue $occNCov 'Lines'))) { Write-Output "        covering: $occNCovLine" }

        # item 7 (false-positive guard): fullscreen click-through overlays must
        # never be counted as covering. Uses the REAL system hit test, so the
        # check pins the "no rectangle intersection" design directly.
        $vsO2 = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $winsO = @(Get-WinList)
        $ovCand = @($winsO | Where-Object {
          ($_.W -ge ($vsO2.Width - 4) -and $_.H -ge ($vsO2.Height - 4)) -and
          (($_.Proc -eq 'NVIDIA Overlay') -or ($_.Proc -eq 'TextInputHost') -or ($_.Class -eq 'Progman') -or ($_.Class -eq 'CEF-OSC-WIDGET'))
        })
        if (@($ovCand).Count -eq 0) {
          ST-Skip 'live: click-through overlays are not counted as covering' 'no fullscreen click-through overlay (NVIDIA Overlay / TextInputHost / Progman) present on this desktop right now'
        } else {
          $pgC = Get-OcclusionPoints $tW.Left $tW.Top $tW.W $tW.H 1
          $ctrP = $pgC.Points[0]
          $hitC = Get-HitWindow $ctrP.X $ctrP.Y
          $occC = Get-OcclusionVerdict $tW.Left $tW.Top $tW.W $tW.H $tW.Handle 5
          $badOv = @($occC.Covering | Where-Object { (@($ovCand | ForEach-Object { $_.Handle }) -contains $_.Hwnd) })
          ST-Check 'live: click-through overlays are not counted as covering (hit-test, not rect overlap)' (
            $badOv.Count -eq 0 -and $null -ne $hitC -and $hitC.Hwnd -eq $tW.Handle)
          Write-Output "      overlay candidates: $(@($ovCand | ForEach-Object { "$($_.Proc):$($_.Class)" }) -join '; ')"
          Write-Output "      centre hit (own target): pid=$($hitC.Pid) title='$($hitC.Title)'; overlays in covering: $($badOv.Count)"
        }

        # item 5 (true positive): a spawned coverer moved over the centre
        $cProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $cScript -PassThru -WindowStyle Hidden
        [void]$occTProcs.Add($cProc)
        $cW = $null
        $swC = [System.Diagnostics.Stopwatch]::StartNew()
        while ($swC.Elapsed.TotalSeconds -lt 15) { $cW = Resolve-Window $covTitle; if ($cW) { break }; Start-Sleep -Milliseconds 300 }
        if (-not $cW) { throw 'DTX-OccCover window did not appear within 15s' }
        Start-Sleep -Milliseconds 300
        $mvX = [int]($tW.Left + $tW.W / 2 - $cW.W / 2)
        $mvY = [int]($tW.Top + $tW.H / 2 - $cW.H / 2)
        Invoke-DesktopCommand 'win-move' @($covTitle, [string]$mvX, [string]$mvY) | Out-Null
        Start-Sleep -Milliseconds 600
        $occP = Get-OcclusionVerdict $tW.Left $tW.Top $tW.W $tW.H $tW.Handle 5
        $covHit = @($occP.Covering | Where-Object { $_.Pid -eq $cW.Pid })
        ST-Check 'live: occlusion true positive - spawned coverer counted (pid in Covering)' ($occP.Pct -gt 0 -and $covHit.Count -ge 1)
        Write-Output "      occlusion positive: pct=$($occP.Pct)% coverer-pid=$($cW.Pid) count=$($covHit[0].Count) checked=$($occP.Checked)"

        # v1.5.4 (R-25) integration: the TEXT report and the --json report must be the
        # same list seen two ways. Offline contract tests pin the renderer; this pins
        # that the real command line actually goes through it - the summary pid equals
        # json coveredBy[0].pid, the line says which scan and rect it measured, and the
        # stderr detail names as many coverers as the json carries (the bug was the text
        # path dropping the 4th while json kept it).
        # The two calls go through cmd /c, NOT 'powershell ... 2>&1': the occlusion
        # WARNING is written with [Console]::Error.WriteLine, i.e. straight to the
        # stderr handle, which PowerShell cannot merge as a stream - under
        # ErrorActionPreference=Stop it surfaces as a terminating NativeCommandError
        # and kills the whole block (measured: this exact case went red that way,
        # with a perfectly correct '[scan=read] ... 36% OCCLUDED' line as the error).
        # Same trap as the mutation probe; cmd /c merges before PowerShell sees it.
        $oTxT = (& cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File `"$script:ToolEntryPath`" read-text $tgtTitle --max-lines 1 2>&1") | Out-String
        $oTxJ = (& cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File `"$script:ToolEntryPath`" read-text $tgtTitle --json --max-lines 1 2>&1") | Out-String
        $oJOb = $null
        foreach ($jl in ($oTxJ -split "`r?`n")) {
          $sl = $jl.Trim()
          if ($sl.StartsWith('{')) { try { $oJOb = $sl | ConvertFrom-Json } catch { } }
        }
        $oJPid = ''
        $oJCovN = 0
        if ($oJOb) {
          $oJCovN = @($oJOb.coveredBy).Count
          if ($oJCovN -gt 0) { $oJPid = "$($oJOb.coveredBy[0].pid)" }
        }
        $oTSum = ''
        if ($oTxT -match 'scan=read rect=\([0-9-]+,[0-9-]+,[0-9]+x[0-9]+\) occluded=[0-9]+% coveredBy=pid=(\d+)') { $oTSum = $Matches[1] }
        $oTDetail = @(($oTxT -split "`r?`n") | Where-Object { $_ -match '^\s+covering: pid=' })
        ST-Check 'live: occlusion text summary names the same pid as --json coveredBy[0], and is labelled scan+rect' (
          $oTSum -ne '' -and $oTSum -ceq $oJPid)
        ST-Check 'live: the stderr covering list is as long as the json list (nothing dropped from the human view)' (
          $oJCovN -gt 0 -and @($oTDetail).Count -eq $oJCovN)
        Write-Output "      R-25 integration: text-summary-pid=$oTSum json-first-pid=$oJPid json-coverers=$oJCovN text-coverers=$(($oTDetail | Measure-Object).Count)"

        # item 8 (guard grading): strict refuses, --allow-occluded downgrades,
        # --occlude off bypasses - exactly the contract the task requires
        if ($ocrOk) {
          # Anchored on the REFUSAL wording, not on the bare word "occlusion": since v1.5.7 a
          # negative verdict carries its premises (owner supplement 3), so an informational
          # `occluded=36% coveredBy=...` / `occlusion check skipped` is now part of every miss
          # message. Demanding the word be absent tested the vocabulary, not the decision -
          # and --allow-occluded only ever passed by luck of "occluded" vs "occlusion".
          # `content guard FAILED (occlusion` is the occlusion refusal; `content guard
          # FAILED: '<needle>' not found` is the content refusal and ALWAYS ends with
          # "NOTHING was sent", so that phrase cannot tell the two apart either.
          $gMsg1 = ''
          try { Invoke-ContentGuard $tW 'ZZZNOZZZ' '' 'auto' 16 $false '' $false 5 } catch { $gMsg1 = $_.Exception.Message }
          $gMsg2 = ''
          try { Invoke-ContentGuard $tW 'ZZZNOZZZ' '' 'auto' 16 $false '' $true 5 } catch { $gMsg2 = $_.Exception.Message }
          $gMsg3 = ''
          try { Invoke-ContentGuard $tW 'ZZZNOZZZ' '' 'auto' 16 $false 'off' $false 5 } catch { $gMsg3 = $_.Exception.Message }
          # decisions go into variables FIRST: a `-match` with a parenthesis in the pattern
          # inside "$(...)" inside a double-quoted string does not parse in PS 5.1.
          $gRefused = ($gMsg1 -match 'content guard FAILED \(occlusion')
          $gSent = ($gMsg1 -match 'NOTHING was sent')
          $gAllowContent = ($gMsg2 -match 'not found')
          $gAllowNoRefuse = -not ($gMsg2 -match 'content guard FAILED \(occlusion')
          $gAllowNamesOcc = ($gMsg2 -match 'occluded=[0-9]+%')
          $gOffContent = ($gMsg3 -match 'not found')
          $gOffNoRefuse = -not ($gMsg3 -match 'content guard FAILED \(occlusion')
          $gOffSaysSkipped = ($gMsg3 -match 'occlusion check skipped')
          ST-Check 'live: guard refuses an occluded target (strict default)' ($gRefused -and $gSent)
          ST-Check 'live: guard --allow-occluded downgrades the DECISION and still reports the occlusion' (
            $gAllowContent -and $gAllowNoRefuse -and $gAllowNamesOcc)
          ST-Check 'live: guard --occlude off skips the check and says it was skipped (never silently absent)' (
            $gOffContent -and $gOffSaysSkipped -and $gOffNoRefuse)
          Write-Output ("      guard grading: strict-refused=" + $gRefused + "; allow-reached-content=" + ($gAllowContent -and $gAllowNoRefuse) +
            "; allow-still-names-occlusion=" + $gAllowNamesOcc + "; off-reached-content=" + ($gOffContent -and $gOffNoRefuse) +
            "; off-self-reported-skip=" + $gOffSaysSkipped)
        } else {
          ST-Skip 'live: guard occlusion grading' 'OCR engine unavailable'
        }

        # item 9 (sidecar staleness): capture the target, move it >= 50px,
        # then imgclick --dry must FAIL with old/new origins; --stale-ok passes.
        try { Stop-Process -Id $cProc.Id -Force -ErrorAction SilentlyContinue } catch { }
        Start-Sleep -Milliseconds 500
        $stPath = Join-Path $OutDir ('st-occ-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.png')
        [void]$occTmp.Add($stPath); [void]$occTmp.Add($stPath + '.map.txt')
        Invoke-DesktopCommand 'win' @($tgtTitle, $stPath, '--fit', '0') | Out-Null
        $sideOk = $false
        if (Test-Path -LiteralPath ($stPath + '.map.txt')) {
          $sideTxt = [System.IO.File]::ReadAllText($stPath + '.map.txt')
          $sideOk = ($sideTxt -match '(?m)^kind=win') -and ($sideTxt -match '(?m)^pid=\d+') -and ($sideTxt -match '(?m)^handle=\d+')
        }
        ST-Check 'live: win sidecar records the pid/handle anchor' $sideOk
        $tW2 = Resolve-Window $tgtTitle
        $nx = [int]$tW2.Left + 60
        Invoke-DesktopCommand 'win-move' @($tgtTitle, [string]$nx, [string]$tW2.Top) | Out-Null
        Start-Sleep -Milliseconds 500
        $o9 = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath imgclick $stPath 10 10 --dry 2>&1 | Out-String
        $c9 = $LASTEXITCODE
        ST-Check 'live: stale sidecar (win-move >=50px) - imgclick --dry FAILS with old/new origins' (
          $c9 -eq 1 -and $o9 -match 'STALE' -and $o9 -match "origin was \($($tW2.Left),$($tW2.Top)\) now \($nx,$($tW2.Top)\)")
        Write-Output "      sidecar stale run: exit=$c9 msg=$(($o9.Trim() -split "`r?`n")[0])"
        $o9b = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath imgclick $stPath 10 10 --dry --stale-ok 2>&1 | Out-String
        $c9b = $LASTEXITCODE
        ST-Check 'live: imgclick --stale-ok passes with a note' ($c9b -eq 0 -and $o9b -match '\[stale-ok\]')
        $o9c = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ToolEntryPath unmap $stPath 10 10 2>&1 | Out-String
        $c9c = $LASTEXITCODE
        ST-Check 'live: unmap applies the same staleness contract' ($c9c -eq 1 -and $o9c -match 'STALE')

        # item 10 (cost): warm run then measured run on the largest window
        $bigW = @($winsO | Sort-Object -Property Area -Descending | Select-Object -First 1)
        if (@($bigW).Count -ge 1) {
          $null = Get-OcclusionVerdict $bigW[0].Left $bigW[0].Top $bigW[0].W $bigW[0].H $bigW[0].Handle 5
          $occMs = Get-OcclusionVerdict $bigW[0].Left $bigW[0].Top $bigW[0].W $bigW[0].H $bigW[0].Handle 5
          ST-Check 'live: occlusion cost - 5x5 scan under 80ms' ($occMs.Ms -lt 80)
          Write-Output "      occlusion cost: $($bigW[0].W)x$($bigW[0].H) 5x5 took $($occMs.Ms) ms (warm; checked=$($occMs.Checked))"
        }
      } catch {
        ST-Check 'live: occlusion selftest setup+run' $false
        Write-Output "      occlusion selftest error: $($_.Exception.Message)"
      } finally {
        foreach ($pr in @($occTProcs)) { try { if ($pr -and -not $pr.HasExited) { Stop-Process -Id $pr.Id -Force -ErrorAction SilentlyContinue } } catch { } }
        foreach ($fp in @($occTmp)) { try { if (Test-Path -LiteralPath $fp) { Remove-Item -LiteralPath $fp -Force -ErrorAction SilentlyContinue } } catch { } }
      }

      # BOM introduction anchor (v1.5.0 fix round): FIXED history objects
      # only - no worktree comparison and no dynamic HEAD, so this can never
      # go red because of pending edits (the old worktree-vs-HEAD form did).
      # The one-time "+3 bytes only" check compared the pre-BOM file with its
      # BOM'd self at add time; that transient pair was never persisted (the
      # recovery attempt is documented in the v1.5.0 iteration log), so the
      # durable form anchors the two immutable blobs of the introduction:
      #   [1] the parent blob (592ed7d) must be BOM-less, sha256 pinned;
      #   [2] the introducing commit's blob (a039318) must be exactly
      #       EF BB BF + the frozen payload (payload starts with '#'),
      #       payload sha256 pinned. A silent rewrite of the history bytes
      #       trips at least one pin. (Neither side reads the worktree.)
      # v3.0.1 (audit #20): this anchor shells out to `git cat-file`. On a machine without
      # git in PATH the case could not run at all, and it reported FAIL - a red that looks
      # like "the history bytes changed" (the one thing this check exists to detect) when
      # the truth is "no git binary here". Absent tooling is a SKIP, the same shape the
      # OCR and Chrome cases above already use; a git that IS present and disagrees with a
      # pin still fails, which is the case the pins are for.
      $gitAnchorReady = $false
      try { $gitAnchorReady = ($null -ne (Get-Command git -ErrorAction SilentlyContinue)) } catch { $gitAnchorReady = $false }
      if (-not $gitAnchorReady) {
        ST-Skip 'live: BOM introduction anchor (fixed blobs): parent BOM-less + child = BOM + frozen payload, sha256 pinned' 'no git binary in PATH - the anchor reads history objects, there is nothing to measure'
      } else {
      # v3.1.0 (F-03, found by THIS round's own --live on the published tree, not by a review report):
      # both pinned objects are PRIVATE-history anchors. A published clone is re-rooted at its own
      # "Initial public release" commit, so `git cat-file` cannot resolve them and the case reported
      # FAIL while comparing nothing at all. Absent tooling is already a SKIP (v3.0.1, audit #20);
      # this narrows the other absent-input shape the same way - but ONLY for a tree that is
      # demonstrably the published one (no internal overview beside desktop.ps1, the same signal F-01
      # uses). In the private tree a vanished anchor is exactly the rewrite these pins exist to catch,
      # so there it falls through to the assertions and still goes red. The skip also says out loud
      # that no bytes were compared, so nobody can read it as a pass.
      $anchRootDir = Split-Path -Parent $OutDir
      $anchPublished = -not (Test-Path -LiteralPath (Join-Path $anchRootDir ("$([char]0x9879)$([char]0x76EE)$([char]0x603B)$([char]0x89C8).md")))
      $anchMissing = @()
      foreach ($anchOid in @('592ed7d', 'a039318')) {
        $anchProbe = Join-Path $env:TEMP ('dtx-anchor-probe-' + [guid]::NewGuid().ToString('N') + '.txt')
        try {
          $apf = Start-Process -FilePath 'git' -ArgumentList 'cat-file', '-e', ($anchOid + ':desktop.ps1') -WorkingDirectory $anchRootDir -RedirectStandardOutput $anchProbe -RedirectStandardError ($anchProbe + '.err') -Wait -PassThru -NoNewWindow
          if ($apf.ExitCode -ne 0) { $anchMissing += $anchOid }
        } finally {
          Remove-Item -LiteralPath $anchProbe, ($anchProbe + '.err') -Force -ErrorAction SilentlyContinue
        }
      }
      $anchRootOid = 'unknown'
      if ($anchMissing.Count -gt 0) {
        $anchRt = Join-Path $env:TEMP ('dtx-anchor-root-' + [guid]::NewGuid().ToString('N') + '.txt')
        try {
          $arp = Start-Process -FilePath 'git' -ArgumentList 'rev-list', '--max-parents=0', 'HEAD' -WorkingDirectory $anchRootDir -RedirectStandardOutput $anchRt -Wait -PassThru -NoNewWindow
          if ($arp.ExitCode -eq 0) {
            $anchFirst = [string](Get-Content -LiteralPath $anchRt -TotalCount 1 -ErrorAction SilentlyContinue)
            if ($anchFirst) { $anchRootOid = $anchFirst.Substring(0, [Math]::Min(12, $anchFirst.Length)) }
          }
        } finally {
          Remove-Item -LiteralPath $anchRt -Force -ErrorAction SilentlyContinue
        }
      }
      if ($anchPublished -and $anchMissing.Count -gt 0) {
        ST-Skip 'live: BOM introduction anchor (fixed blobs): parent BOM-less + child = BOM + frozen payload, sha256 pinned' ('pinned objects ' + ($anchMissing -join ',') + ' are private-history anchors and this is the published tree (no internal overview beside desktop.ps1; this history roots at ' + $anchRootOid + ') - NO bytes were compared, read this as a known gap of a re-rooted clone, never as a pass')
      } else {
      $bomOk = $false
      $bomInfo = 'not run'
      $tmpP = Join-Path $env:TEMP ('dtx-anchor-parent-' + [guid]::NewGuid().ToString('N') + '.bin')
      $tmpC = Join-Path $env:TEMP ('dtx-anchor-child-' + [guid]::NewGuid().ToString('N') + '.bin')
      try {
        $gp = Start-Process -FilePath 'git' -ArgumentList 'cat-file', 'blob', '592ed7d:desktop.ps1' -WorkingDirectory (Split-Path -Parent $OutDir) -RedirectStandardOutput $tmpP -Wait -PassThru -NoNewWindow
        if ($gp.ExitCode -ne 0) { throw "git cat-file (parent) exit=$($gp.ExitCode)" }
        $gc = Start-Process -FilePath 'git' -ArgumentList 'cat-file', 'blob', 'a039318:desktop.ps1' -WorkingDirectory (Split-Path -Parent $OutDir) -RedirectStandardOutput $tmpC -Wait -PassThru -NoNewWindow
        if ($gc.ExitCode -ne 0) { throw "git cat-file (child) exit=$($gc.ExitCode)" }
        $pB = [System.IO.File]::ReadAllBytes($tmpP)
        $cB = [System.IO.File]::ReadAllBytes($tmpC)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $pNoBom = -not ($pB.Length -ge 3 -and $pB[0] -eq 0xEF -and $pB[1] -eq 0xBB -and $pB[2] -eq 0xBF)
        $hP = [BitConverter]::ToString($sha.ComputeHash($pB))
        $cBom = ($cB.Length -ge 4 -and $cB[0] -eq 0xEF -and $cB[1] -eq 0xBB -and $cB[2] -eq 0xBF)
        $payload = $cB[3..($cB.Length - 1)]
        $hCP = [BitConverter]::ToString($sha.ComputeHash($payload))
        $leadOk = ($cB.Length -ge 4 -and $cB[3] -eq 0x23)
        $expP = 'F5-35-9F-B6-F8-18-CD-60-E9-D0-17-59-FA-34-AB-50-B8-59-3B-41-01-53-F8-39-9C-1F-99-50-25-2F-E3-C4'
        $expC = '6E-40-16-EA-B5-28-D2-47-89-0A-6A-66-7E-6A-2F-71-C7-14-BB-4F-51-01-CC-BF-80-AC-99-F2-ED-CD-39-2F'
        $bomOk = ($pNoBom -and $cBom -and $leadOk -and ($hP -eq $expP) -and ($hCP -eq $expC))
        $bomInfo = "parent.noBOM=$pNoBom child.bom=$cBom payload.leadOk=$leadOk"
        if ($bomOk) {
          Write-Output "      bom-anchor ok: parent(592ed7d)=$($pB.Length)B BOM-less (sha256 pinned), child(a039318)=$($cB.Length)B = 3B BOM + $($payload.Length)B payload (sha256 pinned)"
        } else {
          Write-Output "      bom-anchor MISMATCH: $bomInfo / parent.sha256=$hP (exp $expP) / payload.sha256=$hCP (exp $expC)"
        }
      } catch {
        $bomInfo = "error: $($_.Exception.Message)"
        Write-Output "      bom-anchor error: $bomInfo"
      } finally {
        Remove-Item -LiteralPath $tmpP -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tmpC -Force -ErrorAction SilentlyContinue
      }
      ST-Check 'live: BOM introduction anchor (fixed blobs): parent BOM-less + child = BOM + frozen payload, sha256 pinned' $bomOk
      }
      }
    }
    # ---------- live: v1.8.0 a11y route, measured on whatever is really on screen ----------
    # These stay permanent because they need no orchestration: they read the Chrome
    # window a normal desktop already has. The Chrome RESTART A/B (cold tree vs warm
    # tree, with flag vs without) is deliberately NOT a selftest case - it would bounce
    # the owner's browser on every live round; those numbers are recorded once in the
    # iteration log instead.
    $awL = $null
    try { $awL = Resolve-Window 'Chrome' } catch { }
    if (-not $awL) {
      ST-Skip 'live: a11y depth knob and page-content reachability' 'no Chrome window on this desktop right now - nothing to measure'
    } else {
      $aShallow = Measure-A11yTree $awL 3
      $aDeep = Measure-A11yTree $awL 40
      ST-Check 'live: a11y-probe depth is a real limit (the same window at depth 3 and depth 40 counts different nodes)' (
        ($aDeep.Verdict -ne 'no-root') -and ($aDeep.Nodes -gt $aShallow.Nodes))
      Write-Output "      a11y depth: nodes@3=$($aShallow.Nodes) nodes@40=$($aDeep.Nodes) page-area@40=$($aDeep.PageHits) verdict=$($aDeep.Verdict)"
      if ($aDeep.Verdict -eq 'exposed') {
        # The real page's own Names are NOT usable as live-case needles: a console page
        # re-renders between the measurement and the search (a Button whose Name is a
        # status line with a clock changes every second), which reads as hits=0 and looks
        # exactly like a broken matcher. So this case drives a synthetic window whose
        # Names are fixed AND contain the characters that used to break matching -
        # '/', '[', ']', '*' - which is the defect actually being pinned. Real-page
        # reachability is evidenced once in the iteration log instead (uia-find on the
        # owner's console found the '/codex' button and the send button by their own
        # Names, with the send button's Name being non-ASCII).
        $uFixRand = ''
        try { $uFixRand = ([guid]::NewGuid().ToString('N')).Substring(0, 12) } catch { $uFixRand = '0' }
        $uFixScript = Join-Path $env:TEMP ('dtx-uia-name-' + $uFixRand + '.ps1')
        $uFixSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-UiaNameProbe'
$f.ClientSize = New-Object System.Drawing.Size(520, 320)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(180, 300)
$f.TopMost = $true
$b1 = New-Object System.Windows.Forms.Button
$b1.Text = '/help'
$b1.SetBounds(20, 20, 150, 60)
[void]$f.Controls.Add($b1)
$b2 = New-Object System.Windows.Forms.Button
$b2.Text = '[opt]*x?'
$b2.SetBounds(20, 100, 150, 60)
[void]$f.Controls.Add($b2)
[System.Windows.Forms.Application]::Run($f)
'@
        [System.IO.File]::WriteAllText($uFixScript, $uFixSrc, (New-Object System.Text.UTF8Encoding($false)))
        $uFixProc = $null
        try {
          $uFixProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $uFixScript -PassThru
          $uFixW = $null
          $uSw = [System.Diagnostics.Stopwatch]::StartNew()
          while ($uSw.ElapsedMilliseconds -lt 15000) {
            $uFixW = Resolve-Window 'DTX-UiaNameProbe'
            if ($uFixW) { break }
            Start-Sleep -Milliseconds 400
          }
          if ($null -eq $uFixW) { throw 'the DTX-UiaNameProbe fixture window never appeared' }
          $uOut1 = (@(Invoke-DesktopCommand 'uia-find' @('DTX-UiaNameProbe', '/help')) -join "`n")
          $uHits1 = -1
          if ($uOut1 -match 'hits=(\d+)') { $uHits1 = [int]$Matches[1] }
          # the wildcard-bearing Name: with -like this was 0 hits (pattern '[opt]' matches
          # one char, '*x?' exploded), with literal matching it must be exactly 1
          $uOut2 = (@(Invoke-DesktopCommand 'uia-find' @('DTX-UiaNameProbe', '[opt]*x?')) -join "`n")
          $uHits2 = -1
          if ($uOut2 -match 'hits=(\d+)') { $uHits2 = [int]$Matches[1] }
          $uOut3 = (@(Invoke-DesktopCommand 'uia-find' @('DTX-UiaNameProbe', 'DTXABSENTNEEDLEQZ7X')) -join "`n")
          $uHits3 = -1
          if ($uOut3 -match 'hits=(\d+)') { $uHits3 = [int]$Matches[1] }
          ST-Check 'live: uia-find matches Names LITERALLY - a slash-named and a bracket/star/question-named button are both found by their own Name, an absent one is 0' (
            ($uHits1 -eq 1) -and ($uHits2 -eq 1) -and ($uHits3 -eq 0))
          # v2.1.0 (plan doc 1.2) live plumbing. The cold-start RE-CONTACT itself is proven
          # offline by injecting a walker whose first contact returns nothing - a real cold
          # start cannot be staged on demand (owner ruling closing v1.8.0 limitation 15).
          # What this round CAN prove live is that the field is really measured and spoken
          # on a real tree, that a first-contact hit does not burn a second walk, and that a
          # zero which survives the rule hands the caller the OCR road instead of a bare
          # "hits=0" (which is the entry to screenshot eyeballing - the exact failure the
          # plan doc was written from).
          $u12Absent = ($uOut3 -like '*cold-zero-reprobe=*') -and ($uOut3 -like '*walks=*') -and ($uOut3 -like '*reprobe-floor=*') -and ($uOut3 -like '*Next road: find-text*')
          ST-Check 'live: uia-find reports the cold-start fields it measured and, when even the rule is done and it still has nothing, points at the OCR road' ($u12Absent)
          $u12HitOnce = ($uOut1 -like '*walks=1 *') -and ($uOut1 -like '*cold-zero-reprobe=no*')
          ST-Check 'live: uia-find that hits on first contact spends no second walk (walks=1, cold-zero-reprobe=no)' ($u12HitOnce)
          Write-Output ("      uia reprobe live: absent-echo=" + (($uOut3 -split "`r?`n" | Where-Object { $_ -like 'scanned*' }) -join '') + " | hit-echo=" + (($uOut1 -split "`r?`n" | Where-Object { $_ -like 'scanned*' }) -join ''))
          Write-Output "      literal name match: /help hits=$uHits1  [opt]*x? hits=$uHits2  absent hits=$uHits3"
        } catch {
          ST-Check 'live: uia-find literal Name fixture case setup+run' $false
          Write-Output "      literal name fixture error: $($_.Exception.Message)"
        } finally {
          if ($uFixProc -and -not $uFixProc.HasExited) { try { Stop-Process -Id $uFixProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
          if (Test-Path -LiteralPath $uFixScript) { Remove-Item -LiteralPath $uFixScript -Force -ErrorAction SilentlyContinue }
        }
        Write-Output "      real-page reachability (recorded once, not a permanent case): sampled Button Names now = [$($aDeep.Sample)]"
      } else {
        ST-Skip 'live: uia-find reaches page content by Name' "page area measured 0 interactive controls at depth 40 (nodes=$($aDeep.Nodes)). Not a verdict about the tool and not a permanent verdict about the app: a page whose lower half holds no interactive elements measures 0 with the tree wide open, and this round a --force-renderer-accessibility fixture also measured 0. Check the fixture before believing 'collapsed'."
      }
    }

    # ---------- live: v2.2.0 plan doc 3 - the folded long payload receipt ----------
    # The shipped false negative: an input that folds a long text into an attachment chip never
    # renders the tail the v1.5.9 readback asks for, so a send that WORKED reads as a failure.
    # Three tool-made fixtures, each killed in its own finally:
    #   DTX-FoldProbe - a real text box that, on receiving text, CLEARS itself, shows a chip
    #                   label and grows its height. The tail is unreadable by construction, so
    #                   the only way this case can pass is the receipt route - and the height
    #                   growth is checked against `wins`, outside the tool's own claim.
    #   DTX-NoFold    - no text box, one static painted label: the send goes nowhere and nothing
    #                   changes. This is the control that stops 'accept on any change'.
    #   DTX-ShowProbe - the text stays visible: the verbatim criterion must still win outright,
    #                   proving the threshold does not bypass the primary read.
    $frProc = $null; $nfProc = $null; $shProc = $null
    $rcpTmp = New-Object System.Collections.ArrayList
    # INC-02: same pair as the step-probe block - declared ahead of the try so the catch can tell a
    # refused write from a real failure, and the gate names the four legs this block owns.
    $rcpGate = ''
    $rcpGuard = $null
    try {
      # Clipboard hygiene (2026-10-29, live-r4): every paste here snapshots and restores the
      # clipboard, and a PNG/Bitmap left anywhere upstream (a capture or copy-file --image
      # check restored its own snapshot back) makes the CU-OPS write guard refuse the paste
      # BEFORE the receipt chain even runs - the refusal text carries no none-of-three, so
      # the control case reads as a wording failure when it is really leftover state. Fold
      # ran first and passed only because it met a still-clean clipboard; every scenario
      # after it inherits whatever the previous restore left. Normalizing to a plain text
      # format here makes all four scenarios start from a state this tool can snapshot,
      # restore, and - when the control case needs it - refuse for the RIGHT reason.
      # INC-02: that normalization is a write to the SHARED clipboard. It now runs only over a
      # snapshot the tool can put back; refused => the four names this block owns skip with the
      # verdict as the reason. The alternative - writing anyway because the fixtures are this
      # round's own windows - is the loss this item was raised for: clip.exe replaces the machine
      # owner's content, not a fixture's.
      $rcpGuard = Start-LiveClipboardGuard 'paste-receipt normalization write' $null
      if (-not $rcpGuard.Started) { $rcpGate = 'clipboard guard refused the normalization write: ' + $rcpGuard.Verdict; throw $rcpGate }
      'DTX-CLIP-NORMALIZED' | & "$env:SystemRoot\System32\clip.exe"
      $rcpGuard.Written = $true
      $frScript = Join-Path $env:TEMP ('dtx-fold-probe-' + (Get-Random) + '.ps1')
      $nfScript = Join-Path $env:TEMP ('dtx-nofold-probe-' + (Get-Random) + '.ps1')
      $shScript = Join-Path $env:TEMP ('dtx-show-probe-' + (Get-Random) + '.ps1')
      $frPayload = Join-Path $env:TEMP ('dtx-fold-payload-' + (Get-Random) + '.txt')
      [void]$rcpTmp.Add($frScript); [void]$rcpTmp.Add($nfScript); [void]$rcpTmp.Add($shScript); [void]$rcpTmp.Add($frPayload)
      $frSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HXFR { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[void][HXFR]::SetProcessDPIAware()
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-FoldProbe'
$f.ClientSize = New-Object System.Drawing.Size(520, 240)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(1400, 1480)
$f.TopMost = $true
$chip = New-Object System.Windows.Forms.Label
$chip.Text = 'EMPTY'
$chip.Font = New-Object System.Drawing.Font('Segoe UI', 14)
$chip.SetBounds(20, 16, 480, 34)
[void]$f.Controls.Add($chip)
$tb = New-Object System.Windows.Forms.TextBox
$tb.Multiline = $true
$tb.Font = New-Object System.Drawing.Font('Segoe UI', 14)
$tb.SetBounds(20, 60, 480, 120)
[void]$f.Controls.Add($tb)
$tb.Add_TextChanged({
  if ($tb.Text.Length -gt 0) {
    $n = $tb.Text.Length
    $tb.Clear()
    $chip.Text = 'CHIP-' + $n
    $f.Height = $f.Height + 48
  }
})
$f.Add_Activated({ [void]$tb.Focus() })
$f.Add_Shown({ [void]$tb.Focus() })
[System.Windows.Forms.Application]::Run($f)
'@
      $nfSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HXNF { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[void][HXNF]::SetProcessDPIAware()
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-NoFold'
$f.ClientSize = New-Object System.Drawing.Size(520, 240)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(1960, 1480)
$f.TopMost = $true
$lb = New-Object System.Windows.Forms.Label
$lb.Text = 'NOFOLD-STATIC'
$lb.Font = New-Object System.Drawing.Font('Segoe UI', 14)
$lb.SetBounds(20, 60, 480, 40)
[void]$f.Controls.Add($lb)
[System.Windows.Forms.Application]::Run($f)
'@
      $shSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HXSH { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[void][HXSH]::SetProcessDPIAware()
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-ShowProbe'
$f.ClientSize = New-Object System.Drawing.Size(520, 420)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(2520, 1400)
$f.TopMost = $true
$tb = New-Object System.Windows.Forms.TextBox
$tb.Multiline = $true
$tb.Font = New-Object System.Drawing.Font('Segoe UI', 14)
$tb.SetBounds(20, 40, 480, 340)
$tb.Add_TextChanged({ [void]$tb.ScrollToCaret() })
[void]$f.Controls.Add($tb)
$f.Add_Activated({ [void]$tb.Focus() })
$f.Add_Shown({ [void]$tb.Focus() })
[System.Windows.Forms.Application]::Run($f)
'@
      [System.IO.File]::WriteAllText($frScript, $frSrc, (New-Object System.Text.UTF8Encoding($false)))
      [System.IO.File]::WriteAllText($nfScript, $nfSrc, (New-Object System.Text.UTF8Encoding($false)))
      [System.IO.File]::WriteAllText($shScript, $shSrc, (New-Object System.Text.UTF8Encoding($false)))
      # >= fold-threshold chars, one distinctive final line the fold fixture will eat.
      # v4.1.2 (owner ruling 2026-10-07: fix the fixture, touch no threshold). Two independent
      # flakiness sources were measured in the old construction 'DTXFOLDTAIL' + (Get-Random):
      #  (1) ALPHABET. The tail row is always painted and always OCR'd - the CHARACTER match is
      #      what fails. Measured mis-reads on this machine: 'DTXFOLDTAIL1752305831' came back as
      #      'DTXFOLDTAILI 752305831' (digit 1 read as the letter I, plus an inserted space) and
      #      'DTXFOLDTAIL1416373754' as 'DTXFOLDTAlL1416373754'. That is the 0/O/1/I/l confuseable
      #      set. Same-session A/B in this very three-fixture context: old tail 4/6 verbatim
      #      (2 accepted on a receipt), new tail 6/6, and 12/12 across three payload shapes.
      #  (2) LENGTH. Get-Random returns 1-10 digits, so the tail was 12-21 chars and the payload
      #      196-205 bytes - it could fall BELOW the 200-char fold threshold, which would make the
      #      FOLD leg demand a verbatim read it can never get. The tail is now fixed at 20 chars,
      #      so the payload is always 204: above the threshold by a stated margin, and still inside
      #      the 24-char autoexpect cap.
      # The value stays unique per run, so a stale anchor still cannot satisfy the check.
      $frTailAlpha = '23456789'
      $frTailDigits = ''
      for ($frI = 0; $frI -lt 12; $frI++) { $frTailDigits += $frTailAlpha[(Get-Random -Maximum $frTailAlpha.Length)] }
      $frTail = 'DTXCHECK' + $frTailDigits
      $frBody = ('A' * 90) + "`r`n" + ('B' * 90) + "`r`n" + $frTail
      # Two guards, so neither cause can come back silently. They throw INSIDE the block's own
      # try, which the existing setup check turns into a FAIL - not into a passing run that quietly
      # measures something else.
      if ($frTail -match '[01OIl]') { throw "fold fixture tail left the confuseable-free alphabet: $frTail" }
      if ($frTail.Length -ne 20) { throw "fold fixture tail must be exactly 20 chars (autoexpect cap is 24, payload floor is the fold threshold): got $frTail.Length" }
      if ($frBody.Length -lt (Get-PasteFoldThreshold)) { throw "fold fixture payload ($($frBody.Length) chars) is below fold-threshold ($(Get-PasteFoldThreshold)) - the fold leg could not fold: $frTail" }
      [System.IO.File]::WriteAllText($frPayload, $frBody, (New-Object System.Text.UTF8Encoding($false)))
      $frProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $frScript -PassThru
      $nfProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $nfScript -PassThru
      $shProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $shScript -PassThru
      $frWin = $null; $nfWin = $null; $shWin = $null
      $frWait = [System.Diagnostics.Stopwatch]::StartNew()
      while ($frWait.Elapsed.TotalSeconds -lt 15) {
        $frWin = Resolve-Window 'DTX-FoldProbe'; $nfWin = Resolve-Window 'DTX-NoFold'; $shWin = Resolve-Window 'DTX-ShowProbe'
        if ($frWin -and $nfWin -and $shWin) { break }
        Start-Sleep -Milliseconds 400
      }
      if (-not ($frWin -and $nfWin -and $shWin)) { throw 'the three receipt fixtures did not all appear within 15s' }
      Start-Sleep -Milliseconds 900
      $frH0 = [int](Resolve-Window 'DTX-FoldProbe').H
      $nfH0 = [int](Resolve-Window 'DTX-NoFold').H
      # Split-stream capture for all three (2026-10-29, live-r5): any stderr line the child
      # emits turns a bare 2>&1 into a terminating NativeCommandError under EAP=Stop and the
      # refusal text on stdout is swallowed with it (measured: all three verdicts read
      # no-readback-line while exit and heights were readable). Files keep the verdict text
      # parseable and the warnings on record; ReadAllText keeps an empty stream ''.
      $frErrF = Join-Path $OutDir ('st-paste-fold-' + [guid]::NewGuid().ToString('N') + '.stderr.txt')
      $frOutF = $frErrF -replace '\.stderr\.txt$', '.stdout.txt'
      [void]$rcpTmp.Add($frErrF); [void]$rcpTmp.Add($frOutF)
      $frArgStr = '-NoProfile -ExecutionPolicy Bypass -File "' + $script:ToolEntryPath + '" paste "' + $frPayload + '" --to DTX-FoldProbe'
      $frCp = Start-Process -FilePath 'powershell.exe' -ArgumentList $frArgStr -RedirectStandardOutput $frOutF -RedirectStandardError $frErrF -Wait -PassThru -NoNewWindow
      $frCode = $frCp.ExitCode
      $frOut = ''
      if (Test-Path -LiteralPath $frOutF) { $frOut = [IO.File]::ReadAllText($frOutF) }
      $frH1 = [int](Resolve-Window 'DTX-FoldProbe').H
      $nfErrF = Join-Path $OutDir ('st-paste-nofold-' + [guid]::NewGuid().ToString('N') + '.stderr.txt')
      $nfOutF = $nfErrF -replace '\.stderr\.txt$', '.stdout.txt'
      [void]$rcpTmp.Add($nfErrF); [void]$rcpTmp.Add($nfOutF)
      $nfArgStr = '-NoProfile -ExecutionPolicy Bypass -File "' + $script:ToolEntryPath + '" paste "' + $frPayload + '" --to DTX-NoFold'
      $nfCp = Start-Process -FilePath 'powershell.exe' -ArgumentList $nfArgStr -RedirectStandardOutput $nfOutF -RedirectStandardError $nfErrF -Wait -PassThru -NoNewWindow
      $nfCode = $nfCp.ExitCode
      $nfOut = ''
      if (Test-Path -LiteralPath $nfOutF) { $nfOut = [IO.File]::ReadAllText($nfOutF) }
      $nfH1 = [int](Resolve-Window 'DTX-NoFold').H
      $shErrF = Join-Path $OutDir ('st-paste-show-' + [guid]::NewGuid().ToString('N') + '.stderr.txt')
      $shOutF = $shErrF -replace '\.stderr\.txt$', '.stdout.txt'
      [void]$rcpTmp.Add($shErrF); [void]$rcpTmp.Add($shOutF)
      $shArgStr = '-NoProfile -ExecutionPolicy Bypass -File "' + $script:ToolEntryPath + '" paste "' + $frPayload + '" --to DTX-ShowProbe'
      $shCp = Start-Process -FilePath 'powershell.exe' -ArgumentList $shArgStr -RedirectStandardOutput $shOutF -RedirectStandardError $shErrF -Wait -PassThru -NoNewWindow
      $shCode = $shCp.ExitCode
      $shOut = ''
      if (Test-Path -LiteralPath $shOutF) { $shOut = [IO.File]::ReadAllText($shOutF) }
      # 1) the folded send: accepted ONLY through the receipt, and the height really grew
      ST-Check 'live: paste of a folded long payload is accepted on a named receipt while the window genuinely grew (the v1.5.9 verbatim ask was a guaranteed false negative here)' (
        ($frCode -eq 0) -and ($frOut -match 'accepted on receipt=') -and ($frOut -match 'fold-threshold=') -and
        (($frH1 - $frH0) -ge 8) -and ($frOut -notmatch 'readback=verbatim-tail'))
      # 2) the control: a send that reached nothing is still refused, and says all three legs
      ST-Check 'live: paste into a target that received nothing is STILL refused with receipt-tried=none-of-three and the measured numbers (a receipt that fires on any paste is worse than the false negative it fixes)' (
        ($nfCode -eq 1) -and ($nfOut -match 'none-of-three') -and (($nfH1 - $nfH0) -lt 8))
      # 3) the primary road is not bypassed: visible text is still read back verbatim
      ST-Check 'live: a long payload the target DOES render is still accepted on readback=verbatim-tail and never on a receipt (threshold must not downgrade the primary read)' (
        ($shCode -eq 0) -and ($shOut -match 'read back from target - readback=verbatim-tail') -and ($shOut -notmatch 'accepted on receipt='))
      Write-Output ("      paste receipt live: fold=exit$frCode h$frH0->$frH1 nofold=exit$nfCode h$nfH0->$nfH1 show=exit$shCode threshold=" + (Get-PasteFoldThreshold))
      # Each of the three verdicts is echoed, not just the fold one: live-v220-3 lost the SHOW
      # case with exit 0 and the round could not say whether the body was read verbatim or
      # accepted on a weak receipt under the owner's occluding window. A red that cannot
      # classify itself is the shape this repo keeps paying for.
      foreach ($shPair in @(@('fold', $frOut, $frErrF), @('nofold', $nfOut, $nfErrF), @('show', $shOut, $shErrF))) {
        $shLine = (($shPair[1].Trim() -split "`r?`n" | Where-Object { $_ -match 'readback=|accepted on receipt|none-of-three' }) -join ' ;; ')
        Write-Output ('      verdict[' + $shPair[0] + ']: ' + $(if ($shLine) { $shLine } else { 'no-readback-line' }))
        if (-not $shLine) {
          Write-Output ('      ' + $shPair[0] + ' stdout tail: ' + (($shPair[1].Trim() -split "`r?`n" | Select-Object -Last 3) -join ' | '))
          $shErrHead = ''
          try { $shErrHead = (@([IO.File]::ReadAllLines($shPair[2])) | Select-Object -First 1) -join '' } catch { $shErrHead = '(no stderr file)' }
          Write-Output ('      ' + $shPair[0] + ' stderr head: ' + $shErrHead)
        }
      }
      Write-Output ("      fold echo tail: " + (($frOut.Trim() -split "`r?`n" | Where-Object { $_ -match 'receipt|verified|pasted' }) -join ' | '))
    } catch {
      # INC-02: a refused normalization is an environment state, not a build result - the four names
      # this block owns skip under the verdict, each carrying it, so a machine whose clipboard could
      # not be preserved is never read as "the receipt chain is broken" and never as a pass.
      if ($rcpGate) {
        Write-Output ('      paste receipt block NOT VERIFIED (clipboard guard refused the write, never a pass): ' + $rcpGate)
        ST-Skip 'live: paste receipt fixture block setup+run' ('environment blocked - ' + $rcpGate)
        ST-Skip 'live: paste of a folded long payload is accepted on a named receipt while the window genuinely grew (the v1.5.9 verbatim ask was a guaranteed false negative here)' ('environment blocked - ' + $rcpGate)
        ST-Skip 'live: paste into a target that received nothing is STILL refused with receipt-tried=none-of-three and the measured numbers (a receipt that fires on any paste is worse than the false negative it fixes)' ('environment blocked - ' + $rcpGate)
        ST-Skip 'live: a long payload the target DOES render is still accepted on readback=verbatim-tail and never on a receipt (threshold must not downgrade the primary read)' ('environment blocked - ' + $rcpGate)
      } else {
        ST-Check 'live: paste receipt fixture block setup+run' $false
        Write-Output "      paste receipt error: $($_.Exception.Message)"
      }
    } finally {
      # INC-02: restore first, on every path that reaches the finally, and assert the outcome rather
      # than assume it - partial/failed is red. An outside kill runs no finally: disclosed, not covered.
      $rcpGuardNote = Stop-LiveClipboardGuard $rcpGuard
      $rcpGuardOutcome = Get-ClipboardRestoreOutcome $rcpGuardNote
      ST-Check 'live: the paste-receipt clipboard guard restores the pre-write clipboard on every exit path (partial or failed restore is red, a refused write had nothing to write)' (
        (@('ok', 'skipped') -ccontains $rcpGuardOutcome))
      Write-Output ('      paste receipt clipboard guard: verdict=[' + $(if ($rcpGuard) { [string]$rcpGuard.Verdict } else { '(no guard object)' }) + '] written=' +
        $(if ($rcpGuard) { [string]$rcpGuard.Written } else { '-' }) + '] outcome=' + $rcpGuardOutcome + ' restore=[' + $rcpGuardNote + ']')
      if ($frProc -and -not $frProc.HasExited) { try { Stop-Process -Id $frProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
      if ($nfProc -and -not $nfProc.HasExited) { try { Stop-Process -Id $nfProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
      if ($shProc -and -not $shProc.HasExited) { try { Stop-Process -Id $shProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
      foreach ($fl in @('DTX-FoldProbe', 'DTX-NoFold', 'DTX-ShowProbe')) {
        $lf = Resolve-Window $fl
        if ($lf) { try { Stop-Process -Id $lf.Pid -Force -ErrorAction SilentlyContinue } catch { } }
      }
      foreach ($ft in $rcpTmp) { if (Test-Path -LiteralPath $ft) { Remove-Item -LiteralPath $ft -Force -ErrorAction SilentlyContinue } }
    }

    # ---------- live: v2.3.0 red-1/red-2 - the occlusion front gate over the weak receipt chain ----------
    # Real-machine shape (2026-10-02, archived in .cowork-temp/zq-t1-RED-*.md): a paste into a
    # target that receives NOTHING was accepted on receipt=lines-changed twice, because the
    # legs sampled the target's SCREEN rect and the coverer supplied the motion (a playing
    # video; then the paste's own foreground switch). Fixtures:
    #   DTX-GateNoFold - clone of DTX-NoFold (static label, receives nothing) but NOT topmost:
    #                    even after the paste's own activation raises it, the topmost occluder
    #                    stays above it (Win32 z-band rule - Activate-Win uses BringWindowToTop,
    #                    no topmost toggle) - the same way the desktop could never rise above
    #                    its coverers in the real red.
    #   DTX-GateAnim   - topmost occluder parked exactly over the receiver. Its WinForms timer
    #                    APPENDS a long token line (LINE-000N-OCCL-MOTION) every 500ms and NEVER
    #                    resets during the test: the OCR line count over the covered rect
    #                    therefore differs deterministically between the receipt's two
    #                    measurements, which is exactly what made the shipped lines-changed leg
    #                    fire on nothing. Two measured traps live in this fixture: WinRT OCR
    #                    drops 2-3 char tokens whole (the first L<n> draft read 0 lines), and
    #                    150% DPI makes 7pt Consolas ~14px per line, so the 30-line budget
    #                    needs the 440px label to stay unclipped.
    $gnProc = $null; $gaProc = $null
    $gateTmp = New-Object System.Collections.ArrayList
    try {
      $gnScript = Join-Path $env:TEMP ('dtx-gate-nofold-' + (Get-Random) + '.ps1')
      $gaScript = Join-Path $env:TEMP ('dtx-gate-anim-' + (Get-Random) + '.ps1')
      $gatePayload = Join-Path $env:TEMP ('dtx-gate-payload-' + (Get-Random) + '.txt')
      [void]$gateTmp.Add($gnScript); [void]$gateTmp.Add($gaScript); [void]$gateTmp.Add($gatePayload)
      $gnSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HXGN { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[void][HXGN]::SetProcessDPIAware()
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-GateNoFold'
$f.ClientSize = New-Object System.Drawing.Size(520, 240)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(1400, 1480)
$f.TopMost = $false
$lb = New-Object System.Windows.Forms.Label
$lb.Text = 'GATE-NOFOLD-STATIC'
$lb.Font = New-Object System.Drawing.Font('Segoe UI', 14)
$lb.SetBounds(20, 60, 480, 40)
[void]$f.Controls.Add($lb)
[System.Windows.Forms.Application]::Run($f)
'@
      $gaSrc = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HXGA { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[void][HXGA]::SetProcessDPIAware()
$f = New-Object System.Windows.Forms.Form
$f.Text = 'DTX-GateAnim'
$f.ClientSize = New-Object System.Drawing.Size(560, 460)
$f.StartPosition = 'Manual'
$f.Location = New-Object System.Drawing.Point(1380, 1440)
$f.TopMost = $true
$lb = New-Object System.Windows.Forms.Label
$lb.Text = ''
$lb.Font = New-Object System.Drawing.Font('Consolas', 7)
$lb.SetBounds(10, 10, 540, 440)
[void]$f.Controls.Add($lb)
$script:gaN = 0
$gaTimer = New-Object System.Windows.Forms.Timer
$gaTimer.Interval = 500
$gaTimer.Add_Tick({
  $script:gaN++
  $lb.Text = ($lb.Text + 'LINE-' + $script:gaN.ToString('0000') + '-OCCL-MOTION' + [Environment]::NewLine)
})
$gaTimer.Start()
[System.Windows.Forms.Application]::Run($f)
'@
      [System.IO.File]::WriteAllText($gnScript, $gnSrc, (New-Object System.Text.UTF8Encoding($false)))
      [System.IO.File]::WriteAllText($gaScript, $gaSrc, (New-Object System.Text.UTF8Encoding($false)))
      # >= fold-threshold chars so the receipt route is even in play (202 chars, no tail needed:
      # this case asserts a REFUSAL, never a verbatim read).
      $gateBody = ('C' * 100) + "`r`n" + ('D' * 100)
      [System.IO.File]::WriteAllText($gatePayload, $gateBody, (New-Object System.Text.UTF8Encoding($false)))
      $gnProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $gnScript -PassThru
      $gaProc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $gaScript -PassThru
      $gnWin = $null; $gaWin = $null
      $gateWait = [System.Diagnostics.Stopwatch]::StartNew()
      while ($gateWait.Elapsed.TotalSeconds -lt 15) {
        $gnWin = Resolve-Window 'DTX-GateNoFold'; $gaWin = Resolve-Window 'DTX-GateAnim'
        if ($gnWin -and $gaWin) { break }
        Start-Sleep -Milliseconds 400
      }
      if (-not ($gnWin -and $gaWin)) { throw 'the two occlusion-gate fixtures did not both appear within 15s' }
      Start-Sleep -Milliseconds 1500
      $gnH0 = [int](Resolve-Window 'DTX-GateNoFold').H
      # Split-stream capture (2026-10-29, live-r4): a paste this occlusion gate is supposed
      # to refuse can also emit a [scan=guard] WARNING on stderr, and under
      # ErrorActionPreference=Stop the bare 2>&1 turns that into a terminating
      # NativeCommandError that swallows the whole capture (verdict[gate] read
      # no-readback-line while exit and heights were fine). Separate files keep the
      # refusal text on stdout parseable; ReadAllText, not [string](Get-Content -Raw),
      # so an empty stream is '' and never a null (the live-r2 lesson).
      $gateErrF = Join-Path $env:TEMP ('dtx-gate-paste-' + [guid]::NewGuid().ToString('N') + '.stderr.txt')
      $gateOutF = $gateErrF -replace '\.stderr\.txt$', '.stdout.txt'
      [void]$gateTmp.Add($gateErrF); [void]$gateTmp.Add($gateOutF)
      $gateArgStr = '-NoProfile -ExecutionPolicy Bypass -File "' + $script:ToolEntryPath + '" paste "' + $gatePayload + '" --to DTX-GateNoFold'
      $gateCp = Start-Process -FilePath 'powershell.exe' -ArgumentList $gateArgStr -RedirectStandardOutput $gateOutF -RedirectStandardError $gateErrF -Wait -PassThru -NoNewWindow
      $gateCode = $gateCp.ExitCode
      $gateOut = ''
      if (Test-Path -LiteralPath $gateOutF) { $gateOut = [IO.File]::ReadAllText($gateOutF) }
      $gnH1 = [int](Resolve-Window 'DTX-GateNoFold').H
      ST-Check 'live: paste into a COVERED target that receives nothing is refused by the occlusion gate with the measured pct and the coverer named (the real-machine red-1/red-2 shape: the desktop could not rise above its coverers either)' (
        # v3.1.0 (P-04) wording branch, strength unchanged: the verbatim expectation leg now has
        # its own occlusion gate, so a covered paste can be refused BEFORE the weak receipt chain
        # runs - the refusal then reads 'expect refused: target occluded=N% coveredBy=...' instead
        # of 'receipt-tried=occluded-refused (...)'. Both are accepted; every substantive assertion
        # (exit 1, a percentage named, the coverer named, no 'accepted on receipt', no growth) is
        # still required. Measured live at 21:20: only the wording moved, exit code stayed 1.
        ($gateCode -eq 1) -and ($gateOut -match 'receipt-tried=occluded-refused|expect refused: target occluded') -and ($gateOut -match 'occluded-refused=\d+(\.\d+)?%|occluded=\d+%') -and
        ($gateOut -match 'DTX-GateAnim') -and ($gateOut -notmatch 'accepted on receipt=') -and (($gnH1 - $gnH0) -lt 8))
      Write-Output ("      paste occlusion gate live: exit$gateCode h$gnH0->$gnH1 occlusion-gate=" + (Get-PasteReceiptOcclusionMax))
      $gateLine = (($gateOut.Trim() -split "`r?`n" | Where-Object { $_ -match 'readback=|occluded-refused|none-of-three|accepted on receipt|expect refused' }) -join ' ;; ')
      Write-Output ('      verdict[gate]: ' + $(if ($gateLine) { $gateLine } else { 'no-readback-line' }))
      if (-not $gateLine) { Write-Output ('      gate stdout tail: ' + (($gateOut.Trim() -split "`r?`n" | Select-Object -Last 3) -join ' | ')); Write-Output ('      gate stderr head: ' + ((@([IO.File]::ReadAllLines($gateErrF)) | Select-Object -First 1) -join '')) }
    } catch {
      ST-Check 'live: paste occlusion gate fixture block setup+run' $false
      Write-Output "      paste occlusion gate error: $($_.Exception.Message)"
    } finally {
      if ($gnProc -and -not $gnProc.HasExited) { try { Stop-Process -Id $gnProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
      if ($gaProc -and -not $gaProc.HasExited) { try { Stop-Process -Id $gaProc.Id -Force -ErrorAction SilentlyContinue } catch { } }
      foreach ($gl in @('DTX-GateNoFold', 'DTX-GateAnim')) {
        $gwin = Resolve-Window $gl
        if ($gwin) { try { Stop-Process -Id $gwin.Pid -Force -ErrorAction SilentlyContinue } catch { } }
      }
      foreach ($gt in $gateTmp) { if (Test-Path -LiteralPath $gt) { Remove-Item -LiteralPath $gt -Force -ErrorAction SilentlyContinue } }
    }
  } else {
    # v4.1.3 (external review A, found while measuring the four-context matrix): this used
    # to be a bare Write-Output shaped like a check outcome. The log therefore printed a
    # "SKIP  " line the summary never counted - 815 passed / 0 skipped on screen next to a
    # SKIP row. It IS a "could not run here" outcome, so it is one now.
    ST-Skip 'live OCR checks (pass --live to run them)' 'offline run - the live ladder was not requested'
  }

  # INC-02 (offline): the guard lifecycle measured through the isolated interface. Every leg below
  # runs in BOTH modes and none of them touches the shared clipboard - the seam stands in for save,
  # verdict and restore over an in-memory snapshot, so "success, exception and cancellation all
  # restore" is a measurement here rather than a promise about a --live round nobody authorized.
  # $q2Box.seq records what actually ran, in order; the comparison against the expected order is the
  # ruler, and the planted out-of-order witness below says that ruler can see a swap.
  $q2Snap = @{ Kind = 'text'; Text = 'DTX-SEAM-SNAPSHOT'; Files = @(); ImagePath = ''; ImageSaveError = $false; Formats = @('UnicodeText'); Extras = @(); ReadError = '' }
  $q2Box = @{ save = 0; verdict = 0; restore = 0; restored = $null; seq = @(); snapshot = $q2Snap; verdictText = 'yes'; restoreText = 'clipboard restored (previous content was text, 16 chars)' }
  $q2Seam = @{
    Save = { $q2Box.save = [int]$q2Box.save + 1; $q2Box.seq = @($q2Box.seq) + 'save'; return $q2Box.snapshot }
    Verdict = { param($st) $q2Box.verdict = [int]$q2Box.verdict + 1; $q2Box.seq = @($q2Box.seq) + 'verdict'; return [string]$q2Box.verdictText }
    Restore = { param($st) $q2Box.restore = [int]$q2Box.restore + 1; $q2Box.seq = @($q2Box.seq) + 'restore'; $q2Box.restored = $st; return [string]$q2Box.restoreText }
  }
  # (1) the success path, including that the snapshot was taken BEFORE the write
  $q2G1 = Start-LiveClipboardGuard 'seam-success' $q2Seam
  $q2N1 = 'not-run'
  try {
    if (-not $q2G1.Started) { throw 'the guard refused a clipboard its own verdict called restorable' }
    $q2Box.seq = @($q2Box.seq) + 'write'; $q2G1.Written = $true
  } finally { $q2N1 = Stop-LiveClipboardGuard $q2G1 }
  $q2Order1 = (@($q2Box.seq) -join ',')
  $q2OrderWant = 'save,verdict,write,restore'
  # Mutation witness, EXECUTED THROUGH A SECOND COPY OF THE SAME SEAM, not compared against a literal:
  # the write is planted before the guard starts, which is exactly what a normalization site that saves
  # only after it writes does. The same ruler is then pointed at the order that actually got recorded -
  # a comparison that accepts 'write before save' measures nothing, and a teeth value computed from a
  # string literal never exercises the ruler at all.
  $q2BoxM = @{ save = 0; verdict = 0; restore = 0; restored = $null; seq = @(); snapshot = $q2Snap; verdictText = 'yes'; restoreText = 'clipboard restored (previous content was text, 16 chars)' }
  $q2SeamM = @{
    Save = { $q2BoxM.save = [int]$q2BoxM.save + 1; $q2BoxM.seq = @($q2BoxM.seq) + 'save'; return $q2BoxM.snapshot }
    Verdict = { param($st) $q2BoxM.verdict = [int]$q2BoxM.verdict + 1; $q2BoxM.seq = @($q2BoxM.seq) + 'verdict'; return [string]$q2BoxM.verdictText }
    Restore = { param($st) $q2BoxM.restore = [int]$q2BoxM.restore + 1; $q2BoxM.seq = @($q2BoxM.seq) + 'restore'; $q2BoxM.restored = $st; return [string]$q2BoxM.restoreText }
  }
  $q2BoxM.seq = @($q2BoxM.seq) + 'write'
  $q2G1m = Start-LiveClipboardGuard 'seam-write-before-save' $q2SeamM
  $q2N1m = 'not-run'
  try { $q2G1m.Written = $true } finally { $q2N1m = Stop-LiveClipboardGuard $q2G1m }
  $q2Order1m = (@($q2BoxM.seq) -join ',')
  $q2RulerTeeth1 = (($q2Order1m -cne $q2OrderWant) -and ($q2Order1 -ceq $q2OrderWant))
  ST-Check 'unit (INC-02): through the isolated interface a restorable clipboard saves before the write, allows it and restores exactly that snapshot on the success path (order measured, and a swapped order is refused by the same ruler)' (
    ($q2G1.Started -eq $true) -and ($q2Order1 -ceq $q2OrderWant) -and $q2RulerTeeth1 -and
    ([int]$q2Box.save -eq 1) -and ([int]$q2Box.verdict -eq 1) -and ([int]$q2Box.restore -eq 1) -and
    ([string]$q2Box.restored.Text -ceq 'DTX-SEAM-SNAPSHOT') -and ((Get-ClipboardRestoreOutcome $q2N1) -ceq 'ok'))
  Write-Output ('      INC-02 seam order ruler: want=' + $q2OrderWant + ' measured=' + $q2Order1 +
    ' planted-inversion=' + $q2Order1m + ' refused=' + ($q2Order1m -cne $q2OrderWant) +
    ' counts=' + [string]$q2Box.save + '/' + [string]$q2Box.verdict + '/' + [string]$q2Box.restore +
    ' mutated-counts=' + [string]$q2BoxM.save + '/' + [string]$q2BoxM.verdict + '/' + [string]$q2BoxM.restore +
    ' mutated-note-outcome=' + (Get-ClipboardRestoreOutcome $q2N1m))
  # (2) the exception path: the block throws AFTER the write, the finally still restores
  $q2Box = @{ save = 0; verdict = 0; restore = 0; restored = $null; seq = @(); snapshot = $q2Snap; verdictText = 'yes'; restoreText = 'clipboard restored (previous content was text, 16 chars)' }
  $q2G2 = Start-LiveClipboardGuard 'seam-exception' $q2Seam
  $q2N2 = 'not-run'
  $q2Caught2 = ''
  try {
    $q2Box.seq = @($q2Box.seq) + 'write'; $q2G2.Written = $true
    throw 'injected: the fixture never came up'
  } catch { $q2Caught2 = $_.Exception.Message } finally { $q2N2 = Stop-LiveClipboardGuard $q2G2 }
  ST-Check 'unit (INC-02): the exception exit path is covered too - a throw after the write still restores the snapshot, and the guard does not swallow the original reason' (
    ($q2Caught2 -ceq 'injected: the fixture never came up') -and ((@($q2Box.seq) -join ',') -ceq 'save,verdict,write,restore') -and
    ([int]$q2Box.restore -eq 1) -and ((Get-ClipboardRestoreOutcome $q2N2) -ceq 'ok'))
  # (3) the cancellation path: an early break out of the block, no exception at all
  $q2Box = @{ save = 0; verdict = 0; restore = 0; restored = $null; seq = @(); snapshot = $q2Snap; verdictText = 'yes'; restoreText = 'clipboard restored (previous content was text, 16 chars)' }
  $q2G3 = Start-LiveClipboardGuard 'seam-cancel' $q2Seam
  $q2N3 = 'not-run'
  $q2LeftLoop = -1
  try {
    while ($true) {
      $q2Box.seq = @($q2Box.seq) + 'write'; $q2G3.Written = $true
      $q2LeftLoop = 1
      break
    }
  } finally { $q2N3 = Stop-LiveClipboardGuard $q2G3 }
  ST-Check 'unit (INC-02): an exit that is neither success nor an exception (a break out of the block) still restores, and the restore note is the answer of the guard itself' (
    ($q2LeftLoop -eq 1) -and ((@($q2Box.seq) -join ',') -ceq 'save,verdict,write,restore') -and
    ([int]$q2Box.restore -eq 1) -and ((Get-ClipboardRestoreOutcome $q2N3) -ceq 'ok') -and ($q2N3 -like 'clipboard restored (*'))
  # (4) and (5): the two refusals. Started=false, the write is never reached, restore never runs, and
  # the reason the live catch prints is the measured verdict itself.
  $q2Box = @{ save = 0; verdict = 0; restore = 0; restored = $null; seq = @(); snapshot = $q2Snap; verdictText = 'no - unknown formats (HTML Format); a write would need --replace-clipboard'; restoreText = 'MUST-NOT-RUN' }
  $q2G4 = Start-LiveClipboardGuard 'seam-refuse-formats' $q2Seam
  $q2Gate4 = ''
  $q2N4 = 'not-run'
  try {
    if (-not $q2G4.Started) { $q2Gate4 = 'clipboard guard refused the normalization write: ' + [string]$q2G4.Verdict; throw $q2Gate4 }
    $q2Box.seq = @($q2Box.seq) + 'write'; $q2G4.Written = $true
  } catch { } finally { $q2N4 = Stop-LiveClipboardGuard $q2G4 }
  $q2Seq4 = (@($q2Box.seq) -join ',')
  $q2Restore4 = [int]$q2Box.restore
  $q2Box = @{ save = 0; verdict = 0; restore = 0; restored = $null; seq = @(); snapshot = $q2Snap; verdictText = 'unknown - the clipboard could not be read (injected: access denied); a write would need --replace-clipboard'; restoreText = 'MUST-NOT-RUN' }
  $q2G5 = Start-LiveClipboardGuard 'seam-refuse-unknown' $q2Seam
  $q2N5 = 'not-run'
  try {
    if (-not $q2G5.Started) { throw 'refused' }
    $q2Box.seq = @($q2Box.seq) + 'write'; $q2G5.Written = $true
  } catch { } finally { $q2N5 = Stop-LiveClipboardGuard $q2G5 }
  $q2Seq5 = (@($q2Box.seq) -join ',')
  $q2Restore5 = [int]$q2Box.restore
  ST-Check 'unit (INC-02): a clipboard the tool cannot put back - unknown formats, or a clipboard it could not read - refuses the write, never writes, never restores and hands the verdict to the gate as the reason' (
    ($q2G4.Started -eq $false) -and ($q2G5.Started -eq $false) -and
    ($q2Gate4 -ceq 'clipboard guard refused the normalization write: no - unknown formats (HTML Format); a write would need --replace-clipboard') -and
    ($q2Seq4 -ceq 'save,verdict') -and ($q2Restore4 -eq 0) -and ($q2Seq5 -ceq 'save,verdict') -and ($q2Restore5 -eq 0) -and
    ((Get-ClipboardRestoreOutcome $q2N5) -ceq 'skipped') -and ($q2N5 -like 'skipped clipboard restore (the guard refused the write: unknown - the clipboard could not be read*)') -and
    ($q2N4 -like 'skipped clipboard restore (the guard refused the write: no - unknown formats (HTML Format)*') -and
    ((Get-ClipboardRestoreOutcome $q2N4) -ceq 'skipped'))
  # (6) the two no-op shapes: a block that never got a guard, and one whose guard started but whose
  # write line never ran. Both must say so and must NOT touch the clipboard on the way out - a guard
  # that re-writes an unchanged clipboard is a second writer nobody asked for.
  $q2Box = @{ save = 0; verdict = 0; restore = 0; restored = $null; seq = @(); snapshot = $q2Snap; verdictText = 'yes'; restoreText = 'MUST-NOT-RUN' }
  $q2N6a = Stop-LiveClipboardGuard $null
  $q2G6 = Start-LiveClipboardGuard 'seam-no-write' $q2Seam
  $q2N6b = Stop-LiveClipboardGuard $q2G6
  ST-Check 'unit (INC-02): a guard that was never started, and one that started but never wrote, both report skipped without touching the clipboard on the way out' (
    ($q2G6.Started -eq $true) -and ([int]$q2Box.restore -eq 0) -and
    ($q2N6a -ceq 'skipped clipboard restore (no guard was started for this block)') -and
    ($q2N6b -ceq 'skipped clipboard restore (the guard started but this block never wrote)') -and
    ((Get-ClipboardRestoreOutcome $q2N6a) -ceq 'skipped') -and ((Get-ClipboardRestoreOutcome $q2N6b) -ceq 'skipped'))
  # (7) the ruler the two live finally-blocks assert with, pointed at every shape of note: a lost
  # clipboard (partial/failed) must be RED, so the live rows cannot go green over one.
  $q2Clean = @('clipboard restored (previous content was text, 3 chars)', 'skipped clipboard restore (empty)',
    'skipped clipboard restore (the guard refused the write: no - unknown formats (HTML Format))',
    'skipped clipboard restore (no guard was started for this block)', 'skipped clipboard restore (the guard started but this block never wrote)')
  $q2Dirty = @('clipboard PARTIALLY restored (wanted text 3 chars; read back 0)', 'clipboard restore failed (text)', 'something else entirely')
  $q2RulerTable = @()
  foreach ($q2 in @($q2Clean)) { if ((Get-ClipboardRestoreOutcome $q2) -notin @('ok', 'skipped')) { $q2RulerTable += ('clean-reads-as-' + (Get-ClipboardRestoreOutcome $q2) + ': ' + $q2) } }
  foreach ($q2 in @($q2Dirty)) { if ((Get-ClipboardRestoreOutcome $q2) -in @('ok', 'skipped')) { $q2RulerTable += ('dirty-reads-as-' + (Get-ClipboardRestoreOutcome $q2) + ': ' + $q2) } }
  ST-Check 'unit (INC-02): the clean-exit ruler the live guards assert with accepts ok and every skipped shape and rejects partial, failed and an unrecognized note' (
    (@($q2RulerTable).Count -eq 0) -and (@($q2Clean).Count -eq 5) -and (@($q2Dirty).Count -eq 3))
  Write-Output ('      INC-02 ruler: clean=' + (@($q2Clean) -join ' | ') + ' dirty=' + (@($q2Dirty) -join ' | ') + ' breaches=[' + ($q2RulerTable -join '; ') + ']')
  # (8) the wiring itself, over the live-suite body: every shared-clipboard write in this family sits
  # behind a guard start and ahead of a Stop inside a finally. Comment lines are out of the scan (the
  # rationale above names clip.exe in prose) and every needle is built by CONCATENATION, because a
  # scan line holding its own search string counts itself as a site.
  $q2Agg = @($codeLines).Count
  $q2FnFrom = -1
  for ($q2 = 0; $q2 -lt $q2Agg; $q2++) { if ($codeLines[$q2].StartsWith('function Invoke-SelftestFamily-LiveSuite')) { $q2FnFrom = $q2; break } }
  $q2FnTo = $q2Agg
  if ($q2FnFrom -ge 0) { for ($q2 = $q2FnFrom + 1; $q2 -lt $q2Agg; $q2++) { if ($codeLines[$q2].StartsWith('function ')) { $q2FnTo = $q2; break } } }
  $q2Body = @()
  if ($q2FnFrom -ge 0) {
    for ($q2 = $q2FnFrom; $q2 -lt $q2FnTo; $q2++) {
      $q2L = [string]$codeLines[$q2]
      if ($q2L -match '^\s*#') { continue }
      $q2Body += $q2L
    }
  }
  $q2WriteNeedle = 'System32\clip' + '.exe'
  $q2StartNeedle = 'Start-LiveClipboard' + 'Guard'
  $q2StopNeedle = 'Stop-LiveClipboard' + 'Guard'
  $q2FinallyNeedle = '} finally {'
  $q2PairNotes = @()
  $q2WritesSeen = 0
  for ($q2 = 0; $q2 -lt $q2Body.Count; $q2++) {
    # the parentheses are load-bearing: -not [string]$x.Contains($n) casts the BOOLEAN result to the
    # string 'True'/'False', both of which are truthy, so the negation never fired and every body line
    # counted as a clip write.
    if (-not (([string]$q2Body[$q2]).Contains($q2WriteNeedle))) { continue }
    $q2WritesSeen++
    $q2StartIdx = -1
    for ($q2s = $q2 - 1; $q2s -ge 0; $q2s--) {
      if ($q2s -eq 0 -and [string]$q2Body[$q2s].StartsWith('function ')) { break }
      if (([string]$q2Body[$q2s]).Contains($q2StartNeedle) -and -not ([string]$q2Body[$q2s]).StartsWith('function ') -and -not ([string]$q2Body[$q2s]).Trim().StartsWith('function ')) { $q2StartIdx = $q2s; break }
    }
    $q2StopIdx = -1
    $q2FinIdx = -1
    for ($q2t = $q2 + 1; $q2t -lt $q2Body.Count; $q2t++) {
      if ($q2FinIdx -lt 0 -and ([string]$q2Body[$q2t]).Contains($q2FinallyNeedle)) { $q2FinIdx = $q2t }
      if (([string]$q2Body[$q2t]).Contains($q2StopNeedle) -and -not ([string]$q2Body[$q2t]).Trim().StartsWith('function ')) { $q2StopIdx = $q2t; break }
    }
    if ($q2StartIdx -lt 0) { $q2PairNotes += ('write@' + ($q2 + 1) + '=no-guard-ahead') }
    if ($q2StopIdx -lt 0) { $q2PairNotes += ('write@' + ($q2 + 1) + '=no-restore-after') }
    elseif ($q2FinIdx -lt 0 -or $q2FinIdx -gt $q2StopIdx) { $q2PairNotes += ('write@' + ($q2 + 1) + '=restore-not-inside-a-finally') }
  }
  # Mutation witness for the same ruler, run on the REAL body: move the guard start of the first
  # paired write to just after the write itself and require the ruler to name the break. A pairing
  # check that stays green when the guard is behind the write is not a wiring check at all.
  $q2Mutated = @($q2Body)
  $q2W1 = -1
  $q2S1 = -1
  for ($q2 = 0; $q2 -lt $q2Mutated.Count; $q2++) { if ($q2W1 -lt 0 -and ([string]$q2Mutated[$q2]).Contains($q2WriteNeedle)) { $q2W1 = $q2 } }
  for ($q2 = $q2W1 - 1; $q2 -ge 0; $q2--) { if (([string]$q2Mutated[$q2]).Contains($q2StartNeedle) -and -not ([string]$q2Mutated[$q2]).Trim().StartsWith('function ')) { $q2S1 = $q2; break } }
  $q2MutNotes = @('ruler-not-run')
  if ($q2W1 -ge 0 -and $q2S1 -ge 0) {
    $q2Hold = [string]$q2Mutated[$q2S1]
    $q2Mutated[$q2S1] = [string]$q2Mutated[$q2W1]
    $q2Mutated[$q2W1] = $q2Hold
    $q2MutNotes = @()
    for ($q2 = 0; $q2 -lt $q2Mutated.Count; $q2++) {
      if (-not ([string]$q2Mutated[$q2]).Contains($q2WriteNeedle)) { continue }
      $q2BackStart = -1
      for ($q2s = $q2 - 1; $q2s -ge 0; $q2s--) {
        if (([string]$q2Mutated[$q2s]).Contains($q2StartNeedle) -and -not ([string]$q2Mutated[$q2s]).Trim().StartsWith('function ')) { $q2BackStart = $q2s; break }
      }
      if ($q2BackStart -lt 0 -or $q2BackStart -gt $q2) { $q2MutNotes += ('write@' + ($q2 + 1) + '=guard-moved-behind') }
    }
  }
  ST-Check 'contract (INC-02): every shared-clipboard write in the live suite is behind a started guard and ahead of a restore inside a finally - the two normalization sites are named, and moving a guard behind its write breaks the ruler' (
    ($q2FnFrom -ge 0) -and ($q2WritesSeen -eq 2) -and (@($q2PairNotes).Count -eq 0) -and
    (@($q2MutNotes).Count -gt 0) -and ($q2W1 -ge 0) -and ($q2S1 -ge 0))
  Write-Output ('      INC-02 wiring ruler: body-lines=' + @($q2Body).Count + ' clip-writes=' + $q2WritesSeen +
    ' pairing-notes=[' + ($q2PairNotes -join '; ') + '] guard@' + $q2S1 + ' write@' + $q2W1 +
    ' swapped-and-named=[' + ($q2MutNotes -join '; ') + ']')

  # INC-03 (offline): the branch order the identity legs above depend on, measured against the REAL
  # resolver and the REAL process variables - set, read, restored inside one finally, and the
  # before/after snapshot of all four sources is part of the assertion, so a fixture cannot leak into
  # the rest of the round (let alone into a child's call record).
  # !! each name is parenthesised on purpose. The array comma binds TIGHTER than +, so the un-parenthesised
  # form @('A' + 'B', 'C' + 'D') collapses to ONE string: the clear-all and restore-all loops below then
  # touch a single garbage name, every leg reads back as already-clean, and the "all four isolated" claim
  # is measured against nothing. The shape is pinned by a count and the isolation by a read-back.
  $q3Names = @(('DTX_CALLER_L' + 'ABEL'), ('DTX_CALLER_S' + 'ESSION_ID'), ('CODEX_THREAD_' + 'ID'), ('CODEX_SESSION_' + 'ID'))
  $q3Base = @{}
  foreach ($q3n in $q3Names) { $q3Base[$q3n] = [Environment]::GetEnvironmentVariable($q3n, 'Process') }
  $q3Cases = @()
  try {
    foreach ($q3n in $q3Names) { [Environment]::SetEnvironmentVariable($q3n, $null, 'Process') }
    # measured, not assumed: every one of the four names has to answer empty here, or the 'all-empty'
    # leg below is proving nothing about the resolver and is only proving that this machine had unset vars.
    $q3ClearNotes = @()
    foreach ($q3n in $q3Names) { if ($null -ne [Environment]::GetEnvironmentVariable($q3n, 'Process')) { $q3ClearNotes += ($q3n + '=still-set') } }
    $q3All = Get-DtxCallIdentity $null
    $q3Cases += [pscustomobject]@{ Leg = 'all-empty'; Label = [string]$q3All.CallerLabel; Session = [string]$q3All.CallerSessionId; Source = [string]$q3All.IdentitySource }
    [Environment]::SetEnvironmentVariable('CODEX_THREAD_' + 'ID', 'q3-thread-fixture', 'Process')
    $q3T = Get-DtxCallIdentity $null
    $q3Cases += [pscustomobject]@{ Leg = 'codex-thread'; Label = [string]$q3T.CallerLabel; Session = [string]$q3T.CallerSessionId; Source = [string]$q3T.IdentitySource }
    [Environment]::SetEnvironmentVariable('CODEX_THREAD_' + 'ID', $null, 'Process')
    [Environment]::SetEnvironmentVariable('CODEX_SESSION_' + 'ID', 'q3-session-fixture', 'Process')
    $q3S = Get-DtxCallIdentity $null
    $q3Cases += [pscustomobject]@{ Leg = 'codex-session'; Label = [string]$q3S.CallerLabel; Session = [string]$q3S.CallerSessionId; Source = [string]$q3S.IdentitySource }
    [Environment]::SetEnvironmentVariable('DTX_CALLER_L' + 'ABEL', 'q3-label-fixture', 'Process')
    $q3E = Get-DtxCallIdentity $null
    $q3Cases += [pscustomobject]@{ Leg = 'label-outranks-codex'; Label = [string]$q3E.CallerLabel; Session = [string]$q3E.CallerSessionId; Source = [string]$q3E.IdentitySource }
  } finally {
    foreach ($q3n in $q3Names) { [Environment]::SetEnvironmentVariable($q3n, $q3Base[$q3n], 'Process') }
  }
  $q3Leaked = @()
  foreach ($q3n in $q3Names) { if ([string][Environment]::GetEnvironmentVariable($q3n, 'Process') -cne [string]$q3Base[$q3n]) { $q3Leaked += ($q3n + '=drifted') } }
  ST-Check 'unit (INC-03): the resolver answers unknown only when ALL FOUR sources are empty - a lone Codex thread or session answers Codex under its own source name, an explicit label outranks the fallback, and the harness leaves what it found (the four names and the measured clear are part of the assertion)' (
    (@($q3Names).Count -eq 4) -and (@(@($q3Names) | Sort-Object -Unique).Count -eq 4) -and
    (@($q3ClearNotes).Count -eq 0) -and
    (@($q3Cases).Count -eq 4) -and
    ($q3Cases[0].Label -ceq 'unknown') -and ($q3Cases[0].Session -ceq 'unknown') -and ($q3Cases[0].Source -ceq 'unknown') -and
    ($q3Cases[1].Label -ceq 'Codex') -and ($q3Cases[1].Session -ceq 'q3-thread-fixture') -and ($q3Cases[1].Source -ceq 'codex-thread-environment') -and
    ($q3Cases[2].Label -ceq 'Codex') -and ($q3Cases[2].Session -ceq 'q3-session-fixture') -and ($q3Cases[2].Source -ceq 'codex-session-environment') -and
    ($q3Cases[3].Label -ceq 'q3-label-fixture') -and ($q3Cases[3].Source -ceq 'partial-explicit-environment') -and
    (@($q3Leaked).Count -eq 0))
  Write-Output ('      INC-03 resolver legs: ' + ((@($q3Cases) | ForEach-Object { $_.Leg + '=>' + $_.Label + '/' + $_.Source }) -join ' ') +
    ' residue=[' + ($q3Leaked -join ',') + '] names=' + @($q3Names).Count + ' clear-breach=[' + ($q3ClearNotes -join ',') + ']' +
    ' inherited-codex=' + $(if ((@($q3Names).Count -eq 4) -and [string]$q3Base[$q3Names[2]]) { 'thread' } elseif ((@($q3Names).Count -eq 4) -and [string]$q3Base[$q3Names[3]]) { 'session' } else { 'none' }))
  # INC-03 wiring: in the live ladder the unlabeled child must run AFTER both DTX names and both Codex
  # names are cleared, and the labeled child must run after the restore. Positions are measured over
  # the family body (comment lines out, needles concatenated), each index gated at -1, and the whole
  # ordering claim is witnessed by swapping the clear with the run and showing the ruler names it -
  # the exact shape the old control had: an isolated label and an unisolated fallback.
  $q3Agg = @($codeLines).Count
  $q3FnFrom = -1
  for ($q3 = 0; $q3 -lt $q3Agg; $q3++) { if ($codeLines[$q3].StartsWith('function Invoke-SelftestFamily-LiveSuite')) { $q3FnFrom = $q3; break } }
  $q3FnTo = $q3Agg
  if ($q3FnFrom -ge 0) { for ($q3 = $q3FnFrom + 1; $q3 -lt $q3Agg; $q3++) { if ($codeLines[$q3].StartsWith('function ')) { $q3FnTo = $q3; break } } }
  $q3Body = @()
  if ($q3FnFrom -ge 0) {
    for ($q3 = $q3FnFrom; $q3 -lt $q3FnTo; $q3++) {
      $q3L = [string]$codeLines[$q3]
      if ($q3L -match '^\s*#') { continue }
      $q3Body += $q3L
    }
  }
  $q3Needles = @{
    ClearLabel = 'Set-StLiveCaller' + 'Identity $null'
    ClearCodex = 'Set-StLiveCodex' + 'Identity $null $null'
    UnlabeledRun = 'st-id-' + 'unlabeled-'
    FallbackRun = 'st-id-' + 'codex-'
    RestoreCodex = 'Set-StLiveCodex' + 'Identity $stIdBase'
    Relabel = 'Set-StLiveCaller' + 'Identity ' + [char]39 + 'selftest-live'
    LabeledRun = 'st-id-' + 'labeled-'
  }
  $q3Idx = @{}
  foreach ($q3k in @('ClearLabel', 'ClearCodex', 'UnlabeledRun', 'FallbackRun', 'Relabel', 'LabeledRun')) {
    $q3Idx[$q3k] = -1
    for ($q3 = 0; $q3 -lt $q3Body.Count; $q3++) {
      if (([string]$q3Body[$q3]).Contains([string]$q3Needles[$q3k])) { $q3Idx[$q3k] = $q3; break }
    }
  }
  # the restore is looked for AFTER the fallback run, not anywhere in the body: the fallback leg
  # itself re-arms the inherited Codex id before it spawns, and first-occurrence-anywhere would read
  # that line as the finally's restore and time the order backwards.
  $q3Idx.RestoreCodex = -1
  if ($q3Idx.FallbackRun -ge 0) {
    for ($q3 = $q3Idx.FallbackRun + 1; $q3 -lt $q3Body.Count; $q3++) {
      if (([string]$q3Body[$q3]).Contains([string]$q3Needles.RestoreCodex)) { $q3Idx.RestoreCodex = $q3; break }
    }
  }
  $q3OrderOk = (($q3Idx.ClearLabel -ge 0) -and ($q3Idx.ClearLabel -lt $q3Idx.ClearCodex) -and ($q3Idx.ClearCodex -lt $q3Idx.UnlabeledRun) -and
    ($q3Idx.UnlabeledRun -lt $q3Idx.FallbackRun) -and ($q3Idx.FallbackRun -lt $q3Idx.RestoreCodex) -and
    ($q3Idx.RestoreCodex -lt $q3Idx.Relabel) -and ($q3Idx.Relabel -lt $q3Idx.LabeledRun))
  # Mutation witness on a copy of the body: put the fallback clear back AFTER the unlabeled child run
  # (which is what the shipped control did) and require the ruler to refuse the ordering.
  $q3Mutated = @($q3Body)
  $q3MutBroken = $false
  if (($q3Idx.ClearCodex -ge 0) -and ($q3Idx.UnlabeledRun -ge 0)) {
    $q3Hold = [string]$q3Mutated[$q3Idx.ClearCodex]
    $q3Mutated[$q3Idx.ClearCodex] = [string]$q3Mutated[$q3Idx.UnlabeledRun]
    $q3Mutated[$q3Idx.UnlabeledRun] = $q3Hold
    $q3MutCodex = -1
    $q3MutRun = -1
    for ($q3 = 0; $q3 -lt $q3Mutated.Count; $q3++) {
      if ($q3MutCodex -lt 0 -and ([string]$q3Mutated[$q3]).Contains([string]$q3Needles.ClearCodex)) { $q3MutCodex = $q3 }
      if ($q3MutRun -lt 0 -and ([string]$q3Mutated[$q3]).Contains([string]$q3Needles.UnlabeledRun)) { $q3MutRun = $q3 }
    }
    $q3MutBroken = (($q3MutCodex -ge 0) -and ($q3MutRun -ge 0) -and ($q3MutCodex -gt $q3MutRun))
  }
  ST-Check 'contract (INC-03): the unlabeled child runs only after every identity source is cleared and the labeled child only after the restore - the order is measured over the body and a control that clears the fallback after the run is refused' (
    ($q3FnFrom -ge 0) -and $q3OrderOk -and $q3MutBroken -and ($q3Idx.ClearLabel -lt $q3Idx.LabeledRun))
  Write-Output ('      INC-03 order ruler: clearLabel@' + $q3Idx.ClearLabel + ' clearCodex@' + $q3Idx.ClearCodex + ' unlabeled@' + $q3Idx.UnlabeledRun +
    ' fallback@' + $q3Idx.FallbackRun + ' restore@' + $q3Idx.RestoreCodex + ' relabel@' + $q3Idx.Relabel + ' labeled@' + $q3Idx.LabeledRun +
    ' swapped=' + $q3MutBroken)

  # The outcome prefixes are the gate's wire format: every log parser downstream (including
  # the 'PASS line count equals passed' contract above) reads a line starting with one as a
  # check result. So only the two emitters may print them - found by traversal, and the
  # boundary itself is asserted, because a lint whose exemption window silently failed to
  # locate would pass for the wrong reason.
  $stEmitFrom = -1
  $stEmitTo = -1
  for ($oci = 0; $oci -lt $codeLines.Count; $oci++) {
    if ($stEmitFrom -lt 0) {
      if ($codeLines[$oci].StartsWith('function ST-Check')) { $stEmitFrom = $oci }
      continue
    }
    if ($codeLines[$oci].StartsWith('function Get-RegionCheckNames')) { $stEmitTo = $oci; break }
  }
  ST-Check 'contract: the outcome-emitter range was located by traversal (a missing boundary would make the bare-prefix lint vacuous)' (
    $stEmitFrom -ge 0 -and $stEmitTo -gt $stEmitFrom)
  $bareOutcome = @()
  for ($oci = 0; $oci -lt $codeLines.Count; $oci++) {
    if ($codeLines[$oci] -match '^\s*#') { continue }
    if ($codeLines[$oci] -notmatch 'Write-Output\s+.?(PASS|FAIL|SKIP)  ') { continue }
    if ($oci -ge $stEmitFrom -and $oci -lt $stEmitTo) { continue }
    $bareOutcome += (($oci + 1).ToString())
  }
  ST-Check 'contract: only ST-Check and ST-Skip print an outcome prefix (a bare SKIP line is not a counted outcome)' (
    @($bareOutcome).Count -eq 0)
  if (@($bareOutcome).Count -gt 0) { Write-Output ("      bare outcome-prefix writes at lines: " + (@($bareOutcome) -join ', ')) }


}
