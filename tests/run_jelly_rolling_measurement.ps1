param(
    [string]$GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$cases = @(
    [ordered]@{ Name = "locked"; AngularDamp = 1.0; RotationLock = "on" },
    [ordered]@{ Name = "damp_5"; AngularDamp = 5.0; RotationLock = "off" },
    [ordered]@{ Name = "damp_15"; AngularDamp = 15.0; RotationLock = "off" },
    [ordered]@{ Name = "damp_30"; AngularDamp = 30.0; RotationLock = "off" }
)

foreach ($case in $cases) {
    $output = "res://artifacts/jelly_rolling_$($case.Name).json"
    $outputPath = Join-Path $repoPath "artifacts\jelly_rolling_$($case.Name).json"
    Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
    & $GodotPath --headless --path $repoPath --fixed-fps 120 --audio-driver Dummy `
        res://tests/spike/JellyPhysicsMeasurement.tscn -- `
        --friction=0.3 `
        --angular-damp=$($case.AngularDamp) `
        --rotation-lock=$($case.RotationLock) `
        --output=$output
    if ($LASTEXITCODE -ne 0) {
        throw "JELLY rolling measurement '$($case.Name)' failed with exit code $LASTEXITCODE"
    }
    if (-not (Test-Path -LiteralPath $outputPath)) {
        throw "JELLY rolling measurement '$($case.Name)' did not create $outputPath"
    }
}

Write-Output "JELLY_ROLLING_MEASUREMENT_COMPLETE cases=4"
