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
$tuningBotIds = @("heuristic_0_6", "random_0_3")
$conditions = @(
    [ordered]@{
        Id = "a_l4_k1"
        Label = "A L4 +0.5 k1"
        BlastMinLevel = 4
        BlastBonus = 0.5
        BonusScale = 1.0
        BotIds = $allBotIds
    },
    [ordered]@{
        Id = "b_l6_k1"
        Label = "B L6 +2.0 k1"
        BlastMinLevel = 6
        BlastBonus = 2.0
        BonusScale = 1.0
        BotIds = $allBotIds
    },
    [ordered]@{
        Id = "b_l6_k0_75"
        Label = "B L6 +2.0 k0.75"
        BlastMinLevel = 6
        BlastBonus = 2.0
        BonusScale = 0.75
        BotIds = $tuningBotIds
    },
    [ordered]@{
        Id = "b_l6_k1_5"
        Label = "B L6 +2.0 k1.5"
        BlastMinLevel = 6
        BlastBonus = 2.0
        BonusScale = 1.5
        BotIds = $tuningBotIds
    },
    [ordered]@{
        Id = "b_l6_k2"
        Label = "B L6 +2.0 k2"
        BlastMinLevel = 6
        BlastBonus = 2.0
        BonusScale = 2.0
        BotIds = $tuningBotIds
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
            $baseName = "blitz_blast_l6_$($condition.Id)_$($bot.Id)"
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
                        "--blitz-survival-bonus-scale=$(Format-Invariant ([double]$condition.BonusScale))",
                        "--blitz-drain-ramp=0.1",
                        "--blitz-blast-min-level=$($condition.BlastMinLevel)",
                        "--blitz-time-bonus-blast=$(Format-Invariant ([double]$condition.BlastBonus))",
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
            Write-Output ("BLITZ_BLAST_L6_START name={0} pid={1}" -f $task.Name, $process.Id)
        }
        foreach ($entry in $running) {
            $entry.Process.WaitForExit()
            $entry.Process.Refresh()
            if ($entry.Process.ExitCode -ne 0) {
                $stdout = Get-Content -LiteralPath $entry.Task.Stdout -Raw -ErrorAction SilentlyContinue
                $stderr = Get-Content -LiteralPath $entry.Task.Stderr -Raw -ErrorAction SilentlyContinue
                throw "$($entry.Task.Name) failed with exit $($entry.Process.ExitCode)`n$stdout`n$stderr"
            }
            Write-Output ("BLITZ_BLAST_L6_DONE name={0} exit=0" -f $entry.Task.Name)
        }
    }

    foreach ($condition in $conditions) {
        foreach ($bot in (Get-ConditionBots $condition)) {
            $baseName = "blitz_blast_l6_$($condition.Id)_$($bot.Id)"
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
            Write-Output ("BLITZ_BLAST_L6_MERGED name={0} seeds={1}" -f $baseName, $rows.Count)
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

function Get-BotSummary(
    [System.Collections.IDictionary]$Condition,
    [System.Collections.IDictionary]$Bot
) {
    $path = Join-Path $outputDirectory "blitz_blast_l6_$($Condition.Id)_$($Bot.Id)_raw.json"
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
        base_blast_bonus = [double]$condition.BlastBonus
        bonus_scale = [double]$condition.BonusScale
        bots = $botReports
    }
}

$defaultCase = @($caseReports | Where-Object { $_.id -eq "b_l6_k1" })[0]
$defaultSurvival = [double]$defaultCase.bots.heuristic_0_6.survived_seconds.p50
$selected = $defaultCase
$requiresQuestion = $false
if ($defaultSurvival -lt 60.0 -or $defaultSurvival -gt 150.0) {
    $alternatives = @($caseReports | Where-Object {
        $_.id -in @("b_l6_k0_75", "b_l6_k1_5", "b_l6_k2")
    })
    $inRange = @($alternatives | Where-Object {
        $value = [double]$_.bots.heuristic_0_6.survived_seconds.p50
        $value -ge 60.0 -and $value -le 150.0
    } | Sort-Object {
        [Math]::Abs([double]$_.bots.heuristic_0_6.survived_seconds.p50 - 90.0)
    })
    if ($inRange.Count -gt 0) {
        $selected = $inRange[0]
    } else {
        $requiresQuestion = $true
        $selected = @($alternatives | Sort-Object {
            [Math]::Abs([double]$_.bots.heuristic_0_6.survived_seconds.p50 - 90.0)
        })[0]
    }
}

$summary = [ordered]@{
    engine = "Godot 4.8-dev3 mono"
    physics_engine = "Jolt Physics"
    physics_ticks_per_second = 120
    seeds = $seedValues
    session_cap_seconds = 600.0
    default_rule = [ordered]@{
        survival_p50_min = 60.0
        survival_p50_max = 150.0
        target_seconds = 90.0
    }
    selected_condition = [string]$selected.id
    selected_bonus_scale = [double]$selected.bonus_scale
    selected_requires_question = $requiresQuestion
    cases = $caseReports
}
$summaryPath = Join-Path $outputDirectory "blitz_blast_l6_summary.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
$consoleRows = @($caseReports | ForEach-Object {
    [ordered]@{
        id = $_.id
        k = $_.bonus_scale
        h06_survival_p50 = $_.bots.heuristic_0_6.survived_seconds.p50
        h06_score_p50 = $_.bots.heuristic_0_6.score.p50
        h06_blast_p50 = $_.bots.heuristic_0_6.blast_count.p50
        h06_jackpot_p50 = $_.bots.heuristic_0_6.jackpot_count.p50
        h06_final_occupancy_p50 = $_.bots.heuristic_0_6.final_occupancy_percent.p50
        h06_max_occupancy_p50 = $_.bots.heuristic_0_6.max_occupancy_percent.p50
    }
})
Write-Output ("BLITZ_BLAST_L6_RESULT {0}" -f ($consoleRows | ConvertTo-Json -Compress -Depth 8))
Write-Output ("BLITZ_BLAST_L6_SELECTION selected={0} k={1} question={2}" -f `
    $selected.id, $selected.bonus_scale, $requiresQuestion)
Write-Output ("BLITZ_BLAST_L6_SUITE exit=0 report={0}" -f $summaryPath)
