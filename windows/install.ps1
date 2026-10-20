# Radiojoy for Windows 10 / 11. Double-click install.cmd, or from the repo:
#   powershell -ExecutionPolicy Bypass -File windows\install.ps1 [options]
#   -NoSplash    don't add the terminal splash to your PowerShell profile
#   -NoSpotify   leave Spotify / Spicetify alone
#   -NoAccent    keep your accent colour (no crimson / periwinkle Start and taskbar)
#   -NoBorders   keep the normal window borders and title bars
#   -NoSounds    keep your notification sound
#   -NoWeek      no Radiojoy Week collage (it needs Python + Pillow)
#   -Yes         don't ask anything, take the defaults
param([switch]$NoSplash, [switch]$NoSpotify, [switch]$NoAccent, [switch]$NoBorders,
  [switch]$NoSounds, [switch]$NoWeek, [switch]$Yes)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'radiojoy-common.ps1')

function Say([string]$Text) { Write-Host ([char]::ConvertFromUtf32(0x1F4FB) + ' ') -NoNewline -ForegroundColor Red; Write-Host $Text }
function Warn([string]$Text) { Write-Host "! $Text" -ForegroundColor Yellow }
function Ask([string]$Question) {
  if ($Yes) { return $true }
  $a = Read-Host "$Question [Y/n]"
  return -not ($a -match '^\s*n')
}

if ([Environment]::OSVersion.Version.Major -lt 10) { throw 'Radiojoy needs Windows 10 or 11.' }
$build = [Environment]::OSVersion.Version.Build

# A running agent quits (putting colours back) before its files are replaced.
$pidFile = Join-Path $RJState 'agent.pid'
if (Test-Path $pidFile) {
  New-Item -ItemType File -Force -Path (Join-Path $RJState 'agent.quit') | Out-Null
  $old = Get-Process -Id ([int](Read-RJText $pidFile)) -ErrorAction SilentlyContinue
  if ($old) { if (-not $old.WaitForExit(8000)) { $old.Kill() } }
}

Say 'Copying the theme'
New-Item -ItemType Directory -Force -Path $RJ, $RJTheme, $RJState, $RJWeekDir | Out-Null
Save-RJBackup
foreach ($f in 'radiojoy-common.ps1', 'radiojoy-agent.ps1', 'radiojoy-splash.ps1', 'radiojoy-prompt.ps1',
  'radiojoy-sixel.ps1', 'RadiojoySixel.cs', 'RadiojoyNative.cs', 'uninstall.ps1') {
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot $f) -Destination $RJ -Force
}
Copy-Item -LiteralPath (Join-Path $repo 'bin\radiojoy-week') -Destination (Join-Path $RJ 'radiojoy-week.py') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'sounds') -Destination $RJ -Recurse -Force
$theme = Join-Path $repo 'theme'
# the user's own edits to the Radiojoy Week lists survive a reinstall
$keep = @{}
foreach ($f in 'radiojoy-week.txt', 'radiojoy-week-artists.txt') {
  $p = Join-Path $RJTheme $f
  if (Test-Path $p) { $keep[$f] = Read-RJText $p }
}
if (Test-Path $RJBackgrounds) { Remove-Item -LiteralPath $RJBackgrounds -Recurse -Force }
foreach ($item in Get-ChildItem -LiteralPath $theme) {
  # Omarchy-only pieces stay behind
  if ($item.Name -in 'hyprland.lua', 'icons.theme', 'preview.png', 'unlock.png') { continue }
  if ($item.Name -like 'screensaver*' -or $item.Name -like '*.ogg') { continue }
  Copy-Item -LiteralPath $item.FullName -Destination $RJTheme -Recurse -Force
}
Remove-Item -LiteralPath (Join-Path $RJTheme 'splash\build.py') -ErrorAction SilentlyContinue
foreach ($f in $keep.Keys) {
  # keep the user's list, but add new weeks from the repo's
  $mine = $keep[$f]
  $add = @((Read-RJText (Join-Path $theme $f)) -split "`r?`n" | Where-Object { $_ -match '^\S+' -and -not $_.StartsWith('#') -and -not $mine.Contains($_) })
  if ($add.Count) { $mine = $mine.TrimEnd() + "`n" + ($add -join "`n") + "`n" }
  Write-RJFile (Join-Path $RJTheme $f) $mine
}
# files from a downloaded zip are marked as coming from the internet
Get-ChildItem -LiteralPath $RJ -Recurse -File | Unblock-File

if (-not ('RadiojoyNative' -as [type])) { Add-Type -Path (Join-Path $RJ 'RadiojoyNative.cs') }

$config = [ordered]@{ accent = -not $NoAccent; borders = -not $NoBorders; sounds = -not $NoSounds; python = '' }

Say 'Dark mode, and the first wallpaper (Alastor)'
Set-RJDword $RJKeys.Personalize 'AppsUseLightTheme' 0
Set-RJDword $RJKeys.Personalize 'SystemUsesLightTheme' 0
if ($config.accent) {
  # accent colour on Start, the taskbar and title bars (Windows 10 has no per-window colours)
  Set-RJDword $RJKeys.Personalize 'ColorPrevalence' 1
  Set-RJDword $RJKeys.Dwm 'ColorPrevalence' 1
}
Set-ItemProperty -Path $RJKeys.Desktop -Name 'WallpaperStyle' -Value '10'   # fill
Set-ItemProperty -Path $RJKeys.Desktop -Name 'TileWallpaper' -Value '0'
$first = @(Get-RJCarousel | Where-Object { [IO.Path]::GetFileName($_) -like '01-*' })[0]
if (-not (Test-RJOurs (Get-RJWallpaper)) -and $first) { [void][RadiojoyNative]::SetWallpaper($first) }

# --- Windows Terminal: colour schemes and a Radiojoy profile ---------------------------
Say 'Windows Terminal colour schemes'
$names = @{ radiojoy = 'Radiojoy'; alastor = 'Radiojoy Alastor'; emily = 'Radiojoy Emily' }
$schemes = @()
foreach ($who in 'radiojoy', 'alastor', 'emily') {
  $ini = Read-RJIni (Join-Path $RJTheme "shell\foot-$who.ini")
  $c = $ini['colors-dark']
  $order = 'black', 'red', 'green', 'yellow', 'blue', 'purple', 'cyan', 'white'
  $s = [ordered]@{ name = $names[$who]; foreground = "#$($c.foreground)"; background = "#$($c.background)"
    cursorColor = "#$(($c.cursor -split ' ')[-1])"; selectionBackground = "#$($c['selection-background'])" }
  for ($i = 0; $i -lt 8; $i++) {
    $s[$order[$i]] = "#$($c["regular$i"])"
    $s['bright' + $order[$i].Substring(0, 1).ToUpper() + $order[$i].Substring(1)] = "#$($c["bright$i"])"
  }
  $schemes += $s
}
$shell = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { 'pwsh.exe -NoLogo' } else { 'powershell.exe -NoLogo' }
$fragment = [ordered]@{
  schemes = $schemes
  profiles = @([ordered]@{ guid = '{7a1d0e3c-6b6e-4b4a-9a8e-5241444a4f59}'; name = 'Radiojoy'; commandline = $shell
      colorScheme = 'Radiojoy'; icon = (Join-Path $RJTheme 'splash\heads.png'); startingDirectory = '%USERPROFILE%' })
}
$fragDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\Radiojoy'
Write-RJFile (Join-Path $fragDir 'radiojoy.json') ($fragment | ConvertTo-Json -Depth 5)

# --- PowerShell profile: splash + terminal colours ---------------------------------------
if (-not $NoSplash) {
  $policy = Get-ExecutionPolicy
  if ($policy -in 'Restricted', 'AllSigned', 'Undefined') {
    Warn "PowerShell won't run profile scripts (execution policy: $policy)."
    if (Ask 'Allow your own scripts (Set-ExecutionPolicy RemoteSigned for your user only)?') {
      Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    } else { Warn 'Skipping the terminal splash; rerun the installer to add it later.'; $NoSplash = $true }
  }
}
$block = @'
# >>> radiojoy >>>
if (Test-Path "$env:LOCALAPPDATA\Radiojoy\radiojoy-prompt.ps1") {
  if ($Host.Name -eq 'ConsoleHost') { & "$env:LOCALAPPDATA\Radiojoy\radiojoy-splash.ps1" }
  . "$env:LOCALAPPDATA\Radiojoy\radiojoy-prompt.ps1"
}
# <<< radiojoy <<<
'@
$docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($dir in 'WindowsPowerShell', 'PowerShell') {
  Edit-RJProfile (Join-Path $docs "$dir\profile.ps1") $(if ($NoSplash) { '' } else { $block })
}
if (-not $NoSplash) { Say 'Terminal splash added to your PowerShell profile (Windows Terminal 1.22+ draws the art)' }

# --- Spotify (Spicetify) ---------------------------------------------------------------
if (-not $NoSpotify) {
  if (Get-Command spicetify -ErrorAction SilentlyContinue) {
    Say 'Spotify: Radiojoy colours (Spicetify)'
    try {
      $cfg = Split-Path -Parent "$(Invoke-RJNative spicetify -c | Select-Object -Last 1)".Trim()
      New-Item -ItemType Directory -Force -Path (Join-Path $cfg 'Extensions'), (Join-Path $cfg 'Themes') | Out-Null
      Copy-Item -LiteralPath (Join-Path $repo 'spicetify\radiojoy-follow.js') -Destination (Join-Path $cfg 'Extensions') -Force
      Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'spicetify\Radiojoy') -Destination (Join-Path $cfg 'Themes') -Recurse -Force
      $current = "$(Invoke-RJNative spicetify config current_theme | Select-Object -Last 1)".Trim()
      if (-not $current -or $current -in 'SpicetifyDefault', 'marketplace', 'Radiojoy') {
        Invoke-RJNative spicetify config current_theme Radiojoy color_scheme Radiojoy | Out-Null
      } else { Warn "Keeping your Spicetify theme '$current'; Alastor / Emily colours still follow the wallpaper." }
      Invoke-RJNative spicetify config extensions radiojoy-follow.js | Out-Null
      Invoke-RJNative spicetify apply | Out-Null
      if ($LASTEXITCODE) { Invoke-RJNative spicetify backup apply | Out-Null }
      if ($LASTEXITCODE) { Warn 'spicetify apply failed; run "spicetify backup apply" yourself.' }
    } catch { Warn "Spicetify: $_" }
  } else {
    Warn 'Spotify colours need Spicetify (spicetify.app); install it and rerun this to add them.'
  }
}

# --- Radiojoy Week collage: Python + Pillow ------------------------------------------------
if (-not $NoWeek) {
  $py = $null
  foreach ($cmd in @(@('py', '-3'), @('python'))) {
    if (-not (Get-Command $cmd[0] -ErrorAction SilentlyContinue)) { continue }
    $pyArgs = @($cmd | Select-Object -Skip 1) + @('-c', 'import sys; print(sys.executable)')
    # the Microsoft Store "python" placeholder prints nothing useful
    $exe = "$(Invoke-RJNative $cmd[0] @pyArgs | Select-Object -Last 1)".Trim()
    if ($exe -and (Test-Path $exe) -and $exe -notmatch 'WindowsApps') { $py = $exe; break }
  }
  if ($py) {
    Invoke-RJNative $py -c 'import PIL'
    if ($LASTEXITCODE -and (Ask 'The Radiojoy Week collage needs Pillow. Install it (pip --user)?')) {
      Invoke-RJNative $py -m pip install --user --quiet pillow
    }
    Invoke-RJNative $py -c 'import PIL'
    if (-not $LASTEXITCODE) {
      $pyw = Join-Path (Split-Path $py) 'pythonw.exe'
      $config.python = if (Test-Path $pyw) { $pyw } else { $py }
      Say 'Radiojoy Week collage: on'
      if (-not (Get-Command tesseract -ErrorAction SilentlyContinue)) {
        Warn 'Optional: Tesseract OCR lets it read next year''s week from announcement banners.'
      }
    }
  } else {
    Warn 'The Radiojoy Week collage needs Python (winget install Python.Python.3.13); rerun this after.'
  }
}
Write-RJFile (Join-Path $RJ 'config.json') ($config | ConvertTo-Json)

# --- start at login, and now ------------------------------------------------------------------
Say 'Starting Radiojoy (and at every login)'
$agentArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $RJ 'radiojoy-agent.ps1')`""
$conhost = Join-Path $env:WINDIR 'System32\conhost.exe'
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Startup')) 'Radiojoy.lnk'))
if ($build -ge 19041) {
  # conhost --headless: no window at all, even where Windows Terminal is the default
  $shortcut.TargetPath = $conhost
  $shortcut.Arguments = "--headless powershell.exe $agentArgs -Login"
} else {
  $shortcut.TargetPath = 'powershell.exe'
  $shortcut.Arguments = "$agentArgs -Login"
  $shortcut.WindowStyle = 7
}
$shortcut.WorkingDirectory = $RJ
$shortcut.Description = 'Radiojoy: the desktop follows the wallpaper'
$shortcut.Save()
if ($build -ge 19041) { Start-Process -FilePath $conhost -ArgumentList "--headless powershell.exe $agentArgs" }
else { Start-Process -FilePath 'powershell.exe' -ArgumentList $agentArgs -WindowStyle Hidden }

Write-Host ''
Say 'Done! Click the Radiojoy icon in the tray (it may hide under the ^ arrow) for the next wallpaper.'
Write-Host '   Windows Terminal: pick the "Radiojoy" profile, or set it as the default in Settings.'
Write-Host "   Uninstall: powershell -ExecutionPolicy Bypass -File `"$(Join-Path $RJ 'uninstall.ps1')`""
