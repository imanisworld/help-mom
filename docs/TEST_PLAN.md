# Test plan and verification record

## Phase 3 save-integrity branch (new tests not yet executed)

- New XCTest coverage: blocked `planner.json` write prevents editable export; retry after filesystem recovery saves latest text; restore preserves previously unflushed edits in sibling recovery; failed drawing write does not increment successful-save revision.
- Run `bash Tools/build_and_test.sh` in macOS Xcode CI after integrating this PR. The prior verified 12-test CI baseline does not establish that these new changes compile or pass.
- Manual test: create a note and immediately restore an older backup; verify restored note and preserved local recovery copy. Try interrupted/low-storage saves on a test device before release.


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

[Run 43779305378](https://github.com/imanisworld/help-mom/actions/runs/43779305378) used Xcode 26.6 (17F113), iPhoneSimulator26.5 SDK. Compilation failed at `Store.swift:205`: `CocoaError.Code` has no member `fileReadUnknownVersion`. Replaced it with the existing native `fileReadCorruptFile` error for unsupported backup versions; validation still rejects the backup before changing files. The existing unsupported-backup regression test covers this path. Retest passed; see final result below.

[Run 43779530099](https://github.com/imanisworld/help-mom/actions/runs/43779530099), commit `f6b29d7`: **BUILD SUCCEEDED** on Xcode 26.6. XCTest did not execute because no eligible simulator was found. Added destination/runtime diagnostics to distinguish runner availability from destination selection.

[Run 43779882941](https://github.com/imanisworld/help-mom/actions/runs/43779882941) confirmed available iOS 26.2, 26.4.1 and 26.5 simulator destinations. Destination discovery now captures stderr as well as stdout from Xcode. No additional runtime installation is needed on the CI runner.

## Verified CI result (2026-11-15, America/Indiana/Indianapolis)

[Run 43780104771](https://github.com/imanisworld/help-mom/actions/runs/43780104771), tested commit `e1070a8`: **BUILD SUCCEEDED** and **TEST SUCCEEDED**.

- Xcode 26.6, build 17F113; iPhoneSimulator26.5 SDK.
- Test destination: iPad (A16), iOS 26.2, arm64.
- Command: `bash Tools/build_and_test.sh` (generic simulator build, then simulator XCTest).
- **12 tests executed, zero failures**: calendar/JSON (3), interaction/backup (4), storage/drawings (3), legacy tasks/date validation (2).
- The unsupported-backup regression passed after the one-line compiler fix.
- Nonblocking toolchain notices: unused AppIntents metadata extraction, signed Apple XCTest libraries not stripped, duplicate simulator architectures; existing checkout action reports Node 20 deprecation. No new frameworks were added to silence these notices.
- Local full Xcode remains absent. Manual UI/artwork/PDF smoke tests and real iPad/Pencil testing remain outstanding; XCTest success does not certify those flows.
- Subsequent documentation-only commits do not change the tested app or scripts.

## Independent-use acceptance (planned; not yet run)

After installation, ask Mom to complete these tasks without step-by-step coaching:

1. Open Creative Moments from its icon and find My Planner.
2. Add a plan or checklist item, change it, then return home.
3. Choose a seasonal picture, draw, make a mistake and undo it.
4. Write a reflection through My Journal.
5. Close and reopen the app; find the plan, reflection and drawing without manually saving.
6. Reopen a drawing through My Creations and share or print it.
7. Cancel an accidental destructive action and demonstrate recovery where deletion is supported.

Record completion, hesitation, wrong turns, requests for help, and any lost work. Repeat with larger system text and check layouts on iPhone and iPad. Any required developer-tool step or lost work fails acceptance. Proposed home/journal/gallery routes must be implemented before testing them; do not record this checklist as passed from unit-test results.

## Phase 2 verification
- Local static package validation: PASS after navigation implementation.
- Local native build: BLOCKED by Command Line Tools selection (full Xcode unavailable).
- Added three regression tests: legacy drawing discovery/filtering/order, shared journal/planner persistence, gallery refresh after restore. CI execution pending.
- Manual checks pending: open each home card; return Home; navigate older/future months; edit journal and verify same planner notes; resume seasonal/free drawing; reopen/share a creation; empty gallery; accessibility text sizes and VoiceOver.
