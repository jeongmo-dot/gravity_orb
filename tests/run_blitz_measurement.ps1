param(
    [string]$GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe",
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$artifactPath = Join-Path $repoPath "artifacts"
$conditions = @(
    [ordered]@{ bot = "heuristic"; interval = 0.6; name = "heuristic_0_6" },
    [ordered]@{ bot = "heuristic"; interval = 1.2; name = "heuristic_1_2" },
    [ordered]@{ bot = "random"; interval = 0.3; name = "random_0_3" }
)
New-Item -ItemType Directory -Force -Path $artifactPath | Out-Null

if (-not $AggregateOnly) {
    foreach ($condition in $conditions) {
        $rawName = "blitz_$($condition.name)_raw.json"
        & $GodotPath --headless --path $repoPath --fixed-fps 120 tests/spike/BlitzMeasurement.tscn -- `
            --blitz-bot=$($condition.bot) `
            --blitz-bot-interval=$($condition.interval) `
            --blitz-seeds=101,102,103,104,105,106,107,108,109,110,111,112 `
            --blitz-output=res://artifacts/$rawName
        if ($LASTEXITCODE -ne 0) {
            throw "BLITZ measurement $($condition.name) failed with exit code $LASTEXITCODE"
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

$cases = @()
foreach ($condition in $conditions) {
    $rawPath = Join-Path $artifactPath "blitz_$($condition.name)_raw.json"
    $report = Get-Content -LiteralPath $rawPath -Raw | ConvertFrom-Json
    $rows = @($report.seeds)
    $timeline = @()
    $seconds = @($rows | ForEach-Object { $_.occupancy_timeline } | ForEach-Object { [int]$_.second } | Sort-Object -Unique)
    foreach ($second in $seconds) {
        $values = @($rows | ForEach-Object {
            $_.occupancy_timeline | Where-Object { [int]$_.second -eq $second } | ForEach-Object { [double]$_.occupancy_percent }
        })
        $timeline += [ordered]@{
            second = $second
            sample_count = $values.Count
            occupancy_percent = Get-Distribution $values
        }
    }
    $chainDistribution = [ordered]@{}
    foreach ($row in $rows) {
        foreach ($property in $row.chain_histogram.PSObject.Properties) {
            $key = [string]$property.Name
            if (-not $chainDistribution.Contains($key)) { $chainDistribution[$key] = 0 }
            $chainDistribution[$key] += [int]$property.Value
        }
    }
    $cases += [ordered]@{
        name = [string]$condition.name
        bot = [string]$condition.bot
        bot_interval = [double]$condition.interval
        seed_count = $rows.Count
        completed_count = @($rows | Where-Object { [bool]$_.completed }).Count
        score = Get-Distribution @($rows | ForEach-Object { [double]$_.score })
        reactions = Get-Distribution @($rows | ForEach-Object { [double]$_.reactions })
        max_chain = Get-Distribution @($rows | ForEach-Object { [double]$_.max_chain })
        chain_distribution = $chainDistribution
        accepted_swipes = Get-Distribution @($rows | ForEach-Object { [double]$_.accepted_swipes })
        productive_swipes = Get-Distribution @($rows | ForEach-Object { [double]$_.productive_swipes })
        productive_swipe_percent = Get-Distribution @($rows | ForEach-Object { [double]$_.productive_swipe_percent })
        fever_count = Get-Distribution @($rows | ForEach-Object { [double]$_.fever_count })
        fever_total_time = Get-Distribution @($rows | ForEach-Object { [double]$_.fever_total_time })
        fever_time_percent = Get-Distribution @($rows | ForEach-Object { [double]$_.fever_time_percent })
        blast_count = Get-Distribution @($rows | ForEach-Object { [double]$_.blast_count })
        time_bonus_total = Get-Distribution @($rows | ForEach-Object { [double]$_.time_bonus_total })
        play_time = Get-Distribution @($rows | ForEach-Object { [double]$_.play_time })
        initial_fill_count = Get-Distribution @($rows | ForEach-Object { [double]$_.initial_fill_count })
        spawn_count = Get-Distribution @($rows | ForEach-Object { [double]$_.spawn_count })
        skipped_spawn_count = Get-Distribution @($rows | ForEach-Object { [double]$_.skipped_spawn_count })
        first_reaction_time = Get-Distribution @($rows | ForEach-Object { [double]$_.first_reaction_time })
        finale_score_percent = Get-Distribution @($rows | ForEach-Object { [double]$_.finale_score_percent })
        final_occupancy_percent = Get-Distribution @($rows | ForEach-Object { [double]$_.final_occupancy_percent })
        occupancy_timeline = $timeline
        max_wall_penetration_px = [double](($rows | Measure-Object -Property max_wall_penetration_px -Maximum).Maximum)
        max_pair_penetration_px_sampled_10hz = [double](($rows | Measure-Object -Property max_pair_penetration_px_sampled_10hz -Maximum).Maximum)
        departures = [int](($rows | Measure-Object -Property departures -Sum).Sum)
        divergences = [int](($rows | Measure-Object -Property divergences -Sum).Sum)
    }
}

$summary = [ordered]@{
    engine = "Godot 4.8-dev3 mono"
    physics_engine = "Jolt Physics"
    physics_ticks_per_second = 120
    seeds = @(101..112)
    cases = $cases
}
$summaryPath = Join-Path $artifactPath "blitz_swipe_spawn_summary.json"
$summary | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output "BLITZ_SUMMARY $summaryPath"
