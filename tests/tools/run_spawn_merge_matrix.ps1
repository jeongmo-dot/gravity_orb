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

$profiles = @(
    [pscustomobject]@{ Name = "S5-G1"; Slug = "s5_g1"; SpawnMax = 5; Gap = 1; Wide = 0 },
    [pscustomobject]@{ Name = "S4-G1"; Slug = "s4_g1"; SpawnMax = 4; Gap = 1; Wide = 0 },
    [pscustomobject]@{ Name = "S3-G1"; Slug = "s3_g1"; SpawnMax = 3; Gap = 1; Wide = 0 },
    [pscustomobject]@{ Name = "S5-G2"; Slug = "s5_g2"; SpawnMax = 5; Gap = 2; Wide = 0 },
    [pscustomobject]@{ Name = "S4-G2"; Slug = "s4_g2"; SpawnMax = 4; Gap = 2; Wide = 0 },
    [pscustomobject]@{ Name = "S3-G2"; Slug = "s3_g2"; SpawnMax = 3; Gap = 2; Wide = 0 },
    [pscustomobject]@{ Name = "S5-H6"; Slug = "s5_h6"; SpawnMax = 5; Gap = 1; Wide = 6 },
    [pscustomobject]@{ Name = "S4-H6"; Slug = "s4_h6"; SpawnMax = 4; Gap = 1; Wide = 6 },
    [pscustomobject]@{ Name = "S3-H6"; Slug = "s3_h6"; SpawnMax = 3; Gap = 1; Wide = 6 }
)

foreach ($profile in $profiles) {
    foreach ($mode in @("save", "all")) {
        $tapMode = if ($mode -eq "save") { "Save" } else { "All" }
        $autoLabel = "137_$($profile.Slug)_auto_$mode"
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
                SpawnCountMax = $profile.SpawnMax
                JellyMergeLevelGap = $profile.Gap
                JellyMergeWideGapMinLevel = $profile.Wide
                JellyTapLiftSpeed = 900.0
            }
            if ($AggregateOnly) { $autoArguments.AggregateOnly = $true }
            & $autoScript @autoArguments
        } else {
            Write-Output "SPAWN_MERGE_MATRIX_REUSE kind=auto label=$autoLabel"
        }

        $strategyLabel = "137_$($profile.Slug)_strategy_$mode"
        $strategyArguments = @{
            GodotPath = $GodotPath
            SeedCount = 20
            Parallelism = $Parallelism
            TurnCap = 600
            LevelProfile = "D"
            TapBlastBotMode = $tapMode
            SpawnCountMax = $profile.SpawnMax
            JellyMergeLevelGap = $profile.Gap
            JellyMergeWideGapMinLevel = $profile.Wide
            JellyTapLiftSpeed = 900.0
            Strategies = if ($mode -eq "save") { "r,l_merge" } else { "l_merge" }
            MeasurementLabel = $strategyLabel
        }
        if ($ReuseCompleted) { $strategyArguments.ReuseCompleted = $true }
        if ($AggregateOnly) { $strategyArguments.AggregateOnly = $true }
        & $strategyScript @strategyArguments
    }
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

$matrix = [ordered]@{}
foreach ($profile in $profiles) {
    $autoSavePath = Join-Path $repoPath "artifacts\jelly_physics_autoplay_137_$($profile.Slug)_auto_save.json"
    $autoAllPath = Join-Path $repoPath "artifacts\jelly_physics_autoplay_137_$($profile.Slug)_auto_all.json"
    $strategySavePath = Join-Path $measurementDirectory "jelly_rules_measurement_137_$($profile.Slug)_strategy_save.json"
    $strategyAllPath = Join-Path $measurementDirectory "jelly_rules_measurement_137_$($profile.Slug)_strategy_all.json"
    foreach ($path in @($autoSavePath, $autoAllPath, $strategySavePath, $strategyAllPath)) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Missing $path" }
    }
    $autoSave = Get-Content -LiteralPath $autoSavePath -Raw | ConvertFrom-Json
    $autoAll = Get-Content -LiteralPath $autoAllPath -Raw | ConvertFrom-Json
    $strategySave = Get-Content -LiteralPath $strategySavePath -Raw | ConvertFrom-Json
    $strategyAll = Get-Content -LiteralPath $strategyAllPath -Raw | ConvertFrom-Json
    $matrix[$profile.Name] = [ordered]@{
        spawn_count_max = $profile.SpawnMax
        jelly_merge_level_gap = $profile.Gap
        jelly_merge_wide_gap_min_level = $profile.Wide
        auto_d_save = Get-AutoRow $autoSave
        auto_d_all = Get-AutoRow $autoAll
        r_d_save = Get-StrategyRow $strategySave.strategies.r
        l_merge_d_save = Get-StrategyRow $strategySave.strategies.l_merge
        l_merge_d_all = Get-StrategyRow $strategyAll.strategies.l_merge
        d_save_l_over_r_length_ratio = [double]$strategySave.skill_length_ratio_l_merge_over_r
        d_save_l_over_r_score_ratio = [double]$strategySave.skill_score_ratio_l_merge_over_r
    }
}

$report = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    engine = "Godot 4.8-dev3 standard"
    conditions = "3x3 spawn/merge matrix; auto seeds 101-120; strategy seeds 1-20; 600 turns; fixed 120 fps"
    jelly_tap_lift_speed = 900.0
    profiles = $matrix
}
$outputPath = Join-Path $measurementDirectory "spawn_merge_matrix_3x3.json"
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $outputPath -Encoding utf8
Write-Output "SPAWN_MERGE_MATRIX_REPORT $outputPath"
