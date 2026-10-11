param(
    [string]$GodotPath = "",
    [ValidateRange(1, [int]::MaxValue)]
    [int]$FixedFps = 120
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $repoPath "artifacts\screens"
$captureSpecs = @(
    [ordered]@{ Name = "540x960"; Resolution = "540x960"; HudOnly = $false },
    [ordered]@{ Name = "540x1170"; Resolution = "540x1170"; HudOnly = $false }
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
    "11_result_new_record.png",
    "12_turn_ramp_next.png",
    "13_turn_ramp_uncapped_next.png",
    "14_orb_codex.png",
    "15_orb_closeup.png",
    "16_gravity_switch.png",
    "17_board_danger.png",
    "18_board_blocked.png",
    "19_settings.png",
    "20_start_no_record.png",
    "21_start_screen_t2_5.png",
    "22_start_screen_t5_0.png",
    "23_merge_stardust_a.png",
    "23_merge_stardust_b.png",
    "24_birth_l6_a.png",
    "24_birth_l6_b.png",
    "25_birth_l7_a.png",
    "25_birth_l7_b.png",
    "26_blast_l4_a.png",
    "26_blast_l4_b.png",
    "27_blast_l6_a.png",
    "27_blast_l6_b.png",
    "28_blast_l5_crowded_a.png",
    "28_blast_l5_crowded_b.png",
    "29_blast_l6_crowded_a.png",
	"29_blast_l6_crowded_b.png",
	"30_callout_great_a.png",
	"30_callout_great_b.png",
	"31_callout_unstoppable_a.png",
	"31_callout_unstoppable_b.png",
	"32_popup_merge.png",
	"33_popup_blast_big.png",
	"34_color_push_a.png",
	"34_color_push_b.png",
	"35_color_pull_a.png",
	"35_color_pull_b.png",
	"36_color_shake_a.png",
	"36_color_shake_b.png",
	"37_color_lift_a.png",
	"37_color_lift_b.png",
	"38_fever_start_a.png",
	"38_fever_start_b.png",
	"39_fever_running.png",
	"40_blitz_timer_long.png",
	"41_blitz_bonus_gauge_a.png",
	"41_blitz_bonus_gauge_b.png",
	"42_blitz_bonus_layer_cross.png",
	"43_blitz_bonus_fever.png"
)
$hudExpectedFiles = @(
    "02_turn_early.png",
    "03_turn_combo.png",
    "06_blitz_fever_chain.png",
    "07_blitz_danger.png",
    "12_turn_ramp_next.png",
    "13_turn_ramp_uncapped_next.png",
    "17_board_danger.png",
	"18_board_blocked.png",
	"40_blitz_timer_long.png",
	"41_blitz_bonus_gauge_a.png",
	"41_blitz_bonus_gauge_b.png",
	"42_blitz_bonus_layer_cross.png",
	"43_blitz_bonus_fever.png"
)
$capturedFileCount = 0
$boardReports = @()

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
        "--capture-save-path=res://artifacts/screens/$($captureSpec.Name)/capture_save.tmp.cfg",
        "--jolt-seed=5050"
    )
    if ($captureSpec.HudOnly) {
        $arguments += "--capture-hud-scenes-only"
    }

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $GodotPath @arguments
        $captureExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($captureExit -ne 0) {
        throw "Screenshot capture $($captureSpec.Name) failed with exit code $captureExit"
    }

    $captureExpectedFiles = if ($captureSpec.HudOnly) { $hudExpectedFiles } else { $expectedFiles }
    foreach ($fileName in $captureExpectedFiles) {
        $filePath = Join-Path $outputPath $fileName
        if (-not (Test-Path -LiteralPath $filePath)) {
            throw "Screenshot capture did not create $filePath"
        }
        Write-Output ("SCREEN_CAPTURE_RESULT ratio={0} file={1}" -f $captureSpec.Name, $filePath)
        $capturedFileCount += 1
    }

    $boardReportPath = Join-Path $outputPath "board_projection.json"
    if (-not (Test-Path -LiteralPath $boardReportPath)) {
        throw "Screenshot capture did not create $boardReportPath"
    }
    $boardReport = Get-Content -LiteralPath $boardReportPath -Raw | ConvertFrom-Json
    if ($boardReport.logical.left -lt 16.0 -or
        $boardReport.logical.right -gt $boardReport.logical_size.x - 16.0) {
        throw "Projected board is outside the 16 logical pixel margins for $($captureSpec.Name)"
    }
    $boardReports += [pscustomobject]@{
        Name = $captureSpec.Name
        Left = [double]$boardReport.pixels.left
        Right = [double]$boardReport.pixels.right
        Width = [double]$boardReport.pixels.width
    }

    $temporarySave = Join-Path $outputPath "capture_save.tmp.cfg"
    if (Test-Path -LiteralPath $temporarySave) {
        Remove-Item -LiteralPath $temporarySave -Force
    }
}
$baseBoard = $boardReports[0]
$tallBoard = $boardReports[1]
$leftDifference = [Math]::Abs($baseBoard.Left - $tallBoard.Left)
$rightDifference = [Math]::Abs($baseBoard.Right - $tallBoard.Right)
$widthDifferenceRatio = [Math]::Abs($baseBoard.Width - $tallBoard.Width) / $baseBoard.Width
if ($leftDifference -gt 2.0 -or $rightDifference -gt 2.0) {
    throw ("Board capture x mismatch: left={0:N3}px right={1:N3}px" -f `
        $leftDifference, $rightDifference)
}
if ($widthDifferenceRatio -gt 0.01) {
    throw ("Board capture width mismatch: {0:P3}" -f $widthDifferenceRatio)
}
Write-Output (("SCREEN_CAPTURE_BOARD_RESULT base={0:N3},{1:N3} tall={2:N3},{3:N3} " +
    "left_delta={4:N3}px right_delta={5:N3}px width_delta={6:P3}") -f `
    $baseBoard.Left, $baseBoard.Right, $tallBoard.Left, $tallBoard.Right, `
    $leftDifference, $rightDifference, $widthDifferenceRatio)
Write-Output ("SCREEN_CAPTURE_SUITE exit=0 ratios={0} files={1}" -f $captureSpecs.Count, $capturedFileCount)
