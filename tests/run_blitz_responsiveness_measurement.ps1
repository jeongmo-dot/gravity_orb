param(
    [string]$GodotPath = "",
    [string]$Label = "before",
    [double]$GravityStrength = 0.0
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $repoPath "artifacts\measurements"
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
        $GodotPath = $env:GODOT
    } elseif (Test-Path -LiteralPath "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe") {
        $GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe"
    } else {
        $GodotPath = "godot"
    }
}

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$seedReports = @()
foreach ($seed in 101..104) {
    $seedFileName = "blitz_responsiveness_{0}_{1}.json" -f $Label, $seed
    $seedPath = Join-Path $outputDirectory $seedFileName
    $arguments = @(
        "--path", $repoPath,
        "--windowed",
        "--resolution", "540x960",
        "--audio-driver", "Dummy",
        "res://tests/spike/RunBlitzResponsivenessMeasurement.tscn",
        "--",
        ("--output=res://artifacts/measurements/{0}" -f $seedFileName),
        ("--seed={0}" -f $seed)
    )
    if ($GravityStrength -gt 0.0) {
        $arguments += ("--gravity-strength={0}" -f $GravityStrength)
    }
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $GodotPath @arguments
        $measurementExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($measurementExit -ne 0) {
        throw "BLITZ responsiveness seed $seed failed with exit code $measurementExit"
    }
    if (-not (Test-Path -LiteralPath $seedPath)) {
        throw "BLITZ responsiveness seed $seed did not create $seedPath"
    }
    $seedReports += Get-Content -LiteralPath $seedPath -Raw | ConvertFrom-Json
}

function Get-Percentile([double[]]$Values, [double]$Percentile) {
    if ($Values.Count -eq 0) {
        return 0.0
    }
    $sorted = $Values | Sort-Object
    $index = [Math]::Ceiling(($Percentile / 100.0) * $sorted.Count) - 1
    $index = [Math]::Max(0, [Math]::Min($index, $sorted.Count - 1))
    return [double]$sorted[$index]
}

$frames = [System.Collections.Generic.List[double]]::new()
$inputLatencies = [System.Collections.Generic.List[double]]::new()
$spawnLatencies = [System.Collections.Generic.List[double]]::new()
$blastFrames = [System.Collections.Generic.List[double]]::new()
$largeBatchFrames = [System.Collections.Generic.List[double]]::new()
foreach ($report in $seedReports) {
    foreach ($value in $report.frame_samples_ms) { $frames.Add([double]$value) }
    foreach ($value in $report.input_latency_ms) { $inputLatencies.Add([double]$value) }
    foreach ($value in $report.spawn_latency_ms) { $spawnLatencies.Add([double]$value) }
    if ([double]$report.first_blast_frame_ms -ge 0.0) {
        $blastFrames.Add([double]$report.first_blast_frame_ms)
    }
    if ([double]$report.first_large_batch_frame_ms -ge 0.0) {
        $largeBatchFrames.Add([double]$report.first_large_batch_frame_ms)
    }
}

$aggregate = [ordered]@{
    label = $Label
    gravity_strength = [double]$seedReports[0].gravity_strength
    seeds = @(101, 102, 103, 104)
    renderer = [string]$seedReports[0].renderer
    frame_count = $frames.Count
    frame_p50_ms = Get-Percentile $frames.ToArray() 50
    frame_p95_ms = Get-Percentile $frames.ToArray() 95
    frame_p99_ms = Get-Percentile $frames.ToArray() 99
    frame_max_ms = if ($frames.Count -gt 0) { [double](($frames | Measure-Object -Maximum).Maximum) } else { 0.0 }
    frames_over_16_7_ms = @($frames | Where-Object { $_ -gt 16.7 }).Count
    frames_over_33_3_ms = @($frames | Where-Object { $_ -gt 33.3 }).Count
    input_accept_p50_ms = Get-Percentile $inputLatencies.ToArray() 50
    input_accept_p95_ms = Get-Percentile $inputLatencies.ToArray() 95
    input_accept_max_ms = if ($inputLatencies.Count -gt 0) { [double](($inputLatencies | Measure-Object -Maximum).Maximum) } else { 0.0 }
    accept_spawn_p50_ms = Get-Percentile $spawnLatencies.ToArray() 50
    accept_spawn_p95_ms = Get-Percentile $spawnLatencies.ToArray() 95
    accept_spawn_max_ms = if ($spawnLatencies.Count -gt 0) { [double](($spawnLatencies | Measure-Object -Maximum).Maximum) } else { 0.0 }
    requested_inputs = [int](($seedReports | Measure-Object -Property requested_inputs -Sum).Sum)
    accepted_inputs = [int](($seedReports | Measure-Object -Property accepted_inputs -Sum).Sum)
    dropped_inputs = [int](($seedReports | Measure-Object -Property dropped_inputs -Sum).Sum)
    first_blast_frame_ms = @($blastFrames)
    first_large_batch_frame_ms = @($largeBatchFrames)
    max_spawn_batch = [int](($seedReports | Measure-Object -Property max_spawn_batch -Maximum).Maximum)
    per_seed = $seedReports
}
$aggregatePath = Join-Path $outputDirectory ("blitz_responsiveness_{0}.json" -f $Label)
$aggregate | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $aggregatePath -Encoding utf8
$consoleSummary = [ordered]@{}
foreach ($entry in $aggregate.GetEnumerator()) {
    if ($entry.Key -ne "per_seed") {
        $consoleSummary[$entry.Key] = $entry.Value
    }
}
Write-Output ("BLITZ_RESPONSIVENESS_RESULT {0}" -f ($consoleSummary | ConvertTo-Json -Compress -Depth 4))
Write-Output ("BLITZ_RESPONSIVENESS_SUITE exit=0 report={0}" -f $aggregatePath)
