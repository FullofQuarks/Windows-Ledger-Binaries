[CmdletBinding()]
param(
    [switch] $CleanDependencies,
    [switch] $SkipTests,

    [string] $Generator = "Visual Studio 18 2026"
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

function Invoke-External {
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [string[]] $Arguments = @()
    )

    Write-Host ""
    Write-Host "> $FilePath $($Arguments -join ' ')"

    & $FilePath @Arguments

    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: $FilePath"
    }
}

Write-Host "Checking required tools..."

$GitCommand = Get-Command `
    git `
    -CommandType Application `
    -ErrorAction Stop

$CMakeCommand = Get-Command `
    cmake `
    -CommandType Application `
    -ErrorAction Stop

if (-not $SkipTests) {
    $CTestCommand = Get-Command `
        ctest `
        -CommandType Application `
        -ErrorAction Stop
}

Write-Host "Git:   $($GitCommand.Source)"
Write-Host "CMake: $($CMakeCommand.Source)"

#
# Locate the newest Visual Studio installation that has the
# Microsoft C++ x64/x86 toolchain installed.
#
$VsWhere = Join-Path `
    ${env:ProgramFiles(x86)} `
    "Microsoft Visual Studio\Installer\vswhere.exe"

if (-not (Test-Path $VsWhere)) {
    throw @"
vswhere.exe was not found.

Install Visual Studio with the Desktop development with C++ workload.
"@
}

$VsQuery = @(
    "-latest",
    "-products", "*",
    "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "-property", "installationPath"
)

$VsInstallOutput = @(
    & $VsWhere @VsQuery 2>&1
)

$vsWhereExitCode = $LASTEXITCODE

if ($vsWhereExitCode -ne 0) {
    throw @"
vswhere failed while locating Visual Studio.

Exit code:
$vsWhereExitCode

Output:
$($VsInstallOutput -join [Environment]::NewLine)
"@
}

if ($VsInstallOutput.Count -eq 0) {
    throw @"
Visual Studio with the Microsoft C++ x64/x86 build tools was not found.

Open Visual Studio Installer and install the Desktop development with C++
workload.
"@
}

$VsInstallPath = ([string] $VsInstallOutput[0]).Trim()

if ([string]::IsNullOrWhiteSpace($VsInstallPath)) {
    throw "Visual Studio was detected, but its installation path was empty."
}

Write-Host "Visual Studio: $VsInstallPath"
Write-Host "Generator:     $Generator"

#
# Ensure the source submodules are initialized at the revisions recorded
# by the parent Git repository.
#
Write-Host ""
Write-Host "Initializing submodules..."

Invoke-External `
    -FilePath $GitCommand.Source `
    -Arguments @(
        "-C", $Root,
        "submodule",
        "update",
        "--init",
        "--recursive"
    )

if (-not (Test-Path $LedgerRoot)) {
    throw "The Ledger submodule directory was not found: $LedgerRoot"
}

if (-not (Test-Path $VcpkgRoot)) {
    throw "The vcpkg submodule directory was not found: $VcpkgRoot"
}

if (-not (Test-Path (Join-Path $Root "vcpkg.json"))) {
    throw "vcpkg.json was not found in the repository root."
}

#
# Configure vcpkg.
#
$env:VCPKG_ROOT = $VcpkgRoot
$env:VCPKG_DISABLE_METRICS = "1"
$env:VCPKG_VISUAL_STUDIO_PATH = $VsInstallPath

$VcpkgExe = Join-Path $VcpkgRoot "vcpkg.exe"

if (-not (Test-Path $VcpkgExe)) {
    Write-Host ""
    Write-Host "Bootstrapping vcpkg..."

    $BootstrapVcpkg = Join-Path `
        $VcpkgRoot `
        "bootstrap-vcpkg.bat"

    if (-not (Test-Path $BootstrapVcpkg)) {
        throw "The vcpkg bootstrap script was not found: $BootstrapVcpkg"
    }

    Invoke-External `
        -FilePath $BootstrapVcpkg `
        -Arguments @("-disableMetrics")
}

if (-not (Test-Path $VcpkgExe)) {
    throw "vcpkg.exe was not created successfully."
}

#
# Clean generated output.
#
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

#
# Configure Ledger.
#
$ToolchainFile = Join-Path `
    $VcpkgRoot `
    "scripts\buildsystems\vcpkg.cmake"

if (-not (Test-Path $ToolchainFile)) {
    throw "The vcpkg CMake toolchain file was not found: $ToolchainFile"
}

$ConfigureArguments = @(
    "-S", $LedgerRoot,
    "-B", $BuildRoot,
    "-G", $Generator,
    "-A", "x64",

    "-DCMAKE_GENERATOR_INSTANCE=$VsInstallPath",
    "-DCMAKE_TOOLCHAIN_FILE=$ToolchainFile",
    "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded",

    "-DVCPKG_TARGET_TRIPLET=$Triplet",
    "-DVCPKG_INSTALLED_DIR=$InstalledRoot",
    "-DVCPKG_MANIFEST_DIR=$Root",
    "-DVCPKG_MANIFEST_INSTALL=ON",

    "-DUSE_PYTHON=OFF",
    "-DUSE_GPGME=OFF",
    "-DBUILD_LIBRARY=OFF",
    "-DBUILD_DOCS=OFF",
    "-DBUILD_WEB_DOCS=OFF",
    "-DPRECOMPILE_SYSTEM_HH=ON"
)

Write-Host ""
Write-Host "Configuring Ledger..."

Invoke-External `
    -FilePath $CMakeCommand.Source `
    -Arguments $ConfigureArguments

#
# Build Ledger and any configured test targets.
#
Write-Host ""
Write-Host "Building Ledger..."

Invoke-External `
    -FilePath $CMakeCommand.Source `
    -Arguments @(
        "--build", $BuildRoot,
        "--config", "Release",
        "--parallel"
    )

#
# Run the test suite unless explicitly skipped.
#
if (-not $SkipTests) {
    Write-Host ""
    Write-Host "Running Ledger tests..."

    Invoke-External `
        -FilePath $CTestCommand.Source `
        -Arguments @(
            "--test-dir", $BuildRoot,
            "-C", "Release",
            "--output-on-failure",
            "--parallel", [Environment]::ProcessorCount.ToString()
        )
}

#
# Locate and copy ledger.exe.
#
$PossibleExecutables = @(
    (Join-Path $BuildRoot "Release\ledger.exe"),
    (Join-Path $BuildRoot "ledger.exe")
)

$BuiltExecutable = $null

foreach ($candidate in $PossibleExecutables) {
    if (Test-Path $candidate) {
        $BuiltExecutable = $candidate
        break
    }
}

if ($null -eq $BuiltExecutable) {
    throw @"
The build completed, but ledger.exe could not be found.

Locations checked:
$($PossibleExecutables -join [Environment]::NewLine)
"@
}

$ArtifactExecutable = Join-Path `
    $ArtifactRoot `
    "ledger.exe"

Copy-Item `
    -Path $BuiltExecutable `
    -Destination $ArtifactExecutable `
    -Force

#
# Copy Ledger's license.
#
$LedgerLicenseCandidates = @(
    (Join-Path $LedgerRoot "LICENSE.md"),
    (Join-Path $LedgerRoot "LICENSE")
)

$LedgerLicense = $LedgerLicenseCandidates |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if ($null -ne $LedgerLicense) {
    Copy-Item `
        -Path $LedgerLicense `
        -Destination (Join-Path $ArtifactRoot "LICENSE-ledger.txt") `
        -Force
}
else {
    Write-Warning "Ledger's license file was not found."
}

#
# Copy dependency license notices generated by vcpkg.
#
$LicenseRoot = Join-Path `
    $ArtifactRoot `
    "licenses"

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
            $CopyrightFile = Join-Path `
                $_.FullName `
                "copyright"

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
else {
    Write-Warning "The vcpkg dependency notice directory was not found."
}

#
# Run a simple functional smoke test.
#
Write-Host ""
Write-Host "Running a basic smoke test..."

$SmokeFile = Join-Path `
    $ArtifactRoot `
    "smoke-test.ledger"

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

Remove-Item `
    -Path $SmokeFile `
    -Force

#
# Generate the release checksum.
#
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
