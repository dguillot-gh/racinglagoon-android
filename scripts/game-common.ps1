# Shared by the numbered scripts: where things are, the supported discs, logging. Dot-sourced:
#   . (Join-Path $PSScriptRoot "game-common.ps1")
# The game itself (its name, app id, supported discs) is described in game\port.ps1.
#
# Layout (the WORKSPACE is the folder that holds this repository):
#   workspace\<this repository>\     this repository
#   workspace\discs\                 your .cue/.bin files (any names: found by their SHA-1)
#   workspace\tools-cache\           Java 17, Android SDK/NDK, Python, llvm-mingw (1-INSTALL-TOOLS.ps1)
#   workspace\recomps\<game>\        the game set up from your discs (2-PREPARE.ps1)
#   workspace\android-recomp\<game>\ the build: generated code, Android app, pre-compiled code
#   workspace\apks\                  finished APKs
#   workspace\logs\                  one log per script run
$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
$Workspace = Split-Path -Parent $Repo
. (Join-Path $Repo "tools\paths.ps1")   # $DriveRoot (= workspace), $ToolsCache, $FrameworkDir, Find-*
. (Join-Path $Repo "game\port.ps1")     # $Game, $Package, $Title, $Supported

$DiscDir = Join-Path $Workspace "discs"
$RecompDir = Join-Path $DriveRoot "recomps\$Game"
$GameDir = Join-Path $DefaultWorkDir $Game
$ApkDir = Join-Path $Workspace "apks"
$LogDir = Join-Path $Workspace "logs"
$DiscCount = $Supported[0].Sha1.Count

New-Item -ItemType Directory -Force $LogDir | Out-Null
# Plain cmdlets only in these scripts: PCs in Constrained Language Mode block [IO.Path] and similar calls.
$script:LogFile = Join-Path $LogDir ("{0}-{1}.log" -f (Split-Path $MyInvocation.PSCommandPath -LeafBase), (Get-Date -Format "yyyyMMdd-HHmmss"))
function Say([string]$msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
    Write-Host $line
    Add-Content -Path $script:LogFile -Value $line
}
function Fail([string]$msg) { Say "FAIL: $msg"; exit 1 }

# Run a tool script (pwsh -File) and stop on failure. -DryRun only says what would run.
function Run-Step([string]$what, [string]$script, [string[]]$arguments = @()) {
    if ($DryRun) { Say "DRY RUN: would run $what ($script $($arguments -join ' '))"; return }
    Say "$what ..."
    pwsh -NoProfile -ExecutionPolicy Bypass -File $script @arguments 2>&1 | Tee-Object -FilePath $script:LogFile -Append | Out-Host
    if ($LASTEXITCODE -ne 0) { Fail "$what (exit $LASTEXITCODE; log $script:LogFile)" }
}

# The user's discs, in disc order, as .cue paths; matched by SHA-1 against $Supported.
# A disc is recognised by the SHA-1 of the FIRST file its .cue names (the data track: "Track 1" in a
# multi-file rip, the only .bin in a single-file one). Every file the .cue names must be next to it.
function Find-Discs {
    if (-not (Test-Path $DiscDir)) { Fail "no discs folder: put your .cue/.bin files in $DiscDir" }
    $found = @{}
    foreach ($cue in Get-ChildItem -LiteralPath $DiscDir -Filter *.cue -File) {
        $bins = @(Get-Content -LiteralPath $cue.FullName | ForEach-Object {
            if ($_ -match '^\s*FILE\s+"([^"]+)"' -or $_ -match '^\s*FILE\s+(\S+)') { Join-Path $DiscDir $Matches[1] } })
        if ($bins.Count -lt 1) { Say "skip $($cue.Name): it names no files"; continue }
        $missing = @($bins | Where-Object { -not (Test-Path -LiteralPath $_) })
        if ($missing.Count -gt 0) { Say "skip $($cue.Name): $($missing.Count) of its files are not next to it"; continue }
        Say "checking $($cue.Name) ..."
        $sha = (Get-FileHash -LiteralPath $bins[0] -Algorithm SHA1).Hash.ToLower()
        foreach ($s in $Supported) {
            $i = -1
            for ($k = 0; $k -lt $s.Sha1.Count; $k++) { if ($s.Sha1[$k] -eq $sha) { $i = $k } }
            if ($i -ge 0) { $found[$i] = $cue.FullName; Say "  disc $($i + 1) of $($s.Name)" }
        }
        if (-not ($Supported | Where-Object { $_.Sha1 -contains $sha })) { Say "  not a supported dump (SHA-1 $sha)" }
    }
    for ($i = 0; $i -lt $DiscCount; $i++) { if (-not $found.ContainsKey($i)) { Fail "disc $($i + 1) of $DiscCount not found in $DiscDir (see README: What you need)" } }
    return @(0..($DiscCount - 1) | ForEach-Object { $found[$_] })
}
