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
    } else {
        $env:GODOT
    }
}
$autoScript = Join-Path $repoPath "tests\run_jelly_physics_autoplay.ps1"
$strategyScript = Join-Path $PSScriptRoot "run_jelly_measurement.ps1"
$measurementDirectory = Join-Path $repoPath "artifacts\measurements"
New-Item -ItemType Directory -Path $measurementDirectory -Force | Out-Null

$profiles = @(
    [pscustomobject]@{ Slug = "b10"; Name = "B10"; Turns = 4; Level = 5; BurstCount = 10 },
    [pscustomobject]@{ Slug = "b8"; Name = "B8"; Turns = 4; Level = 5; BurstCount = 8 },
    [pscustomobject]@{ Slug = "b6"; Name = "B6"; Turns = 4; Level = 5; BurstCount = 6 }
)

foreach ($profile in $profiles) {
    foreach ($mode in @("save", "all")) {
        $tapMode = if ($mode -eq "save") { "Save" } else { "All" }
        $autoLabel = "146_$($profile.Slug)_auto_$mode"
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
                JellyTimedBurstCount = $profile.BurstCount
                JellyTimedBurstOtherColors = "On"
            }
            if ($AggregateOnly) { $autoArguments.AggregateOnly = $true }
            & $autoScript @autoArguments
        }

        $strategyLabel = "146_$($profile.Slug)_strategy_$mode"
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
            JellyTimedBurstCount = $profile.BurstCount
            JellyTimedBurstOtherColors = "On"
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
        burst_internal_merges_per_game = [double]$Summary.timed_burst_internal_merges_per_game
        burst_internal_merges_per_timeout = [double]$Summary.timed_burst_internal_merges_per_timeout
        burst_board_merges_per_game = [double]$Summary.timed_burst_board_merges_per_game
        burst_board_merges_per_timeout = [double]$Summary.timed_burst_board_merges_per_timeout
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
    $autoSave = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_146_$($profile.Slug)_auto_save.json") -Raw | ConvertFrom-Json
    $autoAll = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_146_$($profile.Slug)_auto_all.json") -Raw | ConvertFrom-Json
    $strategySave = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_146_$($profile.Slug)_strategy_save.json") -Raw | ConvertFrom-Json
    $strategyAll = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_146_$($profile.Slug)_strategy_all.json") -Raw | ConvertFrom-Json
    $profileReports[$profile.Name] = [ordered]@{
        timed_turns = $profile.Turns
        timed_level = $profile.Level
        timed_burst_count = $profile.BurstCount
        auto_d_save = Get-AutoRow $autoSave
        auto_d_all = Get-AutoRow $autoAll
        r_d_save = Get-StrategyRow $strategySave.strategies.r
        l_merge_d_save = Get-StrategyRow $strategySave.strategies.l_merge
        l_merge_d_all = Get-StrategyRow $strategyAll.strategies.l_merge
    }
}

$baseline = [pscustomobject]@{
    Name = "#145 K5-4 same-color B10"
    Level = 5
    Turns = 4
    BurstCount = 10
    AutoSuccess = 0.4976958525345622
    RSuccess = 0.4620938628158845
    AutoTurns = 273.4
    AverageSuccess = 0.47989485767522333
}
$eligibleProfiles = @()
foreach ($profile in $profiles) {
    $profileReport = $profileReports[$profile.Name]
    $autoSuccess = [double]$profileReport.auto_d_save.success_ratio
    $rSuccess = [double]$profileReport.r_d_save.success_ratio
    $averageSuccess = ($autoSuccess + $rSuccess) / 2.0
    $candidate = [pscustomobject]@{
        Name = $profile.Name
        Level = $profile.Level
        Turns = $profile.Turns
        BurstCount = $profile.BurstCount
        AutoSuccess = $autoSuccess
        RSuccess = $rSuccess
        AutoTurns = [double]$profileReport.auto_d_save.turns_average
        AverageSuccess = $averageSuccess
        DistanceFromHalf = [Math]::Abs($averageSuccess - 0.5)
    }
    if (
        $autoSuccess -ge 0.4 -and $autoSuccess -le 0.6 -and
        $rSuccess -ge 0.4 -and $rSuccess -le 0.6 -and
        $candidate.AutoTurns -ge 176.4
    ) {
        $eligibleProfiles += $candidate
    }
}
$selectedProfile = if ($eligibleProfiles.Count -gt 0) {
    @(
        $eligibleProfiles |
            Sort-Object @{ Expression = "BurstCount"; Descending = $true } |
            Select-Object -First 1
    )[0]
} else {
    @($profiles | Where-Object { $_.Name -eq "B10" } | ForEach-Object {
        [pscustomobject]@{
            Name = $_.Name
            Level = $_.Level
            Turns = $_.Turns
            BurstCount = $_.BurstCount
            AutoSuccess = [double]$profileReports[$_.Name].auto_d_save.success_ratio
            RSuccess = [double]$profileReports[$_.Name].r_d_save.success_ratio
            AutoTurns = [double]$profileReports[$_.Name].auto_d_save.turns_average
            AverageSuccess = ([double]$profileReports[$_.Name].auto_d_save.success_ratio + [double]$profileReports[$_.Name].r_d_save.success_ratio) / 2.0
        }
    })[0]
}
$warnings = @()
if ($eligibleProfiles.Count -eq 0) {
    $warnings += "No profile meets both 40-60% success ratios and auto D-save average turns >= 176.4; keep B10"
}
foreach ($profileEntry in $profileReports.GetEnumerator()) {
    foreach ($rowEntry in $profileEntry.Value.GetEnumerator()) {
        if ($rowEntry.Key -in @("timed_turns", "timed_level", "timed_burst_count")) { continue }
        if ([int]$rowEntry.Value.departures -gt 0) {
            $warnings += "$($profileEntry.Key) $($rowEntry.Key) departures: $($rowEntry.Value.departures)"
        }
        if ([double]$rowEntry.Value.burst_internal_merges_per_timeout -ge 1.0) {
            $warnings += "$($profileEntry.Key) $($rowEntry.Key) burst-burst merges per timeout: $($rowEntry.Value.burst_internal_merges_per_timeout)"
        }
    }
}

$report = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    engine = "Godot 4.8-dev3 standard"
    conditions = "B10/B8/B6 other-color L1; L5/4 turns; #145 K5-4 same-color B10 baseline not rerun; auto seeds 101-120; strategy seeds 1-20; five bots; 600 turns; fixed 120 fps"
    baseline_145_k5_4 = $baseline
    profiles = $profileReports
    selection = [ordered]@{
        eligible_profile_names = @($eligibleProfiles | ForEach-Object { $_.Name })
        selected_profile_name = $selectedProfile.Name
        selected_level = $selectedProfile.Level
        selected_turns = $selectedProfile.Turns
        selected_burst_count = $selectedProfile.BurstCount
        selected_average_success_ratio = $selectedProfile.AverageSuccess
    }
    warnings = $warnings
}
$outputPath = Join-Path $measurementDirectory "timed_jelly_burst_color_balance.json"
$report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $outputPath -Encoding utf8
Write-Output "TIMED_JELLY_BALANCE_REPORT $outputPath"
