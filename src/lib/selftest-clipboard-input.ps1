# lib/selftest-clipboard-input.ps1 - family clipboard-input of the selftest section, lifted out of
# lib/selftest.ps1 by A-14d (A-beta). Bodies are byte-identical to what the section carried.
# Why this family could go first: A-14b measured every family's unmet state reads, and this one
# needed exactly one thing - $codeLines - which A-14c hoisted into the orchestrator and published
# through $Ctx. So this is the first lift that moves state through the declared channel instead of
# through the call chain, and nothing outside it reads anything it binds (measured: 0 exports).
# Three of its four banners were already contiguous; the parked-pick block moves to join them, which
# is a reordering this card reports rather than hides.
function Invoke-SelftestFamily-ClipboardInput($Ctx) {
  # context handover (the one thing in this file that is not lifted text)
  $codeLines = $Ctx['codeLines']

  # ---------- unit: v1.5.2 WP-4 clipboard kind branch (audit R-05) ----------
  # The 'both' state cannot be produced faithfully from a script (see the note on
  # Save-ClipboardState), so the branch itself is pinned here - text and FileDrop
  # must no longer be exclusive buckets.
  ST-Check 'unit: clipboard kind - text+FileDrop together is its own kind' ((Resolve-ClipboardKind $true $true) -ceq 'both')
  ST-Check 'unit: clipboard kind - text alone' ((Resolve-ClipboardKind $true $false) -ceq 'text')
  ST-Check 'unit: clipboard kind - FileDrop alone' ((Resolve-ClipboardKind $false $true) -ceq 'files')
  ST-Check 'unit: clipboard kind - neither' ((Resolve-ClipboardKind $false $false) -ceq 'other')

  # ---------- unit: v1.5.2 WP-5 confusable fold is a marked SECOND pass --------
  # audit R-10: OCR reads 'QXHELLO123' as 'QXHELL01231' and 'DTX-AuditInput' as
  # 'DTX-Auditlnput', so a --verify that really succeeded used to report FAILURE.
  # The fold may only ever be a second pass, and a folded hit must never look like
  # an exact one (task order section 6: a broadened match presented as confirmed
  # is the false green the guards exist to prevent).
  $foldLines = New-Object System.Collections.ArrayList
  [void]$foldLines.Add([pscustomobject]@{ Text = 'QXHELL01231'; X = 10; Y = 10; W = 80; H = 14 })
  $fx1 = Find-OcrHits $foldLines 'QXHELLO123'
  ST-Check 'unit: confusable fold rescans only after the exact pass misses' (@($fx1).Count -eq 1)
  ST-Check 'unit: a folded hit is marked Folded' ($fx1[0].PSObject.Properties['Folded'] -and $fx1[0].Folded -eq $true)
  $foldMark = Get-OcrFoldMarker $fx1
  ST-Check 'unit: folded hit echo says confusable-fold' ($foldMark -like '*confusable-fold*')
  $exactLines = New-Object System.Collections.ArrayList
  [void]$exactLines.Add([pscustomobject]@{ Text = 'QXHELLO123'; X = 10; Y = 10; W = 80; H = 14 })
  $fx2 = Find-OcrHits $exactLines 'QXHELLO123'
  ST-Check 'unit: exact hit is NOT marked and prints no fold marker' (
    @($fx2).Count -eq 1 -and -not $fx2[0].PSObject.Properties['Folded'] -and (Get-OcrFoldMarker $fx2) -eq '')
  # the fold set is closed on purpose: S/5, Z/2, B/8 must NOT be folded.
  # NOTE the deliberate bare-call form below: wrapping a Find-OcrHits call in an
  # @() gives Object[1]{ArrayList} whose Count is always 1 - the very trap this
  # lint exists for, and it bit while these very cases were being written (the
  # selftest caught it, which is the proof the gate has teeth).
  $noFoldLines = New-Object System.Collections.ArrayList
  [void]$noFoldLines.Add([pscustomobject]@{ Text = 'RATE5OK'; X = 1; Y = 1; W = 40; H = 12 })
  $nf1 = Find-OcrHits $noFoldLines 'RATE S OK'
  ST-Check 'unit: S/5 is deliberately not folded (no broadened false green)' ($nf1.Count -eq 0)
  $zLines = New-Object System.Collections.ArrayList
  [void]$zLines.Add([pscustomobject]@{ Text = 'LINK2UP'; X = 1; Y = 1; W = 40; H = 12 })
  $nf2 = Find-OcrHits $zLines 'LINKZUP'
  ST-Check 'unit: Z/2 is deliberately not folded' ($nf2.Count -eq 0)
  # ---------- unit: v1.5.2 WP-5 strict UTF-8 gate for sent files (audit R-11) ----------
  $u8ok = Join-Path $env:TEMP ('dtx-utf8-' + [guid]::NewGuid().ToString('N') + '.txt')
  $u8bom = Join-Path $env:TEMP ('dtx-bom-' + [guid]::NewGuid().ToString('N') + '.txt')
  $u8gbk = Join-Path $env:TEMP ('dtx-gbk-' + [guid]::NewGuid().ToString('N') + '.txt')
  try {
    [System.IO.File]::WriteAllBytes($u8ok, [System.Text.Encoding]::UTF8.GetBytes('QX UTF8 OK'))
    $bomBytes = [System.Text.Encoding]::UTF8.GetBytes('QX BOM TEXT')
    $withBom = New-Object byte[] ($bomBytes.Length + 3)
    $withBom[0] = 0xEF; $withBom[1] = 0xBB; $withBom[2] = 0xBF
    [System.Array]::Copy($bomBytes, 0, $withBom, 3, $bomBytes.Length)
    [System.IO.File]::WriteAllBytes($u8bom, $withBom)
    # GBK 'zhong wen' bytes: invalid as UTF-8 - this is the exact file shape that
    # used to paste as 53 chars of garbage with exit 0
    [System.IO.File]::WriteAllBytes($u8gbk, [byte[]]@(0xD6, 0xD0, 0xCE, 0xC4))
    $r1 = Read-SendFileUtf8 $u8ok
    ST-Check 'unit: valid UTF-8 file reads exactly, no BOM' ($r1.Text -ceq 'QX UTF8 OK' -and $r1.HadBom -eq $false)
    $r2 = Read-SendFileUtf8 $u8bom
    ST-Check 'unit: UTF-8 BOM is detected and stripped from the payload' ($r2.Text -ceq 'QX BOM TEXT' -and $r2.HadBom -eq $true)
    $r3err = ''
    try { [void](Read-SendFileUtf8 $u8gbk) } catch { $r3err = $_.Exception.Message }
    ST-Check 'unit: a GBK/ANSI file is REFUSED with an actionable message' (
      $r3err -like 'file is not valid UTF-8*' -and $r3err -like '*Re-save as UTF-8*' -and $r3err -like '*D6 D0 CE C4*')
    Write-Output "      UTF-8 gate message: $r3err"
  } catch {
    ST-Check 'unit: UTF-8 gate tests run' $false
    Write-Output "      UTF-8 gate error: $($_.Exception.Message)"
  } finally {
    foreach ($tfu in @($u8ok, $u8bom, $u8gbk)) { if (Test-Path -LiteralPath $tfu) { Remove-Item -LiteralPath $tfu -Force -ErrorAction SilentlyContinue } }
  }


  # ---------- unit + lint: v4.2.0 feedback item 6 - a parked pick says parked ----------
  ST-Check 'unit: a minimized pick is labelled parked on BOTH bases, a live pick keeps its basis' (
    ((Get-WindowPickLabel 'fg' $false) -ceq 'fg') -and ((Get-WindowPickLabel 'largest' $false) -ceq 'largest') -and
    ((Get-WindowPickLabel 'fg' $true) -ceq 'parked') -and ((Get-WindowPickLabel 'largest' $true) -ceq 'parked'))
  ST-Check 'unit: Test-WindowIconic answers false for no window and for a synthetic handle instead of throwing' (
    ((Test-WindowIconic $null) -eq $false) -and ((Test-WindowIconic @{ Handle = [IntPtr]::Zero }) -eq $false))
  # the scan pattern is written WITH escapes so this very line cannot match itself.
  # both needles assembled by concatenation: a literal would make this line its own hit
  # (measured: the Iconic scan reported 3 = 2 production + 1 check).
  $p6IconNeedle = 'Add-Member -NotePropertyName ' + 'Iconic'
  $p6EchoNeedle = 'iconic=' + [char]36 + '(Get-OptValue'
  $p6IconicSites = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($p6IconNeedle) })
  $p6EchoSites = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($p6EchoNeedle) })
  ST-Check 'lint: both Resolve-Window branches stamp Iconic, and assert-window echoes it (one site each)' (
    (@($p6IconicSites).Count -eq 2) -and (@($p6EchoSites).Count -eq 1))
  $d7RowNoOwner = Format-WinRowText ([pscustomobject]@{ Pid = 1; Proc = 'p'; Class = 'c'; Popup = $false; Owner = [int64]0; Main = 'yes'; Left = 0; Top = 0; Right = 8; Bottom = 6; W = 8; H = 6; Title = 'T' })
  ST-Check 'unit: wins text row prints owner=- for an unowned window and carries main=' ($d7RowNoOwner.Contains('owner=- main=yes'))
  $d7RowOwner = Format-WinRowText ([pscustomobject]@{ Pid = 1; Proc = 'p'; Class = 'c'; Popup = $false; Owner = [int64]42; Main = 'no'; Left = 0; Top = 0; Right = 8; Bottom = 6; W = 8; H = 6; Title = 'T' })
  ST-Check 'unit: wins text row prints the real owner handle when there is one' ($d7RowOwner.Contains('owner=42 main=no'))
  # the two views of one row must not drift: the text row has exactly one producer, and the
  # JSON key set is pinned so a future column edit is a deliberate contract change.
  # !! Every search marker below is built by CONCATENATION: a scan line that contains its
  # own search string matches itself (this exact trap made the first version of these two
  # checks report "2 projection lines" - one real, one the check).
  $d7RowPat = 'rect=(' + '$($_.Left),$($_.Top))'
  $d7InlineRow = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($d7RowPat) })
  $d7CallPat = 'Format-WinRowText ' + '$_'
  $d7Calls = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($d7CallPat) })
  ST-Check 'lint: wins prints through Format-WinRowText and has no second copy of the row shape' (
    @($d7InlineRow).Count -eq 0 -and @($d7Calls).Count -eq 1)
  foreach ($d in @($d7InlineRow)) { Write-Output "      second copy of the row shape: $($d.Trim())" }
  $d7JsonPat = 'popup = [bool]$_.Popup;' + ' owner ='
  $d7JsonLine = @($codeLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Contains($d7JsonPat) })
  $d7Keys = @()
  if (@($d7JsonLine).Count -eq 1) {
    $d7Keys = @([regex]::Matches($d7JsonLine[0], '([a-z_]+) = ') | ForEach-Object { $_.Groups[1].Value })
  }
  $d7Want = @('pid', 'proc', 'class', 'popup', 'owner', 'main', 'x', 'y', 'w', 'h', 'title')
  ST-Check 'unit: wins --json row key set is exactly the pinned 11 keys (add/drop = deliberate contract edit)' (
    @($d7JsonLine).Count -eq 1 -and (@($d7Keys | Sort-Object) -join ',') -ceq (($d7Want | Sort-Object) -join ','))
  if (@($d7JsonLine).Count -ne 1) { Write-Output "      wins json projection lines found: $(@($d7JsonLine).Count)" }
  if (@($d7Keys).Count -gt 0) { Write-Output "      wins json keys: $(@($d7Keys) -join ' ')" }

}
