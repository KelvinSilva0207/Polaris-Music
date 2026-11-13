<#
    Genera las imagenes del asistente de instalacion a partir del logo de la app.

    - assets/wizard.png        430x824  panel lateral (Welcome / Finished)
    - assets/wizard_small.png  168x168  icono de la esquina superior derecha

    Uso:  powershell -ExecutionPolicy Bypass -File installer\generate_assets.ps1
#>

[CmdletBinding()]
param(
    [string]$LogoPath,
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $LogoPath) {
    $LogoPath = Join-Path $scriptDir '..\assets\icons\polaris_music.ico'
}
if (-not $OutputDir) {
    $OutputDir = Join-Path $scriptDir 'assets'
}

function New-RoundedPath {
    param([float]$X, [float]$Y, [float]$W, [float]$H, [float]$R)

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $R * 2
    $path.AddArc($X, $Y, $d, $d, 180, 90)
    $path.AddArc($X + $W - $d, $Y, $d, $d, 270, 90)
    $path.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90)
    $path.AddArc($X, $Y + $H - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Set-HighQuality {
    param([System.Drawing.Graphics]$Graphics)

    $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $Graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $Graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
}

function Draw-RoundedImage {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Image]$Image,
        [float]$X,
        [float]$Y,
        [float]$Size,
        [float]$Radius
    )

    $path = New-RoundedPath -X $X -Y $Y -W $Size -H $Size -R $Radius
    $state = $Graphics.Save()
    $Graphics.SetClip($path)
    $dest = New-Object System.Drawing.Rectangle([int]$X, [int]$Y, [int]$Size, [int]$Size)
    $Graphics.DrawImage($Image, $dest)
    $Graphics.Restore($state)
    $path.Dispose()
}

function Add-StarField {
    param(
        [System.Drawing.Graphics]$Graphics,
        [int]$Width,
        [int]$Height,
        [int]$Count = 110
    )

    $random = New-Object System.Random(20261112)
    for ($i = 0; $i -lt $Count; $i++) {
        $x = [float]$random.Next(10, $Width - 10)
        $y = [float]$random.Next(10, $Height - 10)
        $size = [float]($random.NextDouble() * 1.7 + 0.6)
        $alpha = $random.Next(18, 105)
        $color = [System.Drawing.Color]::FromArgb($alpha, 226, 230, 255)
        $brush = New-Object System.Drawing.SolidBrush($color)
        $Graphics.FillEllipse($brush, $x, $y, $size, $size)
        $brush.Dispose()
    }
}

function Add-Glow {
    param(
        [System.Drawing.Graphics]$Graphics,
        [float]$CenterX,
        [float]$CenterY,
        [float]$Radius,
        [System.Drawing.Color]$Color,
        [int]$Alpha = 95
    )

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse($CenterX - $Radius, $CenterY - $Radius, $Radius * 2, $Radius * 2)
    $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $brush.CenterColor = [System.Drawing.Color]::FromArgb($Alpha, $Color.R, $Color.G, $Color.B)
    $brush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $Color.R, $Color.G, $Color.B))
    $Graphics.FillPath($brush, $path)
    $brush.Dispose()
    $path.Dispose()
}

function Draw-CenteredText {
    param(
        [System.Drawing.Graphics]$Graphics,
        [string]$Text,
        [float]$Y,
        [float]$Height,
        [float]$Size,
        [string]$Family,
        [System.Drawing.Color]$Color,
        [int]$Width = 430
    )

    $font = New-Object System.Drawing.Font($Family, $Size, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $brush = New-Object System.Drawing.SolidBrush($Color)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = New-Object System.Drawing.RectangleF(0, $Y, $Width, $Height)
    $Graphics.DrawString($Text, $font, $brush, $rect, $format)
    $brush.Dispose()
    $font.Dispose()
    $format.Dispose()
}

if (-not (Test-Path -LiteralPath $LogoPath)) {
    throw "No se encontro el logo: $LogoPath"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$iconObject = $null
$fullLogoPath = [System.IO.Path]::GetFullPath($LogoPath)
if ([System.IO.Path]::GetExtension($fullLogoPath) -ieq '.ico') {
    $iconObject = New-Object System.Drawing.Icon($fullLogoPath, 256, 256)
    $logo = $iconObject.ToBitmap()
}
else {
    $logo = [System.Drawing.Image]::FromFile($fullLogoPath)
}

# -----------------------------------------------------------------------------
# Panel lateral del asistente (430x824)
# -----------------------------------------------------------------------------
$w = 430
$h = 824
$wizard = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($wizard)
Set-HighQuality -Graphics $g
$rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)

$background = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(255, 6, 9, 22),
    [System.Drawing.Color]::FromArgb(255, 27, 20, 58),
    90.0
)
$g.FillRectangle($background, $rect)
$background.Dispose()

# Halo violeta detras del logo y brillo inferior.
Add-Glow -Graphics $g -CenterX 215 -CenterY 305 -Radius 240 -Color ([System.Drawing.Color]::FromArgb(255, 124, 92, 255)) -Alpha 105
Add-Glow -Graphics $g -CenterX 215 -CenterY 720 -Radius 210 -Color ([System.Drawing.Color]::FromArgb(255, 58, 44, 140)) -Alpha 65

Add-StarField -Graphics $g -Width $w -Height $h

# Orbitas concentricas.
$orbitColors = @(38, 30, 22)
$orbitSizes = @(150, 196, 242)
for ($i = 0; $i -lt $orbitSizes.Count; $i++) {
    $r = $orbitSizes[$i]
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($orbitColors[$i], 198, 188, 255), 1.0)
    $g.DrawEllipse($pen, 215 - $r, 305 - $r, $r * 2, $r * 2)
    $pen.Dispose()
}

# Logo principal (recortado en una tarjeta redondeada).
$logoSize = 286
$logoX = ($w - $logoSize) / 2
$logoY = 162
Draw-RoundedImage -Graphics $g -Image $logo -X $logoX -Y $logoY -Size $logoSize -Radius 62

# Nombre y firma visual.
Draw-CenteredText -Graphics $g -Text 'P O L A R I S' -Y 500 -Height 48 -Size 31 -Family 'Segoe UI Semibold' -Color ([System.Drawing.Color]::FromArgb(245, 241, 238, 255)) -Width $w
Draw-CenteredText -Graphics $g -Text 'M U S I C' -Y 549 -Height 26 -Size 14 -Family 'Segoe UI' -Color ([System.Drawing.Color]::FromArgb(225, 178, 160, 255)) -Width $w

$linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(190, 142, 118, 255), 1.6)
$g.DrawLine($linePen, 180, 592, 250, 592)
$linePen.Dispose()

Draw-CenteredText -Graphics $g -Text 'Reproductor de audio' -Y 612 -Height 26 -Size 13 -Family 'Segoe UI' -Color ([System.Drawing.Color]::FromArgb(150, 214, 210, 238)) -Width $w
Draw-CenteredText -Graphics $g -Text 'W I N D O W S   ·   A N D R O I D' -Y 756 -Height 24 -Size 10 -Family 'Segoe UI' -Color ([System.Drawing.Color]::FromArgb(110, 190, 186, 220)) -Width $w

# Vinetas superior e inferior para integrar el panel con el asistente.
$topFade = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle(0, 0, $w, 110)),
    [System.Drawing.Color]::FromArgb(120, 4, 6, 18),
    [System.Drawing.Color]::FromArgb(0, 4, 6, 18),
    90.0
)
$g.FillRectangle($topFade, 0, 0, $w, 110)
$topFade.Dispose()

$fadeY = $h - 150
$bottomFade = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle(0, $fadeY, $w, 150)),
    [System.Drawing.Color]::FromArgb(0, 4, 6, 18),
    [System.Drawing.Color]::FromArgb(160, 4, 6, 18),
    90.0
)
$g.FillRectangle($bottomFade, 0, $fadeY, $w, 150)
$bottomFade.Dispose()

$g.Dispose()
$wizardPath = Join-Path $OutputDir 'wizard.png'
$wizard.Save($wizardPath, [System.Drawing.Imaging.ImageFormat]::Png)
$wizard.Dispose()

# -----------------------------------------------------------------------------
# Icono pequeno del asistente (168x168, esquinas transparentes)
# -----------------------------------------------------------------------------
$s = 168
$small = New-Object System.Drawing.Bitmap($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($small)
Set-HighQuality -Graphics $g
$g.Clear([System.Drawing.Color]::Transparent)

$tilePath = New-RoundedPath -X 4 -Y 4 -W 160 -H 160 -R 36
$tileGradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle(4, 4, 160, 160)),
    [System.Drawing.Color]::FromArgb(255, 19, 25, 53),
    [System.Drawing.Color]::FromArgb(255, 43, 30, 88),
    45.0
)
$g.FillPath($tileGradient, $tilePath)
$tileGradient.Dispose()

$borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(185, 139, 117, 255), 1.4)
$g.DrawPath($borderPen, $tilePath)
$borderPen.Dispose()

Add-Glow -Graphics $g -CenterX 84 -CenterY 84 -Radius 62 -Color ([System.Drawing.Color]::FromArgb(255, 130, 100, 255)) -Alpha 80

$smallLogo = 112
$smallX = ($s - $smallLogo) / 2
Draw-RoundedImage -Graphics $g -Image $logo -X $smallX -Y $smallX -Size $smallLogo -Radius 26

$g.Dispose()
$tilePath.Dispose()
$smallPath = Join-Path $OutputDir 'wizard_small.png'
$small.Save($smallPath, [System.Drawing.Imaging.ImageFormat]::Png)
$small.Dispose()

$logo.Dispose()
if ($iconObject) {
    $iconObject.Dispose()
}

Write-Host "Imagenes generadas en $OutputDir" -ForegroundColor Green
Write-Host "  wizard.png        ($w x $h)"
Write-Host "  wizard_small.png  ($s x $s)"
