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
    [pscustomobject]@{ Slug = "h8"; Name = "H8"; Turns = 8; Level = 3 },
    [pscustomobject]@{ Slug = "h6"; Name = "H6"; Turns = 6; Level = 3 },
    [pscustomobject]@{ Slug = "h10"; Name = "H10"; Turns = 10; Level = 3 },
    [pscustomobject]@{ Slug = "h8_l2"; Name = "H8-L2"; Turns = 8; Level = 2 }
)

foreach ($profile in $profiles) {
    foreach ($mode in @("save", "all")) {
        $tapMode = if ($mode -eq "save") { "Save" } else { "All" }
        $autoLabel = "143_$($profile.Slug)_auto_$mode"
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
                JellyTapEffectModes = "Four"
                TurnStartColors = 4
                TurnColorUnlockTurns = "None"
                JellyTapCleanMaxLevel = 1
                JellyTapCleanZoneRule = "On"
                JellyTapRestCleanCount = 2
                JellyTimedEnabled = "On"
                JellyTimedTurns = $profile.Turns
                JellyTimedLevel = $profile.Level
            }
            if ($AggregateOnly) { $autoArguments.AggregateOnly = $true }
            & $autoScript @autoArguments
        }

        $strategyLabel = "143_$($profile.Slug)_strategy_$mode"
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
            JellyTapEffectModes = "Four"
            TurnStartColors = 4
            TurnColorUnlockTurns = "None"
            JellyTapCleanMaxLevel = 1
            JellyTapCleanZoneRule = "On"
            JellyTapRestCleanCount = 2
            JellyTimedEnabled = "On"
            JellyTimedTurns = $profile.Turns
            JellyTimedLevel = $profile.Level
            Strategies = if ($mode -eq "save") { "r,l_merge" } else { "l_merge" }
            MeasurementLabel = $strategyLabel
        }
        if ($ReuseCompleted) { $strategyArguments.ReuseCompleted = $true }
        if ($AggregateOnly) { $strategyArguments.AggregateOnly = $true }
        & $strategyScript @strategyArguments
    }
}

function Get-TimedFields($Summary) {
    return [ordered]@{
        timed_per_game = [double]$Summary.timed_jelly_per_game
        success_ratio = [double]$Summary.timed_jelly_success_ratio
        fail_zero_ratio = [double]$Summary.timed_jelly_failure_ratio
        remain_end_ratio = [double]$Summary.timed_jelly_remaining_ratio
        average_turns_to_success = [double]$Summary.timed_jelly_average_turns_to_success
        success_result_levels = $Summary.timed_jelly_success_result_levels
    }
}

function Get-AutoRow($Summary) {
    $row = [ordered]@{
        games = 20
        complete = [int]$Summary.game_over_count
        incomplete = [int]$Summary.incomplete_count
        turns_average = [double]$Summary.average_turns_all
        turns_median = [double]$Summary.median_turns_all
        turns_minimum = [double]$Summary.minimum_turns_all
        turns_maximum = [double]$Summary.maximum_turns_all
        score_average = [double]$Summary.average_score_all
        level_eight_plus_games = [int]$Summary.level_eight_plus_game_count
        level_eight_plus_per_game = [double]$Summary.average_level_eight_plus_creations_per_game
        departures = [int]$Summary.departures
    }
    foreach ($entry in (Get-TimedFields $Summary).GetEnumerator()) { $row[$entry.Key] = $entry.Value }
    return $row
}

function Get-StrategyRow($Summary) {
    $row = [ordered]@{
        games = [int]$Summary.games
        complete = [int]$Summary.game_over_count
        incomplete = [int]$Summary.incomplete_count
        turns_average = [double]$Summary.turns_average
        turns_median = [double]$Summary.turns_median
        turns_minimum = [double]$Summary.turns_minimum
        turns_maximum = [double]$Summary.turns_maximum
        score_average = [double]$Summary.score_average
        level_eight_plus_games = [int]$Summary.level_eight_plus_game_count
        level_eight_plus_per_game = [double]$Summary.average_level_eight_plus_creations_per_game
        departures = [int]$Summary.departures
    }
    foreach ($entry in (Get-TimedFields $Summary).GetEnumerator()) { $row[$entry.Key] = $entry.Value }
    return $row
}

$profileReports = [ordered]@{}
foreach ($profile in $profiles) {
    $autoSave = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_143_$($profile.Slug)_auto_save.json") -Raw | ConvertFrom-Json
    $autoAll = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_143_$($profile.Slug)_auto_all.json") -Raw | ConvertFrom-Json
    $strategySave = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_143_$($profile.Slug)_strategy_save.json") -Raw | ConvertFrom-Json
    $strategyAll = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_143_$($profile.Slug)_strategy_all.json") -Raw | ConvertFrom-Json
    $profileReports[$profile.Name] = [ordered]@{
        timed_turns = $profile.Turns
        timed_level = $profile.Level
        auto_d_save = Get-AutoRow $autoSave
        auto_d_all = Get-AutoRow $autoAll
        r_d_save = Get-StrategyRow $strategySave.strategies.r
        l_merge_d_save = Get-StrategyRow $strategySave.strategies.l_merge
        l_merge_d_all = Get-StrategyRow $strategyAll.strategies.l_merge
    }
}

$warnings = @()
foreach ($entry in $profileReports.H8.GetEnumerator()) {
    if ($entry.Key -in @("timed_turns", "timed_level")) { continue }
    if ([double]$entry.Value.success_ratio -lt 0.20 -or [double]$entry.Value.success_ratio -gt 0.80) {
        $warnings += "H8 $($entry.Key) success ratio outside 20-80%: $($entry.Value.success_ratio)"
    }
    if ([int]$entry.Value.departures -gt 0) {
        $warnings += "H8 $($entry.Key) departures: $($entry.Value.departures)"
    }
}
if ([double]$profileReports.H8.auto_d_save.turns_average -lt 176.4) {
    $warnings += "H8 auto D-save average turn below 176.4: $($profileReports.H8.auto_d_save.turns_average)"
}

$report = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    engine = "Godot 4.8-dev3 standard"
    conditions = "H8/H6/H10/H8-L2; auto seeds 101-120; strategy seeds 1-20; five bots; 600 turns; fixed 120 fps"
    profiles = $profileReports
    warnings = $warnings
}
$outputPath = Join-Path $measurementDirectory "timed_jelly_balance.json"
$report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $outputPath -Encoding utf8
Write-Output "TIMED_JELLY_BALANCE_REPORT $outputPath"
