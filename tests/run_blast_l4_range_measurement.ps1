param(
    [string]$GodotPath = "",
    [switch]$AggregateOnly,
    [ValidateRange(1, 32)]
    [int]$Parallelism = 16
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $repoPath "artifacts\measurements"
$seedValues = @(101..112)
$bots = @(
    [ordered]@{ Id = "heuristic_0_3"; Kind = "heuristic"; Interval = 0.3 },
    [ordered]@{ Id = "heuristic_0_6"; Kind = "heuristic"; Interval = 0.6 },
    [ordered]@{ Id = "random_0_3"; Kind = "random"; Interval = 0.3 },
    [ordered]@{ Id = "random_0_6"; Kind = "random"; Interval = 0.6 }
)
$allBotIds = @($bots | ForEach-Object { $_.Id })
$conditions = @(
    [ordered]@{
        Id = "a_l4_full_board"
        Label = "A L4 full-board blast"
        BlastMinLevel = 4
        BlastRadiusByLevel = "0,0,0,1,1,1,1"
        BlastBonusByLevel = "0,0,0,0.5,0.5,0.5,0.5"
        BotIds = $allBotIds
    },
    [ordered]@{
        Id = "b_l4_level_range"
        Label = "B L4 level-scaled blast"
        BlastMinLevel = 4
        BlastRadiusByLevel = "0,0,0,0.3,0.55,1,1"
        BlastBonusByLevel = "0,0,0,0.5,1,2,3"
        BotIds = $allBotIds
    }
)

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
        $GodotPath = $env:GODOT
    } elseif (Test-Path -LiteralPath "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe") {
        $GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe"
    } else {
        $GodotPath = "godot"
    }
}

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

function Format-Invariant([double]$Value) {
    return $Value.ToString("0.################", [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-ConditionBots([System.Collections.IDictionary]$Condition) {
    return @($bots | Where-Object { $Condition.BotIds -contains $_.Id })
}

if (-not $AggregateOnly) {
    $tasks = @()
    foreach ($condition in $conditions) {
        foreach ($bot in (Get-ConditionBots $condition)) {
            $baseName = "blast_l4_range_$($condition.Id)_$($bot.Id)"
            $combinedPath = Join-Path $outputDirectory "${baseName}_raw.json"
            if (Test-Path -LiteralPath $combinedPath) { continue }
            foreach ($seed in $seedValues) {
                $seedName = "${baseName}_seed${seed}"
                $seedPath = Join-Path $outputDirectory "${seedName}.json"
                if (Test-Path -LiteralPath $seedPath) { continue }
                $tasks += [ordered]@{
                    Name = $seedName
                    Stdout = Join-Path $outputDirectory "${seedName}.stdout.log"
                    Stderr = Join-Path $outputDirectory "${seedName}.stderr.log"
                    Arguments = @(
                        "--headless", "--path", $repoPath, "--fixed-fps", "120",
                        "--audio-driver", "Dummy", "res://tests/spike/BlitzMeasurement.tscn", "--",
                        "--blitz-bot=$($bot.Kind)",
                        "--blitz-bot-interval=$(Format-Invariant ([double]$bot.Interval))",
                        "--blitz-color-count=6", "--blitz-refill-rule=target",
                        "--blitz-seeds=$seed",
                        "--blitz-survival-bonus-scale=1",
                        "--blitz-drain-ramp=0.1",
                        "--blast-min-level=$($condition.BlastMinLevel)",
                        "--blast-push-radius-by-level=$($condition.BlastRadiusByLevel)",
                        "--blitz-time-bonus-blast-by-level=$($condition.BlastBonusByLevel)",
                        "--blitz-output=res://artifacts/measurements/${seedName}.json"
                    )
                }
            }
        }
    }

    for ($offset = 0; $offset -lt $tasks.Count; $offset += $Parallelism) {
        $lastIndex = [Math]::Min($offset + $Parallelism - 1, $tasks.Count - 1)
        $batch = @($tasks[$offset..$lastIndex])
        $running = @()
        foreach ($task in $batch) {
            Remove-Item -LiteralPath $task.Stdout, $task.Stderr -Force -ErrorAction SilentlyContinue
            $process = Start-Process `
                -FilePath $GodotPath `
                -ArgumentList $task.Arguments `
                -NoNewWindow `
                -PassThru `
                -RedirectStandardOutput $task.Stdout `
                -RedirectStandardError $task.Stderr
            $running += [ordered]@{ Task = $task; Process = $process }
            Write-Output ("BLAST_L4_RANGE_START name={0} pid={1}" -f $task.Name, $process.Id)
        }
        foreach ($entry in $running) {
            $entry.Process.WaitForExit()
            $entry.Process.Refresh()
            if ($entry.Process.ExitCode -ne 0) {
                $stdout = Get-Content -LiteralPath $entry.Task.Stdout -Raw -ErrorAction SilentlyContinue
                $stderr = Get-Content -LiteralPath $entry.Task.Stderr -Raw -ErrorAction SilentlyContinue
                throw "$($entry.Task.Name) failed with exit $($entry.Process.ExitCode)`n$stdout`n$stderr"
            }
            Write-Output ("BLAST_L4_RANGE_DONE name={0} exit=0" -f $entry.Task.Name)
        }
    }

    foreach ($condition in $conditions) {
        foreach ($bot in (Get-ConditionBots $condition)) {
            $baseName = "blast_l4_range_$($condition.Id)_$($bot.Id)"
            $combinedPath = Join-Path $outputDirectory "${baseName}_raw.json"
            if (Test-Path -LiteralPath $combinedPath) { continue }
            $combined = $null
            $rows = @()
            foreach ($seed in $seedValues) {
                $seedPath = Join-Path $outputDirectory "${baseName}_seed${seed}.json"
                if (-not (Test-Path -LiteralPath $seedPath)) {
                    throw "Missing per-seed report $seedPath"
                }
                $seedReport = Get-Content -LiteralPath $seedPath -Raw | ConvertFrom-Json
                if ($null -eq $combined) { $combined = $seedReport }
                $rows += @($seedReport.seeds)[0]
            }
            $combined.seeds = $rows
            $combined | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $combinedPath -Encoding utf8
            Write-Output ("BLAST_L4_RANGE_MERGED name={0} seeds={1}" -f $baseName, $rows.Count)
        }
    }
}

function Get-Percentile([double[]]$Values, [double]$Ratio) {
    if ($Values.Count -eq 0) { return 0.0 }
    $sorted = @($Values | Sort-Object)
    $index = [int][Math]::Round(($sorted.Count - 1) * $Ratio)
    $index = [Math]::Max(0, [Math]::Min($sorted.Count - 1, $index))
    return [double]$sorted[$index]
}

function Get-Distribution([double[]]$Values) {
    if ($Values.Count -eq 0) {
        return [ordered]@{ p50 = 0.0; p90 = 0.0; max = 0.0; mean = 0.0 }
    }
    return [ordered]@{
        p50 = Get-Percentile $Values 0.50
        p90 = Get-Percentile $Values 0.90
        max = [double](($Values | Measure-Object -Maximum).Maximum)
        mean = [double](($Values | Measure-Object -Average).Average)
    }
}

function Get-DynamicSum([object[]]$Rows, [string]$PropertyName) {
    $sums = [ordered]@{}
    foreach ($row in $Rows) {
        $container = $row.$PropertyName
        if ($null -eq $container) { continue }
        foreach ($property in $container.PSObject.Properties) {
            if (-not $sums.Contains($property.Name)) { $sums[$property.Name] = 0.0 }
            $sums[$property.Name] = [double]$sums[$property.Name] + [double]$property.Value
        }
    }
    return $sums
}

function Get-WeightedBlastMovedRatios([object[]]$Rows) {
    $counts = [ordered]@{}
    $weightedSums = [ordered]@{}
    foreach ($row in $Rows) {
        $countContainer = $row.blast_count_by_level
        $ratioContainer = $row.blast_moved_orb_ratio_by_level
        if ($null -eq $countContainer -or $null -eq $ratioContainer) { continue }
        foreach ($property in $countContainer.PSObject.Properties) {
            $level = [int]$property.Name.TrimStart('L')
            $key = if ($level -ge 6) { "L6_plus" } else { "L$level" }
            $count = [double]$property.Value
            $ratioProperty = $ratioContainer.PSObject.Properties[$property.Name]
            $ratio = if ($null -eq $ratioProperty) { 0.0 } else { [double]$ratioProperty.Value }
            if (-not $counts.Contains($key)) {
                $counts[$key] = 0.0
                $weightedSums[$key] = 0.0
            }
            $counts[$key] = [double]$counts[$key] + $count
            $weightedSums[$key] = [double]$weightedSums[$key] + $ratio * $count
        }
    }
    $result = [ordered]@{}
    foreach ($key in $counts.Keys) {
        $result[$key] = if ([double]$counts[$key] -gt 0.0) {
            [double]$weightedSums[$key] / [double]$counts[$key]
        } else { 0.0 }
    }
    return $result
}

function Get-BotSummary(
    [System.Collections.IDictionary]$Condition,
    [System.Collections.IDictionary]$Bot
) {
    $path = Join-Path $outputDirectory "blast_l4_range_$($Condition.Id)_$($Bot.Id)_raw.json"
    $report = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $rows = @($report.seeds)
    $playMinutes = [double](($rows | Measure-Object -Property play_time -Sum).Sum) / 60.0
    $bonusTotals = Get-DynamicSum $rows "time_bonus_by_source"
    $bonusPerMinute = [ordered]@{}
    foreach ($key in $bonusTotals.Keys) {
        $bonusPerMinute[$key] = if ($playMinutes -gt 0.0) {
            [double]$bonusTotals[$key] / $playMinutes
        } else { 0.0 }
    }
    return [ordered]@{
        bot = [string]$Bot.Kind
        interval = [double]$Bot.Interval
        seed_count = $rows.Count
        completed_count = @($rows | Where-Object { [bool]$_.completed }).Count
        cap_reached_count = @($rows | Where-Object { [bool]$_.measurement_cap_reached }).Count
        survived_seconds = Get-Distribution @($rows | ForEach-Object { [double]$_.play_time })
        score = Get-Distribution @($rows | ForEach-Object { [double]$_.score })
        merge_count_by_result_level = Get-DynamicSum $rows "merge_count_by_result_level"
        blast_count = Get-Distribution @($rows | ForEach-Object { [double]$_.blast_count })
        blast_count_by_level = Get-DynamicSum $rows "blast_count_by_level"
        blast_moved_orb_ratio_by_level = Get-WeightedBlastMovedRatios $rows
        jackpot_count = Get-Distribution @($rows | ForEach-Object { [double]$_.jackpot_count })
        finale_blast_count = Get-Distribution @($rows | ForEach-Object { [double]$_.finale_blast_count })
        time_bonus_by_source_per_minute = $bonusPerMinute
        fever_time_percent = Get-Distribution @($rows | ForEach-Object { [double]$_.fever_time_percent })
        final_occupancy_percent = Get-Distribution @($rows | ForEach-Object {
            [double]$_.final_occupancy_percent
        })
        max_occupancy_percent = Get-Distribution @($rows | ForEach-Object {
            [double]$_.max_occupancy_percent
        })
        max_wall_penetration_px = [double](($rows |
            Measure-Object -Property max_wall_penetration_px -Maximum).Maximum)
        max_pair_penetration_px = [double](($rows |
            Measure-Object -Property max_pair_penetration_px_sampled_10hz -Maximum).Maximum)
        departures = [int](($rows | Measure-Object -Property departures -Sum).Sum)
        divergences = [int](($rows | Measure-Object -Property divergences -Sum).Sum)
    }
}

$caseReports = @()
foreach ($condition in $conditions) {
    $botReports = [ordered]@{}
    foreach ($bot in (Get-ConditionBots $condition)) {
        $botReports[$bot.Id] = Get-BotSummary $condition $bot
    }
    $caseReports += [ordered]@{
        id = [string]$condition.Id
        label = [string]$condition.Label
        blast_min_level = [int]$condition.BlastMinLevel
        blast_push_radius_by_level = [string]$condition.BlastRadiusByLevel
        blast_time_bonus_by_level = [string]$condition.BlastBonusByLevel
        bots = $botReports
    }
}

$summary = [ordered]@{
    engine = "Godot 4.8-dev3 mono"
    physics_engine = "Jolt Physics"
    physics_ticks_per_second = 120
    seeds = $seedValues
    session_cap_seconds = 600.0
    cases = $caseReports
}
$summaryPath = Join-Path $outputDirectory "blast_l4_range_summary.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
$consoleRows = @($caseReports | ForEach-Object {
    [ordered]@{
        id = $_.id
        h06_survival_p50 = $_.bots.heuristic_0_6.survived_seconds.p50
        h06_score_p50 = $_.bots.heuristic_0_6.score.p50
        h06_blast_p50 = $_.bots.heuristic_0_6.blast_count.p50
        h06_jackpot_p50 = $_.bots.heuristic_0_6.jackpot_count.p50
        h06_final_occupancy_p50 = $_.bots.heuristic_0_6.final_occupancy_percent.p50
        h06_max_occupancy_p50 = $_.bots.heuristic_0_6.max_occupancy_percent.p50
    }
})
Write-Output ("BLAST_L4_RANGE_RESULT {0}" -f ($consoleRows | ConvertTo-Json -Compress -Depth 8))
Write-Output ("BLAST_L4_RANGE_SUITE exit=0 report={0}" -f $summaryPath)
