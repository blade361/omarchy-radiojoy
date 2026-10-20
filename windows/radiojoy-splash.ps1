# Radiojoy terminal splash for Windows: system info with Alastor / Emily / both drawn
# beside it as a real image (sixel, Windows Terminal 1.22+), "tuning in" through radio
# static, plus a quote. Follows the wallpaper. Terminals without sixel get the
# half-block text version. Any key skips the animation; RADIOJOY_SPLASH_LOOPS=0 turns
# the animation off. Run from the PowerShell profile block (install.ps1 adds it).
. (Join-Path $PSScriptRoot 'radiojoy-common.ps1')
$who = Get-RJWho
if (-not $who) { return }
# Needs a terminal that understands escape sequences (Windows Terminal, WezTerm...).
if (-not ($env:WT_SESSION -or $env:TERM_PROGRAM -or $env:TERM)) { return }

$e = [char]27
$padL = 2
$loops = 1
if ($env:RADIOJOY_SPLASH_LOOPS -match '^\d+$') { $loops = [int]$env:RADIOJOY_SPLASH_LOOPS }
$oldEnc = [Console]::OutputEncoding
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Console]::Write((Get-RJTermSequence $who))
$global:RadiojoyWho = $who

function Get-RJVisibleWidth([string]$s) { ($s -replace "$e\[[0-9;]*[A-Za-z]", '').Length }

# A terminal query: writes $Query, reads the reply up to $End (or gives up).
function Read-RJReply([string]$Query, [char]$End, [int]$Ms = 300) {
  try { while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) } } catch { return '' }
  [Console]::Write($Query)
  $sb = New-Object System.Text.StringBuilder
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.ElapsedMilliseconds -lt $Ms) {
    if ([Console]::KeyAvailable) {
      $c = [Console]::ReadKey($true).KeyChar
      [void]$sb.Append($c)
      if ($c -eq $End) { break }
    } else { Start-Sleep -Milliseconds 5 }
  }
  $sb.ToString()
}

# The info column: fastfetch when it's installed, else a short built-in list.
function Get-RJInfo {
  if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    $out = @(& fastfetch --pipe false --logo none 2>$null)
    if ($out.Count) { return $out }
  }
  $accent = if ($who -eq 'emily') { '180;184;240' } else { '220;34;73' }
  $k = { param($name, $value) "$e[1;38;2;${accent}m$name$e[0m: $value" }
  $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
  $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
  $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
  $title = "$env:USERNAME@$env:COMPUTERNAME"
  $lines = @("$e[1;38;2;${accent}m$title$e[0m", ('-' * $title.Length))
  if ($os) {
    $lines += & $k 'OS' "$($os.Caption -replace '^Microsoft ', '') $($os.OSArchitecture)"
    $up = (Get-Date) - $os.LastBootUpTime
    $lines += & $k 'Uptime' ('{0}{1} hours, {2} mins' -f $(if ($up.Days) { "$($up.Days) days, " } else { '' }), $up.Hours, $up.Minutes)
  }
  if ($cs) { $lines += & $k 'Host' "$($cs.Manufacturer) $($cs.Model)" }
  $lines += & $k 'Shell' "PowerShell $($PSVersionTable.PSVersion)"
  $lines += & $k 'Terminal' $(if ($env:WT_SESSION) { 'Windows Terminal' } elseif ($env:TERM_PROGRAM) { $env:TERM_PROGRAM } else { 'Console' })
  if ($cpu) { $lines += & $k 'CPU' ($cpu.Name.Trim() -replace '\s+', ' ') }
  if ($os) {
    $total = $os.TotalVisibleMemorySize / 1MB; $used = $total - $os.FreePhysicalMemory / 1MB
    $lines += & $k 'Memory' ('{0:0.00} GiB / {1:0.00} GiB ({2:0}%)' -f $used, $total, (100 * $used / $total))
  }
  $lines += ''
  $lines += ((0..7 | ForEach-Object { "$e[4${_}m   " }) -join '') + "$e[0m"
  $lines
}

# Under the info: a quote (Emily's in her periwinkle), a status line and Radiojoy Week.
function Write-RJQuote {
  $color = if ($who -eq 'emily') { '180;184;240' } else { '220;34;73' }
  $status = switch ($who) {
    'alastor' { "$([char]::ConvertFromUtf32(0x1F4FB))  Station: 666 AM  $([char]0xB7)  On air since 1933" }
    'emily' { "$([char]::ConvertFromUtf32(0x1F607))  Halo: polished  $([char]0xB7)  Wings: 6  $([char]0xB7)  Joy: 100%" }
    default { "$([char]::ConvertFromUtf32(0x1F4FB))$([char]::ConvertFromUtf32(0x1F607))  Now playing: Radiojoy on 666 AM" }
  }
  $pad = ' ' * $padL
  [Console]::Write("`n")
  $q = Get-RJQuote $who
  if ($q) { [Console]::Write("$pad$e[3;38;2;${color}m$q$e[0m`n") }
  [Console]::Write("$pad$e[38;2;157;153;188m$status$e[0m`n")
  $week = Get-RJWeek
  $star = [char]0x2605
  if ($week.Prompt) { [Console]::Write("$pad$e[1;38;2;242;193;78m$star  Radiojoy Week $([char]0xB7) $($week.Prompt)$e[0m`n") }
  elseif ($null -ne $week.DaysUntil) {
    $s = if ($week.DaysUntil -eq 1) { '' } else { 's' }
    [Console]::Write("$pad$e[38;2;242;193;78m$star  Radiojoy Week in $($week.DaysUntil) day$s$e[0m`n")
  }
}

# Shows frames[1..] then frames[0] at the saved cursor position; any key skips.
function Show-RJFrames($frames) {
  [Console]::Write("$e[?25l")
  $stop = $false
  for ($l = 0; $l -lt $loops -and -not $stop; $l++) {
    for ($i = 1; $i -lt $frames.Count; $i++) {
      [Console]::Write("$e" + '8' + $frames[$i])
      Start-Sleep -Milliseconds 80
      if ([Console]::KeyAvailable) { [void][Console]::ReadKey($true); $stop = $true; break }
    }
  }
  [Console]::Write("$e" + '8' + $frames[0] + "$e[?25h")
}

function Get-RJPngSize([string]$Path) {
  $fs = [IO.File]::OpenRead($Path)
  try {
    $b = New-Object byte[] 24; [void]$fs.Read($b, 0, 24)
    # big-endian; [int] first, since -shl on a byte stays a byte
    $w = ([int]$b[16] -shl 24) -bor ([int]$b[17] -shl 16) -bor ([int]$b[18] -shl 8) -bor [int]$b[19]
    $h = ([int]$b[20] -shl 24) -bor ([int]$b[21] -shl 16) -bor ([int]$b[22] -shl 8) -bor [int]$b[23]
    @($w, $h)
  } finally { $fs.Dispose() }
}

try {
  $size = $Host.UI.RawUI.WindowSize
  $cols = $size.Width; $lines = $size.Height
  $info = @(Get-RJInfo)
  $infoCols = ($info | ForEach-Object { Get-RJVisibleWidth $_ } | Measure-Object -Maximum).Maximum + 2

  $splash = Join-Path $RJTheme 'splash'
  $suffix = if ($who -eq 'radiojoy') { '' } else { "-$who" }
  $art = Join-Path $splash "art$suffix.png"
  if (-not (Test-Path -LiteralPath $art)) { $art = Join-Path $splash 'art.png' }
  $textDir = Join-Path $splash "text$suffix"
  if (-not (Test-Path -LiteralPath (Join-Path $textDir '00.txt'))) { $textDir = $splash }

  # Sixel? Ask the terminal (DA1 lists 4 when it can draw sixel images).
  $mode = 'text'; $frames = @(); $artCols = 0; $rows = 0
  $da = Read-RJReply "$e[c" 'c'
  if ($da -match '\[\?[\d;]*\b4\b[\d;]*c' -and (Test-Path -LiteralPath $art)) {
    # Windows Terminal scales sixel images from a 10x20 pixel cell; others report theirs
    $cw = 10; $ch = 20
    if (-not $env:WT_SESSION) {
      $r = Read-RJReply "$e[16t" 't'
      if ($r -match '\[6;(\d+);(\d+)t') { $ch = [int]$Matches[1]; $cw = [int]$Matches[2] }
    }
    $wh = Get-RJPngSize $art
    $colsFor = { param($r) [int][math]::Ceiling($wh[0] * $r * $ch / $wh[1] / $cw) }
    # beside the info, as tall as the window allows and narrow enough to leave the info room
    $side = $lines - 8
    while ($side -ge 8 -and ((& $colsFor $side) + $padL + $infoCols + 1) -gt $cols) { $side-- }
    if ($side -ge 8) { $mode = 'side'; $rows = $side }
    else {
      # else above the info, sized so both stay on screen
      $top = [math]::Min(20, $lines - $info.Count - 6)
      if ($top -ge 6 -and ((& $colsFor $top) + $padL) -le $cols) { $mode = 'top'; $rows = $top }
    }
    if ($mode -ne 'text') {
      $script = Join-Path $PSScriptRoot 'radiojoy-sixel.ps1'
      # System.Drawing and the C# compiler: always Windows PowerShell
      $res = if ($PSVersionTable.PSEdition -eq 'Core') {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -Art $art -Rows $rows -CellW $cw -CellH $ch 2>$null
      } else { & $script -Art $art -Rows $rows -CellW $cw -CellH $ch 2>$null }
      $parts = "$res" -split ' ', 3
      if ($parts.Count -eq 3 -and (Test-Path -LiteralPath (Join-Path $parts[2] '00.six'))) {
        $artCols = [int]$parts[0]
        $frames = @(Get-ChildItem -LiteralPath $parts[2] -Filter '*.six' | Sort-Object Name | ForEach-Object { Read-RJText $_.FullName })
        if ($loops -eq 0) { $frames = @($frames[0]) }
      } else { $mode = 'text' }
    }
  }

  if ($mode -eq 'text') {
    # half-block text frames, one string per frame, each line re-anchored to the art column
    $first = @((Read-RJText (Join-Path $textDir '00.txt')) -split "`r?`n" | Where-Object { $_ -ne '' })
    $artCols = Get-RJVisibleWidth $first[0]
    $rows = $first.Count
    if ($artCols + $padL + $infoCols -le $cols) {
      # only the numbered frames: the shared splash folder also holds the quotes
      $frames = @(Get-ChildItem -LiteralPath $textDir -Filter '*.txt' | Where-Object { $_.Name -match '^\d\d\.txt$' } | Sort-Object Name | ForEach-Object {
          $ls = @((Read-RJText $_.FullName) -split "`r?`n" | Where-Object { $_ -ne '' })
          ($ls | ForEach-Object { $_ + "$e[1B$e[$($padL + 1)G" }) -join ''
        })
      if ($loops -eq 0) { $frames = @($frames[0]) }
    } else { $mode = 'none' }
  }

  [Console]::Write("`n")
  if ($mode -eq 'top') {
    # reserve the art's rows, draw it there, then the info below it
    [Console]::Write("`n" * $rows + "$e[${rows}A$e[$($padL + 1)G$e" + '7')
    Show-RJFrames $frames
    [Console]::Write("$e" + '8' + "$e[${rows}B`r")
    foreach ($l in $info) { [Console]::Write("$l`n") }
  } elseif ($mode -eq 'none') {
    foreach ($l in $info) { [Console]::Write((' ' * $padL) + "$l`n") }
  } else {
    $region = [math]::Max($rows, $info.Count)
    [Console]::Write("`n" * $region + "$e[${region}A$e[$($padL + 1)G$e" + '7')
    Show-RJFrames $frames
    $col = $padL + $artCols + 3
    for ($j = 0; $j -lt $info.Count; $j++) {
      $down = if ($j -gt 0) { "$e[${j}B" } else { '' }
      [Console]::Write("$e" + '8' + $down + "$e[${col}G" + $info[$j] + "$e[0m")
    }
    [Console]::Write("$e" + '8' + "$e[${region}B`r")
  }
  Write-RJQuote
} catch {
  # never get in the way of the shell starting
} finally {
  [Console]::Write("$e[?25h")
  [Console]::OutputEncoding = $oldEnc
}
