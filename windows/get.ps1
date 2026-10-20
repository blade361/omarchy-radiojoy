# Radiojoy for Windows in one line. Paste into PowerShell (Start > type "PowerShell"):
#   irm https://raw.githubusercontent.com/blade361/omarchy-radiojoy/main/windows/get.ps1 | iex
# Downloads the theme, installs it for your user (no admin) and cleans up after itself.
& {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'   # Windows PowerShell downloads crawl with the progress bar
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $branch = if ($env:RADIOJOY_BRANCH) { $env:RADIOJOY_BRANCH } else { 'main' }
  $tmp = Join-Path $env:TEMP ('radiojoy-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  New-Item -ItemType Directory -Path $tmp | Out-Null
  try {
    Write-Host ([char]::ConvertFromUtf32(0x1F4FB) + ' Downloading Radiojoy (about 40 MB)...')
    $zip = Join-Path $tmp 'radiojoy.zip'
    Invoke-WebRequest "https://github.com/blade361/omarchy-radiojoy/archive/refs/heads/$branch.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -LiteralPath $zip -DestinationPath $tmp
    $root = Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1
    # Windows PowerShell even when this was pasted into PowerShell 7: the tray icon needs it
    & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root.FullName 'windows\install.ps1')
  } finally {
    Set-Location $env:TEMP
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}
