param(
    [string]$GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe",
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$artifactPath = Join-Path $repoPath "artifacts"
$conditions = foreach ($massExponent in 1, 2, 3) {
    foreach ($gravityLevelScale in 0, 0.05, 0.1) {
        [pscustomobject]@{
            MassExponent = [double]$massExponent
            GravityLevelScale = [double]$gravityLevelScale
            Id = "mass{0}_gravity{1}" -f $massExponent, ($gravityLevelScale.ToString("0.00").Replace(".", "_"))
        }
    }
}

if (-not $AggregateOnly) {
    foreach ($condition in $conditions) {
        $relativeOutput = "res://artifacts/weight_$($condition.Id).json"
        & $GodotPath --headless --path $repoPath --fixed-fps 120 tests/spike/JoltMeasurement.tscn -- `
            --jolt-ticks=120 `
            --jolt-seeds=101,102,103,104,105,106,107,108,109,110,111,112 `
            --jolt-max-turns=400 `
            --jolt-no-determinism `
            --mass-exponent=$($condition.MassExponent) `
            --gravity-level-scale=$($condition.GravityLevelScale) `
            --jolt-output=$relativeOutput
        if ($LASTEXITCODE -ne 0) {
            throw "Weight sweep failed for $($condition.Id) with exit code $LASTEXITCODE"
        }
    }
}

$rows = foreach ($condition in $conditions) {
    $reportFile = Join-Path $artifactPath "weight_$($condition.Id).json"
    $report = Get-Content -Raw -LiteralPath $reportFile | ConvertFrom-Json
    $tick = $report.ticks[0]
    $seedRows = @($tick.seeds)
    $completedTurns = @($seedRows | ForEach-Object { [double]$_.completed_turns })
    $scores = @($seedRows | ForEach-Object { [double]$_.score })
    $maxWall = 0.0
    $maxPair = 0.0
    $departures = 0
    $divergences = 0
    foreach ($binProperty in $tick.bins.PSObject.Properties) {
        $bin = $binProperty.Value
        $maxWall = [Math]::Max($maxWall, [double]$bin.max_wall_penetration_px)
        $maxPair = [Math]::Max($maxPair, [double]$bin.max_pair_penetration_px)
        $departures += [int]$bin.departures
        $divergences += [int]$bin.divergences
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
            $levelValues = $levelProperty.Value
            $levelSamples = [int]$levelValues.samples
            $movementSum += [double]$levelValues.mean_movement_px * $levelSamples
            $belowRadiusCount += [double]$levelValues.below_radius_percent * $levelSamples / 100.0
            $samples += $levelSamples
        }
        $jamByLevel["L$level"] = [ordered]@{
            samples = $samples
            mean_movement_px = if ($samples -eq 0) { 0.0 } else { $movementSum / $samples }
            below_radius_percent = if ($samples -eq 0) { 0.0 } else { $belowRadiusCount * 100.0 / $samples }
        }
    }

    [ordered]@{
        mass_exponent = [double]$report.mass_exponent
        gravity_level_scale = [double]$report.gravity_level_scale
        game_over_count = [int]$tick.game_over_count
        seed_count = $seedRows.Count
        game_over_turn_p50 = [double]$tick.game_over_turn_p50
        completed_turn_min = [int](($completedTurns | Measure-Object -Minimum).Minimum)
        completed_turn_max = [int](($completedTurns | Measure-Object -Maximum).Maximum)
        occupancy_mean_percent = [double]$tick.game_over_occupancy_mean_percent
        score_mean = ($scores | Measure-Object -Average).Average
        aborted_count = [int]$tick.aborted_count
        departures = $departures
        divergences = $divergences
        max_wall_penetration_px = $maxWall
        max_pair_penetration_px = $maxPair
        jam_occupancy_40_plus_by_level = $jamByLevel
        feel_metrics = $report.feel_metrics
    }
}

$summary = [ordered]@{
    engine = "Godot 4.8-dev3 mono"
    physics_engine = "Jolt Physics"
    physics_ticks_per_second = 120
    seeds = @(101..112)
    max_turns = 400
    defaults_unchanged = $true
    rows = @($rows)
}
$summaryFile = Join-Path $artifactPath "weight_sweep_summary.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryFile -Encoding utf8
Write-Output "WEIGHT_SWEEP_SUMMARY $summaryFile"
