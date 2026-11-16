# Change log

## 2026-11-15 — Working copy: first planning and safety improvements (unverified on iOS)
- Added a Today screen with dated/overdue tasks and shared daily notes.
- Added year navigation while keeping the original saved month keys and artwork.
- Added optional task due dates with backwards-compatible decoding of existing tasks.
- Added user-confirmed carry-forward that moves unfinished tasks without duplicating UUIDs.
- Added editable full backup export and confirmed restore for notes, tasks, cover and drawings.
- Documented file ownership, code interactions, save/restore flow, and rules for future agents.
- Added regression tests for new date/task/storage behavior.
- **Not yet verified:** Xcode compilation, XCTest execution, simulator/device behavior, signed app, or remote GitHub source upload.

## 2026-11-15 — Phase 1 project preparation
- Preserved the original Xcode project and seasonal artwork.
- Created project roadmap, architecture notes, test plan, agent instructions and Mac build script.
- Static source inspection only; no compiled app.

## 2026-11-15 — Development setup
- Imported the existing project and preserved source/artwork/data contracts.
- Added VS Code tasks, dependency-free macOS static validation and explicit Xcode prerequisite errors.
- Build helper runs simulator tests by default; import helper preserves remote files.
- Local simulator build blocked by missing full Xcode; no runtime success claimed.
- Fixed the CI-confirmed nonexistent Cocoa error code for unsupported backup versions; rejection and saved formats remain unchanged.
- Verified Xcode 26.6 simulator build and all 12 XCTest tests (zero failures) in CI run 43780104771.
