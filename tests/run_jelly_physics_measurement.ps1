param(
    [string]$GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
foreach ($profile in @("before", "after")) {
    $output = "res://artifacts/jelly_physics_$profile.json"
    $outputPath = Join-Path $repoPath "artifacts\jelly_physics_$profile.json"
    Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
    & $GodotPath --headless --path $repoPath --fixed-fps 120 --audio-driver Dummy `
        res://tests/spike/JellyPhysicsMeasurement.tscn -- `
        --profile=$profile --output=$output
    if ($LASTEXITCODE -ne 0) {
        throw "JELLY physics measurement '$profile' failed with exit code $LASTEXITCODE"
    }
    if (-not (Test-Path -LiteralPath $outputPath)) {
        throw "JELLY physics measurement '$profile' did not create $outputPath"
    }
}

Write-Output "JELLY_PHYSICS_MEASUREMENT_COMPLETE"
