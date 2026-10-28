# lib/handlers-batch.ps1 - the batch-group handlers, lifted out of desktop.ps1 (A-17..A-19 line).
#    Byte-identical to what the dispatcher carried after A-15 pen 2: the union of the lifted lines was
#    hashed before the cut and the same bytes are re-hashed from this file afterwards (printed by
#    handler-lift.js, and recorded in the ledger row for this card). The group membership is declared in
#    $script:StHandlerGroups and reconciled against the definitions by lint (A-16) - this file is named in
#    $script:StHandlerFiles in the same write that removes the code from the entry, so neither half can
#    land on its own.

# v4.4.0 (A-15): imgclick - the case body, verbatim
function Invoke-Handler-imgclick([string]$Cmd, [string[]]$Rest) {
      # imgclick <outPath> <ix> <iy> [--to <sel>] [--expect <needle>|--expect-gone <needle>] [--dry] [--allow-outside] [--stale-ok] [--require-verified]
      # v1.5.0 WP-3: reverse-map an image pixel through <outPath>.map.txt and
      # click the derived screen point. Replaces painted-out ix/scale math;
      # --dry prints the mapping and stops. A missing sidecar is a hard error.
      # v1.5.1 WP-B: the sidecar is validated against the window's CURRENT rect
      # before anything is clicked - a window that moved/resized since capture
      # (>2px) is refused instead of silently clicked at the stale position;
      # --stale-ok maps against the old origin anyway. rect/zoom captures have
      # no host window and say so in the echo (staleness not verifiable).
      # CU-EXTERNAL-EXPERIENCE-20261028 (A1): a crop CAN be bound to a host now
      # (rect/zoom ... --to <sel>), and --require-verified turns "unverifiable" from a
      # note into a refusal BEFORE any input. --stale-ok and --require-verified are
      # contradictory permissions, so asking for both is refused here, by name.
      $own = Strip-OwnFlags $Rest 'imgclick'
      $dry = [bool]$own.Values['--dry']
      $staleOk = [bool]$own.Values['--stale-ok']
      $requireVer = [bool]$own.Values['--require-verified']
      $p = Split-Target @($own.Rest) 'imgclick'
      if ($p.Words.Count -ne 3) { throw 'usage: imgclick <outPath> <ix> <iy> [--to <sel>] [--expect <needle>|--expect-gone <needle>] [--dry] [--allow-outside] [--stale-ok] [--require-verified]' }
      if ($requireVer -and $staleOk) { throw 'imgclick: --require-verified and --stale-ok contradict each other - one refuses anything not verified, the other explicitly maps against a stale origin; pick one' }
      $img = $p.Words[0]
      $ix = [int]$p.Words[1]; $iy = [int]$p.Words[2]
      $map = Read-MapSidecar $img
      if ($ix -lt 0 -or $ix -ge $map.OutW -or $iy -lt 0 -or $iy -ge $map.OutH) { throw "imgclick: image coords ($ix,$iy) outside $($map.OutW)x$($map.OutH) of $img" }
      $st = Test-MapSidecarStale $map
      if ($st.Verdict -eq 'gone') { throw "imgclick: $($st.Msg)" }
      if ($requireVer -and $st.Verdict -ne 'ok') {
        throw "imgclick: --require-verified: this image cannot be verified against its host window ($($st.Verdict)) - $($st.Msg). Re-capture with 'win <sel>' or 'rect/zoom ... --to <sel>', or drop --require-verified to accept the OLD unverified contract"
      }
      if ($st.Verdict -eq 'stale' -and -not $staleOk) { throw "imgclick: $($st.Msg)" }
      $sp = Convert-ImageToScreen $map $ix $iy
      $staleNote = ''
      if ($st.Verdict -eq 'unverifiable') { $staleNote = "  ($($st.Msg))" }
      elseif ($st.Verdict -eq 'stale') { $staleNote = "  [stale-ok] $($st.Msg)" }
      # v1.5.7 (D-6, owner's added condition): grid lines are painted ON this image, so a
      # point read off it can land on a line. Silently mapping it through would be the
      # same class of lie as an unstated truncation.
      $gridWarn = $(if ($map.Grid -gt 0) { "  WARNING: source image carries a grid overlay (step=$($map.Grid)px, labelled in screen coords) - a point measured off it may sit on a grid line; read the labels or prefer find-text <small region> --needle <text>" } else { '' })
      # v1.7.0 (J-07 A, "do not lose" #1): the echo must carry the mapping provenance -
      # which sidecar, and the actual image->screen formula (scale-aware: 1:1 wins read
      # "screen = image + (L,T)", scaled rect/zoom reads "screen = image / k + (L,T)").
      $mapForm = $(if ($map.Scale -eq 1) { "screen = image + ($($map.OriginX),$($map.OriginY))" } else { "screen = image / $($map.Scale) + ($($map.OriginX),$($map.OriginY))" })
      "imgclick: $img ($($map.OutW)x$($map.OutH) kind=$($map.Kind) scale=$($map.Scale)) image ($ix,$iy) -> screen ($($sp.X),$($sp.Y))  [map: $img.map.txt; $mapForm]$staleNote$gridWarn"
      if ($dry) {
        "  [dry run] not clicked"
      } else {
        $tgt = $null
        if ($p.Sel) {
          $tgt = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle
          Emit-ResolveNote
        }
        # CU-EXTERNAL-EXPERIENCE-20261028 (A1): a strict caller must not click a point that
        # was mapped from ANOTHER window - the pixel came from $map's host, so a --to that
        # resolves to a different handle is the same lie as a stale origin.
        if ($requireVer -and $null -ne $tgt -and ([Int64]$map.HostHwnd -ne 0) -and ([Int64]$tgt.Handle -ne [Int64]$map.HostHwnd)) {
          throw "imgclick: --require-verified: the image was captured from handle=$(([Int64]$map.HostHwnd)) ('$($map.HostTitle)') but --to resolves to handle=$(([Int64]$tgt.Handle)) ('$($tgt.Title)') - refusing to click a point mapped from another window"
        }
        Invoke-TargetBlockGuard $tgt
        Invoke-HitWindowCheck $sp.X $sp.Y $tgt ($p.Sel -ne '') $p.AllowOutside
        # CU-EXTERNAL-EXPERIENCE-20261028 B5: the shared flag table already admits
        # --expect-change for imgclick; before this line the handler accepted it and did
        # nothing. Baseline before the click, verdict after it - same shape as click/rclick.
        $ecb = Get-ExpectChangeBaseline $p $tgt
        # v4.6.7 (CU-466-REVIEW-20261028-01 A1-a): the geometry above was verified BEFORE
        # Resolve-Target ran. Activation and the guards since then cost time, and a host that
        # moved in that window turns a pixel mapped from the OLD origin into a lie even when the
        # old point still falls inside the window rect (the landing guard cannot see that). So
        # re-check the SAME recorded baseline immediately before input; never translate the old
        # point by the measured delta. --stale-ok remains the explicit permission to map anyway.
        $stInput = Test-MapSidecarStale $map
        if ($stInput.Verdict -eq 'gone') { throw "imgclick: $($stInput.Msg)" }
        if ($stInput.Verdict -eq 'stale' -and ($requireVer -or -not $staleOk)) {
          throw "imgclick: the host moved after the initial check, immediately before input - $($stInput.Msg) - refusing; re-capture the image"
        }
        Log-Action (Get-RedactedLogArgs $Rest @() $p.LogPayload) "img=$img ix=$ix iy=$iy -> $($sp.X),$($sp.Y)" $Cmd
        Move-Click $sp.X $sp.Y 'left'
        "clicked $($sp.X),$($sp.Y)"
        Invoke-ExpectChangeCheck $p $ecb 'clicked'
        Invoke-ActionExpectation $p $tgt 'clicked'
      }
}

# v4.4.0 (A-15): zoom - the case body, verbatim
function Invoke-Handler-zoom([string]$Cmd, [string[]]$Rest) {
      # zoom <x> <y> <w> <h> [scale] [outPath] [--to <sel>] - capture a small region and
      # enlarge it (NearestNeighbor) so tiny text/buttons are readable in one
      # shot instead of iterating manual rect crops. Echo gives the mapping
      # back to screen pixels: screen = (x + ix/scale, y + iy/scale).
      # CU-EXTERNAL-EXPERIENCE-20261028 (A1): --to binds the zoom crop to its host window
      # exactly like rect --to; the refusal happens before any pixels are grabbed.
      $hb = Resolve-CaptureTargetArgs $Rest
      $Rest = @($hb.Words)
      if ($Rest.Count -lt 4) { throw 'usage: zoom <x> <y> <w> <h> [scale] [outPath] [--to <sel>]' }
      $x = [int]$Rest[0]; $y = [int]$Rest[1]; $w = [int]$Rest[2]; $h = [int]$Rest[3]
      if ($w -le 0 -or $h -le 0) { throw 'zoom: w and h must be positive' }
      $scale = 2.0; $path = ''
      if ($Rest.Count -gt 4) {
        foreach ($a in @($Rest[4..($Rest.Count - 1)])) {
          if ($a -match '^\d+(\.\d+)?$') { $scale = [double]$a }
          elseif (-not $path) { $path = $a }
        }
      }
      if ($scale -lt 1 -or $scale -gt 8) { throw 'zoom: scale must be within 1..8' }
      if (-not $path) { $path = Default-ShotName 'zoom' }
      $hostWin = $null; $hostSnap = $null
      if ($hb.Sel) {
        $ch = Resolve-CropHost $hb.Sel $x $y $w $h 'zoom'
        $hostWin = $ch.Win
        # v4.6.7 (A1-b): freeze identity AND rect BEFORE the pixels are grabbed; the capture is
        # re-checked after the save and a moved host is refused instead of being re-recorded.
        $hostSnap = Get-CaptureHostSnapshot $ch
      }
      Ensure-OutDir
      $src = New-Object System.Drawing.Bitmap($w, $h)
      $gs = [System.Drawing.Graphics]::FromImage($src)
      $gs.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size($w, $h)))
      $gs.Dispose()
      $ow = [int]($w * $scale); $oh = [int]($h * $scale)
      $dst = New-Object System.Drawing.Bitmap($ow, $oh)
      $gd = [System.Drawing.Graphics]::FromImage($dst)
      $gd.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
      $gd.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
      $gd.DrawImage($src, 0, 0, $ow, $oh)
      $gd.Dispose(); $src.Dispose()
      # v4.6.8 (CU-467-REVIEW-20261028-01 A1-b): re-check the frozen baseline BEFORE the PNG is
      # written. The old order saved first and refused afterwards, so a failed re-capture into an
      # existing name replaced the image while the old .map.txt stayed behind - a pair that read
      # 'ok' once the window returned. Refuse first, then publish.
      if ($null -ne $hostSnap) { [void](Assert-CaptureHostStable $hostSnap 'zoom') }
      $dst.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
      $dst.Dispose()
      $size = (Get-Item -LiteralPath $path).Length
      Write-MapSidecar $path $x $y $scale $ow $oh 'zoom' $hostWin 0 $hostSnap
      "saved $path  src=($x,$y) ${w}x${h} scale=${scale}x image=${ow}x${oh}  bytes=$size"
      "click mapping: screen = ($x + ix/$scale, $y + iy/$scale)  (ix,iy = pixel in zoom image)"
      "map: $path.map.txt  (imgclick <image> <ix> <iy> maps back and clicks; unmap prints only)"
      if ($hostWin) { "host binding: --to '$($hb.Sel)' bound pid=$($hostWin.Pid) handle=$(([IntPtr]$hostWin.Handle).ToInt64()) - the sidecar records this window's rect so imgclick --require-verified can compare the crop against it" }
}

# v4.4.0 (A-15): ime-en - the case body, verbatim
function Invoke-Handler-ime-en([string]$Cmd, [string[]]$Rest) {
      # ime-en - actively switch the foreground IME to alphanumeric (English)
      # and POLL-VERIFY; some TSF IMEs ignore the control message, and the
      # verification turns that into an honest ERROR instead of a false OK.
      $f = Get-FgThreadInfo
      $orig = Get-ImeMode $f.Hwnd
      if ($orig -lt 0) { throw "no default IME window for pid=$($f.Pid) title='$($f.Title)'" }
      if ($orig -eq 0) { "already alphanumeric: pid=$($f.Pid) title='$($f.Title)'"; exit 0 }
      if (Set-ImeModeVerified $f.Hwnd 0) {
        "ime-en: pid=$($f.Pid) title='$($f.Title)' now alphanumeric (previous $(Format-ImeMode $orig); restore with: ime-cn 0x$($orig.ToString('X')))"
      } else {
        throw "ime-en: IME did not accept the switch (mode still $(Format-ImeMode (Get-ImeMode $f.Hwnd))); switch manually (Ctrl+Space / Shift) or use paste"
      }
}

# v4.4.0 (A-15): ime-cn - the case body, verbatim
function Invoke-Handler-ime-cn([string]$Cmd, [string[]]$Rest) {
      # ime-cn - switch back to a Chinese (native) conversion mode and verify.
      # Default 0x1 (native, halfwidth symbols); pass the exact mode that
      # ime-en reported to restore it bit-exact, e.g. ime-cn 0x401.
      $f = Get-FgThreadInfo
      $mode = 0x1
      if ($Rest.Count -ge 1 -and $Rest[0]) { $mode = [Convert]::ToInt32(($Rest[0] -replace '^0x', ''), 16) }
      if (Set-ImeModeVerified $f.Hwnd $mode) {
        "ime-cn: pid=$($f.Pid) title='$($f.Title)' now $(Format-ImeMode $mode)"
      } else {
        throw "ime-cn: IME did not accept the switch (mode still $(Format-ImeMode (Get-ImeMode $f.Hwnd)))"
      }
}

# v4.4.0 (A-15): ime-state - the case body, verbatim
function Invoke-Handler-ime-state([string]$Cmd, [string[]]$Rest) {
      # ime-state - the CONVERSION mode (Chinese composition vs alphanumeric)
      # of the foreground thread's IME, which the HKL cannot show. Read via the
      # default IME window (sub-codes probed live, see Get-ImeMode).
      $f = Get-FgThreadInfo
      $mode = Get-ImeMode $f.Hwnd
      if ($mode -lt 0) { throw "no default IME window for pid=$($f.Pid) title='$($f.Title)'" }
      if ($script:Json) {
        Get-ImeStateView $f.Pid $f.Title $mode | ConvertTo-Json -Compress
      } else {
        "foreground pid=$($f.Pid) title='$($f.Title)'  $(Format-ImeMode $mode)  (0 = type English directly; native = IME composes)"
      }
}

# v4.4.0 (A-15): challenge-probe - the case body, verbatim
function Invoke-Handler-challenge-probe([string]$Cmd, [string[]]$Rest) {
      # challenge-probe <sel> [--allow-attempt --attempt-click x,y]
      # READ-ONLY by default: whole-window OCR, match the challenge corpus, report
      # type/confidence/staleness and the human-handoff block. The window's pixels are
      # hashed and recorded so a challenge that sits unchanged across calls reads as
      # STALE (expired ticket - dismiss it, do not solve it). --allow-attempt arms the
      # ONE authorized interaction: a single caller-named click inside this window;
      # if the challenge survives it, a fuse is recorded and every later attempt on
      # the same challenge image is refused. No solver exists here by design.
      $cpAllow = $false; $cpClick = $null
      $cpWords = @($Rest)
      if ($cpWords.Count -lt 1) { throw 'usage: challenge-probe <sel> [--allow-attempt --attempt-click x,y]' }
      $cpSel = "$($cpWords[0])"
      for ($cpi = 1; $cpi -lt $cpWords.Count; $cpi++) {
        $t = "$($cpWords[$cpi])"
        if ($t -eq '--allow-attempt') { $cpAllow = $true }
        elseif ($t -eq '--attempt-click') {
          $cpi++
          if ($cpi -ge $cpWords.Count) { throw 'challenge-probe: --attempt-click needs x,y' }
          $cpParts = "$($cpWords[$cpi])" -split ','
          if (@($cpParts).Count -ne 2 -or @($cpParts | Where-Object { $_ -match '^\d+$' }).Count -ne 2) { throw "challenge-probe: --attempt-click expects x,y (window-relative pixels), got: $($cpWords[$cpi])" }
          $cpClick = @{ X = [int]$cpParts[0]; Y = [int]$cpParts[1] }
        }
        else { throw "challenge-probe: unknown flag '$t' (valid: --allow-attempt | --attempt-click x,y)" }
      }
      if ($cpAllow -and ($null -eq $cpClick)) { throw 'challenge-probe: --allow-attempt also needs --attempt-click x,y - an authorized attempt is ONE caller-named click, never a free hand' }
      $cw = Resolve-Window $cpSel
      if (-not $cw) { throw "no window matching: $cpSel" }
      # hash + OCR read the CLIENT area, not the frame: a focus flip repaints the title
      # bar and would make an unchanged challenge read as changed (measured: stale=False
      # on the second sample of a static image when the window lost focus in between)
      $cpCr = New-Object DT+RECT
      [void][DT]::GetClientRect($cw.Handle, [ref]$cpCr)
      $cpPt = New-Object DT+POINT
      [void][DT]::ClientToScreen($cw.Handle, [ref]$cpPt)
      $cpCx = [int]$cpPt.X; $cpCy = [int]$cpPt.Y
      $cpCw = [int]($cpCr.Right - $cpCr.Left); $cpCh = [int]($cpCr.Bottom - $cpCr.Top)
      $cpLines = Invoke-OcrRegion $cpCx $cpCy $cpCw $cpCh
      $cpVerdict = Test-ChallengeLines $cpLines
      # v3.1.0 (P-05): two full client-area captures (CopyFromScreen + PNG encode + MD5) used to
      # run here and be discarded - staleness is decided by the IDENTITY hash below (the challenge
      # text), never by pixels. Nothing ever read them (measured: two assignments, zero uses), so
      # every challenge-probe call paid for two screenshots to throw the bytes away. A lint now
      # refuses the shape "assigned and never read" for this name again.
      $cpHash = Get-ChallengeIdentityHash $cpVerdict
      # v4.0.1 (audit finding 2): the file's own existence is asked separately from whether this
      # call could read it, because "never logged" and "could not read" are different answers and
      # only the first one may be reported as first-seen.
      $cpLogExists = [bool](Test-Path -LiteralPath $ActionLog)
      $cpLogErr = ''
      $cpLog = @()
      if ($cpLogExists) {
        try { $cpLog = @(Get-Content -LiteralPath $ActionLog -Encoding UTF8 -ErrorAction Stop) }
        catch { $cpLogErr = $_.Exception.Message }
      }
      $cpState = Test-ChallengeLogLines $cpLog $cw.Pid
      $cpStale = Test-ChallengeStale $cpState.LastHash $cpHash
      # v4.1.1 (self-caught, would have made the finding-2 fix decoration): the sighting line used
      # to be an UNGUARDED write that ran BEFORE the state was ever consulted. On a fully locked
      # log it threw an unrelated IOException first, so neither the honest `stale=unknown(...)`
      # echo nor the refusal below could be reached. The write is attempted here and its failure
      # is folded INTO the state - a log we cannot write is a fuse we cannot arm.
      $cpSeenErr = ''
      try { Log-Action @("pid=$($cw.Pid)") "seen hash=$cpHash" $Cmd } catch { $cpSeenErr = $_.Exception.Message }
      if ($cpStale.Stale -eq $true) { try { Log-Action @("pid=$($cw.Pid)") "stale hash=$cpHash" $Cmd } catch { } }
      $cpLogState = Resolve-ChallengeLogState $cpLogExists ($cpLogErr -eq '') ($cpSeenErr -eq '')
      if (-not $cpVerdict.Challenge) {
        $cpNote = ''
        try {
          if (Test-SparseReadability ([int]$cw.W) ([int]$cw.H) (@($cpLines).Count) 1.5) { $cpNote = ' note=large-area-unreadable' }
        } catch { }
        "challenge: none lines=$(@($cpLines).Count)$cpNote"
        exit 0
      }
      "challenge: type=$($cpVerdict.Type) confidence=$($cpVerdict.Confidence) matched=[$(@($cpVerdict.Matched) -join ', ')] lines=$(@($cpLines).Count) rect=($([int]$cw.Left),$([int]$cw.Top),$([int]$cw.W)x$([int]$cw.H))"
      $cpStaleTxt = $cpStale.Stale
      $cpLogWhy = ''
      if ($cpLogErr) { $cpLogWhy = $cpLogErr } elseif ($cpSeenErr) { $cpLogWhy = $cpSeenErr }
      if ($cpLogState -ceq 'unreadable') { $cpStaleTxt = "unknown(log-unreadable: $cpLogWhy)" }
      if ($cpLogState -ceq 'unwritable') { $cpStaleTxt = "unknown(log-unwritable: $cpLogWhy)" }
      "stale=$cpStaleTxt$(if ($cpStale.Recommend) { " recommend=$($cpStale.Recommend)" })"
      "action: DO NOT treat a needle miss on this window as 'the card is gone' - this window is covered by an in-window challenge modal; judge the underlying target only after the challenge is dismissed"
      $cpShot = Join-Path $OutDir ('challenge-' + (Get-Date -Format 'yyyyMMddTHHmmss') + '.png')
      Save-RectEx $cw.Left $cw.Top $cw.W $cw.H $cpShot 0 -1 @() | Write-Output
      @((Build-ChallengeHandoff $cpVerdict $cw ($cpHash.Substring(0, 8)) $cpShot)) | ForEach-Object { Write-Output $_ }
      if (-not $cpAllow) {
        "attempt: not authorized (pass --allow-attempt --attempt-click x,y to permit ONE caller-named click; retries escalate account risk-control). There is NO solver in this tool by design - the boundary is deliberate, see README known limitations"
        Log-Action @("pid=$($cw.Pid)") "challenge type=$($cpVerdict.Type) verdict=reported-no-attempt" $Cmd
        exit 0
      }
      # An UNKNOWN fuse is treated as ARMED. This fuse exists only because a second attempt on the
      # same challenge image escalates account risk-control, so "could not check" - whether the
      # check failed because the log would not open for READING or because it would not accept the
      # sighting WRITE - must not buy a retry. The refusal is logged best-effort, and when even
      # that write fails the thrown message says so instead of implying an audit line that exists.
      if ($cpLogState -ceq 'unreadable' -or $cpLogState -ceq 'unwritable') {
        $cpFuseNote = ''
        try { Log-Action @("pid=$($cw.Pid)") "fuse-unknown hash=$cpHash reason=log-$($cpLogState.Substring(1))" $Cmd }
        catch { $cpFuseNote = ' - and the audit line could not be written either: ' + $_.Exception.Message }
        throw "challenge attempt refused: $ActionLog could not be used to check the fuse ($cpLogWhy), so the fuse state for pid=$($cw.Pid) is UNKNOWN and an unknown fuse is treated as armed (retries escalate account risk-control)$cpFuseNote. Free the log (another process is holding it) or have a human complete or dismiss the challenge"
      }
      if ($cpState.FuseHash -eq $cpHash) {
        Log-Action @("pid=$($cw.Pid)") "fuse-blocked hash=$cpHash" $Cmd
        throw "challenge attempt refused: the fuse for this exact challenge image (pid=$($cw.Pid) hash=$($cpHash.Substring(0, 8))) is armed from a previous failed attempt - a human completes or dismisses the challenge, or it is refreshed to a new image; retries escalate account risk-control"
      }
      Log-Action @("pid=$($cw.Pid)", "attempt-click=$($cpClick.X),$($cpClick.Y)") "attempt type=$($cpVerdict.Type) pre-hash=$cpHash" $Cmd
      $cpAx = [int]($cw.Left + $cpClick.X)
      $cpAy = [int]($cw.Top + $cpClick.Y)
      $cpClickErr = ''
      try {
        $null = Invoke-DesktopCommand 'click' @([string]$cpAx, [string]$cpAy, '--to', $cpSel)
      } catch {
        # the click never landed (guards refused, window vanished, ...) - that is still
        # a FAILED attempt: arm the fuse, tell the caller why, stop touching the challenge
        $cpClickErr = "$($_.Exception.Message)"
      }
      Start-Sleep -Milliseconds 800
      $cpLines2 = Invoke-OcrRegion $cpCx $cpCy $cpCw $cpCh
      $cpVerdict2 = Test-ChallengeLines $cpLines2
      $cpHash2 = Get-ChallengeIdentityHash $cpVerdict2
      if (-not $cpVerdict2.Challenge) {
        Log-Action @("pid=$($cw.Pid)") "attempt-cleared post-hash=$cpHash2" $Cmd
        "challenge attempt: cleared (no challenge text remains after the one authorized click)"
        exit 0
      }
      Log-Action @("pid=$($cw.Pid)") "fuse hash=$cpHash2" $Cmd
      $cpEm = [string][char]0x2014
      $cpWhy = 'the challenge is still on the window after the click'
      if ($cpClickErr) { $cpWhy = "the authorized click itself failed: $cpClickErr" }
      throw ("challenge attempt FAILED $cpEm refusing further interaction with this challenge (retries escalate account risk-control); fuse armed for pid=$($cw.Pid) hash=$($cpHash2.Substring(0, 8)) - $cpWhy")
}

# v4.4.0 (A-15): shots-cleanup - the case body, verbatim
function Invoke-Handler-shots-cleanup([string]$Cmd, [string[]]$Rest) {
      # shots-cleanup [--keep N] [--go] [--quarantine <dir>]
      # v1.5.2 WP-7 (audit R-14): bound the runtime screenshot dir. DRY RUN by
      # default; --go does NOT delete - it moves the files into the machine's
      # designated quarantine folder and appends a MANIFEST.md line per file
      # (original path + SHA256 + size + times), so every move can be undone.
      # v2.5.2/v2.5.3: the --go target is no longer a machine-specific folder baked
      # into the script - precedence: explicit --quarantine > DTX_QUARANTINE process
      # env > DTX_QUARANTINE User-scope registry > Machine-scope registry, else the
      # command REFUSES (exit 2) naming both remedies and echoing no path. The
      # registry tiers exist because a process env block is a startup snapshot:
      # resident hosts predate any later User-level write, so $env: alone would
      # refuse on exactly the machine that set the variable. Dry run never needed
      # the target, so it works unchanged on a machine with nothing configured.
      $keepN = 100; $go = $false; $quarFlag = ''
      $words = @($Rest)
      for ($i = 0; $i -lt $words.Count; $i++) {
        if ($words[$i] -eq '--keep') { $i++; $keepN = Read-FlagNumber '--keep' $words[$i] $true '(images to keep)' }
        elseif ($words[$i] -eq '--go') { $go = $true }
        elseif ($words[$i] -eq '--quarantine') { $i++; $quarFlag = $words[$i] }
        else { throw "shots-cleanup: unknown flag '$($words[$i])' (valid: --keep <n> | --go | --quarantine <dir>)" }
      }
      if ($keepN -lt 0) { throw "shots-cleanup: --keep must be >= 0, got: $keepN" }
      Ensure-OutDir
      $all = @(Get-ChildItem -LiteralPath $OutDir -File | Where-Object { $_.Name -like '*.png' -or $_.Name -like '*.jpg' -or $_.Name -like '*.map.txt' })
      $plan = Get-ShotCleanupPlan $all $keepN
      "shots-cleanup: $($all.Count) capture file(s) in $OutDir, keep newest $keepN image(s) -> keep $($plan.Keep.Count), move $($plan.Move.Count) ($($plan.Bytes) bytes)"
      if ($plan.Move.Count -eq 0) { 'nothing to do'; exit 0 }
      $shown = 0
      foreach ($m in $plan.Move) {
        if ($shown -lt 12) {
          $shown++
          "  MOVE $($m.Name)  $($m.Length) bytes  $($m.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm'))Z"
        }
      }
      if ($plan.Move.Count -gt $shown) { "  ... and $($plan.Move.Count - $shown) more" }
      if (-not $go) { 'DRY RUN - nothing moved. Pass --go to MOVE them to the quarantine folder (never delete).'; exit 0 }
      # v2.5.3: resolve the --go target here (only --go needs one). Refusal and the
      # missing-folder branch below are DIFFERENT failures and stay separate: this one
      # means "no target was configured at all", that one means "the configured target
      # is not there".
      $qResolved = Resolve-ShotsCleanupQuarantine $quarFlag
      $quar = $qResolved.Dir
      if (-not $quar) {
        Write-Output 'ERROR: shots-cleanup --go refused: no quarantine target. Pass --quarantine <dir> or set the DTX_QUARANTINE environment variable (process env or User/Machine registry scope); the baked-in machine default was removed on purpose.'
        exit 2
      }
      "shots-cleanup: quarantine target resolved by: $($qResolved.Source)"
      if (-not (Test-Path -LiteralPath $quar)) { throw "shots-cleanup: quarantine folder does not exist: $quar - create it first or pass --quarantine <existing parent>" }
      # v2.6.0: the loop moved into Move-ShotsToQuarantine so the automatic trim uses the
      # same code. The heading text, the MANIFEST format and both echo lines are unchanged.
      $qHeading = "## shots-cleanup v1.5.2 " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm') + " UTC (keep newest $keepN, moved $(@($plan.Move).Count))"
      $qRes = Move-ShotsToQuarantine $plan.Move $quar 'shots_' $qHeading
      foreach ($ft in @($qRes.Failures)) { "$ft" }
      Log-Action @("shots-cleanup", "--keep", "$keepN", '--go') "moved=$($qRes.Moved) failed=$($qRes.Failed) unrecorded=$(@($qRes.Unrecorded).Count) dest=$($qRes.Dest)" $Cmd
      "shots-cleanup: moved $($qRes.Moved) file(s) to $($qRes.Dest) (manifest: $($qRes.Manifest)), $($qRes.Failed) failed - nothing was deleted"
      if (@($qRes.Unrecorded).Count -gt 0) {
        # TB-3: this is not a move failure, it is an EVIDENCE failure, and the two must not share a
        # counter. The mover stopped on its own because a file it had already moved could not get its
        # MANIFEST row written - so the run that looks partially successful is the one where the undo
        # trail has a hole. Named on stdout with the entry contract's ERROR: prefix, and red.
        Write-Output "ERROR: shots-cleanup --go: $(@($qRes.Unrecorded).Count) moved file(s) have NO manifest row (manifest: $($qRes.Manifest)) - the run stopped rather than moving more files without a record"
        exit 1
      }
      if ($qRes.Failed -gt 0) {
        # v3.1.0 (P-05): the entry contract is "exit 1 AND stdout carries ERROR: ..." - the
        # summary line above is prose, so a caller that only greps for ERROR: read a partially
        # failed run as clean. The exit-2 refusal path in this same command already names itself
        # properly; only this path did not. Failures are still echoed one by one above.
        Write-Output "ERROR: shots-cleanup --go: $($qRes.Failed) move(s) FAILED, $($qRes.Moved) moved - failure lines above, manifest: $($qRes.Manifest)"
        exit 1
      }
}

# v4.4.0 (A-15): unmap - the case body, verbatim
function Invoke-Handler-unmap([string]$Cmd, [string[]]$Rest) {
      # unmap <outPath> <ix> <iy> [--stale-ok] - side-effect-free inverse mapping:
      # print the screen point for an image pixel (no click, no log). imgclick
      # minus click. v1.5.1 WP-B: same staleness contract as imgclick - a win
      # sidecar whose window moved/resized fails rather than printing a wrong
      # answer (--stale-ok overrides); rect/zoom sidecars say unverifiable.
      $own = Strip-OwnFlags $Rest 'unmap'
      $staleOk = [bool]$own.Values['--stale-ok']
      $Rest = @($own.Rest)
      if ($Rest.Count -ne 3) { throw 'usage: unmap <outPath> <ix> <iy> [--stale-ok]' }
      $map = Read-MapSidecar $Rest[0]
      $ix = [int]$Rest[1]; $iy = [int]$Rest[2]
      if ($ix -lt 0 -or $ix -ge $map.OutW -or $iy -lt 0 -or $iy -ge $map.OutH) { throw "unmap: image coords ($ix,$iy) outside $($map.OutW)x$($map.OutH) of $($Rest[0])" }
      $st = Test-MapSidecarStale $map
      if ($st.Verdict -eq 'gone') { throw "unmap: $($st.Msg)" }
      if ($st.Verdict -eq 'stale' -and -not $staleOk) { throw "unmap: $($st.Msg)" }
      $sp = Convert-ImageToScreen $map $ix $iy
      $staleNote = ''
      if ($st.Verdict -eq 'unverifiable') { $staleNote = "  ($($st.Msg))" }
      elseif ($st.Verdict -eq 'stale') { $staleNote = "  [stale-ok] $($st.Msg)" }
      # v1.5.7 (D-6): same admission as imgclick - unmap prints only, so the grid note
      # belongs on its output too (the number it prints may have been read off a line).
      $gridWarn = $(if ($map.Grid -gt 0) { "  WARNING: source image carries a grid overlay (step=$($map.Grid)px, labelled in screen coords)" } else { '' })
      "unmap: $($Rest[0]) ($($map.OutW)x$($map.OutH) kind=$($map.Kind) scale=$($map.Scale)) image ($ix,$iy) -> screen ($($sp.X),$($sp.Y))$staleNote$gridWarn"
}

