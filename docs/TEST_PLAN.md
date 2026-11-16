# Test plan and verification record

## Automated baseline

1. On a Mac with Xcode, inspect project and scheme, then run `Tools/build_and_test.sh`.
2. Record Xcode/build version, simulator model/OS, command, result and relevant logs.
3. Run all existing and new XCTest methods (date range, leap day/Monday start, JSON round-trip, persistence, corrupt-file non-overwrite, drawing isolation, legacy due-date decoding, valid/invalid date keys, Today query, one-time carry-forward and editable backup/restore).
4. Fix build warnings/errors and failing tests before new feature work.

## Manual smoke test on simulator
- Launch home, select first/middle/last month; open Calendar, Checklist, Doodle.
- Add tasks, edit notes and focus, navigate away, force quit, relaunch; verify values.
- Draw in adjacent sections/months and verify isolation after relaunch.
- Export a month as PDF; open file and inspect dates, note details, drawings, long/emoji text.
- Cover photo select/replace/remove; reject corrupt/unsupported image safely.
- Confirm error alerts are visible and recovery text is accurate.

## Real-device test on iPad (required for Pencil behavior)
- Finger and Apple Pencil; pen, marker, eraser, undo, redo and clear confirmation.
- Zoom/pan/rotation and saved stroke/artwork alignment after relaunch.
- Large drawings and interrupted background save; no data loss or freezes.

## Follow-on test requirements before schema changes
- Preserve v1 data byte-for-byte or retain restorable copy prior to migration.
- Successful migration, rollback, future-version data rejection and corrupt-file recovery.
- Complete editable backup round-trip (planner, all drawing files, cover and settings).
- Time-zone, DST, leap year, reminder permissions and recurrence idempotency.
- Accessibility (VoiceOver, dynamic type, contrast), iPhone compact size and iPad split view.

## Current verification (2026-11-15, local Mac)

- `python3 Tools/validate_package.py`: **PASS**. Six app Swift files and one test file parse; project references resolve; twelve scenes, icon dimensions/alpha, plists, asset JSON and shared scheme validate. This is syntax/inventory validation, not iOS type checking.
- `bash -n` on both shell helpers: **PASS**.
- `bash Tools/build_and_test.sh`: **BLOCKED**, exit 2. `xcodebuild` reports that `/Library/Developer/CommandLineTools` is not full Xcode. Compilation and all 12 XCTest methods **NOT RUN locally**.
- Simulator launch, runtime artwork loading, manual flows and real-device/Pencil tests: **NOT RUN**.
- Import preserves all app/test Swift files, Xcode files and artwork byte-for-byte from the newer local package; no application behavior or data format changed.
- The existing CI workflow invokes the build helper; it now requires an actual simulator test run and cannot succeed by silently skipping XCTest.

## First native CI build

[Run 43779305378](https://github.com/imanisworld/help-mom/actions/runs/43779305378) used Xcode 26.6 (17F113), iPhoneSimulator26.5 SDK. Compilation failed at `Store.swift:205`: `CocoaError.Code` has no member `fileReadUnknownVersion`. Replaced it with the existing native `fileReadCorruptFile` error for unsupported backup versions; validation still rejects the backup before changing files. The existing unsupported-backup regression test covers this path. Retest pending.

[Run 43779530099](https://github.com/imanisworld/help-mom/actions/runs/43779530099), commit `f6b29d7`: **BUILD SUCCEEDED** on Xcode 26.6. XCTest did not execute because no eligible simulator was found. Added destination/runtime diagnostics to distinguish runner availability from destination selection.

[Run 43779882941](https://github.com/imanisworld/help-mom/actions/runs/43779882941) confirmed available iOS 26.2, 26.4.1 and 26.5 simulator destinations. Destination discovery now captures stderr as well as stdout from Xcode. No additional runtime installation is needed on the CI runner.
