param(
    [string]$GodotPath = "",
    [ValidateRange(1, 20)]
    [int]$SeedCount = 20,
    [ValidateRange(1, 8)]
    [int]$Parallelism = 3,
    [ValidateRange(1, 600)]
    [int]$TurnCap = 600,
	[ValidateSet("D", "M", "A", "B")]
	[string]$LevelProfile = "D",
	[switch]$TapBlastBot,
	[ValidateSet("None", "Save", "All")]
	[string]$TapBlastBotMode = "None",
	[ValidateRange(0, 10)]
	[int]$JellyMergeLevelGap = 1,
	[ValidateRange(0, 10)]
	[int]$JellyMergeWideGapMinLevel = 0,
	[ValidateRange(0, 10)]
	[int]$JellyBlastMinLevel = 8,
	[ValidateRange(0, 10)]
	[int]$JellyTapBlastMinLevel = 8,
	[ValidateRange(0.0, 100.0)]
	[double]$BlastScoreFactor = 15.0,
	[ValidateRange(0.0, 100.0)]
	[double]$JellyTapBlastScoreFactor = 0.5,
	[ValidateSet("On", "Off")]
	[string]$JellyTapBlastUsesTurn = "On",
	[ValidateRange(0, 10)]
	[int]$JellyTapCleanMaxLevel = 2,
	[ValidateRange(0, 100)]
	[int]$JellyTapGrowMinClean = 3,
	[ValidateSet("Push", "None", "Color")]
	[string]$JellyTapEffectModes = "Color",
	[ValidateSet("On", "Off")]
	[string]$JellyBlastRequiresSameLevel = "Off",
	[ValidateSet("On", "Off")]
	[string]$JellyTapCommonPush = "On",
	[ValidateRange(0.0, 10000.0)]
	[double]$JellyTapLiftSpeed = 0.0,
	[ValidateRange(0.0, 1.0)]
	[double]$JellyTapPushRadiusFactor = 0.5,
	[ValidateRange(0.0, 10000.0)]
	[double]$JellyTapPushSpeed = 1800.0,
	[ValidateRange(0.0, 10.0)]
	[double]$BlastGravityPauseTime = 0.2,
	[ValidateRange(0.0, 10000.0)]
	[double]$BlastSpeed = 1350.0,
	[ValidateRange(0.0, 1.0)]
	[double]$BlastFarFactor = 0.5,
	[string]$OrbFrictionByLevel = "0.3,0.3,0.3,0.4,0.4,0.4,0.4,0.5,0.5,0.5",
	[ValidateRange(1, 100)]
	[int]$SpawnCountMax = 4,
	[string]$Strategies = "r,g,l_merge",
	[string]$MeasurementLabel = "",
    [switch]$ReuseCompleted,
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$resolvedTapBlastBotMode = if ($TapBlastBot -and $TapBlastBotMode -eq "None") { "All" } else { $TapBlastBotMode }
if ($OrbFrictionByLevel -ne "none" -and $OrbFrictionByLevel -notmatch '^\d+(\.\d+)?(,\d+(\.\d+)?)*$') {
	throw "OrbFrictionByLevel must be 'none' or comma-separated non-negative numbers"
}
$resolvedStrategies = @($Strategies.Split(',') | ForEach-Object { $_.Trim().ToLower() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($resolvedStrategies.Count -eq 0 -or @($resolvedStrategies | Where-Object { $_ -notin @('r', 'g', 'l_merge') }).Count -gt 0) {
	throw "Strategies must be a comma-separated subset of r,g,l_merge"
}
$repoPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$outputDirectory = Join-Path $repoPath "artifacts\measurements"
$measurementLabel = if ([string]::IsNullOrWhiteSpace($MeasurementLabel)) {
	"$($LevelProfile.ToLower())$(if ($TapBlastBot) { '1' } else { '0' })"
} else {
	$MeasurementLabel.ToLower()
}
$summaryPath = Join-Path $outputDirectory "jelly_rules_measurement_$measurementLabel.json"
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
        $GodotPath = $env:GODOT
    } else {
        $GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
    }
}
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

function Get-SeedShards([int]$Count, [int]$Size) {
    $result = @()
    for ($start = 1; $start -le $Count; $start += $Size) {
        $end = [Math]::Min($start + $Size - 1, $Count)
        $result += [pscustomobject]@{ Start = $start; End = $end; Csv = (@($start..$end) -join ",") }
    }
    return $result
}

if (-not $AggregateOnly) {
    $tasks = @()
	foreach ($strategy in $resolvedStrategies) {
        # Keep each Godot worker below the desktop task runner's process window.
        # A single 600-turn seed can already take more than one minute.
        $shardSize = 1
        foreach ($shard in @(Get-SeedShards $SeedCount $shardSize)) {
            $name = "jelly_${measurementLabel}_${strategy}_part$($shard.Start)-$($shard.End)"
            $output = Join-Path $outputDirectory "$name.json"
            $tasks += [pscustomobject]@{
                Name = $name
                Output = $output
                Stdout = Join-Path $outputDirectory "$name.stdout.log"
                Stderr = Join-Path $outputDirectory "$name.stderr.log"
                Arguments = @(
                    "--headless", "--path", $repoPath, "--fixed-fps", "120", "--audio-driver", "Dummy",
                    "--log-file", (Join-Path $outputDirectory "$name.godot.log"),
                    "res://tests/spike/JoltMeasurement.tscn", "--",
                    "--game-mode=jelly", "--jolt-ticks=120", "--jolt-seeds=$($shard.Csv)",
                    "--jolt-max-turns=$TurnCap", "--jolt-no-determinism", "--skill-strategy=$strategy",
					"--jelly-level-profile=$LevelProfile",
					"--jelly-merge-level-gap=$JellyMergeLevelGap",
					"--jelly-merge-wide-gap-min-level=$JellyMergeWideGapMinLevel",
					"--jelly-blast-min-level=$JellyBlastMinLevel",
					"--jelly-tap-blast-min-level=$JellyTapBlastMinLevel",
					"--blast-score-factor=$($BlastScoreFactor.ToString([Globalization.CultureInfo]::InvariantCulture))",
					"--jelly-tap-blast-score-factor=$($JellyTapBlastScoreFactor.ToString([Globalization.CultureInfo]::InvariantCulture))",
					"--jelly-tap-blast-uses-turn=$($JellyTapBlastUsesTurn.ToLower())",
					"--jelly-tap-clean-max-level=$JellyTapCleanMaxLevel",
					"--jelly-tap-grow-min-clean=$JellyTapGrowMinClean",
					"--jelly-tap-effect-modes=$($JellyTapEffectModes.ToLower())",
					"--jelly-blast-requires-same-level=$($JellyBlastRequiresSameLevel.ToLower())",
					"--jelly-tap-common-push=$($JellyTapCommonPush.ToLower())",
					"--jelly-tap-lift-speed=$($JellyTapLiftSpeed.ToString([Globalization.CultureInfo]::InvariantCulture))",
					"--jelly-tap-push-radius-factor=$($JellyTapPushRadiusFactor.ToString([Globalization.CultureInfo]::InvariantCulture))",
					"--jelly-tap-push-speed=$($JellyTapPushSpeed.ToString([Globalization.CultureInfo]::InvariantCulture))",
					"--blast-gravity-pause-time=$($BlastGravityPauseTime.ToString([Globalization.CultureInfo]::InvariantCulture))",
					"--blast-speed=$($BlastSpeed.ToString([Globalization.CultureInfo]::InvariantCulture))",
					"--blast-far-factor=$($BlastFarFactor.ToString([Globalization.CultureInfo]::InvariantCulture))",
					"--orb-friction-by-level=$OrbFrictionByLevel",
					"--spawn-count-max=$SpawnCountMax",
					"--jelly-tap-blast-bot=$($resolvedTapBlastBotMode.ToLower())",
                    "--jolt-output=res://artifacts/measurements/$name.json"
                )
            }
        }
    }
    if ($ReuseCompleted) {
        $tasks = @($tasks | Where-Object { -not ((Test-Path -LiteralPath $_.Output) -and (Get-Item -LiteralPath $_.Output).Length -gt 0) })
    }
    $nextTaskIndex = 0
    $running = @()
    while ($nextTaskIndex -lt $tasks.Count -or $running.Count -gt 0) {
        while ($nextTaskIndex -lt $tasks.Count -and $running.Count -lt $Parallelism) {
            $task = $tasks[$nextTaskIndex]
            $nextTaskIndex += 1
            Remove-Item -LiteralPath $task.Output, $task.Stdout, $task.Stderr -Force -ErrorAction SilentlyContinue
            $process = Start-Process -FilePath $GodotPath -ArgumentList $task.Arguments -WindowStyle Hidden `
                -PassThru -RedirectStandardOutput $task.Stdout -RedirectStandardError $task.Stderr
            $running += [pscustomobject]@{ Task = $task; Process = $process }
            Write-Output "JELLY_MEASUREMENT_START name=$($task.Name) pid=$($process.Id)"
        }
        Start-Sleep -Milliseconds 500
        $stillRunning = @()
        foreach ($entry in $running) {
			$entry.Process.Refresh()
			if (-not $entry.Process.HasExited) {
				$stillRunning += $entry
				continue
			}
			$entry.Process.WaitForExit()
			$entry.Process.Refresh()
            $stdout = Get-Content -LiteralPath $entry.Task.Stdout -Raw -ErrorAction SilentlyContinue
            $stderr = Get-Content -LiteralPath $entry.Task.Stderr -Raw -ErrorAction SilentlyContinue
            $exitCode = if ($null -eq $entry.Process.ExitCode) { 0 } else { [int]$entry.Process.ExitCode }
            if ($exitCode -ne 0 -or ("$stdout`n$stderr" -match "SCRIPT ERROR|Parse Error|ERROR:")) {
                throw "$($entry.Task.Name) failed exit=$exitCode`n$stdout`n$stderr"
            }
            if (-not (Test-Path -LiteralPath $entry.Task.Output)) { throw "Missing $($entry.Task.Output)" }
            Write-Output "JELLY_MEASUREMENT_DONE name=$($entry.Task.Name) exit=0"
        }
		$running = $stillRunning
    }
}

function Get-Median($Values) {
    $items = @($Values | ForEach-Object { [double]$_ } | Sort-Object)
    if ($items.Count -eq 0) { return 0.0 }
    $middle = [Math]::Floor($items.Count / 2)
    if ($items.Count % 2 -eq 1) { return [double]$items[$middle] }
    return ([double]$items[$middle - 1] + [double]$items[$middle]) / 2.0
}
function Get-Ratio([double]$Numerator, [double]$Denominator) {
    if ($Denominator -eq 0.0) { return 0.0 }
    return $Numerator / $Denominator
}
function Get-SameSeedWinRate($Better, $Baseline, [string]$Field) {
    $lookup = @{}
    foreach ($row in @($Baseline)) { $lookup[[int]$row.seed] = [double]$row.$Field }
    $wins = 0.0
    foreach ($row in @($Better)) {
        $difference = [double]$row.$Field - $lookup[[int]$row.seed]
        if ($difference -gt 0.0) { $wins += 1.0 } elseif ($difference -eq 0.0) { $wins += 0.5 }
    }
    return Get-Ratio $wins @($Better).Count
}
function Get-Summary($Rows) {
    $earlyMerges = [double](($Rows | Measure-Object -Property early_merge_count -Sum).Sum)
    $earlyTurns = [double](($Rows | Measure-Object -Property early_turn_count -Sum).Sum)
    $finalMoves = [double](($Rows | Measure-Object -Property final_move_count -Sum).Sum)
    $finalSuccess = [double](($Rows | Measure-Object -Property final_move_success_count -Sum).Sum)
    $merges = [double](($Rows | Measure-Object -Property merge_count -Sum).Sum)
    $levelUps = [double](($Rows | Measure-Object -Property level_up_count -Sum).Sum)
    $absorptions = [double](($Rows | Measure-Object -Property one_level_absorption_count -Sum).Sum)
    $decisions = [double](($Rows | Measure-Object -Property preview_decision_turns -Sum).Sum)
    $fatalAvoidance = [double](($Rows | Measure-Object -Property preview_fatal_avoidance_turns -Sum).Sum)
    $outlineFrames = [double](($Rows | Measure-Object -Property jelly_outline_visible_frames -Sum).Sum)
    $unarmedOutlineFrames = [double](($Rows | Measure-Object -Property jelly_unarmed_outline_visible_frames -Sum).Sum)
    $outlineMaxAlpha = [double](($Rows | Measure-Object -Property jelly_outline_max_alpha -Maximum).Maximum)
    $blastCountByLevel = [ordered]@{}
	$tapBlastCountByLevel = [ordered]@{}
	$tapBlastCountByColor = [ordered]@{}
	$tapCleanCountByColor = [ordered]@{}
	$sameLevelBlastCountByLevel = [ordered]@{}
	$mixedLevelBlastCountByLevel = [ordered]@{}
	$reactionScoreTotals = [ordered]@{ merge = 0; blast = 0; tap = 0; jackpot = 0 }
    foreach ($row in @($Rows)) {
        foreach ($levelProperty in $row.blast_count_by_level.PSObject.Properties) {
            $levelKey = [string]$levelProperty.Name
            if (-not $blastCountByLevel.Contains($levelKey)) {
                $blastCountByLevel[$levelKey] = 0
            }
            $blastCountByLevel[$levelKey] += [int]$levelProperty.Value
        }
		foreach ($levelProperty in $row.tap_blast_count_by_level.PSObject.Properties) {
			$levelKey = [string]$levelProperty.Name
			if (-not $tapBlastCountByLevel.Contains($levelKey)) { $tapBlastCountByLevel[$levelKey] = 0 }
			$tapBlastCountByLevel[$levelKey] += [int]$levelProperty.Value
		}
		foreach ($colorProperty in $row.tap_blast_count_by_color.PSObject.Properties) {
			$colorKey = [string]$colorProperty.Name
			if (-not $tapBlastCountByColor.Contains($colorKey)) { $tapBlastCountByColor[$colorKey] = 0 }
			$tapBlastCountByColor[$colorKey] += [int]$colorProperty.Value
		}
		foreach ($colorProperty in $row.tap_clean_count_by_color.PSObject.Properties) {
			$colorKey = [string]$colorProperty.Name
			if (-not $tapCleanCountByColor.Contains($colorKey)) { $tapCleanCountByColor[$colorKey] = 0 }
			$tapCleanCountByColor[$colorKey] += [int]$colorProperty.Value
		}
		foreach ($levelProperty in $row.same_level_blast_count_by_level.PSObject.Properties) {
			$levelKey = [string]$levelProperty.Name
			if (-not $sameLevelBlastCountByLevel.Contains($levelKey)) { $sameLevelBlastCountByLevel[$levelKey] = 0 }
			$sameLevelBlastCountByLevel[$levelKey] += [int]$levelProperty.Value
		}
		foreach ($levelProperty in $row.mixed_level_blast_count_by_level.PSObject.Properties) {
			$levelKey = [string]$levelProperty.Name
			if (-not $mixedLevelBlastCountByLevel.Contains($levelKey)) { $mixedLevelBlastCountByLevel[$levelKey] = 0 }
			$mixedLevelBlastCountByLevel[$levelKey] += [int]$levelProperty.Value
		}
		foreach ($scoreProperty in $row.score_by_reaction_type.PSObject.Properties) {
			$scoreKey = [string]$scoreProperty.Name
			$reactionScoreTotals[$scoreKey] += [long]$scoreProperty.Value
		}
    }
	$turnTotal = [double](($Rows | Measure-Object -Property completed_turns -Sum).Sum)
	$scoreTotal = [double](($Rows | Measure-Object -Property score -Sum).Sum)
	$reactionScoreTotal = [double](($reactionScoreTotals.Values | Measure-Object -Sum).Sum)
	$tapBlastTotal = [double](($Rows | Measure-Object -Property tap_blast_count -Sum).Sum)
	$tapCleanTotal = [double](($Rows | Measure-Object -Property tap_clean_count_total -Sum).Sum)
	$bigReactionWindows = [double](($Rows | ForEach-Object { $_.reactions_within_one_second_after_blast.big.windows } | Measure-Object -Sum).Sum)
	$bigReactionMerges = [double](($Rows | ForEach-Object { $_.reactions_within_one_second_after_blast.big.merges } | Measure-Object -Sum).Sum)
	$bigReactionBlasts = [double](($Rows | ForEach-Object { $_.reactions_within_one_second_after_blast.big.blasts } | Measure-Object -Sum).Sum)
	$tapReactionWindows = [double](($Rows | ForEach-Object { $_.reactions_within_one_second_after_blast.tap.windows } | Measure-Object -Sum).Sum)
	$tapReactionMerges = [double](($Rows | ForEach-Object { $_.reactions_within_one_second_after_blast.tap.merges } | Measure-Object -Sum).Sum)
	$tapReactionBlasts = [double](($Rows | ForEach-Object { $_.reactions_within_one_second_after_blast.tap.blasts } | Measure-Object -Sum).Sum)
	$reactionScoreShares = [ordered]@{}
	foreach ($scoreKey in $reactionScoreTotals.Keys) {
		$reactionScoreShares[$scoreKey] = Get-Ratio ([double]$reactionScoreTotals[$scoreKey]) $reactionScoreTotal
	}
    return [ordered]@{
        games = @($Rows).Count
		game_over_count = @($Rows | Where-Object { $_.game_over }).Count
		incomplete_count = @($Rows | Where-Object { -not $_.game_over }).Count
		turns_average = ($Rows | Measure-Object -Property completed_turns -Average).Average
		turns_minimum = ($Rows | Measure-Object -Property completed_turns -Minimum).Minimum
		turns_maximum = ($Rows | Measure-Object -Property completed_turns -Maximum).Maximum
        turns_median = Get-Median @($Rows | ForEach-Object { $_.completed_turns })
		score_average = ($Rows | Measure-Object -Property score -Average).Average
        score_median = Get-Median @($Rows | ForEach-Object { $_.score })
		score_per_turn = Get-Ratio $scoreTotal $turnTotal
		score_by_reaction_type = $reactionScoreTotals
		score_share_by_reaction_type = $reactionScoreShares
		merges_per_turn = Get-Ratio $merges $turnTotal
		level_ups_per_turn = Get-Ratio $levelUps $turnTotal
		peak_active_orbs = ($Rows | Measure-Object -Property max_active_orbs -Maximum).Maximum
        early_merges_per_turn_1_30 = Get-Ratio $earlyMerges $earlyTurns
        final_move_occurrences = [int]$finalMoves
        final_move_successes = [int]$finalSuccess
        final_move_success_rate = Get-Ratio $finalSuccess $finalMoves
        one_level_absorption_fraction = Get-Ratio $absorptions $merges
        blast_outline_visible_frames = [int]$outlineFrames
        unarmed_blast_outline_visible_frames = [int]$unarmedOutlineFrames
        blast_outline_max_alpha = $outlineMaxAlpha
		level_seven_game_rate = Get-Ratio @($Rows | Where-Object { $_.reached_level_seven }).Count @($Rows).Count
		level_eight_plus_game_count = @($Rows | Where-Object { $_.reached_level_eight_plus }).Count
		level_eight_plus_creation_count = [int](($Rows | Measure-Object -Property level_eight_plus_creation_count -Sum).Sum)
		average_level_eight_plus_creations_per_game = Get-Ratio ([double](($Rows | Measure-Object -Property level_eight_plus_creation_count -Sum).Sum)) @($Rows).Count
		level_ten_game_count = @($Rows | Where-Object { [int]$_.max_level_reached -ge 10 }).Count
        jackpots = [int](($Rows | Measure-Object -Property max_clear_count -Sum).Sum)
		blasts = [int](($Rows | Measure-Object -Property blast_count -Sum).Sum)
		tap_blasts = [int](($Rows | Measure-Object -Property tap_blast_count -Sum).Sum)
		blast_count_by_level = $blastCountByLevel
		tap_blast_count_by_level = $tapBlastCountByLevel
		tap_blast_count_by_color = $tapBlastCountByColor
		tap_clean_count_by_color = $tapCleanCountByColor
		average_clean_count_per_tap = Get-Ratio $tapCleanTotal $tapBlastTotal
		maximum_clean_count_per_tap = ($Rows | Measure-Object -Property tap_clean_count_max -Maximum).Maximum
		purple_same_turn_blast_count = [int](($Rows | Measure-Object -Property purple_same_turn_blast_count -Sum).Sum)
		reactions_within_one_second_after_blast = [ordered]@{
			big = [ordered]@{ windows = [int]$bigReactionWindows; merges = [int]$bigReactionMerges; blasts = [int]$bigReactionBlasts }
			tap = [ordered]@{ windows = [int]$tapReactionWindows; merges = [int]$tapReactionMerges; blasts = [int]$tapReactionBlasts }
		}
		maximum_pair_penetration_px = ($Rows | ForEach-Object { [double]$_.max_turn_end_pair.penetration_px } | Measure-Object -Maximum).Maximum
		departures = [int](($Rows | Measure-Object -Property departures -Sum).Sum)
		forced_settle_turns = [int](($Rows | Measure-Object -Property capped_turn_count -Sum).Sum)
		same_level_blast_count_by_level = $sameLevelBlastCountByLevel
		mixed_level_blast_count_by_level = $mixedLevelBlastCountByLevel
        preview_fatal_avoidance_turns = [int]$fatalAvoidance
        preview_fatal_avoidance_ratio = Get-Ratio $fatalAvoidance $decisions
    }
}

$rows = [ordered]@{}
foreach ($strategy in $resolvedStrategies) { $rows[$strategy] = @() }
foreach ($strategy in @($rows.Keys)) {
    $shardSize = 1
    foreach ($shard in @(Get-SeedShards $SeedCount $shardSize)) {
        $filePath = Join-Path $outputDirectory "jelly_${measurementLabel}_${strategy}_part$($shard.Start)-$($shard.End).json"
        if (-not (Test-Path -LiteralPath $filePath)) { throw "Missing $filePath" }
        $rows[$strategy] += @((Get-Content -LiteralPath $filePath -Raw | ConvertFrom-Json).ticks[0].seeds)
    }
    $rows[$strategy] = @($rows[$strategy] | Sort-Object { [int]$_.seed })
    if ($rows[$strategy].Count -ne $SeedCount) { throw "$strategy expected $SeedCount rows, got $($rows[$strategy].Count)" }
}
$strategySummaries = [ordered]@{}
foreach ($strategy in @($rows.Keys)) {
	$strategySummaries[$strategy] = Get-Summary ($rows[$strategy])
}
$hasSkillComparison = (
	'r' -in $strategySummaries.Keys -and 'l_merge' -in $strategySummaries.Keys
)
$lengthRatio = if ($hasSkillComparison) {
	Get-Ratio $strategySummaries.l_merge.turns_median $strategySummaries.r.turns_median
} else { $null }
$scoreRatio = if ($hasSkillComparison) {
	Get-Ratio $strategySummaries.l_merge.score_median $strategySummaries.r.score_median
} else { $null }
$adjustmentCandidates = @()
if ('r' -in $strategySummaries.Keys -and $strategySummaries.r.turns_median -lt 150) {
    $adjustmentCandidates += "Delay JELLY color unlocks or increase spawn_count_ramp_turns to lengthen random games"
} elseif ('r' -in $strategySummaries.Keys -and $strategySummaries.r.turns_median -gt 300) {
    $adjustmentCandidates += "Advance JELLY color unlocks or reduce spawn_count_ramp_turns to shorten random games"
}
if ($hasSkillComparison -and $lengthRatio -lt 1.3) {
    $adjustmentCandidates += "Measure JELLY-specific difficulty transition intervals because preview skill length ratio is below 1.3"
}
if (
	'r' -in $strategySummaries.Keys -and
	$strategySummaries.r.early_merges_per_turn_1_30 -le 0.595
) {
    $adjustmentCandidates += "Measure JELLY early color count/unlock candidates because early merge rate is not above CLASSIC C2"
}
$report = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
	conditions = "JELLY $($resolvedStrategies -join '/'), seeds 1-$SeedCount, $TurnCap turns, fixed 120 fps"
	level_profile = $LevelProfile
	tap_blast_bot_mode = $resolvedTapBlastBotMode.ToLower()
	blast_score_factor = $BlastScoreFactor
	jelly_tap_blast_score_factor = $JellyTapBlastScoreFactor
	jelly_tap_blast_uses_turn = $JellyTapBlastUsesTurn -eq "On"
	jelly_tap_clean_max_level = $JellyTapCleanMaxLevel
	jelly_tap_grow_min_clean = $JellyTapGrowMinClean
	jelly_tap_effect_modes = $JellyTapEffectModes.ToLower()
	jelly_merge_level_gap = $JellyMergeLevelGap
	jelly_merge_wide_gap_min_level = $JellyMergeWideGapMinLevel
	jelly_blast_min_level = $JellyBlastMinLevel
	jelly_tap_blast_min_level = $JellyTapBlastMinLevel
	jelly_blast_requires_same_level = $JellyBlastRequiresSameLevel -eq "On"
	jelly_tap_common_push = $JellyTapCommonPush -eq "On"
	jelly_tap_lift_speed = $JellyTapLiftSpeed
	blast_gravity_pause_time = $BlastGravityPauseTime
	blast_speed = $BlastSpeed
	blast_far_factor = $BlastFarFactor
	orb_friction_by_level = $OrbFrictionByLevel
	spawn_count_max = $SpawnCountMax
	strategies_requested = $resolvedStrategies
	strategies = $strategySummaries
    skill_length_ratio_l_merge_over_r = $lengthRatio
    skill_score_ratio_l_merge_over_r = $scoreRatio
    same_seed_length_win_rate = if ($hasSkillComparison) {
		Get-SameSeedWinRate $rows.l_merge $rows.r "completed_turns"
	} else { $null }
    same_seed_score_win_rate = if ($hasSkillComparison) {
		Get-SameSeedWinRate $rows.l_merge $rows.r "score"
	} else { $null }
    comparison = [ordered]@{
        classic_c2 = [ordered]@{ r_turns = 221.0; r_score = 124262.5; l_turns = 327.0; l_score = 338539.5; skill_length_ratio = 1.479638009; early_merge_rate = 0.595 }
        slime_s2 = [ordered]@{ r_turns = 52.0; r_score = 103232.0; l_turns = 60.0; l_score = 151202.0; skill_length_ratio = 1.153846154; early_merge_rate = 2.966431688 }
        jelly_j5_98 = [ordered]@{ r_turns = 223.5; l_turns = 328.0; skill_length_ratio = 1.467561521; skill_score_ratio = 4.15; early_merge_rate = 0.725 }
        jelly_motion_101 = [ordered]@{ r_turns = 230.5 }
    }
    desired_range = [ordered]@{
        random_length_150_to_300 = if ('r' -in $strategySummaries.Keys) {
			$strategySummaries.r.turns_median -ge 150 -and $strategySummaries.r.turns_median -le 300
		} else { $null }
        skill_length_ratio_at_least_1_3 = if ($hasSkillComparison) {
			$lengthRatio -ge 1.3
		} else { $null }
        early_merge_above_classic_c2 = if ('r' -in $strategySummaries.Keys) {
			$strategySummaries.r.early_merges_per_turn_1_30 -gt 0.595
		} else { $null }
    }
    adjustment_candidates = $adjustmentCandidates
}
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output "JELLY_MEASUREMENT_REPORT $summaryPath"
