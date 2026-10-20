# Builds the splash art's sixel frames for a given height in terminal rows: 00.six is
# the clear picture, 01.six.. the radio static tuning in to it. Cached per size.
# Prints "<cols> <rows> <frame dir>". Run with Windows PowerShell (System.Drawing).
param(
  [Parameter(Mandatory)] [string]$Art,
  [Parameter(Mandatory)] [int]$Rows,
  [int]$CellW = 10,
  [int]$CellH = 20
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'radiojoy-common.ps1')
Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile($Art)
try {
  $h = $Rows * $CellH
  $w = [int][math]::Floor($src.Width * $h / $src.Height)
  $cols = [int][math]::Ceiling($w / $CellW)
  $item = Get-Item -LiteralPath $Art
  $sha = [Security.Cryptography.SHA1]::Create()
  $key = ($sha.ComputeHash($RJUtf8.GetBytes("$($item.FullName)|$($item.LastWriteTimeUtc.Ticks)|${w}x$h")) |
      ForEach-Object { $_.ToString('x2') }) -join ''
  $out = Join-Path $RJCache ('sixel\' + $key.Substring(0, 12))
  if (-not (Test-Path -LiteralPath (Join-Path $out '00.six'))) {
    if (-not ('RadiojoySixel' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'RadiojoySixel.cs') }
    $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($src, 0, 0, $w, $h)
    $g.Dispose()
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $bmp.PixelFormat)
    $px = New-Object int[] ($w * $h)
    # rows can be padded (stride), so copy them one at a time
    for ($y = 0; $y -lt $h; $y++) {
      [Runtime.InteropServices.Marshal]::Copy([IntPtr]($data.Scan0.ToInt64() + $y * $data.Stride), $px, $y * $w, $w)
    }
    $bmp.UnlockBits($data); $bmp.Dispose()
    [RadiojoySixel]::Harden($px)
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    $steps = 12; $block = [math]::Max(2, [int]($CellW / 2))
    for ($i = $steps; $i -ge 0; $i--) {
      $frame = if ($i -eq 0) { $px } else { [RadiojoySixel]::Static($px, $w, $h, $i, $steps, $block) }
      # 00.six last: its presence means the set is complete
      Write-RJFile (Join-Path $out ('{0:00}.six' -f $i)) ([RadiojoySixel]::Encode($frame, $w, $h))
    }
  }
  "$cols $Rows $out"
} finally {
  $src.Dispose()
}
