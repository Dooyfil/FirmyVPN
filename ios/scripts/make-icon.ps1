# Draws AppIcon.png 1024x1024 for FirmyVPN: dark aurora background, neon glow,
# minimalist shield with the letter F. Run:
#   powershell -ExecutionPolicy Bypass -File ios/scripts/make-icon.ps1
Add-Type -AssemblyName System.Drawing

$out = Join-Path $PSScriptRoot "..\Resources\Assets.xcassets\AppIcon.appiconset\AppIcon.png"
$w = 1024; $h = 1024
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::FromArgb(255, 4, 6, 16))

$rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)

# 1. Diagonal gradient: deep navy -> violet
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(255, 5, 8, 24),
    [System.Drawing.Color]::FromArgb(255, 24, 10, 58),
    48)
$g.FillRectangle($bg, $rect)

# 2. Cyan aurora glow top-right
$path1 = New-Object System.Drawing.Drawing2D.GraphicsPath
$path1.AddEllipse(300, -160, 900, 900)
$pg1 = New-Object System.Drawing.Drawing2D.PathGradientBrush($path1)
$pg1.CenterColor = [System.Drawing.Color]::FromArgb(130, 34, 211, 238)
$pg1.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 34, 211, 238))
$g.FillPath($pg1, $path1)

# 3. Violet glow bottom-left
$path2 = New-Object System.Drawing.Drawing2D.GraphicsPath
$path2.AddEllipse(-320, 380, 900, 900)
$pg2 = New-Object System.Drawing.Drawing2D.PathGradientBrush($path2)
$pg2.CenterColor = [System.Drawing.Color]::FromArgb(110, 166, 140, 250)
$pg2.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 166, 140, 250))
$g.FillPath($pg2, $path2)

# 4. Pink glow bottom-right
$path3 = New-Object System.Drawing.Drawing2D.GraphicsPath
$path3.AddEllipse(520, 560, 760, 760)
$pg3 = New-Object System.Drawing.Drawing2D.PathGradientBrush($path3)
$pg3.CenterColor = [System.Drawing.Color]::FromArgb(80, 245, 116, 181)
$pg3.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 245, 116, 181))
$g.FillPath($pg3, $path3)

# 5. Shield: glow underlay + main gradient
function New-ShieldPath([float]$scale, [float]$dx, [float]$dy) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cx = 512.0; $cy = 540.0
    $pts = @(
        @(-168, -278), @(168, -278), @(168, -60), @(160, 60),
        @(112, 176), @(0, 256), @(-112, 176), @(-160, 60), @(-168, -60)
    )
    $scaled = @()
    foreach ($pt in $pts) {
        $scaled += New-Object System.Drawing.PointF(
            [float]($cx + $pt[0] * $scale + $dx),
            [float]($cy + $pt[1] * $scale + $dy))
    }
    $p.AddPolygon($scaled)
    return $p
}

$glow = New-ShieldPath 1.10 0 0
$pgGlow = New-Object System.Drawing.Drawing2D.PathGradientBrush($glow)
$pgGlow.CenterColor = [System.Drawing.Color]::FromArgb(70, 34, 211, 238)
$pgGlow.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 34, 211, 238))
$g.FillPath($pgGlow, $glow)

$shield = New-ShieldPath 1.0 0 0
$srect = New-Object System.Drawing.Rectangle(344, 262, 336, 556)
$sg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $srect,
    [System.Drawing.Color]::FromArgb(255, 255, 255, 255),
    [System.Drawing.Color]::FromArgb(255, 96, 226, 245),
    70)
$g.FillPath($sg, $shield)
$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(160, 210, 250, 255), 5)
$g.DrawPath($pen, $shield)

# 6. Letter F
$font = New-Object System.Drawing.Font("Segoe UI", 300, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = [System.Drawing.StringAlignment]::Center
$fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
$shadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60, 0, 0, 0))
$g.DrawString("F", $font, $shadow, (New-Object System.Drawing.RectangleF(316, 274, 400, 480)), $fmt)
$dark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 8, 12, 30))
$g.DrawString("F", $font, $dark, (New-Object System.Drawing.RectangleF(312, 270, 400, 480)), $fmt)

$dir = Split-Path $out -Parent
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host ("Done: " + $out)
