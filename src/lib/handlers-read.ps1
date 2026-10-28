# lib/handlers-read.ps1 - the read/locate/assert handlers, lifted out of desktop.ps1 by A-16 (A-beta).
#    The 26 blocks below are byte-identical to what the dispatcher carried after A-15 pen 2: the union of
#    the lifted lines was hashed before the cut and the same bytes are re-hashed from this file afterwards
#    (.cowork-temp/a16-move.js prints both). Nothing is handed to the dispatcher and nothing is handed back
#    - these are ordinary function definitions the entry calls by name, and the case that names them stays
#    a three-line stub in desktop.ps1. The group assignment is declared in $script:StHandlerGroups, which
#    lint (A-16) reconciles against the functions actually defined in each handlers-<group>.ps1.

# v4.4.0 (A-15): help - the case body, verbatim
function Invoke-Handler-help([string]$Cmd, [string[]]$Rest) {
      # help | help <command> - the whole page, or one command's entry (v1.5.7). Reading
      # 300 lines to answer "does shot take --grid" is what made people guess flag names,
      # and guessing a flag name is what produces the unknown-flag errors this tool gets.
      if ($Rest.Count -ge 1 -and "$($Rest[0])" -and "$($Rest[0])" -cne 'help') {
        Format-CommandHelp (Get-UsageLines) "$($Rest[0])"
      } else { Usage }
}

# v4.4.0 (A-15): wins - the case body, verbatim
function Invoke-Handler-wins([string]$Cmd, [string[]]$Rest) {
      $list = @(Get-WinList | Sort-Object -Property Area -Descending)
      # proc + class columns exist because titles lie: two windows can both be
      # titled WeChat while belonging to Weixin.exe and its WeChatAppEx webview.
      # popup=yes marks WS_POPUP windows (context menus are their own top-level
      # windows - shoot the menu itself instead of cropping the parent).
      # v1.5.7 (D-7): owner=/main= are the columns that separate a Steam-style promo
      # popup from the app window behind it - both share pid, class AND WS_POPUP, so
      # popup=yes pointed at neither. The row text has ONE producer (Format-WinRowText);
      # the JSON keys are pinned by a selftest unit, so adding or dropping one is a
      # deliberate contract edit and not a silent side effect of touching the print.
      if ($script:Json) {
        @($list | ForEach-Object { [pscustomobject]@{ pid = $_.Pid; proc = $_.Proc; class = $_.Class; popup = [bool]$_.Popup; owner = [int64]$_.Owner; main = $_.Main; x = $_.Left; y = $_.Top; w = $_.W; h = $_.H; title = $_.Title } }) | ConvertTo-Json -Compress -Depth 3
      } else {
        $list | ForEach-Object { Format-WinRowText $_ }
      }
}

# v4.4.0 (A-15): win - the case body, verbatim
function Invoke-Handler-win([string]$Cmd, [string[]]$Rest) {
      $of = Split-OcclusionFlags $Rest
      $pf = Parse-CaptureFlags @($of.Words) $false
      if ($pf.Rest.Count -lt 1) { throw 'usage: win <sel> [outPath] [--fit <px|0>] [--grid [step]] [--mark x,y] [--occlude off|warn|strict]' }
      $w = Resolve-Window $pf.Rest[0]
      if (-not $w) { throw (Format-WindowMissMessage $pf.Rest[0]) }
      Emit-ResolveNote
      # A minimized window's rect is the -32000 parking spot: capturing it
      # silently produced a garbage screenshot (audit 2026-09-29b #10). Read
      # commands must not restore windows themselves, so fail with the fix.
      if ([DT]::IsIconic($w.Handle)) {
        throw "window '$($w.Title)' is MINIMIZED (rect would be the -32000 parking spot); run: win-restore $($pf.Rest[0]) - then retry"
      }
      # v1.5.1 WP-A: check the target's pixels BEFORE capturing - a covered
      # window yields an image that shows the coverer, and (with --occlude
      # strict) the check refuses instead of writing that lie to disk.
      $occAct = (Resolve-OcclusionMode $of.Occlude $of.AllowOccluded $false).Action
      $gate = Invoke-OcclusionGate @{ X = $w.Left; Y = $w.Top; W = $w.W; H = $w.H } $w.Handle $occAct $of.OcclGrid $w.Title $pf.Rest[0] 'read'
      $path = if ($pf.Rest.Count -ge 2 -and $pf.Rest[1]) { $pf.Rest[1] } else { Default-ShotName 'win' }
      # Self-report the coordinate mapping so nobody clicks this image's pixels
      # directly: it is a screen-region grab at origin (Left,Top), NOT a
      # re-rendered window image.
      Save-RectEx $w.Left $w.Top $w.W $w.H $path $pf.Fit $pf.Grid $pf.Marks 'win' $w $pf | Write-Output
      "window-relative clicks -> relclick $($pf.Rest[0]) <dx> <dy> (same origin); $($gate.Echo); pixels read are whatever sits on top where occluded (raise the window, or pass --occlude off to skip the check)"
}

# v4.4.0 (A-15): info - the case body, verbatim
function Invoke-Handler-info([string]$Cmd, [string[]]$Rest) {
      if ($Rest.Count -lt 1) { throw 'usage: info <sel>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw (Format-WindowMissMessage $Rest[0]) }
      Emit-ResolveNote
      $cr = New-Object DT+RECT
      [void][DT]::GetClientRect($w.Handle, [ref]$cr)
      $pt = New-Object DT+POINT
      $pt.X = 0; $pt.Y = 0
      [void][DT]::ClientToScreen($w.Handle, [ref]$pt)
      $fg = [DT]::GetForegroundWindow()
      if ($script:Json) {
        [pscustomobject]@{ pid = $w.Pid; handle = $w.Handle; title = $w.Title; pick = $w.Pick
          proc = $w.Proc; class = $w.Class; popup = [bool]$w.Popup; owner = [int64]$w.Owner; main = $w.Main
          x = $w.Left; y = $w.Top; w = $w.W; h = $w.H
          client_x = $pt.X; client_y = $pt.Y; client_w = $cr.Right; client_h = $cr.Bottom
          iconic = [DT]::IsIconic($w.Handle); foreground = ($fg -eq $w.Handle) } | ConvertTo-Json -Compress -Depth 3
      } else {
        "pid=$($w.Pid)  handle=$($w.Handle)  title=$($w.Title)  pick=$($w.Pick)"
        "proc=$($w.Proc)  class=$($w.Class)  popup=$($w.Popup.ToString().ToLower())  owner=$(if ([int64]$w.Owner -eq 0) { '-' } else { [int64]$w.Owner })  main=$($w.Main)"
        "window rect = ($($w.Left),$($w.Top))-($($w.Right),$($w.Bottom))  size=$($w.W) x $($w.H)"
        "client rect = ($($pt.X),$($pt.Y))  size=$($cr.Right) x $($cr.Bottom)"
        "iconic=$([DT]::IsIconic($w.Handle))  foreground=$($fg -eq $w.Handle)"
      }
}

# v4.4.0 (A-15): rect - the case body, verbatim
function Invoke-Handler-rect([string]$Cmd, [string[]]$Rest) {
      # rect <x> <y> <w> <h> [outPath] [--fit <px|0>] [--grid [step]] [--mark x,y] [--occlude off|warn|strict] [--to <sel>]
      # Default fit=900: a crop wider than 900px is saved downscaled with the
      # explicit scale in the echo, so the image->screen formula is always
      # concrete. --fit 0 keeps the full-resolution crop (then expect the
      # wide-image WARN).
      # CU-EXTERNAL-EXPERIENCE-20261028 (A1): --to BINDS the crop to the window it
      # was taken from. Without it the sidecar has no host and imgclick can only say
      # 'unverifiable' - and used to click anyway. The binding is refused before any
      # pixels are grabbed when the region lies outside that window.
      $hb = Resolve-CaptureTargetArgs $Rest
      $of = Split-OcclusionFlags @($hb.Words)
      $pf = Parse-CaptureFlags @($of.Words) $true
      if ($pf.Rest.Count -lt 4) { throw 'usage: rect <x> <y> <w> <h> [outPath] [--fit <px|0>] [--grid [step]] [--mark x,y] [--to <sel>]' }
      $x = [int]$pf.Rest[0]; $y = [int]$pf.Rest[1]; $w = [int]$pf.Rest[2]; $h = [int]$pf.Rest[3]
      $path = if ($pf.Rest.Count -ge 5 -and $pf.Rest[4]) { $pf.Rest[4] } else { Default-ShotName 'rect' }
      $hostWin = $null
      if ($hb.Sel) {
        $hostWin = (Resolve-CropHost $hb.Sel $x $y $w $h 'rect').Win
        "host binding: --to '$($hb.Sel)' bound pid=$($hostWin.Pid) handle=$(([IntPtr]$hostWin.Handle).ToInt64()) - the sidecar records this window's rect so imgclick --require-verified can compare the crop against it"
      }
      Save-RectEx $x $y $w $h $path $pf.Fit $pf.Grid $pf.Marks 'rect' $hostWin $pf | Write-Output
      # v1.5.1 WP-A owners mode (see shot for the rationale).
      $occAct = (Resolve-OcclusionMode $of.Occlude $of.AllowOccluded $false).Action
      $own = Invoke-OcclusionOwners @{ X = $x; Y = $y; W = $w; H = $h } $occAct $of.OcclGrid
      if ($own.Ran) { Write-Output ("occ: " + $own.Echo) }
}

# v4.4.0 (A-15): rect-of - the case body, verbatim
function Invoke-Handler-rect-of([string]$Cmd, [string[]]$Rest) {
      if ($Rest.Count -lt 1) { throw 'usage: rect-of <sel>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw (Format-WindowMissMessage $Rest[0]) }
      Emit-ResolveNote
      if ($script:Json) {
        [pscustomobject]@{ x = $w.Left; y = $w.Top; w = $w.W; h = $w.H } | ConvertTo-Json -Compress
      } else {
        "$($w.Left) $($w.Top) $($w.W) $($w.H)"
      }
}

# v4.4.0 (A-15): cursor - the case body, verbatim
function Invoke-Handler-cursor([string]$Cmd, [string[]]$Rest) {
      $p = New-Object DT+POINT
      [void][DT]::GetCursorPos([ref]$p)
      "cursor=($($p.X),$($p.Y))"
}

# v4.5.5 (OSS-05): dpi - restored verbatim from the published v4.1.4 tree. The source-line
# migration had dropped the Per-Monitor V2 block and this command while the docs still
# promised both. Reports the awareness mode actually obtained at startup plus every
# monitor's bounds in physical pixels, so a mismatch between screenshot size and click
# coordinates can be diagnosed in one call.
function Invoke-Handler-dpi([string]$Cmd, [string[]]$Rest) {
      $o = [System.Windows.Forms.SystemInformation]::VirtualScreen
      "dpi-mode=$script:DpiMode  virtual-screen=($($o.X),$($o.Y)) $($o.Width)x$($o.Height)"
      foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
        $b = $s.Bounds
        "$($s.DeviceName) primary=$($s.Primary) bounds=($($b.X),$($b.Y)) $($b.Width)x$($b.Height)"
      }
}

# v4.4.0 (A-15): status-summary - the case body, verbatim
function Invoke-Handler-status-summary([string]$Cmd, [string[]]$Rest) {
      $s = Get-WorkspaceSummary
      if ($script:Json) {
        [pscustomobject]@{
          head = $s.Head
          git = [bool]$s.Git
          clean = $(if ($null -eq $s.Clean) { $null } else { [bool]$s.Clean })
          ahead = $(if ($null -eq $s.Ahead) { $null } else { [int]$s.Ahead })
          offline = [pscustomobject]@{ passed = [int]$s.Offline.Passed; failed = [int]$s.Offline.Failed; skipped = [int]$s.Offline.Skipped; exit = [int]$s.Offline.Exit }
          latestLive = [pscustomobject]@{ name = $s.LatestLive.Name; passed = [int]$s.LatestLive.Passed; failed = [int]$s.LatestLive.Failed; skipped = [int]$s.LatestLive.Skipped }
          dtxResidual = [int]$s.DtxResidual
        } | ConvertTo-Json -Compress -Depth 4
      } else {
        "HEAD: $($s.Head)"
        # a missing git is reported as n/a, never as an empty field and never as
        # clean=false - "unknown" and "dirty" are different answers (audit #20/#24 family)
        "worktree: git=$(if ($s.Git) { 'yes' } else { 'no' }) clean=$(if ($null -eq $s.Clean) { 'n/a' } else { $s.Clean.ToString().ToLower() }) ahead=$(if ($null -eq $s.Ahead) { 'n/a' } else { $s.Ahead })"
        "offline-selftest: passed=$($s.Offline.Passed) failed=$($s.Offline.Failed) skipped=$($s.Offline.Skipped) exit=$($s.Offline.Exit)"
        "latest-live: $($s.LatestLive.Name) passed=$($s.LatestLive.Passed) failed=$($s.LatestLive.Failed) skipped=$($s.LatestLive.Skipped)"
        "DTX residual: $($s.DtxResidual)"
      }
}

# v4.4.0 (A-15): shot - the case body, verbatim
# v4.5.4 (CU-REL-05): close shot's positional shape before touching the screen or output path.
function Resolve-ShotOutputPath([string[]]$Positionals) {
      $pos = @()
      if ($null -ne $Positionals) { $pos = @($Positionals) }
      foreach ($token in $pos) {
        if ([string]$token -like '--*') {
          throw "shot: unknown flag '$token'; shot captures the whole virtual screen and accepts at most one output path. For a local screenshot use: rect 0 2010 400 80 <outPath> --fit 0"
        }
      }
      if ($pos.Count -gt 1) {
        throw 'shot: extra positional arguments are not accepted; shot captures the whole virtual screen. For a local screenshot use: rect 0 2010 400 80 <outPath> --fit 0'
      }
      if ($pos.Count -eq 1 -and [string]$pos[0]) { return [string]$pos[0] }
      return ''
}

function Invoke-Handler-shot([string]$Cmd, [string[]]$Rest) {
      $of = Split-OcclusionFlags $Rest
      $pf = Parse-CaptureFlags @($of.Words) $false
      $path = Resolve-ShotOutputPath @($pf.Rest)
      $o = [System.Windows.Forms.SystemInformation]::VirtualScreen
      if (-not $path) { $path = Default-ShotName 'shot' }
      Save-RectEx $o.X $o.Y $o.Width $o.Height $path $pf.Fit $pf.Grid $pf.Marks '' $null $pf | Write-Output
      # v1.5.1 WP-A owners mode: a full-screen/multi-window capture has no
      # single owner - report who owns the sampled pixels instead of guessing.
      $occAct = (Resolve-OcclusionMode $of.Occlude $of.AllowOccluded $false).Action
      $own = Invoke-OcclusionOwners @{ X = $o.X; Y = $o.Y; W = $o.Width; H = $o.Height } $occAct $of.OcclGrid
      if ($own.Ran) { Write-Output ("occ: " + $own.Echo) }
}

# v4.4.0 (A-15): ocr-cap - the case body, verbatim
function Invoke-Handler-ocr-cap([string]$Cmd, [string[]]$Rest) {
      # ocr-cap - read-only: the OCR engine's dimension limit + installed
      # recognizer languages + the language the engine will actually use, so
      # every WP-1/WP-4 threshold judgement can be checked against real values
      # instead of a comment's assumption.
      $dimCap = 0L
      try { $dimCap = Get-OcrMaxDimension } catch { $dimCap = 0L }
      $avail = @()
      try {
        $null = [Windows.Media.Ocr.OcrEngine,Windows.Media.Ocr,ContentType=WindowsRuntime]
        $avail = @([Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages | ForEach-Object { $_.LanguageTag })
      } catch { }
      $eng = Get-OcrEngine
      $cur = if ($null -ne $eng) { $eng.RecognizerLanguage.LanguageTag } else { '(no engine)' }
      if ($script:Json) {
        [pscustomobject]@{ MaxImageDimension = $dimCap; available = $avail; current = $cur } | ConvertTo-Json -Compress -Depth 3
      } else {
        "MaxImageDimension = $dimCap"
        "available OCR languages: $($avail -join ', ')"
        "current language: $cur"
      }
}

# v4.4.0 (A-15): hash - the case body, verbatim
function Invoke-Handler-hash([string]$Cmd, [string[]]$Rest) {
      # hash <sel|x y w h> [--occlude off|warn|strict] - MD5 of the region's PNG bytes
      # (assert-hash input). v1.5.1: occlusion-aware like the other reads.
      $of = Split-OcclusionFlags $Rest
      $Rest = @($of.Words)
      if ($Rest.Count -lt 1) { throw 'usage: hash <sel|x y w h>' }
      $region = Resolve-Region $Rest 0
      $occAct = (Resolve-OcclusionMode $of.Occlude $of.AllowOccluded $false).Action
      $gate = $null
      $owners = $null
      if ($null -ne $region.Win) { $gate = Invoke-OcclusionGate $region $region.Win.Handle $occAct $of.OcclGrid $region.Win.Title $Rest[0] 'read' }
      else { $owners = Invoke-OcclusionOwners $region $occAct $of.OcclGrid }
      $h = Get-RegionHash $region.X $region.Y $region.W $region.H
      if ($script:Json) {
        $occJ = $null; $covJ = @()
        if ($null -ne $gate) {
          if (-not $gate.Err) { $occJ = [int][math]::Round($gate.Pct) }
          $covJ = @($gate.Covering | ForEach-Object { [pscustomobject]@{ pid = $_.Pid; proc = $_.Proc; title = $_.Title; count = $_.Count } })
        }
        [pscustomobject]@{ hash = $h; x = $region.X; y = $region.Y; w = $region.W; h = $region.H; occluded = $occJ; coveredBy = $covJ } | ConvertTo-Json -Compress -Depth 4
      } else {
        $occSeg = ''
        if ($null -ne $gate) { $occSeg = " [occ: $($gate.Echo)]" }
        elseif ($null -ne $owners -and $owners.Ran) { $occSeg = " [occ: $($owners.Echo)]" }
        "hash=$h  rect=($($region.X),$($region.Y)) $($region.W)x$($region.H)$occSeg"
      }
}

# v4.4.0 (A-15): read-text - the case body, verbatim
function Invoke-Handler-read-text([string]$Cmd, [string[]]$Rest) {
      # read-text <sel|x y w h> [--max-lines n] [--filter needle] [--scale auto|1|2|tiled] [--max-tiles n] [--no-tile]
      # A whole-window OCR can return ~100 lines and flood the caller's context
      # (audit 2026-09-29b #9): --filter keeps only lines containing the needle
      # (same normalization as find-text; original line numbers preserved),
      # --max-lines caps the output and says how many were cut. --json honours both.
      # --scale: auto = 1x (this command has no needle to retry against); '2' or
      # 'tiled' force the tiled 2x read for small text; '1'/'--no-tile = raw 1x.
      $of = Split-OcclusionFlags $Rest
      $Rest = @($of.Words)
      $maxLines = -1
      $filter = ''
      $scaleMode = 'auto'; $maxTiles = 16; $noTile = $false
      # v2.9.0: read-text's own loud threshold is the NEAR-ZERO rule, not the band. The
      # 489-capture survey showed density 1.5 cuts through the mode of normal traffic (214
      # quiet reads sat in [1.5,2.0) alone), so it fired on 18.6% of ordinary dumps; the
      # negative-conclusion commands (find-text / assert-text / expect / challenge-probe)
      # keep the band, because there the read IS the claim of absence. 0.1 still warns on
      # every real failure shape the band was built for: the modal incident measured 2 lines
      # on a 1722x1597 window = 0.07, and the survey's blank-looking reads were 0.00.
      $minLineDensity = 0.1
      $filePath = ''
      $words = New-Object System.Collections.ArrayList
      $i = 0
      while ($i -lt $Rest.Count) {
        if ($Rest[$i] -eq '--max-lines') { $i++; $maxLines = Read-FlagNumber '--max-lines' $Rest[$i] $true '(lines to print)' }
        elseif ($Rest[$i] -eq '--all-lines') { $maxLines = -1 }   # v1.5.7 (D-4): no cap, and the header still says the total
        elseif ($Rest[$i] -eq '--filter') { $i++; $filter = $Rest[$i] }
        elseif ($Rest[$i] -eq '--scale') { $i++; $scaleMode = $Rest[$i]; if ($scaleMode -notin @('auto', '1', '2', 'tiled')) { throw "--scale must be auto|1|2|tiled, got: $scaleMode" } }
        elseif ($Rest[$i] -eq '--max-tiles') { $i++; $maxTiles = Read-FlagNumber '--max-tiles' $Rest[$i] $true '(tiles per tiled OCR pass)' }
        elseif ($Rest[$i] -eq '--no-tile') { $noTile = $true }
        elseif ($Rest[$i] -eq '--file') {
          $i++
          if ($i -ge $Rest.Count) { throw 'read-text: --file needs a path to a saved capture (png/jpg)' }
          $filePath = $Rest[$i]
        }
        elseif ($Rest[$i] -eq '--min-line-density') { $i++; $minLineDensity = Read-FlagNumber '--min-line-density' $Rest[$i] $false '(lines per 100k px2, 0 disables)'; if ($minLineDensity -lt 0) { throw "--min-line-density must be >= 0, got: $minLineDensity" } }
        elseif ($Rest[$i] -eq '--needle') {
          $i++
          if ($i -ge $Rest.Count) { throw 'read-text: --needle needs a value' }
          [void]$words.Add($Rest[$i])
        }
        elseif ("$($Rest[$i])" -like '--*') {
          throw "read-text: unknown flag '$($Rest[$i])' - spell a flag exactly (see 'desktop.ps1 help'); to search for text that starts with --, pass it as --needle <text>$(Get-RectFlagAliasHint 'read-text' "$($Rest[$i])")"
        }
        else { [void]$words.Add($Rest[$i]) }
        $i++
      }
      $Rest = @($words)
      $region = $null
      $gate = $null
      $owners = $null
      $tiledInfo = ''
      $fileResult = $null
      if ($filePath) {
        # v2.7.0: OCR a SAVED capture. No screen is involved, so region resolution and the
        # occlusion gate are skipped, and --json is REFUSED,
        # because the read-text envelope keys are a pinned contract with no field that
        # could say "these are image pixels, not screen pixels". Reusing the envelope
        # silently would let a machine consumer click where a glyph merely sits.
        if ($script:Json) { throw 'read-text --file: --json is not accepted in file mode - the pinned read-text envelope (schemaVersion+occluded+coveredBy+lines) has no provenance field, so image px would be indistinguishable from screen px. Drop --json: text mode labels every rect img-rect= and states the origin.' }
        $fScale = 1.0
        if ($scaleMode -eq '2' -or $scaleMode -eq 'tiled') { $fScale = 2.0 }
        $fileRetry = ''
        if ($scaleMode -eq 'tiled') {
          # v2.8.0: this used to fall through to a plain 2x read, i.e. the flag was accepted
          # and did nothing beyond what --scale 2 already does. A flag that changes no
          # behaviour is worse than no flag: it tells the caller the escape hatch was used.
          $fileResult = Invoke-OcrFileTiled $filePath $fScale $maxTiles
        } else {
          $fileResult = Invoke-OcrFile $filePath $fScale
          # v2.8.1: the ladder (whole image at 2x, then four un-upscaled overlapping crops),
          # gated on its OWN floor - see Get-EmptyReadAreaFloor for why the sparse-WARN band
          # was the wrong trigger. Opt-out is --no-tile, which means "no extra pass" here too.
          if (@($fileResult.Lines).Count -eq 0 -and -not $noTile -and
              (Test-EmptyReadSuspect ([int]$fileResult.W) ([int]$fileResult.H))) {
            $rt = Invoke-OcrFileRetryLadder $filePath $maxTiles
            $foundBack = @($rt.Lines).Count
            $fileRetry = "auto-retry (floor=$(Get-EmptyReadAreaFloor) px2): whole-image@1x=0 line(s), $($rt.Report), kept=$foundBack"
            if ($foundBack -gt 0) { $fileResult = @{ Lines = @($rt.Lines); W = $fileResult.W; H = $fileResult.H; Scale = $rt.Scale; Tiles = $rt.Tiles; Ms = $rt.Ms; Notes = @() } }
          }
        }
        $lines = @($fileResult.Lines)
      } else {
        if ($Rest.Count -lt 1) { throw 'usage: read-text <sel|x y w h> [--file <png>] [--max-lines n | --all-lines] [--filter needle] [--scale auto|1|2|tiled] [--max-tiles n] [--no-tile] [--min-line-density n]' }
        $region = Resolve-Region $Rest 0
        $occAct = (Resolve-OcclusionMode $of.Occlude $of.AllowOccluded $false).Action
        if ($null -ne $region.Win) { $gate = Invoke-OcclusionGate $region $region.Win.Handle $occAct $of.OcclGrid $region.Win.Title $Rest[0] 'read' }
        else { $owners = Invoke-OcclusionOwners $region $occAct $of.OcclGrid }
        if (($scaleMode -eq '2' -or $scaleMode -eq 'tiled') -and -not $noTile) {
          $t = Invoke-OcrRegionTiled $region.X $region.Y $region.W $region.H 2.0 $maxTiles
          $lines = $t.Lines
          $tiledInfo = ", tiled: $($t.Tiles) tile(s), $([math]::Round($t.Ms / 1000.0, 1)) s$(if (@($t.Notes).Count -gt 0) { ' ' + (@($t.Notes) -join ' ') })"
        } else {
          $lines = Invoke-OcrRegion $region.X $region.Y $region.W $region.H
        }
      }
      $total = @($lines).Count
      $shown = New-Object System.Collections.ArrayList
      for ($li = 0; $li -lt $total; $li++) {
        $ln = $lines[$li]
        if ($filter) {
          $h = Find-OcrHits @($ln) $filter
          if (@($h).Count -eq 0) { continue }
        }
        [void]$shown.Add(@{ N = ($li + 1); Line = $ln })
      }
      $cut = 0
      if ($maxLines -ge 0 -and @($shown).Count -gt $maxLines) { $cut = @($shown).Count - $maxLines; $shown = @($shown | Select-Object -First $maxLines) }
      # v1.5.9 (P-4): sparse-read hint on the negative path, TEXT MODE ONLY - the --json
      # envelope keys are a pinned contract and machine consumers count lines themselves.
      $sparseWarn = ''
      # The density hint needs a box: screen px in region mode, IMAGE px in file mode.
      # X-02: this used to read $region.W unconditionally, and in file mode $region is
      # deliberately $null (set two branches above and never resolved, because no screen is
      # involved) - so the value taken here was one this branch must not take at all. It was
      # invisible only because the next line overwrites it. Under StrictMode the read itself
      # is the failure: `read-text --file` died before printing a line.
      $boxW = 0; $boxH = 0
      if ($null -ne $region) { $boxW = $region.W; $boxH = $region.H }
      if ($fileResult) { $boxW = $fileResult.W; $boxH = $fileResult.H }
      $sparseSubject = 'region'
      if ($fileResult) { $sparseSubject = 'image' }
      # v2.9.0: the MEASUREMENT is always on the table; the ALARM is not. A read-text dump is
      # for something that can count lines itself, so one more number in the header is cheaper
      # and more inspectable than a shouted line - and at density 1.5 the shout fired on 18.6%
      # of 489 ordinary captures (the survey's quiet reads cluster right above the band: 214 of
      # them in [1.5,2.0) alone). The loud WARN stays for near-zero reads, where "not found"
      # genuinely cannot be trusted, and for the negative-conclusion commands (find-text /
      # assert-text / expect / challenge-probe), which keep the band because there the read IS
      # the claim of absence. --min-line-density still moves the line; 0 still silences both.
      $srArea = [long]$boxW * [long]$boxH
      $srPolicy = Get-SparseReadPolicy $srArea $minLineDensity
      $readLabel = ''
      if (-not $script:Json -and $srPolicy.Enabled) {
        $srDens = [math]::Round(([double]$total) / ($srArea / 100000.0), 2)
        $readLabel = " readability=$srDens lines per 100k px2 (area=$srArea px2, warn-below=$($srPolicy.Threshold), band=$($srPolicy.Band))"
      }
      if (-not $script:Json -and (Test-SparseReadability $boxW $boxH $total $minLineDensity)) {
        $sparseWarn = Build-SparseReadWarn $boxW $boxH $total $minLineDensity $sparseSubject
      }
      if ($script:Json) {
        # CONTRACT keys: schemaVersion + occluded + coveredBy + lines. Same rule as
        # find-text above - key set changes bump $JsonSchemaVersion and README.
        $envelope = New-OcrJsonEnvelope 'lines' $gate @($shown | ForEach-Object { [pscustomobject]@{ n = $_.N; text = $_.Line.Text; x = $_.Line.X; y = $_.Line.Y; w = $_.Line.W; h = $_.Line.H } })
        $envelope | ConvertTo-Json -Compress -Depth 4
      } else {
        $occSeg = ''
        if ($null -ne $gate) { $occSeg = " [occ: $($gate.Echo)]" }
        elseif ($null -ne $owners -and $owners.Ran) { $occSeg = " [occ: $($owners.Echo)]" }
        if ($fileResult) {
          # Image px, origin at the image's own top-left. The label is deliberately a
          # DIFFERENT shape from the screen mode's rect= - "img-rect=" - so a file read
          # cannot be pasted into a click by a caller who skimmed, and the header says
          # in as many words that these are not screen coordinates.
          # [IO.Path]::GetFileName, NOT Split-Path: on PowerShell 5.1 `-LiteralPath` and
          # `-Leaf` belong to different parameter sets and the call dies with "Parameter
          # set cannot be resolved" (they were unified in PS 7). This tool is 5.1-only, and
          # GetFileName is also wildcard-safe where -Path would not be.
          $fn = [System.IO.Path]::GetFileName($filePath)
          $fTileSeg = ''
          if (Get-OptValue $fileResult 'Tiles') { $fTileSeg = ", tiled: $(Get-OptValue $fileResult 'Tiles') tile(s), $([math]::Round((Get-OptValue $fileResult 'Ms') / 1000.0, 1)) s" }
          $fNoteSeg = ''
          if (@(Get-OptValue $fileResult 'Notes').Count -gt 0) { $fNoteSeg = ' ' + (@(Get-OptValue $fileResult 'Notes') -join ' ') }
          "OCR file '$fn' $($fileResult.W)x$($fileResult.H) source=file scale=$($fileResult.Scale): $total line(s)$(if ($filter) { ", filter='$filter'" })$fTileSeg$(if ($fileRetry) { " [$fileRetry]" })$fNoteSeg$readLabel - coords are IMAGE px from the image top-left, NOT a screen rect; img-rect= is not clickable"
          foreach ($e in $shown) { "L{0:D2} img-rect=({1},{2},{3}x{4})  {5}" -f $e.N, $e.Line.X, $e.Line.Y, $e.Line.W, $e.Line.H, $e.Line.Text }
        } else {
        "OCR region ($($region.X),$($region.Y)) $($region.W)x$($region.H): $total line(s)$(if ($filter) { ", filter='$filter'" })$tiledInfo$occSeg$readLabel$(if ($cut -gt 0) { ", showing first $($maxLines) ($cut more cut off - raise --max-lines or add --filter)" })"
        foreach ($e in $shown) { "L{0:D2} rect=({1},{2},{3}x{4})  {5}" -f $e.N, $e.Line.X, $e.Line.Y, $e.Line.W, $e.Line.H, $e.Line.Text }
        }
        if ($sparseWarn) { Write-Output $sparseWarn }
      }
}

# v4.4.0 (A-15): focus - the case body, verbatim
function Invoke-Handler-focus([string]$Cmd, [string[]]$Rest) {
      # focus <sel> | focus --to <sel> - --to accepted so the muscle memory from
      # type/keys/paste does not become a misleading "no window matching: --to"
      # (audit 2026-09-29b #5: the flag used to be parsed as the selector itself).
      # CU-REL-01 (v4.4.1): it used to print the label captured at SELECT time plus Activate-Win's
      # boolean and never look at the window again - "focused ... fg_ok=False" read as usable, and a
      # target that stayed minimized or parked off-screen was indistinguishable from a restored one.
      # It now activates through the common target path (handle pin, the was-already-foreground skip,
      # the did-not-come-forward refusal), then RE-READS THE SAME HANDLE and prints both states.
      # A window that is not actually foreground / iconic / visible / on-screen is refused here, so a
      # caller can never take this line as permission to click blind. No new flags: --to stays sugar,
      # and --force is deliberately NOT accepted, because a forced focus would print a usable-looking
      # line for a window it could not raise - exactly what this card removes.
      $sel = $Rest[0]
      if ($Rest.Count -ge 2 -and $Rest[0] -eq '--to') { $sel = $Rest[1] }
      if (-not $sel -or $sel -like '--*') { throw 'usage: focus <sel>  (or: focus --to <sel>)' }
      $tgt = $null
      try { $tgt = Resolve-Target $sel $false $false '' } catch {
        # The shared guard's sentence ends with "Re-run with" plus that flag, which focus refuses on
        # purpose, so passing it through unedited would send the caller after something not accepted.
        # so passing it through unedited would send the caller after something that does not exist.
        # Repair the way out, keep the measured facts, and re-throw (only that one message is touched).
        $fe = $_.Exception.Message
        if ($fe -like '*foreground guard*') {
          throw ($fe + "  - focus has no --force: it will not report a window it could not raise. Re-read with 'wins', try 'win-restore'/'win-max', or let the next command carry its own --to/--guard.")
        }
        throw
      }
      Emit-ResolveNote
      $fHwnd = $tgt.Handle
      # Both readings are measurements, never restatements of what the command tried to do.
      # at-select: the snapshot Resolve-Window took before the activation ran (its rect, whether
      # it was the foreground one, and whether it was minimized). Get-WinList only enumerates
      # windows that answer IsWindowVisible, which is why visible=true there is a reading too.
      # after-activate: read again NOW, by handle, so a window that is still minimized or still
      # parked at -32000 cannot hide behind an Activate-Win return value.
      $atSelect = @{
        Fg = ("$($tgt.Pick)" -eq 'fg')
        Iconic = [bool]$tgt.Iconic
        Visible = $true
        Rect = @{ X = $tgt.Left; Y = $tgt.Top; W = $tgt.W; H = $tgt.H }
      }
      $after = @{
        Fg = ([DT]::GetForegroundWindow() -eq $fHwnd)
        Iconic = [bool][DT]::IsIconic($fHwnd)
        Visible = [bool][DT]::IsWindowVisible($fHwnd)
        Rect = (Get-WindowVisibleRect $fHwnd)
      }
      $fState = (Format-FocusState 'at-select' $atSelect) + ' ' + (Format-FocusState 'after-activate' $after)
      Log-Action $Rest "pid=$($tgt.Pid) title='$($tgt.Title)' pick=$($tgt.Pick) $fState" $Cmd
      if (-not (Test-FocusUsable $after)) {
        throw "focus: the window did not end up in a usable foreground state (pick=$($tgt.Pick)) - $fState. This call does NOT say the window is ready to be clicked at: re-read it with 'wins', try 'win-restore' (or 'win-max'), and give the next command its own --to/--guard so it re-checks the same way."
      }
      # fg_ok stays the single contract token (README/reference/the live focus pin all read it), and it
      # now appears ONLY on a line that also passed Test-FocusUsable. The measured states are spelled
      # with fg= so a refusal quoting them can never be mistaken for that token. pick= stays too:
      # README's selector section says info/focus/wait-win name the pick basis.
      "focused pid=$($tgt.Pid) title=$($tgt.Title) fg_ok=$($after.Fg) pick=$($tgt.Pick) $fState"
}

# v4.4.0 (A-15): find - the case body, verbatim
function Invoke-Handler-find([string]$Cmd, [string[]]$Rest) {
      # find <needle...> [--target <sel>] [--region x,y,w,h] [--needle <text>]
      # The composite locator (plan doc 1.1): UIA first, OCR as the second road, and the
      # echo says WHICH ONE ANSWERED. Never silent - a caller that thinks it holds a UIA
      # rect while it actually holds an OCR line has the wrong confidence in the point.
      # Deliberate choices, all of them behavioural:
      #   NO activation. The target is resolved read-only (Resolve-Window / the region's
      #   hit window / the foreground window as it already is), because this is a locator,
      #   not an action - raising a window above a self-drawn popup is a side effect
      #   (v1.5.6 D-2/A-2 measured that twice).
      #   No title guessing when a bare call is made: with neither --target nor --region
      #   the target is the ACTUAL foreground window, named in the echo.
      $own = Strip-OwnFlags $Rest 'find'
      $fRegion = [string]$own.Values['--region']
      $fTarget = [string]$own.Values['--target']
      # v4.2.0 (feedback item 5): the requested depth knob. 0 = unlimited, which is what
      # this road has ALWAYS walked (Uia-WalkAll's default) - the echo used to keep that
      # fact quiet while callers blamed "the depth" for a zero. Setting it bounds the walk
      # and the echo prints the bound that actually ran.
      $fDepth = [int]$own.Values['--depth']
      $of = Split-OcclusionFlags @($own.Rest)
      $words = New-Object System.Collections.ArrayList
      $fNeedle = ''
      $fi = 0
      while ($fi -lt @($of.Words).Count) {
        $tok = "$(@($of.Words)[$fi])"
        if ($tok -eq '--needle') {
          $fi++
          if ($fi -ge @($of.Words).Count) { throw 'find: --needle needs a value' }
          $fNeedle = "$(@($of.Words)[$fi])"
        }
        elseif ($tok -like '--*') { throw (Get-UnknownFlagMessage 'find' $tok) }
        else { [void]$words.Add($tok) }
        $fi++
      }
      if (-not $fNeedle) { $fNeedle = (@($words) -join ' ').Trim() }
      if ($fNeedle.Length -lt 1) { throw 'find: empty needle - pass the text to look for, or --needle <text> for text that starts with --' }
      # ---- target / region ----
      $fWin = $null; $fWinHow = ''
      $fRect = $null
      if ($fRegion) {
        $fRect = Parse-FindRegionSpec $fRegion
        $hit = Get-HitWindow ([int]($fRect.X + [int]($fRect.W / 2))) ([int]($fRect.Y + [int]($fRect.H / 2)))
        if ($hit) { $fWin = [pscustomobject]@{ Handle = $hit.Hwnd; Pid = $hit.Pid }; $fWinHow = 'region-hit' }
      }
      if ($fTarget) {
        $fWin = Resolve-Window $fTarget
        if (-not $fWin) { throw "find: no window matching: $fTarget" }
        $fWinHow = 'target'
        if ($null -eq $fRect) { $fRect = @{ X = $fWin.Left; Y = $fWin.Top; W = $fWin.W; H = $fWin.H } }
      }
      if ($null -eq $fWin -and $null -eq $fRect) {
        $fh = [DT]::GetForegroundWindow()
        $fpid = 0
        [void][DT]::GetWindowThreadProcessId($fh, [ref]$fpid)
        $fWin = [pscustomobject]@{ Handle = $fh; Pid = $fpid }
        $fr = Get-WindowVisibleRect $fh
        if ($null -eq $fr) { throw "find: the foreground window has no visible rect (pid=$fpid) - pass --target <sel> or --region x,y,w,h" }
        $fRect = @{ X = $fr.X; Y = $fr.Y; W = $fr.W; H = $fr.H }
        $fWinHow = 'foreground'
      }
      $fDesc = "target=$(if ($fWin) { 'pid=' + $fWin.Pid } else { 'no-window' }) region=($($fRect.X),$($fRect.Y),$($fRect.W)x$($fRect.H)) via=$fWinHow"
      # ---- road 1: UIA (with the cold-start re-contact of plan 1.2) ----
      $fUia = $null; $fUiaHits = @(); $fScanned = 0; $fWalked = 0; $fReprobe = 'n/a (no UIA root)'
      if ($null -ne $fWin) {
        $fwf = {
          param($contact)
          if ($contact -gt 1) { Start-Sleep -Milliseconds 400 }
          $rr = Uia-Roots $fWin
          if ($rr.Roots.Count -lt 1) { return @{ Elements = @(); Scanned = 0; Walked = 0; Depth = [int]$fDepth; Roots = 0; Via = 'no-root' } }
          # v4.2.0 (feedback item 5): the walk is bounded by the caller's --depth (0 =
          # unlimited) and Walked counts every element seen BEFORE the region filter, so
          # "scanned 14" can no longer be read as either "the tree is shallow" or "the
          # filter ate it" without evidence.
          $els = @(Uia-WalkAll $rr.Roots $fDepth)
          # the region filter is what makes --region mean something to the UIA road too:
          # a control outside the asked-for rect is not an answer to this question.
          $keep = New-Object System.Collections.ArrayList
          foreach ($e in $els) {
            $r = $null
            try { $r = $e.Current.BoundingRectangle } catch { }
            if ($null -eq $r -or $r.IsEmpty) { [void]$keep.Add($e); continue }
            $cx = [int]($r.X + $r.Width / 2); $cy = [int]($r.Y + $r.Height / 2)
            if ($cx -ge $fRect.X -and $cx -lt ($fRect.X + $fRect.W) -and $cy -ge $fRect.Y -and $cy -lt ($fRect.Y + $fRect.H)) { [void]$keep.Add($e) }
          }
          return @{ Elements = @($keep); Scanned = @($keep).Count; Walked = @($els).Count; Depth = [int]$fDepth; Roots = @($rr.Roots).Count; Via = $rr.Via }
        }
        $fUia = Search-UiaTree $fwf $fNeedle '' (Get-UiaReprobeFloor)
        $fUiaHits = @($fUia.Hits); $fScanned = [int]$fUia.Scanned; $fReprobe = "$($fUia.Reprobe)"
        $fWalked = [int](Get-OptValue $fUia 'Walked')
      }
      $fDecision = Get-FindSourceDecision $fUiaHits.Count 0
      $occTxt = ''
      $fHits = @()
      $fGate = $null
      $fOcrLines = 0
      $fOcrNote = 'not run (the UIA road answered)'
      if ($fDecision.Source -eq 'uia') {
        $fRectless = 0
        foreach ($el in @($fUiaHits)) {
          $hn = ''; $hr = $null
          try { $hn = $el.Current.Name } catch { }
          try { $hr = $el.Current.BoundingRectangle } catch { }
          # v3.0.1 (same Rect.Empty family, this site found while fixing the reported three
          # and NOT in the audit report): Rect.Empty's members are +/-Infinity, so the
          # [int] casts below threw and ended the command; and when the property read
          # itself failed, $hr was $null and the cast produced 0 - a hit at (0,0) sized
          # 0x0 that a caller would happily try to click. find's entire promise is a
          # clickable point, so an element without one is dropped and COUNTED, not faked.
          if (-not (Test-UiaRectUsable $hr)) { $fRectless++; continue }
          $fHits += @{ road = 'uia'; text = $hn; x = [int]$hr.X; y = [int]$hr.Y; w = [int]$hr.Width; h = [int]$hr.Height }
        }
        if (-not $script:Json) {
          Write-Output "find: source=uia $fDesc"
          Write-Output "  uia: walked=$fWalked kept=$fScanned depth=$(Format-UiaWalkDepth $fDepth) walks=$($fUia.Walks) reprobe-floor=$(Get-UiaReprobeFloor) cold-zero-reprobe=$fReprobe hits=$(@($fUiaHits).Count) rectless=$fRectless"
          foreach ($el in @($fUiaHits)) {
            Uia-Line $el 0
            $r = $null
            try { $r = $el.Current.BoundingRectangle } catch { }
            if (-not (Test-UiaRectUsable $r)) {
              # the old code swallowed this in a catch and printed nothing, which read as
              # "this hit has no centre for some reason"; say which reason
              "  centre=unavailable (UIA reported no rectangle for this element) - not clickable, see rectless="
            } else {
              $ccx = [int]($r.X + ($r.Width / 2)); $ccy = [int]($r.Y + ($r.Height / 2))
              "  centre=$ccx,$ccy -> click $ccx $ccy"
            }
          }
        }
      }
      else {
        # ---- road 2: OCR, announced before it runs ----
        if (-not $script:Json) {
          Write-Output "find: uia gave 0 hits after walking $fWalked element(s) at depth $(Format-UiaWalkDepth $fDepth) - $fScanned of them survived the region filter ($fReprobe) - falling back to OCR on the same rect. source=ocr means the rect came from OCR: it folds look-alike glyphs, can merge two controls into one line, and cannot see enabled/offscreen."
        }
        $fReg = @{ X = $fRect.X; Y = $fRect.Y; W = $fRect.W; H = $fRect.H; Win = $(if ($fWinHow -eq 'target') { $fWin } else { $null }) }
        $occAct = (Resolve-OcclusionMode $of.Occlude $of.AllowOccluded $false).Action
        $fOwners = $null
        if ($null -ne $fReg.Win) { $fGate = Invoke-OcclusionGate $fReg $fReg.Win.Handle $occAct $of.OcclGrid $fReg.Win.Title $fNeedle 'read' }
        else { $fOwners = Invoke-OcclusionOwners $fReg $occAct $of.OcclGrid }
        $f2 = Find-OcrHitsScaled $fRect.X $fRect.Y $fRect.W $fRect.H $fNeedle 'auto' 16 $false
        $fOcrHits = @($f2.Hits)
        $fOcrLines = @($f2.Lines).Count
        $fOcrNote = Format-OcrRetryNote $f2
        $fDecision = Get-FindSourceDecision $fUiaHits.Count $fOcrHits.Count
        if ($null -ne $fGate) { $occTxt = "; occluded=$([int][math]::Round($fGate.Pct))% $($fGate.Echo)" }
        elseif ($null -ne $fOwners -and $fOwners.Ran) { $occTxt = "; owners $($fOwners.Echo)" }
        if ($fDecision.Refuse) {
          # the miss names BOTH roads with what each one measured - never a bare 'not found'
          $fUiaNote = "walks=$(if ($null -ne $fUia) { $fUia.Walks } else { 0 }) walked=$fWalked depth=$(Format-UiaWalkDepth $fDepth) kept=$fScanned after region filter re-contact=$fReprobe"
          throw (Format-FindMiss $fNeedle $fWalked $fUiaNote $fOcrLines $fOcrNote "($($fRect.X),$($fRect.Y)) $($fRect.W)x$($fRect.H)" $occTxt)
        }
        foreach ($ln in $fOcrHits) {
          $fFolded = $false
          try { if ($ln.PSObject.Properties['Folded'] -and $ln.Folded) { $fFolded = $true } } catch { }
          $fHits += @{ road = 'ocr'; text = "$($ln.Text)"; x = [int]$ln.X; y = [int]$ln.Y; w = [int]$ln.W; h = [int]$ln.H; folded = $fFolded }
        }
        if (-not $script:Json) {
          Write-Output "find: source=ocr $fDesc"
          Write-Output "  ocr: $fOcrLines line(s) read, $fOcrNote - retry knobs (--scale / --no-tile / --all) live on find-text$occTxt"
          # the cut is announced on the line next to it (self-scan contract: no user-visible
          # list may be truncated silently), and the exact hidden count rides after the loop
          Write-Output "  hits: $(@($fOcrHits).Count) line(s) - the list below is cut at 8, more hit lines exist (find-text --all prints every one)"
          foreach ($ln in @($fOcrHits | Select-Object -First 8)) {
            $foldTag = ''
            try { if ($ln.PSObject.Properties['Folded'] -and $ln.Folded) { $foldTag = ' [folded-match]' } } catch { }
            "  line '$($ln.Text)' rect=($($ln.X),$($ln.Y),$($ln.W)x$($ln.H)) centre=$([int]($ln.X + ($ln.W / 2))),$([int]($ln.Y + ($ln.H / 2)))$foldTag"
          }
          if (@($fOcrHits).Count -gt 8) { "  ... and $(@($fOcrHits).Count - 8) more hit line(s) not listed - find-text --all prints every one" }
        }
      }
      if ($script:Json) {
        (New-FindJsonEnvelope $fDecision.Source $fDesc $fGate $fHits) | ConvertTo-Json -Compress -Depth 5
      }
}

# v4.4.0 (A-15): find-text - the case body, verbatim
function Invoke-Handler-find-text([string]$Cmd, [string[]]$Rest) {
      # find-text <sel|x y w h> <needle...> [--all] [--scale auto|1|2|tiled] [--max-tiles n] [--no-tile]
      # OCR the region, return the screen rect of every line containing the
      # needle. This is the structured locator for a11y-less apps (Qt/Java/
      # Chromium shells): one call instead of crop -> measure -> convert -> miss.
      if ($Rest.Count -lt 2) { throw 'usage: find-text <sel|x y w h> <needle...> [--all] [--scale auto|1|2|tiled] [--max-tiles n] [--no-tile] [--min-line-density n]' }
      $of = Split-OcclusionFlags $Rest
      $Rest = @($of.Words)
      $all = $false; $scaleMode = 'auto'; $maxTiles = 16; $noTile = $false
      $minLineDensity = 1.5
      $words = New-Object System.Collections.ArrayList
      $i = 0
      while ($i -lt $Rest.Count) {
        if ($Rest[$i] -eq '--all') { $all = $true }
        elseif ($Rest[$i] -eq '--scale') { $i++; $scaleMode = $Rest[$i]; if ($scaleMode -notin @('auto', '1', '2', 'tiled')) { throw "--scale must be auto|1|2|tiled, got: $scaleMode" } }
        elseif ($Rest[$i] -eq '--max-tiles') { $i++; $maxTiles = Read-FlagNumber '--max-tiles' $Rest[$i] $true '(tiles per tiled OCR pass)' }
        elseif ($Rest[$i] -eq '--no-tile') { $noTile = $true }
        elseif ($Rest[$i] -eq '--min-line-density') { $i++; $minLineDensity = Read-FlagNumber '--min-line-density' $Rest[$i] $false '(lines per 100k px2, 0 disables)'; if ($minLineDensity -lt 0) { throw "--min-line-density must be >= 0, got: $minLineDensity" } }
        elseif ($Rest[$i] -eq '--needle') {
          $i++
          if ($i -ge $Rest.Count) { throw 'find-text: --needle needs a value' }
          [void]$words.Add($Rest[$i])
        }
        elseif ("$($Rest[$i])" -like '--*') {
          throw "find-text: unknown flag '$($Rest[$i])' - spell a flag exactly (see 'desktop.ps1 help'); to search for text that starts with --, pass it as --needle <text>$(Get-RectFlagAliasHint 'find-text' "$($Rest[$i])")"
        }
        else { [void]$words.Add($Rest[$i]) }
        $i++
      }
      $Rest = @($words)
      $region = Resolve-Region $Rest 0
      $rw = Region-WordCount $Rest 0
      if ($Rest.Count -le $rw) { throw 'find-text: empty needle' }
      $needle = (@($Rest[$rw..($Rest.Count - 1)]) -join ' ').Trim()
      $occAct = (Resolve-OcclusionMode $of.Occlude $of.AllowOccluded $false).Action
      $gate = $null
      $owners = $null
      if ($null -ne $region.Win) { $gate = Invoke-OcclusionGate $region $region.Win.Handle $occAct $of.OcclGrid $region.Win.Title $Rest[0] 'read' }
      else { $owners = Invoke-OcclusionOwners $region $occAct $of.OcclGrid }
      $f = Find-OcrHitsScaled $region.X $region.Y $region.W $region.H $needle $scaleMode $maxTiles $noTile
      $hits = $f.Hits; $lines = $f.Lines
      if ($hits.Count -eq 0) {
        # quote the retry decision verbatim: a silent skip must never read as
        # "we tried everything" (audit 2026-09-29b #1; three states per v1.5.0 WP-1 2.6)
        # v1.5.7 (owner supplement 3): every premise that produced this NEGATIVE now
        # rides on the SAME line - rect scanned, how it was scanned, the occlusion
        # verdict, whether the confusable-fold pass ran, and shown-of-total. A reader who
        # only gets one line must not be able to turn a fragment into a fact (R-25).
        $missRect = "($($region.X),$($region.Y)) $($region.W)x$($region.H)"
        $occTxt = ''
        if ($null -ne $gate) { $occTxt = "$([int][math]::Round($gate.Pct))% $($gate.Echo)" }
        elseif ($null -ne $owners -and $owners.Ran) { $occTxt = "owners $($owners.Echo)" }
        $occNote = ''
        if ($null -ne $gate -and $gate.Mismatch -gt 0 -and @($gate.Covering).Count -gt 0) {
          $occNote = "; TARGET OCCLUDED: $([int][math]::Round($gate.Pct))% covered by pid=$($gate.Covering[0].Pid) proc=$($gate.Covering[0].Proc) - a not-found here is NOT evidence the text is absent (raise/focus the window, or pass --occlude off)"
        } elseif ($null -ne $owners -and $owners.Ran -and @($owners.Owners).Count -gt 0) {
          # CU-FINAL-ROUND2: a raw rect has NO target, so "other windows" was an unwarranted
          # inference - the owner shown can be the very window the caller meant, and the
          # share next to it is pixel OWNERSHIP, not an occlusion rate. Say only the fact.
          $occNote = '; raw rect (no target window): the owner/share above is pixel OWNERSHIP, not an occlusion verdict - pass <sel> instead of x y w h to compare against a window'
        }
        # v1.5.9 (P-4): a large near-empty read on a MISS usually means an in-window
        # scrim - say so before the not-found line is taken as fact.
        if (Test-SparseReadability $region.W $region.H @($lines).Count $minLineDensity) {
          Write-Output (Build-SparseReadWarn $region.W $region.H @($lines).Count $minLineDensity)
        }
        throw "find-text: '$needle' not found in region $missRect ($(Format-OcrRetryNote $f)); $(Format-OcrSampleTail $lines 8 @{ Rect = $missRect; Retry = (Format-OcrRetryNote $f); Occlusion = $occTxt; Needle = $needle })$occNote"
      }
      if ($script:Json) {
        # CONTRACT keys: schemaVersion + occluded + coveredBy + hits. Changing this
        # set means bumping $JsonSchemaVersion and README together (see
        # New-OcrJsonEnvelope); selftest asserts the set exactly.
        $envelope = New-OcrJsonEnvelope 'hits' $gate @($hits | ForEach-Object { [pscustomobject]@{ text = $_.Text; x = $_.X; y = $_.Y; w = $_.W; h = $_.H; cx = ($_.X + [int]($_.W / 2)); cy = ($_.Y + [int]($_.H / 2)); folded = [bool]($_.PSObject.Properties['Folded'] -and $_.Folded) } })
        $envelope | ConvertTo-Json -Compress -Depth 5
      } else {
        $show = if ($all) { $hits } else { $hits[0] }
        $foldMark = Get-OcrFoldMarker $hits
        foreach ($h in $show) {
          $cx = $h.X + [int]($h.W / 2); $cy = $h.Y + [int]($h.H / 2)
          "hit: text='$($h.Text)' rect=($($h.X),$($h.Y),$($h.W)x$($h.H)) centre=($cx,$cy)  -> click $cx $cy"
        }
        if ($foldMark) { Write-Output "needle: $foldMark" }
        # J-05: the hit count a reader is about to act on is line-granular BY RULING; say
        # so only when the numbers actually diverge (the wording has one producer).
        $j05Hint = Format-MultiOccurrenceHint $needle $hits
        if ($j05Hint) { Write-Output $j05Hint }
        if ($f.Tiled) { "tiled: $($f.TileCount) tile(s), $([math]::Round($f.Ms / 1000.0, 1)) s" }
        if (-not $all -and $hits.Count -gt 1) { "($($hits.Count) hits total; pass --all to list them)" }
        $occLine = ''
        if ($null -ne $gate) { $occLine = "occ: $($gate.Echo)" }
        elseif ($null -ne $owners -and $owners.Ran) { $occLine = "occ: $($owners.Echo)" }
        if ($occLine) { Write-Output $occLine }
      }
}

# v4.4.0 (A-15): find-color - the case body, verbatim
function Invoke-Handler-find-color([string]$Cmd, [string[]]$Rest) {
      # find-color <x> <y> <w> <h> <#RRGGBB> [--tolerance n] [--all]
      if ($Rest.Count -lt 5) { throw 'usage: find-color <x> <y> <w> <h> <#RRGGBB> [--tolerance n] [--all]' }
      $tol = 20
      $all = $false
      $words = New-Object System.Collections.ArrayList
      $i = 0
      while ($i -lt $Rest.Count) {
        if ($Rest[$i] -eq '--tolerance') { $i++; $tol = Read-FlagNumber '--tolerance' $Rest[$i] $true '(0..255 per channel)' }
        elseif ($Rest[$i] -eq '--all') { $all = $true }
        elseif ($Rest[$i] -like '--*') { throw (Get-UnknownFlagMessage 'find-color' "$($Rest[$i])") }
        else { [void]$words.Add($Rest[$i]) }
        $i++
      }
      $Rest = @($words)
      $hits = Find-ColorMatches ([int]$Rest[0]) ([int]$Rest[1]) ([int]$Rest[2]) ([int]$Rest[3]) $Rest[4] $tol
      if ($hits.Count -eq 0) {
        throw "find-color: $($Rest[4]) not found in region ($($Rest[0]),$($Rest[1])) $($Rest[2])x$($Rest[3]) (tolerance $tol)"
      }
      if ($script:Json) {
        # selection-not-display: 'first' is one field of the object and 'hits' below is full
        [pscustomobject]@{ count = $hits.Count; first = ($hits | Select-Object -First 1 | ForEach-Object { [pscustomobject]@{ x = $_.X; y = $_.Y; hex = $_.Hex } }); hits = @($hits | ForEach-Object { [pscustomobject]@{ x = $_.X; y = $_.Y; hex = $_.Hex } }) } | ConvertTo-Json -Compress -Depth 4
      } else {
        "found $($hits.Count) pixel(s) matching $($Rest[4]) (tol=$tol); first at ($($hits[0].X),$($hits[0].Y)) actual=$($hits[0].Hex)"
        if ($all) { $hits | Select-Object -First 20 | ForEach-Object { "  ($($_.X),$($_.Y)) $($_.Hex)" }; if ($hits.Count -gt 20) { "  (+$($hits.Count - 20) more matches not listed - showing the first 20 of $($hits.Count))" } }
      }
}

# v4.4.0 (A-15): color-at - the case body, verbatim
function Invoke-Handler-color-at([string]$Cmd, [string[]]$Rest) {
      # color-at <x> <y> - deterministic answer to "is that indicator green".
      if ($Rest.Count -lt 2) { throw 'usage: color-at <x> <y>' }
      $hex = Get-PixelHex ([int]$Rest[0]) ([int]$Rest[1])
      if ($script:Json) {
        [pscustomobject]@{ x = [int]$Rest[0]; y = [int]$Rest[1]; hex = $hex } | ConvertTo-Json -Compress
      } else {
        "color at ($($Rest[0]),$($Rest[1])) = $hex"
      }
}

# v4.4.0 (A-15): wait-win - the case body, verbatim
function Invoke-Handler-wait-win([string]$Cmd, [string[]]$Rest) {
      # wait-win <sel> <timeoutSec> - poll every 500ms until <sel> resolves.
      if ($Rest.Count -lt 2) { throw 'usage: wait-win <sel> <timeoutSec>' }
      $timeout = Read-FlagNumber 'wait-win <timeoutSec>' $Rest[1] $false '(seconds)'
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      $w = $null
      while ($sw.Elapsed.TotalSeconds -lt $timeout) {
        $w = Resolve-Window $Rest[0]
        if ($w) { break }
        Start-Sleep -Milliseconds 500
      }
      if (-not $w) { throw "timeout after ${timeout}s waiting for window: $($Rest[0])" }
      "appeared after $([math]::Round($sw.Elapsed.TotalSeconds,1))s: pid=$($w.Pid)  rect=($($w.Left),$($w.Top))-($($w.Right),$($w.Bottom))  size=$($w.W)x$($w.H)  title=$($w.Title)  pick=$($w.Pick)"
}

# v4.4.0 (A-15): wait-gone - the case body, verbatim
function Invoke-Handler-wait-gone([string]$Cmd, [string[]]$Rest) {
      # wait-gone <sel> <timeoutSec> - poll every 500ms until <sel> no longer
      # resolves (dialog closed, operation took effect).
      if ($Rest.Count -lt 2) { throw 'usage: wait-gone <sel> <timeoutSec>' }
      $timeout = Read-FlagNumber 'wait-gone <timeoutSec>' $Rest[1] $false '(seconds)'
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      $w = Resolve-Window $Rest[0]
      while ($null -ne $w -and $sw.Elapsed.TotalSeconds -lt $timeout) {
        Start-Sleep -Milliseconds 500
        $w = Resolve-Window $Rest[0]
      }
      if ($null -ne $w) { throw "timeout after ${timeout}s, window still present: $($Rest[0])" }
      "gone after $([math]::Round($sw.Elapsed.TotalSeconds,1))s: $($Rest[0])"
}

# v4.4.0 (A-15): wait-stable - the case body, verbatim
function Invoke-Handler-wait-stable([string]$Cmd, [string[]]$Rest) {
      # wait-stable <sel|x y w h> <timeoutSec> [--interval ms] [--changed]
      # Default: poll until two consecutive captures hash identical (UI
      # settled). --changed flips the semantics: entry baseline hash, poll
      # until it DIFFERS - the "did my click do anything at all" probe.
      $of = Split-OcclusionFlags $Rest
      $Rest = @($of.Words)
      $words = New-Object System.Collections.ArrayList
      $interval = 500
      $changed = $false
      $i = 0
      while ($i -lt $Rest.Count) {
        if ($Rest[$i] -eq '--interval') { $i++; $interval = Read-FlagNumber '--interval' $Rest[$i] $true '(milliseconds)' }
        elseif ($Rest[$i] -eq '--changed') { $changed = $true }
        elseif ($Rest[$i] -like '--*') { throw (Get-UnknownFlagMessage 'wait-stable' "$($Rest[$i])") }
        else { [void]$words.Add($Rest[$i]) }
        $i++
      }
      $Rest = @($words)
      if ($Rest.Count -lt 2) { throw 'usage: wait-stable <sel|x y w h> <timeoutSec> [--interval ms] [--changed]' }
      $region = Resolve-Region $Rest 0
      # Occlusion is a snapshot at entry: if the window gets covered MID-poll
      # the pixel changes are the coverer's - the entry verdict is still the
      # honest statement about what the poll is allowed to prove.
      $occAct = (Resolve-OcclusionMode $of.Occlude $of.AllowOccluded $false).Action
      $gate = $null
      $owners = $null
      if ($null -ne $region.Win) { $gate = Invoke-OcclusionGate $region $region.Win.Handle $occAct $of.OcclGrid $region.Win.Title $Rest[0] 'read' }
      else { $owners = Invoke-OcclusionOwners $region $occAct $of.OcclGrid }
      $occSeg = ''
      if ($null -ne $gate) { $occSeg = " [occ: $($gate.Echo)]" }
      elseif ($null -ne $owners -and $owners.Ran) { $occSeg = " [occ: $($owners.Echo)]" }
      if ($changed) {
        $r = Wait-RegionChanged $region ([double]$Rest[1]) $interval
        if (-not $r.Changed) { throw "no change within $($Rest[1])s (hash stayed $($r.From)) - the click probably did nothing$(if ($gate -and $gate.Mismatch -gt 0) { '; NOTE: target was occluded at start - the pixels watched may belong to a coverer' })" }
        if ($script:Json) {
          $occJ = $null; $covJ = @()
          if ($null -ne $gate) { if (-not $gate.Err) { $occJ = [int][math]::Round($gate.Pct) }; $covJ = @($gate.Covering | ForEach-Object { [pscustomobject]@{ pid = $_.Pid; proc = $_.Proc; title = $_.Title; count = $_.Count } }) }
          [pscustomobject]@{ changed = $true; elapsed = [math]::Round($r.Elapsed, 1); from = $r.From; to = $r.To; occluded = $occJ; coveredBy = $covJ } | ConvertTo-Json -Compress -Depth 4
        } else {
          "changed after $([math]::Round($r.Elapsed, 1))s (hash $($r.From) -> $($r.To))$occSeg"
        }
      } else {
        $r = Wait-RegionStable $region ([double]$Rest[1]) $interval
        if (-not $r.Stable) { throw "not stable within $($Rest[1])s (last hash=$($r.Hash)). If the region holds a blinking caret, a spinner or video it never repeats two frames in a row - use wait-win/wait-gone or a sub-region that excludes it." }
        if ($script:Json) {
          $occJ = $null; $covJ = @()
          if ($null -ne $gate) { if (-not $gate.Err) { $occJ = [int][math]::Round($gate.Pct) }; $covJ = @($gate.Covering | ForEach-Object { [pscustomobject]@{ pid = $_.Pid; proc = $_.Proc; title = $_.Title; count = $_.Count } }) }
          [pscustomobject]@{ stable = $true; elapsed = [math]::Round($r.Elapsed, 1); hash = $r.Hash; occluded = $occJ; coveredBy = $covJ } | ConvertTo-Json -Compress -Depth 4
        } else {
          "stable after $([math]::Round($r.Elapsed, 1))s  hash=$($r.Hash)  rect=($($region.X),$($region.Y)) $($region.W)x$($region.H)$occSeg"
        }
      }
}

# v4.4.0 (A-15): assert-changed - the case body, verbatim
function Invoke-Handler-assert-changed([string]$Cmd, [string[]]$Rest) {
      # assert-changed <sel|x y w h> <timeoutSec> - wait-stable --changed with
      # the assertion exit-code contract (0 = something changed). v1.5.1: like
      # the other assert-* commands it is occlusion-strict by default (an
      # occluded target can make "changed" lie); --allow-occluded downgrades.
      $xr = @($Rest)
      if ($xr -notcontains '--occlude') { $xr += @('--occlude', 'strict') }
      Invoke-DesktopCommand 'wait-stable' (@('--changed') + $xr)
}

# v4.4.0 (A-15): assert-window - the case body, verbatim
function Invoke-Handler-assert-window([string]$Cmd, [string[]]$Rest) {
      # assert-window <sel> - exit 0 when it resolves, ERROR + exit 1 otherwise.
      if ($Rest.Count -lt 1) { throw 'usage: assert-window <sel>' }
      $w = Resolve-Window $Rest[0]
      if (-not $w) { throw "assert-window failed: no window matching: $($Rest[0])" }
      Emit-ResolveNote
      # v4.2.0 (feedback item 6): iconic= rides here because this is the command the
      # reporter reads as a checkpoint - a parked window used to print pick=fg with a rect
      # at (-31991,-32000) and nothing on the line said the window is in the taskbar.
      "ASSERT OK: window pid=$($w.Pid) rect=($($w.Left),$($w.Top)) $($w.W)x$($w.H) title='$($w.Title)' pick=$($w.Pick) iconic=$(Get-OptValue $w 'Iconic')"
}

# v4.4.0 (A-15): assert-text - the case body, verbatim
function Invoke-Handler-assert-text([string]$Cmd, [string[]]$Rest) {
      # assert-text <sel|x y w h> <needle...> [--scale auto|1|2|tiled] [--max-tiles n] [--no-tile]
      # v1.5.1 WP-A: occlusion-strict by default - an assertion over a
      # coverer's pixels is not evidence about the target (--allow-occluded /
      # --occlude warn downgrade to a warning).
      $of = Split-OcclusionFlags $Rest
      $Rest = @($of.Words)
      if ($Rest.Count -lt 2) { throw 'usage: assert-text <sel|x y w h> <needle...> [--scale auto|1|2|tiled] [--max-tiles n] [--no-tile]' }
      $scaleMode = 'auto'; $maxTiles = 16; $noTile = $false
      $words = New-Object System.Collections.ArrayList
      $i = 0
      while ($i -lt $Rest.Count) {
        if ($Rest[$i] -eq '--scale') { $i++; $scaleMode = $Rest[$i]; if ($scaleMode -notin @('auto', '1', '2', 'tiled')) { throw "--scale must be auto|1|2|tiled, got: $scaleMode" } }
        elseif ($Rest[$i] -eq '--max-tiles') { $i++; $maxTiles = Read-FlagNumber '--max-tiles' $Rest[$i] $true '(tiles per tiled OCR pass)' }
        elseif ($Rest[$i] -eq '--no-tile') { $noTile = $true }
        elseif ($Rest[$i] -eq '--needle') {
          $i++
          if ($i -ge $Rest.Count) { throw 'assert-text: --needle needs a value' }
          [void]$words.Add($Rest[$i])
        }
        elseif ("$($Rest[$i])" -like '--*') {
          throw "assert-text: unknown flag '$($Rest[$i])' - spell a flag exactly (see 'desktop.ps1 help'); to search for text that starts with --, pass it as --needle <text>$(Get-RectFlagAliasHint 'assert-text' "$($Rest[$i])")"
        }
        else { [void]$words.Add($Rest[$i]) }
        $i++
      }
      $Rest = @($words)
      $region = Resolve-Region $Rest 0
      $rw = Region-WordCount $Rest 0
      if ($Rest.Count -le $rw) { throw 'assert-text: empty needle' }
      $needle = (@($Rest[$rw..($Rest.Count - 1)]) -join ' ').Trim()
      if (-not $needle) { throw 'assert-text: empty needle' }
      $occAct = (Resolve-OcclusionMode $of.Occlude $of.AllowOccluded $true).Action
      $gate = $null
      $owners = $null
      if ($null -ne $region.Win) { $gate = Invoke-OcclusionGate $region $region.Win.Handle $occAct $of.OcclGrid $region.Win.Title $Rest[0] 'assert' }
      else { $owners = Invoke-OcclusionOwners $region $occAct $of.OcclGrid }
      $f = Find-OcrHitsScaled $region.X $region.Y $region.W $region.H $needle $scaleMode $maxTiles $noTile
      $hits = $f.Hits; $lines = $f.Lines
      if ($hits.Count -eq 0) {
        $missRect = "($($region.X),$($region.Y)) $($region.W)x$($region.H)"
        $occTxt = ''
        if ($null -ne $gate) { $occTxt = "$([int][math]::Round($gate.Pct))% $($gate.Echo)" }
        elseif ($null -ne $owners -and $owners.Ran) { $occTxt = "owners $($owners.Echo)" }
        $occNote = ''
        if ($null -ne $gate -and $gate.Mismatch -gt 0 -and @($gate.Covering).Count -gt 0) {
          $occNote = " NOTE: target was occluded at start ($($gate.Echo)) - the miss may be the coverer's text, not the target's."
        } elseif ($null -ne $owners -and $owners.Ran -and @($owners.Owners).Count -gt 0) {
          $occNote = ' Sampled pixels belong to other windows - see premises below.'
        }
        throw "assert-text failed: '$needle' not found in region $missRect ($(Format-OcrRetryNote $f)); $(Format-OcrSampleTail $lines 8 @{ Rect = $missRect; Retry = (Format-OcrRetryNote $f); Occlusion = $occTxt; Needle = $needle })$occNote"
      }
      $occSeg = ''
      if ($null -ne $gate) { $occSeg = " [occ: $($gate.Echo)]" }
      elseif ($null -ne $owners -and $owners.Ran) { $occSeg = " [occ: $($owners.Echo)]" }
      "ASSERT OK: '$needle' at ($($hits[0].X),$($hits[0].Y)) $($hits[0].W)x$($hits[0].H) text='$($hits[0].Text)'$(if ($f.Tiled) { " [tiled: $($f.TileCount) tile(s), $([math]::Round($f.Ms / 1000.0, 1)) s]" })$(Get-OcrFoldMarker $hits)$occSeg"
}

# v4.4.0 (A-15): assert-color - the case body, verbatim
function Invoke-Handler-assert-color([string]$Cmd, [string[]]$Rest) {
      # assert-color <x> <y> <#RRGGBB> [--tolerance n] - pixel check, exit 0/1.
      if ($Rest.Count -lt 3) { throw 'usage: assert-color <x> <y> <#RRGGBB> [--tolerance n]' }
      $tol = 20
      $words = New-Object System.Collections.ArrayList
      $i = 0
      while ($i -lt $Rest.Count) {
        if ($Rest[$i] -eq '--tolerance') { $i++; $tol = Read-FlagNumber '--tolerance' $Rest[$i] $true '(0..255 per channel)' }
        elseif ($Rest[$i] -like '--*') { throw (Get-UnknownFlagMessage 'assert-color' "$($Rest[$i])") }
        else { [void]$words.Add($Rest[$i]) }
        $i++
      }
      $Rest = @($words)
      $hex = Get-PixelHex ([int]$Rest[0]) ([int]$Rest[1])
      $rgb = Convert-HexToRgb $Rest[2]
      $got = Convert-HexToRgb $hex
      if ([math]::Abs($got.R - $rgb.R) -gt $tol -or [math]::Abs($got.G - $rgb.G) -gt $tol -or [math]::Abs($got.B - $rgb.B) -gt $tol) {
        throw "assert-color failed: ($($Rest[0]),$($Rest[1])) is $hex, expected $($Rest[2]) (tolerance $tol)"
      }
      "ASSERT OK: ($($Rest[0]),$($Rest[1])) = $hex (expected $($Rest[2]), tol $tol)"
}

# v4.4.0 (A-15): assert-hash - the case body, verbatim
function Invoke-Handler-assert-hash([string]$Cmd, [string[]]$Rest) {
      # assert-hash <sel> ==|!= <md5>   or   assert-hash <x> <y> <w> <h> ==|!= <md5>
      # (v1.3.0 hard-required 6 tokens, so the documented <sel> form could never
      # run - audit 2026-09-29 #2. Region-WordCount picks the form, same as
      # find-text/assert-text.)
      # v1.5.1 WP-A: occlusion-strict by default like the other asserts.
      $of = Split-OcclusionFlags $Rest
      $Rest = @($of.Words)
      if ($Rest.Count -lt 3) { throw 'usage: assert-hash <sel|x y w h> ==|!= <md5>' }
      $rw = Region-WordCount $Rest 0
      $region = Resolve-Region $Rest 0
      if ($Rest.Count -le ($rw + 1)) { throw 'usage: assert-hash <sel|x y w h> ==|!= <md5>' }
      $occAct = (Resolve-OcclusionMode $of.Occlude $of.AllowOccluded $true).Action
      $gate = $null
      $owners = $null
      if ($null -ne $region.Win) { $gate = Invoke-OcclusionGate $region $region.Win.Handle $occAct $of.OcclGrid $region.Win.Title $Rest[0] 'assert' }
      else { $owners = Invoke-OcclusionOwners $region $occAct $of.OcclGrid }
      $op = $Rest[$rw]
      $want = (($Rest[($rw + 1)..($Rest.Count - 1)] -join ' ') -replace '-', '').ToLower()
      $got = Get-RegionHash $region.X $region.Y $region.W $region.H
      $ok = if ($op -eq '==') { $got -eq $want } elseif ($op -eq '!=') { $got -ne $want } else { throw "assert-hash: operator must be == or !=, got: $op" }
      if (-not $ok) { throw "assert-hash failed: region hash $got $op $want" }
      $occSeg = ''
      if ($null -ne $gate) { $occSeg = " [occ: $($gate.Echo)]" }
      elseif ($null -ne $owners -and $owners.Ran) { $occSeg = " [occ: $($owners.Echo)]" }
      "ASSERT OK: hash $got $op $want$occSeg"
}

# v4.4.0 (A-15): assert-stable - the case body, verbatim
function Invoke-Handler-assert-stable([string]$Cmd, [string[]]$Rest) {
      # assert-stable <sel|x y w h> <timeoutSec> - alias of wait-stable (the
      # exit-code contract is the assertion). v1.5.1: occlusion-strict by
      # default; --allow-occluded downgrades (--occlude overrides explicitly).
      $xr = @($Rest)
      if ($xr -notcontains '--occlude') { $xr += @('--occlude', 'strict') }
      Invoke-DesktopCommand 'wait-stable' $xr
}


# ---------------------------------------------------------------------------
# CU-OPS-COMPLETE-20261026-01 (package A): process observation, launch, wait.
#
# The gap this closes: "the app is stuck" had no accurate way out - wins only shows
# windows, and there was no way to see a process without one, wait for it to exit, or
# terminate exactly it. These commands are bound to a PID AND its creation time, because
# a PID alone is reused: an identity that does not match its recorded creation time is
# refused instead of acted on. Unreadable fields are printed as denied/unknown - never
# silently dropped, never turned into "does not exist".
#
# Termination lives in handlers-act (proc-kill) and is preview-by-default.
# ---------------------------------------------------------------------------

$script:ProcSystemNames = @('system', 'idle', 'registry', 'memory compression', 'csrss', 'wininit', 'winlogon',
  'services', 'lsass', 'smss', 'svchost', 'dwm', 'explorer', 'sihost', 'taskhostw', 'fontdrvhost',
  'spoolsv', 'audiodg', 'securityhealthservice', 'msmpeng', 'searchindexer')

# One process -> the fields every proc command reports. Each field is read under its own
# try/catch so a single protected property cannot erase the rest of the identity.
# R-04 / CU-OPS-CORRECTION-20261028-01: a failed LOOKUP is classified BEFORE it is reported.
# "Cannot find a process" is the only answer that may print exists=false; a permission or
# unknown failure means existence could not be determined, and saying "no process with that
# id" there tells the operator the opposite of the truth (a protected process was reported as
# absent). The classification uses STABLE identities - exception types and the resource-
# independent FullyQualifiedErrorId / CategoryInfo - never the message text, which is
# localized: a zh-CN host prints the same lookup failure in Chinese for the SAME error an
# en-US host reports as "Cannot find a process with the process identifier N".
function Get-ProcLookupFailureKind($err) {
  # Callers pass the ErrorRecord; a bare exception is still accepted for old call sites.
  $ex = $err
  $fqid = ''
  $cat = ''
  if ($err -is [System.Management.Automation.ErrorRecord]) {
    try { $fqid = [string]$err.FullyQualifiedErrorId } catch { $fqid = '' }
    try { $cat = [string]$err.CategoryInfo.Category } catch { $cat = '' }
    $ex = $err.Exception
  }
  $e = $ex
  while ($null -ne $e) {
    $tn = "$($e.GetType().FullName)"
    if ($e -is [System.UnauthorizedAccessException]) { return 'denied' }
    if ($tn -match 'SecurityException') { return 'denied' }
    if ($tn -match 'ItemNotFoundException|ObjectNotFoundException|ProcessNotFoundException') { return 'not-found' }
    $e = $e.InnerException
  }
  if ($fqid -match '^NoProcessFoundForGiven(Id|Name)(,|$)') { return 'not-found' }
  if ($cat -eq 'ObjectNotFound' -and "$($ex.GetType().FullName)" -eq 'Microsoft.PowerShell.Commands.ProcessCommandException') { return 'not-found' }
  if ($cat -eq 'PermissionDenied' -or $cat -eq 'SecurityError') { return 'denied' }
  return 'lookup-failed'
}

function Get-ProcSnapshot([int]$procId) {
  $snap = [ordered]@{
    pid = $procId; name = 'unknown'; path = 'unknown'; start = 'unknown'
    responding = 'unknown'; hwnd = 'unknown'; title = 'unknown'
    session = 'unknown'; threads = 'unknown'; ws_mb = 'unknown'; handles = 'unknown'
    exists = 'unknown'; exists_why = 'lookup did not run'; protected = $false
  }
  $pr = $null
  try { $pr = Get-Process -Id $procId -ErrorAction Stop }
  catch {
    # The ErrorRecord (not just its Exception) carries the stable identity the classifier reads.
    $kind = Get-ProcLookupFailureKind $_
    if ($kind -eq 'not-found') { $snap.exists = $false; $snap.exists_why = 'the process is not running' }
    else { $snap.exists = 'unknown'; $snap.exists_why = "$kind - $($_.Exception.Message)" }
    return $snap
  }
  $snap.exists = $true
  $snap.exists_why = ''
  try { $snap.name = [string]$pr.ProcessName } catch { $snap.name = 'denied' }
  if ($script:ProcSystemNames -contains $snap.name.ToLowerInvariant()) { $snap.protected = $true }
  if ($procId -eq 0 -or $procId -eq 4) { $snap.protected = $true }
  try { $snap.path = [string]$pr.Path } catch { $snap.path = 'denied' }
  if ($snap.path -eq '') { $snap.path = 'denied' }
  try { $snap.start = $pr.StartTime.ToString('o') } catch { $snap.start = 'denied' }
  try { $snap.responding = [bool]$pr.Responding } catch { $snap.responding = 'denied' }
  try { $snap.hwnd = $pr.MainWindowHandle.ToInt64() } catch { $snap.hwnd = 'denied' }
  try { $snap.title = [string]$pr.MainWindowTitle } catch { $snap.title = 'denied' }
  try { $snap.session = [int]$pr.SessionId } catch { $snap.session = 'denied' }
  try { $snap.threads = [int]$pr.Threads.Count } catch { $snap.threads = 'denied' }
  try { $snap.ws_mb = [int][math]::Round($pr.WorkingSet64 / 1MB) } catch { $snap.ws_mb = 'denied' }
  try { $snap.handles = [int]$pr.HandleCount } catch { $snap.handles = 'denied' }
  return $snap
}

function Format-ProcSnapshot($s) {
  if ($s.exists -eq $false) { return "pid=$($s.pid) exists=false (no process with that id right now)" }
  if ($s.exists -ne $true) { return "pid=$($s.pid) exists=unknown (existence could not be determined: $($s.exists_why))" }
  $hw = if ($s.hwnd -eq 'unknown' -or $s.hwnd -eq 'denied') { $s.hwnd } else { '0x' + ([int64]$s.hwnd).ToString('X') }
  return ("pid=$($s.pid) name=$($s.name) start=$($s.start) path=$($s.path) responding=$($s.responding) hwnd=$hw title='$($s.title)' session=$($s.session) threads=$($s.threads) ws=$($s.ws_mb)MB handles=$($s.handles)" + $(if ($s.protected) { ' protected=yes' } else { '' }))
}

# Is this PID still the same process that was observed? Creation time is the identity:
# a reused PID has a different one. CU-OPS-ADJ-01 (v4.6.1): the comparison is EXACT ticks,
# with no tolerance - a 1s tolerance still let a process created one second after the pin
# pass as "the same". Both sides come from Process.StartTime (the same FILETIME), so there
# is no read jitter for a tolerance to absorb.
function Test-ProcIdentity([int]$procId, [string]$createdIso) {
  $s = Get-ProcSnapshot $procId
  if ($s.exists -ne $true) {
    $why = $(if ($s.exists -eq $false) { 'process-not-running' } else { "process-existence-unknown: $($s.exists_why)" })
    return @{ Ok = $false; Why = $why; Snap = $s }
  }
  if ($createdIso -eq '' -or $null -eq $createdIso) { return @{ Ok = $true; Why = 'no-created-pin'; Snap = $s } }
  if ($s.start -eq 'denied' -or $s.start -eq 'unknown') { return @{ Ok = $false; Why = "creation time unreadable ($($s.start)) so the identity cannot be confirmed"; Snap = $s } }
  $want = [datetime]::MinValue
  if (-not [datetime]::TryParse($createdIso, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$want)) {
    if (-not [datetime]::TryParse($createdIso, [ref]$want)) { return @{ Ok = $false; Why = "unparseable --created '$createdIso'"; Snap = $s } }
  }
  $have = [datetime]::Parse($s.start, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
  $diff = ($have.ToUniversalTime() - $want.ToUniversalTime()).TotalSeconds
  if ($diff -ne 0) { return @{ Ok = $false; Why = "creation time mismatch: recorded $createdIso, now $($s.start) (diff $diff s; the creation time must be exact - any other process, however close, is a different one)"; Snap = $s } }
  return @{ Ok = $true; Why = 'creation time matches exactly'; Snap = $s }
}

# proc-list [nameFilter] - every process, window or not. The window columns are blank
# for a process without one; that is the point (a background app has no `wins` row).
function Invoke-Handler-proc-list([string]$Cmd, [string[]]$Rest) {
  $own = Strip-OwnFlags $Rest 'proc-list'
  $words = @($own.Rest)
  $filter = ''
  foreach ($a in $words) {
    if ($filter) { throw 'usage: proc-list [name-filter]' }
    $filter = "$a"
  }
  $all = @(Get-Process | Sort-Object ProcessName, Id)
  $n = 0
  foreach ($pr in $all) {
    $name = ''
    try { $name = [string]$pr.ProcessName } catch { $name = 'unknown' }
    if ($filter -and ($name -notlike "*$filter*")) { continue }
    $s = Get-ProcSnapshot ([int]$pr.Id)
    $line = Format-ProcSnapshot $s
    if ($s.exists -eq $true -and ($s.hwnd -eq 0)) { $line = $line + ' nowindow=yes' }
    $line
    $n++
  }
  "proc-list: $n process(es)$(if ($filter) { " matching '$filter'" }) of $(@($all).Count) total  (a process without a visible window is listed too - no nowindow row is an absence of that process, not of its window)"
}

# proc-info <pid> - one identity, plus every top-level window the PID owns.
function Invoke-Handler-proc-info([string]$Cmd, [string[]]$Rest) {
  $own = Strip-OwnFlags $Rest 'proc-info'
  $words = @($own.Rest)
  if ($words.Count -lt 1) { throw 'usage: proc-info <pid>' }
  $pidNum = 0
  if (-not [int]::TryParse([string]$words[0], [ref]$pidNum)) { throw "proc-info: '$($words[0])' is not a pid" }
  $s = Get-ProcSnapshot $pidNum
  Format-ProcSnapshot $s
  if ($s.exists -eq $true) {
    $wins = @(Get-WinList | Where-Object { [int]$_.Pid -eq $pidNum })
    if (@($wins).Count -eq 0) { 'windows: none visible to this desktop (a background process legitimately has no window)' }
    else {
      "windows: $(@($wins).Count)"
      foreach ($w in $wins) { "  hwnd=0x$(([int64]$w.Handle).ToString('X')) class=$($w.Class) rect=($($w.Left),$($w.Top))-($($w.Right),$($w.Bottom)) title='$($w.Title)'" }
    }
  }
}

# proc-wait <pid> --exit|--window [--created <iso>] [--timeout s] [--interval ms]
# Two different predicates, deliberately not one: the process ending and its window
# disappearing are separate facts, and a caller that needs one must not be told the other.
function Invoke-Handler-proc-wait([string]$Cmd, [string[]]$Rest) {
  $own = Strip-OwnFlags $Rest 'proc-wait'
  $words = @($own.Rest)
  $waitExit = [bool]$own.Values['--exit']
  $waitWin = [bool]$own.Values['--window']
  $created = [string]$own.Values['--created']
  $timeout = [int]$own.Values['--timeout']
  $interval = [int]$own.Values['--interval']
  if ($words.Count -lt 1) { throw 'usage: proc-wait <pid> [--exit|--window] [--created <iso>] [--timeout s] [--interval ms]' }
  if ($waitExit -eq $waitWin) { throw 'proc-wait: say which predicate to wait for: --exit (process gone) or --window (a top-level window appears) - exactly one' }
  $mode = if ($waitExit) { 'exit' } else { 'window' }
  $pidNum = 0
  if (-not [int]::TryParse([string]$words[0], [ref]$pidNum)) { throw "proc-wait: '$($words[0])' is not a pid" }
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $lastWhy = ''
  while ($sw.Elapsed.TotalSeconds -lt $timeout) {
    $id = Test-ProcIdentity $pidNum $created
    if (-not $id.Ok) {
      if ($id.Why -eq 'process-not-running') {
        if ($mode -eq 'exit') { "proc-wait: pid=$pidNum exited after $([math]::Round($sw.Elapsed.TotalSeconds,1))s (creation pin: $(if ($created) { $created } else { 'none' }))"; return }
        throw "proc-wait: pid=$pidNum is not running, so --window can never be satisfied (waited $([math]::Round($sw.Elapsed.TotalSeconds,1))s)"
      }
      throw "proc-wait: identity refused - $($id.Why)"
    }
    if ($mode -eq 'window') {
      $hasWin = $false
      try { $hasWin = ($id.Snap.hwnd -ne 0 -and $id.Snap.hwnd -ne 'denied' -and $id.Snap.hwnd -ne 'unknown') } catch { $hasWin = $false }
      if ($hasWin) { "proc-wait: pid=$pidNum window appeared after $([math]::Round($sw.Elapsed.TotalSeconds,1))s hwnd=0x$(([int64]$id.Snap.hwnd).ToString('X')) title='$($id.Snap.title)'  start=$($id.Snap.start)"; return }
    } else {
      # --exit: the process is running, that is all this poll proved
      $lastWhy = 'still running'
    }
    Start-Sleep -Milliseconds $interval
  }
  if ($mode -eq 'exit') { throw "proc-wait: timeout after ${timeout}s - pid=$pidNum still running ($lastWhy). A kill request is a separate, explicit command (proc-kill); this wait does not escalate by itself" }
  throw "proc-wait: timeout after ${timeout}s - pid=$pidNum has no top-level window yet (a background process may never get one)"
}

# ---------------------------------------------------------------------------
# CU-OPS package F (v4.6.0): tpl-find - deterministic template location.
# Determinism is the whole contract: ONE nearest-neighbour resample per requested
# scale (no interpolation modes to drift), integer pixel comparison with an explicit
# per-channel tolerance, a bounded search area and a bounded time budget, and its own
# numbers printed. Multi-hit is a REFUSAL, not a guess: two matches mean the caller
# has not said which one it means, and picking the first would be the "roughly this
# title" mistake moved into pixels. imgclick keeps its own semantics; this command
# only reports points and never clicks.
# ---------------------------------------------------------------------------
function Get-Bitmap32Bytes($bmp) {
  $rect = New-Object System.Drawing.Rectangle(0, 0, $bmp.Width, $bmp.Height)
  $bd = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $bytes = New-Object byte[] ($bd.Stride * $bmp.Height)
    [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $bytes.Length)
  } finally { $bmp.UnlockBits($bd) }
  return @{ Bytes = $bytes; Stride = $bd.Stride; W = $bmp.Width; H = $bmp.Height }
}

function ConvertTo-Bitmap32($bmp) {
  if ($bmp.PixelFormat -eq [System.Drawing.Imaging.PixelFormat]::Format32bppArgb) { return $bmp }
  $norm = New-Object System.Drawing.Bitmap($bmp.Width, $bmp.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($norm)
  try { $g.DrawImage($bmp, 0, 0, $bmp.Width, $bmp.Height) } finally { $g.Dispose() }
  return $norm
}

function Resize-BitmapNearest($bmp, [double]$scale) {
  $nw = [int][math]::Round($bmp.Width * $scale)
  $nh = [int][math]::Round($bmp.Height * $scale)
  if ($nw -lt 1 -or $nh -lt 1) { throw "tpl-find: scale $scale shrinks the template to ${nw}x${nh} - nothing to match; keep the scales so the template stays at least 1x1" }
  $dst = New-Object System.Drawing.Bitmap($nw, $nh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($dst)
  try {
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.DrawImage($bmp, 0, 0, $nw, $nh)
  } finally { $g.Dispose() }
  return $dst
}

# One position test used by the self-test only: nine anchors first (cheap rejection),
# then the full template. The scanner itself runs the compiled [TPL] loop in desktop.ps1
# (the same comparison); this PowerShell twin exists so a selftest can pin the semantics
# without a screen.
function Test-TemplateAt($hay, $need, [int]$ox, [int]$oy, [int]$tol) {
  $tw = $need.W; $th = $need.H
  $hb = $hay.Bytes; $nb = $need.Bytes
  $hs = $hay.Stride; $ns = $need.Stride
  $twLast = $tw - 1
  $thLast = $th - 1
  $xs = @(0, [int]($twLast / 2), $twLast)
  $ys = @(0, [int]($thLast / 2), $thLast)
  foreach ($ay in $ys) {
    foreach ($ax in $xs) {
      $no = $ay * $ns + $ax * 4
      if ($nb[$no + 3] -eq 0) { continue }
      $ho = ($oy + $ay) * $hs + ($ox + $ax) * 4
      if ([math]::Abs([int]$hb[$ho + 2] - [int]$nb[$no + 2]) -gt $tol) { return $false }
      if ([math]::Abs([int]$hb[$ho + 1] - [int]$nb[$no + 1]) -gt $tol) { return $false }
      if ([math]::Abs([int]$hb[$ho] - [int]$nb[$no]) -gt $tol) { return $false }
    }
  }
  for ($y = 0; $y -lt $th; $y++) {
    $nrow = $y * $ns
    $hrow = ($oy + $y) * $hs
    for ($x = 0; $x -lt $tw; $x++) {
      $no = $nrow + $x * 4
      if ($nb[$no + 3] -eq 0) { continue }
      $ho = $hrow + ($ox + $x) * 4
      if ([math]::Abs([int]$hb[$ho + 2] - [int]$nb[$no + 2]) -gt $tol) { return $false }
      if ([math]::Abs([int]$hb[$ho + 1] - [int]$nb[$no + 1]) -gt $tol) { return $false }
      if ([math]::Abs([int]$hb[$ho] - [int]$nb[$no]) -gt $tol) { return $false }
    }
  }
  return $true
}

function Invoke-Handler-tpl-find([string]$Cmd, [string[]]$Rest) {
      $own = Strip-OwnFlags $Rest 'tpl-find'
      $p = Split-Target @($own.Rest) 'tpl-find'
      if ($p.Words.Count -ne 1) { throw 'usage: tpl-find <templatePath> [--to <sel>] [--region x,y,w,h] [--space screen|window|client] [--tolerance n] [--scales 1,1.25] [--index n] [--max-ms ms]' }
      $tplPath = [string]$p.Words[0]
      if (-not (Test-Path -LiteralPath $tplPath -PathType Leaf)) { throw "template not found: $tplPath" }
      $tol = [int]$own.Values['--tolerance']
      $maxMs = [int]$own.Values['--max-ms']
      $indexPassed = [bool]$own.Present['--index']
      $index = [int]$own.Values['--index']
      $scaleText = [string]$own.Values['--scales']
      if ($scaleText -eq '') { $scaleText = '1' }
      $scales = New-Object System.Collections.ArrayList
      foreach ($s in @("$scaleText" -split ',')) {
        $sv = 0.0
        if (-not [double]::TryParse($s.Trim(), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$sv)) { throw "tpl-find: --scales needs comma-separated numbers, got '$s'; nothing was read" }
        if ($sv -lt 0.5 -or $sv -gt 2.0) { throw "tpl-find: scale $sv is outside 0.5..2.0 (bounded on purpose - a wide ladder turns a locator into a guess); nothing was read" }
        [void]$scales.Add($sv)
      }
      if ($scales.Count -lt 1 -or $scales.Count -gt 3) { throw "tpl-find: --scales accepts 1..3 values, got $($scales.Count); nothing was read" }
      $spaceArg = [string]$own.Values['--space']
      $space = if ($spaceArg) { Test-PointSpaceArg $spaceArg } elseif ($p.Sel) { 'window' } else { 'screen' }
      $created = [string]$own.Values['--created']
      if ($space -ne 'screen' -and -not $p.Sel) { throw "tpl-find: --space $space needs --to <sel> (a relative region has no origin without a named window); nothing was read" }
      $regionText = [string]$own.Values['--region']
      $tgt = $null
      if ($p.Sel) {
        $tgt = Resolve-Target $p.Sel $p.Force $p.AlwaysActivate $p.ExpectHandle $created
        Emit-ResolveNote
      }
      $origin = Get-PointSpaceOrigin $space $tgt
      $rx = 0; $ry = 0; $rw = $origin.W; $rh = $origin.H
      if ($space -eq 'screen' -and -not $regionText) {
        # screen space has no window to size the search: the default is the virtual
        # desktop, and the 3,000,000-pixel bound below decides whether that is allowed.
        $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $rx = [int]$vs.X; $ry = [int]$vs.Y; $rw = [int]$vs.Width; $rh = [int]$vs.Height
      }
      if ($regionText) {
        $rn = @("$regionText" -split ',' | ForEach-Object { $_.Trim() })
        if ($rn.Count -ne 4) { throw "tpl-find: --region needs x,y,w,h, got: $regionText" }
        $rx = [int]$rn[0]; $ry = [int]$rn[1]; $rw = [int]$rn[2]; $rh = [int]$rn[3]
      }
      if ($rw -le 0 -or $rh -le 0) { throw "tpl-find: the search region is ${rw}x${rh} - nothing to read" }
      if ($space -ne 'screen') {
        if ($rx -lt 0 -or $ry -lt 0 -or ($rx + $rw) -gt $origin.W -or ($ry + $rh) -gt $origin.H) {
          throw ('tpl-find: region ' + $rx + ',' + $ry + ',' + $rw + ',' + $rh + ' is outside the target area ' + $origin.W + 'x' + $origin.H + ' (space=' + $space + '); nothing was read and no clamping was applied')
        }
      }
      $area = [int64]$rw * [int64]$rh
      if ($area -gt 3000000) { throw "tpl-find: region $($rw)x$($rh) is $area pixels - above the 3,000,000-pixel bound; pass a smaller --region (a locator that scans the whole desktop is a guess) " }

      $tplSrc = New-Object System.Drawing.Bitmap((Get-Item -LiteralPath $tplPath).FullName)
      $tplNorm = $null
      $hits = New-Object System.Collections.ArrayList
      $positions = 0
      # CU-OPS F: do not race our OWN activation. When this call was the one that raised
      # the window (activated=yes), the client area can still be mid-repaint for a moment,
      # and a capture taken inside that window reports "no match" for a pattern that is
      # plainly there - measured 2026-10-27 on the F fixture: the first call after
      # activation failed, the identical second call matched. The settle is only paid
      # when activation actually happened, and it is printed in the receipt.
      $settleMs = 0
      if ($null -ne $tgt -and [bool]$tgt.Activated) {
        $settleMs = 300
        Start-Sleep -Milliseconds $settleMs
      }
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      try {
        $tplNorm = ConvertTo-Bitmap32 $tplSrc
        $cap = Get-ScreenBitmap ($origin.X + $rx) ($origin.Y + $ry) $rw $rh 1.0
        try {
          $hay = Get-Bitmap32Bytes $cap.Bitmap
          foreach ($s in @($scales)) {
            $tb = $null
            $t32 = $null
            try {
              $tb = Resize-BitmapNearest $tplNorm $s
              $t32 = ConvertTo-Bitmap32 $tb
              $need = Get-Bitmap32Bytes $t32
              if ($need.W -gt $hay.W -or $need.H -gt $hay.H) { continue }
              $posOut = [int64]0
              $overOut = $false
              $raw = [TPL]::Find($hay.Bytes, $hay.Stride, $hay.W, $hay.H, $need.Bytes, $need.Stride, $need.W, $need.H, $tol, ($maxMs - [int]$sw.ElapsedMilliseconds), [ref]$posOut, [ref]$overOut)
              $positions = $positions + [int]$posOut
              if ($overOut) {
                throw ('tpl-find: the search exceeded its ' + $maxMs + 'ms budget after ' + $positions + ' positions at scale ' + $s + ' - narrow --region or pass fewer --scales; no match list is being invented')
              }
              foreach ($pair in @($raw)) {
                $hx = [int]($pair -shr 32)
                $hy = [int]($pair -band 0xFFFFFFFFL)
                [void]$hits.Add([pscustomobject]@{ X = ($origin.X + $rx + $hx); Y = ($origin.Y + $ry + $hy); RelX = ($rx + $hx); RelY = ($ry + $hy); Scale = $s; W = $need.W; H = $need.H })
              }
            } finally {
              if ($null -ne $t32 -and -not [object]::ReferenceEquals($t32, $tb)) { $t32.Dispose() }
              if ($null -ne $tb) { $tb.Dispose() }
            }
          }
        } finally { $cap.Bitmap.Dispose() }
      } finally {
        if ($null -ne $tplNorm -and -not [object]::ReferenceEquals($tplNorm, $tplSrc)) { $tplNorm.Dispose() }
        $tplSrc.Dispose()
      }
      # Non-maximum suppression: matches whose boxes OVERLAP are one object seen twice
      # (a solid glyph matches at every offset inside itself, and a pattern found at two
      # scales is still one pattern). Genuinely separate copies do not overlap and are
      # kept apart - which is exactly what the ambiguity refusal below reports.
      $uniq = New-Object System.Collections.ArrayList
      foreach ($h in @($hits | Sort-Object Y, X)) {
        $dup = $false
        foreach ($u in $uniq) {
          $limX = [math]::Max([int]$h.W, [int]$u.W)
          $limY = [math]::Max([int]$h.H, [int]$u.H)
          if ([math]::Abs([int]$h.X - [int]$u.X) -lt $limX -and [math]::Abs([int]$h.Y - [int]$u.Y) -lt $limY) { $dup = $true; break }
        }
        if (-not $dup) { [void]$uniq.Add($h) }
      }
      $elapsed = [int]$sw.ElapsedMilliseconds
      if ($uniq.Count -eq 0) { throw "tpl-find: no match for '$tplPath' in region ($($origin.X + $rx),$($origin.Y + $ry)) ${rw}x${rh} (tolerance $tol, scales $scaleText, space=$space, positions=$positions ms=$elapsed settle=${settleMs}ms)" }
      if (-not $indexPassed -and $uniq.Count -gt 1) {
        $list = (@($uniq | ForEach-Object { "screen=($($_.X),$($_.Y)) rel=($($_.RelX),$($_.RelY))@$($_.Scale)" }) -join ', ')
        throw "tpl-find: $($uniq.Count) matches for '$tplPath' - ambiguous, nothing was chosen: $list. Pass --index n, or narrow --region, or raise the fidelity (lower --tolerance)."
      }
      if ($indexPassed -and $index -ge @($uniq).Count) { throw "tpl-find: --index $index is out of range - only $(@($uniq).Count) match(es) were found" }
      $chosen = if ($indexPassed) { @($uniq)[$index] } else { @($uniq)[0] }
      if ($script:Json) {
        [pscustomobject]@{
          template = (Split-Path -Leaf $tplPath)
          tolerance = $tol
          space = $space
          region = [pscustomobject]@{ x = ($origin.X + $rx); y = ($origin.Y + $ry); w = $rw; h = $rh }
          matches = @($uniq | ForEach-Object { [pscustomobject]@{ x = $_.X; y = $_.Y; relx = $_.RelX; rely = $_.RelY; w = $_.W; h = $_.H; scale = $_.Scale } })
          selected = [pscustomobject]@{ x = $chosen.X; y = $chosen.Y; relx = $chosen.RelX; rely = $chosen.RelY; w = $chosen.W; h = $chosen.H; scale = $chosen.Scale }
          positions = $positions
          ms = $elapsed
          settleMs = $settleMs
        } | ConvertTo-Json -Compress -Depth 5
      } else {
        "tpl-find: template=$(Split-Path -Leaf $tplPath) tolerance=$tol scales=$scaleText space=$space region=($($origin.X + $rx),$($origin.Y + $ry)) ${rw}x${rh} matches=$(@($uniq).Count) positions=$positions ms=$elapsed settle=${settleMs}ms"
        $k = 0
        foreach ($u in @($uniq)) { "  match[$k] screen=($($u.X),$($u.Y)) rel=($($u.RelX),$($u.RelY)) size=$($u.W)x$($u.H) scale=$($u.Scale)"; $k++ }
        "  selected index=$(if ($indexPassed) { $index } else { 0 }) screen=($($chosen.X),$($chosen.Y))  (tpl-find only locates; it never clicks)"
      }
}

# ---------------------------------------------------------------------------
# CU-OPS package G (v4.6.1): clip-info - READ-ONLY clipboard metadata.
# It exists so "what is on the clipboard, and can this tool put it back" can be
# answered WITHOUT touching the content: format names, counts, and a restorable
# verdict derived from the SAME branch Save/Restore-ClipboardState use.
# v4.6.1: this handler reads the FORMAT LIST and nothing else. It no longer calls
# Save-ClipboardState (which opens text/FileDrop, decodes the image and may write a
# temp PNG), so the "metadata only" promise is now true by construction; the image is
# reported as a FORMAT, never by size, and no carrier file is created or deleted here.
# ---------------------------------------------------------------------------
function Invoke-Handler-clip-info([string]$Cmd, [string[]]$Rest) {
      $own = Strip-OwnFlags $Rest 'clip-info'
      if (@($own.Rest).Count -ne 0) { throw 'usage: clip-info [--json] - it takes no positional arguments (use paste/paste-file/copy-file to change the clipboard)' }
      $formats = @()
      $readErr = ''
      try {
        $do = [System.Windows.Forms.Clipboard]::GetDataObject()
        if ($null -ne $do) { $formats = @($do.GetFormats()) } else { $readErr = 'GetDataObject returned null (the clipboard could not be opened)' }
      } catch { $readErr = [string]$_.Exception.Message }
      $plan = Get-ClipboardFormatPlan $formats
      # A plan-shaped state, not a saved snapshot: content fields are deliberately empty
      # because this command never opened them. G-1: a format-list read that FAILED is
      # reported as unknown, never as an empty clipboard.
      $st = @{ Kind = $plan.Kind; Text = ''; Files = @(); ImagePath = ''; ImageSaveError = $false; Formats = @($plan.Formats); Extras = @($plan.Extras) }
      if ($readErr -ne '') { $st.Kind = 'unknown'; $st.ReadError = $readErr }
      $imgNote = if ($plan.HasImage) { 'Bitmap/DIB format present - content NOT decoded by this read-only command (the writing command saves the carrier)' } else { 'none' }
      $textNote = if ($plan.HasText) { 'present - content NOT read by this read-only command' } else { 'none' }
      $filesNote = if ($plan.HasFiles) { 'FileDrop present - the list was NOT read by this read-only command' } else { 'none' }
      $extrasNote = if ($readErr -ne '') { 'NOT READ - the format list could not be opened, so this is not an empty clipboard' } elseif (@($plan.Extras).Count -gt 0) { Format-ClipboardFormatNames $plan.Extras } else { 'none' }
      $restorable = Get-ClipboardRestorableVerdict $st
      if ($script:Json) {
        [pscustomobject]@{
          kind = $st.Kind
          read_error = $readErr
          formats = $formats
          extras = @($plan.Extras)
          text = $textNote
          files = $filesNote
          image = $imgNote
          restorable = $restorable
        } | ConvertTo-Json -Compress -Depth 4
      } else {
        $countText = if ($readErr -ne '') { 'unknown' } else { [string]@($plan.Formats).Count }
        "clipboard kind=$($st.Kind) formats=$countText unknown=$($extrasNote)"
        "  formats: " + $(if ($readErr -ne '') { '(not read - the format list could not be opened)' } elseif (@($plan.Formats).Count -gt 0) { (@($plan.Formats) -join ', ') } else { '(none)' })
        "  text: $textNote"
        "  files: $filesNote"
        "  image: $imgNote"
        "  restorable by this tool: $restorable"
        "  (read-only: no text, file list or image was read or decoded, and nothing was written)"
      }
}

# ---------------------------------------------------------------------------
# CU-OPS package D (v4.6.0): wait-cond - ONE bounded wait for the conditions the
# older commands each cover separately, with the three outcomes kept distinct:
# matched, timed out, and COULD NOT READ (a read that throws is never reported as
# "the condition did not happen"). Read-only; it never activates or clicks.
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# R-03 (CU-OPS-FINAL-REVIEW-20261027-01): a UIA read is a CROSS-PROCESS call to the
# target's own provider. When that provider does not answer, the call blocks inside the
# COM boundary and no Stopwatch in this process can interrupt it - the old wait-cond loop
# measured 1837ms for a 1000ms budget and, if the provider never answered at all, had no
# exit at all. The read therefore runs in a SELF-BUILT probe process with the REMAINDER of
# the declared budget; on expiry that process is terminated. The target application is
# never touched or killed: only this tool's own worker is.
# ---------------------------------------------------------------------------
function Get-UiaProbeScriptSource {
  return @'
param([string]$ArgsFile, [string]$OutFile)
$ErrorActionPreference = 'Stop'
function Write-Result($o) {
  $j = $o | ConvertTo-Json -Depth 6 -Compress
  [System.IO.File]::WriteAllText($OutFile, $j, (New-Object System.Text.UTF8Encoding($false)))
}
try {
  $a = [System.IO.File]::ReadAllText($ArgsFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  Add-Type -AssemblyName UIAutomationClient
  Add-Type -AssemblyName UIAutomationTypes
  $hwnd = [IntPtr]([int64]$a.hwnd)
  $want = [string]$a.name
  $el = $null
  $fhErr = ''
  try { $el = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd) } catch { $fhErr = $_.Exception.Message }
  if ($null -eq $el) {
    if ($fhErr -ne '') { Write-Result @{ status = 'error'; value = ''; detail = ('FromHandle failed: ' + $fhErr); scanned = 0 }; exit 0 }
    Write-Result @{ status = 'no-uia-root'; value = ''; detail = 'FromHandle returned null without an error'; scanned = 0 }; exit 0
  }
  $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
  $q = New-Object System.Collections.Queue
  $q.Enqueue($el)
  $found = $null
  $n = 0
  $walkErr = ''
  $readErrs = 0
  $readFirst = ''
  while ($q.Count -gt 0 -and $n -lt 6000) {
    $cur = $q.Dequeue()
    $n++
    $nm = ''
    # The property-read form is deliberately the METHOD: PowerShell 5.1 silently answers
    # $null for a throwing .NET property getter (measured), so a denied Name read through
    # .Current.Name would look like an empty name and the probe would claim not-found. The
    # method form raises a catchable exception, which is counted and reported below.
    try { $nm = [string]$cur.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::NameProperty) } catch { $readErrs++; if ($readFirst -eq '') { $readFirst = $_.Exception.Message } }
    if ($nm -ne '' -and $nm.ToLowerInvariant().Contains($want.ToLowerInvariant())) { $found = $cur; break }
    try {
      $ch = $walker.GetFirstChild($cur)
      while ($null -ne $ch) { $q.Enqueue($ch); $ch = $walker.GetNextSibling($ch) }
    } catch {
      if ($walkErr -eq '') { $walkErr = $_.Exception.Message }
      break
    }
  }
  if ($null -eq $found) {
    if ($walkErr -ne '') { Write-Result @{ status = 'error'; value = ''; detail = ('the UIA tree walk failed after ' + $n + ' node(s): ' + $walkErr); scanned = $n }; exit 0 }
    if ($readErrs -gt 0) { Write-Result @{ status = 'error'; value = ''; detail = ('' + $readErrs + ' node(s) could not be read (first: ' + $readFirst + '); no name match among the readable nodes'); scanned = $n }; exit 0 }
    Write-Result @{ status = 'not-found'; value = ''; detail = ''; scanned = $n }; exit 0
  }
  $val = ''
  $tp = $null
  try { $tp = $found.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern) } catch { $tp = $null }
  if ($null -ne $tp) {
    $val = 'toggle:' + [string]$tp.Current.ToggleState
  } else {
    $si = $null
    try { $si = $found.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern) } catch { $si = $null }
    if ($null -ne $si) {
      $val = 'selected:' + ([bool]$si.Current.IsSelected).ToString()
    } else {
      $ec = $null
      try { $ec = $found.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern) } catch { $ec = $null }
      if ($null -ne $ec) { $val = 'expand:' + [string]$ec.Current.ExpandCollapseState } else { $val = 'no-state-pattern' }
    }
  }
  Write-Result @{ status = 'ok'; value = $val; detail = ''; scanned = $n }
  exit 0
} catch {
  Write-Result @{ status = 'error'; value = ''; detail = ($_.Exception.Message); scanned = 0 }
  exit 0
}
'@
}

function Get-UiaProbeTempDir {
  $d = Join-Path $env:TEMP 'agent-computer-use-uiaprobe'
  if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
  return $d
}

# Runs ONE probe with a hard wall-clock bound. Every exit path returns the same shape, and
# every self-built resource is disposed or deleted here - no probe script, args file or
# result file survives the call, and a timed-out worker is waited for after Kill.
function Invoke-BoundedUiaProbe([int64]$hwnd, [string]$nameSub, [int]$budgetMs, [string]$ScriptText = '') {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $out = @{ Status = 'error'; Value = ''; Detail = 'probe did not run'; Scanned = 0; ElapsedMs = 0; BudgetMs = [int]$budgetMs; ChildPid = 0; Killed = $false }
  $dir = Get-UiaProbeTempDir
  $tag = [guid]::NewGuid().ToString('N')
  $af = Join-Path $dir "args-$tag.json"
  $of = Join-Path $dir "out-$tag.json"
  $sf = Join-Path $dir "probe-$tag.ps1"
  $proc = $null
  try {
    if ($ScriptText -eq '') { $ScriptText = Get-UiaProbeScriptSource }
    $argJson = ConvertTo-Json -InputObject @{ hwnd = [int64]$hwnd; name = [string]$nameSub } -Compress
    [System.IO.File]::WriteAllText($af, $argJson, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($sf, $ScriptText, (New-Object System.Text.UTF8Encoding($false)))
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$sf`" -ArgsFile `"$af`" -OutFile `"$of`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.EnvironmentVariables['DTX_SHOT_AUTOTRIM'] = '0'
    $proc = [System.Diagnostics.Process]::Start($psi)
    $out.ChildPid = [int]$proc.Id
    $left = [int]([math]::Max(1, $budgetMs))
    $exited = $proc.WaitForExit($left)
    $out.ElapsedMs = [int]$sw.ElapsedMilliseconds
    if (-not $exited) {
      $out.Killed = $true
      try { $proc.Kill() } catch { }
      try { [void]$proc.WaitForExit(2000) } catch { }
      $out.Status = 'timeout'
      $out.Detail = "no answer within ${left}ms; this tool's own probe process was terminated (the target application and its provider were not touched)"
      return $out
    }
    if (-not (Test-Path -LiteralPath $of)) {
      $out.Status = 'error'
      $out.Detail = "the probe exited with code $($proc.ExitCode) without a result file"
      return $out
    }
    $res = $null
    try { $res = [System.IO.File]::ReadAllText($of, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $res = $null }
    if ($null -eq $res) { $out.Status = 'error'; $out.Detail = 'the probe result file was not valid JSON'; return $out }
    if ($res.PSObject.Properties['status']) { $out.Status = [string]$res.status }
    if ($res.PSObject.Properties['value']) { $out.Value = [string]$res.value }
    if ($res.PSObject.Properties['detail']) { $out.Detail = [string]$res.detail }
    if ($res.PSObject.Properties['scanned']) { $out.Scanned = [int]$res.scanned }
    if ($out.Status -eq '') { $out.Status = 'error'; $out.Detail = 'the probe returned no status' }
    return $out
  } catch {
    $out.Status = 'error'
    $out.Detail = $_.Exception.Message
    $out.ElapsedMs = [int]$sw.ElapsedMilliseconds
    return $out
  } finally {
    foreach ($f in @($af, $of, $sf)) { try { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force } } catch { } }
    if ($null -ne $proc) { try { $proc.Dispose() } catch { } }
  }
}

function Invoke-Handler-wait-cond([string]$Cmd, [string[]]$Rest) {
      $own = Strip-OwnFlags $Rest 'wait-cond'
      $words = @($own.Rest)
      if ($words.Count -ne 1) { throw 'usage: wait-cond <sel> (--win | --gone | --foreground | --text <needle> | --uia <nameSub> [--state <On|Off|Expanded|Collapsed|Selected|NotSelected>]) [--timeout s] [--interval ms]' }
      $sel = [string]$words[0]
      $wantWin = [bool]$own.Values['--win']
      $wantGone = [bool]$own.Values['--gone']
      $wantFg = [bool]$own.Values['--foreground']
      $needle = [string]$own.Values['--text']
      $uiaName = [string]$own.Values['--uia']
      $wantState = [string]$own.Values['--state']
      $preds = 0
      foreach ($b in @($wantWin, $wantGone, $wantFg, [bool]($needle -ne ''), [bool]($uiaName -ne ''))) { if ($b) { $preds++ } }
      if ($preds -ne 1) { throw 'wait-cond: give exactly ONE predicate (--win, --gone, --foreground, --text <needle> or --uia <nameSub>); nothing was polled' }
      if ($wantState -ne '' -and $uiaName -eq '') { throw 'wait-cond: --state only means something with --uia <nameSub>; nothing was polled' }
      if ($wantState -ne '' -and $wantState -notin @('On', 'Off', 'Expanded', 'Collapsed', 'Selected', 'NotSelected')) { throw "wait-cond: --state must be On|Off|Expanded|Collapsed|Selected|NotSelected, got '$wantState'; nothing was polled" }
      $timeout = [int]$own.Values['--timeout']
      $interval = [int]$own.Values['--interval']
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      $lastRead = ''
      $readErrors = 0
      $polls = 0
      while ($sw.Elapsed.TotalSeconds -lt $timeout) {
        $polls++
        $ok = $false
        try {
          if ($wantWin -or $wantGone -or $wantFg) {
            $w = Resolve-Window $sel
            if ($wantWin) { $ok = ($null -ne $w); $lastRead = $(if ($w) { "hwnd=$($w.Handle) pid=$($w.Pid)" } else { 'no window' }) }
            elseif ($wantGone) { $ok = ($null -eq $w); $lastRead = $(if ($w) { "still hwnd=$($w.Handle) pid=$($w.Pid)" } else { 'gone' }) }
            else {
              # R-02: compare the FOREGROUND HWND with the resolved window's own handle.
              # A pid string only proves "some window of that process" is in front - a second
              # top-level window of the same process, a reused pid or a stale handle would all
              # read as met. The title is reported, never used as the identity.
              $fg = Get-ForegroundIdentity
              $ok = ($null -ne $w) -and ([int64]$fg.Hwnd -eq [int64]$w.Handle) -and ([int64]$w.Handle -ne 0)
              $lastRead = "foreground hwnd=0x$($fg.Hwnd.ToString('X')) pid=$($fg.Pid) title='$($fg.Title)' target hwnd=$(if ($null -ne $w) { '0x' + ([int64]$w.Handle).ToString('X') } else { 'none' }) pid=$(if ($null -ne $w) { $w.Pid } else { 'none' })"
            }
          } elseif ($needle -ne '') {
            $w = Resolve-Window $sel
            if (-not $w) { throw "target window '$sel' is gone - a text wait cannot read a window that is not there" }
            $r = Get-TargetRect $w
            if ($null -eq $r) { throw "the target rect for '$sel' could not be read now" }
            # W-1: the OCR read gets only what is LEFT of the declared timeout, and a read
            # that runs out of budget is a read ERROR - the miss inside it is not evidence
            # that the text is absent.
            $remaining = [int][math]::Floor(($timeout - $sw.Elapsed.TotalSeconds) * 1000)
            if ($remaining -lt 1) { $remaining = 1 }
            $f = Find-OcrHitsScaled $r.X $r.Y $r.W $r.H $needle 'auto' 16 $false $remaining
            if ($f.TimedOut) {
              $readErrors++
              $why = $(if ($f.Note) { [string]$f.Note } else { "no complete pass within ${remaining}ms" })
              $lastRead = "text read timed out: $why - the partial read is not evidence that the text is absent"
              $ok = $false
            } else {
              $ok = (@($f.Hits).Count -gt 0)
              $lastRead = "ocr hits=$(@($f.Hits).Count)"
            }
          } else {
            # R-03: the UIA read gets only what is LEFT of the declared timeout, and it runs
            # in a killable probe process, so a blocking provider cannot outlive the budget.
            $w = Resolve-Window $sel
            if ($null -eq $w) {
              $got = 'gone'
              $lastRead = 'gone (the target window is not there)'
              $ok = $false
            } else {
              $remaining = [int][math]::Floor(($timeout - $sw.Elapsed.TotalSeconds) * 1000)
              if ($remaining -lt 1) { $remaining = 1 }
              $probe = Invoke-BoundedUiaProbe ([int64]$w.Handle) $uiaName $remaining
              if ($probe.Status -eq 'timeout') {
                $readErrors++
                $lastRead = "uia read timed out: no answer within $($probe.ElapsedMs)ms of a ${remaining}ms budget; this tool's own probe process was terminated and the target provider was not touched"
                $ok = $false
              } elseif ($probe.Status -eq 'error') {
                $readErrors++
                $lastRead = "read error: $($probe.Detail)"
                $ok = $false
              } else {
                $got = $(if ($probe.Status -eq 'ok') { [string]$probe.Value } else { [string]$probe.Status })
                $lastRead = "$got (probe $($probe.ElapsedMs)ms, scanned $($probe.Scanned) node(s))"
                if ($wantState -eq '') { $ok = ($got -ne 'gone' -and $got -ne 'no-uia-root' -and $got -ne 'not-found' -and $got -ne 'no-state-pattern') }
                elseif ($wantState -in @('On', 'Off')) { $ok = ($got -ceq ('toggle:' + $wantState)) }
                elseif ($wantState -in @('Expanded', 'Collapsed')) { $ok = ($got -ceq ('expand:' + $wantState)) }
                else { $ok = ($got -ceq ('selected:' + $(if ($wantState -eq 'Selected') { 'True' } else { 'False' }))) }
              }
            }
          }
        } catch {
          $readErrors++
          $lastRead = 'read error: ' + $_.Exception.Message
        }
        if ($ok) {
          $mode = $(if ($wantWin) { 'win' } elseif ($wantGone) { 'gone' } elseif ($wantFg) { 'foreground' } elseif ($needle -ne '') { 'text' } else { 'uia' })
          "wait-cond $mode met after $([math]::Round($sw.Elapsed.TotalSeconds,1))s ($polls polls): $lastRead"
          return
        }
        Start-Sleep -Milliseconds $interval
      }
      if ($readErrors -gt 0 -and $readErrors -eq $polls) {
        throw "wait-cond: timed out after ${timeout}s but EVERY poll failed to read ($lastRead) - this is a read failure, not evidence the condition stayed false"
      }
      $mode = $(if ($wantWin) { 'win' } elseif ($wantGone) { 'gone' } elseif ($wantFg) { 'foreground' } elseif ($needle -ne '') { 'text' } else { 'uia' })
      throw "wait-cond: timeout after ${timeout}s waiting for $mode on '$sel' ($polls polls, $readErrors read errors); last read: $lastRead"
}

# ---------------------------------------------------------------------------
# CU-OPS package H (v4.6.0): capabilities - the command surface DERIVED from the
# dispatcher's own registry, not a second hand-written list. Each name comes from
# $script:StHandlerGroups (whose total this command re-checks), flags come from the
# same private/shared tables the parsers read, and the entry identity is the file
# this process is actually running. A name that is registered but unreachable, or
# a registry total that disagrees with the names summed by group, is an error.
# ---------------------------------------------------------------------------
function Invoke-Handler-capabilities([string]$Cmd, [string[]]$Rest) {
      $own = Strip-OwnFlags $Rest 'capabilities'
      if (@($own.Rest).Count -ne 0) { throw 'usage: capabilities [--json] - it takes no positional arguments' }
      $names = New-Object System.Collections.ArrayList
      foreach ($gk in @(Get-HashKeys $script:StHandlerGroups | Sort-Object)) {
        foreach ($n in @($script:StHandlerGroups[$gk])) { [void]$names.Add([pscustomobject]@{ Name = [string]$n; Group = [string]$gk }) }
      }
      $groupsCount = @(Get-HashKeys $script:StHandlerGroups).Count
      $rows = New-Object System.Collections.ArrayList
      foreach ($r in @($names | Sort-Object Name)) {
        $ownF = @(Get-HashKeys (Get-OwnFlagSpec $r.Name) | Sort-Object)
        $sharedF = @(Get-CommandSharedSet $r.Name)
        $allF = @(Get-CommandFlagSet $r.Name)
        [void]$rows.Add([pscustomobject]@{
          name = $r.Name
          group = $r.Group
          ownFlags = $ownF
          sharedFlags = $sharedF
          flags = $allF
          # R-05: the JSON gate in the dispatcher accepts the READ family as well as the
          # action family (Test-JsonCapableCommand is the single gate). Advertising only the
          # action table marked 17 readable commands json=false while they really answer
          # --json - the capability list must come from the SAME source the gate uses.
          json = [bool](Test-JsonCapableCommand $r.Name)
        })
      }
      $entryPath = [string]$script:ToolEntryPath
      $sha = ''
      if ($entryPath -ne '' -and (Test-Path -LiteralPath $entryPath -PathType Leaf)) {
        try { $sha = (Get-FileHash -LiteralPath $entryPath -Algorithm SHA256).Hash.ToLowerInvariant() } catch { $sha = 'unreadable' }
      }
      $dpi = [string]$script:DpiMode
      if ($dpi -eq '') { $dpi = 'unreadable' }
      if ($script:Json) {
        [pscustomobject]@{
          version = $script:ToolVersion
          entry = [pscustomobject]@{ path = $entryPath; sha256 = $sha }
          environment = [pscustomobject]@{ psversion = [string]$PSVersionTable.PSVersion; dpi = $dpi; os = [string][System.Environment]::OSVersion.VersionString }
          counts = [pscustomobject]@{ groups = $groupsCount; names = @($rows).Count }
          commands = @($rows)
        } | ConvertTo-Json -Compress -Depth 6
      } else {
        "capabilities: version=$($script:ToolVersion) names=$(@($rows).Count) groups=$groupsCount"
        "  entry: $entryPath"
        "  sha256: $sha"
        "  environment: PowerShell $($PSVersionTable.PSVersion)  dpi=$dpi"
        foreach ($g in @('read', 'act', 'ui', 'batch')) {
          $gn = @($rows | Where-Object { $_.Group -eq $g })
          "  [$g] $($gn.Count): " + (($gn | ForEach-Object { $_.name }) -join ' ')
        }
        "  (flags/json per command: pass --json for the machine-readable table)"
      }
}
