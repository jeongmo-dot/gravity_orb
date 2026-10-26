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
    "17_jelly_max_effect.png",
    "18_jelly_landing_strip.png",
    "19_jelly_crowded_rest.png",
    "20_jelly_yellow_cheek_zoom.png",
    "21_jelly_green_cheek_zoom.png",
    "22_jelly_blue_cheek_zoom.png",
    "23_jelly_belly_half_zoom.png",
    "24_jelly_belly_three_quarter_zoom.png",
    "25_jelly_max_effect_zoom.png",
    "26_settings.png",
    "27_start_no_record.png",
    "28_gravity_switch.png",
    "29_board_danger.png",
    "30_board_blocked.png",
    "31_turn_input_ready.png",
    "32_turn_input_busy.png",
    "33_turn_input_rejected.png",
    "34_callout_great.png",
    "35_callout_incredible.png",
    "36_popup_merge.png",
    "37_popup_blast_big.png",
    "38_jelly_look_levels.png",
    "39_jelly_look_crowded.png",
    "40_jelly_look_max.png",
    "41_jelly_look_stretch.png",
    "42_jelly_look_absorption.png",
    "43_jelly_look_unlock.png",
    "44_jelly_motion_land_01.png",
    "45_jelly_motion_land_02.png",
    "46_jelly_motion_land_03.png",
    "47_jelly_motion_land_04.png",
    "48_jelly_motion_land_05.png",
    "49_jelly_motion_land_06.png",
    "50_jelly_motion_land_07.png",
    "51_jelly_motion_land_08.png",
    "52_jelly_motion_land_09.png",
    "53_jelly_motion_land_10.png",
    "54_jelly_motion_breathe_max.png",
    "55_jelly_motion_rest.png",
    "56_jelly_motion_right.png"
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
    $landingFiles = @(1..10 | ForEach-Object {
        Join-Path $outputPath ("{0:D2}_jelly_motion_land_{1:D2}.png" -f (43 + $_), $_)
    })
    $uniqueLandingHashes = @(
        $landingFiles |
            ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash } |
            Sort-Object -Unique
    )
    if ($uniqueLandingHashes.Count -ne $landingFiles.Count) {
        throw (
            "JELLY landing strip must contain 10 distinct frames for {0}; found {1}" -f `
                $captureSpec.Name,
                $uniqueLandingHashes.Count
        )
    }
    Write-Output (
        "SCREEN_CAPTURE_MOTION_CHECK ratio={0} landing_unique={1}/10" -f `
            $captureSpec.Name,
            $uniqueLandingHashes.Count
    )
    $temporarySave = Join-Path $outputPath "capture_save.tmp.cfg"
    if (Test-Path -LiteralPath $temporarySave) {
        Remove-Item -LiteralPath $temporarySave -Force
    }
}
Write-Output ("SCREEN_CAPTURE_SUITE exit=0 ratios={0} files={1}" -f $captureSpecs.Count, $capturedFileCount)
