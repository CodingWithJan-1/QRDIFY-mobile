param(
    [string]$Source = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Source)) {
    $Source = Join-Path $repoRoot "assets\images\logo\school logo.jpg"
}

function Write-SquareIcon {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$Size,
        [double]$LogoScale = 0.84,
        [bool]$Transparent = $false
    )

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null

    $sourceImage = [System.Drawing.Image]::FromFile($Source)
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.Clear($(if ($Transparent) { [System.Drawing.Color]::Transparent } else { [System.Drawing.Color]::White }))

        $logoSize = [Math]::Max(1, [int]($Size * $LogoScale))
        $offset = [int](($Size - $logoSize) / 2)
        $graphics.DrawImage($sourceImage, $offset, $offset, $logoSize, $logoSize)
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
        $sourceImage.Dispose()
    }
}

$androidIcons = @{
    "mipmap-mdpi\ic_launcher.png" = 48
    "mipmap-hdpi\ic_launcher.png" = 72
    "mipmap-xhdpi\ic_launcher.png" = 96
    "mipmap-xxhdpi\ic_launcher.png" = 144
    "mipmap-xxxhdpi\ic_launcher.png" = 192
}

$androidRes = Join-Path $repoRoot "android\app\src\main\res"
foreach ($entry in $androidIcons.GetEnumerator()) {
    Write-SquareIcon -Path (Join-Path $androidRes $entry.Key) -Size $entry.Value
}
Write-SquareIcon `
    -Path (Join-Path $androidRes "drawable-nodpi\ic_launcher_foreground.png") `
    -Size 432 `
    -LogoScale 0.66 `
    -Transparent $true

$iosIcons = @{
    "Icon-App-20x20@1x.png" = 20
    "Icon-App-20x20@2x.png" = 40
    "Icon-App-20x20@3x.png" = 60
    "Icon-App-29x29@1x.png" = 29
    "Icon-App-29x29@2x.png" = 58
    "Icon-App-29x29@3x.png" = 87
    "Icon-App-40x40@1x.png" = 40
    "Icon-App-40x40@2x.png" = 80
    "Icon-App-40x40@3x.png" = 120
    "Icon-App-60x60@2x.png" = 120
    "Icon-App-60x60@3x.png" = 180
    "Icon-App-76x76@1x.png" = 76
    "Icon-App-76x76@2x.png" = 152
    "Icon-App-83.5x83.5@2x.png" = 167
    "Icon-App-1024x1024@1x.png" = 1024
}

$iosIconDir = Join-Path $repoRoot "ios\Runner\Assets.xcassets\AppIcon.appiconset"
foreach ($entry in $iosIcons.GetEnumerator()) {
    Write-SquareIcon -Path (Join-Path $iosIconDir $entry.Key) -Size $entry.Value
}

Write-Host "Generated Android and iOS icons from $Source"
