# Radiojoy in a PowerShell window: the splash, then terminal colours that follow the
# wallpaper. Dot-sourced by the Windows Terminal "Radiojoy" profile and by the block
# install.ps1 adds to your PowerShell profile (once per window, whichever runs first).
if ($global:RadiojoyLoaded) { return }
$global:RadiojoyLoaded = $true
if ($Host.Name -eq 'ConsoleHost') { & (Join-Path $PSScriptRoot 'radiojoy-splash.ps1') }
. (Join-Path $PSScriptRoot 'radiojoy-prompt.ps1')
