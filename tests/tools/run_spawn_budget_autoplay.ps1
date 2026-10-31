param(
    [string]$GodotPath = "",
    [ValidateRange(1, 4)]
    [int]$Parallelism = 4,
    [ValidateRange(1, 600)]
    [int]$TurnCap = 600,
    [switch]$AggregateOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$runner = Join-Path $repoPath "tests\run_jelly_physics_autoplay.ps1"
$outputPath = Join-Path $repoPath "artifacts\measurements\spawn_budget_autoplay_measurement.json"
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = if ([string]::IsNullOrWhiteSpace($env:GODOT)) {
        "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
    } else {
        $env:GODOT
    }
}
$variants = @(
    [pscustomobject]@{ Name = "B"; Max = 0; Costs = "1,1" },
    [pscustomobject]@{ Name = "M0"; Max = 5; Costs = "1,1" },
    [pscustomobject]@{ Name = "M2"; Max = 5; Costs = "1,2" },
    [pscustomobject]@{ Name = "M3"; Max = 5; Costs = "1,3" }
)
$candidateReport = [ordered]@{}
foreach ($variant in $variants) {
    $label = "spawn_budget_$($variant.Name)"
    $arguments = @{
        GodotPath = $GodotPath
        RepoPath = $repoPath
        Label = $label
        Parallelism = $Parallelism
        MaxTurns = $TurnCap
        SpawnCountMax = $variant.Max
        SpawnLevelCosts = $variant.Costs
    }
    if ($AggregateOnly) { $arguments.AggregateOnly = $true }
    & $runner @arguments
    $summaryPath = Join-Path $repoPath "artifacts\jelly_physics_autoplay_$label.json"
    $candidateReport[$variant.Name] = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
}
$report = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    conditions = "B/M0/M2/M3 automatic direction bot, seeds 101-120, $TurnCap turns, fixed 120 fps"
    candidates = $candidateReport
}
New-Item -ItemType Directory -Path (Split-Path -Parent $outputPath) -Force | Out-Null
$report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $outputPath -Encoding utf8
Write-Output "SPAWN_BUDGET_AUTOPLAY_REPORT $outputPath"
