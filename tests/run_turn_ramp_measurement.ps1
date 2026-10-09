param(
    [string]$GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe",
    [string]$SummaryName = "turn_ramp_measurement_summary.json",
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$artifactPath = Join-Path $repoPath "artifacts"
$conditions = @(
    [ordered]@{ id = "A"; name = "current"; ramp = 0; max = 3 },
    [ordered]@{ id = "B"; name = "ramp100_max2"; ramp = 100; max = 2 },
    [ordered]@{ id = "C"; name = "ramp100_max3"; ramp = 100; max = 3 },
    [ordered]@{ id = "D"; name = "ramp60_max3"; ramp = 60; max = 3 }
)

New-Item -ItemType Directory -Force -Path $artifactPath | Out-Null

if (-not $AggregateOnly) {
    foreach ($condition in $conditions) {
        $rawName = "turn_ramp_$($condition.id)_raw.json"
        & $GodotPath --headless --path $repoPath --fixed-fps 120 tests/spike/JoltMeasurement.tscn -- `
            --jolt-ticks=120 `
            --jolt-seeds=101,102,103,104,105,106,107,108,109,110,111,112 `
            --jolt-max-turns=800 `
            --jolt-no-determinism `
            --spawn-ramp-turns=$($condition.ramp) `
            --spawn-count-max=$($condition.max) `
            --jolt-output=res://artifacts/$rawName
        if ($LASTEXITCODE -ne 0) {
            throw "Turn ramp measurement '$($condition.id)' failed with exit code $LASTEXITCODE"
        }
    }
}

function Get-Percentile([double[]]$Values, [double]$Ratio) {
    if ($Values.Count -eq 0) { return 0.0 }
    $sorted = @($Values | Sort-Object)
    $index = [Math]::Clamp([Math]::Round(($sorted.Count - 1) * $Ratio), 0, $sorted.Count - 1)
    return [double]$sorted[$index]
}

function Get-Distribution([double[]]$Values) {
    if ($Values.Count -eq 0) {
        return [ordered]@{ min = 0.0; p50 = 0.0; max = 0.0; mean = 0.0 }
    }
    return [ordered]@{
        min = [double](($Values | Measure-Object -Minimum).Minimum)
        p50 = Get-Percentile $Values 0.5
        max = [double](($Values | Measure-Object -Maximum).Maximum)
        mean = [double](($Values | Measure-Object -Average).Average)
    }
}

function Get-TurnSummary([object[]]$Rows) {
    $turns = $Rows.Count
    $reactions = [int](($Rows | Measure-Object -Property reactions -Sum).Sum)
    $zero = @($Rows | Where-Object { [int]$_.reactions -eq 0 }).Count
    return [ordered]@{
        turns = $turns
        reactions = $reactions
        reactions_per_turn = $(if ($turns -eq 0) { 0.0 } else { $reactions / [double]$turns })
        zero_reaction_turns = $zero
        zero_reaction_turn_percent = $(if ($turns -eq 0) { 0.0 } else { 100.0 * $zero / $turns })
    }
}

$caseSummaries = @()
foreach ($condition in $conditions) {
    $rawFile = Join-Path $artifactPath "turn_ramp_$($condition.id)_raw.json"
    if (-not (Test-Path -LiteralPath $rawFile)) {
        throw "Missing raw report: $rawFile"
    }
    $report = Get-Content -Raw -LiteralPath $rawFile | ConvertFrom-Json
    if ([int]$report.spawn_count_ramp_turns -ne [int]$condition.ramp) {
        throw "Condition $($condition.id) ramp mismatch"
    }
    if ([int]$report.spawn_count_max -ne [int]$condition.max) {
        throw "Condition $($condition.id) max mismatch"
    }
    $tick = @($report.ticks)[0]
    $seedRows = @($tick.seeds)
    if ($seedRows.Count -ne 12) {
        throw "Condition $($condition.id) expected 12 seeds, got $($seedRows.Count)"
    }
    $allRows = @($seedRows | ForEach-Object { @($_.turn_rows) })
    $band1 = @($allRows | Where-Object { [int]$_.turn -le 100 })
    $band2 = @($allRows | Where-Object { [int]$_.turn -ge 101 -and [int]$_.turn -le 200 })
    $band3 = @($allRows | Where-Object { [int]$_.turn -ge 201 -and [int]$_.turn -le 300 })
    $band4 = @($allRows | Where-Object { [int]$_.turn -ge 301 })
    $lateRows = @($allRows | Where-Object { [int]$_.turn -ge 201 })
    $last50 = @()
    foreach ($seedRow in $seedRows) {
        $rows = @($seedRow.turn_rows)
        $start = [Math]::Max(0, $rows.Count - 50)
        if ($rows.Count -gt 0) {
            $last50 += @($rows[$start..($rows.Count - 1)])
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
        $maxPairAnyFrame = [Math]::Max($maxPairAnyFrame, [double]$bin.max_pair_penetration_any_frame_px)
        $departures += [int]$bin.departures
        $divergences += [int]$bin.divergences
    }

    $lengths = [double[]]@($seedRows | ForEach-Object { [double]$_.completed_turns })
    $occupancies = [double[]]@($seedRows | ForEach-Object { [double]$_.final_occupancy_percent })
    $scores = [double[]]@($seedRows | ForEach-Object { [double]$_.score })
    $combos = [double[]]@($seedRows | ForEach-Object { [double]$_.max_combo })
    $blastCounts = [double[]]@($seedRows | ForEach-Object { [double]$_.blast_count })
    $firstBlastTurns = [double[]]@(
        $seedRows |
            Where-Object { [int]$_.first_blast_turn -ge 0 } |
            ForEach-Object { [double]$_.first_blast_turn }
    )
    $blockedCounts = [double[]]@($seedRows | ForEach-Object { [double]$_.entrance_blocked_turns })
    $lateSummary = Get-TurnSummary $lateRows
    $gameOverCount = @($seedRows | Where-Object { [bool]$_.game_over }).Count
    $reached800Count = @($seedRows | Where-Object { -not [bool]$_.game_over -and [int]$_.completed_turns -ge 800 }).Count
    $physicsPass = (
        $maxWall -le 28.0 -and
        $maxPair -le 60.0 -and
        $departures -eq 0 -and
        $divergences -eq 0 -and
        [int]$tick.aborted_count -eq 0
    )
    $lengthSummary = Get-Distribution $lengths

    $caseSummaries += [ordered]@{
        id = $condition.id
        name = $condition.name
        spawn_count_per_turn = [int]$report.spawn_count_per_turn
        spawn_count_ramp_turns = [int]$report.spawn_count_ramp_turns
        spawn_count_max = [int]$report.spawn_count_max
        seed_count = $seedRows.Count
        game_over_count = $gameOverCount
        reached_800_count = $reached800Count
        aborted_count = [int]$tick.aborted_count
        game_length = $lengthSummary
        final_occupancy_percent = Get-Distribution $occupancies
        score = Get-Distribution $scores
        max_combo = Get-Distribution $combos
        blast = [ordered]@{
            total = [int](($blastCounts | Measure-Object -Sum).Sum)
            per_game = Get-Distribution $blastCounts
            games_with_blast = $firstBlastTurns.Count
            first_turn = Get-Distribution $firstBlastTurns
        }
        by_turn_band = [ordered]@{
            '1-100' = Get-TurnSummary $band1
            '101-200' = Get-TurnSummary $band2
            '201-300' = Get-TurnSummary $band3
            '301-end' = Get-TurnSummary $band4
        }
        turns_201_end = $lateSummary
        last_50_turns = Get-TurnSummary $last50
        entrance_blocked_turns = [ordered]@{
            total = [int](($blockedCounts | Measure-Object -Sum).Sum)
            per_game = Get-Distribution $blockedCounts
        }
        max_wall_penetration_px = $maxWall
        max_turn_end_pair_penetration_px = $maxPair
        max_pair_penetration_any_frame_px = $maxPairAnyFrame
        departures = $departures
        divergences = $divergences
        criteria_observations = [ordered]@{
            all_games_game_over = ($gameOverCount -eq 12)
            length_p50_in_250_400 = ([double]$lengthSummary.p50 -ge 250.0 -and [double]$lengthSummary.p50 -le 400.0)
            turns_201_end_zero_reaction_at_most_45_percent = ([double]$lateSummary.zero_reaction_turn_percent -le 45.0)
            physics_within_limits = $physicsPass
        }
        thresholds = [ordered]@{
            wall_limit_px = 28.0
            pair_limit_px = 60.0
        }
    }
}

$summary = [ordered]@{
    engine = "Godot 4.8-dev3 mono"
    physics_engine = "Jolt Physics"
    physics_ticks_per_second = 120
    seeds = @(101..112)
    max_turns = 800
    independent_process_per_condition = $true
    entrance_blocked_turn_definition = "turn ended with one or more Board3D entrance waiting orbs"
    cases = $caseSummaries
}
$summaryFile = Join-Path $artifactPath $SummaryName
$summary | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $summaryFile -Encoding utf8
Write-Output "TURN_RAMP_SUMMARY $summaryFile"
