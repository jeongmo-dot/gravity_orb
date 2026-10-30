param(
    [string]$GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe",
    [ValidateRange(1, 8)]
    [int]$Parallelism = 4
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot "run_gravity_turn_measurements.ps1") -GodotPath $GodotPath

foreach ($diagonalTime in @(0.1, 0.15, 0.25)) {
    $tag = $diagonalTime.ToString("0.00", [Globalization.CultureInfo]::InvariantCulture).Replace(".", "p")
    & (Join-Path $PSScriptRoot "run_jelly_physics_autoplay.ps1") `
        -GodotPath $GodotPath `
        -RepoPath $repoPath `
        -Label "gravity_turn_$tag" `
        -GravityTurnDiagonalTime $diagonalTime `
        -Parallelism $Parallelism
}

Write-Output "GRAVITY_TURN_CANDIDATES_COMPLETE cases=3 seeds_per_case=20"
