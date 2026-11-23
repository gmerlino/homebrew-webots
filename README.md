# Homebrew Webots

Webots R2025a built from official source for Apple Silicon with current Homebrew Qt 6, Assimp, FreeType and FFmpeg.

```sh
brew install gmerlino/webots/webots
open /opt/homebrew/opt/webots/Webots.app
webots --version
brew test gmerlino/webots/webots
```

As checked on 2026-11-23, R2025a is the latest stable upstream release. There are nightly pre-releases through 2026-11-20, but no stable R2026a or R2026b. The formula pins commit `c6793d8f7230a311c4bc2a3101d9f1a8bc0aa01b` behind the annotated R2025a tag.

- Releases: https://github.com/cyberbotics/webots/releases
- macOS source build: https://github.com/cyberbotics/webots/wiki/macOS-installation

## Build and compatibility

Webots, its bundled ODE/Wren engines, controller APIs and sample controllers are compiled from source. Qt frameworks and standard libraries come from Homebrew. The Robotis SSH library also uses current Homebrew libssh, avoiding the upstream binary dependency on removed macOS OpenSSL 0.9.8. Official binary resources for OIS joystick support, Pico speech synthesis, the legacy Robotis ZIP support files and the e-puck XC16 firmware toolchain are preserved with SHA-256 checksums. This is a source build of Webots, not a claim that every dependency is built from source. The Robotis ZIP library and e-puck firmware toolchain retain their upstream legacy architectures; physical robot transfer has not been tested. Retaining the XC16 toolchain is for feature parity with the official cask and is not a claim that this external compiler is FOSS.

The embedded patch adapts C++ compilation and Qt tools, native ARM64 controller and robot-window build rules, and explicit FreeType linkage. The macOS port-availability probe uses native loopback sockets: an isolated Qt test on the validation host incorrectly reported successful connections to closed ports with a null peer address. The actual server and protocol remain Qt-based. An occupied-port test verified that Webots actually listens on the next port rather than reusing an occupied one.

## Controller development

```sh
export WEBOTS_HOME=/opt/homebrew/opt/webots/Webots.app
export WEBOTS_HOME_PATH="$WEBOTS_HOME/Contents"
make
```

`WEBOTS_HOME_PATH` matches the macOS bundle layout and is also set by Webots' built-in editor. C, C++, Python and Java interfaces are included. Java 27 currently emits a native-access warning, but the tested controller works.

## Validation

The standalone source build passed a falling-sphere physics test using C, C++, Python and Java controllers: height changed from 2.0 m to approximately 0.197963 m after 1.92 simulated seconds. Each controller writes a result file, so verification does not depend on console output being flushed at application shutdown.

The GUI was checked interactively: rendering shows the sphere and floor; Step advances 32 ms; real-time execution drops the sphere onto the floor; Pause stops the simulation. The packaged bundle passed the same four physics/controller tests. The final Homebrew installation passed all four controller/physics tests, the occupied-port test, `brew test`, strict code-signature verification, `brew linkage --test`, `brew missing` and `brew style`. Visual confirmation of the installed vacuum-gripper sample remains pending because the UI automation service could not locate its window; the original cask is still retained.

`brew test` checks offscreen startup, loading the native controller API and compiling a C++ controller. The full physics/controller suite needs a macOS graphical session; Homebrew’s isolated test environment cannot access all required graphical services.

Run the extended controller tests from this tap:

```sh
python3 tests/verify_controllers.py /opt/homebrew/opt/webots/Webots.app
python3 tests/verify_ports.py /opt/homebrew/opt/webots/Webots.app
```

## Migration

The old cask is retained until installed-package verification completes. Back up the application, preferences and projects before removal, and do not use `--zap`. The migration backup on the validation machine is under `~/webots-migration/backup`. No user project is edited by the tests, which use a dedicated temporary project.

## Nightly formula

`webots-nightly` pins the official `nightly_20_11_2026` tag at commit `49d2ab7df9efc95a6e7a44c31f114bf2c73fabb2`. It is a reproducible snapshot, not an automatically tracking HEAD build. Its internal Webots version remains R2025a.

```sh
brew install --build-from-source gmerlino/webots/webots-nightly
webots-nightly
```

The command and installation prefix are separate from stable Webots. Both bundles are named Webots.app and share upstream application identity and R2025a preferences: avoid running them simultaneously and back up settings before switching. No application link in /Applications is replaced.

Nightly patches were refreshed against the pinned source and checked with a clean dry run. Its upstream port detection already includes the macOS peer validation fix, so the stable-only socket patch is omitted. Formula syntax/style and metadata are checked. The nightly was successfully built and installed on the validation machine (2026-11-23); GUI verification by the user is pending for both installed variants. The stable formula’s runtime tests do not certify the nightly.
