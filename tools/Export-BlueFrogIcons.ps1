param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$StoreBranding
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$sourcePath = Join-Path $ProjectRoot 'assets\app-icons\blue-frog-foreground.png'
$sourceImage = [System.Drawing.Bitmap]::FromFile($sourcePath)
if ($sourceImage.Width -ne 1024 -or $sourceImage.Height -ne 1024) {
    $sourceImage.Dispose()
    throw 'The foreground must be 1024 x 1024.'
}

function Save-FrogResource {
    param([string]$RelativePath, [string]$Background = 'transparent', [int]$Size = 1024)
    $outputPath = Join-Path $ProjectRoot $RelativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $outputPath) -Force | Out-Null
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $fill = [System.Drawing.Color]::Transparent
        if ($Background -eq 'black') { $fill = [System.Drawing.Color]::Black }
        if ($Background -eq 'white') { $fill = [System.Drawing.Color]::White }
        $graphics.Clear($fill)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        if ($Background -ne 'background-black' -and $Background -ne 'background-white') {
            $graphics.DrawImage($sourceImage, [System.Drawing.Rectangle]::new(0, 0, $Size, $Size))
        }
        if ($Background -eq 'background-black') { $graphics.Clear([System.Drawing.Color]::Black) }
        if ($Background -eq 'background-white') { $graphics.Clear([System.Drawing.Color]::White) }
        $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    Save-FrogResource 'AppScope\resources\base\media\frog_foreground.png'
    Save-FrogResource 'AppScope\resources\base\media\frog_background_white.png' 'background-white'
    Save-FrogResource 'AppScope\resources\base\media\frog_background_black.png' 'background-black'
    Save-FrogResource 'AppScope\resources\base\media\alt_icon_frog_white_preview.png' 'white'
    Save-FrogResource 'AppScope\resources\base\media\alt_icon_frog_black_preview.png' 'black'
    Save-FrogResource 'assets\app-icons\blue-frog-white.png' 'white'
    Save-FrogResource 'assets\app-icons\blue-frog-black.png' 'black'

    if ($StoreBranding) {
        foreach ($mode in @('base', 'light', 'dark')) {
            $background = 'black'
            if ($mode -eq 'light') { $background = 'white' }
            foreach ($mediaRoot in @('AppScope\resources', 'entry\src\main\resources')) {
                $mediaPath = "$mediaRoot\$mode\media"
                Save-FrogResource "$mediaPath\icon_foreground.png"
                Save-FrogResource "$mediaPath\icon_background.png" "background-$background"
                if ($mediaRoot -eq 'AppScope\resources') {
                    Save-FrogResource "$mediaPath\app_icon.png" $background
                    Save-FrogResource "$mediaPath\ui_brand_foreground.png"
                } else {
                    Save-FrogResource "$mediaPath\icon.png" $background
                    Save-FrogResource "$mediaPath\start_window_icon.png" 'transparent' 144
                }
            }
        }
    }
} finally {
    $sourceImage.Dispose()
}
Write-Output 'Exported the white and black blue-frog icons; all backgrounds are opaque and foregrounds retain alpha.'
