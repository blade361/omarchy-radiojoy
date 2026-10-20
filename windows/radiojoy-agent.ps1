# Radiojoy for Windows: runs in the background from login (a Startup shortcut) and
# makes the desktop follow the wallpaper, like radiojoy-sync on Omarchy:
#   - tray icon (the bar button): click = next wallpaper, right-click = menu with a
#     quote, Radiojoy Week and more; it goes "on air" while Spotify plays
#   - window borders and title bars (Windows 11) and the accent colour
#   - lock screen: steps one wallpaper along the order on every lock, with the
#     character art at the sides
#   - Spotify (Spicetify) and Zen / Firefox colours, notification sound
#   - Radiojoy Week: collage wallpaper via radiojoy-week.py (needs Python + Pillow)
# A wallpaper that isn't one of the theme's turns all of that off, like switching
# away from the theme on Omarchy. Needs Windows PowerShell 5.1 (WinRT, WinForms).
param([switch]$Login)
. (Join-Path $PSScriptRoot 'radiojoy-common.ps1')

$mutex = New-Object System.Threading.Mutex($false, 'Local\RadiojoyAgent')
if (-not $mutex.WaitOne(0)) { exit 0 }
New-Item -ItemType Directory -Force -Path $RJState | Out-Null
[IO.File]::WriteAllText((Join-Path $RJState 'agent.pid'), "$PID")

$logFile = Join-Path $RJState 'agent.log'
function Write-RJLog([string]$Text) {
  try {
    if ((Test-Path $logFile) -and (Get-Item $logFile).Length -gt 512KB) { Remove-Item $logFile -Force }
    Add-Content -Path $logFile -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Text) -Encoding UTF8
  } catch { }
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
if (-not ('RadiojoyNative' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'RadiojoyNative.cs') }

$config = @{ accent = $true; sounds = $true; borders = $true; python = '' }
try {
  $c = (Read-RJText (Join-Path $RJ 'config.json')) | ConvertFrom-Json
  foreach ($p in $c.PSObject.Properties) { $config[$p.Name] = $p.Value }
} catch { }
$backup = Get-RJBackup
$win11 = [Environment]::OSVersion.Version.Build -ge 22000

function ConvertFrom-RJHex([string]$Hex) { [Convert]::ToInt32($Hex.TrimStart('#'), 16) }

# --- WinRT (lock screen, media) --------------------------------------------------
$winrt = $false
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $asTaskOp = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
  $asTaskAction = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' } | Select-Object -First 1
  $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
  $null = [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime]
  $winrt = $true
} catch { Write-RJLog "WinRT unavailable: $_" }

function Wait-RJAsync($Op, [Type]$Type) {
  $t = $asTaskOp.MakeGenericMethod($Type).Invoke($null, @($Op))
  [void]$t.Wait(10000); $t.Result
}
function Wait-RJAction($Op) {
  $t = $asTaskAction.Invoke($null, @($Op)); [void]$t.Wait(10000)
}

# --- accent colour, sound ----------------------------------------------------------
function Set-RJAccent([string]$Hex) {
  if (-not $config.accent) { return }
  if (-not $Hex) {
    foreach ($n in $RJAccentValues) { Restore-RJValue $backup $n[0] $n[1] }
  } else {
    $rgb = ConvertFrom-RJHex $Hex
    $r = ($rgb -shr 16) -band 255; $g = ($rgb -shr 8) -band 255; $b = $rgb -band 255
    $abgr = { param($r, $g, $b) [int64](0xFF000000L -bor ($b -shl 16) -bor ($g -shl 8) -bor $r) }
    # 8 shades, light to dark, as Windows keeps them
    $pal = New-Object byte[] 32
    $mix = @(0.55, 0.35, 0.18, 0, -0.25, -0.45, -0.65, -0.8)
    $shade = @()
    for ($i = 0; $i -lt 8; $i++) {
      $m = $mix[$i]
      $f = { param($c) if ($m -ge 0) { [int]($c + (255 - $c) * $m) } else { [int]($c * (1 + $m)) } }
      $s = @((& $f $r), (& $f $g), (& $f $b))
      $shade += , $s
      $pal[$i * 4] = $s[0]; $pal[$i * 4 + 1] = $s[1]; $pal[$i * 4 + 2] = $s[2]; $pal[$i * 4 + 3] = 0
    }
    Set-RJDword $RJKeys.Dwm 'AccentColor' (& $abgr $r $g $b)
    Set-RJDword $RJKeys.Dwm 'ColorizationColor' (0xC4000000L -bor $rgb)
    Set-RJDword $RJKeys.Dwm 'ColorizationAfterglow' (0xC4000000L -bor $rgb)
    if (-not (Test-Path $RJKeys.Accent)) { New-Item -Path $RJKeys.Accent -Force | Out-Null }
    Set-ItemProperty -Path $RJKeys.Accent -Name 'AccentPalette' -Value $pal -Type Binary
    Set-RJDword $RJKeys.Accent 'AccentColorMenu' (& $abgr $shade[4][0] $shade[4][1] $shade[4][2])
    Set-RJDword $RJKeys.Accent 'StartColorMenu' (& $abgr $shade[5][0] $shade[5][1] $shade[5][2])
  }
  [RadiojoyNative]::Broadcast('ImmersiveColorSet')
}

function Set-RJSound([string]$Who) {
  if (-not $config.sounds) { return }
  $wav = Join-Path $RJ "sounds\notify-$Who.wav"
  if ($Who -and (Test-Path $wav)) {
    if (-not (Test-Path $RJKeys.Sound)) { New-Item -Path $RJKeys.Sound -Force | Out-Null }
    Set-ItemProperty -Path $RJKeys.Sound -Name '(default)' -Value $wav
  } else { Restore-RJValue $backup $RJKeys.Sound '(default)' }
}

# --- Spotify (Spicetify) and Zen / Firefox ------------------------------------------
$xpui = $null
if (Get-Command spicetify -ErrorAction SilentlyContinue) {
  try {
    $sp = (& spicetify config spotify_path 2>$null | Select-Object -Last 1)
    if ($sp) { $d = Join-Path $sp.Trim() 'Apps\xpui'; if (Test-Path $d) { $xpui = $d } }
  } catch { }
  # Spicetify leaves spotify_path empty when Spotify is in its usual place
  if (-not $xpui -and (Test-Path "$env:APPDATA\Spotify\Apps\xpui")) { $xpui = "$env:APPDATA\Spotify\Apps\xpui" }
}
$spotify = Read-RJIni (Join-Path $RJTheme 'spotify')

function Set-RJSpotify([string]$Who) {
  if (-not $xpui) { return }
  $pairs = @()
  $sec = $spotify[$Who]
  if ($sec) { foreach ($k in ($sec.Keys | Sort-Object)) { $pairs += '"{0}":"{1}"' -f $k, $sec[$k] } }
  Write-RJFile (Join-Path $xpui 'radiojoy-colors.json') ('{{"who":"{0}","colors":{{{1}}}}}' -f $Who, ($pairs -join ','))
}

function Set-RJBrowser([string]$Who) {
  $css = @()
  foreach ($root in @("$env:APPDATA\zen\Profiles", "$env:APPDATA\Mozilla\Firefox\Profiles")) {
    if (Test-Path $root) { $css += @(Get-ChildItem -Path $root -Directory | ForEach-Object { Join-Path $_.FullName 'chrome\userChrome.css' } | Where-Object { Test-Path $_ }) }
  }
  foreach ($f in $css) {
    if ((Read-RJText $f) -notmatch 'radiojoy-zen\.css') { continue }
    $out = Join-Path (Split-Path $f) 'radiojoy-zen.css'
    $text = ''
    if ($Who) {
      $c = Read-RJColors $Who
      $text = @"
/* written by radiojoy-agent for the current wallpaper */
:root {
  --zen-primary-color: $($c.accent) !important;
  --zen-colors-primary: $($c.lighter_background) !important;
  --zen-colors-secondary: $($c.selection) !important;
  --zen-colors-tertiary: $($c.dark_background) !important;
  --zen-colors-border: $($c.accent) !important;
  --zen-main-browser-background: $($c.background) !important;
  --zen-main-browser-background-toolbar: $($c.background) !important;
  --toolbar-bgcolor: $($c.background) !important;
  --toolbar-color: $($c.foreground) !important;
  --toolbox-textcolor: $($c.foreground) !important;
  --tab-selected-bgcolor: $($c.lighter_background) !important;
}
"@
    }
    Write-RJFile $out $text
  }
}

# --- window borders --------------------------------------------------------------
function Set-RJBorders([string]$Who) {
  if (-not ($config.borders -and $win11)) { return }
  if (-not $Who) { [RadiojoyBorders]::Off(); return }
  $grad = [int[]]@(Get-RJBorder $Who | ForEach-Object { ConvertFrom-RJHex $_ })
  $c = Read-RJColors $Who
  [RadiojoyBorders]::Set($grad, (ConvertFrom-RJHex $c.lighter_background), (ConvertFrom-RJHex $c.dark_background), (ConvertFrom-RJHex $c.foreground))
}

# --- lock screen -----------------------------------------------------------------
$lockDir = Join-Path $RJState 'lock'

# The wallpaper with the character art at its sides and a tagline, as a new file
# (the lock screen keeps its own copy, so a fresh name makes sure it updates).
function New-RJLockImage([string]$Background) {
  New-Item -ItemType Directory -Force -Path $lockDir | Out-Null
  $who = Get-RJWho $Background
  $bg = [System.Drawing.Image]::FromFile($Background)
  try {
    $W = [math]::Max(1920, $bg.Width); $H = [int]($W * 9 / 16)
    $canvas = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    # cover
    $s = [math]::Max($W / $bg.Width, $H / $bg.Height)
    $dw = $bg.Width * $s; $dh = $bg.Height * $s
    $g.DrawImage($bg, [float](($W - $dw) / 2), [float](($H - $dh) / 2), [float]$dw, [float]$dh)
    $collage = [IO.Path]::GetFileName($Background) -like 'radiojoy-week-*'
    if (-not $collage) {
      $pre = if ($who -eq 'radiojoy') { 'lock' } else { "lock-$who" }
      $tag = switch ($who) { 'alastor' { '~ stay tuned ~' } 'emily' { '~ have a heavenly day ~' } default { '~ stay tuned, my angel ~' } }
      # dark fade at the bottom so the art and tagline read on bright wallpapers
      $fadeRect = New-Object System.Drawing.Rectangle 0, ([int]($H * 0.55)), $W, ([int]($H * 0.45) + 1)
      $fade = New-Object System.Drawing.Drawing2D.LinearGradientBrush $fadeRect, ([System.Drawing.Color]::FromArgb(0, 10, 4, 6)), ([System.Drawing.Color]::FromArgb(190, 10, 4, 6)), ([float]90)
      $g.FillRectangle($fade, $fadeRect); $fade.Dispose()
      foreach ($side in 'left', 'right') {
        $f = Join-Path $RJTheme "$pre-$side.png"
        if (-not (Test-Path $f)) { continue }
        $im = [System.Drawing.Image]::FromFile($f)
        $ah = $H * 0.75; $aw = $im.Width * $ah / $im.Height
        $x = if ($side -eq 'left') { $W * 0.02 } else { $W * 0.98 - $aw }
        $g.DrawImage($im, [float]$x, [float]($H - $ah), [float]$aw, [float]$ah)
        $im.Dispose()
      }
      $color = if ($who -eq 'emily') { [System.Drawing.Color]::FromArgb(213, 237, 248) } else { [System.Drawing.Color]::FromArgb(242, 193, 78) }
      $font = New-Object System.Drawing.Font 'Georgia', ([float]($H * 0.032)), ([System.Drawing.FontStyle]::Italic), ([System.Drawing.GraphicsUnit]::Pixel)
      $fmt = New-Object System.Drawing.StringFormat
      $fmt.Alignment = [System.Drawing.StringAlignment]::Center
      $shadow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(160, 0, 0, 0))
      $brush = New-Object System.Drawing.SolidBrush $color
      $g.DrawString($tag, $font, $shadow, (New-Object System.Drawing.RectangleF 2, ([float]($H * 0.9) + 2), $W, ([float]($H * 0.08))), $fmt)
      $g.DrawString($tag, $font, $brush, (New-Object System.Drawing.RectangleF 0, ([float]($H * 0.9)), $W, ([float]($H * 0.08))), $fmt)
      $font.Dispose(); $brush.Dispose(); $shadow.Dispose()
    }
    $g.Dispose()
    Get-ChildItem -Path $lockDir -Filter 'lock-*.jpg' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    $out = Join-Path $lockDir ('lock-{0}.jpg' -f [DateTime]::Now.Ticks)
    $jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 92L
    $canvas.Save($out, $jpeg, $ep); $canvas.Dispose()
    $out
  } finally { $bg.Dispose() }
}

function Set-RJLockImage([string]$Path) {
  if (-not $winrt) { return }
  try {
    $file = Wait-RJAsync ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Path)) ([Windows.Storage.StorageFile])
    Wait-RJAction ([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($file))
  } catch { Write-RJLog "lock screen: $_" }
}

# Next lock's background: one step along the order every lock (Alastor -> Emily ->
# Radiojoy ...), the week's collage during Radiojoy Week, the plain desktop wallpaper
# while the theme is off.
function Update-RJLock([switch]$Advance) {
  $wall = Get-RJWallpaper
  if (-not (Test-RJOurs $wall)) { if ($wall -and (Test-Path $wall)) { Set-RJLockImage $wall }; return }
  $pointer = Join-Path $RJState 'lock-background.txt'
  $collage = Get-RJCollage
  if ((Get-RJWeek).Prompt -and (Test-Path $collage)) { $pick = $collage }
  else {
    $list = @(Get-RJCarousel)
    $last = (Read-RJText $pointer).Trim()
    if (-not ($list -contains $last)) { $last = $wall }
    $pick = $last
    if ($Advance) {
      $i = [array]::IndexOf($list, $last)
      $pick = $list[($i + 1) % $list.Count]
    }
    Write-RJFile $pointer $pick
  }
  try { Set-RJLockImage (New-RJLockImage $pick) } catch { Write-RJLog "lock image: $_" }
}

# --- tray icon -------------------------------------------------------------------
$icons = @{}
function Get-RJIcon([string]$Who, [bool]$OnAir) {
  $key = "$Who|$OnAir"
  if ($icons[$key]) { return $icons[$key] }
  $suffix = if ($Who -and $Who -ne 'radiojoy') { "-$Who" } else { '' }
  $src = [System.Drawing.Image]::FromFile((Join-Path $RJTheme "splash\heads$suffix.png"))
  $bmp = New-Object System.Drawing.Bitmap 32, 32
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $s = [math]::Min(32 / $src.Width, 32 / $src.Height)
  $w = $src.Width * $s; $h = $src.Height * $s
  if ($Who) { $g.DrawImage($src, [float]((32 - $w) / 2), [float]((32 - $h) / 2), [float]$w, [float]$h) }
  else {
    # theme off: a grey version
    $cm = New-Object System.Drawing.Imaging.ColorMatrix
    $cm.Matrix00 = 0.3; $cm.Matrix01 = 0.3; $cm.Matrix02 = 0.3
    $cm.Matrix10 = 0.59; $cm.Matrix11 = 0.59; $cm.Matrix12 = 0.59
    $cm.Matrix20 = 0.11; $cm.Matrix21 = 0.11; $cm.Matrix22 = 0.11
    $cm.Matrix33 = 0.7
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle ([int]((32 - $w) / 2)), ([int]((32 - $h) / 2)), ([int]$w), ([int]$h)), 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
  }
  if ($OnAir) {
    $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 220, 34, 73))), 21, 21, 10, 10)
    $g.DrawEllipse((New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 1.5), 21, 21, 10, 10)
  }
  $g.Dispose(); $src.Dispose()
  $icons[$key] = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
  $icons[$key]
}

$tray = New-Object System.Windows.Forms.NotifyIcon
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$header = $menu.Items.Add('Radiojoy'); $header.Enabled = $false
$weekItem = $menu.Items.Add(''); $weekItem.Enabled = $false
[void]$menu.Items.Add('-')
$menu.Items.Add('Next wallpaper').add_Click({ Step-RJWallpaper })
$menu.Items.Add('A quote').add_Click({ Show-RJQuote })
$menu.Items.Add('Open the wallpapers folder').add_Click({ Start-Process explorer.exe $RJBackgrounds })
[void]$menu.Items.Add('-')
$menu.Items.Add('Quit Radiojoy (until next login)').add_Click({ $script:quit = $true })
$tray.ContextMenuStrip = $menu
$tray.add_MouseClick({ param($s, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Step-RJWallpaper } })

function Show-RJBalloon([string]$Title, [string]$Text) {
  if (-not $Text) { $Text = ' ' }
  $tray.ShowBalloonTip(8000, $Title, $Text, [System.Windows.Forms.ToolTipIcon]::None)
}

function Show-RJQuote {
  $who = Get-RJWho
  if (-not $who) { $who = 'radiojoy' }
  $name = (Get-Culture).TextInfo.ToTitleCase($who)
  Show-RJBalloon $name (Get-RJQuote $who)
}

function Step-RJWallpaper {
  $wall = Get-RJWallpaper
  $week = Get-RJWeek
  if ($week.Prompt -and (Test-Path (Get-RJCollage)) -and (Test-RJOurs $wall)) {
    Show-RJBalloon "$([char]0x2605) Radiojoy Week" "$($week.Prompt)`nThe wallpaper is the week's collage until the week is over."
    return
  }
  $list = @(Get-RJCarousel)
  if (-not $list.Count) { return }
  if (Test-RJOurs $wall) { $i = [array]::IndexOf($list, $wall); $pick = $list[($i + 1) % $list.Count] }
  else {
    # theme off: back to the last Radiojoy wallpaper
    $last = (Read-RJText (Join-Path $RJState 'last-wallpaper.txt')).Trim()
    $pick = if ($list -contains $last) { $last } else { $list[0] }
  }
  [void][RadiojoyNative]::SetWallpaper($pick)
}

$script:onAir = $false
function Update-RJTray {
  $who = Get-RJWho
  $tray.Icon = Get-RJIcon $who $script:onAir
  $name = if ($who) { (Get-Culture).TextInfo.ToTitleCase($who) } else { 'Radiojoy (off)' }
  $week = Get-RJWeek
  $weekText = if ($week.Prompt) { "$([char]0x2605) Radiojoy Week: $($week.Prompt)" }
    elseif ($null -ne $week.DaysUntil) { "Radiojoy Week in $($week.DaysUntil) day$(if ($week.DaysUntil -ne 1) { 's' })" } else { '' }
  $tip = $name
  if ($script:onAir) { $tip += ' - on air' }
  if ($weekText) { $tip += "`n$weekText" }
  # NotifyIcon refuses tooltips over 63 characters
  if ($tip.Length -gt 63) { $tip = $tip.Substring(0, 62) + [char]0x2026 }
  $tray.Text = $tip
  $header.Text = if ($script:onAir) { "$name $([char]0xB7) on air" } else { $name }
  $weekItem.Text = $weekText
  $weekItem.Visible = [bool]$weekText
}

# --- following the wallpaper ---------------------------------------------------------
$script:applied = $null
$script:lastWall = $null
function Update-RJFollow {
  $wall = Get-RJWallpaper
  $who = Get-RJWho $wall
  # During Radiojoy Week the wallpaper stays on the week's collage: another Radiojoy
  # wallpaper is switched straight back (one that isn't the theme's is left alone).
  $collage = Get-RJCollage
  if ($who -and (Get-RJWeek).Prompt -and (Test-Path $collage) -and $wall -ne $collage) {
    [void][RadiojoyNative]::SetWallpaper($collage)
    return
  }
  if ($who -and $wall -ne $script:lastWall) {
    Write-RJFile (Join-Path $RJState 'last-wallpaper.txt') $wall
    $script:lastWall = $wall
  }
  if ($who -eq $script:applied) { return }
  $script:applied = $who
  Write-RJLog "wallpaper: $wall -> '$who'"
  $border = @(Get-RJBorder $who)
  foreach ($step in @(
      { Set-RJBorders $who },
      { Set-RJAccent $(if ($border.Count) { $border[0] } else { '' }) },
      { Set-RJSound $who },
      { Set-RJSpotify $who },
      { Set-RJBrowser $who })) {
    try { & $step } catch { Write-RJLog "apply: $_" }
  }
  Update-RJTray
}

# --- Spotify playing: on air -----------------------------------------------------------
$media = $null
try {
  $null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
  $media = Wait-RJAsync ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
} catch { Write-RJLog "media sessions unavailable: $_" }

function Update-RJOnAir {
  if (-not $media) { return }
  $on = $false
  try {
    foreach ($s in $media.GetSessions()) {
      if ($s.SourceAppUserModelId -match 'spotify' -and $s.GetPlaybackInfo().PlaybackStatus -eq 'Playing') { $on = $true }
    }
  } catch { }
  if ($on -ne $script:onAir) { $script:onAir = $on; Update-RJTray }
}

# --- Radiojoy Week ---------------------------------------------------------------------
$notifyFile = Join-Path $RJ 'notify.jsonl'
$script:notifyPos = if (Test-Path $notifyFile) { (Get-Item $notifyFile).Length } else { 0 }

# radiojoy-week.py appends {"title","body"} lines; shown as notifications here.
function Read-RJNotify {
  if (-not (Test-Path $notifyFile)) { return }
  $len = (Get-Item $notifyFile).Length
  if ($len -lt $script:notifyPos) { $script:notifyPos = 0 }
  if ($len -eq $script:notifyPos) { return }
  $fs = [IO.File]::Open($notifyFile, 'Open', 'Read', 'ReadWrite')
  try {
    [void]$fs.Seek($script:notifyPos, 'Begin')
    $text = (New-Object IO.StreamReader($fs, $RJUtf8)).ReadToEnd()
    $script:notifyPos = $len
  } finally { $fs.Dispose() }
  foreach ($line in $text -split "`n") {
    if (-not $line.Trim()) { continue }
    try { $n = $line | ConvertFrom-Json; Show-RJBalloon $n.title $n.body } catch { }
  }
}

function Invoke-RJWeek {
  $week = Get-RJWeek
  $today = '{0:yyyy-MM-dd}' -f (Get-Date)
  $seen = Join-Path $RJState 'week-notified.txt'
  if ($week.Prompt -and (Read-RJText $seen).Trim() -ne $today) {
    Show-RJBalloon "$([char]0x2605) Radiojoy Week" $week.Prompt
    Write-RJFile $seen $today
  }
  if (-not ($config.python -and (Test-Path $config.python))) { return }
  $script = Join-Path $PSScriptRoot 'radiojoy-week.py'
  $stamp = Join-Path $RJState 'week-run.txt'
  $last = 0L; [void][int64]::TryParse((Read-RJText $stamp).Trim(), [ref]$last)
  if ([DateTime]::UtcNow.Ticks - $last -gt [TimeSpan]::FromMinutes(59).Ticks) {
    Write-RJFile $stamp ([DateTime]::UtcNow.Ticks)
    Start-Process -FilePath $config.python -ArgumentList "`"$script`"" -WindowStyle Hidden
  }
  $dstamp = Join-Path $RJState 'week-discover.txt'
  $last = 0L; [void][int64]::TryParse((Read-RJText $dstamp).Trim(), [ref]$last)
  if ([DateTime]::UtcNow.Ticks - $last -gt [TimeSpan]::FromDays(7).Ticks) {
    Write-RJFile $dstamp ([DateTime]::UtcNow.Ticks)
    Start-Process -FilePath $config.python -ArgumentList "`"$script`" --discover" -WindowStyle Hidden
  }
}

# --- main loop -------------------------------------------------------------------------
if ($Login) {
  $wav = Join-Path $RJ 'sounds\login.wav'
  if ((Test-Path $wav) -and (Test-RJOurs (Get-RJWallpaper))) { try { (New-Object System.Media.SoundPlayer $wav).Play() } catch { } }
}
Update-RJTray
$tray.Visible = $true
try { Update-RJFollow } catch { Write-RJLog "follow: $_" }
try { Update-RJLock } catch { Write-RJLog "lock: $_" }

$script:quit = $false
$quitFlag = Join-Path $RJState 'agent.quit'
Remove-Item $quitFlag -ErrorAction SilentlyContinue
$wasLocked = $false
$clock = [Diagnostics.Stopwatch]::StartNew()
$t = @{ follow = 0L; air = 0L; notify = 0L; week = -600000L; tray = 0L }
while (-not $script:quit) {
  [System.Windows.Forms.Application]::DoEvents()
  Start-Sleep -Milliseconds 100
  $now = $clock.ElapsedMilliseconds
  try {
    if ($now - $t.follow -ge 1000) {
      $t.follow = $now
      if (Test-Path $quitFlag) { Remove-Item $quitFlag -ErrorAction SilentlyContinue; $script:quit = $true; continue }
      Update-RJFollow
      $locked = [RadiojoyNative]::IsLocked()
      # just unlocked: the next lock shows the next wallpaper in the order
      if ($wasLocked -and -not $locked) { Update-RJLock -Advance }
      $wasLocked = $locked
    }
    if ($now - $t.air -ge 3000) { $t.air = $now; Update-RJOnAir }
    if ($now - $t.notify -ge 2000) { $t.notify = $now; Read-RJNotify }
    if ($now - $t.tray -ge 60000) { $t.tray = $now; Update-RJTray }
    if ($now - $t.week -ge 600000) { $t.week = $now; Invoke-RJWeek }
  } catch { Write-RJLog "loop: $_" }
}

# Quit: everything back to normal until the next login.
$script:applied = $null
foreach ($step in @({ Set-RJBorders '' }, { Set-RJAccent '' }, { Set-RJSound '' }, { Set-RJSpotify '' }, { Set-RJBrowser '' })) {
  try { & $step } catch { }
}
$tray.Visible = $false
$tray.Dispose()
Remove-Item (Join-Path $RJState 'agent.pid') -ErrorAction SilentlyContinue
$mutex.ReleaseMutex()
