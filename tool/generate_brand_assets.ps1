# Generates the temporary Tafseer Audio brand assets.
# Run from the project root:
#   powershell -ExecutionPolicy Bypass -File tool/generate_brand_assets.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$imagesDir = Join-Path $root 'assets\images'
New-Item -ItemType Directory -Force -Path $imagesDir | Out-Null

$emerald = [System.Drawing.ColorTranslator]::FromHtml('#0B4F3C')
$emeraldDark = [System.Drawing.ColorTranslator]::FromHtml('#073B2D')
$gold = [System.Drawing.ColorTranslator]::FromHtml('#C6A15B')

function New-RoundedRectPath {
    param(
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Radius
    )

    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-Mark {
    param(
        [System.Drawing.Graphics]$Graphics,
        [float]$CenterX,
        [float]$CenterY,
        [float]$Scale,
        [System.Drawing.Color]$Color
    )

    $state = $Graphics.Save()
    $Graphics.TranslateTransform($CenterX, $CenterY)
    $Graphics.ScaleTransform($Scale, $Scale)

    $starPen = [System.Drawing.Pen]::new($Color, 14)
    $starPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Miter

    # Two overlapping squares form an eight-pointed Islamic star.
    $starRect = [System.Drawing.RectangleF]::new(-205, -205, 410, 410)
    $Graphics.DrawRectangle($starPen, $starRect.X, $starRect.Y, $starRect.Width, $starRect.Height)
    $Graphics.TranslateTransform(0, 0)
    $Graphics.RotateTransform(45)
    $Graphics.DrawRectangle($starPen, $starRect.X, $starRect.Y, $starRect.Width, $starRect.Height)
    $Graphics.ResetTransform()
    $Graphics.TranslateTransform($CenterX, $CenterY)
    $Graphics.ScaleTransform($Scale, $Scale)

    # A mihrab-inspired pointed arch.
    $arch = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $arch.StartFigure()
    $arch.AddLine(-140, 200, -140, -30)
    $arch.AddBezier(-140, -30, -140, -120, -70, -210, 0, -230)
    $arch.AddBezier(0, -230, 70, -210, 140, -120, 140, -30)
    $arch.AddLine(140, -30, 140, 200)
    $arch.CloseFigure()

    $archFill = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(24, $Color))
    $archPen = [System.Drawing.Pen]::new($Color, 14)
    $Graphics.FillPath($archFill, $arch)
    $Graphics.DrawPath($archPen, $arch)

    # Sound-wave bars inside the arch.
    $barBrush = [System.Drawing.SolidBrush]::new($Color)
    $barWidth = 18.0
    $barCenters = @(-80.0, -40.0, 0.0, 40.0, 80.0)
    $barHeights = @(54.0, 96.0, 138.0, 96.0, 54.0)
    for ($i = 0; $i -lt $barCenters.Count; $i++) {
        $height = $barHeights[$i]
        $barPath = New-RoundedRectPath `
            -X ($barCenters[$i] - $barWidth / 2) `
            -Y (75 - $height / 2) `
            -Width $barWidth `
            -Height $height `
            -Radius 9
        $Graphics.FillPath($barBrush, $barPath)
        $barPath.Dispose()
    }

    $archFill.Dispose()
    $archPen.Dispose()
    $barBrush.Dispose()
    $arch.Dispose()
    $starPen.Dispose()
    $Graphics.Restore($state)
}

function New-Canvas {
    param([int]$Size, [bool]$Transparent = $false)

    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    if ($Transparent) {
        $graphics.Clear([System.Drawing.Color]::Transparent)
    }

    return @{ Bitmap = $bitmap; Graphics = $graphics }
}

function Save-Png {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Path
    )

    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

# Legacy square launcher icon.
$canvas = New-Canvas -Size 1024
$gradientRect = [System.Drawing.Rectangle]::new(0, 0, 1024, 1024)
$gradient = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    $gradientRect,
    $emerald,
    $emeraldDark,
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
)
$canvas.Graphics.FillRectangle($gradient, $gradientRect)

# Subtle geometric texture.
$texturePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(16, $gold), 2)
for ($x = 96; $x -lt 1024; $x += 128) {
    for ($y = 96; $y -lt 1024; $y += 128) {
        $canvas.Graphics.DrawRectangle($texturePen, $x - 14, $y - 14, 28, 28)
        $state = $canvas.Graphics.Save()
        $canvas.Graphics.TranslateTransform($x, $y)
        $canvas.Graphics.RotateTransform(45)
        $canvas.Graphics.DrawRectangle($texturePen, -14, -14, 28, 28)
        $canvas.Graphics.Restore($state)
    }
}
$texturePen.Dispose()
$gradient.Dispose()

Draw-Mark -Graphics $canvas.Graphics -CenterX 512 -CenterY 512 -Scale 1.35 -Color $gold
Save-Png -Bitmap $canvas.Bitmap -Path (Join-Path $imagesDir 'app_icon.png')
$canvas.Graphics.Dispose()
$canvas.Bitmap.Dispose()

# Adaptive icon foreground (transparent, safe-zone sized mark).
$canvas = New-Canvas -Size 1024 -Transparent $true
Draw-Mark -Graphics $canvas.Graphics -CenterX 512 -CenterY 512 -Scale 1.0 -Color $gold
Save-Png -Bitmap $canvas.Bitmap -Path (Join-Path $imagesDir 'app_icon_foreground.png')
$canvas.Graphics.Dispose()
$canvas.Bitmap.Dispose()

# Themed monochrome icon.
$canvas = New-Canvas -Size 1024 -Transparent $true
Draw-Mark -Graphics $canvas.Graphics -CenterX 512 -CenterY 512 -Scale 1.0 -Color ([System.Drawing.Color]::White)
Save-Png -Bitmap $canvas.Bitmap -Path (Join-Path $imagesDir 'app_icon_monochrome.png')
$canvas.Graphics.Dispose()
$canvas.Bitmap.Dispose()

# In-app transparent mark.
$canvas = New-Canvas -Size 512 -Transparent $true
Draw-Mark -Graphics $canvas.Graphics -CenterX 256 -CenterY 256 -Scale 0.72 -Color $gold
Save-Png -Bitmap $canvas.Bitmap -Path (Join-Path $imagesDir 'app_mark.png')
$canvas.Graphics.Dispose()
$canvas.Bitmap.Dispose()

# Splash mark: emerald medallion with a gold mark.
$canvas = New-Canvas -Size 512 -Transparent $true
$medallionRect = [System.Drawing.RectangleF]::new(46, 46, 420, 420)
$medallionBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    [System.Drawing.Rectangle]::new(46, 46, 420, 420),
    $emerald,
    $emeraldDark,
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
)
$canvas.Graphics.FillEllipse($medallionBrush, $medallionRect)
$medallionBrush.Dispose()
Draw-Mark -Graphics $canvas.Graphics -CenterX 256 -CenterY 256 -Scale 0.62 -Color $gold
Save-Png -Bitmap $canvas.Bitmap -Path (Join-Path $imagesDir 'splash_logo.png')
$canvas.Graphics.Dispose()
$canvas.Bitmap.Dispose()

Write-Host "Generated brand assets in $imagesDir"
