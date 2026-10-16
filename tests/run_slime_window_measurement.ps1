param(
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $repoPath "artifacts\measurements"
$reportPath = Join-Path $outputDirectory "slime_window.json"
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
    "res://tests/spike/SlimeWindowMeasurement.tscn",
    "--",
    "--output=res://artifacts/measurements/slime_window.json"
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
    throw "Slime window measurement failed with exit code $measurementExit"
}
if (-not (Test-Path -LiteralPath $reportPath)) {
    throw "Slime window measurement did not create $reportPath"
}
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
$frames = @($report.frame_samples_ms | ForEach-Object { [double]$_ } | Sort-Object)
if ($frames.Count -eq 0) {
    throw "Slime window measurement recorded no frames"
}
$p99Index = [Math]::Max(0, [Math]::Min([Math]::Ceiling(0.99 * $frames.Count) - 1, $frames.Count - 1))
$p99 = [double]$frames[$p99Index]
$maximum = [double](($frames | Measure-Object -Maximum).Maximum)
$over16 = @($frames | Where-Object { $_ -gt 16.7 }).Count
$over33 = @($frames | Where-Object { $_ -gt 33.3 }).Count
$drawCalls = @($report.draw_call_samples | ForEach-Object { [int]$_ })
$drawCallMax = if ($drawCalls.Count -gt 0) { [int](($drawCalls | Measure-Object -Maximum).Maximum) } else { 0 }
if ([int]$report.vsync_mode -ne 0) {
    throw "Slime window measurement expected vsync disabled, got $($report.vsync_mode)"
}
if ([int]$report.slime_count -ne 40) {
    throw "Slime window measurement expected 40 slimes, got $($report.slime_count)"
}
if ($p99 -gt 16.7) {
    throw ("Slime window frame p99 exceeds 16.7 ms: {0:N3} ms" -f $p99)
}
Write-Output (
    "SLIME_WINDOW_RESULT exit=0 slimes={0} samples={1} p99_ms={2:N3} max_ms={3:N3} over_16_7={4} over_33_3={5} draw_calls_max={6} renderer={7}" -f `
        $report.slime_count, $frames.Count, $p99, $maximum, $over16, $over33, $drawCallMax, $report.renderer
)
