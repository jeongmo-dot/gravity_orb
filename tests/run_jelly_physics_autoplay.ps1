param(
    [string]$GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe",
    [string]$RepoPath = "",
    [string]$Label = "after",
    [ValidateRange(1, 8)]
    [int]$Parallelism = 4,
    [double]$Friction = -1.0,
    [double]$AngularDamp = -1.0,
    [double]$GravityTurnDiagonalTime = -1.0,
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Split-Path -Parent $PSScriptRoot
}
if ($Friction -ne -1.0 -and ($Friction -le 0.0 -or $Friction -gt 1.0)) {
    throw "Friction must be greater than 0 and at most 1"
}
if ($AngularDamp -lt -1.0) {
    throw "AngularDamp must be non-negative or -1 for the config default"
}
if ($GravityTurnDiagonalTime -lt -1.0) {
    throw "GravityTurnDiagonalTime must be non-negative or -1 for the config default"
}
$culture = [Globalization.CultureInfo]::InvariantCulture
$physicsArguments = @()
if ($Friction -gt 0.0) {
    $physicsArguments += "--physics-friction=$($Friction.ToString($culture))"
}
if ($AngularDamp -ge 0.0) {
    $physicsArguments += "--physics-angular-damp=$($AngularDamp.ToString($culture))"
}
if ($GravityTurnDiagonalTime -ge 0.0) {
    $physicsArguments += "--physics-gravity-turn-diagonal-time=$($GravityTurnDiagonalTime.ToString($culture))"
}
$outputDirectory = Join-Path $RepoPath "artifacts\jelly_physics_autoplay_$Label"
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$tasks = @()
foreach ($seed in 101..120) {
    $name = "seed_$seed"
    $tasks += [pscustomobject]@{
        Seed = $seed
        Output = Join-Path $outputDirectory "$name.json"
        Stdout = Join-Path $outputDirectory "$name.stdout.log"
        Stderr = Join-Path $outputDirectory "$name.stderr.log"
        Arguments = @(
            "--headless", "--path", $RepoPath, "--fixed-fps", "120", "--audio-driver", "Dummy",
            "res://tests/spike/JoltMeasurement.tscn", "--",
            "--game-mode=jelly", "--jolt-ticks=120", "--jolt-seeds=$seed",
            "--jolt-max-turns=400", "--jolt-no-determinism",
            "--jolt-output=res://artifacts/jelly_physics_autoplay_$Label/$name.json"
        ) + $physicsArguments
    }
}

if (-not $AggregateOnly) {
    for ($offset = 0; $offset -lt $tasks.Count; $offset += $Parallelism) {
        $end = [Math]::Min($offset + $Parallelism - 1, $tasks.Count - 1)
        $running = @()
        foreach ($task in @($tasks[$offset..$end])) {
            Remove-Item -LiteralPath $task.Output, $task.Stdout, $task.Stderr -Force -ErrorAction SilentlyContinue
            $process = Start-Process -FilePath $GodotPath -ArgumentList $task.Arguments `
                -WindowStyle Hidden -PassThru -RedirectStandardOutput $task.Stdout `
                -RedirectStandardError $task.Stderr
            $running += [pscustomobject]@{ Task = $task; Process = $process }
            Write-Output "JELLY_PHYSICS_AUTOPLAY_START label=$Label seed=$($task.Seed) pid=$($process.Id)"
        }
        while (@($running | Where-Object { -not $_.Process.HasExited }).Count -gt 0) {
            Start-Sleep -Milliseconds 500
            foreach ($entry in $running) { $entry.Process.Refresh() }
        }
        foreach ($entry in $running) {
            $entry.Process.WaitForExit()
            $entry.Process.Refresh()
            $stdout = Get-Content -LiteralPath $entry.Task.Stdout -Raw -ErrorAction SilentlyContinue
            $stderr = Get-Content -LiteralPath $entry.Task.Stderr -Raw -ErrorAction SilentlyContinue
            $exitCode = if ($null -eq $entry.Process.ExitCode) { 0 } else { [int]$entry.Process.ExitCode }
            if ($exitCode -ne 0 -or ("$stdout`n$stderr" -match "SCRIPT ERROR|Parse Error|ERROR:")) {
                throw "Seed $($entry.Task.Seed) failed exit=$exitCode`n$stdout`n$stderr"
            }
            if (-not (Test-Path -LiteralPath $entry.Task.Output)) {
                throw "Missing $($entry.Task.Output)"
            }
            Write-Output "JELLY_PHYSICS_AUTOPLAY_DONE label=$Label seed=$($entry.Task.Seed) exit=0"
        }
    }
}

$seedRows = @()
$turnFrameCounts = @()
$forcedTurnCount = 0
$totalTurns = 0
$totalMerges = 0
$departures = 0
$maxTurnEndPairPenetration = 0.0
$shockTotals = @{}
foreach ($task in $tasks) {
    $report = Get-Content -LiteralPath $task.Output -Raw | ConvertFrom-Json
    $tick = $report.ticks[0]
    $seedRow = $tick.seeds[0]
    $seedRows += $seedRow
    $totalTurns += [int]$seedRow.completed_turns
    $totalMerges += [int]$seedRow.merge_count
    $maxTurnEndPairPenetration = [Math]::Max(
        $maxTurnEndPairPenetration,
        [double]$seedRow.max_turn_end_pair.penetration_px
    )
    foreach ($sample in @($seedRow.turn_performance_samples)) {
        $frames = [int]$sample.physics_frames
        $turnFrameCounts += $frames
        if ($frames -ge 180) { $forcedTurnCount += 1 }
    }
    foreach ($binProperty in $tick.bins.PSObject.Properties) {
        $bin = $binProperty.Value
        $departures += [int]$bin.departures
    }
    foreach ($levelProperty in $tick.shock_displacement_by_target_level.PSObject.Properties) {
        $level = $levelProperty.Name
        $value = $levelProperty.Value
        if (-not $shockTotals.ContainsKey($level)) {
            $shockTotals[$level] = [ordered]@{ sum = 0.0; samples = 0 }
        }
        $shockTotals[$level].sum += (
            [double]$value.mean_target_displacement_px * [int]$value.target_samples
        )
        $shockTotals[$level].samples += [int]$value.target_samples
    }
}

$completedGames = @($seedRows | Where-Object { $_.game_over })
$gameOverTurns = @($completedGames | ForEach-Object { [double]$_.completed_turns })
$scores = @($seedRows | ForEach-Object { [double]$_.score })
$gameOverScores = @($completedGames | ForEach-Object { [double]$_.score })
$shockSummary = [ordered]@{}
foreach ($level in @($shockTotals.Keys | Sort-Object)) {
    $samples = [int]$shockTotals[$level].samples
    $shockSummary[$level] = [ordered]@{
        mean_target_displacement_px = if ($samples -gt 0) { [double]$shockTotals[$level].sum / $samples } else { 0.0 }
        target_samples = $samples
    }
}
$summary = [ordered]@{
    label = $Label
    engine = "Godot 4.8-dev3 standard"
    seeds = @(101..120)
    fixed_fps = 120
    max_turns = 400
    friction = if ($Friction -gt 0.0) { $Friction } else { $null }
    angular_damp = if ($AngularDamp -ge 0.0) { $AngularDamp } else { $null }
    gravity_turn_diagonal_time = if ($GravityTurnDiagonalTime -ge 0.0) { $GravityTurnDiagonalTime } else { $null }
    game_over_count = $completedGames.Count
    average_game_over_turns = if ($gameOverTurns.Count -gt 0) { ($gameOverTurns | Measure-Object -Average).Average } else { 0.0 }
    average_game_over_score = if ($gameOverScores.Count -gt 0) { ($gameOverScores | Measure-Object -Average).Average } else { 0.0 }
    average_score_all = ($scores | Measure-Object -Average).Average
    average_turn_seconds = if ($turnFrameCounts.Count -gt 0) { (($turnFrameCounts | Measure-Object -Average).Average / 120.0) } else { 0.0 }
    forced_settle_turns = $forcedTurnCount
    forced_settle_ratio = if ($turnFrameCounts.Count -gt 0) { [double]$forcedTurnCount / $turnFrameCounts.Count } else { 0.0 }
    merges_per_turn = if ($totalTurns -gt 0) { [double]$totalMerges / $totalTurns } else { 0.0 }
    max_turn_end_pair_penetration_px = $maxTurnEndPairPenetration
    departures = $departures
    color_effect_target_displacement = $shockSummary
}
$summaryPath = Join-Path (Split-Path -Parent $outputDirectory) "jelly_physics_autoplay_$Label.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output "JELLY_PHYSICS_AUTOPLAY_REPORT $summaryPath"
