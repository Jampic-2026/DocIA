param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

Add-Type -AssemblyName System.Drawing

$sourcePath = Join-Path $ProjectRoot 'assets\images\logo.png'
$masterPath = Join-Path $ProjectRoot 'assets\images\doc_ia_app_icon.png'

function New-DocIaIcon {
    param(
        [int]$Size,
        [string]$Destination,
        [double]$MarkWidthRatio = 0.76,
        [double]$CornerRadiusRatio = 0.20,
        [switch]$OpaqueBackground
    )

    $source = [System.Drawing.Bitmap]::FromFile($sourcePath)
    try {
        # El símbolo oficial comienza después del texto "Doc".
        $cropX = 795
        $crop = New-Object System.Drawing.Rectangle(
            $cropX,
            0,
            ($source.Width - $cropX),
            $source.Height
        )
        $canvas = New-Object System.Drawing.Bitmap($Size, $Size)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($canvas)
            try {
                $graphics.Clear(
                    $(if ($OpaqueBackground) {
                        [System.Drawing.Color]::White
                    } else {
                        [System.Drawing.Color]::Transparent
                    })
                )
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

                if (-not $OpaqueBackground) {
                    $radius = [single]($Size * $CornerRadiusRatio)
                    $diameter = [single]($radius * 2)
                    $edge = [single]($Size - 1)
                    $background = New-Object System.Drawing.Drawing2D.GraphicsPath
                    try {
                        $background.AddArc(0, 0, $diameter, $diameter, 180, 90)
                        $background.AddArc($edge - $diameter, 0, $diameter, $diameter, 270, 90)
                        $background.AddArc($edge - $diameter, $edge - $diameter, $diameter, $diameter, 0, 90)
                        $background.AddArc(0, $edge - $diameter, $diameter, $diameter, 90, 90)
                        $background.CloseFigure()
                        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
                        try {
                            $graphics.FillPath($brush, $background)
                        } finally {
                            $brush.Dispose()
                        }
                        $graphics.SetClip($background)
                    } finally {
                        $background.Dispose()
                    }
                }

                $targetWidth = [int]($Size * $MarkWidthRatio)
                $targetHeight = [int]($targetWidth * $crop.Height / $crop.Width)
                $targetX = [int](($Size - $targetWidth) / 2)
                $targetY = [int](($Size - $targetHeight) / 2)
                $target = New-Object System.Drawing.Rectangle(
                    $targetX,
                    $targetY,
                    $targetWidth,
                    $targetHeight
                )
                $graphics.DrawImage($source, $target, $crop, [System.Drawing.GraphicsUnit]::Pixel)
            } finally {
                $graphics.Dispose()
            }
            $directory = Split-Path -Parent $Destination
            if (-not (Test-Path $directory)) {
                New-Item -ItemType Directory -Path $directory | Out-Null
            }
            $canvas.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $canvas.Dispose()
        }
    } finally {
        $source.Dispose()
    }
}

New-DocIaIcon -Size 1024 -Destination $masterPath

$androidIcons = @{
    'mipmap-mdpi\ic_launcher.png' = 48
    'mipmap-hdpi\ic_launcher.png' = 72
    'mipmap-xhdpi\ic_launcher.png' = 96
    'mipmap-xxhdpi\ic_launcher.png' = 144
    'mipmap-xxxhdpi\ic_launcher.png' = 192
}
foreach ($entry in $androidIcons.GetEnumerator()) {
    New-DocIaIcon -Size $entry.Value -Destination (Join-Path $ProjectRoot "android\app\src\main\res\$($entry.Key)")
}

$webIcons = @{
    'web\favicon.png' = 32
    'web\icons\Icon-192.png' = 192
    'web\icons\Icon-512.png' = 512
}
foreach ($entry in $webIcons.GetEnumerator()) {
    New-DocIaIcon -Size $entry.Value -Destination (Join-Path $ProjectRoot $entry.Key)
}
New-DocIaIcon -Size 192 -MarkWidthRatio 0.68 -OpaqueBackground -Destination (Join-Path $ProjectRoot 'web\icons\Icon-maskable-192.png')
New-DocIaIcon -Size 512 -MarkWidthRatio 0.68 -OpaqueBackground -Destination (Join-Path $ProjectRoot 'web\icons\Icon-maskable-512.png')

$iosManifestPath = Join-Path $ProjectRoot 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Contents.json'
$iosManifest = Get-Content $iosManifestPath -Raw | ConvertFrom-Json
foreach ($image in $iosManifest.images) {
    if (-not $image.filename) { continue }
    $points = [double]($image.size.Split('x')[0])
    $scale = [double]($image.scale.TrimEnd('x'))
    $pixels = [int]($points * $scale)
    $destination = Join-Path (Split-Path -Parent $iosManifestPath) $image.filename
    New-DocIaIcon -Size $pixels -OpaqueBackground -Destination $destination
}

Write-Output "Iconos Doc IA generados desde $sourcePath"
