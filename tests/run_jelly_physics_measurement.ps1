param(
    [string]$GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$culture = [Globalization.CultureInfo]::InvariantCulture
foreach ($friction in @(0.15, 0.3, 0.45, 0.6)) {
    $tag = $friction.ToString("0.00", $culture).Replace(".", "p")
    $output = "res://artifacts/jelly_friction_$tag.json"
    $outputPath = Join-Path $repoPath "artifacts\jelly_friction_$tag.json"
    Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
    & $GodotPath --headless --path $repoPath --fixed-fps 120 --audio-driver Dummy `
        res://tests/spike/JellyPhysicsMeasurement.tscn -- `
        --friction=$($friction.ToString($culture)) --output=$output
    if ($LASTEXITCODE -ne 0) {
        throw "JELLY friction measurement '$friction' failed with exit code $LASTEXITCODE"
    }
    if (-not (Test-Path -LiteralPath $outputPath)) {
        throw "JELLY friction measurement '$friction' did not create $outputPath"
    }
}

Write-Output "JELLY_FRICTION_MEASUREMENT_COMPLETE cases=4"
