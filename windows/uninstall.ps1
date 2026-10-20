# Removes Radiojoy from Windows and puts back what it changed (wallpaper, accent
# colour, dark mode, notification sound, PowerShell profile, Windows Terminal schemes,
# Spicetify). Run: powershell -ExecutionPolicy Bypass -File uninstall.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'radiojoy-common.ps1')
function Say([string]$Text) { Write-Host ([char]::ConvertFromUtf32(0x1F4FB) + ' ') -NoNewline -ForegroundColor Red; Write-Host $Text }

# The agent quits first: it turns the borders, accent and app colours back itself.
$pidFile = Join-Path $RJState 'agent.pid'
if (Test-Path $pidFile) {
  New-Item -ItemType File -Force -Path (Join-Path $RJState 'agent.quit') | Out-Null
  $agent = Get-Process -Id ([int](Read-RJText $pidFile)) -ErrorAction SilentlyContinue
  if ($agent) { if (-not $agent.WaitForExit(8000)) { $agent.Kill() } }
  Say 'Stopped Radiojoy'
}
Remove-Item (Join-Path ([Environment]::GetFolderPath('Startup')) 'Radiojoy.lnk') -ErrorAction SilentlyContinue

$backup = Get-RJBackup
if ($backup) {
  foreach ($v in $RJBackupValues) { Restore-RJValue $backup $v[0] $v[1] }
  if (-not ('RadiojoyNative' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'RadiojoyNative.cs') }
  $wall = $backup.PSObject.Properties["$($RJKeys.Desktop)|WallPaper"].Value
  if (-not $wall -or -not (Test-Path -LiteralPath $wall)) { $wall = '' }
  [void][RadiojoyNative]::SetWallpaper($wall)
  [RadiojoyNative]::Broadcast('ImmersiveColorSet')
  # the lock screen: back to that wallpaper (Spotlight can be turned on again in Settings)
  if ($wall -and $PSVersionTable.PSEdition -ne 'Core') {
    try {
      Add-Type -AssemblyName System.Runtime.WindowsRuntime
      $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
      $asAction = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' } | Select-Object -First 1
      $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
      $null = [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime]
      $t = $asTask.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @([Windows.Storage.StorageFile]::GetFileFromPathAsync($wall)))
      [void]$t.Wait(10000)
      [void]$asAction.Invoke($null, @([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($t.Result))).Wait(10000)
    } catch { }
  }
  Say 'Put back your wallpaper, colours and sounds'
}

$docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($dir in 'WindowsPowerShell', 'PowerShell') { Edit-RJProfile (Join-Path $docs "$dir\profile.ps1") '' }
Remove-Item (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\Radiojoy') -Recurse -Force -ErrorAction SilentlyContinue
Say 'Removed the terminal splash and Windows Terminal schemes'

if (Get-Command spicetify -ErrorAction SilentlyContinue) {
  try {
    $cfg = Split-Path -Parent "$(Invoke-RJNative spicetify -c | Select-Object -Last 1)".Trim()
    Invoke-RJNative spicetify config extensions radiojoy-follow.js- | Out-Null
    if ("$(Invoke-RJNative spicetify config current_theme | Select-Object -Last 1)".Trim() -eq 'Radiojoy') {
      Invoke-RJNative spicetify config current_theme SpicetifyDefault color_scheme '' | Out-Null
    }
    Invoke-RJNative spicetify apply | Out-Null
    Remove-Item (Join-Path $cfg 'Extensions\radiojoy-follow.js'), (Join-Path $cfg 'Themes\Radiojoy') -Recurse -Force -ErrorAction SilentlyContinue
    Say 'Removed the Spotify colours'
  } catch { }
}

# Zen / Firefox: the imported file goes, the @import line is yours to remove
foreach ($root in @("$env:APPDATA\zen\Profiles", "$env:APPDATA\Mozilla\Firefox\Profiles")) {
  if (Test-Path $root) { Get-ChildItem -Path $root -Filter 'radiojoy-zen.css' -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force }
}

# This script lives in the folder it removes: delete it after we've exited.
Say 'Removing the Radiojoy folder'
Set-Location $env:TEMP
Start-Process -FilePath cmd.exe -ArgumentList "/c timeout /t 2 /nobreak >nul & rmdir /s /q `"$RJ`"" -WindowStyle Hidden
Say 'Radiojoy is uninstalled. Stay tuned!'
