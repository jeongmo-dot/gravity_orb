param(
    [string]$GodotPath = "",
    [string]$PrototypePath = "C:\work\GravityOrb-main\GravityOrb\prototype"
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
        $GodotPath = $env:GODOT
    } else {
        $GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
    }
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}
if (-not (Test-Path -LiteralPath (Join-Path $PrototypePath "main.gd") -PathType Leaf)) {
    throw "Read-only Gravity Slime prototype not found: $PrototypePath"
}
$candidatePath = Join-Path $repoPath "artifacts\screens\540x960\49_slime_states.png"
if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
    throw "Run tests\capture_screens.ps1 first: $candidatePath"
}

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$workPath = Join-Path $tempRoot ("gravity-slime-capture-" + [guid]::NewGuid().ToString("N"))
$resolvedWorkPath = [System.IO.Path]::GetFullPath($workPath)
if (-not $resolvedWorkPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a capture workspace outside the system temp directory."
}
$outputDirectory = Join-Path $repoPath "artifacts\screens"
$originalPath = Join-Path $outputDirectory "49_slime_original.png"
$comparisonPath = Join-Path $outputDirectory "49_slime_original_compare.png"

try {
    New-Item -ItemType Directory -Path $resolvedWorkPath | Out-Null
    Copy-Item -Path (Join-Path $PrototypePath "*") -Destination $resolvedWorkPath -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "slime_original_capture_driver.gd") -Destination (Join-Path $resolvedWorkPath "capture_driver.gd") -Force
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "slime_original_capture_game.gd") -Destination (Join-Path $resolvedWorkPath "capture_game.gd") -Force
    & $GodotPath --path $resolvedWorkPath --windowed --resolution 640x920 --audio-driver Dummy -s res://capture_driver.gd -- "--output=$originalPath"
    if ($LASTEXITCODE -ne 0) {
        throw "Original capture runner failed with exit $LASTEXITCODE"
    }

    Add-Type -AssemblyName System.Drawing
    $original = [System.Drawing.Image]::FromFile($originalPath)
    $candidate = [System.Drawing.Image]::FromFile($candidatePath)
    try {
        $canvas = New-Object System.Drawing.Bitmap 1180, 960
        $graphics = [System.Drawing.Graphics]::FromImage($canvas)
        try {
            $graphics.Clear([System.Drawing.Color]::FromArgb(6, 9, 19))
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($original, 0, 20, 640, 920)
            $graphics.DrawImage($candidate, 640, 0, 540, 960)
            $canvas.Save($comparisonPath, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $graphics.Dispose()
            $canvas.Dispose()
        }
    } finally {
        $original.Dispose()
        $candidate.Dispose()
    }
    Write-Output "SLIME_ORIGINAL_COMPARISON_RESULT file=$comparisonPath original_read_only=true"
} finally {
    if (Test-Path -LiteralPath $resolvedWorkPath) {
        $verifiedPath = [System.IO.Path]::GetFullPath($resolvedWorkPath)
        if ($verifiedPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and $verifiedPath -ne $tempRoot) {
            Remove-Item -LiteralPath $verifiedPath -Recurse -Force
        }
    }
}
