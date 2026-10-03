param(
    [string]$GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe",
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$artifactPath = Join-Path $repoPath "artifacts"
$weightCases = @(
    [pscustomobject]@{ Name = "default"; MassExponent = 1.0; GravityLevelScale = 0.0 },
    [pscustomobject]@{ Name = "heavy"; MassExponent = 3.0; GravityLevelScale = 0.1 }
)
$impulses = @(0.0, 300.0, 600.0, 1200.0)
$conditions = foreach ($weightCase in $weightCases) {
    foreach ($impulse in $impulses) {
        [pscustomobject]@{
            Name = $weightCase.Name
            MassExponent = $weightCase.MassExponent
            GravityLevelScale = $weightCase.GravityLevelScale
            ShockImpulse = $impulse
            Id = "{0}_impulse{1}" -f $weightCase.Name, [int]$impulse
        }
    }
}

if (-not $AggregateOnly) {
    foreach ($condition in $conditions) {
        $relativeOutput = "res://artifacts/shock_$($condition.Id).json"
        & $GodotPath --headless --path $repoPath --fixed-fps 120 tests/spike/JoltMeasurement.tscn -- `
            --jolt-ticks=120 `
            --jolt-seeds=101,102,103,104,105,106,107,108,109,110,111,112 `
            --jolt-max-turns=400 `
            --jolt-no-determinism `
            --mass-exponent=$($condition.MassExponent) `
            --gravity-level-scale=$($condition.GravityLevelScale) `
            --shock-impulse=$($condition.ShockImpulse) `
            --shock-radius-factor=2.5 `
            --shock-level-scale=0.3 `
            --shock-jackpot-scale=3 `
            --jolt-output=$relativeOutput
        if ($LASTEXITCODE -ne 0) {
            throw "Shock sweep failed for $($condition.Id) with exit code $LASTEXITCODE"
        }
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

$rows = foreach ($condition in $conditions) {
    $reportFile = Join-Path $artifactPath "shock_$($condition.Id).json"
    $report = Get-Content -Raw -LiteralPath $reportFile | ConvertFrom-Json
    $tick = $report.ticks[0]
    $seedRows = @($tick.seeds)
    $completedTurns = [double[]]@($seedRows | ForEach-Object { [double]$_.completed_turns })
    $scores = [double[]]@($seedRows | ForEach-Object { [double]$_.score })
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
            $values = $levelProperty.Value
            $levelSamples = [int]$values.samples
            $movementSum += [double]$values.mean_movement_px * $levelSamples
            $belowRadiusCount += [double]$values.below_radius_percent * $levelSamples / 100.0
            $samples += $levelSamples
        }
        $jamByLevel["L$level"] = [ordered]@{
            samples = $samples
            mean_movement_px = if ($samples -eq 0) { 0.0 } else { $movementSum / $samples }
            below_radius_percent = if ($samples -eq 0) { 0.0 } else { $belowRadiusCount * 100.0 / $samples }
        }
    }

    [ordered]@{
        weight_case = $condition.Name
        mass_exponent = [double]$report.mass_exponent
        gravity_level_scale = [double]$report.gravity_level_scale
        shock_impulse = [double]$report.shock_impulse
        game_over_count = [int]$tick.game_over_count
        seed_count = $seedRows.Count
        game_over_turn_p50 = [double]$tick.game_over_turn_p50
        completed_turn_min = [int](($completedTurns | Measure-Object -Minimum).Minimum)
        completed_turn_max = [int](($completedTurns | Measure-Object -Maximum).Maximum)
        occupancy_mean_percent = [double]$tick.game_over_occupancy_mean_percent
        score_mean = ($scores | Measure-Object -Average).Average
        score_p50 = Get-Percentile $scores 0.5
        score_min = [long](($scores | Measure-Object -Minimum).Minimum)
        score_max = [long](($scores | Measure-Object -Maximum).Maximum)
        aborted_count = [int]$tick.aborted_count
        departures = $departures
        divergences = $divergences
        max_wall_penetration_px = $maxWall
        max_pair_penetration_px = $maxPair
        rearrangement_60_plus_mean = [double]$tick.rearrangement_60_plus_mean
        rearrangement_60_plus_samples = [int]$tick.rearrangement_60_plus_samples
        jam_occupancy_40_plus_by_level = $jamByLevel
        shock_displacement_by_target_level = $tick.shock_displacement_by_target_level
    }
}

$summary = [ordered]@{
    engine = "Godot 4.8-dev3 mono"
    physics_engine = "Jolt Physics"
    physics_ticks_per_second = 120
    seeds = @(101..112)
    max_turns = 400
    shock_radius_factor = 2.5
    shock_level_scale = 0.3
    shock_jackpot_scale = 3.0
    impulse_units = "mass * px/s; L1 mass=1 gives nominal delta-v 0/300/600/1200 px/s before distance and level multipliers"
    rearrangement_method = "Kendall discordant-pair fraction over persistent orb order projected onto the turn gravity axis; 0=no order changes, 1=all pairs reversed; sampled when turn-start occupancy >=60%"
    displacement_method = "For each shock reaction, measure each surviving target from shock-time position to turn end; average targets within a reaction, then average reaction means by target level"
    defaults_unchanged = $true
    rows = @($rows)
}
$summaryFile = Join-Path $artifactPath "shock_sweep_summary.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryFile -Encoding utf8
Write-Output "SHOCK_SWEEP_SUMMARY $summaryFile"
