param(
    [string]$GodotPath = "",
    [string]$OutputPath = "res://artifacts/measurements/blast_push_k0_k4.json"
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = if ([string]::IsNullOrWhiteSpace($env:GODOT)) {
        "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
    } else {
        $env:GODOT
    }
}
& $GodotPath --headless --path $repoPath `
    --log-file "res://.godot/blast-push-measurement.log" --fixed-fps 120 `
    res://tests/spike/BlastPushMeasurement.tscn -- "--output=$OutputPath"
if ($LASTEXITCODE -ne 0) {
    throw "Blast push measurement failed with exit code $LASTEXITCODE"
}
