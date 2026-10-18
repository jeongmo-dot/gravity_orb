param(
    [string]$GodotPath = "",
    [ValidateRange(1, 1000)]
    [int]$ClassicSeedCount = 30,
    [ValidateRange(1, 5000)]
    [int]$ClassicTurnCap = 600,
    [ValidateRange(1, 1000)]
    [int]$SlimeSeedCount = 100,
    [ValidateRange(1, 5000)]
    [int]$SlimeTurnCap = 250,
    [ValidateRange(1, 1000)]
    [int]$BlitzSeedCount = 30,
    [ValidateRange(1, 3600)]
    [int]$BlitzSessionCapSeconds = 600,
    [ValidateRange(1, 5)]
    [int]$Parallelism = 3,
    [switch]$ReuseCompleted,
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$outputDirectory = Join-Path $repoPath "artifacts\measurements"
$summaryPath = Join-Path $outputDirectory "mode_preview_report.json"
$durationPath = Join-Path $outputDirectory "mode_preview_durations.json"

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
        $GodotPath = $env:GODOT
    } elseif (Test-Path -LiteralPath "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe") {
        $GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
    } else {
        $GodotPath = "godot"
    }
}

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

function Get-SeedCsv([int]$Count) {
    return (@(1..$Count) -join ",")
}

function Get-SeedShards([int]$Count, [int]$ShardSize) {
    $shards = @()
    for ($start = 1; $start -le $Count; $start += $ShardSize) {
        $end = [Math]::Min($start + $ShardSize - 1, $Count)
        $shards += [pscustomobject]@{
            Start = $start
            End = $end
            Count = $end - $start + 1
            Csv = (@($start..$end) -join ",")
        }
    }
    return $shards
}

function Get-PreviewPath([string]$Mode, [string]$Strategy) {
    return Join-Path $outputDirectory "mode_preview_${Mode}_${Strategy}.json"
}

function Get-BaselinePath([string]$Mode, [string]$Strategy) {
    return Join-Path $outputDirectory "mode_skill_${Mode}_${Strategy}.json"
}

function Assert-Baseline([string]$Path, [string]$Description) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing #89 baseline for $Description at $Path. Run .\tests\tools\run_mode_skill_measurement.ps1 once, then rerun this command."
    }
}

$processDurations = [ordered]@{}
if (($ReuseCompleted -or $AggregateOnly) -and (Test-Path -LiteralPath $durationPath)) {
    $savedDurations = Get-Content -LiteralPath $durationPath -Raw | ConvertFrom-Json
    foreach ($property in $savedDurations.PSObject.Properties) {
        $processDurations[$property.Name] = [double]$property.Value
    }
}

if (-not $AggregateOnly) {
    if (-not $ReuseCompleted) {
        Get-ChildItem -LiteralPath $outputDirectory -Filter "mode_preview_*_part*" -File |
            Remove-Item -Force
        Remove-Item -LiteralPath $durationPath -Force -ErrorAction SilentlyContinue
    }
    $blitzSeeds = Get-SeedCsv $BlitzSeedCount
    $tasks = @()
    foreach ($strategy in @("g", "l_space", "l_merge")) {
        $shardSize = if ($strategy -eq "g") { 5 } else { 1 }
        foreach ($shard in @(Get-SeedShards $ClassicSeedCount $shardSize)) {
            $name = "classic_${strategy}_part$($shard.Start)-$($shard.End)"
            $resourceOutput = "res://artifacts/measurements/mode_preview_${name}.json"
            $tasks += [pscustomobject]@{
                Name = $name
                Output = Join-Path $outputDirectory "mode_preview_${name}.json"
                Stdout = Join-Path $outputDirectory "mode_preview_${name}.stdout.log"
                Stderr = Join-Path $outputDirectory "mode_preview_${name}.stderr.log"
                Arguments = @(
                    "--headless", "--path", $repoPath, "--fixed-fps", "120", "--audio-driver", "Dummy",
                    "--log-file", (Join-Path $outputDirectory "mode_preview_${name}.godot.log"),
                    "res://tests/spike/JoltMeasurement.tscn", "--",
                    "--jolt-ticks=120", "--jolt-seeds=$($shard.Csv)",
                    "--jolt-max-turns=$ClassicTurnCap", "--jolt-no-determinism",
                    "--skill-strategy=$strategy", "--jolt-output=$resourceOutput"
                )
            }
        }
    }

    $blitzOutput = "res://artifacts/measurements/mode_preview_blitz_g.json"
    $tasks += [pscustomobject]@{
        Name = "blitz_g"
        Output = Get-PreviewPath "blitz" "g"
        Stdout = Join-Path $outputDirectory "mode_preview_blitz_g.stdout.log"
        Stderr = Join-Path $outputDirectory "mode_preview_blitz_g.stderr.log"
        Arguments = @(
            "--headless", "--path", $repoPath, "--fixed-fps", "120", "--audio-driver", "Dummy",
            "--log-file", (Join-Path $outputDirectory "mode_preview_blitz_g.godot.log"),
            "res://tests/spike/BlitzMeasurement.tscn", "--",
            "--blitz-bot=g", "--blitz-bot-interval=0.35",
            "--blitz-seeds=$blitzSeeds", "--blitz-color-count=6",
            "--blitz-refill-rule=target", "--blitz-session-cap=$BlitzSessionCapSeconds",
            "--blitz-output=$blitzOutput"
        )
    }

    foreach ($shard in @(Get-SeedShards $SlimeSeedCount 25)) {
        $name = "slime_g_preview_part$($shard.Start)-$($shard.End)"
        $slimeOutput = "res://artifacts/measurements/mode_preview_${name}.json"
        $tasks += [pscustomobject]@{
            Name = $name
            Output = Join-Path $outputDirectory "mode_preview_${name}.json"
            Stdout = Join-Path $outputDirectory "mode_preview_${name}.stdout.log"
            Stderr = Join-Path $outputDirectory "mode_preview_${name}.stderr.log"
            Arguments = @(
                "--headless", "--path", $repoPath, "--fixed-fps", "120", "--audio-driver", "Dummy",
                "--log-file", (Join-Path $outputDirectory "mode_preview_${name}.godot.log"),
                "-s", "res://tests/tools/run_mode_skill_slime_measurement.gd", "--",
                "--seed-start=$($shard.Start)", "--seed-count=$($shard.Count)",
                "--turn-cap=$SlimeTurnCap", "--strategies=g,preview_space,preview_merge",
                "--output=$slimeOutput"
            )
        }
    }

    if ($ReuseCompleted) {
        $pendingTasks = @()
        foreach ($task in $tasks) {
            if ((Test-Path -LiteralPath $task.Output) -and (Get-Item -LiteralPath $task.Output).Length -gt 0) {
                Write-Output ("MODE_PREVIEW_REUSE name={0} output={1}" -f $task.Name, $task.Output)
                continue
            }
            $pendingTasks += $task
        }
        $tasks = $pendingTasks
    }

    for ($offset = 0; $offset -lt $tasks.Count; $offset += $Parallelism) {
        $lastIndex = [Math]::Min($offset + $Parallelism - 1, $tasks.Count - 1)
        $batch = @($tasks[$offset..$lastIndex])
        $running = @()
        foreach ($task in $batch) {
            Remove-Item -LiteralPath $task.Output, $task.Stdout, $task.Stderr -Force -ErrorAction SilentlyContinue
            $process = Start-Process `
                -FilePath $GodotPath `
                -ArgumentList $task.Arguments `
                -WindowStyle Hidden `
                -PassThru `
                -RedirectStandardOutput $task.Stdout `
                -RedirectStandardError $task.Stderr
            $running += [pscustomobject]@{ Task = $task; Process = $process }
            Write-Output ("MODE_PREVIEW_START name={0} pid={1}" -f $task.Name, $process.Id)
        }
        while (@($running | Where-Object { -not $_.Process.HasExited }).Count -gt 0) {
            Start-Sleep -Milliseconds 500
            foreach ($entry in $running) { $entry.Process.Refresh() }
        }
        foreach ($entry in $running) {
            $entry.Process.Refresh()
            $duration = [Math]::Round(
                ($entry.Process.ExitTime - $entry.Process.StartTime).TotalSeconds,
                3
            )
            $processDurations[$entry.Task.Name] = $duration
            $processDurations | ConvertTo-Json | Set-Content -LiteralPath $durationPath -Encoding utf8
            $stdout = Get-Content -LiteralPath $entry.Task.Stdout -Raw -ErrorAction SilentlyContinue
            $stderr = Get-Content -LiteralPath $entry.Task.Stderr -Raw -ErrorAction SilentlyContinue
            if ($entry.Process.ExitCode -ne 0) {
                throw "$($entry.Task.Name) failed with exit $($entry.Process.ExitCode)`n$stdout`n$stderr"
            }
            if (("$stdout`n$stderr") -match "SCRIPT ERROR|Parse Error|ERROR:") {
                throw "$($entry.Task.Name) emitted an engine error`n$stdout`n$stderr"
            }
            if (-not (Test-Path -LiteralPath $entry.Task.Output)) {
                throw "Missing measurement output $($entry.Task.Output)"
            }
            Write-Output ("MODE_PREVIEW_DONE name={0} exit=0 seconds={1}" -f $entry.Task.Name, $duration)
        }
    }
}

$classicRPath = Get-BaselinePath "classic" "r"
$classicSPath = Get-BaselinePath "classic" "s"
$slimeBaselinePath = Join-Path $outputDirectory "mode_skill_slime.json"
$blitzRPath = Get-BaselinePath "blitz" "r"
$blitzSPath = Get-BaselinePath "blitz" "s"
Assert-Baseline $classicRPath "CLASSIC R"
Assert-Baseline $classicSPath "CLASSIC S"
Assert-Baseline $slimeBaselinePath "SLIME R/S"
Assert-Baseline $blitzRPath "BLITZ R"
Assert-Baseline $blitzSPath "BLITZ S"

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

function Get-SameSeedWinRate($BetterRows, $BaselineRows, [string]$Field) {
    $baseline = @{}
    foreach ($row in @($BaselineRows)) { $baseline[[int]$row.seed] = [double]$row.$Field }
    $points = 0.0
    $count = 0
    foreach ($row in @($BetterRows)) {
        $seed = [int]$row.seed
        if (-not $baseline.ContainsKey($seed)) { continue }
        $value = [double]$row.$Field
        if ($value -gt $baseline[$seed]) { $points += 1.0 }
        elseif ($value -eq $baseline[$seed]) { $points += 0.5 }
        $count++
    }
    return Get-SafeRatio $points $count
}

function New-Stats($Rows, [string]$Field) {
    $values = @($Rows | ForEach-Object { [double]$_.$Field })
    return [ordered]@{ median = Get-Median $values; mean = Get-Mean $values }
}

function New-ClassicSummary($Rows) {
    return [ordered]@{
        games = @($Rows).Count
        turns = New-Stats $Rows "completed_turns"
        score = New-Stats $Rows "score"
        max_level_mean = Get-Mean @($Rows | ForEach-Object { $_.max_level_reached })
        max_level_peak = [int](($Rows | Measure-Object -Property max_level_reached -Maximum).Maximum)
        blast_total = [int](($Rows | Measure-Object -Property blast_count -Sum).Sum)
        jackpot_total = [int](($Rows | Measure-Object -Property max_clear_count -Sum).Sum)
        game_over_count = @($Rows | Where-Object { [bool]$_.game_over }).Count
    }
}

function New-SlimeSummary($Rows) {
    return [ordered]@{
        games = @($Rows).Count
        turns = New-Stats $Rows "turns"
        score = New-Stats $Rows "score"
        max_level_mean = Get-Mean @($Rows | ForEach-Object { $_.max_level_reached })
        max_level_peak = [int](($Rows | Measure-Object -Property max_level_reached -Maximum).Maximum)
        max_mass_peak = [int](($Rows | Measure-Object -Property max_mass_reached -Maximum).Maximum)
        turn_cap_reached = @($Rows | Where-Object { [bool]$_.turn_cap_reached }).Count
    }
}

function New-BlitzSummary($Rows) {
    return [ordered]@{
        games = @($Rows).Count
        survived_seconds = New-Stats $Rows "play_time"
        score = New-Stats $Rows "score"
        max_level_mean = Get-Mean @($Rows | ForEach-Object { $_.max_level_reached })
        max_level_peak = [int](($Rows | Measure-Object -Property max_level_reached -Maximum).Maximum)
        blast_total = [int](($Rows | Measure-Object -Property blast_count -Sum).Sum)
        jackpot_total = [int](($Rows | Measure-Object -Property jackpot_count -Sum).Sum)
        cap_reached = @($Rows | Where-Object { [bool]$_.measurement_cap_reached }).Count
    }
}

function New-ClassicChoiceMetrics($Rows) {
    $decisionTurns = [int](($Rows | Measure-Object -Property preview_decision_turns -Sum).Sum)
    $fatalTurns = [int](($Rows | Measure-Object -Property preview_fatal_avoidance_turns -Sum).Sum)
    $unblockedSpreadSum = [double](($Rows | Measure-Object -Property preview_unblocked_spread_sum -Sum).Sum)
    $decisionUsec = [double](($Rows | Measure-Object -Property preview_decision_usec_sum -Sum).Sum)
    $scoreSpreads = @($Rows | ForEach-Object { @($_.preview_score_gain_spreads) })
    return [ordered]@{
        decision_turns = $decisionTurns
        fatal_avoidance_turns = $fatalTurns
        fatal_avoidance_turn_ratio = Get-SafeRatio $fatalTurns $decisionTurns
        unblocked_direction_spread_mean = Get-SafeRatio $unblockedSpreadSum $decisionTurns
        score_gain_spread_median = Get-Median $scoreSpreads
        decision_milliseconds_per_turn = Get-SafeRatio ($decisionUsec / 1000.0) $decisionTurns
    }
}

function New-SlimeChoiceMetrics($Reports, [string]$Strategy) {
    $metrics = @($Reports | ForEach-Object { $_.strategies.PSObject.Properties[$Strategy].Value.choice_metrics })
    $decisionTurns = [int](($metrics | Measure-Object -Property decision_turns -Sum).Sum)
    $fatalTurns = [int](($metrics | Measure-Object -Property fatal_avoidance_turns -Sum).Sum)
    $unblockedSpreadSum = [double](($metrics | Measure-Object -Property unblocked_direction_spread_sum -Sum).Sum)
    $decisionUsec = [double](($metrics | Measure-Object -Property decision_usec_sum -Sum).Sum)
    $scoreSpreads = @($metrics | ForEach-Object { @($_.score_gain_spreads) })
    return [ordered]@{
        decision_turns = $decisionTurns
        fatal_avoidance_turns = $fatalTurns
        fatal_avoidance_turn_ratio = Get-SafeRatio $fatalTurns $decisionTurns
        unblocked_direction_spread_mean = Get-SafeRatio $unblockedSpreadSum $decisionTurns
        score_gain_spread_median = Get-Median $scoreSpreads
        decision_milliseconds_per_turn = Get-SafeRatio ($decisionUsec / 1000.0) $decisionTurns
    }
}

function Get-ModeDuration([string]$Mode) {
    $values = @($processDurations.GetEnumerator() | Where-Object { $_.Key -like "${Mode}_*" } | ForEach-Object { [double]$_.Value })
    if ($values.Count -eq 0) {
        return [ordered]@{ longest_shard_seconds = 0.0; process_seconds = 0.0 }
    }
    return [ordered]@{
        longest_shard_seconds = [double](($values | Measure-Object -Maximum).Maximum)
        process_seconds = [double](($values | Measure-Object -Sum).Sum)
    }
}

$classicRows = [ordered]@{}
$classicRows.r = @((Get-Content -LiteralPath $classicRPath -Raw | ConvertFrom-Json).ticks[0].seeds | Where-Object { [int]$_.seed -le $ClassicSeedCount })
$classicRows.s = @((Get-Content -LiteralPath $classicSPath -Raw | ConvertFrom-Json).ticks[0].seeds | Where-Object { [int]$_.seed -le $ClassicSeedCount })
foreach ($strategy in @("g", "l_space", "l_merge")) {
    $rows = @()
    $files = @(Get-ChildItem -LiteralPath $outputDirectory -Filter "mode_preview_classic_${strategy}_part*.json")
    foreach ($file in $files) {
        $rows += @((Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json).ticks[0].seeds)
    }
    $classicRows[$strategy] = @($rows | Sort-Object { [int]$_.seed })
    if ($classicRows[$strategy].Count -ne $ClassicSeedCount) {
        throw "CLASSIC $strategy expected $ClassicSeedCount rows, got $($classicRows[$strategy].Count)"
    }
}

$slimeBaseline = Get-Content -LiteralPath $slimeBaselinePath -Raw | ConvertFrom-Json
$slimePreviewReports = @(
    Get-ChildItem -LiteralPath $outputDirectory -Filter "mode_preview_slime_g_preview_part*.json" |
        ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json }
)
$slimeRows = [ordered]@{
    r = @($slimeBaseline.strategies.r.rows | Where-Object { [int]$_.seed -le $SlimeSeedCount })
    s = @($slimeBaseline.strategies.s.rows | Where-Object { [int]$_.seed -le $SlimeSeedCount })
    g = @($slimePreviewReports | ForEach-Object { @($_.strategies.g.rows) } | Sort-Object { [int]$_.seed })
    preview_space = @($slimePreviewReports | ForEach-Object { @($_.strategies.preview_space.rows) } | Sort-Object { [int]$_.seed })
    preview_merge = @($slimePreviewReports | ForEach-Object { @($_.strategies.preview_merge.rows) } | Sort-Object { [int]$_.seed })
}
foreach ($strategy in @("g", "preview_space", "preview_merge")) {
    if ($slimeRows[$strategy].Count -ne $SlimeSeedCount) {
        throw "SLIME $strategy expected $SlimeSeedCount rows, got $($slimeRows[$strategy].Count)"
    }
}
$slimeChoiceMetrics = [ordered]@{
    preview_space = New-SlimeChoiceMetrics $slimePreviewReports "preview_space"
    preview_merge = New-SlimeChoiceMetrics $slimePreviewReports "preview_merge"
}

$blitzRows = [ordered]@{}
$blitzRows.r = @((Get-Content -LiteralPath $blitzRPath -Raw | ConvertFrom-Json).seeds | Where-Object { [int]$_.seed -le $BlitzSeedCount })
$blitzRows.s = @((Get-Content -LiteralPath $blitzSPath -Raw | ConvertFrom-Json).seeds | Where-Object { [int]$_.seed -le $BlitzSeedCount })
$blitzRows.g = @((Get-Content -LiteralPath (Get-PreviewPath "blitz" "g") -Raw | ConvertFrom-Json).seeds)

$classicStrategies = [ordered]@{}
foreach ($strategy in $classicRows.Keys) { $classicStrategies[$strategy] = New-ClassicSummary $classicRows[$strategy] }
$slimeStrategies = [ordered]@{}
foreach ($strategy in $slimeRows.Keys) { $slimeStrategies[$strategy] = New-SlimeSummary $slimeRows[$strategy] }
$blitzStrategies = [ordered]@{}
foreach ($strategy in $blitzRows.Keys) { $blitzStrategies[$strategy] = New-BlitzSummary $blitzRows[$strategy] }

$classicComparisons = [ordered]@{}
foreach ($strategy in @("g", "l_space", "l_merge")) {
    $classicComparisons[$strategy] = [ordered]@{
        over_r_length = Get-SafeRatio $classicStrategies[$strategy].turns.median $classicStrategies.r.turns.median
        over_r_score = Get-SafeRatio $classicStrategies[$strategy].score.median $classicStrategies.r.score.median
        same_seed_win_rate = Get-SameSeedWinRate $classicRows[$strategy] $classicRows.r "completed_turns"
    }
}
$slimeComparisons = [ordered]@{}
foreach ($strategy in @("g", "preview_space", "preview_merge")) {
    $slimeComparisons[$strategy] = [ordered]@{
        over_r_length = Get-SafeRatio $slimeStrategies[$strategy].turns.median $slimeStrategies.r.turns.median
        over_r_score = Get-SafeRatio $slimeStrategies[$strategy].score.median $slimeStrategies.r.score.median
        same_seed_win_rate = Get-SameSeedWinRate $slimeRows[$strategy] $slimeRows.r "turns"
    }
}
$blitzComparison = [ordered]@{
    g_over_r_length = Get-SafeRatio $blitzStrategies.g.survived_seconds.median $blitzStrategies.r.survived_seconds.median
    g_over_r_score = Get-SafeRatio $blitzStrategies.g.score.median $blitzStrategies.r.score.median
    g_same_seed_win_rate = Get-SameSeedWinRate $blitzRows.g $blitzRows.r "play_time"
}

$report = [ordered]@{
    generated_at = [DateTime]::UtcNow.ToString("o")
    engine = (& $GodotPath --version | Select-Object -First 1)
    baseline = [ordered]@{ source = "#89 raw measurement outputs"; r_and_s_reused = $true }
    conditions = [ordered]@{
        classic = [ordered]@{ seeds = "1-$ClassicSeedCount"; turn_cap = $ClassicTurnCap }
        slime = [ordered]@{ seeds = "1-$SlimeSeedCount"; turn_cap = $SlimeTurnCap }
        blitz = [ordered]@{ seeds = "1-$BlitzSeedCount"; swipe_interval_seconds = 0.35; session_cap_seconds = $BlitzSessionCapSeconds }
    }
    classic = [ordered]@{
        strategies = $classicStrategies
        comparison = $classicComparisons
        choice_metrics = [ordered]@{
            l_space = New-ClassicChoiceMetrics $classicRows.l_space
            l_merge = New-ClassicChoiceMetrics $classicRows.l_merge
        }
        measurement_time = Get-ModeDuration "classic"
    }
    slime = [ordered]@{
        strategies = $slimeStrategies
        comparison = $slimeComparisons
        choice_metrics = $slimeChoiceMetrics
        measurement_time = Get-ModeDuration "slime"
    }
    blitz = [ordered]@{
        strategies = $blitzStrategies
        comparison = $blitzComparison
        measurement_time = Get-ModeDuration "blitz"
    }
    summary = @(
        [pscustomobject][ordered]@{ mode = "CLASSIC"; strategy = "G"; over_r_length = $classicComparisons.g.over_r_length; same_seed_win_rate = $classicComparisons.g.same_seed_win_rate; fatal_avoidance_ratio = $null; decision_ms = $null },
        [pscustomobject][ordered]@{ mode = "CLASSIC"; strategy = "L-space"; over_r_length = $classicComparisons.l_space.over_r_length; same_seed_win_rate = $classicComparisons.l_space.same_seed_win_rate; fatal_avoidance_ratio = (New-ClassicChoiceMetrics $classicRows.l_space).fatal_avoidance_turn_ratio; decision_ms = (New-ClassicChoiceMetrics $classicRows.l_space).decision_milliseconds_per_turn },
        [pscustomobject][ordered]@{ mode = "CLASSIC"; strategy = "L-merge"; over_r_length = $classicComparisons.l_merge.over_r_length; same_seed_win_rate = $classicComparisons.l_merge.same_seed_win_rate; fatal_avoidance_ratio = (New-ClassicChoiceMetrics $classicRows.l_merge).fatal_avoidance_turn_ratio; decision_ms = (New-ClassicChoiceMetrics $classicRows.l_merge).decision_milliseconds_per_turn },
        [pscustomobject][ordered]@{ mode = "SLIME"; strategy = "G"; over_r_length = $slimeComparisons.g.over_r_length; same_seed_win_rate = $slimeComparisons.g.same_seed_win_rate; fatal_avoidance_ratio = $null; decision_ms = $null },
        [pscustomobject][ordered]@{ mode = "SLIME"; strategy = "preview-space"; over_r_length = $slimeComparisons.preview_space.over_r_length; same_seed_win_rate = $slimeComparisons.preview_space.same_seed_win_rate; fatal_avoidance_ratio = $slimeChoiceMetrics.preview_space.fatal_avoidance_turn_ratio; decision_ms = $slimeChoiceMetrics.preview_space.decision_milliseconds_per_turn },
        [pscustomobject][ordered]@{ mode = "SLIME"; strategy = "preview-merge"; over_r_length = $slimeComparisons.preview_merge.over_r_length; same_seed_win_rate = $slimeComparisons.preview_merge.same_seed_win_rate; fatal_avoidance_ratio = $slimeChoiceMetrics.preview_merge.fatal_avoidance_turn_ratio; decision_ms = $slimeChoiceMetrics.preview_merge.decision_milliseconds_per_turn },
        [pscustomobject][ordered]@{ mode = "BLITZ"; strategy = "G"; over_r_length = $blitzComparison.g_over_r_length; same_seed_win_rate = $blitzComparison.g_same_seed_win_rate; fatal_avoidance_ratio = $null; decision_ms = $null }
    )
}

$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output "MODE_PREVIEW_SUMMARY"
$report.summary | Format-Table -AutoSize | Out-String | Write-Output
Write-Output ("MODE_PREVIEW_RESULT path={0} exit=0" -f $summaryPath)
