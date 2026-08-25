# Windows Ledger Binaries
A more automated windows build for the Ledger CLI.

Ledger homepage and documentation located [here](https://www.ledger-cli.org/).

Ledger is a double-entry accounting system with a command-line reporting interface.

Main project is located here: https://github.com/ledger/ledger

The only purpose this repo serves is to provide a location for Windows binaries, and instructions on how to build it yourself. These instructions show how to build using MSYS2 UCRT64.

This repo also currently supplies the Windows binaries for the [Chocolatey](https://chocolatey.org/packages/ledger) package.

The build enables:

* GNU Readline
* ICU Unicode regular expressions
* GPGME encrypted-journal support
* User/web documentation
* Doxygen documentation
* Static third-party libraries

Python bindings and the shared `libledger` library are intentionally disabled.

## Build

### 1. Install MSYS2

Install [MSYS2](https://www.msys2.org/), then open the **MSYS2 UCRT64** shell.

Update MSYS2:

```bash
pacman -Syu
```

If prompted to close the shell, reopen the **UCRT64** shell and run `pacman -Syu` again.

### 2. Install dependencies

```bash
pacman -S --needed \
  base-devel \
  git \
  groff \
  mingw-w64-ucrt-x86_64-toolchain \
  mingw-w64-ucrt-x86_64-cmake \
  mingw-w64-ucrt-x86_64-ninja \
  mingw-w64-ucrt-x86_64-pkgconf \
  mingw-w64-ucrt-x86_64-boost \
  mingw-w64-ucrt-x86_64-gmp \
  mingw-w64-ucrt-x86_64-mpfr \
  mingw-w64-ucrt-x86_64-icu \
  mingw-w64-ucrt-x86_64-readline \
  mingw-w64-ucrt-x86_64-gpgme \
  mingw-w64-ucrt-x86_64-utf8cpp \
  mingw-w64-ucrt-x86_64-python \
  mingw-w64-ucrt-x86_64-doxygen \
  mingw-w64-ucrt-x86_64-graphviz \
  mingw-w64-ucrt-x86_64-texinfo \
  mingw-w64-ucrt-x86_64-texlive-core
```

CMake 4.4 or newer is required.

### 3. Clone

```bash
git clone --recursive https://github.com/FullofQuarks/Windows-Ledger-Binaries.git
cd Windows-Ledger-Binaries
```

If already cloned:

```bash
git submodule update --init --recursive
```

### 4. Configure

```bash
cmake \
  -S "$PWD/ledger" \
  --presets-file "$PWD/CMakePresets.json" \
  --preset windows-ucrt64-static
```

### 5. Build

```bash
cmake \
  --build \
  --presets-file "$PWD/CMakePresets.json" \
  --preset windows-ucrt64-static \
  --parallel
```

This creates the build located:

```text
build/ledger.exe
```

### 6. Test

```bash
ctest \
  --presets-file "$PWD/CMakePresets.json" \
  --preset windows-ucrt64-static
```

### 7. Build documentation

```bash
cmake \
  --build \
  --presets-file "$PWD/CMakePresets.json" \
  --preset windows-ucrt64-docs \
  --parallel
```

The main generated documentation is:

```text
build/doc/ledger3.html
build/doc/ledger3.pdf
build/doc/html/index.html
```

`build/doc/html/index.html` is the Doxygen developer documentation.

### 8. Stage the installation

```bash
cmake --install build
```

Installed files are placed under:

```text
stage/
```

### Optional: strip the release executable

```bash
cp build/ledger.exe ledger.exe
strip --strip-unneeded ledger.exe
```

