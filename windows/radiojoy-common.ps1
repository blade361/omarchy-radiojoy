# Shared by the Radiojoy scripts on Windows: where things live, which character the
# wallpaper shows, and small file readers. Works in Windows PowerShell 5.1 and 7.
$RJ = Join-Path $env:LOCALAPPDATA 'Radiojoy'
$RJTheme = Join-Path $RJ 'theme'
$RJBackgrounds = Join-Path $RJTheme 'backgrounds'
$RJWeekDir = Join-Path $RJ 'week'
$RJState = Join-Path $RJ 'state'
$RJCache = Join-Path $RJ 'cache'
$RJUtf8 = New-Object System.Text.UTF8Encoding $false

function Get-RJWallpaper {
  try { (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallPaper -ErrorAction Stop).WallPaper } catch { '' }
}

# True for the theme's wallpapers and the Radiojoy Week collages: while one of them
# is up the theme is "on", like having the Radiojoy theme set on Omarchy.
function Test-RJOurs([string]$Path) {
  if (-not $Path) { return $false }
  foreach ($dir in @($RJBackgrounds, $RJWeekDir)) {
    if ($Path.StartsWith($dir.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
  }
  $false
}

# alastor / emily / radiojoy for our wallpapers (NN-alastor.*, NN-emily.*, anything
# else), '' when the wallpaper isn't one of ours.
function Get-RJWho([string]$Path = (Get-RJWallpaper)) {
  if (-not (Test-RJOurs $Path)) { return '' }
  $name = [IO.Path]::GetFileName($Path).ToLowerInvariant()
  if ($name -match '-alastor\.') { 'alastor' } elseif ($name -match '-emily\.') { 'emily' } else { 'radiojoy' }
}

function Read-RJText([string]$Path) {
  if (Test-Path -LiteralPath $Path) { [IO.File]::ReadAllText($Path, $RJUtf8) } else { '' }
}

# Atomic write, UTF-8 without a BOM (browsers and Spotify's JSON.parse reject one).
function Write-RJFile([string]$Path, [string]$Text) {
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $tmp = "$Path.tmp"
  [IO.File]::WriteAllText($tmp, $Text, $RJUtf8)
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}

# key=value files (foot-*.ini, borders); [sections] are returned as nested tables.
function Read-RJIni([string]$Path) {
  $top = @{}; $cur = $top
  foreach ($line in (Read-RJText $Path) -split "`r?`n") {
    $line = $line.Trim()
    if (-not $line -or $line.StartsWith('#') -or $line.StartsWith(';')) { continue }
    if ($line -match '^\[(.+)\]$') { $cur = @{}; $top[$Matches[1]] = $cur; continue }
    $i = $line.IndexOf('=')
    if ($i -gt 0) { $cur[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1).Trim() }
  }
  $top
}

# The colours of shell/colors-<who>.toml: name -> '#rrggbb'.
function Read-RJColors([string]$Who) {
  $c = @{}
  $file = Join-Path $RJTheme "shell\colors-$Who.toml"
  foreach ($line in (Read-RJText $file) -split "`r?`n") {
    if ($line -match '^\s*([a-z_]+)\s*=\s*"(#[0-9a-fA-F]{6})"') { $c[$Matches[1]] = $Matches[2] }
  }
  $c
}

# The window border gradient for a character: hex colours 'rrggbb' (from theme\borders).
function Get-RJBorder([string]$Who) {
  $b = Read-RJIni (Join-Path $RJTheme 'borders')
  $v = $b[$Who]
  if (-not $v) { return @() }
  @([regex]::Matches($v, 'rgba\(([0-9a-fA-F]{6})') | ForEach-Object { $_.Groups[1].Value })
}

# Radiojoy Week (radiojoy-week.txt): today's prompt, or the days until the next week.
function Get-RJWeek {
  $today = (Get-Date).Date
  $next = $null; $prompt = $null; $days = @()
  foreach ($line in (Read-RJText (Join-Path $RJTheme 'radiojoy-week.txt')) -split "`r?`n") {
    if ($line -match '^(\d{4}-\d{2}-\d{2})\t(.+)$') {
      $d = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null)
      $days += $d
      if ($d -eq $today) { $prompt = $Matches[2].Trim() }
      elseif ($d -gt $today -and ($null -eq $next -or $d -lt $next)) { $next = $d }
    }
  }
  $in = $null
  if ($next) { $in = [int]($next - $today).TotalDays }
  New-Object psobject -Property @{ Prompt = $prompt; DaysUntil = $in }
}

function Get-RJCollage {
  Join-Path $RJWeekDir ('radiojoy-week-{0}.png' -f (Get-Date).Year)
}

# The wallpaper order: keepsake collages of past weeks first, then the theme's own.
function Get-RJCarousel {
  $list = @()
  if (Test-Path -LiteralPath $RJWeekDir) {
    $current = Get-RJCollage
    $list += @(Get-ChildItem -LiteralPath $RJWeekDir -Filter 'radiojoy-week-*.png' | Sort-Object Name |
        Where-Object { $_.FullName -ne $current -or -not (Get-RJWeek).Prompt } | ForEach-Object { $_.FullName })
  }
  $list += @(Get-ChildItem -LiteralPath $RJBackgrounds -File | Where-Object { $_.Extension -match '^\.(jpe?g|png|webp|bmp)$' } |
      Sort-Object Name | ForEach-Object { $_.FullName })
  $list
}

function Get-RJQuote([string]$Who) {
  $f = Join-Path $RJTheme "splash\quotes-$Who.txt"
  if (-not (Test-Path -LiteralPath $f)) { $f = Join-Path $RJTheme 'splash\quotes.txt' }
  $lines = @((Read-RJText $f) -split "`r?`n" | Where-Object { $_.Trim() })
  if ($lines.Count) { $lines[(Get-Random -Maximum $lines.Count)] } else { '' }
}

# OSC sequences that recolour the terminal to the character's palette (foot-<who>.ini),
# or reset it to its own colours when $Who is ''.
function Get-RJTermSequence([string]$Who) {
  $e = [char]27; $bel = [char]7
  if (-not $Who) { return "$e]104$bel$e]110$bel$e]111$bel$e]112$bel" }
  $ini = Read-RJIni (Join-Path $RJTheme "shell\foot-$Who.ini")
  $c = $ini['colors-dark']
  if (-not $c) { $c = $ini['colors'] }
  if (-not $c) { return '' }
  $s = New-Object System.Text.StringBuilder
  foreach ($k in $c.Keys) {
    $v = $c[$k]
    switch -regex ($k) {
      '^foreground$' { [void]$s.Append("$e]10;#$v$bel") }
      '^background$' { [void]$s.Append("$e]11;#$v$bel") }
      '^cursor$' { [void]$s.Append("$e]12;#$(($v -split ' ')[-1])$bel") }
      '^regular([0-7])$' { [void]$s.Append("$e]4;$($Matches[1]);#$v$bel") }
      '^bright([0-7])$' { [void]$s.Append("$e]4;$([int]$Matches[1] + 8);#$v$bel") }
    }
  }
  $s.ToString()
}

# --- registry: what the installer saves and the agent / uninstaller put back ----------
$RJKeys = @{
  Dwm = 'HKCU:\Software\Microsoft\Windows\DWM'
  Accent = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
  Personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
  Sound = 'HKCU:\AppEvents\Schemes\Apps\.Default\Notification.Default\.Current'
  Desktop = 'HKCU:\Control Panel\Desktop'
}
$RJAccentValues = @(
  @($RJKeys.Dwm, 'AccentColor'), @($RJKeys.Dwm, 'ColorizationColor'), @($RJKeys.Dwm, 'ColorizationAfterglow'),
  @($RJKeys.Accent, 'AccentColorMenu'), @($RJKeys.Accent, 'StartColorMenu'), @($RJKeys.Accent, 'AccentPalette'))
$RJBackupValues = $RJAccentValues + @(
  @($RJKeys.Dwm, 'ColorPrevalence'), @($RJKeys.Personalize, 'ColorPrevalence'),
  @($RJKeys.Personalize, 'AppsUseLightTheme'), @($RJKeys.Personalize, 'SystemUsesLightTheme'),
  @($RJKeys.Sound, '(default)'), @($RJKeys.Desktop, 'WallPaper'), @($RJKeys.Desktop, 'WallpaperStyle'),
  @($RJKeys.Desktop, 'TileWallpaper'))

function Set-RJDword($Key, $Name, [int64]$Value) {
  if (-not (Test-Path $Key)) { New-Item -Path $Key -Force | Out-Null }
  # DWORDs come back from the registry as signed Int32
  $v = if ($Value -lt 0) { [int32]$Value } else { [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]$Value), 0) }
  Set-ItemProperty -Path $Key -Name $Name -Value $v -Type DWord
}

function Get-RJBackup {
  try { (Read-RJText (Join-Path $RJState 'backup.json')) | ConvertFrom-Json } catch { $null }
}

# The values as they were before Radiojoy: number, string, 'bin:<base64>', or $null
# for "wasn't set". Saved once, so reinstalling never overwrites the originals.
function Save-RJBackup {
  $file = Join-Path $RJState 'backup.json'
  if (Test-Path $file) { return }
  $b = [ordered]@{}
  foreach ($v in $RJBackupValues) {
    $val = $null
    try {
      $item = Get-ItemProperty -Path $v[0] -Name $v[1] -ErrorAction Stop
      $val = $item.($v[1])
      if ($val -is [byte[]]) { $val = 'bin:' + [Convert]::ToBase64String($val) }
    } catch { }
    $b["$($v[0])|$($v[1])"] = $val
  }
  Write-RJFile $file ($b | ConvertTo-Json)
}

function Restore-RJValue($Backup, $Key, $Name) {
  if (-not $Backup) { return }
  $entry = $Backup.PSObject.Properties["$Key|$Name"]
  if (-not $entry) { return }
  $v = $entry.Value
  if ($null -eq $v) { Remove-ItemProperty -Path $Key -Name $Name -ErrorAction SilentlyContinue }
  elseif ($v -is [string] -and $v.StartsWith('bin:')) {
    Set-ItemProperty -Path $Key -Name $Name -Value ([byte[]][Convert]::FromBase64String($v.Substring(4))) -Type Binary
  } elseif ($v -is [string]) {
    if (-not (Test-Path $Key)) { New-Item -Path $Key -Force | Out-Null }
    Set-ItemProperty -Path $Key -Name $Name -Value $v
  } else { Set-RJDword $Key $Name ([int64]$v) }
}

# Adds or removes the Radiojoy block in a PowerShell profile, keeping the file's own
# encoding (Windows PowerShell 5.1 reads a profile without a BOM as ANSI).
function Edit-RJProfile([string]$Path, [string]$Block) {
  $bom = $false; $enc = $RJUtf8; $text = ''
  if (Test-Path -LiteralPath $Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    try { $text = (New-Object System.Text.UTF8Encoding $false, $true).GetString($bytes) }
    catch { $enc = [Text.Encoding]::Default; $text = $enc.GetString($bytes) }
    if ($bom) { $text = $text.Substring(1) }
  }
  $text = [regex]::Replace($text, '(?s)(\r?\n)*# >>> radiojoy >>>.*?# <<< radiojoy <<<(\r?\n)?', '').TrimEnd()
  if ($Block) {
    # last, so the prompt it wraps is the final one (starship, oh-my-posh...)
    $text = ($text + "`r`n`r`n" + ($Block -replace "`r?`n", "`r`n")).TrimStart() + "`r`n"
  } elseif ($text) { $text += "`r`n" }
  if (-not $text -and -not (Test-Path -LiteralPath $Path)) { return }
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if ($enc -eq $RJUtf8 -and $bom) { $enc = New-Object System.Text.UTF8Encoding $true }
  [IO.File]::WriteAllText($Path, $text, $enc)
}

# A native command whose stderr and exit code shouldn't stop a script that runs with
# $ErrorActionPreference = 'Stop' (Windows PowerShell turns redirected stderr into errors).
function Invoke-RJNative([string]$Exe) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { & $Exe @args 2>$null } finally { $ErrorActionPreference = $old }
}
