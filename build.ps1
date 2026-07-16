[CmdletBinding()]
param(
    [switch] $CleanDependencies,
    [switch] $SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot

$LedgerRoot = Join-Path $Root "ledger"
$VcpkgRoot = Join-Path $Root "vcpkg"
$BuildRoot = Join-Path $Root "build\ledger"
$InstalledRoot = Join-Path $Root "vcpkg_installed"
$ArtifactRoot = Join-Path $Root "artifacts"

$Triplet = "x64-windows-static"

$ExpectedLedgerCommit =
    "d422d3cdbf16e72d653908a3fda8ffda8dfadaf7"

$ExpectedVcpkgCommit =
    "cd61e1e26a038e82d6550a3ebbe0fbbfe7da78e3"

function Invoke-External {
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [string[]] $Arguments = @()
    )

    Write-Host ""
    Write-Host "> $FilePath $($Arguments -join ' ')"

    & $FilePath @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE: $FilePath"
    }
}

function Get-GitCommit {
    param(
        [Parameter(Mandatory)]
        [string] $RepositoryPath
    )

    $commit = & git -C $RepositoryPath rev-parse HEAD |
        Select-Object -First 1

    if ($LASTEXITCODE -ne 0) {
        throw "Could not read Git revision from $RepositoryPath"
    }

    return $commit.Trim()
}

Write-Host "Checking required tools..."

Get-Command git -ErrorAction Stop | Out-Null
Get-Command cmake -ErrorAction Stop | Out-Null
Get-Command ctest -ErrorAction Stop | Out-Null

$cmakeVersionLine = & cmake --version |
    Select-Object -First 1

if ($LASTEXITCODE -ne 0) {
    throw "Could not determine the installed CMake version."
}

if ($cmakeVersionLine -notmatch "(\d+\.\d+\.\d+)") {
    throw "Could not parse CMake version from: $cmakeVersionLine"
}

$cmakeVersion = [version] $Matches[1]

if ($cmakeVersion -lt [version] "4.2.0") {
    throw "CMake 4.2.0 or newer is required for Visual Studio 2026. Found $cmakeVersion."
}

Write-Host "CMake version: $cmakeVersion"

$VsWhere = Join-Path ${env:ProgramFiles(x86)} `
    "Microsoft Visual Studio\Installer\vswhere.exe"

if (-not (Test-Path $VsWhere)) {
    throw "vswhere.exe was not found. Install Visual Studio 2026."
}

$VsQuery = @(
    "-latest",
    "-version", "[18.0,19.0)",
    "-products", "*",
    "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
)

$VsInstallPath = & $VsWhere @VsQuery `
    -property installationPath |
    Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($VsInstallPath)) {
    throw "Visual Studio 2026 with the x64/x86 C++ tools was not found."
}

$VsInstallPath = $VsInstallPath.Trim()

$VsVersion = & $VsWhere @VsQuery `
    -property installationVersion |
    Select-Object -First 1

Write-Host "Visual Studio: $VsVersion"
Write-Host "Installation:  $VsInstallPath"

# Ensure vcpkg uses the same Visual Studio installation selected by CMake.
$env:VCPKG_ROOT = $VcpkgRoot
$env:VCPKG_DISABLE_METRICS = "1"
$env:VCPKG_VISUAL_STUDIO_PATH = $VsInstallPath

Write-Host ""
Write-Host "Initializing pinned submodules..."

Invoke-External `
    -FilePath "git" `
    -Arguments @(
        "-C", $Root,
        "submodule", "update",
        "--init", "--recursive"
    )

$LedgerCommit = Get-GitCommit -RepositoryPath $LedgerRoot
$VcpkgCommit = Get-GitCommit -RepositoryPath $VcpkgRoot

if ($LedgerCommit -ne $ExpectedLedgerCommit) {
    throw @"
Unexpected Ledger revision.

Expected: $ExpectedLedgerCommit
Actual:   $LedgerCommit

Run:
git submodule update --init
git -C ledger checkout --detach v3.4.1
"@
}

if ($VcpkgCommit -ne $ExpectedVcpkgCommit) {
    throw @"
Unexpected vcpkg revision.

Expected: $ExpectedVcpkgCommit
Actual:   $VcpkgCommit

Run:
git submodule update --init
git -C vcpkg checkout --detach 2026.06.24
"@
}

Write-Host "Ledger commit: $LedgerCommit"
Write-Host "vcpkg commit: $VcpkgCommit"

$VcpkgExe = Join-Path $VcpkgRoot "vcpkg.exe"

if (-not (Test-Path $VcpkgExe)) {
    Write-Host ""
    Write-Host "Bootstrapping vcpkg..."

    Invoke-External `
        -FilePath (Join-Path $VcpkgRoot "bootstrap-vcpkg.bat") `
        -Arguments @("-disableMetrics")
}

Write-Host ""
Write-Host "Cleaning generated build output..."

Remove-Item `
    -Path $BuildRoot `
    -Recurse `
    -Force `
    -ErrorAction SilentlyContinue

Remove-Item `
    -Path $ArtifactRoot `
    -Recurse `
    -Force `
    -ErrorAction SilentlyContinue

if ($CleanDependencies) {
    Write-Host "Removing installed vcpkg dependencies..."

    Remove-Item `
        -Path $InstalledRoot `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}

New-Item `
    -Path $BuildRoot `
    -ItemType Directory `
    -Force |
    Out-Null

New-Item `
    -Path $ArtifactRoot `
    -ItemType Directory `
    -Force |
    Out-Null

$ToolchainFile = Join-Path `
    $VcpkgRoot `
    "scripts\buildsystems\vcpkg.cmake"

$ConfigureArguments = @(
    "-S", $LedgerRoot
    "-B", $BuildRoot
    "-G", "Visual Studio 18 2026"
    "-A", "x64"

    "-DCMAKE_GENERATOR_INSTANCE=$VsInstallPath"
    "-DCMAKE_BUILD_TYPE=Release"

    "-DCMAKE_TOOLCHAIN_FILE=$ToolchainFile"
    "-DVCPKG_TARGET_TRIPLET=$Triplet"
    "-DVCPKG_INSTALLED_DIR=$InstalledRoot"
    "-DVCPKG_MANIFEST_DIR=$Root"
    "-DVCPKG_MANIFEST_INSTALL=ON"

    # The vcpkg static triplet also requests the static CRT.
    "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded"

    # The Chocolatey binary does not need optional language bindings,
    # documentation generation, GPG support, or libledger.dll.
    "-DUSE_PYTHON=OFF"
    "-DUSE_GPGME=OFF"
    "-DBUILD_LIBRARY=OFF"
    "-DBUILD_DOCS=OFF"
    "-DBUILD_WEB_DOCS=OFF"

    "-DPRECOMPILE_SYSTEM_HH=ON"
)

Write-Host ""
Write-Host "Configuring Ledger..."

Invoke-External `
    -FilePath "cmake" `
    -Arguments $ConfigureArguments

Write-Host ""
Write-Host "Building Ledger and its tests..."

Invoke-External `
    -FilePath "cmake" `
    -Arguments @(
        "--build", $BuildRoot,
        "--config", "Release",
        "--parallel"
    )

if (-not $SkipTests) {
    Write-Host ""
    Write-Host "Running Ledger tests..."

    Invoke-External `
        -FilePath "ctest" `
        -Arguments @(
            "--test-dir", $BuildRoot,
            "-C", "Release",
            "--output-on-failure",
            "--parallel", [Environment]::ProcessorCount.ToString()
        )
}

$BuiltExecutable = Join-Path `
    $BuildRoot `
    "Release\ledger.exe"

if (-not (Test-Path $BuiltExecutable)) {
    throw "The build completed, but ledger.exe was not found at $BuiltExecutable"
}

$ArtifactExecutable = Join-Path `
    $ArtifactRoot `
    "ledger.exe"

Copy-Item `
    -Path $BuiltExecutable `
    -Destination $ArtifactExecutable `
    -Force

# Include Ledger's own license.
Copy-Item `
    -Path (Join-Path $LedgerRoot "LICENSE.md") `
    -Destination (Join-Path $ArtifactRoot "LICENSE-ledger.md") `
    -Force

# Preserve all dependency notices emitted by vcpkg.
$LicenseRoot = Join-Path $ArtifactRoot "licenses"

New-Item `
    -Path $LicenseRoot `
    -ItemType Directory `
    -Force |
    Out-Null

$VcpkgShareRoot = Join-Path `
    $InstalledRoot `
    "$Triplet\share"

if (Test-Path $VcpkgShareRoot) {
    Get-ChildItem `
        -Path $VcpkgShareRoot `
        -Directory |
        ForEach-Object {
            $CopyrightFile = Join-Path $_.FullName "copyright"

            if (Test-Path $CopyrightFile) {
                Copy-Item `
                    -Path $CopyrightFile `
                    -Destination (
                        Join-Path $LicenseRoot "$($_.Name).txt"
                    ) `
                    -Force
            }
        }
}

Write-Host ""
Write-Host "Verifying version..."

$VersionOutput = & $ArtifactExecutable --version 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "ledger.exe failed while reporting its version."
}

Write-Host $VersionOutput

if (($VersionOutput -join "`n") -notmatch "\b3\.4\.1\b") {
    throw "The executable did not identify itself as Ledger 3.4.1."
}

Write-Host ""
Write-Host "Running a basic smoke test..."

$SmokeFile = Join-Path $ArtifactRoot "smoke-test.ledger"

@'
2026-01-01 Opening Balance
    Assets:Cash        $10.00
    Equity:Opening
'@ | Set-Content `
    -Path $SmokeFile `
    -Encoding Ascii

Invoke-External `
    -FilePath $ArtifactExecutable `
    -Arguments @(
        "-f", $SmokeFile,
        "balance"
    )

Remove-Item $SmokeFile -Force

$Hash = Get-FileHash `
    -Path $ArtifactExecutable `
    -Algorithm SHA256

$HashText = "$($Hash.Hash.ToLowerInvariant())  ledger.exe"

Set-Content `
    -Path (Join-Path $ArtifactRoot "ledger.exe.sha256") `
    -Value $HashText `
    -Encoding Ascii

Write-Host ""
Write-Host "Build completed successfully."
Write-Host ""
Write-Host "Executable:"
Write-Host "  $ArtifactExecutable"
Write-Host ""
Write-Host "SHA-256:"
Write-Host "  $($Hash.Hash)"
