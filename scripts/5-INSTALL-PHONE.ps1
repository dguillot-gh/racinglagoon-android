# Step 5: install the app on your phone over USB, and copy your discs to it.
#   pwsh -File scripts\5-INSTALL-PHONE.ps1 [-Serial <adb serial>] [-NoDiscs] [-Card <your.mcd>] [-DryRun]
# Needs USB debugging on (Settings > Developer options) and the phone's "Allow USB debugging" answered.
# Before installing, the app's saves on the phone (memory cards, settings, save states) are copied to
# workspace\saves-backup; an update keeps them anyway. Your discs go to the phone's Download\<game>
# folder (skipped when already there). On the phone: open the app, Select game file, go to
# Download > <game>, pick the .cue file(s), then Play.
# -Serial: which phone, when more than one is connected (adb devices lists them).
# -Card: a PS1 memory card image of your own (128 KB .mcd, e.g. from DuckStation) for slot 1. It never
#        replaces a card the phone already has.
param([string]$Serial = "", [switch]$NoDiscs, [string]$Card = "", [switch]$DryRun)
. (Join-Path $PSScriptRoot "game-common.ps1")

if ($Serial) { $env:ANDROID_SERIAL = $Serial }
$apk = Get-ChildItem $ApkDir -Filter "$Game-*.apk" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
if (-not $apk -and -not $DryRun) { Fail "no APK in ${ApkDir}: run scripts\4-BUILD-ANDROID.ps1 first" }
$phone = Join-Path $Repo "tools\phone.ps1"
$backup = Join-Path $Workspace "saves-backup"
$dry = @(); if ($DryRun) { $dry = @("-DryRun") }
Run-Step "finding the phone" $phone (@("-Action", "connect") + $dry)
Run-Step "installing $(if ($apk) { $apk.Name } else { 'the newest APK' }) (saves backed up to $backup first)" $phone `
    (@("-Action", "install", "-Package", $Package, "-Apk", "$(if ($apk) { $apk.FullName } else { 'none' })", "-OutDir", $backup) + $dry)
if (-not $NoDiscs) {
    Run-Step "copying your discs to the phone (skipped when already there)" $phone `
        (@("-Action", "push-disc", "-Folder", (Join-Path $RecompDir "disc"), "-Name", $Game) + $dry)
}
if ($Card) {
    if ($DryRun) { Say "DRY RUN: would import $Card as memory card 1 (only if the phone has none)" }
    else {
        pwsh -NoProfile -File $phone -Action import-card -Package $Package -Card $Card -Slot 1 2>&1 | Out-Host
        if ($LASTEXITCODE -eq 2) { Say "the phone already has a memory card 1: left as it is" }
        elseif ($LASTEXITCODE -ne 0) { Fail "importing the memory card" }
    }
}
Say "OK: installed. On the phone: open $Title, Select game file, Download > $Game, pick the .cue file(s), Play."
