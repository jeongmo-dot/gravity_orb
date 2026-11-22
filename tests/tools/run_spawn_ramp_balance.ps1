param(
    [string]$GodotPath = "",
    [ValidateRange(1, 8)]
    [int]$Parallelism = 4,
    [ValidatePattern('^(4|8|10|0)(,(4|8|10|0))*$')]
    [string]$CandidateCaps = "4,8,10,0",
    [ValidateRange(-1, 10)]
    [int]$JellyBlastPairTopMinLevel = -1,
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
$caps = @($CandidateCaps.Split(',') | ForEach-Object { [int]$_ })

function Invoke-Candidate([int]$Cap) {
    $slug = "155_gap2_p$Cap"
    foreach ($mode in @("save", "all")) {
        $tapMode = if ($mode -eq "save") { "Save" } else { "All" }
        $autoLabel = "${slug}_auto_$mode"
        $autoSummaryPath = Join-Path $repoPath "artifacts\jelly_physics_autoplay_$autoLabel.json"
        if (-not ($ReuseCompleted -and (Test-Path -LiteralPath $autoSummaryPath))) {
            $autoArguments = @{
                GodotPath = $GodotPath
                RepoPath = $repoPath
                Label = $autoLabel
                Parallelism = $Parallelism
                SeedCount = 20
                MaxTurns = 600
                LevelProfile = "D"
                TapBlastBotMode = $tapMode
                SpawnCountMax = $Cap
                JellyMergeLevelGap = 2
                JellyBlastMinLevel = 9
                JellyTapBlastMinLevel = 9
            }
            if ($JellyBlastPairTopMinLevel -ge 0) {
                $autoArguments.JellyBlastPairTopMinLevel = $JellyBlastPairTopMinLevel
            }
            if ($AggregateOnly) { $autoArguments.AggregateOnly = $true }
            & $autoScript @autoArguments
        }

        $strategyLabel = "${slug}_strategy_$mode"
        $strategyArguments = @{
            GodotPath = $GodotPath
            SeedCount = 20
            Parallelism = $Parallelism
            TurnCap = 600
            LevelProfile = "D"
            TapBlastBotMode = $tapMode
            SpawnCountMax = $Cap
            JellyMergeLevelGap = 2
            JellyBlastMinLevel = 9
            JellyTapBlastMinLevel = 9
            Strategies = if ($mode -eq "save") { "r,l_merge" } else { "l_merge" }
            MeasurementLabel = $strategyLabel
        }
        if ($JellyBlastPairTopMinLevel -ge 0) {
            $strategyArguments.JellyBlastPairTopMinLevel = $JellyBlastPairTopMinLevel
        }
        if ($ReuseCompleted) { $strategyArguments.ReuseCompleted = $true }
        if ($AggregateOnly) { $strategyArguments.AggregateOnly = $true }
        & $strategyScript @strategyArguments
    }
}

foreach ($cap in $caps) {
    Invoke-Candidate $cap
}

function Get-LevelCount($Counts, [string]$Level) {
    if ($null -eq $Counts) { return 0 }
    $property = $Counts.PSObject.Properties[$Level]
    if ($null -eq $property) { return 0 }
    return [int]$property.Value
}

function Get-SettingMismatch($Summary, [int]$Cap) {
    $mismatches = @()
    $expectedPairTop = if ($JellyBlastPairTopMinLevel -ge 0) { $JellyBlastPairTopMinLevel } else { 0 }
    if ([int]$Summary.jelly_merge_level_gap -ne 2) { $mismatches += "jelly_merge_level_gap" }
    if ([int]$Summary.jelly_timed_merge_level_gap -ne -1) { $mismatches += "jelly_timed_merge_level_gap" }
    if ([int]$Summary.jelly_blast_min_level -ne 9) { $mismatches += "jelly_blast_min_level" }
    if ([int]$Summary.jelly_blast_pair_top_min_level -ne $expectedPairTop) { $mismatches += "jelly_blast_pair_top_min_level" }
    if ([int]$Summary.jelly_tap_blast_min_level -ne 9) { $mismatches += "jelly_tap_blast_min_level" }
    if ([int]$Summary.spawn_count_max -ne $Cap) { $mismatches += "spawn_count_max" }
    return $mismatches
}

function Get-AutoRow($Summary, [string]$Bot) {
    $games = @($Summary.seeds).Count
    return [ordered]@{
        bot = $Bot
        games = $games
        turns_average = [double]$Summary.average_turns_all
        incomplete = [int]$Summary.incomplete_count
        completed_turns_average = [double]$Summary.average_game_over_turns
        blasts_per_game = [double]$Summary.average_blasts_per_game
        tap_blasts_l9_per_game = [double](Get-LevelCount $Summary.tap_blast_count_by_level "L9") / $games
        tap_blasts_l10_per_game = [double](Get-LevelCount $Summary.tap_blast_count_by_level "L10") / $games
        first_blast_turn_median = $Summary.first_blast_turn_median
        zero_blast_games = [int]$Summary.zero_blast_game_count
        blasts_through_turn_200_per_game = [double]$Summary.average_blasts_through_turn_200_per_game
        level_nine_creations_per_game = [double](Get-LevelCount $Summary.level_creation_count_by_level "L9") / $games
        level_ten_creations_per_game = [double](Get-LevelCount $Summary.level_creation_count_by_level "L10") / $games
        blast_pairs_l9_l10_per_game = [double](Get-LevelCount $Summary.blast_count_by_pair_levels "L9+L10") / $games
        blast_pairs_l10_l10_per_game = [double](Get-LevelCount $Summary.blast_count_by_pair_levels "L10+L10") / $games
        score_average = [double]$Summary.average_score_all
        timed_success_ratio = [double]$Summary.timed_jelly_success_ratio
        timed_stones_per_game = [double]$Summary.timed_stone_per_game
        level_eight_plus_per_game = [double]$Summary.average_level_eight_plus_creations_per_game
        game_over_spawn_count_average = [double]$Summary.average_game_over_spawn_count
        maximum_active_orbs = [int]$Summary.maximum_active_sample.active_orbs
        maximum_active_orbs_turn = [int]$Summary.maximum_active_sample.turn
        maximum_physics_ms = [double]$Summary.maximum_peak_active_physics_ms
        departures = [int]$Summary.departures
        maximum_penetration_px = [double]$Summary.max_turn_end_pair_penetration_px
    }
}

function Get-StrategyRow($Summary, [string]$Bot) {
    $games = [int]$Summary.games
    return [ordered]@{
        bot = $Bot
        games = $games
        turns_average = [double]$Summary.turns_average
        incomplete = [int]$Summary.incomplete_count
        completed_turns_average = $Summary.completed_turns_average
        blasts_per_game = [double]$Summary.average_blasts_per_game
        tap_blasts_l9_per_game = [double](Get-LevelCount $Summary.tap_blast_count_by_level "L9") / $games
        tap_blasts_l10_per_game = [double](Get-LevelCount $Summary.tap_blast_count_by_level "L10") / $games
        first_blast_turn_median = $Summary.first_blast_turn_median
        zero_blast_games = [int]$Summary.zero_blast_game_count
        blasts_through_turn_200_per_game = [double]$Summary.average_blasts_through_turn_200_per_game
        level_nine_creations_per_game = [double](Get-LevelCount $Summary.level_creation_count_by_level "L9") / $games
        level_ten_creations_per_game = [double](Get-LevelCount $Summary.level_creation_count_by_level "L10") / $games
        blast_pairs_l9_l10_per_game = [double](Get-LevelCount $Summary.blast_count_by_pair_levels "L9+L10") / $games
        blast_pairs_l10_l10_per_game = [double](Get-LevelCount $Summary.blast_count_by_pair_levels "L10+L10") / $games
        score_average = [double]$Summary.score_average
        timed_success_ratio = [double]$Summary.timed_jelly_success_ratio
        timed_stones_per_game = [double]$Summary.timed_stone_created_per_game
        level_eight_plus_per_game = [double]$Summary.average_level_eight_plus_creations_per_game
        game_over_spawn_count_average = $Summary.average_game_over_spawn_count
        maximum_active_orbs = [int]$Summary.maximum_active_sample.active_orbs
        maximum_active_orbs_turn = [int]$Summary.maximum_active_sample.turn
        maximum_physics_ms = [double]$Summary.maximum_peak_active_physics_ms
        departures = [int]$Summary.departures
        maximum_penetration_px = [double]$Summary.maximum_pair_penetration_px
    }
}

$candidates = @()
foreach ($cap in $caps) {
    $slug = "155_gap2_p$Cap"
    $autoSave = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_${slug}_auto_save.json") -Raw | ConvertFrom-Json
    $autoAll = Get-Content -LiteralPath (Join-Path $repoPath "artifacts\jelly_physics_autoplay_${slug}_auto_all.json") -Raw | ConvertFrom-Json
    $strategySave = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_${slug}_strategy_save.json") -Raw | ConvertFrom-Json
    $strategyAll = Get-Content -LiteralPath (Join-Path $measurementDirectory "jelly_rules_measurement_${slug}_strategy_all.json") -Raw | ConvertFrom-Json
    $mismatches = @(
        Get-SettingMismatch $autoSave $cap
        Get-SettingMismatch $autoAll $cap
        Get-SettingMismatch $strategySave $cap
        Get-SettingMismatch $strategyAll $cap
    ) | Select-Object -Unique
    if ($mismatches.Count -gt 0) {
        throw "GAP2-P$Cap setting mismatch: $($mismatches -join ', ')"
    }
    $rows = [ordered]@{
        auto_d_save = Get-AutoRow $autoSave "auto_d_save"
        auto_d_all = Get-AutoRow $autoAll "auto_d_all"
        r_d_save = Get-StrategyRow $strategySave.strategies.r "r_d_save"
        l_merge_d_save = Get-StrategyRow $strategySave.strategies.l_merge "l_merge_d_save"
        l_merge_d_all = Get-StrategyRow $strategyAll.strategies.l_merge "l_merge_d_all"
    }
    $dSaveEligible = (
        $rows.auto_d_save.incomplete -le 1 -and
        $rows.r_d_save.incomplete -le 1 -and
        $rows.l_merge_d_save.incomplete -le 1
    )
    $safetyObserved = @($rows.Values | Where-Object {
        $_.departures -gt 0 -or $_.maximum_penetration_px -ge 30.0
    }).Count -gt 0
    $candidates += [pscustomobject][ordered]@{
        name = "GAP2-P$Cap"
        spawn_count_max = $cap
        settings = [ordered]@{
            jelly_merge_level_gap = 2
            jelly_timed_merge_level_gap = -1
            jelly_blast_min_level = 9
            jelly_blast_pair_top_min_level = if ($JellyBlastPairTopMinLevel -ge 0) { $JellyBlastPairTopMinLevel } else { 0 }
            jelly_tap_blast_min_level = 9
        }
        rows = $rows
        d_save_eligible = $dSaveEligible
        safety_warning = $safetyObserved
    }
}

$eligible = @($candidates | Where-Object { $_.d_save_eligible })
$topCandidate = @($eligible | Sort-Object { [double]$_.rows.auto_d_save.blasts_per_game } -Descending | Select-Object -First 1)
$topBlastRate = if ($topCandidate.Count -gt 0) {
    [double]$topCandidate[0].rows.auto_d_save.blasts_per_game
} else { $null }
$leaders = if ($null -ne $topBlastRate) {
    @($eligible | Where-Object {
        [Math]::Abs([double]$_.rows.auto_d_save.blasts_per_game - $topBlastRate) -lt 0.000001
    })
} else { @() }
$references = [ordered]@{}
foreach ($reference in @(
    [pscustomobject]@{ Name = "GAP2-A4"; Slug = "155_gap2_a4"; Blast = 10; Tap = 9 },
    [pscustomobject]@{ Name = "GAP2-B9"; Slug = "155_gap2_b9"; Blast = 9; Tap = 8 },
    [pscustomobject]@{ Name = "GAP2-T9"; Slug = "155_gap2_t9"; Blast = 8; Tap = 9 }
)) {
    $autoSavePath = Join-Path $repoPath "artifacts\jelly_physics_autoplay_$($reference.Slug)_auto_save.json"
    $autoAllPath = Join-Path $repoPath "artifacts\jelly_physics_autoplay_$($reference.Slug)_auto_all.json"
    $strategySavePath = Join-Path $measurementDirectory "jelly_rules_measurement_$($reference.Slug)_strategy_save.json"
    $strategyAllPath = Join-Path $measurementDirectory "jelly_rules_measurement_$($reference.Slug)_strategy_all.json"
    $referencePaths = @($autoSavePath, $autoAllPath, $strategySavePath, $strategyAllPath)
    if (@($referencePaths | Where-Object { -not (Test-Path -LiteralPath $_) }).Count -gt 0) {
        continue
    }
    $autoSave = Get-Content -LiteralPath $autoSavePath -Raw | ConvertFrom-Json
    $autoAll = Get-Content -LiteralPath $autoAllPath -Raw | ConvertFrom-Json
    $strategySave = Get-Content -LiteralPath $strategySavePath -Raw | ConvertFrom-Json
    $strategyAll = Get-Content -LiteralPath $strategyAllPath -Raw | ConvertFrom-Json
    $references[$reference.Name] = [ordered]@{
        settings = [ordered]@{
            spawn_count_max = 4
            jelly_merge_level_gap = 2
            jelly_timed_merge_level_gap = -1
            jelly_blast_min_level = $reference.Blast
            jelly_blast_pair_top_min_level = 0
            jelly_tap_blast_min_level = $reference.Tap
        }
        rows = [ordered]@{
            auto_d_save = Get-AutoRow $autoSave "auto_d_save"
            auto_d_all = Get-AutoRow $autoAll "auto_d_all"
            r_d_save = Get-StrategyRow $strategySave.strategies.r "r_d_save"
            l_merge_d_save = Get-StrategyRow $strategySave.strategies.l_merge "l_merge_d_save"
            l_merge_d_all = Get-StrategyRow $strategyAll.strategies.l_merge "l_merge_d_all"
        }
    }
}
$report = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    engine = "Godot 4.8-dev3 standard"
    conditions = "GAP2; timed gap -1; blast min L9 with pair top L$(if ($JellyBlastPairTopMinLevel -ge 0) { $JellyBlastPairTopMinLevel } else { 0 }); tap L9; five bots x 20 games; 600 turns; fixed 120 fps"
    candidates = $candidates
    references = $references
    eligible_names = @($eligible | ForEach-Object { $_.name })
    criterion_leader = if ($leaders.Count -eq 1) { $leaders[0].name } else { $null }
    criterion_leaders = @($leaders | ForEach-Object { $_.name })
}
$outputPath = Join-Path $measurementDirectory "spawn_ramp_pair_balance.json"
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $outputPath -Encoding utf8
Write-Output "SPAWN_RAMP_BALANCE_REPORT $outputPath"
