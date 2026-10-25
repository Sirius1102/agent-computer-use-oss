# lib/selftest-capture-ocr.ps1 - family capture-ocr of the selftest section, lifted out of
# lib/selftest.ps1 by A-14h (A-beta). Bodies are byte-identical to what the section carried.
# Eight banners in six gathered pieces (two pairs were already adjacent): read-text on a saved
# capture, one OCR tail for every miss, CJK spacing Windows OCR invents, the retry decision, the
# tiled planner and merge, the folded long-payload receipt, the sparse-read hint and needle
# sub-span aiming. State arrives only through $Ctx; lint (A-14b) names any read that reaches past it.
# These pieces were scattered between lines 509 and 3625, so gathering them reorders the section -
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

}
