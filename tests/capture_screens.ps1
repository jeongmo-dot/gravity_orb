param(
    [string]$GodotPath = "",
    [ValidateRange(1, [int]::MaxValue)]
    [int]$FixedFps = 120,
    [switch]$HudScenesOnly
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $repoPath "artifacts\screens"
$captureSpecs = @(
    [ordered]@{ Name = "540x960"; Resolution = "540x960" },
    [ordered]@{ Name = "540x1170"; Resolution = "540x1170" }
)
$expectedFiles = @(
    "01_jelly_start.png",
    "02_jelly_ranking.png",
    "03_jelly_result.png",
    "04_jelly_gameplay.png",
    "05_jelly_final_move.png",
    "06_jelly_blast_down.png",
    "07_jelly_blast_right.png",
    "08_jelly_full_down.png",
    "09_jelly_full_right.png",
    "10_jelly_eat_00.png",
    "11_jelly_eat_01.png",
    "12_jelly_eat_02.png",
    "13_jelly_merge_effect.png",
    "14_jelly_absorption_effect.png",
    "15_jelly_blast_effect.png",
    "16_jelly_jackpot_effect.png",
    "17_jelly_max_effect.png"
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

$capturedFileCount = 0
foreach ($captureSpec in $captureSpecs) {
    $outputPath = Join-Path $outputRoot $captureSpec.Name
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    $arguments = @(
        "--path", $repoPath,
        "--windowed",
        "--resolution", $captureSpec.Resolution,
        "--audio-driver", "Dummy",
        "--fixed-fps", $FixedFps.ToString(),
        "res://tests/spike/CaptureScreens.tscn",
        "--",
        "--capture-output-directory=res://artifacts/screens/$($captureSpec.Name)",
        "--capture-save-path=res://artifacts/screens/$($captureSpec.Name)/capture_save.tmp.cfg"
    )
    & $GodotPath @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Screenshot capture $($captureSpec.Name) failed with exit code $LASTEXITCODE"
    }
    foreach ($fileName in $expectedFiles) {
        $filePath = Join-Path $outputPath $fileName
        if (-not (Test-Path -LiteralPath $filePath)) {
            throw "Screenshot capture did not create $filePath"
        }
        Write-Output ("SCREEN_CAPTURE_RESULT ratio={0} file={1}" -f $captureSpec.Name, $filePath)
        $capturedFileCount += 1
    }
    $temporarySave = Join-Path $outputPath "capture_save.tmp.cfg"
    if (Test-Path -LiteralPath $temporarySave) {
        Remove-Item -LiteralPath $temporarySave -Force
    }
}
Write-Output ("SCREEN_CAPTURE_SUITE exit=0 ratios={0} files={1}" -f $captureSpecs.Count, $capturedFileCount)
