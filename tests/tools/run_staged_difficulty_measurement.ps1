param(
    [string]$GodotPath = "",
    [ValidateRange(1, 100)]
    [int]$ClassicSeedCount = 20,
    [ValidateRange(1, 500)]
    [int]$SlimeSeedCount = 100,
    [ValidateRange(1, 4)]
    [int]$Parallelism = 3,
    [switch]$ReuseCompleted,
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$outputDirectory = Join-Path $repoPath "artifacts\measurements"
$reportPath = Join-Path $outputDirectory "staged_difficulty_report.json"
$durationPath = Join-Path $outputDirectory "staged_difficulty_durations.json"

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
        $GodotPath = $env:GODOT
    } elseif (Test-Path -LiteralPath "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe") {
        $GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
    } else {
        $GodotPath = "godot"
    }
}

$classicCandidates = [ordered]@{
    c1 = [ordered]@{ start_colors = 4; unlock_turns = "40,80"; ramp_turns = 40 }
    c2 = [ordered]@{ start_colors = 4; unlock_turns = "30,60"; ramp_turns = 50 }
    c3 = [ordered]@{ start_colors = 4; unlock_turns = "50,100"; ramp_turns = 60 }
}
$slimeCandidates = [ordered]@{
    s0 = [ordered]@{ mode = "score"; unlock_turns = ""; floor_steps = "30:2,60:3" }
    s1 = [ordered]@{ mode = "turn"; unlock_turns = "15,30,45,60"; floor_steps = "30:2,60:3" }
    s2 = [ordered]@{ mode = "turn"; unlock_turns = "20,40,60,80"; floor_steps = "20:2,40:3,60:4" }
    s3 = [ordered]@{ mode = "turn"; unlock_turns = "25,50,75,100"; floor_steps = "25:2,50:3,75:4" }
}

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

function Get-SeedShards([int]$Count, [int]$ShardSize) {
    $result = @()
    for ($start = 1; $start -le $Count; $start += $ShardSize) {
        $end = [Math]::Min($start + $ShardSize - 1, $Count)
        $result += [pscustomobject]@{
            Start = $start
            End = $end
            Count = $end - $start + 1
            Csv = (@($start..$end) -join ",")
        }
    }
    return $result
}

function Assert-File([string]$Path, [string]$Description) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing $Description at $Path. Run #89/#90 measurement commands first."
    }
}

$durations = [ordered]@{}
if (($ReuseCompleted -or $AggregateOnly) -and (Test-Path -LiteralPath $durationPath)) {
    $saved = Get-Content -LiteralPath $durationPath -Raw | ConvertFrom-Json
    foreach ($property in $saved.PSObject.Properties) {
        $durations[$property.Name] = [double]$property.Value
    }
}

if (-not $AggregateOnly) {
    if (-not $ReuseCompleted) {
        Get-ChildItem -LiteralPath $outputDirectory -Filter "staged_difficulty_*_part*.json" -File |
            Remove-Item -Force
        Remove-Item -LiteralPath $durationPath -Force -ErrorAction SilentlyContinue
    }
    $tasks = @()
    foreach ($candidateName in $classicCandidates.Keys) {
        $candidate = $classicCandidates[$candidateName]
        foreach ($strategy in @("r", "g", "l_merge")) {
            $shardSize = if ($strategy -eq "l_merge") { 1 } else { 5 }
            foreach ($shard in @(Get-SeedShards $ClassicSeedCount $shardSize)) {
                $name = "classic_${candidateName}_${strategy}_part$($shard.Start)-$($shard.End)"
                $output = Join-Path $outputDirectory "staged_difficulty_${name}.json"
                $resourceOutput = "res://artifacts/measurements/staged_difficulty_${name}.json"
                $tasks += [pscustomobject]@{
                    Name = $name
                    Output = $output
                    Stdout = Join-Path $outputDirectory "staged_difficulty_${name}.stdout.log"
                    Stderr = Join-Path $outputDirectory "staged_difficulty_${name}.stderr.log"
                    Arguments = @(
                        "--headless", "--path", $repoPath, "--fixed-fps", "120", "--audio-driver", "Dummy",
                        "--log-file", (Join-Path $outputDirectory "staged_difficulty_${name}.godot.log"),
                        "res://tests/spike/JoltMeasurement.tscn", "--",
                        "--jolt-ticks=120", "--jolt-seeds=$($shard.Csv)", "--jolt-max-turns=600",
                        "--jolt-no-determinism", "--skill-strategy=$strategy",
                        "--turn-start-colors=$($candidate.start_colors)",
                        "--turn-color-unlock-turns=$($candidate.unlock_turns)",
                        "--spawn-ramp-turns=$($candidate.ramp_turns)",
                        "--jolt-output=$resourceOutput"
                    )
                }
            }
        }
    }
    foreach ($candidateName in $slimeCandidates.Keys) {
        $candidate = $slimeCandidates[$candidateName]
        foreach ($shard in @(Get-SeedShards $SlimeSeedCount 25)) {
            $name = "slime_${candidateName}_part$($shard.Start)-$($shard.End)"
            $output = Join-Path $outputDirectory "staged_difficulty_${name}.json"
            $resourceOutput = "res://artifacts/measurements/staged_difficulty_${name}.json"
            $tasks += [pscustomobject]@{
                Name = $name
                Output = $output
                Stdout = Join-Path $outputDirectory "staged_difficulty_${name}.stdout.log"
                Stderr = Join-Path $outputDirectory "staged_difficulty_${name}.stderr.log"
                Arguments = @(
                    "--headless", "--path", $repoPath, "--fixed-fps", "120", "--audio-driver", "Dummy",
                    "--log-file", (Join-Path $outputDirectory "staged_difficulty_${name}.godot.log"),
                    "-s", "res://tests/tools/run_mode_skill_slime_measurement.gd", "--",
                    "--seed-start=$($shard.Start)", "--seed-count=$($shard.Count)", "--turn-cap=250",
                    "--strategies=r,g,preview_space,preview_merge",
                    "--color-unlock-mode=$($candidate.mode)",
                    "--color-unlock-turns=$($candidate.unlock_turns)",
                    "--turn-floor-steps=$($candidate.floor_steps)",
                    "--output=$resourceOutput"
                )
            }
        }
    }

    if ($ReuseCompleted) {
        $tasks = @($tasks | Where-Object {
            if ((Test-Path -LiteralPath $_.Output) -and (Get-Item -LiteralPath $_.Output).Length -gt 0) {
                Write-Host "STAGED_DIFFICULTY_REUSE name=$($_.Name)"
                return $false
            }
            return $true
        })
    }

    for ($offset = 0; $offset -lt $tasks.Count; $offset += $Parallelism) {
        $end = [Math]::Min($offset + $Parallelism - 1, $tasks.Count - 1)
        $batch = @($tasks[$offset..$end])
        $running = @()
        foreach ($task in $batch) {
            Remove-Item -LiteralPath $task.Output, $task.Stdout, $task.Stderr -Force -ErrorAction SilentlyContinue
            $process = Start-Process -FilePath $GodotPath -ArgumentList $task.Arguments -WindowStyle Hidden `
                -PassThru -RedirectStandardOutput $task.Stdout -RedirectStandardError $task.Stderr
            $running += [pscustomobject]@{ Task = $task; Process = $process }
            Write-Output "STAGED_DIFFICULTY_START name=$($task.Name) pid=$($process.Id)"
        }
        while (@($running | Where-Object { -not $_.Process.HasExited }).Count -gt 0) {
            Start-Sleep -Milliseconds 500
            foreach ($entry in $running) { $entry.Process.Refresh() }
        }
        foreach ($entry in $running) {
            $entry.Process.Refresh()
            $seconds = [Math]::Round(($entry.Process.ExitTime - $entry.Process.StartTime).TotalSeconds, 3)
            $durations[$entry.Task.Name] = $seconds
            $durations | ConvertTo-Json | Set-Content -LiteralPath $durationPath -Encoding utf8
            $stdout = Get-Content -LiteralPath $entry.Task.Stdout -Raw -ErrorAction SilentlyContinue
            $stderr = Get-Content -LiteralPath $entry.Task.Stderr -Raw -ErrorAction SilentlyContinue
            if ($entry.Process.ExitCode -ne 0 -or ("$stdout`n$stderr" -match "SCRIPT ERROR|Parse Error|ERROR:")) {
                throw "$($entry.Task.Name) failed exit=$($entry.Process.ExitCode)`n$stdout`n$stderr"
            }
            if (-not (Test-Path -LiteralPath $entry.Task.Output)) {
                throw "Missing output $($entry.Task.Output)"
            }
            Write-Output "STAGED_DIFFICULTY_DONE name=$($entry.Task.Name) exit=0 seconds=$seconds"
        }
    }
}

function Get-Mean($Values) {
    $items = @($Values | ForEach-Object { [double]$_ })
    if ($items.Count -eq 0) { return 0.0 }
    return [double](($items | Measure-Object -Average).Average)
}

function Get-Median($Values) {
    $items = @($Values | ForEach-Object { [double]$_ } | Sort-Object)
    if ($items.Count -eq 0) { return 0.0 }
    $middle = [Math]::Floor($items.Count / 2)
    if ($items.Count % 2 -eq 1) { return [double]$items[$middle] }
    return ([double]$items[$middle - 1] + [double]$items[$middle]) / 2.0
}

function Get-SafeRatio([double]$Numerator, [double]$Denominator) {
    if ($Denominator -eq 0.0) { return 0.0 }
    return $Numerator / $Denominator
}

function Get-CoefficientOfVariation($Values) {
    $items = @($Values | ForEach-Object { [double]$_ })
    $mean = Get-Mean $items
    if ($items.Count -eq 0 -or $mean -eq 0.0) { return 0.0 }
    $squareSum = 0.0
    foreach ($value in $items) { $squareSum += [Math]::Pow($value - $mean, 2) }
    return [Math]::Sqrt($squareSum / $items.Count) / $mean
}

function Get-SameSeedWinRate($BetterRows, $BaselineRows, [string]$Field) {
    $baseline = @{}
    foreach ($row in @($BaselineRows)) { $baseline[[int]$row.seed] = [double]$row.$Field }
    $points = 0.0
    $count = 0
    foreach ($row in @($BetterRows)) {
        if (-not $baseline.ContainsKey([int]$row.seed)) { continue }
        $difference = [double]$row.$Field - $baseline[[int]$row.seed]
        if ($difference -gt 0.0) { $points += 1.0 }
        elseif ($difference -eq 0.0) { $points += 0.5 }
        $count++
    }
    return Get-SafeRatio $points $count
}

function Get-EarlyMergeRate($Rows) {
    $merges = 0.0
    $turns = 0.0
    foreach ($row in @($Rows)) {
        if ($null -ne $row.early_merge_count) {
            $merges += [double]$row.early_merge_count
            $turns += [double]$row.early_turn_count
            continue
        }
        foreach ($turnRow in @($row.turn_rows | Where-Object { [int]$_.turn -le 30 })) {
            $merges += [Math]::Max(0.0, [double]$turnRow.reactions - [double]$turnRow.blast_count)
            $turns++
        }
    }
    return Get-SafeRatio $merges $turns
}

function Test-RowSawColor($Row, [int]$Color) {
    if ($null -ne $Row.seen_colors) { return @($Row.seen_colors) -contains $Color }
    foreach ($orb in @($Row.final_state)) {
        if ([int]$orb.color -eq $Color) { return $true }
    }
    $names = @("RED", "BLUE", "GREEN", "YELLOW", "PURPLE", "CYAN")
    return $Color -lt $names.Count -and [int]$Row.reactions_by_color.($names[$Color]) -gt 0
}

function Get-ColorAppearance($Rows, [int]$ColorCount) {
    $result = [ordered]@{}
    for ($color = 0; $color -lt $ColorCount; $color++) {
        $seen = @($Rows | Where-Object { Test-RowSawColor $_ $color }).Count
        $result["color_$color"] = Get-SafeRatio $seen @($Rows).Count
    }
    return $result
}

function New-StrategySummary($Rows, [string]$TurnField) {
    return [ordered]@{
        games = @($Rows).Count
        turns_median = Get-Median @($Rows | ForEach-Object { $_.$TurnField })
        turns_mean = Get-Mean @($Rows | ForEach-Object { $_.$TurnField })
        score_median = Get-Median @($Rows | ForEach-Object { $_.score })
        score_mean = Get-Mean @($Rows | ForEach-Object { $_.score })
        early_merges_per_turn_1_30 = Get-EarlyMergeRate $Rows
    }
}

function Get-FatalRatio($Rows) {
    $decisions = [double](($Rows | Measure-Object -Property preview_decision_turns -Sum).Sum)
    $fatal = [double](($Rows | Measure-Object -Property preview_fatal_avoidance_turns -Sum).Sum)
    return Get-SafeRatio $fatal $decisions
}

function Get-CandidateDuration([string]$Prefix) {
    $values = @($durations.GetEnumerator() | Where-Object { $_.Key -like "$Prefix*" } | ForEach-Object { [double]$_.Value })
    if ($values.Count -eq 0) { return [ordered]@{ process_seconds = 0.0; longest_shard_seconds = 0.0 } }
    return [ordered]@{
        process_seconds = [double](($values | Measure-Object -Sum).Sum)
        longest_shard_seconds = [double](($values | Measure-Object -Maximum).Maximum)
    }
}

$classicRows = [ordered]@{}
$classicRPath = Join-Path $outputDirectory "mode_skill_classic_r.json"
Assert-File $classicRPath "#89 CLASSIC R baseline"
$classicRows.c0 = [ordered]@{
    r = @((Get-Content -LiteralPath $classicRPath -Raw | ConvertFrom-Json).ticks[0].seeds)
    g = @()
    l_merge = @()
}
foreach ($file in @(Get-ChildItem -LiteralPath $outputDirectory -Filter "mode_preview_classic_g_part*.json")) {
    $classicRows.c0.g += @((Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json).ticks[0].seeds)
}
foreach ($file in @(Get-ChildItem -LiteralPath $outputDirectory -Filter "mode_preview_classic_l_merge_part*.json")) {
    $classicRows.c0.l_merge += @((Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json).ticks[0].seeds)
}
foreach ($strategy in @("r", "g", "l_merge")) {
    if (@($classicRows.c0[$strategy]).Count -ne 30) { throw "C0 $strategy baseline must contain 30 rows" }
}
foreach ($candidateName in $classicCandidates.Keys) {
    $candidateRows = [ordered]@{ r = @(); g = @(); l_merge = @() }
    foreach ($strategy in @($candidateRows.Keys)) {
        foreach ($file in @(Get-ChildItem -LiteralPath $outputDirectory -Filter "staged_difficulty_classic_${candidateName}_${strategy}_part*.json")) {
            $candidateRows[$strategy] += @((Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json).ticks[0].seeds)
        }
        $candidateRows[$strategy] = @($candidateRows[$strategy] | Sort-Object { [int]$_.seed })
        if ($candidateRows[$strategy].Count -ne $ClassicSeedCount) {
            throw "$candidateName $strategy expected $ClassicSeedCount rows, got $($candidateRows[$strategy].Count)"
        }
    }
    $classicRows[$candidateName] = $candidateRows
}

$slimeRows = [ordered]@{}
$slimeChoiceMetrics = [ordered]@{}
foreach ($candidateName in $slimeCandidates.Keys) {
    $reports = @(Get-ChildItem -LiteralPath $outputDirectory -Filter "staged_difficulty_slime_${candidateName}_part*.json" |
        ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
    $candidateRows = [ordered]@{ r = @(); g = @(); preview_space = @(); preview_merge = @() }
    $candidateMetrics = [ordered]@{}
    foreach ($strategy in @($candidateRows.Keys)) {
        $candidateRows[$strategy] = @($reports | ForEach-Object { @($_.strategies.$strategy.rows) } | Sort-Object { [int]$_.seed })
        if ($candidateRows[$strategy].Count -ne $SlimeSeedCount) {
            throw "$candidateName $strategy expected $SlimeSeedCount rows, got $($candidateRows[$strategy].Count)"
        }
        $candidateMetrics[$strategy] = [ordered]@{
            decision_turns = [double](($reports | ForEach-Object { $_.strategies.$strategy.choice_metrics.decision_turns } | Measure-Object -Sum).Sum)
            fatal_avoidance_turns = [double](($reports | ForEach-Object { $_.strategies.$strategy.choice_metrics.fatal_avoidance_turns } | Measure-Object -Sum).Sum)
        }
    }
    $slimeRows[$candidateName] = $candidateRows
    $slimeChoiceMetrics[$candidateName] = $candidateMetrics
}

$classicReport = [ordered]@{}
foreach ($candidateName in $classicRows.Keys) {
    $rows = $classicRows[$candidateName]
    $strategies = [ordered]@{}
    foreach ($strategy in $rows.Keys) { $strategies[$strategy] = New-StrategySummary $rows[$strategy] "completed_turns" }
    $best = if ($strategies.g.turns_median -ge $strategies.l_merge.turns_median) { "g" } else { "l_merge" }
    $classicReport[$candidateName] = [ordered]@{
        schedule = if ($candidateName -eq "c0") { [ordered]@{ source = "#89/#90"; start_colors = 6; unlock_turns = ""; ramp_turns = 40 } } else { $classicCandidates[$candidateName] }
        strategies = $strategies
        best_preview = $best
        skill_length_ratio = Get-SafeRatio $strategies[$best].turns_median $strategies.r.turns_median
        skill_score_ratio = Get-SafeRatio $strategies[$best].score_median $strategies.r.score_median
        same_seed_win_rate = Get-SameSeedWinRate $rows[$best] $rows.r "completed_turns"
        random_length_cv = Get-CoefficientOfVariation @($rows.r | ForEach-Object { $_.completed_turns })
        random_early_merges_per_turn_1_30 = Get-EarlyMergeRate $rows.r
        random_color_appearance = Get-ColorAppearance $rows.r 6
        fatal_avoidance_turn_ratio = Get-FatalRatio $rows[$best]
        measurement_time = if ($candidateName -eq "c0") { [ordered]@{ reused = $true } } else { Get-CandidateDuration "classic_${candidateName}_" }
    }
}

$slimeReport = [ordered]@{}
foreach ($candidateName in $slimeRows.Keys) {
    $rows = $slimeRows[$candidateName]
    $strategies = [ordered]@{}
    foreach ($strategy in $rows.Keys) { $strategies[$strategy] = New-StrategySummary $rows[$strategy] "turns" }
    $best = if ($strategies.preview_space.turns_median -ge $strategies.preview_merge.turns_median) { "preview_space" } else { "preview_merge" }
    $slimeReport[$candidateName] = [ordered]@{
        schedule = $slimeCandidates[$candidateName]
        strategies = $strategies
        best_preview = $best
        skill_length_ratio = Get-SafeRatio $strategies[$best].turns_median $strategies.r.turns_median
        skill_score_ratio = Get-SafeRatio $strategies[$best].score_median $strategies.r.score_median
        same_seed_win_rate = Get-SameSeedWinRate $rows[$best] $rows.r "turns"
        random_length_cv = Get-CoefficientOfVariation @($rows.r | ForEach-Object { $_.turns })
        random_early_merges_per_turn_1_30 = Get-EarlyMergeRate $rows.r
        random_color_appearance = Get-ColorAppearance $rows.r 7
        fatal_avoidance_turn_ratio = Get-SafeRatio `
            $slimeChoiceMetrics[$candidateName][$best].fatal_avoidance_turns `
            $slimeChoiceMetrics[$candidateName][$best].decision_turns
        measurement_time = Get-CandidateDuration "slime_${candidateName}_"
    }
}

$report = [ordered]@{
    generated_at = [DateTime]::UtcNow.ToString("o")
    engine = (& $GodotPath --version | Select-Object -First 1)
    conditions = [ordered]@{
        classic = "C0 30 reused; C1-C3 seeds 1-$ClassicSeedCount, 600 turns, R/G/L-merge"
        slime = "S0-S3 seeds 1-$SlimeSeedCount, 250 turns, R/G/preview-space/preview-merge"
    }
    classic = $classicReport
    slime = $slimeReport
}
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $reportPath -Encoding utf8
Write-Output "STAGED_DIFFICULTY_SUMMARY"
foreach ($mode in @("classic", "slime")) {
    foreach ($property in $report[$mode].GetEnumerator()) {
        $value = $property.Value
        Write-Output ("{0} {1} R_turn={2:N1} skill={3:N3} win={4:P1} early={5:N3}" -f `
            $mode.ToUpper(), $property.Key.ToUpper(), $value.strategies.r.turns_median,
            $value.skill_length_ratio, $value.same_seed_win_rate, $value.random_early_merges_per_turn_1_30)
    }
}
Write-Output "STAGED_DIFFICULTY_RESULT path=$reportPath exit=0"
