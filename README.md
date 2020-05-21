# Windows Ledger Binaries
A more automated windows build for the Ledger CLI.

Ledger homepage and documentation located [here](https://www.ledger-cli.org/).

Ledger is a double-entry accounting system with a command-line reporting interface.

Main project is located here: https://github.com/ledger/ledger

The only purpose this repo serves is to provide a location for Windows binaries.

This repo also currently supplies the Windows binaries for the [Chocolatey](https://chocolatey.org/packages/ledger) package.

To follow along and build yourself:

Requirements:
* Visual Studio Community 2019 (other versions also work). Mainly need the `msbuild` command.
* CMake 3.14.4

Then to build:
1. Clone the repo (will take quite a while, as Boost is pretty large)
2. Either open the Developer Powershell for Visual Studio, or add `msbuild` to your PATH. 
3. run the build Powershell script `build.ps1`, or just run the commands individually
