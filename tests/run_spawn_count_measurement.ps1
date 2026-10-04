param(
    [string]$GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe",
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$artifactPath = Join-Path $repoPath "artifacts"
$seedCsv = "101,102,103,104,105,106,107,108,109,110,111,112"
$cases = @(
    [ordered]@{ name = "one_per_turn"; spawnCount = 1 },
    [ordered]@{ name = "two_per_turn"; spawnCount = 2 }
)

if (-not $AggregateOnly) {
    foreach ($case in $cases) {
        $output = "res://artifacts/spawn_count_$($case.name)_raw.json"
        & $GodotPath --headless --path $repoPath --fixed-fps 120 tests/spike/JoltMeasurement.tscn -- `
            --jolt-ticks=120 `
            --jolt-seeds=$seedCsv `
            --jolt-max-turns=800 `
            --jolt-no-determinism `
            --mass-exponent=2 `
            --gravity-level-scale=0.1 `
            --shock-impulse=600 `
            --shock-radius-factor=2.5 `
            --shock-level-scale=0.3 `
            --shock-jackpot-scale=3 `
            --color-effects=on `
            --opposites=none `
            --spawn-count=$($case.spawnCount) `
            --jolt-output=$output
        if ($LASTEXITCODE -ne 0) {
            throw "Spawn-count measurement '$($case.name)' failed with exit code $LASTEXITCODE"
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

function Get-CaseSummary($Case) {
    $rawFile = Join-Path $artifactPath "spawn_count_$($Case.name)_raw.json"
    $report = Get-Content -Raw -LiteralPath $rawFile | ConvertFrom-Json
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
    $departures = 0
    $divergences = 0
    $totalBinTurns = 0
    foreach ($binProperty in $tick.bins.PSObject.Properties) {
        $totalBinTurns += [int]$binProperty.Value.turns
    }
    $bins = [ordered]@{}
    foreach ($binProperty in $tick.bins.PSObject.Properties) {
        $bin = $binProperty.Value
        $maxWall = [Math]::Max($maxWall, [double]$bin.max_wall_penetration_px)
        $maxTurnEndPair = [Math]::Max($maxTurnEndPair, [double]$bin.max_pair_penetration_px)
        $departures += [int]$bin.departures
        $divergences += [int]$bin.divergences
        $binTurns = [int]$bin.turns
        $bins[$binProperty.Name] = [ordered]@{
            turns = $binTurns
            turn_percent = if ($totalBinTurns -eq 0) {
                0.0
            } else {
                [double]$binTurns * 100.0 / [double]$totalBinTurns
            }
        }
    }

    $seedOutcomes = @(
        $seedRows | ForEach-Object {
            [ordered]@{
                seed = [int]$_.seed
                completed_turns = [int]$_.completed_turns
                game_over = [bool]$_.game_over
                final_occupancy_percent = [double]$_.final_occupancy_percent
                score = [long]$_.score
                max_combo = [int]$_.max_combo
                max_level_reached = [int]$_.max_level_reached
                max_clear_count = [int]$_.max_clear_count
            }
        }
    )

    return [ordered]@{
        name = $Case.name
        spawn_count_per_turn = [int]$report.spawn_count_per_turn
        preview_turns = [int]$report.preview_turns
        game_over_count = [int]$tick.game_over_count
        turn_limit_count = @(
            $seedRows | Where-Object {
                -not [bool]$_.game_over -and [int]$_.completed_turns -ge 800
            }
        ).Count
        seed_count = $seedRows.Count
        aborted_count = [int]$tick.aborted_count
        game_length_turns = Get-Distribution $turns
        final_occupancy_percent = Get-Distribution $occupancies
        score = Get-Distribution $scores
        max_combo = Get-Distribution $maxCombos
        max_level = Get-Distribution $maxLevels
        l7_reached_seed_count = @($seedRows | Where-Object { [int]$_.max_level_reached -ge 7 }).Count
        l7_jackpot_count = [int](($maxClearCounts | Measure-Object -Sum).Sum)
        occupancy_bin_turns = $bins
        max_wall_penetration_px = $maxWall
        max_turn_end_pair_penetration_px = $maxTurnEndPair
        departures = $departures
        divergences = $divergences
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

$summaryFile = Join-Path $artifactPath "spawn_count_measurement_summary.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryFile -Encoding utf8
Write-Output "SPAWN_COUNT_MEASUREMENT_SUMMARY $summaryFile"
