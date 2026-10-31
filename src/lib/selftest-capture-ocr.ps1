# lib/selftest-capture-ocr.ps1 - family capture-ocr of the selftest section, lifted out of
# lib/selftest.ps1 by A-14h (A-beta). Bodies are byte-identical to what the section carried.
# Ten banners in six gathered pieces (two pairs were already adjacent): read-text on a saved
# capture, one OCR tail for every miss, CJK spacing Windows OCR invents, the retry decision,
# the tiled planner and merge, the folded long-payload receipt, the sparse-read hint and
# needle sub-span aiming, the one-budget wait pair, and the PT profile / anchor pair. State
# arrives only through $Ctx; lint (A-14b) names any read that reaches past it. The lifted
# pieces were scattered between lines 509 and 3625, so gathering them reorders the section -
# the card counts that by name and position rather than claiming the order does not matter.
function Invoke-SelftestFamily-CaptureOcr($Ctx) {
  # context handover (the one thing in this file that is not lifted text)
  $self = [string]$Ctx['self']
  $src = [string]$Ctx['src']
  $codeLines = $Ctx['codeLines']
  $clCount = $Ctx['clCount']
  $code = $Ctx['code']
  $j5ProdStart = $Ctx['j5ProdStart']
  $j5ProdEnd = $Ctx['j5ProdEnd']

  # ---------- v2.7.0: OCR a saved capture (read-text --file) ----------
  # This is the check that finally makes the OCR road MEASURABLE: it renders a known
  # string to a PNG with GDI+ and reads it back through the same engine the live road
  # uses, with no window raised and no desktop touched. It is NOT gated behind --live,
  # because the whole point is that it can run anywhere, any time - and it is the harness
  # the recognizer A/B (en-US vs zh-Hans language pack) is meant to be run through.
  # On a box with no OCR language pack it SKIPS with a reason; skipping must not move the
  # badge total (that is the v2.5.4 fix, and this check is one of its first users).
  $ocrPackTag = ''
  try {
    $oe = Get-OcrEngine
    if ($null -ne $oe) { $ocrPackTag = "$($oe.RecognizerLanguage.LanguageTag)" }
  } catch { $ocrPackTag = '' }
  $ocDir = Join-Path $env:TEMP ('st_ocrfile_' + [guid]::NewGuid().ToString('N'))
  # v4.1.3 (external review B): the else branch below holds NINETEEN checks, while this
  # branch used to emit ONE skip - so every engine that cannot reach the recognizer lost
  # eighteen checks without saying so (measured here: pwsh 7 emits 795 of 815). The skip
  # side now accounts for the whole region by name, read back out of this file's source.
  $script:StRecord = New-Object System.Collections.ArrayList
  if ($ocrPackTag -eq '') {
    ST-SkipRegion 'ocr-file' 'no OCR language pack / recognizer unreachable from this engine - the road itself is unavailable, so this is not a regression'
  } else {
    # REGION-BEGIN ocr-file  (every ST-Check between here and REGION-END is accounted for
    # by ST-SkipRegion when the recognizer is missing - a check that needs something ELSE
    # must not join this region, or the skip side would excuse it too)
    New-Item -ItemType Directory -Force -Path $ocDir | Out-Null
    $ocPng = Join-Path $ocDir 'render.png'
    $ocWant = 'File Edit View Run Terminal Help'
    $ab = New-Object System.Drawing.Bitmap(1200, 90)
    $ag = [System.Drawing.Graphics]::FromImage($ab)
    $ag.Clear([System.Drawing.Color]::White)
    $ag.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $af = New-Object System.Drawing.Font('Segoe UI', 28, [System.Drawing.FontStyle]::Regular)
    $ag.DrawString($ocWant, $af, [System.Drawing.Brushes]::Black, 10, 20)
    $ag.Dispose(); $af.Dispose()
    $ab.Save($ocPng, [System.Drawing.Imaging.ImageFormat]::Png)
    $ocW = [int]$ab.Width; $ocH = [int]$ab.Height
    $ab.Dispose()
    try {
      # The round trip goes through the REAL command line, not the function: the first
      # version of this check called Invoke-OcrFile directly and passed while the CLI was
      # broken (Split-Path -LiteralPath -Leaf dies on PowerShell 5.1, and it only lives in
      # the CLI's header). A check must exercise the path a caller exercises.
      $cliOut = Join-Path $ocDir 'cli.txt'
      $cliArgs = '-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" read-text --file "' + $ocPng + '"'
      $cli = Start-Process -FilePath 'powershell.exe' -ArgumentList $cliArgs -RedirectStandardOutput $cliOut -RedirectStandardError "$cliOut.err" -Wait -PassThru -NoNewWindow
      $cliTxt = ''
      if (Test-Path -LiteralPath $cliOut) { $cliTxt += (Get-Content -Raw -LiteralPath $cliOut) }
      if (Test-Path -LiteralPath "$cliOut.err") { $cliTxt += (Get-Content -Raw -LiteralPath "$cliOut.err") }
      $cliGot = ''
      foreach ($cl in ($cliTxt -split "`r?`n")) {
        if ($cl -match '^L\d\d img-rect=') { $cliGot += (($cl -replace '^L\d\d img-rect=\([0-9,\-x]+\)\s*', '') + ' ') }
      }
      $gotNorm = ($cliGot -replace '\s+', ' ').Trim()
      $wantNorm = ($ocWant -replace '\s+', ' ').Trim()
      ST-Check 'e2e: read-text --file round-trips a rendered string back through the recognizer' (
        ($cli.ExitCode -eq 0) -and ("$gotNorm" -ceq "$wantNorm") -and ($cliTxt -match 'source=file') -and ($cliTxt -match 'NOT a screen rect'))
      Write-Output ("      ocr-file: pack=$ocrPackTag exit=$($cli.ExitCode) wanted=[$wantNorm] got=[$gotNorm]")
      $fr = Invoke-OcrFile $ocPng 1.0
      ST-Check 'e2e: read-text --file reports the image size and keeps every rect inside it' (
        ($fr.W -eq $ocW) -and ($fr.H -eq $ocH) -and (@($fr.Lines | Where-Object { $_.X -lt 0 -or $_.Y -lt 0 -or ($_.X + $_.W) -gt $ocW -or ($_.Y + $_.H) -gt $ocH }).Count -eq 0))
      # The refusal is user-visible behavior, so it is pinned end to end: a child that
      # exits non-zero AND names both the img-rect label and the pinned-contract reason.
      # The argument string carries EMBEDDED quotes on purpose: PS 5.1's Start-Process
      # -ArgumentList array form does not quote elements containing spaces.
      $jrOut = Join-Path $ocDir 'jsonrefusal.txt'
      $jrArgs = '-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" read-text --file "' + $ocPng + '" --json'
      $jr = Start-Process -FilePath 'powershell.exe' -ArgumentList $jrArgs -RedirectStandardOutput $jrOut -RedirectStandardError "$jrOut.err" -Wait -PassThru -NoNewWindow
      $jrTxt = ''
      if (Test-Path -LiteralPath $jrOut) { $jrTxt += (Get-Content -Raw -LiteralPath $jrOut) }
      if (Test-Path -LiteralPath "$jrOut.err") { $jrTxt += (Get-Content -Raw -LiteralPath "$jrOut.err") }
      ST-Check 'e2e: read-text --file refuses --json instead of emitting an ambiguous coordinate space' (
        ($jr.ExitCode -ne 0) -and ("$jrTxt" -match 'img-rect') -and ("$jrTxt" -match 'pinned'))
      # The header and the per-line label are the only things standing between a caller
      # and clicking a glyph's image px, so the documentation of them is a check, not a
      # comment. Whitespace MUST be collapsed before matching: the Usage page is an array
      # of indented lines, so a phrase that wraps across a line break would never match
      # (this cost one red run - the phrase was in the help all along).
      $usageTxt = ((@(Get-UsageLines)) -join ' ') -replace '\s+', ' '
      ST-Check 'lint: the file-mode help names the img-rect label and says the coords are not a screen rect' (
        ($usageTxt.Contains('img-rect=')) -and ($usageTxt.Contains('NOT a screen rect')) -and ($usageTxt.Contains('--file <png>')))
      ST-Check 'lint: the file-mode help documents the retry ladder, its own floor, its opt-out and the engine-cap skip' (
        ($usageTxt.Contains('--scale tiled')) -and ($usageTxt.Contains('auto-retry')) -and
        ($usageTxt.Contains('30000 px2')) -and ($usageTxt.Contains('300k px2')) -and
        ($usageTxt.Contains('--no-tile')) -and ($usageTxt.Contains('never "region"')) -and
        ($usageTxt.Contains('four un-upscaled overlapping crops')) -and
        ($usageTxt.Contains("dimension limit rules the upscale out")))
      # v2.9.0 changed what a read-text header LOOKS like, so the change is pinned where a
      # reader finds it: the help must name the label, say the lowered line belongs to
      # read-text alone, and point at the negative paths that still shout at the band.
      ST-Check 'lint: the help states the readability label and that only read-text lowered its line' (
        ($usageTxt.Contains('readability=')) -and ($usageTxt.Contains('FOR read-text ONLY')) -and
        ($usageTxt.Contains('0.1')) -and ($usageTxt.Contains('find-text / assert-text / expect')))

      # ---- v2.8.0 end to end. These drive the command line, not the functions, because
      # the defect fixed this round was precisely "a flag that is accepted and does
      # nothing": a function-level check would have stayed green through it.
      $stRun = {
        param([string]$Path, [string]$Extra, [string]$OutName)
        $o = Join-Path $ocDir $OutName
        $a = '-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" read-text --file "' + $Path + '" ' + $Extra
        $pr = Start-Process -FilePath 'powershell.exe' -ArgumentList $a -RedirectStandardOutput $o -RedirectStandardError "$o.err" -Wait -PassThru -NoNewWindow
        $txt = ''
        if (Test-Path -LiteralPath $o) { $txt += (Get-Content -Raw -LiteralPath $o) }
        if (Test-Path -LiteralPath "$o.err") { $txt += (Get-Content -Raw -LiteralPath "$o.err") }
        return @{ Exit = $pr.ExitCode; Txt = $txt }
      }
      # (1) --scale tiled must subdivide. The 1200x90 menu-bar render is far below the
      # engine's 10000px limit, so the only thing that can produce tiles >= 2 here is the
      # v2.8.0 override - which is what this asserts.
      $tT = & $stRun $ocPng '--scale tiled' 'tiled.txt'
      $tTiles = 0
      if ($tT.Txt -match 'tiled:\s+(\d+) tile') { $tTiles = [int]$Matches[1] }
      $tOut = New-Object System.Collections.ArrayList
      # 16px of slack, on purpose: the Windows engine jitters line bboxes (observed up to
      # ~90px on tiles sitting exactly at its dimension limit), and a strictly-in-bounds
      # assertion here would turn that engine artifact into a red gate. What must hold is
      # that no rect is off by a LOT - that is what a mapping bug looks like.
      foreach ($cl in ($tT.Txt -split "`r?`n")) {
        if ($cl -match '^L\d\d img-rect=\((-?\d+),(-?\d+),(\d+)x(\d+)\)') {
          $lx = [int]$Matches[1]; $ly = [int]$Matches[2]; $lw = [int]$Matches[3]; $lh = [int]$Matches[4]
          if ($lx -lt -16 -or $ly -lt -16 -or ($lx + $lw) -gt ($ocW + 16) -or ($ly + $lh) -gt ($ocH + 16)) { [void]$tOut.Add($cl) }
        }
      }
      ST-Check 'e2e: --scale tiled in file mode subdivides the image and keeps every img-rect inside it' (
        ($tT.Exit -eq 0) -and ($tTiles -ge 2) -and (@($tOut).Count -eq 0) -and ($tT.Txt -match 'source=file scale=2'))
      Write-Output ("      file tiling: tiles=$tTiles out-of-bounds=$(@($tOut).Count)")
      # (2) an empty read must go through the LADDER and every pass must report its own
      # count - including zeros, and including a pass that never ran because --max-tiles
      # refused it. The three cases that used to be indistinguishable ("this is a photo",
      # "the recognizer lost a region", "nobody looked") have to print differently.
      $gyPng = Join-Path $ocDir 'gray.png'
      $gb = New-Object System.Drawing.Bitmap(800, 500)
      $gg = [System.Drawing.Graphics]::FromImage($gb)
      $gg.Clear([System.Drawing.Color]::FromArgb(128, 128, 128))
      $gg.Dispose()
      $gb.Save($gyPng, [System.Drawing.Imaging.ImageFormat]::Png); $gb.Dispose()
      $tR = & $stRun $gyPng '' 'retry.txt'
      $tN = & $stRun $gyPng '--no-tile' 'notile.txt'
      ST-Check 'e2e: an empty capture is re-read through the ladder and each pass reports its own count' (
        ($tR.Exit -eq 0) -and ($tR.Txt -match 'auto-retry') -and
        ($tR.Txt -match 'whole-image@1x=0 line\(s\)') -and ($tR.Txt -match 'whole@2x=0 line\(s\)') -and
        ($tR.Txt -match 'quadrants@1x=0 line\(s\) \(4 tiles\)') -and ($tR.Txt -match 'kept=0'))
      ST-Check 'e2e: --no-tile suppresses the ladder (the opt-out has to be real, not decorative)' (
        ($tN.Exit -eq 0) -and (-not ($tN.Txt -match 'auto-retry')))
      $tM = & $stRun $gyPng '--max-tiles 2' 'maxtiles.txt'
      ST-Check 'e2e: a ladder pass the tile budget refuses is reported as skipped, not as a bare 0' (
        ($tM.Exit -eq 0) -and ($tM.Txt -match 'auto-retry') -and ($tM.Txt -match 'quadrants@1x=skipped') -and
        ($tM.Txt -match 'quadrants needs 4 tiles') -and ($tM.Txt -match '--max-tiles 2'))
      # (2b) THE REGRESSION v2.8.0 SHIPPED WITH. Its ladder was gated on the sparse WARN's
      # 300k px2 band, which sits ABOVE the real 228,800 px2 capture the retry exists for -
      # so that capture got no warning, no retry, and printed exactly like a blank image.
      # 400x300 = 120,000 px2 is below the old band and above the empty-read floor: it must
      # now come back with a ladder report.
      $smPng = Join-Path $ocDir 'gray-small.png'
      $sbk = New-Object System.Drawing.Bitmap(400, 300)
      $sgk = [System.Drawing.Graphics]::FromImage($sbk)
      $sgk.Clear([System.Drawing.Color]::FromArgb(120, 120, 120))
      $sgk.Dispose()
      $sbk.Save($smPng, [System.Drawing.Imaging.ImageFormat]::Png); $sbk.Dispose()
      $tS2 = & $stRun $smPng '' 'retrysmall.txt'
      ST-Check 'e2e: an empty read below the WARN band still gets the ladder (v2.8.0 gated it out and shipped that way)' (
        ($tS2.Exit -eq 0) -and ($tS2.Txt -match 'auto-retry') -and ($tS2.Txt -match 'quadrants@1x=') -and
        ($tS2.Txt -match 'floor=30000'))
      # The ladder PRINTS the scale it used, so that number is part of the contract, not an
      # internal detail: the first build of the quadrant pass returned no Scale key at all,
      # and a recovered capture announced itself as "scale=0" - a self-report that is
      # silently wrong is worse than no self-report. Pinned at the function boundary because
      # the CLI only shows the adopted branch, which the gray fixtures never reach.
      $qRes = Invoke-OcrFileQuadrants $ocPng 16
      $qOut = @($qRes.Lines | Where-Object { $_.X -lt 0 -or $_.Y -lt 0 -or ($_.X + $_.W) -gt $ocW -or ($_.Y + $_.H) -gt $ocH })
      ST-Check 'unit: the quadrant pass states the scale it really read at and keeps every rect inside the image' (
        ($qRes.Scale -eq 1.0) -and ($qRes.Tiles -eq 4) -and (@($qRes.Lines).Count -ge 1) -and (@($qOut).Count -eq 0))
      $lRes = Invoke-OcrFileRetryLadder $gyPng 16
      $lRes2 = Invoke-OcrFileRetryLadder $ocPng 16
      ST-Check 'unit: the ladder never reports a scale it did not use, whichever pass it keeps' (
        (@(1.0, 2.0) -contains [double]$lRes.Scale) -and (@(1.0, 2.0) -contains [double]$lRes2.Scale) -and
        ($lRes.Report -match 'whole@2x=') -and ($lRes2.Report -match 'whole@2x='))
      # v3.0.1 (audit item 8, reproduced 2026-10-05 on a 6000x200 capture): the first rung
      # upscaled unconditionally and the engine THROWS on an oversized bitmap rather than
      # returning nothing, so the throw ended the command and the quadrant pass - the one
      # built for wide images - never ran. Any stored capture wider than half the cap was
      # simply unreadable in file mode. Both directions below use the SAME file; the only
      # difference is the cap, so the skip cannot be explained by a broken fixture.
      $ldSkip = Invoke-OcrFileRetryLadder $ocPng 16 100
      ST-Check 'unit: a first rung the engine cannot fit is skipped WITH A REASON and the quadrant pass still delivers the text' (
        ($ldSkip.Report -match 'whole@2x=skipped \(') -and (@($ldSkip.Lines).Count -ge 1) -and ($ldSkip.Scale -eq 1.0))
      $ldFit = Invoke-OcrFileRetryLadder $ocPng 16 20000
      ST-Check 'unit: the same capture under a cap it DOES fit runs the first rung (a limit, not an unconditional branch)' (
        ($ldFit.Report -match 'whole@2x=[0-9]+ line') -and ($ldFit.Scale -eq 2.0))
      $ldEdge = @((Get-OcrFileRung1Fit 5000 200 10000).Fits, (Get-OcrFileRung1Fit 5001 200 10000).Fits,
        (Get-OcrFileRung1Fit 100 100 0).Fits, (Get-OcrFileRung1Fit 4999 4999 9998).Fits)
      ST-Check 'unit: the rung-1 fit test is inclusive at the cap and distrustful of an unknown cap' (
        ($ldEdge[0] -eq $true) -and ($ldEdge[1] -eq $false) -and ($ldEdge[2] -eq $false) -and ($ldEdge[3] -eq $true))
      Write-Output ("      rung1 fit: 5000x200@10000=" + $ldEdge[0] + " 5001=" + $ldEdge[1] + " cap0=" + $ldEdge[2] + " exact=" + $ldEdge[3])
      # (3) v2.9.0: the changed rule, asserted on RENDERED output in both directions.
      # A merely-sparse read now carries the measurement and stays quiet; a near-zero read
      # still shouts and still says "image", never "region". The middle fixture is the SAME
      # file read twice at two thresholds, so the quiet one cannot be explained by a blank
      # capture or a broken fixture - only by the threshold moving.
      $spPng = Join-Path $ocDir 'sparse.png'
      $sb = New-Object System.Drawing.Bitmap(800, 500)
      $sg = [System.Drawing.Graphics]::FromImage($sb)
      $sg.Clear([System.Drawing.Color]::White)
      $sfont = New-Object System.Drawing.Font('Segoe UI', 26, [System.Drawing.FontStyle]::Regular)
      $sg.DrawString('DTX sparse capture row one', $sfont, [System.Drawing.Brushes]::Black, [single]20, [single]30)
      $sg.DrawString('DTX sparse capture row two', $sfont, [System.Drawing.Brushes]::Black, [single]20, [single]90)
      $sg.Dispose(); $sfont.Dispose()
      $sb.Save($spPng, [System.Drawing.Imaging.ImageFormat]::Png); $sb.Dispose()
      $tS = & $stRun $spPng '' 'sparse.txt'
      ST-Check 'e2e: a merely sparse read carries readability= and stays quiet (the shout that fired on 18.6% of real traffic is now a measurement)' (
        ($tS.Exit -eq 0) -and ($tS.Txt -match 'readability=0\.5 lines per 100k px2') -and
        ($tS.Txt -match 'warn-below=0\.1') -and ($tS.Txt -match 'band=small-area') -and
        (-not ($tS.Txt -match 'WARN:')))
      $tSO = & $stRun $spPng '--min-line-density 1.5' 'sparse-old.txt'
      ST-Check 'e2e: the very same capture at the old 1.5 band DOES shout, so the quiet above is the threshold, not a blank fixture' (
        ($tSO.Exit -eq 0) -and ($tSO.Txt -match 'WARN: image is 800x500') -and ($tSO.Txt -match 'active-threshold=1'))
      $nzPng = Join-Path $ocDir 'nearzero.png'
      $nb = New-Object System.Drawing.Bitmap(2000, 1200)
      $ng = [System.Drawing.Graphics]::FromImage($nb)
      $ng.Clear([System.Drawing.Color]::White)
      $nfont = New-Object System.Drawing.Font('Segoe UI', 30, [System.Drawing.FontStyle]::Regular)
      $ng.DrawString('DTX near zero capture row one', $nfont, [System.Drawing.Brushes]::Black, [single]40, [single]60)
      $ng.DrawString('DTX near zero capture row two', $nfont, [System.Drawing.Brushes]::Black, [single]40, [single]120)
      $ng.Dispose(); $nfont.Dispose()
      $nb.Save($nzPng, [System.Drawing.Imaging.ImageFormat]::Png); $nb.Dispose()
      $tN2 = & $stRun $nzPng '' 'nearzero.txt'
      $nzLines = @($tN2.Txt -split "`r?`n" | Where-Object { $_ -match '^L\d\d img-rect=' }).Count
      ST-Check 'e2e: a near-zero read on a large capture still shouts, names it an image, and offers the ladder' (
        ($tN2.Exit -eq 0) -and ($tN2.Txt -match 'WARN: image is 2000x1200') -and (-not ($tN2.Txt -match 'WARN: region')) -and
        ($tN2.Txt -match 'readability=0\.0[0-9]') -and ($tN2.Txt -match 'warn-below=0\.1') -and
        ($tN2.Txt -match '--scale tiled') -and ($nzLines -ge 1))
      Write-Output ("      readability pair: sparse exit=$($tS.Exit) shouted=" + $(if ($tS.Txt -match 'WARN:') { 'yes' } else { 'no' }) +
        " old-band shouted=" + $(if ($tSO.Txt -match 'WARN:') { 'yes' } else { 'no' }) + " nearzero-lines=$nzLines")
    } finally {
      Remove-Item -LiteralPath $ocDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    # REGION-END ocr-file
  }
  $ocrFileEmitted = @($script:StRecord)
  $script:StRecord = $null
  ST-ReconcileRegion 'ocr-file' $ocrFileEmitted

  # ---------- unit: v1.5.5 (D-4) one OCR tail for every miss ----------
  $ot3 = Format-OcrSampleTail (@(
    [pscustomobject]@{ Text = 'alpha' }, [pscustomobject]@{ Text = 'beta' }, [pscustomobject]@{ Text = 'gamma' })) 8
  ST-Check 'unit: an OCR tail under the cap reports the total and says nothing is hidden' (
    $ot3 -ceq "OCR read 3 line(s) total: 'alpha', 'beta', 'gamma'")
  $otManyLines = @(1..11 | ForEach-Object { [pscustomobject]@{ Text = "L$_" } })
  $otMany = Format-OcrSampleTail $otManyLines 8
  # expected value is built as its own value first: `-ceq 'a' + 'b'` binds left to
  # right, i.e. ($x -ceq 'a') + 'b', and the assertion would compare a string.
  $otManyHead = ((1..8 | ForEach-Object { "'L{0}'" -f $_ }) -join ', ')
  $otManyWant = "OCR read 11 line(s) total: $otManyHead (+3 more lines not shown)"
  $otShown = (@([regex]::Matches($otMany, "'L[0-9]+'") | ForEach-Object { $_.Value }) | Sort-Object -Unique).Count
  ST-Check 'unit: an OCR tail over the cap names the hidden count, and the count is the real arithmetic' (
    $otMany -ceq $otManyWant -and $otShown -eq 8 -and $otMany.Contains('(+3 more'))
  ST-Check 'unit: an empty OCR read is reported as zero lines, never as a missing field' (
    (Format-OcrSampleTail @() 8) -ceq 'OCR read 0 line(s) total: ')
  ST-Check 'unit: a non-positive cap falls back to 8 instead of showing nothing' (
    (Format-OcrSampleTail $otManyLines 0) -ceq $otMany)

  # ---------- unit: CJK spacing that Windows OCR invents (built from code points
  # so this file stays pure ASCII) ----------
  $wen = [char]0x6587; $jian = [char]0x4EF6; $qing = [char]0x6E05; $dan = [char]0x5355
  $spaced = [string]$wen + ' ' + $jian + ' ' + $qing + ' ' + $dan
  $tight = [string]$wen + $jian + $qing + $dan
  ST-Check 'unit: Normalize-OcrText collapses CJK-CJK gaps' ((Normalize-OcrText $spaced) -eq $tight)
  ST-Check 'unit: Normalize-OcrText leaves English spacing alone' ((Normalize-OcrText 'a b c') -eq 'a b c')
  $cnLines = New-Object System.Collections.ArrayList
  [void]$cnLines.Add([pscustomobject]@{ Text = $spaced; X = 1; Y = 1; W = 40; H = 12 })
  ST-Check 'unit: natural CJK needle hits an OCR-spaced line' ((Find-OcrHits $cnLines ([string]$qing + $dan)).Count -eq 1)
  ST-Check 'unit: spaced CJK needle still hits (no regression)' ((Find-OcrHits $cnLines $spaced).Count -eq 1)
  # OCR renders a typed ASCII hyphen as U+2014 in terminal text; without folding,
  # every hyphenated --verify needle misses.
  $emdash = [string]('HELLO' + [char]0x2014 + 'VERIFY-TEST')
  ST-Check 'unit: dash confusables fold to ASCII hyphen' ((Normalize-OcrText $emdash) -eq 'HELLO-VERIFY-TEST')
  $dashLines = New-Object System.Collections.ArrayList
  [void]$dashLines.Add([pscustomobject]@{ Text = $emdash; X = 1; Y = 1; W = 90; H = 12 })
  ST-Check 'unit: hyphen needle hits an em-dash OCR line' ((Find-OcrHits $dashLines 'HELLO-VERIFY-TEST').Count -eq 1)
  # ---------- unit: OCR retry decision + normalization ----------
  # The old hardcoded 2200/1200 retry guard sat BELOW real window sizes, so
  # whole-window searches silently skipped the 2x pass while the miss message
  # claimed it ran (audit 2026-09-29b #1). Pin the engine-driven decision here.
  ST-Check 'unit: Test-OcrRetryFits - real-size windows retry' (
    (Test-OcrRetryFits 2361 1469 10000) -and (Test-OcrRetryFits 3840 2160 10000))
  ST-Check 'unit: Test-OcrRetryFits - boundary at engine limit' (
    (Test-OcrRetryFits 5000 5000 10000) -and -not (Test-OcrRetryFits 5001 100 10000) -and -not (Test-OcrRetryFits 6000 4000 10000))
  ST-Check 'unit: Test-OcrRetryFits - unknown engine limit means no retry' (-not (Test-OcrRetryFits 100 100 0))
  $fwComma = [string][char]0xFF0C
  $ocrDigits = "100 $fwComma 000 $fwComma 000"
  ST-Check 'unit: Normalize-OcrText folds fullwidth comma padding (100,000,000)' (
    (Find-OcrHits @([pscustomobject]@{ Text = $ocrDigits; X = 0; Y = 0; W = 1; H = 1 }) '100,000,000').Count -eq 1)

  # ---------- unit: tiled OCR planner + merge (v1.5.0 WP-1) ----------
  $pl = Get-OcrTilePlan 2482 1514 2.0 10000 64 16
  ST-Check 'tileplan: single tile when 2x fits the engine limit' ($pl.Error -eq '' -and $pl.Count -eq 1 -and $pl.Covered)
  $pl2 = Get-OcrTilePlan 6000 3000 2.0 10000 64 16
  ST-Check 'tileplan: oversized region tiles with full coverage' ($pl2.Error -eq '' -and $pl2.Count -gt 1 -and $pl2.Covered)
  $sizeOk = $true
  foreach ($t in $pl2.Tiles) { if (($t.W * 2) -gt 10000 -or ($t.H * 2) -gt 10000) { $sizeOk = $false } }
  ST-Check 'tileplan: every tile scaled stays within maxDim' $sizeOk
  $tw2 = $pl2.Tiles[0].W; $th2 = $pl2.Tiles[0].H
  $ovlOk = $true
  $ux = @($pl2.Tiles | ForEach-Object { $_.X } | Sort-Object -Unique)
  for ($i = 1; $i -lt $ux.Count; $i++) { if (($tw2 - ($ux[$i] - $ux[$i - 1])) -lt 64) { $ovlOk = $false } }
  $uy = @($pl2.Tiles | ForEach-Object { $_.Y } | Sort-Object -Unique)
  for ($i = 1; $i -lt $uy.Count; $i++) { if (($th2 - ($uy[$i] - $uy[$i - 1])) -lt 64) { $ovlOk = $false } }
  ST-Check 'tileplan: adjacent tiles overlap at least the requested 64px' $ovlOk
  # "any (w,h,scale,maxDim)" broadened: independent union math over several
  # shapes, plus per-tile size and per-adjacent-pair overlap on each of them.
  $plShapes = @(
    @(2482, 1514, 2.0, 10000, 64, 16),
    @(6000, 3000, 2.0, 10000, 64, 16),
    @(9000, 2000, 1.0, 10000, 64, 16),
    @(300, 300, 2.0, 4096, 64, 16),
    @(6100, 1700, 2.0, 10000, 64, 16)
  )
  $shapeOk = $true
  foreach ($cs in $plShapes) {
    $ps2 = Get-OcrTilePlan $cs[0] $cs[1] $cs[2] $cs[3] $cs[4] $cs[5]
    if ($ps2.Error) { $shapeOk = $false; continue }
    $tw2s = $ps2.Tiles[0].W; $th2s = $ps2.Tiles[0].H
    $sxs = @($ps2.Tiles | ForEach-Object { $_.X } | Sort-Object -Unique)
    $sys = @($ps2.Tiles | ForEach-Object { $_.Y } | Sort-Object -Unique)
    $cxs = ($sxs[0] -eq 0) -and (($sxs[$sxs.Count - 1] + $tw2s) -ge $cs[0])
    for ($k = 1; $k -lt $sxs.Count; $k++) { if (($sxs[$k] - $sxs[$k - 1]) -gt $tw2s) { $cxs = $false } }
    $cys = ($sys[0] -eq 0) -and (($sys[$sys.Count - 1] + $th2s) -ge $cs[1])
    for ($k = 1; $k -lt $sys.Count; $k++) { if (($sys[$k] - $sys[$k - 1]) -gt $th2s) { $cys = $false } }
    $ovS = $true
    for ($k = 1; $k -lt $sxs.Count; $k++) { if (($sxs[$k] - $sxs[$k - 1]) -gt ($tw2s - $cs[4])) { $ovS = $false } }
    for ($k = 1; $k -lt $sys.Count; $k++) { if (($sys[$k] - $sys[$k - 1]) -gt ($th2s - $cs[4])) { $ovS = $false } }
    $szS = $true
    foreach ($t2 in $ps2.Tiles) { if (($t2.W * $cs[2]) -gt $cs[3] -or ($t2.H * $cs[2]) -gt $cs[3]) { $szS = $false } }
    if (-not ($cxs -and $cys -and $ps2.Covered -and $ovS -and $szS)) { $shapeOk = $false }
  }
  ST-Check 'tileplan: coverage + size + overlap hold across shapes (independent union math)' $shapeOk
  $plX = Get-OcrTilePlan 6000 3000 2.0 10000 64 1
  ST-Check 'tileplan: over max-tiles refuses with the real count in Error' ($plX.Error -match 'needs \d+ tiles' -and $plX.Tiles.Count -eq 0)
  $plR = Get-OcrTilePlan 6000 3000 2.0 10000 64 16
  $plS = Get-OcrTilePlan 6000 3000 2.0 10000 64 16
  $det = ($plR.Count -eq $plS.Count)
  if ($det) { for ($i = 0; $i -lt $plR.Tiles.Count; $i++) { if ($plR.Tiles[$i].X -ne $plS.Tiles[$i].X -or $plR.Tiles[$i].Y -ne $plS.Tiles[$i].Y -or $plR.Tiles[$i].W -ne $plS.Tiles[$i].W -or $plR.Tiles[$i].H -ne $plS.Tiles[$i].H) { $det = $false } } }
  ST-Check 'tileplan: same args -> identical row-major order (index reproducible)' ($det -and $plR.Covered)
  $mk = { param($t, $x, $y) [pscustomobject]@{ Text = $t; X = $x; Y = $y; W = 100; H = 14 } }
  $tileA = @(& $mk 'SAME LINE' 100 200; & $mk 'OTHER' 10 20)
  $tileB = @(& $mk 'SAME LINE' 102 201)
  $tileC = @(& $mk 'SAME LINE' 110 200)
  $mrg = Merge-OcrTileLines @($tileA, $tileB, $tileC)
  ST-Check 'merge: 2px-overlap duplicate collapses, 10px distinct stays' ($mrg.Lines.Count -eq 3 -and $mrg.Duplicates -eq 1)

  # ---------- unit + lint: v2.2.0 plan doc section 3, the folded-long-payload receipt ----------
  # The judgement table. Each case feeds numbers of the same shape the IO pair produces, so
  # the RULE is provable offline; the IO pair itself is proven live by the fold fixture.
  $pvV = @{ VerbatimOk = $true; Threshold = 200; HeightMin = 8; PayloadChars = 12000; UiaBefore = 14; UiaAfter = 14; HeightBefore = 240; HeightAfter = 240; LinesBefore = 5; LinesAfter = 5; HashBefore = 'aaaa1111'; HashAfter = 'aaaa1111' }
  $pvOk = Get-PasteReceiptVerdict $pvV
  # The knob's DEFAULT is pinned too, and the boundary is measured against the shipped value
  # rather than a number copied into the test: a threshold nobody reads can be quietly set to
  # "never" and every other case in the table keeps passing.
  $pvThr = [int](Get-PasteFoldThreshold)
  $pvAt = Get-PasteReceiptVerdict @{ VerbatimOk = $false; Threshold = $pvThr; HeightMin = (Get-PasteReceiptHeightMin); PayloadChars = $pvThr; UiaBefore = 14; UiaAfter = 15; HeightBefore = 240; HeightAfter = 240; LinesBefore = 5; LinesAfter = 5; HashBefore = 'aaaa1111'; HashAfter = 'aaaa1111' }
  $pvUnder = Get-PasteReceiptVerdict @{ VerbatimOk = $false; Threshold = $pvThr; HeightMin = (Get-PasteReceiptHeightMin); PayloadChars = ($pvThr - 1); UiaBefore = 14; UiaAfter = 15; HeightBefore = 240; HeightAfter = 240; LinesBefore = 5; LinesAfter = 5; HashBefore = 'aaaa1111'; HashAfter = 'aaaa1111' }
  ST-Check 'unit: the shipped fold-threshold is one specific spoken number (200) - a default no check reads can be set to "never" while the whole table stays green' (
    ($pvThr -eq 200) -and ([int](Get-PasteReceiptHeightMin) -eq 8))
  ST-Check 'unit: a payload AT the fold-threshold engages the receipt route and one char under it does not (the boundary is the knob, measured against the shipped value)' (
    $pvAt.Ok -and (-not $pvUnder.Ok) -and $pvUnder.Detail.Contains('under fold-threshold'))
  ST-Check 'unit: paste receipt - a verbatim read-back wins outright and is never labelled a degradation' (
    $pvOk.Ok -and (-not $pvOk.Degraded) -and ($pvOk.Criterion -ceq 'verbatim-tail'))
  $pvShort = Get-PasteReceiptVerdict @{ VerbatimOk = $false; Threshold = 200; HeightMin = 8; PayloadChars = 60; UiaBefore = 14; UiaAfter = 99; HeightBefore = 240; HeightAfter = 900; LinesBefore = 1; LinesAfter = 9; HashBefore = 'aaaa1111'; HashAfter = 'bbbb2222' }
  ST-Check 'unit: paste receipt - a SHORT payload whose body is not visible stays a failure even if the window threw a fit (a weak receipt must not excuse a small paste)' (
    (-not $pvShort.Ok) -and ($pvShort.Criterion -ceq 'verbatim-tail') -and $pvShort.Detail.Contains('under fold-threshold'))
  $pvKnob = Get-PasteReceiptVerdict @{ VerbatimOk = $false; Threshold = 0; HeightMin = 8; PayloadChars = 12000; UiaBefore = 14; UiaAfter = 99; HeightBefore = 240; HeightAfter = 900; LinesBefore = 1; LinesAfter = 9; HashBefore = 'aaaa1111'; HashAfter = 'bbbb2222' }
  ST-Check 'unit: paste receipt - fold-threshold=0 switches the receipt route off and NAMES the knob that did it (an inert knob is the fake-flag shape this repo has been bitten by)' (
    (-not $pvKnob.Ok) -and $pvKnob.Detail.Contains('fold-threshold=0'))
  $pvNodes = Get-PasteReceiptVerdict @{ VerbatimOk = $false; Threshold = 200; HeightMin = 8; PayloadChars = 8556; UiaBefore = 14; UiaAfter = 15; HeightBefore = 240; HeightAfter = 240; LinesBefore = 5; LinesAfter = 5; HashBefore = 'aaaa1111'; HashAfter = 'aaaa1111' }
  ST-Check 'unit: paste receipt - one NEW ui automation node is enough on a long payload, and it is reported as the degraded criterion with the numbers it measured' (
    $pvNodes.Ok -and $pvNodes.Degraded -and ($pvNodes.Criterion -ceq 'uia-nodes') -and $pvNodes.Detail.Contains('nodes 14->15'))
  $pvGrow = Get-PasteReceiptVerdict @{ VerbatimOk = $false; Threshold = 200; HeightMin = 8; PayloadChars = 12774; UiaBefore = -1; UiaAfter = -1; HeightBefore = 240; HeightAfter = 260; LinesBefore = 5; LinesAfter = 5; HashBefore = 'aaaa1111'; HashAfter = 'bbbb2222' }
  ST-Check 'unit: paste receipt - ui automation unreadable (both sides -1) still leaves the height leg, which must quote before and after' (
    $pvGrow.Ok -and ($pvGrow.Criterion -ceq 'grow-height') -and $pvGrow.Detail.Contains('h 240->260'))
  $pvTiny = Get-PasteReceiptVerdict @{ VerbatimOk = $false; Threshold = 200; HeightMin = 8; PayloadChars = 12774; UiaBefore = 14; UiaAfter = 14; HeightBefore = 240; HeightAfter = 244; LinesBefore = 5; LinesAfter = 5; HashBefore = 'aaaa1111'; HashAfter = 'aaaa1111' }
  ST-Check 'unit: paste receipt - a 4px growth under the floor does NOT count as a receipt (a drifting rect must not be enough to pass)' (
    (-not $pvTiny.Ok) -and ($pvTiny.Criterion -ceq 'none-of-three'))
  $pvLines = Get-PasteReceiptVerdict @{ VerbatimOk = $false; Threshold = 200; HeightMin = 8; PayloadChars = 12774; UiaBefore = 14; UiaAfter = 14; HeightBefore = 240; HeightAfter = 240; LinesBefore = 5; LinesAfter = 3; HashBefore = 'aaaa1111'; HashAfter = 'bbbb2222' }
  ST-Check 'unit: paste receipt - line count changed WITH a different pixel hash counts as content arriving (the chip replacing the body is exactly this shape)' (
    $pvLines.Ok -and ($pvLines.Criterion -ceq 'lines-changed') -and $pvLines.Detail.Contains('lines 5->3'))
  $pvPixel = Get-PasteReceiptVerdict @{ VerbatimOk = $false; Threshold = 200; HeightMin = 8; PayloadChars = 12774; UiaBefore = 14; UiaAfter = 14; HeightBefore = 240; HeightAfter = 240; LinesBefore = 5; LinesAfter = 5; HashBefore = 'aaaa1111'; HashAfter = 'bbbb2222' }
  ST-Check 'unit: paste receipt - pixels moving alone is NOT a receipt (a blinking caret would otherwise pass every paste ever made)' (
    (-not $pvPixel.Ok) -and ($pvPixel.Criterion -ceq 'none-of-three'))
  $pvNone = Get-PasteReceiptVerdict @{ VerbatimOk = $false; Threshold = 200; HeightMin = 8; PayloadChars = 12774; UiaBefore = 14; UiaAfter = 14; HeightBefore = 240; HeightAfter = 240; LinesBefore = 5; LinesAfter = 5; HashBefore = 'aaaa1111'; HashAfter = 'aaaa1111' }
  ST-Check 'unit: paste receipt - refusing names ALL THREE legs with what each one measured (a bare not-visible leaves the caller guessing whether the receipt route even ran)' (
    (-not $pvNone.Ok) -and $pvNone.Detail.Contains('nodes 14->14') -and $pvNone.Detail.Contains('h 240->240') -and $pvNone.Detail.Contains('lines 5->5'))
  # ---------- unit: v1.5.9/P-4b sparse-read hint - dual area bands, wording, synthetic pair, wiring ----------
  # C-plan: area >= 300000 px2 remains the floor; a small-area region (<500000 px2)
  # uses the relaxed 1.0 threshold while a large region uses 1.5. Both sides of
  # every boundary are asserted - a threshold with only a positive case has no teeth.
  ST-Check 'unit: sparse predicate fires on a large near-empty region (2000x1200, 0 lines)' (Test-SparseReadability 2000 1200 0 1.5)
  ST-Check 'unit: sparse predicate stays quiet on the same region densely read (60 lines)' (-not (Test-SparseReadability 2000 1200 60 1.5))
  ST-Check 'unit: sparse predicate never fires below the 300k px2 area floor (500x300, 0 lines)' (-not (Test-SparseReadability 500 300 0 1.5))
  ST-Check 'unit: sparse predicate 0 disables the hint entirely (huge region, 0 lines)' (-not (Test-SparseReadability 2000 1200 0 0))
  ST-Check 'unit: sparse predicate threshold is a strict less-than (exactly 1.5 lines/100k px2 stays quiet, one line less fires)' (
    (-not (Test-SparseReadability 2000 1200 36 1.5)) -and (Test-SparseReadability 2000 1200 35 1.5))
  ST-Check 'unit: sparse predicate relaxes the small-area band for a legal sparse dialog (749x540, 5 lines)' (-not (Test-SparseReadability 749 540 5 1.5))
  ST-Check 'unit: sparse predicate still warns on a truly masked large region (2000x1200, 2 lines)' (Test-SparseReadability 2000 1200 2 1.5)
  ST-Check 'unit: sparse predicate small-area band has a live boundary (749x540, 4 lines warns)' (Test-SparseReadability 749 540 4 1.5)
  # v2.9.0: read-text's OWN loud threshold moved from the band to the near-zero rule, because
  # the 489-capture survey showed 1.5 cuts through the mode of ordinary traffic (214 quiet reads
  # sit in [1.5,2.0) alone; 91 of 489 = 18.6% shouted) while every genuine failure shape sits far
  # lower. Both directions here, on the two shapes the survey actually produced - and the second
  # one asserts the OLD value too, so "quiet" cannot be explained by a broken predicate.
  ST-Check 'unit: the modal-scrim shape (2 lines on 1722x1597 = density 0.07) still shouts at the new 0.1 default' (
    (Test-SparseReadability 1722 1597 2 0.1))
  ST-Check 'unit: an ordinary sparse window (40 lines on 1722x1597 = density 1.45) is quiet at 0.1 and was NOT quiet at 1.5' (
    (-not (Test-SparseReadability 1722 1597 40 0.1)) -and (Test-SparseReadability 1722 1597 40 1.5))
  ST-Check 'unit: the small-area cap cannot lift a lowered threshold (0.1 on a 749x540 dialog warns only below 0.1)' (
    (Get-SparseReadPolicy ([long]749 * 540) 0.1).Threshold -eq 0.1 -and (-not (Test-SparseReadability 749 540 5 0.1)))
  # and the split itself must be visible in the source: exactly ONE command lowered its default.
  $mldLow = @($codeLines | Where-Object { $_ -match '\$minLineDensity = 0\.1\s*$' }).Count
  $mldBand = @($codeLines | Where-Object { $_ -match '\$minLineDensity = 1\.5\s*$' }).Count
  ST-Check 'lint: read-text alone dropped to the near-zero default; the two absence-claiming paths keep the band' (
    ($mldLow -eq 1) -and ($mldBand -eq 2))
  # the readability label must reach BOTH headers (file mode and screen mode) and be produced in
  # exactly one place, or one mode silently stops reporting its own quality. The token is
  # assembled at runtime: this scan line would otherwise match its own search string and the
  # count would be off by one forever (same self-evasion idiom as the badge lint).
  $rlTok = 'read' + 'Label'
  $rlSites = @($codeLines | Where-Object { $_.Contains($rlTok) -and $_ -notmatch '^\s*#' }).Count
  ST-Check 'lint: the readability label has one producer and reaches both read-text headers' ($rlSites -eq 4)
  if ($rlSites -ne 4) { Write-Output "      readability label sites: $rlSites (want 4: init + build + 2 headers)" }
  $srw = Build-SparseReadWarn 2482 1514 2 1.5
  ST-Check 'unit: sparse WARN wording names the size, the count, the modal/scrim suspicion and the escape hatch' (
    $srw.Contains('WARN: region is 2482x1514 but only 2 line(s) read') -and
    $srw.Contains('in-window modal/scrim, a loading veil, or a very low-contrast theme') -and
    $srw.Contains('Do NOT treat "not found" as "absent"') -and
    $srw.Contains('sparse-policy=large-area') -and $srw.Contains('active-threshold=1.5') -and
    $srw.Contains('min-line-density=1.5') -and $srw.Contains('--min-line-density 0 to silence'))
  # v2.8.0: the SAME producer must speak two dialects, because a file-mode read is not a
  # window. Both directions are asserted: a one-sided check ("says image") would also pass
  # if the word region simply vanished from the sentence.
  $srwImg = Build-SparseReadWarn 2482 1514 2 1.5 'image'
  ST-Check 'unit: the sparse WARN calls a stored capture an image and offers the subdivided re-read' (
    $srwImg.Contains('WARN: image is 2482x1514 but only 2 line(s) read') -and
    (-not $srwImg.Contains('region')) -and
    (-not $srwImg.Contains('window')) -and
    $srwImg.Contains('mostly graphics') -and
    $srwImg.Contains('--scale tiled') -and
    $srwImg.Contains('Do NOT treat "not found" as "absent"') -and
    $srwImg.Contains('sparse-policy=large-area'))
  ST-Check 'unit: the default subject still speaks screen mode (region + window wording intact)' (
    $srw.Contains('WARN: region is 2482x1514') -and (-not $srw.Contains('WARN: image is')))

  # v2.8.0: the engine's own dimension limit (10000 measured on this box) sits far above any
  # screenshot, so the live road's "tile only when too big" rule yields ONE tile for a stored
  # image and the flag would be decorative. The override has to actually subdivide - and it
  # must never be able to RAISE the limit, or a tile would exceed what the engine accepts.
  $gtmSmall = Get-OcrTilePlan 920 520 2.0 10000 64 16
  $gtmCut = Get-OcrTilePlan 920 520 2.0 (Get-FileTileMaxDim 920 520 2.0) 64 16
  ST-Check 'unit: file tiling halves the long side so one capture becomes several reads (real limit gives 1)' (
    ($gtmSmall.Count -eq 1) -and ($gtmCut.Count -ge 2) -and (-not $gtmSmall.Error) -and (-not $gtmCut.Error))
  $gtmWide = Get-FileTileMaxDim 400 3000 2.0
  $gtmWidePlan = Get-OcrTilePlan 400 3000 2.0 $gtmWide 64 64
  $gtmOver = @($gtmWidePlan.Tiles | Where-Object { ($_.W * 2) -gt 10000 -or ($_.H * 2) -gt 10000 })
  ST-Check 'unit: file tiling cuts the LONGER side and never asks for a tile above the engine limit' (
    ($gtmWide -eq 3000) -and ((Get-FileTileMaxDim 0 0 0) -ge 32) -and
    (-not $gtmWidePlan.Error) -and (@($gtmWidePlan.Tiles).Count -ge 2) -and (@($gtmOver).Count -eq 0))
  # v2.8.1: the empty-read floor is its own producer, and the boundary must be the one the
  # measurement asked for. 1040x220 = 228,800 px2 is the REAL capture that v2.8.0's retry
  # skipped because it borrowed the WARN band - it must be inside the new floor, and a chip
  # small enough that "no text" is the honest answer must stay outside.
  ST-Check 'unit: empty-read predicate fires on the 228,800 px2 capture the WARN band is above, and stays off a 100x100 chip' (
    (Test-EmptyReadSuspect 1040 220) -and (Get-EmptyReadAreaFloor -eq 30000) -and
    (-not (Test-EmptyReadSuspect 100 100)) -and (Test-EmptyReadSuspect 173 174))
  $qrA = Get-QuadrantRects 920 520 64
  $qrOdd = Get-QuadrantRects 1001 77 64
  $qrBad = @()
  foreach ($r in @($qrA.Rects + $qrOdd.Rects)) {
    if ($r.X -lt 0 -or $r.Y -lt 0 -or $r.Width -lt 1 -or $r.Height -lt 1) { $qrBad += 'shape' }
  }
  ST-Check 'unit: quadrant crops cover the image, stay inside it, and overlap on the inner edges' (
    ($qrA.Count -eq 4) -and (@($qrBad).Count -eq 0) -and
    (@($qrA.Rects | Where-Object { ($_.X + $_.Width) -le 920 -and ($_.Y + $_.Height) -le 520 }).Count -eq 4) -and
    ((@($qrA.Rects | Where-Object { $_.X -gt 0 })[0]).X -eq (460 - 64)) -and
    ($qrOdd.Count -eq 4) -and ((@($qrOdd.Rects | Where-Object { $_.Y -eq 0 }).Count) -eq 2) -and
    ((Get-QuadrantRects 0 0 0).Error -ne ''))
  # the overlap must never be able to produce a zero-width crop on a narrow image
  $qrThin = Get-QuadrantRects 300 20 64
  ST-Check 'unit: a crop overlap larger than the image is clamped, not turned into a zero-width tile' (
    ($qrThin.Count -eq 4) -and (@($qrThin.Rects | Where-Object { $_.Width -lt 1 -or $_.Height -lt 1 }).Count -eq 0))

  # Synthetic-bitmap two-state pair (the task order's acceptance). Memory-only canvases:
  # no window is created and no screen is captured, so the pair runs in the OFFLINE gate.
  # v4.1.3 (external review B): "catch-guarded" used to mean the caught error was fed to the
  # assertion as a FAIL condition, so an engine that cannot reach the recognizer reported a
  # product failure for a missing capability - against the contract this file states at the
  # read-text --file check ("On a box with no OCR language pack it SKIPS with a reason").
  # The pair is now gated on the same probe the live family uses, and the region accounts
  # for itself by name, so the total cannot move between machines.
  $script:StRecord = New-Object System.Collections.ArrayList
  if ($ocrPackTag -eq '') {
    ST-SkipRegion 'ocr-synthetic' 'no OCR language pack / recognizer unreachable from this engine - the bitmap road cannot be measured, so this is not a regression'
  } else {
  # REGION-BEGIN ocr-synthetic
  $srGrayErr = ''
  $srGray = New-Object System.Drawing.Bitmap(2000, 1200)
  $sgGray = [System.Drawing.Graphics]::FromImage($srGray)
  $sgGray.Clear([System.Drawing.Color]::FromArgb(128, 128, 128))
  $sgGray.Dispose()
  $srGrayLines = @()
  try { $srGrayLines = @((Invoke-OcrBitmap $srGray).Lines) } catch { $srGrayErr = $_.Exception.Message }
  ST-Check 'unit: synthetic 2000x1200 pure-gray bitmap OCRs to 0 lines and trips the sparse predicate' (
    (-not $srGrayErr) -and @($srGrayLines).Count -eq 0 -and (Test-SparseReadability 2000 1200 @($srGrayLines).Count 1.5))
  if ($srGrayErr) { Write-Output "      OCR unavailable: $srGrayErr" }
  $srDenseErr = ''
  $srDense = New-Object System.Drawing.Bitmap(2000, 1200)
  $sgDense = [System.Drawing.Graphics]::FromImage($srDense)
  $sgDense.Clear([System.Drawing.Color]::White)
  $fntD = New-Object System.Drawing.Font('Consolas', 10, [System.Drawing.FontStyle]::Regular)
  $brsD = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
  for ($sd = 0; $sd -lt 60; $sd++) { $sgDense.DrawString("DTX dense readability row $sd of 60", $fntD, $brsD, [single]10, [single](8 + $sd * 19)) }
  $sgDense.Dispose(); $fntD.Dispose(); $brsD.Dispose()
  $srDenseLines = @()
  try { $srDenseLines = @((Invoke-OcrBitmap $srDense).Lines) } catch { $srDenseErr = $_.Exception.Message }
  ST-Check 'unit: synthetic 2000x1200 60-row bitmap reads dense enough to stay quiet (measured, not assumed)' (
    (-not $srDenseErr) -and @($srDenseLines).Count -ge 36 -and (-not (Test-SparseReadability 2000 1200 @($srDenseLines).Count 1.5)))
  if ($srDenseErr) { Write-Output "      OCR unavailable: $srDenseErr" }
  Write-Output "      synthetic sparse pair: gray=$(@($srGrayLines).Count) line(s), dense=$(@($srDenseLines).Count) line(s) (density $([math]::Round(@($srDenseLines).Count / 24.0, 2)) lines per 100k px2, threshold 1.5)"
  $srGray.Dispose(); $srDense.Dispose()
  # REGION-END ocr-synthetic
  }
  $ocrSynEmitted = @($script:StRecord)
  $script:StRecord = $null
  ST-ReconcileRegion 'ocr-synthetic' $ocrSynEmitted

  # Wiring: the hint must stay attached to all negative paths, the wording must
  # keep its single producer, and the tuning flag must stay reachable everywhere it is
  # documented (Split-Target + both read commands). v1.10.0 adds the 4th consumer: the
  # challenge-probe none-path note (the task order names it as P-4's existing behaviour
  # carried over), so the pinned count moves 4 -> 5.
  # v2.8.0 moved 5 -> 6: the file-mode auto-retry consulted THIS predicate rather than
  # inventing a second area floor. v2.8.1 moves it back 6 -> 5, and the reason is a
  # measurement, not a tidy-up: re-running the two real captures that motivated the retry
  # showed that retry recovered NEITHER, and the 1040x220 one (228,800 px2) never even
  # reached it, because the WARN band's 300k floor sits ABOVE that image. An EMPTY read is
  # suspicious at a far smaller size than a SPARSE one, so emptiness now has its own
  # producer (Get-EmptyReadAreaFloor, pinned by name and value in its own unit check).
  # This lint going DOWN therefore means the two rules were SPLIT, not that a negative path
  # lost its hint - the five sites below are the same five that carried it before v2.8.0.
  $srSites = @()
  for ($sri = 0; $sri -lt $codeLines.Count; $sri++) {
    if ($sri -ge $j5ProdStart -and $sri -lt $j5ProdEnd) { continue }
    if ($codeLines[$sri] -match '^\s*#') { continue }
    if ($codeLines[$sri].Contains('Test-SparseReadability')) { $srSites += ($sri + 1) }
  }
  ST-Check 'lint: the sparse predicate is wired on all negative paths (exactly 5 sites: 1 def + read-text + find-text + expect + challenge-probe)' (@($srSites).Count -eq 5)
  if (@($srSites).Count -ne 5) { Write-Output "      sparse predicate sites: $(@($srSites) -join ', ')" }
  # and the empty-read rule must have exactly one floor producer too, so a second literal
  # cannot quietly appear somewhere else and disagree with the one the report prints.
  $erSites = @()
  for ($sri = 0; $sri -lt $codeLines.Count; $sri++) {
    if ($sri -ge $j5ProdStart -and $sri -lt $j5ProdEnd) { continue }
    if ($codeLines[$sri] -match '^\s*#') { continue }
    if ($codeLines[$sri].Contains('Get-EmptyReadAreaFloor')) { $erSites += ($sri + 1) }
  }
  ST-Check 'lint: the empty-read floor has one producer and two named consumers (def + predicate + header)' (@($erSites).Count -eq 3)
  if (@($erSites).Count -ne 3) { Write-Output "      empty-read floor sites: $(@($erSites) -join ', ')" }
  $srBuildSites = @()
  for ($sri = 0; $sri -lt $codeLines.Count; $sri++) {
    if ($sri -ge $j5ProdStart -and $sri -lt $j5ProdEnd) { continue }
    if ($codeLines[$sri] -match '^\s*#') { continue }
    if ($codeLines[$sri].Contains('Build-SparseReadWarn')) { $srBuildSites += ($sri + 1) }
  }
  ST-Check 'lint: the sparse WARN has one producer and three consumers (exactly 4 sites)' (@($srBuildSites).Count -eq 4)
  if (@($srBuildSites).Count -ne 4) { Write-Output "      sparse WARN sites: $(@($srBuildSites) -join ', ')" }
  $srFlagSites = @()
  for ($sri = 0; $sri -lt $codeLines.Count; $sri++) {
    if ($sri -ge $j5ProdStart -and $sri -lt $j5ProdEnd) { continue }
    if ($codeLines[$sri] -match '^\s*#') { continue }
    if ($codeLines[$sri].Contains("-eq '--min-line-density'")) { $srFlagSites += ($sri + 1) }
  }
  ST-Check 'lint: --min-line-density is parsed by Split-Target AND both read commands (exactly 3 sites)' (@($srFlagSites).Count -eq 3)
  if (@($srFlagSites).Count -ne 3) { Write-Output "      min-line-density parse sites: $(Format-SourceLineList @($srFlagSites))" }

  # ---------- unit: v1.5.9 P-2 needle sub-span aiming - pure mapping + synthetic line ----------
  # Pure mapping units first: the CJK case reproduces the real incident (two tabs OCR'd
  # as one line; the needle is the left tab), the Latin case pins the proportional math.
  $gaCjk = Get-NeedleAimX ([string]::Join(' ', @([char]0x6267, [char]0x884C, [char]0x5386, [char]0x53F2, [char]0x4EFB, [char]0x52A1, [char]0x6A21, [char]0x677F))) 100 800 ([string]::Join('', @([char]0x6267, [char]0x884C, [char]0x5386, [char]0x53F2)))
  ST-Check 'unit: needle aim maps the CJK needle onto its own sub-span (the two-tab incident: left tab, not the gap)' (
    $gaCjk.Matched -and $gaCjk.AimX -eq 300 -and $gaCjk.SpanStart -eq 0 -and $gaCjk.SpanEnd -eq 4 -and $gaCjk.NormLen -eq 8)
  $gaLat = Get-NeedleAimX 'AAA BBB' 0 700 'BBB'
  ST-Check 'unit: needle aim maps a Latin needle proportionally (BBB span 4-7 of 7 -> centre 550)' (
    $gaLat.Matched -and $gaLat.AimX -eq 550 -and $gaLat.SpanStart -eq 4 -and $gaLat.SpanEnd -eq 7)
  ST-Check 'unit: needle aim matches case-insensitively' ((Get-NeedleAimX 'AAA BBB' 0 700 'aaa').Matched)
  $gaMiss = Get-NeedleAimX 'AAA BBB' 0 700 'ZZZ'
  ST-Check 'unit: needle aim reports a miss and hands back the line centre (honest fallback)' (
    (-not $gaMiss.Matched) -and $gaMiss.AimX -eq 350 -and ((Get-NeedleAimX 'AAA BBB' 0 700 '').Matched -eq $false))

  # Synthetic merged-line pair (the task order's acceptance, one deviation documented in
  # the iteration log): the task order sketched two drawn blocks "AAA" / "BBB", but the
  # engine reads Latin letter runs with NON-deterministic inserted spaces ('AAAB BB' vs
  # 'AAA BBB' on identical bitmaps - measured while building this unit), so a Latin
  # needle's contiguity - and therefore its aim - would flake. The row is therefore drawn
  # as ONE string with an ideographic-space gap (U+3000): CJK inter-glyph spaces are
  # folded by Normalize-OcrText BY DESIGN, so both needles always match after
  # normalization, whatever the engine inserts. Assertions are stated on the READ rect
  # and hold for either normalization length (6 = gap folded, 7 = gap kept as a char):
  # the row merges into ONE OCR line (the incident shape), the hit count stays 1
  # (J-05 granularity), each needle's aim moves to its own side of the line centre by at
  # least 1/7 of the line width - i.e. the OLD line-centre behaviour clicked a materially
  # different, wrong point - and the needle/line ratio stays in NOTE territory.
  # v4.1.3 (external review B): gated like the synthetic pair above - and the three checks
  # nested under the merged-line precondition now report SKIP when it does not hold,
  # instead of vanishing (measured: pwsh 7 lost exactly those three on top of the pair).
  $script:StRecord = New-Object System.Collections.ArrayList
  if ($ocrPackTag -eq '') {
    ST-SkipRegion 'ocr-merged' 'no OCR language pack / recognizer unreachable from this engine - the merged-line shape cannot be measured, so this is not a regression'
  } else {
  # REGION-BEGIN ocr-merged
  $gaBmp = New-Object System.Drawing.Bitmap(460, 100)
  $gaG = [System.Drawing.Graphics]::FromImage($gaBmp)
  $gaG.Clear([System.Drawing.Color]::White)
  $gaFnt = New-Object System.Drawing.Font('Microsoft YaHei UI', 24, [System.Drawing.FontStyle]::Regular)
  $gaBrs = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
  $gaL = [string]::Join('', @([char]0x6728, [char]0x6C34, [char]0x706B))
  $gaR = [string]::Join('', @([char]0x571F, [char]0x91D1, [char]0x7530))
  $gaRow = $gaL + [string][char]0x3000 + $gaR
  $gaG.DrawString($gaRow, $gaFnt, $gaBrs, [single]40, [single]25)
  $gaG.Dispose(); $gaFnt.Dispose(); $gaBrs.Dispose()
  $gaErr = ''
  $gaLines = @()
  try { $gaLines = @((Invoke-OcrBitmap $gaBmp).Lines) } catch { $gaErr = $_.Exception.Message }
  $gaMerged = @($gaLines | Where-Object { (($_.Text -replace '\s', '') -replace [string][char]0x3000, '') -like ('*' + $gaL + $gaR + '*') })
  ST-Check 'unit: synthetic two-block CJK row OCRs as ONE merged line (the incident shape, engine-verified)' (
    (-not $gaErr) -and @($gaMerged).Count -eq 1)
  if ($gaErr) { Write-Output "      OCR unavailable: $gaErr" }
  if (@($gaMerged).Count -ne 1) { Write-Output ("      merged-line diagnostics: " + ((@($gaLines | ForEach-Object { "'" + $_.Text + "'@" + $_.X + "+" + $_.W })) -join ' | ')) }
  if (@($gaMerged).Count -eq 1) {
    $gaHit = $gaMerged[0]
    $gaHitsL = Find-OcrHits @($gaLines) $gaL
    ST-Check 'unit: the merged row is still exactly ONE hit for the left needle (J-05 line granularity intact)' (@($gaHitsL).Count -eq 1)
    $gaAimL = Get-NeedleAimX "$($gaHit.Text)" $gaHit.X $gaHit.W $gaL
    $gaAimR = Get-NeedleAimX "$($gaHit.Text)" $gaHit.X $gaHit.W $gaR
    $gaCentre = $gaHit.X + [int]($gaHit.W / 2)
    $gaW7 = [int]($gaHit.W / 7)
    ST-Check 'unit: both needles aim into their own half, each at least 1/7 line-width away from the old line-centre point' (
      $gaAimL.Matched -and $gaAimR.Matched -and ($gaAimL.AimX -lt $gaCentre) -and ($gaCentre -lt $gaAimR.AimX) -and
      (($gaCentre - $gaAimL.AimX) -gt $gaW7) -and (($gaAimR.AimX - $gaCentre) -gt $gaW7))
    ST-Check 'unit: the merged line is much wider than either needle, so the wider-than-needle NOTE condition holds' (
      ((($gaAimL.SpanEnd - $gaAimL.SpanStart) / $gaAimL.NormLen) -le 0.6) -and
      ((($gaAimR.SpanEnd - $gaAimR.SpanStart) / $gaAimR.NormLen) -le 0.6))
    Write-Output "      synthetic aim pair: line rect=($($gaHit.X),$($gaHit.Y),$($gaHit.W)x$($gaHit.H)) text='$($gaHit.Text)' normLen=$($gaAimL.NormLen) aimL=$($gaAimL.AimX) aimR=$($gaAimR.AimX) lineCentre=$gaCentre"
  } else {
    # v4.1.3 (external review B): these three sat behind a precondition and used to be
    # skipped from EXISTING when it did not hold - the run got shorter instead of narrower,
    # and that is where a third of the missing 24 went. They now account for themselves.
    ST-Skip 'unit: the merged row is still exactly ONE hit for the left needle (J-05 line granularity intact)' 'the merged-line precondition did not hold - there is no single line to aim at'
    ST-Skip 'unit: both needles aim into their own half, each at least 1/7 line-width away from the old line-centre point' 'the merged-line precondition did not hold - there is no single line to aim at'
    ST-Skip 'unit: the merged line is much wider than either needle, so the wider-than-needle NOTE condition holds' 'the merged-line precondition did not hold - there is no single line to aim at'
  }
  $gaBmp.Dispose()
  # REGION-END ocr-merged
  }
  $ocrMergedEmitted = @($script:StRecord)
  $script:StRecord = $null
  ST-ReconcileRegion 'ocr-merged' $ocrMergedEmitted

  $aimSites = @()
  for ($gai = 0; $gai -lt $codeLines.Count; $gai++) {
    if ($gai -ge $j5ProdStart -and $gai -lt $j5ProdEnd) { continue }
    if ($codeLines[$gai] -match '^\s*#') { continue }
    if ($codeLines[$gai].Contains('Get-NeedleAimX')) { $aimSites += ($gai + 1) }
  }
  ST-Check 'lint: find-click wires the needle sub-span aiming (exactly 2 sites: 1 def + 1 call)' (@($aimSites).Count -eq 2)
  if (@($aimSites).Count -ne 2) { Write-Output "      needle aim sites: $(@($aimSites) -join ', ')" }
  $aimFlagSites = @()
  for ($gai = 0; $gai -lt $codeLines.Count; $gai++) {
    if ($gai -ge $j5ProdStart -and $gai -lt $j5ProdEnd) { continue }
    if ($codeLines[$gai] -match '^\s*#') { continue }
    if ($codeLines[$gai].Contains('--aim-line')) { $aimFlagSites += ($gai + 1) }
  }
  ST-Check 'lint: --aim-line has its table entry, handler read, usage flag and echo note (exactly 4 code sites; help text is the D-1 lint''s source, not this scan)' (@($aimFlagSites).Count -eq 4)
  if (@($aimFlagSites).Count -ne 4) { Write-Output "      aim-line sites: $(Format-SourceLineList @($aimFlagSites))" }

  # -------------------------------------------------------------------------
  # CU-OPS-COMPLETE-20261026-01 package F: the template matcher. tpl-find's scan
  # runs the compiled [TPL] loop (the PowerShell loop costs ~6ms/position, which
  # would make the advertised pixel bound unreachable), so the CRITICAL property
  # is that both implementations agree. A 40x30 synthetic canvas pins that by
  # brute force: every offset is tested in both, and the hit sets must be equal.
  # -------------------------------------------------------------------------
  Add-Type -AssemblyName System.Drawing
  $curFHay = New-Object System.Drawing.Bitmap(40, 30, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $curFTpl = New-Object System.Drawing.Bitmap(6, 4, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $curFG = [System.Drawing.Graphics]::FromImage($curFHay)
  try {
    $curFG.Clear([System.Drawing.Color]::White)
    $curFRed = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 200, 10, 10))
    $curFBlue = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 10, 10, 200))
    try {
      $curFG.FillRectangle($curFRed, 10, 8, 3, 2)
      $curFG.FillRectangle($curFBlue, 13, 8, 3, 2)
      $curFG.FillRectangle($curFBlue, 10, 10, 3, 2)
      $curFG.FillRectangle($curFRed, 13, 10, 3, 2)
    } finally { $curFRed.Dispose(); $curFBlue.Dispose() }
  } finally { $curFG.Dispose() }
  $curFG2 = [System.Drawing.Graphics]::FromImage($curFTpl)
  try {
    $curFG2.Clear([System.Drawing.Color]::White)
    $curFRed2 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 200, 10, 10))
    $curFBlue2 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 10, 10, 200))
    try {
      $curFG2.FillRectangle($curFRed2, 0, 0, 3, 2)
      $curFG2.FillRectangle($curFBlue2, 3, 0, 3, 2)
      $curFG2.FillRectangle($curFBlue2, 0, 2, 3, 2)
      $curFG2.FillRectangle($curFRed2, 3, 2, 3, 2)
    } finally { $curFRed2.Dispose(); $curFBlue2.Dispose() }
  } finally { $curFG2.Dispose() }
  $curFHayB = Get-Bitmap32Bytes $curFHay
  $curFTplB = Get-Bitmap32Bytes $curFTpl
  $curFAgree = $true
  $curFHitCount = 0
  $curFHitList = @()
  foreach ($curFTol in @(0, 12)) {
    $curFPos = [int64]0
    $curFOver = $false
    $curFCompiled = @([TPL]::Find($curFHayB.Bytes, $curFHayB.Stride, $curFHayB.W, $curFHayB.H, $curFTplB.Bytes, $curFTplB.Stride, $curFTplB.W, $curFTplB.H, $curFTol, 60000, [ref]$curFPos, [ref]$curFOver))
    $curFPosSet = @()
    for ($curFY = 0; $curFY -le ($curFHayB.H - $curFTplB.H); $curFY++) {
      for ($curFX = 0; $curFX -le ($curFHayB.W - $curFTplB.W); $curFX++) {
        if (Test-TemplateAt $curFHayB $curFTplB $curFX $curFY $curFTol) { $curFPosSet += ($curFX + $curFY * 1000) }
      }
    }
    $curFCompiledPacked = @($curFCompiled | ForEach-Object { [int]($_ -shr 32) + [int]($_ -band 0xFFFFFFFFL) * 1000 } | Sort-Object)
    $curFPosSet = @($curFPosSet | Sort-Object)
    if (($curFCompiledPacked -join ',') -cne ($curFPosSet -join ',')) { $curFAgree = $false }
    if ($curFTol -eq 0) {
      $curFHitCount = @($curFCompiledPacked).Count
      $curFHitList = @($curFCompiledPacked)
    }
    if ($curFOver -or $curFPos -lt 1) { $curFAgree = $false }
  }
  ST-Check 'unit (F-01): the compiled scanner and the PowerShell twin agree on EVERY offset (tolerance 0 and 12), so the fast path cannot drift from the pinned semantics' (
    $curFAgree)
  ST-Check 'unit (F-02): the planted 6x4 four-quadrant pattern is found exactly once, at its drawn offset (10,8)' (
    ($curFHitCount -eq 1) -and ($curFHitList -contains 8010))
  if (-not ($curFHitCount -eq 1 -and $curFHitList -contains 8010)) { Write-Output ('      F-02 hits: ' + ($curFHitList -join ', ')) }
  $curFTolEdgeA = Test-TemplateAt $curFHayB @{ Bytes = [byte[]]$curFTplB.Bytes.Clone(); Stride = $curFTplB.Stride; W = $curFTplB.W; H = $curFTplB.H } 10 8 0
  # one channel moved 12 away: tolerance 12 is inclusive, 11 is not
  $curFShift = Get-Bitmap32Bytes $curFTpl
  $curFShift.Bytes[0] = [byte]([math]::Min(255, [int]$curFShift.Bytes[0] + 12))
  $curFTolIn = Test-TemplateAt $curFHayB $curFShift 10 8 12
  $curFTolOut = Test-TemplateAt $curFHayB $curFShift 10 8 11
  ST-Check 'unit (F-03): the per-channel tolerance is INCLUSIVE (a 12-off channel passes at 12 and fails at 11)' (
    $curFTolEdgeA -and $curFTolIn -and (-not $curFTolOut))
  $curFHay.Dispose()
  $curFTpl.Dispose()

  # ---------- CU-OPS-464-REVIEW-20261028-01 (W-1a/W-1b): one budget, checked on EVERY exit ----------
  # The reviewer reproduced two holes against the real functions: a first-read HIT returned
  # before the budget check (1000ms request, answer at 1852ms, still reported "met"), and the
  # poll sleep always took the full interval (timeout 1s, interval 5000ms, real 5009ms). These
  # checks bind the FIX, not a rewritten copy: the REAL Find-OcrHitsScaled runs with only the
  # low-level OCR read stubbed, and the REAL wait-cond handler runs with only its read stubbed.
  # Stubs go through a Set-Item seam, not the ${function:...} table A-07 registers.
  $w1Names = @('Invoke-OcrRegion', 'Resolve-Window', 'Get-TargetRect', 'Find-OcrHitsScaled')
  $w1Orig = @{}
  foreach ($w1n in $w1Names) { $w1Orig[$w1n] = (Get-Item ("function:" + $w1n)).ScriptBlock }
  try {
    Set-Item -Path 'function:Invoke-OcrRegion' -Value { param($x, $y, $w, $h, $forceScale, $DeadlineMs)
      Start-Sleep -Milliseconds 1800
      return ,@([pscustomobject]@{ Text = 'W1NEEDLE'; X = 0; Y = 0; W = 10; H = 10 }) }
    $w1LateHit = Find-OcrHitsScaled 0 0 100 40 'W1NEEDLE' 'auto' 16 $false 1000
    ST-Check 'unit (W-1a): a FIRST-READ hit that lands past the declared budget is TimedOut, not a met read - the hit is kept for diagnosis and the note says it came back past the 1000ms budget' (
      ([bool]$w1LateHit.TimedOut) -and (@($w1LateHit.Hits).Count -eq 1) -and ("$($w1LateHit.Note)" -like '*past the 1000ms budget*') -and ($w1LateHit.Ms -ge 1500))
    Set-Item -Path 'function:Invoke-OcrRegion' -Value { param($x, $y, $w, $h, $forceScale, $DeadlineMs)
      Start-Sleep -Milliseconds 1800
      return ,@([pscustomobject]@{ Text = 'other text'; X = 0; Y = 0; W = 10; H = 10 }) }
    $w1LateMiss = Find-OcrHitsScaled 0 0 100 40 'W1NEEDLE' 'auto' 16 $false 1000
    ST-Check 'unit (W-1a): a FIRST-READ miss that lands past the budget is TimedOut too - a late miss is not evidence that the text is absent' (
      ([bool]$w1LateMiss.TimedOut) -and (@($w1LateMiss.Hits).Count -eq 0) -and ("$($w1LateMiss.Note)" -like '*past the 1000ms budget*'))
    Set-Item -Path 'function:Invoke-OcrRegion' -Value { param($x, $y, $w, $h, $forceScale, $DeadlineMs)
      Start-Sleep -Milliseconds 100
      return ,@([pscustomobject]@{ Text = 'W1NEEDLE'; X = 0; Y = 0; W = 10; H = 10 }) }
    $w1InBudget = Find-OcrHitsScaled 0 0 100 40 'W1NEEDLE' 'auto' 16 $false 1000
    ST-Check 'unit (W-1a): the same read inside the budget stays a clean hit (TimedOut false, Hits 1) - the new check does not turn ordinary reads into timeouts' (
      (-not [bool]$w1InBudget.TimedOut) -and (@($w1InBudget.Hits).Count -eq 1))
    Set-Item -Path 'function:Find-OcrHitsScaled' -Value { param($x, $y, $w, $h, $needle, $scale, $maxTiles, $noTile, $deadline)
      Start-Sleep -Milliseconds 1200
      return @{ Hits = @([pscustomobject]@{ X = 1; Y = 1; W = 2; H = 2 }); Lines = @('late-hit'); Scaled = $false; Tiled = $false; TileCount = 0; Retried = $false; Note = ''; Ms = 1200.0; TimedOut = $false } }
    Set-Item -Path 'function:Resolve-Window' -Value { param($sel) return [pscustomobject]@{ Handle = [IntPtr]1; Pid = 4242; Title = 'w1-fake'; Left = 0; Top = 0; W = 100; H = 40 } }
    Set-Item -Path 'function:Get-TargetRect' -Value { param($w) return @{ X = 0; Y = 0; W = 100; H = 40 } }
    $w1LateErr = ''
    $w1LateOut = ''
    try { $w1LateOut = Invoke-Handler-wait-cond 'wait-cond' @('w1-fake', '--text', 'W1NEEDLE', '--timeout', '1', '--interval', '100') }
    catch { $w1LateErr = "$($_.Exception.Message)" }
    ST-Check 'unit (W-1a): the REAL wait-cond handler does NOT print "met" for a late hit - the expired read is counted as a read failure and reaches the caller as an error' (
      ($w1LateOut -notlike '*met after*') -and ($w1LateErr -like '*late result is not accepted as met*') -and ($w1LateErr -like '*EVERY poll failed*'))
    if (-not ($w1LateOut -notlike '*met after*' -and $w1LateErr -like '*late result*')) { Write-Output ("      W-1a handler: out=[" + $w1LateOut + "] err=[" + $w1LateErr + "]") }
    Set-Item -Path 'function:Find-OcrHitsScaled' -Value $w1Orig['Find-OcrHitsScaled']
    Set-Item -Path 'function:Resolve-Window' -Value { param($sel) return $null }
    $w1SleepErr = ''
    $w1SleepSw = [System.Diagnostics.Stopwatch]::StartNew()
    try { Invoke-Handler-wait-cond 'wait-cond' @('w1-gone', '--win', '--timeout', '1', '--interval', '5000') | Out-Null }
    catch { $w1SleepErr = "$($_.Exception.Message)" }
    $w1SleepSw.Stop()
    ST-Check 'unit (W-1b): an interval (5000ms) larger than the whole budget (1s) cannot buy extra time - the poll sleep is capped to what is LEFT, so the command exits near 1s, not 5s' (
      ($w1SleepSw.ElapsedMilliseconds -lt 3000) -and ($w1SleepErr -like '*timeout after 1s*'))
    if ($w1SleepSw.ElapsedMilliseconds -ge 3000) { Write-Output ("      W-1b sleep: elapsed=" + $w1SleepSw.ElapsedMilliseconds + "ms") }
    $script:w1WinSeq = 0
    Set-Item -Path 'function:Resolve-Window' -Value { param($sel)
      $script:w1WinSeq++
      if ($script:w1WinSeq -lt 3) { return $null }
      return [pscustomobject]@{ Handle = [IntPtr]1; Pid = 4242; Title = 'w1-fake'; Left = 0; Top = 0; W = 100; H = 40 } }
    $w1MetOut = ''
    $w1MetErr = ''
    try { $w1MetOut = Invoke-Handler-wait-cond 'wait-cond' @('w1-fake', '--win', '--timeout', '3', '--interval', '100') }
    catch { $w1MetErr = "$($_.Exception.Message)" }
    ST-Check 'unit (W-1b): the normal false -> false -> true sequence still reports met, at the third poll, with no error - capping the sleep did not break the ordinary wait' (
      ($w1MetOut -like 'wait-cond win met after*') -and ($w1MetOut -like '*(3 polls)*') -and ($w1MetErr -eq ''))
    if (-not ($w1MetOut -like 'wait-cond win met after*')) { Write-Output ("      W-1b met: out=[" + $w1MetOut + "] err=[" + $w1MetErr + "]") }
  } finally {
    foreach ($w1n in $w1Names) { Set-Item -Path ('function:' + $w1n) -Value $w1Orig[$w1n] }
  }

  # ---------- D-1 (v4.6.13): PT profile and anchor calibration (pt-profile / pt-anchor) ----------
  # A profile is ONE surface written down: window identity plus the OCR lines it carried,
  # in WINDOW-RELATIVE coordinates. These checks pin the three promises the pair makes:
  # (1) a multi-pass profile keeps only lines EVERY pass saw, each at the median of its
  # sample positions (even counts take the lower median - a stated rule, not a coin flip);
  # (2) loading refuses a corrupt or unusable profile BY NAME instead of trusting it;
  # (3) matching reports its tier (exact / fold / substring / ambiguous / none) and the
  # drift is the difference of two REAL reads, never arithmetic on remembered coordinates.
  # The two OCR-dependent cases (a file profile round trip and a synthetic +7/+9 shift)
  # live in their own region below, so a box without a language pack skips them by name
  # instead of reporting a product failure.
  $ptDir = Join-Path $env:TEMP ('st_ptanchor_' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $ptDir | Out-Null
  try {
    # (1) the sample merge: intersection across passes + median position
    $ptS1 = @(
      (New-PtAnchorRecord 'DTX alpha row' 10 10 100 20),
      (New-PtAnchorRecord 'DTX beta row' 10 40 80 20)
    )
    $ptS2 = @(
      (New-PtAnchorRecord 'DTX alpha row' 14 10 100 20),
      (New-PtAnchorRecord 'DTX beta row' 12 40 80 20),
      (New-PtAnchorRecord 'DTX gamma row' 10 70 90 20)
    )
    $ptS3 = @(
      (New-PtAnchorRecord 'DTX alpha row' 12 10 100 20),
      (New-PtAnchorRecord 'DTX beta row' 11 40 80 20)
    )
    $ptM = @(Merge-PtAnchorSamples @($ptS1, $ptS2, $ptS3))
    $ptAlpha = @($ptM | Where-Object { ([string](Get-OptValue $_ 'text')) -ceq 'DTX alpha row' })
    $ptBeta = @($ptM | Where-Object { ([string](Get-OptValue $_ 'text')) -ceq 'DTX beta row' })
    $ptEven = @(Merge-PtAnchorSamples @(
      @((New-PtAnchorRecord 'DTX even row' 10 0 10 10)),
      @((New-PtAnchorRecord 'DTX even row' 16 0 10 10))))
    $ptGammaSeen = @($ptM | Where-Object { ([string](Get-OptValue $_ 'text')) -ceq 'DTX gamma row' }).Count
    ST-Check 'unit (D-1): Merge-PtAnchorSamples keeps only lines every pass saw, one dropped line never becomes an anchor, and each anchor sits at the lower median' (
      (@($ptM).Count -eq 2) -and (@($ptAlpha).Count -eq 1) -and (@($ptBeta).Count -eq 1) -and
      ([int](Get-OptValue $ptAlpha[0] 'ix') -eq 12) -and ([int](Get-OptValue $ptBeta[0] 'ix') -eq 11) -and
      (@($ptEven).Count -eq 1) -and ([int](Get-OptValue $ptEven[0] 'ix') -eq 10) -and ($ptGammaSeen -eq 0))
    if (($ptGammaSeen -ne 0) -or (@($ptM).Count -ne 2)) { Write-Output ("      D-1 merge: kept=$(@($ptM).Count) gamma=$ptGammaSeen") }
    # (2) the loader reasons: each defect has its own sentence
    $ptGoodWin = [pscustomobject]@{ rect = @(0, 0, 100, 50) }
    $ptGoodAnchor = [pscustomobject]@{ text = 'DTX line'; ix = 5; iy = 5 }
    $ptGood = [pscustomobject]@{ version = 1; window = $ptGoodWin; anchors = @($ptGoodAnchor) }
    $ptGoodWhy = Get-PtProfileReason $ptGood
    $ptRVer = Get-PtProfileReason ([pscustomobject]@{ version = 2; window = $ptGoodWin; anchors = @($ptGoodAnchor) })
    $ptREmpty = Get-PtProfileReason ([pscustomobject]@{ version = 1; window = $ptGoodWin; anchors = @() })
    $ptRNoIy = Get-PtProfileReason ([pscustomobject]@{ version = 1; window = $ptGoodWin; anchors = @([pscustomobject]@{ text = 'DTX line'; ix = 5 }) })
    $ptRRect = Get-PtProfileReason ([pscustomobject]@{ version = 1; window = [pscustomobject]@{ rect = @(0, 0, 100) }; anchors = @($ptGoodAnchor) })
    ST-Check 'unit (D-1): Get-PtProfileReason accepts a usable profile and names each defect it refuses instead of calling it invalid' (
      ($ptGoodWhy -eq '') -and ($ptRVer -ceq "version must be 1, got '2'") -and
      ($ptREmpty -ceq 'anchors array is empty - nothing to relocate') -and
      ($ptRNoIy -ceq "anchor 'DTX line' has no iy") -and ($ptRRect -ceq 'window.rect must be [x,y,w,h]'))
    $ptEmptyP = Join-Path $ptDir 'empty.json'
    [System.IO.File]::WriteAllText($ptEmptyP, '', (New-Object System.Text.UTF8Encoding($false)))
    $ptBadP = Join-Path $ptDir 'bad.json'
    [System.IO.File]::WriteAllText($ptBadP, 'not json', (New-Object System.Text.UTF8Encoding($false)))
    $ptVerP = Join-Path $ptDir 'version2.json'
    [System.IO.File]::WriteAllText($ptVerP, '{"version":2,"window":{"rect":[0,0,100,50]},"anchors":[{"text":"DTX row","ix":1,"iy":1}]}', (New-Object System.Text.UTF8Encoding($false)))
    $ptGoodP = Join-Path $ptDir 'good.json'
    [System.IO.File]::WriteAllText($ptGoodP, '{"version":1,"window":{"rect":[0,0,100,50]},"anchors":[{"text":"DTX row","ix":5,"iy":5}]}', (New-Object System.Text.UTF8Encoding($false)))
    $ptWhyMissing = ''
    $ptWhyEmpty = ''
    $ptWhyFolder = ''
    $ptWhyJson = ''
    $ptWhyVer = ''
    $ptLoaded = $null
    try { [void](Import-PtProfile (Join-Path $ptDir 'nope.json') 'pt-anchor') } catch { $ptWhyMissing = $_.Exception.Message }
    try { [void](Import-PtProfile $ptEmptyP 'pt-anchor') } catch { $ptWhyEmpty = $_.Exception.Message }
    try { [void](Import-PtProfile $ptDir 'pt-anchor') } catch { $ptWhyFolder = $_.Exception.Message }
    try { [void](Import-PtProfile $ptBadP 'pt-anchor') } catch { $ptWhyJson = $_.Exception.Message }
    try { [void](Import-PtProfile $ptVerP 'pt-anchor') } catch { $ptWhyVer = $_.Exception.Message }
    try { $ptLoaded = Import-PtProfile $ptGoodP 'pt-anchor' } catch { }
    ST-Check 'unit (D-1): Import-PtProfile refuses a missing file, an empty file, a folder, bad JSON and an unusable shape by name, and loads a good one' (
      ($ptWhyMissing -like '*profile not found*') -and ($ptWhyEmpty -like '*profile file is empty*') -and
      ($ptWhyFolder -like '*profile is a folder*') -and ($ptWhyJson -like '*not valid JSON*') -and
      ($ptWhyVer -like '*version must be 1*') -and ($null -ne $ptLoaded) -and ([int](Get-OptValue $ptLoaded 'version') -eq 1))
    if (($ptWhyMissing -eq '') -or ($ptWhyJson -eq '')) { Write-Output ("      D-1 loader: missing=[$ptWhyMissing] json=[$ptWhyJson] folder=[$ptWhyFolder] ver=[$ptWhyVer]") }
    # (3) the tiers and the drift arithmetic
    $ptA = @(
      (New-PtAnchorRecord 'DTX exact row' 10 10 80 20),
      (New-PtAnchorRecord 'QX7AUDITBEGIN' 10 40 100 20),
      (New-PtAnchorRecord 'DTX long needle row' 10 70 120 20)
    )
    $ptMExact = Find-PtAnchorMatch $ptA 'dtx exact row'
    $ptMFold = Find-PtAnchorMatch $ptA 'QX7AUD1TBEG1N'
    $ptMSub = Find-PtAnchorMatch $ptA 'long needle'
    $ptMAmb = Find-PtAnchorMatch $ptA 'DTX'
    $ptMNone = Find-PtAnchorMatch $ptA 'NOPE42'
    $ptDr = Get-PtAnchorDrift (New-PtAnchorRecord 'DTX line' 10 20 0 0) (New-PtAnchorRecord 'DTX line' 17 29 0 0)
    ST-Check 'unit (D-1): Find-PtAnchorMatch reports exact, fold, substring, ambiguous and none as distinct tiers, and the drift is the difference of two reads' (
      ($ptMExact.Kind -ceq 'exact') -and (@($ptMExact.Rows).Count -eq 1) -and
      ($ptMFold.Kind -ceq 'fold') -and (@($ptMFold.Rows).Count -eq 1) -and
      ($ptMSub.Kind -ceq 'substring') -and (@($ptMSub.Rows).Count -eq 1) -and
      ($ptMAmb.Kind -ceq 'ambiguous') -and (@($ptMAmb.Rows).Count -eq 2) -and
      ($ptMNone.Kind -ceq 'none') -and (@($ptMNone.Rows).Count -eq 0) -and
      ([int]$ptDr.Dx -eq 7) -and ([int]$ptDr.Dy -eq 9) -and ([double]$ptDr.Dist -eq 11.4))
    if (-not ($ptMExact.Kind -ceq 'exact' -and $ptMFold.Kind -ceq 'fold' -and $ptMSub.Kind -ceq 'substring' -and $ptMAmb.Kind -ceq 'ambiguous')) {
      Write-Output ("      D-1 tiers: exact=$($ptMExact.Kind) fold=$($ptMFold.Kind) sub=$($ptMSub.Kind) amb=$($ptMAmb.Kind) none=$($ptMNone.Kind)")
    }
    # (4) the refusal is user-visible behaviour, so it is pinned through the real command
    # line: a corrupt profile must exit non-zero AND name the field that is wrong.
    $ptCliOut = Join-Path $ptDir 'corrupt.txt'
    $ptCliArg = '-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-anchor "' + $ptVerP + '" --needle "DTX row"'
    $ptCli = Start-Process -FilePath 'powershell.exe' -ArgumentList $ptCliArg -RedirectStandardOutput $ptCliOut -RedirectStandardError "$ptCliOut.err" -Wait -PassThru -NoNewWindow
    $ptCliTxt = ''
    if (Test-Path -LiteralPath $ptCliOut) { $ptCliTxt += [IO.File]::ReadAllText($ptCliOut) }
    if (Test-Path -LiteralPath "$ptCliOut.err") { $ptCliTxt += [IO.File]::ReadAllText("$ptCliOut.err") }
    ST-Check 'e2e (D-1): pt-anchor refuses a corrupt profile through the real command line, exits non-zero and names the field' (
      ($ptCli.ExitCode -ne 0) -and ($ptCliTxt -match 'version must be 1') -and ($ptCliTxt -match 'refusing an unusable profile'))
    if ($ptCli.ExitCode -eq 0 -or -not ($ptCliTxt -match 'version must be 1')) { Write-Output ("      D-1 corrupt-profile e2e: exit=$($ptCli.ExitCode) out=[$ptCliTxt]") }
  } finally {
    Remove-Item -LiteralPath $ptDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  # The OCR-dependent half: a profile has to be WRITTEN from a real read and then re-read
  # against a moved copy of the same surface. Synthetic bitmaps keep this offline - no window
  # and no desktop, the same road read-text --file already uses.
  $script:StRecord = New-Object System.Collections.ArrayList
  if ($ocrPackTag -eq '') {
    ST-SkipRegion 'pt-anchor' 'no OCR language pack / recognizer unreachable from this engine - the anchor road cannot be measured, so this is not a regression'
  } else {
  # REGION-BEGIN pt-anchor
  $ptImgDir = Join-Path $env:TEMP ('st_ptfiles_' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $ptImgDir | Out-Null
  try {
    $ptText = 'DTXANCHOR42'
    $ptW = 1200
    $ptH = 120
    $ptPngA = Join-Path $ptImgDir 'anchor-a.png'
    $ptBmA = New-Object System.Drawing.Bitmap($ptW, $ptH)
    $ptGrA = [System.Drawing.Graphics]::FromImage($ptBmA)
    $ptGrA.Clear([System.Drawing.Color]::White)
    $ptGrA.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $ptFntA = New-Object System.Drawing.Font('Consolas', 28, [System.Drawing.FontStyle]::Bold)
    $ptGrA.DrawString($ptText, $ptFntA, [System.Drawing.Brushes]::Black, 10, 20)
    $ptGrA.Dispose(); $ptFntA.Dispose()
    $ptBmA.Save($ptPngA, [System.Drawing.Imaging.ImageFormat]::Png)
    # B carries the SAME ink translated by +7/+12, not a re-render at (+7,+9): measured
    # 2026-10-30, a re-render lands in a zone where Windows OCR inflates the line box from
    # 24px to 36px tall and reports y=57 instead of 39 (ink was pixel-exact), which would
    # make a <=1px assertion measure fixture luck, not the tool. The translation keeps the
    # glyph raster identical, and dy=12 is one of the offsets re-measured clean (box=24px).
    $ptPngB = Join-Path $ptImgDir 'anchor-b.png'
    $ptBmB = New-Object System.Drawing.Bitmap($ptW, $ptH)
    $ptGrB = [System.Drawing.Graphics]::FromImage($ptBmB)
    $ptGrB.Clear([System.Drawing.Color]::White)
    $ptGrB.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $ptGrB.DrawImage($ptBmA, 7, 12, $ptW, $ptH)
    $ptGrB.Dispose()
    $ptBmB.Save($ptPngB, [System.Drawing.Imaging.ImageFormat]::Png); $ptBmB.Dispose(); $ptBmA.Dispose()
    $ptRun = {
      param([string]$ArgLine, [string]$OutName)
      $o = Join-Path $ptImgDir $OutName
      $pr = Start-Process -FilePath 'powershell.exe' -ArgumentList $ArgLine -RedirectStandardOutput $o -RedirectStandardError "$o.err" -Wait -PassThru -NoNewWindow
      $txt = ''
      if (Test-Path -LiteralPath $o) { $txt += [IO.File]::ReadAllText($o) }
      if (Test-Path -LiteralPath "$o.err") { $txt += [IO.File]::ReadAllText("$o.err") }
      return @{ Exit = $pr.ExitCode; Txt = $txt }
    }
    # (5) write-read round trip: the saved profile must load back field for field
    $ptProfPath = Join-Path $ptImgDir 'profile.json'
    $ptA1 = & $ptRun ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-profile --file "' + $ptPngA + '" --save "' + $ptProfPath + '"') 'profile.txt'
    $ptProfObj = $null
    $ptProfObj2 = $null
    try { $ptProfObj = Import-PtProfile $ptProfPath 'pt-anchor' } catch { }
    try { $ptProfObj2 = Import-PtProfile $ptProfPath 'pt-anchor' } catch { }
    $ptJsonA = ''
    $ptJsonB = ''
    if ($null -ne $ptProfObj) { $ptJsonA = ($ptProfObj | ConvertTo-Json -Depth 6 -Compress) }
    if ($null -ne $ptProfObj2) { $ptJsonB = ($ptProfObj2 | ConvertTo-Json -Depth 6 -Compress) }
    $ptRectTxt = ''
    $ptAnch = @()
    $ptHit = $null
    $ptNullConf = -1
    if ($null -ne $ptProfObj) {
      $ptRectTxt = (@(Get-OptValue (Get-OptValue $ptProfObj 'window') 'rect') -join ',')
      $ptAnch = @(Get-OptValue $ptProfObj 'anchors')
      $ptHit = Find-PtAnchorMatch $ptAnch $ptText
      $ptNullConf = @($ptAnch | Where-Object { $null -ne (Get-OptValue $_ 'ocrConf') }).Count
    }
    ST-Check 'e2e (D-1): pt-profile --file writes a profile that loads back field for field, keeps ocrConf null and anchors the rendered text' (
      ($ptA1.Exit -eq 0) -and ($null -ne $ptProfObj) -and ($ptJsonA -ceq $ptJsonB) -and
      (([string](Get-OptValue $ptProfObj 'basis')) -ceq 'file') -and
      ($ptRectTxt -ceq ('0,0,' + [string]$ptW + ',' + [string]$ptH)) -and
      ($ptHit.Kind -ceq 'exact') -and ($ptNullConf -eq 0) -and ($ptA1.Txt -match 'saved: '))
    if (-not (($ptA1.Exit -eq 0) -and ($null -ne $ptProfObj) -and ($ptJsonA -ceq $ptJsonB) -and
              (([string](Get-OptValue $ptProfObj 'basis')) -ceq 'file') -and
              ($ptRectTxt -ceq ('0,0,' + [string]$ptW + ',' + [string]$ptH)) -and
              ($ptHit.Kind -ceq 'exact') -and ($ptNullConf -eq 0) -and ($ptA1.Txt -match 'saved: '))) {
      Write-Output ("      D-1 profile e2e: exit=$($ptA1.Exit) loaded=$($null -ne $ptProfObj) jsonEq=$($ptJsonA -ceq $ptJsonB) rect=[$ptRectTxt] hit=$($ptHit.Kind) nullConf=$ptNullConf out=[$($ptA1.Txt)]")
    }
    # (6) the synthetic shift: the same ink translated +7/+12 must be reported within one pixel
    $ptB1 = & $ptRun ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-anchor "' + $ptProfPath + '" --needle "' + $ptText + '" --file "' + $ptPngB + '" --max-drift 20') 'anchor-b.txt'
    $ptDx = 999
    $ptDy = 999
    if ($ptB1.Txt -match 'drift=\(([-0-9]+),([-0-9]+)\)') { $ptDx = [int]$Matches[1]; $ptDy = [int]$Matches[2] }
    ST-Check 'e2e (D-1): pt-anchor --file reports the synthetic +7/+12 shift within one pixel and calls it within' (
      ($ptB1.Exit -eq 0) -and ($ptB1.Txt -match 'match=exact') -and ($ptB1.Txt -match 'verdict=within') -and
      ([math]::Abs($ptDx - 7) -le 1) -and ([math]::Abs($ptDy - 12) -le 1))
    if (($ptB1.Exit -ne 0) -or ([math]::Abs($ptDx - 7) -gt 1) -or ([math]::Abs($ptDy - 12) -gt 1)) {
      Write-Output ("      D-1 drift e2e: exit=$($ptB1.Exit) drift=($ptDx,$ptDy) out=[$($ptB1.Txt)]")
    }
    # (7) --strict: the same drift, a tighter bound, a non-zero exit that names both numbers
    $ptB2 = & $ptRun ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-anchor "' + $ptProfPath + '" --needle "' + $ptText + '" --file "' + $ptPngB + '" --strict --max-drift 5') 'anchor-strict.txt'
    ST-Check 'e2e (D-1): --strict turns a drift above --max-drift into a non-zero exit that names both numbers' (
      ($ptB2.Exit -ne 0) -and ($ptB2.Txt -match 'exceeds --max-drift 5px'))
    if ($ptB2.Exit -eq 0) { Write-Output ("      D-1 strict e2e: exit=$($ptB2.Exit) out=[$($ptB2.Txt)]") }
  } finally {
    Remove-Item -LiteralPath $ptImgDir -Recurse -Force -ErrorAction SilentlyContinue
  }
  # REGION-END pt-anchor
  }
  $ptEmitted = @($script:StRecord)
  $script:StRecord = $null
  ST-ReconcileRegion 'pt-anchor' $ptEmitted

  # ---------- v4.7.0 (B-1): two anchors estimate, a THIRD one tests ----------
  # The calibration layer, judged where it can be judged exactly. Nothing in this block opens a
  # window or touches the desktop: the estimator legs are hand-built numbers, and every handler
  # leg either refuses BEFORE the surface read (that is the property under test) or points
  # --file at a path that does not exist, so the first thing the read can do is refuse by name.
  # The OCR-dependent half - a scale measured off a real re-rendered surface - is the
  # 'pt-calibrate' region further down, skippable by name on a box with no language pack.
  $pcItem = {
    param($ix, $lb, $bx, $by, $ox, $oy)
    [pscustomobject]@{ Index = $ix; Label = $lb; Bx = [double]$bx; By = [double]$by; Ox = [double]$ox; Oy = [double]$oy }
  }
  # (1) the exact fit: obs = 2*basis on both axes, so scale=2, delta=(0,0) and the anchor the
  # fit never saw lands exactly on its prediction. Every number here is asserted, not just "ok".
  $pcF1 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 20), (& $pcItem 2 'BBB' 110 60 220 120)) -Verifies @((& $pcItem 3 'CCC' 300 300 600 600))
  ST-Check 'unit (B-1): a 2x surface read through two anchors gives scale=2, delta=(0,0) and a zero residual on the independent third' (
    ([bool]$pcF1.Ok) -and ($pcF1.Verdict -ceq 'fit') -and ($pcF1.Scale -eq 2.0) -and
    ($pcF1.Sx -eq 2.0) -and ($pcF1.Sy -eq 2.0) -and ($pcF1.Dx -eq 0.0) -and ($pcF1.Dy -eq 0.0) -and
    ($pcF1.BasisSpacing -eq 111.803) -and ($pcF1.ObservedSpacing -eq 223.607) -and
    (@(@($pcF1.Residuals)).Count -eq 1) -and (@($pcF1.Residuals)[0].Residual -eq 0.0) -and
    (@($pcF1.Residuals)[0].Index -eq 3))
  # (2) scale AND translate together: obs = 1.5*basis + (5,9). The delta is the mean of the two
  # per-anchor deltas, so both anchors must agree or the printed pair is a lie.
  $pcF2 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 24), (& $pcItem 2 'BBB' 110 60 170 99)) -Verifies @((& $pcItem 3 'CCC' 200 400 305 609))
  ST-Check 'unit (B-1): uniform 1.5x plus a (5,9) shift is recovered as scale=1.5 delta=(5,9) with the third anchor inside the limit' (
    ([bool]$pcF2.Ok) -and ($pcF2.Verdict -ceq 'fit') -and ($pcF2.Scale -eq 1.5) -and
    ($pcF2.Dx -eq 5.0) -and ($pcF2.Dy -eq 9.0) -and ($pcF2.ResidualMax -eq 0.0) -and ($pcF2.ResidualMean -eq 0.0))
  # (3) the residual is the whole point of the third anchor: displace ONLY the verify point by
  # 10px. Ok stays true (the arithmetic ran), the VERDICT says exceeded, and the limit is the
  # caller's knob - the same numbers under limit 20 come back fit, so "exceeded" cannot be a
  # fixture artefact or a hardcoded no.
  $pcF3 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 24), (& $pcItem 2 'BBB' 110 60 170 99)) -Verifies @((& $pcItem 3 'CCC' 200 400 305 619)) -ResidualLimit 3
  $pcF3b = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 24), (& $pcItem 2 'BBB' 110 60 170 99)) -Verifies @((& $pcItem 3 'CCC' 200 400 305 619)) -ResidualLimit 20
  ST-Check 'unit (B-1): a verify anchor 10px off the model prints residual-max=10 and verdict=exceeded at limit 3, and the SAME geometry is a fit at limit 20' (
    ([bool]$pcF3.Ok) -and ($pcF3.Verdict -ceq 'exceeded') -and ($pcF3.ResidualMax -eq 10.0) -and
    ($pcF3.ResidualLimit -eq 3.0) -and ($pcF3.Note -like '*did not follow uniform-scale+translation*') -and
    ($pcF3b.Verdict -ceq 'fit') -and ($pcF3b.ResidualMax -eq 10.0))
  # (4) two verifies: the mean is over what was actually measured, not over the estimate pair.
  $pcF4 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 20), (& $pcItem 2 'BBB' 110 60 220 120)) -Verifies @((& $pcItem 3 'CCC' 300 300 600 600), (& $pcItem 4 'DDD' 400 50 800 106))
  ST-Check 'unit (B-1): with two independent anchors the mean is the mean of the two residuals and the max is the max' (
    ([bool]$pcF4.Ok) -and (@(@($pcF4.Residuals)).Count -eq 2) -and ($pcF4.ResidualMax -eq 6.0) -and
    ($pcF4.ResidualMean -eq 3.0) -and ($pcF4.Verdict -ceq 'exceeded'))
  # (5) NON-UNIFORM scale: sx=2, sy=1.8. There is no shear term in this model, so the answer is
  # a refusal that names both ratios - never the average the caller might have wanted.
  $pcF5 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 20), (& $pcItem 2 'BBB' 110 60 220 110)) -Verifies @((& $pcItem 3 'CCC' 300 300 600 600))
  # two-sided control on the tolerance knob: 0.01 apart must pass where 0.2 apart refuses.
  $pcF5b = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 20), (& $pcItem 2 'BBB' 110 60 220 120.5)) -Verifies @((& $pcItem 3 'CCC' 300 300 600.6 600.6))
  ST-Check 'unit (B-1): sx=2 against sy=1.8 is refused as axis-divergence and the two ratios are printed in the refusal, while a 0.01 spread fits' (
    (-not [bool]$pcF5.Ok) -and ($pcF5.Code -ceq 'axis-divergence') -and ($pcF5.Sx -eq 2.0) -and
    ($pcF5.Sy -eq 1.8) -and ($pcF5.Note -like '*non-uniform*') -and ($pcF5.Note -like '*averaging*') -and
    ([bool]$pcF5b.Ok) -and ($pcF5b.Sy -eq 2.01) -and ($pcF5b.Verdict -ceq 'fit'))
  # (6) a ROTATION of 30 degrees about the first anchor. The Euclidean scale is 1.0 - a
  # uniform-scale reader would happily report "no zoom" - but the per-axis ratios are 0.566 and
  # 1.699, which is exactly what the axis test is for. This leg is the proof that "unmodeled
  # rotation" is a refusal and not something the model absorbs.
  $pcF6 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 10 10), (& $pcItem 2 'BBB' 110 70 66.6025 111.9615)) -Verifies @((& $pcItem 3 'CCC' 300 300 300 300))
  ST-Check 'unit (B-1): a 30-degree rotation is refused, not averaged - its Euclidean scale would have read as no zoom at all' (
    (-not [bool]$pcF6.Ok) -and ($pcF6.Code -ceq 'axis-divergence') -and ($pcF6.Sx -eq 0.566) -and
    ($pcF6.Sy -eq 1.6994) -and ($pcF6.Note -like '*rotation*'))
  # (7) degenerate geometry, each named by its own code.
  $pcF7a = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 20), (& $pcItem 2 'BBB' 14 14 28 28)) -Verifies @((& $pcItem 3 'CCC' 30 30 60 60))
  $pcF7b = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 20), (& $pcItem 2 'BBB' 14 14 28 28)) -Verifies @((& $pcItem 3 'CCC' 30 30 60 60)) -MinSpacing 5
  ST-Check 'unit (B-1): a 5.7px baseline is refused as basis-degenerate at the 20px floor and fits when the caller lowers --min-spacing to 5' (
    (-not [bool]$pcF7a.Ok) -and ($pcF7a.Code -ceq 'basis-degenerate') -and ($pcF7a.BasisSpacing -eq 5.657) -and
    ($pcF7a.Note -like '*20*') -and ([bool]$pcF7b.Ok) -and ($pcF7b.Scale -eq 2.0))
  $pcF8 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 40 40), (& $pcItem 2 'BBB' 110 10 240 40)) -Verifies @((& $pcItem 3 'CCC' 300 10 600 40))
  ST-Check 'unit (B-1): anchors on one horizontal line are refused as axis-degenerate, because the test that catches a non-uniform scale cannot run without extent on both axes' (
    (-not [bool]$pcF8.Ok) -and ($pcF8.Code -ceq 'axis-degenerate') -and ($pcF8.Note -like '*dx=100*'))
  $pcF9 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 50 50), (& $pcItem 2 'BBB' 110 60 50 50)) -Verifies @((& $pcItem 3 'CCC' 300 300 50 50))
  ST-Check 'unit (B-1): two anchors reading at the same place now are refused as observed-degenerate instead of reporting an infinite or zero scale' (
    (-not [bool]$pcF9.Ok) -and ($pcF9.Code -ceq 'observed-degenerate') -and ($pcF9.ObservedSpacing -eq 0.0) -and
    ($pcF9.Scale -eq 0.0))
  # (8) the structural refusals, in the order the contract puts them.
  $pcG1 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 20)) -Verifies @((& $pcItem 3 'CCC' 300 300 600 600))
  $pcG2 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 20), (& $pcItem 2 'BBB' 110 60 220 120), (& $pcItem 5 'EEE' 10 90 20 180)) -Verifies @((& $pcItem 3 'CCC' 300 300 600 600))
  $pcG3 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 20), (& $pcItem 2 'BBB' 110 60 220 120)) -Verifies @()
  $pcG4 = Get-PtCalibration -Estimates @((& $pcItem 1 '' 10 10 20 20), (& $pcItem 2 'BBB' 110 60 220 120)) -Verifies @((& $pcItem 3 'CCC' 300 300 600 600))
  $pcG5 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 20), (& $pcItem 2 'AAA' 110 60 220 120)) -Verifies @((& $pcItem 3 'CCC' 300 300 600 600))
  $pcG6 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 20), (& $pcItem 2 'BBB' 110 60 220 120)) -Verifies @((& $pcItem 3 'AAA' 300 300 600 600))
  # the ordering witness the reorder was made for: the same label repeats INSIDE the estimate set
  # as well as across the two sets. duplicate-first would answer "your labels repeat"; the caller's
  # actual mistake is that a point is doing both jobs, so that is what must come back.
  $pcG7 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 10 10 20 20), (& $pcItem 2 'AAA' 110 60 220 120)) -Verifies @((& $pcItem 3 'AAA' 300 300 600 600))
  ST-Check 'unit (B-1): estimate-count, verify-count, empty-label, verify-overlaps-estimate and duplicate-label each refuse with their own code, and an anchor shared across the sets reports the overlap rather than the repeat (order, not luck)' (
    ($pcG1.Code -ceq 'estimate-count') -and ($pcG1.Note -like '*exactly 2*got 1*') -and
    ($pcG2.Code -ceq 'estimate-count') -and ($pcG2.Note -like '*got 3*') -and
    ($pcG3.Code -ceq 'verify-count') -and ($pcG3.Note -like '*is a guess, not a measurement*') -and
    ($pcG4.Code -ceq 'empty-label') -and ($pcG5.Code -ceq 'duplicate-label') -and
    ($pcG5.Note -like "*'AAA'*") -and ($pcG6.Code -ceq 'verify-overlaps-estimate') -and
    ($pcG6.Note -like '*zero by construction*') -and ($pcG7.Code -ceq 'verify-overlaps-estimate'))
  # (9) applying the model: half-to-even, both directions, because a rule that only rounds down
  # would pass a one-sided fixture.
  $pcM = Get-PtMappedPoint $pcF2 100 200
  $pcMh1 = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 0 0 1 1), (& $pcItem 2 'BBB' 100 50 101 51)) -Verifies @((& $pcItem 3 'CCC' 200 90 201 91))
  $pcMh2 = Get-PtMappedPoint $pcMh1 2 3
  $pcMh3 = Get-PtMappedPoint $pcMh1 4 5
  ST-Check 'unit (B-1): the conversion carries scale and delta to the point named, reports the float and rounds half-to-even in BOTH directions (2.5 -> 2, 3.5 -> 4)' (
    ($pcM.Xf -eq 155.0) -and ($pcM.Yf -eq 309.0) -and ($pcM.Xi -eq 155) -and ($pcM.Yi -eq 309) -and
    ($pcMh1.Scale -eq 1.0) -and ($pcMh1.Dx -eq 1.0) -and ($pcMh1.Dy -eq 1.0) -and
    ($pcMh2.Xf -eq 3.0) -and ($pcMh3.Xf -eq 5.0))
  $pcHalf = Get-PtCalibration -Estimates @((& $pcItem 1 'AAA' 0 0 0 0), (& $pcItem 2 'BBB' 100 40 100 40)) -Verifies @((& $pcItem 3 'CCC' 200 80 200 80))
  $pcH1 = Get-PtMappedPoint $pcHalf 1.5 2.5
  $pcH2 = Get-PtMappedPoint $pcHalf 2.5 3.5
  ST-Check 'unit (B-1): a pure half-pixel model rounds 1.5 and 2.5 to 2 and 2, 2.5 and 3.5 to 2 and 4 - half-to-even, not half-up' (
    ($pcHalf.Scale -eq 1.0) -and ($pcHalf.Dx -eq 0.0) -and ($pcH1.Xf -eq 1.5) -and ($pcH1.Xi -eq 2) -and
    ($pcH1.Yf -eq 2.5) -and ($pcH1.Yi -eq 2) -and ($pcH2.Xf -eq 2.5) -and ($pcH2.Xi -eq 2) -and
    ($pcH2.Yf -eq 3.5) -and ($pcH2.Yi -eq 4))

  # (10) the two grammars the new flags share, and the scope-qualifier trap the refusal text
  # would have fallen into ("$Owner : ..." prints a space, "$Owner: ..." loses the name).
  $pcIdxOk = @(Parse-PtAnchorIndexes '1,3' '--estimate')
  $pcIdxErrs = @()
  foreach ($pcBad in @('', '0', '-1', 'x', '1,1', '1,,3')) {
    $pcGot = ''
    try { [void](Parse-PtAnchorIndexes $pcBad '--estimate') } catch { $pcGot = $_.Exception.Message }
    if ($pcGot -eq '') { $pcIdxErrs += ($pcBad + ': accepted') }
    elseif (-not $pcGot.StartsWith('--estimate ')) { $pcIdxErrs += ($pcBad + ': ' + $pcGot) }
  }
  ST-Check 'unit (B-1): Parse-PtAnchorIndexes takes 1,3 and refuses empty, zero, negative, non-numeric, a repeated index and an empty segment - each refusal names the flag it belongs to' (
    (@($pcIdxOk).Count -eq 2) -and ($pcIdxOk[0] -eq 1) -and ($pcIdxOk[1] -eq 3) -and (@($pcIdxErrs).Count -eq 0))
  if (@($pcIdxErrs).Count -gt 0) { Write-Output ('      index grammar: ' + ($pcIdxErrs -join ' | ')) }
  $pcQuad = Parse-QuadSpec '0,0,10,20' 'pt-calibrate' '--canvas'
  $pcQuadErrs = @()
  foreach ($pcQB in @('1,2,3', 'a,0,0,0', '0,0,0,10', '0,0,10,0', '')) {
    $pcQM = ''
    try { [void](Parse-QuadSpec $pcQB 'pt-calibrate' '--canvas') } catch { $pcQM = $_.Exception.Message }
    if ($pcQM -eq '') { $pcQuadErrs += ($pcQB + ': accepted') }
    elseif (-not $pcQM.StartsWith('pt-calibrate: --canvas')) { $pcQuadErrs += ($pcQB + ' -> [' + $pcQM + ']') }
  }
  ST-Check 'unit (B-1): Parse-QuadSpec accepts x,y,w,h and refuses a short list, a non-numeric segment, w=0, h=0 and an empty string - every refusal begins "pt-calibrate: --canvas", with no space before the colon' (
    ($pcQuad.X -eq 0) -and ($pcQuad.W -eq 10) -and (@($pcQuadErrs).Count -eq 0))
  if (@($pcQuadErrs).Count -gt 0) { Write-Output ('      quad grammar: ' + ($pcQuadErrs -join ' | ')) }
  $pcNeg = Parse-QuadSpec '-5,-5,10,10' 'pt-calibrate' '--canvas'
  ST-Check 'unit (B-1): a canvas may start at negative image pixels - the grammar refuses shape, not sign' (
    ($pcNeg.X -eq -5) -and ($pcNeg.Y -eq -5) -and ($pcNeg.W -eq 10))

  # (11) which row of the current surface IS this anchor: exact, then the confusable fold, and a
  # tie is a refusal. The fullwidth comma is assembled from its code point so this file stays
  # pure ASCII, and both sides go through the same normaliser the reader uses.
  $pcFoldT = [string]::Join('', @([char]0x41, [char]0xFF0C, [char]0x42))
  $pcObE = Resolve-PtAnchorObservation (New-PtAnchorRecord 'ALPHA' 10 10 60 20) @((New-PtAnchorRecord 'ALPHA' 70 80 60 20))
  $pcObF = Resolve-PtAnchorObservation (New-PtAnchorRecord $pcFoldT 10 10 60 20) @((New-PtAnchorRecord 'A,B' 70 80 60 20))
  $pcObD = Resolve-PtAnchorObservation (New-PtAnchorRecord 'ALPHA' 10 10 60 20) @((New-PtAnchorRecord 'ALPHA' 70 80 60 20), (New-PtAnchorRecord 'ALPHA' 70 180 60 20))
  $pcObN = Resolve-PtAnchorObservation (New-PtAnchorRecord 'ALPHA' 10 10 60 20) @((New-PtAnchorRecord 'OMEGA' 70 80 60 20))
  ST-Check 'unit (B-1): the observation resolves exact, then the folded form, and answers duplicate (with the count) or none rather than picking a row' (
    ($pcObE.Tier -ceq 'exact') -and ($pcObE.Row.ix -eq 70) -and ($pcObF.Tier -ceq 'fold') -and
    ($pcObD.Tier -ceq 'duplicate') -and ($pcObD.Count -eq 2) -and ($null -eq $pcObD.Row) -and
    ($pcObN.Tier -ceq 'none') -and ($pcObN.Count -eq 0))

  # (12) the handler's refusals, all of which must fire BEFORE anything reads a surface. The
  # profile is written by hand here (three unique anchors, 60px apart) precisely so the fixture
  # cannot be the reason a leg passed.
  $pcDir = Join-Path $env:TEMP ('st_ptcal_' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $pcDir | Out-Null
  try {
    $pcProfP = Join-Path $pcDir 'cal.json'
    $pcDupP = Join-Path $pcDir 'dup.json'
    $pcNoFile = Join-Path $pcDir 'no-such.png'
    $pcAnch = @(
      (New-PtAnchorRecord 'DTXCALPHA' 10 10 120 24),
      (New-PtAnchorRecord 'DTXCALBRAVO' 10 70 120 24),
      (New-PtAnchorRecord 'DTXCALCHARLIE' 10 130 120 24)
    )
    $pcDupA = @(
      (New-PtAnchorRecord 'DTXCALDUP' 10 10 120 24),
      (New-PtAnchorRecord 'DTXCALDUP' 10 70 120 24),
      (New-PtAnchorRecord 'DTXCALONLY' 10 130 120 24)
    )
    $pcWin = [pscustomobject]@{ pid = 0; proc = ''; class = ''; title = 'cal.json'; rect = @(0, 0, 600, 260) }
    [IO.File]::WriteAllText($pcProfP, ([pscustomobject]@{ version = 1; capturedAt = '2026-10-30 00:00:00 UTC'; basis = 'file'; samples = 1; window = $pcWin; anchors = @($pcAnch) } | ConvertTo-Json -Depth 6))
    [IO.File]::WriteAllText($pcDupP, ([pscustomobject]@{ version = 1; capturedAt = '2026-10-30 00:00:00 UTC'; basis = 'file'; samples = 1; window = $pcWin; anchors = @($pcDupA) } | ConvertTo-Json -Depth 6))
    $pcCall = {
      param([string[]]$Argv)
      $o = @{ Exit = 0; Txt = ''; Err = '' }
      $lines = @()
      try { $lines = @(Invoke-Handler-pt-calibrate 'pt-calibrate' $Argv) } catch { $o.Err = $_.Exception.Message }
      $o.Txt = ($lines -join "`n")
      return $o
    }
    $pcH1r = & $pcCall @($pcProfP)
    $pcH2r = & $pcCall @($pcProfP, '--estimate', '1,2')
    $pcH3r = & $pcCall @($pcProfP, '--estimate', '1,2,3', '--verify', '1', '--file', $pcNoFile)
    $pcH4r = & $pcCall @($pcProfP, '--estimate', '0,1', '--verify', '2', '--file', $pcNoFile)
    $pcH5r = & $pcCall @($pcProfP, '--estimate', '1,1', '--verify', '2', '--file', $pcNoFile)
    $pcH6r = & $pcCall @($pcProfP, '--estimate', '1,9', '--verify', '2', '--file', $pcNoFile)
    $pcH7r = & $pcCall @($pcProfP, '--estimate', '1,2', '--verify', '2', '--file', $pcNoFile)
    $pcH8r = & $pcCall @($pcProfP, '--estimate', '1,2', '--verify', '3', '--canvas', '1,2,3', '--file', $pcNoFile)
    $pcH9r = & $pcCall @($pcProfP, '--estimate', '1,2', '--verify', '3', '--relocate', '7', '--file', $pcNoFile)
    $pcHAr = & $pcCall @($pcProfP, '--estimate', '1,2', '--verify', '3', '--file', $pcNoFile)
    $pcHBr = & $pcCall @($pcDupP, '--estimate', '1,2', '--verify', '3', '--file', $pcNoFile)
    $pcHCe = & $pcCall @($pcProfP, '--estimate', '1,2', '--verify', '3', '--min-spacing', '4000', '--file', $pcNoFile)
    ST-Check 'unit (B-1): pt-calibrate refuses a missing --estimate and a missing --verify by name, before it reads anything' (
      ($pcH1r.Err.StartsWith('pt-calibrate: --estimate')) -and ($pcH2r.Err.StartsWith('pt-calibrate: --verify')) -and
      ($pcH1r.Err.Contains('--list prints the numbering')) -and ($pcH2r.Err.Contains('is a guess')))
    ST-Check 'unit (B-1): the index grammar is enforced at the command too - three indexes refused, zero refused, a repeated index refused, an index past the end names the real anchor count' (
      ($pcH3r.Err -like '*needs exactly 2 indexes, got 3*') -and ($pcH4r.Err -like '*1-based*') -and
      ($pcH5r.Err -like '*twice*') -and ($pcH6r.Err -like '*past the end of this profile, which has 3 anchor(s)*'))
    ST-Check 'unit (B-1): an anchor in BOTH --estimate and --verify is refused with the reason, not deduplicated for the caller' (
      $pcH7r.Err -like '*in BOTH --estimate and --verify*' -and $pcH7r.Err -like '*proves nothing*')
    ST-Check 'unit (B-1): --canvas and --relocate refuse their own bad shapes with the command name in front' (
      $pcH8r.Err.StartsWith('pt-calibrate: --canvas needs x,y,w,h') -and $pcH9r.Err.StartsWith('pt-calibrate: --relocate needs x,y'))
    ST-Check 'unit (B-1): a profile that carries the same text twice is refused as ambiguous before the caller is even asked which indexes he means' (
      $pcHBr.Err.StartsWith('pt-calibrate: this profile carries duplicate anchor labels') -and
      ($pcHBr.Err.Contains("'DTXCALDUP' x2")) -and ($pcHBr.Err.Contains('--samples 2+')))
    ST-Check 'unit (B-1): the --file branch is the one that reads, and it refuses a missing image by name instead of falling back to the desktop' (
      $pcHAr.Err -eq 'pt-calibrate: image not found: ' + $pcNoFile)
    ST-Check 'unit (B-1): --min-spacing far above the baseline cannot smuggle the run past the surface read either - the read is refused by name first, which is the proof that the estimator never sees a fabricated observation' (
      $pcHCe.Err -eq 'pt-calibrate: image not found: ' + $pcNoFile)

    # (13) --list is the numbering the whole interface depends on. It must print without reading
    # a surface (the profile above names pid 0, which no window has - a leg that reaches the
    # window resolution would THROW here, and that is exactly the control).
    $pcLr = & $pcCall @($pcProfP, '--list')
    $pcLr2 = & $pcCall @($pcDupP, '--list')
    ST-Check 'unit (B-1): --list prints every anchor with its 1-based index and its basis position, and does not read a surface to do it' (
      ($pcLr.Err -eq '') -and ($pcLr.Txt.StartsWith("pt-calibrate: $pcProfP has 3 anchor(s)")) -and
      ($pcLr.Txt.Contains("#1 'DTXCALPHA' at (10,10)")) -and ($pcLr.Txt.Contains("#3 'DTXCALCHARLIE' at (10,130)")) -and
      (@(@($pcLr.Txt -split "`n")).Count -eq 4) -and ($pcLr2.Err.StartsWith('pt-calibrate: this profile carries duplicate anchor labels')))
    $pcSavedJson = [bool]$script:Json
    try {
      $script:Json = $true
      $pcLj = & $pcCall @($pcProfP, '--list')
      $pcLjO = $null
      try { $pcLjO = $pcLj.Txt | ConvertFrom-Json } catch { }
      ST-Check 'unit (B-1): --list --json carries the real index/label/basis per anchor (the numbering a caller types is the numbering this prints)' (
        ($null -ne $pcLjO) -and ($pcLjO.list -eq $true) -and (@(@($pcLjO.anchors)).Count -eq 3) -and
        (@(@($pcLjO.anchors))[0].index -eq 1) -and (@(@($pcLjO.anchors))[2].index -eq 3) -and
        (@(@($pcLjO.anchors))[1].label -ceq 'DTXCALBRAVO') -and ((@(@($pcLjO.anchors))[1].basis) -join ',') -eq '10,70')
      if ($null -eq $pcLjO) { Write-Output ('      list json unparseable: [' + $pcLj.Txt + ']') }
      $pcUj = & $pcCall @($pcProfP)
      ST-Check 'unit (B-1): on the --json road a refusal still writes nothing to stdout and keeps the numbers in its text (the machine consumer cannot be handed a verdict without a measurement)' (
        ($pcUj.Err.StartsWith('pt-calibrate: --estimate')) -and ($pcUj.Txt -eq ''))
    } finally { $script:Json = $pcSavedJson }

    # (14) the loader belongs to the caller who typed the command, not to whichever command got
    # there first. Without the prefix argument every pt-calibrate refusal would print pt-anchor.
    $pcPre = ''
    try { [void](Import-PtProfile $pcProfP '') } catch { $pcPre = $_.Exception.Message }
    $pcPreC = ''
    try { [void](Import-PtProfile $pcProfP 'pt-calibrate') } catch { $pcPreC = $_.Exception.Message }
    $pcMiss = ''
    try { [void](Import-PtProfile (Join-Path $pcDir 'gone.json') 'pt-calibrate') } catch { $pcMiss = $_.Exception.Message }
    ST-Check 'unit (B-1): the shared profile loader refuses a caller that brings no command name, and prints the name it was given on every other refusal' (
      ($pcPre.Contains('needs the command name') -and -not $pcPre.Contains('pt-anchor')) -and
      ($pcMiss.StartsWith('pt-calibrate: profile not found:')) -and ($pcPreC -eq ''))

    # (15) shape lints. These measure the PRODUCT face: the entry plus every lib file that is not
    # a lifted selftest family. Scanning the whole aggregate instead would be red for the wrong
    # reason - a selftest that CALLS the estimator twenty times is not a second copy of it, and a
    # scan that cannot tell a caller from a copy cannot catch a copy either. The face is therefore
    # named, counted and printed, so an empty ruler can never read as a clean one.
    # A-22 shape: the face is a FILE-SYSTEM fact (entry + lib/*.ps1), so in single-file mode the
    # scan target does not exist and the lints SKIP with that named - they are not vacuously green.
    if ($script:StSourceMode -cne 'aggregate') {
      ST-Skip 'lint (B-1): the estimator/handler/reader face lints over entry+lib files' 'single-file source mode (no lib/ beside the entry) - the product-face file set these lints measure does not exist; the installed shape carries the same functions inlined'
      ST-Skip 'lint (B-1): the handler forwards --min-spacing/--max-residual and the refusal carries the numbers' 'single-file source mode (no lib/ beside the entry)'
      ST-Skip 'lint (B-1): pt-calibrate is read-only by construction' 'single-file source mode (no lib/ beside the entry)'
      ST-Skip 'lint (B-1): the read-only and no-trigonometry scans flag a planted click call and a planted sine term' 'single-file source mode (no lib/ beside the entry)'
      ST-Skip 'lint (B-1): pt-calibrate is advertised as --json capable AND honors it, and the rectangle grammar has one producer' 'single-file source mode (no lib/ beside the entry)'
      ST-Skip 'lint (B-1): the two PT readers share ONE surface read' 'single-file source mode (no lib/ beside the entry)'
      ST-Skip 'lint (B-1): every profile load in the product face names the command whose error it is printing' 'single-file source mode (no lib/ beside the entry)'
      ST-Skip 'lint (B-1): the calibration answer carries model, units, source, both clocks and the applies-to region, and says out loud that menus and toolbars are not covered' 'single-file source mode (no lib/ beside the entry)'
    } else {
    $pcProdFace = New-Object System.Collections.ArrayList
    foreach ($pcPf in @(Get-ChildItem -LiteralPath $script:ToolRootPath -Filter '*.ps1' -File | Sort-Object Name)) {
      [void]$pcProdFace.Add(@{ Name = [string]$pcPf.Name; Lines = @([System.IO.File]::ReadAllLines([string]$pcPf.FullName)) })
    }
    $pcLibDir = Join-Path $script:ToolRootPath 'lib'
    foreach ($pcPf in @(Get-ChildItem -LiteralPath $pcLibDir -Filter '*.ps1' -File | Where-Object { ([string]$_.Name) -notlike 'selftest*' } | Sort-Object Name)) {
      [void]$pcProdFace.Add(@{ Name = ('lib/' + [string]$pcPf.Name); Lines = @([System.IO.File]::ReadAllLines([string]$pcPf.FullName)) })
    }
    $pcFaceLines = 0
    foreach ($pcPf in @($pcProdFace)) { $pcFaceLines += @($pcPf.Lines).Count }
    # The handler body is located IN THE FACE, not in $codeLines. $codeLines is the ENTRY: after
    # the CU-OPS-464 handler split the read handlers live in lib/handlers-read.ps1, so a scan of
    # the entry alone finds no 'function Invoke-Handler-pt-calibrate' and returns an EMPTY body -
    # and an empty body contains no input API, so every needle counted over it reads as clean.
    # That is the vacuous-ruler shape this suite has been bitten by before, and here it was the
    # shape of four red gates plus one green gate that should have been red.
    # !! The first repair of that bug was ITSELF a vacuous ruler, and this is the shape it made:
    # writing the test as [string]$lines[$i].StartsWith($mark) does not cast the element and then
    # call the method - the cast takes the WHOLE member-access expression, so the condition is the
    # string 'True' or 'False', and a non-empty string is truthy in PowerShell. Every line of every
    # face file matched, the last file won, and the "body" was one stray line out of a selftest
    # file. The boolean is therefore taken from the string method with no cast on the condition,
    # every match is COLLECTED rather than overwritten (so a second copy is a count of 2, not a
    # silent last-one-wins), and the located extent is named and numbered.
    $pcHFn = -1
    $pcBody = @()
    $pcBodyTxt = ''
    $pcBodyFile = ''
    $pcBodyHits = @()
    $pcBodyMark = 'function Invoke-' + 'Handler-pt-calibrate'
    foreach ($pcPf in @($pcProdFace)) {
      $plines = @($pcPf.Lines)
      for ($pi = 0; $pi -lt $plines.Count; $pi++) {
        if ($plines[$pi].StartsWith($pcBodyMark)) {
          $pcBodyHits += ([string]$pcPf.Name + ':' + ($pi + 1))
          $pcHFn = $pi
          $pcBodyFile = [string]$pcPf.Name
          $pcEnd = $plines.Count
          for ($pj = $pi + 1; $pj -lt $plines.Count; $pj++) {
            if ($plines[$pj].StartsWith('function ')) { $pcEnd = $pj; break }
          }
          $pcBody = @($plines[$pi..($pcEnd - 1)])
          $pcBodyTxt = ($pcBody -join "`n")
        }
      }
    }
    $pcEstDefs = @()
    $pcEstCalls = @()
    $pcSurfDefs = @()
    $pcSurfCalls = @()
    $pcNoPrefix = @()
    $pcPrefixNames = @('pt-anchor', 'pt-calibrate', 'pt-profile')
    $pcDefMark = 'function Get-Pt' + 'Calibration'
    $pcCallMark = '= Get-Pt' + 'Calibration '
    $pcSurfDefMark = 'function Get-Pt' + 'SurfaceRead'
    $pcSurfCallMark = '= Get-Pt' + 'SurfaceRead '
    $pcLoadMark = 'Import-Pt' + 'Profile'
    foreach ($pcPf in @($pcProdFace)) {
      $plN = 0
      foreach ($plt in @($pcPf.Lines)) {
        $plN++
        $plt = [string]$plt
        if ($plt -match '^\s*#') { continue }
        if ($plt.StartsWith($pcDefMark)) { $pcEstDefs += ($pcPf.Name + ':' + $plN) }
        if ($plt.Contains($pcCallMark)) { $pcEstCalls += ($pcPf.Name + ':' + $plN) }
        if ($plt.StartsWith($pcSurfDefMark)) { $pcSurfDefs += ($pcPf.Name + ':' + $plN) }
        if ($plt.Contains($pcSurfCallMark)) { $pcSurfCalls += ($pcPf.Name + ':' + $plN) }
        if (-not $plt.Contains($pcLoadMark)) { continue }
        if ($plt.StartsWith('function ' + $pcLoadMark)) { continue }
        $pcTail = $plt.Substring($plt.IndexOf($pcLoadMark) + $pcLoadMark.Length)
        $pcHasName = $false
        foreach ($pcpn in $pcPrefixNames) { if ($pcTail.Contains("'" + $pcpn + "'")) { $pcHasName = $true } }
        if (-not $pcHasName) { $pcNoPrefix += ($pcPf.Name + ':' + $plN + ': ' + $plt.Trim()) }
      }
    }
    # teeth: the same predicates over a planted fixture - one extra definition, one extra call
    # site and one bare loader call must each be counted, or the three checks below are needle
    # counts over a face that happens to be clean.
    # !! Every element below is parenthesized ON PURPOSE. A bare expression followed by a comma at
    # end of line inside @() does NOT continue the array - the comma binds into the addition, the
    # "array" comes out as ONE element (every line concatenated by the $OFS space), and the teeth
    # loop then counts a fixture that was never the one written: teethSurf and teethBare measured 0
    # against a fixture that reads as seven lines in the source (b-wip-r1, 2026-10-30). Plain string
    # literals do continue, which is why the shape looks right and counts wrong.
    $pcTeeth = @(@{ Name = 'fixture'; Lines = @(
      ($pcDefMark + ' {'),
      ('  ' + $pcCallMark + '-Estimates @()'),
      ($pcSurfDefMark + '($a,$b,$c) {'),
      ('  $x = ' + $pcSurfCallMark + '$p "" "o"'),
      ('  $y = ' + $pcLoadMark + ' $path'),
      ('  $z = ' + $pcLoadMark + ' $path ''pt-calibrate'''),
      ('#' + $pcLoadMark + ' a comment mentioning the loader')
    ) })
    $pcTeethEst = 0
    $pcTeethCall = 0
    $pcTeethSurf = 0
    $pcTeethBare = 0
    foreach ($pcPf in $pcTeeth) {
      foreach ($plt in @($pcPf.Lines)) {
        $plt = [string]$plt
        if ($plt -match '^\s*#') { continue }
        if ($plt.StartsWith($pcDefMark)) { $pcTeethEst++ }
        if ($plt.Contains($pcCallMark)) { $pcTeethCall++ }
        if ($plt.StartsWith($pcSurfDefMark)) { $pcTeethSurf++ }
        if (-not $plt.Contains($pcLoadMark)) { continue }
        if ($plt.StartsWith('function ' + $pcLoadMark)) { continue }
        $pcTail = $plt.Substring($plt.IndexOf($pcLoadMark) + $pcLoadMark.Length)
        $pcHasName = $false
        foreach ($pcpn in $pcPrefixNames) { if ($pcTail.Contains("'" + $pcpn + "'")) { $pcHasName = $true } }
        if (-not $pcHasName) { $pcTeethBare++ }
      }
    }
    ST-Check 'lint (B-1): the calibration estimator exists exactly once in the product face and is called from exactly one handler, the handler body is located in exactly one file with a numbered extent, and the same predicates count 1 definition, 1 call and 1 bare loader on a planted fixture (the ruler is not empty)' (
      (@($pcEstDefs).Count -eq 1) -and (@($pcEstCalls).Count -eq 1) -and ($pcHFn -ge 0) -and
      (@($pcBodyHits).Count -eq 1) -and (@($pcBody).Count -ge 100) -and ($pcBodyFile -ceq 'lib/handlers-read.ps1') -and
      (@($pcProdFace).Count -ge 6) -and ($pcTeethEst -eq 1) -and ($pcTeethCall -eq 1) -and ($pcTeethBare -eq 1))
    Write-Output ('      B-1 product face: files=' + (@($pcProdFace).Count) + ' lines=' + $pcFaceLines +
      ' estimator-def=[' + ($pcEstDefs -join ',') + '] estimator-call=[' + ($pcEstCalls -join ',') + ']' +
      ' handler-body=' + (@($pcBody).Count) + ' lines at [' + ($pcBodyHits -join ',') + ']')
    # the caller''s two knobs have to reach the estimator, and the refusal has to carry the numbers
    # it says it carries - judged on the handler source, because the leg that measures real
    # spacings off a real surface belongs to the OCR region below.
    ST-Check 'lint (B-1): the handler passes --min-spacing to -MinSpacing and --max-residual to -ResidualLimit and its refusal line carries both spacings, both axis ratios and the profile it read' (
      ($pcBodyTxt.Contains('-MinSpacing ([double]$minSpacing)')) -and
      ($pcBodyTxt.Contains('-ResidualLimit ([double]$maxResidual)')) -and
      ($pcBodyTxt.Contains(' spacing-basis=')) -and ($pcBodyTxt.Contains('px spacing-observed=')) -and
      ($pcBodyTxt.Contains('axis=(sx=')) -and ($pcBodyTxt.Contains("' profile='")) -and
      (-not ($pcBodyTxt.Replace('-MinSpacing ([double]$minSpacing)', '')).Contains('-MinSpacing ([double]$minSpacing)')))
    $pcInput = @(('Send' + 'Input'), ('mouse_' + 'event'), ('keybd_' + 'event'), ('Set-Cursor' + 'Position'), ('Move-' + 'Mouse'), ('Invoke-' + 'Handler-click'), ('Set-Foreground' + 'Window'), 'mouse_event')
    $pcInputHits = @($pcInput | Where-Object { $pcBodyTxt.Contains($_) })
    $pcTrig = @(([string]::Join('', @('[math]::', 'Sin'))), ([string]::Join('', @('[math]::', 'Cos'))), 'Math.Sin', 'Math.Cos')
    $pcTrigHits = @($pcTrig | Where-Object { $pcBodyTxt.Contains($_) })
    ST-Check 'lint (B-1): pt-calibrate is read-only by construction - its body contains no input API and no trigonometry, so it cannot click and cannot absorb a rotation' (
      (@($pcBody).Count -ge 60) -and (@($pcInputHits).Count -eq 0) -and (@($pcTrigHits).Count -eq 0))
    $pcPlantBody = ($pcBodyTxt + "`n" + ('  ' + 'Send' + 'Input 1 2') + "`n" + ('  ' + [string]::Join('', @('[math]::', 'Sin')) + ' 30'))
    ST-Check 'lint (B-1): the read-only and no-trigonometry scans flag a planted click call and a planted sine term in the same body (the two refusals they are supposed to be)' (
      (@(@($pcInput) | Where-Object { $pcPlantBody.Contains($_) }).Count -ge 1) -and
      (@(@($pcTrig) | Where-Object { $pcPlantBody.Contains($_) }).Count -ge 1))
    ST-Check 'lint (B-1): pt-calibrate is advertised as --json capable AND honors it, and the rectangle grammar has one producer that the handler actually calls' (
      (Test-JsonCapableCommand 'pt-calibrate') -and ($pcBodyTxt.Contains('script:Json')) -and
      (@(@($pcBody) | Where-Object { $_.Contains('= Parse-QuadSpec ') }).Count -eq 1) -and
      (@(@($pcBody) | Where-Object { $_.Contains('= Get-PtSurfaceRead ') }).Count -eq 1))
    ST-Check 'lint (B-1): the two PT readers share ONE surface read - one definition in the product face, called from exactly the two handlers, and the same predicate counts 1/1 on a planted copy (a duplicated window-resolution block is how one of them later lies about the other)' (
      (@($pcSurfDefs).Count -eq 1) -and (@($pcSurfCalls).Count -eq 2) -and
      ($pcTeethSurf -eq 1) -and (@($pcSurfDefs + $pcSurfCalls) -join ',' -match 'handlers-read'))
    # the loader call sites: every one must name the command whose error it is printing. The scan
    # covers the product face, because a NEW caller is exactly the thing that forgets the argument.
    ST-Check 'lint (B-1): every profile load in the product face names the command whose error it is printing (and the predicate flags a planted bare call while leaving a named one alone)' (
      (@($pcNoPrefix).Count -eq 0))
    if (@($pcNoPrefix).Count -gt 0) { Write-Output ('      loader call without a command name: ' + ($pcNoPrefix -join ' | ')) }
    # the contract text the answer owes the caller: units, both clocks, the region it applies to
    # and the sentence that says menus and toolbars are not covered.
    $pcContract = @()
    foreach ($pcNeedle in @('model=uniform-scale+translation', 'units=px', 'source: profile=', 'captured=', 'read-at=', 'applies-to:', 'menus, toolbars and child windows')) {
      if (-not $pcBodyTxt.Contains($pcNeedle)) { $pcContract += $pcNeedle }
    }
    ST-Check 'lint (B-1): the calibration answer carries model, units, source, both clocks and the applies-to region, and says out loud that menus and toolbars are not covered' (
      $pcContract -join '|' -eq '')
    if (@($pcContract).Count -gt 0) { Write-Output ('      missing contract text: ' + ($pcContract -join ', ')) }
    }
  } finally {
    Remove-Item -LiteralPath $pcDir -Recurse -Force -ErrorAction SilentlyContinue
  }
  # The OCR-dependent half lives in the region below; it is counted by name so a box without a
  # language pack loses those legs and says so, instead of quietly reporting a smaller suite.
  $script:StRecord = New-Object System.Collections.ArrayList
  if ($ocrPackTag -eq '') {
    ST-SkipRegion 'pt-calibrate' 'no OCR language pack / recognizer unreachable from this engine - the calibration road cannot be measured, so this is not a regression'
  } else {
  # REGION-BEGIN pt-calibrate
  $pcImgDir = Join-Path $env:TEMP ('st_ptcalimg_' + [guid]::NewGuid().ToString('N'))
  # pessimistic default: if anything below dies mid-run, the fixture directory is KEPT for
  # inspection rather than deleted by the finally (see that finally for the rest of the rule).
  $pcLegRed = $true
  New-Item -ItemType Directory -Force -Path $pcImgDir | Out-Null
  try {
    # 900x700, Consolas 28 Bold, three lines ~280-630px apart on BOTH axes for EVERY pair, labels
    # CAL-A / CAL-B / CAL-C. The label ALPHABET is measured, not taste - three shapes were tried and
    # rejected on this box (2026-10-30, five process reads each through the real pt-profile):
    #   11-char Latin (DTXCALBRAVO ...) - the recognizer truncated DTXCALBRAVO to 'DTXCALBR' in
    #     THREE OF THREE profile builds in one gate and THREE OF THREE again in another (b-wip-r1);
    #     a profile holding a truncated label makes every leg resolve to a different anchor than the
    #     geometry names.
    #   CJK 28pt YaHei (ding4-bu4-ji1-zhun3-xian4, five glyphs) - text read back 5/5 stable in
    #     isolation, but under gate load the last glyph once came back as its radical form and the
    #     proportional-glyph boxes jittered between processes enough to trip the 2% axis-ratio gate
    #     on a PURE TRANSLATION (b-wip-r2: sx=1.0126 sy=0.9531). Consolas boxes, by contrast, were
    #     pixel-identical 5/5 - and in b-wip-r1 the fit leg measured residual=0 even while its
    #     labels were truncated, so the monospace box is the stable half of this fixture. It stays;
    #     only the label text moves.
    #   digits ('67890' -> '6789e') and letter/digit mixes ('ABC-1' -> 'ABC-I') - deterministic
    #     misreads, and 'ROWA' collapsed to 'R 0 (' entirely. Rejected.
    # CAL-A survives every check: 5/5 identical text AND boxes across processes (measured via
    # pt-profile), the duplicate-paste surface reads BOTH same-ink rows as the same text 'CAL-A'
    # (measured via read-text --file: L01 and L03), and the trailing -A/-B/-C keep the three rows
    # unique so the profile never has to drop a duplicate.
    # GEOMETRY (1100x700, rows y=20/340/620, x=20/900/300): two measured constraints shaped it.
    # (a) The levers are LONG: the estimator's per-axis gate refuses at 2% divergence, and one
    #     pixel of box noise is 1/baseline of a percent - the first geometry (spans 630/320) let
    #     gate-context noise reach that fraction (b-wip-r3: sx=0.9813 on the displaced surface),
    #     so the x-stagger keeps every pair above 280px on both axes (top-mid 880/320).
    # (b) The ROW POSITIONS are ones the recognizer reads CLEAN. Windows OCR's line boxes on this
    #     machine are position-dependent: the D-1 block above measured a re-render at certain
    #     offsets inflating a 24px box to 36px and reporting y=57 for ink at y=39, and b-wip-r4
    #     measured the same disease at rows y=420/740 (a 1100x800 canvas: CAL-A's box came back
    #     at (0,73), CAL-B's at (914,387), CAL-C vanished - while the SAME construction read
    #     pixel-exact 3/3 from a console probe). The rows therefore stay at the y positions the
    #     D-1-era fixture measured clean, and the canvas does not grow: the displaced-row surface
    #     moves its row UP 40px inside the SAME canvas, because a taller canvas changed the
    #     recognizer's boxes on the estimate pair itself (b-wip-r3).
    # Every surface below was measured through the real pt-profile/pt-calibrate before being
    # pinned (probe-final-geom, 2026-10-30): A reads 3/3 identical boxes, B fits scale=1
    # delta=(4,9) ratios (1,1) residual=0, C refuses at exactly 40px and fits at 60 disclosing
    # the same 40, D refuses as not-on-this-surface with 2 lines read, E refuses as a duplicate.
    $pcW = 1100
    $pcH = 700
    $pcYs = @(20, 340, 620)
    # STAGGERED x, on purpose, and far enough apart that EVERY PAIR keeps a long lever on both
    # axes. An anchor record stores the OCR box TOP-LEFT, so three lines all drawn at one x give
    # a basis pair with dx=0 - and the estimator refuses such a pair (axis-degenerate: the
    # per-axis comparison that detects a non-uniform scale cannot run on a pair with no extent on
    # one axis). Refusing every leg of this region for a reason that has nothing to do with the
    # calibration would be a fixture bug wearing a product's clothes.
    $pcXs = @(20, 900, 300)
    $pcTexts = @('CAL-A', 'CAL-B', 'CAL-C')
    $pcRun = {
      param([string]$ArgLine, [string]$OutName)
      $o = Join-Path $pcImgDir $OutName
      $pr = Start-Process -FilePath 'powershell.exe' -ArgumentList $ArgLine -RedirectStandardOutput $o -RedirectStandardError "$o.err" -Wait -PassThru -NoNewWindow
      $txt = ''
      if (Test-Path -LiteralPath $o) { $txt += [IO.File]::ReadAllText($o) }
      if (Test-Path -LiteralPath "$o.err") { $txt += [IO.File]::ReadAllText("$o.err") }
      return @{ Exit = $pr.ExitCode; Txt = $txt }
    }
    # The five surfaces are rendered by a FRESH CHILD PROCESS, not by this one. Measured
    # (b-wip-r6): GDI+ text rendering is NOT process-state-independent - this family process has
    # already drawn dozens of fixtures (F-01, D-4, D-5, pt-anchor) by the time it gets here, and
    # its cal-a.png hashed 3FD34CD5... where a fresh process hashed B92DDE8D... for the SAME
    # DrawString calls; the shifted ink moved every OCR box by +(3,5), dropped E's duplicated row
    # entirely (read=3) and skewed C's boxes non-uniformly (sx=1.0239 sy=0.7875). A fresh child
    # has a clean typography state, so the bytes - and therefore the reads - match what the
    # probes measured. The geometry travels as a JSON parameter file; the script is a literal.
    $pcParamsPath = Join-Path $pcImgDir 'render-params.json'
    $pcRenderParams = @{ w = $pcW; h = $pcH; xs = $pcXs; ys = $pcYs; texts = $pcTexts; outDir = $pcImgDir } | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($pcParamsPath, $pcRenderParams, (New-Object System.Text.UTF8Encoding($false)))
    $pcRenderPath = Join-Path $pcImgDir 'render-fixture.ps1'
    $pcRenderSrc = @'
param([string]$Params)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$p = Get-Content -LiteralPath $Params -Raw -Encoding UTF8 | ConvertFrom-Json
function New-Canvas([int]$w, [int]$h) {
  $bm = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bm)
  $g.Clear([System.Drawing.Color]::White)
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  return @{ Bm = $bm; G = $g }
}
$fnt = New-Object System.Drawing.Font('Consolas', 28, [System.Drawing.FontStyle]::Bold)
$a = New-Canvas $p.w $p.h
for ($i = 0; $i -lt 3; $i++) { [void]$a.G.DrawString([string]$p.texts[$i], $fnt, [System.Drawing.Brushes]::Black, [single]$p.xs[$i], [single]$p.ys[$i]) }
$a.Bm.Save((Join-Path $p.outDir 'cal-a.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$b = New-Canvas $p.w $p.h
$b.G.DrawImage($a.Bm, 5, 9, $p.w, $p.h)
$b.Bm.Save((Join-Path $p.outDir 'cal-b.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$c = New-Canvas $p.w $p.h
$c.G.DrawImage($a.Bm, 5, 9, $p.w, $p.h)
[void]$c.G.FillRectangle([System.Drawing.Brushes]::White, 0, 600, $p.w, 80)
$dc = [System.Drawing.Rectangle]::new(5, 569, $p.w, 80)
$c.G.DrawImage($a.Bm, $dc, 0, 600, $p.w, 80, [System.Drawing.GraphicsUnit]::Pixel)
$c.Bm.Save((Join-Path $p.outDir 'cal-c.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$e = New-Canvas $p.w ($p.h + 100)
$e.G.DrawImage($a.Bm, 5, 9, $p.w, $p.h)
$de = [System.Drawing.Rectangle]::new(5, 480, $p.w, 60)
$e.G.DrawImage($a.Bm, $de, 0, 0, $p.w, 60, [System.Drawing.GraphicsUnit]::Pixel)
$e.Bm.Save((Join-Path $p.outDir 'cal-e.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$d = New-Canvas $p.w $p.h
$d.G.DrawImage($a.Bm, 0, 0, $p.w, $p.h)
[void]$d.G.FillRectangle([System.Drawing.Brushes]::White, 0, 0, $p.w, 70)
$d.Bm.Save((Join-Path $p.outDir 'cal-d.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$fnt.Dispose()
foreach ($k in @($a, $b, $c, $e, $d)) { try { $k.G.Dispose(); $k.Bm.Dispose() } catch { } }
Write-Output ('rendered 5 surfaces')
'@
    [System.IO.File]::WriteAllText($pcRenderPath, $pcRenderSrc, (New-Object System.Text.UTF8Encoding($true)))
    $pcRendered = & $pcRun ('-NoProfile -ExecutionPolicy Bypass -File "' + $pcRenderPath + '" "' + $pcParamsPath + '"') 'render.txt'
    $pcPngA = Join-Path $pcImgDir 'cal-a.png'
    $pcPngB = Join-Path $pcImgDir 'cal-b.png'
    $pcPngC = Join-Path $pcImgDir 'cal-c.png'
    $pcPngE = Join-Path $pcImgDir 'cal-e.png'
    $pcPngD = Join-Path $pcImgDir 'cal-d.png'
    $pcMissing = @(@('cal-a.png', 'cal-b.png', 'cal-c.png', 'cal-d.png', 'cal-e.png') | Where-Object { -not (Test-Path -LiteralPath (Join-Path $pcImgDir $_)) })
    # B is A translated by exactly (+5,+9) through DrawImage inside the child (a re-render puts
    # the line box in a zone where Windows OCR inflates it, measured in the D-1 block above);
    # C moves ONLY the third line 40px UP on a canvas the SAME SIZE as A and B (609-569 = 40,
    # band arithmetic - a taller canvas changed the recognizer's boxes on the estimate pair
    # itself, measured b-wip-r3); E duplicates the top row at 480..539; D erases it entirely.
    # Byte hashes of the five surfaces, printed every run: the gate-context reads of the special
    # surfaces have differed from console probes of the same construction, and this line is what
    # decides whether the difference is in the RENDER (hashes differ) or in the READ (they match).
    $pcHashLine = { param([string]$p) $h = [System.Security.Cryptography.SHA256]::Create(); try { $fs = [System.IO.File]::OpenRead($p); try { return ([System.BitConverter]::ToString($h.ComputeHash($fs))).Replace('-', '').Substring(0, 16) } finally { $fs.Dispose() } } finally { $h.Dispose() } }
    Write-Output ('      B-1 fixture render: exit=' + $pcRendered.Exit + ' missing=[' + ($pcMissing -join ',') + '] hashes: a=' + (& $pcHashLine $pcPngA) + ' b=' + (& $pcHashLine $pcPngB) + ' c=' + (& $pcHashLine $pcPngC) + ' d=' + $(if (Test-Path -LiteralPath $pcPngD) { & $pcHashLine $pcPngD } else { '-' }) + ' e=' + $(if (Test-Path -LiteralPath $pcPngE) { & $pcHashLine $pcPngE } else { '-' }))
    # A leg that reads a SURFACE is at the mercy of the recognizer, not of the product (see the
    # profile-build note below: the same bytes came out with one label truncated in one read out of
    # ten). The legs therefore re-RUN the same command up to three times and stop as soon as the
    # OUTCOME THEY INTEND TO MEASURE happens, and every one of them asserts the full text of that
    # outcome, not just the exit code - so this is a retry of the environment read and not a vote on
    # the product's behaviour: break the duplicate check and all three attempts fit, break the fit
    # and all three refuse. The attempt count is printed for each leg: a suite that quietly needed
    # three of every three is a suite whose fixture has stopped holding still, and that has to be
    # visible rather than absorbed.
    $pcTry = {
      param([string]$ArgLine, [string]$OutName, [scriptblock]$Want)
      $res = $null
      $tries = 0
      for ($tt = 1; $tt -le 3; $tt++) {
        $tries = $tt
        $res = & $pcRun $ArgLine ($OutName + '.' + $tt + '.txt')
        if (& $Want $res) { break }
      }
      return @{ Exit = $res.Exit; Txt = $res.Txt; Tries = $tries }
    }
    $pcProfPath = Join-Path $pcImgDir 'cal-profile.json'
    # WHICH INDEX IS WHICH ROW is not something this fixture may assume. The profile stores the
    # recognizer's own row order, and the same drawing came out BRAVO/ALPHA/CHARLIE in one process
    # and with CHARLIE first in another (measured 2026-10-30), so a leg that hard-codes
    # '--estimate 1,2' points at an arbitrary pair - and which pair it lands on decides the
    # baseline length, which decides whether the fit is measurable at all. The rows are therefore
    # named by GEOMETRY (top / middle / bottom of the basis column, which IS what the fixture
    # controls) and the numbering the caller has to type is read back out of '--list'. The premise
    # check below is the tooth: it fails out loud when the recognizer cannot read the three labels,
    # instead of letting a later leg refuse for a reason that has nothing to do with calibration.
    # The BUILD is what gets retried, not the verdict. Measured 2026-10-30 on this fixture: nine
    # clean process reads of cal-a.png returned all three labels and one returned 'DTXCALBR' for
    # BRAVO - the recognizer is not perfectly repeatable across processes, and a profile holding a
    # truncated label makes every leg below resolve to a different anchor than the geometry names.
    # Retrying the environment read is not retrying the product: nothing here decides a product
    # outcome by repetition (each leg below asserts the full refusal TEXT), the attempt count is
    # printed for every leg, and a suite that needed 3 of 3 builds is visible in the output.
    $pcProfBuilds = 0
    $pcProfLabels = ''
    $pcRows = @()
    $pcListOut = $null
    $pcP1 = $null
    for ($pa = 1; $pa -le 3; $pa++) {
      $pcProfBuilds = $pa
      if (Test-Path -LiteralPath $pcProfPath) { Remove-Item -LiteralPath $pcProfPath -Force }
      $pcP1 = & $pcRun ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-profile --file "' + $pcPngA + '" --save "' + $pcProfPath + '"') ('profile-' + $pa + '.txt')
      if ($pcP1.Exit -ne 0) { continue }
      $pcListOut = & $pcRun ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-calibrate "' + $pcProfPath + '" --list') ('cal-list-' + $pa + '.txt')
      $pcRows = @()
      foreach ($pl in @(($pcListOut.Txt -split "`n"))) {
        $pm = [regex]::Match([string]$pl, '^\s*#([0-9]+) ''(.*)'' at \((-?[0-9]+),(-?[0-9]+)\)')
        if ($pm.Success) {
          $pcRows += [pscustomobject]@{
            Idx = [int]$pm.Groups[1].Value; Lab = [string]$pm.Groups[2].Value
            Bx = [int]$pm.Groups[3].Value; By = [int]$pm.Groups[4].Value
          }
        }
      }
      $pcProfLabels = (@(@($pcRows) | ForEach-Object { $_.Lab }) -join ',')
      # Label equality goes through the same fold the product's matcher uses: the recognizer spaces
      # CJK deterministically but the stored label is the RAW spaced read, so comparing raw to the
      # drawn (unspaced) text would never hold even when every glyph came back right.
      if ((@($pcRows).Count -eq 3) -and
        ((@(@($pcRows) | ForEach-Object { Normalize-OcrText ([string]$_.Lab) }) | Sort-Object) -join ',') -ceq ((@($pcTexts) | Sort-Object) -join ',')) { break }
    }
    ST-Check 'e2e (B-1): the calibration runs on a profile that a real surface read produced, not on a hand-written one (3 anchors, unique labels, no OCR merging them)' (
      ($pcP1.Exit -eq 0) -and (Test-Path -LiteralPath $pcProfPath) -and
      (@(Get-OptValue (Import-PtProfile $pcProfPath 'pt-calibrate') 'anchors').Count -eq 3))
    if ($pcP1.Exit -ne 0) { Write-Output ('      B-1 profile leg: ' + $pcP1.Txt) }
    $pcByY = @(@($pcRows) | Sort-Object By)
    $pcTop = $null; $pcMid = $null; $pcBot = $null
    if (@($pcByY).Count -eq 3) { $pcTop = $pcByY[0]; $pcMid = $pcByY[1]; $pcBot = $pcByY[2] }
    $pcEM = ''
    $pcV = ''
    if ($null -ne $pcTop) { $pcEM = [string]$pcTop.Idx + ',' + [string]$pcMid.Idx; $pcV = [string]$pcBot.Idx }
    $pcEM2 = ''
    if ($null -ne $pcTop) { $pcEM2 = [string]$pcMid.Idx + ',' + [string]$pcBot.Idx }
    # Read once, into plain strings: the legs below are inside Set-StrictMode -Version Latest, where
    # a property access on a $null variable THROWS and would abort the whole family instead of
    # failing one check. When the preflight has no rows these are empty, which makes every leg
    # refuse - a red leg, which is the honest outcome, not a crash.
    $pcTopLab = ''
    $pcBotLab = ''
    $pcTopIdx = ''
    $pcBotIdx = -1
    if ($null -ne $pcTop) { $pcTopLab = [string]$pcTop.Lab }
    if ($null -ne $pcBot) { $pcBotLab = [string]$pcBot.Lab }
    if ($null -ne $pcTop) { $pcTopIdx = [string]$pcTop.Idx }
    if ($null -ne $pcBot) { $pcBotIdx = [int]$pcBot.Idx }
    ST-Check 'preflight (B-1): the anchor numbering the legs type is read back from --list and the three rows are named by geometry, with the labels the fixture drew on the row that geometry holds' (
      (@($pcRows).Count -eq 3) -and ($null -ne $pcTop) -and
      ((Normalize-OcrText ([string]$pcTop.Lab)) -ceq (Normalize-OcrText ([string]$pcTexts[0]))) -and
      ((Normalize-OcrText ([string]$pcMid.Lab)) -ceq (Normalize-OcrText ([string]$pcTexts[1]))) -and
      ((Normalize-OcrText ([string]$pcBot.Lab)) -ceq (Normalize-OcrText ([string]$pcTexts[2]))) -and
      ((@(@($pcRows) | ForEach-Object { $_.Idx }) | Sort-Object) -join ',') -eq '1,2,3' -and
      ($pcTop.By -lt $pcMid.By) -and ($pcMid.By -lt $pcBot.By) -and
      ([math]::Abs($pcTop.Bx - $pcMid.Bx) -gt 250) -and ([math]::Abs($pcMid.Bx - $pcBot.Bx) -gt 250) -and
      ([math]::Abs($pcTop.Bx - $pcBot.Bx) -gt 250))
    if (@($pcRows).Count -ne 3) { Write-Output ('      B-1 preflight read ' + (@($pcRows).Count) + ' anchor row(s) from --list: [' + $pcListOut.Txt + ']') }
    Write-Output ('      B-1 anchor numbering: profile-build(s)=' + $pcProfBuilds + ' of 3 labels=[' + $pcProfLabels +
      '] top=#' + $(if ($null -ne $pcTop) { $pcTop.Idx } else { '-' }) + ' mid=#' +
      $(if ($null -ne $pcMid) { $pcMid.Idx } else { '-' }) + ' bot=#' + $(if ($null -ne $pcBot) { $pcBot.Idx } else { '-' }) +
      ' estimate=' + $pcEM + ' verify=' + $pcV)
    # (16) the translation read as a calibration. The INK is a pure (+5,+9) paste of the same
    # bitmap; what the estimator receives is the recognizer's BOXES, and those do not translate
    # exactly: the box for the shifted copy snaps its left edge one pixel wider (measured 6/6
    # identical via pt-profile: every B box is A + (4,9) with width +1), and the wobble is
    # CONTEXT-dependent - a console probe measured delta exactly (4,9) while the same fixture
    # inside a gate run measured delta=(5.531,9.019) (b-wip-r3). Pinning exact integers would
    # therefore assert one context's quantization and go red in the other. The bands below are
    # sized to that measured wobble with headroom and are NOT a general tolerance: they still
    # refuse a broken estimator (a wrong scale by >1%, a translation off by >2px on either axis,
    # a per-axis ratio past the product's own 2% gate, spacings that disagree by >2px, or a
    # residual above 3px on a surface that obeys the model).
    $pcC1 = & $pcTry ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-calibrate "' + $pcProfPath + '" --estimate ' + $pcEM + ' --verify ' + $pcV + ' --file "' + $pcPngB + '" --max-residual 8') 'cal-fit' { param($r) $r.Exit -eq 0 }
    $pcScale1 = -1.0
    $pcDx1 = 999
    $pcDy1 = 999
    $pcSx1 = -1.0
    $pcSy1 = -1.0
    $pcSpB1 = -1.0
    $pcSpO1 = -1.0
    $pcResFit = -1.0
    if ($pcC1.Txt -match 'scale=([0-9.]+) delta=\((-?[0-9.]+),(-?[0-9.]+)\)') { $pcScale1 = [double]$Matches[1]; $pcDx1 = [double]$Matches[2]; $pcDy1 = [double]$Matches[3] }
    if ($pcC1.Txt -match 'axis-ratios=\(sx=([0-9.]+),sy=([0-9.]+)\)') { $pcSx1 = [double]$Matches[1]; $pcSy1 = [double]$Matches[2] }
    if ($pcC1.Txt -match 'spacing-basis=([0-9.]+)px spacing-observed=([0-9.]+)px') { $pcSpB1 = [double]$Matches[1]; $pcSpO1 = [double]$Matches[2] }
    if ($pcC1.Txt -match 'residual-max=([0-9.]+)px') { $pcResFit = [double]$Matches[1] }
    ST-Check 'e2e (B-1): a surface translated by exactly (+5,+9) calibrates to scale ~1, delta within two pixels of the drawn (5,9), axis ratios inside 1.5% of 1, spacings agreeing within 2px and residual under 3px, with verdict=fit and both clocks UTC' (
      ($pcC1.Exit -eq 0) -and ($pcC1.Txt.Contains('model=uniform-scale+translation')) -and
      ([math]::Abs($pcScale1 - 1.0) -le 0.01) -and ([math]::Abs($pcDx1 - 5) -le 2) -and ([math]::Abs($pcDy1 - 9) -le 1.5) -and
      ([math]::Abs($pcSx1 - 1.0) -le 0.015) -and ([math]::Abs($pcSy1 - 1.0) -le 0.015) -and
      ($pcResFit -le 3) -and ($pcSpB1 -gt 500) -and ([math]::Abs($pcSpO1 - $pcSpB1) -le 2) -and
      ($pcC1.Tries -ge 1) -and
      ($pcC1.Txt.Contains('verdict=fit')) -and ($pcC1.Txt.Contains('units=px')) -and
      ($pcC1.Txt -match 'captured=\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC read-at=\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC'))
    if ($pcC1.Exit -ne 0) { Write-Output ('      B-1 fit leg: attempts=' + $pcC1.Tries + ' exit=' + $pcC1.Exit + ' out=[' + $pcC1.Txt + ']') }
    if ($pcC1.Exit -eq 0) { Write-Output ('      B-1 fit measured: attempts=' + $pcC1.Tries + ' scale=' + $pcScale1 + ' delta=(' + $pcDx1 + ',' + $pcDy1 + ') axis=(' + $pcSx1 + ',' + $pcSy1 + ') spacing=' + $pcSpB1 + '/' + $pcSpO1 + ' residual=' + $pcResFit) }
    # (17) the negative that pays for the whole command: ONE independent anchor 40px off makes the
    # answer a refusal, at a limit the SAME geometry clears when raised - so the knob is what is
    # being proved and both sides run. The drawn displacement is exactly 40px and the residual is
    # measured on recognizer boxes, so the number is asserted within +-2px of the drawn truth (the
    # same box wobble the fit leg bands) and the verify row is checked to QUOTE a number, not to
    # quote one specific rendering of it.
    $pcC2 = & $pcTry ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-calibrate "' + $pcProfPath + '" --estimate ' + $pcEM + ' --verify ' + $pcV + ' --file "' + $pcPngC + '" --max-residual 10') 'cal-exceeded' { param($r) ($r.Exit -ne 0) -and $r.Txt.Contains('refused (residual-exceeded)') }
    $pcC3 = & $pcTry ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-calibrate "' + $pcProfPath + '" --estimate ' + $pcEM + ' --verify ' + $pcV + ' --file "' + $pcPngC + '" --max-residual 60') 'cal-loose' { param($r) $r.Exit -eq 0 }
    $pcRes2 = -1.0
    if ($pcC2.Txt -match 'residual-max=([0-9.]+)px') { $pcRes2 = [double]$Matches[1] }
    $pcRes3 = -1.0
    if ($pcC3.Txt -match 'residual-max=([0-9.]+)px') { $pcRes3 = [double]$Matches[1] }
    ST-Check 'e2e (B-1): one independent anchor displaced 40px is refused at --max-residual 10 quoting a residual within 2px of 40 and reporting no conversion, and the same geometry fits at 60 with that same residual disclosed' (
      ($pcC2.Exit -ne 0) -and ($pcC2.Txt.Contains('refused (residual-exceeded)')) -and
      ($pcRes2 -ge 38) -and ($pcRes2 -le 42) -and ($pcC2.Txt.Contains('no conversion is reported')) -and
      ($pcC2.Txt -match ("verify='" + [regex]::Escape($pcBotLab) + "'=[0-9.]+px")) -and
      ($pcC3.Exit -eq 0) -and ($pcC3.Txt.Contains('verdict=fit')) -and ($pcRes3 -ge 38) -and ($pcRes3 -le 42) -and
      ($pcC2.Tries -ge 1) -and ($pcC3.Tries -ge 1))
    if ($pcC2.Exit -eq 0) { Write-Output ('      B-1 exceeded leg did NOT refuse: attempts=' + $pcC2.Tries + ' out=[' + $pcC2.Txt + ']') }
    if ($pcC3.Exit -ne 0) { Write-Output ('      B-1 loose leg refused at 60px: attempts=' + $pcC3.Tries + ' out=[' + $pcC3.Txt + ']') }
    Write-Output ('      B-1 residual legs: exceeded attempts=' + $pcC2.Tries + ' residual=' + $pcRes2 + ' loose attempts=' + $pcC3.Tries + ' residual=' + $pcRes3)
    # (18) an anchor that is not on the surface at all, and a text that matches two rows: both
    # refusals, neither a pick. Which index names the top row is decided by the preflight above
    # (geometry, read back from --list), never by a number written here - the recognizer sorts the
    # rows its own way and a leg that hard-coded that order would fail for a reason that is not
    # the product's. Here the estimate pair is middle+bottom so the erased/duplicated TOP row is
    # always the independent anchor. BOTH refusal legs print their last attempt UNCONDITIONALLY:
    # a leg that refused for the WRONG reason used to be visible only as a count of zero.
    $pcC4 = & $pcTry ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-calibrate "' + $pcProfPath + '" --estimate ' + $pcEM2 + ' --verify ' + $pcTopIdx + ' --file "' + $pcPngD + '"') 'cal-absent' { param($r) ($r.Exit -ne 0) -and $r.Txt.Contains('is not on this surface on re-read') }
    $pcC5 = & $pcTry ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-calibrate "' + $pcProfPath + '" --estimate ' + $pcEM2 + ' --verify ' + $pcTopIdx + ' --file "' + $pcPngE + '"') 'cal-duprow' { param($r) ($r.Exit -ne 0) -and $r.Txt.Contains(' rows on the current surface') }
    $pcDupCount = 0
    if ($pcC5.Txt -match 'matches ([0-9]+) rows on the current surface') { $pcDupCount = [int]$Matches[1] }
    ST-Check 'e2e (B-1): an anchor erased from the surface is refused as not-on-this-surface (naming how many lines were read), and a surface carrying the same line twice is refused as a duplicate rather than resolved by loop order' (
      ($pcC4.Exit -ne 0) -and ($pcC4.Txt -match ("anchor #[0-9]+ \('" + [regex]::Escape($pcTopLab) + "'\) is not on this surface on re-read \(2 line\(s\) read\)")) -and
      ($pcC5.Exit -ne 0) -and ($pcC5.Txt -match ("anchor #[0-9]+ \('" + [regex]::Escape($pcTopLab) + "'\) matches [0-9]+ rows on the current surface")) -and
      ($pcDupCount -ge 2) -and ($pcC4.Tries -ge 1) -and ($pcC5.Tries -ge 1))
    Write-Output ('      B-1 refusal legs (always printed): absent attempts=' + $pcC4.Tries + ' exit=' + $pcC4.Exit + ' dup attempts=' + $pcC5.Tries + ' exit=' + $pcC5.Exit)
    Write-Output ('      B-1 absent leg last attempt: [' + $pcC4.Txt + ']')
    Write-Output ('      B-1 dup leg last attempt: [' + $pcC5.Txt + ']')
    Write-Output ('      B-1 ambiguity legs: absent attempts=' + $pcC4.Tries + ' dup attempts=' + $pcC5.Tries + ' rows-matching-the-duplicated-anchor=' + $pcDupCount)
    # (19) --relocate converts ONE named point and says so, and the number it prints is the model
    # the fit just reported (scale*basis+delta) - asserted AGAINST THE SAME HEADER LINE, not
    # against constants: the drawn answer depends on the recognizer's box quantization (see leg
    # 16), but whatever scale and delta the fit reported, the relocate of (100,200) must be
    # exactly scale*100+dx and scale*200+dy, with the rounded ints within half a pixel of the
    # floats they came from.
    $pcC6 = & $pcTry ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-calibrate "' + $pcProfPath + '" --estimate ' + $pcEM + ' --verify ' + $pcV + ' --file "' + $pcPngB + '" --max-residual 8 --canvas 0,0,300,200 --relocate 100,200') 'cal-reloc' { param($r) $r.Exit -eq 0 }
    $pcRs = -1.0
    $pcRdx = 999
    $pcRdy = 999
    $pcRx = -1.0
    $pcRy = -1.0
    $pcRrx = -1.0
    $pcRry = -1.0
    if ($pcC6.Txt -match 'relocate: \(100,200\) -> \(([-0-9.]+),([-0-9.]+)\) rounded=\(([-0-9.]+),([-0-9.]+)\)') { $pcRx = [double]$Matches[1]; $pcRy = [double]$Matches[2]; $pcRrx = [double]$Matches[3]; $pcRry = [double]$Matches[4] }
    if ($pcC6.Txt -match '^pt-calibrate: model=uniform-scale\+translation scale=([0-9.]+) delta=\((-?[0-9.]+),(-?[0-9.]+)\)') { $pcRs = [double]$Matches[1]; $pcRdx = [double]$Matches[2]; $pcRdy = [double]$Matches[3] }
    $pcWant = $pcRs * 100 + $pcRdx
    $pcWantY = $pcRs * 200 + $pcRdy
    ST-Check 'e2e (B-1): --relocate converts exactly the point asked for - the floats equal scale*point+delta from the same header line and the rounded ints sit within half a pixel of those floats - and --canvas scopes the applies-to answer' (
      ($pcC6.Exit -eq 0) -and ([math]::Abs($pcRx - $pcWant) -le 0.01) -and ([math]::Abs($pcRy - $pcWantY) -le 0.01) -and
      ([math]::Abs($pcRrx - $pcRx) -le 0.5) -and ([math]::Abs($pcRry - $pcRy) -le 0.5) -and
      ($pcC6.Txt.Contains('applies-to: canvas=(0,0,300,200) declared with --canvas')) -and
      ($pcC6.Txt.Contains('menus, toolbars and child windows are not covered by it')))
    if ($pcC6.Exit -ne 0) { Write-Output ('      B-1 relocate leg: out=[' + $pcC6.Txt + ']') }
    # (20) the machine-readable face carries the same numbers, including each verify anchor's OWN
    # index (the field a caller needs to point back at --list). --json goes AFTER the command name,
    # which is the position every other leg of this suite and the usage line use: a leading --json
    # is eaten by PowerShell's own -File parameter binding and never reaches $Cmd (measured
    # 2026-10-30 - `--json ocr-cap` ran as `help` and refused against 'help').
    $pcC7 = & $pcTry ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-calibrate "' + $pcProfPath + '" --estimate ' + $pcEM + ' --verify ' + $pcV + ' --file "' + $pcPngB + '" --max-residual 8 --json') 'cal-json' { param($r) $r.Exit -eq 0 }
    $pcJO = $null
    # The JSON line is selected BY SHAPE (starts with '{'), not by position: $pcRun appends the
    # child's stderr after its stdout, and INC-03 kept the caller-identity warning on stderr, so
    # the last non-empty line of every healthy run is that warning - taking Last-1 parsed the
    # warning and reported the leg 'unparseable' forever (b-wip-r1, 2026-10-30).
    try { $pcJO = ($pcC7.Txt -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -Last 1) | ConvertFrom-Json } catch { }
    $pcJdx = 999.0
    $pcJdy = 999.0
    $pcJsx = -1.0
    $pcJsy = -1.0
    if ($null -ne $pcJO) {
      if (@(@($pcJO.delta)).Count -eq 2) { $pcJdx = [double](@($pcJO.delta))[0]; $pcJdy = [double](@($pcJO.delta))[1] }
      if (@(@($pcJO.axis_ratios)).Count -eq 2) { $pcJsx = [double](@($pcJO.axis_ratios))[0]; $pcJsy = [double](@($pcJO.axis_ratios))[1] }
    }
    ST-Check 'e2e (B-1): --json emits model, units, scale ~1, delta banded around the drawn (5,9), both spacings equal within 2px, axis ratios inside 1.5% of 1, the default floor, verdict=fit and a verify row that carries its own index, label and a residual under 3px' (
      ($pcC7.Exit -eq 0) -and ($null -ne $pcJO) -and ($pcJO.model -ceq 'uniform-scale+translation') -and
      ($pcJO.units -ceq 'px') -and ($pcJO.verdict -ceq 'fit') -and ([math]::Abs([double]$pcJO.scale - 1) -le 0.01) -and
      ([math]::Abs($pcJdx - 5) -le 2) -and ([math]::Abs($pcJdy - 9) -le 1.5) -and
      ([math]::Abs($pcJsx - 1) -le 0.015) -and ([math]::Abs($pcJsy - 1) -le 0.015) -and
      ([math]::Abs((([double](@($pcJO.spacing))[0]) - ([double](@($pcJO.spacing))[1]))) -le 2) -and (@(@($pcJO.spacing)).Count -eq 2) -and
      ($pcJO.min_spacing -eq 20) -and ([double]$pcJO.residual_max -le 3) -and (@(@($pcJO.estimate)).Count -eq 2) -and
      (@(@($pcJO.verify)).Count -eq 1) -and (@(@($pcJO.verify))[0].index -eq $pcBotIdx) -and
      (@(@($pcJO.verify))[0].label -ceq $pcBotLab) -and ([double](@(@($pcJO.verify))[0].residual) -le 3) -and
      (@(@($pcJO.source)).Count -eq 1) -and ($pcJO.source.image -ceq $pcPngB) -and ($pcJO.source.lines -eq 3))
    if ($null -eq $pcJO) { Write-Output ('      B-1 json leg unparseable: attempts=' + $pcC7.Tries + ' out=[' + $pcC7.Txt + ']') }
    if ($null -ne $pcJO) { Write-Output ('      B-1 json leg: attempts=' + $pcC7.Tries + ' verify index=' + [string](@(@($pcJO.verify))[0].index) + ' label=' + [string](@(@($pcJO.verify))[0].label) + ' spacing=' + (@($pcJO.spacing) -join '/') ) }
    # (21) the baseline floor measured off a REAL surface. The offline legs can only prove the flag
    # is wired (they never reach a surface read, so they cannot produce a spacing at all): here the
    # number that decides the refusal comes out of OCR, and the measured baseline is the drawn
    # top/mid lever (sqrt(880^2+320^2) = 936.376px, and the probe measured EXACTLY that on both
    # sides) - above the default floor of 20, below 4000. Both sides of the knob run, and the
    # refusal quotes BOTH spacings with their units: "too close" without the measurement is a
    # verdict nobody can check afterwards.
    $pcC8 = & $pcTry ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-calibrate "' + $pcProfPath + '" --estimate ' + $pcEM + ' --verify ' + $pcV + ' --file "' + $pcPngB + '" --min-spacing 4000') 'cal-floor' { param($r) ($r.Exit -ne 0) -and $r.Txt.Contains('refused (basis-degenerate)') }
    $pcC9 = & $pcTry ('-NoProfile -ExecutionPolicy Bypass -File "' + $self + '" pt-calibrate "' + $pcProfPath + '" --estimate ' + $pcEM + ' --verify ' + $pcV + ' --file "' + $pcPngB + '" --min-spacing 20') 'cal-floor-ok' { param($r) $r.Exit -eq 0 }
    $pcFB = -1.0
    $pcFO = -1.0
    if ($pcC8.Txt -match 'spacing-basis=([0-9.]+)px spacing-observed=([0-9.]+)px') { $pcFB = [double]$Matches[1]; $pcFO = [double]$Matches[2] }
    ST-Check 'e2e (B-1): the real sub-1000px baseline this fixture draws is refused by --min-spacing 4000 quoting both spacings in px, and accepted at a floor below it (the knob, both sides, measured not assumed)' (
      ($pcC8.Exit -ne 0) -and ($pcC8.Txt.Contains('refused (basis-degenerate)')) -and
      ($pcC8.Txt.Contains('floor --min-spacing 4000')) -and ($pcFB -gt 500) -and ($pcFB -lt 4000) -and
      ([math]::Abs($pcFO - $pcFB) -le 2) -and ($pcC8.Txt.Contains("estimate anchors are " + $pcFB + "px apart in the profile")) -and
      ($pcC9.Exit -eq 0) -and ($pcC9.Txt.Contains('verdict=fit')) -and ($pcC8.Tries -ge 1) -and ($pcC9.Tries -ge 1))
    if ($pcC8.Exit -eq 0 -or $pcC9.Exit -ne 0) { Write-Output ('      B-1 floor legs: strict attempts=' + $pcC8.Tries + ' exit=' + $pcC8.Exit + ' [' + $pcC8.Txt + '] default attempts=' + $pcC9.Tries + ' exit=' + $pcC9.Exit + ' [' + $pcC9.Txt + ']') }
    Write-Output ('      B-1 floor legs: strict attempts=' + $pcC8.Tries + ' default attempts=' + $pcC9.Tries + ' spacing-basis=' + $pcFB + 'px spacing-observed=' + $pcFO + 'px')
    if (-not ($pcC8.Txt -match 'spacing-basis=')) { Write-Output ('      B-1 floor leg printed no spacing ruler: [' + $pcC8.Txt + ']') }
    # every leg has run: recompute the keep-images flag from the outcomes (the pessimistic
    # default above only governs a death BEFORE this line).
    $pcLegRed = ($pcP1.Exit -ne 0) -or (@($pcRows).Count -ne 3) -or ($pcC1.Exit -ne 0) -or ($pcC2.Exit -eq 0) -or ($pcC3.Exit -ne 0) -or ($pcC4.Exit -eq 0) -or ($pcC5.Exit -eq 0) -or ($pcC6.Exit -ne 0) -or ($pcC7.Exit -ne 0) -or ($pcC8.Exit -eq 0) -or ($pcC9.Exit -ne 0)
  } finally {
    # The fixture images are deleted on the way out EXCEPT when a leg went red: a red leg whose
    # surface cannot be inspected afterwards is a red nobody can re-measure, and the gate-context
    # reads of the special surfaces (C/D/E) have measured DIFFERENT from console probes of the
    # same construction (b-wip-r3/r5). $pcLegRed is set by the legs below; on a green run the
    # directory goes away as before. The hashes print either way: identical bytes in both
    # contexts point the finger at the read, different bytes at the render.
    if ($pcLegRed) {
      $pcKeep = Join-Path ([System.IO.Path]::GetTempPath()) ('st_ptcalimg-kept-' + [guid]::NewGuid().ToString('N'))
      try { Move-Item -LiteralPath $pcImgDir -Destination $pcKeep -Force; Write-Output ('      B-1 fixture images kept for inspection: ' + $pcKeep) } catch { }
    } else {
      Remove-Item -LiteralPath $pcImgDir -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  # REGION-END pt-calibrate
  }
  $pcEmitted = @($script:StRecord)
  $script:StRecord = $null
  ST-ReconcileRegion 'pt-calibrate' $pcEmitted

}
