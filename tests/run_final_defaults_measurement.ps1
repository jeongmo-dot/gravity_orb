param(
    [string]$GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe",
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$artifactPath = Join-Path $repoPath "artifacts"
$rawFile = Join-Path $artifactPath "final_defaults_raw.json"

if (-not $AggregateOnly) {
    & $GodotPath --headless --path $repoPath --fixed-fps 120 tests/spike/JoltMeasurement.tscn -- `
        --jolt-ticks=120 `
        --jolt-seeds=101,102,103,104,105,106,107,108,109,110,111,112 `
        --jolt-max-turns=400 `
        --jolt-no-determinism `
        --mass-exponent=2 `
        --gravity-level-scale=0.1 `
        --shock-impulse=600 `
        --shock-radius-factor=2.5 `
        --shock-level-scale=0.3 `
        --shock-jackpot-scale=3 `
        --jolt-output=res://artifacts/final_defaults_raw.json
    if ($LASTEXITCODE -ne 0) {
        throw "Final-default measurement failed with exit code $LASTEXITCODE"
    }
}

function Get-Percentile([double[]]$Values, [double]$Ratio) {
    if ($Values.Count -eq 0) {
        return 0.0
    }
    $sorted = @($Values | Sort-Object)
    $index = [Math]::Clamp([Math]::Round(($sorted.Count - 1) * $Ratio), 0, $sorted.Count - 1)
    return [double]$sorted[$index]
}

$report = Get-Content -Raw -LiteralPath $rawFile | ConvertFrom-Json
$tick = $report.ticks[0]
$seedRows = @($tick.seeds)
$turns = [double[]]@($seedRows | ForEach-Object { [double]$_.completed_turns })
$scores = [double[]]@($seedRows | ForEach-Object { [double]$_.score })
$occupancies = [double[]]@($seedRows | ForEach-Object { [double]$_.final_occupancy_percent })
$maxCombos = [double[]]@($seedRows | ForEach-Object { [double]$_.max_combo })
$maxLevels = [double[]]@($seedRows | ForEach-Object { [double]$_.max_level_reached })

$maxWall = 0.0
$maxPair = 0.0
$departures = 0
$divergences = 0
$bins = [ordered]@{}
foreach ($binProperty in $tick.bins.PSObject.Properties) {
    $bin = $binProperty.Value
    $maxWall = [Math]::Max($maxWall, [double]$bin.max_wall_penetration_px)
    $maxPair = [Math]::Max($maxPair, [double]$bin.max_pair_penetration_px)
    $departures += [int]$bin.departures
    $divergences += [int]$bin.divergences
    $bins[$binProperty.Name] = [ordered]@{
        max_wall_penetration_px = [double]$bin.max_wall_penetration_px
        max_pair_penetration_px = [double]$bin.max_pair_penetration_px
        departures = [int]$bin.departures
        divergences = [int]$bin.divergences
        mean_movement_px = [double]$bin.mean_movement_px
        below_radius_percent = [double]$bin.below_radius_percent
        movement_samples = [int]$bin.movement_samples
    }
}

$jamByLevel = [ordered]@{}
foreach ($level in 1..7) {
    $movementSum = 0.0
    $belowRadiusCount = 0.0
    $samples = 0
    foreach ($binName in "40-60", "60+") {
        $levelProperty = $tick.bins.$binName.levels.PSObject.Properties[[string]$level]
        if ($null -eq $levelProperty) {
            continue
        }
        $values = $levelProperty.Value
        $levelSamples = [int]$values.samples
        $movementSum += [double]$values.mean_movement_px * $levelSamples
        $belowRadiusCount += [double]$values.below_radius_percent * $levelSamples / 100.0
        $samples += $levelSamples
    }
    $jamByLevel["L$level"] = [ordered]@{
        samples = $samples
        mean_movement_px = if ($samples -eq 0) { 0.0 } else { $movementSum / $samples }
        below_radius_percent = if ($samples -eq 0) {
            0.0
        } else {
            $belowRadiusCount * 100.0 / $samples
        }
    }
}

$summary = [ordered]@{
    engine = "Godot 4.8-dev3 mono"
    physics_engine = "Jolt Physics"
    physics_ticks_per_second = 120
    position_steps = 4
    seeds = @(101..112)
    config = [ordered]@{
        mass_exponent = 2.0
        gravity_level_scale = 0.1
        shock_impulse = 600.0
        shock_radius_factor = 2.5
        shock_level_scale = 0.3
        shock_jackpot_scale = 3.0
    }
    game_over_count = [int]$tick.game_over_count
    seed_count = $seedRows.Count
    aborted_count = [int]$tick.aborted_count
    completed_turn_p50 = Get-Percentile $turns 0.5
    completed_turn_min = [int](($turns | Measure-Object -Minimum).Minimum)
    completed_turn_max = [int](($turns | Measure-Object -Maximum).Maximum)
    occupancy_mean_percent = ($occupancies | Measure-Object -Average).Average
    occupancy_min_percent = ($occupancies | Measure-Object -Minimum).Minimum
    occupancy_max_percent = ($occupancies | Measure-Object -Maximum).Maximum
    score_mean = ($scores | Measure-Object -Average).Average
    score_p50 = Get-Percentile $scores 0.5
    score_min = [long](($scores | Measure-Object -Minimum).Minimum)
    score_max = [long](($scores | Measure-Object -Maximum).Maximum)
    max_combo_p50 = Get-Percentile $maxCombos 0.5
    max_combo_max = [int](($maxCombos | Measure-Object -Maximum).Maximum)
    max_level_p50 = Get-Percentile $maxLevels 0.5
    max_level_max = [int](($maxLevels | Measure-Object -Maximum).Maximum)
    departures = $departures
    divergences = $divergences
    max_wall_penetration_px = $maxWall
    max_pair_penetration_px = $maxPair
    rearrangement_60_plus_mean = [double]$tick.rearrangement_60_plus_mean
    rearrangement_60_plus_samples = [int]$tick.rearrangement_60_plus_samples
    bins = $bins
    jam_occupancy_40_plus_by_level = $jamByLevel
    shock_displacement_by_target_level = $tick.shock_displacement_by_target_level
}

$summaryFile = Join-Path $artifactPath "final_defaults_summary.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryFile -Encoding utf8
Write-Output "FINAL_DEFAULTS_SUMMARY $summaryFile"
