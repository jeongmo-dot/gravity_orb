param(
    [string]$GodotPath = "",
    [ValidateRange(0, [int]::MaxValue)]
    [int]$FixedFps = 120,
    [string]$GeneralSuite = "general",
    [string]$LongSuite = "long",
    [string]$PerfSuite = "perf"
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

$godotArguments = @("--headless")
if ($FixedFps -gt 0) {
    $godotArguments += @("--fixed-fps", $FixedFps.ToString())
}
$godotArguments += @(
    "--path", $repoPath,
    "-s", "res://tests/run_tests.gd"
)
Write-Output ("TEST_WRAPPER_START fixed_fps={0}" -f $FixedFps)

$generalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& $GodotPath @godotArguments -- "--test-suite=$GeneralSuite"
$generalExit = $LASTEXITCODE
$generalStopwatch.Stop()
Write-Output (
    "TEST_SUITE_RESULT name=general suite={0} exit={1} duration_seconds={2:F3}" -f `
        $GeneralSuite,
        $generalExit,
        $generalStopwatch.Elapsed.TotalSeconds
)

$longStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& $GodotPath @godotArguments -- "--test-suite=$LongSuite"
$longExit = $LASTEXITCODE
$longStopwatch.Stop()
Write-Output (
    "TEST_SUITE_RESULT name=long suite={0} exit={1} duration_seconds={2:F3}" -f `
        $LongSuite,
        $longExit,
        $longStopwatch.Elapsed.TotalSeconds
)

$perfStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& $GodotPath @godotArguments -- "--test-suite=$PerfSuite"
$perfExit = $LASTEXITCODE
$perfStopwatch.Stop()
Write-Output (
    "TEST_SUITE_RESULT name=perf suite={0} exit={1} duration_seconds={2:F3}" -f `
        $PerfSuite,
        $perfExit,
        $perfStopwatch.Elapsed.TotalSeconds
)

$wrapperExit = if (
    $generalExit -eq 0 -and $longExit -eq 0 -and $perfExit -eq 0
) { 0 } else { 1 }
Write-Output (
    "TEST_WRAPPER_RESULT fixed_fps={0} general_exit={1} long_exit={2} perf_exit={3} exit={4} total_seconds={5:F3}" -f `
        $FixedFps,
        $generalExit,
        $longExit,
        $perfExit,
        $wrapperExit,
        (
            $generalStopwatch.Elapsed.TotalSeconds +
            $longStopwatch.Elapsed.TotalSeconds +
            $perfStopwatch.Elapsed.TotalSeconds
        )
)
exit $wrapperExit
