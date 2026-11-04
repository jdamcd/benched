# CLAUDE.md

Benched is a native macOS menu bar app that shows Claude subscription usage
limits, read from Claude Code's `/usage` command. Pure Swift with AppKit and
SwiftUI, macOS 26 and later, no runtime dependencies.

## Build and run

Open `Benched.xcodeproj` in Xcode and press Run, or build from the command
line:

```bash
xcodebuild -project Benched.xcodeproj -scheme Benched build
```

Xcode passes its own environment to the app it runs. To see what real users
get (`PATH`, keychain access), launch the built app with `open`, which goes
through LaunchServices like a Finder launch.

Logs go to the unified log. zsh has its own `log` builtin, hence the full path:

```bash
/usr/bin/log stream --predicate 'subsystem == "com.jdamcd.benched"' --info
```

## Checks

```bash
./check          # swiftformat, build, unit tests and UI tests
./check --fast   # the same without UI tests
```

Run `./check` before committing. It's the only thing that formats the code:
CI (`.github/workflows/push.yml`) builds and runs the tests, minus the UI
tests, but doesn't run swiftformat.

UI tests take over the keyboard and screen, so use `--fast` by default and ask
before running the full check.

The output is long and gets truncated. Tee it to a log:

```bash
./check --fast 2>&1 | tee /tmp/check.log
```

## Project layout

- One app target, `Benched`, with an AppKit entry point (`AppDelegate`), an
  `NSStatusItem`, and an `NSPopover` that hosts SwiftUI views.
- The project uses synchronized folders, so adding, moving or deleting files
  needs no project file edit.
- Default actor isolation is `nonisolated`, not Xcode 26's MainActor default.
  Mark UI types `@MainActor` explicitly.
- `Benched/Usage/` holds the non-UI logic (running `claude`, scanning and
  decoding its output). It must not import SwiftUI or AppKit.
- `BenchedTests` (Swift Testing) is hosted by the app. `AppDelegate` skips the
  status item when it's hosting tests, so a test run never fetches usage for
  real.
- `BenchedUITests` launches the app with `--show-popover`, because XCUITest
  can't click a status item, and `--fixture <path>`, which replays a captured
  fixture instead of running `claude` (Debug builds only). With a fixture the
  app uses its own fresh settings suite and no snapshot cache.

## UI tests

```bash
xcodebuild test -project Benched.xcodeproj -scheme Benched \
    -destination 'platform=macOS' -only-testing:BenchedUITests
scripts/extract-screenshots.sh   # PNGs in screenshots/, which is gitignored
```

After changing UI code, run them (asking first, as above) and look at the
screenshots with the Read tool. Screenshots are of the app's own elements only,
never `XCUIScreen`, which would capture everything else on the screen. That
rules out the popover element too: its frame takes in the screen around its
rounded corners and arrow, so capture `popoverContent` inside it. The test
runner is sandboxed, so it can't read the app's defaults: check settings
through the UI instead.

## Snapshot tests

Snapshot tests render views at 1x in light and dark, with an en_GB locale and
UTC, and compare them with the PNGs in `Snapshots/<test file>/`. The images
live outside `BenchedTests/` because that folder is synchronized, and every PNG
in it would be copied into the test bundle. The views come from
`PreviewData`, which the SwiftUI previews use too.

A missing reference is recorded and the test fails once, so run the tests
again. To re-record after an intended change, delete the PNG and run twice.
Look at new or changed images (the Read tool shows PNGs) before committing.

## Fixtures

`BenchedTests/Fixtures/` holds real `claude -p /usage` output, named
`<claude version>-<variant>.jsonl`. To capture the current Claude Code's
output (it runs the real CLI, which uses no tokens):

```bash
scripts/capture-fixture.sh            # logged in, the normal case
scripts/capture-fixture.sh logged-out # also api-key, no-home
```

`LiveTests` runs the whole fetch against the real `claude` on this Mac. It's
skipped unless you ask for it:

```bash
TEST_RUNNER_BENCHED_LIVE=1 xcodebuild test -project Benched.xcodeproj \
    -scheme Benched -destination 'platform=macOS' -only-testing:BenchedTests/LiveTests
```

When Claude Code updates, capture a new fixture and compare it with the newest
one. If the format changed, keep both and add tests against the new one.

## The gauge

`scripts/draw-gauge.py` draws the app icon's layers and a menu bar image for
every 10% (`Assets.xcassets/MenuBarGauge/`) from the same shapes. Change the
script and rerun it rather than editing the SVGs, then re-record the menu bar
snapshots. To see the icon as macOS renders it:

```bash
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" \
    Benched/AppIcon.icon --export-image --output-file /tmp/icon.png \
    --platform macOS --rendition Default --width 256 --height 256 --scale 1
```

## Rules

- Every fix for a format change adds a fixture. Old fixtures are never
  deleted, so the decoder keeps handling every format it has seen.
