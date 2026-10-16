param(
    [string]$GodotPath = "",
    [string]$PrototypePath = "C:\work\GravityOrb-main\GravityOrb\prototype"
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
        $GodotPath = $env:GODOT
    } else {
        $GodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"
    }
}

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}
if (-not (Test-Path -LiteralPath (Join-Path $PrototypePath "main.gd") -PathType Leaf)) {
    throw "Read-only Gravity Slime prototype not found: $PrototypePath"
}

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$workPath = Join-Path $tempRoot ("gravity-slime-parity-" + [guid]::NewGuid().ToString("N"))
$resolvedWorkPath = [System.IO.Path]::GetFullPath($workPath)
if (-not $resolvedWorkPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a parity workspace outside the system temp directory."
}

try {
    New-Item -ItemType Directory -Path $resolvedWorkPath | Out-Null
    $originalProject = Join-Path $resolvedWorkPath "original"
    New-Item -ItemType Directory -Path $originalProject | Out-Null
    Copy-Item -Path (Join-Path $PrototypePath "*") -Destination $originalProject -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "slime_parity_original_driver.gd") -Destination (Join-Path $originalProject "parity_original.gd") -Force
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "slime_parity_original_game.gd") -Destination (Join-Path $originalProject "parity_original_game.gd") -Force

    $candidateOutput = Join-Path $resolvedWorkPath "candidate.jsonl"
    $originalOutput = Join-Path $resolvedWorkPath "original.jsonl"

    & $GodotPath --headless --path $repoPath -s res://tests/tools/slime_parity_candidate.gd -- "--output=$candidateOutput"
    if ($LASTEXITCODE -ne 0) {
        throw "Candidate parity runner failed with exit $LASTEXITCODE"
    }
    & $GodotPath --headless --path $originalProject -s res://parity_original.gd -- "--output=$originalOutput"
    if ($LASTEXITCODE -ne 0) {
        throw "Original parity runner failed with exit $LASTEXITCODE"
    }

    $candidateLines = @(Get-Content -LiteralPath $candidateOutput | ForEach-Object { $_ | ConvertFrom-Json })
    $originalLines = @(Get-Content -LiteralPath $originalOutput | ForEach-Object { $_ | ConvertFrom-Json })
    if ($candidateLines.Count -ne $originalLines.Count) {
        throw "Snapshot count mismatch: candidate=$($candidateLines.Count), original=$($originalLines.Count)"
    }

    $tolerance = 1.0e-6
    for ($lineIndex = 0; $lineIndex -lt $candidateLines.Count; $lineIndex++) {
        $candidate = $candidateLines[$lineIndex]
        $original = $originalLines[$lineIndex]
        if ($null -ne $candidate.end_tick -or $null -ne $original.end_tick) {
            if ($candidate.scenario -ne $original.scenario -or $candidate.end_tick -ne $original.end_tick) {
                throw "End tick mismatch at line $lineIndex"
            }
            continue
        }
        foreach ($field in @("scenario", "tick", "score", "chain", "moving")) {
            if ($candidate.$field -ne $original.$field) {
                throw "Field '$field' mismatch at line $lineIndex"
            }
        }
        if ($candidate.bodies.Count -ne $original.bodies.Count) {
            throw "Body count mismatch at scenario $($candidate.scenario), tick $($candidate.tick)"
        }
        for ($bodyIndex = 0; $bodyIndex -lt $candidate.bodies.Count; $bodyIndex++) {
            $candidateBody = $candidate.bodies[$bodyIndex]
            $originalBody = $original.bodies[$bodyIndex]
            foreach ($valueIndex in 0..3) {
                if ([math]::Abs([double]$candidateBody[$valueIndex] - [double]$originalBody[$valueIndex]) -gt $tolerance) {
                    throw "Physics mismatch at scenario $($candidate.scenario), tick $($candidate.tick), body $bodyIndex, value $valueIndex"
                }
            }
            foreach ($valueIndex in 4..6) {
                if ($candidateBody[$valueIndex] -ne $originalBody[$valueIndex]) {
                    throw "Body data mismatch at scenario $($candidate.scenario), tick $($candidate.tick), body $bodyIndex, value $valueIndex"
                }
            }
        }
    }

    Write-Output "SLIME_PARITY_RESULT scenarios=6 tolerance=1e-6 status=PASS"
} finally {
    if (Test-Path -LiteralPath $resolvedWorkPath) {
        $verifiedPath = [System.IO.Path]::GetFullPath($resolvedWorkPath)
        if ($verifiedPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and $verifiedPath -ne $tempRoot) {
            Remove-Item -LiteralPath $verifiedPath -Recurse -Force
        }
    }
}
