# Windows renderer for the simple vector mark in web/icons/cafe.svg.
Add-Type -AssemblyName System.Drawing
$webRoot = Join-Path $PSScriptRoot '../web'
function Write-CafeIcon([int]$size, [string]$relativePath, [bool]$rounded = $true) {
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.ScaleTransform($size / 512.0, $size / 512.0)
    $background = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#253D32'))
    if ($rounded) {
        $outline = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $outline.AddArc(0, 0, 224, 224, 180, 90)
        $outline.AddArc(288, 0, 224, 224, 270, 90)
        $outline.AddArc(288, 288, 224, 224, 0, 90)
        $outline.AddArc(0, 288, 224, 224, 90, 90)
        $outline.CloseFigure()
        $graphics.FillPath($background, $outline)
        $outline.Dispose()
    } else {
        $graphics.FillRectangle($background, 0, 0, 512, 512)
    }
    $background.Dispose()
    $cream = [System.Drawing.ColorTranslator]::FromHtml('#E5EBDD')
    $pen = [System.Drawing.Pen]::new($cream, 18)
    $pen.StartCap = $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $brush = [System.Drawing.SolidBrush]::new($cream)
    $cup = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $cup.AddLine(154, 230, 336, 230)
    $cup.AddLine(336, 230, 336, 296)
    $cup.AddBezier(336, 296, 336, 340, 300, 368, 245, 368)
    $cup.AddBezier(245, 368, 190, 368, 154, 340, 154, 296)
    $cup.CloseFigure()
    $graphics.FillPath($brush, $cup)
    $graphics.DrawPath($pen, $cup)
    $handle = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $handle.AddLine(339, 240, 355, 240)
    $handle.AddBezier(355, 240, 408, 240, 399, 316, 339, 316)
    $graphics.DrawPath($pen, $handle)
    $graphics.DrawLine($pen, 145, 397, 352, 397)
    $graphics.DrawBezier($pen, 194, 180, 164, 150, 214, 140, 194, 112)
    $graphics.DrawBezier($pen, 256, 170, 226, 140, 276, 130, 256, 102)
    $graphics.DrawBezier($pen, 318, 180, 288, 150, 338, 140, 318, 112)
    $bitmap.Save((Join-Path $webRoot $relativePath), [System.Drawing.Imaging.ImageFormat]::Png)
    $handle.Dispose(); $cup.Dispose(); $brush.Dispose(); $pen.Dispose()
    $graphics.Dispose(); $bitmap.Dispose()
}
Write-CafeIcon 32 'favicon.png'
Write-CafeIcon 180 'icons/apple-touch-icon.png' $false
Write-CafeIcon 192 'icons/Icon-192.png'
Write-CafeIcon 512 'icons/Icon-512.png'
# These platforms apply their own icon mask and require an opaque background.
Write-CafeIcon 192 'icons/Icon-maskable-192.png' $false
Write-CafeIcon 512 'icons/Icon-maskable-512.png' $false
