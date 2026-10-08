param(
    [string]$GodotPath = "",
    [string]$GeneralSuite = "general",
    [string]$LongSuite = "long"
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
        $GodotPath = $env:GODOT
    } elseif (Test-Path -LiteralPath "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe") {
        $GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe"
    } else {
        $GodotPath = "godot"
    }
}

$generalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& $GodotPath `
    --headless `
    --path $repoPath `
    -s res://tests/run_tests.gd `
    -- `
    "--test-suite=$GeneralSuite"
$generalExit = $LASTEXITCODE
$generalStopwatch.Stop()
Write-Output (
    "TEST_SUITE_RESULT name=general suite={0} exit={1} duration_seconds={2:F3}" -f `
        $GeneralSuite,
        $generalExit,
        $generalStopwatch.Elapsed.TotalSeconds
)

$longStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& $GodotPath `
    --headless `
    --path $repoPath `
    -s res://tests/run_tests.gd `
    -- `
    "--test-suite=$LongSuite"
$longExit = $LASTEXITCODE
$longStopwatch.Stop()
Write-Output (
    "TEST_SUITE_RESULT name=long suite={0} exit={1} duration_seconds={2:F3}" -f `
        $LongSuite,
        $longExit,
        $longStopwatch.Elapsed.TotalSeconds
)

$wrapperExit = if ($generalExit -eq 0 -and $longExit -eq 0) { 0 } else { 1 }
Write-Output (
    "TEST_WRAPPER_RESULT general_exit={0} long_exit={1} exit={2} total_seconds={3:F3}" -f `
        $generalExit,
        $longExit,
        $wrapperExit,
        ($generalStopwatch.Elapsed.TotalSeconds + $longStopwatch.Elapsed.TotalSeconds)
)
exit $wrapperExit
