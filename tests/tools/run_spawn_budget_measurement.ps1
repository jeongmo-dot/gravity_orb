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
$summaryPath = Join-Path $outputDirectory "spawn_budget_strategy_measurement.json"
$variants = @(
    [pscustomobject]@{ Name = "B"; Max = 0; Costs = "1,1" },
    [pscustomobject]@{ Name = "M0"; Max = 5; Costs = "1,1" },
    [pscustomobject]@{ Name = "M2"; Max = 5; Costs = "1,2" },
    [pscustomobject]@{ Name = "M3"; Max = 5; Costs = "1,3" }
)
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = if ([string]::IsNullOrWhiteSpace($env:GODOT)) {
        "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
    } else {
        $env:GODOT
    }
}
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

function Get-SeedShards([int]$Count, [int]$Size) {
    $result = @()
    for ($start = 1; $start -le $Count; $start += $Size) {
        $end = [Math]::Min($start + $Size - 1, $Count)
        $result += [pscustomobject]@{
            Start = $start
            End = $end
            Csv = (@($start..$end) -join ",")
        }
    }
    return $result
}

function Get-TaskName($Variant, [string]$Strategy, $Shard) {
    return "spawn_budget_$($Variant.Name)_${Strategy}_part$($Shard.Start)-$($Shard.End)"
}

if (-not $AggregateOnly) {
    $tasks = @()
    foreach ($variant in $variants) {
        foreach ($strategy in @("r", "g", "l_merge")) {
            $shardSize = if ($strategy -eq "l_merge") { 1 } else { 5 }
            foreach ($shard in @(Get-SeedShards $SeedCount $shardSize)) {
                $name = Get-TaskName $variant $strategy $shard
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
                        "--spawn-count-max=$($variant.Max)", "--spawn-level-costs=$($variant.Costs)",
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
            Write-Output "SPAWN_BUDGET_STRATEGY_START name=$($task.Name) pid=$($process.Id)"
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
            if (-not (Test-Path -LiteralPath $entry.Task.Output)) {
                throw "Missing $($entry.Task.Output)"
            }
            Write-Output "SPAWN_BUDGET_STRATEGY_DONE name=$($entry.Task.Name) exit=0"
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

function Get-BlastCounts($Rows) {
    $result = [ordered]@{}
    foreach ($row in @($Rows)) {
        foreach ($property in $row.blast_count_by_level.PSObject.Properties) {
            if (-not $result.Contains($property.Name)) { $result[$property.Name] = 0 }
            $result[$property.Name] += [int]$property.Value
        }
    }
    return $result
}

function Get-Summary($Rows) {
    $turns = @($Rows | ForEach-Object { [double]$_.completed_turns })
    $scores = @($Rows | ForEach-Object { [double]$_.score })
    return [ordered]@{
        games = @($Rows).Count
        game_over_count = @($Rows | Where-Object { $_.game_over }).Count
        turns_median = Get-Median $turns
        turns_mean = ($turns | Measure-Object -Average).Average
        score_median = Get-Median $scores
        score_mean = ($scores | Measure-Object -Average).Average
        blast_count = [int](($Rows | Measure-Object -Property blast_count -Sum).Sum)
        blast_count_by_level = Get-BlastCounts $Rows
    }
}

function Get-VariantReport($Variant) {
    $rows = [ordered]@{ r = @(); g = @(); l_merge = @() }
    foreach ($strategy in @($rows.Keys)) {
        $shardSize = if ($strategy -eq "l_merge") { 1 } else { 5 }
        foreach ($shard in @(Get-SeedShards $SeedCount $shardSize)) {
            $name = Get-TaskName $Variant $strategy $shard
            $filePath = Join-Path $outputDirectory "$name.json"
            if (-not (Test-Path -LiteralPath $filePath)) { throw "Missing $filePath" }
            $rows[$strategy] += @((Get-Content -LiteralPath $filePath -Raw | ConvertFrom-Json).ticks[0].seeds)
        }
        $rows[$strategy] = @($rows[$strategy] | Sort-Object { [int]$_.seed })
        if ($rows[$strategy].Count -ne $SeedCount) {
            throw "$($Variant.Name) $strategy expected $SeedCount rows, got $($rows[$strategy].Count)"
        }
    }
    $strategies = [ordered]@{}
    foreach ($strategy in @($rows.Keys)) { $strategies[$strategy] = Get-Summary $rows[$strategy] }
    return [ordered]@{
        spawn_count_max = $Variant.Max
        spawn_level_costs = $Variant.Costs
        strategies = $strategies
        skill_length_ratio_l_merge_over_r = Get-Ratio $strategies.l_merge.turns_median $strategies.r.turns_median
        skill_score_ratio_l_merge_over_r = Get-Ratio $strategies.l_merge.score_median $strategies.r.score_median
        same_seed_length_win_rate = Get-SameSeedWinRate $rows.l_merge $rows.r "completed_turns"
        same_seed_score_win_rate = Get-SameSeedWinRate $rows.l_merge $rows.r "score"
    }
}

$candidateReport = [ordered]@{}
foreach ($variant in $variants) {
    $candidateReport[$variant.Name] = Get-VariantReport $variant
}
$report = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    conditions = "B/M0/M2/M3, R/G/L-merge, seeds 1-$SeedCount, $TurnCap turns, fixed 120 fps"
    candidates = $candidateReport
}
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output "SPAWN_BUDGET_STRATEGY_REPORT $summaryPath"
