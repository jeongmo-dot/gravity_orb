param(
    [int]$MaxParallel = 3,
    [switch]$Reduced
)

$ErrorActionPreference = 'Stop'
$repoPath = Split-Path -Parent $PSScriptRoot
$godotPath = 'C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe'
$resultPath = Join-Path $repoPath '.godot\physics-sweep'
New-Item -ItemType Directory -Force -Path $resultPath | Out-Null

$cases = @()
foreach ($gravity in @(2400, 1800, 1200)) {
    foreach ($friction in @(0.3, 0.1, 0.0)) {
        foreach ($bounce in @(0.15, 0.05)) {
            if ($Reduced -and $bounce -eq 0.05 -and $gravity -eq 1800) {
                continue
            }
            $frictionName = $friction.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture).Replace('.', 'p')
            $bounceName = $bounce.ToString('0.00', [Globalization.CultureInfo]::InvariantCulture).Replace('.', 'p')
            $cases += [pscustomobject]@{
                Name = "G${gravity}_F${frictionName}_B${bounceName}"
                Gravity = $gravity
                Friction = $friction
                Bounce = $bounce
            }
        }
    }
}

for ($batchStart = 0; $batchStart -lt $cases.Count; $batchStart += $MaxParallel) {
    $batchEnd = [Math]::Min($batchStart + $MaxParallel - 1, $cases.Count - 1)
    $running = @()
    foreach ($case in $cases[$batchStart..$batchEnd]) {
        $stdoutPath = Join-Path $resultPath "$($case.Name).out.log"
        $stderrPath = Join-Path $resultPath "$($case.Name).err.log"
        $arguments = @(
            '--headless',
            '--path', '.',
            '--fixed-fps', '240',
            '-s', 'res://tests/run_tests.gd',
            '--',
            '--game-over-suite=measurement',
            "--physics-case=$($case.Name)",
            "--physics-gravity=$($case.Gravity)",
            "--physics-friction=$($case.Friction.ToString([Globalization.CultureInfo]::InvariantCulture))",
            "--physics-bounce=$($case.Bounce.ToString([Globalization.CultureInfo]::InvariantCulture))"
        )
        $process = Start-Process `
            -FilePath $godotPath `
            -ArgumentList $arguments `
            -WorkingDirectory $repoPath `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -WindowStyle Hidden `
            -PassThru
        $running += [pscustomobject]@{ Case = $case; Process = $process }
        Write-Output "START $($case.Name) pid=$($process.Id)"
    }
    foreach ($item in $running) {
        $item.Process.WaitForExit()
        Write-Output "DONE $($item.Case.Name) exit=$($item.Process.ExitCode)"
        if ($item.Process.ExitCode -ne 0) {
            throw "Physics sweep case failed: $($item.Case.Name)"
        }
    }
}

Write-Output "Physics sweep completed: $($cases.Count) cases"
