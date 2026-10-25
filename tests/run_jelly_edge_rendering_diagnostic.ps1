param(
    [string]$GodotPath = "",
    [ValidateRange(1, [int]::MaxValue)]
    [int]$FixedFps = 120
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $repoPath "artifacts\measurements\jelly_edge_rendering"
$specs = @(
    [ordered]@{ Name = "540x960"; Resolution = "540x960" },
    [ordered]@{ Name = "540x1170"; Resolution = "540x1170" }
)

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
        $GodotPath = $env:GODOT
    } else {
        $GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
    }
}

foreach ($spec in $specs) {
    $outputPath = Join-Path $outputRoot $spec.Name
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    $logPath = Join-Path $outputPath "stdout.log"
    $arguments = @(
        "--path", $repoPath,
        "--windowed",
        "--resolution", $spec.Resolution,
        "--audio-driver", "Dummy",
        "--fixed-fps", $FixedFps.ToString(),
        "res://tests/spike/JellyEdgeRenderingDiagnostic.tscn",
        "--",
        "--jelly-edge-output-directory=res://artifacts/measurements/jelly_edge_rendering/$($spec.Name)"
    )
    & $GodotPath @arguments *>&1 | Tee-Object -FilePath $logPath
    if ($LASTEXITCODE -ne 0) {
        throw "JELLY edge rendering diagnostic $($spec.Name) failed with exit code $LASTEXITCODE"
    }
    if (Select-String -Path $logPath -Pattern "SCRIPT ERROR|Parse Error|ERROR:" -Quiet) {
        throw "JELLY edge rendering diagnostic $($spec.Name) emitted an error"
    }
    $reportPath = Join-Path $outputPath "report.json"
    if (-not (Test-Path -LiteralPath $reportPath)) {
        throw "Missing diagnostic report $reportPath"
    }
    Write-Output ("JELLY_EDGE_DIAGNOSTIC_RESULT ratio={0} report={1}" -f $spec.Name, $reportPath)
}
