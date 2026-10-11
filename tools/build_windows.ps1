param(
    [switch]$Debug,
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$repoPath = Split-Path -Parent $PSScriptRoot
$defaultGodotPath = "C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe"

function Resolve-GodotExecutable {
    param([string]$RequestedPath)

    $candidate = $RequestedPath
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
            $candidate = $env:GODOT
        } elseif (Test-Path -LiteralPath $defaultGodotPath) {
            $candidate = $defaultGodotPath
        } else {
            $candidate = "godot"
        }
    }

    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $candidate).Path
    }
    $command = Get-Command -Name $candidate -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw (
            "Godot executable not found: {0}. Set GODOT or pass -GodotPath. " +
            "Default: {1}"
        ) -f $candidate, $defaultGodotPath
    }
    return $command.Source
}

$GodotPath = Resolve-GodotExecutable -RequestedPath $GodotPath
$engineVersionLines = @(& $GodotPath --version)
if ($LASTEXITCODE -ne 0 -or $engineVersionLines.Count -eq 0) {
    throw "Could not read the Godot version from $GodotPath"
}
$engineVersion = ($engineVersionLines[0] | Out-String).Trim()
$templateVersion = $engineVersion -replace '\.official\..*$', ''
$templateDirectory = Join-Path $env:APPDATA "Godot\export_templates\$templateVersion"
$templateName = if ($Debug) {
    "windows_debug_x86_64.exe"
} else {
    "windows_release_x86_64.exe"
}
$consoleTemplateName = [IO.Path]::GetFileNameWithoutExtension($templateName) + "_console.exe"
$templatePath = Join-Path $templateDirectory $templateName
$consoleTemplatePath = Join-Path $templateDirectory $consoleTemplateName
if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $consoleTemplatePath -PathType Leaf)) {
    throw (
        "Godot Windows export templates are missing. Install the official {0} templates in " +
        "{1}. Expected: {2} and {3}"
    ) -f $templateVersion, $templateDirectory, $templateName, $consoleTemplateName
}

$modeName = if ($Debug) { "Debug" } else { "Release" }
$exportFlag = if ($Debug) { "--export-debug" } else { "--export-release" }
$buildRoot = [IO.Path]::GetFullPath((Join-Path $repoPath "build"))
$outputLeaf = if ($Debug) { "windows-debug" } else { "windows" }
$outputDirectory = [IO.Path]::GetFullPath((Join-Path $buildRoot $outputLeaf))
$expectedPrefix = $buildRoot.TrimEnd('\') + '\'
if (-not $outputDirectory.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean unexpected output directory: $outputDirectory"
}
if (Test-Path -LiteralPath $outputDirectory) {
    Remove-Item -LiteralPath $outputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$outputExecutable = Join-Path $outputDirectory "GravityOrb.exe"
$consoleWrapper = Join-Path $outputDirectory "GravityOrb.console.exe"
$sidecarPck = Join-Path $outputDirectory "GravityOrb.pck"
$previousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    & $GodotPath --headless --path $repoPath $exportFlag "Windows Desktop" $outputExecutable
    $exportExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
if ($exportExitCode -ne 0) {
    throw "Godot Windows $modeName export failed with exit code $exportExitCode"
}
if (-not (Test-Path -LiteralPath $outputExecutable -PathType Leaf)) {
    throw "Godot reported success but did not create $outputExecutable"
}
if (-not (Test-Path -LiteralPath $consoleWrapper -PathType Leaf)) {
    throw "Godot reported success but did not create $consoleWrapper"
}
if (Test-Path -LiteralPath $sidecarPck) {
    throw "Expected an embedded PCK, but Godot created $sidecarPck"
}

$commitHash = (& git -C $repoPath rev-parse HEAD | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($commitHash)) {
    throw "Could not read the Git commit hash for $repoPath"
}
$buildInfoPath = Join-Path $outputDirectory "BUILD.txt"
$buildInfo = @(
    "Commit: $commitHash"
    "BuiltUtc: $([DateTime]::UtcNow.ToString('o'))"
    "Engine: $engineVersion"
    "Mode: $modeName"
)
Set-Content -LiteralPath $buildInfoPath -Value $buildInfo -Encoding UTF8

$executableSize = (Get-Item -LiteralPath $outputExecutable).Length
Write-Output (
    "WINDOWS_BUILD_RESULT mode={0} exit=0 bytes={1} exe={2} wrapper={3} build_info={4}" -f `
        $modeName,
        $executableSize,
        $outputExecutable,
        $consoleWrapper,
        $buildInfoPath
)

