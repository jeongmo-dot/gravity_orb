param(
    [string]$GodotPath = "",
    [ValidateRange(1, 16)]
    [int]$Parallelism = 4,
    [switch]$ReuseCompleted,
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = if ([string]::IsNullOrWhiteSpace($env:GODOT)) {
        "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
    } else { $env:GODOT }
}
$autoScript = Join-Path $repoPath "tests\run_jelly_physics_autoplay.ps1"
$strategyScript = Join-Path $PSScriptRoot "run_jelly_measurement.ps1"
$measurementDirectory = Join-Path $repoPath "artifacts\measurements"
New-Item -ItemType Directory -Path $measurementDirectory -Force | Out-Null

$profiles = @(
    [pscustomobject]@{ Slug = "s6"; Name = "S6"; StoneTurns = 6 },
    [pscustomobject]@{ Slug = "s12"; Name = "S12"; StoneTurns = 12 },
    [pscustomobject]@{ Slug = "s18"; Name = "S18"; StoneTurns = 18 }
)

foreach ($profile in $profiles) {
    foreach ($mode in @("save", "all")) {
        $tapMode = if ($mode -eq "save") { "Save" } else { "All" }
        $autoLabel = "147_$($profile.Slug)_auto_$mode"
        $autoSummaryPath = Join-Path $repoPath "artifacts\jelly_physics_autoplay_$autoLabel.json"
        if (-not ($ReuseCompleted -and (Test-Path -LiteralPath $autoSummaryPath))) {
            $autoArguments = @{
                GodotPath = $GodotPath; RepoPath = $repoPath; Label = $autoLabel
                Parallelism = $Parallelism; MaxTurns = 600; LevelProfile = "D"
                TapBlastBotMode = $tapMode; SpawnCountMax = 4
                JellyMergeLevelGap = 1; JellyMergeWideGapMinLevel = 0
                JellyTapEffectModes = "Four"; TurnStartColors = 4; TurnColorUnlockTurns = "None"
                JellyTapCleanMaxLevel = 1; JellyTapCleanZoneRule = "On"; JellyTapRestCleanCount = 2
                JellyTimedEnabled = "On"; JellyTimedTurns = 4; JellyTimedLevel = 5
                JellyTimedBurstCount = 10; JellyTimedStoneEnabled = "On"
                JellyTimedStoneTurns = $profile.StoneTurns
            }
            if ($AggregateOnly) { $autoArguments.AggregateOnly = $true }
            & $autoScript @autoArguments
        }

        $strategyLabel = "147_$($profile.Slug)_strategy_$mode"
        $strategyArguments = @{
            GodotPath = $GodotPath; SeedCount = 20; Parallelism = $Parallelism
            TurnCap = 600; LevelProfile = "D"; TapBlastBotMode = $tapMode
            SpawnCountMax = 4; JellyMergeLevelGap = 1; JellyMergeWideGapMinLevel = 0
            JellyTapEffectModes = "Four"; TurnStartColors = 4; TurnColorUnlockTurns = "None"
            JellyTapCleanMaxLevel = 1; JellyTapCleanZoneRule = "On"; JellyTapRestCleanCount = 2
            JellyTimedEnabled = "On"; JellyTimedTurns = 4; JellyTimedLevel = 5
            JellyTimedBurstCount = 10; JellyTimedStoneEnabled = "On"
            JellyTimedStoneTurns = $profile.StoneTurns
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
        stone_created_count = [int]$Summary.timed_stone_created_count
        stone_per_game = [double]$(if ($null -ne $Summary.timed_stone_created_per_game) { $Summary.timed_stone_created_per_game } else { $Summary.timed_stone_per_game })
        stone_max_concurrent = [int]$Summary.timed_stone_max_concurrent
        stone_remaining_count = [int]$Summary.timed_stone_remaining_count
        stone_remaining_per_game = [double]$Summary.timed_stone_remaining_per_game
        stone_reaction_count = [int]$Summary.timed_stone_reaction_count
    }
}

function Get-AutoRow($Summary) {
    $row = [ordered]@{
        games = 20; complete = [int]$Summary.game_over_count; incomplete = [int]$Summary.incomplete_count
        turns_average = [double]$Summary.average_turns_all; turns_median = [double]$Summary.median_turns_all
        turns_minimum = [double]$Summary.minimum_turns_all; turns_maximum = [double]$Summary.maximum_turns_all
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
        games = [int]$Summary.games; complete = [int]$Summary.game_over_count; incomplete = [int]$Summary.incomplete_count
        turns_average = [double]$Summary.turns_average; turns_median = [double]$Summary.turns_median
        turns_minimum = [double]$Summary.turns_minimum; turns_maximum = [double]$Summary.turns_maximum
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
    $autoSave = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_147_$($profile.Slug)_auto_save.json") -Raw | ConvertFrom-Json
    $autoAll = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_147_$($profile.Slug)_auto_all.json") -Raw | ConvertFrom-Json
    $strategySave = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_147_$($profile.Slug)_strategy_save.json") -Raw | ConvertFrom-Json
    $strategyAll = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_147_$($profile.Slug)_strategy_all.json") -Raw | ConvertFrom-Json
    $profileReports[$profile.Name] = [ordered]@{
        timed_turns = 4; timed_level = 5; timed_burst_count = 10; stone_turns = $profile.StoneTurns
        auto_d_save = Get-AutoRow $autoSave; auto_d_all = Get-AutoRow $autoAll
        r_d_save = Get-StrategyRow $strategySave.strategies.r
        l_merge_d_save = Get-StrategyRow $strategySave.strategies.l_merge
        l_merge_d_all = Get-StrategyRow $strategyAll.strategies.l_merge
    }
}

$baseline = [ordered]@{
    name = "#145 K5-4"
    auto_d_save_success_ratio = 0.4976958525345622
    r_d_save_success_ratio = 0.4620938628158845
    auto_d_save_turns_average = 273.4
    average_success_ratio = 0.47989485767522333
}
$eligibleProfiles = @()
foreach ($profile in $profiles) {
    $profileReport = $profileReports[$profile.Name]
    $autoSuccess = [double]$profileReport.auto_d_save.success_ratio
    $rSuccess = [double]$profileReport.r_d_save.success_ratio
    if ($autoSuccess -ge 0.4 -and $autoSuccess -le 0.6 -and $rSuccess -ge 0.4 -and $rSuccess -le 0.6 -and [double]$profileReport.auto_d_save.turns_average -ge 176.4) {
        $eligibleProfiles += [pscustomobject]@{
            Name = $profile.Name; StoneTurns = $profile.StoneTurns
            AutoSuccess = $autoSuccess; RSuccess = $rSuccess
            AutoTurns = [double]$profileReport.auto_d_save.turns_average
            AverageSuccess = ($autoSuccess + $rSuccess) / 2.0
        }
    }
}
$fallbackUsed = $eligibleProfiles.Count -eq 0
$selectedProfile = if ($fallbackUsed) { [pscustomobject]@{ Name = "S6"; StoneTurns = 6 } } else { @($eligibleProfiles | Sort-Object StoneTurns -Descending | Select-Object -First 1)[0] }
$warnings = @()
if ($fallbackUsed) { $warnings += "No profile meets both 40-60% success ratios and auto D-save average turns >= 176.4; selected S6 fallback" }
foreach ($profileEntry in $profileReports.GetEnumerator()) {
    foreach ($rowEntry in $profileEntry.Value.GetEnumerator()) {
        if ($rowEntry.Key -in @("timed_turns", "timed_level", "timed_burst_count", "stone_turns")) { continue }
        if ([int]$rowEntry.Value.departures -gt 0) { $warnings += "$($profileEntry.Key) $($rowEntry.Key) departures: $($rowEntry.Value.departures)" }
        if ([int]$rowEntry.Value.stone_reaction_count -gt 0) { $warnings += "$($profileEntry.Key) $($rowEntry.Key) stone reactions: $($rowEntry.Value.stone_reaction_count)" }
    }
}

$report = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    engine = "Godot 4.8-dev3 standard"
    conditions = "S6/S12/S18; timed K5-4; auto seeds 101-120; strategy seeds 1-20; five bots; 600 turns; fixed 120 fps; total 300 games"
    baseline_145_k5_4 = $baseline
    profiles = $profileReports
    selection = [ordered]@{
        criteria = "auto D-save and R D-save success 40-60%; auto D-save average turns >= 176.4; select longest eligible stone duration"
        eligible_profile_names = @($eligibleProfiles | ForEach-Object { $_.Name })
        selected_profile_name = $selectedProfile.Name
        selected_stone_turns = $selectedProfile.StoneTurns
        fallback_used = $fallbackUsed
    }
    warnings = $warnings
}
$outputPath = Join-Path $measurementDirectory "timed_jelly_stone_balance.json"
$report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $outputPath -Encoding utf8
Write-Output "TIMED_JELLY_STONE_BALANCE_REPORT $outputPath"
