param(
    [string]$GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe",
    [int]$MaxParallel = 4,
    [string[]]$Modes = @("turn", "blitz"),
    [int[]]$DummyCounts = @(0, 1, 7, 50, 100),
    [int[]]$Seeds = @(101..112),
    [int]$Turns = 120,
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$artifactPath = Join-Path $repoPath "artifacts\jolt_rid_robustness"
$rawPath = Join-Path $artifactPath "raw"
$logPath = Join-Path $artifactPath "logs"
$dummyCounts = @($DummyCounts)
$modes = @($Modes | ForEach-Object { $_.ToLowerInvariant() })
$seeds = @($Seeds)
$MaxParallel = [Math]::Max($MaxParallel, 1)
New-Item -ItemType Directory -Force -Path $rawPath | Out-Null
New-Item -ItemType Directory -Force -Path $logPath | Out-Null

$cases = @()
foreach ($mode in $modes) {
    foreach ($dummyCount in $dummyCounts) {
        foreach ($seed in $seeds) {
            $name = "${mode}_p${dummyCount}_seed${seed}"
            $cases += [pscustomobject]@{
                mode = $mode
                dummy_count = $dummyCount
                seed = $seed
                name = $name
                output = Join-Path $rawPath "$name.json"
                stdout = Join-Path $logPath "$name.stdout.log"
                stderr = Join-Path $logPath "$name.stderr.log"
                godot_log = Join-Path $logPath "$name.godot.log"
            }
        }
    }
}

if (-not $AggregateOnly) {
    $pending = [System.Collections.Generic.Queue[object]]::new()
    foreach ($case in $cases) { $pending.Enqueue($case) }
    $active = @()
    $completed = 0
    while ($pending.Count -gt 0 -or $active.Count -gt 0) {
        while ($pending.Count -gt 0 -and $active.Count -lt $MaxParallel) {
            $case = $pending.Dequeue()
            $relativeOutput = "res://artifacts/jolt_rid_robustness/raw/$($case.name).json"
            $arguments = @(
                "--headless",
                "--path", $repoPath,
                "--fixed-fps", "120",
                "--log-file", $case.godot_log,
                "tests/spike/JoltRidRobustnessMeasurement.tscn",
                "--",
                "--rid-mode=$($case.mode)",
                "--rid-seed=$($case.seed)",
                "--rid-dummy-count=$($case.dummy_count)",
                "--rid-turns=$Turns",
                "--rid-output=$relativeOutput"
            )
            $process = Start-Process `
                -FilePath $GodotPath `
                -ArgumentList $arguments `
                -PassThru `
                -WindowStyle Hidden `
                -RedirectStandardOutput $case.stdout `
                -RedirectStandardError $case.stderr
            $active += [pscustomobject]@{ process = $process; case = $case }
        }
        $finished = @($active | Where-Object { $_.process.HasExited })
        if ($finished.Count -eq 0) {
            Start-Sleep -Milliseconds 250
            continue
        }
        foreach ($entry in $finished) {
            $entry.process.WaitForExit()
            $case = $entry.case
            if ($entry.process.ExitCode -ne 0) {
                $errorText = ""
                if (Test-Path -LiteralPath $case.stderr) {
                    $errorText = Get-Content -LiteralPath $case.stderr -Raw
                }
                throw "Measurement $($case.name) failed with exit code $($entry.process.ExitCode): $errorText"
            }
            if (-not (Test-Path -LiteralPath $case.output)) {
                throw "Measurement $($case.name) did not write $($case.output)"
            }
            $completed += 1
            $summaryLine = Get-Content -LiteralPath $case.stdout |
                Select-String -Pattern "JOLT_RID" |
                Select-Object -Last 1
            Write-Output "[$completed/$($cases.Count)] $summaryLine"
            $active = @($active | Where-Object { $_.process.Id -ne $entry.process.Id })
        }
    }
}

$reports = @()
foreach ($case in $cases) {
    if (-not (Test-Path -LiteralPath $case.output)) {
        throw "Missing report for $($case.name): $($case.output)"
    }
    $report = Get-Content -LiteralPath $case.output -Raw | ConvertFrom-Json
    $reports += [pscustomobject]@{
        mode = [string]$report.mode
        dummy_count = [int]$report.dummy_body_count
        seed = [int]$report.seed
        completed = [bool]$report.row.completed
        score = [int64]$report.row.score
        final_orbs = [int]$report.row.final_orbs
        physical = $report.row.physical
    }
}

function Merge-Histogram($Rows, [string]$PropertyName) {
    $histogram = [ordered]@{}
    foreach ($row in $Rows) {
        $source = $row.physical.$PropertyName
        foreach ($property in $source.PSObject.Properties) {
            $key = [string]$property.Name
            if (-not $histogram.Contains($key)) { $histogram[$key] = 0 }
            $histogram[$key] += [int]$property.Value
        }
    }
    return $histogram
}

function New-ConditionSummary($Rows, [string]$Name) {
    $rowsArray = @($Rows)
    $details = @()
    foreach ($row in $rowsArray) {
        foreach ($event in @($row.physical.departure_events)) {
            $details += [ordered]@{
                mode = $row.mode
                dummy_body_count = $row.dummy_count
                seed = $row.seed
                stable_spawn_id = [int]$event.stable_spawn_id
                level = [int]$event.level
                start_frame = [int]$event.start_frame
                end_frame = [int]$event.end_frame
                outside_frames = [int]$event.outside_frames
                max_outside_distance_px = [double]$event.max_outside_distance_px
                outcome = [string]$event.outcome
                preceding_event = [string]$event.preceding_event
                preceding_event_age_frames = [int]$event.preceding_event_age_frames
            }
        }
    }
    return [ordered]@{
        name = $Name
        mode = if ($rowsArray.Count -gt 0) { [string]$rowsArray[0].mode } else { "all" }
        dummy_body_count = if ($rowsArray.Count -gt 0) { [int]$rowsArray[0].dummy_count } else { -1 }
        run_count = $rowsArray.Count
        completed_count = @($rowsArray | Where-Object { $_.completed }).Count
        departure_game_count = @($rowsArray | Where-Object { [bool]$_.physical.departure_game }).Count
        departure_frame_count = [int](($rowsArray | ForEach-Object { [int]$_.physical.departure_frame_count } | Measure-Object -Sum).Sum)
        departure_orb_frame_count = [int](($rowsArray | ForEach-Object { [int]$_.physical.departure_orb_frame_count } | Measure-Object -Sum).Sum)
        departure_episode_count = $details.Count
        returned_count = [int](($rowsArray | ForEach-Object { [int]$_.physical.returned_count } | Measure-Object -Sum).Sum)
        never_returned_count = [int](($rowsArray | ForEach-Object { [int]$_.physical.never_returned_count } | Measure-Object -Sum).Sum)
        removed_while_outside_count = [int](($rowsArray | ForEach-Object { [int]$_.physical.removed_while_outside_count } | Measure-Object -Sum).Sum)
        departure_levels = Merge-Histogram $rowsArray "departure_levels"
        preceding_event_counts = Merge-Histogram $rowsArray "preceding_event_counts"
        max_outside_distance_px = [double](($rowsArray | ForEach-Object { [double]$_.physical.max_outside_distance_px } | Measure-Object -Maximum).Maximum)
        max_wall_penetration_px = [double](($rowsArray | ForEach-Object { [double]$_.physical.max_wall_penetration_px } | Measure-Object -Maximum).Maximum)
        max_pair_penetration_px_sampled_10hz = [double](($rowsArray | ForEach-Object { [double]$_.physical.max_pair_penetration_px_sampled_10hz } | Measure-Object -Maximum).Maximum)
        departure_details = $details
    }
}

$conditionSummaries = @()
foreach ($mode in $modes) {
    foreach ($dummyCount in $dummyCounts) {
        $conditionRows = @($reports | Where-Object {
            $_.mode -eq $mode -and $_.dummy_count -eq $dummyCount
        })
        $conditionSummaries += New-ConditionSummary $conditionRows "${mode}_p${dummyCount}"
    }
}

$overall = New-ConditionSummary $reports "all"
$overall["mode"] = "all"
$overall["dummy_body_count"] = -1
$summary = [ordered]@{
    engine = "Godot 4.8-dev3 mono"
    physics_engine = "Jolt Physics"
    physics_ticks_per_second = 120
    seeds = $seeds
    dummy_body_counts = $dummyCounts
    modes = $modes
    process_isolation = "one mode/seed/P per Godot process"
    run_count = $reports.Count
    conditions = $conditionSummaries
    overall = $overall
}
$summaryPath = Join-Path $artifactPath "jolt_rid_robustness_summary.json"
$summary | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output "JOLT_RID_SUMMARY $summaryPath"
Write-Output ($overall | ConvertTo-Json -Depth 10 -Compress)
