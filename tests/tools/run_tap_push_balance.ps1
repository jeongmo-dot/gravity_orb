param(
    [string]$GodotPath = "",
    [ValidateRange(1, 8)]
    [int]$Parallelism = 4,
    [switch]$ReuseCompleted,
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = if ([string]::IsNullOrWhiteSpace($env:GODOT)) {
        "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
    } else {
        $env:GODOT
    }
}
$autoScript = Join-Path $repoPath "tests\run_jelly_physics_autoplay.ps1"
$strategyScript = Join-Path $PSScriptRoot "run_jelly_measurement.ps1"
$measurementDirectory = Join-Path $repoPath "artifacts\measurements"
New-Item -ItemType Directory -Path $measurementDirectory -Force | Out-Null

foreach ($mode in @("save", "all")) {
    $tapMode = if ($mode -eq "save") { "Save" } else { "All" }
    $autoLabel = "138_t3_auto_$mode"
    $autoSummaryPath = Join-Path $repoPath "artifacts\jelly_physics_autoplay_$autoLabel.json"
    if (-not ($ReuseCompleted -and (Test-Path -LiteralPath $autoSummaryPath))) {
        $autoArguments = @{
            GodotPath = $GodotPath
            RepoPath = $repoPath
            Label = $autoLabel
            Parallelism = $Parallelism
            MaxTurns = 600
            LevelProfile = "D"
            TapBlastBotMode = $tapMode
            SpawnCountMax = 4
            JellyMergeLevelGap = 1
            JellyMergeWideGapMinLevel = 0
            JellyTapLiftSpeed = 0.0
            JellyTapPushRadiusFactor = 0.5
            JellyTapPushSpeed = 1800.0
        }
        if ($AggregateOnly) { $autoArguments.AggregateOnly = $true }
        & $autoScript @autoArguments
    }

    $strategyLabel = "138_t3_strategy_$mode"
    $strategyArguments = @{
        GodotPath = $GodotPath
        SeedCount = 20
        Parallelism = $Parallelism
        TurnCap = 600
        LevelProfile = "D"
        TapBlastBotMode = $tapMode
        SpawnCountMax = 4
        JellyMergeLevelGap = 1
        JellyMergeWideGapMinLevel = 0
        JellyTapLiftSpeed = 0.0
        JellyTapPushRadiusFactor = 0.5
        JellyTapPushSpeed = 1800.0
        Strategies = if ($mode -eq "save") { "r,l_merge" } else { "l_merge" }
        MeasurementLabel = $strategyLabel
    }
    if ($ReuseCompleted) { $strategyArguments.ReuseCompleted = $true }
    if ($AggregateOnly) { $strategyArguments.AggregateOnly = $true }
    & $strategyScript @strategyArguments
}

function Get-AutoRow($Summary) {
    return [ordered]@{
        games = 20
        game_over = [int]$Summary.game_over_count
        incomplete = [int]$Summary.incomplete_count
        turns_average = [double]$Summary.average_turns_all
        turns_median = [double]$Summary.median_turns_all
        turns_minimum = [double]$Summary.minimum_turns_all
        turns_maximum = [double]$Summary.maximum_turns_all
        score_average = [double]$Summary.average_score_all
        score_median = [double]$Summary.median_score_all
        score_per_turn = [double]$Summary.score_per_turn_all
        merges_per_turn = [double]$Summary.merges_per_turn
        level_ups_per_turn = [double]$Summary.level_ups_per_turn
        level_eight_plus_game_count = [int]$Summary.level_eight_plus_game_count
        level_eight_plus_creations_per_game = [double]$Summary.average_level_eight_plus_creations_per_game
        level_ten_game_count = [int]$Summary.level_ten_game_count
        blasts = [int]$Summary.blast_count
        tap_blasts = [int]$Summary.tap_blast_count
        peak_active_orbs = [int]$Summary.maximum_active_sample.active_orbs
        maximum_pair_penetration_px = [double]$Summary.max_turn_end_pair_penetration_px
        departures = [int]$Summary.departures
    }
}

function Get-StrategyRow($Summary) {
    return [ordered]@{
        games = [int]$Summary.games
        game_over = [int]$Summary.game_over_count
        incomplete = [int]$Summary.incomplete_count
        turns_average = [double]$Summary.turns_average
        turns_median = [double]$Summary.turns_median
        turns_minimum = [double]$Summary.turns_minimum
        turns_maximum = [double]$Summary.turns_maximum
        score_average = [double]$Summary.score_average
        score_median = [double]$Summary.score_median
        score_per_turn = [double]$Summary.score_per_turn
        merges_per_turn = [double]$Summary.merges_per_turn
        level_ups_per_turn = [double]$Summary.level_ups_per_turn
        level_eight_plus_game_count = [int]$Summary.level_eight_plus_game_count
        level_eight_plus_creations_per_game = [double]$Summary.average_level_eight_plus_creations_per_game
        level_ten_game_count = [int]$Summary.level_ten_game_count
        blasts = [int]$Summary.blasts
        tap_blasts = [int]$Summary.tap_blasts
        peak_active_orbs = [int]$Summary.peak_active_orbs
        maximum_pair_penetration_px = [double]$Summary.maximum_pair_penetration_px
        departures = [int]$Summary.departures
    }
}

$autoSave = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_138_t3_auto_save.json") -Raw | ConvertFrom-Json
$autoAll = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_138_t3_auto_all.json") -Raw | ConvertFrom-Json
$strategySave = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_138_t3_strategy_save.json") -Raw | ConvertFrom-Json
$strategyAll = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_138_t3_strategy_all.json") -Raw | ConvertFrom-Json

$report = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    engine = "Godot 4.8-dev3 standard"
    conditions = "T3; auto seeds 101-120; strategy seeds 1-20; 600 turns; fixed 120 fps"
    profile = [ordered]@{
        jelly_tap_lift_speed = 0.0
        jelly_tap_push_radius_factor = 0.5
        jelly_tap_push_speed = 1800.0
        spawn_count_max = 4
        jelly_merge_level_gap = 1
    }
    auto_d_save = Get-AutoRow $autoSave
    auto_d_all = Get-AutoRow $autoAll
    r_d_save = Get-StrategyRow $strategySave.strategies.r
    l_merge_d_save = Get-StrategyRow $strategySave.strategies.l_merge
    l_merge_d_all = Get-StrategyRow $strategyAll.strategies.l_merge
    d_save_l_over_r_length_ratio = [double]$strategySave.skill_length_ratio_l_merge_over_r
    d_save_l_over_r_score_ratio = [double]$strategySave.skill_score_ratio_l_merge_over_r
}
$outputPath = Join-Path $measurementDirectory "tap_push_t3_balance.json"
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $outputPath -Encoding utf8
Write-Output "TAP_PUSH_BALANCE_REPORT $outputPath"
