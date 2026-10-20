# Radiojoy for Windows 10 / 11. The easy way is the one line in the README (get.ps1),
# or double-click install.cmd. It asks nothing; from the repo with options:
#   powershell -ExecutionPolicy Bypass -File windows\install.ps1 [options]
#   -NoSplash    don't add the terminal splash to your PowerShell profile
#   -NoSpotify   leave Spotify / Spicetify alone
#   -NoAccent    keep your accent colour (no crimson / periwinkle Start and taskbar)
#   -NoBorders   keep the normal window borders and title bars
#   -NoSounds    keep your notification sound
#   -NoWeek      no Radiojoy Week collage (it needs Python + Pillow)
#   -NoExtras    don't install fastfetch or Pillow
#   -NoDefault   don't make Radiojoy Windows Terminal's default profile
param([switch]$NoSplash, [switch]$NoSpotify, [switch]$NoAccent, [switch]$NoBorders,
  [switch]$NoSounds, [switch]$NoWeek, [switch]$NoExtras, [switch]$NoDefault, [switch]$Yes)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'radiojoy-common.ps1')

function Say([string]$Text) { Write-Host ([char]::ConvertFromUtf32(0x1F4FB) + ' ') -NoNewline -ForegroundColor Red; Write-Host $Text }
function Warn([string]$Text) { Write-Host "! $Text" -ForegroundColor Yellow }

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
foreach ($f in 'radiojoy-common.ps1', 'radiojoy-agent.ps1', 'radiojoy-splash.ps1', 'radiojoy-prompt.ps1', 'radiojoy-shell.ps1',
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
# The Radiojoy profile runs its own scripts with -ExecutionPolicy Bypass, so it works
# without changing PowerShell's script policy.
$shellExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { 'pwsh.exe' } else { 'powershell.exe' }
$shell = "$shellExe -NoLogo -NoExit -ExecutionPolicy Bypass -Command "". '$(Join-Path $RJ 'radiojoy-shell.ps1')'"""
$guid = '{7a1d0e3c-6b6e-4b4a-9a8e-5241444a4f59}'
$fragment = [ordered]@{
  schemes = $schemes
  profiles = @([ordered]@{ guid = $guid; name = 'Radiojoy'; commandline = $shell
      colorScheme = 'Radiojoy'; icon = (Join-Path $RJ 'radiojoy.ico'); startingDirectory = '%USERPROFILE%' })
}
$fragDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\Radiojoy'
Write-RJFile (Join-Path $fragDir 'radiojoy.json') ($fragment | ConvertTo-Json -Depth 5)
# ...and opens when you start Windows Terminal (the old default is put back on uninstall)
if (-not $NoDefault) {
  foreach ($f in Get-RJTerminalSettings) {
    $text = Read-RJText $f
    $m = [regex]::Match($text, '"defaultProfile"\s*:\s*"([^"]*)"')
    if (-not $m.Success -or $m.Groups[1].Value -eq $guid) { continue }
    $saved = Join-Path $RJState 'terminal-default.json'
    $old = @{}
    try { $o = (Read-RJText $saved) | ConvertFrom-Json; foreach ($q in $o.PSObject.Properties) { $old[$q.Name] = $q.Value } } catch { }
    if (-not $old.ContainsKey($f)) { $old[$f] = $m.Groups[1].Value; Write-RJFile $saved ($old | ConvertTo-Json) }
    Write-RJFile $f ($text.Substring(0, $m.Groups[1].Index) + $guid + $text.Substring($m.Groups[1].Index + $m.Groups[1].Length))
  }
}

# --- PowerShell profile: splash + colours in every PowerShell window --------------------
# Only where PowerShell may run profile scripts; the Radiojoy terminal profile works anyway.
$policy = Get-ExecutionPolicy
$profileOk = $policy -in 'RemoteSigned', 'Unrestricted', 'Bypass'
$block = @'
# >>> radiojoy >>>
if (-not $global:RadiojoyLoaded -and (Test-Path "$env:LOCALAPPDATA\Radiojoy\radiojoy-shell.ps1")) {
  . "$env:LOCALAPPDATA\Radiojoy\radiojoy-shell.ps1"
}
# <<< radiojoy <<<
'@
$docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($dir in 'WindowsPowerShell', 'PowerShell') {
  Edit-RJProfile (Join-Path $docs "$dir\profile.ps1") $(if ($NoSplash -or -not $profileOk) { '' } else { $block })
}

# --- extras: fastfetch for the splash ---------------------------------------------------
if (-not $NoExtras -and -not (Get-Command fastfetch -ErrorAction SilentlyContinue) -and (Get-Command winget -ErrorAction SilentlyContinue)) {
  Say 'Installing fastfetch (the system info in the terminal splash)'
  Invoke-RJNative winget install --exact --id Fastfetch-cli.Fastfetch --scope user --silent --accept-source-agreements --accept-package-agreements | Out-Null
}

# --- Spotify (Spicetify) ---------------------------------------------------------------
$notes = @()
if (-not $NoSpotify) {
  if (Get-Command spicetify -ErrorAction SilentlyContinue) {
    Say 'Spotify colours (Spicetify)'
    try {
      $cfg = Split-Path -Parent "$(Invoke-RJNative spicetify -c | Select-Object -Last 1)".Trim()
      New-Item -ItemType Directory -Force -Path (Join-Path $cfg 'Extensions'), (Join-Path $cfg 'Themes') | Out-Null
      Copy-Item -LiteralPath (Join-Path $repo 'spicetify\radiojoy-follow.js') -Destination (Join-Path $cfg 'Extensions') -Force
      Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'spicetify\Radiojoy') -Destination (Join-Path $cfg 'Themes') -Recurse -Force
      $current = "$(Invoke-RJNative spicetify config current_theme | Select-Object -Last 1)".Trim()
      if (-not $current -or $current -in 'SpicetifyDefault', 'marketplace', 'Radiojoy') {
        Invoke-RJNative spicetify config current_theme Radiojoy color_scheme Radiojoy | Out-Null
      }
      Invoke-RJNative spicetify config extensions radiojoy-follow.js | Out-Null
      Invoke-RJNative spicetify apply | Out-Null
      if ($LASTEXITCODE) { Invoke-RJNative spicetify backup apply | Out-Null }
      if ($LASTEXITCODE) { $notes += 'Spotify: run "spicetify backup apply" once to finish.' }
    } catch { $notes += "Spotify colours couldn't be set up ($_)." }
  } else {
    $notes += 'Want Spotify in Radiojoy colours too? Install Spicetify (spicetify.app), then install Radiojoy again.'
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
    if ($LASTEXITCODE -and -not $NoExtras) {
      Say 'Installing Pillow (for the Radiojoy Week collage)'
      Invoke-RJNative $py -m pip install --user --quiet pillow
    }
    Invoke-RJNative $py -c 'import PIL'
    if (-not $LASTEXITCODE) {
      $pyw = Join-Path (Split-Path $py) 'pythonw.exe'
      $config.python = if (Test-Path $pyw) { $pyw } else { $py }
    }
  }
  if (-not $config.python) {
    $notes += 'Want the Radiojoy Week collage wallpaper? Install Python (python.org), then install Radiojoy again.'
  }
}
Write-RJFile (Join-Path $RJ 'config.json') ($config | ConvertTo-Json)

# --- icon, Start menu, Settings > Apps ------------------------------------------------------
New-RJIcon (Join-Path $RJTheme 'splash\heads.png') (Join-Path $RJ 'radiojoy.ico')
$agentArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $RJ 'radiojoy-agent.ps1')`""
$conhost = Join-Path $env:WINDIR 'System32\conhost.exe'
$wsh = New-Object -ComObject WScript.Shell
function New-RJShortcut([string]$Path, [string]$Arguments) {
  $sc = $wsh.CreateShortcut($Path)
  if ($build -ge 19041) {
    # conhost --headless: no window at all, even where Windows Terminal is the default
    $sc.TargetPath = $conhost; $sc.Arguments = "--headless powershell.exe $Arguments"
  } else { $sc.TargetPath = 'powershell.exe'; $sc.Arguments = $Arguments; $sc.WindowStyle = 7 }
  $sc.WorkingDirectory = $RJ
  $sc.IconLocation = Join-Path $RJ 'radiojoy.ico'
  $sc.Description = 'Radiojoy: the desktop follows the wallpaper'
  $sc.Save()
}
New-RJShortcut (Join-Path ([Environment]::GetFolderPath('Startup')) 'Radiojoy.lnk') "$agentArgs -Login"
# in the Start menu, to bring the tray icon back after "Quit"
New-RJShortcut (Join-Path ([Environment]::GetFolderPath('Programs')) 'Radiojoy.lnk') $agentArgs

$uninstall = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Radiojoy'
New-Item -Path $uninstall -Force | Out-Null
$un = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $RJ 'uninstall.ps1')`""
foreach ($kv in @(@('DisplayName', 'Radiojoy'), @('DisplayIcon', (Join-Path $RJ 'radiojoy.ico')), @('Publisher', 'blade361'),
    @('DisplayVersion', '1.0'), @('InstallLocation', $RJ), @('UninstallString', $un), @('QuietUninstallString', $un),
    @('URLInfoAbout', 'https://github.com/blade361/omarchy-radiojoy'))) {
  Set-ItemProperty -Path $uninstall -Name $kv[0] -Value $kv[1]
}
Set-RJDword $uninstall 'NoModify' 1; Set-RJDword $uninstall 'NoRepair' 1
Set-RJDword $uninstall 'EstimatedSize' ([int]((Get-ChildItem -LiteralPath $RJ -Recurse -File | Measure-Object Length -Sum).Sum / 1KB))

# --- start it -----------------------------------------------------------------------------
Remove-Item (Join-Path $RJState 'welcomed') -ErrorAction SilentlyContinue
if ($build -ge 19041) { Start-Process -FilePath $conhost -ArgumentList "--headless powershell.exe $agentArgs" }
else { Start-Process -FilePath 'powershell.exe' -ArgumentList $agentArgs -WindowStyle Hidden }

Write-Host ''
Say 'Radiojoy is on! Stay tuned.'
Write-Host '   - Click the Radiojoy icon by the clock for the next wallpaper (it may hide under ^).'
Write-Host '   - Open Windows Terminal to see the splash.'
Write-Host '   - To remove it: Settings > Apps > Installed apps > Radiojoy > Uninstall.'
foreach ($n in $notes) { Write-Host "   - $n" -ForegroundColor DarkGray }
