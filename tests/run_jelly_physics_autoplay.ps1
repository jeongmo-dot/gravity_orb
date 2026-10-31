param(
    [string]$GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe",
    [string]$RepoPath = "",
    [string]$Label = "after",
    [ValidateRange(1, 8)]
    [int]$Parallelism = 4,
    [double]$Friction = -1.0,
    [double]$AngularDamp = -1.0,
    [double]$GravityTurnDiagonalTime = -1.0,
    [ValidateRange(-1, 7)]
    [int]$JellyBlastMinLevel = -1,
    [ValidateRange(1, 600)]
    [int]$MaxTurns = 400,
    [ValidateRange(-1, 100)]
    [int]$SpawnCountMax = -1,
    [string]$SpawnLevelCosts = "",
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
if ($JellyBlastMinLevel -ge 0) {
    $physicsArguments += "--jelly-blast-min-level=$JellyBlastMinLevel"
}
if ($SpawnCountMax -ge 0) {
    $physicsArguments += "--spawn-count-max=$SpawnCountMax"
}
if (-not [string]::IsNullOrWhiteSpace($SpawnLevelCosts)) {
    if ($SpawnLevelCosts -notmatch '^\d+(,\d+)*$') {
        throw "SpawnLevelCosts must be comma-separated non-negative integers"
    }
    $physicsArguments += "--spawn-level-costs=$SpawnLevelCosts"
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
        GodotLog = Join-Path $outputDirectory "$name.godot.log"
        Arguments = @(
            "--headless", "--path", $RepoPath, "--fixed-fps", "120", "--audio-driver", "Dummy",
            "--log-file", (Join-Path $outputDirectory "$name.godot.log"),
            "res://tests/spike/JoltMeasurement.tscn", "--",
            "--game-mode=jelly", "--jolt-ticks=120", "--jolt-seeds=$seed",
            "--jolt-max-turns=$MaxTurns", "--jolt-no-determinism",
            "--jolt-output=res://artifacts/jelly_physics_autoplay_$Label/$name.json"
        ) + $physicsArguments
    }
}

if (-not $AggregateOnly) {
    for ($offset = 0; $offset -lt $tasks.Count; $offset += $Parallelism) {
        $end = [Math]::Min($offset + $Parallelism - 1, $tasks.Count - 1)
        $running = @()
        foreach ($task in @($tasks[$offset..$end])) {
            Remove-Item -LiteralPath $task.Output, $task.Stdout, $task.Stderr, $task.GodotLog -Force -ErrorAction SilentlyContinue
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
$totalBlasts = 0
$blastCountByLevel = @{}
$totalJackpots = 0
$totalLevelSevenCreations = 0
$departures = 0
$maxTurnEndPairPenetration = 0.0
$spawnedOrbCounts = @()
$spawnedLevelOneCount = 0
$spawnedLevelTwoCount = 0
$finalMoveCount = 0
$finalMoveSuccessCount = 0
$peakActiveOrbs = @()
$peakActivePhysicsMeans = @()
$peakActivePhysicsMaxima = @()
$maximumActiveSample = $null
$shockTotals = @{}
foreach ($task in $tasks) {
    $report = Get-Content -LiteralPath $task.Output -Raw | ConvertFrom-Json
    $tick = $report.ticks[0]
    $seedRow = $tick.seeds[0]
    $seedRows += $seedRow
    $totalTurns += [int]$seedRow.completed_turns
    $totalMerges += [int]$seedRow.merge_count
    $totalBlasts += [int]$seedRow.blast_count
    $totalJackpots += [int]$seedRow.max_clear_count
    $totalLevelSevenCreations += [int]$seedRow.level_seven_creation_count
    foreach ($levelProperty in $seedRow.blast_count_by_level.PSObject.Properties) {
        $level = $levelProperty.Name
        if (-not $blastCountByLevel.ContainsKey($level)) { $blastCountByLevel[$level] = 0 }
        $blastCountByLevel[$level] += [int]$levelProperty.Value
    }
    $spawnedOrbCounts += [double]$seedRow.spawned_orb_count
    $spawnedLevelOneCount += [int]$seedRow.spawned_orb_count_by_level.L1
    $spawnedLevelTwoCount += [int]$seedRow.spawned_orb_count_by_level.L2
    $finalMoveCount += [int]$seedRow.final_move_count
    $finalMoveSuccessCount += [int]$seedRow.final_move_success_count
    $peakActiveOrbs += [double]$seedRow.max_active_orbs
    $peakActivePhysicsMeans += [double]$seedRow.max_active_physics_ms_mean
    $peakActivePhysicsMaxima += [double]$seedRow.max_active_physics_ms_max
    if ($null -eq $maximumActiveSample -or [int]$seedRow.max_active_orbs -gt [int]$maximumActiveSample.active_orbs) {
        $maximumActiveSample = [ordered]@{
            seed = [int]$seedRow.seed
            turn = [int]$seedRow.max_active_orbs_turn
            active_orbs = [int]$seedRow.max_active_orbs
            physics_ms_mean = [double]$seedRow.max_active_physics_ms_mean
            physics_ms_max = [double]$seedRow.max_active_physics_ms_max
        }
    }
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
$gameOverSpawnCounts = @($completedGames | ForEach-Object { [double]$_.game_over_spawn_count })
$gameOverSpawnedJellyCounts = @($completedGames | ForEach-Object { [double]$_.game_over_spawned_jelly_count })
$gameOverSpawnedTotals = @($completedGames | ForEach-Object { [double]$_.spawned_orb_count })
$gameOverHighLevelCounts = @(
    $completedGames | ForEach-Object {
        @($_.final_state | Where-Object { [int]$_.level -ge 5 }).Count
    }
)
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
    max_turns = $MaxTurns
    friction = if ($Friction -gt 0.0) { $Friction } else { $null }
    angular_damp = if ($AngularDamp -ge 0.0) { $AngularDamp } else { $null }
    gravity_turn_diagonal_time = if ($GravityTurnDiagonalTime -ge 0.0) { $GravityTurnDiagonalTime } else { $null }
    jelly_blast_min_level = if ($JellyBlastMinLevel -ge 0) { $JellyBlastMinLevel } else { $null }
    spawn_count_max = if ($SpawnCountMax -ge 0) { $SpawnCountMax } else { $null }
    spawn_level_costs = if ([string]::IsNullOrWhiteSpace($SpawnLevelCosts)) { $null } else { $SpawnLevelCosts }
    game_over_count = $completedGames.Count
    average_game_over_turns = if ($gameOverTurns.Count -gt 0) { ($gameOverTurns | Measure-Object -Average).Average } else { 0.0 }
    minimum_game_over_turns = if ($gameOverTurns.Count -gt 0) { ($gameOverTurns | Measure-Object -Minimum).Minimum } else { 0.0 }
    maximum_game_over_turns = if ($gameOverTurns.Count -gt 0) { ($gameOverTurns | Measure-Object -Maximum).Maximum } else { 0.0 }
    average_game_over_score = if ($gameOverScores.Count -gt 0) { ($gameOverScores | Measure-Object -Average).Average } else { 0.0 }
    minimum_game_over_score = if ($gameOverScores.Count -gt 0) { ($gameOverScores | Measure-Object -Minimum).Minimum } else { 0.0 }
    maximum_game_over_score = if ($gameOverScores.Count -gt 0) { ($gameOverScores | Measure-Object -Maximum).Maximum } else { 0.0 }
    average_score_all = ($scores | Measure-Object -Average).Average
    total_spawned_orbs = ($spawnedOrbCounts | Measure-Object -Sum).Sum
    average_spawned_orbs_all = ($spawnedOrbCounts | Measure-Object -Average).Average
    spawned_level_one_count = $spawnedLevelOneCount
    spawned_level_two_count = $spawnedLevelTwoCount
    spawned_level_two_ratio = if (($spawnedLevelOneCount + $spawnedLevelTwoCount) -gt 0) { [double]$spawnedLevelTwoCount / ($spawnedLevelOneCount + $spawnedLevelTwoCount) } else { 0.0 }
    average_game_over_spawned_orbs = if ($gameOverSpawnedTotals.Count -gt 0) { ($gameOverSpawnedTotals | Measure-Object -Average).Average } else { 0.0 }
    average_game_over_spawn_count = if ($gameOverSpawnCounts.Count -gt 0) { ($gameOverSpawnCounts | Measure-Object -Average).Average } else { 0.0 }
    minimum_game_over_spawn_count = if ($gameOverSpawnCounts.Count -gt 0) { ($gameOverSpawnCounts | Measure-Object -Minimum).Minimum } else { 0.0 }
    maximum_game_over_spawn_count = if ($gameOverSpawnCounts.Count -gt 0) { ($gameOverSpawnCounts | Measure-Object -Maximum).Maximum } else { 0.0 }
    average_game_over_spawned_jelly_count = if ($gameOverSpawnedJellyCounts.Count -gt 0) { ($gameOverSpawnedJellyCounts | Measure-Object -Average).Average } else { 0.0 }
    minimum_game_over_spawned_jelly_count = if ($gameOverSpawnedJellyCounts.Count -gt 0) { ($gameOverSpawnedJellyCounts | Measure-Object -Minimum).Minimum } else { 0.0 }
    maximum_game_over_spawned_jelly_count = if ($gameOverSpawnedJellyCounts.Count -gt 0) { ($gameOverSpawnedJellyCounts | Measure-Object -Maximum).Maximum } else { 0.0 }
    final_move_count = $finalMoveCount
    final_move_success_count = $finalMoveSuccessCount
    final_move_success_rate = if ($finalMoveCount -gt 0) { [double]$finalMoveSuccessCount / $finalMoveCount } else { 0.0 }
    average_turn_seconds = if ($turnFrameCounts.Count -gt 0) { (($turnFrameCounts | Measure-Object -Average).Average / 120.0) } else { 0.0 }
    forced_settle_turns = $forcedTurnCount
    forced_settle_ratio = if ($turnFrameCounts.Count -gt 0) { [double]$forcedTurnCount / $turnFrameCounts.Count } else { 0.0 }
    merges_per_turn = if ($totalTurns -gt 0) { [double]$totalMerges / $totalTurns } else { 0.0 }
    blast_count = $totalBlasts
    blast_count_by_level = $blastCountByLevel
    jackpot_count = $totalJackpots
    level_seven_creation_count = $totalLevelSevenCreations
    average_game_over_level_five_plus_count = if ($gameOverHighLevelCounts.Count -gt 0) { ($gameOverHighLevelCounts | Measure-Object -Average).Average } else { 0.0 }
    minimum_game_over_level_five_plus_count = if ($gameOverHighLevelCounts.Count -gt 0) { ($gameOverHighLevelCounts | Measure-Object -Minimum).Minimum } else { 0.0 }
    maximum_game_over_level_five_plus_count = if ($gameOverHighLevelCounts.Count -gt 0) { ($gameOverHighLevelCounts | Measure-Object -Maximum).Maximum } else { 0.0 }
    max_turn_end_pair_penetration_px = $maxTurnEndPairPenetration
    departures = $departures
    average_peak_active_orbs = ($peakActiveOrbs | Measure-Object -Average).Average
    maximum_active_sample = $maximumActiveSample
    average_peak_active_physics_ms_mean = ($peakActivePhysicsMeans | Measure-Object -Average).Average
    maximum_peak_active_physics_ms = ($peakActivePhysicsMaxima | Measure-Object -Maximum).Maximum
    color_effect_target_displacement = $shockSummary
}
$summaryPath = Join-Path (Split-Path -Parent $outputDirectory) "jelly_physics_autoplay_$Label.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output "JELLY_PHYSICS_AUTOPLAY_REPORT $summaryPath"
