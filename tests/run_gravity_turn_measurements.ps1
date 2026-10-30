param(
    [string]$GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$culture = [Globalization.CultureInfo]::InvariantCulture

foreach ($diagonalTime in @(0.0, 0.1, 0.15, 0.25)) {
    $tag = $diagonalTime.ToString("0.00", $culture).Replace(".", "p")
    $outputPath = Join-Path $repoPath "artifacts\gravity_turn_$tag.json"
    Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
    & $GodotPath --headless --path $repoPath --fixed-fps 120 --audio-driver Dummy `
        res://tests/spike/GravityTurnMeasurement.tscn -- `
        --diagonal-time=$($diagonalTime.ToString($culture)) `
        --output=res://artifacts/gravity_turn_$tag.json
    if ($LASTEXITCODE -ne 0) {
        throw "Gravity turn measurement '$diagonalTime' failed with exit code $LASTEXITCODE"
    }
    if (-not (Test-Path -LiteralPath $outputPath)) {
        throw "Gravity turn measurement '$diagonalTime' did not create $outputPath"
    }
}

Write-Output "GRAVITY_TURN_MEASUREMENTS_COMPLETE cases=4"
