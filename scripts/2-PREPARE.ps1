# Step 2: set the game up from YOUR discs and generate its code.
#   pwsh -File scripts\2-PREPARE.ps1 [-Background <your picture.jpg>] [-DryRun]
# 1. Finds your discs in workspace\discs by SHA-1 (any file names; README: What you need).
# 2. Copies them into workspace\recomps\<game> and probes Disc 1 (tools\new-recomp.ps1), then puts
#    this repository's tuned setup (game\game.toml, seeds, the game's own tools) over the probe's.
# 3. Makes the build folder workspace\android-recomp\<game>: the engine, the Android app, the app's
#    default settings (game\game.toml.in) (tools\port-game.ps1).
# 4. Recompiles the game's main program to C (the recompiler from step 1; about a minute).
# -Background: a picture of your own for the start screen (JPEG). Box art for the app icon is downloaded
# from libretro-thumbnails at build time; neither is part of this repository.
# Your discs are only read, never changed. Safe to run again.
param([string]$Background = "", [switch]$DryRun)
. (Join-Path $PSScriptRoot "game-common.ps1")

$exe = Join-Path $FrameworkDir "recompiler\build-mingw\psxrecomp-game.exe"
if (-not (Test-Path $exe)) { Fail "no recompiler yet: run scripts\1-INSTALL-TOOLS.ps1 first" }
$discs = Find-Discs

# --- the game folder (recomps\<game>) -------------------------------------------------------------
if (Test-Path (Join-Path $RecompDir "game.toml")) {
    Say "game folder already set up: $RecompDir (refreshing its setup from game\)"
    if (-not $DryRun) {
        # Keep this PC's disc names; take everything else from the repository's game.toml.
        $mine = Get-Content (Join-Path $RecompDir "game.toml") -Raw
        $discBlock = [regex]::Match($mine, '(?ms)^discs\s*=\s*\[.*?^\][ \t]*\r?\n(disc[ \t]*=[ \t]*"[^"\r\n]*"[ \t]*\r?\n)?').Value
        $ours = Get-Content (Join-Path $Repo "game\game.toml") -Raw
        # -replace, not [regex]::Replace with a script block (Constrained Language Mode garbles that).
        $ours = $ours -replace '(?ms)^discs\s*=\s*\[.*?^\]\s*\r?\n', ''
        $ours = $ours -replace '(?m)^disc\s*=\s*".*"\s*\r?\n', ''
        $ours = $ours -replace '(?m)^(exe\s*=\s*".*?")[ \t]*\r?\n', ('${1}' + "`n" + $discBlock.Replace('$', '$$'))
        Set-Content (Join-Path $RecompDir "game.toml") $ours -Encoding utf8NoBOM -NoNewline
        foreach ($d in "seeds", "tools", "src", "aot") { if (Test-Path (Join-Path $Repo "game\$d")) { Copy-Item (Join-Path $Repo "game\$d") $RecompDir -Recurse -Force } }
        foreach ($f in "aot_exclude.txt", "android-bios.txt", "boxart-name.txt") { if (Test-Path (Join-Path $Repo "game\$f")) { Copy-Item (Join-Path $Repo "game\$f") $RecompDir -Force } }
    }
} elseif ($DryRun) {
    Say "DRY RUN: would copy your discs into $RecompDir and probe Disc 1 (tools\new-recomp.ps1)"
} else {
    Say "setting the game up from your discs (copies them into $RecompDir) ..."
    & (Join-Path $Repo "tools\new-recomp.ps1") -Name $Game -Disc $discs 2>&1 | Tee-Object -FilePath $script:LogFile -Append | Out-Host
    if ($LASTEXITCODE -ne 0) { Fail "tools\new-recomp.ps1 (log $script:LogFile)" }
}

# --- the build folder (android-recomp\<game>) -------------------------------------------------------
$ported = (Test-Path (Join-Path $GameDir "android\app\build.gradle")) -and (Test-Path (Join-Path $GameDir "CMakeLists.txt"))
if ($DryRun) {
    Say "DRY RUN: would $(if ($ported) { 'refresh' } else { 'make' }) the build folder $GameDir"
} else {
    if ((Test-Path $GameDir) -and -not $ported) {
        $aside = "$Game.incomplete-" + (Get-Date -Format "yyyyMMdd-HHmmss")
        Rename-Item $GameDir $aside
        Say "an earlier build folder was only partly made; moved aside to $aside"
    }
    if (Test-Path $GameDir) {
        Say "build folder: $GameDir (updating its engine copy and setup)"
        robocopy $FrameworkDir (Join-Path $GameDir "psxrecomp") /MIR /XD (Join-Path $FrameworkDir "recompiler\build") (Join-Path $FrameworkDir ".git") /XF overlay_codegen_hash.h /NFL /NDL /NJH /NJS | Out-Null
        if ($LASTEXITCODE -ge 8) { Fail "copying the engine into $GameDir" }
        robocopy $RecompDir $GameDir game.toml /NFL /NDL /NJH /NJS | Out-Null
        foreach ($d in "seeds", "tools", "src", "aot") { if (Test-Path (Join-Path $RecompDir $d)) { robocopy (Join-Path $RecompDir $d) (Join-Path $GameDir $d) /E /NFL /NDL /NJH /NJS | Out-Null } }
    } else {
        Say "making the build folder $GameDir (copies the engine, about 0.5 GB) ..."
        pwsh -NoProfile -File (Join-Path $Repo "tools\port-game.ps1") -Name $Game -SourceDir (Split-Path $RecompDir) -Framework $FrameworkDir -OutRoot $DefaultWorkDir 2>&1 |
            Tee-Object -FilePath $script:LogFile -Append | Out-Host
        if ($LASTEXITCODE -ne 0) { Fail "tools\port-game.ps1 (log $script:LogFile)" }
    }
    # The app's own settings: this repository's tuned defaults (speed settings for weaker phones).
    Copy-Item (Join-Path $Repo "game\game.toml.in") (Join-Path $GameDir "android\app\src\main\assets\game.toml.in") -Force
    # The game's own additions to the app's CMake build (game\cmake-extra.cmake: e.g. a C source for a mod),
    # appended once after a marker line; running this again replaces them instead of adding them twice.
    $extra = Join-Path $Repo "game\cmake-extra.cmake"
    if (Test-Path $extra) {
        $cm = Join-Path $GameDir "CMakeLists.txt"
        $mark = "# --- added by 2-PREPARE from game/cmake-extra.cmake ---"
        $body = (Get-Content $cm -Raw) -split $mark, 0, "SimpleMatch"
        Set-Content $cm ($body[0].TrimEnd() + "`n`n" + $mark + "`n" + (Get-Content $extra -Raw)) -Encoding utf8NoBOM -NoNewline
        Say "game\cmake-extra.cmake added to the build"
    }
    if ($Background) {
        if (-not (Test-Path -LiteralPath $Background)) { Fail "no such picture: $Background" }
        $drawable = Join-Path $GameDir "android\app\src\main\res\drawable"
        New-Item -ItemType Directory -Force $drawable | Out-Null
        Get-ChildItem $drawable -Filter "launcher_bg.*" | Remove-Item -Force
        Copy-Item -LiteralPath $Background (Join-Path $drawable ("launcher_bg" + (Get-Item -LiteralPath $Background).Extension.ToLower())) -Force
        Say "start-screen background: $Background"
    }
}

# --- generate the game's code --------------------------------------------------------------------
$marker = Join-Path $GameDir ".regenerated"
$tomlTime = (Get-Item (Join-Path $Repo "game\game.toml")).LastWriteTime
$stale = -not (Test-Path $marker) -or (Get-Item $exe).LastWriteTime -gt (Get-Item $marker).LastWriteTime -or
         $tomlTime -gt (Get-Item $marker).LastWriteTime
if ($DryRun) {
    Say "DRY RUN: would $(if ($stale) { 'generate' } else { 'keep' }) the game's code"
} elseif (-not $stale) {
    Say "code already generated (and nothing changed since)"
} else {
    Say "generating the game's code (about a minute; log $GameDir\regen.log) ..."
    $local = Join-Path $GameDir "psxrecomp\recompiler\build-mingw\psxrecomp-game.exe"
    New-Item -ItemType Directory -Force (Split-Path $local) | Out-Null
    robocopy (Split-Path $exe) (Split-Path $local) *.exe *.dll /NFL /NDL /NJH /NJS | Out-Null
    Push-Location $GameDir
    & $local --config game.toml *> (Join-Path $GameDir "regen.log")
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { Fail "code generation (exit $code; see $GameDir\regen.log)" }
    # A regeneration that writes fewer split files leaves old higher-numbered ones behind: remove them.
    $gen = Join-Path $GameDir "generated"
    foreach ($w in Select-String (Join-Path $GameDir "regen.log") -Pattern 'Wrote (\d+) shards .* for (\S+)') {
        $n = [int]$w.Matches[0].Groups[1].Value; $stem = $w.Matches[0].Groups[2].Value
        Get-ChildItem $gen -Filter "$($stem)_full_*.c" | Where-Object { $_.Name -match '_full_(\d+)\.c$' -and [int]$Matches[1] -ge $n } | Remove-Item -Force
    }
    Set-Content $marker (Get-Date -Format s)
    Say "code generated"
}

if (-not $DryRun) {
    # The codegen hash header: the pre-compile and the app build both read it before CMake would write it.
    $py = Find-Python
    $local = Join-Path $GameDir "psxrecomp\recompiler\build-mingw\psxrecomp-game.exe"
    & $py (Join-Path $Repo "tools\codegen_hash.py") (Join-Path $GameDir "psxrecomp") --recompiler $local 2>&1 | Out-Host
    if ($LASTEXITCODE -eq 2) { Fail "the recompiler is older than the engine: run scripts\1-INSTALL-TOOLS.ps1 again" }
    if ($LASTEXITCODE -ne 0) { Fail "could not write the codegen hash header" }
    # The cover archive's name for the game, when it differs from the disc file's (game\boxart-name.txt),
    # and the Sony BIOS the game needs, when it needs one (game\android-bios.txt; README: What you need).
    foreach ($f in "boxart-name.txt", "android-bios.txt") { if (Test-Path (Join-Path $Repo "game\$f")) { Copy-Item (Join-Path $Repo "game\$f") $GameDir -Force } }
    pwsh -NoProfile -File (Join-Path $Repo "tools\icon.ps1") -GameDir $GameDir 2>&1 | Out-Host
}
Say "OK: prepared. Next: scripts\3-PRECOMPILE.ps1"
