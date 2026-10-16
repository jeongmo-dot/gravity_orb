param(
    [string]$GodotPath = "",
    [ValidateRange(1, 10000)]
    [int]$SeedCount = 100,
    [ValidateRange(1, 10000)]
    [int]$TurnCap = 250
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

& $GodotPath --headless --fixed-fps 120 --path $repoPath -s res://tests/tools/run_slime_bot_measurement.gd -- "--seed-count=$SeedCount" "--turn-cap=$TurnCap"
exit $LASTEXITCODE
