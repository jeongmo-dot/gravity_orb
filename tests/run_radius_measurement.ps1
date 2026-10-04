param(
    [string]$GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe",
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$artifactPath = Join-Path $repoPath "artifacts"
$seedCsv = "101,102,103,104,105,106,107,108,109,110,111,112"
$cases = @(
    [ordered]@{
        name = "current"
        radii = "25,40,60,85,115,150,190"
    },
    [ordered]@{
        name = "reduced"
        radii = "25,40,60,85,100,120,140"
    }
)

if (-not $AggregateOnly) {
    foreach ($case in $cases) {
        $output = "res://artifacts/radius_$($case.name)_raw.json"
        & $GodotPath --headless --path $repoPath --fixed-fps 120 tests/spike/JoltMeasurement.tscn -- `
            --jolt-ticks=120 `
            --jolt-seeds=$seedCsv `
            --jolt-max-turns=800 `
            --jolt-no-determinism `
            --spawn-count=1 `
            --mass-exponent=2 `
            --gravity-level-scale=0.1 `
            --shock-impulse=600 `
            --shock-radius-factor=2.5 `
            --shock-level-scale=0.3 `
            --shock-jackpot-scale=3 `
            --color-effects=on `
            --opposites=none `
            --level-radii=$($case.radii) `
            --jolt-output=$output
        if ($LASTEXITCODE -ne 0) {
            throw "Radius measurement '$($case.name)' failed with exit code $LASTEXITCODE"
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

function Get-Distribution([double[]]$Values) {
    return [ordered]@{
        min = [double](($Values | Measure-Object -Minimum).Minimum)
        p50 = Get-Percentile $Values 0.5
        max = [double](($Values | Measure-Object -Maximum).Maximum)
        mean = [double](($Values | Measure-Object -Average).Average)
    }
}

function Get-LevelJam($Bin) {
    $result = [ordered]@{}
    foreach ($level in 1..7) {
        $levelProperty = $Bin.levels.PSObject.Properties[[string]$level]
        if ($null -eq $levelProperty) {
            $result["L$level"] = [ordered]@{
                samples = 0
                mean_movement_px = 0.0
                below_radius_percent = 0.0
            }
            continue
        }
        $values = $levelProperty.Value
        $result["L$level"] = [ordered]@{
            samples = [int]$values.samples
            mean_movement_px = [double]$values.mean_movement_px
            below_radius_percent = [double]$values.below_radius_percent
        }
    }
    return $result
}

function Get-CaseSummary($Case) {
    $rawFile = Join-Path $artifactPath "radius_$($Case.name)_raw.json"
    $report = Get-Content -Raw -LiteralPath $rawFile | ConvertFrom-Json
    if ([int]$report.spawn_count_per_turn -ne 1 -or [int]$report.preview_turns -ne 2) {
        throw (
            "Radius measurement '$($Case.name)' used unexpected spawn/preview config: " +
            "$($report.spawn_count_per_turn)/$($report.preview_turns)"
        )
    }
    $tick = $report.ticks[0]
    $seedRows = @($tick.seeds)
    $turns = [double[]]@($seedRows | ForEach-Object { [double]$_.completed_turns })
    $occupancies = [double[]]@($seedRows | ForEach-Object { [double]$_.final_occupancy_percent })
    $scores = [double[]]@($seedRows | ForEach-Object { [double]$_.score })
    $maxCombos = [double[]]@($seedRows | ForEach-Object { [double]$_.max_combo })
    $maxLevels = [double[]]@($seedRows | ForEach-Object { [double]$_.max_level_reached })
    $maxClearCounts = [double[]]@($seedRows | ForEach-Object { [double]$_.max_clear_count })

    $maxWall = 0.0
    $maxTurnEndPair = 0.0
    $maxAnyFramePair = 0.0
    $departures = 0
    $divergences = 0
    $bins = [ordered]@{}
    foreach ($binProperty in $tick.bins.PSObject.Properties) {
        $bin = $binProperty.Value
        $maxWall = [Math]::Max($maxWall, [double]$bin.max_wall_penetration_px)
        $maxTurnEndPair = [Math]::Max($maxTurnEndPair, [double]$bin.max_pair_penetration_px)
        $maxAnyFramePair = [Math]::Max(
            $maxAnyFramePair,
            [double]$bin.max_pair_penetration_any_frame_px
        )
        $departures += [int]$bin.departures
        $divergences += [int]$bin.divergences
        $bins[$binProperty.Name] = [ordered]@{
            turns = [int]$bin.turns
            movement_samples = [int]$bin.movement_samples
            mean_movement_px = [double]$bin.mean_movement_px
            below_radius_percent = [double]$bin.below_radius_percent
            max_wall_penetration_px = [double]$bin.max_wall_penetration_px
            max_turn_end_pair_penetration_px = [double]$bin.max_pair_penetration_px
            departures = [int]$bin.departures
            divergences = [int]$bin.divergences
        }
    }

    $seedOutcomes = @(
        $seedRows | ForEach-Object {
            [ordered]@{
                seed = [int]$_.seed
                completed_turns = [int]$_.completed_turns
                game_over = [bool]$_.game_over
                final_occupancy_percent = [double]$_.final_occupancy_percent
                final_orb_count = [int]$_.final_orb_count
                max_level_reached = [int]$_.max_level_reached
                max_clear_count = [int]$_.max_clear_count
                score = [long]$_.score
                max_combo = [int]$_.max_combo
            }
        }
    )

    return [ordered]@{
        name = $Case.name
        level_radii_px = @($report.level_radii_px | ForEach-Object { [double]$_ })
        game_over_count = [int]$tick.game_over_count
        turn_cap_count = @($seedRows | Where-Object { -not [bool]$_.game_over }).Count
        seed_count = $seedRows.Count
        aborted_count = [int]$tick.aborted_count
        game_length_turns = Get-Distribution $turns
        final_occupancy_percent = Get-Distribution $occupancies
        score = Get-Distribution $scores
        max_combo = Get-Distribution $maxCombos
        max_level = Get-Distribution $maxLevels
        l7_reached_seed_count = @($seedRows | Where-Object { [int]$_.max_level_reached -ge 7 }).Count
        l7_reached_seeds = @(
            $seedRows |
                Where-Object { [int]$_.max_level_reached -ge 7 } |
                ForEach-Object { [int]$_.seed }
        )
        l7_jackpot_count = [int](($maxClearCounts | Measure-Object -Sum).Sum)
        max_clear_count = Get-Distribution $maxClearCounts
        max_wall_penetration_px = $maxWall
        max_turn_end_pair_penetration_px = $maxTurnEndPair
        max_pair_penetration_any_frame_px = $maxAnyFramePair
        departures = $departures
        divergences = $divergences
        occupancy_bins = $bins
        jam_occupancy_60_plus_by_level = Get-LevelJam $tick.bins.'60+'
        seed_outcomes = $seedOutcomes
    }
}

$summaries = @($cases | ForEach-Object { Get-CaseSummary $_ })
$summary = [ordered]@{
    engine = "Godot 4.8-dev3 mono"
    physics_engine = "Jolt Physics"
    physics_ticks_per_second = 120
    seeds = @(101..112)
    max_turns = 800
    independent_process_per_condition = $true
    config = [ordered]@{
        spawn_count_per_turn = 1
        preview_turns = 2
        mass_exponent = 2.0
        gravity_level_scale = 0.1
        shock_impulse = 600.0
        shock_radius_factor = 2.5
        shock_level_scale = 0.3
        shock_jackpot_scale = 3.0
        color_effects_enabled = $true
        opposite_pairs = @()
    }
    cases = $summaries
}

$summaryFile = Join-Path $artifactPath "radius_remeasurement_summary.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryFile -Encoding utf8
Write-Output "RADIUS_REMEASUREMENT_SUMMARY $summaryFile"
