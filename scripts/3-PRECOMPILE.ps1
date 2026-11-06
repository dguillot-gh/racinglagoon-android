# Step 3: pre-compile the code the game loads from the disc while it runs, so the phone runs it natively
# instead of on the slower interpreter.
#   pwsh -File scripts\3-PRECOMPILE.ps1 [-MaxMinutes 45] [-FromPhone] [-DryRun]
# The disc scan (and the game's own extractor, game\tools\overlay_extract.py, when it has one) takes the
# code modules from your discs; tools\speed.ps1 compiles them with the Android NDK, one group per CPU core. 20-45 minutes the first
# time; finished pieces are kept, so a stopped run carries on where it was.
# -FromPhone: also pull the code the installed app recorded while you played (USB debugging on), so the
# next build covers that too.
param([int]$MaxMinutes = 45, [switch]$FromPhone, [switch]$DryRun)
. (Join-Path $PSScriptRoot "game-common.ps1")

if (-not (Test-Path (Join-Path $GameDir "android\app\src\main\assets\game.toml.in"))) { Fail "run scripts\2-PREPARE.ps1 first" }
$speedArgs = @("-GameDir", $GameDir, "-Package", $Package, "-MaxMinutes", "$MaxMinutes")
if (-not $FromPhone) { $speedArgs += "-NoPhone" }
Run-Step "pre-compiling the disc code of $Title (20-45 minutes the first time)" (Join-Path $Repo "tools\speed.ps1") $speedArgs
Say "OK: pre-compiled. Next: scripts\4-BUILD-ANDROID.ps1"
