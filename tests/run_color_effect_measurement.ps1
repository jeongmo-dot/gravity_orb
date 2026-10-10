param(
    [string]$GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe",
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$artifactPath = Join-Path $repoPath "artifacts"
$continuousWallLimitPx = 34.0
$continuousPairLimitPx = 68.0
$conditions = @(
    [ordered]@{
        name = "baseline_annihilation_effects_off"
        colorEffects = "off"
        opposites = "red-blue"
    },
    [ordered]@{
        name = "no_annihilation_effects_off"
        colorEffects = "off"
        opposites = "none"
    },
    [ordered]@{
        name = "no_annihilation_color_effects_on"
        colorEffects = "on"
        opposites = "none"
    }
)

New-Item -ItemType Directory -Force -Path $artifactPath | Out-Null

if (-not $AggregateOnly) {
    foreach ($condition in $conditions) {
        $rawName = "color_effects_$($condition.name)_raw.json"
        & $GodotPath --headless --path $repoPath --fixed-fps 120 tests/spike/JoltMeasurement.tscn -- `
            --jolt-ticks=120 `
            --jolt-seeds=101,102,103,104,105,106,107,108,109,110,111,112 `
            --jolt-max-turns=400 `
            --jolt-no-determinism `
            --color-effects=$($condition.colorEffects) `
            --opposites=$($condition.opposites) `
            --jolt-output=res://artifacts/$rawName
        if ($LASTEXITCODE -ne 0) {
            throw "Color-effect measurement '$($condition.name)' failed with exit code $LASTEXITCODE"
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

$caseSummaries = @()
foreach ($condition in $conditions) {
    $rawFile = Join-Path $artifactPath "color_effects_$($condition.name)_raw.json"
    $report = Get-Content -Raw -LiteralPath $rawFile | ConvertFrom-Json
    $tick = $report.ticks[0]
    $seedRows = @($tick.seeds)
    $turns = [double[]]@($seedRows | ForEach-Object { [double]$_.completed_turns })
    $scores = [double[]]@($seedRows | ForEach-Object { [double]$_.score })
    $maxCombos = [double[]]@($seedRows | ForEach-Object { [double]$_.max_combo })
    $reactionCounts = [ordered]@{
        RED = 0
        BLUE = 0
        GREEN = 0
        YELLOW = 0
        PURPLE = 0
        CYAN = 0
    }
    foreach ($seedRow in $seedRows) {
        foreach ($color in @("RED", "BLUE", "GREEN", "YELLOW", "PURPLE", "CYAN")) {
            $reactionCounts[$color] += [int]$seedRow.reactions_by_color.$color
        }
    }

    $maxWall = 0.0
    $maxPair = 0.0
    $maxPairAnyFrame = 0.0
    $departures = 0
    $divergences = 0
    foreach ($binProperty in $tick.bins.PSObject.Properties) {
        $bin = $binProperty.Value
        $maxWall = [Math]::Max($maxWall, [double]$bin.max_wall_penetration_px)
        $maxPair = [Math]::Max($maxPair, [double]$bin.max_pair_penetration_px)
        $maxPairAnyFrame = [Math]::Max(
            $maxPairAnyFrame,
            [double]$bin.max_pair_penetration_any_frame_px
        )
        $departures += [int]$bin.departures
        $divergences += [int]$bin.divergences
    }

    $jam60Plus = [ordered]@{}
    foreach ($level in 1..7) {
        $levelProperty = $tick.bins.'60+'.levels.PSObject.Properties[[string]$level]
        if ($null -eq $levelProperty) {
            $jam60Plus["L$level"] = [ordered]@{
                samples = 0
                mean_movement_px = 0.0
                below_radius_percent = 0.0
            }
            continue
        }
        $values = $levelProperty.Value
        $jam60Plus["L$level"] = [ordered]@{
            samples = [int]$values.samples
            mean_movement_px = [double]$values.mean_movement_px
            below_radius_percent = [double]$values.below_radius_percent
        }
    }

    $caseSummaries += [ordered]@{
        name = $condition.name
        color_effects_enabled = [bool]$report.color_effects_enabled
        opposite_pairs = @($report.opposite_pairs)
        game_over_count = [int]$tick.game_over_count
        seed_count = $seedRows.Count
        aborted_count = [int]$tick.aborted_count
        game_length = [ordered]@{
            min = [int](($turns | Measure-Object -Minimum).Minimum)
            p50 = Get-Percentile $turns 0.5
            max = [int](($turns | Measure-Object -Maximum).Maximum)
            mean = ($turns | Measure-Object -Average).Average
        }
        score = [ordered]@{
            min = [long](($scores | Measure-Object -Minimum).Minimum)
            p50 = Get-Percentile $scores 0.5
            max = [long](($scores | Measure-Object -Maximum).Maximum)
            mean = ($scores | Measure-Object -Average).Average
        }
        max_combo = [ordered]@{
            p50 = Get-Percentile $maxCombos 0.5
            max = [int](($maxCombos | Measure-Object -Maximum).Maximum)
            mean = ($maxCombos | Measure-Object -Average).Average
        }
        reactions_by_color = $reactionCounts
        max_wall_penetration_px = $maxWall
        max_turn_end_pair_penetration_px = $maxPair
        max_pair_penetration_any_frame_px = $maxPairAnyFrame
        departures = $departures
        divergences = $divergences
        jam_occupancy_60_plus_by_level = $jam60Plus
        thresholds = [ordered]@{
            continuous_wall_limit_px = $continuousWallLimitPx
            continuous_pair_limit_px = $continuousPairLimitPx
            continuous_limits_pass = (
                $maxWall -le $continuousWallLimitPx -and
                $maxPair -le $continuousPairLimitPx -and
                $departures -eq 0 -and
                $divergences -eq 0
            )
        }
    }
}

$summary = [ordered]@{
    engine = "Godot 4.8-dev3 mono"
    physics_engine = "Jolt Physics"
    physics_ticks_per_second = 120
    seeds = @(101..112)
    max_turns = 400
    independent_process_per_condition = $true
    cases = $caseSummaries
}

$summaryFile = Join-Path $artifactPath "color_effects_summary.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryFile -Encoding utf8
Write-Output "COLOR_EFFECTS_SUMMARY $summaryFile"
