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
    "06_jelly_l6_normal_l8_blast_face.png",
    "07_jelly_l10_blast.png",
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
    "56_jelly_motion_right.png",
    "57_callout_nice.png",
    "58_callout_amazing.png",
    "59_callout_unstoppable.png",
    "60_popup_crowded.png",
    "61_jelly_gravity_left_down_diagonal.png",
    "62_jelly_gravity_left_down_rest.png",
    "63_jelly_gravity_right_down_rest.png",
    "64_jelly_initial_four_colors.png",
    "65_jelly_preview_budget_mix.png",
    "66_jelly_preview_board_match.png",
    "67_jelly_preview_next_1.png",
    "68_jelly_preview_next_2.png",
    "69_jelly_preview_next_5.png",
    "70_jelly_preview_then_l2_5.png",
    "71_jelly_turn_hud_three_digit.png",
    "72_jelly_merge_process_equal_00.png",
    "73_jelly_merge_process_equal_25.png",
    "74_jelly_merge_process_equal_50.png",
    "75_jelly_merge_process_equal_75.png",
    "76_jelly_merge_process_equal_100.png",
    "77_jelly_merge_process_absorb_00.png",
    "78_jelly_merge_process_absorb_25.png",
    "79_jelly_merge_process_absorb_50.png",
    "80_jelly_merge_process_absorb_75.png",
    "81_jelly_merge_process_absorb_100.png",
    "82_jelly_merge_process_level_up_00.png",
    "83_jelly_merge_process_level_up_25.png",
    "84_jelly_merge_process_level_up_50.png",
    "85_jelly_merge_process_level_up_75.png",
    "86_jelly_merge_process_level_up_100.png",
    "87_jelly_l1_l10_profile_a.png",
    "88_jelly_l1_l10_profile_b.png",
    "89_jelly_tap_blast_a_00.png",
    "90_jelly_tap_blast_a_50.png",
    "91_jelly_tap_blast_a_100.png",
    "92_jelly_tap_blast_b_00.png",
    "93_jelly_tap_blast_b_50.png",
    "94_jelly_tap_blast_b_100.png",
    "95_jelly_l10_blast_a.png",
    "96_jelly_l10_blast_b.png",
    "97_jelly_l10_jackpot_a.png",
    "98_jelly_l10_jackpot_b.png",
    "99_jelly_result_l10_max.png",
    "100_jelly_default_l7_l6_00.png",
    "101_jelly_default_l7_l6_50.png",
    "102_jelly_default_l7_l6_100.png",
    "103_jelly_default_l8_blast.png",
    "104_jelly_l8_tap_turn_before.png",
    "105_jelly_l8_tap_turn_entering.png",
    "106_jelly_l8_tap_turn_settled.png",
    "107_jelly_l8_l9_blast.png",
    "108_jelly_tap_pink_before.png",
    "109_jelly_tap_pink_010.png",
    "110_jelly_tap_pink_settled.png",
    "111_jelly_tap_blue_before.png",
    "112_jelly_tap_blue_010.png",
    "113_jelly_tap_blue_settled.png",
    "114_jelly_tap_green_before.png",
    "115_jelly_tap_green_010.png",
    "116_jelly_tap_green_settled.png",
    "117_jelly_tap_yellow_before.png",
    "118_jelly_tap_yellow_010.png",
    "119_jelly_tap_yellow_settled.png",
    "120_jelly_tap_purple_before.png",
    "121_jelly_tap_purple_010.png",
    "122_jelly_tap_purple_settled.png",
    "123_jelly_tap_orange_before.png",
    "124_jelly_tap_orange_010.png",
    "125_jelly_tap_orange_settled.png",
    "126_jelly_tap_blue_callout.png",
    "127_jelly_tap_orange_callout.png",
    "128_jelly_tap_effects_full.png",
    "129_jelly_blast_push_k0_big_000.png",
    "130_jelly_blast_push_k0_big_010.png",
    "131_jelly_blast_push_k0_big_020.png",
    "132_jelly_blast_push_k0_big_040.png",
    "133_jelly_blast_push_k0_yellow_000.png",
    "134_jelly_blast_push_k0_yellow_010.png",
    "135_jelly_blast_push_k0_yellow_020.png",
    "136_jelly_blast_push_k0_yellow_040.png",
    "137_jelly_blast_push_k4_big_000.png",
    "138_jelly_blast_push_k4_big_010.png",
    "139_jelly_blast_push_k4_big_020.png",
    "140_jelly_blast_push_k4_big_040.png",
    "141_jelly_blast_push_k4_yellow_000.png",
    "142_jelly_blast_push_k4_yellow_010.png",
    "143_jelly_blast_push_k4_yellow_020.png",
    "144_jelly_blast_push_k4_yellow_040.png",
    "145_jelly_blast_push_full.png",
    "146_jelly_tap_lift_0_yellow_000.png",
    "147_jelly_tap_lift_0_yellow_010.png",
    "148_jelly_tap_lift_0_yellow_020.png",
    "149_jelly_tap_lift_0_yellow_040.png",
    "150_jelly_tap_lift_900_yellow_000.png",
    "151_jelly_tap_lift_900_yellow_010.png",
    "152_jelly_tap_lift_900_yellow_020.png",
    "153_jelly_tap_lift_900_yellow_040.png",
    "154_jelly_tap_lift_full.png",
    "155_jelly_tap_push_l9_center_000.png",
    "156_jelly_tap_push_l9_center_010.png",
    "157_jelly_tap_push_l9_center_020.png",
    "158_jelly_tap_push_l9_center_040.png",
    "159_jelly_tap_push_l9_yellow_000.png",
    "160_jelly_tap_push_l9_yellow_010.png",
    "161_jelly_tap_push_l9_yellow_020.png",
    "162_jelly_tap_push_l9_yellow_040.png",
    "163_jelly_tap_push_t0_center_000.png",
    "164_jelly_tap_push_t0_center_010.png",
    "165_jelly_tap_push_t0_center_020.png",
    "166_jelly_tap_push_t0_center_040.png",
    "167_jelly_tap_push_t0_yellow_000.png",
    "168_jelly_tap_push_t0_yellow_010.png",
    "169_jelly_tap_push_t0_yellow_020.png",
    "170_jelly_tap_push_t0_yellow_040.png",
    "171_jelly_tap_push_t3_center_000.png",
    "172_jelly_tap_push_t3_center_010.png",
    "173_jelly_tap_push_t3_center_020.png",
    "174_jelly_tap_push_t3_center_040.png",
    "175_jelly_tap_push_t3_yellow_000.png",
    "176_jelly_tap_push_t3_yellow_010.png",
    "177_jelly_tap_push_t3_yellow_020.png",
    "178_jelly_tap_push_t3_yellow_040.png",
    "179_jelly_tap_push_full.png",
    "180_jelly_four_green_rest_before.png",
    "181_jelly_four_green_rest_after.png",
    "182_jelly_four_yellow_magnet_000.png",
    "183_jelly_four_yellow_magnet_020.png",
    "184_jelly_four_yellow_magnet_040.png",
    "185_jelly_four_yellow_magnet_070.png",
    "186_jelly_four_pink_callout.png",
    "187_jelly_four_blue_callout.png",
    "188_jelly_four_green_callout.png",
    "189_jelly_four_yellow_callout.png",
    "190_jelly_four_effects_full.png",
    "191_jelly_clean_zone_pink_before.png",
    "192_jelly_clean_zone_pink_after.png",
    "193_jelly_clean_zone_blue_before.png",
    "194_jelly_clean_zone_blue_after.png",
    "195_jelly_clean_zone_green_before.png",
    "196_jelly_clean_zone_green_after.png",
    "197_jelly_clean_zone_yellow_before.png",
    "198_jelly_clean_zone_yellow_after.png",
    "199_jelly_timed_board_initial.png",
    "200_jelly_timed_board_1.png",
    "201_jelly_timed_preview_next.png",
    "202_jelly_timed_success_before.png",
    "203_jelly_timed_success_after_bonus.png",
    "204_jelly_timed_timeout_before.png",
    "205_jelly_timed_stone_after_harden.png",
    "206_jelly_timed_first_callout.png",
    "207_jelly_timed_stone_1.png",
    "208_jelly_timed_stone_broken_settled.png",
    "209_jelly_timed_stone_first_callout.png",
    "210_jelly_timed_stone_10.png"
)
$expectedZoomFiles = @(
    "199_jelly_timed_4_5x.png",
    "200_jelly_timed_1_5x.png",
    "205_jelly_timed_stone_18_5x.png",
    "207_jelly_timed_stone_1_5x.png",
    "210_jelly_timed_stone_10_5x.png"
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
    foreach ($fileName in $expectedZoomFiles) {
        $filePath = Join-Path (Join-Path $outputPath "zoom") $fileName
        if (-not (Test-Path -LiteralPath $filePath)) {
            throw "Screenshot capture did not create $filePath"
        }
        Write-Output ("SCREEN_CAPTURE_ZOOM_RESULT ratio={0} file={1}" -f $captureSpec.Name, $filePath)
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
