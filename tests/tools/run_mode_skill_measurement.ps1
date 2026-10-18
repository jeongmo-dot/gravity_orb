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
    [ValidateRange(1, 7)]
    [int]$Parallelism = 3,
    [switch]$ReuseCompleted,
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$outputDirectory = Join-Path $repoPath "artifacts\measurements"
$summaryPath = Join-Path $outputDirectory "mode_skill_report.json"
$durationPath = Join-Path $outputDirectory "mode_skill_durations.json"
$strategies = @("r", "s", "g")

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

function Get-RawPath([string]$Mode, [string]$Strategy) {
    return Join-Path $outputDirectory "mode_skill_${Mode}_${Strategy}.json"
}

$processDurations = [ordered]@{}
if (Test-Path -LiteralPath $durationPath) {
    $savedDurations = Get-Content -LiteralPath $durationPath -Raw | ConvertFrom-Json
    foreach ($property in $savedDurations.PSObject.Properties) {
        $processDurations[$property.Name] = [double]$property.Value
    }
}
if (-not $AggregateOnly) {
    $tasks = @()
    $classicSeeds = Get-SeedCsv $ClassicSeedCount
    $blitzSeeds = Get-SeedCsv $BlitzSeedCount
    foreach ($strategy in $strategies) {
        $classicName = "classic_$strategy"
        $classicOutput = "res://artifacts/measurements/mode_skill_${classicName}.json"
        $tasks += [pscustomobject]@{
            Name = $classicName
            Mode = "classic"
            Output = Get-RawPath "classic" $strategy
            Stdout = Join-Path $outputDirectory "mode_skill_${classicName}.stdout.log"
            Stderr = Join-Path $outputDirectory "mode_skill_${classicName}.stderr.log"
            Arguments = @(
                "--headless", "--path", $repoPath, "--fixed-fps", "120", "--audio-driver", "Dummy",
                "--log-file", (Join-Path $outputDirectory "mode_skill_${classicName}.godot.log"),
                "res://tests/spike/JoltMeasurement.tscn", "--",
                "--jolt-ticks=120", "--jolt-seeds=$classicSeeds",
                "--jolt-max-turns=$ClassicTurnCap", "--jolt-no-determinism",
                "--skill-strategy=$strategy", "--jolt-output=$classicOutput"
            )
        }

        $blitzName = "blitz_$strategy"
        $blitzOutput = "res://artifacts/measurements/mode_skill_${blitzName}.json"
        $tasks += [pscustomobject]@{
            Name = $blitzName
            Mode = "blitz"
            Output = Get-RawPath "blitz" $strategy
            Stdout = Join-Path $outputDirectory "mode_skill_${blitzName}.stdout.log"
            Stderr = Join-Path $outputDirectory "mode_skill_${blitzName}.stderr.log"
            Arguments = @(
                "--headless", "--path", $repoPath, "--fixed-fps", "120", "--audio-driver", "Dummy",
                "--log-file", (Join-Path $outputDirectory "mode_skill_${blitzName}.godot.log"),
                "res://tests/spike/BlitzMeasurement.tscn", "--",
                "--blitz-bot=$strategy", "--blitz-bot-interval=0.35",
                "--blitz-seeds=$blitzSeeds", "--blitz-color-count=6",
                "--blitz-refill-rule=target", "--blitz-session-cap=$BlitzSessionCapSeconds",
                "--blitz-output=$blitzOutput"
            )
        }
    }

    $slimeOutput = "res://artifacts/measurements/mode_skill_slime.json"
    $tasks += [pscustomobject]@{
        Name = "slime"
        Mode = "slime"
        Output = Join-Path $outputDirectory "mode_skill_slime.json"
        Stdout = Join-Path $outputDirectory "mode_skill_slime.stdout.log"
        Stderr = Join-Path $outputDirectory "mode_skill_slime.stderr.log"
        Arguments = @(
            "--headless", "--path", $repoPath, "--fixed-fps", "120", "--audio-driver", "Dummy",
            "--log-file", (Join-Path $outputDirectory "mode_skill_slime.godot.log"),
            "-s", "res://tests/tools/run_mode_skill_slime_measurement.gd", "--",
            "--seed-count=$SlimeSeedCount", "--turn-cap=$SlimeTurnCap", "--output=$slimeOutput"
        )
    }

    if ($ReuseCompleted) {
        $pendingTasks = @()
        foreach ($task in $tasks) {
            if ((Test-Path -LiteralPath $task.Output) -and (Get-Item -LiteralPath $task.Output).Length -gt 0) {
                Write-Output ("MODE_SKILL_REUSE name={0} output={1}" -f $task.Name, $task.Output)
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
            Write-Output ("MODE_SKILL_START name={0} pid={1}" -f $task.Name, $process.Id)
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
            Write-Output ("MODE_SKILL_DONE name={0} exit=0 seconds={1}" -f $entry.Task.Name, $duration)
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

function Get-CoefficientOfVariation($Values) {
    $items = @($Values | ForEach-Object { [double]$_ })
    $mean = Get-Mean $items
    if ($items.Count -eq 0 -or $mean -eq 0.0) { return 0.0 }
    $squared = @($items | ForEach-Object { ([double]$_ - $mean) * ([double]$_ - $mean) })
    return [Math]::Sqrt((Get-Mean $squared)) / $mean
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
    return [ordered]@{
        median = Get-Median $values
        mean = Get-Mean $values
    }
}

function Get-Sum($Rows, [string]$Field) {
    return [double](Get-Mean @($Rows | ForEach-Object { [double]$_.$Field })) * @($Rows).Count
}

function New-ClassicStrategySummary($Rows) {
    $gameOvers = @($Rows | Where-Object { [bool]$_.game_over })
    $blockedEnds = @($gameOvers | Where-Object { [bool]$_.blocked_direction_game_over }).Count
    return [ordered]@{
        games = @($Rows).Count
        turns = New-Stats $Rows "completed_turns"
        score = New-Stats $Rows "score"
        max_level_mean = Get-Mean @($Rows | ForEach-Object { [double]$_.max_level_reached })
        max_level_peak = [int](($Rows | Measure-Object -Property max_level_reached -Maximum).Maximum)
        level_7_games = @($Rows | Where-Object { [int]$_.max_level_reached -ge 7 }).Count
        blast_total = [int](Get-Sum $Rows "blast_count")
        jackpot_total = [int](Get-Sum $Rows "max_clear_count")
        game_over_count = $gameOvers.Count
        blocked_direction_game_over_count = $blockedEnds
        blocked_direction_game_over_ratio = Get-SafeRatio $blockedEnds $gameOvers.Count
    }
}

function New-BlitzStrategySummary($Rows) {
    return [ordered]@{
        games = @($Rows).Count
        survived_seconds = New-Stats $Rows "play_time"
        score = New-Stats $Rows "score"
        max_level_mean = Get-Mean @($Rows | ForEach-Object { [double]$_.max_level_reached })
        max_level_peak = [int](($Rows | Measure-Object -Property max_level_reached -Maximum).Maximum)
        level_7_games = @($Rows | Where-Object { [int]$_.max_level_reached -ge 7 }).Count
        blast_total = [int](Get-Sum $Rows "blast_count")
        jackpot_total = [int](Get-Sum $Rows "jackpot_count")
        cap_reached = @($Rows | Where-Object { [bool]$_.measurement_cap_reached }).Count
    }
}

function New-SlimeStrategySummary($Rows) {
    return [ordered]@{
        games = @($Rows).Count
        turns = New-Stats $Rows "turns"
        score = New-Stats $Rows "score"
        max_level_mean = Get-Mean @($Rows | ForEach-Object { [double]$_.max_level_reached })
        max_level_peak = [int](($Rows | Measure-Object -Property max_level_reached -Maximum).Maximum)
        max_mass_peak = [int](($Rows | Measure-Object -Property max_mass_reached -Maximum).Maximum)
        max_completions_total = [int](Get-Sum $Rows "max_completions")
        max_clear_total = [int](Get-Sum $Rows "max_clears")
        turn_cap_reached = @($Rows | Where-Object { [bool]$_.turn_cap_reached }).Count
    }
}

$classicRows = [ordered]@{}
$blitzRows = [ordered]@{}
foreach ($strategy in $strategies) {
    $classicReport = Get-Content -LiteralPath (Get-RawPath "classic" $strategy) -Raw | ConvertFrom-Json
    $classicRows[$strategy] = @($classicReport.ticks[0].seeds)
    $blitzReport = Get-Content -LiteralPath (Get-RawPath "blitz" $strategy) -Raw | ConvertFrom-Json
    $blitzRows[$strategy] = @($blitzReport.seeds)
}
$slimeReport = Get-Content -LiteralPath (Join-Path $outputDirectory "mode_skill_slime.json") -Raw | ConvertFrom-Json
$slimeRows = [ordered]@{}
foreach ($strategy in @("r", "s", "g", "preview_space", "preview_merge")) {
    $slimeRows[$strategy] = @($slimeReport.strategies.PSObject.Properties[$strategy].Value.rows)
}

$classicStrategies = [ordered]@{}
$blitzStrategies = [ordered]@{}
$slimeStrategies = [ordered]@{}
foreach ($strategy in $strategies) {
    $classicStrategies[$strategy] = New-ClassicStrategySummary $classicRows[$strategy]
    $blitzStrategies[$strategy] = New-BlitzStrategySummary $blitzRows[$strategy]
    $slimeStrategies[$strategy] = New-SlimeStrategySummary $slimeRows[$strategy]
}
$slimeStrategies["preview_space"] = New-SlimeStrategySummary $slimeRows["preview_space"]
$slimeStrategies["preview_merge"] = New-SlimeStrategySummary $slimeRows["preview_merge"]

$classicComparison = [ordered]@{
    g_over_r_turns = Get-SafeRatio $classicStrategies.g.turns.median $classicStrategies.r.turns.median
    s_over_r_turns = Get-SafeRatio $classicStrategies.s.turns.median $classicStrategies.r.turns.median
    g_over_r_score = Get-SafeRatio $classicStrategies.g.score.median $classicStrategies.r.score.median
    s_over_r_score = Get-SafeRatio $classicStrategies.s.score.median $classicStrategies.r.score.median
    g_same_seed_win_rate = Get-SameSeedWinRate $classicRows.g $classicRows.r "completed_turns"
    r_turn_cv = Get-CoefficientOfVariation @($classicRows.r | ForEach-Object { $_.completed_turns })
    r_score_cv = Get-CoefficientOfVariation @($classicRows.r | ForEach-Object { $_.score })
}
$slimeComparison = [ordered]@{
    g_over_r_turns = Get-SafeRatio $slimeStrategies.g.turns.median $slimeStrategies.r.turns.median
    s_over_r_turns = Get-SafeRatio $slimeStrategies.s.turns.median $slimeStrategies.r.turns.median
    g_over_r_score = Get-SafeRatio $slimeStrategies.g.score.median $slimeStrategies.r.score.median
    s_over_r_score = Get-SafeRatio $slimeStrategies.s.score.median $slimeStrategies.r.score.median
    g_same_seed_win_rate = Get-SameSeedWinRate $slimeRows.g $slimeRows.r "turns"
    r_turn_cv = Get-CoefficientOfVariation @($slimeRows.r | ForEach-Object { $_.turns })
    r_score_cv = Get-CoefficientOfVariation @($slimeRows.r | ForEach-Object { $_.score })
}
$blitzComparison = [ordered]@{
    g_over_r_seconds = Get-SafeRatio $blitzStrategies.g.survived_seconds.median $blitzStrategies.r.survived_seconds.median
    s_over_r_seconds = Get-SafeRatio $blitzStrategies.s.survived_seconds.median $blitzStrategies.r.survived_seconds.median
    g_over_r_score = Get-SafeRatio $blitzStrategies.g.score.median $blitzStrategies.r.score.median
    s_over_r_score = Get-SafeRatio $blitzStrategies.s.score.median $blitzStrategies.r.score.median
    g_same_seed_win_rate = Get-SameSeedWinRate $blitzRows.g $blitzRows.r "play_time"
    r_seconds_cv = Get-CoefficientOfVariation @($blitzRows.r | ForEach-Object { $_.play_time })
    r_score_cv = Get-CoefficientOfVariation @($blitzRows.r | ForEach-Object { $_.score })
}

function Get-ModeDuration([string]$Mode) {
    $values = @($processDurations.GetEnumerator() | Where-Object { $_.Key -like "$Mode*" } | ForEach-Object { [double]$_.Value })
    if ($values.Count -eq 0) { return 0.0 }
    return [ordered]@{ wall_seconds = ($values | Measure-Object -Maximum).Maximum; process_seconds = ($values | Measure-Object -Sum).Sum }
}

$report = [ordered]@{
    generated_at = [DateTime]::UtcNow.ToString("o")
    engine = (& $GodotPath --version | Select-Object -First 1)
    conditions = [ordered]@{
        classic = [ordered]@{ seeds = "1-$ClassicSeedCount"; turn_cap = $ClassicTurnCap }
        slime = [ordered]@{ seeds = "1-$SlimeSeedCount"; turn_cap = $SlimeTurnCap }
        blitz = [ordered]@{ seeds = "1-$BlitzSeedCount"; swipe_interval_seconds = 0.35; session_cap_seconds = $BlitzSessionCapSeconds }
    }
    classic = [ordered]@{ strategies = $classicStrategies; comparison = $classicComparison; measurement_time = Get-ModeDuration "classic" }
    slime = [ordered]@{ strategies = $slimeStrategies; comparison = $slimeComparison; measurement_time = Get-ModeDuration "slime" }
    blitz = [ordered]@{ strategies = $blitzStrategies; comparison = $blitzComparison; measurement_time = Get-ModeDuration "blitz" }
    summary = @(
        [pscustomobject][ordered]@{ mode = "CLASSIC"; g_over_r_length = $classicComparison.g_over_r_turns; s_over_r_length = $classicComparison.s_over_r_turns; g_same_seed_win_rate = $classicComparison.g_same_seed_win_rate; r_length_cv = $classicComparison.r_turn_cv },
        [pscustomobject][ordered]@{ mode = "SLIME"; g_over_r_length = $slimeComparison.g_over_r_turns; s_over_r_length = $slimeComparison.s_over_r_turns; g_same_seed_win_rate = $slimeComparison.g_same_seed_win_rate; r_length_cv = $slimeComparison.r_turn_cv },
        [pscustomobject][ordered]@{ mode = "BLITZ"; g_over_r_length = $blitzComparison.g_over_r_seconds; s_over_r_length = $blitzComparison.s_over_r_seconds; g_same_seed_win_rate = $blitzComparison.g_same_seed_win_rate; r_length_cv = $blitzComparison.r_seconds_cv }
    )
}

$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output "MODE_SKILL_SUMMARY"
$report.summary | Format-Table -AutoSize | Out-String | Write-Output
Write-Output ("MODE_SKILL_RESULT path={0} exit=0" -f $summaryPath)
