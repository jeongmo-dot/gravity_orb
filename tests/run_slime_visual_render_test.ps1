param(
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
        $GodotPath = $env:GODOT
    } elseif (Test-Path -LiteralPath "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe") {
        $GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
    } else {
        $GodotPath = "godot"
    }
}

$arguments = @(
    "--path", $repoPath,
    "--windowed",
    "--disable-vsync",
    "--audio-driver", "Dummy",
    "--rendering-method", "gl_compatibility",
    "--fixed-fps", "120",
    "-s", "res://tests/run_tests.gd",
    "--",
    "--test-suite=general",
    "--test-file=res://tests/test_slime_visuals.gd"
)
$previousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    & $GodotPath @arguments
    $testExit = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
if ($testExit -ne 0) {
    throw "Slime visual render regression failed with exit code $testExit"
}
Write-Output "SLIME_VISUAL_RENDER_TEST_RESULT exit=0"
