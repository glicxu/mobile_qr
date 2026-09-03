param(
    [string]$ScreenshotDirectory = "artifacts/screenshots",
    [string]$BackgroundPath = "artifacts/screenshots/dali-qr-store-background.png"
)

Add-Type -AssemblyName System.Drawing

$canvasWidth = 1080
$canvasHeight = 2160
$screenX = 155
$screenY = 366
$screenWidth = 770
$screenHeight = 1540
$scale = $screenWidth / 1080.0

function New-RoundedPath {
    param(
        [System.Drawing.RectangleF]$Rectangle,
        [float]$Radius
    )

    $diameter = $Radius * 2
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddArc($Rectangle.X, $Rectangle.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($Rectangle.Right - $diameter, $Rectangle.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($Rectangle.Right - $diameter, $Rectangle.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($Rectangle.X, $Rectangle.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-RoundedFill {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Brush]$Brush,
        [System.Drawing.RectangleF]$Rectangle,
        [float]$Radius
    )

    $path = New-RoundedPath -Rectangle $Rectangle -Radius $Radius
    $Graphics.FillPath($Brush, $path)
    $path.Dispose()
}

function Draw-RoundedOutline {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Pen]$Pen,
        [System.Drawing.RectangleF]$Rectangle,
        [float]$Radius
    )

    $path = New-RoundedPath -Rectangle $Rectangle -Radius $Radius
    $Graphics.DrawPath($Pen, $path)
    $path.Dispose()
}

function Convert-ScreenRectangle {
    param([int[]]$Rectangle)

    return [System.Drawing.RectangleF]::new(
        [float]($screenX + ($Rectangle[0] * $scale)),
        [float]($screenY + ($Rectangle[1] * $scale)),
        [float](($Rectangle[2] - $Rectangle[0]) * $scale),
        [float](($Rectangle[3] - $Rectangle[1]) * $scale)
    )
}

function Draw-Highlight {
    param(
        [System.Drawing.Graphics]$Graphics,
        [int[]]$SourceRectangle,
        [int]$Number
    )

    $target = Convert-ScreenRectangle -Rectangle $SourceRectangle
    $target.Inflate(8, 8)
    $glowPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(75, 245, 158, 11), 18)
    $linePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 245, 158, 11), 7)
    Draw-RoundedOutline -Graphics $Graphics -Pen $glowPen -Rectangle $target -Radius 22
    Draw-RoundedOutline -Graphics $Graphics -Pen $linePen -Rectangle $target -Radius 22
    $glowPen.Dispose()
    $linePen.Dispose()

    $badgeRectangle = [System.Drawing.RectangleF]::new($target.X - 21, $target.Y - 21, 54, 54)
    $badgeBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 245, 158, 11))
    $Graphics.FillEllipse($badgeBrush, $badgeRectangle)
    $badgeBrush.Dispose()

    $badgeFont = [System.Drawing.Font]::new("Segoe UI", 25, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $badgeTextBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $badgeFormat = [System.Drawing.StringFormat]::new()
    $badgeFormat.Alignment = [System.Drawing.StringAlignment]::Center
    $badgeFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
    $Graphics.DrawString($Number.ToString(), $badgeFont, $badgeTextBrush, $badgeRectangle, $badgeFormat)
    $badgeFormat.Dispose()
    $badgeTextBrush.Dispose()
    $badgeFont.Dispose()
}

function Draw-CalloutPill {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.RectangleF]$Rectangle,
        [int]$Number,
        [string]$Label
    )

    $pillBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(235, 255, 255, 255))
    Draw-RoundedFill -Graphics $Graphics -Brush $pillBrush -Rectangle $Rectangle -Radius 30
    $pillBrush.Dispose()

    $circle = [System.Drawing.RectangleF]::new($Rectangle.X + 17, $Rectangle.Y + 17, 52, 52)
    $numberBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 245, 158, 11))
    $Graphics.FillEllipse($numberBrush, $circle)
    $numberBrush.Dispose()

    $numberFont = [System.Drawing.Font]::new("Segoe UI", 24, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $labelFont = [System.Drawing.Font]::new("Segoe UI", 25, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $whiteBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $textBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 35, 47, 67))
    $center = [System.Drawing.StringFormat]::new()
    $center.Alignment = [System.Drawing.StringAlignment]::Center
    $center.LineAlignment = [System.Drawing.StringAlignment]::Center
    $Graphics.DrawString($Number.ToString(), $numberFont, $whiteBrush, $circle, $center)
    $labelRectangle = [System.Drawing.RectangleF]::new($Rectangle.X + 80, $Rectangle.Y, $Rectangle.Width - 92, $Rectangle.Height)
    $center.Alignment = [System.Drawing.StringAlignment]::Near
    $Graphics.DrawString($Label, $labelFont, $textBrush, $labelRectangle, $center)
    $center.Dispose()
    $textBrush.Dispose()
    $whiteBrush.Dispose()
    $labelFont.Dispose()
    $numberFont.Dispose()
}

$items = @(
    @{
        Input = "play-store-01-verification-code.png"
        Output = "play-store-framed-01-verification.png"
        Headline = "VERIFY BEFORE YOU TRUST"
        Subtitle = "Match the code printed inside and beside every QR."
        Highlights = @(@(185, 1390, 880, 1550), @(470, 1565, 960, 1720))
        Labels = @("Verification code", "Share QR image")
    },
    @{
        Input = "play-store-02-customized-qr.png"
        Output = "play-store-framed-02-customized.png"
        Headline = "MAKE EVERY QR YOURS"
        Subtitle = "Add a custom image, then save or share in one tap."
        Highlights = @(@(455, 790, 625, 955), @(470, 1565, 960, 1720))
        Labels = @("Custom image", "Share anywhere")
    },
    @{
        Input = "play-store-03-reuse-and-share.png"
        Output = "play-store-framed-03-reuse.png"
        Headline = "SAVE ONCE. REUSE ANYTIME."
        Subtitle = "Your private QR library stays ready to copy, edit, and open."
        Highlights = @(@(300, 1080, 780, 1230), @(330, 1970, 565, 2080))
        Labels = @("Copy QR image", "Edit saved QRs")
    }
)

$background = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $BackgroundPath))

foreach ($item in $items) {
    $inputPath = Join-Path $ScreenshotDirectory $item.Input
    $outputPath = Join-Path $ScreenshotDirectory $item.Output
    $screen = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $inputPath))
    $canvas = [System.Drawing.Bitmap]::new($canvasWidth, $canvasHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.DrawImage($background, 0, 0, $canvasWidth, $canvasHeight)

    $brandBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 73, 106, 165))
    $brandRectangle = [System.Drawing.RectangleF]::new(58, 42, 190, 56)
    Draw-RoundedFill -Graphics $graphics -Brush $brandBrush -Rectangle $brandRectangle -Radius 28
    $brandBrush.Dispose()

    $brandFont = [System.Drawing.Font]::new("Segoe UI", 24, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $headlineFont = [System.Drawing.Font]::new("Segoe UI", 53, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $subtitleFont = [System.Drawing.Font]::new("Segoe UI", 28, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $whiteBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $headlineBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 25, 35, 52))
    $subtitleBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 73, 83, 101))
    $centerFormat = [System.Drawing.StringFormat]::new()
    $centerFormat.Alignment = [System.Drawing.StringAlignment]::Center
    $centerFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
    $graphics.DrawString("DALI QR", $brandFont, $whiteBrush, $brandRectangle, $centerFormat)
    $graphics.DrawString($item.Headline, $headlineFont, $headlineBrush, [System.Drawing.RectangleF]::new(50, 112, 980, 72), $centerFormat)
    $graphics.DrawString($item.Subtitle, $subtitleFont, $subtitleBrush, [System.Drawing.RectangleF]::new(70, 194, 940, 88), $centerFormat)

    $shadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(45, 20, 36, 62))
    Draw-RoundedFill -Graphics $graphics -Brush $shadowBrush -Rectangle ([System.Drawing.RectangleF]::new(130, 350, 830, 1584)) -Radius 55
    $shadowBrush.Dispose()
    $frameBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 25, 31, 43))
    Draw-RoundedFill -Graphics $graphics -Brush $frameBrush -Rectangle ([System.Drawing.RectangleF]::new(139, 350, 802, 1572)) -Radius 48
    $frameBrush.Dispose()

    $screenRectangle = [System.Drawing.RectangleF]::new($screenX, $screenY, $screenWidth, $screenHeight)
    $screenPath = New-RoundedPath -Rectangle $screenRectangle -Radius 34
    $oldClip = $graphics.Clip
    $graphics.SetClip($screenPath)
    $graphics.DrawImage($screen, $screenRectangle)
    $graphics.Clip = $oldClip
    $oldClip.Dispose()
    $screenPath.Dispose()

    for ($index = 0; $index -lt $item.Highlights.Count; $index++) {
        Draw-Highlight -Graphics $graphics -SourceRectangle $item.Highlights[$index] -Number ($index + 1)
    }

    Draw-CalloutPill -Graphics $graphics -Rectangle ([System.Drawing.RectangleF]::new(42, 1980, 486, 90)) -Number 1 -Label $item.Labels[0]
    Draw-CalloutPill -Graphics $graphics -Rectangle ([System.Drawing.RectangleF]::new(552, 1980, 486, 90)) -Number 2 -Label $item.Labels[1]

    $centerFormat.Dispose()
    $subtitleBrush.Dispose()
    $headlineBrush.Dispose()
    $whiteBrush.Dispose()
    $subtitleFont.Dispose()
    $headlineFont.Dispose()
    $brandFont.Dispose()
    $graphics.Dispose()
    $screen.Dispose()
    $canvas.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.Dispose()
}

$background.Dispose()
