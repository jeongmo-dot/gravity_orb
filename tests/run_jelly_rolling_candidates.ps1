param(
    [string]$GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe",
    [ValidateRange(1, 8)]
    [int]$Parallelism = 4
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot "run_jelly_rolling_measurement.ps1") -GodotPath $GodotPath

foreach ($angularDamp in @(5.0, 15.0, 30.0)) {
    $tag = [int]$angularDamp
    & (Join-Path $PSScriptRoot "run_jelly_physics_autoplay.ps1") `
        -GodotPath $GodotPath `
        -RepoPath $repoPath `
        -Label "rolling_damp_$tag" `
        -Friction 0.3 `
        -AngularDamp $angularDamp `
        -Parallelism $Parallelism
}

Write-Output "JELLY_ROLLING_CANDIDATES_COMPLETE cases=3 seeds_per_case=20"
