Set-StrictMode -Version Latest

function ConvertTo-EvidenceLines {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [int]$MaximumCharacters = 112
    )

    $clean = [regex]::Replace($Text, "$([char]27)\[[0-?]*[ -/]*[@-~]", "")
    $clean = $clean.Replace("`r", "")
    $result = [System.Collections.Generic.List[string]]::new()

    foreach ($sourceLine in ($clean -split "`n")) {
        $line = $sourceLine.TrimEnd()
        if ($line.Length -eq 0) {
            $result.Add("")
            continue
        }

        while ($line.Length -gt $MaximumCharacters) {
            $breakAt = $line.LastIndexOf(" ", $MaximumCharacters)
            if ($breakAt -lt 40) {
                $breakAt = $MaximumCharacters
            }
            $result.Add($line.Substring(0, $breakAt).TrimEnd())
            $line = $line.Substring($breakAt).TrimStart()
        }
        $result.Add($line)
    }

    return $result.ToArray()
}

function Save-TerminalEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [Parameter(Mandatory = $true)]
        [string]$OutputText,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    Add-Type -AssemblyName System.Drawing

    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    $installedFonts = [System.Drawing.Text.InstalledFontCollection]::new()
    $fontNames = @($installedFonts.Families | ForEach-Object Name)
    $fontName = if ("Cascadia Mono" -in $fontNames) { "Cascadia Mono" } else { "Consolas" }

    $bodyLines = @(ConvertTo-EvidenceLines -Text $OutputText)
    $commandLines = @(ConvertTo-EvidenceLines -Text "> $Command")
    $allLines = @($commandLines) + @(">") + $bodyLines

    $width = 1800
    $lineHeight = 31
    $headerHeight = 82
    $topPadding = 28
    $bottomPadding = 58
    $height = [Math]::Max(520, $headerHeight + $topPadding + ($allLines.Count * $lineHeight) + $bottomPadding)

    $bitmap = [System.Drawing.Bitmap]::new($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $graphics.Clear([System.Drawing.Color]::FromArgb(13, 17, 23))

    $headerBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(22, 27, 34))
    $graphics.FillRectangle($headerBrush, 0, 0, $width, $headerHeight)

    $graphics.FillEllipse([System.Drawing.Brushes]::IndianRed, 28, 28, 22, 22)
    $graphics.FillEllipse([System.Drawing.Brushes]::Goldenrod, 62, 28, 22, 22)
    $graphics.FillEllipse([System.Drawing.Brushes]::MediumSeaGreen, 96, 28, 22, 22)

    $titleFont = [System.Drawing.Font]::new("Segoe UI Semibold", 25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $bodyFont = [System.Drawing.Font]::new($fontName, 22, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $footerFont = [System.Drawing.Font]::new("Segoe UI", 17, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $titleBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(230, 237, 243))
    $bodyBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(201, 209, 217))
    $commandBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(126, 231, 135))
    $footerBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(139, 148, 158))

    $graphics.DrawString($Title, $titleFont, $titleBrush, 145, 24)

    $y = $headerHeight + $topPadding
    for ($index = 0; $index -lt $allLines.Count; $index++) {
        $brush = if ($index -lt $commandLines.Count) { $commandBrush } else { $bodyBrush }
        $graphics.DrawString($allLines[$index], $bodyFont, $brush, 38, $y)
        $y += $lineHeight
    }

    $footer = "KX-DAY26 | Captured from actual command output | API keys hidden"
    $graphics.DrawString($footer, $footerFont, $footerBrush, 38, $height - 38)

    try {
        $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $footerBrush.Dispose()
        $commandBrush.Dispose()
        $bodyBrush.Dispose()
        $titleBrush.Dispose()
        $footerFont.Dispose()
        $bodyFont.Dispose()
        $titleFont.Dispose()
        $headerBrush.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
        $installedFonts.Dispose()
    }
}
