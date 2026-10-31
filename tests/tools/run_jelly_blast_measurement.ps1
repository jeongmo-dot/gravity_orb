param(
    [string]$GodotPath = "",
    [ValidateRange(1, 20)]
    [int]$SeedCount = 20,
    [ValidateRange(1, 4)]
    [int]$Parallelism = 4,
    [ValidateRange(1, 600)]
    [int]$TurnCap = 600,
    [switch]$ReuseCompleted,
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$outputDirectory = Join-Path $repoPath "artifacts\measurements"
$summaryPath = Join-Path $outputDirectory "jelly_blast_candidates_measurement.json"
$candidateLevels = @(5, 7)
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
    foreach ($candidateLevel in $candidateLevels) {
        foreach ($strategy in @("r", "g", "l_merge")) {
            $shardSize = if ($strategy -eq "l_merge") { 1 } else { 5 }
            foreach ($shard in @(Get-SeedShards $SeedCount $shardSize)) {
                $name = "jelly_j${candidateLevel}_${strategy}_part$($shard.Start)-$($shard.End)"
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
                        "--game-mode=jelly", "--jelly-blast-min-level=$candidateLevel",
                        "--jolt-ticks=120", "--jolt-seeds=$($shard.Csv)",
                        "--jolt-max-turns=$TurnCap", "--jolt-no-determinism", "--skill-strategy=$strategy",
                        "--jolt-output=res://artifacts/measurements/$name.json"
                    )
                }
            }
        }
    }
    if ($ReuseCompleted) {
        $tasks = @($tasks | Where-Object {
            -not ((Test-Path -LiteralPath $_.Output) -and (Get-Item -LiteralPath $_.Output).Length -gt 0)
        })
    }
    for ($offset = 0; $offset -lt $tasks.Count; $offset += $Parallelism) {
        $end = [Math]::Min($offset + $Parallelism - 1, $tasks.Count - 1)
        $running = @()
        foreach ($task in @($tasks[$offset..$end])) {
            Remove-Item -LiteralPath $task.Output, $task.Stdout, $task.Stderr -Force -ErrorAction SilentlyContinue
            $process = Start-Process -FilePath $GodotPath -ArgumentList $task.Arguments -WindowStyle Hidden `
                -PassThru -RedirectStandardOutput $task.Stdout -RedirectStandardError $task.Stderr
            $running += [pscustomobject]@{ Task = $task; Process = $process }
            Write-Output "JELLY_BLAST_MEASUREMENT_START name=$($task.Name) pid=$($process.Id)"
        }
        while (@($running | Where-Object { -not $_.Process.HasExited }).Count -gt 0) {
            Start-Sleep -Milliseconds 500
            foreach ($entry in $running) { $entry.Process.Refresh() }
        }
        foreach ($entry in $running) {
            $entry.Process.WaitForExit()
            $entry.Process.Refresh()
            $stdout = [string](Get-Content -LiteralPath $entry.Task.Stdout -Raw -ErrorAction SilentlyContinue)
            $stderr = [string](Get-Content -LiteralPath $entry.Task.Stderr -Raw -ErrorAction SilentlyContinue)
            $exitCode = if ($null -eq $entry.Process.ExitCode) { 0 } else { [int]$entry.Process.ExitCode }
            if ($exitCode -ne 0 -or ("$stdout`n$stderr" -match "SCRIPT ERROR|Parse Error|ERROR:")) {
                throw "$($entry.Task.Name) failed exit=$exitCode`n$stdout`n$stderr"
            }
            if (-not (Test-Path -LiteralPath $entry.Task.Output)) { throw "Missing $($entry.Task.Output)" }
            Write-Output "JELLY_BLAST_MEASUREMENT_DONE name=$($entry.Task.Name) exit=0"
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
    $levelSevenCreations = [double](($Rows | Measure-Object -Property level_seven_creation_count -Sum).Sum)
    return [ordered]@{
        games = @($Rows).Count
        turns_median = Get-Median @($Rows | ForEach-Object { $_.completed_turns })
        score_median = Get-Median @($Rows | ForEach-Object { $_.score })
        early_merges_per_turn_1_30 = Get-Ratio $earlyMerges $earlyTurns
        blast_count = [int](($Rows | Measure-Object -Property blast_count -Sum).Sum)
        final_move_occurrences = [int]$finalMoves
        final_move_successes = [int]$finalSuccess
        final_move_success_rate = Get-Ratio $finalSuccess $finalMoves
        one_level_absorption_fraction = Get-Ratio $absorptions $merges
        level_seven_game_rate = Get-Ratio @($Rows | Where-Object { $_.reached_level_seven }).Count @($Rows).Count
        jackpots = [int](($Rows | Measure-Object -Property max_clear_count -Sum).Sum)
        level_seven_creations = [int]$levelSevenCreations
        preview_fatal_avoidance_turns = [int]$fatalAvoidance
        preview_fatal_avoidance_ratio = Get-Ratio $fatalAvoidance $decisions
    }
}

function Get-CandidateReport([int]$CandidateLevel) {
    $rows = [ordered]@{ r = @(); g = @(); l_merge = @() }
    foreach ($strategy in @($rows.Keys)) {
        $shardSize = if ($strategy -eq "l_merge") { 1 } else { 5 }
        foreach ($shard in @(Get-SeedShards $SeedCount $shardSize)) {
            $filePath = Join-Path $outputDirectory "jelly_j${CandidateLevel}_${strategy}_part$($shard.Start)-$($shard.End).json"
            if (-not (Test-Path -LiteralPath $filePath)) { throw "Missing $filePath" }
            $rows[$strategy] += @((Get-Content -LiteralPath $filePath -Raw | ConvertFrom-Json).ticks[0].seeds)
        }
        $rows[$strategy] = @($rows[$strategy] | Sort-Object { [int]$_.seed })
        if ($rows[$strategy].Count -ne $SeedCount) {
            throw "J$CandidateLevel $strategy expected $SeedCount rows, got $($rows[$strategy].Count)"
        }
    }
    $strategies = [ordered]@{}
    foreach ($strategy in @($rows.Keys)) { $strategies[$strategy] = Get-Summary $rows[$strategy] }
    $lengthRatio = Get-Ratio $strategies.l_merge.turns_median $strategies.r.turns_median
    $scoreRatio = Get-Ratio $strategies.l_merge.score_median $strategies.r.score_median
    return [ordered]@{
        blast_min_level = $CandidateLevel
        strategies = $strategies
        skill_length_ratio_l_merge_over_r = $lengthRatio
        skill_score_ratio_l_merge_over_r = $scoreRatio
        same_seed_length_win_rate = Get-SameSeedWinRate $rows.l_merge $rows.r "completed_turns"
        same_seed_score_win_rate = Get-SameSeedWinRate $rows.l_merge $rows.r "score"
        criteria = [ordered]@{
            random_length_150_to_300 = $strategies.r.turns_median -ge 150 -and $strategies.r.turns_median -le 300
            skill_length_ratio_at_least_1_3 = $lengthRatio -ge 1.3
            early_merge_above_classic_c2 = $strategies.r.early_merges_per_turn_1_30 -gt 0.595
        }
    }
}

$report = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    conditions = "J5/J7 R/G/L-merge, seeds 1-$SeedCount, $TurnCap turns, fixed 120 fps"
    candidates = [ordered]@{
        j5 = $(Get-CandidateReport 5)
        j7 = $(Get-CandidateReport 7)
    }
    comparison = [ordered]@{
        classic_c2 = [ordered]@{ r_turns = 221.0; r_score = 124262.5; l_turns = 327.0; l_score = 338539.5; skill_length_ratio = 1.479638009; early_merge_rate = 0.595 }
        slime_s2 = [ordered]@{ r_turns = 52.0; r_score = 103232.0; l_turns = 60.0; l_score = 151202.0; skill_length_ratio = 1.153846154; early_merge_rate = 2.966431688 }
    }
}
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output "JELLY_BLAST_MEASUREMENT_REPORT $summaryPath"
