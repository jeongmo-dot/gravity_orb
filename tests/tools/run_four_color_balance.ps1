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
    [pscustomobject]@{ Slug = "c6"; Name = "C6"; Unlocks = "30,60"; Effects = "Color"; SpawnMax = 4 },
    [pscustomobject]@{ Slug = "c4"; Name = "C4"; Unlocks = "None"; Effects = "Color"; SpawnMax = 4 },
    [pscustomobject]@{ Slug = "c4e"; Name = "C4E"; Unlocks = "None"; Effects = "Four"; SpawnMax = 4 },
    [pscustomobject]@{ Slug = "c4e_s5"; Name = "C4E-S5"; Unlocks = "None"; Effects = "Four"; SpawnMax = 5 }
)

foreach ($profile in $profiles) {
    foreach ($mode in @("save", "all")) {
        $tapMode = if ($mode -eq "save") { "Save" } else { "All" }
        $autoLabel = "139_$($profile.Slug)_auto_$mode"
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
                JellyMergeLevelGap = 1
                JellyMergeWideGapMinLevel = 0
                JellyTapEffectModes = $profile.Effects
                TurnStartColors = 4
                TurnColorUnlockTurns = $profile.Unlocks
            }
            if ($AggregateOnly) { $autoArguments.AggregateOnly = $true }
            & $autoScript @autoArguments
        }

        $strategyLabel = "139_$($profile.Slug)_strategy_$mode"
        $strategyArguments = @{
            GodotPath = $GodotPath
            SeedCount = 20
            Parallelism = $Parallelism
            TurnCap = 600
            LevelProfile = "D"
            TapBlastBotMode = $tapMode
            SpawnCountMax = $profile.SpawnMax
            JellyMergeLevelGap = 1
            JellyMergeWideGapMinLevel = 0
            JellyTapEffectModes = $profile.Effects
            TurnStartColors = 4
            TurnColorUnlockTurns = $profile.Unlocks
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
        tap_blast_count_by_color = $Summary.tap_blast_count_by_color
        tap_clean_count_by_color = $Summary.tap_clean_count_by_color
        average_clean_count_per_tap = [double]$Summary.average_clean_count_per_tap
        rest_skipped_turns = [int]$Summary.rest_skipped_turns
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
        tap_blast_count_by_color = $Summary.tap_blast_count_by_color
        tap_clean_count_by_color = $Summary.tap_clean_count_by_color
        average_clean_count_per_tap = [double]$Summary.average_clean_count_per_tap
        rest_skipped_turns = [int]$Summary.rest_skipped_turns
        peak_active_orbs = [int]$Summary.peak_active_orbs
        maximum_pair_penetration_px = [double]$Summary.maximum_pair_penetration_px
        departures = [int]$Summary.departures
    }
}

$profileReports = [ordered]@{}
foreach ($profile in $profiles) {
    $autoSave = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_139_$($profile.Slug)_auto_save.json") -Raw | ConvertFrom-Json
    $autoAll = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_139_$($profile.Slug)_auto_all.json") -Raw | ConvertFrom-Json
    $strategySave = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_139_$($profile.Slug)_strategy_save.json") -Raw | ConvertFrom-Json
    $strategyAll = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_139_$($profile.Slug)_strategy_all.json") -Raw | ConvertFrom-Json
    $profileReports[$profile.Name] = [ordered]@{
        colors = if ($profile.Unlocks -eq "None") { 4 } else { 6 }
        turn_color_unlock_turns = $profile.Unlocks
        jelly_tap_effect_modes = $profile.Effects
        spawn_count_max = $profile.SpawnMax
        auto_d_save = Get-AutoRow $autoSave
        auto_d_all = Get-AutoRow $autoAll
        r_d_save = Get-StrategyRow $strategySave.strategies.r
        l_merge_d_save = Get-StrategyRow $strategySave.strategies.l_merge
        l_merge_d_all = Get-StrategyRow $strategyAll.strategies.l_merge
    }
}

$report = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    engine = "Godot 4.8-dev3 standard"
    conditions = "C6/C4/C4E/C4E-S5; auto seeds 101-120; strategy seeds 1-20; 600 turns; fixed 120 fps"
    profiles = $profileReports
}
$outputPath = Join-Path $measurementDirectory "four_color_balance.json"
$report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $outputPath -Encoding utf8
Write-Output "FOUR_COLOR_BALANCE_REPORT $outputPath"
