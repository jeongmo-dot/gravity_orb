param(
    [string]$GodotPath = "",
    [ValidateRange(1, [int]::MaxValue)]
    [int]$FixedFps = 120
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $repoPath "artifacts\screens"
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
        $GodotPath = $env:GODOT
    } elseif (Test-Path -LiteralPath "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe") {
        $GodotPath = "C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe"
    } else {
        $GodotPath = "godot"
    }
}

New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
$arguments = @(
    "--path", $repoPath,
    "--windowed",
    "--resolution", "540x960",
    "--audio-driver", "Dummy",
    "--fixed-fps", $FixedFps.ToString(),
    "res://tests/spike/CaptureScreens.tscn",
    "--",
    "--capture-save-path=res://artifacts/screens/capture_save.tmp.cfg",
    "--jolt-seed=5050"
)

$previousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    & $GodotPath @arguments
    $captureExit = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
if ($captureExit -ne 0) {
    throw "Screenshot capture failed with exit code $captureExit"
}

$expectedFiles = @(
    "01_start_screen.png",
    "02_turn_early.png",
    "03_turn_combo.png",
    "04_turn_game_over.png",
    "05_blitz_ready.png",
    "06_blitz_fever_chain.png",
    "07_blitz_danger.png",
    "08_blitz_time_up.png",
    "09_blitz_result.png",
    "10_ranking_blitz.png",
    "11_result_new_record.png"
)
foreach ($fileName in $expectedFiles) {
    $filePath = Join-Path $outputPath $fileName
    if (-not (Test-Path -LiteralPath $filePath)) {
        throw "Screenshot capture did not create $filePath"
    }
    Write-Output ("SCREEN_CAPTURE_RESULT {0}" -f $filePath)
}

$temporarySave = Join-Path $outputPath "capture_save.tmp.cfg"
if (Test-Path -LiteralPath $temporarySave) {
    Remove-Item -LiteralPath $temporarySave -Force
}
Write-Output ("SCREEN_CAPTURE_SUITE exit=0 files={0}" -f $expectedFiles.Count)
