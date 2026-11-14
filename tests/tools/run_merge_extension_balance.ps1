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
    [pscustomobject]@{ Slug = "e0"; Name = "E0"; Extension = 0.0 },
    [pscustomobject]@{ Slug = "e15"; Name = "E1.5"; Extension = 1.5 }
)

foreach ($profile in $profiles) {
    foreach ($mode in @("save", "all")) {
        $tapMode = if ($mode -eq "save") { "Save" } else { "All" }
        $autoLabel = "149_$($profile.Slug)_auto_$mode"
        $autoSummaryPath = Join-Path $repoPath "artifacts\jelly_physics_autoplay_$autoLabel.json"
        if (-not ($ReuseCompleted -and (Test-Path -LiteralPath $autoSummaryPath))) {
            $autoArguments = @{
                GodotPath = $GodotPath; RepoPath = $repoPath; Label = $autoLabel
                Parallelism = $Parallelism; MaxTurns = 600; LevelProfile = "D"
                TapBlastBotMode = $tapMode; SpawnCountMax = 4
                JellyMergeLevelGap = 1; JellyMergeWideGapMinLevel = 0
                JellyMergeExtensionMax = $profile.Extension
                JellyTapEffectModes = "Four"; TurnStartColors = 4; TurnColorUnlockTurns = "None"
                JellyTapCleanMaxLevel = 1; JellyTapCleanZoneRule = "On"; JellyTapRestCleanCount = 2
                JellyTimedEnabled = "On"; JellyTimedTurns = 4; JellyTimedLevel = 5
                JellyTimedBurstCount = 10; JellyTimedStoneEnabled = "On"; JellyTimedStoneTurns = 18
            }
            if ($AggregateOnly) { $autoArguments.AggregateOnly = $true }
            & $autoScript @autoArguments
        }

        $strategyLabel = "149_$($profile.Slug)_strategy_$mode"
        $strategyArguments = @{
            GodotPath = $GodotPath; SeedCount = 20; Parallelism = $Parallelism
            TurnCap = 600; LevelProfile = "D"; TapBlastBotMode = $tapMode
            SpawnCountMax = 4; JellyMergeLevelGap = 1; JellyMergeWideGapMinLevel = 0
            JellyMergeExtensionMax = $profile.Extension
            JellyTapEffectModes = "Four"; TurnStartColors = 4; TurnColorUnlockTurns = "None"
            JellyTapCleanMaxLevel = 1; JellyTapCleanZoneRule = "On"; JellyTapRestCleanCount = 2
            JellyTimedEnabled = "On"; JellyTimedTurns = 4; JellyTimedLevel = 5
            JellyTimedBurstCount = 10; JellyTimedStoneEnabled = "On"; JellyTimedStoneTurns = 18
            Strategies = if ($mode -eq "save") { "r,l_merge" } else { "l_merge" }
            MeasurementLabel = $strategyLabel
        }
        if ($ReuseCompleted) { $strategyArguments.ReuseCompleted = $true }
        if ($AggregateOnly) { $strategyArguments.AggregateOnly = $true }
        & $strategyScript @strategyArguments
    }
}

function Get-CommonRow($Summary, [bool]$Auto) {
    return [ordered]@{
        games = if ($Auto) { 20 } else { [int]$Summary.games }
        complete = [int]$Summary.game_over_count
        incomplete = [int]$Summary.incomplete_count
        turns_average = [double]$(if ($Auto) { $Summary.average_turns_all } else { $Summary.turns_average })
        turns_median = [double]$(if ($Auto) { $Summary.median_turns_all } else { $Summary.turns_median })
        score_average = [double]$(if ($Auto) { $Summary.average_score_all } else { $Summary.score_average })
        merges_per_turn = [double]$Summary.merges_per_turn
        blasts = [int]$(if ($Auto) { $Summary.blast_count } else { $Summary.blasts })
        timed_success_ratio = [double]$Summary.timed_jelly_success_ratio
        timed_stone_created_count = [int]$Summary.timed_stone_created_count
        input_waiting_touching_merge_turns = [int]$Summary.input_waiting_touching_merge_turns
        input_waiting_touching_merge_turn_ratio = [double]$Summary.input_waiting_touching_merge_turn_ratio
        average_touching_merge_pairs_per_affected_turn = [double]$Summary.average_touching_merge_pairs_per_affected_turn
        maximum_touching_merge_pairs_at_input_waiting = [int]$Summary.maximum_touching_merge_pairs_at_input_waiting
        deferred_jelly_merge_count = [int]$Summary.deferred_jelly_merge_count
        merge_extension_turn_ratio = [double]$Summary.merge_extension_turn_ratio
        average_merge_extension_seconds = [double]$Summary.average_merge_extension_seconds
        maximum_merge_extension_seconds = [double]$Summary.maximum_merge_extension_seconds
        merge_extension_capped_turns = [int]$Summary.merge_extension_capped_turns
        merge_extension_capped_turn_ratio = [double]$Summary.merge_extension_capped_turn_ratio
        average_turn_seconds = [double]$Summary.average_turn_seconds
        forced_settle_ratio = [double]$Summary.forced_settle_ratio
        departures = [int]$Summary.departures
    }
}

$profileReports = [ordered]@{}
foreach ($profile in $profiles) {
    $autoSave = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_149_$($profile.Slug)_auto_save.json") -Raw | ConvertFrom-Json
    $autoAll = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_149_$($profile.Slug)_auto_all.json") -Raw | ConvertFrom-Json
    $strategySave = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_149_$($profile.Slug)_strategy_save.json") -Raw | ConvertFrom-Json
    $strategyAll = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_149_$($profile.Slug)_strategy_all.json") -Raw | ConvertFrom-Json
    $profileReports[$profile.Name] = [ordered]@{
        extension_seconds = $profile.Extension
        auto_d_save = Get-CommonRow $autoSave $true
        auto_d_all = Get-CommonRow $autoAll $true
        r_d_save = Get-CommonRow $strategySave.strategies.r $false
        l_merge_d_save = Get-CommonRow $strategySave.strategies.l_merge $false
        l_merge_d_all = Get-CommonRow $strategyAll.strategies.l_merge $false
    }
}

$warnings = @()
foreach ($botName in @("auto_d_save", "auto_d_all", "r_d_save", "l_merge_d_save", "l_merge_d_all")) {
    $baseline = $profileReports.E0[$botName]
    $extended = $profileReports.'E1.5'[$botName]
    if ([double]$extended.input_waiting_touching_merge_turn_ratio -gt 0.005) {
        $warnings += "$botName input-wait touching pair ratio exceeds 0.5%"
    }
    if (([double]$extended.average_turn_seconds - [double]$baseline.average_turn_seconds) -ge 0.2) {
        $warnings += "$botName average turn time increased by at least 0.2 seconds"
    }
    if ([double]$extended.merge_extension_capped_turn_ratio -gt 0.01) {
        $warnings += "$botName extension cap ratio exceeds 1%"
    }
    if ([int]$extended.departures -ge 1) {
        $warnings += "$botName has one or more departures"
    }
}

$report = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    engine = "Godot 4.8-dev3 standard"
    conditions = "E0/E1.5; timed L5-4; stone 18; auto seeds 101-120; strategy seeds 1-20; five bots; 600 turns; fixed 120 fps; total 200 games"
    profiles = $profileReports
    warnings = $warnings
}
$outputPath = Join-Path $measurementDirectory "merge_extension_balance.json"
$report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $outputPath -Encoding utf8
Write-Output "MERGE_EXTENSION_BALANCE_REPORT $outputPath"
