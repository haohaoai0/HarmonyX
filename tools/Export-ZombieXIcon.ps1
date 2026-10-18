param(
    [string]$SourcePath = 'C:\Users\Fanha\.codex\generated_images\01a14a6d-caea-77e2-bd20-a1a37f62dcf9\exec-c5833b80-372a-4081-af94-96390fdd30aa.png',
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetRoot = Join-Path $ProjectRoot 'assets\app-icons\zombie-x'
New-Item -ItemType Directory -Path $assetRoot -Force | Out-Null
$savedSource = Join-Path $assetRoot 'source.png'
if (-not (Test-Path -LiteralPath $savedSource)) {
    Copy-Item -LiteralPath $SourcePath -Destination $savedSource
}

$source = [System.Drawing.Bitmap]::FromFile($savedSource)
$sourceSize = @($source.Width, $source.Height)
$foreground = [System.Drawing.Bitmap]::new(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($foreground)
$attributes = [System.Drawing.Imaging.ImageAttributes]::new()
try {
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, 1024, 1024),
        0, 0, $source.Width, $source.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
    $foreground.Save((Join-Path $assetRoot 'foreground.png'), [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $source.Dispose()
    $graphics.Dispose()
    $attributes.Dispose()
}

$background = [System.Drawing.Bitmap]::new(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($background)
$brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    [System.Drawing.Rectangle]::new(0, 0, 1024, 1024),
    [System.Drawing.Color]::FromArgb(255, 23, 29, 22),
    [System.Drawing.Color]::FromArgb(255, 7, 10, 7),
    [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
try {
    $graphics.FillRectangle($brush, 0, 0, 1024, 1024)
    $background.Save((Join-Path $assetRoot 'background.png'), [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $brush.Dispose()
    $graphics.Dispose()
}

$preview = [System.Drawing.Bitmap]::new(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($preview)
try {
    $graphics.DrawImageUnscaled($background, 0, 0)
    $graphics.DrawImageUnscaled($foreground, 0, 0)
    $preview.Save((Join-Path $assetRoot 'preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    foreach ($size in @(48, 96, 192)) {
        $small = [System.Drawing.Bitmap]::new($size, $size)
        $smallGraphics = [System.Drawing.Graphics]::FromImage($small)
        try {
            $smallGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $smallGraphics.DrawImage($preview, 0, 0, $size, $size)
            $small.Save((Join-Path $assetRoot "preview-$size.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $smallGraphics.Dispose()
            $small.Dispose()
        }
    }

    $checks = @()
    foreach ($entry in @(
        @{ Name = 'foreground.png'; Bitmap = $foreground },
        @{ Name = 'background.png'; Bitmap = $background },
        @{ Name = 'preview.png'; Bitmap = $preview }
    )) {
        $bitmap = $entry.Bitmap
        $data = $bitmap.LockBits([System.Drawing.Rectangle]::new(0, 0, 1024, 1024),
            [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $pixels = [byte[]]::new($data.Stride * $data.Height)
            [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $pixels, 0, $pixels.Length)
            $minAlpha = 255
            $maxAlpha = 0
            $transparentPixels = 0
            $left = 1024
            $top = 1024
            $right = -1
            $bottom = -1
            for ($y = 0; $y -lt 1024; $y++) {
                for ($x = 0; $x -lt 1024; $x++) {
                    $alpha = [int]$pixels[$y * $data.Stride + $x * 4 + 3]
                    if ($alpha -lt $minAlpha) { $minAlpha = $alpha }
                    if ($alpha -gt $maxAlpha) { $maxAlpha = $alpha }
                    if ($alpha -eq 0) { $transparentPixels++ }
                    if ($alpha -gt 16) {
                        if ($x -lt $left) { $left = $x }
                        if ($y -lt $top) { $top = $y }
                        if ($x -gt $right) { $right = $x }
                        if ($y -gt $bottom) { $bottom = $y }
                    }
                }
            }
            $checks += [ordered]@{
                file = $entry.Name
                width = 1024
                height = 1024
                alphaRange = @($minAlpha, $maxAlpha)
                fullyTransparentPixels = $transparentPixels
                visibleBoundsAtAlpha17 = @($left, $top, $right, $bottom)
                cornersAlpha = @([int]$pixels[3], [int]$pixels[1023 * 4 + 3],
                    [int]$pixels[1023 * $data.Stride + 3],
                    [int]$pixels[1023 * $data.Stride + 1023 * 4 + 3])
            }
        } finally {
            $bitmap.UnlockBits($data)
        }
    }
    if ($checks[0].alphaRange[0] -ne 0 -or $checks[0].alphaRange[1] -ne 255) {
        throw 'Foreground must preserve genuine alpha transparency.'
    }
    if ($checks[1].alphaRange[0] -ne 255 -or $checks[2].alphaRange[0] -ne 255) {
        throw 'Background and full preview must be completely opaque.'
    }
    $report = [ordered]@{
        generator = 'Built-in image_gen'
        sourceDimensions = $sourceSize
        sourceSha256 = (Get-FileHash -LiteralPath $savedSource -Algorithm SHA256).Hash
        resourceChecks = $checks
        appRegistered = (Test-Path -LiteralPath (Join-Path $ProjectRoot 'AppScope\resources\base\media\alt_icon_zombie_x.json'))
        deviceAppearanceVerified = $false
    }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $assetRoot 'verification.json') -Encoding utf8
    $report | ConvertTo-Json -Depth 8
} finally {
    $graphics.Dispose()
    $preview.Dispose()
    $background.Dispose()
    $foreground.Dispose()
}
