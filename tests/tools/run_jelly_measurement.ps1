param(
    [string]$GodotPath = "",
    [ValidateRange(1, 20)]
    [int]$SeedCount = 20,
    [ValidateRange(1, 8)]
    [int]$Parallelism = 3,
    [ValidateRange(1, 600)]
    [int]$TurnCap = 600,
    [switch]$ReuseCompleted,
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$outputDirectory = Join-Path $repoPath "artifacts\measurements"
$summaryPath = Join-Path $outputDirectory "jelly_rules_measurement.json"
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
    foreach ($strategy in @("r", "g", "l_merge")) {
        # Keep each Godot worker below the desktop task runner's process window.
        # A single 600-turn seed can already take more than one minute.
        $shardSize = 1
        foreach ($shard in @(Get-SeedShards $SeedCount $shardSize)) {
            $name = "jelly_${strategy}_part$($shard.Start)-$($shard.End)"
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
                    "--jolt-output=res://artifacts/measurements/$name.json"
                )
            }
        }
    }
    if ($ReuseCompleted) {
        $tasks = @($tasks | Where-Object { -not ((Test-Path -LiteralPath $_.Output) -and (Get-Item -LiteralPath $_.Output).Length -gt 0) })
    }
    for ($offset = 0; $offset -lt $tasks.Count; $offset += $Parallelism) {
        $end = [Math]::Min($offset + $Parallelism - 1, $tasks.Count - 1)
        $running = @()
        foreach ($task in @($tasks[$offset..$end])) {
            Remove-Item -LiteralPath $task.Output, $task.Stdout, $task.Stderr -Force -ErrorAction SilentlyContinue
            $process = Start-Process -FilePath $GodotPath -ArgumentList $task.Arguments -WindowStyle Hidden `
                -PassThru -RedirectStandardOutput $task.Stdout -RedirectStandardError $task.Stderr
            $running += [pscustomobject]@{ Task = $task; Process = $process }
            Write-Output "JELLY_MEASUREMENT_START name=$($task.Name) pid=$($process.Id)"
        }
        while (@($running | Where-Object { -not $_.Process.HasExited }).Count -gt 0) {
            Start-Sleep -Milliseconds 500
            foreach ($entry in $running) { $entry.Process.Refresh() }
        }
        foreach ($entry in $running) {
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
    $absorptions = [double](($Rows | Measure-Object -Property one_level_absorption_count -Sum).Sum)
    $decisions = [double](($Rows | Measure-Object -Property preview_decision_turns -Sum).Sum)
    $fatalAvoidance = [double](($Rows | Measure-Object -Property preview_fatal_avoidance_turns -Sum).Sum)
    $outlineFrames = [double](($Rows | Measure-Object -Property jelly_outline_visible_frames -Sum).Sum)
    $unarmedOutlineFrames = [double](($Rows | Measure-Object -Property jelly_unarmed_outline_visible_frames -Sum).Sum)
    $outlineMaxAlpha = [double](($Rows | Measure-Object -Property jelly_outline_max_alpha -Maximum).Maximum)
    return [ordered]@{
        games = @($Rows).Count
        turns_median = Get-Median @($Rows | ForEach-Object { $_.completed_turns })
        score_median = Get-Median @($Rows | ForEach-Object { $_.score })
        early_merges_per_turn_1_30 = Get-Ratio $earlyMerges $earlyTurns
        final_move_occurrences = [int]$finalMoves
        final_move_successes = [int]$finalSuccess
        final_move_success_rate = Get-Ratio $finalSuccess $finalMoves
        one_level_absorption_fraction = Get-Ratio $absorptions $merges
        blast_outline_visible_frames = [int]$outlineFrames
        unarmed_blast_outline_visible_frames = [int]$unarmedOutlineFrames
        blast_outline_max_alpha = $outlineMaxAlpha
        level_seven_game_rate = Get-Ratio @($Rows | Where-Object { $_.reached_level_seven }).Count @($Rows).Count
        jackpots = [int](($Rows | Measure-Object -Property max_clear_count -Sum).Sum)
        preview_fatal_avoidance_turns = [int]$fatalAvoidance
        preview_fatal_avoidance_ratio = Get-Ratio $fatalAvoidance $decisions
    }
}

$rows = [ordered]@{ r = @(); g = @(); l_merge = @() }
foreach ($strategy in @($rows.Keys)) {
    $shardSize = 1
    foreach ($shard in @(Get-SeedShards $SeedCount $shardSize)) {
        $filePath = Join-Path $outputDirectory "jelly_${strategy}_part$($shard.Start)-$($shard.End).json"
        if (-not (Test-Path -LiteralPath $filePath)) { throw "Missing $filePath" }
        $rows[$strategy] += @((Get-Content -LiteralPath $filePath -Raw | ConvertFrom-Json).ticks[0].seeds)
    }
    $rows[$strategy] = @($rows[$strategy] | Sort-Object { [int]$_.seed })
    if ($rows[$strategy].Count -ne $SeedCount) { throw "$strategy expected $SeedCount rows, got $($rows[$strategy].Count)" }
}
$strategies = [ordered]@{}
foreach ($strategy in @($rows.Keys)) { $strategies[$strategy] = Get-Summary $rows[$strategy] }
$lengthRatio = Get-Ratio $strategies.l_merge.turns_median $strategies.r.turns_median
$scoreRatio = Get-Ratio $strategies.l_merge.score_median $strategies.r.score_median
$adjustmentCandidates = @()
if ($strategies.r.turns_median -lt 150) {
    $adjustmentCandidates += "Delay JELLY color unlocks or increase spawn_count_ramp_turns to lengthen random games"
} elseif ($strategies.r.turns_median -gt 300) {
    $adjustmentCandidates += "Advance JELLY color unlocks or reduce spawn_count_ramp_turns to shorten random games"
}
if ($lengthRatio -lt 1.3) {
    $adjustmentCandidates += "Measure JELLY-specific difficulty transition intervals because preview skill length ratio is below 1.3"
}
if ($strategies.r.early_merges_per_turn_1_30 -le 0.595) {
    $adjustmentCandidates += "Measure JELLY early color count/unlock candidates because early merge rate is not above CLASSIC C2"
}
$report = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    conditions = "JELLY R/G/L-merge, seeds 1-$SeedCount, $TurnCap turns, fixed 120 fps"
    strategies = $strategies
    skill_length_ratio_l_merge_over_r = $lengthRatio
    skill_score_ratio_l_merge_over_r = $scoreRatio
    same_seed_length_win_rate = Get-SameSeedWinRate $rows.l_merge $rows.r "completed_turns"
    same_seed_score_win_rate = Get-SameSeedWinRate $rows.l_merge $rows.r "score"
    comparison = [ordered]@{
        classic_c2 = [ordered]@{ r_turns = 221.0; r_score = 124262.5; l_turns = 327.0; l_score = 338539.5; skill_length_ratio = 1.479638009; early_merge_rate = 0.595 }
        slime_s2 = [ordered]@{ r_turns = 52.0; r_score = 103232.0; l_turns = 60.0; l_score = 151202.0; skill_length_ratio = 1.153846154; early_merge_rate = 2.966431688 }
        jelly_j5_98 = [ordered]@{ r_turns = 223.5; l_turns = 328.0; skill_length_ratio = 1.467561521; skill_score_ratio = 4.15; early_merge_rate = 0.725 }
        jelly_motion_101 = [ordered]@{ r_turns = 230.5 }
    }
    desired_range = [ordered]@{
        random_length_150_to_300 = $strategies.r.turns_median -ge 150 -and $strategies.r.turns_median -le 300
        skill_length_ratio_at_least_1_3 = $lengthRatio -ge 1.3
        early_merge_above_classic_c2 = $strategies.r.early_merges_per_turn_1_30 -gt 0.595
    }
    adjustment_candidates = $adjustmentCandidates
}
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output "JELLY_MEASUREMENT_REPORT $summaryPath"
