# Step 1: the build tools, and the engine (the framework submodule).
#   pwsh -File scripts\1-INSTALL-TOOLS.ps1 [-DryRun]
# Puts Java 17, the Android SDK (platform 35, NDK 28.2, CMake 3.22), a portable Python and the llvm-mingw
# C++ compiler into workspace\tools-cache (tools\setup.ps1), then builds the recompiler from the framework
# (tools\build-recompiler.ps1). Nothing is installed into Windows and no admin rights are needed.
# Before the Android SDK is installed you are asked to accept Google's licence for it
# (-AcceptAndroidLicenses: you already have). Tools you already have (Java 17, an Android SDK with the
# right NDK) are used instead of downloading them. Safe to run again: finished parts are skipped.
param([switch]$AcceptAndroidLicenses, [switch]$DryRun)
. (Join-Path $PSScriptRoot "game-common.ps1")

Say "workspace: $Workspace"
if (-not (Test-Path (Join-Path $Repo "framework\runtime\runtime.cmake"))) {
    if ($DryRun) { Say "DRY RUN: would fetch the framework submodule (git submodule update --init framework)" }
    else {
        Say "fetching the engine (framework submodule, about 150 MB) ..."
        git -C $Repo submodule update --init --recursive framework
        if ($LASTEXITCODE -ne 0) { Fail "git submodule update (clone with --recurse-submodules, or check your network)" }
    }
}
Say "engine: $FrameworkDir"
Run-Step "build tools (Java, Android SDK/NDK, Python)" (Join-Path $Repo "tools\setup.ps1") $(if ($AcceptAndroidLicenses) { @("-AcceptAndroidLicenses") } else { @() })
Run-Step "the recompiler (about 5-10 minutes the first time)" (Join-Path $Repo "tools\build-recompiler.ps1")
Say "OK: tools ready. Next: scripts\2-PREPARE.ps1"
