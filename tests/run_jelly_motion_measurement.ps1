param(
    [string]$GodotPath = "",
    [string]$Label = "current"
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $repoPath "artifacts\measurements"
$reportPath = Join-Path $outputDirectory "jelly_motion_$Label.json"
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
        $GodotPath = $env:GODOT
    } elseif (Test-Path -LiteralPath "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe") {
        $GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
    } else {
        $GodotPath = "godot"
    }
}

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$arguments = @(
    "--headless",
    "--fixed-fps", "120",
    "--path", $repoPath,
    "res://tests/spike/JellyMotionMeasurement.tscn",
    "--",
    "--output=res://artifacts/measurements/jelly_motion_$Label.json"
)
& $GodotPath @arguments
$measurementExit = $LASTEXITCODE
if ($measurementExit -ne 0) {
    throw "JELLY motion measurement failed with exit code $measurementExit"
}
if (-not (Test-Path -LiteralPath $reportPath)) {
    throw "JELLY motion measurement did not create $reportPath"
}
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
Write-Output (
    "JELLY_MOTION_RESULT label={0} exit=0 orbs={1} turns={2} touching_pairs={3} impact_starts_per_second={4:N6} rest_scale_change_ratio={5:N6} motion_scale_change_ratio={6:N6} motion_rotation_change_radians={7:N6} breath_toggle_ratio={8:N6}" -f `
        $Label, $report.jelly_count, $report.settle_turn_count, $report.touching_pairs, `
        $report.impact_starts_per_second, $report.rest_max_scale_change_ratio, `
        $report.motion_max_scale_change_ratio, $report.motion_max_rotation_change_radians, `
        $report.max_breath_toggle_change_ratio
)
