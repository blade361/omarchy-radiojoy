# Dot-sourced by the PowerShell profile block: at every prompt, a terminal whose
# palette doesn't match the wallpaper's character switches to it (OSC sequences), and
# back to its own colours when the wallpaper isn't a Radiojoy one.
. (Join-Path $PSScriptRoot 'radiojoy-common.ps1')
if ($null -eq $global:RadiojoyWho) { $global:RadiojoyWho = '' }
$global:RadiojoyInnerPrompt = $function:prompt
function global:prompt {
  # the inner prompt first, so it still sees the last command's $?
  $p = & $global:RadiojoyInnerPrompt
  $w = Get-RJWho
  if ($w -ne $global:RadiojoyWho) {
    [Console]::Write((Get-RJTermSequence $w))
    $global:RadiojoyWho = $w
  }
  $p
}
