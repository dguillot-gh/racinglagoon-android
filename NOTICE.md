# Notices

## This repository
The scripts, build tools, Android app template and game setup are MIT-licensed ([LICENSE](LICENSE)). The build tools come from [psx-android](https://github.com/dguillot-gh/psx-android) (MIT, same author), by way of [ff7-android](https://github.com/dguillot-gh/ff7-android).

## The engine (`framework/`, a git submodule)
[psxrecomp-android](https://github.com/dguillot-gh/psxrecomp-android): [psxrecomp](https://github.com/mstan/psxrecomp) by mstan plus an Android layer. **PolyForm Noncommercial License 1.0.0** (<https://polyformproject.org/licenses/noncommercial/1.0.0>): personal and other non-commercial use only.

## OpenBIOS
`framework/bios/openbios.bin` is OpenBIOS from [PCSX-Redux](https://github.com/grumpycoders/pcsx-redux), MIT; see `framework/bios/OpenBIOS.LICENSE`. It is bundled into the app so no Sony BIOS is needed.

## Downloaded at build time (not in this repository)
- Java 17, the Android SDK, NDK and CMake (Google; you accept Android's SDK licence), Python, llvm-mingw, SDL3 (zlib licence), Gradle and the Android libraries the app uses.
- The app icon is made from the game's cover in [libretro-thumbnails](https://github.com/libretro-thumbnails/libretro-thumbnails), downloaded during the build and kept out of the repository.

## The game
*Racing Lagoon* belongs to its publisher. This repository contains no part of it: you build from your own disc, and the builds you make are for your own use.
