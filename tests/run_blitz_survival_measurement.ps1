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
$conditions = @(
    [ordered]@{ Id = "k0_5_r0"; BonusScale = 0.5; Ramp = 0.0 },
    [ordered]@{ Id = "k0_5_r0_1"; BonusScale = 0.5; Ramp = 0.1 },
    [ordered]@{ Id = "k1_r0"; BonusScale = 1.0; Ramp = 0.0 },
    [ordered]@{ Id = "k1_r0_1"; BonusScale = 1.0; Ramp = 0.1 },
    [ordered]@{ Id = "k2_r0"; BonusScale = 2.0; Ramp = 0.0 },
    [ordered]@{ Id = "k2_r0_1"; BonusScale = 2.0; Ramp = 0.1 }
)
$bots = @(
    [ordered]@{ Id = "heuristic_0_3"; Kind = "heuristic"; Interval = 0.3 },
    [ordered]@{ Id = "heuristic_0_6"; Kind = "heuristic"; Interval = 0.6 },
    [ordered]@{ Id = "random_0_3"; Kind = "random"; Interval = 0.3 },
    [ordered]@{ Id = "random_0_6"; Kind = "random"; Interval = 0.6 }
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

if (-not $AggregateOnly) {
    $tasks = @()
    foreach ($condition in $conditions) {
        foreach ($bot in $bots) {
            $baseName = "blitz_survival_$($condition.Id)_$($bot.Id)"
            $combinedPath = Join-Path $outputDirectory "${baseName}_raw.json"
            if (Test-Path -LiteralPath $combinedPath) { continue }
            foreach ($seed in $seedValues) {
                $seedName = "${baseName}_seed${seed}"
                $seedPath = Join-Path $outputDirectory "${seedName}.json"
                if (Test-Path -LiteralPath $seedPath) { continue }
                $tasks += [ordered]@{
                    Name = $seedName
                    Output = "res://artifacts/measurements/${seedName}.json"
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
                        "--blitz-drain-ramp=$(Format-Invariant ([double]$condition.Ramp))",
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
            Write-Output ("BLITZ_SURVIVAL_START name={0} pid={1}" -f $task.Name, $process.Id)
        }
        foreach ($entry in $running) {
            $entry.Process.WaitForExit()
            $entry.Process.Refresh()
            if ($entry.Process.ExitCode -ne 0) {
                $stdout = Get-Content -LiteralPath $entry.Task.Stdout -Raw -ErrorAction SilentlyContinue
                $stderr = Get-Content -LiteralPath $entry.Task.Stderr -Raw -ErrorAction SilentlyContinue
                throw "$($entry.Task.Name) failed with exit $($entry.Process.ExitCode)`n$stdout`n$stderr"
            }
            Write-Output ("BLITZ_SURVIVAL_DONE name={0} exit=0" -f $entry.Task.Name)
        }
    }

    foreach ($condition in $conditions) {
        foreach ($bot in $bots) {
            $baseName = "blitz_survival_$($condition.Id)_$($bot.Id)"
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
            Write-Output ("BLITZ_SURVIVAL_MERGED name={0} seeds={1}" -f $baseName, $rows.Count)
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
    $path = Join-Path $outputDirectory "blitz_survival_$($Condition.Id)_$($Bot.Id)_raw.json"
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
    $mergeCounts = Get-DynamicSum $rows "merge_count_by_result_level"
    $firstL4 = @($rows | Where-Object { [double]$_.first_l4_merge_time -ge 0.0 } |
        ForEach-Object { [double]$_.first_l4_merge_time })
    return [ordered]@{
        bot = [string]$Bot.Kind
        interval = [double]$Bot.Interval
        seed_count = $rows.Count
        completed_count = @($rows | Where-Object { [bool]$_.completed }).Count
        cap_reached_count = @($rows | Where-Object { [bool]$_.measurement_cap_reached }).Count
        survived_seconds = Get-Distribution @($rows | ForEach-Object { [double]$_.play_time })
        score = Get-Distribution @($rows | ForEach-Object { [double]$_.score })
        time_bonus_total = Get-Distribution @($rows | ForEach-Object { [double]$_.time_bonus_total })
        time_bonus_by_source_per_minute = $bonusPerMinute
        merge_count_by_result_level = $mergeCounts
        blast_count = Get-Distribution @($rows | ForEach-Object { [double]$_.blast_count })
        fever_time_percent = Get-Distribution @($rows | ForEach-Object { [double]$_.fever_time_percent })
        first_l4_merge_seconds_p50 = Get-Percentile $firstL4 0.50
        first_l4_merge_missing_count = $rows.Count - $firstL4.Count
        final_occupancy_percent = Get-Distribution @($rows | ForEach-Object {
            [double]$_.final_occupancy_percent
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
    foreach ($bot in $bots) {
        $botReports[$bot.Id] = Get-BotSummary $condition $bot
    }
    $same03 = if ([double]$botReports.heuristic_0_3.score.p50 -gt 0.0) {
        [double]$botReports.random_0_3.score.p50 / [double]$botReports.heuristic_0_3.score.p50
    } else { 0.0 }
    $same06 = if ([double]$botReports.heuristic_0_6.score.p50 -gt 0.0) {
        [double]$botReports.random_0_6.score.p50 / [double]$botReports.heuristic_0_6.score.p50
    } else { 0.0 }
    $crossScore = if ([double]$botReports.heuristic_0_6.score.p50 -gt 0.0) {
        [double]$botReports.random_0_3.score.p50 / [double]$botReports.heuristic_0_6.score.p50
    } else { 0.0 }
    $crossSurvival = if ([double]$botReports.heuristic_0_6.survived_seconds.p50 -gt 0.0) {
        [double]$botReports.random_0_3.survived_seconds.p50 /
            [double]$botReports.heuristic_0_6.survived_seconds.p50
    } else { 0.0 }
    $capCount = 0
    foreach ($botId in @("heuristic_0_3", "heuristic_0_6", "random_0_3", "random_0_6")) {
        $capCount += [int]$botReports[$botId].cap_reached_count
    }
    $passes = (
        [double]$botReports.heuristic_0_6.survived_seconds.p50 -ge 90.0 -and
        [double]$botReports.heuristic_0_6.survived_seconds.p50 -le 180.0 -and
        $crossSurvival -le 0.6 -and
        $crossScore -le 0.5 -and
        $capCount -eq 0
    )
    $caseReports += [ordered]@{
        id = [string]$condition.Id
        bonus_scale = [double]$condition.BonusScale
        drain_ramp_per_minute = [double]$condition.Ramp
        bots = $botReports
        random_to_heuristic_score_ratio_0_3 = $same03
        random_to_heuristic_score_ratio_0_6 = $same06
        random_0_3_to_heuristic_0_6_score_ratio = $crossScore
        random_0_3_to_heuristic_0_6_survival_ratio = $crossSurvival
        cap_reached_count = $capCount
        passes_all_criteria = $passes
    }
}

$defaultCase = @($caseReports | Where-Object { $_.id -eq "k1_r0_1" })[0]
$selected = $null
$requiresQuestion = $false
if ($defaultCase.passes_all_criteria) {
    $selected = $defaultCase
} else {
    $passing = @($caseReports | Where-Object { $_.passes_all_criteria } | Sort-Object `
        random_0_3_to_heuristic_0_6_score_ratio, drain_ramp_per_minute)
    if ($passing.Count -gt 0) {
        $selected = $passing[0]
    } else {
        $requiresQuestion = $true
        foreach ($case in $caseReports) {
            $survival = [double]$case.bots.heuristic_0_6.survived_seconds.p50
            $survivalPenalty = if ($survival -lt 90.0) { (90.0 - $survival) / 90.0 } `
                elseif ($survival -gt 180.0) { ($survival - 180.0) / 180.0 } else { 0.0 }
            $case["selection_distance"] = (
                $survivalPenalty +
                [Math]::Max(0.0, [double]$case.random_0_3_to_heuristic_0_6_survival_ratio - 0.6) +
                [Math]::Max(0.0, [double]$case.random_0_3_to_heuristic_0_6_score_ratio - 0.5) +
                [double]$case.cap_reached_count
            )
        }
        $selected = @($caseReports | Sort-Object `
            { [double]$_["selection_distance"] },
            { [double]$_["drain_ramp_per_minute"] })[0]
    }
}

$summary = [ordered]@{
    engine = "Godot 4.8-dev3 mono"
    physics_engine = "Jolt Physics"
    physics_ticks_per_second = 120
    seeds = @(101..112)
    session_cap_seconds = 600.0
    criteria = [ordered]@{
        heuristic_0_6_survival_p50_min = 90.0
        heuristic_0_6_survival_p50_max = 180.0
        random_0_3_to_heuristic_0_6_survival_ratio_max = 0.6
        random_0_3_to_heuristic_0_6_score_ratio_max = 0.5
        cap_reached_count_max = 0
    }
    selected_condition = [string]$selected.id
    selected_requires_question = $requiresQuestion
    cases = $caseReports
}
$summaryPath = Join-Path $outputDirectory "blitz_survival_summary.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
$consoleRows = @($caseReports | ForEach-Object {
    [ordered]@{
        id = $_.id
        h06_survival_p50 = $_.bots.heuristic_0_6.survived_seconds.p50
        r03_survival_p50 = $_.bots.random_0_3.survived_seconds.p50
        survival_ratio = $_.random_0_3_to_heuristic_0_6_survival_ratio
        h06_score_p50 = $_.bots.heuristic_0_6.score.p50
        r03_score_p50 = $_.bots.random_0_3.score.p50
        score_ratio = $_.random_0_3_to_heuristic_0_6_score_ratio
        cap_count = $_.cap_reached_count
        passes = $_.passes_all_criteria
    }
})
Write-Output ("BLITZ_SURVIVAL_RESULT {0}" -f ($consoleRows | ConvertTo-Json -Compress -Depth 8))
Write-Output ("BLITZ_SURVIVAL_SELECTION selected={0} question={1}" -f `
    $selected.id, $requiresQuestion)
Write-Output ("BLITZ_SURVIVAL_SUITE exit=0 report={0}" -f $summaryPath)
