# Everything, in order, stopping at the first step that fails:
#   pwsh -File scripts\RUN-ALL.ps1 [-Install] [-Serial <adb serial>] [-Background <picture.jpg>]
#                                  [-AcceptAndroidLicenses] [-DryRun]
# 1-INSTALL-TOOLS, 2-PREPARE, 3-PRECOMPILE, 4-BUILD-ANDROID; with -Install also 5-INSTALL-PHONE.
# About 1-2 hours the first time (mostly the pre-compile and the app build); much faster afterwards.
param([switch]$Install, [string]$Serial = "", [string]$Background = "", [switch]$AcceptAndroidLicenses, [switch]$DryRun)
$ErrorActionPreference = "Stop"
# Each step's arguments are a list built with +=: a bare string would be splatted letter by letter.
$a1 = @(); if ($AcceptAndroidLicenses) { $a1 += "-AcceptAndroidLicenses" }
$a2 = @(); if ($Background) { $a2 += "-Background"; $a2 += $Background }
$a5 = @(); if ($Serial) { $a5 += "-Serial"; $a5 += $Serial }
$steps = @(
    @{ File = "1-INSTALL-TOOLS.ps1"; Args = $a1 },
    @{ File = "2-PREPARE.ps1"; Args = $a2 },
    @{ File = "3-PRECOMPILE.ps1"; Args = @() },
    @{ File = "4-BUILD-ANDROID.ps1"; Args = @() }
)
if ($Install) { $steps += @{ File = "5-INSTALL-PHONE.ps1"; Args = $a5 } }
$started = Get-Date
foreach ($s in $steps) {
    $a = @(); $a += $s.Args; if ($DryRun) { $a += "-DryRun" }
    Write-Host "`n=== $($s.File) ===" -ForegroundColor Cyan
    pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $s.File) @a
    if ($LASTEXITCODE -ne 0) { Write-Host "`nStopped: $($s.File) failed (its log is in the workspace's logs folder)." -ForegroundColor Red; exit 1 }
}
Write-Host ("`nAll done in {0:N0} minutes." -f ((Get-Date) - $started).TotalMinutes) -ForegroundColor Green
if (-not $Install) { Write-Host "To put it on your phone: pwsh -File scripts\5-INSTALL-PHONE.ps1" }
