param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetRoot = Join-Path $ProjectRoot 'assets\app-icons\milk-frog'
$mediaRoot = Join-Path $ProjectRoot 'AppScope\resources\base\media'
$source = [System.Drawing.Bitmap]::FromFile((Join-Path $assetRoot 'portrait-source.png'))

# Preserve the natural neck/shoulder crop at the bottom of the generated portrait.
$foreground = New-Object System.Drawing.Bitmap(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($foreground)
$imageAttributes = New-Object System.Drawing.Imaging.ImageAttributes
try {
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $imageAttributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, 1024, 1024),
        0, 0, $source.Width, $source.Height, [System.Drawing.GraphicsUnit]::Pixel, $imageAttributes)
    $foreground.Save((Join-Path $assetRoot 'foreground.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    $foreground.Save((Join-Path $mediaRoot 'milk_frog_foreground.png'), [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $graphics.Dispose()
    $imageAttributes.Dispose()
    $source.Dispose()
}

try {
    foreach ($variant in @('white', 'black')) {
        $background = [System.Drawing.Bitmap]::FromFile((Join-Path $mediaRoot "frog_background_$variant.png"))
        $preview = New-Object System.Drawing.Bitmap(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($preview)
        try {
            $graphics.DrawImage($background, 0, 0, 1024, 1024)
            $graphics.DrawImage($foreground, 0, 0, 1024, 1024)
            $preview.Save((Join-Path $mediaRoot "alt_icon_milk_frog_${variant}_preview.png"), [System.Drawing.Imaging.ImageFormat]::Png)
            $preview.Save((Join-Path $assetRoot "$variant.png"), [System.Drawing.Imaging.ImageFormat]::Png)
            foreach ($size in @(48, 96)) {
                $small = New-Object System.Drawing.Bitmap($size, $size)
                $smallGraphics = [System.Drawing.Graphics]::FromImage($small)
                try {
                    $smallGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $smallGraphics.DrawImage($preview, 0, 0, $size, $size)
                    $small.Save((Join-Path $assetRoot "$variant-$size.png"), [System.Drawing.Imaging.ImageFormat]::Png)
                } finally {
                    $smallGraphics.Dispose()
                    $small.Dispose()
                }
            }
        } finally {
            $graphics.Dispose()
            $preview.Dispose()
            $background.Dispose()
        }
    }
} finally {
    $foreground.Dispose()
}
Write-Output 'Exported colored milk-frog portrait foreground, black/white backgrounds, and 48/96 px checks.'
