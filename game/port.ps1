# Racing Lagoon: what the build scripts need to know (dot-sourced by scripts\game-common.ps1).
$Game = 'racinglagoon_recomp'
$Package = 'com.psxrecomp.racinglagoon'
$Title = 'Racing Lagoon'
# Supported dumps: the SHA-1 of each disc's data track (the first file its .cue names), in disc order.
$Supported = @(
    @{ Name = 'Racing Lagoon (SLPS-02038)'
       Sha1 = @('31c7cb9dacdcab9c69c5c9dbbd0e2466f5c0a300') }
)
