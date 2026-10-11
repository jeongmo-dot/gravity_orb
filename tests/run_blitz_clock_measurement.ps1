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

function Format-Invariant([double]$Value) {
    return $Value.ToString("0.################", [System.Globalization.CultureInfo]::InvariantCulture)
}

if (-not $AggregateOnly) {
    $tasks = @()
    foreach ($bot in $bots) {
        foreach ($seed in $seedValues) {
            $name = "blitz_clock_default_$($bot.Id)_seed${seed}"
            $path = Join-Path $outputDirectory "${name}.json"
            if (Test-Path -LiteralPath $path) { continue }
            $tasks += [ordered]@{
                Name = $name
                Output = "res://artifacts/measurements/${name}.json"
                Stdout = Join-Path $outputDirectory "${name}.stdout.log"
                Stderr = Join-Path $outputDirectory "${name}.stderr.log"
                Arguments = @(
                    "--headless", "--path", $repoPath, "--fixed-fps", "120",
                    "--audio-driver", "Dummy", "res://tests/spike/BlitzMeasurement.tscn", "--",
                    "--blitz-bot=$($bot.Kind)",
                    "--blitz-bot-interval=$(Format-Invariant ([double]$bot.Interval))",
                    "--blitz-color-count=6", "--blitz-refill-rule=target",
                    "--blitz-seeds=$seed",
                    "--blitz-output=res://artifacts/measurements/${name}.json"
                )
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
                -WindowStyle Hidden `
                -PassThru `
                -RedirectStandardOutput $task.Stdout `
                -RedirectStandardError $task.Stderr
            $running += [ordered]@{ Task = $task; Process = $process }
            Write-Output ("BLITZ_CLOCK_START name={0} pid={1}" -f $task.Name, $process.Id)
        }
        foreach ($entry in $running) {
            $entry.Process.WaitForExit()
            $entry.Process.Refresh()
            if ($entry.Process.ExitCode -ne 0) {
                $stdout = Get-Content -LiteralPath $entry.Task.Stdout -Raw -ErrorAction SilentlyContinue
                $stderr = Get-Content -LiteralPath $entry.Task.Stderr -Raw -ErrorAction SilentlyContinue
                throw "$($entry.Task.Name) failed with exit $($entry.Process.ExitCode)`n$stdout`n$stderr"
            }
            Write-Output ("BLITZ_CLOCK_DONE name={0} exit=0" -f $entry.Task.Name)
        }
    }
}

function Get-Percentile([double[]]$Values, [double]$Ratio) {
    if ($Values.Count -eq 0) { return 0.0 }
    $sorted = @($Values | Sort-Object)
    $index = [int][Math]::Round(($sorted.Count - 1) * $Ratio)
    return [double]$sorted[[Math]::Max(0, [Math]::Min($sorted.Count - 1, $index))]
}

function Get-Distribution([double[]]$Values) {
    return [ordered]@{
        p50 = Get-Percentile $Values 0.50
        p90 = Get-Percentile $Values 0.90
        max = [double](($Values | Measure-Object -Maximum).Maximum)
    }
}

function Get-SourceBonusPerMinute([object[]]$Rows) {
    $totals = [ordered]@{}
    $minutes = [double](($Rows | Measure-Object -Property play_time -Sum).Sum) / 60.0
    foreach ($row in $Rows) {
        foreach ($property in $row.time_bonus_by_source.PSObject.Properties) {
            if (-not $totals.Contains($property.Name)) { $totals[$property.Name] = 0.0 }
            $totals[$property.Name] = [double]$totals[$property.Name] + [double]$property.Value
        }
    }
    $perMinute = [ordered]@{}
    foreach ($key in $totals.Keys) {
        $perMinute[$key] = if ($minutes -gt 0.0) { [double]$totals[$key] / $minutes } else { 0.0 }
    }
    return $perMinute
}

$botReports = [ordered]@{}
$sampleReport = $null
foreach ($bot in $bots) {
    $rows = @()
    foreach ($seed in $seedValues) {
        $path = Join-Path $outputDirectory "blitz_clock_default_$($bot.Id)_seed${seed}.json"
        if (-not (Test-Path -LiteralPath $path)) { throw "Missing measurement report $path" }
        $report = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        if ($null -eq $sampleReport) { $sampleReport = $report }
        $rows += @($report.seeds)[0]
    }
    $botReports[$bot.Id] = [ordered]@{
        bot = $bot.Kind
        interval = [double]$bot.Interval
        seed_count = $rows.Count
        survived_seconds = Get-Distribution @($rows | ForEach-Object { [double]$_.play_time })
        cap_reached_count = @($rows | Where-Object { [bool]$_.measurement_cap_reached }).Count
        score_p50 = Get-Percentile @($rows | ForEach-Object { [double]$_.score }) 0.50
        time_bonus_by_source_per_minute = Get-SourceBonusPerMinute $rows
    }
}

$summary = [ordered]@{
    engine = $sampleReport.engine
    physics_engine = $sampleReport.physics_engine
    physics_ticks_per_second = 120
    seeds = $seedValues
    session_cap_seconds = 600.0
    defaults = [ordered]@{
        blitz_time_max = [double]$sampleReport.config.time_max
        blitz_time_bar_reference = [double]$sampleReport.config.time_bar_reference
        blitz_drain_ramp_per_minute = [double]$sampleReport.survival_drain_ramp_per_minute
    }
    bots = $botReports
}
$summaryPath = Join-Path $outputDirectory "blitz_clock_summary.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output ("BLITZ_CLOCK_RESULT {0}" -f ($summary | ConvertTo-Json -Compress -Depth 20))
Write-Output ("BLITZ_CLOCK_SUITE exit=0 report={0}" -f $summaryPath)
