param(
    [string]$GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe",
    [ValidateRange(1, 8)]
    [int]$Parallelism = 4
)

$ErrorActionPreference = "Stop"
$culture = [Globalization.CultureInfo]::InvariantCulture
$repoPath = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot "run_jelly_physics_measurement.ps1") -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) {
    throw "JELLY friction physical measurement failed with exit code $LASTEXITCODE"
}

foreach ($friction in @(0.15, 0.3, 0.45, 0.6)) {
    $tag = $friction.ToString("0.00", $culture).Replace(".", "p")
    & (Join-Path $PSScriptRoot "run_jelly_physics_autoplay.ps1") `
        -GodotPath $GodotPath `
        -RepoPath $repoPath `
        -Label "friction_$tag" `
        -Friction $friction `
        -Parallelism $Parallelism
    if ($LASTEXITCODE -ne 0) {
        throw "JELLY friction autoplay '$friction' failed with exit code $LASTEXITCODE"
    }
}

Write-Output "JELLY_FRICTION_SWEEP_COMPLETE cases=4 seeds_per_case=20"
