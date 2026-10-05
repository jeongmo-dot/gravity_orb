param(
    [string]$GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe",
    [double]$BlastSpeed = 900.0,
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$artifactPath = Join-Path $repoPath "artifacts"
$conditions = @(
    [ordered]@{ name = "blast_off"; enabled = "off" },
    [ordered]@{ name = "blast_on"; enabled = "on" }
)

New-Item -ItemType Directory -Force -Path $artifactPath | Out-Null

if (-not $AggregateOnly) {
    foreach ($condition in $conditions) {
        $rawName = "blast_$($condition.name)_raw.json"
        & $GodotPath --headless --path $repoPath --fixed-fps 120 tests/spike/JoltMeasurement.tscn -- `
            --jolt-ticks=120 `
            --jolt-seeds=101,102,103,104,105,106,107,108,109,110,111,112 `
            --jolt-max-turns=800 `
            --jolt-no-determinism `
            --blast=$($condition.enabled) `
            --blast-speed=$BlastSpeed `
            --jolt-output=res://artifacts/$rawName
        if ($LASTEXITCODE -ne 0) {
            throw "BLAST measurement '$($condition.name)' failed with exit code $LASTEXITCODE"
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
    $scoreGain = [long](($Rows | Measure-Object -Property score_gain -Sum).Sum)
    $zero = @($Rows | Where-Object { [int]$_.reactions -eq 0 }).Count
    $combo0 = @($Rows | Where-Object { [int]$_.combo -eq 0 }).Count
    $combo1 = @($Rows | Where-Object { [int]$_.combo -eq 1 }).Count
    $combo2 = @($Rows | Where-Object { [int]$_.combo -eq 2 }).Count
    $combo3 = @($Rows | Where-Object { [int]$_.combo -ge 3 }).Count
    return [ordered]@{
        turns = $turns
        reactions = $reactions
        reactions_per_turn = $(if ($turns -eq 0) { 0.0 } else { $reactions / [double]$turns })
        zero_reaction_turn_percent = $(if ($turns -eq 0) { 0.0 } else { 100.0 * $zero / $turns })
        combo_distribution = [ordered]@{
            '0' = $combo0
            '1' = $combo1
            '2' = $combo2
            '3+' = $combo3
        }
        score_gain = $scoreGain
        score_gain_per_turn = $(if ($turns -eq 0) { 0.0 } else { $scoreGain / [double]$turns })
    }
}

$caseSummaries = @()
foreach ($condition in $conditions) {
    $rawFile = Join-Path $artifactPath "blast_$($condition.name)_raw.json"
    $report = Get-Content -Raw -LiteralPath $rawFile | ConvertFrom-Json
    $tick = $report.ticks[0]
    $seedRows = @($tick.seeds)
    $allRows = @($seedRows | ForEach-Object { @($_.turn_rows) })
    $band1 = @($allRows | Where-Object { [int]$_.turn -le 100 })
    $band2 = @($allRows | Where-Object { [int]$_.turn -ge 101 -and [int]$_.turn -le 200 })
    $band3 = @($allRows | Where-Object { [int]$_.turn -ge 201 })
    $occ0 = @($allRows | Where-Object { [double]$_.occupancy -lt 0.20 })
    $occ1 = @($allRows | Where-Object { [double]$_.occupancy -ge 0.20 -and [double]$_.occupancy -lt 0.40 })
    $occ2 = @($allRows | Where-Object { [double]$_.occupancy -ge 0.40 -and [double]$_.occupancy -lt 0.60 })
    $occ3 = @($allRows | Where-Object { [double]$_.occupancy -ge 0.60 })
    $last50 = @()
    foreach ($seedRow in $seedRows) {
        $rows = @($seedRow.turn_rows)
        $start = [Math]::Max(0, $rows.Count - 50)
        if ($rows.Count -gt 0) { $last50 += @($rows[$start..($rows.Count - 1)]) }
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

    $jam60Plus = [ordered]@{}
    foreach ($level in 1..7) {
        $property = $tick.bins.'60+'.levels.PSObject.Properties[[string]$level]
        $jam60Plus["L$level"] = if ($null -eq $property) {
            [ordered]@{ samples = 0; mean_movement_px = 0.0; below_radius_percent = 0.0 }
        } else {
            [ordered]@{
                samples = [int]$property.Value.samples
                mean_movement_px = [double]$property.Value.mean_movement_px
                below_radius_percent = [double]$property.Value.below_radius_percent
            }
        }
    }

    $postBlastSum = [int](($seedRows | ForEach-Object { $_.reactions_three_turns_after_blast.sum } | Measure-Object -Sum).Sum)
    $postBlastWindows = [int](($seedRows | ForEach-Object { $_.reactions_three_turns_after_blast.windows } | Measure-Object -Sum).Sum)
    $firstBlastTurns = [double[]]@($seedRows | Where-Object { [int]$_.first_blast_turn -ge 0 } | ForEach-Object { [double]$_.first_blast_turn })
    $blastCounts = [double[]]@($seedRows | ForEach-Object { [double]$_.blast_count })
    $lengths = [double[]]@($seedRows | ForEach-Object { [double]$_.completed_turns })
    $scores = [double[]]@($seedRows | ForEach-Object { [double]$_.score })
    $combos = [double[]]@($seedRows | ForEach-Object { [double]$_.max_combo })
    $continuousPass = (
        $maxWall -le 28.0 -and $maxPair -le 60.0 -and
        $departures -eq 0 -and $divergences -eq 0
    )

    $caseSummaries += [ordered]@{
        name = $condition.name
        blast_enabled = [bool]$report.blast_enabled
        blast_speed = [double]$report.blast_speed
        seed_count = $seedRows.Count
        game_over_count = [int]$tick.game_over_count
        reached_800_count = @($seedRows | Where-Object { [int]$_.completed_turns -ge 800 }).Count
        aborted_count = [int]$tick.aborted_count
        game_length = Get-Distribution $lengths
        score = Get-Distribution $scores
        max_combo = Get-Distribution $combos
        blast = [ordered]@{
            total = [int](($blastCounts | Measure-Object -Sum).Sum)
            per_game = Get-Distribution $blastCounts
            games_with_blast = $firstBlastTurns.Count
            first_turn = Get-Distribution $firstBlastTurns
            reactions_next_three_turns = [ordered]@{
                sum = $postBlastSum
                windows = $postBlastWindows
                mean = $(if ($postBlastWindows -eq 0) { 0.0 } else { $postBlastSum / [double]$postBlastWindows })
            }
        }
        by_turn_band = [ordered]@{
            '1-100' = Get-TurnSummary $band1
            '101-200' = Get-TurnSummary $band2
            '201-end' = Get-TurnSummary $band3
        }
        by_occupancy = [ordered]@{
            '0-20' = Get-TurnSummary $occ0
            '20-40' = Get-TurnSummary $occ1
            '40-60' = Get-TurnSummary $occ2
            '60+' = Get-TurnSummary $occ3
        }
        last_50_turns = Get-TurnSummary $last50
        jam_occupancy_60_plus_by_level = $jam60Plus
        max_wall_penetration_px = $maxWall
        max_turn_end_pair_penetration_px = $maxPair
        max_pair_penetration_any_frame_px = $maxPairAnyFrame
        departures = $departures
        divergences = $divergences
        thresholds = [ordered]@{
            wall_limit_px = 28.0
            pair_limit_px = 60.0
            continuous_limits_pass = $continuousPass
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
    cases = $caseSummaries
}
$summaryFile = Join-Path $artifactPath "blast_summary.json"
$summary | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $summaryFile -Encoding utf8
Write-Output "BLAST_SUMMARY $summaryFile"
