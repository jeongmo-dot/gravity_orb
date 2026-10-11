param(
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $repoPath "artifacts\measurements"
$reportPath = Join-Path $outputDirectory "start_screen.json"
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
    "--path", $repoPath,
    "--windowed",
    "--disable-vsync",
    "--resolution", "540x960",
    "--audio-driver", "Dummy",
    "res://tests/spike/StartScreenMeasurement.tscn",
    "--",
    "--output=res://artifacts/measurements/start_screen.json"
)
$previousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    & $GodotPath @arguments
    $measurementExit = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
if ($measurementExit -ne 0) {
    throw "Start-screen measurement failed with exit code $measurementExit"
}
if (-not (Test-Path -LiteralPath $reportPath)) {
    throw "Start-screen measurement did not create $reportPath"
}
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
$frames = @($report.frame_samples_ms | ForEach-Object { [double]$_ } | Sort-Object)
if ($frames.Count -eq 0) {
    throw "Start-screen measurement recorded no frames"
}
$p99Index = [Math]::Max(0, [Math]::Min(
    [Math]::Ceiling(0.99 * $frames.Count) - 1,
    $frames.Count - 1
))
$p99 = [double]$frames[$p99Index]
$maximum = [double](($frames | Measure-Object -Maximum).Maximum)
if ([int]$report.vsync_mode -ne 0) {
    throw "Start-screen measurement expected vsync disabled, got $($report.vsync_mode)"
}
if ($p99 -gt 16.7) {
    throw ("Start-screen frame p99 exceeds 16.7 ms: {0:N3} ms" -f $p99)
}
Write-Output (
    "START_SCREEN_MEASUREMENT_RESULT exit=0 duration_seconds={0} samples={1} p99_ms={2:N3} max_ms={3:N3} renderer={4}" -f `
        $report.duration_seconds,
        $frames.Count,
        $p99,
        $maximum,
        $report.renderer
)
