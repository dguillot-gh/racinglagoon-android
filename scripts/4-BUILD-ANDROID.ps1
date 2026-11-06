# Step 4: build the phone app (APK) into workspace\apks.
#   pwsh -File scripts\4-BUILD-ANDROID.ps1 [-DryRun]
# Gradle builds the app with the generated code and the pre-compiled code from step 3 (30-60 minutes the
# first time; later builds are much faster). Gradle downloads Android libraries from Google and Maven
# Central, and SDL3 once, on the first build.
# The APK contains the game's code: it is for your own phone. Please do not share it.
param([switch]$DryRun)
. (Join-Path $PSScriptRoot "game-common.ps1")

if (-not (Test-Path (Join-Path $GameDir ".regenerated"))) { Fail "run scripts\2-PREPARE.ps1 first" }
Run-Step "building the app" (Join-Path $Repo "tools\build.ps1") @("-GameDir", $GameDir, "-Play")
if (-not $DryRun) {
    $apk = Get-ChildItem (Join-Path $GameDir "apk") -Filter *.apk | Sort-Object LastWriteTime | Select-Object -Last 1
    New-Item -ItemType Directory -Force $ApkDir | Out-Null
    Copy-Item $apk.FullName $ApkDir -Force
    # Keep the newest three here (one to roll back to); each is about 100 MB.
    Get-ChildItem $ApkDir -Filter "$Game-*.apk" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 3 | Remove-Item -Force
    Get-ChildItem (Join-Path $GameDir "apk") -Filter "$Game-*.apk" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 2 | Remove-Item -Force
    Say "OK: $(Join-Path $ApkDir $apk.Name)"
}
Say "Next: scripts\5-INSTALL-PHONE.ps1 (phone on USB with USB debugging on)"
