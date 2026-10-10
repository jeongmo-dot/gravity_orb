param(
    [string]$GodotPath = "",
    [switch]$AggregateOnly,
    [ValidateRange(1, 24)]
    [int]$Parallelism = 12
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $repoPath "artifacts\measurements"
$seedValues = @(101..112)
$wallLimitPx = 34.0
$pairLimitPx = 68.0
$conditions = @(
    [ordered]@{ Id = "ramp50"; Ramp = 50 },
    [ordered]@{ Id = "ramp40"; Ramp = 40 },
    [ordered]@{ Id = "ramp30"; Ramp = 30 }
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

function Get-Percentile([double[]]$Values, [double]$Ratio) {
    if ($Values.Count -eq 0) { return 0.0 }
    $sorted = @($Values | Sort-Object)
    $index = [int][Math]::Round(($sorted.Count - 1) * $Ratio)
    $index = [Math]::Max(0, [Math]::Min($sorted.Count - 1, $index))
    return [double]$sorted[$index]
}

function Get-Distribution([double[]]$Values) {
    if ($Values.Count -eq 0) {
        return [ordered]@{ min = 0.0; p50 = 0.0; max = 0.0; mean = 0.0 }
    }
    return [ordered]@{
        min = [double](($Values | Measure-Object -Minimum).Minimum)
        p50 = Get-Percentile $Values 0.50
        max = [double](($Values | Measure-Object -Maximum).Maximum)
        mean = [double](($Values | Measure-Object -Average).Average)
    }
}

function Get-DynamicSum([object[]]$Rows, [string]$PropertyName) {
    $result = [ordered]@{}
    foreach ($row in $Rows) {
        $container = $row.$PropertyName
        if ($null -eq $container) { continue }
        foreach ($property in $container.PSObject.Properties) {
            if (-not $result.Contains($property.Name)) { $result[$property.Name] = 0.0 }
            $result[$property.Name] = [double]$result[$property.Name] + [double]$property.Value
        }
    }
    return $result
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

function Invoke-Condition([System.Collections.IDictionary]$Condition) {
    $rawName = "blast_l4_turn_$($Condition.Id)_raw.json"
    $rawPath = Join-Path $outputDirectory $rawName
    if (Test-Path -LiteralPath $rawPath) { return }
    $tasks = @()
    foreach ($seed in $seedValues) {
        $seedName = "blast_l4_turn_$($Condition.Id)_seed${seed}"
        $seedPath = Join-Path $outputDirectory "${seedName}.json"
        if (Test-Path -LiteralPath $seedPath) { continue }
        $tasks += [ordered]@{
            Name = $seedName
            Stdout = Join-Path $outputDirectory "${seedName}.stdout.log"
            Stderr = Join-Path $outputDirectory "${seedName}.stderr.log"
            Arguments = @(
                "--headless", "--path", $repoPath, "--fixed-fps", "120",
                "--audio-driver", "Dummy", "tests/spike/JoltMeasurement.tscn", "--",
                "--jolt-ticks=120", "--jolt-seeds=$seed", "--jolt-max-turns=800",
                "--jolt-no-determinism", "--spawn-ramp-turns=$($Condition.Ramp)",
                "--spawn-count-max=0", "--blast-min-level=4",
                "--blast-push-radius-by-level=0,0,0,0.3,0.55,1,1",
                "--jolt-output=res://artifacts/measurements/${seedName}.json"
            )
        }
    }
    for ($offset = 0; $offset -lt $tasks.Count; $offset += $Parallelism) {
        $lastIndex = [Math]::Min($offset + $Parallelism - 1, $tasks.Count - 1)
        $batch = @($tasks[$offset..$lastIndex])
        $running = @()
        foreach ($task in $batch) {
            Remove-Item -LiteralPath $task.Stdout, $task.Stderr -Force -ErrorAction SilentlyContinue
            $process = Start-Process -FilePath $GodotPath -ArgumentList $task.Arguments `
                -NoNewWindow -PassThru -RedirectStandardOutput $task.Stdout `
                -RedirectStandardError $task.Stderr
            $running += [ordered]@{ Task = $task; Process = $process }
            Write-Output ("BLAST_L4_TURN_START name={0} pid={1}" -f $task.Name, $process.Id)
        }
        foreach ($entry in $running) {
            $entry.Process.WaitForExit()
            $entry.Process.Refresh()
            if ($entry.Process.ExitCode -ne 0) {
                $stdout = Get-Content -LiteralPath $entry.Task.Stdout -Raw -ErrorAction SilentlyContinue
                $stderr = Get-Content -LiteralPath $entry.Task.Stderr -Raw -ErrorAction SilentlyContinue
                throw "$($entry.Task.Name) failed with exit $($entry.Process.ExitCode)`n$stdout`n$stderr"
            }
            Write-Output ("BLAST_L4_TURN_DONE name={0} exit=0" -f $entry.Task.Name)
        }
    }
    $combined = $null
    $combinedTick = $null
    $rows = @()
    foreach ($seed in $seedValues) {
        $seedPath = Join-Path $outputDirectory "blast_l4_turn_$($Condition.Id)_seed${seed}.json"
        if (-not (Test-Path -LiteralPath $seedPath)) { throw "Missing report $seedPath" }
        $seedReport = Get-Content -LiteralPath $seedPath -Raw | ConvertFrom-Json
        $seedTick = @($seedReport.ticks)[0]
        $rows += @($seedTick.seeds)[0]
        if ($null -eq $combined) {
            $combined = $seedReport
            $combinedTick = $combined.ticks[0]
            continue
        }
        $combinedTick.game_over_count = [int]$combinedTick.game_over_count + [int]$seedTick.game_over_count
        $combinedTick.aborted_count = [int]$combinedTick.aborted_count + [int]$seedTick.aborted_count
        foreach ($binProperty in $seedTick.bins.PSObject.Properties) {
            $targetBin = $combinedTick.bins.($binProperty.Name)
            $sourceBin = $binProperty.Value
            $targetBin.max_wall_penetration_px = [Math]::Max(
                [double]$targetBin.max_wall_penetration_px,
                [double]$sourceBin.max_wall_penetration_px
            )
            $targetBin.max_pair_penetration_px = [Math]::Max(
                [double]$targetBin.max_pair_penetration_px,
                [double]$sourceBin.max_pair_penetration_px
            )
            $targetBin.departures = [int]$targetBin.departures + [int]$sourceBin.departures
            $targetBin.divergences = [int]$targetBin.divergences + [int]$sourceBin.divergences
        }
    }
    $combinedTick.seeds = $rows
    $combined | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $rawPath -Encoding utf8
    Write-Output ("BLAST_L4_TURN_MERGED name={0} seeds={1}" -f $Condition.Id, $rows.Count)
}

function Get-RawRows([System.Collections.IDictionary]$Condition) {
    $rawPath = Join-Path $outputDirectory "blast_l4_turn_$($Condition.Id)_raw.json"
    if (-not (Test-Path -LiteralPath $rawPath)) {
        throw "Missing raw report $rawPath"
    }
    $report = Get-Content -LiteralPath $rawPath -Raw | ConvertFrom-Json
    if ([int]$report.blast_min_level -ne 4) { throw "Blast minimum mismatch" }
    if ([int]$report.spawn_count_ramp_turns -ne [int]$Condition.Ramp) {
        throw "Ramp mismatch for $($Condition.Id)"
    }
    return @(@($report.ticks)[0].seeds)
}

if (-not $AggregateOnly) {
    Invoke-Condition $conditions[0]
}

$baseRows = @(Get-RawRows $conditions[0])
$baseLengths = [double[]]@($baseRows | ForEach-Object { [double]$_.completed_turns })
$baseReached800 = @($baseRows | Where-Object {
    -not [bool]$_.game_over -and [int]$_.completed_turns -ge 800
}).Count
$baseP50 = Get-Percentile $baseLengths 0.50
$runExtraRamps = $baseReached800 -gt 0 -or $baseP50 -gt 250.0

if ($runExtraRamps -and -not $AggregateOnly) {
    Invoke-Condition $conditions[1]
    Invoke-Condition $conditions[2]
}

$selectedConditions = @($conditions[0])
if ($runExtraRamps) { $selectedConditions += @($conditions[1], $conditions[2]) }
$caseReports = @()
foreach ($condition in $selectedConditions) {
    $rows = @(Get-RawRows $condition)
    $allTurnRows = @($rows | ForEach-Object { @($_.turn_rows) })
    $lateRows = @($allTurnRows | Where-Object { [int]$_.turn -ge 201 })
    $lateZeroCount = @($lateRows | Where-Object { [int]$_.reactions -eq 0 }).Count
    $lateZeroPercent = if ($lateRows.Count -gt 0) {
        100.0 * [double]$lateZeroCount / [double]$lateRows.Count
    } else { 0.0 }
    $maxWall = 0.0
    $maxPair = 0.0
    $departures = 0
    $divergences = 0
    $rawPath = Join-Path $outputDirectory "blast_l4_turn_$($condition.Id)_raw.json"
    $rawReport = Get-Content -LiteralPath $rawPath -Raw | ConvertFrom-Json
    $tick = @($rawReport.ticks)[0]
    foreach ($binProperty in $tick.bins.PSObject.Properties) {
        $bin = $binProperty.Value
        $maxWall = [Math]::Max($maxWall, [double]$bin.max_wall_penetration_px)
        $maxPair = [Math]::Max($maxPair, [double]$bin.max_pair_penetration_px)
        $departures += [int]$bin.departures
        $divergences += [int]$bin.divergences
    }
    $lengths = [double[]]@($rows | ForEach-Object { [double]$_.completed_turns })
    $scores = [double[]]@($rows | ForEach-Object { [double]$_.score })
    $blasts = [double[]]@($rows | ForEach-Object { [double]$_.blast_count })
    $occupancies = [double[]]@($rows | ForEach-Object { [double]$_.final_occupancy_percent })
    $finalSpawnCounts = [double[]]@($rows | ForEach-Object {
        1.0 + [Math]::Floor(([Math]::Max([int]$_.completed_turns, 1) - 1) / [double]$condition.Ramp)
    })
    $reached800 = @($rows | Where-Object {
        -not [bool]$_.game_over -and [int]$_.completed_turns -ge 800
    }).Count
    $caseReports += [ordered]@{
        id = [string]$condition.Id
        spawn_count_ramp_turns = [int]$condition.Ramp
        seed_count = $rows.Count
        game_over_count = @($rows | Where-Object { [bool]$_.game_over }).Count
        reached_800_count = $reached800
        game_length = Get-Distribution $lengths
        score = Get-Distribution $scores
        blast = Get-Distribution $blasts
        blast_count_by_level = Get-DynamicSum $rows "blast_count_by_level"
        blast_moved_orb_ratio_by_level = Get-WeightedBlastMovedRatios $rows
        late_zero_reaction_turn_percent = $lateZeroPercent
        final_turn_spawn_count = Get-Distribution $finalSpawnCounts
        final_occupancy_percent = Get-Distribution $occupancies
        max_wall_penetration_px = $maxWall
        max_pair_penetration_px = $maxPair
        departures = $departures
        divergences = $divergences
        physics_within_limits = (
            $maxWall -le $wallLimitPx -and $maxPair -le $pairLimitPx -and
            $departures -eq 0 -and $divergences -eq 0 -and
            [int]$tick.aborted_count -eq 0
        )
    }
}

$summary = [ordered]@{
    engine = "Godot 4.8-dev3 mono"
    physics_engine = "Jolt Physics"
    physics_ticks_per_second = 120
    seeds = @(101..112)
    max_turns = 800
    blast_min_level = 4
    blast_push_radius_by_level = @(0, 0, 0, 0.3, 0.55, 1.0, 1.0)
    previous_l6_baseline = [ordered]@{ game_length_p50 = 162.0; source = "#60" }
    extra_ramp_trigger = [ordered]@{
        reached_800_count = $baseReached800
        base_game_length_p50 = $baseP50
        triggered = $runExtraRamps
        rule = "reached_800_count > 0 or base_game_length_p50 > 250"
    }
    thresholds = [ordered]@{ wall_limit_px = $wallLimitPx; pair_limit_px = $pairLimitPx }
    cases = $caseReports
}
$summaryPath = Join-Path $outputDirectory "blast_l4_turn_summary.json"
$summary | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output ("BLAST_L4_TURN_RESULT {0}" -f ($caseReports | ConvertTo-Json -Compress -Depth 10))
Write-Output ("BLAST_L4_TURN_SUITE exit=0 trigger={0} report={1}" -f $runExtraRamps, $summaryPath)
