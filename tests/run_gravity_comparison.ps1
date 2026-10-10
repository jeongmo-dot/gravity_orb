param(
    [string]$GodotPath = "",
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $repoPath "artifacts\measurements"
$gravities = @(1800, 3600)
$seeds = "101,102,103,104,105,106,107,108,109,110,111,112"
$cycle3DWallLimitPx = 20.0
$cycle3DPairLimitPx = 22.0
$compatibility2DWallLimitPx = 14.0
$continuousWallLimitPx = 34.0
$continuousPairLimitPx = 68.0
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

function Invoke-GodotMeasurement([string[]]$Arguments, [string]$Name) {
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $GodotPath @Arguments
        $measurementExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($measurementExit -ne 0) {
        throw "$Name failed with exit code $measurementExit"
    }
}

if (-not $AggregateOnly) {
    foreach ($gravity in $gravities) {
        $turnOutput = "res://artifacts/measurements/gravity_${gravity}_turn_raw.json"
        $turnArguments = @(
            "--headless", "--path", $repoPath, "--fixed-fps", "120", "--audio-driver", "Dummy",
            "res://tests/spike/JoltMeasurement.tscn", "--",
            "--jolt-ticks=120", "--jolt-seeds=$seeds", "--jolt-max-turns=400",
            "--jolt-no-determinism", "--gravity-strength=$gravity", "--jolt-output=$turnOutput"
        )
        Invoke-GodotMeasurement $turnArguments "TURN gravity $gravity"

        foreach ($bot in @(
            [ordered]@{ Kind = "heuristic"; Interval = 0.6 },
            [ordered]@{ Kind = "random"; Interval = 0.3 }
        )) {
            $kind = [string]$bot.Kind
            $interval = [double]$bot.Interval
            $blitzOutput = "res://artifacts/measurements/gravity_${gravity}_blitz_${kind}_raw.json"
            $blitzArguments = @(
                "--headless", "--path", $repoPath, "--fixed-fps", "120", "--audio-driver", "Dummy",
                "res://tests/spike/BlitzMeasurement.tscn", "--",
                "--blitz-bot=$kind", "--blitz-bot-interval=$interval", "--blitz-color-count=6",
                "--blitz-refill-rule=target", "--blitz-seeds=$seeds",
                "--gravity-strength=$gravity", "--blitz-output=$blitzOutput"
            )
            Invoke-GodotMeasurement $blitzArguments "BLITZ $kind gravity $gravity"
        }

        & (Join-Path $PSScriptRoot "run_blitz_responsiveness_measurement.ps1") `
            -GodotPath $GodotPath `
            -Label "gravity_$gravity" `
            -GravityStrength $gravity
        if ($LASTEXITCODE -ne 0) {
            throw "Windowed BLITZ gravity $gravity failed with exit code $LASTEXITCODE"
        }
    }
}

function Get-Percentile([double[]]$Values, [double]$Ratio) {
    if ($Values.Count -eq 0) { return 0.0 }
    $sorted = @($Values | Sort-Object)
    $index = [int][Math]::Round(($sorted.Count - 1) * $Ratio)
    $index = [Math]::Max(0, [Math]::Min($sorted.Count - 1, $index))
    return [double]$sorted[$index]
}

function Get-Distribution([double[]]$Values) {
    if ($Values.Count -eq 0) {
        return [ordered]@{ min = 0.0; p50 = 0.0; p95 = 0.0; max = 0.0; mean = 0.0 }
    }
    return [ordered]@{
        min = [double](($Values | Measure-Object -Minimum).Minimum)
        p50 = Get-Percentile $Values 0.50
        p95 = Get-Percentile $Values 0.95
        max = [double](($Values | Measure-Object -Maximum).Maximum)
        mean = [double](($Values | Measure-Object -Average).Average)
    }
}

function Get-TurnSummary([int]$Gravity) {
    $path = Join-Path $outputDirectory "gravity_${Gravity}_turn_raw.json"
    $report = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $tick = @($report.ticks | Where-Object { [int]$_.physics_ticks_per_second -eq 120 })[0]
    $rows = @($tick.seeds)
    $durations = @($rows | ForEach-Object {
        $_.turn_performance_samples | ForEach-Object { [double]$_.physics_frames / 120.0 }
    })
    $maxWall = 0.0
    $maxPair = 0.0
    $departures = 0
    $divergences = 0
    foreach ($property in $tick.bins.PSObject.Properties) {
        $bin = $property.Value
        $maxWall = [Math]::Max($maxWall, [double]$bin.max_wall_penetration_px)
        $maxPair = [Math]::Max($maxPair, [double]$bin.max_pair_penetration_px)
        $departures += [int]$bin.departures
        $divergences += [int]$bin.divergences
    }
    return [ordered]@{
        gravity_strength = $Gravity
        seed_count = $rows.Count
        game_over_count = @($rows | Where-Object { [bool]$_.game_over }).Count
        game_length_turns = Get-Distribution @($rows | ForEach-Object { [double]$_.completed_turns })
        turn_duration_seconds = Get-Distribution $durations
        score = Get-Distribution @($rows | ForEach-Object { [double]$_.score })
        blast_count = Get-Distribution @($rows | ForEach-Object { [double]$_.blast_count })
        max_wall_penetration_px = $maxWall
        max_pair_penetration_px = $maxPair
        departures = $departures
        divergences = $divergences
        physics_within_limits = (
            $maxWall -le $continuousWallLimitPx -and
            $maxPair -le $continuousPairLimitPx -and
            $departures -eq 0 -and
            $divergences -eq 0
        )
        wall_recoveries = 0
        wall_recovery_note = "Board3D has no corrective wall-recovery path; penetration is observed only"
    }
}

function Get-BlitzSummary([int]$Gravity, [string]$Bot) {
    $path = Join-Path $outputDirectory "gravity_${Gravity}_blitz_${Bot}_raw.json"
    $report = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $rows = @($report.seeds)
    return [ordered]@{
        gravity_strength = $Gravity
        bot = $Bot
        bot_interval = [double]$report.bot_interval
        seed_count = $rows.Count
        completed_count = @($rows | Where-Object { [bool]$_.completed }).Count
        score = Get-Distribution @($rows | ForEach-Object { [double]$_.score })
        reactions = Get-Distribution @($rows | ForEach-Object { [double]$_.reactions })
        blast_count = Get-Distribution @($rows | ForEach-Object { [double]$_.blast_count })
        fever_time_percent = Get-Distribution @($rows | ForEach-Object { [double]$_.fever_time_percent })
        final_occupancy_percent = Get-Distribution @($rows | ForEach-Object { [double]$_.final_occupancy_percent })
        max_wall_penetration_px = [double](($rows | Measure-Object -Property max_wall_penetration_px -Maximum).Maximum)
        max_pair_penetration_px = [double](($rows | Measure-Object -Property max_pair_penetration_px_sampled_10hz -Maximum).Maximum)
        departures = [int](($rows | Measure-Object -Property departures -Sum).Sum)
        divergences = [int](($rows | Measure-Object -Property divergences -Sum).Sum)
        physics_within_limits = (
            [double](($rows | Measure-Object -Property max_wall_penetration_px -Maximum).Maximum) -le $continuousWallLimitPx -and
            [double](($rows | Measure-Object -Property max_pair_penetration_px_sampled_10hz -Maximum).Maximum) -le $continuousPairLimitPx -and
            [int](($rows | Measure-Object -Property departures -Sum).Sum) -eq 0 -and
            [int](($rows | Measure-Object -Property divergences -Sum).Sum) -eq 0
        )
    }
}

$cases = @()
foreach ($gravity in $gravities) {
    $framePath = Join-Path $outputDirectory "blitz_responsiveness_gravity_${gravity}.json"
    $frame = Get-Content -LiteralPath $framePath -Raw | ConvertFrom-Json
    $cases += [ordered]@{
        gravity_strength = $gravity
        turn = Get-TurnSummary $gravity
        blitz_heuristic_0_6 = Get-BlitzSummary $gravity "heuristic"
        blitz_random_0_3 = Get-BlitzSummary $gravity "random"
        windowed_blitz = [ordered]@{
            frame_p99_ms = [double]$frame.frame_p99_ms
            frame_max_ms = [double]$frame.frame_max_ms
            frames_over_33_3_ms = [int]$frame.frames_over_33_3_ms
            dropped_inputs = [int]$frame.dropped_inputs
        }
    }
}

$summary = [ordered]@{
    engine = "Godot 4.8-dev3 mono"
    physics_engine = "Jolt Physics"
    physics_ticks_per_second = 120
    seeds = @(101..112)
    windowed_seeds = @(101..104)
    thresholds = [ordered]@{
        cycle_3d_wall_limit_px = $cycle3DWallLimitPx
        cycle_3d_pair_limit_px = $cycle3DPairLimitPx
        compatibility_2d_wall_limit_px = $compatibility2DWallLimitPx
        continuous_wall_limit_px = $continuousWallLimitPx
        continuous_pair_limit_px = $continuousPairLimitPx
        departure_limit = 0
        divergence_limit = 0
    }
    cases = $cases
}
$summaryPath = Join-Path $outputDirectory "gravity_1800_vs_3600_summary.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
$consoleSummary = @($cases | ForEach-Object {
    [ordered]@{
        gravity_strength = $_.gravity_strength
        turn_game_length_p50 = $_.turn.game_length_turns.p50
        turn_duration_p50 = $_.turn.turn_duration_seconds.p50
        turn_wall_max = $_.turn.max_wall_penetration_px
        turn_pair_max = $_.turn.max_pair_penetration_px
        turn_departures = $_.turn.departures
        turn_divergences = $_.turn.divergences
        turn_physics_pass = $_.turn.physics_within_limits
        blitz_heuristic_score_p50 = $_.blitz_heuristic_0_6.score.p50
        blitz_random_score_p50 = $_.blitz_random_0_3.score.p50
        blitz_wall_max = [Math]::Max(
            $_.blitz_heuristic_0_6.max_wall_penetration_px,
            $_.blitz_random_0_3.max_wall_penetration_px
        )
        blitz_pair_max = [Math]::Max(
            $_.blitz_heuristic_0_6.max_pair_penetration_px,
            $_.blitz_random_0_3.max_pair_penetration_px
        )
        blitz_physics_pass = (
            $_.blitz_heuristic_0_6.physics_within_limits -and
            $_.blitz_random_0_3.physics_within_limits
        )
        windowed_p99_ms = $_.windowed_blitz.frame_p99_ms
        windowed_max_ms = $_.windowed_blitz.frame_max_ms
    }
})
Write-Output ("GRAVITY_COMPARISON_RESULT {0}" -f ($consoleSummary | ConvertTo-Json -Compress -Depth 8))
Write-Output "GRAVITY_COMPARISON_SUITE exit=0 report=$summaryPath"
